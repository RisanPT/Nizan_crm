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

  /// What it held at the end of last month — null when no balance had been entered by then.
  final double? previousBalance;

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
    this.previousBalance,
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
      previousBalance: (j['previousBalance'] as num?)?.toDouble(),
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

/// The totals at the end of last month, to compare today's with — each null when an account in it
/// had no balance entered by then.
class PreviousBalances {
  /// 'YYYY-MM-DD' — the last day of the month before this one.
  final String asOf;
  final double? total;
  final double? bank;
  final double? cash;
  const PreviousBalances({this.asOf = '', this.total, this.bank, this.cash});

  factory PreviousBalances.fromJson(Map<String, dynamic> j) => PreviousBalances(
        asOf: j['asOf']?.toString() ?? '',
        total: (j['total'] as num?)?.toDouble(),
        bank: (j['bank'] as num?)?.toDouble(),
        cash: (j['cash'] as num?)?.toDouble(),
      );
}

/// How far [now] is from [before], in percent of [before]; null when there is nothing to compare with.
double? percentChange(double now, double? before) {
  if (before == null || before == 0) return null;
  return (now - before) / before.abs() * 100;
}

/// Who is behind a transaction: the artist, driver or employee.
class TxnPerson {
  final String id;
  final String name;

  /// 'Artist' | 'Driver' | 'Employee' | 'Collected by' | 'Paid by'
  final String role;
  const TxnPerson({this.id = '', required this.name, this.role = ''});
}

/// One line of an account's statement: money in or out, the balance after it, and WHAT IT WAS FOR
/// (described by the server from the record the voucher was posted from).
class BankTxn {
  final String id;
  final DateTime? date;
  final String voucherNo;
  final String voucherType;
  final String narration;
  final String source;
  final double moneyIn;
  final double moneyOut;

  /// The account's balance after this line — null when it is dated before the first balance entered.
  final double? balance;

  /// 'collection' | 'artist_expense' | 'fleet' | 'admin_expense' | 'salary' | 'transfer' | 'journal' …
  final String kind;
  final String kindLabel;
  final String category;
  final String categoryLabel;

  /// What the list is filtered by ("Artist expense · Food") and its key.
  final String group;
  final String groupLabel;

  /// The name to read first (the client, the payee, the vehicle…).
  final String title;
  final String particulars;
  final TxnPerson? person;
  final String personKey;
  final String client;
  final String bookingNumber;
  final DateTime? workDate;
  final String paymentMode;
  final String reference;
  final String notes;
  final String status;

  /// An expense approved for less: what the artist logged ([moneyOut] is what was approved).
  final double? loggedAmount;
  final String attachmentUrl;

  /// Everything known about it, in reading order.
  final List<({String label, String value})> details;

  const BankTxn({
    this.id = '',
    this.date,
    this.voucherNo = '',
    this.voucherType = '',
    this.narration = '',
    this.source = '',
    this.moneyIn = 0,
    this.moneyOut = 0,
    this.balance,
    this.kind = '',
    this.kindLabel = '',
    this.category = '',
    this.categoryLabel = '',
    this.group = '',
    this.groupLabel = '',
    this.title = '',
    this.particulars = '',
    this.person,
    this.personKey = '',
    this.client = '',
    this.bookingNumber = '',
    this.workDate,
    this.paymentMode = '',
    this.reference = '',
    this.notes = '',
    this.status = '',
    this.loggedAmount,
    this.attachmentUrl = '',
    this.details = const [],
  });

  bool get isIn => moneyIn > 0;

  /// Positive in, negative out.
  double get signed => isIn ? moneyIn : -moneyOut;

  /// What it is, in words: the server's description, else the voucher's narration.
  String get heading => particulars.isNotEmpty ? particulars : (narration.isNotEmpty ? narration : voucherNo);

  /// Who and which work, on one line: "Megha · BK-100 · by Asha" for money in,
  /// "Asha · Megha · BK-100" for money out. Nothing is said twice.
  String get whoLine {
    final by = person?.name ?? '';
    final parts = isIn
        ? [title, bookingNumber, if (by.isNotEmpty) 'by $by']
        : [by, title, bookingNumber];
    final seen = <String>{};
    return [
      for (final p in parts)
        if (p.trim().isNotEmpty && p != heading && seen.add(p.replaceFirst('by ', '').toLowerCase())) p,
    ].join(' · ');
  }

  factory BankTxn.fromJson(Map<String, dynamic> j) {
    final p = j['person'];
    return BankTxn(
      id: j['id']?.toString() ?? '',
      date: DateTime.tryParse(j['date']?.toString() ?? ''),
      voucherNo: j['voucherNo']?.toString() ?? '',
      voucherType: j['voucherType']?.toString() ?? '',
      narration: j['narration']?.toString() ?? '',
      source: j['source']?.toString() ?? '',
      moneyIn: (j['in'] as num?)?.toDouble() ?? 0,
      moneyOut: (j['out'] as num?)?.toDouble() ?? 0,
      balance: (j['balance'] as num?)?.toDouble(),
      kind: j['kind']?.toString() ?? '',
      kindLabel: j['kindLabel']?.toString() ?? '',
      category: j['category']?.toString() ?? '',
      categoryLabel: j['categoryLabel']?.toString() ?? '',
      group: j['group']?.toString() ?? '',
      groupLabel: j['groupLabel']?.toString() ?? '',
      title: j['title']?.toString() ?? '',
      particulars: j['particulars']?.toString() ?? '',
      person: p is Map && (p['name']?.toString() ?? '').isNotEmpty
          ? TxnPerson(id: p['id']?.toString() ?? '', name: p['name'].toString(), role: p['role']?.toString() ?? '')
          : null,
      personKey: j['personKey']?.toString() ?? '',
      client: j['client']?.toString() ?? '',
      bookingNumber: j['bookingNumber']?.toString() ?? '',
      workDate: DateTime.tryParse(j['workDate']?.toString() ?? ''),
      paymentMode: j['paymentMode']?.toString() ?? '',
      reference: j['reference']?.toString() ?? '',
      notes: j['notes']?.toString() ?? '',
      status: j['status']?.toString() ?? '',
      loggedAmount: (j['loggedAmount'] as num?)?.toDouble(),
      attachmentUrl: j['attachmentUrl']?.toString() ?? '',
      details: [
        for (final d in (j['details'] as List? ?? const []))
          if (d is Map) (label: d['label']?.toString() ?? '', value: d['value']?.toString() ?? ''),
      ],
    );
  }
}

/// Money in, money out and how many.
class TxnTotals {
  final double moneyIn;
  final double moneyOut;
  final int count;
  const TxnTotals({this.moneyIn = 0, this.moneyOut = 0, this.count = 0});
  double get net => moneyIn - moneyOut;

  factory TxnTotals.fromJson(Map<String, dynamic> j) => TxnTotals(
        moneyIn: (j['in'] as num?)?.toDouble() ?? 0,
        moneyOut: (j['out'] as num?)?.toDouble() ?? 0,
        count: (j['count'] as num?)?.toInt() ?? 0,
      );
}

/// Something the statement can be narrowed to: a category or a person.
typedef TxnFacet = ({String key, String label, int count});

/// A page of an account's statement.
class BankTxnResult {
  /// The day of the balance the list starts after — null when a date range was asked for.
  final DateTime? since;

  /// The balance before the first row and after the last — null when it cannot be known.
  final double? opening;
  final double? closing;
  final List<BankTxn> rows;
  final int page;
  final int limit;
  final int totalItems;
  final int totalPages;

  /// Of what matches the filters, and of everything in the period.
  final TxnTotals totals;
  final TxnTotals allTotals;
  final List<TxnFacet> groups;
  final List<TxnFacet> people;

  /// More transactions matched than can be read at once.
  final bool truncated;

  const BankTxnResult({
    this.since,
    this.opening,
    this.closing,
    this.rows = const [],
    this.page = 1,
    this.limit = 25,
    this.totalItems = 0,
    this.totalPages = 1,
    this.totals = const TxnTotals(),
    this.allTotals = const TxnTotals(),
    this.groups = const [],
    this.people = const [],
    this.truncated = false,
  });

  factory BankTxnResult.fromJson(Map<String, dynamic> j) {
    final rows = ((j['rows'] as List?) ?? const []).map((e) => BankTxn.fromJson((e as Map).cast<String, dynamic>())).toList();
    final facets = (j['facets'] as Map?) ?? const {};
    List<TxnFacet> facet(String key, String labelField) => [
          for (final f in (facets[key] as List? ?? const []))
            if (f is Map) (key: f['key']?.toString() ?? '', label: f[labelField]?.toString() ?? '', count: (f['count'] as num?)?.toInt() ?? 0),
        ];
    return BankTxnResult(
      since: DateTime.tryParse(j['since']?.toString() ?? ''),
      opening: (j['opening'] as num?)?.toDouble(),
      closing: (j['closing'] as num?)?.toDouble(),
      rows: rows,
      page: (j['page'] as num?)?.toInt() ?? 1,
      limit: (j['limit'] as num?)?.toInt() ?? rows.length,
      totalItems: (j['totalItems'] as num?)?.toInt() ?? rows.length,
      totalPages: (j['totalPages'] as num?)?.toInt() ?? 1,
      totals: j['totals'] is Map ? TxnTotals.fromJson((j['totals'] as Map).cast<String, dynamic>()) : const TxnTotals(),
      allTotals: j['allTotals'] is Map ? TxnTotals.fromJson((j['allTotals'] as Map).cast<String, dynamic>()) : const TxnTotals(),
      groups: facet('groups', 'label'),
      people: facet('people', 'name'),
      truncated: j['truncated'] == true,
    );
  }
}

/// What to show of an account's statement. An immutable value: equal queries are the same request.
class BankTxnQuery {
  final String accountId;

  /// 'YYYY-MM-DD' (inclusive). Both null = since the last balance entered.
  final String? from;
  final String? to;

  /// 'in' | 'out' | null (both)
  final String? direction;
  final String? group;
  final String? person;
  final String search;
  final int page;
  final int limit;

  const BankTxnQuery({
    required this.accountId,
    this.from,
    this.to,
    this.direction,
    this.group,
    this.person,
    this.search = '',
    this.page = 1,
    this.limit = 25,
  });

  bool get isFiltered => direction != null || group != null || person != null || search.trim().isNotEmpty;

  BankTxnQuery copyWith({
    Object? from = _unset,
    Object? to = _unset,
    Object? direction = _unset,
    Object? group = _unset,
    Object? person = _unset,
    String? search,
    int? page,
    int? limit,
  }) =>
      BankTxnQuery(
        accountId: accountId,
        from: identical(from, _unset) ? this.from : from as String?,
        to: identical(to, _unset) ? this.to : to as String?,
        direction: identical(direction, _unset) ? this.direction : direction as String?,
        group: identical(group, _unset) ? this.group : group as String?,
        person: identical(person, _unset) ? this.person : person as String?,
        search: search ?? this.search,
        page: page ?? this.page,
        limit: limit ?? this.limit,
      );

  /// A change of what is being looked at goes back to the first page.
  BankTxnQuery refiltered({Object? direction = _unset, Object? group = _unset, Object? person = _unset, String? search}) =>
      copyWith(direction: direction, group: group, person: person, search: search, page: 1);

  /// Without the filters (the period stays).
  BankTxnQuery get cleared => BankTxnQuery(accountId: accountId, from: from, to: to, limit: limit);

  Map<String, String> toParams({bool export = false}) => {
        'from': ?from,
        'to': ?to,
        'direction': ?direction,
        'group': ?group,
        'person': ?person,
        if (search.trim().isNotEmpty) 'search': search.trim(),
        if (export) 'export': '1' else ...{'page': '$page', 'limit': '$limit'},
      };

  @override
  bool operator ==(Object other) =>
      other is BankTxnQuery &&
      other.accountId == accountId &&
      other.from == from &&
      other.to == to &&
      other.direction == direction &&
      other.group == group &&
      other.person == person &&
      other.search == search &&
      other.page == page &&
      other.limit == limit;

  @override
  int get hashCode => Object.hash(accountId, from, to, direction, group, person, search, page, limit);
}

const _unset = Object();
