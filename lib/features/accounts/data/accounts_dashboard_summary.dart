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
      );
}
