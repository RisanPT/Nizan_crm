import 'package:nizan_crm/core/models/spot_invoice.dart';

/// Builds the printable **spot quotation/invoice** HTML — the Team N Makeovers
/// invoice look, WITHOUT GST (this is a quotation, not a tax invoice).
///
/// Pure Dart (no platform imports) so it can be unit-tested.
String buildSpotInvoiceHtml(SpotInvoiceData data) {
  final rows = StringBuffer();
  if (data.lines.isEmpty) {
    rows.write(
        '<tr><td>Makeup services</td><td class="right fw600">${_money(data.total)}</td></tr>');
  } else {
    for (final l in data.lines) {
      rows.write(
          '<tr><td>${_esc(l.label)}</td><td class="right fw600">${_money(l.amount)}</td></tr>');
    }
  }

  final noteBlock = data.note.trim().isEmpty
      ? ''
      : '<div class="note"><b>Note:</b> ${_esc(data.note.trim())}</div>';
  final phoneBlock = data.customerPhone.trim().isEmpty
      ? ''
      : '<div>Phone: ${_esc(data.customerPhone.trim())}</div>';

  return '''
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<title>Quotation · ${_esc(data.invoiceNo)}</title>
<style>
  * { box-sizing: border-box; }
  body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Arial, sans-serif;
    color: #1f2937; margin: 28px; font-size: 12.5px; }
  .brandbar { text-align: center; }
  .logo { width: 58px; height: 58px; border-radius: 50%; background: #601A29; color: #fff;
    display: inline-flex; align-items: center; justify-content: center; font-size: 28px; font-weight: 800; }
  .brand { font-size: 22px; font-weight: 800; color: #601A29; letter-spacing: .5px; margin-top: 6px; }
  .sub { color: #9CA3AF; font-size: 10px; }
  .rule { border: none; border-top: 2px solid #601A29; margin: 16px 0; }
  .meta { display: flex; justify-content: space-between; }
  .meta .k { color: #9CA3AF; font-size: 9px; text-transform: uppercase; }
  .meta .v { font-weight: 700; font-size: 12px; }
  .billed { border: 1px solid #E5E7EB; border-radius: 8px; padding: 12px; margin: 14px 0; }
  .billed .k { color: #9CA3AF; font-size: 9px; text-transform: uppercase; }
  .billed .name { font-size: 13px; font-weight: 700; }
  table { width: 100%; border-collapse: collapse; margin-top: 6px; }
  th { background: #601A29; color: #fff; text-align: left; padding: 8px 10px; font-size: 9px; }
  th.right, td.right { text-align: right; }
  td { padding: 8px 10px; border-bottom: .5px solid #E5E7EB; }
  .fw600 { font-weight: 600; }
  .totals { width: 240px; margin-left: auto; margin-top: 14px; }
  .totals .row { display: flex; justify-content: space-between; padding: 4px 0; }
  .totals .grand { background: #601A29; color: #fff; padding: 8px 10px; font-weight: 800; display: flex; justify-content: space-between; }
  .note { margin-top: 16px; font-size: 11px; color: #374151; }
  .terms { margin-top: 18px; font-size: 9px; color: #6B7280; }
  .foot { text-align: center; margin-top: 18px; font-size: 8px; color: #9CA3AF; }
</style>
</head>
<body>
  <div class="brandbar">
    <div class="logo">N</div>
    <div class="brand">TEAM N MAKEOVERS</div>
    <div class="sub">QUOTATION</div>
  </div>
  <hr class="rule">
  <div class="meta">
    <div><div class="k">Quotation No.</div><div class="v">${_esc(data.invoiceNo)}</div></div>
    <div><div class="k">Date</div><div class="v">${_date(data.date)}</div></div>
  </div>
  <div class="billed">
    <div class="k">Billed To</div>
    <div class="name">${_esc(data.customerName.trim().isEmpty ? '-' : data.customerName)}</div>
    $phoneBlock
  </div>
  <table>
    <tr><th>Description</th><th class="right">Amount</th></tr>
    $rows
  </table>
  <div class="totals">
    <div class="row"><span>Subtotal</span><span class="fw600">${_money(data.total)}</span></div>
    <div class="grand"><span>Total</span><span>${_money(data.total)}</span></div>
  </div>
  $noteBlock
  <div class="terms">
    This is a quotation for makeup services and is not a tax invoice. Prices are subject to confirmation.
  </div>
  <div class="foot">Team N Makeovers — Quotation</div>
</body>
</html>''';
}

String _money(double v) => '₹${v.toStringAsFixed(0)}';

String _esc(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;');

String _date(DateTime d) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final l = d.toLocal();
  return '${l.day.toString().padLeft(2, '0')} ${months[l.month - 1]} ${l.year}';
}
