import 'package:intl/intl.dart';

import 'package:nizan_crm/features/accounts/data/accounts_dashboard_summary.dart';

// What the Combined Accounts Dashboard needs worked out from the summary: how money is written, the percentage
// against the earlier period, the trend chart's points (a day each, or a week / month for a long period), the
// expense lines as the design groups them, and the rows of the downloaded report.
//
// Pure — test/accounts_dashboard_test.dart.

final _grouped = NumberFormat.decimalPattern('en_IN');

/// ₹2,36,34,500 — whole rupees, Indian grouping.
String inrFull(double v) => '${v < 0 ? '-' : ''}₹${_grouped.format(v.abs().round())}';

/// For a big number on a card: under a lakh in full (₹53,000), then lakhs (₹14.1 L), then crores (₹2.36 Cr).
String inrCompact(double v) {
  final a = v.abs();
  final sign = v < 0 ? '-' : '';
  if (a >= 10000000) return '$sign₹${(a / 10000000).toStringAsFixed(2)} Cr';
  if (a >= 100000) return '$sign₹${(a / 100000).toStringAsFixed(1)} L';
  return '$sign₹${_grouped.format(a.round())}';
}

String _trim(double v) => v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1);

/// For the chart's money axis: ₹0, ₹500, ₹20k, ₹1.5L, ₹2Cr.
String axisMoney(double v) {
  final a = v.abs();
  final sign = v < 0 ? '-' : '';
  if (a < 1000) return '$sign₹${a.round()}';
  if (a < 100000) return '$sign₹${_trim(a / 1000)}k';
  if (a < 10000000) return '$sign₹${_trim(a / 100000)}L';
  return '$sign₹${_trim(a / 10000000)}Cr';
}

/// How much [current] is above (+) or below (−) [previous], in percent; null when there is no earlier figure to
/// measure against (it was 0). A loss that shrank counts as an improvement: the base is its size, not its sign.
double? pctChange(double current, double previous) {
  if (previous.abs() < 0.005) return null;
  return (current - previous) / previous.abs() * 100;
}

/// "+12%", "−6%", "+0.4%" (under 1% keeps a decimal so a small move is not shown as 0).
String pctText(double pct) {
  final sign = pct < 0 ? '−' : '+';
  final a = pct.abs();
  return a < 1 ? '$sign${a.toStringAsFixed(1)}%' : '$sign${a.round()}%';
}

/// What the percentage is measured against, for its tooltip: "Oct 1 – Oct 5" (month, preceding) or the same dates last year.
String comparisonText(PeriodComparison p) {
  DateTime? parse(String s) {
    final x = s.split('-').map(int.tryParse).toList();
    return x.length == 3 && !x.contains(null) ? DateTime(x[0]!, x[1]!, x[2]!) : null;
  }

  final a = parse(p.from);
  final b = parse(p.to);
  if (a == null || b == null) return 'the earlier period';
  final sameYear = a.year == b.year;
  String d(DateTime x) => sameYear ? DateFormat('d MMM').format(x) : DateFormat('d MMM yyyy').format(x);
  final span = p.from == p.to ? d(a) : '${d(a)} – ${d(b)}${sameYear ? ' ${b.year}' : ''}';
  return switch (p.mode) {
    'month' => 'the same days of the month before ($span)',
    'fy' => 'the same dates a year earlier ($span)',
    _ => 'the period just before ($span)',
  };
}

// ── the trend chart ─────────────────────────────────────────────────────────

/// One point of the trend chart: a day, or — over a long period — a week or a month of days added together.
class ChartBucket {
  final DateTime start;
  final DateTime end;
  final String label;
  final String tooltip;
  final double income;
  final double expense;
  final int incomeCount;
  final int expenseCount;

  const ChartBucket({
    required this.start,
    required this.end,
    required this.label,
    required this.tooltip,
    required this.income,
    required this.expense,
    required this.incomeCount,
    required this.expenseCount,
  });
}

/// Up to 62 days: a point per day. Up to 200: a point per week. Longer (a financial year): a point per month.
List<ChartBucket> bucketSeries(List<DayPoint> days) {
  if (days.isEmpty) return const [];
  ChartBucket make(List<DayPoint> part, String label, String tooltip) => ChartBucket(
        start: part.first.date,
        end: part.last.date,
        label: label,
        tooltip: tooltip,
        income: part.fold(0.0, (s, d) => s + d.income),
        expense: part.fold(0.0, (s, d) => s + d.expense),
        incomeCount: part.fold(0, (s, d) => s + d.incomeCount),
        expenseCount: part.fold(0, (s, d) => s + d.expenseCount),
      );
  final day = DateFormat('MMM d');
  if (days.length <= 62) {
    return [for (final d in days) make([d], day.format(d.date), DateFormat('EEE, d MMM yyyy').format(d.date))];
  }
  if (days.length <= 200) {
    final out = <ChartBucket>[];
    for (var i = 0; i < days.length; i += 7) {
      final part = days.sublist(i, i + 7 > days.length ? days.length : i + 7);
      out.add(make(part, day.format(part.first.date), '${DateFormat('d MMM').format(part.first.date)} – ${DateFormat('d MMM yyyy').format(part.last.date)}'));
    }
    return out;
  }
  final out = <ChartBucket>[];
  var i = 0;
  final longSpan = days.last.date.difference(days.first.date).inDays > 366;
  while (i < days.length) {
    var j = i;
    while (j < days.length && days[j].date.year == days[i].date.year && days[j].date.month == days[i].date.month) {
      j++;
    }
    final part = days.sublist(i, j);
    out.add(make(part, DateFormat(longSpan ? 'MMM yy' : 'MMM').format(part.first.date), DateFormat('MMMM yyyy').format(part.first.date)));
    i = j;
  }
  return out;
}

/// A y-axis ceiling that is a round number above [max] (so the gridlines read ₹20k, ₹40k …), and the gap between lines.
({double max, double step}) niceScale(double max) {
  if (max <= 0) return (max: 100, step: 25);
  var step = _niceStep(max / 4);
  var top = (max / step).ceil() * step;
  if (top <= max) top += step;
  return (max: top, step: step);
}

double _niceStep(double raw) {
  var pow10 = 1.0;
  while (raw >= pow10 * 10) {
    pow10 *= 10;
  }
  while (raw < pow10) {
    pow10 /= 10;
  }
  final f = raw / pow10;
  final nice = f <= 1 ? 1 : (f <= 2 ? 2 : (f <= 2.5 ? 2.5 : (f <= 5 ? 5 : 10)));
  return nice * pow10;
}

// ── the breakdown cards ─────────────────────────────────────────────────────

/// A line of the Income / Expense breakdown cards.
class BreakdownLine {
  final String label;
  final double amount;
  final int count;

  /// Includes an estimate (a subscription's run-rate).
  final bool estimated;

  /// For "Others": what is inside it, as "HRA ₹400, Vendor bills ₹1,180"; '' otherwise.
  final String detail;

  const BreakdownLine(this.label, this.amount, {this.count = 0, this.estimated = false, this.detail = ''});
}

/// The expense lines the design shows — Salaries, Office & admin expenses, Artist expenses, Artist payouts,
/// Fleet & fuel — and "Others" for everything else (HRA, vendor bills, subscriptions, refunds, cash out).
const _mainExpenseKeys = ['salaries', 'admin_expenses', 'artist_expenses', 'artist_payouts', 'fleet'];

List<BreakdownLine> expenseBreakdown(SummaryGroup g) {
  final main = <BreakdownLine>[];
  for (final key in _mainExpenseKeys) {
    final l = g.items.where((i) => i.key == key).firstOrNull;
    if (l != null) main.add(BreakdownLine(l.label, l.amount, count: l.count, estimated: l.estimated));
  }
  final rest = g.items.where((i) => !_mainExpenseKeys.contains(i.key)).toList();
  final shown = rest.where((i) => i.amount != 0).toList();
  main.add(BreakdownLine(
    'Others',
    rest.fold(0.0, (s, i) => s + i.amount),
    count: rest.fold(0, (s, i) => s + i.count),
    estimated: shown.any((i) => i.estimated),
    detail: shown.map((i) => '${i.label} ${inrFull(i.amount)}${i.estimated ? ' (est.)' : ''}').join(', '),
  ));
  return main;
}

List<BreakdownLine> incomeBreakdown(SummaryGroup g) =>
    [for (final i in g.items) BreakdownLine(i.label, i.amount, count: i.count, estimated: i.estimated)];

// ── the downloaded report ───────────────────────────────────────────────────

class DashboardReport {
  final String title;
  final String fileBase;
  final List<String> headers;
  final List<List<dynamic>> rows;
  const DashboardReport(this.title, this.fileBase, this.headers, this.rows);
}

/// The whole dashboard as a table: every income and expense line (not grouped), the result, the dues and what is
/// waiting for approval. [periodLabel] is what the page says ("November 2026").
DashboardReport buildDashboardReport(AccountsDashboardSummary s, String periodLabel) {
  String amt(double v) => v.toStringAsFixed(2);
  final rows = <List<dynamic>>[];
  void section(String name, SummaryGroup g, String totalLabel) {
    for (final l in g.items) {
      rows.add([name, l.estimated ? '${l.label} (estimate)' : l.label, l.count == 0 ? '' : l.count, amt(l.amount)]);
    }
    rows.add([name, totalLabel, '', amt(g.total)]);
  }

  section('Income', s.income, 'Total income');
  section('Expense', s.expense, 'Total expense');
  rows.add(['Result', s.net >= 0 ? 'Net profit' : 'Net loss', '', amt(s.net)]);
  final p = s.previous;
  if (p != null) {
    rows.add(['Compared with', 'Income ${p.from} to ${p.to}', '', amt(p.income)]);
    rows.add(['Compared with', 'Expense ${p.from} to ${p.to}', '', amt(p.expense)]);
  }
  rows.add(['Dues (today)', 'Receivables outstanding', s.receivables.partyCount, amt(s.receivables.totalOutstanding)]);
  rows.add(['Dues (today)', 'Receivables overdue', '', amt(s.receivables.totalOverdue)]);
  rows.add(['Dues (today)', 'Payables outstanding', s.payables.partyCount, amt(s.payables.totalOutstanding)]);
  rows.add(['Dues (today)', 'Payables overdue', '', amt(s.payables.totalOverdue)]);
  rows.add(['Balances (today)', 'Bank', '', amt(s.bankTotal)]);
  rows.add(['Balances (today)', 'Cash', '', amt(s.cashTotal)]);
  rows.add(['Balances (today)', 'Cash & bank', '', amt(s.cashBankTotal)]);
  section('Awaiting approval', s.pending, 'Total pending');
  return DashboardReport(
    'Combined Accounts Report — $periodLabel',
    'combined_accounts_${periodLabel.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_').replaceAll(RegExp(r'^_|_$'), '')}',
    const ['Section', 'Item', 'Count', 'Amount (INR)'],
    rows,
  );
}
