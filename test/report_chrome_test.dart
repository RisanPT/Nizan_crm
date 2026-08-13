import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nizan_crm/core/theme/app_theme.dart';
import 'package:nizan_crm/features/finance/presentation/widgets/report_chrome.dart';

void main() {
  group('rangeForPreset (Indian FY)', () {
    final now = DateTime(2026, 8, 13); // mid-August 2026 → FY 2026-27

    test('previous month', () {
      final r = rangeForPreset(DateRangePreset.previousMonth, now);
      expect(r.from, DateTime(2026, 7, 1));
      expect(r.to, DateTime(2026, 7, 31));
    });

    test('this month', () {
      final r = rangeForPreset(DateRangePreset.thisMonth, now);
      expect(r.from, DateTime(2026, 8, 1));
      expect(r.to, DateTime(2026, 8, 31));
    });

    test('this fiscal year runs Apr 1 → today', () {
      final r = rangeForPreset(DateRangePreset.thisFy, now);
      expect(r.from, DateTime(2026, 4, 1));
      expect(r.to, DateTime(2026, 8, 13));
    });

    test('previous fiscal year is Apr 1 → Mar 31', () {
      final r = rangeForPreset(DateRangePreset.previousFy, now);
      expect(r.from, DateTime(2025, 4, 1));
      expect(r.to, DateTime(2026, 3, 31));
    });

    test('this quarter (Jul-Sep for August)', () {
      final r = rangeForPreset(DateRangePreset.thisQuarter, now);
      expect(r.from, DateTime(2026, 7, 1));
      expect(r.to, DateTime(2026, 9, 30));
    });

    test('all time is open-ended', () {
      final r = rangeForPreset(DateRangePreset.allTime, now);
      expect(r.from, isNull);
      expect(r.to, isNull);
    });
  });

  testWidgets('ReportChrome renders header + preset dropdown fires onPreset',
      (tester) async {
    DateRangePreset? picked;
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(extensions: [AppTheme.crmThemeExtension]),
      home: Scaffold(
        body: ReportChrome(
          category: 'Business Overview',
          title: 'Profit and Loss',
          preset: DateRangePreset.allTime,
          onPreset: (p) => picked = p,
          child: const Text('REPORT BODY'),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Profit and Loss'), findsOneWidget);
    expect(find.text('BUSINESS OVERVIEW'), findsOneWidget);
    expect(find.text('Date Range :'), findsOneWidget);
    expect(find.text('REPORT BODY'), findsOneWidget);

    // Open the preset dropdown and choose "This Month".
    await tester.tap(find.text('All Time'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('This Month').last);
    await tester.pumpAndSettle();
    expect(picked, DateRangePreset.thisMonth);
  });
}
