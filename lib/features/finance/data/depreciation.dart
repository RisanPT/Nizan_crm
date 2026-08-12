/// One asset's depreciation line in the schedule as-of a date.
class DepreciationRow {
  final String assetId;
  final String name;
  final String assetType;
  final String category;
  final String method;
  final double rate;
  final double usefulLifeYears;
  final double cost;
  final double salvageValue;
  final double currentAccumulated;
  final double targetAccumulated;
  final double periodDepreciation; // what a run would post now
  final double bookValue;
  final DateTime? depreciationStart;
  final bool fullyDepreciated;

  const DepreciationRow({
    required this.assetId,
    required this.name,
    this.assetType = '',
    this.category = '',
    this.method = 'straight_line',
    this.rate = 0,
    this.usefulLifeYears = 0,
    this.cost = 0,
    this.salvageValue = 0,
    this.currentAccumulated = 0,
    this.targetAccumulated = 0,
    this.periodDepreciation = 0,
    this.bookValue = 0,
    this.depreciationStart,
    this.fullyDepreciated = false,
  });

  factory DepreciationRow.fromJson(Map<String, dynamic> j) => DepreciationRow(
        assetId: j['assetId'] as String? ?? '',
        name: j['name'] as String? ?? '',
        assetType: j['assetType'] as String? ?? '',
        category: j['category'] as String? ?? '',
        method: j['method'] as String? ?? 'straight_line',
        rate: (j['rate'] as num?)?.toDouble() ?? 0,
        usefulLifeYears: (j['usefulLifeYears'] as num?)?.toDouble() ?? 0,
        cost: (j['cost'] as num?)?.toDouble() ?? 0,
        salvageValue: (j['salvageValue'] as num?)?.toDouble() ?? 0,
        currentAccumulated: (j['currentAccumulated'] as num?)?.toDouble() ?? 0,
        targetAccumulated: (j['targetAccumulated'] as num?)?.toDouble() ?? 0,
        periodDepreciation: (j['periodDepreciation'] as num?)?.toDouble() ?? 0,
        bookValue: (j['bookValue'] as num?)?.toDouble() ?? 0,
        depreciationStart: DateTime.tryParse(j['depreciationStart']?.toString() ?? '')?.toLocal(),
        fullyDepreciated: j['fullyDepreciated'] as bool? ?? false,
      );
}

class DepreciationTotals {
  final int count;
  final double totalCost;
  final double totalAccumulated;
  final double totalPeriodDepreciation;
  final double totalBookValue;

  const DepreciationTotals({
    this.count = 0,
    this.totalCost = 0,
    this.totalAccumulated = 0,
    this.totalPeriodDepreciation = 0,
    this.totalBookValue = 0,
  });

  factory DepreciationTotals.fromJson(Map<String, dynamic> j) => DepreciationTotals(
        count: (j['count'] as num?)?.toInt() ?? 0,
        totalCost: (j['totalCost'] as num?)?.toDouble() ?? 0,
        totalAccumulated: (j['totalAccumulated'] as num?)?.toDouble() ?? 0,
        totalPeriodDepreciation: (j['totalPeriodDepreciation'] as num?)?.toDouble() ?? 0,
        totalBookValue: (j['totalBookValue'] as num?)?.toDouble() ?? 0,
      );
}

class DepreciationSchedule {
  final DateTime? asOf;
  final List<DepreciationRow> rows;
  final DepreciationTotals totals;

  const DepreciationSchedule({
    this.asOf,
    this.rows = const [],
    this.totals = const DepreciationTotals(),
  });

  factory DepreciationSchedule.fromJson(Map<String, dynamic> j) => DepreciationSchedule(
        asOf: DateTime.tryParse(j['asOf']?.toString() ?? '')?.toLocal(),
        rows: (j['rows'] as List<dynamic>? ?? const [])
            .map((e) => DepreciationRow.fromJson(e as Map<String, dynamic>))
            .toList(),
        totals: DepreciationTotals.fromJson(j['totals'] as Map<String, dynamic>? ?? const {}),
      );
}

/// Result of posting a depreciation run.
class DepreciationRunResult {
  final bool posted;
  final double total;
  final int assetsAffected;
  final String voucherNo;
  final String message;

  const DepreciationRunResult({
    this.posted = false,
    this.total = 0,
    this.assetsAffected = 0,
    this.voucherNo = '',
    this.message = '',
  });

  factory DepreciationRunResult.fromJson(Map<String, dynamic> j) => DepreciationRunResult(
        posted: j['posted'] as bool? ?? false,
        total: (j['total'] as num?)?.toDouble() ?? 0,
        assetsAffected: (j['assetsAffected'] as num?)?.toInt() ?? 0,
        voucherNo: j['voucherNo'] as String? ?? '',
        message: j['message'] as String? ?? '',
      );
}

/// A row of the run history.
class DepreciationRunSummary {
  final String id;
  final DateTime? periodEnd;
  final double totalAmount;
  final int assetsAffected;
  final String voucherNo;

  const DepreciationRunSummary({
    required this.id,
    this.periodEnd,
    this.totalAmount = 0,
    this.assetsAffected = 0,
    this.voucherNo = '',
  });

  factory DepreciationRunSummary.fromJson(Map<String, dynamic> j) => DepreciationRunSummary(
        id: j['id'] as String? ?? '',
        periodEnd: DateTime.tryParse(j['periodEnd']?.toString() ?? '')?.toLocal(),
        totalAmount: (j['totalAmount'] as num?)?.toDouble() ?? 0,
        assetsAffected: (j['assetsAffected'] as num?)?.toInt() ?? 0,
        voucherNo: j['voucherNo'] as String? ?? '',
      );
}
