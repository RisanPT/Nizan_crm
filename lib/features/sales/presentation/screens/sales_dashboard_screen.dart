import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/providers/auth_provider.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/core/utils/file_saver.dart';
import 'package:nizan_crm/core/utils/responsive_builder.dart';
import 'package:nizan_crm/features/sales/data/sales_overview.dart';
import 'package:nizan_crm/features/sales/presentation/widgets/sales_overview_widgets.dart';
import 'package:nizan_crm/features/sales/presentation/widgets/sales_eod_dialog.dart';
import 'package:nizan_crm/features/sales/services/sales_overview_service.dart';
import 'package:nizan_crm/features/sales/services/sales_target_service.dart';

/// Period chips at the top of the Sales Dashboard.
enum SalesPeriod { today, week, month, lastMonth, custom }

extension on SalesPeriod {
  String get label => switch (this) {
        SalesPeriod.today => 'Today',
        SalesPeriod.week => 'This week',
        SalesPeriod.month => 'This month',
        SalesPeriod.lastMonth => 'Last month',
        SalesPeriod.custom => 'Custom',
      };
}

String _key(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

/// Inclusive [from, to] for a period, relative to [now].
({DateTime from, DateTime to}) salesPeriodRange(SalesPeriod p, DateTime now, {DateTimeRange? custom}) {
  final today = DateTime(now.year, now.month, now.day);
  switch (p) {
    case SalesPeriod.today:
      return (from: today, to: today);
    case SalesPeriod.week:
      return (from: today.subtract(Duration(days: today.weekday - 1)), to: today);
    case SalesPeriod.month:
      return (from: DateTime(today.year, today.month, 1), to: today);
    case SalesPeriod.lastMonth:
      final first = DateTime(today.year, today.month - 1, 1);
      return (from: first, to: DateTime(today.year, today.month, 0));
    case SalesPeriod.custom:
      final r = custom ?? DateTimeRange(start: today, end: today);
      return (from: r.start, to: r.end);
  }
}

/// Sales Dashboard — redesigned (Nov 2026).
///
/// Top to bottom: one filter bar, an alert strip (only when there is
/// something to act on), the month target bar, four key numbers, then tabs:
/// Overview · Leads and sources · Team · Reports.
///
/// Every figure comes from GET /api/dashboard/sales-overview, the same rules
/// as the Sales EOD, the enquiry check and Sales Targets.
class SalesDashboardScreen extends ConsumerStatefulWidget {
  const SalesDashboardScreen({super.key, this.now});

  /// Fixed "today" for tests.
  final DateTime? now;

  @override
  ConsumerState<SalesDashboardScreen> createState() => _SalesDashboardScreenState();
}

class _SalesDashboardScreenState extends ConsumerState<SalesDashboardScreen> {
  SalesPeriod _period = SalesPeriod.month;
  DateTimeRange? _custom;
  String? _salesPersonId;
  int _tab = 0;

  DateTime get _now => widget.now ?? DateTime.now();

  SalesOverviewQuery get _query {
    final r = salesPeriodRange(_period, _now, custom: _custom);
    return (from: _key(r.from), to: _key(r.to), salesPersonId: _salesPersonId);
  }

  Future<void> _pickCustom() async {
    final now = _now;
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2, 4, 1),
      lastDate: DateTime(now.year, now.month, now.day),
      initialDateRange: _custom ??
          DateTimeRange(start: DateTime(now.year, now.month, 1), end: DateTime(now.year, now.month, now.day)),
    );
    if (picked != null && mounted) {
      setState(() {
        _custom = picked;
        _period = SalesPeriod.custom;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final isMobile = ResponsiveBuilder.isMobile(context);
    final role = (ref.watch(authSessionProvider)?.role ?? '').toLowerCase();
    final viewOnly = role.startsWith('marketing');
    final canEnterCount = role.startsWith('sales') || role == 'admin' || role == 'manager';
    final q = _query;
    final async = ref.watch(salesOverviewProvider(q));
    final data = async.value;

    return RefreshIndicator(
      onRefresh: () => ref.refresh(salesOverviewProvider(q).future),
      child: ListView(
        padding: EdgeInsets.fromLTRB(isMobile ? 14 : 24, 16, isMobile ? 14 : 24, 32),
        children: [
          _header(crm, isMobile, data, viewOnly),
          const SizedBox(height: 12),
          _filters(crm, data),
          const SizedBox(height: 14),
          if (async.hasError && data == null)
            AppErrorView(error: async.error!, onRetry: () => ref.invalidate(salesOverviewProvider(q)))
          else if (data == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 80),
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            if (async.isLoading) const LinearProgressIndicator(minHeight: 2),
            AlertStrip(
              data: data,
              isToday: q.to == _key(_now),
              canEnterCount: canEnterCount,
              onShowSources: () => setState(() => _tab = 1),
            ),
            TargetCard(
              target: data.target,
              canSetTargets: canSetSalesTargets(role),
            ),
            const SizedBox(height: 12),
            KpiGrid(data: data, isMobile: isMobile),
            const SizedBox(height: 16),
            _tabs(crm),
            const SizedBox(height: 12),
            switch (_tab) {
              0 => OverviewTab(data: data, isMobile: isMobile),
              1 => SourcesTab(data: data),
              2 => TeamTab(data: data),
              _ => ReportsTab(data: data, onExport: () => _exportCsv(data)),
            },
          ],
        ],
      ),
    );
  }

  Widget _header(CrmTheme crm, bool isMobile, SalesOverview? d, bool viewOnly) {
    final title = Text('Sales dashboard',
        style: TextStyle(fontSize: isMobile ? 21 : 25, fontWeight: FontWeight.w800, color: crm.textPrimary));
    final range = d == null ? '' : rangeLabel(d.from, d.to);
    final actions = viewOnly
        ? const <Widget>[]
        : [
            OutlinedButton.icon(
              onPressed: () => context.go('/sales/leads'),
              icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
              label: const Text('Leads'),
            ),
            OutlinedButton.icon(
              onPressed: () => showSalesEodDialog(context),
              icon: const Icon(Icons.summarize_outlined, size: 18),
              label: const Text('EOD report'),
            ),
          ];
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      runSpacing: 10,
      spacing: 10,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            title,
            if (range.isNotEmpty)
              Text(range, style: TextStyle(fontSize: 13, color: crm.textSecondary)),
          ],
        ),
        if (actions.isNotEmpty) Wrap(spacing: 8, runSpacing: 8, children: actions),
      ],
    );
  }

  Widget _filters(CrmTheme crm, SalesOverview? d) {
    final people = d?.salespeople ?? const <({String id, String name})>[];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final p in SalesPeriod.values)
          ChoiceChip(
            key: ValueKey('period-${p.name}'),
            label: Text(p == SalesPeriod.custom && _custom != null && _period == SalesPeriod.custom
                ? rangeLabel(_key(_custom!.start), _key(_custom!.end))
                : p.label),
            selected: _period == p,
            avatar: p == SalesPeriod.custom ? const Icon(Icons.date_range, size: 16) : null,
            onSelected: (_) {
              if (p == SalesPeriod.custom) {
                _pickCustom();
              } else {
                setState(() => _period = p);
              }
            },
          ),
        if (people.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              border: Border.all(color: crm.border),
              borderRadius: BorderRadius.circular(10),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                key: const ValueKey('salesperson-filter'),
                value: people.any((p) => p.id == _salesPersonId) ? _salesPersonId : null,
                isDense: true,
                icon: const Icon(Icons.expand_more, size: 18),
                items: [
                  const DropdownMenuItem<String?>(value: null, child: Text('All salespeople')),
                  for (final p in people) DropdownMenuItem<String?>(value: p.id, child: Text(p.name)),
                ],
                onChanged: (v) => setState(() => _salesPersonId = v),
              ),
            ),
          ),
      ],
    );
  }

  Widget _tabs(CrmTheme crm) {
    const labels = ['Overview', 'Leads and sources', 'Team', 'Reports'];
    return Container(
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: crm.border))),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (var i = 0; i < labels.length; i++)
              InkWell(
                key: ValueKey('tab-$i'),
                onTap: () => setState(() => _tab = i),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: _tab == i ? crm.primary : Colors.transparent, width: 2.5),
                    ),
                  ),
                  child: Text(labels[i],
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: _tab == i ? FontWeight.w800 : FontWeight.w500,
                        color: _tab == i ? crm.primary : crm.textSecondary,
                      )),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportCsv(SalesOverview d) async {
    String esc(Object? v) {
      final s = '$v';
      return s.contains(',') || s.contains('"') ? '"${s.replaceAll('"', '""')}"' : s;
    }

    final b = StringBuffer()
      ..writeln('Date,Team count,Leads saved (count days),Leads,Bookings,Order value');
    for (final r in d.trend) {
      b.writeln([r.day, r.enquiries ?? '', r.enquiries == null ? '' : r.saved, r.leads, r.bookings, r.orderValue.round()]
          .map(esc)
          .join(','));
    }
    b.writeln();
    b.writeln('Channel,Team count,Saved,Not saved,Leads,Converted,Conversion %,Bookings,Order value');
    for (final s in d.sources.where((s) => !s.isEmpty)) {
      b.writeln([s.channel, s.enquiries, s.saved, s.notSaved, s.leads, s.converted, s.conversion, s.bookings, s.orderValue.round()]
          .map(esc)
          .join(','));
    }
    b.writeln();
    b.writeln('Salesperson,Leads,Converted,Calls,Follow-ups,Overdue follow-ups,Bookings,Order value');
    for (final p in d.team) {
      b.writeln([p.name, p.leads, p.converted, p.calls, p.followUps, p.overdueFollowUps, p.bookings, p.orderValue.round()]
          .map(esc)
          .join(','));
    }
    try {
      await saveFileBytes('Sales_Dashboard_${d.from}_to_${d.to}.csv', b.toString().codeUnits, mime: 'text/csv');
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    }
  }
}
