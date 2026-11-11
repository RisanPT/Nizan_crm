import 'package:nizan_crm/features/it/domain/models/it_project_model.dart';

// How long a project runs decides what KIND of project it is:
//
//   Mini      7 days  – 1 month      a short piece of work
//   Moderate  1 month – 3 months     a real project
//   Main      3 months and more      a major / strategic project
//
// The tier is never typed in: it is worked out from the project's start and end dates, so it can never
// disagree with the plan. A project with no end date yet falls back to the end of its target year (the
// strategic roadmap's way of dating a project); with neither it is "unscheduled" until someone dates it.
// Months are calendar months (3 Nov – 3 Dec is exactly one month), so "1 month" means the same in every month.
//
// Pure — test/project_tier_test.dart.

enum ProjectTier { mini, moderate, main, unscheduled }

extension ProjectTierX on ProjectTier {
  String get label => switch (this) {
        ProjectTier.mini => 'Mini',
        ProjectTier.moderate => 'Moderate',
        ProjectTier.main => 'Main',
        ProjectTier.unscheduled => 'No timeline',
      };

  /// "Mini projects", "Main projects" …
  String get plural => this == ProjectTier.unscheduled ? 'Projects with no timeline' : '$label projects';

  /// The timeline this tier covers, in words.
  String get range => switch (this) {
        ProjectTier.mini => '7 days to 1 month',
        ProjectTier.moderate => '1 to 3 months',
        ProjectTier.main => '3 months and above',
        ProjectTier.unscheduled => 'Set a start and end date',
      };
}

/// The calendar day of [d] (no time of day).
DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// [d] plus whole calendar months; the day is kept, or pulled back to the month's last day (31 Jan + 1 month = 28 Feb).
DateTime addMonths(DateTime d, int months) {
  final total = d.year * 12 + (d.month - 1) + months;
  final year = total ~/ 12;
  final month = total % 12 + 1;
  final lastDay = DateTime(year, month + 1, 0).day;
  return DateTime(year, month, d.day > lastDay ? lastDay : d.day);
}

/// The tier of a project that runs from [start] to [end] (both included).
/// An end before the start is not a timeline: unscheduled.
ProjectTier tierForRange(DateTime start, DateTime end) {
  final s = dateOnly(start);
  final e = dateOnly(end);
  if (e.isBefore(s)) return ProjectTier.unscheduled;
  if (!e.isAfter(addMonths(s, 1))) return ProjectTier.mini;
  if (!e.isAfter(addMonths(s, 3))) return ProjectTier.moderate;
  return ProjectTier.main;
}

/// Days a project runs, both ends counted (3 Nov – 3 Nov is 1 day).
int daysBetweenInclusive(DateTime start, DateTime end) => dateOnly(end).difference(dateOnly(start)).inDays + 1;

/// A project's dates and tier, ready to show.
class ProjectTimeline {
  final ProjectTier tier;
  final DateTime? start;
  final DateTime? end;

  /// The end was taken from the project's target year, not set as a date.
  final bool endFromTargetYear;

  const ProjectTimeline({required this.tier, this.start, this.end, this.endFromTargetYear = false});

  bool get scheduled => tier != ProjectTier.unscheduled;
  int? get days => start != null && end != null ? daysBetweenInclusive(start!, end!) : null;

  /// Runs fewer than 7 days — shorter than a mini project is meant to be.
  bool get underMinimum => tier == ProjectTier.mini && (days ?? 7) < 7;

  /// "15 days", "1 month", "2 months 10 days", "3 months", "2 yr 3 mo"; '' when there is no timeline.
  String get durationText => start == null || end == null ? '' : durationLabel(start!, end!);
}

/// The timeline of [p]: its dates, else (no end date) the end of its target year.
ProjectTimeline timelineOf(ITProjectModel p) => timelineFor(start: p.startDate, end: p.endDate, targetYear: p.targetYear);

ProjectTimeline timelineFor({DateTime? start, DateTime? end, int? targetYear}) {
  var fromYear = false;
  var stop = end;
  if (stop == null && targetYear != null && targetYear > 0) {
    stop = DateTime(targetYear, 12, 31);
    fromYear = true;
  }
  if (start == null || stop == null) return ProjectTimeline(tier: ProjectTier.unscheduled, start: start, end: stop, endFromTargetYear: fromYear);
  final tier = tierForRange(start, stop);
  return ProjectTimeline(tier: tier, start: dateOnly(start), end: dateOnly(stop), endFromTargetYear: fromYear);
}

ProjectTier projectTierOf(ITProjectModel p) => timelineOf(p).tier;

/// How long a project runs, in words. Under a month: the days (both ends counted). From a month on: whole
/// calendar months (3 Nov – 3 Dec is "1 month", the same boundary the tier uses), with the days left over
/// below 3 months; then years.
String durationLabel(DateTime start, DateTime end) {
  final s = dateOnly(start);
  final e = dateOnly(end);
  if (e.isBefore(s)) return '';
  String plural(int n, String one, String many) => '$n ${n == 1 ? one : many}';
  if (e.isBefore(addMonths(s, 1))) return plural(daysBetweenInclusive(s, e), 'day', 'days');
  var months = 1;
  while (!addMonths(s, months + 1).isAfter(e)) {
    months++;
  }
  final extraDays = e.difference(addMonths(s, months)).inDays;
  if (months < 3) return extraDays > 0 ? '${plural(months, 'month', 'months')} ${plural(extraDays, 'day', 'days')}' : plural(months, 'month', 'months');
  if (months < 12) return plural(months, 'month', 'months');
  final years = months ~/ 12;
  final rest = months % 12;
  return rest == 0 ? plural(years, 'year', 'years') : '${plural(years, 'year', 'years')} ${plural(rest, 'month', 'months')}';
}

enum TimeLeftKind { overdue, today, soon, normal, done }

class TimeLeft {
  final TimeLeftKind kind;
  final String label;
  const TimeLeft(this.kind, this.label);
}

/// How far a project is from its end date, for the badge on a card. A finished project says so; a cancelled
/// one has nothing to count. "Soon" is a week or less.
TimeLeft? timeLeft(DateTime? end, {required String status, required DateTime today}) {
  if (status == 'cancelled' || end == null) return null;
  if (status == 'completed') return const TimeLeft(TimeLeftKind.done, 'Completed');
  final left = dateOnly(end).difference(dateOnly(today)).inDays;
  if (left < 0) return TimeLeft(TimeLeftKind.overdue, 'Overdue ${-left}d');
  if (left == 0) return const TimeLeft(TimeLeftKind.today, 'Due today');
  if (left <= 7) return TimeLeft(TimeLeftKind.soon, left == 1 ? '1 day left' : '$left days left');
  if (left <= 60) return TimeLeft(TimeLeftKind.normal, '$left days left');
  if (left < 365) return TimeLeft(TimeLeftKind.normal, '${(left / 30).floor()} months left');
  final years = left ~/ 365;
  final months = ((left % 365) / 30).floor();
  return TimeLeft(TimeLeftKind.normal, months == 0 ? '$years yr left' : '$years yr $months mo left');
}

/// The ready-made lengths offered when dating a project: label, and the end date for a given start.
class DurationPreset {
  final String label;
  final DateTime Function(DateTime start) endFor;
  const DurationPreset(this.label, this.endFor);
}

final List<DurationPreset> kDurationPresets = [
  DurationPreset('1 week', (s) => dateOnly(s).add(const Duration(days: 6))),
  DurationPreset('2 weeks', (s) => dateOnly(s).add(const Duration(days: 13))),
  DurationPreset('1 month', (s) => addMonths(dateOnly(s), 1)),
  DurationPreset('2 months', (s) => addMonths(dateOnly(s), 2)),
  DurationPreset('3 months', (s) => addMonths(dateOnly(s), 3)),
  DurationPreset('6 months', (s) => addMonths(dateOnly(s), 6)),
  DurationPreset('1 year', (s) => addMonths(dateOnly(s), 12)),
];

/// Orders projects for a list: unfinished before finished, then by end date (soonest first; no end date last), then by name.
int compareForList(ITProjectModel a, ITProjectModel b) {
  bool finished(ITProjectModel p) => p.status == 'completed' || p.status == 'cancelled';
  if (finished(a) != finished(b)) return finished(a) ? 1 : -1;
  final ea = timelineOf(a).end;
  final eb = timelineOf(b).end;
  if (ea != eb) {
    if (ea == null) return 1;
    if (eb == null) return -1;
    return ea.compareTo(eb);
  }
  return a.name.toLowerCase().compareTo(b.name.toLowerCase());
}
