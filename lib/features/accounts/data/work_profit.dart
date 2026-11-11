import 'package:flutter/foundation.dart';

// WORK PROFIT: what each work earned and what it cost to deliver (GET /api/work-profit). The
// server does the sums — revenue after discount with the GST backed out, minus the artists'
// expenses, the drivers' expenses and what freelancers are paid for the job. These are the request
// ([WorkProfitQuery]) and the response ([WorkProfitPage]).

const _unset = Object();

double _d(Object? v) => (v as num?)?.toDouble() ?? 0;

/// The period, the filter, the sort and which page. Immutable: two equal queries are the same cached request.
@immutable
class WorkProfitQuery {
  /// 'YYYY-MM-DD' (inclusive).
  final String from;
  final String to;
  final String search;

  /// '' | loss | thin | no_costs | pending_costs
  final String flag;

  /// date_desc | date_asc | profit_asc | profit_desc | margin_asc | margin_desc
  final String sort;
  final int page;
  final int limit;

  const WorkProfitQuery({
    required this.from,
    required this.to,
    this.search = '',
    this.flag = '',
    this.sort = 'date_desc',
    this.page = 1,
    this.limit = 20,
  });

  WorkProfitQuery copyWith({
    String? from,
    String? to,
    String? search,
    Object? flag = _unset,
    String? sort,
    int? page,
    int? limit,
  }) => WorkProfitQuery(
    from: from ?? this.from,
    to: to ?? this.to,
    search: search ?? this.search,
    flag: identical(flag, _unset) ? this.flag : '$flag',
    sort: sort ?? this.sort,
    page: page ?? this.page,
    limit: limit ?? this.limit,
  );

  /// A change of filter always goes back to the first page.
  WorkProfitQuery refiltered({
    String? from,
    String? to,
    String? search,
    Object? flag = _unset,
    String? sort,
    int? limit,
  }) => copyWith(
    from: from,
    to: to,
    search: search,
    flag: flag,
    sort: sort,
    limit: limit,
    page: 1,
  );

  Map<String, dynamic> toParams({bool export = false}) => {
    'from': from,
    'to': to,
    if (search.trim().isNotEmpty) 'search': search.trim(),
    if (flag.isNotEmpty) 'flag': flag,
    'sort': sort,
    if (export) 'export': '1' else ...{'page': page, 'limit': limit},
  };

  @override
  bool operator ==(Object other) =>
      other is WorkProfitQuery &&
      other.from == from &&
      other.to == to &&
      other.search == search &&
      other.flag == flag &&
      other.sort == sort &&
      other.page == page &&
      other.limit == limit;

  @override
  int get hashCode => Object.hash(from, to, search, flag, sort, page, limit);
}

/// The work's revenue, in rupees.
class WorkRevenue {
  final double gross;
  final double discount;

  /// What the customer pays (after discount).
  final double net;

  /// [net] with the GST taken out when prices include it — what profit is measured on.
  final double taxable;
  final double gst;
  final double received;
  final double outstanding;
  const WorkRevenue({
    this.gross = 0,
    this.discount = 0,
    this.net = 0,
    this.taxable = 0,
    this.gst = 0,
    this.received = 0,
    this.outstanding = 0,
  });

  factory WorkRevenue.fromJson(Map<String, dynamic> j) => WorkRevenue(
    gross: _d(j['gross']),
    discount: _d(j['discount']),
    net: _d(j['net']),
    taxable: _d(j['taxable']),
    gst: _d(j['gst']),
    received: _d(j['received']),
    outstanding: _d(j['outstanding']),
  );
}

/// One kind of cost (artists / fleet / freelancers) and how it splits.
class CostGroup {
  final double total;

  /// The part not yet verified / approved.
  final double pending;

  /// The part that was a share of a whole-day cost (fleet only).
  final double shared;
  final Map<String, double> byCategory;
  const CostGroup({
    this.total = 0,
    this.pending = 0,
    this.shared = 0,
    this.byCategory = const {},
  });

  factory CostGroup.fromJson(Object? json) {
    final j = json is Map
        ? json.cast<String, dynamic>()
        : const <String, dynamic>{};
    return CostGroup(
      total: _d(j['total']),
      pending: _d(j['pending']),
      shared: _d(j['shared']),
      byCategory: {
        for (final e in ((j['byCategory'] as Map?) ?? const {}).entries)
          '${e.key}': _d(e.value),
      },
    );
  }
}

class WorkCosts {
  final CostGroup artist;
  final CostGroup fleet;
  final CostGroup freelance;
  final double total;
  final double pending;
  const WorkCosts({
    this.artist = const CostGroup(),
    this.fleet = const CostGroup(),
    this.freelance = const CostGroup(),
    this.total = 0,
    this.pending = 0,
  });

  factory WorkCosts.fromJson(Map<String, dynamic> j) => WorkCosts(
    artist: CostGroup.fromJson(j['artist']),
    fleet: CostGroup.fromJson(j['fleet']),
    freelance: CostGroup.fromJson(j['freelance']),
    total: _d(j['total']),
    pending: _d(j['pending']),
  );
}

/// One work's profit.
class WorkProfit {
  final String bookingId;
  final String bookingNumber;
  final String customerName;
  final String service;
  final String status;
  final DateTime? serviceStart;
  final String place;
  final List<String> artists;
  final WorkRevenue revenue;
  final WorkCosts costs;
  final double profit;

  /// Profit as a percent of revenue; null when the work earned nothing.
  final double? marginPct;

  /// loss | thin | no_costs | pending_costs
  final List<String> flags;

  const WorkProfit({
    required this.bookingId,
    this.bookingNumber = '',
    this.customerName = '',
    this.service = '',
    this.status = '',
    this.serviceStart,
    this.place = '',
    this.artists = const [],
    this.revenue = const WorkRevenue(),
    this.costs = const WorkCosts(),
    this.profit = 0,
    this.marginPct,
    this.flags = const [],
  });

  bool get isLoss => flags.contains('loss');
  bool get isThin => flags.contains('thin');
  bool get noCosts => flags.contains('no_costs');
  bool get hasPending => flags.contains('pending_costs');

  factory WorkProfit.fromJson(Map<String, dynamic> j) => WorkProfit(
    bookingId: '${j['bookingId'] ?? ''}',
    bookingNumber: '${j['bookingNumber'] ?? ''}',
    customerName: '${j['customerName'] ?? ''}',
    service: '${j['service'] ?? ''}',
    status: '${j['status'] ?? ''}',
    serviceStart: DateTime.tryParse('${j['serviceStart'] ?? ''}')?.toLocal(),
    place: '${j['place'] ?? ''}',
    artists: [for (final a in (j['artists'] as List? ?? const [])) '$a'],
    revenue: WorkRevenue.fromJson(
      (j['revenue'] as Map?)?.cast<String, dynamic>() ?? const {},
    ),
    costs: WorkCosts.fromJson(
      (j['costs'] as Map?)?.cast<String, dynamic>() ?? const {},
    ),
    profit: _d(j['profit']),
    marginPct: (j['marginPct'] as num?)?.toDouble(),
    flags: [for (final f in (j['flags'] as List? ?? const [])) '$f'],
  );
}

/// The period's totals.
class WorkProfitTotals {
  final double net;
  final double taxable;
  final double gst;
  final double received;
  final double artist;
  final double fleet;
  final double freelance;
  final double costs;
  final double pendingCosts;
  final double profit;
  final double? marginPct;

  /// Spent in the period but not on any of these works (no work that day, or a work this report doesn't count).
  final double unallocatedArtist;
  final double unallocatedFleet;
  final double unallocated;
  final double profitAfterUnallocated;
  final int works;
  final int loss;
  final int thin;
  final int noCosts;
  final int pendingCount;

  const WorkProfitTotals({
    this.net = 0,
    this.taxable = 0,
    this.gst = 0,
    this.received = 0,
    this.artist = 0,
    this.fleet = 0,
    this.freelance = 0,
    this.costs = 0,
    this.pendingCosts = 0,
    this.profit = 0,
    this.marginPct,
    this.unallocatedArtist = 0,
    this.unallocatedFleet = 0,
    this.unallocated = 0,
    this.profitAfterUnallocated = 0,
    this.works = 0,
    this.loss = 0,
    this.thin = 0,
    this.noCosts = 0,
    this.pendingCount = 0,
  });

  factory WorkProfitTotals.fromJson(Map<String, dynamic> j) {
    Map<String, dynamic> m(String k) =>
        (j[k] as Map?)?.cast<String, dynamic>() ?? const {};
    final rev = m('revenue'),
        c = m('costs'),
        u = m('unallocated'),
        n = m('count');
    return WorkProfitTotals(
      net: _d(rev['net']),
      taxable: _d(rev['taxable']),
      gst: _d(rev['gst']),
      received: _d(rev['received']),
      artist: _d(c['artist']),
      fleet: _d(c['fleet']),
      freelance: _d(c['freelance']),
      costs: _d(c['total']),
      pendingCosts: _d(c['pending']),
      profit: _d(j['profit']),
      marginPct: (j['marginPct'] as num?)?.toDouble(),
      unallocatedArtist: _d(u['artist']),
      unallocatedFleet: _d(u['fleet']),
      unallocated: _d(u['total']),
      profitAfterUnallocated: _d(j['profitAfterUnallocated']),
      works: (n['works'] as num?)?.toInt() ?? 0,
      loss: (n['loss'] as num?)?.toInt() ?? 0,
      thin: (n['thin'] as num?)?.toInt() ?? 0,
      noCosts: (n['noCosts'] as num?)?.toInt() ?? 0,
      pendingCount: (n['pendingCosts'] as num?)?.toInt() ?? 0,
    );
  }
}

class WorkProfitPage {
  final String from;
  final String to;
  final List<WorkProfit> items;
  final int page;
  final int limit;
  final int totalItems;
  final int totalPages;
  final WorkProfitTotals totals;

  /// A margin under this percent is "thin".
  final double thinMarginPct;

  /// The GST rate in use, when GST is on ('' rate = 0).
  final double gstRate;
  final bool gstOn;
  final bool truncated;

  const WorkProfitPage({
    this.from = '',
    this.to = '',
    this.items = const [],
    this.page = 1,
    this.limit = 20,
    this.totalItems = 0,
    this.totalPages = 1,
    this.totals = const WorkProfitTotals(),
    this.thinMarginPct = 20,
    this.gstRate = 0,
    this.gstOn = false,
    this.truncated = false,
  });

  factory WorkProfitPage.fromJson(Map<String, dynamic> j) {
    final gst = (j['gst'] as Map?)?.cast<String, dynamic>() ?? const {};
    return WorkProfitPage(
      from: '${j['from'] ?? ''}',
      to: '${j['to'] ?? ''}',
      items: [
        for (final i in (j['items'] as List? ?? const []))
          WorkProfit.fromJson((i as Map).cast<String, dynamic>()),
      ],
      page: (j['page'] as num?)?.toInt() ?? 1,
      limit: (j['limit'] as num?)?.toInt() ?? 20,
      totalItems: (j['totalItems'] as num?)?.toInt() ?? 0,
      totalPages: (j['totalPages'] as num?)?.toInt() ?? 1,
      totals: WorkProfitTotals.fromJson(
        (j['totals'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      thinMarginPct: _d(j['thinMarginPct']) == 0 ? 20 : _d(j['thinMarginPct']),
      gstRate: _d(gst['rate']),
      gstOn: gst['enabled'] == true && _d(gst['rate']) > 0,
      truncated: j['truncated'] == true,
    );
  }
}
