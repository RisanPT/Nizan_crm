import 'package:flutter/material.dart';
import 'package:nizan_crm/features/accounts/data/artist_expense.dart';
import 'package:nizan_crm/features/accounts/data/finance_list.dart';
import 'package:nizan_crm/features/accounts/presentation/widgets/artist_finance_common.dart';
import 'package:nizan_crm/features/accounts/presentation/widgets/artist_finance_list_kit.dart';
import 'package:nizan_crm/features/accounts/presentation/widgets/finance_list_widgets.dart';
import 'package:nizan_crm/features/accounts/presentation/widgets/list_common.dart' show NameOption;

/// Desktop Artist Finance → Expenses: four totals, then ONE card with the filters across the top
/// (search · Filters · sort · page size, status chips, what is switched on), the breakdown and the
/// table. Real data only — an empty period says so — and no horizontal scrolling: the columns share
/// the width there is, and a narrow window gets cards instead (see [AfTable]).
class ArtistFinanceExpensesView extends StatelessWidget {
  final FinancePage<ArtistExpense>? data;
  final FinanceQuery query;
  final ValueChanged<FinanceQuery> onQueryChanged;

  /// The artists the list can be narrowed to (empty = an artist sees only their own, no picker).
  final List<NameOption> artists;
  final VoidCallback onExport;
  final ValueChanged<ArtistExpense> onApprove;
  final ValueChanged<ArtistExpense> onReject;
  final ValueChanged<ArtistExpense> onEdit;
  final ValueChanged<ArtistExpense> onDelete;
  final ValueChanged<String> onViewReceipt;
  final bool canVerify;

  /// A page is being fetched / failed to load (the last page that did load stays on screen).
  final bool loading;
  final Object? error;
  final VoidCallback? onRetry;

  /// The totals of the period just before this one, for "vs Oct"; null = nothing to compare.
  final FinanceSummary? previous;
  final String previousLabel;

  const ArtistFinanceExpensesView({
    super.key,
    required this.data,
    required this.query,
    required this.onQueryChanged,
    required this.artists,
    required this.onExport,
    required this.onApprove,
    required this.onReject,
    required this.onEdit,
    required this.onDelete,
    required this.onViewReceipt,
    this.canVerify = true,
    this.loading = false,
    this.error,
    this.onRetry,
    this.previous,
    this.previousLabel = 'last period',
  });

  static const _columns = [
    AfColumn('Date', width: 104),
    AfColumn('Artist', flex: 3),
    AfColumn('Work', flex: 3),
    AfColumn('Category', flex: 3),
    AfColumn('Amount', width: 116, right: true),
    AfColumn('Status', width: 96),
    AfColumn('', width: 44),
  ];

  @override
  Widget build(BuildContext context) {
    final s = data?.summary;
    final total = s?.allAmount ?? 0.0;
    double share(double part) => total > 0 ? part / total * 100 : 0;
    String pct(double part) => '${share(part).round()}% of total';
    final delta = s == null
        ? null
        : afDeltaText(current: total, previous: previous?.allAmount, previousLabel: previousLabel, higherIsGood: false);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AfKpiRow(
            cards: [
              AfKpiCard(
                icon: Icons.account_balance_wallet_outlined,
                iconColor: AfTheme.coral,
                iconBgColor: AfTheme.coralLight,
                title: 'Total Expenses',
                value: AfTheme.formatCurrency(total),
                subtext: delta?.text ?? (s == null ? null : '${s.allCount} ${s.allCount == 1 ? 'claim' : 'claims'}'),
                subtextColor: delta?.color ?? AfTheme.textSecondary,
              ),
              AfKpiCard(
                icon: Icons.layers_outlined,
                iconColor: AfTheme.green,
                iconBgColor: AfTheme.greenLight,
                title: 'Approved',
                value: AfTheme.formatCurrency(s?.status('verified').amount ?? 0),
                subtext: s == null ? null : '${s.status('verified').count} · ${pct(s.status('verified').amount)}',
                subtextColor: AfTheme.green,
              ),
              AfKpiCard(
                icon: Icons.hourglass_empty,
                iconColor: AfTheme.yellow,
                iconBgColor: AfTheme.yellowLight,
                title: 'Pending',
                value: AfTheme.formatCurrency(s?.status('pending').amount ?? 0),
                subtext: s == null ? null : '${s.status('pending').count} · ${pct(s.status('pending').amount)}',
                subtextColor: AfTheme.yellow,
              ),
              AfKpiCard(
                icon: Icons.cancel_outlined,
                iconColor: AfTheme.red,
                iconBgColor: AfTheme.redLight,
                title: 'Rejected',
                value: AfTheme.formatCurrency(s?.status('rejected').amount ?? 0),
                subtext: s == null ? null : '${s.status('rejected').count} · ${pct(s.status('rejected').amount)}',
                subtextColor: AfTheme.textSecondary,
              ),
            ],
          ),
          const SizedBox(height: 16),
          AfListPanel<ArtistExpense>(
            title: 'Expenses',
            noun: 'expenses',
            data: data,
            query: query,
            onQueryChanged: onQueryChanged,
            loading: loading,
            error: error,
            onRetry: onRetry,
            onExport: onExport,
            emptyIcon: Icons.receipt_long_outlined,
            emptyHint: 'Expenses the artists file will appear here.',
            controls: AfListControls(
              kind: FinanceKind.expense,
              query: query,
              summary: s,
              onChanged: onQueryChanged,
              artists: artists,
              searchHint: 'Search client, artist, category, booking no., notes or amount',
            ),
            breakdown: s == null
                ? null
                : AfBreakdownTile(
                    storageKey: 'afExpenseBreakdown',
                    groups: [
                      BreakdownGroup(
                        title: 'By category',
                        rows: s.byCategory,
                        keyPrefix: 'category',
                        labels: kArtistExpenseCategoryLabels,
                        isOn: (r) => query.categories.contains(r.key),
                        onTap: (r) => onQueryChanged(query.refiltered(categories: _toggle(query.categories, r.key))),
                      ),
                      BreakdownGroup(
                        title: 'By work type',
                        rows: s.byWorkType,
                        keyPrefix: 'work',
                        labels: kWorkTypeLabels,
                        isOn: (r) => query.workType == r.key,
                        onTap: (r) => onQueryChanged(query.refiltered(workType: query.workType == r.key ? null : r.key)),
                      ),
                      if (artists.isNotEmpty)
                        BreakdownGroup(
                          title: 'By artist',
                          rows: s.byArtist,
                          keyPrefix: 'artist',
                          isOn: (r) => query.employeeId == r.key,
                          onTap: (r) => onQueryChanged(query.refiltered(employeeId: query.employeeId == r.key ? null : r.key)),
                        ),
                    ],
                  ),
            table: (items) => AfTable<ArtistExpense>(
              columns: _columns,
              items: items,
              rowKey: (e) => Key('afExpenseRow_${e.id}'),
              cells: _cells,
              card: _card,
            ),
          ),
        ],
      ),
    );
  }

  static Set<String> _toggle(Set<String> current, String key) {
    final next = {...current};
    next.contains(key) ? next.remove(key) : next.add(key);
    return next;
  }

  // ── what a row says ────────────────────────────────────────────────────────

  String _artist(ArtistExpense e) => e.employee?.name ?? 'Artist';

  /// (client, booking · service) for the work the spend is under — or what it is instead.
  (String, String, bool) _work(ArtistExpense e) {
    final b = e.booking;
    if (b != null) {
      final sub = [if (b.bookingNumber.isNotEmpty) b.bookingNumber, if (b.service.isNotEmpty) b.service].join(' · ');
      return (b.customerName.isEmpty ? (b.bookingNumber.isEmpty ? 'Work' : b.bookingNumber) : b.customerName, sub, false);
    }
    if (e.workType == 'model_shoot') return ('Model shoot', 'Internal shoot', false);
    final placed = e.allocation?.isPlaced ?? false;
    return placed ? ('Placed by meal time', e.allocation?.reason ?? '', false) : ('Not tied to a work', e.allocation?.reason ?? '', true);
  }

  /// "Food · Lunch" for a meal, else the notes (or nothing).
  String _detail(ArtistExpense e) {
    final meals = e.effectiveMeals;
    final bits = [if (e.category == 'food' && meals.isNotEmpty) mealsLabel(meals), if (e.notes.trim().isNotEmpty) e.notes.trim()];
    return bits.join(' · ');
  }

  List<Widget> _cells(ArtistExpense e) {
    final (client, sub, warn) = _work(e);
    final detail = _detail(e);
    return [
      AfCellText(afDay(e.date), muted: true),
      Row(
        children: [
          AfInitialsAvatar(name: _artist(e), size: 26),
          const SizedBox(width: 8),
          Expanded(child: AfCellText(_artist(e), strong: true)),
        ],
      ),
      Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AfCellText(client, strong: true, color: warn ? AfTheme.yellow : null),
          if (sub.isNotEmpty) AfCellText(sub, muted: true),
        ],
      ),
      Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AfFit(AfCategoryBadge(category: e.category)),
          if (detail.isNotEmpty) ...[const SizedBox(height: 3), AfCellText(detail, muted: true)],
        ],
      ),
      _amount(e),
      AfFit(AfStatusBadge(status: e.status)),
      _menu(e),
    ];
  }

  Widget _card(ArtistExpense e) {
    final (client, sub, warn) = _work(e);
    final detail = _detail(e);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            AfInitialsAvatar(name: _artist(e), size: 30),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AfCellText(_artist(e), strong: true),
                  AfCellText([client, if (sub.isNotEmpty) sub].join(' · '), muted: true, color: warn ? AfTheme.yellow : null),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _amount(e),
            _menu(e),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            AfCellText(afDay(e.date), muted: true),
            AfCategoryBadge(category: e.category),
            AfStatusBadge(status: e.status),
          ],
        ),
        if (detail.isNotEmpty) ...[const SizedBox(height: 6), AfCellText(detail, muted: true, maxLines: 2)],
      ],
    );
  }

  /// The amount that counts. When the approval reduced it, the logged amount sits under it —
  /// and the reason, if one was given, shows on hover.
  Widget _amount(ArtistExpense e) {
    final main = AfCellText(AfTheme.formatCurrency(e.amount), strong: true);
    if (!e.isReduced) return main;
    final note = e.approvalNote.trim();
    final col = Column(
      key: Key('afExpenseReduced_${e.id}'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        main,
        AfCellText('Logged ${AfTheme.formatCurrency(e.loggedAmount!)}', muted: true, color: AfTheme.yellow),
      ],
    );
    return note.isEmpty ? col : Tooltip(message: 'Approved for less: $note', child: col);
  }

  Widget _menu(ArtistExpense e) => PopupMenuButton<String>(
        key: Key('afExpenseMenu_${e.id}'),
        tooltip: 'Actions',
        padding: EdgeInsets.zero,
        icon: const Icon(Icons.more_horiz, size: 18, color: AfTheme.textSecondary),
        onSelected: (v) {
          switch (v) {
            case 'receipt':
              onViewReceipt(e.receiptImage);
            case 'approve':
              onApprove(e);
            case 'reject':
              onReject(e);
            case 'edit':
              onEdit(e);
            case 'delete':
              onDelete(e);
          }
        },
        itemBuilder: (_) => [
          if (e.receiptImage.isNotEmpty) const PopupMenuItem(value: 'receipt', child: Text('View receipt')),
          if (canVerify && e.status == 'pending') ...const [
            PopupMenuItem(value: 'approve', child: Text('Approve expense')),
            PopupMenuItem(value: 'reject', child: Text('Reject expense')),
          ],
          const PopupMenuItem(value: 'edit', child: Text('Edit')),
          const PopupMenuItem(value: 'delete', child: Text('Delete')),
        ],
      );
}
