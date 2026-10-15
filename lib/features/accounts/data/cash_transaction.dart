/// Accounts' own Cash In / Cash Out / Transfer entry (GET /cash-transactions).
double _d(dynamic v) => (v as num?)?.toDouble() ?? 0;
String _s(dynamic v) => v?.toString() ?? '';

/// A Chart of Accounts ledger as referenced by a transaction.
class TxnAccountRef {
  final String id;
  final String code;
  final String name;
  final String nature;
  final String accountType;
  const TxnAccountRef({
    required this.id,
    required this.code,
    required this.name,
    this.nature = '',
    this.accountType = '',
  });

  factory TxnAccountRef.fromJson(Map<String, dynamic> j) => TxnAccountRef(
        id: _s(j['_id']),
        code: _s(j['code']),
        name: _s(j['name']),
        nature: _s(j['nature']),
        accountType: _s(j['accountType']),
      );

  String get label => '$code · $name';
}

/// A Bank & Cash account (Bank Balance screen) as referenced by a transaction.
class TxnMoneyRef {
  final String id;
  final String name;
  final String kind; // bank | cash
  const TxnMoneyRef({required this.id, required this.name, this.kind = 'bank'});

  factory TxnMoneyRef.fromJson(Map<String, dynamic> j) =>
      TxnMoneyRef(id: _s(j['_id']), name: _s(j['name']), kind: _s(j['kind']) == 'cash' ? 'cash' : 'bank');
}

class CashTransaction {
  final String id;

  /// 'in' | 'out' | 'transfer'
  final String type;
  final DateTime date;
  final String department;
  final TxnAccountRef? account;
  final double amount;
  final String gstType; // none | gst | rcm
  final double gstAmount;
  final String paymentMode;
  final TxnMoneyRef? moneyAccount;
  final TxnMoneyRef? toMoneyAccount;
  final String paymentRef;
  final String party;
  final String reference;
  final String notes;
  final String createdByName;

  const CashTransaction({
    required this.id,
    required this.type,
    required this.date,
    this.department = '',
    this.account,
    this.amount = 0,
    this.gstType = 'none',
    this.gstAmount = 0,
    this.paymentMode = '',
    this.moneyAccount,
    this.toMoneyAccount,
    this.paymentRef = '',
    this.party = '',
    this.reference = '',
    this.notes = '',
    this.createdByName = '',
  });

  /// What actually left / reached the bank or cash account.
  double get total => type == 'out' && gstType == 'gst' ? amount + gstAmount : amount;

  factory CashTransaction.fromJson(Map<String, dynamic> j) {
    Map<String, dynamic>? m(dynamic v) => v is Map ? v.cast<String, dynamic>() : null;
    final acc = m(j['account']);
    final money = m(j['moneyAccount']);
    final to = m(j['toMoneyAccount']);
    return CashTransaction(
      id: _s(j['_id']),
      type: _s(j['type']),
      date: DateTime.tryParse(_s(j['date']))?.toLocal() ?? DateTime.now(),
      department: _s(j['department']),
      account: acc == null ? null : TxnAccountRef.fromJson(acc),
      amount: _d(j['amount']),
      gstType: _s(j['gstType']).isEmpty ? 'none' : _s(j['gstType']),
      gstAmount: _d(j['gstAmount']),
      paymentMode: _s(j['paymentMode']),
      moneyAccount: money == null ? null : TxnMoneyRef.fromJson(money),
      toMoneyAccount: to == null ? null : TxnMoneyRef.fromJson(to),
      paymentRef: _s(j['paymentRef']),
      party: _s(j['party']),
      reference: _s(j['reference']),
      notes: _s(j['notes']),
      createdByName: _s(j['createdByName']),
    );
  }
}

class CashTxnTotals {
  final double moneyIn;
  final double moneyOut;
  final double net;
  final double transfer;
  final int count;
  const CashTxnTotals({this.moneyIn = 0, this.moneyOut = 0, this.net = 0, this.transfer = 0, this.count = 0});

  factory CashTxnTotals.fromJson(Map<String, dynamic>? j) => CashTxnTotals(
        moneyIn: _d(j?['in']),
        moneyOut: _d(j?['out']),
        net: _d(j?['net']),
        transfer: _d(j?['transfer']),
        count: (j?['count'] as num?)?.toInt() ?? 0,
      );
}

class CashTxnPage {
  final List<CashTransaction> rows;
  final CashTxnTotals totals;
  const CashTxnPage({required this.rows, required this.totals});
}

/// List filter (period + type + search).
typedef CashTxnFilter = ({String from, String to, String type, String search});
