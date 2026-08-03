double _d(dynamic v) => (v as num?)?.toDouble() ?? 0;
int _i(dynamic v) => (v as num?)?.toInt() ?? 0;

class PackageRow {
  final String package;
  final int count;
  final double revenue;
  final double advance;
  final double balance;
  final int cancellations;

  const PackageRow({
    required this.package,
    required this.count,
    required this.revenue,
    required this.advance,
    required this.balance,
    required this.cancellations,
  });

  factory PackageRow.fromJson(Map<String, dynamic> j) => PackageRow(
        package: j['package'] as String? ?? 'Unspecified',
        count: _i(j['count']),
        revenue: _d(j['revenue']),
        advance: _d(j['advance']),
        balance: _d(j['balance']),
        cancellations: _i(j['cancellations']),
      );
}

class DistrictRow {
  final String district;
  final int count;
  final double revenue;
  const DistrictRow(
      {required this.district, required this.count, required this.revenue});
  factory DistrictRow.fromJson(Map<String, dynamic> j) => DistrictRow(
        district: j['district'] as String? ?? 'Unspecified',
        count: _i(j['count']),
        revenue: _d(j['revenue']),
      );
}

class CancellationRow {
  final String customer;
  final String package;
  final String reason;
  const CancellationRow(
      {required this.customer, required this.package, required this.reason});
  factory CancellationRow.fromJson(Map<String, dynamic> j) => CancellationRow(
        customer: j['customer'] as String? ?? '—',
        package: j['package'] as String? ?? '—',
        reason: j['reason'] as String? ?? '—',
      );
}

class FinancialAnalystReport {
  final String month;
  // Sales
  final List<PackageRow> packageBreakdown;
  final int totalBookings;
  final double totalRevenue;
  final double totalAdvance;
  final double totalBalance;
  final double totalDiscounts;
  final int totalCancellations;
  final int enquiries;
  final Map<String, int> leadSource;
  final int forwardCount;
  final double forwardValue;
  // Customer Relations
  final int activeClients;
  final int newClients;
  final int repeatClients;
  final List<DistrictRow> districtBreakdown;
  final int referralLeads;
  final List<CancellationRow> cancellations;
  // Finance
  final double cashCollected;
  final double aging0to30;
  final double aging31to90;
  final double aging90plus;

  const FinancialAnalystReport({
    required this.month,
    required this.packageBreakdown,
    required this.totalBookings,
    required this.totalRevenue,
    required this.totalAdvance,
    required this.totalBalance,
    required this.totalDiscounts,
    required this.totalCancellations,
    required this.enquiries,
    required this.leadSource,
    required this.forwardCount,
    required this.forwardValue,
    required this.activeClients,
    required this.newClients,
    required this.repeatClients,
    required this.districtBreakdown,
    required this.referralLeads,
    required this.cancellations,
    required this.cashCollected,
    required this.aging0to30,
    required this.aging31to90,
    required this.aging90plus,
  });

  factory FinancialAnalystReport.fromJson(Map<String, dynamic> j) {
    final sales = (j['sales'] as Map<String, dynamic>?) ?? const {};
    final totals = (sales['totals'] as Map<String, dynamic>?) ?? const {};
    final fwd = (sales['forwardBookings'] as Map<String, dynamic>?) ?? const {};
    final cr = (j['customerRelations'] as Map<String, dynamic>?) ?? const {};
    final fin = (j['finance'] as Map<String, dynamic>?) ?? const {};
    final aging = (fin['receivablesAging'] as Map<String, dynamic>?) ?? const {};
    final ls = (sales['leadSource'] as Map<String, dynamic>?) ?? const {};

    return FinancialAnalystReport(
      month: j['month'] as String? ?? '',
      packageBreakdown: ((sales['packageBreakdown'] as List?) ?? const [])
          .map((e) => PackageRow.fromJson(e as Map<String, dynamic>))
          .toList(),
      totalBookings: _i(totals['totalBookings']),
      totalRevenue: _d(totals['totalRevenue']),
      totalAdvance: _d(totals['totalAdvance']),
      totalBalance: _d(totals['totalBalance']),
      totalDiscounts: _d(totals['totalDiscounts']),
      totalCancellations: _i(totals['totalCancellations']),
      enquiries: _i(sales['enquiries']),
      leadSource: ls.map((k, v) => MapEntry(k, _i(v))),
      forwardCount: _i(fwd['count']),
      forwardValue: _d(fwd['value']),
      activeClients: _i(cr['activeClients']),
      newClients: _i(cr['newClients']),
      repeatClients: _i(cr['repeatClients']),
      districtBreakdown: ((cr['districtBreakdown'] as List?) ?? const [])
          .map((e) => DistrictRow.fromJson(e as Map<String, dynamic>))
          .toList(),
      referralLeads: _i(cr['referralLeads']),
      cancellations: ((cr['cancellations'] as List?) ?? const [])
          .map((e) => CancellationRow.fromJson(e as Map<String, dynamic>))
          .toList(),
      cashCollected: _d(fin['cashCollected']),
      aging0to30: _d(aging['d0_30']),
      aging31to90: _d(aging['d31_90']),
      aging90plus: _d(aging['d90plus']),
    );
  }
}
