import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:nizan_crm/core/models/auth_session.dart';
import 'package:nizan_crm/core/providers/auth_provider.dart';
import 'package:nizan_crm/core/theme/app_theme.dart';
import 'package:nizan_crm/core/utils/report_range.dart';
import 'package:nizan_crm/features/reports/data/financial_analyst_report.dart';
import 'package:nizan_crm/features/reports/presentation/screens/financial_analyst_report_screen.dart';
import 'package:nizan_crm/features/reports/services/financial_report_service.dart';
import 'package:nizan_crm/features/sales/data/goal_report.dart';
import 'package:nizan_crm/features/sales/presentation/screens/sales_goals_report_screen.dart';
import 'package:nizan_crm/features/sales/services/goal_service.dart';
import 'package:nizan_crm/presentation/widgets/export_sales_report_dialog.dart';

// Custom dates on three report screens: the Sales Report & Goals (day / week / month, or any days), the Financial Analyst report (a
// month, or any days) and the sales export dialog ("Choose your own dates").

Finder _k(String key) => find.byKey(Key(key));

GoalReport _goalReport(
  String granularity,
  String start,
  String end,
) => GoalReport(
  granularity: granularity,
  basis: 'added',
  start: start,
  end: end,
  // the four metrics, as the server always sends them (the day table has a cell for each)
  metrics: [
    for (final k in kGoalMetrics)
      GoalMetric(
        key: k,
        label: kGoalMetricLabels[k]!,
        actual: 1,
        target: 2,
        pct: 50,
      ),
  ],
  days: [
    GoalDay(
      day: start,
      values: {for (final k in kGoalMetrics) k: 1},
      targets: {for (final k in kGoalMetrics) k: null},
    ),
  ],
  canEdit: false,
);

const _mtd = MtdReport(
  month: '2026-11',
  asOf: '2026-11-17',
  dayOfMonth: 17,
  daysInMonth: 30,
  method: '',
  metrics: [],
);

AuthSession _session() => const AuthSession(
  token: 't',
  userId: 'u',
  name: 'U',
  email: 'u@x',
  role: 'admin',
);

FinancialAnalystReport _analyst(String key) {
  final days = key.split('..');
  final custom = days.length == 2;
  return FinancialAnalystReport.fromJson({
    'month': custom ? days[0].substring(0, 7) : key,
    'period': {
      'from': custom ? days[0] : '$key-01',
      'to': custom ? days[1] : '$key-30',
      'days': 1,
      'label': custom
          ? ReportRange(
              from: DateTime.parse(days[0]),
              to: DateTime.parse(days[1]),
            ).label
          : 'month',
      'custom': custom,
    },
    'sales': {
      'packageBreakdown': <dynamic>[],
      'totals': <String, dynamic>{},
      'forwardBookings': <String, dynamic>{},
      'leadSource': <String, dynamic>{},
    },
    'customerRelations': <String, dynamic>{},
    'finance': {'receivablesAging': <String, dynamic>{}},
  });
}

void main() {
  group('Sales Report & Goals', () {
    final asked = <GoalQuery>[];

    Future<void> open(WidgetTester t) async {
      asked.clear();
      t.view.physicalSize = const Size(1300, 1600);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(
        ProviderScope(
          retry: (_, _) => null,
          overrides: <Override>[
            authSessionProvider.overrideWithValue(_session()),
            goalReportProvider.overrideWith((ref, q) async {
              asked.add(q);
              final days = q.granularity == 'range'
                  ? q.date.split('..')
                  : [q.date, q.date];
              return _goalReport(q.granularity, days[0], days[1]);
            }),
            mtdReportProvider.overrideWith((ref, q) async => _mtd),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const SalesGoalsReportScreen(),
          ),
        ),
      );
      await t.pumpAndSettle();
    }

    testWidgets(
      'begins on a day, as before, with a Custom dates button beside it',
      (t) async {
        await open(t);
        expect(asked.last.granularity, 'day');
        expect(_k('goals_custom_dates'), findsOneWidget);
        expect(find.text('Custom dates'), findsOneWidget);
        expect(_k('goals_range_clear'), findsNothing);
      },
    );

    testWidgets(
      'choosing days asks the server for them, and the report is headed with them',
      (t) async {
        await open(t);
        await t.tap(_k('goals_custom_dates'));
        await t.pumpAndSettle();
        await t.tap(_k('report_range_chip_last7'));
        await t.pumpAndSettle();
        await t.tap(_k('report_range_confirm'));
        await t.pumpAndSettle();
        final q = asked.last;
        expect(q.granularity, 'range');
        final want = reportRangeFor(ReportPreset.last7, DateTime.now());
        expect(q.date, '${want.fromIso}..${want.toIso}');
        expect(t.widget<Text>(_k('goals_period_text')).data, want.label);
        expect(find.text(want.label), findsWidgets); // on the button too
        expect(_k('goals_range_clear'), findsOneWidget);
      },
    );

    testWidgets(
      '"Back to the day" returns to the day, week or month; moving the period does too',
      (t) async {
        await open(t);
        await t.tap(_k('goals_custom_dates'));
        await t.pumpAndSettle();
        await t.tap(_k('report_range_chip_last30'));
        await t.pumpAndSettle();
        await t.tap(_k('report_range_confirm'));
        await t.pumpAndSettle();
        expect(asked.last.granularity, 'range');
        expect(find.text('Back to the day'), findsOneWidget);
        await t.tap(_k('goals_range_clear'));
        await t.pumpAndSettle();
        expect(asked.last.granularity, 'day');
        expect(_k('goals_range_clear'), findsNothing);

        // choosing days, then a different period type, leaves the days
        await t.tap(_k('goals_custom_dates'));
        await t.pumpAndSettle();
        await t.tap(_k('report_range_confirm'));
        await t.pumpAndSettle();
        expect(asked.last.granularity, 'range');
        await t.tap(find.text('Week'));
        await t.pumpAndSettle();
        expect(asked.last.granularity, 'week');
      },
    );

    testWidgets(
      'a whole financial year is within what the server builds, and all time is not offered',
      (t) async {
        await open(t);
        await t.tap(_k('goals_custom_dates'));
        await t.pumpAndSettle();
        expect(_k('report_range_chip_all'), findsNothing);
        await t.tap(_k('report_range_chip_lastFy'));
        await t.pumpAndSettle();
        expect(_k('report_range_too_long'), findsNothing);
        await t.tap(_k('report_range_confirm'));
        await t.pumpAndSettle();
        expect(asked.last.granularity, 'range');
        final fy = reportRangeFor(ReportPreset.lastFy, DateTime.now());
        expect(asked.last.date, '${fy.fromIso}..${fy.toIso}');
      },
    );
  });

  group('Financial Analyst report', () {
    final asked = <String>[];

    Future<void> open(WidgetTester t) async {
      asked.clear();
      t.view.physicalSize = const Size(1300, 1600);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(
        ProviderScope(
          retry: (_, _) => null,
          overrides: <Override>[
            financialAnalystReportProvider.overrideWith((ref, key) async {
              asked.add(key);
              return _analyst(key);
            }),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const FinancialAnalystReportScreen(),
          ),
        ),
      );
      await t.pumpAndSettle();
    }

    testWidgets('begins on a month; the dates button is there beside it', (
      t,
    ) async {
      await open(t);
      expect(
        RegExp(r'^\d{4}-\d{2}$').hasMatch(asked.last),
        isTrue,
        reason: asked.last,
      );
      expect(_k('analyst_pick_dates'), findsOneWidget);
      expect(_k('analyst_range_label'), findsNothing);
      expect(find.byIcon(Icons.chevron_left), findsOneWidget);
    });

    testWidgets(
      'choosing days asks for them, shows them where the month was, and the month arrows go',
      (t) async {
        await open(t);
        await t.tap(_k('analyst_pick_dates'));
        await t.pumpAndSettle();
        expect(find.text('Report for which dates?'), findsOneWidget);
        await t.tap(_k('report_range_chip_lastMonth'));
        await t.pumpAndSettle();
        await t.tap(_k('report_range_confirm'));
        await t.pumpAndSettle();
        final want = reportRangeFor(ReportPreset.lastMonth, DateTime.now());
        expect(asked.last, '${want.fromIso}..${want.toIso}');
        expect(
          t
              .widget<Text>(
                find.descendant(
                  of: _k('analyst_range_label'),
                  matching: find.byType(Text),
                ),
              )
              .data,
          want.label,
        );
        expect(find.byIcon(Icons.chevron_left), findsNothing);
      },
    );

    testWidgets('the close button goes back to the month', (t) async {
      await open(t);
      await t.tap(_k('analyst_pick_dates'));
      await t.pumpAndSettle();
      await t.tap(_k('report_range_confirm'));
      await t.pumpAndSettle();
      expect(asked.last.contains('..'), isTrue);
      await t.tap(_k('analyst_range_clear'));
      await t.pumpAndSettle();
      expect(RegExp(r'^\d{4}-\d{2}$').hasMatch(asked.last), isTrue);
      expect(_k('analyst_range_label'), findsNothing);
    });
  });

  group('the sales export dialog', () {
    final calls = <(bool, ReportRange, String)>[];

    Future<void> open(WidgetTester t, {bool custom = true}) async {
      calls.clear();
      t.view.physicalSize = const Size(900, 1800);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      void noop(bool _) {}
      await t.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Builder(
              builder: (context) => FilledButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => ExportSalesReportDialog(
                    financialYear: '2026-27',
                    initialUseEventDate: false,
                    onTodayReport: noop,
                    onDailyPerformance: noop,
                    onExecutiveSummary: noop,
                    onFullLedger: noop,
                    onForecastReport: noop,
                    onSixMonthsReport: noop,
                    onOneYearReport: noop,
                    onAprJunReport: noop,
                    onJulSepReport: noop,
                    onOctDecReport: noop,
                    onJanMarReport: noop,
                    onMonthEndCashFlowReport: (a, b, c) {},
                    onCustomRangeReport: custom
                        ? (useEvent, range, type) =>
                              calls.add((useEvent, range, type))
                        : null,
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await t.tap(find.text('open'));
      await t.pumpAndSettle();
    }

    Future<void> scrollTo(WidgetTester t, Finder f) async {
      await t.ensureVisible(f);
      await t.pumpAndSettle();
    }

    testWidgets(
      'offers "Choose your own dates" for the sales report, the executive summary and the ledger',
      (t) async {
        await open(t);
        for (final type in ['sales', 'executive', 'crm']) {
          expect(_k('export_custom_$type'), findsOneWidget, reason: type);
        }
        expect(find.text('Choose your own dates'), findsOneWidget);
      },
    );

    testWidgets(
      'a card asks for the days, then answers with them, the basis and which report',
      (t) async {
        await open(t);
        await scrollTo(t, _k('export_custom_executive'));
        await t.tap(_k('export_custom_executive'));
        await t.pumpAndSettle();
        expect(find.text('Counted by the booking date.'), findsOneWidget);
        await t.tap(_k('report_range_chip_last30'));
        await t.pumpAndSettle();
        await t.tap(_k('report_range_confirm'));
        await t.pumpAndSettle();
        expect(calls, hasLength(1));
        final (useEvent, range, type) = calls.single;
        expect((useEvent, type), (false, 'executive'));
        expect(range.days, 30);
        expect(
          find.text('Export Sales Report'),
          findsNothing,
          reason: 'the export dialog closes',
        );
      },
    );

    testWidgets('the date basis chosen in the dialog goes with it', (t) async {
      await open(t);
      await t.tap(find.text('By Event Date'));
      await t.pumpAndSettle();
      await scrollTo(t, _k('export_custom_crm'));
      await t.tap(_k('export_custom_crm'));
      await t.pumpAndSettle();
      expect(find.text('Counted by the event date.'), findsOneWidget);
      await t.tap(_k('report_range_confirm'));
      await t.pumpAndSettle();
      expect(calls.single.$1, isTrue);
      expect(calls.single.$3, 'crm');
    });

    testWidgets(
      'backing out of the dates leaves the export dialog open and asks for nothing',
      (t) async {
        await open(t);
        await scrollTo(t, _k('export_custom_sales'));
        await t.tap(_k('export_custom_sales'));
        await t.pumpAndSettle();
        await t.tap(_k('report_range_cancel'));
        await t.pumpAndSettle();
        expect(calls, isEmpty);
        expect(find.text('Export Sales Report'), findsOneWidget);
      },
    );

    testWidgets('a screen that does not offer it has no such section', (
      t,
    ) async {
      await open(t, custom: false);
      expect(find.text('Choose your own dates'), findsNothing);
      expect(_k('export_custom_sales'), findsNothing);
    });
  });
}
