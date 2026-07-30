import 'package:nizan_crm/models/customer.dart';

/// Builds the printable HTML for the "all client details" report.
///
/// Pure Dart (no platform imports) so it can be unit-tested; the web print
/// service feeds the result into an iframe and calls `print()`.
String buildClientsReportHtml(List<Customer> clients, {DateTime? generatedAt}) {
  final rows = StringBuffer();
  for (var i = 0; i < clients.length; i++) {
    final c = clients[i];
    rows.write('''
<tr>
  <td class="num">${i + 1}</td>
  <td class="name">${_dash(c.name)}</td>
  <td>${_dash(c.phone)}</td>
  <td>${_cleanEmail(c.email)}</td>
  <td>${_dash(c.address)}</td>
  <td class="center">${_dash(c.pincode)}</td>
  <td>${_dash(c.company)}</td>
  <td class="center">${_formatEventDate(c.eventDate)}</td>
  <td class="center"><span class="status">${_dash(c.status)}</span></td>
</tr>''');
  }

  final total = clients.length;
  final stamp = _fmt(generatedAt ?? DateTime.now());

  return '''
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<title>Clients Directory Report</title>
<style>
  * { box-sizing: border-box; }
  body {
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Arial, sans-serif;
    color: #1f2937; margin: 28px; font-size: 12px;
  }
  .head { display: flex; justify-content: space-between; align-items: flex-end;
    border-bottom: 2px solid #601A29; padding-bottom: 12px; margin-bottom: 4px; }
  .brand { font-size: 20px; font-weight: 800; color: #601A29; letter-spacing: .5px; }
  .subtitle { font-size: 12px; color: #6b7280; margin-top: 2px; }
  .meta { text-align: right; font-size: 11px; color: #6b7280; line-height: 1.6; }
  .meta b { color: #1f2937; }
  table { width: 100%; border-collapse: collapse; margin-top: 16px; }
  thead th {
    background: #601A29; color: #fff; text-align: left; font-size: 10.5px;
    font-weight: 700; padding: 8px 8px; text-transform: uppercase; letter-spacing: .3px;
  }
  tbody td { padding: 7px 8px; border-bottom: 1px solid #e5e7eb; vertical-align: top; }
  tbody tr:nth-child(even) { background: #faf7f8; }
  td.num { color: #9ca3af; width: 30px; }
  td.name { font-weight: 700; }
  td.center, th.center { text-align: center; }
  .status { display: inline-block; padding: 2px 8px; border-radius: 10px;
    background: #f3e9ec; color: #601A29; font-size: 10px; font-weight: 700; }
  .footer { margin-top: 18px; font-size: 10px; color: #9ca3af; text-align: center; }
  .empty { margin-top: 40px; text-align: center; color: #9ca3af; font-size: 13px; }
  @media print { body { margin: 12px; } thead { display: table-header-group; } }
</style>
</head>
<body>
  <div class="head">
    <div>
      <div class="brand">TEAM N MAKEOVERS</div>
      <div class="subtitle">Clients Directory — Full Report</div>
    </div>
    <div class="meta">
      Generated <b>$stamp</b><br>
      Total clients: <b>$total</b>
    </div>
  </div>

  ${total == 0 ? '<div class="empty">No clients to report.</div>' : '''
  <table>
    <thead>
      <tr>
        <th class="center">#</th>
        <th>Name</th>
        <th>Phone</th>
        <th>Email</th>
        <th>Address</th>
        <th class="center">Pincode</th>
        <th>Company</th>
        <th class="center">Event Date</th>
        <th class="center">Status</th>
      </tr>
    </thead>
    <tbody>
      ${rows.toString()}
    </tbody>
  </table>'''}

  <div class="footer">Team N Makeovers · Confidential client report</div>
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

String _formatEventDate(String? dateString) {
  final s = (dateString ?? '').trim();
  if (s.isEmpty) return '—';
  
  try {
    final d = DateTime.parse(s);
    const months = [
      'january', 'february', 'march', 'april', 'may', 'june',
      'july', 'august', 'september', 'october', 'november', 'december',
    ];
    final day = d.day.toString().padLeft(2, '0');
    final month = months[d.month - 1];
    return '$day $month ${d.year}';
  } catch (_) {
    return _esc(s);
  }
}

String _cleanEmail(String email) {
  final s = email.trim();
  if (s.isEmpty || s.contains('@placeholder')) return '—';
  return _esc(s);
}

String _fmt(DateTime d) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final hh = d.hour == 0 ? 12 : (d.hour > 12 ? d.hour - 12 : d.hour);
  final mm = d.minute.toString().padLeft(2, '0');
  final ap = d.hour >= 12 ? 'PM' : 'AM';
  return '${d.day} ${months[d.month - 1]} ${d.year}, $hh:$mm $ap';
}
