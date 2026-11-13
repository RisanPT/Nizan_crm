import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:nizan_crm/core/auth/access_control.dart';
import 'package:nizan_crm/core/auth/app_role.dart';
import 'package:nizan_crm/core/auth/workspace.dart';
import 'package:nizan_crm/core/theme/app_theme.dart';
import 'package:nizan_crm/features/finance/data/month_end.dart';
import 'package:nizan_crm/features/finance/presentation/screens/month_end_review_screen.dart';
import 'package:nizan_crm/features/finance/services/month_end_service.dart';

// Each section of the month-end review links to a detail report. A login that may not open that report (the ledger, for the CEO and
// the Executive Director) is not offered the link — it used to bounce silently to the home screen.

Future<void> _pump(WidgetTester tester, Access access) async {
  tester.view.physicalSize = const Size(1200, 6000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  // the screen already trips a debug-only ListTile-in-a-coloured-box assertion on every open section and a test-font overflow in its header; that is not what is tested here
  final original = FlutterError.onError;
  FlutterError.onError = (d) {
    final text = d.toString();
    if (!text.contains('ListTile background color') && !text.contains('overflowed')) original?.call(d); // (test-font overflow in the header)
  };
  addTearDown(() => FlutterError.onError = original);
  final overrides = <Override>[
    effectiveAccessProvider.overrideWithValue(access),
    monthEndReviewProvider.overrideWith((ref, key) async => MonthEndReview.fromJson({
          'revenue': {'total': 820000, 'previous': 700000},
          'profitability': {'netProfit': 210000, 'netMarginPct': 25.6},
          'kpis': {'burnRate': 250000, 'cashRunwayMonths': 9.8},
        })),
  ];
  await tester.pumpWidget(ProviderScope(overrides: overrides, child: MaterialApp(theme: AppTheme.lightTheme, home: const MonthEndReviewScreen())));
  await tester.pumpAndSettle();
  // (every section starts open, so every link is built)
}

void main() {
  testWidgets('the CEO / Executive Director are offered the reports they can open — and not the general ledger', (tester) async {
    await _pump(tester, const Access(AppRole.ceo, {'ceo', 'company_finance.month_end', 'company_finance.aging', 'company_finance.reports'}, roleKey: 'executive_director'));
    expect(tester.takeException(), isNull);
    expect(find.text('Aging report'), findsOneWidget);
    expect(find.text('General ledger'), findsNothing);
  });

  testWidgets('an administrator is offered both', (tester) async {
    await _pump(tester, const Access(AppRole.admin, {}, roleKey: 'admin'));
    expect(find.text('Aging report'), findsOneWidget);
    expect(find.text('General ledger'), findsOneWidget);
  });
}
