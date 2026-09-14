// A statutory return (GST/TDS) tracked for compliance.
class TaxFiling {
  final String id;
  final String type; // gstr1 | gstr3b | tds_payment | tds_return
  final String label;
  final int periodMonth, periodYear;
  final DateTime? dueDate, filedDate;
  final String status; // pending | overdue | filed
  final String arn, notes;
  final double? amount;

  const TaxFiling({
    this.id = '',
    required this.type,
    required this.label,
    required this.periodMonth,
    required this.periodYear,
    this.dueDate,
    this.filedDate,
    this.status = 'pending',
    this.arn = '',
    this.notes = '',
    this.amount,
  });

  bool get isFiled => status == 'filed';
  bool get isOverdue => status == 'overdue';

  static DateTime? _dt(dynamic v) =>
      v == null ? null : DateTime.tryParse(v.toString())?.toLocal();

  factory TaxFiling.fromJson(Map<String, dynamic> j) => TaxFiling(
        id: j['id'] as String? ?? j['_id'] as String? ?? '',
        type: j['type'] as String? ?? '',
        label: j['label'] as String? ?? '',
        periodMonth: (j['periodMonth'] as num?)?.toInt() ?? 1,
        periodYear: (j['periodYear'] as num?)?.toInt() ?? 0,
        dueDate: _dt(j['dueDate']),
        filedDate: _dt(j['filedDate']),
        status: j['status'] as String? ?? 'pending',
        arn: j['arn'] as String? ?? '',
        notes: j['notes'] as String? ?? '',
        amount: (j['amount'] as num?)?.toDouble(),
      );
}

/// The `/tax-filings` payload: the selected period's filings + an overdue
/// watchlist from prior periods + a summary.
class TaxFilingBoard {
  final int month, year;
  final List<TaxFiling> filings;
  final List<TaxFiling> overdue;
  final int summaryOverdue, summaryPending, summaryFiled;

  const TaxFilingBoard({
    required this.month,
    required this.year,
    this.filings = const [],
    this.overdue = const [],
    this.summaryOverdue = 0,
    this.summaryPending = 0,
    this.summaryFiled = 0,
  });

  factory TaxFilingBoard.fromJson(Map<String, dynamic> j) {
    final period = j['period'] as Map<String, dynamic>? ?? const {};
    final summary = j['summary'] as Map<String, dynamic>? ?? const {};
    List<TaxFiling> list(dynamic v) => (v as List<dynamic>? ?? const [])
        .map((e) => TaxFiling.fromJson(e as Map<String, dynamic>))
        .toList();
    return TaxFilingBoard(
      month: (period['month'] as num?)?.toInt() ?? 1,
      year: (period['year'] as num?)?.toInt() ?? 0,
      filings: list(j['filings']),
      overdue: list(j['overdue']),
      summaryOverdue: (summary['overdue'] as num?)?.toInt() ?? 0,
      summaryPending: (summary['pending'] as num?)?.toInt() ?? 0,
      summaryFiled: (summary['filed'] as num?)?.toInt() ?? 0,
    );
  }
}
