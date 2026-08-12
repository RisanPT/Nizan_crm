/// A bank or cash account eligible for reconciliation.
class BankAccountRef {
  final String id;
  final String code;
  final String name;
  final bool isBank;
  final bool isCash;

  const BankAccountRef({
    required this.id,
    required this.code,
    required this.name,
    this.isBank = false,
    this.isCash = false,
  });

  factory BankAccountRef.fromJson(Map<String, dynamic> j) => BankAccountRef(
        id: j['id'] as String? ?? j['_id'] as String? ?? '',
        code: j['code'] as String? ?? '',
        name: j['name'] as String? ?? '',
        isBank: j['isBank'] as bool? ?? false,
        isCash: j['isCash'] as bool? ?? false,
      );

  String get label => '$code · $name';
}

/// A matched statement-line ↔ ledger-voucher pair.
class MatchedPair {
  final String statementLineId;
  final String entryId;
  final DateTime? txnDate;
  final String description;
  final String refNo;
  final double amount;
  final String voucherNo;
  final DateTime? voucherDate;

  const MatchedPair({
    required this.statementLineId,
    required this.entryId,
    this.txnDate,
    this.description = '',
    this.refNo = '',
    this.amount = 0,
    this.voucherNo = '',
    this.voucherDate,
  });

  factory MatchedPair.fromJson(Map<String, dynamic> j) => MatchedPair(
        statementLineId: j['statementLineId'] as String? ?? '',
        entryId: j['entryId'] as String? ?? '',
        txnDate: DateTime.tryParse(j['txnDate']?.toString() ?? '')?.toLocal(),
        description: j['description'] as String? ?? '',
        refNo: j['refNo'] as String? ?? '',
        amount: (j['amount'] as num?)?.toDouble() ?? 0,
        voucherNo: j['voucherNo'] as String? ?? '',
        voucherDate: DateTime.tryParse(j['voucherDate']?.toString() ?? '')?.toLocal(),
      );
}

/// An unmatched line from the imported bank statement.
class StatementLine {
  final String id;
  final DateTime? txnDate;
  final String description;
  final String refNo;
  final double amount; // +ve = money in, -ve = money out
  final double? runningBalance;

  const StatementLine({
    required this.id,
    this.txnDate,
    this.description = '',
    this.refNo = '',
    this.amount = 0,
    this.runningBalance,
  });

  factory StatementLine.fromJson(Map<String, dynamic> j) => StatementLine(
        id: j['id'] as String? ?? j['_id'] as String? ?? '',
        txnDate: DateTime.tryParse(j['txnDate']?.toString() ?? '')?.toLocal(),
        description: j['description'] as String? ?? '',
        refNo: j['refNo'] as String? ?? '',
        amount: (j['amount'] as num?)?.toDouble() ?? 0,
        runningBalance: (j['runningBalance'] as num?)?.toDouble(),
      );
}

/// An unmatched ledger movement (a voucher touching this account).
class LedgerMovement {
  final String entryId;
  final DateTime? date;
  final String voucherNo;
  final String voucherType;
  final String narration;
  final double amount; // +ve = money in, -ve = money out

  const LedgerMovement({
    required this.entryId,
    this.date,
    this.voucherNo = '',
    this.voucherType = 'journal',
    this.narration = '',
    this.amount = 0,
  });

  factory LedgerMovement.fromJson(Map<String, dynamic> j) => LedgerMovement(
        entryId: j['entryId'] as String? ?? '',
        date: DateTime.tryParse(j['date']?.toString() ?? '')?.toLocal(),
        voucherNo: j['voucherNo'] as String? ?? '',
        voucherType: j['voucherType'] as String? ?? 'journal',
        narration: j['narration'] as String? ?? '',
        amount: (j['amount'] as num?)?.toDouble() ?? 0,
      );
}

/// The full reconciliation view for one account.
class Reconciliation {
  final String accountId;
  final String accountCode;
  final String accountName;
  final double bookClosing;
  final double? statementClosing;
  final List<MatchedPair> matched;
  final List<StatementLine> unmatchedStatement;
  final List<LedgerMovement> unmatchedLedger;

  final int statementCount;
  final int ledgerCount;
  final double unmatchedStatementNet;
  final double unmatchedLedgerNet;
  final double expectedStatementClosing;
  final double? difference;
  final bool reconciled;

  const Reconciliation({
    this.accountId = '',
    this.accountCode = '',
    this.accountName = '',
    this.bookClosing = 0,
    this.statementClosing,
    this.matched = const [],
    this.unmatchedStatement = const [],
    this.unmatchedLedger = const [],
    this.statementCount = 0,
    this.ledgerCount = 0,
    this.unmatchedStatementNet = 0,
    this.unmatchedLedgerNet = 0,
    this.expectedStatementClosing = 0,
    this.difference,
    this.reconciled = false,
  });

  factory Reconciliation.fromJson(Map<String, dynamic> j) {
    final acc = j['account'] as Map<String, dynamic>? ?? const {};
    final t = j['totals'] as Map<String, dynamic>? ?? const {};
    List<T> list<T>(dynamic v, T Function(Map<String, dynamic>) f) =>
        (v as List<dynamic>? ?? const [])
            .map((e) => f(e as Map<String, dynamic>))
            .toList();
    return Reconciliation(
      accountId: acc['id'] as String? ?? '',
      accountCode: acc['code'] as String? ?? '',
      accountName: acc['name'] as String? ?? '',
      bookClosing: (j['bookClosing'] as num?)?.toDouble() ?? 0,
      statementClosing: (j['statementClosing'] as num?)?.toDouble(),
      matched: list(j['matched'], MatchedPair.fromJson),
      unmatchedStatement: list(j['unmatchedStatement'], StatementLine.fromJson),
      unmatchedLedger: list(j['unmatchedLedger'], LedgerMovement.fromJson),
      statementCount: (t['statementCount'] as num?)?.toInt() ?? 0,
      ledgerCount: (t['ledgerCount'] as num?)?.toInt() ?? 0,
      unmatchedStatementNet: (t['unmatchedStatementNet'] as num?)?.toDouble() ?? 0,
      unmatchedLedgerNet: (t['unmatchedLedgerNet'] as num?)?.toDouble() ?? 0,
      expectedStatementClosing: (t['expectedStatementClosing'] as num?)?.toDouble() ?? 0,
      difference: (t['difference'] as num?)?.toDouble(),
      reconciled: t['reconciled'] as bool? ?? false,
    );
  }
}

/// Result of an import call.
class ImportResult {
  final int imported;
  final int duplicates;
  final int invalid;
  final int total;

  const ImportResult({
    this.imported = 0,
    this.duplicates = 0,
    this.invalid = 0,
    this.total = 0,
  });

  factory ImportResult.fromJson(Map<String, dynamic> j) => ImportResult(
        imported: (j['imported'] as num?)?.toInt() ?? 0,
        duplicates: (j['duplicates'] as num?)?.toInt() ?? 0,
        invalid: (j['invalid'] as num?)?.toInt() ?? 0,
        total: (j['total'] as num?)?.toInt() ?? 0,
      );
}
