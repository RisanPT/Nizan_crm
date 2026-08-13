import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nizan_crm/core/theme/app_theme.dart';
import 'package:nizan_crm/features/finance/data/sales_report.dart';
import 'package:nizan_crm/features/finance/controllers/sales_report_provider.dart';
import 'package:nizan_crm/features/finance/services/sales_report_service.dart';
import 'package:nizan_crm/features/finance/presentation/screens/sales_report_screen.dart';

void main() {
  testWidgets('Sales report screen renders headers, rows and totals from a spec',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    const report = SalesReport(
      rows: [
        SalesRow(label: 'ASWATHY', sublabel: '9895', count: 4, amount: 209000, received: 9000, outstanding: 200000),
        SalesRow(label: 'MINNU', sublabel: '9876', count: 2, amount: 50000, received: 50000),
      ],
      totalCount: 6,
      totalAmount: 259000,
      totalReceived: 59000,
    );

    await tester.pumpWidget(ProviderScope(
      overrides: [
        salesReportProvider.overrideWith((ref, key) async => report),
      ],
      child: MaterialApp(
        theme: ThemeData(extensions: [AppTheme.crmThemeExtension]),
        home: SalesReportScreen(spec: kSalesReportSpecs[kSalesByCustomer]!),
      ),
    ));
    await tester.pumpAndSettle();

    // Title (chrome + centered block), the CUSTOMER column, a data row, and TOTAL.
    expect(find.text('Sales by Customer'), findsWidgets);
    expect(find.text('CUSTOMER'), findsOneWidget);
    expect(find.text('RECEIVED'), findsOneWidget); // customer spec shows received
    expect(find.text('ASWATHY'), findsOneWidget);
    expect(find.text('MINNU'), findsOneWidget);
    expect(find.text('TOTAL'), findsOneWidget);
    expect(find.textContaining('Date Range'), findsOneWidget); // report chrome present
  });

  testWidgets('Payments-by-mode spec hides the Received column', (tester) async {
    tester.view.physicalSize = const Size(1000, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    const report = SalesReport(
      rows: [
        SalesRow(label: 'Cash', count: 21, amount: 545500),
        SalesRow(label: 'UPI', count: 27, amount: 699500),
      ],
      totalCount: 48,
      totalAmount: 1245000,
    );

    await tester.pumpWidget(ProviderScope(
      overrides: [salesReportProvider.overrideWith((ref, key) async => report)],
      child: MaterialApp(
        theme: ThemeData(extensions: [AppTheme.crmThemeExtension]),
        home: SalesReportScreen(spec: kSalesReportSpecs[kPaymentsByMode]!),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('PAYMENT MODE'), findsOneWidget);
    expect(find.text('PAYMENTS'), findsOneWidget);
    expect(find.text('RECEIVED'), findsNothing); // no received column here
    expect(find.text('Cash'), findsOneWidget);
    expect(find.text('UPI'), findsOneWidget);
  });
}
