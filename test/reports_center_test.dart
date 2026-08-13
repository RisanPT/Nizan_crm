import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nizan_crm/core/theme/app_theme.dart';
import 'package:nizan_crm/features/finance/presentation/screens/reports_center_screen.dart';

Widget _harness() => ProviderScope(
      child: MaterialApp(
        theme: ThemeData(extensions: [AppTheme.crmThemeExtension]),
        home: const ReportsCenterScreen(),
      ),
    );

void main() {
  testWidgets('Reports Center: lists, filters by category, favorites, search',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1200, 1100);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    // Catalog renders (wide rail layout).
    expect(find.text('Profit and Loss'), findsOneWidget);
    expect(find.text('Bank Reconciliation'), findsOneWidget);
    expect(find.text('All Reports'), findsWidgets);

    // Category filter: Taxes → only the GST report. (Rail item is first in the
    // tree; the word also appears as a row's category column.)
    await tester.tap(find.text('Taxes').first);
    await tester.pumpAndSettle();
    expect(find.text('GST Summary & GSTR-1'), findsOneWidget);
    expect(find.text('Profit and Loss'), findsNothing);

    // Favorites is empty to begin with.
    await tester.tap(find.text('Favorites').first);
    await tester.pumpAndSettle();
    expect(find.text('No favorites yet'), findsOneWidget);

    // Back to All, star the first report, then it shows under Favorites.
    await tester.tap(find.text('All Reports').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Add to favorites').first);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Favorites').first);
    await tester.pumpAndSettle();
    expect(find.text('No favorites yet'), findsNothing);
    expect(find.text('Profit and Loss'), findsOneWidget); // first catalog entry

    // Search narrows the list.
    await tester.tap(find.text('All Reports').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'depreciation');
    await tester.pumpAndSettle();
    expect(find.text('Depreciation'), findsOneWidget);
    expect(find.text('Profit and Loss'), findsNothing);
  });
}
