import 'package:nizan_crm/features/reports/data/financial_analyst_report.dart';

String _money(num v) {
  final s = v.round().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return '₹$b';
}

String _esc(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;');

String _table(List<String> headers, List<List<String>> rows) {
  final head = headers.map((h) => '<th>${_esc(h)}</th>').join();
  final body = rows.isEmpty
      ? '<tr><td colspan="${headers.length}" class="muted">No data</td></tr>'
      : rows
          .map((r) =>
              '<tr>${r.asMap().entries.map((e) => '<td class="${e.key == 0 ? '' : 'right'}">${_esc(e.value)}</td>').join()}</tr>')
          .toList()
          .join();
  return '<table><tr>$head</tr>$body</table>';
}

/// Pure HTML for the monthly Financial-Analyst report (brand-styled, printable).
String buildFinancialReportHtml(FinancialAnalystReport r) {
  final pkgRows = [
    for (final p in r.packageBreakdown)
      [
        p.package,
        '${p.count}',
        _money(p.revenue),
        _money(p.advance),
        _money(p.balance),
        '${p.cancellations}',
      ]
  ];
  final leadRows = [
    for (final e in r.leadSource.entries) [e.key, '${e.value}']
  ];
  final distRows = [
    for (final d in r.districtBreakdown)
      [d.district, '${d.count}', _money(d.revenue)]
  ];
  final cancelRows = [
    for (final c in r.cancellations) [c.customer, c.package, c.reason]
  ];

  String kpi(String label, String value) =>
      '<div class="kpi"><div class="v">${_esc(value)}</div><div class="l">${_esc(label)}</div></div>';

  return '''
<!DOCTYPE html>
<html><head><meta charset="utf-8">
<title>Financial Report · ${_esc(r.month)}</title>
<style>
  * { box-sizing: border-box; }
  body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Arial, sans-serif; color:#1f2937; margin:26px; font-size:12px; }
  .brand { text-align:center; }
  .logo { width:50px; height:50px; border-radius:50%; background:#601A29; color:#fff; display:inline-flex; align-items:center; justify-content:center; font-size:24px; font-weight:800; }
  h1 { color:#601A29; font-size:20px; margin:6px 0 0; }
  .sub { color:#9CA3AF; font-size:11px; }
  hr { border:none; border-top:2px solid #601A29; margin:14px 0; }
  h2 { color:#601A29; font-size:14px; margin:18px 0 8px; }
  .kpis { display:flex; flex-wrap:wrap; gap:8px; margin-bottom:8px; }
  .kpi { border:1px solid #E5E7EB; border-radius:8px; padding:8px 12px; min-width:140px; }
  .kpi .v { font-weight:800; font-size:15px; color:#601A29; }
  .kpi .l { font-size:10px; color:#6B7280; }
  table { width:100%; border-collapse:collapse; margin:6px 0 4px; }
  th { background:#601A29; color:#fff; text-align:left; padding:6px 8px; font-size:10px; }
  td { padding:6px 8px; border-bottom:.5px solid #E5E7EB; }
  td.right, th.right { text-align:right; }
  .muted { color:#9CA3AF; }
  .note { font-size:10px; color:#6B7280; margin-top:6px; }
  .foot { text-align:center; font-size:9px; color:#9CA3AF; margin-top:20px; }
</style></head>
<body>
  <div class="brand">
    <div class="logo">N</div>
    <h1>Team N Makeovers</h1>
    <div class="sub">Monthly Financial-Analyst Report · ${_esc(r.month)}</div>
  </div>
  <hr>

  <h2>📋 Sales</h2>
  <div class="kpis">
    ${kpi('Total bookings', '${r.totalBookings}')}
    ${kpi('Revenue', _money(r.totalRevenue))}
    ${kpi('Advance', _money(r.totalAdvance))}
    ${kpi('Balance', _money(r.totalBalance))}
    ${kpi('Discounts', _money(r.totalDiscounts))}
    ${kpi('Cancellations', '${r.totalCancellations}')}
    ${kpi('Enquiries', '${r.enquiries}')}
    ${kpi('Next-month bookings', '${r.forwardCount} · ${_money(r.forwardValue)}')}
  </div>
  ${_table(['Package', 'Bookings', 'Revenue', 'Advance', 'Balance', 'Cancel'], pkgRows)}
  ${leadRows.isEmpty ? '' : '<h2>Lead source</h2>${_table(['Source', 'Count'], leadRows)}'}

  <h2>🤝 Customer Relations</h2>
  <div class="kpis">
    ${kpi('Active clients', '${r.activeClients}')}
    ${kpi('New clients', '${r.newClients}')}
    ${kpi('Repeat clients', '${r.repeatClients}')}
    ${kpi('Referral leads', '${r.referralLeads}')}
    ${kpi('Advance collected', _money(r.totalAdvance))}
    ${kpi('Balance outstanding', _money(r.totalBalance))}
  </div>
  ${_table(['District', 'Bookings', 'Revenue'], distRows)}
  ${cancelRows.isEmpty ? '' : '<h2>Cancellations (reason)</h2>${_table(['Customer', 'Package', 'Reason'], cancelRows)}'}

  <h2>💰 Finance (from CRM)</h2>
  <div class="kpis">
    ${kpi('Cash collected', _money(r.cashCollected))}
    ${kpi('Receivables 0–30d', _money(r.aging0to30))}
    ${kpi('Receivables 31–90d', _money(r.aging31to90))}
    ${kpi('Receivables 90d+', _money(r.aging90plus))}
  </div>
  <div class="note">Cash = verified collections this month. GST, bank balances, loans and full expense exports come from the accounting system (Zoho), not the CRM.</div>

  <div class="foot">Team N Makeovers — Confidential · for internal financial analysis</div>
</body></html>''';
}
