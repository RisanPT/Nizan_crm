/// One manual balance update in an account's history.
class BalanceEntry {
  final double balance;
  final DateTime asOf;
  final String note;
  final String byName;
  final DateTime? at;

  const BalanceEntry({
    required this.balance,
    required this.asOf,
    this.note = '',
    this.byName = '',
    this.at,
  });

  factory BalanceEntry.fromJson(Map<String, dynamic> j) => BalanceEntry(
        balance: (j['balance'] as num?)?.toDouble() ?? 0,
        asOf: DateTime.tryParse(j['asOf']?.toString() ?? '') ?? DateTime.now(),
        note: j['note']?.toString() ?? '',
        byName: j['byName']?.toString() ?? '',
        at: DateTime.tryParse(j['createdAt']?.toString() ?? j['at']?.toString() ?? ''),
      );
}

/// The Chart of Accounts ledger a bank / cash account is linked to.
class BankLedgerRef {
  final String id;
  final String code;
  final String name;
  const BankLedgerRef({required this.id, required this.code, required this.name});

  factory BankLedgerRef.fromJson(Map<String, dynamic> j) => BankLedgerRef(
        id: j['_id']?.toString() ?? '',
        code: j['code']?.toString() ?? '',
        name: j['name']?.toString() ?? '',
      );

  String get label => '$code · $name';
}

/// Ledger receipts / payments after the latest manual balance.
class LedgerMovement {
  final double moneyIn;
  final double moneyOut;
  final int count;
  const LedgerMovement({this.moneyIn = 0, this.moneyOut = 0, this.count = 0});

  factory LedgerMovement.fromJson(Map<String, dynamic> j) => LedgerMovement(
        moneyIn: (j['in'] as num?)?.toDouble() ?? 0,
        moneyOut: (j['out'] as num?)?.toDouble() ?? 0,
        count: (j['count'] as num?)?.toInt() ?? 0,
      );
}

/// A bank or cash-in-hand account. [balance] / [asOf] is the latest manually
/// entered closing balance; when linked to a ledger, [currentBalance] adds the
/// ledger's receipts and payments dated after that day.
class BankAccount {
  final String id;
  final String name;

  /// 'bank' | 'cash'
  final String kind;
  final String bankName;
  final String accountNumber;
  final double balance;
  final DateTime? asOf;
  final String note;
  final bool active;
  final List<BalanceEntry> history;
  final BankLedgerRef? ledger;
  final LedgerMovement? movement;
  final double currentBalance;

  const BankAccount({
    required this.id,
    required this.name,
    this.kind = 'bank',
    this.bankName = '',
    this.accountNumber = '',
    this.balance = 0,
    this.asOf,
    this.note = '',
    this.active = true,
    this.history = const [],
    this.ledger,
    this.movement,
    this.currentBalance = 0,
  });

  bool get isCash => kind == 'cash';
  bool get isLinked => ledger != null;

  factory BankAccount.fromJson(Map<String, dynamic> j) {
    final balance = (j['balance'] as num?)?.toDouble() ?? 0;
    final ledger = j['ledger'];
    final movement = j['movement'];
    return BankAccount(
      id: j['_id']?.toString() ?? j['id']?.toString() ?? '',
      name: j['name']?.toString() ?? '',
      kind: j['kind']?.toString() == 'cash' ? 'cash' : 'bank',
      bankName: j['bankName']?.toString() ?? '',
      accountNumber: j['accountNumber']?.toString() ?? '',
      balance: balance,
      asOf: DateTime.tryParse(j['asOf']?.toString() ?? ''),
      note: j['note']?.toString() ?? '',
      active: j['active'] != false,
      history: ((j['history'] as List?) ?? const [])
          .map((e) => BalanceEntry.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
      ledger: ledger is Map ? BankLedgerRef.fromJson(ledger.cast<String, dynamic>()) : null,
      movement: movement is Map ? LedgerMovement.fromJson(movement.cast<String, dynamic>()) : null,
      currentBalance: (j['currentBalance'] as num?)?.toDouble() ?? balance,
    );
  }

  String get maskedAccount {
    final a = accountNumber.trim();
    if (a.length <= 4) return a;
    return '•••• ${a.substring(a.length - 4)}';
  }
}

/// A Cash / Bank ledger that an account can be linked to.
class LedgerOption {
  final String id;
  final String code;
  final String name;

  /// 'cash' | 'bank'
  final String accountType;

  /// Name of the account already using this ledger ('' = free).
  final String linkedTo;

  const LedgerOption({
    required this.id,
    required this.code,
    required this.name,
    required this.accountType,
    this.linkedTo = '',
  });

  factory LedgerOption.fromJson(Map<String, dynamic> j) => LedgerOption(
        id: j['_id']?.toString() ?? '',
        code: j['code']?.toString() ?? '',
        name: j['name']?.toString() ?? '',
        accountType: j['accountType']?.toString() ?? '',
        linkedTo: j['linkedTo']?.toString() ?? '',
      );

  String get label => '$code · $name';
}

/// One ledger movement on a linked account (Transactions sheet).
class BankTxn {
  final DateTime? date;
  final String voucherNo;
  final String narration;
  final String source;
  final double moneyIn;
  final double moneyOut;
  final double balance;

  const BankTxn({
    this.date,
    this.voucherNo = '',
    this.narration = '',
    this.source = '',
    this.moneyIn = 0,
    this.moneyOut = 0,
    this.balance = 0,
  });

  factory BankTxn.fromJson(Map<String, dynamic> j) => BankTxn(
        date: DateTime.tryParse(j['date']?.toString() ?? ''),
        voucherNo: j['voucherNo']?.toString() ?? '',
        narration: j['narration']?.toString() ?? '',
        source: j['source']?.toString() ?? '',
        moneyIn: (j['in'] as num?)?.toDouble() ?? 0,
        moneyOut: (j['out'] as num?)?.toDouble() ?? 0,
        balance: (j['balance'] as num?)?.toDouble() ?? 0,
      );
}

class BankTxnResult {
  final DateTime? since;
  final double opening;
  final double closing;
  final List<BankTxn> rows;
  const BankTxnResult({this.since, this.opening = 0, this.closing = 0, this.rows = const []});

  factory BankTxnResult.fromJson(Map<String, dynamic> j) => BankTxnResult(
        since: DateTime.tryParse(j['since']?.toString() ?? ''),
        opening: (j['opening'] as num?)?.toDouble() ?? 0,
        closing: (j['closing'] as num?)?.toDouble() ?? 0,
        rows: ((j['rows'] as List?) ?? const [])
            .map((e) => BankTxn.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
      );
}
