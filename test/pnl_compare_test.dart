import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nizan_crm/core/theme/app_theme.dart';
import 'package:nizan_crm/features/finance/data/report_models.dart';
import 'package:nizan_crm/features/finance/controllers/accounting_provider.dart';
import 'package:nizan_crm/features/finance/presentation/screens/profit_loss_screen.dart';

const _current = PnlReport(
  income: [ReportLine(code: '4000', name: 'Sales', amount: 100000)],
  expense: [ReportLine(code: '5000', name: 'Rent', amount: 40000)],
  totalIncome: 100000,
  totalExpense: 40000,
  netProfit: 60000,
);
const _previous = PnlReport(
  income: [ReportLine(code: '4000', name: 'Sales', amount: 80000)],
  expense: [ReportLine(code: '5000', name: 'Rent', amount: 50000)],
  totalIncome: 80000,
  totalExpense: 50000,
  netProfit: 30000,
);

void main() {
  testWidgets('P&L Compare With Previous Year shows a two-column comparison',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 1500);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final nowYear = DateTime.now().year;

    await tester.pumpWidget(ProviderScope(
      overrides: [
        profitLossProvider.overrideWith((ref, key) async {
          if (key.from.isEmpty) return _current; // all-time (initial)
          final y = DateTime.tryParse(key.from)?.year ?? nowYear;
          return y >= nowYear ? _current : _previous; // earlier window → previous
        }),
      ],
      child: MaterialApp(
        theme: ThemeData(extensions: [AppTheme.crmThemeExtension]),
        home: const ProfitLossScreen(),
      ),
    ));
    await tester.pumpAndSettle();

    // Single view initially.
    expect(find.text('Net Profit'), findsOneWidget);
    expect(find.text('CURRENT'), findsNothing);

    // Pick a bounded period (This Month) so comparison is defined.
    await tester.tap(find.text('All Time'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('This Month').last);
    await tester.pumpAndSettle();

    // Turn on Compare With: Previous Year.
    await tester.tap(find.text('None'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Previous Year').last);
    await tester.pumpAndSettle();

    // Two-column comparison renders with the previous figure + a delta.
    expect(find.text('CURRENT'), findsWidgets);
    expect(find.text('PREVIOUS'), findsWidgets);
    expect(find.text('CHANGE'), findsWidgets);
    expect(find.textContaining('was ₹30,000'), findsOneWidget); // previous net profit
    expect(find.text('▲ 100%'), findsOneWidget); // 60k vs 30k
  });
}
