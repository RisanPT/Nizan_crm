import 'package:nizan_crm/core/models/spot_invoice.dart';
import 'package:nizan_crm/core/utils/team_logo.dart';

/// Builds the printable spot invoice HTML in the SAME format as the Team N GST
/// invoice template (company header + GSTIN, "Billed To" / "Company Details"
/// cards, itemised services table, summary, terms & conditions) — issued as a
/// no-GST quotation. Pure Dart (no platform imports) so it can be unit-tested.
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

  final customer = data.customerName.trim().isEmpty ? '-' : data.customerName.trim();
  final phoneLine = data.customerPhone.trim().isEmpty
      ? ''
      : '<div class="info-line"><span class="info-key">Phone</span> <span class="info-val">${_esc(data.customerPhone.trim())}</span></div>';
  final noteBlock = data.note.trim().isEmpty
      ? ''
      : '<div class="gst-note" style="background:#fbf7f8;border-color:#e7d2d8;color:#601a29;"><b>Note:</b> ${_esc(data.note.trim())}</div>';

  return '''
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<title>Spot Invoice · ${_esc(data.invoiceNo)}</title>
<style>
  * { box-sizing: border-box; }
  body { margin: 0; background: #fff; }
  .gst-invoice { font-family: Arial, sans-serif; color: #1a1a2e; max-width: 860px; margin: 0 auto; padding: 28px; border: 1px solid #d9dde3; border-radius: 12px; }
  .inv-header { display: flex; flex-direction: column; align-items: center; gap: 16px; margin-bottom: 20px; padding-bottom: 16px; border-bottom: 2px solid #601a29; }
  .inv-logo { width: 76px; height: 76px; object-fit: contain; }
  .inv-company { font-size: 22px; font-weight: 700; color: #601a29; letter-spacing: 0.03em; text-align: center; }
  .inv-doc-type { font-size: 11px; color: #667085; margin-top: 3px; letter-spacing: 0.06em; text-align: center; }
  .inv-meta-grid { display: flex; justify-content: center; gap: 32px; width: 100%; flex-wrap: wrap; }
  .inv-meta-cell { display: flex; flex-direction: column; align-items: center; gap: 3px; }
  .meta-label { font-size: 10px; color: #667085; letter-spacing: 0.08em; text-transform: uppercase; }
  .meta-val { font-size: 14px; font-weight: 600; color: #1a1a2e; }
  .two-col-section { display: grid; grid-template-columns: 1fr 1fr; gap: 16px; margin-bottom: 20px; }
  .info-card { border: 1px solid #d9dde3; border-radius: 10px; padding: 14px 16px; background: #fafbfc; }
  .info-card-title { font-size: 10px; color: #667085; text-transform: uppercase; letter-spacing: 0.08em; margin-bottom: 8px; font-weight: 700; }
  .info-customer { font-size: 16px; font-weight: 700; color: #601a29; margin-bottom: 6px; }
  .info-line { font-size: 13px; color: #44526d; margin-bottom: 4px; }
  .info-key { font-weight: 600; color: #44526d; margin-right: 6px; }
  .info-val { color: #1a1a2e; }
  .section-title { font-size: 11px; font-weight: 700; color: #601a29; letter-spacing: 0.06em; margin-bottom: 8px; }
  .gst-table { width: 100%; border-collapse: collapse; margin-bottom: 20px; }
  .gst-table th { background: #601a29; color: #fff; font-size: 11px; font-weight: 700; padding: 8px 10px; letter-spacing: 0.04em; text-align: left; }
  .gst-table td { font-size: 13px; padding: 8px 10px; border-bottom: 1px solid #e5e9ef; color: #1a1a2e; }
  .gst-table tbody tr:nth-child(even) td { background: #f8f9fb; }
  .right { text-align: right !important; }
  .fw600 { font-weight: 600; }
  .summary-outer { display: flex; justify-content: flex-end; margin-bottom: 24px; }
  .summary-table { border-collapse: collapse; min-width: 320px; }
  .sum-row td { padding: 6px 12px; font-size: 13px; border-bottom: 1px solid #e5e9ef; }
  .sum-label { color: #44526d; font-weight: 500; white-space: nowrap; }
  .sum-val { font-weight: 600; color: #1a1a2e; white-space: nowrap; }
  .grand-row td { background: #601a29; padding: 10px 12px; }
  .grand-label { font-size: 14px; font-weight: 700; color: #fff; }
  .grand-val { font-size: 16px; font-weight: 700; color: #fff; }
  .inv-footer { margin-top: 8px; border-top: 1px solid #d9dde3; padding-top: 14px; }
  .gst-note { font-size: 12px; border-radius: 6px; padding: 6px 12px; margin-bottom: 14px; display: inline-block; }
  .terms-title { font-size: 13px; font-weight: 700; color: #601a29; margin-bottom: 8px; }
  .terms-list { margin: 0; padding-left: 18px; color: #44526d; line-height: 1.7; font-size: 12px; }
  .terms-list li { margin-bottom: 5px; }
  @media print {
    .gst-invoice { border: none; padding: 12px; max-width: 100%; }
    .gst-table th, .grand-row td { -webkit-print-color-adjust: exact; print-color-adjust: exact; }
  }
</style>
</head>
<body>
<div class="gst-invoice">
  <div class="inv-header">
    <img class="inv-logo" src="data:image/png;base64,$teamLogoBase64" alt="Team N logo">

    <div>
      <div class="inv-company">TEAM N ERP</div>
      <div class="inv-doc-type">SPOT INVOICE &middot; QUOTATION (NO GST)</div>
    </div>
    <div class="inv-meta-grid">
      <div class="inv-meta-cell"><span class="meta-label">Invoice No.</span><span class="meta-val">${_esc(data.invoiceNo)}</span></div>
      <div class="inv-meta-cell"><span class="meta-label">Date</span><span class="meta-val">${_date(data.date)}</span></div>
    </div>
  </div>

  <div class="two-col-section">
    <div class="info-card">
      <div class="info-card-title">Billed To</div>
      <div class="info-customer">${_esc(customer)}</div>
      $phoneLine
    </div>
    <div class="info-card">
      <div class="info-card-title">Company Details</div>
      <div class="info-customer">TEAM N ERP</div>
      <div class="info-line"><span class="info-val" style="line-height:1.5;">Kozhikode, Kerala 673014<br>India</span></div>
      <div style="margin-top:8px;"></div>
      <div class="info-line"><span class="info-key" style="min-width:60px;">GSTIN</span> <span class="info-val">32AAJCN6432D1ZR</span></div>
      <div class="info-line"><span class="info-key" style="min-width:60px;">Phone</span> <span class="info-val">9645424283</span></div>
      <div class="info-line"><span class="info-key" style="min-width:60px;">Email</span> <span class="info-val">teamnfinance@gmail.com</span></div>
    </div>
  </div>

  <div class="section-title">SERVICES</div>
  <table class="gst-table">
    <thead><tr><th>Description</th><th class="right">Amount</th></tr></thead>
    <tbody>
      $rows
    </tbody>
  </table>

  <div class="summary-outer">
    <table class="summary-table">
      <tr class="sum-row"><td class="right sum-label">Subtotal</td><td class="right sum-val">${_money(data.total)}</td></tr>
      <tr class="grand-row"><td class="right grand-label">Total</td><td class="right grand-val">${_money(data.total)}</td></tr>
    </table>
  </div>

  <div class="inv-footer">
    $noteBlock
    <div class="terms-title">Terms &amp; Conditions</div>
    <ol class="terms-list">
      <li>This is a quotation for makeup services and is not a tax invoice. Prices are subject to confirmation.</li>
      <li>The booking advance payment is non-refundable and non-transferable under any circumstances.</li>
      <li>Any additional services requested on the event day will be charged extra as per actual costs.</li>
      <li>The remaining balance must be fully paid on or before the event date prior to service completion.</li>
    </ol>
  </div>
</div>
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
