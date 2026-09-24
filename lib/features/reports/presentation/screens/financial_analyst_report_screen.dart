import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/core/widgets/date_pickers.dart';
import 'package:nizan_crm/features/reports/data/financial_analyst_report.dart';
import 'package:nizan_crm/features/reports/services/financial_report_service.dart';
import 'package:nizan_crm/core/utils/financial_report_service.dart' as export_svc;
import 'package:nizan_crm/core/error/errors.dart';

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
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December'
];

/// Upper bound for how far ahead the report can be navigated. Matches the
/// default `maxYear` of [showMonthPicker] so the forward arrow and the picker
/// agree on the same range.
const _kMaxReportYear = 2035;

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

  // Bookings are taken in advance, so a future month already carries real
  // booked revenue (total / advance / balance) worth reporting on. The report
  // is therefore no longer capped at the current month; the forward arrow is
  // bounded by the month picker's own upper year so it cannot run away.
  bool get _canGoForward => _month.isBefore(DateTime(_kMaxReportYear, 12, 1));

  Future<void> _pickMonth() async {
    final picked = await showMonthPicker(context, initial: _month);
    if (picked == null) return;
    setState(() => _month = DateTime(picked.year, picked.month, 1));
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final async = ref.watch(financialAnalystReportProvider(_monthKey));

    return Scaffold(
      backgroundColor: crm.background,
      body: Column(
        children: [
          // ── Month navigator + export ─────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: BoxDecoration(
              color: crm.surface,
              border: Border(bottom: BorderSide(color: crm.border)),
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => _shift(-1),
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: InkWell(
                    onTap: _pickMonth,
                    borderRadius: BorderRadius.circular(8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('${_months[_month.month - 1]} ${_month.year}',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                        Icon(Icons.arrow_drop_down, color: crm.textSecondary),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _canGoForward ? () => _shift(1) : null,
                  icon: const Icon(Icons.chevron_right),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: crm.primary),
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
                  child: Text(friendlyErrorMessage(e),
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

class _Kpi {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _Kpi(this.label, this.value, this.icon, this.color);
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
        _section(Icons.receipt_long_outlined, 'Sales', [
          _kpiGrid([
            _Kpi('Total bookings', '${r.totalBookings}', Icons.event_note_outlined, Colors.indigo),
            _Kpi('Revenue', _money(r.totalRevenue), Icons.payments_outlined, const Color(0xFF2E8B57)),
            _Kpi('Advance', _money(r.totalAdvance), Icons.savings_outlined, Colors.teal),
            _Kpi('Balance', _money(r.totalBalance), Icons.account_balance_wallet_outlined, Colors.orange.shade700),
            _Kpi('Discounts', _money(r.totalDiscounts), Icons.percent, Colors.purple),
            _Kpi('Cancellations', '${r.totalCancellations}', Icons.cancel_outlined, Colors.red.shade600),
            _Kpi('Enquiries', '${r.enquiries}', Icons.contact_phone_outlined, Colors.blue.shade600),
            _Kpi('Next-month bookings', '${r.forwardCount} · ${_money(r.forwardValue)}', Icons.trending_up, crm.primary),
          ]),
          16.gap,
          _subTitle('Package-wise'),
          _table(
            ['Package', 'Bookings', 'Revenue', 'Advance', 'Balance', 'Cancel'],
            [
              for (final p in r.packageBreakdown)
                [p.package, '${p.count}', _money(p.revenue), _money(p.advance), _money(p.balance), '${p.cancellations}'],
            ],
          ),
          if (r.leadSource.isNotEmpty) ...[
            16.gap,
            _subTitle('Lead source'),
            _table(
              ['Source', 'Bookings/Leads'],
              [for (final e in r.leadSource.entries) [e.key, '${e.value}']],
            ),
          ],
        ]),
        16.gap,
        _section(Icons.handshake_outlined, 'Customer Relations', [
          _kpiGrid([
            _Kpi('Active clients', '${r.activeClients}', Icons.groups_outlined, Colors.teal),
            _Kpi('New clients', '${r.newClients}', Icons.person_add_alt, const Color(0xFF2E8B57)),
            _Kpi('Repeat clients', '${r.repeatClients}', Icons.repeat, Colors.indigo),
            _Kpi('Referral leads', '${r.referralLeads}', Icons.share_outlined, Colors.blue.shade600),
          ]),
          16.gap,
          _subTitle('District-wise'),
          _table(
            ['District', 'Bookings', 'Revenue'],
            [for (final d in r.districtBreakdown) [d.district, '${d.count}', _money(d.revenue)]],
          ),
          if (r.cancellations.isNotEmpty) ...[
            16.gap,
            _subTitle('Cancellations (reason)'),
            _table(
              ['Customer', 'Package', 'Reason'],
              [for (final c in r.cancellations) [c.customer, c.package, c.reason]],
            ),
          ],
        ]),
        16.gap,
        _section(Icons.account_balance_outlined, 'Finance (from CRM)', [
          _kpiGrid([
            _Kpi('Cash collected', _money(r.cashCollected), Icons.account_balance_outlined, const Color(0xFF2E8B57)),
            _Kpi('Receivables 0–30d', _money(r.aging0to30), Icons.schedule_outlined, Colors.amber.shade700),
            _Kpi('Receivables 31–90d', _money(r.aging31to90), Icons.history_toggle_off, Colors.orange.shade700),
            _Kpi('Receivables 90d+', _money(r.aging90plus), Icons.warning_amber_outlined, Colors.red.shade600),
          ]),
          10.gap,
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: crm.background,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: crm.border),
            ),
            child: Row(children: [
              Icon(Icons.info_outline, size: 15, color: crm.textSecondary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Cash = verified collections this month. GST, bank balances, loans and '
                  'expense exports come from the accounting system (Zoho), not the CRM.',
                  style: TextStyle(fontSize: 11, color: crm.textSecondary),
                ),
              ),
            ]),
          ),
        ]),
      ],
    );
  }

  Widget _section(IconData icon, String title, List<Widget> children) => Container(
        margin: const EdgeInsets.only(bottom: 2),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: crm.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: crm.border),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 12, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: crm.primary.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, size: 18, color: crm.primary),
              ),
              const SizedBox(width: 10),
              Text(title, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: crm.primary)),
            ]),
            16.gap,
            ...children,
          ],
        ),
      );

  Widget _subTitle(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(t.toUpperCase(),
            style: TextStyle(
                fontSize: 10.5, fontWeight: FontWeight.bold, letterSpacing: 1, color: crm.textSecondary)),
      );

  Widget _kpiGrid(List<_Kpi> items) => LayoutBuilder(builder: (ctx, c) {
        final perRow = c.maxWidth >= 1000 ? 4 : (c.maxWidth >= 640 ? 3 : 2);
        const gap = 12.0;
        final w = (c.maxWidth - gap * (perRow - 1)) / perRow;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [for (final k in items) SizedBox(width: w, child: _kpiCard(k))],
        );
      });

  Widget _kpiCard(_Kpi k) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: crm.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: crm.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(color: k.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
              child: Icon(k.icon, size: 16, color: k.color),
            ),
            10.gap,
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(k.value,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: crm.textPrimary, letterSpacing: -0.3)),
            ),
            3.gap,
            Text(k.label, style: TextStyle(fontSize: 11, color: crm.textSecondary, fontWeight: FontWeight.w600)),
          ],
        ),
      );

  bool _numericCol(List<List<String>> rows, int col) {
    if (rows.isEmpty) return false;
    final re = RegExp(r'^[₹]?[\d,]+(\.\d+)?$');
    return rows.every((r) {
      final c = r[col].trim();
      return c.isEmpty || re.hasMatch(c);
    });
  }

  Widget _table(List<String> headers, List<List<String>> rows) {
    final rightCols = {
      for (var i = 0; i < headers.length; i++)
        if (i != 0 && _numericCol(rows, i)) i
    };
    int flexOf(int i) => i == 0 ? 3 : 2;
    Widget cell(String text, int i, {required bool header}) => Expanded(
          flex: flexOf(i),
          child: Text(
            text,
            textAlign: rightCols.contains(i) ? TextAlign.right : TextAlign.left,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: header
                ? TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: crm.primary, letterSpacing: 0.3)
                : TextStyle(fontSize: 12.5, color: crm.textPrimary),
          ),
        );

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: crm.border),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        Container(
          color: crm.primary.withValues(alpha: 0.07),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(children: [for (var i = 0; i < headers.length; i++) cell(headers[i], i, header: true)]),
        ),
        if (rows.isEmpty)
          Padding(
            padding: const EdgeInsets.all(18),
            child: Text('No data for this month.', style: TextStyle(color: crm.textSecondary, fontSize: 12.5)),
          )
        else
          for (var ri = 0; ri < rows.length; ri++)
            Container(
              color: ri.isOdd ? crm.background.withValues(alpha: 0.4) : Colors.transparent,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              child: Row(children: [for (var i = 0; i < headers.length; i++) cell(rows[ri][i], i, header: false)]),
            ),
      ]),
    );
  }
}

extension _Gap on int {
  Widget get gap => SizedBox(height: toDouble());
}
