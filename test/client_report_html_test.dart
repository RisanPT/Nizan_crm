import 'package:flutter_test/flutter_test.dart';
import 'package:nizan_crm/core/utils/client_report_html.dart';
import 'package:nizan_crm/models/customer.dart';

void main() {
  final when = DateTime(2026, 7, 28, 16, 5);

  test('lists every client with their details', () {
    final html = buildClientsReportHtml([
      Customer(name: 'Shifa Faizal', email: 'shifa@mail.com', phone: '7356196623', address: 'Kollam', pincode: '691001', status: 'Active'),
      Customer(name: 'Meera', email: 'meera@mail.com', phone: '9000000000'),
    ], generatedAt: when);

    expect(html, contains('Shifa Faizal'));
    expect(html, contains('7356196623'));
    expect(html, contains('Kollam'));
    expect(html, contains('Meera'));
    expect(html, contains('Total clients: <b>2</b>'));
    expect(html, contains('TEAM N MAKEOVERS'));
  });

  test('hides placeholder emails and shows a dash for blanks', () {
    final html = buildClientsReportHtml([
      Customer(name: 'NoEmail', email: 'x@placeholder.local', phone: ''),
    ], generatedAt: when);
    // Placeholder email must not leak into the report.
    expect(html.contains('@placeholder'), isFalse);
    expect(html, contains('—')); // dash for the empty phone
  });

  test('escapes HTML so a malicious name cannot inject markup', () {
    final html = buildClientsReportHtml([
      Customer(name: '<script>alert(1)</script>', email: 'a@b.com'),
    ], generatedAt: when);
    expect(html.contains('<script>alert(1)</script>'), isFalse);
    expect(html, contains('&lt;script&gt;'));
  });

  test('renders an empty-state when there are no clients', () {
    final html = buildClientsReportHtml([], generatedAt: when);
    expect(html, contains('No clients to report.'));
    expect(html, contains('Total clients: <b>0</b>'));
  });
}
