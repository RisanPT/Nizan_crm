/// A single line in a financial statement (one ledger account's total).
class ReportLine {
  final String code;
  final String name;
  final String group;
  final double amount;

  const ReportLine({required this.code, required this.name, this.group = '', this.amount = 0});

  factory ReportLine.fromJson(Map<String, dynamic> j) => ReportLine(
        code: j['code'] as String? ?? '',
        name: j['name'] as String? ?? '',
        group: j['group'] as String? ?? '',
        amount: (j['amount'] as num?)?.toDouble() ?? 0,
      );
}

List<ReportLine> _lines(dynamic v) => (v as List<dynamic>? ?? const [])
    .map((e) => ReportLine.fromJson(e as Map<String, dynamic>))
    .toList();

/// Profit & Loss statement for a period.
class PnlReport {
  final List<ReportLine> income;
  final List<ReportLine> expense;
  final double totalIncome;
  final double totalExpense;
  final double netProfit;

  const PnlReport({
    this.income = const [],
    this.expense = const [],
    this.totalIncome = 0,
    this.totalExpense = 0,
    this.netProfit = 0,
  });

  factory PnlReport.fromJson(Map<String, dynamic> j) => PnlReport(
        income: _lines(j['income']),
        expense: _lines(j['expense']),
        totalIncome: (j['totalIncome'] as num?)?.toDouble() ?? 0,
        totalExpense: (j['totalExpense'] as num?)?.toDouble() ?? 0,
        netProfit: (j['netProfit'] as num?)?.toDouble() ?? 0,
      );
}

/// Balance Sheet as of a date.
class BalanceSheetReport {
  final List<ReportLine> assets;
  final List<ReportLine> liabilities;
  final List<ReportLine> equity;
  final double retainedEarnings;
  final double totalAssets;
  final double totalLiabilities;
  final double totalEquity; // equity + retained earnings
  final double liabilitiesAndEquity;
  final bool balanced;

  const BalanceSheetReport({
    this.assets = const [],
    this.liabilities = const [],
    this.equity = const [],
    this.retainedEarnings = 0,
    this.totalAssets = 0,
    this.totalLiabilities = 0,
    this.totalEquity = 0,
    this.liabilitiesAndEquity = 0,
    this.balanced = false,
  });

  factory BalanceSheetReport.fromJson(Map<String, dynamic> j) => BalanceSheetReport(
        assets: _lines(j['assets']),
        liabilities: _lines(j['liabilities']),
        equity: _lines(j['equity']),
        retainedEarnings: (j['retainedEarnings'] as num?)?.toDouble() ?? 0,
        totalAssets: (j['totalAssets'] as num?)?.toDouble() ?? 0,
        totalLiabilities: (j['totalLiabilities'] as num?)?.toDouble() ?? 0,
        totalEquity: (j['totalEquity'] as num?)?.toDouble() ?? 0,
        liabilitiesAndEquity: (j['liabilitiesAndEquity'] as num?)?.toDouble() ?? 0,
        balanced: j['balanced'] as bool? ?? false,
      );
}
