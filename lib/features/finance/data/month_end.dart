// Data models for the Month-End Review (GET /reports/month-end) and the Monthly
// Planning targets (GET/PUT /reports/targets).

double _d(dynamic v) => (v as num?)?.toDouble() ?? 0;
double? _dn(dynamic v) => v == null ? null : (v as num?)?.toDouble();
int _i(dynamic v) => (v as num?)?.toInt() ?? 0;

class AgingBuckets {
  final double current, days30, days60, days90, notYetDue;
  const AgingBuckets({
    this.current = 0,
    this.days30 = 0,
    this.days60 = 0,
    this.days90 = 0,
    this.notYetDue = 0,
  });
  factory AgingBuckets.fromJson(Map<String, dynamic> j) => AgingBuckets(
        current: _d(j['current']),
        days30: _d(j['days30']),
        days60: _d(j['days60']),
        days90: _d(j['days90']),
        notYetDue: _d(j['notYetDue']),
      );
}

class LabelAmount {
  final String label;
  final double amount;
  const LabelAmount(this.label, this.amount);
  factory LabelAmount.fromJson(Map<String, dynamic> j) =>
      LabelAmount(j['label'] as String? ?? '', _d(j['amount']));
}

class HighRiskDebtor {
  final String name;
  final double amount;
  final int daysOverdue;
  const HighRiskDebtor(this.name, this.amount, this.daysOverdue);
  factory HighRiskDebtor.fromJson(Map<String, dynamic> j) =>
      HighRiskDebtor(j['name'] as String? ?? '', _d(j['amount']), _i(j['daysOverdue']));
}

class UpcomingPayment {
  final String label;
  final double amount;
  final DateTime? dueDate;
  const UpcomingPayment(this.label, this.amount, this.dueDate);
  factory UpcomingPayment.fromJson(Map<String, dynamic> j) => UpcomingPayment(
        j['label'] as String? ?? '',
        _d(j['amount']),
        DateTime.tryParse(j['dueDate']?.toString() ?? '')?.toLocal(),
      );
}

class BudgetRow {
  final String category;
  final double budget, actual, variance, variancePct;
  const BudgetRow(this.category, this.budget, this.actual, this.variance, this.variancePct);
  factory BudgetRow.fromJson(Map<String, dynamic> j) => BudgetRow(
        j['category'] as String? ?? '',
        _d(j['budget']),
        _d(j['actual']),
        _d(j['variance']),
        _d(j['variancePct']),
      );
}

class ForecastMonth {
  final String label;
  final double inflow, outflow, net, closingCash;
  const ForecastMonth(this.label, this.inflow, this.outflow, this.net, this.closingCash);
  factory ForecastMonth.fromJson(Map<String, dynamic> j) => ForecastMonth(
        j['label'] as String? ?? '',
        _d(j['inflow']),
        _d(j['outflow']),
        _d(j['net']),
        _d(j['closingCash']),
      );
}

class UnusualTxn {
  final String voucherNo, narration, reason;
  final double amount;
  final DateTime? date;
  const UnusualTxn(this.voucherNo, this.narration, this.reason, this.amount, this.date);
  factory UnusualTxn.fromJson(Map<String, dynamic> j) => UnusualTxn(
        j['voucherNo'] as String? ?? '',
        j['narration'] as String? ?? '',
        j['reason'] as String? ?? '',
        _d(j['amount']),
        DateTime.tryParse(j['date']?.toString() ?? '')?.toLocal(),
      );
}

class MonthEndReview {
  final int month, year;
  final String periodLabel;

  // 1. Revenue
  final double revenue, revenuePrev, revenueGrowthPct;
  final double? revenueTarget, revenueTargetPct;
  final int orders;
  final double avgOrderValue;
  final List<LabelAmount> revenueByUnit;

  // 2. Profitability
  final double grossProfit, grossMarginPct, ebitda, ebitdaMarginPct, netProfit, netMarginPct, depreciation, totalExpense;
  final double? profitTarget, profitTargetPct;
  final String profitNote;

  // 3. Cash flow
  final double cashReceived, cashPaid, cashNet, bankBalance, cashBalance, totalLiquid;
  final List<ForecastMonth> forecast;

  // 4. Receivables
  final double arOutstanding, arOverdue, arNotYetDue, collectionEfficiencyPct;
  final AgingBuckets arBuckets;
  final List<HighRiskDebtor> highRisk;

  // 5. Payables
  final double apOutstanding, apOverdue;
  final AgingBuckets apBuckets;
  final List<UpcomingPayment> upcoming;

  // 6. Budget vs actual
  final List<BudgetRow> budgetRows;
  final double totalBudget, totalActual, totalVariance;

  // 7. Working capital
  final double inventoryValue, currentAssets, currentLiabilities, workingCapital;
  final double? currentRatio;

  // 8. KPIs
  final int employeeCount;
  final double revenuePerEmployee, burnRate;
  final double? cashRunwayMonths;
  final double cac, ltv, marketingSpend;
  final int newCustomers;

  // 9. Risk
  final double gstNetPayable, gstOutput, gstInputCredit;
  final List<UnusualTxn> unusualTransactions;

  // 10. Governance
  final int openDecisions;

  const MonthEndReview({
    required this.month,
    required this.year,
    required this.periodLabel,
    required this.revenue,
    required this.revenuePrev,
    required this.revenueGrowthPct,
    this.revenueTarget,
    this.revenueTargetPct,
    required this.orders,
    required this.avgOrderValue,
    required this.revenueByUnit,
    required this.grossProfit,
    required this.grossMarginPct,
    required this.ebitda,
    required this.ebitdaMarginPct,
    required this.netProfit,
    required this.netMarginPct,
    required this.depreciation,
    required this.totalExpense,
    this.profitTarget,
    this.profitTargetPct,
    required this.profitNote,
    required this.cashReceived,
    required this.cashPaid,
    required this.cashNet,
    required this.bankBalance,
    required this.cashBalance,
    required this.totalLiquid,
    required this.forecast,
    required this.arOutstanding,
    required this.arOverdue,
    required this.arNotYetDue,
    required this.collectionEfficiencyPct,
    required this.arBuckets,
    required this.highRisk,
    required this.apOutstanding,
    required this.apOverdue,
    required this.apBuckets,
    required this.upcoming,
    required this.budgetRows,
    required this.totalBudget,
    required this.totalActual,
    required this.totalVariance,
    required this.inventoryValue,
    required this.currentAssets,
    required this.currentLiabilities,
    required this.workingCapital,
    this.currentRatio,
    required this.employeeCount,
    required this.revenuePerEmployee,
    required this.burnRate,
    this.cashRunwayMonths,
    required this.cac,
    required this.ltv,
    required this.marketingSpend,
    required this.newCustomers,
    required this.gstNetPayable,
    required this.gstOutput,
    required this.gstInputCredit,
    required this.unusualTransactions,
    required this.openDecisions,
  });

  factory MonthEndReview.fromJson(Map<String, dynamic> j) {
    final period = j['period'] as Map<String, dynamic>? ?? const {};
    final rev = j['revenue'] as Map<String, dynamic>? ?? const {};
    final prof = j['profitability'] as Map<String, dynamic>? ?? const {};
    final cash = j['cashFlow'] as Map<String, dynamic>? ?? const {};
    final ar = j['receivables'] as Map<String, dynamic>? ?? const {};
    final ap = j['payables'] as Map<String, dynamic>? ?? const {};
    final bva = j['budgetVsActual'] as Map<String, dynamic>? ?? const {};
    final wc = j['workingCapital'] as Map<String, dynamic>? ?? const {};
    final kpi = j['kpis'] as Map<String, dynamic>? ?? const {};
    final risk = j['risk'] as Map<String, dynamic>? ?? const {};
    List<T> list<T>(dynamic v, T Function(Map<String, dynamic>) f) =>
        (v as List<dynamic>? ?? const []).map((e) => f(e as Map<String, dynamic>)).toList();

    return MonthEndReview(
      month: _i(period['month']),
      year: _i(period['year']),
      periodLabel: period['label'] as String? ?? '',
      revenue: _d(rev['total']),
      revenuePrev: _d(rev['previous']),
      revenueGrowthPct: _d(rev['growthPct']),
      revenueTarget: _dn(rev['target']),
      revenueTargetPct: _dn(rev['targetAchievedPct']),
      orders: _i(rev['orders']),
      avgOrderValue: _d(rev['avgOrderValue']),
      revenueByUnit: list(rev['byUnit'], LabelAmount.fromJson),
      grossProfit: _d(prof['grossProfit']),
      grossMarginPct: _d(prof['grossMarginPct']),
      ebitda: _d(prof['ebitda']),
      ebitdaMarginPct: _d(prof['ebitdaMarginPct']),
      netProfit: _d(prof['netProfit']),
      netMarginPct: _d(prof['netMarginPct']),
      depreciation: _d(prof['depreciation']),
      totalExpense: _d(prof['totalExpense']),
      profitTarget: _dn(prof['target']),
      profitTargetPct: _dn(prof['targetAchievedPct']),
      profitNote: prof['note'] as String? ?? '',
      cashReceived: _d(cash['received']),
      cashPaid: _d(cash['paid']),
      cashNet: _d(cash['net']),
      bankBalance: _d(cash['bankBalance']),
      cashBalance: _d(cash['cashBalance']),
      totalLiquid: _d(cash['totalLiquid']),
      forecast: list(cash['forecast'], ForecastMonth.fromJson),
      arOutstanding: _d(ar['outstanding']),
      arOverdue: _d(ar['overdue']),
      arNotYetDue: _d(ar['notYetDue']),
      collectionEfficiencyPct: _d(ar['collectionEfficiencyPct']),
      arBuckets: AgingBuckets.fromJson(ar['buckets'] as Map<String, dynamic>? ?? const {}),
      highRisk: list(ar['highRisk'], HighRiskDebtor.fromJson),
      apOutstanding: _d(ap['outstanding']),
      apOverdue: _d(ap['overdue']),
      apBuckets: AgingBuckets.fromJson(ap['buckets'] as Map<String, dynamic>? ?? const {}),
      upcoming: list(ap['upcoming'], UpcomingPayment.fromJson),
      budgetRows: list(bva['rows'], BudgetRow.fromJson),
      totalBudget: _d(bva['totalBudget']),
      totalActual: _d(bva['totalActual']),
      totalVariance: _d(bva['totalVariance']),
      inventoryValue: _d(wc['inventoryValue']),
      currentAssets: _d(wc['currentAssets']),
      currentLiabilities: _d(wc['currentLiabilities']),
      workingCapital: _d(wc['workingCapital']),
      currentRatio: _dn(wc['currentRatio']),
      employeeCount: _i(kpi['employeeCount']),
      revenuePerEmployee: _d(kpi['revenuePerEmployee']),
      burnRate: _d(kpi['burnRate']),
      cashRunwayMonths: _dn(kpi['cashRunwayMonths']),
      cac: _d(kpi['customerAcquisitionCost']),
      ltv: _d(kpi['customerLifetimeValue']),
      marketingSpend: _d(kpi['marketingSpend']),
      newCustomers: _i(kpi['newCustomers']),
      gstNetPayable: _d(risk['gstNetPayable']),
      gstOutput: _d(risk['gstOutput']),
      gstInputCredit: _d(risk['gstInputCredit']),
      unusualTransactions: list(risk['unusualTransactions'], UnusualTxn.fromJson),
      openDecisions: _i(j['openDecisions']),
    );
  }
}

class TargetAllocation {
  final String name;
  final double amount;
  const TargetAllocation(this.name, this.amount);
  factory TargetAllocation.fromJson(Map<String, dynamic> j) =>
      TargetAllocation(j['name'] as String? ?? '', _d(j['amount']));
  Map<String, dynamic> toJson() => {'name': name, 'amount': amount};
}

class MonthlyTarget {
  final int month, year;
  final double revenueTarget, profitTarget, collectionTarget, expenseLimit;
  final List<TargetAllocation> allocations;
  final String notes;

  const MonthlyTarget({
    required this.month,
    required this.year,
    this.revenueTarget = 0,
    this.profitTarget = 0,
    this.collectionTarget = 0,
    this.expenseLimit = 0,
    this.allocations = const [],
    this.notes = '',
  });

  factory MonthlyTarget.fromJson(Map<String, dynamic> j) => MonthlyTarget(
        month: _i(j['month']),
        year: _i(j['year']),
        revenueTarget: _d(j['revenueTarget']),
        profitTarget: _d(j['profitTarget']),
        collectionTarget: _d(j['collectionTarget']),
        expenseLimit: _d(j['expenseLimit']),
        allocations: (j['allocations'] as List<dynamic>? ?? const [])
            .map((e) => TargetAllocation.fromJson(e as Map<String, dynamic>))
            .toList(),
        notes: j['notes'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'month': month,
        'year': year,
        'revenueTarget': revenueTarget,
        'profitTarget': profitTarget,
        'collectionTarget': collectionTarget,
        'expenseLimit': expenseLimit,
        'allocations': allocations.map((a) => a.toJson()).toList(),
        'notes': notes,
      };

  MonthlyTarget copyWith({
    double? revenueTarget,
    double? profitTarget,
    double? collectionTarget,
    double? expenseLimit,
    List<TargetAllocation>? allocations,
    String? notes,
  }) =>
      MonthlyTarget(
        month: month,
        year: year,
        revenueTarget: revenueTarget ?? this.revenueTarget,
        profitTarget: profitTarget ?? this.profitTarget,
        collectionTarget: collectionTarget ?? this.collectionTarget,
        expenseLimit: expenseLimit ?? this.expenseLimit,
        allocations: allocations ?? this.allocations,
        notes: notes ?? this.notes,
      );
}

// ── CEO decisions / action items ──────────────────────────────────────────

const kDecisionTypes = <String>['cost_approval', 'hiring', 'capex', 'investment', 'strategic', 'action_item'];
const kDecisionStatuses = <String>['pending', 'approved', 'rejected', 'deferred', 'done'];

String decisionTypeLabel(String t) => switch (t) {
      'cost_approval' => 'Cost approval',
      'hiring' => 'Hiring',
      'capex' => 'CapEx',
      'investment' => 'Investment',
      'strategic' => 'Strategic',
      _ => 'Action item',
    };
String decisionStatusLabel(String s) => switch (s) {
      'approved' => 'Approved',
      'rejected' => 'Rejected',
      'deferred' => 'Deferred',
      'done' => 'Done',
      _ => 'Pending',
    };

class CeoDecision {
  final String id;
  final int month, year;
  final String type, title, description, status, owner;
  final double amount;
  final DateTime? dueDate;

  const CeoDecision({
    this.id = '',
    required this.month,
    required this.year,
    this.type = 'action_item',
    this.title = '',
    this.description = '',
    this.status = 'pending',
    this.owner = '',
    this.amount = 0,
    this.dueDate,
  });

  bool get isOpen => status == 'pending' || status == 'deferred';

  factory CeoDecision.fromJson(Map<String, dynamic> j) => CeoDecision(
        id: j['_id'] as String? ?? j['id'] as String? ?? '',
        month: _i(j['month']),
        year: _i(j['year']),
        type: j['type'] as String? ?? 'action_item',
        title: j['title'] as String? ?? '',
        description: j['description'] as String? ?? '',
        status: j['status'] as String? ?? 'pending',
        owner: j['owner'] as String? ?? '',
        amount: _d(j['amount']),
        dueDate: DateTime.tryParse(j['dueDate']?.toString() ?? '')?.toLocal(),
      );

  Map<String, dynamic> toJson() => {
        'month': month,
        'year': year,
        'type': type,
        'title': title,
        'description': description,
        'status': status,
        'owner': owner,
        'amount': amount,
        'dueDate': dueDate?.toIso8601String(),
      };
}
