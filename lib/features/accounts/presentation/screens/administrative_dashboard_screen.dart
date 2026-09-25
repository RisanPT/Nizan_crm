import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:nizan_crm/core/extensions/space_extension.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/core/utils/responsive_builder.dart';
import 'package:nizan_crm/features/accounts/data/admin_expense.dart';
import 'package:nizan_crm/features/accounts/data/sales_return.dart';
import 'package:nizan_crm/features/accounts/controllers/admin_expense_controller.dart';
import 'package:nizan_crm/features/accounts/controllers/subscription_controller.dart';
import 'package:nizan_crm/features/accounts/controllers/sales_return_provider.dart';
import 'package:nizan_crm/features/accounts/services/salary_service.dart';
import 'package:nizan_crm/core/error/errors.dart';

const _monthNames = [
  '', 'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

String _money(num v) =>
    NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0).format(v);

const _catPalette = [
  Color(0xFF6366F1), Color(0xFF22C55E), Color(0xFFF97316), Color(0xFFEAB308),
  Color(0xFF3B82F6), Color(0xFFEC4899), Color(0xFF14B8A6), Color(0xFF8B5CF6),
  Color(0xFFEF4444), Color(0xFF64748B), Color(0xFF0EA5E9), Color(0xFFA855F7),
];

/// Everything the Administrative dashboard needs for one month.
class _AdminMonthData {
  final double adminExpenses; // total admin expenses this month (incl. HRA)
  final double hra;
  final double pending;
  final double approved;
  final double salaries; // net payroll this month
  final double subscriptionsRunRate;
  final int upcomingRenewals;
  final double salesReturns;
  final Map<String, double> byCategory;
  final Map<String, double> byDepartment;
  final List<AdminExpense> recent;

  const _AdminMonthData({
    required this.adminExpenses,
    required this.hra,
    required this.pending,
    required this.approved,
    required this.salaries,
    required this.subscriptionsRunRate,
    required this.upcomingRenewals,
    required this.salesReturns,
    required this.byCategory,
    required this.byDepartment,
    required this.recent,
  });

  double get totalBurn => adminExpenses + salaries + subscriptionsRunRate;
}

/// Aggregates a month's administrative data. Keyed by 'YYYY-MM'.
final _adminMonthProvider =
    FutureProvider.autoDispose.family<_AdminMonthData, String>((ref, key) async {
  final parts = key.split('-');
  final year = int.parse(parts[0]);
  final month = int.parse(parts[1]);
  final start = DateTime(year, month, 1);
  final end = DateTime(year, month + 1, 0, 23, 59, 59, 999);

  final adminSvc = ref.watch(adminExpenseServiceProvider);
  final salarySvc = ref.watch(salaryServiceProvider);

  final expenses = await adminSvc.getAdminExpenses(startDate: start, endDate: end);
  final salaryRes = await salarySvc.getSalaries(month: month, year: year);
  final subStats = await ref.watch(subscriptionStatsProvider.future);
  final allReturns = await ref.watch(salesReturnsProvider.future);

  double total = 0, hra = 0, pending = 0, approved = 0;
  final byCat = <String, double>{};
  final byDept = <String, double>{};
  for (final e in expenses) {
    total += e.amount;
    if (e.source == 'hra') hra += e.amount;
    if (e.status == 'approved') {
      approved += e.amount;
    } else if (e.status != 'rejected') {
      pending += e.amount;
    }
    byCat[e.categoryLabel] = (byCat[e.categoryLabel] ?? 0) + e.amount;
    final dept = e.department.isEmpty ? 'General' : e.department;
    byDept[dept] = (byDept[dept] ?? 0) + e.amount;
  }

  final recent = [...expenses]..sort((a, b) => b.date.compareTo(a.date));

  bool inMonth(SalesReturn r) =>
      r.date.year == year && r.date.month == month && r.reducesRevenue;
  final salesReturns =
      allReturns.where(inMonth).fold<double>(0, (s, r) => s + r.amount);

  return _AdminMonthData(
    adminExpenses: total,
    hra: hra,
    pending: pending,
    approved: approved,
    salaries: salaryRes.stats.totalNet,
    subscriptionsRunRate: subStats.monthlyRunRate,
    upcomingRenewals: subStats.upcomingRenewalsCount,
    salesReturns: salesReturns,
    byCategory: byCat,
    byDepartment: byDept,
    recent: recent.take(6).toList(),
  );
});

class AdministrativeDashboardScreen extends ConsumerStatefulWidget {
  const AdministrativeDashboardScreen({super.key});

  @override
  ConsumerState<AdministrativeDashboardScreen> createState() =>
      _AdministrativeDashboardScreenState();
}

class _AdministrativeDashboardScreenState
    extends ConsumerState<AdministrativeDashboardScreen> {
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
  }

  String get _key => '${_month.year}-${_month.month}';

  void _shift(int delta) => setState(() => _month = DateTime(_month.year, _month.month + delta));

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final isMobile = ResponsiveBuilder.isMobile(context);
    final async = ref.watch(_adminMonthProvider(_key));

    return Scaffold(
      backgroundColor: crm.background,
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(subscriptionStatsProvider);
          ref.invalidate(salesReturnsProvider);
          ref.invalidate(_adminMonthProvider(_key));
        },
        child: ListView(
          padding: EdgeInsets.fromLTRB(isMobile ? 16 : 24, 16, isMobile ? 16 : 24, 32),
          children: [
            // Header + month selector
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              runSpacing: 12,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Administrative Dashboard',
                        style: TextStyle(fontSize: isMobile ? 22 : 28, fontWeight: FontWeight.w800, color: crm.textPrimary, letterSpacing: -0.5)),
                    4.h,
                    Text('Expenses, payroll, HRA, subscriptions & returns — by month',
                        style: TextStyle(fontSize: 13, color: crm.textSecondary)),
                  ],
                ),
                _MonthBar(month: _month, crm: crm, onPrev: () => _shift(-1), onNext: () => _shift(1)),
              ],
            ),
            20.h,
            async.when(
              loading: () => const Padding(
                padding: EdgeInsets.only(top: 80),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.only(top: 60),
                child: AppErrorView(
                  error: e,
                  onRetry: () {
                    // The month aggregate awaits these shared providers too;
                    // a cached failure there would make Retry fail again.
                    ref.invalidate(subscriptionStatsProvider);
                    ref.invalidate(salesReturnsProvider);
                    ref.invalidate(_adminMonthProvider(_key));
                  },
                ),
              ),
              data: (d) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _KpiGrid(d: d, crm: crm),
                  22.h,
                  _ChartsRow(d: d, crm: crm),
                  22.h,
                  Text('Recent expenses · ${_monthNames[_month.month]} ${_month.year}',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: crm.textPrimary)),
                  12.h,
                  if (d.recent.isEmpty)
                    _emptyBox(crm, 'No administrative expenses this month.')
                  else
                    ...d.recent.map((e) => _RecentRow(e: e, crm: crm)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyBox(CrmTheme crm, String text) => Container(
        padding: const EdgeInsets.all(28),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: crm.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: crm.border.faded(0.6)),
        ),
        child: Text(text, style: TextStyle(color: crm.textSecondary)),
      );
}

class _MonthBar extends StatelessWidget {
  const _MonthBar({required this.month, required this.crm, required this.onPrev, required this.onNext});
  final DateTime month;
  final CrmTheme crm;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: crm.sidebar.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: crm.border.faded(0.5)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        IconButton(icon: Icon(Icons.keyboard_arrow_left_rounded, color: crm.accent), onPressed: onPrev),
        SizedBox(
          width: 128,
          child: Center(
            child: Text('${_monthNames[month.month]} ${month.year}',
                style: TextStyle(fontWeight: FontWeight.w800, color: crm.primary, fontSize: 14)),
          ),
        ),
        IconButton(icon: Icon(Icons.keyboard_arrow_right_rounded, color: crm.accent), onPressed: onNext),
      ]),
    );
  }
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.d, required this.crm});
  final _AdminMonthData d;
  final CrmTheme crm;
  @override
  Widget build(BuildContext context) {
    final tiles = <Widget>[
      _kpi('Admin Expenses', _money(d.adminExpenses), Icons.payments_rounded, crm.primary, sub: 'incl. HRA ${_money(d.hra)}'),
      _kpi('Payroll (Salaries)', _money(d.salaries), Icons.badge_rounded, crm.accent),
      _kpi('HRA', _money(d.hra), Icons.home_work_rounded, const Color(0xFF14B8A6)),
      _kpi('Subscriptions / Mo', _money(d.subscriptionsRunRate), Icons.cloud_sync_rounded, const Color(0xFF6366F1), sub: '${d.upcomingRenewals} renewals soon'),
      _kpi('Total Burn / Mo', _money(d.totalBurn), Icons.account_balance_wallet_rounded, crm.destructive),
      _kpi('Sales Returns', _money(d.salesReturns), Icons.assignment_return_rounded, crm.warning, sub: 'reduces revenue'),
    ];
    return LayoutBuilder(builder: (ctx, c) {
      final perRow = c.maxWidth >= 1000 ? 3 : (c.maxWidth >= 560 ? 3 : 2);
      const gap = 12.0;
      final w = (c.maxWidth - gap * (perRow - 1)) / perRow;
      return Wrap(spacing: gap, runSpacing: gap, children: tiles.map((t) => SizedBox(width: w, child: t)).toList());
    });
  }

  Widget _kpi(String label, String value, IconData icon, Color color, {String? sub}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: crm.border.faded(0.6)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, size: 18, color: color),
          ),
          12.h,
          FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(value, style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: crm.textPrimary, letterSpacing: -0.5))),
          4.h,
          Text(label, style: TextStyle(fontSize: 11.5, color: crm.textSecondary, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
          if (sub != null) ...[
            2.h,
            Text(sub, style: TextStyle(fontSize: 10.5, color: color, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ],
      ),
    );
  }
}

class _ChartsRow extends StatelessWidget {
  const _ChartsRow({required this.d, required this.crm});
  final _AdminMonthData d;
  final CrmTheme crm;
  @override
  Widget build(BuildContext context) {
    final catEntries = d.byCategory.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final deptEntries = d.byDepartment.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final cards = <Widget>[
      _panel(
        'Expenses by Category',
        catEntries.isEmpty
            ? _noData()
            : _CategoryDonut(entries: catEntries, total: d.adminExpenses, crm: crm),
      ),
      _panel(
        'Expenses by Department',
        deptEntries.isEmpty ? _noData() : _DeptBars(entries: deptEntries, crm: crm),
      ),
      _panel('Approval Status', _StatusSplit(pending: d.pending, approved: d.approved, crm: crm)),
    ];

    return LayoutBuilder(builder: (ctx, c) {
      final perRow = c.maxWidth >= 1000 ? 3 : (c.maxWidth >= 640 ? 2 : 1);
      const gap = 16.0;
      final w = (c.maxWidth - gap * (perRow - 1)) / perRow;
      return Wrap(spacing: gap, runSpacing: gap, children: cards.map((card) => SizedBox(width: w, child: card)).toList());
    });
  }

  Widget _noData() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 30),
        child: Center(child: Text('No data', style: TextStyle(color: crm.textSecondary))),
      );

  Widget _panel(String title, Widget child) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: crm.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: crm.border.faded(0.6)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 12, offset: const Offset(0, 5))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: crm.textPrimary)),
          child,
        ]),
      );
}

class _CategoryDonut extends StatelessWidget {
  const _CategoryDonut({required this.entries, required this.total, required this.crm});
  final List<MapEntry<String, double>> entries;
  final double total;
  final CrmTheme crm;
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      14.h,
      SizedBox(
        width: 128,
        height: 128,
        child: Stack(alignment: Alignment.center, children: [
          PieChart(PieChartData(
            sectionsSpace: 2,
            centerSpaceRadius: 40,
            sections: [
              for (var i = 0; i < entries.length; i++)
                PieChartSectionData(value: entries[i].value, color: _catPalette[i % _catPalette.length], radius: 24, showTitle: false),
            ],
          )),
          Column(mainAxisSize: MainAxisSize.min, children: [
            Text(_money(total), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: crm.textPrimary)),
            Text('total', style: TextStyle(fontSize: 10, color: crm.textSecondary)),
          ]),
        ]),
      ),
      14.h,
      ...entries.take(6).toList().asMap().entries.map((it) {
        final e = it.value;
        final pct = total > 0 ? (e.value / total * 100).round() : 0;
        return Padding(
          padding: const EdgeInsets.only(bottom: 7),
          child: Row(children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(color: _catPalette[it.key % _catPalette.length], shape: BoxShape.circle)),
            8.w,
            Expanded(child: Text(e.key, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: crm.textPrimary))),
            Text('${_money(e.value)}  ($pct%)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: crm.textSecondary)),
          ]),
        );
      }),
    ]);
  }
}

class _DeptBars extends StatelessWidget {
  const _DeptBars({required this.entries, required this.crm});
  final List<MapEntry<String, double>> entries;
  final CrmTheme crm;
  @override
  Widget build(BuildContext context) {
    final max = entries.first.value;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      14.h,
      ...entries.take(7).map((e) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(e.key, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: crm.textPrimary, fontWeight: FontWeight.w600))),
                Text(_money(e.value), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: crm.primary)),
              ]),
              6.h,
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: max > 0 ? (e.value / max).clamp(0.0, 1.0) : 0,
                  minHeight: 8,
                  backgroundColor: crm.border.faded(0.5),
                  valueColor: AlwaysStoppedAnimation(crm.primary),
                ),
              ),
            ]),
          )),
    ]);
  }
}

class _StatusSplit extends StatelessWidget {
  const _StatusSplit({required this.pending, required this.approved, required this.crm});
  final double pending;
  final double approved;
  final CrmTheme crm;
  @override
  Widget build(BuildContext context) {
    final total = pending + approved;
    Widget row(String label, double v, Color color) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(label, style: TextStyle(fontSize: 12.5, color: crm.textPrimary, fontWeight: FontWeight.w600))),
              Text(_money(v), style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: color)),
            ]),
            6.h,
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: total > 0 ? (v / total).clamp(0.0, 1.0) : 0,
                minHeight: 8,
                backgroundColor: crm.border.faded(0.5),
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          ]),
        );
    return Column(children: [
      16.h,
      row('Approved', approved, crm.success),
      row('Pending', pending, crm.warning),
      if (total == 0)
        Padding(padding: const EdgeInsets.only(top: 8), child: Text('No expenses to approve.', style: TextStyle(fontSize: 12, color: crm.textSecondary))),
    ]);
  }
}

class _RecentRow extends StatelessWidget {
  const _RecentRow({required this.e, required this.crm});
  final AdminExpense e;
  final CrmTheme crm;
  @override
  Widget build(BuildContext context) {
    final statusColor = e.status == 'approved'
        ? crm.success
        : e.status == 'rejected'
            ? crm.destructive
            : crm.warning;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: crm.border.faded(0.7)),
      ),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              if (e.source == 'hra') ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(color: crm.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                  child: Text('HRA', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: crm.primary)),
                ),
                6.w,
              ],
              Flexible(child: Text(e.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5))),
            ]),
            2.h,
            Text('${e.headLabel} · ${e.department} · ${DateFormat('d MMM').format(e.date)}',
                style: TextStyle(fontSize: 11.5, color: crm.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
          ]),
        ),
        8.w,
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(_money(e.amount), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
          2.h,
          Text(e.status.toUpperCase(), style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: statusColor)),
        ]),
      ]),
    );
  }
}
