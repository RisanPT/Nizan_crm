import 'package:flutter_test/flutter_test.dart';
import 'package:nizan_crm/features/it/domain/project_tier.dart';

// A project's tier comes from how long it runs: mini 7 days – 1 month, moderate 1 – 3 months, main 3 months and more.

DateTime d(int y, int m, int day) => DateTime(y, m, day);

void main() {
  group('calendar months', () {
    test('a month keeps the day; a short month pulls it back to its last day', () {
      expect(addMonths(d(2026, 11, 3), 1), d(2026, 12, 3));
      expect(addMonths(d(2026, 1, 31), 1), d(2026, 2, 28));
      expect(addMonths(d(2028, 1, 31), 1), d(2028, 2, 29), reason: 'a leap year');
      expect(addMonths(d(2026, 11, 15), 3), d(2027, 2, 15), reason: 'over the new year');
      expect(addMonths(d(2026, 12, 31), 12), d(2027, 12, 31));
    });
  });

  group('the tier of a start and an end', () {
    final s = d(2026, 11, 3);

    test('mini: up to one month, the last day of the month included', () {
      expect(tierForRange(s, d(2026, 11, 9)), ProjectTier.mini, reason: '7 days');
      expect(tierForRange(s, d(2026, 11, 20)), ProjectTier.mini);
      expect(tierForRange(s, d(2026, 12, 3)), ProjectTier.mini, reason: 'exactly one month');
    });

    test('moderate: over a month, up to three', () {
      expect(tierForRange(s, d(2026, 12, 4)), ProjectTier.moderate, reason: 'a day over a month');
      expect(tierForRange(s, d(2027, 1, 15)), ProjectTier.moderate);
      expect(tierForRange(s, d(2027, 2, 3)), ProjectTier.moderate, reason: 'exactly three months');
    });

    test('main: over three months', () {
      expect(tierForRange(s, d(2027, 2, 4)), ProjectTier.main, reason: 'a day over three months');
      expect(tierForRange(s, d(2030, 12, 31)), ProjectTier.main);
    });

    test('"1 month" is the same in every month', () {
      expect(tierForRange(d(2026, 1, 31), d(2026, 2, 28)), ProjectTier.mini, reason: '31 Jan + 1 month = 28 Feb');
      expect(tierForRange(d(2026, 1, 31), d(2026, 3, 1)), ProjectTier.moderate);
    });

    test('times of day do not matter', () {
      expect(tierForRange(DateTime(2026, 11, 3, 23, 59), DateTime(2026, 12, 3, 0, 1)), ProjectTier.mini);
    });

    test('an end before the start is no timeline; one day is a (very short) mini', () {
      expect(tierForRange(s, d(2026, 11, 2)), ProjectTier.unscheduled);
      expect(tierForRange(s, s), ProjectTier.mini);
    });
  });

  group('a project\'s timeline', () {
    test('dated: the tier, the days (both ends counted) and the length in words', () {
      final t = timelineFor(start: d(2026, 11, 3), end: d(2026, 11, 17));
      expect([t.tier, t.days, t.durationText, t.endFromTargetYear, t.underMinimum], [ProjectTier.mini, 15, '15 days', false, false]);
    });

    test('no end date: the end of the target year stands in for it', () {
      final t = timelineFor(start: d(2026, 11, 3), targetYear: 2030);
      expect([t.tier, t.end, t.endFromTargetYear], [ProjectTier.main, d(2030, 12, 31), true]);
    });

    test('an end date always wins over the target year', () {
      final t = timelineFor(start: d(2026, 11, 3), end: d(2026, 11, 20), targetYear: 2030);
      expect([t.tier, t.endFromTargetYear], [ProjectTier.mini, false]);
    });

    test('no end date and no target year: unscheduled', () {
      final t = timelineFor(start: d(2026, 11, 3));
      expect([t.tier, t.scheduled, t.days, t.durationText], [ProjectTier.unscheduled, false, null, '']);
      expect(timelineFor().tier, ProjectTier.unscheduled);
    });

    test('shorter than 7 days is still a mini, flagged as under the minimum', () {
      final t = timelineFor(start: d(2026, 11, 3), end: d(2026, 11, 5));
      expect([t.tier, t.days, t.underMinimum], [ProjectTier.mini, 3, true]);
      expect(timelineFor(start: d(2026, 11, 3), end: d(2026, 11, 9)).underMinimum, isFalse, reason: '7 days is the minimum');
    });
  });

  group('the length in words', () {
    String len(DateTime a, DateTime b) => durationLabel(a, b);
    test('days, months, years', () {
      expect(len(d(2026, 11, 3), d(2026, 11, 3)), '1 day');
      expect(len(d(2026, 11, 3), d(2026, 11, 9)), '7 days');
      expect(len(d(2026, 11, 3), d(2026, 12, 2)), '30 days', reason: 'under a month: counted in days');
      expect(len(d(2026, 11, 3), d(2026, 12, 3)), '1 month', reason: 'the same boundary the tier uses');
      expect(len(d(2026, 11, 3), d(2026, 12, 17)), '1 month 14 days');
      expect(len(d(2026, 11, 3), d(2027, 2, 3)), '3 months');
      expect(len(d(2026, 11, 3), d(2027, 2, 20)), '3 months', reason: 'days are dropped from 3 months on');
      expect(len(d(2026, 11, 3), d(2027, 11, 3)), '1 year');
      expect(len(d(2026, 11, 3), d(2028, 5, 3)), '1 year 6 months');
      expect(len(d(2026, 11, 3), d(2026, 11, 1)), '', reason: 'an end before the start');
    });
  });

  group('time left', () {
    final today = d(2026, 11, 10);
    TimeLeft? left(DateTime? end, {String status = 'active'}) => timeLeft(end, status: status, today: today);

    test('overdue, today, soon, later', () {
      expect(left(d(2026, 11, 7))!.label, 'Overdue 3d');
      expect(left(d(2026, 11, 7))!.kind, TimeLeftKind.overdue);
      expect(left(d(2026, 11, 10))!.label, 'Due today');
      expect(left(d(2026, 11, 11))!.label, '1 day left');
      expect([left(d(2026, 11, 17))!.label, left(d(2026, 11, 17))!.kind], ['7 days left', TimeLeftKind.soon]);
      expect([left(d(2026, 11, 18))!.label, left(d(2026, 11, 18))!.kind], ['8 days left', TimeLeftKind.normal]);
      expect(left(d(2027, 2, 10))!.label, '3 months left');
      expect(left(d(2028, 11, 10))!.label, '2 yr left');
    });

    test('a finished project says so, a cancelled one has nothing to count, no end date no badge', () {
      expect(left(d(2026, 11, 1), status: 'completed')!.label, 'Completed', reason: 'never "overdue" once done');
      expect(left(d(2026, 11, 20), status: 'cancelled'), isNull);
      expect(left(null), isNull);
    });
  });

  group('the length presets', () {
    test('each ends where it says', () {
      final s = d(2026, 11, 3);
      DateTime end(String label) => kDurationPresets.firstWhere((p) => p.label == label).endFor(s);
      expect(end('1 week'), d(2026, 11, 9));
      expect(end('2 weeks'), d(2026, 11, 16));
      expect(end('1 month'), d(2026, 12, 3));
      expect(end('3 months'), d(2027, 2, 3));
      expect(end('1 year'), d(2027, 11, 3));
    });

    test('every preset lands in the tier its name suggests', () {
      final s = d(2026, 11, 3);
      final tiers = {for (final p in kDurationPresets) p.label: tierForRange(s, p.endFor(s))};
      expect(tiers['1 week'], ProjectTier.mini);
      expect(tiers['2 weeks'], ProjectTier.mini);
      expect(tiers['1 month'], ProjectTier.mini);
      expect(tiers['2 months'], ProjectTier.moderate);
      expect(tiers['3 months'], ProjectTier.moderate);
      expect(tiers['6 months'], ProjectTier.main);
      expect(tiers['1 year'], ProjectTier.main);
    });
  });
}
