import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/core/utils/export_utils.dart';
import 'package:nizan_crm/core/utils/responsive_builder.dart';
import 'package:nizan_crm/features/accounts/controllers/expense_controller.dart';
import 'package:nizan_crm/features/accounts/data/artist_expense.dart' show mealLabel, mealsLabel, periodLabel, travelDistanceText;
import 'package:nizan_crm/features/accounts/data/food_allowance.dart';
import 'package:nizan_crm/features/accounts/data/work_cost.dart';
import 'package:nizan_crm/features/accounts/presentation/widgets/artist_day_timeline.dart';
import 'package:nizan_crm/features/accounts/presentation/widgets/finance_list_widgets.dart'
    show FinanceLoadError, financeTotalText;
import 'package:nizan_crm/features/accounts/presentation/widgets/list_common.dart';
import 'package:nizan_crm/presentation/common_widgets/paginated_footer.dart';

/// The headers and one row per cost line of a cost-per-work export.
const kWorkCostExportHeaders = [
  'Work date',
  'Client',
  'Booking no.',
  'Artist',
  'Category',
  'Meal',
  'Time',
  'Amount',
  'Status',
  'Placed',
  'Why',
  'Heads on work',
  'Work food per head',
  'Travel distance (km)',
  'Work food allowed',
  'Work food over allowance',
];

String _placed(String mode) => switch (mode) {
  'pinned' => 'Chosen by the artist',
  'time' => 'By time of the meal',
  'single' => 'Only work that day',
  'last' => 'Last work of the day',
  'direct' => 'Tied to the work',
  _ => mode,
};

List<List<String>> workCostExportRows(List<WorkCostRow> works) => [
  for (final w in works)
    for (final l in w.lines)
      [
        w.serviceStart == null
            ? ''
            : DateFormat('dd MMM yyyy').format(w.serviceStart!),
        w.customerName,
        w.bookingNumber,
        l.artist,
        l.category,
        // one meal ('lunch'), or every meal a combined bill covers ('breakfast + lunch + dinner')
        l.effectiveMeals.join(' + '),
        l.at == null ? '' : DateFormat('dd MMM yyyy h:mm a').format(l.at!),
        l.amount.toStringAsFixed(2),
        l.status,
        _placed(l.mode),
        l.reason,
        '${w.heads}',
        w.foodPerHead == null ? '' : w.foodPerHead!.toStringAsFixed(2),
        // how far the work is; blank when the booking has no distance
        w.travelDistanceKm > 0 ? (w.travelDistanceKm == w.travelDistanceKm.roundToDouble() ? w.travelDistanceKm.toStringAsFixed(0) : w.travelDistanceKm.toStringAsFixed(1)) : '',
        w.allowance.meals.any((m) => m.allowed != null) ? w.allowance.allowed.toStringAsFixed(2) : '',
        w.allowance.over > 0 ? w.allowance.over.toStringAsFixed(2) : '',
      ],
];

/// ACCOUNTS: what each WORK cost over the period shown above — the artists' food placed under the
/// work it was eaten for by the time of the meal. Search, artist and status narrow it; a work
/// opens to its lines; the whole thing exports as CSV / PDF.
class WorkCostsTab extends ConsumerStatefulWidget {
  /// The period ('YYYY-MM-DD', inclusive; null = no limit) — owned by the screen's period bar.
  final String? from;
  final String? to;

  /// The artists to filter by.
  final List<NameOption> artists;

  /// True when the tab sits in a NestedScrollView body (the Artist Finance screen).
  final bool inNestedScrollView;

  const WorkCostsTab({
    super.key,
    required this.from,
    required this.to,
    this.artists = const [],
    this.inNestedScrollView = false,
  });

  @override
  ConsumerState<WorkCostsTab> createState() => _WorkCostsTabState();
}

class _WorkCostsTabState extends ConsumerState<WorkCostsTab> {
  String _search = '';
  String? _employeeId;
  Set<String> _statuses = const {'pending', 'verified'};
  int _page = 1;
  WorkCostPage? _last;
  Timer? _debounce;
  late final _searchCtrl = TextEditingController();

  static const _statusChoices = <(String, String, Set<String>)>[
    ('counted', 'Pending + approved', {'pending', 'verified'}),
    ('verified', 'Approved only', {'verified'}),
    ('pending', 'Pending only', {'pending'}),
  ];

  WorkCostQuery get _query => WorkCostQuery(
    from: widget.from,
    to: widget.to,
    employeeId: _employeeId,
    statuses: _statuses,
    search: _search,
    page: _page,
  );

  @override
  void didUpdateWidget(WorkCostsTab old) {
    super.didUpdateWidget(old);
    if (old.from != widget.from || old.to != widget.to) {
      _page = 1; // a new period starts at the first page
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearch(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted && text.trim() != _search) {
        setState(() {
          _search = text.trim();
          _page = 1;
        });
      }
    });
    setState(() {}); // the clear button
  }

  Future<void> _export(bool pdf) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final all = await ref
          .read(expenseServiceProvider)
          .exportWorkCosts(_query);
      if (all.items.isEmpty) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Nothing to export for this period.')),
        );
        return;
      }
      final rows = workCostExportRows(all.items);
      final stamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      if (pdf) {
        await ExportUtils.exportPdf(
          'cost_per_work_$stamp.pdf',
          'Cost per work',
          kWorkCostExportHeaders,
          rows,
        );
      } else {
        await ExportUtils.exportCsv('cost_per_work_$stamp.csv', [
          kWorkCostExportHeaders,
          ...rows,
        ]);
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            all.truncated
                ? 'Exported the first part only — narrow the period for the rest.'
                : 'Exported ${all.items.length} works.',
          ),
        ),
      );
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final async = ref.watch(workCostsPageProvider(_query));
    if (async.hasValue) _last = async.value;
    final page = async.value ?? _last;

    if (page == null) {
      if (async.hasError) {
        return AppErrorView(
          error: async.error!,
          onRetry: () => ref.invalidate(workCostsPageProvider),
        );
      }
      return const Center(child: CircularProgressIndicator());
    }

    // Approving / deleting the only entry on the last page leaves that page empty.
    if (page.items.isEmpty &&
        page.page == _page &&
        page.page > page.totalPages &&
        page.totalPages >= 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _page == page.page) {
          setState(() => _page = page.totalPages);
        }
      });
    }

    final t = page.totals;
    final filtered =
        _search.isNotEmpty ||
        _employeeId != null ||
        !setEquals(_statuses, const {'pending', 'verified'});

    final slivers = <Widget>[
      if (widget.inNestedScrollView)
        Builder(
          builder: (ctx) => SliverOverlapInjector(
            handle: NestedScrollView.sliverOverlapAbsorberHandleFor(ctx),
          ),
        ),
      SliverPadding(
        padding: const EdgeInsets.only(top: 12, bottom: 24),
        sliver: SliverList.list(
          children: [
            if (async.isLoading)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: LinearProgressIndicator(minHeight: 3),
              ),
            if (async.hasError && !async.isLoading)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: FinanceLoadError(
                  error: async.error!,
                  onRetry: () => ref.invalidate(workCostsPageProvider),
                ),
              ),
            Text(
              'What each work cost',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: crm.textPrimary),
            ),
            Text(
              "Artists' food is counted under the work it was eaten for, by the time of the meal.",
              style: TextStyle(fontSize: 12, color: crm.textSecondary),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _pill(
                  crm,
                  'Food',
                  rupeesWhole(t.food),
                  crm.primary,
                  const Key('costsFood'),
                ),
                _pill(
                  crm,
                  'Other spend',
                  rupeesWhole(t.other),
                  crm.accent,
                  const Key('costsOther'),
                ),
                _pill(
                  crm,
                  'Total under works',
                  rupeesWhole(t.total),
                  crm.success,
                  const Key('costsTotal'),
                ),
                if (t.unplacedCount > 0)
                  _pill(
                    crm,
                    'Not placed · ${t.unplacedCount}',
                    rupeesWhole(t.unplaced),
                    crm.warning,
                    const Key('costsUnplaced'),
                  ),
                // Food over the per-head allowance: how many works, and by how much in all.
                if (t.overAllowanceCount > 0)
                  _pill(
                    crm,
                    'Over food allowance · ${t.overAllowanceCount} ${t.overAllowanceCount == 1 ? 'work' : 'works'}',
                    rupeesWhole(t.overAllowanceAmount),
                    crm.destructive,
                    const Key('costsOverAllowance'),
                  ),
              ],
            ),
            if (page.truncated)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  'More expenses matched than can be read at once, so these figures are partial — narrow the period.',
                  key: const Key('costsTruncated'),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: crm.warning,
                  ),
                ),
              ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('costsSearch'),
                    controller: _searchCtrl,
                    onChanged: _onSearch,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'Search client, booking no. or artist',
                      hintStyle: const TextStyle(fontSize: 13),
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: _searchCtrl.text.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.close, size: 18),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() {
                                  _search = '';
                                  _page = 1;
                                });
                              },
                            ),
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                PopupMenuButton<bool>(
                  key: const Key('costsExport'),
                  tooltip: 'Export',
                  onSelected: _export,
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: false, child: Text('Export CSV')),
                    PopupMenuItem(value: true, child: Text('Export PDF')),
                  ],
                  child: const Chip(
                    avatar: Icon(Icons.download_outlined, size: 18),
                    label: Text('Export'),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final (key, label, set) in _statusChoices)
                  ChoiceChip(
                    key: Key('costsStatus_$key'),
                    label: Text(label),
                    selected: setEquals(_statuses, set),
                    onSelected: (_) => setState(() {
                      _statuses = set;
                      _page = 1;
                    }),
                  ),
                if (widget.artists.isNotEmpty)
                  SizedBox(
                    width: 200,
                    child: DropdownButtonFormField<String?>(
                      key: const Key('costsArtist'),
                      initialValue:
                          widget.artists.any((a) => a.id == _employeeId)
                          ? _employeeId
                          : null,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        isDense: true,
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                      ),
                      hint: const Text(
                        'All artists',
                        style: TextStyle(fontSize: 13),
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('All artists'),
                        ),
                        for (final a in widget.artists)
                          DropdownMenuItem<String?>(
                            value: a.id,
                            child: Text(
                              a.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (v) => setState(() {
                        _employeeId = v;
                        _page = 1;
                      }),
                    ),
                  ),
                if (filtered)
                  TextButton(
                    key: const Key('costsClear'),
                    onPressed: () {
                      _searchCtrl.clear();
                      setState(() {
                        _search = '';
                        _employeeId = null;
                        _statuses = const {'pending', 'verified'};
                        _page = 1;
                      });
                    },
                    child: const Text('Clear'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              financeTotalText(total: page.totalItems, noun: 'works'),
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: crm.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
      if (page.items.isEmpty)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Column(
              children: [
                Icon(
                  Icons.payments_outlined,
                  size: 44,
                  color: crm.textSecondary.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 10),
                Text(
                  filtered
                      ? 'No works match these filters.'
                      : 'No work costs in this period.',
                  key: const Key('costsEmpty'),
                  style: TextStyle(color: crm.textSecondary),
                ),
              ],
            ),
          ),
        )
      else
        SliverList.builder(
          itemCount: page.items.length,
          itemBuilder: (_, i) => _WorkCostCard(row: page.items[i]),
        ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 24),
          child: PaginatedFooter(
            page: page.page,
            limit: page.limit,
            totalPages: page.totalPages,
            totalItems: page.totalItems,
            currentItemCount: page.items.length,
            onPrevious: page.page > 1
                ? () => setState(() => _page = page.page - 1)
                : null,
            onNext: page.page < page.totalPages
                ? () => setState(() => _page = page.page + 1)
                : null,
          ),
        ),
      ),
    ];

    // On a phone the other tabs of this screen sit 16px in from the edge; match them.
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: widget.inNestedScrollView && ResponsiveBuilder.isMobile(context) ? 16 : 0),
      child: CustomScrollView(
        key: const PageStorageKey<String>('workCosts'),
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: slivers,
      ),
    );
  }

  static bool setEquals(Set<String> a, Set<String> b) =>
      a.length == b.length && a.containsAll(b);

  Widget _pill(
    CrmTheme crm,
    String label,
    String value,
    Color color,
    Key key,
  ) => Container(
    key: key,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withValues(alpha: 0.25)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: crm.textSecondary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w900,
            color: crm.textPrimary,
          ),
        ),
      ],
    ),
  );
}

/// One work: what it cost, split by kind, opening to the lines behind it.
class _WorkCostCard extends StatelessWidget {
  final WorkCostRow row;
  const _WorkCostCard({required this.row});

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final when = row.serviceStart == null
        ? ''
        : DateFormat('EEE d MMM yyyy').format(row.serviceStart!);
    final kinds = <(String, double)>[
      ('Food', row.food),
      ('Travel', row.travel),
      ('Stay', row.stay),
      ('Materials', row.materials),
      ('Fuel', row.fuel),
      ('Other', row.other),
    ].where((k) => k.$2 > 0).toList();

    return Container(
      key: Key('workCost_${row.bookingId}'),
      margin: const EdgeInsets.only(bottom: 12),
      // A Material (not a coloured box) so the tile's ink and splashes show.
      child: Material(
        color: crm.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: crm.border),
        ),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            // its own storage slot — the list's scroll view saves a scroll offset under its own key
            key: PageStorageKey<String>('workCostTile_${row.bookingId}'),
            tilePadding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
            childrenPadding: const EdgeInsets.only(bottom: 8),
            title: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        row.customerName.isEmpty ? 'Work' : row.customerName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [
                          if (when.isNotEmpty) when,
                          if (row.period.isNotEmpty) periodLabel(row.period),
                          if (row.bookingNumber.isNotEmpty) row.bookingNumber,
                          if (row.artists.isNotEmpty) row.artists.join(', '),
                        ].join('  ·  '),
                        style: TextStyle(
                          fontSize: 11.5,
                          color: crm.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      rupeesWhole(row.total),
                      key: Key('workCostTotal_${row.bookingId}'),
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    if (row.pendingCount > 0)
                      Text(
                        '${row.pendingCount} pending',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: crm.warning,
                        ),
                      ),
                  ],
                ),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  if (row.allowance.hasOver)
                    Container(
                      key: Key('overChip_${row.bookingId}'),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: crm.destructive.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Over allowance ${rupeesWhole(row.allowance.over)}',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: crm.destructive),
                      ),
                    ),
                  // How far the work is — Accounts checks the amounts against it.
                  if (row.travelDistanceKm > 0)
                    Container(
                      key: Key('distanceChip_${row.bookingId}'),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: crm.textSecondary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.route_outlined, size: 12, color: crm.textSecondary),
                          const SizedBox(width: 4),
                          Text(
                            travelDistanceText(row.travelDistanceKm),
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: crm.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  // Per head: the work's food over everyone assigned (lead + assistants).
                  if (row.heads > 0 && row.food > 0)
                    Container(
                      key: Key('perHeadChip_${row.bookingId}'),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: crm.success.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${row.heads} ${row.heads == 1 ? 'head' : 'heads'} · ${rupeesWhole(row.foodPerHead ?? 0)} food / head',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: crm.success),
                      ),
                    ),
                  for (final k in kinds)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color:
                            (k.$1 == 'Food' ? crm.primary : crm.textSecondary)
                                .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${k.$1} ${rupeesWhole(k.$2)}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: k.$1 == 'Food'
                              ? crm.primary
                              : crm.textSecondary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            children: [
              if (row.people.isNotEmpty) _PerHeadBlock(row: row),
              if (row.allowance.meals.isNotEmpty || row.allowance.noMeal > 0) _AllowanceBlock(row: row),
              for (final l in row.lines) _CostLineRow(line: l),
            ],
          ),
        ),
      ),
    );
  }
}

/// Per head: who is on the work, what each spent on food, and the work's food ÷ heads.
class _PerHeadBlock extends StatelessWidget {
  final WorkCostRow row;
  const _PerHeadBlock({required this.row});

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return Container(
      key: Key('perHead_${row.bookingId}'),
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: crm.success.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: crm.success.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('PER HEAD', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 0.6, color: crm.success)),
          const SizedBox(height: 6),
          for (final p in row.people)
            Padding(
              key: Key('person_${row.bookingId}_${p.employeeId}'),
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Expanded(
                    child: Text.rich(
                      TextSpan(children: [
                        TextSpan(text: p.name.isEmpty ? 'Artist' : p.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                        TextSpan(text: '  ·  ${p.roleLabel}', style: TextStyle(color: crm.textSecondary)),
                      ]),
                      style: const TextStyle(fontSize: 12.5),
                    ),
                  ),
                  Text(
                    p.food > 0 ? rupeesWhole(p.food) : 'No food filed',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: p.food > 0 ? crm.textPrimary : crm.textSecondary),
                  ),
                ],
              ),
            ),
          if (row.foodPerHead != null) ...[
            const Divider(height: 14),
            Text(
              'Food ${rupeesWhole(row.food)} ÷ ${row.heads} ${row.heads == 1 ? 'head' : 'heads'} = ${rupeesWhole(row.foodPerHead!)} per head',
              key: Key('perHeadSum_${row.bookingId}'),
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800),
            ),
          ],
        ],
      ),
    );
  }
}

/// The work's food against the allowance, meal by meal: spent, allowed (heads × per head), over.
class _AllowanceBlock extends StatelessWidget {
  final WorkCostRow row;
  const _AllowanceBlock({required this.row});

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final a = row.allowance;
    return Container(
      key: Key('allowance_${row.bookingId}'),
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: (a.hasOver ? crm.destructive : crm.primary).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: (a.hasOver ? crm.destructive : crm.primary).withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('FOOD ALLOWANCE', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 0.6, color: a.hasOver ? crm.destructive : crm.primary)),
          const SizedBox(height: 6),
          for (final m in a.meals) _mealRow(crm, m),
          if (a.noMeal > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('${rupeesWhole(a.noMeal)} with no meal recorded — not checked', style: TextStyle(fontSize: 11.5, color: crm.textSecondary)),
            ),
        ],
      ),
    );
  }

  Widget _mealRow(CrmTheme crm, MealAllowanceCheck m) {
    final String detail;
    final Color color;
    switch (m.status) {
      case 'over':
        detail = 'Over by ${rupeesWhole(m.over)}';
        color = crm.destructive;
      case 'within':
        detail = 'Within';
        color = crm.success;
      case 'no_heads':
        detail = 'Nobody assigned — not checked';
        color = crm.textSecondary;
      default:
        detail = 'No allowance set';
        color = crm.textSecondary;
    }
    final allowed = m.allowed == null
        ? ''
        : ' of ${rupeesWhole(m.allowed!)} (${row.heads} × ${rupeesWhole(m.allowancePerHead ?? 0)})';
    return Padding(
      key: Key('allowanceMeal_${row.bookingId}_${m.meal}'),
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text.rich(
              TextSpan(children: [
                TextSpan(text: m.meals.length > 1 ? mealsLabel(m.meals) : mealLabel(m.meal), style: const TextStyle(fontWeight: FontWeight.w700)),
                TextSpan(text: '   ${rupeesWhole(m.actual)}$allowed', style: TextStyle(color: crm.textSecondary)),
              ]),
              style: const TextStyle(fontSize: 12.5),
            ),
          ),
          Text(detail, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }
}

class _CostLineRow extends StatelessWidget {
  final CostLine line;
  const _CostLineRow({required this.line});

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final struck = !line.counted;
    return Padding(
      key: Key('costsLine_${line.expenseId}'),
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(costLineIcon(line), size: 18, color: crm.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  [
                    costLineLabel(line),
                    if (line.artist.isNotEmpty) line.artist,
                  ].join('  ·  '),
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    decoration: struck ? TextDecoration.lineThrough : null,
                  ),
                ),
                if (line.reason.isNotEmpty)
                  Text(
                    line.reason,
                    style: TextStyle(fontSize: 11.5, color: crm.textSecondary),
                  ),
                if (line.isFar)
                  Text(
                    'Check the time — far from any work',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: crm.warning,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            rupeesWhole(line.amount),
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              decoration: struck ? TextDecoration.lineThrough : null,
            ),
          ),
        ],
      ),
    );
  }
}
