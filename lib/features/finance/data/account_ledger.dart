/// One posting line in an account's ledger, with the running balance after it.
class LedgerRow {
  final DateTime? date;
  final String voucherNo;
  final String voucherType;
  final String narration;
  final double debit;
  final double credit;
  final double balance;
  final String balanceSide; // dr | cr

  const LedgerRow({
    this.date,
    this.voucherNo = '',
    this.voucherType = 'journal',
    this.narration = '',
    this.debit = 0,
    this.credit = 0,
    this.balance = 0,
    this.balanceSide = 'dr',
  });

  factory LedgerRow.fromJson(Map<String, dynamic> j) => LedgerRow(
        date: DateTime.tryParse(j['date']?.toString() ?? '')?.toLocal(),
        voucherNo: j['voucherNo'] as String? ?? '',
        voucherType: j['voucherType'] as String? ?? 'journal',
        narration: j['narration'] as String? ?? '',
        debit: (j['debit'] as num?)?.toDouble() ?? 0,
        credit: (j['credit'] as num?)?.toDouble() ?? 0,
        balance: (j['balance'] as num?)?.toDouble() ?? 0,
        balanceSide: j['balanceSide'] as String? ?? 'dr',
      );
}

/// A general-ledger account statement.
class AccountLedger {
  final String code;
  final String name;
  final String nature;
  final double openingBalance;
  final String openingSide;
  final List<LedgerRow> rows;
  final double totalDebit;
  final double totalCredit;
  final double closingBalance;
  final String closingSide;

  const AccountLedger({
    this.code = '',
    this.name = '',
    this.nature = '',
    this.openingBalance = 0,
    this.openingSide = 'dr',
    this.rows = const [],
    this.totalDebit = 0,
    this.totalCredit = 0,
    this.closingBalance = 0,
    this.closingSide = 'dr',
  });

  factory AccountLedger.fromJson(Map<String, dynamic> j) {
    final a = j['account'] as Map<String, dynamic>? ?? const {};
    return AccountLedger(
      code: a['code'] as String? ?? '',
      name: a['name'] as String? ?? '',
      nature: a['nature'] as String? ?? '',
      openingBalance: (j['openingBalance'] as num?)?.toDouble() ?? 0,
      openingSide: j['openingSide'] as String? ?? 'dr',
      rows: (j['rows'] as List<dynamic>? ?? const [])
          .map((e) => LedgerRow.fromJson(e as Map<String, dynamic>))
          .toList(),
      totalDebit: (j['totalDebit'] as num?)?.toDouble() ?? 0,
      totalCredit: (j['totalCredit'] as num?)?.toDouble() ?? 0,
      closingBalance: (j['closingBalance'] as num?)?.toDouble() ?? 0,
      closingSide: j['closingSide'] as String? ?? 'dr',
    );
  }
}
