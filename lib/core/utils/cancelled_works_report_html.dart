import 'package:nizan_crm/features/bookings/data/booking.dart';

/// Builds the printable "Cancelled Works" report HTML.
///
/// Pure Dart (no platform imports) so it can be unit-tested; the web report
/// service feeds the result into an iframe and calls `print()`.
String buildCancelledWorksReportHtml(
  List<Booking> cancelled, {
  DateTime? generatedAt,
  String periodLabel = 'All time',
}) {
  final rows = StringBuffer();
  var totalValue = 0.0;
  var totalAdvance = 0.0;
  for (var i = 0; i < cancelled.length; i++) {
    final b = cancelled[i];
    totalValue += b.totalPrice;
    totalAdvance += b.advanceAmount;
    final location = [b.district.trim(), b.region.trim()]
        .where((s) => s.isNotEmpty)
        .join(', ');
    rows.write('''
<tr>
  <td class="num">${i + 1}</td>
  <td>${_dash(b.bookingNumber)}</td>
  <td class="name">${_dash(b.customerName)}</td>
  <td>${_dash(b.phone)}</td>
  <td>${_dash(b.service)}</td>
  <td class="center">${_date(b.serviceStart)}</td>
  <td class="right">${_money(b.totalPrice)}</td>
  <td class="right">${_money(b.advanceAmount)}</td>
  <td>${location.isEmpty ? '—' : _esc(location)}</td>
  <td>${_dash(b.internalRemarks)}</td>
</tr>''');
  }

  final total = cancelled.length;
  final stamp = _fmtStamp(generatedAt ?? DateTime.now());

  return '''
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<title>Cancelled Works Report</title>
<style>
  * { box-sizing: border-box; }
  body {
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Arial, sans-serif;
    color: #1f2937; margin: 26px; font-size: 11.5px;
  }
  .head { display: flex; justify-content: space-between; align-items: flex-end;
    border-bottom: 2px solid #601A29; padding-bottom: 12px; }
  .brand { font-size: 20px; font-weight: 800; color: #601A29; letter-spacing: .5px; }
  .subtitle { font-size: 12px; color: #6b7280; margin-top: 2px; }
  .meta { text-align: right; font-size: 11px; color: #6b7280; line-height: 1.6; }
  .meta b { color: #1f2937; }
  .cards { display: flex; gap: 12px; margin: 16px 0 4px; }
  .card { flex: 1; border: 1px solid #e5e7eb; border-radius: 10px; padding: 10px 14px; }
  .card .k { font-size: 10px; text-transform: uppercase; letter-spacing: .3px; color: #6b7280; }
  .card .v { font-size: 17px; font-weight: 800; margin-top: 3px; }
  .card.red .v { color: #b91c1c; }
  table { width: 100%; border-collapse: collapse; margin-top: 14px; }
  thead th {
    background: #601A29; color: #fff; text-align: left; font-size: 10px;
    font-weight: 700; padding: 7px 7px; text-transform: uppercase; letter-spacing: .3px;
  }
  tbody td { padding: 6px 7px; border-bottom: 1px solid #e5e7eb; vertical-align: top; }
  tbody tr:nth-child(even) { background: #faf7f8; }
  td.num { color: #9ca3af; width: 26px; }
  td.name { font-weight: 700; }
  td.center, th.center { text-align: center; }
  td.right, th.right { text-align: right; }
  .footer { margin-top: 16px; font-size: 10px; color: #9ca3af; text-align: center; }
  .empty { margin-top: 40px; text-align: center; color: #9ca3af; font-size: 13px; }
  @media print { body { margin: 12px; } thead { display: table-header-group; } }
</style>
</head>
<body>
  <div class="head">
    <div>
      <div class="brand">TEAM N MAKEOVERS</div>
      <div class="subtitle">Cancelled Works Report · ${_esc(periodLabel)}</div>
    </div>
    <div class="meta">
      Generated <b>$stamp</b><br>
      Cancelled works: <b>$total</b>
    </div>
  </div>

  ${total == 0 ? '<div class="empty">No cancelled works in this period.</div>' : '''
  <div class="cards">
    <div class="card"><div class="k">Cancelled Works</div><div class="v">$total</div></div>
    <div class="card red"><div class="k">Value Lost</div><div class="v">${_money(totalValue)}</div></div>
    <div class="card"><div class="k">Advance Collected</div><div class="v">${_money(totalAdvance)}</div></div>
  </div>
  <table>
    <thead>
      <tr>
        <th class="center">#</th>
        <th>Booking&nbsp;No</th>
        <th>Client</th>
        <th>Phone</th>
        <th>Service</th>
        <th class="center">Event&nbsp;Date</th>
        <th class="right">Amount</th>
        <th class="right">Advance</th>
        <th>Location</th>
        <th>Remarks</th>
      </tr>
    </thead>
    <tbody>
      ${rows.toString()}
    </tbody>
  </table>'''}

  <div class="footer">Team N Makeovers · Confidential sales report</div>
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

String _fmtStamp(DateTime d) {
  final l = d.toLocal();
  final hh = l.hour == 0 ? 12 : (l.hour > 12 ? l.hour - 12 : l.hour);
  final mm = l.minute.toString().padLeft(2, '0');
  final ap = l.hour >= 12 ? 'PM' : 'AM';
  return '${_date(l)}, $hh:$mm $ap';
}
