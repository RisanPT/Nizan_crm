import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/reports/data/financial_analyst_report.dart';
import 'package:nizan_crm/features/reports/services/financial_report_service.dart';
import 'package:nizan_crm/core/utils/financial_report_service.dart' as export_svc;

String _money(num v) {
  final s = v.round().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return '₹$b';
}

const _months = [
  'January','February','March','April','May','June',
  'July','August','September','October','November','December'
];

class FinancialAnalystReportScreen extends ConsumerStatefulWidget {
  const FinancialAnalystReportScreen({super.key});

  @override
  ConsumerState<FinancialAnalystReportScreen> createState() =>
      _FinancialAnalystReportScreenState();
}

class _FinancialAnalystReportScreenState
    extends ConsumerState<FinancialAnalystReportScreen> {
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month, 1);
  bool _exporting = false;

  String get _monthKey =>
      '${_month.year}-${_month.month.toString().padLeft(2, '0')}';

  void _shift(int by) =>
      setState(() => _month = DateTime(_month.year, _month.month + by, 1));

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final async = ref.watch(financialAnalystReportProvider(_monthKey));

    return Scaffold(
      backgroundColor: crm.background,
      body: Column(
        children: [
          // Month navigator + export
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            color: crm.surface,
            child: Row(
              children: [
                IconButton(
                  onPressed: () => _shift(-1),
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Text(
                    '${_months[_month.month - 1]} ${_month.year}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                IconButton(
                  onPressed: _month.isBefore(
                          DateTime(DateTime.now().year, DateTime.now().month, 1))
                      ? () => _shift(1)
                      : null,
                  icon: const Icon(Icons.chevron_right),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: (_exporting || !async.hasValue)
                      ? null
                      : () async {
                          setState(() => _exporting = true);
                          try {
                            await export_svc.printFinancialReport(async.value!);
                          } catch (_) {
                          } finally {
                            if (mounted) setState(() => _exporting = false);
                          }
                        },
                  icon: _exporting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.ios_share, size: 18),
                  label: const Text('Export'),
                ),
              ],
            ),
          ),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Could not load report:\n$e',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: crm.textSecondary)),
                ),
              ),
              data: (r) => _ReportBody(report: r, crm: crm),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportBody extends StatelessWidget {
  final FinancialAnalystReport report;
  final CrmTheme crm;
  const _ReportBody({required this.report, required this.crm});

  @override
  Widget build(BuildContext context) {
    final r = report;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      children: [
        _section(crm, '📋 Sales', [
          _kpiWrap([
            _kpi('Total bookings', '${r.totalBookings}'),
            _kpi('Revenue', _money(r.totalRevenue)),
            _kpi('Advance', _money(r.totalAdvance)),
            _kpi('Balance', _money(r.totalBalance)),
            _kpi('Discounts', _money(r.totalDiscounts)),
            _kpi('Cancellations', '${r.totalCancellations}'),
            _kpi('Enquiries', '${r.enquiries}'),
            _kpi('Next-month bookings',
                '${r.forwardCount} · ${_money(r.forwardValue)}'),
          ]),
          12.gap,
          _subTitle('Package-wise'),
          _table(
            ['Package', 'Bookings', 'Revenue', 'Advance', 'Balance', 'Cancel'],
            [
              for (final p in r.packageBreakdown)
                [
                  p.package,
                  '${p.count}',
                  _money(p.revenue),
                  _money(p.advance),
                  _money(p.balance),
                  '${p.cancellations}',
                ],
            ],
          ),
          if (r.leadSource.isNotEmpty) ...[
            12.gap,
            _subTitle('Lead source'),
            _table(
              ['Source', 'Bookings/Leads'],
              [
                for (final e in r.leadSource.entries) [e.key, '${e.value}'],
              ],
            ),
          ],
        ]),
        16.gap,
        _section(crm, '🤝 Customer Relations', [
          _kpiWrap([
            _kpi('Active clients', '${r.activeClients}'),
            _kpi('New clients', '${r.newClients}'),
            _kpi('Repeat clients', '${r.repeatClients}'),
            _kpi('Referral leads', '${r.referralLeads}'),
          ]),
          12.gap,
          _subTitle('District-wise'),
          _table(
            ['District', 'Bookings', 'Revenue'],
            [
              for (final d in r.districtBreakdown)
                [d.district, '${d.count}', _money(d.revenue)],
            ],
          ),
          if (r.cancellations.isNotEmpty) ...[
            12.gap,
            _subTitle('Cancellations (reason)'),
            _table(
              ['Customer', 'Package', 'Reason'],
              [
                for (final c in r.cancellations)
                  [c.customer, c.package, c.reason],
              ],
            ),
          ],
        ]),
        16.gap,
        _section(crm, '💰 Finance (from CRM)', [
          _kpiWrap([
            _kpi('Cash collected', _money(r.cashCollected)),
            _kpi('Receivables 0–30d', _money(r.aging0to30)),
            _kpi('Receivables 31–90d', _money(r.aging31to90)),
            _kpi('Receivables 90d+', _money(r.aging90plus)),
          ]),
          8.gap,
          Text(
            'Cash = verified collections this month. GST, bank balances, loans '
            'and expense exports come from the accounting system (Zoho), not the CRM.',
            style: TextStyle(fontSize: 11, color: crm.textSecondary),
          ),
        ]),
      ],
    );
  }

  Widget _section(CrmTheme crm, String title, List<Widget> children) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: crm.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: crm.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: crm.primary)),
            12.gap,
            ...children,
          ],
        ),
      );

  Widget _subTitle(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(t.toUpperCase(),
            style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
                color: crm.textSecondary)),
      );

  Widget _kpiWrap(List<Widget> items) =>
      Wrap(spacing: 10, runSpacing: 10, children: items);

  Widget _kpi(String label, String value) => Container(
        constraints: const BoxConstraints(minWidth: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: crm.primary.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: crm.primary.withValues(alpha: 0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(value,
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: crm.primary)),
            Text(label,
                style: TextStyle(fontSize: 11, color: crm.textSecondary)),
          ],
        ),
      );

  Widget _table(List<String> headers, List<List<String>> rows) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowHeight: 36,
        dataRowMinHeight: 34,
        dataRowMaxHeight: 44,
        columnSpacing: 22,
        headingTextStyle: TextStyle(
            fontWeight: FontWeight.bold, fontSize: 12, color: crm.textPrimary),
        dataTextStyle: TextStyle(fontSize: 12.5, color: crm.textPrimary),
        columns: [for (final h in headers) DataColumn(label: Text(h))],
        rows: [
          if (rows.isEmpty)
            DataRow(cells: [
              for (var i = 0; i < headers.length; i++)
                DataCell(Text(i == 0 ? '—' : '',
                    style: TextStyle(color: crm.textSecondary))),
            ])
          else
            for (final row in rows)
              DataRow(cells: [for (final c in row) DataCell(Text(c))]),
        ],
      ),
    );
  }
}

extension _Gap on int {
  Widget get gap => SizedBox(height: toDouble());
}
