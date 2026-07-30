import 'package:nizan_crm/core/models/trial.dart';

/// Builds the printable **trial invoice** HTML — the same Team N Makeovers
/// invoice look as a booking, but WITHOUT GST (trials aren't taxed).
///
/// Pure Dart (no platform imports) so it can be unit-tested; the web service
/// feeds the result into an iframe and calls `print()`.
String buildTrialInvoiceHtml(Trial trial, {DateTime? generatedAt}) {
  String label(TrialItem i) {
    final look = i.lookLabel.trim();
    final pkg = i.packageName.trim();
    if (look.isNotEmpty && pkg.isNotEmpty && look != pkg) return '$pkg — $look';
    if (look.isNotEmpty) return look;
    if (pkg.isNotEmpty) return pkg;
    return 'Trial look';
  }

  final items = trial.trialItems;
  final total = items.fold<double>(0, (s, i) => s + i.price);

  final rows = StringBuffer();
  if (items.isEmpty) {
    rows.write('''
<tr><td>${_esc(trial.clientName)} — Makeup Trial</td><td class="right fw600">${_money(total)}</td></tr>''');
  } else {
    for (final i in items) {
      final note = i.notes.trim();
      final sub = note.isEmpty
          ? ''
          : '<div class="sub">${_esc(note)}</div>';
      rows.write('''
<tr><td>${_esc(label(i))}$sub</td><td class="right fw600">${_money(i.price)}</td></tr>''');
    }
  }

  final invNo = trial.trialNumber.trim().isNotEmpty
      ? trial.trialNumber.trim()
      : 'TRIAL-${trial.id}';
  final status = trial.status.toLowerCase() == 'completed' ? 'COMPLETED' : 'SCHEDULED';
  final schedule = [
    _date(trial.trialDate),
    if (trial.startTime.trim().isNotEmpty || trial.endTime.trim().isNotEmpty)
      '${trial.startTime.trim()}${trial.endTime.trim().isNotEmpty ? ' – ${trial.endTime.trim()}' : ''}',
  ].where((s) => s.trim().isNotEmpty).join(' · ');

  return '''
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<title>Trial Invoice · $invNo</title>
<style>
  * { box-sizing: border-box; }
  body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Arial, sans-serif;
    color: #1f2937; margin: 28px; font-size: 12.5px; }
  .brandbar { text-align: center; }
  .logo { width: 58px; height: 58px; border-radius: 50%; background: #601A29; color: #fff;
    display: inline-flex; align-items: center; justify-content: center; font-size: 28px;
    font-weight: 800; }
  .brand { font-size: 22px; font-weight: 800; color: #601A29; letter-spacing: .5px; margin-top: 6px; }
  .doc-type { font-size: 11px; color: #6b7280; letter-spacing: 1.2px; margin-top: 2px; }
  .rule { border: 0; border-top: 2px solid #601A29; margin: 14px 0; }
  .meta { display: flex; justify-content: space-between; margin-bottom: 14px; }
  .meta .k { font-size: 9.5px; color: #9ca3af; text-transform: uppercase; letter-spacing: .4px; }
  .meta .v { font-size: 13px; font-weight: 700; margin-top: 2px; }
  .bill { border: 1px solid #e5e7eb; border-radius: 8px; padding: 12px 14px; margin-bottom: 16px; }
  .bill .h { font-size: 9.5px; color: #9ca3af; text-transform: uppercase; letter-spacing: .4px; margin-bottom: 4px; }
  .bill .name { font-size: 14px; font-weight: 800; }
  .bill .line { font-size: 12px; color: #4b5563; margin-top: 2px; }
  .sec { font-size: 10px; font-weight: 800; color: #601A29; letter-spacing: .6px; margin: 4px 0 6px; }
  table { width: 100%; border-collapse: collapse; }
  thead th { background: #601A29; color: #fff; text-align: left; font-size: 10px; font-weight: 700;
    padding: 8px 10px; text-transform: uppercase; letter-spacing: .3px; }
  th.right, td.right { text-align: right; }
  tbody td { padding: 9px 10px; border-bottom: 1px solid #e5e7eb; }
  td .sub { font-size: 10px; color: #6b7280; margin-top: 3px; }
  .fw600 { font-weight: 700; }
  .summary { margin-top: 14px; display: flex; justify-content: flex-end; }
  .summary table { width: 300px; }
  .summary td { padding: 7px 10px; }
  .summary .label { text-align: right; color: #4b5563; }
  .summary .val { text-align: right; font-weight: 700; }
  .grand td { background: #601A29; color: #fff; font-weight: 800; }
  .terms-title { font-size: 11px; font-weight: 800; margin: 20px 0 6px; color: #601A29; }
  .terms { font-size: 10.5px; color: #4b5563; padding-left: 16px; margin: 0; }
  .terms li { margin-bottom: 3px; }
  .foot { margin-top: 18px; font-size: 10px; color: #9ca3af; text-align: center; }
  @media print { body { margin: 12px; } }
</style>
</head>
<body>
  <div class="brandbar">
    <div class="logo">N</div>
    <div class="brand">TEAM N MAKEOVERS</div>
    <div class="doc-type">TRIAL INVOICE</div>
  </div>
  <hr class="rule">

  <div class="meta">
    <div><div class="k">Invoice No.</div><div class="v">${_esc(invNo)}</div></div>
    <div><div class="k">Trial Date</div><div class="v">${_date(trial.trialDate)}</div></div>
    <div><div class="k">Status</div><div class="v">$status</div></div>
  </div>

  <div class="bill">
    <div class="h">Billed To</div>
    <div class="name">${_dash(trial.clientName)}</div>
    ${trial.phone.trim().isEmpty ? '' : '<div class="line">Phone: ${_esc(trial.phone)}</div>'}
    ${trial.email.trim().isEmpty ? '' : '<div class="line">Email: ${_esc(trial.email)}</div>'}
    ${schedule.isEmpty ? '' : '<div class="line">$schedule</div>'}
  </div>

  <div class="sec">TRIAL LOOKS</div>
  <table>
    <thead><tr><th>Look / Package</th><th class="right">Amount</th></tr></thead>
    <tbody>$rows</tbody>
  </table>

  <div class="summary">
    <table>
      <tr><td class="label">Subtotal</td><td class="val">${_money(total)}</td></tr>
      <tr class="grand"><td class="label" style="color:#fff">Total</td><td class="val" style="color:#fff">${_money(total)}</td></tr>
    </table>
  </div>

  <div class="terms-title">Terms &amp; Conditions</div>
  <ol class="terms">
    <li>This is a trial invoice for makeup trial services and is not a tax invoice.</li>
    <li>Trial charges are non-refundable once the trial has been rendered.</li>
    <li>Any additional looks requested on the day are charged extra as per actuals.</li>
  </ol>

  <div class="foot">Team N Makeovers · Trial invoice</div>
</body>
</html>
''';
}

String _esc(String? v) {
  final s = (v ?? '').trim();
  if (s.isEmpty) return '';
  return s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
}

String _dash(String? v) {
  final s = (v ?? '').trim();
  return s.isEmpty ? '—' : _esc(s);
}

String _money(double v) => '₹${v.toStringAsFixed(0)}';

String _date(DateTime d) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final l = d.toLocal();
  return '${l.day.toString().padLeft(2, '0')} ${months[l.month - 1]} ${l.year}';
}
