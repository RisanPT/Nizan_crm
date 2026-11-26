import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nizan_crm/core/theme/app_theme.dart';
import 'package:nizan_crm/core/utils/report_range.dart';
import 'package:nizan_crm/core/widgets/report_range_dialog.dart';

// The dates a report is downloaded for: whole days, both ends inclusive; presets and a custom range give the same thing.

final _now = DateTime(2026, 11, 17, 15, 30); // a Tuesday, mid-afternoon

String _fmt(ReportRange r) => '${r.fromIso}..${r.toIso}';

void main() {
  group('presets', () {
    test(
      'today, yesterday, the last 7 and 30 days (today counts as one of them)',
      () {
        expect(
          _fmt(reportRangeFor(ReportPreset.today, _now)),
          '2026-11-17..2026-11-17',
        );
        expect(
          _fmt(reportRangeFor(ReportPreset.yesterday, _now)),
          '2026-11-16..2026-11-16',
        );
        expect(
          _fmt(reportRangeFor(ReportPreset.last7, _now)),
          '2026-11-11..2026-11-17',
        );
        expect(reportRangeFor(ReportPreset.last7, _now).days, 7);
        expect(
          _fmt(reportRangeFor(ReportPreset.last30, _now)),
          '2026-10-19..2026-11-17',
        );
        expect(reportRangeFor(ReportPreset.last30, _now).days, 30);
      },
    );

    test(
      'this month and last month are whole months, across a year end and a short February',
      () {
        expect(
          _fmt(reportRangeFor(ReportPreset.thisMonth, _now)),
          '2026-11-01..2026-11-30',
        );
        expect(
          _fmt(reportRangeFor(ReportPreset.lastMonth, _now)),
          '2026-10-01..2026-10-31',
        );
        expect(
          _fmt(reportRangeFor(ReportPreset.lastMonth, DateTime(2026, 1, 9))),
          '2025-12-01..2025-12-31',
        );
        expect(
          _fmt(reportRangeFor(ReportPreset.thisMonth, DateTime(2027, 2, 10))),
          '2027-02-01..2027-02-28',
        );
        expect(
          _fmt(reportRangeFor(ReportPreset.thisMonth, DateTime(2028, 2, 10))),
          '2028-02-01..2028-02-29',
        );
      },
    );

    test(
      'the financial year runs April to March: March belongs to the one before',
      () {
        expect(
          _fmt(reportRangeFor(ReportPreset.thisFy, _now)),
          '2026-04-01..2027-03-31',
        );
        expect(
          _fmt(reportRangeFor(ReportPreset.lastFy, _now)),
          '2025-04-01..2026-03-31',
        );
        expect(
          _fmt(reportRangeFor(ReportPreset.thisFy, DateTime(2027, 3, 31))),
          '2026-04-01..2027-03-31',
        );
        expect(
          _fmt(reportRangeFor(ReportPreset.thisFy, DateTime(2027, 4, 1))),
          '2027-04-01..2028-03-31',
        );
        expect(
          _fmt(reportRangeFor(ReportPreset.lastFy, DateTime(2027, 1, 5))),
          '2025-04-01..2026-03-31',
        );
      },
    );

    test('all time has no ends', () {
      final r = reportRangeFor(ReportPreset.all, _now);
      expect((r.isAll, r.from, r.to, r.days), (true, null, null, null));
      expect(r.label, 'All time');
      expect(r.fileTag, 'all');
      expect(r.contains(DateTime(1999)), isTrue);
    });
  });

  group('a range', () {
    test(
      'is whole days: the times of day are dropped, and the last day is IN',
      () {
        final r = ReportRange(
          from: DateTime(2026, 11, 1, 22, 45),
          to: DateTime(2026, 11, 17, 3, 5),
        );
        expect(_fmt(r), '2026-11-01..2026-11-17');
        expect(r.contains(DateTime(2026, 11, 1, 0, 0)), isTrue);
        expect(
          r.contains(DateTime(2026, 11, 17, 23, 59, 59)),
          isTrue,
          reason: 'everything on the last day counts',
        );
        expect(r.contains(DateTime(2026, 10, 31, 23, 59, 59)), isFalse);
        expect(r.contains(DateTime(2026, 11, 18, 0, 0, 1)), isFalse);
      },
    );

    test('an open end does not limit that side', () {
      expect(
        ReportRange(from: DateTime(2026, 11, 10)).contains(DateTime(2030)),
        isTrue,
      );
      expect(
        ReportRange(
          from: DateTime(2026, 11, 10),
        ).contains(DateTime(2026, 11, 9)),
        isFalse,
      );
      expect(
        ReportRange(to: DateTime(2026, 11, 10)).contains(DateTime(2001)),
        isTrue,
      );
      expect(
        ReportRange(
          to: DateTime(2026, 11, 10),
        ).contains(DateTime(2026, 11, 11)),
        isFalse,
      );
    });

    test('picked backwards, it is turned over', () {
      final r = ReportRange(
        from: DateTime(2026, 11, 20),
        to: DateTime(2026, 11, 5),
      ).ordered;
      expect(_fmt(r), '2026-11-05..2026-11-20');
      expect(r.days, 16);
      expect(
        ReportRange(
          from: DateTime(2026, 11, 5),
          to: DateTime(2026, 11, 20),
        ).ordered,
        ReportRange(from: DateTime(2026, 11, 5), to: DateTime(2026, 11, 20)),
      );
    });

    test('counts its days across a month and year end', () {
      expect(
        ReportRange(
          from: DateTime(2026, 12, 30),
          to: DateTime(2027, 1, 2),
        ).days,
        4,
      );
      expect(
        ReportRange(
          from: DateTime(2026, 11, 17),
          to: DateTime(2026, 11, 17),
        ).days,
        1,
      );
    });

    test('exclusive end and end of day, for code that compares timestamps', () {
      final r = ReportRange(
        from: DateTime(2026, 11, 1),
        to: DateTime(2026, 11, 30),
      );
      expect(r.endExclusive, DateTime(2026, 12, 1));
      expect(r.endOfDay, DateTime(2026, 11, 30, 23, 59, 59, 999));
      expect(
        ReportRange(
          from: DateTime(2026, 12, 31),
          to: DateTime(2026, 12, 31),
        ).endExclusive,
        DateTime(2027, 1, 1),
      );
      expect(ReportRange.all().endExclusive, isNull);
    });

    test('is named on screen and in a file name', () {
      expect(
        ReportRange(
          from: DateTime(2026, 11, 1),
          to: DateTime(2026, 11, 17),
        ).label,
        '1 Nov – 17 Nov 2026',
      );
      expect(
        ReportRange(
          from: DateTime(2026, 10, 28),
          to: DateTime(2026, 11, 3),
        ).label,
        '28 Oct – 3 Nov 2026',
      );
      expect(
        ReportRange(
          from: DateTime(2025, 12, 28),
          to: DateTime(2026, 1, 3),
        ).label,
        '28 Dec 2025 – 3 Jan 2026',
      );
      expect(
        ReportRange(
          from: DateTime(2026, 11, 17),
          to: DateTime(2026, 11, 17),
        ).label,
        '17 Nov 2026',
      );
      expect(
        ReportRange(from: DateTime(2026, 11, 17)).label,
        'From 17 Nov 2026',
      );
      expect(
        ReportRange(to: DateTime(2026, 11, 17)).label,
        'Up to 17 Nov 2026',
      );
      expect(
        ReportRange(
          from: DateTime(2026, 11, 1),
          to: DateTime(2026, 11, 17),
        ).fileTag,
        '2026-11-01_to_2026-11-17',
      );
      expect(
        ReportRange(
          from: DateTime(2026, 11, 17),
          to: DateTime(2026, 11, 17),
        ).fileTag,
        '2026-11-17',
      );
      expect(
        ReportRange(from: DateTime(2026, 11, 17)).fileTag,
        'from_2026-11-17',
      );
    });

    test('a whole month, and as a Material range', () {
      expect(_fmt(monthRange(DateTime(2026, 2, 14))), '2026-02-01..2026-02-28');
      final r = ReportRange(
        from: DateTime(2026, 11, 1),
        to: DateTime(2026, 11, 3),
      ).asDateTimeRange!;
      expect((r.start, r.end), (DateTime(2026, 11, 1), DateTime(2026, 11, 3)));
      expect(ReportRange.all().asDateTimeRange, isNull);
    });
  });

  group('cutting a list', () {
    final items = [
      ('a', DateTime(2026, 10, 31, 23, 59)),
      ('b', DateTime(2026, 11, 1)),
      ('c', DateTime(2026, 11, 17, 21, 0)),
      ('d', DateTime(2026, 11, 18)),
      ('undated', null),
    ];

    test(
      'keeps what falls on the days, both ends included; what has no date only when there are no ends',
      () {
        final r = ReportRange(
          from: DateTime(2026, 11, 1),
          to: DateTime(2026, 11, 17),
        );
        expect(
          [for (final i in filterByRange(items, (i) => i.$2, r)) i.$1],
          ['b', 'c'],
        );
        expect(
          [
            for (final i in filterByRange(
              items,
              (i) => i.$2,
              ReportRange.all(),
            ))
              i.$1,
          ],
          ['a', 'b', 'c', 'd', 'undated'],
        );
      },
    );

    test('one day', () {
      final one = ReportRange(
        from: DateTime(2026, 11, 17),
        to: DateTime(2026, 11, 17),
      );
      expect(
        [for (final i in filterByRange(items, (i) => i.$2, one)) i.$1],
        ['c'],
      );
    });
  });

  group('the dialog', () {
    Future<void> open(
      WidgetTester t, {
      ReportRange? initial,
      bool allowAll = false,
      List<ReportPreset>? presets,
      int? maxDays,
    }) async {
      await t.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Builder(
              builder: (context) => FilledButton(
                onPressed: () => showReportRangeDialog(
                  context,
                  initial: initial,
                  allowAll: allowAll,
                  presets: presets,
                  maxDays: maxDays,
                  now: _now,
                  title: 'Download the report',
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

    Finder k(String key) => find.byKey(Key(key));
    String summary(WidgetTester t) =>
        t.widget<Text>(k('report_range_summary')).data!;

    testWidgets('begins on this month and says how many days that is', (
      t,
    ) async {
      await open(t);
      expect(find.text('Download the report'), findsOneWidget);
      expect(summary(t), '1 Nov – 30 Nov 2026');
      expect(t.widget<Text>(k('report_range_days')).data, '30 days');
      expect(
        t.widget<ChoiceChip>(k('report_range_chip_thisMonth')).selected,
        isTrue,
      );
      expect(
        k('report_range_chip_all'),
        findsNothing,
        reason: 'all time only when the report allows it',
      );
    });

    testWidgets('a quick choice changes the dates', (t) async {
      await open(t);
      await t.tap(k('report_range_chip_last7'));
      await t.pumpAndSettle();
      expect(summary(t), '11 Nov – 17 Nov 2026');
      expect(
        t.widget<ChoiceChip>(k('report_range_chip_last7')).selected,
        isTrue,
      );
      expect(
        t.widget<ChoiceChip>(k('report_range_chip_thisMonth')).selected,
        isFalse,
      );
      await t.tap(k('report_range_chip_thisFy'));
      await t.pumpAndSettle();
      expect(summary(t), '1 Apr 2026 – 31 Mar 2027');
    });

    testWidgets('all time is offered when asked for, and has no day count', (
      t,
    ) async {
      await open(t, allowAll: true);
      await t.tap(k('report_range_chip_all'));
      await t.pumpAndSettle();
      expect(summary(t), 'All time');
      expect(k('report_range_days'), findsNothing);
    });

    testWidgets(
      'Custom opens a calendar; the days picked are what comes back, the last day included',
      (t) async {
        await open(t);
        await t.tap(k('report_range_chip_custom'));
        await t.pumpAndSettle();
        expect(find.text('Download from – to'), findsOneWidget);
        await t.tap(find.text('5').first);
        await t.pump();
        await t.tap(find.text('12').first);
        await t.pump();
        await t.tap(find.text('Save'));
        await t.pumpAndSettle();
        expect(summary(t), '5 Nov – 12 Nov 2026');
        expect(t.widget<Text>(k('report_range_days')).data, '8 days');
        expect(find.text('Custom: 5 Nov – 12 Nov 2026'), findsOneWidget);
      },
    );

    testWidgets('backing out of the calendar keeps what was chosen', (t) async {
      await open(t);
      await t.tap(k('report_range_chip_yesterday'));
      await t.pumpAndSettle();
      await t.tap(k('report_range_chip_custom'));
      await t.pumpAndSettle();
      await t.tap(find.text('Cancel').last);
      await t.pumpAndSettle();
      expect(summary(t), '16 Nov 2026');
      expect(
        t.widget<ChoiceChip>(k('report_range_chip_yesterday')).selected,
        isTrue,
      );
    });

    testWidgets(
      'starts from the range it is given: a matching preset is on, any other is Custom',
      (t) async {
        await open(t, initial: reportRangeFor(ReportPreset.lastMonth, _now));
        expect(
          t.widget<ChoiceChip>(k('report_range_chip_lastMonth')).selected,
          isTrue,
        );
        expect(summary(t), '1 Oct – 31 Oct 2026');
      },
    );

    testWidgets(
      'a range of the screen\'s own that is no preset shows as Custom',
      (t) async {
        await open(
          t,
          initial: ReportRange(
            from: DateTime(2026, 9, 3),
            to: DateTime(2026, 9, 9),
          ),
        );
        expect(
          t.widget<ChoiceChip>(k('report_range_chip_custom')).selected,
          isTrue,
        );
        expect(find.text('Custom: 3 Sep – 9 Sep 2026'), findsOneWidget);
      },
    );

    testWidgets(
      'a report with a limit: a longer choice is said so and cannot be downloaded; a shorter one can',
      (t) async {
        await open(t, maxDays: 20, allowAll: true);
        FilledButton confirm() =>
            t.widget<FilledButton>(k('report_range_confirm'));
        expect(summary(t), '1 Nov – 30 Nov 2026');
        expect(
          k('report_range_too_long'),
          findsOneWidget,
          reason: '30 days against 20',
        );
        expect(confirm().onPressed, isNull);
        expect(
          t.widget<Text>(k('report_range_too_long')).data,
          'This report covers at most 20 days at a time — choose fewer.',
        );

        await t.tap(k('report_range_chip_last7'));
        await t.pumpAndSettle();
        expect(k('report_range_too_long'), findsNothing);
        expect(confirm().onPressed, isNotNull);

        await t.tap(k('report_range_chip_all'));
        await t.pumpAndSettle();
        expect(
          k('report_range_too_long'),
          findsOneWidget,
          reason: 'all time has no end: no limit can hold it',
        );
        expect(confirm().onPressed, isNull);
      },
    );

    testWidgets('exactly the limit is fine, one more is not', (t) async {
      await open(t, maxDays: 30);
      expect(summary(t), '1 Nov – 30 Nov 2026');
      expect(
        k('report_range_too_long'),
        findsNothing,
        reason: '30 days against 30',
      );
      await t.tap(k('report_range_chip_thisFy'));
      await t.pumpAndSettle();
      expect(k('report_range_too_long'), findsOneWidget);
    });

    testWidgets('a screen can offer fewer choices', (t) async {
      await open(
        t,
        presets: [
          ReportPreset.thisMonth,
          ReportPreset.lastMonth,
          ReportPreset.custom,
        ],
      );
      expect(k('report_range_chip_thisMonth'), findsOneWidget);
      expect(k('report_range_chip_today'), findsNothing);
      expect(k('report_range_chip_thisFy'), findsNothing);
    });

    testWidgets('Download answers with the days; Cancel answers nothing', (
      t,
    ) async {
      ReportRange? got;
      var asked = 0;
      await t.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Builder(
              builder: (context) => FilledButton(
                onPressed: () async {
                  asked++;
                  got = await showReportRangeDialog(
                    context,
                    now: _now,
                    confirmLabel: 'Get the file',
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await t.tap(find.text('open'));
      await t.pumpAndSettle();
      await t.tap(k('report_range_chip_last30'));
      await t.pumpAndSettle();
      expect(find.text('Get the file'), findsOneWidget);
      await t.tap(k('report_range_confirm'));
      await t.pumpAndSettle();
      expect(_fmt(got!), '2026-10-19..2026-11-17');

      got = ReportRange.all();
      await t.tap(find.text('open'));
      await t.pumpAndSettle();
      await t.tap(k('report_range_cancel'));
      await t.pumpAndSettle();
      expect(got, isNull);
      expect(asked, 2);
    });
  });
}
