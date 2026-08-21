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

/// A manually-maintained bank account balance.
class BankAccount {
  final String id;
  final String name;
  final String bankName;
  final String accountNumber;
  final double balance;
  final DateTime? asOf;
  final String note;
  final bool active;
  final List<BalanceEntry> history;

  const BankAccount({
    required this.id,
    required this.name,
    this.bankName = '',
    this.accountNumber = '',
    this.balance = 0,
    this.asOf,
    this.note = '',
    this.active = true,
    this.history = const [],
  });

  factory BankAccount.fromJson(Map<String, dynamic> j) => BankAccount(
        id: j['_id']?.toString() ?? j['id']?.toString() ?? '',
        name: j['name']?.toString() ?? '',
        bankName: j['bankName']?.toString() ?? '',
        accountNumber: j['accountNumber']?.toString() ?? '',
        balance: (j['balance'] as num?)?.toDouble() ?? 0,
        asOf: DateTime.tryParse(j['asOf']?.toString() ?? ''),
        note: j['note']?.toString() ?? '',
        active: j['active'] != false,
        history: ((j['history'] as List?) ?? const [])
            .map((e) => BalanceEntry.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
      );

  String get maskedAccount {
    final a = accountNumber.trim();
    if (a.length <= 4) return a;
    return '•••• ${a.substring(a.length - 4)}';
  }
}
