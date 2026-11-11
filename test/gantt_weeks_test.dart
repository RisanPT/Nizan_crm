import 'package:flutter_test/flutter_test.dart';
import 'package:nizan_crm/features/it/domain/gantt_weeks.dart';

// The Timeline's weeks: Monday to Sunday, numbered the ISO way, labelled, and which one opens first.

void main() {
  group('Mondays', () {
    test('every day of a week maps to its Monday, at midnight', () {
      final monday = DateTime(2026, 11, 2);
      for (var i = 0; i < 7; i++) {
        expect(mondayOf(DateTime(2026, 11, 2 + i, 15, 30)), monday, reason: 'day $i');
      }
      expect(mondayOf(DateTime(2026, 11, 9)), DateTime(2026, 11, 9));
    });

    test('across a month and a year', () {
      expect(mondayOf(DateTime(2026, 12, 1)), DateTime(2026, 11, 30));
      expect(mondayOf(DateTime(2027, 1, 1)), DateTime(2026, 12, 28)); // a Friday
    });

    test('stepping whole weeks, either way, over month ends and years', () {
      expect(addWeeks(DateTime(2026, 11, 2), 1), DateTime(2026, 11, 9));
      expect(addWeeks(DateTime(2026, 11, 2), -1), DateTime(2026, 10, 26));
      expect(addWeeks(DateTime(2026, 12, 28), 1), DateTime(2027, 1, 4));
      expect(addWeeks(DateTime(2026, 11, 2), 0), DateTime(2026, 11, 2));
    });

    test('a week step is always a Monday, even over the clock change', () {
      // clocks change on the last Sunday of March and October in many places: a Monday stays a Monday
      var m = DateTime(2026, 3, 16);
      for (var i = 0; i < 12; i++) {
        m = addWeeks(m, 1);
        expect(m.weekday, DateTime.monday);
        expect(m.hour, 0);
      }
    });

    test('days between counts calendar dates, not 24-hour blocks', () {
      expect(daysBetween(DateTime(2026, 11, 2), DateTime(2026, 11, 9)), 7);
      expect(daysBetween(DateTime(2026, 11, 9), DateTime(2026, 11, 2)), -7);
      expect(daysBetween(DateTime(2026, 3, 25), DateTime(2026, 4, 1)), 7);
      expect(daysBetween(DateTime(2026, 11, 2, 23), DateTime(2026, 11, 3, 1)), 1); // by date, whatever the hour
    });
  });

  group('week numbers (ISO-8601)', () {
    test('the ones people check', () {
      expect(isoWeekNumber(DateTime(2026, 11, 2)), 45);
      expect(isoWeekNumber(DateTime(2026, 11, 8)), 45); // the Sunday is still week 45
      expect(isoWeekNumber(DateTime(2026, 11, 9)), 46);
      expect(isoWeekNumber(DateTime(2026, 1, 1)), 1); // 1 Jan 2026 is a Thursday
      expect(isoWeekNumber(DateTime(2026, 12, 31)), 53); // 2026 has 53 weeks
      expect(isoWeekNumber(DateTime(2027, 1, 1)), 53); // a Friday: still 2026's last week
      expect(isoWeekNumber(DateTime(2027, 1, 4)), 1);
    });

    test('a week that holds the 1st of January belongs to the year its Thursday is in', () {
      expect(isoWeekNumber(DateTime(2024, 12, 30)), 1); // Monday: its Thursday is 2 Jan 2025
      expect(isoWeekNumber(DateTime(2021, 1, 3)), 53); // Sunday: its Thursday is 31 Dec 2020
      expect(isoWeekNumber(DateTime(2020, 12, 28)), 53);
    });

    test('numbers climb by one each Monday through a year', () {
      var m = DateTime(2026, 1, 5);
      var prev = isoWeekNumber(m);
      for (var i = 0; i < 50; i++) {
        m = addWeeks(m, 1);
        final n = isoWeekNumber(m);
        expect(n, prev + 1, reason: m.toString());
        prev = n;
      }
    });
  });

  group('labels', () {
    test('a week inside one month', () {
      expect(weekLabel(DateTime(2026, 11, 2)), 'Week 45 · 2 – 8 Nov 2026');
    });

    test('a week over a month end', () {
      expect(weekLabel(DateTime(2026, 11, 30)), 'Week 49 · 30 Nov – 6 Dec 2026');
    });

    test('a week over New Year shows both years', () {
      expect(weekLabel(DateTime(2026, 12, 28)), 'Week 53 · 28 Dec 2026 – 3 Jan 2027');
      expect(weekLabel(DateTime(2024, 12, 30)), 'Week 1 · 30 Dec 2024 – 5 Jan 2025');
    });

    test('given any day of the week, it labels that week from its Monday', () {
      expect(weekLabel(DateTime(2026, 11, 6)), 'Week 45 · 2 – 8 Nov 2026');
    });
  });

  group('which week opens first', () {
    final today = DateTime(2026, 11, 5, 14); // a Thursday

    test('a project running now opens on this week', () {
      expect(initialFocusWeek(today: today, firstStart: DateTime(2026, 11, 1), lastDue: DateTime(2026, 12, 20)), DateTime(2026, 11, 2));
      // on the very first and very last day it is "running"
      expect(initialFocusWeek(today: today, firstStart: DateTime(2026, 11, 5), lastDue: DateTime(2026, 11, 5)), DateTime(2026, 11, 2));
    });

    test('one that has not started opens on its first week; one that is over, on its last', () {
      expect(initialFocusWeek(today: today, firstStart: DateTime(2027, 1, 13), lastDue: DateTime(2027, 3, 1)), DateTime(2027, 1, 11));
      expect(initialFocusWeek(today: today, firstStart: DateTime(2026, 6, 1), lastDue: DateTime(2026, 9, 3)), DateTime(2026, 8, 31));
    });

    test('with no dates (or only one end), this week', () {
      expect(initialFocusWeek(today: today), DateTime(2026, 11, 2));
      expect(initialFocusWeek(today: today, firstStart: DateTime(2026, 10, 1)), DateTime(2026, 11, 2));
      expect(initialFocusWeek(today: today, lastDue: DateTime(2026, 12, 1)), DateTime(2026, 11, 2));
    });
  });
}
