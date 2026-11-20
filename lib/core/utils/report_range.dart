// THE DATES A REPORT IS DOWNLOADED FOR — one model for every report in the app.
//
// A range is whole calendar days, `from` to `to` BOTH inclusive (the report for 1 Nov – 17 Nov includes everything on the 17th).
// `from == null && to == null` means all time. Days are the device's own calendar days (this is an India-only app; the server reads the
// same `yyyy-MM-dd` as IST days — see backend utils/istDate.js).
//
// Presets (Today, This month, This financial year …) and "Custom" produce the same thing, so a download only ever asks one question:
// which days? `reportRangeFor` works a preset out; `ReportRange.contains` / `filterByRange` cut a list; `label` and `fileTag` name the
// range on screen and in the file name.

import 'package:flutter/material.dart' show DateTimeRange;
import 'package:intl/intl.dart';

/// The longest stretch the server builds one finance report for (backend utils/reportPeriod.js MAX_REPORT_DAYS).
const int kMaxFinanceReportDays = 800;

enum ReportPreset {
  today('Today'),
  yesterday('Yesterday'),
  last7('Last 7 days'),
  last30('Last 30 days'),
  thisMonth('This month'),
  lastMonth('Last month'),
  thisFy('This financial year'),
  lastFy('Last financial year'),
  all('All time'),
  custom('Custom range');

  const ReportPreset(this.label);
  final String label;
}

/// A day with no time of day.
DateTime dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

/// The first day of the Indian financial year (1 April) that [d] falls in.
DateTime financialYearStart(DateTime d) =>
    DateTime(d.month >= 4 ? d.year : d.year - 1, 4, 1);

class ReportRange {
  /// [from] and [to] are cut to whole days. Both null = all time.
  ReportRange({DateTime? from, DateTime? to, this.preset = ReportPreset.custom})
    : from = from == null ? null : dayOf(from),
      to = to == null ? null : dayOf(to);

  /// Everything, whenever it was.
  ReportRange.all() : from = null, to = null, preset = ReportPreset.all;

  final DateTime? from;
  final DateTime? to;

  /// How it was chosen (for showing which chip is on).
  final ReportPreset preset;

  bool get isAll => from == null && to == null;

  /// Reads the right way round: a range picked backwards is turned over.
  ReportRange get ordered {
    final a = from, b = to;
    if (a != null && b != null && b.isBefore(a)) {
      return ReportRange(from: b, to: a, preset: preset);
    }
    return this;
  }

  /// How many days it spans, both ends counted (null for all time or an open end).
  int? get days {
    final a = from, b = to;
    if (a == null || b == null) return null;
    return DateTime.utc(
          b.year,
          b.month,
          b.day,
        ).difference(DateTime.utc(a.year, a.month, a.day)).inDays +
        1;
  }

  /// Is [date]'s calendar day inside the range? An open end does not limit that side.
  bool contains(DateTime date) {
    final d = dayOf(date);
    final a = from, b = to;
    if (a != null && d.isBefore(a)) return false;
    if (b != null && d.isAfter(b)) return false;
    return true;
  }

  /// First moment (inclusive) and the moment after the last day (exclusive) — for code that compares timestamps.
  DateTime? get start => from;
  DateTime? get endExclusive =>
      to == null ? null : DateTime(to!.year, to!.month, to!.day + 1);

  /// The last moment of the last day — for APIs that take an inclusive end.
  DateTime? get endOfDay => to == null
      ? null
      : DateTime(to!.year, to!.month, to!.day, 23, 59, 59, 999);

  /// `yyyy-MM-dd`, as the server reads a day (null when that side is open).
  String? get fromIso => from == null ? null : _iso.format(from!);
  String? get toIso => to == null ? null : _iso.format(to!);

  /// For a screen that wants a Material range.
  DateTimeRange? get asDateTimeRange => (from == null || to == null)
      ? null
      : DateTimeRange(start: from!, end: to!);

  /// "All time" · "17 Nov 2026" · "1 Nov – 17 Nov 2026" · "28 Oct – 3 Nov 2026" · "28 Dec 2025 – 3 Jan 2026".
  String get label {
    final a = from, b = to;
    if (a == null && b == null) return 'All time';
    if (a != null && b == null) return 'From ${_full.format(a)}';
    if (a == null && b != null) return 'Up to ${_full.format(b)}';
    if (a == b) return _full.format(a!);
    if (a!.year == b!.year) {
      return a.month == b.month
          ? '${a.day} ${DateFormat('MMM').format(a)} – ${_full.format(b)}'
          : '${DateFormat('d MMM').format(a)} – ${_full.format(b)}';
    }
    return '${_full.format(a)} – ${_full.format(b)}';
  }

  /// For a file name: `all` · `2026-11-17` · `2026-11-01_to_2026-11-17`.
  String get fileTag {
    final a = fromIso, b = toIso;
    if (a == null && b == null) return 'all';
    if (a != null && b != null) return a == b ? a : '${a}_to_$b';
    return a != null ? 'from_$a' : 'to_$b';
  }

  @override
  bool operator ==(Object other) =>
      other is ReportRange && other.from == from && other.to == to;

  @override
  int get hashCode => Object.hash(from, to);

  @override
  String toString() => 'ReportRange($label)';

  static final _iso = DateFormat('yyyy-MM-dd');
  static final _full = DateFormat('d MMM yyyy');
}

/// The days a preset stands for, as of [now]. [ReportPreset.custom] has no days of its own: it gives this month.
ReportRange reportRangeFor(ReportPreset p, DateTime now) {
  final today = dayOf(now);
  switch (p) {
    case ReportPreset.today:
      return ReportRange(from: today, to: today, preset: p);
    case ReportPreset.yesterday:
      final y = DateTime(today.year, today.month, today.day - 1);
      return ReportRange(from: y, to: y, preset: p);
    case ReportPreset.last7:
      return ReportRange(
        from: DateTime(today.year, today.month, today.day - 6),
        to: today,
        preset: p,
      );
    case ReportPreset.last30:
      return ReportRange(
        from: DateTime(today.year, today.month, today.day - 29),
        to: today,
        preset: p,
      );
    case ReportPreset.thisMonth:
    case ReportPreset.custom:
      return ReportRange(
        from: DateTime(today.year, today.month, 1),
        to: DateTime(today.year, today.month + 1, 0),
        preset: p == ReportPreset.custom ? p : ReportPreset.thisMonth,
      );
    case ReportPreset.lastMonth:
      return ReportRange(
        from: DateTime(today.year, today.month - 1, 1),
        to: DateTime(today.year, today.month, 0),
        preset: p,
      );
    case ReportPreset.thisFy:
      final s = financialYearStart(today);
      return ReportRange(from: s, to: DateTime(s.year + 1, 3, 31), preset: p);
    case ReportPreset.lastFy:
      final s = DateTime(financialYearStart(today).year - 1, 4, 1);
      return ReportRange(from: s, to: DateTime(s.year + 1, 3, 31), preset: p);
    case ReportPreset.all:
      return ReportRange.all();
  }
}

/// A whole calendar month as a range (e.g. for a screen that works by month and downloads by days).
ReportRange monthRange(DateTime inMonth) => ReportRange(
  from: DateTime(inMonth.year, inMonth.month, 1),
  to: DateTime(inMonth.year, inMonth.month + 1, 0),
  preset: ReportPreset.custom,
);

/// The items of [items] whose date ([dateOf]) falls in [range]. An item with no date is kept only for all time (it cannot be placed).
List<T> filterByRange<T>(
  Iterable<T> items,
  DateTime? Function(T item) dateOf,
  ReportRange range,
) {
  if (range.isAll) return items.toList();
  return [
    for (final i in items)
      if (dateOf(i) != null && range.contains(dateOf(i)!)) i,
  ];
}

/// The days of the financial year a label names — "FY 2026-27" or "2026-27" — April to March; null when it names none ("All").
ReportRange? financialYearLabelRange(String label) {
  final m = RegExp(r'(\d{4})\s*-\s*\d{2,4}').firstMatch(label);
  final start = int.tryParse(m?.group(1) ?? '');
  if (start == null) return null;
  return ReportRange(from: DateTime(start, 4, 1), to: DateTime(start + 1, 3, 31), preset: ReportPreset.custom);
}
