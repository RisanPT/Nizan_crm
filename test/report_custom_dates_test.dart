import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/theme/app_theme.dart';
import 'package:nizan_crm/core/utils/report_range.dart';
import 'package:nizan_crm/core/widgets/report_range_dialog.dart';
import 'package:nizan_crm/features/reports/data/financial_analyst_report.dart';
import 'package:nizan_crm/features/reports/services/financial_report_service.dart';
import 'package:nizan_crm/features/sales/services/goal_service.dart';
import 'package:nizan_crm/presentation/common_widgets/export_report_dialog.dart';
import 'package:nizan_crm/services/report_service.dart';

// Custom dates for every report download: how the requests carry the days, what a form shows of them, and what the reports say about them.

final _nov = ReportRange(
  from: DateTime(2026, 11, 1),
  to: DateTime(2026, 11, 17),
);

/// A Dio that answers every request with [data] and remembers what was asked.
class _Asked {
  _Asked(this.data);
  final Object data;
  RequestOptions? last;

  Dio get dio {
    final d = Dio();
    d.interceptors.add(
      InterceptorsWrapper(
        onRequest: (o, h) {
          last = o;
          h.resolve(Response(requestOptions: o, data: data, statusCode: 200));
        },
      ),
    );
    return d;
  }
}

Map<String, dynamic> _analystJson({bool custom = false}) => {
  'month': '2026-11',
  'period': {
    'from': '2026-11-01',
    'to': '2026-11-17',
    'days': 17,
    'label': '1 Nov – 17 Nov 2026',
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
};

Map<String, dynamic> _goalJson(String granularity) => {
  'granularity': granularity,
  'basis': 'added',
  'period': {'start': '2026-11-01', 'end': '2026-11-17', 'days': 17},
  'metrics': <dynamic>[],
  'days': <dynamic>[],
  'canEdit': false,
};

void main() {
  group('the financial year a label names', () {
    test('April to March, from "FY 2026-27", "2026-27" or the long form', () {
      for (final label in [
        'FY 2026-27',
        '2026-27',
        'FY 2026 - 27',
        'FY 2026-2027',
      ]) {
        final r = financialYearLabelRange(label)!;
        expect(
          (r.fromIso, r.toIso),
          ('2026-04-01', '2027-03-31'),
          reason: label,
        );
      }
    });

    test('names the right year, and no year at all gives nothing', () {
      expect(
        financialYearLabelRange('FY 2026-27')!.label,
        '1 Apr 2026 – 31 Mar 2027',
      );
      expect(financialYearLabelRange('FY 2025-26')!.fromIso, '2025-04-01');
      expect(financialYearLabelRange('FY'), isNull);
      expect(financialYearLabelRange('All'), isNull);
      expect(financialYearLabelRange(''), isNull);
    });
  });

  group('the finance report address', () {
    Uri uri({ReportRange? range, String? employeeId, String format = 'csv'}) =>
        ReportService.financeReportUri(
          baseUrl: 'https://api.test/api',
          token: 'tkn',
          range: range ?? _nov,
          employeeId: employeeId,
          format: format,
        );

    test(
      'carries the days as from and to, both ends in — not a month and year',
      () {
        final u = uri();
        expect(u.path, '/api/reports/finance');
        expect(u.queryParameters['from'], '2026-11-01');
        expect(u.queryParameters['to'], '2026-11-17');
        expect(u.queryParameters['format'], 'csv');
        expect(u.queryParameters.containsKey('month'), isFalse);
        expect(u.queryParameters.containsKey('year'), isFalse);
      },
    );

    test(
      'one day is a range of one; the last day of a month and year is kept as it is',
      () {
        final one = uri(
          range: ReportRange(
            from: DateTime(2026, 12, 31),
            to: DateTime(2026, 12, 31),
          ),
        );
        expect(
          (one.queryParameters['from'], one.queryParameters['to']),
          ('2026-12-31', '2026-12-31'),
        );
      },
    );

    test('an artist is narrowed to; "all" is not sent', () {
      expect(uri(employeeId: 'e7').queryParameters['employeeId'], 'e7');
      expect(
        uri(employeeId: 'all').queryParameters.containsKey('employeeId'),
        isFalse,
      );
      expect(uri().queryParameters.containsKey('employeeId'), isFalse);
      expect(uri(format: 'pdf').queryParameters['format'], 'pdf');
      expect(uri(format: 'xlsx').queryParameters['format'], 'xlsx', reason: 'the Excel file');
    });

    test(
      'a range with an open end cannot be asked for: the server builds the file from every entry in it',
      () {
        expect(
          () => uri(range: ReportRange.all()),
          throwsA(isA<AppException>()),
        );
        expect(
          () => uri(range: ReportRange(from: DateTime(2026, 11, 1))),
          throwsA(isA<AppException>()),
        );
      },
    );
  });

  group('the Financial Analyst report over days', () {
    test(
      'a month is asked for as it always was; two days as from and to',
      () async {
        final a = _Asked(_analystJson());
        final svc = FinancialReportService(a.dio);
        await svc.getAnalystReport('2026-11');
        expect(a.last!.queryParameters, {'month': '2026-11'});
        await svc.getAnalystReport(analystKeyFor(_nov));
        expect(a.last!.queryParameters, {
          'from': '2026-11-01',
          'to': '2026-11-17',
        });
        await svc.getAnalystReport('');
        expect(
          a.last!.queryParameters,
          isEmpty,
          reason: 'this month, the server\'s default',
        );
        expect(analystKeyFor(_nov), '2026-11-01..2026-11-17');
      },
    );

    test(
      'the report knows whether it is a month or any days, and names itself and its file for it',
      () {
        final month = FinancialAnalystReport.fromJson(_analystJson());
        expect(
          (
            month.customPeriod,
            month.periodText,
            month.reportTitle,
            month.fileTag,
          ),
          (false, '2026-11', 'Monthly Financial-Analyst Report', '2026-11'),
        );
        final days = FinancialAnalystReport.fromJson(
          _analystJson(custom: true),
        );
        expect(days.customPeriod, isTrue);
        expect(days.periodText, '1 Nov – 17 Nov 2026');
        expect(days.reportTitle, 'Financial-Analyst Report');
        expect(days.fileTag, '2026-11-01_to_2026-11-17');
      },
    );

    test('an older server that sends no period is still a monthly report', () {
      final j = _analystJson()..remove('period');
      final r = FinancialAnalystReport.fromJson(j);
      expect(
        (r.customPeriod, r.periodText, r.fileTag),
        (false, '2026-11', '2026-11'),
      );
    });
  });

  group('the sales goals report over days', () {
    test(
      'a day / week / month is asked for as before; days as from and to, month to date as of the last day',
      () async {
        final a = _Asked(_goalJson('month'));
        final svc = GoalService(a.dio);
        await svc.getReport((
          granularity: 'month',
          date: '2026-11-10',
          basis: 'event',
        ));
        expect(a.last!.queryParameters, {
          'granularity': 'month',
          'date': '2026-11-10',
          'basis': 'event',
        });

        final r = _Asked(_goalJson('range'));
        final rs = GoalService(r.dio);
        final q = goalRangeQuery(_nov, 'added');
        expect((q.granularity, q.date), ('range', '2026-11-01..2026-11-17'));
        final rep = await rs.getReport(q);
        expect(r.last!.queryParameters, {
          'from': '2026-11-01',
          'to': '2026-11-17',
          'basis': 'added',
        });
        expect(rep.granularity, 'range');
        expect((rep.start, rep.end), ('2026-11-01', '2026-11-17'));
      },
    );

    test('month to date, for days, is as of the last of them', () async {
      final a = _Asked({
        'basis': 'added',
        'month': '2026-11',
        'asOf': '2026-11-17',
        'dayOfMonth': 17,
        'daysInMonth': 30,
        'method': '',
        'metrics': <dynamic>[],
      });
      final svc = GoalService(a.dio);
      await svc.getMtd(goalRangeQuery(_nov, 'event'));
      expect(a.last!.queryParameters, {'date': '2026-11-17', 'basis': 'event'});
      await svc.getMtd((
        granularity: 'day',
        date: '2026-11-03',
        basis: 'added',
      ));
      expect(a.last!.queryParameters, {'date': '2026-11-03', 'basis': 'added'});
    });
  });

  group('the dates tile in a download form', () {
    Future<List<ReportRange>> show(
      WidgetTester t, {
      ReportRange? range,
      bool enabled = true,
    }) async {
      final changes = <ReportRange>[];
      await t.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, set) => ReportRangeTile(
                range: changes.isEmpty ? (range ?? _nov) : changes.last,
                enabled: enabled,
                onChanged: (r) => set(() => changes.add(r)),
              ),
            ),
          ),
        ),
      );
      return changes;
    }

    testWidgets('shows the days and how many, and a tap lets them be changed', (
      t,
    ) async {
      final changes = await show(t);
      expect(
        t.widget<Text>(find.byKey(const Key('report_range_tile_label'))).data,
        '1 Nov – 17 Nov 2026',
      );
      expect(find.text('17 days'), findsOneWidget);
      await t.tap(find.byKey(const Key('report_range_tile')));
      await t.pumpAndSettle();
      expect(find.text('Use these dates'), findsOneWidget);
      await t.tap(find.byKey(const Key('report_range_chip_last7')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('report_range_confirm')));
      await t.pumpAndSettle();
      expect(changes, hasLength(1));
      expect(changes.single.days, 7);
      expect(
        t.widget<Text>(find.byKey(const Key('report_range_tile_label'))).data,
        changes.single.label,
      );
    });

    testWidgets(
      'backing out changes nothing; a form that is busy cannot change them',
      (t) async {
        final changes = await show(t);
        await t.tap(find.byKey(const Key('report_range_tile')));
        await t.pumpAndSettle();
        await t.tap(find.byKey(const Key('report_range_cancel')));
        await t.pumpAndSettle();
        expect(changes, isEmpty);

        final busy = await show(t, enabled: false);
        await t.tap(
          find.byKey(const Key('report_range_tile')),
          warnIfMissed: false,
        );
        await t.pumpAndSettle();
        expect(find.byKey(const Key('report_range_dialog')), findsNothing);
        expect(busy, isEmpty);
      },
    );

    testWidgets('a limit given to the tile reaches the dialog it opens', (
      t,
    ) async {
      await t.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: ReportRangeTile(range: _nov, maxDays: 10, onChanged: (_) {}),
          ),
        ),
      );
      await t.tap(find.byKey(const Key('report_range_tile')));
      await t.pumpAndSettle();
      // November 1–17 is 17 days against 10: said so, and cannot be used
      expect(find.byKey(const Key('report_range_too_long')), findsOneWidget);
      expect(
        t
            .widget<FilledButton>(find.byKey(const Key('report_range_confirm')))
            .onPressed,
        isNull,
      );
      await t.tap(find.byKey(const Key('report_range_chip_last7')));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('report_range_too_long')), findsNothing);
      expect(
        t
            .widget<FilledButton>(find.byKey(const Key('report_range_confirm')))
            .onPressed,
        isNotNull,
      );
    });

    testWidgets(
      'a range handed to the dialog backwards comes back the right way round',
      (t) async {
        ReportRange? got;
        await t.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: Builder(
                builder: (context) => FilledButton(
                  onPressed: () async => got = await showReportRangeDialog(
                    context,
                    initial: ReportRange(
                      from: DateTime(2026, 11, 20),
                      to: DateTime(2026, 11, 5),
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
        await t.tap(find.byKey(const Key('report_range_confirm')));
        await t.pumpAndSettle();
        expect(
          (got!.fromIso, got!.toIso, got!.days),
          ('2026-11-05', '2026-11-20', 16),
        );
      },
    );

    testWidgets('all time is shown without a day count', (t) async {
      await show(t, range: ReportRange.all());
      expect(find.text('All time'), findsOneWidget);
      expect(find.textContaining(' days'), findsNothing);
    });
  });

  group('the shared export dialog', () {
    Future<void> open(
      WidgetTester t, {
      ReportRange? range,
      List<String> items = const ['a', 'b', 'c'],
    }) async {
      await t.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Builder(
              builder: (context) => FilledButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => ExportReportDialog<String>(
                    title: 'Collections',
                    range: range,
                    items: items,
                    getVehicleName: (_) => null,
                    getDriverName: (_) => null,
                    headers: const ['Name'],
                    buildRow: (s) => [s],
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

    testWidgets(
      'says the dates the list was cut to and how many entries are in it',
      (t) async {
        await open(t, range: _nov);
        expect(
          t.widget<Text>(find.byKey(const Key('export_dialog_range'))).data,
          '1 Nov – 17 Nov 2026 · 3 entries',
        );
        expect(find.text('Export Collections'), findsOneWidget);
      },
    );

    testWidgets(
      'one entry is "1 entry"; a dialog given no dates is as it was',
      (t) async {
        await open(t, range: _nov, items: const ['only']);
        expect(
          t.widget<Text>(find.byKey(const Key('export_dialog_range'))).data,
          '1 Nov – 17 Nov 2026 · 1 entry',
        );
      },
    );

    testWidgets('with no dates it shows no date line', (t) async {
      await open(t);
      expect(find.byKey(const Key('export_dialog_range')), findsNothing);
      expect(
        find.text('Select filters (optional) before exporting your report.'),
        findsOneWidget,
      );
    });
  });
}
