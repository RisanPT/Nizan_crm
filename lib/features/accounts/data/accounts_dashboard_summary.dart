/// Combined Accounts Dashboard payload from GET /accounting/dashboard-summary.
/// Company-wide income vs expense for a period (only approved / verified money)
/// plus outstanding receivables & payables as of today.
double _d(dynamic v) => (v as num?)?.toDouble() ?? 0;

class SummaryLine {
  final String key;
  final String label;
  final double amount;
  final int count;

  /// True when the figure is an estimate (subscriptions: plan run-rate).
  final bool estimated;

  const SummaryLine({
    required this.key,
    required this.label,
    required this.amount,
    required this.count,
    this.estimated = false,
  });

  factory SummaryLine.fromJson(Map<String, dynamic> j) => SummaryLine(
        key: j['key'] as String? ?? '',
        label: j['label'] as String? ?? '',
        amount: _d(j['amount']),
        count: (j['count'] as num?)?.toInt() ?? 0,
        estimated: j['estimated'] == true,
      );
}

class SummaryGroup {
  final double total;
  final List<SummaryLine> items;
  const SummaryGroup({required this.total, required this.items});

  factory SummaryGroup.fromJson(Map<String, dynamic>? j) => SummaryGroup(
        total: _d(j?['total']),
        items: ((j?['items'] as List?) ?? const [])
            .map((e) => SummaryLine.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class OutstandingParty {
  final String name;
  final String phone;
  final double outstanding;
  final double overdue;
  final int oldestDays;

  const OutstandingParty({
    required this.name,
    required this.phone,
    required this.outstanding,
    required this.overdue,
    required this.oldestDays,
  });

  factory OutstandingParty.fromJson(Map<String, dynamic> j) => OutstandingParty(
        name: j['name'] as String? ?? '',
        phone: j['phone'] as String? ?? '',
        outstanding: _d(j['outstanding']),
        overdue: _d(j['overdue']),
        oldestDays: (j['oldestDays'] as num?)?.toInt() ?? 0,
      );
}

class OutstandingSummary {
  final double totalOutstanding;
  final double totalOverdue;
  final double totalNotYetDue;

  /// Overdue buckets: 0–30, 31–60, 61–90, 90+ days.
  final double current;
  final double days30;
  final double days60;
  final double days90;
  final int partyCount;
  final List<OutstandingParty> top;

  const OutstandingSummary({
    required this.totalOutstanding,
    required this.totalOverdue,
    required this.totalNotYetDue,
    required this.current,
    required this.days30,
    required this.days60,
    required this.days90,
    required this.partyCount,
    required this.top,
  });

  factory OutstandingSummary.fromJson(Map<String, dynamic>? j) {
    final b = (j?['buckets'] as Map<String, dynamic>?) ?? const {};
    return OutstandingSummary(
      totalOutstanding: _d(j?['totalOutstanding']),
      totalOverdue: _d(j?['totalOverdue']),
      totalNotYetDue: _d(j?['totalNotYetDue']),
      current: _d(b['current']),
      days30: _d(b['days30']),
      days60: _d(b['days60']),
      days90: _d(b['days90']),
      partyCount: (j?['partyCount'] as num?)?.toInt() ?? 0,
      top: ((j?['top'] as List?) ?? const [])
          .map((e) => OutstandingParty.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// One day of the period: money in and out, and how many entries made it.
class DayPoint {
  final DateTime date;
  final double income;
  final double expense;
  final int incomeCount;
  final int expenseCount;

  const DayPoint({
    required this.date,
    required this.income,
    required this.expense,
    this.incomeCount = 0,
    this.expenseCount = 0,
  });

  factory DayPoint.fromJson(Map<String, dynamic> j) {
    final parts = (j['date'] as String? ?? '').split('-').map(int.tryParse).toList();
    final ok = parts.length == 3 && !parts.contains(null);
    return DayPoint(
      date: ok ? DateTime(parts[0]!, parts[1]!, parts[2]!) : DateTime.fromMillisecondsSinceEpoch(0),
      income: _d(j['income']),
      expense: _d(j['expense']),
      incomeCount: (j['incomeCount'] as num?)?.toInt() ?? 0,
      expenseCount: (j['expenseCount'] as num?)?.toInt() ?? 0,
    );
  }
}

/// The earlier period this one is compared with ("+12% vs last month"), as the server worked it out: only the
/// days that have happened count, so a month in progress is not set against a whole month.
/// [currentIncome] / [currentExpense] / [currentNet] are THIS period up to today — what the percentages come from.
class PeriodComparison {
  final String from;
  final String to;

  /// 'month' (same days of the previous month) | 'fy' (same dates a year earlier) | 'preceding' (the stretch just before).
  final String mode;
  final int days;
  final double income;
  final double expense;
  final double net;
  final double currentIncome;
  final double currentExpense;
  final double currentNet;

  const PeriodComparison({
    required this.from,
    required this.to,
    required this.mode,
    required this.days,
    required this.income,
    required this.expense,
    required this.net,
    required this.currentIncome,
    required this.currentExpense,
    required this.currentNet,
  });

  factory PeriodComparison.fromJson(Map<String, dynamic> j) => PeriodComparison(
        from: j['from'] as String? ?? '',
        to: j['to'] as String? ?? '',
        mode: j['mode'] as String? ?? 'preceding',
        days: (j['days'] as num?)?.toInt() ?? 0,
        income: _d(j['income']),
        expense: _d(j['expense']),
        net: _d(j['net']),
        currentIncome: _d(j['currentIncome']),
        currentExpense: _d(j['currentExpense']),
        currentNet: _d(j['currentNet']),
      );
}

class AccountsDashboardSummary {
  final String from;
  final String to;
  final SummaryGroup income;
  final SummaryGroup expense;
  final double net;

  /// Money still awaiting verification / approval in the period (not counted
  /// in income or expense).
  final SummaryGroup pending;
  final OutstandingSummary receivables;
  final OutstandingSummary payables;

  /// Live Bank & Cash balances (today), as on the Bank & Cash Balance screen.
  final double cashBankTotal;
  final double bankTotal;
  final double cashTotal;

  /// One point per day of the period (the trend chart and the sparklines).
  final List<DayPoint> series;

  /// How the period compares with the one before it; null when there is nothing to compare with.
  final PeriodComparison? previous;

  const AccountsDashboardSummary({
    required this.from,
    required this.to,
    required this.income,
    required this.expense,
    required this.net,
    required this.pending,
    required this.receivables,
    required this.payables,
    this.cashBankTotal = 0,
    this.bankTotal = 0,
    this.cashTotal = 0,
    this.series = const [],
    this.previous,
  });

  factory AccountsDashboardSummary.fromJson(Map<String, dynamic> j) =>
      AccountsDashboardSummary(
        from: j['from'] as String? ?? '',
        to: j['to'] as String? ?? '',
        income: SummaryGroup.fromJson(j['income'] as Map<String, dynamic>?),
        expense: SummaryGroup.fromJson(j['expense'] as Map<String, dynamic>?),
        net: _d(j['net']),
        pending: SummaryGroup.fromJson(j['pending'] as Map<String, dynamic>?),
        receivables: OutstandingSummary.fromJson(j['receivables'] as Map<String, dynamic>?),
        payables: OutstandingSummary.fromJson(j['payables'] as Map<String, dynamic>?),
        cashBankTotal: _d((j['cashBank'] as Map?)?['total']),
        bankTotal: _d((j['cashBank'] as Map?)?['bank']),
        cashTotal: _d((j['cashBank'] as Map?)?['cash']),
        series: ((j['series'] as List?) ?? const [])
            .map((e) => DayPoint.fromJson(e as Map<String, dynamic>))
            .toList(),
        previous: j['previous'] is Map<String, dynamic>
            ? PeriodComparison.fromJson(j['previous'] as Map<String, dynamic>)
            : null,
      );
}
