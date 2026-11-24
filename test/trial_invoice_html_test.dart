import 'package:flutter_test/flutter_test.dart';
import 'package:nizan_crm/core/models/trial.dart';
import 'package:nizan_crm/core/utils/trial_invoice_html.dart';

void main() {
  Trial t({List<TrialItem> items = const []}) => Trial(
        trialNumber: 'TR-1001',
        clientName: 'Asha',
        phone: '9000000000',
        email: 'asha@mail.com',
        trialDate: DateTime(2026, 7, 24),
        status: 'completed',
        trialItems: items,
      );

  test('renders the trial, totals looks, and shows NO GST', () {
    final html = buildTrialInvoiceHtml(t(items: const [
      TrialItem(lookLabel: 'Bridal Look', price: 4000),
      TrialItem(packageName: 'Airbrush', price: 3000),
    ]));

    expect(html, contains('TRIAL INVOICE'));
    expect(html, contains('TEAM N MAKEOVERS'));
    expect(html, contains('TR-1001'));
    expect(html, contains('Asha'));
    expect(html, contains('Bridal Look'));
    expect(html, contains('₹7000')); // 4000 + 3000

    // No GST anywhere.
    expect(html.contains('GST'), isFalse);
    expect(html.contains('CGST'), isFalse);
    expect(html.contains('SGST'), isFalse);
    expect(html.contains('HSN'), isFalse);
  });

  test('handles a trial with no looks (single line from total)', () {
    final html = buildTrialInvoiceHtml(t());
    expect(html, contains('Makeup Trial'));
    expect(html, contains('₹0'));
  });

  test('escapes client-entered text', () {
    final html = buildTrialInvoiceHtml(Trial(
      clientName: '<script>alert(1)</script>',
      phone: '1',
      trialDate: DateTime(2026, 7, 24),
      trialItems: const [TrialItem(lookLabel: '<b>x</b>', price: 1)],
    ));
    expect(html.contains('<script>alert(1)</script>'), isFalse);
    expect(html, contains('&lt;script&gt;'));
    expect(html.contains('<b>x</b>'), isFalse);
  });
}
