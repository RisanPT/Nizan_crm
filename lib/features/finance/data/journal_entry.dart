/// One posting line of a journal entry (a single account debited or credited).
class JournalLine {
  final String accountId;
  final String accountCode;
  final String accountName;
  final double debit;
  final double credit;
  final String narration;

  const JournalLine({
    required this.accountId,
    this.accountCode = '',
    this.accountName = '',
    this.debit = 0,
    this.credit = 0,
    this.narration = '',
  });

  factory JournalLine.fromJson(Map<String, dynamic> j) {
    final acc = j['account'];
    return JournalLine(
      accountId: acc is Map ? (acc['_id'] as String? ?? '') : (acc as String? ?? ''),
      accountCode: acc is Map ? (acc['code'] as String? ?? '') : '',
      accountName: acc is Map ? (acc['name'] as String? ?? '') : '',
      debit: (j['debit'] as num?)?.toDouble() ?? 0,
      credit: (j['credit'] as num?)?.toDouble() ?? 0,
      narration: j['narration'] as String? ?? '',
    );
  }
}

/// A balanced double-entry voucher.
class JournalEntry {
  final String id;
  final DateTime date;
  final String voucherNo;
  final String voucherType;
  final String narration;
  final List<JournalLine> lines;
  final String status; // draft | posted | void
  final String fyLabel;

  const JournalEntry({
    required this.id,
    required this.date,
    this.voucherNo = '',
    this.voucherType = 'journal',
    this.narration = '',
    this.lines = const [],
    this.status = 'posted',
    this.fyLabel = '',
  });

  double get totalDebit => lines.fold(0, (a, l) => a + l.debit);
  double get totalCredit => lines.fold(0, (a, l) => a + l.credit);

  factory JournalEntry.fromJson(Map<String, dynamic> j) => JournalEntry(
        id: j['_id'] as String? ?? j['id'] as String? ?? '',
        date: DateTime.tryParse(j['date']?.toString() ?? '')?.toLocal() ?? DateTime.now(),
        voucherNo: j['voucherNo'] as String? ?? '',
        voucherType: j['voucherType'] as String? ?? 'journal',
        narration: j['narration'] as String? ?? '',
        lines: (j['lines'] as List<dynamic>? ?? const [])
            .map((e) => JournalLine.fromJson(e as Map<String, dynamic>))
            .toList(),
        status: j['status'] as String? ?? 'posted',
        fyLabel: j['fyLabel'] as String? ?? '',
      );
}

const kVoucherTypes = <String>[
  'journal',
  'sales',
  'purchase',
  'receipt',
  'payment',
  'contra',
  'credit_note',
  'debit_note',
];

String voucherTypeLabel(String t) {
  switch (t) {
    case 'journal':
      return 'Journal';
    case 'sales':
      return 'Sales';
    case 'purchase':
      return 'Purchase';
    case 'receipt':
      return 'Receipt';
    case 'payment':
      return 'Payment';
    case 'contra':
      return 'Contra';
    case 'credit_note':
      return 'Credit Note';
    case 'debit_note':
      return 'Debit Note';
    default:
      return t;
  }
}

/// A row of the Trial Balance.
class TrialBalanceRow {
  final String accountId;
  final String code;
  final String name;
  final String nature;
  final String group;
  final double closingDebit;
  final double closingCredit;

  const TrialBalanceRow({
    this.accountId = '',
    required this.code,
    required this.name,
    required this.nature,
    this.group = '',
    this.closingDebit = 0,
    this.closingCredit = 0,
  });

  factory TrialBalanceRow.fromJson(Map<String, dynamic> j) => TrialBalanceRow(
        accountId: j['accountId'] as String? ?? '',
        code: j['code'] as String? ?? '',
        name: j['name'] as String? ?? '',
        nature: j['nature'] as String? ?? '',
        group: j['group'] as String? ?? '',
        closingDebit: (j['closingDebit'] as num?)?.toDouble() ?? 0,
        closingCredit: (j['closingCredit'] as num?)?.toDouble() ?? 0,
      );
}

class TrialBalance {
  final List<TrialBalanceRow> rows;
  final double totalDebit;
  final double totalCredit;
  final bool balanced;

  const TrialBalance({
    this.rows = const [],
    this.totalDebit = 0,
    this.totalCredit = 0,
    this.balanced = true,
  });

  factory TrialBalance.fromJson(Map<String, dynamic> j) => TrialBalance(
        rows: (j['rows'] as List<dynamic>? ?? const [])
            .map((e) => TrialBalanceRow.fromJson(e as Map<String, dynamic>))
            .toList(),
        totalDebit: (j['totalDebit'] as num?)?.toDouble() ?? 0,
        totalCredit: (j['totalCredit'] as num?)?.toDouble() ?? 0,
        balanced: j['balanced'] as bool? ?? false,
      );
}
