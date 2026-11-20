// THE ASSOCIATE WORKS REPORT (GET /api/associate-works): which works each associate artist did, and what they were paid for them. The works come
// from the bookings' own team assignments, the money from Artist Payouts — joined on the server (backend utils/associateWorks.js). A missing
// part parses to an empty value, never a crash. Money is null when the viewer may not see it (Operations sees works, not fees).

int _i(dynamic v) => (v as num?)?.toInt() ?? 0;
double? _dn(dynamic v) => (v as num?)?.toDouble();
String _s(dynamic v) => v?.toString() ?? '';
Map<String, dynamic> _m(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
List<Map<String, dynamic>> _l(dynamic v) => ((v as List?) ?? const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();

/// What Accounts has recorded for an associate on a work: the fee is paid, partly owed, or not recorded yet.
const kPayoutStates = [('paid', 'Paid'), ('owed', 'Still to pay'), ('none', 'No fee yet')];
String payoutLabel(String? s) => kPayoutStates.firstWhere((e) => e.$1 == s, orElse: () => ('', '')).$2;

/// One associate on one work (a booking they are on, on the booking itself or on any of its items).
class AssociateWork {
  const AssociateWork({
    this.associateId = '', this.associateName = '', this.phone = '', this.bookingId = '', this.bookingNumber = '', this.customerName = '', this.services = const [],
    this.role = '', this.roleType = 'assistant', this.firstDay = '', this.days = 0, this.place = '', this.status = '', this.fee, this.paid, this.owed, this.payout,
  });
  final String associateId, associateName, phone, bookingId, bookingNumber, customerName, role, roleType, firstDay, place, status;
  final List<String> services;
  final int days;

  /// null = the viewer may not see money.
  final double? fee, paid, owed;

  /// paid | owed | none, or null when the viewer may not see money.
  final String? payout;

  bool get isLead => roleType == 'lead';
  factory AssociateWork.fromJson(Map<String, dynamic> j) => AssociateWork(
        associateId: _s(j['associateId']),
        associateName: _s(j['associateName']),
        phone: _s(j['phone']),
        bookingId: _s(j['bookingId']),
        bookingNumber: _s(j['bookingNumber']),
        customerName: _s(j['customerName']),
        services: ((j['services'] as List?) ?? const []).map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList(),
        role: _s(j['role']),
        roleType: _s(j['roleType']).isEmpty ? 'assistant' : _s(j['roleType']),
        firstDay: _s(j['firstDay']),
        days: _i(j['days']),
        place: _s(j['place']),
        status: _s(j['status']),
        fee: _dn(j['fee']),
        paid: _dn(j['paid']),
        owed: _dn(j['owed']),
        payout: j['payout']?.toString(),
      );
}

class AssociateSummary {
  const AssociateSummary({this.associates = 0, this.works = 0, this.days = 0, this.fee, this.paid, this.owed, this.noFee});
  final int associates, works, days;
  final double? fee, paid, owed;
  final int? noFee;
  factory AssociateSummary.fromJson(Map<String, dynamic> j) => AssociateSummary(associates: _i(j['associates']), works: _i(j['works']), days: _i(j['days']), fee: _dn(j['fee']), paid: _dn(j['paid']), owed: _dn(j['owed']), noFee: (j['noFee'] as num?)?.toInt());
}

/// One line per associate.
class AssociateLine {
  const AssociateLine({this.id = '', this.name = '', this.phone = '', this.works = 0, this.days = 0, this.fee, this.paid, this.owed, this.noFee, this.lastDay = ''});
  final String id, name, phone, lastDay;
  final int works, days;
  final double? fee, paid, owed;
  final int? noFee;
  factory AssociateLine.fromJson(Map<String, dynamic> j) => AssociateLine(id: _s(j['id']), name: _s(j['name']), phone: _s(j['phone']), works: _i(j['works']), days: _i(j['days']), fee: _dn(j['fee']), paid: _dn(j['paid']), owed: _dn(j['owed']), noFee: (j['noFee'] as num?)?.toInt(), lastDay: _s(j['lastDay']));
}

/// Money paid to associates in the period that is not on a work this report lists.
class AssociateElsewhere {
  const AssociateElsewhere({this.count = 0, this.amount = 0});
  final int count;
  final double amount;
  factory AssociateElsewhere.fromJson(Map<String, dynamic> j) => AssociateElsewhere(count: _i(j['count']), amount: _dn(j['amount']) ?? 0);
}

class AssociateWorksPage {
  const AssociateWorksPage({
    this.from = '', this.to = '', this.canSeeFees = false, this.summary = const AssociateSummary(), this.associates = const [], this.items = const [], this.page = 1, this.limit = 20,
    this.totalItems = 0, this.totalPages = 1, this.truncated = false, this.elsewhere, this.registered = 0,
  });
  final String from, to;
  final bool canSeeFees, truncated;
  final AssociateSummary summary;
  final List<AssociateLine> associates;
  final List<AssociateWork> items;
  final int page, limit, totalItems, totalPages, registered;

  /// null when the viewer may not see money.
  final AssociateElsewhere? elsewhere;

  factory AssociateWorksPage.fromJson(Map<String, dynamic> j) => AssociateWorksPage(
        from: _s(j['from']),
        to: _s(j['to']),
        canSeeFees: j['canSeeFees'] == true,
        summary: AssociateSummary.fromJson(_m(j['summary'])),
        associates: _l(j['associates']).map(AssociateLine.fromJson).toList(),
        items: _l(j['items']).map(AssociateWork.fromJson).toList(),
        page: _i(j['page']) == 0 ? 1 : _i(j['page']),
        limit: _i(j['limit']) == 0 ? 20 : _i(j['limit']),
        totalItems: _i(j['totalItems']),
        totalPages: _i(j['totalPages']) == 0 ? 1 : _i(j['totalPages']),
        truncated: j['truncated'] == true,
        elsewhere: j['elsewhere'] is Map ? AssociateElsewhere.fromJson(_m(j['elsewhere'])) : null,
        registered: _i(j['registered']),
      );
}

/// The report's request: the period, one associate, one payout state and a search — and which page.
class AssociateWorksQuery {
  const AssociateWorksQuery({required this.from, required this.to, this.associateId = '', this.payout = '', this.search = '', this.page = 1, this.limit = 20});
  final String from, to, associateId, payout, search;
  final int page, limit;

  AssociateWorksQuery copyWith({String? from, String? to, String? associateId, String? payout, String? search, int? page}) => AssociateWorksQuery(
        from: from ?? this.from,
        to: to ?? this.to,
        associateId: associateId ?? this.associateId,
        payout: payout ?? this.payout,
        search: search ?? this.search,
        page: page ?? this.page,
        limit: limit,
      );

  /// A change of filter always goes back to the first page.
  AssociateWorksQuery refiltered({String? from, String? to, String? associateId, String? payout, String? search}) =>
      copyWith(from: from, to: to, associateId: associateId, payout: payout, search: search, page: 1);

  Map<String, dynamic> toParams({bool export = false}) => {
        'from': from,
        'to': to,
        if (associateId.isNotEmpty) 'associateId': associateId,
        if (payout.isNotEmpty) 'payout': payout,
        if (search.trim().isNotEmpty) 'search': search.trim(),
        if (export) 'export': '1' else ...{'page': page, 'limit': limit},
      };

  @override
  bool operator ==(Object other) => other is AssociateWorksQuery && other.from == from && other.to == to && other.associateId == associateId && other.payout == payout && other.search == search && other.page == page && other.limit == limit;

  @override
  int get hashCode => Object.hash(from, to, associateId, payout, search, page, limit);
}

/// A cell that starts like a spreadsheet formula (= + - @) is written as text, so a client named "=HYPERLINK(…)" cannot run anything.
Object? _safe(Object? v) => v is String && v.isNotEmpty && '=+-@\t\r'.contains(v[0]) ? "'$v" : v;

String associateCsvFileName(AssociateWorksPage p) => 'associate-works-${p.from}-to-${p.to}.csv';

/// The whole report as a CSV: its period, then one row per work. The money columns are left out when the viewer may not see money.
List<List<Object?>> associateWorksCsvRows(AssociateWorksPage p) {
  final fees = p.canSeeFees;
  return [
    ['Associate Works'],
    ['From', p.from, 'To', p.to],
    if (p.truncated) ['Only the first ${p.items.length} works are included — narrow the dates.'],
    [],
    ['Associate', 'Phone', 'Booking no.', 'Client', 'Services', 'Role', 'First day', 'Days', 'Place', 'Status', if (fees) ...['Fee (₹)', 'Paid (₹)', 'Still to pay (₹)', 'Fee state']],
    for (final w in p.items)
      [
        _safe(w.associateName), _safe(w.phone), _safe(w.bookingNumber), _safe(w.customerName), _safe(w.services.join(' + ')), _safe(w.role.isEmpty ? (w.isLead ? 'Lead' : 'Associate') : w.role), w.firstDay, w.days, _safe(w.place), _safe(w.status),
        if (fees) ...[w.fee ?? '', w.paid ?? '', w.owed ?? '', payoutLabel(w.payout)],
      ],
  ];
}
