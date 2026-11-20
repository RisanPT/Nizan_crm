import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:nizan_crm/core/auth/workspace.dart' show effectiveAccessProvider;
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/extensions/space_extension.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/core/utils/responsive_builder.dart';
import 'package:nizan_crm/features/accounts/data/finance_list.dart' show FinanceQuery;
import 'package:nizan_crm/features/accounts/presentation/widgets/finance_list_widgets.dart' show FinanceLoadError;
import 'package:nizan_crm/features/accounts/presentation/widgets/list_common.dart';
import 'package:nizan_crm/features/associates/data/associate_works.dart';
import 'package:nizan_crm/features/associates/services/associate_works_service.dart';
import 'package:nizan_crm/features/inventory/presentation/widgets/inventory_widgets.dart';
import 'package:nizan_crm/presentation/common_widgets/paginated_footer.dart';

/// ₹ with Indian grouping; paise only when there are some.
String associateRupees(num v) => NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: v % 1 == 0 ? 0 : 2).format(v);

/// ASSOCIATE WORKS: the outside associate artists Operations puts on a work, which works each did, and what Accounts recorded as their fee
/// for each. The works come from the bookings' own teams; the money from Artist Payouts — nothing is typed twice, and a work with no fee
/// recorded says "No fee yet" instead of showing a guess. Operations sees the works; the money is for Accounts and the owners.
class AssociateWorksScreen extends ConsumerStatefulWidget {
  const AssociateWorksScreen({super.key});

  @override
  ConsumerState<AssociateWorksScreen> createState() => _AssociateWorksScreenState();
}

class _AssociateWorksScreenState extends ConsumerState<AssociateWorksScreen> {
  FinancePeriod _period = FinancePeriod.month;
  DateTime _month = FinancePeriodBar.thisMonth();
  DateTimeRange? _range;
  late AssociateWorksQuery _query = _queryFor(const AssociateWorksQuery(from: '', to: ''));
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  bool _busy = false;

  /// The last page that loaded, kept on screen while the next one is fetched.
  AssociateWorksPage? _last;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  static String _dayText(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  AssociateWorksQuery _queryFor(AssociateWorksQuery q) {
    if (_period == FinancePeriod.range && _range != null) return q.refiltered(from: _dayText(_range!.start), to: _dayText(_range!.end));
    final (from, to) = FinanceQuery.monthBounds(_month);
    return q.refiltered(from: from, to: to);
  }

  void _setQuery(AssociateWorksQuery q) => setState(() => _query = q);

  void _setPeriod(FinancePeriod p, {DateTime? month, DateTimeRange? range}) {
    _period = p;
    if (month != null) _month = DateTime(month.year, month.month);
    if (range != null) _range = range;
    _setQuery(_queryFor(_query));
  }

  void _onSearch(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted && text.trim() != _query.search.trim()) _setQuery(_query.refiltered(search: text.trim()));
    });
  }

  Future<void> _export() async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final data = await ref.read(associateWorksServiceProvider).export(_query);
      if (!mounted) return;
      if (data.items.isEmpty) {
        messenger.showSnackBar(const SnackBar(content: Text('Nothing to export for these filters.')));
      } else {
        await ref.read(associateCsvSaverProvider)(associateCsvFileName(data), associateWorksCsvRows(data));
      }
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final isMobile = ResponsiveBuilder.isMobile(context);
    final async = ref.watch(associateWorksProvider(_query));
    if (async.hasValue) _last = async.value;
    final page = async.value ?? _last;
    if (page == null) {
      if (async.hasError) return AppErrorView(error: async.error!, onRetry: () => ref.invalidate(associateWorksProvider));
      return const Center(child: CircularProgressIndicator());
    }
    final fees = page.canSeeFees;
    final s = page.summary;
    return ListView(
      padding: EdgeInsets.fromLTRB(isMobile ? 16 : 24, 16, isMobile ? 16 : 24, 24),
      children: [
        if (async.isLoading) const Padding(padding: EdgeInsets.only(bottom: 8), child: LinearProgressIndicator(minHeight: 3)),
        _header(crm, isMobile),
        14.h,
        const _TempStaffBanner(),
        FinancePeriodBar(
          period: _period,
          month: _month,
          range: _range,
          allowAll: false,
          onMonth: (m) => _setPeriod(FinancePeriod.month, month: m),
          onRange: (r) => _setPeriod(FinancePeriod.range, range: r),
          onAll: () {},
        ),
        if (async.hasError) ...[10.h, FinanceLoadError(error: async.error!, onRetry: () => ref.invalidate(associateWorksProvider))],
        14.h,
        InvStatGrid(
          isMobile: isMobile,
          stats: [
            InvStat('${s.associates}', 'Associates working${page.registered > 0 ? ' · ${page.registered} registered' : ''}', Icons.groups_2_outlined, crm.primary),
            InvStat('${s.works}', 'Works · ${s.days} ${s.days == 1 ? 'day' : 'days'}', Icons.event_available_outlined, crm.accent),
            if (fees) ...[
              InvStat(associateRupees(s.fee ?? 0), 'Fees recorded · ${associateRupees(s.paid ?? 0)} paid', Icons.payments_outlined, crm.success),
              InvStat(associateRupees(s.owed ?? 0), 'Still to pay · ${s.noFee ?? 0} ${(s.noFee ?? 0) == 1 ? 'work has' : 'works have'} no fee yet', Icons.hourglass_bottom_rounded, (s.owed ?? 0) > 0 || (s.noFee ?? 0) > 0 ? crm.warning : crm.success),
            ] else ...[
              InvStat('${page.registered}', 'Associates registered', Icons.how_to_reg_outlined, crm.success),
              InvStat(s.works == 0 ? '—' : (s.days / s.works).toStringAsFixed(1), 'Days per work', Icons.timelapse_rounded, crm.warning),
            ],
          ],
        ),
        8.h,
        Text(
          fees
              ? 'The works are the bookings each associate is on (a booking counts once, on its first day). A fee is what Accounts recorded in Artist Payouts — a work with none says "No fee yet"; nothing is guessed.'
              : 'The works are the bookings each associate is on (a booking counts once, on its first day). Fees are shown to Accounts and the owners.',
          key: const Key('assocNote'),
          style: TextStyle(fontSize: 11.5, color: crm.textSecondary),
        ),
        if (fees && page.elsewhere != null && page.elsewhere!.count > 0) ...[10.h, _elsewhere(crm, page.elsewhere!)],
        14.h,
        _associates(crm, page),
        14.h,
        _toolbar(crm, fees),
        12.h,
        if (page.items.isEmpty) _empty(crm, page) else ...page.items.map((w) => Padding(padding: const EdgeInsets.only(bottom: 10), child: _WorkCard(work: w, fees: fees))),
        8.h,
        PaginatedFooter(
          page: page.page,
          limit: page.limit,
          totalPages: page.totalPages,
          totalItems: page.totalItems,
          currentItemCount: page.items.length,
          onPrevious: page.page > 1 ? () => _setQuery(_query.copyWith(page: page.page - 1)) : null,
          onNext: page.page < page.totalPages ? () => _setQuery(_query.copyWith(page: page.page + 1)) : null,
        ),
      ],
    );
  }

  Widget _header(CrmTheme crm, bool isMobile) => Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Associate Works', key: const Key('assocTitle'), style: TextStyle(fontSize: isMobile ? 22 : 28, fontWeight: FontWeight.w800, color: crm.textPrimary)),
            4.h,
            Text('Outside associate artists: which works they did, and what they were paid.', style: TextStyle(fontSize: 13, color: crm.textSecondary)),
          ]),
        ),
        IconButton(
          key: const Key('assocExport'),
          tooltip: 'Download everything that matches',
          onPressed: _busy ? null : _export,
          icon: const Icon(Icons.download_rounded),
          style: IconButton.styleFrom(foregroundColor: crm.accent, backgroundColor: crm.accent.withValues(alpha: 0.10)),
        ),
        4.w,
        IconButton(key: const Key('assocRefresh'), tooltip: 'Refresh', onPressed: () => ref.invalidate(associateWorksProvider), icon: const Icon(Icons.refresh_rounded)),
      ]);

  Widget _elsewhere(CrmTheme crm, AssociateElsewhere e) => Container(
        key: const Key('assocElsewhere'),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: crm.warning.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: crm.warning.withValues(alpha: 0.3))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.account_balance_wallet_outlined, size: 18, color: crm.warning),
          10.w,
          Expanded(
            child: Text(
              '${associateRupees(e.amount)} was paid to associates in this period (${e.count} ${e.count == 1 ? 'payout' : 'payouts'}) but is not on any of these works — it has no booking, or the booking is outside the period.',
              style: TextStyle(fontSize: 12.5, height: 1.35, color: crm.textPrimary),
            ),
          ),
        ]),
      );

  /// One chip per associate (tap to see only their works) — with works and, for those who may see money, their fees.
  Widget _associates(CrmTheme crm, AssociateWorksPage page) {
    if (page.associates.isEmpty) return const SizedBox.shrink();
    return Wrap(spacing: 8, runSpacing: 8, children: [
      _AssociateChip(key: const Key('assocLine_all'), label: 'All associates', sub: '${page.summary.works} works', selected: _query.associateId.isEmpty, onTap: () => _setQuery(_query.refiltered(associateId: ''))),
      for (final a in page.associates)
        _AssociateChip(
          key: Key('assocLine_${a.id}'),
          label: a.name,
          sub: '${a.works} ${a.works == 1 ? 'work' : 'works'}${a.fee != null ? ' · ${associateRupees(a.fee!)}' : ''}',
          selected: _query.associateId == a.id,
          onTap: () => _setQuery(_query.refiltered(associateId: _query.associateId == a.id ? '' : a.id)),
        ),
    ]);
  }

  Widget _toolbar(CrmTheme crm, bool fees) => Wrap(spacing: 10, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
        SizedBox(
          width: 280,
          child: TextField(
            key: const Key('assocSearch'),
            controller: _searchCtrl,
            onChanged: _onSearch,
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded, size: 18), hintText: 'Search client, booking no., associate…', isDense: true, border: OutlineInputBorder()),
          ),
        ),
        if (fees) ...[
          _PayoutChip(key: const Key('assocChip_all'), label: 'All', selected: _query.payout.isEmpty, onTap: () => _setQuery(_query.refiltered(payout: ''))),
          for (final p in kPayoutStates) _PayoutChip(key: Key('assocChip_${p.$1}'), label: p.$2, selected: _query.payout == p.$1, onTap: () => _setQuery(_query.refiltered(payout: _query.payout == p.$1 ? '' : p.$1))),
        ],
      ]);

  Widget _empty(CrmTheme crm, AssociateWorksPage page) {
    final filtered = _query.associateId.isNotEmpty || _query.payout.isNotEmpty || _query.search.trim().isNotEmpty;
    final text = page.registered == 0
        ? 'No associates yet. Add one while you assign a work’s team: Manage booking → Artist assignment → ASSOC. → “Add a new associate”.'
        : filtered
            ? 'No work matches these filters.'
            : 'No associate has a work in this period.';
    return Container(
      key: const Key('assocEmpty'),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: crm.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: crm.border)),
      child: Row(children: [
        Icon(Icons.how_to_reg_outlined, color: crm.textSecondary),
        12.w,
        Expanded(child: Text(text, style: TextStyle(fontSize: 13, color: crm.textSecondary, height: 1.4))),
      ]),
    );
  }
}

/// "N bookings still have names in the old Temporary staff box" — shown to those who may convert them, only while some are waiting.
/// It never gets in the way: while loading, on an error, or when nothing is pending it draws nothing.
class _TempStaffBanner extends ConsumerWidget {
  const _TempStaffBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(effectiveAccessProvider).canConvertTempStaff) return const SizedBox.shrink();
    final pending = ref.watch(tempStaffProvider).value?.pendingBookings ?? 0;
    if (pending == 0) return const SizedBox.shrink();
    final crm = context.crmColors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        key: const Key('tsBanner'),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: crm.accent.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: crm.accent.withValues(alpha: 0.3))),
        child: Wrap(spacing: 12, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Icon(Icons.history_edu_outlined, size: 20, color: crm.accent),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Text(
              '$pending ${pending == 1 ? 'booking has' : 'bookings have'} names typed in the old “Temporary staff” box. Convert them to associates so those works appear in this report.',
              key: const Key('tsBannerText'),
              style: TextStyle(fontSize: 12.5, height: 1.35, color: crm.textPrimary),
            ),
          ),
          FilledButton.tonal(key: const Key('tsOpen'), onPressed: () => context.push('/associate-works/temp-staff'), child: const Text('Review & convert')),
        ]),
      ),
    );
  }
}

class _AssociateChip extends StatelessWidget {
  const _AssociateChip({super.key, required this.label, required this.sub, required this.selected, required this.onTap});
  final String label, sub;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 220),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? crm.primary.withValues(alpha: 0.12) : crm.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? crm.primary : crm.border, width: selected ? 1.5 : 1),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: crm.textPrimary)),
          Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: crm.textSecondary)),
        ]),
      ),
    );
  }
}

class _PayoutChip extends StatelessWidget {
  const _PayoutChip({super.key, required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ChoiceChip(label: Text(label), selected: selected, onSelected: (_) => onTap());
}

/// One associate on one work.
class _WorkCard extends StatelessWidget {
  const _WorkCard({required this.work, required this.fees});
  final AssociateWork work;
  final bool fees;

  Color _stateColor(CrmTheme crm) => switch (work.payout) { 'paid' => crm.success, 'owed' => crm.warning, _ => crm.textSecondary };

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final day = DateTime.tryParse(work.firstDay);
    final services = work.services.join(' + ');
    final money = fees ? _money(crm) : null;
    return Container(
      key: Key('assocRow_${work.bookingId}_${work.associateId}'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: crm.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: crm.border)),
      child: LayoutBuilder(builder: (context, box) {
        final wide = box.maxWidth >= 640;
        final body = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Flexible(child: Text(work.customerName.isEmpty ? 'Work' : work.customerName, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: crm.textPrimary))),
            if (work.bookingNumber.isNotEmpty) ...[6.w, Text('#${work.bookingNumber}', style: TextStyle(fontSize: 11.5, color: crm.textSecondary))],
          ]),
          3.h,
          Text([if (services.isNotEmpty) services, if (work.place.isNotEmpty) work.place].join(' · '), maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: crm.textSecondary)),
          6.h,
          Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
            Text(work.associateName, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: crm.primary)),
            _Tag(work.isLead ? 'LEAD' : (work.role.isEmpty ? 'ASSOCIATE' : work.role.toUpperCase()), work.isLead ? Colors.amber.shade800 : Colors.teal),
            if (work.status.isNotEmpty) _Tag(work.status.toUpperCase(), crm.textSecondary),
          ]),
        ]);
        final date = SizedBox(
          width: 56,
          child: Column(children: [
            Text(day == null ? '—' : DateFormat('d MMM').format(day), key: const Key('assocDay'), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: crm.textPrimary)),
            Text(day == null ? '' : DateFormat('EEE').format(day), style: TextStyle(fontSize: 11, color: crm.textSecondary)),
            if (work.days > 1) Text('${work.days} days', key: const Key('assocDays'), style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: crm.accent)),
          ]),
        );
        if (wide) {
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [date, 8.w, Expanded(child: body), if (money != null) ...[12.w, SizedBox(width: 190, child: money)]]);
        }
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [date, 8.w, Expanded(child: body)]),
          if (money != null) ...[8.h, money],
        ]);
      }),
    );
  }

  Widget _money(CrmTheme crm) {
    final c = _stateColor(crm);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _Tag(payoutLabel(work.payout).toUpperCase(), c, key: const Key('assocState')),
      if ((work.fee ?? 0) > 0) ...[
        4.h,
        Text(associateRupees(work.fee!), key: const Key('assocFee'), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: crm.textPrimary)),
        Text('${associateRupees(work.paid ?? 0)} paid${(work.owed ?? 0) > 0 ? ' · ${associateRupees(work.owed!)} to pay' : ''}', style: TextStyle(fontSize: 11, color: crm.textSecondary)),
      ] else ...[
        4.h,
        Text('Accounts has not recorded a fee for this work.', style: TextStyle(fontSize: 11, color: crm.textSecondary)),
      ],
    ]);
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.text, this.color, {super.key});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4)),
        child: Text(text, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: color, letterSpacing: 0.4)),
      );
}
