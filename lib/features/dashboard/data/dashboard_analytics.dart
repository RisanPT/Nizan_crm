// Models for the main dashboard's server-side analytics tabs
// (GET /api/dashboard/sales | marketing | finance).

double _d(dynamic v) => (v as num?)?.toDouble() ?? 0;
double? _dn(dynamic v) => (v as num?)?.toDouble();
int _i(dynamic v) => (v as num?)?.toInt() ?? 0;
String _s(dynamic v) => v?.toString() ?? '';
Map<String, dynamic> _m(dynamic v) =>
    v is Map ? Map<String, dynamic>.from(v) : const <String, dynamic>{};
List<Map<String, dynamic>> _l(dynamic v) =>
    v is List ? v.map(_m).toList() : const <Map<String, dynamic>>[];

String _ymd(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Package families the server groups bookings into (see serviceTypeOf).
const kPackageFamilies = ['Airbrush', 'Platinum', 'Team N Royal', 'Custom Package'];

/// The period a dashboard tab shows, plus the window it is compared with.
class DashboardQuery {
  final DateTime from;
  final DateTime to;

  /// Comparison window: the previous month (same days of it while a month is
  /// still running), or the equal-length span before a custom range.
  final DateTime prevFrom;
  final DateTime prevTo;

  /// Human label for the comparison ("Sep 2026", "previous 14 days").
  final String prevLabel;

  /// Compact form for KPI badges ("Sep", "prev. 14 days").
  final String prevShort;

  /// 'event' (event date) or 'added' (date the booking was entered).
  final String basis;

  /// Sales tab only: one salesperson, or '' for everyone.
  final String salesPersonId;

  const DashboardQuery({
    required this.from,
    required this.to,
    required this.prevFrom,
    required this.prevTo,
    this.prevLabel = 'previous period',
    this.prevShort = 'previous',
    this.basis = 'added',
    this.salesPersonId = '',
  });

  static DateTime _today() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  /// A calendar month. The month in progress runs to today and is compared
  /// with the same days of the previous month, so the comparison is fair.
  factory DashboardQuery.month(DateTime month, {String basis = 'added', String salesPersonId = ''}) {
    final today = _today();
    final start = DateTime(month.year, month.month, 1);
    final monthEnd = DateTime(month.year, month.month + 1, 0);
    final running = !today.isBefore(start) && !today.isAfter(monthEnd);
    final end = running ? today : monthEnd;
    final prevStart = DateTime(month.year, month.month - 1, 1);
    final prevMonthEnd = DateTime(month.year, month.month, 0);
    final prevEnd = running
        ? DateTime(prevStart.year, prevStart.month, end.day.clamp(1, prevMonthEnd.day))
        : prevMonthEnd;
    const names = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final label = '${names[prevStart.month - 1]} ${prevStart.year}${running ? ' (same days)' : ''}';
    return DashboardQuery(
      from: start,
      to: end,
      prevFrom: prevStart,
      prevTo: prevEnd,
      prevLabel: label,
      prevShort: names[prevStart.month - 1],
      basis: basis,
      salesPersonId: salesPersonId,
    );
  }

  /// A custom range, compared with the equal-length span right before it.
  factory DashboardQuery.range(DateTime from, DateTime to, {String basis = 'added', String salesPersonId = ''}) {
    final f = DateTime(from.year, from.month, from.day);
    final t = DateTime(to.year, to.month, to.day);
    final days = t.difference(f).inDays + 1;
    final prevTo = f.subtract(const Duration(days: 1));
    return DashboardQuery(
      from: f,
      to: t,
      prevFrom: prevTo.subtract(Duration(days: days - 1)),
      prevTo: prevTo,
      prevLabel: 'previous $days day${days == 1 ? '' : 's'}',
      prevShort: 'prev. $days d',
      basis: basis,
      salesPersonId: salesPersonId,
    );
  }

  factory DashboardQuery.thisMonth() => DashboardQuery.month(DateTime.now());

  /// True when this is exactly one calendar month (vs a custom range).
  bool get isMonth =>
      from.day == 1 &&
      to.month == from.month &&
      to.year == from.year &&
      (to.day == DateTime(from.year, from.month + 1, 0).day || to == _today());

  DashboardQuery withSalesperson(String id) => DashboardQuery(
        from: from,
        to: to,
        prevFrom: prevFrom,
        prevTo: prevTo,
        prevLabel: prevLabel,
        prevShort: prevShort,
        basis: basis,
        salesPersonId: id,
      );

  Map<String, String> toParams() => {
        'from': _ymd(from),
        'to': _ymd(to),
        'prevFrom': _ymd(prevFrom),
        'prevTo': _ymd(prevTo),
        'basis': basis,
        if (salesPersonId.isNotEmpty) 'salesPersonId': salesPersonId,
      };

  @override
  bool operator ==(Object other) =>
      other is DashboardQuery &&
      other.from == from &&
      other.to == to &&
      other.prevFrom == prevFrom &&
      other.prevTo == prevTo &&
      other.basis == basis &&
      other.salesPersonId == salesPersonId;

  @override
  int get hashCode => Object.hash(from, to, prevFrom, prevTo, basis, salesPersonId);
}

/// One labelled bucket of a breakdown (status / package / source …).
class Bucket {
  final String label;
  final String id;
  final int count;
  final double amount;
  final int converted;
  const Bucket(this.label, this.count, this.amount, {this.converted = 0, this.id = ''});
  factory Bucket.fromJson(Map<String, dynamic> j) => Bucket(
        _s(j['label']),
        _i(j['count']),
        _d(j['amount']),
        converted: _i(j['converted']),
        id: _s(j['id']),
      );
}

/// One point of a trend, with the aligned point of the comparison window.
class TrendPoint {
  final String key;
  final double value;
  final double prevValue;
  final int count;
  final int prevCount;
  const TrendPoint(this.key, this.value, this.prevValue, this.count, {this.prevCount = 0});
}

class SalesKpis {
  final double revenue, avgOrder, received, outstanding, discount, conversion;
  final int orders, enquiries, completed, cancelled;
  const SalesKpis({
    this.revenue = 0,
    this.avgOrder = 0,
    this.received = 0,
    this.outstanding = 0,
    this.discount = 0,
    this.conversion = 0,
    this.orders = 0,
    this.enquiries = 0,
    this.completed = 0,
    this.cancelled = 0,
  });
  factory SalesKpis.fromJson(Map<String, dynamic> j) => SalesKpis(
        revenue: _d(j['revenue']),
        avgOrder: _d(j['avgOrder']),
        received: _d(j['received']),
        outstanding: _d(j['outstanding']),
        discount: _d(j['discount']),
        conversion: _d(j['conversion']),
        orders: _i(j['orders']),
        enquiries: _i(j['enquiries']),
        completed: _i(j['completed']),
        cancelled: _i(j['cancelled']),
      );
}

class Salesperson {
  final String id, name;
  const Salesperson(this.id, this.name);
}

class SalesDashboard {
  final String unit;
  final SalesKpis kpis;
  final SalesKpis previous;
  final List<TrendPoint> trend;
  final List<Bucket> byStatus, byPackage, byDistrict, bySalesperson, leadSources;
  final List<Salesperson> salespeople;

  const SalesDashboard({
    required this.unit,
    required this.kpis,
    required this.previous,
    required this.trend,
    required this.byStatus,
    required this.byPackage,
    required this.byDistrict,
    required this.bySalesperson,
    required this.leadSources,
    required this.salespeople,
  });

  factory SalesDashboard.fromJson(Map<String, dynamic> j) {
    List<Bucket> b(String k) => _l(j[k]).map(Bucket.fromJson).toList();
    return SalesDashboard(
      unit: _s(j['unit']),
      kpis: SalesKpis.fromJson(_m(j['kpis'])),
      previous: SalesKpis.fromJson(_m(j['previous'])),
      trend: _l(j['trend'])
          .map((t) => TrendPoint(_s(t['key']), _d(t['amount']), _d(t['prevAmount']), _i(t['count']),
              prevCount: _i(t['prevCount'])))
          .toList(),
      byStatus: b('byStatus'),
      byPackage: b('byPackage'),
      byDistrict: b('byDistrict'),
      bySalesperson: b('bySalesperson'),
      leadSources: b('leadSources'),
      salespeople: _l(j['salespeople']).map((p) => Salesperson(_s(p['id']), _s(p['name']))).toList(),
    );
  }
}

class MarketingSource {
  final String label;
  final int count, converted;
  final double revenue;
  const MarketingSource(this.label, this.count, this.converted, this.revenue);
  double get conversion => count == 0 ? 0 : converted / count * 100;
}

class MarketingCampaign {
  final String label, channel;
  final double spend, revenue;
  final int leads, converted;
  const MarketingCampaign(this.label, this.channel, this.spend, this.leads, this.converted, this.revenue);
}

class ContentPlatform {
  final String label;
  final int published, planned;
  const ContentPlatform(this.label, this.published, this.planned);
}

class MarketingDashboard {
  final String unit;
  final int enquiries, prevEnquiries, converted, prevConverted, open, lost, published, reviews;
  final double conversion, prevConversion, revenue, spend, prevSpend;
  final double? costPerEnquiry, returnOnSpend, avgRating;
  final List<TrendPoint> trend;
  final List<MarketingSource> sources;
  final List<Bucket> pipeline, priority, districts, ratings;
  final List<MarketingCampaign> campaigns;
  final List<ContentPlatform> content;

  const MarketingDashboard({
    required this.unit,
    required this.enquiries,
    required this.prevEnquiries,
    required this.converted,
    required this.prevConverted,
    required this.open,
    required this.lost,
    required this.published,
    required this.reviews,
    required this.conversion,
    required this.prevConversion,
    required this.revenue,
    required this.spend,
    required this.prevSpend,
    required this.costPerEnquiry,
    required this.returnOnSpend,
    required this.avgRating,
    required this.trend,
    required this.sources,
    required this.pipeline,
    required this.priority,
    required this.districts,
    required this.ratings,
    required this.campaigns,
    required this.content,
  });

  factory MarketingDashboard.fromJson(Map<String, dynamic> j) {
    final k = _m(j['kpis']);
    List<Bucket> b(String key) => _l(j[key]).map(Bucket.fromJson).toList();
    return MarketingDashboard(
      unit: _s(j['unit']),
      enquiries: _i(k['enquiries']),
      prevEnquiries: _i(k['prevEnquiries']),
      converted: _i(k['converted']),
      prevConverted: _i(k['prevConverted']),
      open: _i(k['open']),
      lost: _i(k['lost']),
      published: _i(k['published']),
      reviews: _i(k['reviews']),
      conversion: _d(k['conversion']),
      prevConversion: _d(k['prevConversion']),
      revenue: _d(k['revenue']),
      spend: _d(k['spend']),
      prevSpend: _d(k['prevSpend']),
      costPerEnquiry: _dn(k['costPerEnquiry']),
      returnOnSpend: _dn(k['returnOnSpend']),
      avgRating: _dn(k['avgRating']),
      trend: _l(j['trend'])
          .map((t) => TrendPoint(_s(t['key']), _d(t['count']), _d(t['prevCount']), _i(t['converted'])))
          .toList(),
      sources: _l(j['sources'])
          .map((s) => MarketingSource(_s(s['label']), _i(s['count']), _i(s['converted']), _d(s['revenue'])))
          .toList(),
      pipeline: b('pipeline'),
      priority: b('priority'),
      districts: b('districts'),
      ratings: b('ratings'),
      campaigns: _l(j['campaigns'])
          .map((c) => MarketingCampaign(_s(c['label']), _s(c['channel']), _d(c['spend']), _i(c['leads']),
              _i(c['converted']), _d(c['revenue'])))
          .toList(),
      content: _l(j['content'])
          .map((c) => ContentPlatform(_s(c['label']), _i(c['published']), _i(c['planned'])))
          .toList(),
    );
  }
}

class FinanceLine {
  final String label;
  final double amount, prevAmount;
  final int count;
  const FinanceLine(this.label, this.amount, this.prevAmount, this.count);
  factory FinanceLine.fromJson(Map<String, dynamic> j) =>
      FinanceLine(_s(j['label']), _d(j['amount']), _d(j['prevAmount']), _i(j['count']));
}

class FinanceMonth {
  final String key;
  final double billed, income, expense, net;
  const FinanceMonth(this.key, this.billed, this.income, this.expense, this.net);
}

class FinanceDashboard {
  final Map<String, double> kpis;
  final int collectionsPendingCount;
  final List<FinanceLine> expenses, paymentModes, pendingApprovals;
  final Map<String, double> aging;
  final List<FinanceMonth> trend;

  const FinanceDashboard({
    required this.kpis,
    required this.collectionsPendingCount,
    required this.expenses,
    required this.paymentModes,
    required this.pendingApprovals,
    required this.aging,
    required this.trend,
  });

  double k(String key) => kpis[key] ?? 0;

  factory FinanceDashboard.fromJson(Map<String, dynamic> j) {
    final k = _m(j['kpis']);
    List<FinanceLine> f(String key) => _l(j[key]).map(FinanceLine.fromJson).toList();
    return FinanceDashboard(
      kpis: k.map((key, v) => MapEntry(key, _d(v))),
      collectionsPendingCount: _i(k['collectionsPendingCount']),
      expenses: f('expenses'),
      paymentModes: f('paymentModes'),
      pendingApprovals: f('pendingApprovals'),
      aging: _m(j['aging']).map((key, v) => MapEntry(key, _d(v))),
      trend: _l(j['trend'])
          .map((t) => FinanceMonth(_s(t['key']), _d(t['billed']), _d(t['income']), _d(t['expense']), _d(t['net'])))
          .toList(),
    );
  }
}
