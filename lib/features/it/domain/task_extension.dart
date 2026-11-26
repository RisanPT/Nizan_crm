// EXTENDING A TASK'S DUE DATE — what the app knows about it (the rules are the server's: backend utils/taskExtension.js).
//
//   • A task is OVERDUE when it has a due date, the due day is before today and it is not finished.
//   • Whoever plans the task extends it: a later day and a reason. Every extension is kept for good on the task — who, when, from which
//     day to which, how many days, how late it already was, and why — and the app reads the count and the history from that list.

import 'package:intl/intl.dart';

/// One extension of a task's due date.
class ITExtension {
  const ITExtension({
    required this.at,
    required this.from,
    required this.to,
    this.byName = '',
    this.days = 0,
    this.reason = '',
    this.overdueDays = 0,
    this.viaEdit = false,
  });

  /// When it was done.
  final DateTime at;

  /// The due date before, and the new one.
  final DateTime from;
  final DateTime to;
  final String byName;

  /// How many days later.
  final int days;
  final String reason;

  /// How late the task already was when it was extended (0 when it was not late yet).
  final int overdueDays;

  /// It came from an ordinary edit of the date, not from the "extend" action.
  final bool viaEdit;

  /// Null when the entry has no usable dates.
  static ITExtension? tryParse(Map<String, dynamic> j) {
    DateTime? d(dynamic v) => (v == null || v == '')
        ? null
        : DateTime.tryParse(v.toString())?.toLocal();
    final from = d(j['from']);
    final to = d(j['to']);
    if (from == null || to == null) return null;
    return ITExtension(
      at: d(j['at']) ?? to,
      from: from,
      to: to,
      byName: (j['byName'] ?? '').toString(),
      days: (j['days'] as num?)?.toInt() ?? daysBetween(to, from),
      reason: (j['reason'] ?? '').toString(),
      overdueDays: (j['overdueDays'] as num?)?.toInt() ?? 0,
      viaEdit: j['viaEdit'] == true,
    );
  }
}

/// What the history adds up to.
class ExtensionSummary {
  const ExtensionSummary({
    this.count = 0,
    this.totalDays = 0,
    this.originalDeadline,
    this.last,
    this.whileOverdue = 0,
  });

  /// How many times the due date was extended.
  final int count;

  /// How many days later it is now than it was first.
  final int totalDays;

  /// The due date before the first extension.
  final DateTime? originalDeadline;
  final ITExtension? last;

  /// How many of them were done when the task was already late.
  final int whileOverdue;

  bool get isEmpty => count == 0;
}

/// The history added up; the order the entries arrive in does not matter.
ExtensionSummary summarizeExtensions(List<ITExtension> list) {
  if (list.isEmpty) return const ExtensionSummary();
  final sorted = [...list]..sort((a, b) => a.at.compareTo(b.at));
  return ExtensionSummary(
    count: sorted.length,
    totalDays: sorted.fold<int>(0, (s, e) => s + e.days),
    originalDeadline: sorted.first.from,
    last: sorted.last,
    whileOverdue: sorted.where((e) => e.overdueDays > 0).length,
  );
}

DateTime _day(DateTime d) => DateTime.utc(d.year, d.month, d.day);

/// How many calendar days [later] is after [earlier] (negative when before).
int daysBetween(DateTime later, DateTime earlier) =>
    _day(later).difference(_day(earlier)).inDays;

/// How many days past its due day an unfinished task is; 0 when it is not late, has no due date, or is finished.
int taskOverdueDays({
  required DateTime? due,
  required bool done,
  required DateTime now,
}) {
  if (due == null || done) return 0;
  final d = daysBetween(now, due);
  return d > 0 ? d : 0;
}

/// "2026-11-20" — the day as the server reads it (no time, no zone).
String isoDay(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

final _long = DateFormat('d MMM yyyy');
final _short = DateFormat('d MMM');

/// "12 Nov 2026".
String longDay(DateTime d) => _long.format(d);

/// "12 Nov → 20 Nov 2026" (the year once, when both days are in it).
String dayRange(DateTime from, DateTime to) => from.year == to.year
    ? '${_short.format(from)} → ${_long.format(to)}'
    : '${_long.format(from)} → ${_long.format(to)}';

String daysText(int n) => '$n ${n == 1 ? 'day' : 'days'}';

/// "Extended 3 times · +17 days" / "Never extended".
String extensionHeadline(ExtensionSummary s) => s.isEmpty
    ? 'Never extended'
    : 'Extended ${s.count} ${s.count == 1 ? 'time' : 'times'} · +${daysText(s.totalDays)}';
