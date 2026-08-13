/// One grouped row of a sales report (a customer / package / salesperson /
/// date / payment mode). All five reports share this uniform shape.
class SalesRow {
  final String label;
  final String sublabel;
  final int count;
  final double amount;
  final double received;
  final double outstanding;

  const SalesRow({
    this.label = '',
    this.sublabel = '',
    this.count = 0,
    this.amount = 0,
    this.received = 0,
    this.outstanding = 0,
  });

  factory SalesRow.fromJson(Map<String, dynamic> j) => SalesRow(
        label: j['label'] as String? ?? '',
        sublabel: j['sublabel'] as String? ?? '',
        count: (j['count'] as num?)?.toInt() ?? 0,
        amount: (j['amount'] as num?)?.toDouble() ?? 0,
        received: (j['received'] as num?)?.toDouble() ?? 0,
        outstanding: (j['outstanding'] as num?)?.toDouble() ?? 0,
      );
}

class SalesReport {
  final List<SalesRow> rows;
  final int totalCount;
  final double totalAmount;
  final double totalReceived;
  final String groupBy; // for the date-wise summary: 'day' | 'month'

  const SalesReport({
    this.rows = const [],
    this.totalCount = 0,
    this.totalAmount = 0,
    this.totalReceived = 0,
    this.groupBy = '',
  });

  factory SalesReport.fromJson(Map<String, dynamic> j) {
    final t = j['totals'] as Map<String, dynamic>? ?? const {};
    return SalesReport(
      rows: (j['rows'] as List<dynamic>? ?? const [])
          .map((e) => SalesRow.fromJson(e as Map<String, dynamic>))
          .toList(),
      totalCount: (t['count'] as num?)?.toInt() ?? 0,
      totalAmount: (t['amount'] as num?)?.toDouble() ?? 0,
      totalReceived: (t['received'] as num?)?.toDouble() ?? 0,
      groupBy: j['groupBy'] as String? ?? '',
    );
  }
}
