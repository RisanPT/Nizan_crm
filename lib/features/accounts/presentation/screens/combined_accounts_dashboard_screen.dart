import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:nizan_crm/core/auth/workspace.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/extensions/space_extension.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/core/utils/responsive_builder.dart';
import 'package:nizan_crm/features/accounts/data/accounts_dashboard_summary.dart';
import 'package:nizan_crm/features/finance/controllers/accounting_provider.dart';

final _inr = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
final _iso = DateFormat('yyyy-MM-dd');

String _compact(double value) {
  final v = value.abs();
  final sign = value < 0 ? '-' : '';
  if (v >= 10000000) return '$sign₹${(v / 10000000).toStringAsFixed(2)}Cr';
  if (v >= 100000) return '$sign₹${(v / 100000).toStringAsFixed(1)}L';
  if (v >= 1000) return '$sign₹${(v / 1000).toStringAsFixed(1)}k';
  return '$sign₹${v.toStringAsFixed(0)}';
}

enum _Period { thisMonth, lastMonth, thisFy, custom }

/// Accounts → Combined Dashboard. One company-wide view: income vs expense for
/// a period (approved / verified money only, no Operations / Administrative
/// split), outstanding receivables & payables, and what is still awaiting
/// approval. All figures come from GET /accounting/dashboard-summary.
class CombinedAccountsDashboardScreen extends ConsumerStatefulWidget {
  const CombinedAccountsDashboardScreen({super.key});

  @override
  ConsumerState<CombinedAccountsDashboardScreen> createState() =>
      _CombinedAccountsDashboardScreenState();
}

class _CombinedAccountsDashboardScreenState
    extends ConsumerState<CombinedAccountsDashboardScreen> {
  _Period _period = _Period.thisMonth;
  DateTimeRange? _custom;

  DateTimeRange get _range {
    final now = DateTime.now();
    switch (_period) {
      case _Period.thisMonth:
        return DateTimeRange(
          start: DateTime(now.year, now.month, 1),
          end: DateTime(now.year, now.month + 1, 0),
        );
      case _Period.lastMonth:
        return DateTimeRange(
          start: DateTime(now.year, now.month - 1, 1),
          end: DateTime(now.year, now.month, 0),
        );
      case _Period.thisFy:
        // Indian financial year: April → March.
        final startYear = now.month >= 4 ? now.year : now.year - 1;
        return DateTimeRange(start: DateTime(startYear, 4, 1), end: now);
      case _Period.custom:
        return _custom ??
            DateTimeRange(start: DateTime(now.year, now.month, 1), end: now);
    }
  }

  ({String from, String to}) get _key =>
      (from: _iso.format(_range.start), to: _iso.format(_range.end));

  String get _periodLabel {
    final r = _range;
    switch (_period) {
      case _Period.thisMonth:
      case _Period.lastMonth:
        return DateFormat('MMMM yyyy').format(r.start);
      case _Period.thisFy:
        return 'FY ${r.start.year}-${(r.start.year + 1) % 100} (to date)';
      case _Period.custom:
        return '${DateFormat('d MMM yyyy').format(r.start)} – ${DateFormat('d MMM yyyy').format(r.end)}';
    }
  }

  Future<void> _pickCustom() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: _custom ?? _range,
    );
    if (picked == null) return;
    setState(() {
      _custom = picked;
      _period = _Period.custom;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveBuilder.isMobile(context);
    final crm = context.crmColors;
    final key = _key;
    final async = ref.watch(accountsDashboardSummaryProvider(key));

    Widget periodChip(_Period p, String label) => ChoiceChip(
          label: Text(label),
          selected: _period == p,
          onSelected: (_) {
            if (p == _Period.custom) {
              _pickCustom();
            } else {
              setState(() => _period = p);
            }
          },
        );

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(accountsDashboardSummaryProvider(key)),
        child: ListView(
          padding: EdgeInsets.fromLTRB(isMobile ? 16 : 24, 16, isMobile ? 16 : 24, 32),
          children: [
            Text(
              'Combined Accounts Dashboard',
              style: TextStyle(
                fontSize: isMobile ? 22 : 28,
                fontWeight: FontWeight.w800,
                color: crm.textPrimary,
                letterSpacing: -0.5,
              ),
            ),
            4.h,
            Text(
              'Company income, expenses and dues · $_periodLabel',
              style: TextStyle(fontSize: 13, color: crm.textSecondary),
            ),
            16.h,
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                periodChip(_Period.thisMonth, 'This month'),
                periodChip(_Period.lastMonth, 'Last month'),
                periodChip(_Period.thisFy, 'This FY'),
                periodChip(_Period.custom, 'Custom…'),
              ],
            ),
            20.h,
            async.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 80),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => AppErrorView(
                error: e,
                onRetry: () => ref.invalidate(accountsDashboardSummaryProvider(key)),
              ),
              data: (s) => _DashboardBody(summary: s, isMobile: isMobile),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardBody extends ConsumerWidget {
  final AccountsDashboardSummary summary;
  final bool isMobile;
  const _DashboardBody({required this.summary, required this.isMobile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crm = context.crmColors;
    final s = summary;
    final canOpenAging = ref.watch(effectiveAccessProvider).canSeeSub('company_finance.aging');

    Widget pair(Widget a, Widget b) => isMobile
        ? Column(children: [a, 16.h, b])
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [Expanded(child: a), 16.w, Expanded(child: b)],
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GridView.count(
          crossAxisCount: isMobile ? 2 : 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: isMobile ? 1.55 : 2.6,
          children: [
            _Kpi(_compact(s.income.total), 'Total Income', Icons.arrow_circle_up_outlined, crm.primary),
            _Kpi(_compact(s.expense.total), 'Total Expense', Icons.arrow_circle_down_outlined, crm.destructive),
            _Kpi(
              _compact(s.net),
              'Net Profit / Loss',
              s.net >= 0 ? Icons.trending_up : Icons.trending_down,
              s.net >= 0 ? crm.success : crm.destructive,
            ),
            _Kpi(_compact(s.receivables.totalOutstanding), 'Receivables', Icons.call_received_rounded, crm.warning),
            _Kpi(_compact(s.payables.totalOutstanding), 'Payables', Icons.call_made_rounded, crm.secondary),
            _Kpi(
              _compact(s.cashBankTotal),
              'Cash & Bank now (Bank ${_compact(s.bankTotal)} · Cash ${_compact(s.cashTotal)})',
              Icons.account_balance_outlined,
              crm.primary,
            ),
          ],
        ),
        24.h,
        pair(
          _LinesCard(
            title: 'Income',
            icon: Icons.south_west_rounded,
            color: crm.success,
            group: s.income,
            totalLabel: 'Total Income',
          ),
          _LinesCard(
            title: 'Expenses',
            icon: Icons.north_east_rounded,
            color: crm.destructive,
            group: s.expense,
            totalLabel: 'Total Expense',
          ),
        ),
        16.h,
        pair(
          _OutstandingCard(
            title: 'Receivables',
            subtitle: 'Customers who owe us',
            color: crm.warning,
            data: s.receivables,
            onViewAll: canOpenAging ? () => context.go('/company-finance/aging?kind=receivables') : null,
          ),
          _OutstandingCard(
            title: 'Payables',
            subtitle: 'Vendors we owe',
            color: crm.secondary,
            data: s.payables,
            onViewAll: canOpenAging ? () => context.go('/company-finance/aging?kind=payables') : null,
          ),
        ),
        if (s.pending.total > 0) ...[
          16.h,
          _LinesCard(
            title: 'Awaiting approval',
            subtitle: 'Not counted in income or expense until approved',
            icon: Icons.hourglass_top_rounded,
            color: crm.warning,
            group: s.pending,
            totalLabel: 'Total pending',
            hideZero: true,
          ),
        ],
      ],
    );
  }
}

class _Kpi extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color color;
  const _Kpi(this.value, this.label, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: crm.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: crm.textPrimary),
                ),
              ),
              2.h,
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: crm.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CardShell extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final Color color;
  final Widget? trailing;
  final List<Widget> children;

  const _CardShell({
    required this.title,
    this.subtitle,
    required this.icon,
    required this.color,
    this.trailing,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: crm.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              8.w,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: crm.textPrimary),
                    ),
                    if (subtitle != null)
                      Text(subtitle!, style: TextStyle(fontSize: 12, color: crm.textSecondary)),
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
          16.h,
          ...children,
        ],
      ),
    );
  }
}

class _LinesCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final Color color;
  final SummaryGroup group;
  final String totalLabel;
  final bool hideZero;

  const _LinesCard({
    required this.title,
    this.subtitle,
    required this.icon,
    required this.color,
    required this.group,
    required this.totalLabel,
    this.hideZero = false,
  });

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final lines = hideZero ? group.items.where((l) => l.amount != 0).toList() : group.items;
    return _CardShell(
      title: title,
      subtitle: subtitle,
      icon: icon,
      color: color,
      children: [
        for (final l in lines)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      text: l.label,
                      style: TextStyle(fontSize: 14, color: crm.textSecondary),
                      children: [
                        if (l.estimated)
                          TextSpan(
                            text: '  (est.)',
                            style: TextStyle(fontSize: 11, color: crm.textSecondary),
                          ),
                        if (l.count > 0)
                          TextSpan(
                            text: '  · ${l.count}',
                            style: TextStyle(fontSize: 11, color: crm.textSecondary),
                          ),
                      ],
                    ),
                  ),
                ),
                Text(
                  _inr.format(l.amount),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: l.amount == 0 ? crm.textSecondary : crm.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        Divider(color: crm.border),
        8.h,
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(totalLabel, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: crm.textPrimary)),
            Text(
              _inr.format(group.total),
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
      ],
    );
  }
}

class _OutstandingCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color color;
  final OutstandingSummary data;
  final VoidCallback? onViewAll;

  const _OutstandingCard({
    required this.title,
    required this.subtitle,
    required this.color,
    required this.data,
    this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final d = data;
    final buckets = <(String, double)>[
      ('0–30 days', d.current),
      ('31–60 days', d.days30),
      ('61–90 days', d.days60),
      ('90+ days', d.days90),
    ];
    final maxBucket = buckets.fold<double>(0, (m, b) => b.$2 > m ? b.$2 : m);

    Widget stat(String label, double v, Color c) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 12, color: crm.textSecondary)),
              2.h,
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  _inr.format(v),
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: c),
                ),
              ),
            ],
          ),
        );

    return _CardShell(
      title: title,
      subtitle: subtitle,
      icon: Icons.schedule_rounded,
      color: color,
      trailing: onViewAll == null
          ? null
          : TextButton(onPressed: onViewAll, child: const Text('View all')),
      children: [
        if (d.totalOutstanding <= 0)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text('Nothing outstanding.', style: TextStyle(color: crm.textSecondary)),
          )
        else ...[
          Row(
            children: [
              stat('Outstanding', d.totalOutstanding, crm.textPrimary),
              stat('Overdue', d.totalOverdue, crm.destructive),
              stat('Not yet due', d.totalNotYetDue, crm.textSecondary),
            ],
          ),
          16.h,
          Text('Overdue by', style: TextStyle(fontSize: 12, color: crm.textSecondary)),
          8.h,
          for (final b in buckets)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 84,
                    child: Text(b.$1, style: TextStyle(fontSize: 12, color: crm.textSecondary)),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: maxBucket == 0 ? 0 : b.$2 / maxBucket,
                        minHeight: 8,
                        backgroundColor: crm.border.withValues(alpha: 0.4),
                        valueColor: AlwaysStoppedAnimation(color),
                      ),
                    ),
                  ),
                  8.w,
                  SizedBox(
                    width: 92,
                    child: Text(
                      _inr.format(b.$2),
                      textAlign: TextAlign.right,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: crm.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
          if (d.top.isNotEmpty) ...[
            Divider(color: crm.border),
            8.h,
            Text(
              'Top ${d.top.length} of ${d.partyCount}',
              style: TextStyle(fontSize: 12, color: crm.textSecondary),
            ),
            8.h,
            for (final p in d.top)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        p.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, color: crm.textPrimary),
                      ),
                    ),
                    if (p.overdue > 0)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Text(
                          '${p.oldestDays}d overdue',
                          style: TextStyle(fontSize: 11, color: crm.destructive),
                        ),
                      ),
                    Text(
                      _inr.format(p.outstanding),
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: crm.textPrimary),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ],
    );
  }
}
