import 'package:intl/intl.dart';

// The Timeline's week-by-week handling: which week is "the" week being looked at, its number and its label, how far
// along the timeline it sits, and which week to open first. Weeks run Monday to Sunday and are numbered the ISO way
// (week 1 is the week with the year's first Thursday), so "Week 45" means the same here as on a calendar.
//
// Pure — test/gantt_weeks_test.dart.

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// The Monday of the week [d] falls in (midnight).
DateTime mondayOf(DateTime d) => DateTime(d.year, d.month, d.day - (d.weekday - 1));

/// [weeks] weeks after (or before, if negative) the week starting [monday]. Counted in calendar days, so a change of
/// clocks does not shift it.
DateTime addWeeks(DateTime monday, int weeks) => DateTime(monday.year, monday.month, monday.day + 7 * weeks);

/// Whole days from [from] to [to], by calendar date (clock changes do not count as a day).
int daysBetween(DateTime from, DateTime to) => DateTime.utc(to.year, to.month, to.day).difference(DateTime.utc(from.year, from.month, from.day)).inDays;

/// ISO-8601 week number, 1 to 53.
int isoWeekNumber(DateTime date) {
  // the week belongs to the year its Thursday is in
  final thursday = DateTime.utc(date.year, date.month, date.day + (4 - date.weekday));
  final jan1 = DateTime.utc(thursday.year, 1, 1);
  return thursday.difference(jan1).inDays ~/ 7 + 1;
}

/// "Week 45 · 2 – 8 Nov 2026", "Week 48 · 30 Nov – 6 Dec 2026", "Week 1 · 28 Dec 2026 – 3 Jan 2027" — the week that
/// starts on [monday].
String weekLabel(DateTime monday) {
  final start = mondayOf(monday);
  final end = DateTime(start.year, start.month, start.day + 6);
  final d = DateFormat('d');
  final dm = DateFormat('d MMM');
  final dmy = DateFormat('d MMM yyyy');
  final String range;
  if (start.year != end.year) {
    range = '${dmy.format(start)} – ${dmy.format(end)}';
  } else if (start.month != end.month) {
    range = '${dm.format(start)} – ${dmy.format(end)}';
  } else {
    range = '${d.format(start)} – ${dmy.format(end)}';
  }
  return 'Week ${isoWeekNumber(start)} · $range';
}

/// Which week to show when the timeline opens: this week if the project is running now, otherwise the nearest end of
/// its plan (its first week if it has not started, its last if it is over), so the first sight is never an empty stretch.
/// Without any dates: this week.
DateTime initialFocusWeek({required DateTime today, DateTime? firstStart, DateTime? lastDue}) {
  final t = dateOnly(today);
  if (firstStart != null && t.isBefore(dateOnly(firstStart))) return mondayOf(firstStart);
  if (lastDue != null && t.isAfter(dateOnly(lastDue))) return mondayOf(lastDue);
  return mondayOf(t);
}
