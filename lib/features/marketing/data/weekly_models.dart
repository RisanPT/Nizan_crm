// The Marketing Weekly Report's payload (backend controllers/marketingWeeklyController.js). One page rolling up the chosen range; every
// number is counted once on the server from the records the other screens own. A missing part parses to an empty value, never a crash.

int _i(dynamic v) => (v as num?)?.toInt() ?? 0;
double _d(dynamic v) => (v as num?)?.toDouble() ?? 0;
double? _dn(dynamic v) => (v as num?)?.toDouble();
String _s(dynamic v) => v?.toString() ?? '';
String? _sn(dynamic v) => v?.toString();
bool _b(dynamic v) => v == true;
DateTime? _dt(dynamic v) => v == null ? null : DateTime.tryParse(v.toString())?.toLocal();
Map<String, dynamic> _m(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
List<Map<String, dynamic>> _l(dynamic v) => ((v as List?) ?? const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
List<double>? _spark(dynamic v) => v is List ? v.map((e) => _d(e)).toList() : null;

/// A figure with the value of the period before and the change (percent; percentage points for a rate). change == null: nothing to compare.
class WeeklyFigure {
  const WeeklyFigure({this.now = 0, this.before = 0, this.change});
  final double now, before;
  final double? change;
  factory WeeklyFigure.fromJson(Map<String, dynamic> j) => WeeklyFigure(now: _d(j['now']), before: _d(j['before']), change: _dn(j['change']));
}

class WeeklyHeadline {
  const WeeklyHeadline({this.leads = const WeeklyFigure(), this.bookings = const WeeklyFigure(), this.revenue = const WeeklyFigure(), this.adSpend, this.conversionRate = const WeeklyFigure(), this.conversionKnown = false});
  final WeeklyFigure leads, bookings, revenue, conversionRate;

  /// null = no ad spend recorded for the period (the card says so; it is not a zero).
  final WeeklyFigure? adSpend;

  /// false when there were no leads to divide by (the rate shows "—").
  final bool conversionKnown;
  factory WeeklyHeadline.fromJson(Map<String, dynamic> j) {
    final rate = _m(j['conversionRate']);
    return WeeklyHeadline(
      leads: WeeklyFigure.fromJson(_m(j['leads'])),
      bookings: WeeklyFigure.fromJson(_m(j['bookings'])),
      revenue: WeeklyFigure.fromJson(_m(j['revenue'])),
      adSpend: j['adSpend'] is Map ? WeeklyFigure.fromJson(_m(j['adSpend'])) : null,
      conversionRate: WeeklyFigure.fromJson(rate),
      conversionKnown: rate['now'] != null,
    );
  }
}

/// A day's leads / bookings / revenue.
class WeeklyDayValues {
  const WeeklyDayValues({this.day = '', this.leads = 0, this.bookings = 0, this.revenue = 0});
  final String day;
  final int leads, bookings;
  final double revenue;
  factory WeeklyDayValues.fromJson(Map<String, dynamic> j) => WeeklyDayValues(day: _s(j['day']), leads: _i(j['leads']), bookings: _i(j['bookings']), revenue: _d(j['revenue']));
  double of(String metric) => switch (metric) { 'bookings' => bookings.toDouble(), 'revenue' => revenue, _ => leads.toDouble() };
}

/// One day of the range against the same position in the period before. [weekday]: 0 = Sunday … 6 = Saturday.
class WeeklyDay {
  const WeeklyDay({this.day = '', this.weekday = 0, this.now = const WeeklyDayValues(), this.before});
  final String day;
  final int weekday;
  final WeeklyDayValues now;
  final WeeklyDayValues? before;
  factory WeeklyDay.fromJson(Map<String, dynamic> j) => WeeklyDay(day: _s(j['day']), weekday: _i(j['weekday']), now: WeeklyDayValues.fromJson(_m(j['now'])), before: j['before'] is Map ? WeeklyDayValues.fromJson(_m(j['before'])) : null);
}

class WeeklyShare {
  const WeeklyShare({this.key = '', this.label = '', this.count = 0, this.pct});
  final String key, label;
  final int count;
  final double? pct;
  factory WeeklyShare.fromJson(Map<String, dynamic> j) => WeeklyShare(key: _s(j['key']), label: _s(j['label']), count: _i(j['count']), pct: _dn(j['pct']));
}

class WeeklyDistribution {
  const WeeklyDistribution({this.total = 0, this.rows = const []});
  final int total;
  final List<WeeklyShare> rows;
  factory WeeklyDistribution.fromJson(Map<String, dynamic> j) => WeeklyDistribution(total: _i(j['total']), rows: _l(j['rows']).map(WeeklyShare.fromJson).toList());
}

/// A member's key result from their logs: the activity they logged most (a count, `unit == 'count'`), else their hours logged (`unit == 'hours'`).
class WeeklyMemberRow {
  const WeeklyMemberRow({this.memberId = '', this.name = '', this.role = '', this.metric, this.value = 0, this.unit = 'count', this.change});
  final String memberId, name, role, unit;
  final String? metric;
  final double value;
  final double? change;
  bool get isHours => unit == 'hours';
  factory WeeklyMemberRow.fromJson(Map<String, dynamic> j) => WeeklyMemberRow(memberId: _s(j['memberId']), name: _s(j['name']), role: _s(j['role']), metric: _sn(j['metric']), value: _d(j['value']), unit: _s(j['unit']).isEmpty ? 'count' : _s(j['unit']), change: _dn(j['change']));
}

class WeeklyMembers {
  const WeeklyMembers({this.viewer = false, this.rows = const [], this.silent = 0});

  /// true = a manager looking at the whole team; false = a member looking at their own result only.
  final bool viewer;
  final List<WeeklyMemberRow> rows;

  /// Members who logged nothing in the range.
  final int silent;
  factory WeeklyMembers.fromJson(Map<String, dynamic> j) => WeeklyMembers(viewer: _b(j['viewer']), rows: _l(j['rows']).map(WeeklyMemberRow.fromJson).toList(), silent: _i(j['silent']));
}

class WeeklyCampaignRow {
  const WeeklyCampaignRow({this.id = '', this.title = '', this.brand = 'main', this.status = '', this.spend = 0, this.leads = 0, this.bookings = 0, this.revenue = 0, this.cpl, this.roas});
  final String id, title, brand, status;
  final double spend, revenue;
  final int leads, bookings;
  final double? cpl, roas;
  factory WeeklyCampaignRow.fromJson(Map<String, dynamic> j) => WeeklyCampaignRow(id: _s(j['id']), title: _s(j['title']), brand: _s(j['brand']), status: _s(j['status']), spend: _d(j['spend']), leads: _i(j['leads']), bookings: _i(j['bookings']), revenue: _d(j['revenue']), cpl: _dn(j['cpl']), roas: _dn(j['roas']));
}

class WeeklyAdRow {
  const WeeklyAdRow({this.id = '', this.name = '', this.campaign = '', this.format = '', this.impressions = 0, this.clicks = 0, this.spend = 0, this.results = 0, this.ctr, this.verdict = ''});
  final String id, name, campaign, format, verdict;
  final int impressions, clicks, results;
  final double spend;
  final double? ctr;
  factory WeeklyAdRow.fromJson(Map<String, dynamic> j) => WeeklyAdRow(id: _s(j['id']), name: _s(j['name']), campaign: _s(j['campaign']), format: _s(j['format']), impressions: _i(j['impressions']), clicks: _i(j['clicks']), spend: _d(j['spend']), results: _i(j['results']), ctr: _dn(j['ctr']), verdict: _s(j['verdict']));
}

class WeeklyEvent {
  const WeeklyEvent({this.at, this.kind = '', this.text = ''});
  final DateTime? at;
  final String kind, text;
  factory WeeklyEvent.fromJson(Map<String, dynamic> j) => WeeklyEvent(at: _dt(j['at']), kind: _s(j['kind']), text: _s(j['text']));
}

class WeeklyCategory {
  const WeeklyCategory({this.category = '', this.planned = 0, this.done = 0});
  final String category;
  final int planned, done;
  factory WeeklyCategory.fromJson(Map<String, dynamic> j) => WeeklyCategory(category: _s(j['category']), planned: _i(j['planned']), done: _i(j['done']));
}

class WeeklyProduction {
  const WeeklyProduction({this.planned = 0, this.done = 0, this.categories = const []});
  final int planned, done;
  final List<WeeklyCategory> categories;
  factory WeeklyProduction.fromJson(Map<String, dynamic> j) => WeeklyProduction(planned: _i(j['planned']), done: _i(j['done']), categories: _l(j['categories']).map(WeeklyCategory.fromJson).toList());
}

class WeeklyRevenue {
  const WeeklyRevenue({this.bookings = 0, this.orderValue = 0, this.advance = 0, this.collectedLater = 0, this.balanceDue = 0, this.averageOrder, this.advanceProgress});
  final int bookings;
  final double orderValue, advance, collectedLater, balanceDue;
  final double? averageOrder, advanceProgress;
  factory WeeklyRevenue.fromJson(Map<String, dynamic> j) => WeeklyRevenue(bookings: _i(j['bookings']), orderValue: _d(j['orderValue']), advance: _d(j['advance']), collectedLater: _d(j['collectedLater']), balanceDue: _d(j['balanceDue']), averageOrder: _dn(j['averageOrder']), advanceProgress: _dn(j['advanceProgress']));
}

class WeeklyStatus {
  const WeeklyStatus({this.adSpendRecorded = false, this.adSpendNote, this.leadsCapped = false});
  final bool adSpendRecorded, leadsCapped;
  final String? adSpendNote;
  factory WeeklyStatus.fromJson(Map<String, dynamic> j) => WeeklyStatus(adSpendRecorded: _b(j['adSpendRecorded']), adSpendNote: _sn(j['adSpendNote']), leadsCapped: _b(j['leadsCapped']));
}

class WeeklyReport {
  const WeeklyReport({
    this.from = '', this.to = '', this.brand = 'all', this.previousFrom = '', this.previousTo = '',
    this.headline = const WeeklyHeadline(), this.sparks = const {}, this.trend = const [], this.quality = const WeeklyDistribution(), this.sources = const WeeklyDistribution(),
    this.members = const WeeklyMembers(), this.campaigns = const [], this.campaignTotal = 0, this.ads = const [], this.recent = const [],
    this.production = const WeeklyProduction(), this.revenue = const WeeklyRevenue(), this.insights = const [], this.status = const WeeklyStatus(),
  });
  final String from, to, brand, previousFrom, previousTo;
  final WeeklyHeadline headline;

  /// The little trend line of each KPI card, one value per day (adSpend is null when no spend was recorded).
  final Map<String, List<double>?> sparks;
  final List<WeeklyDay> trend;
  final WeeklyDistribution quality, sources;
  final WeeklyMembers members;
  final List<WeeklyCampaignRow> campaigns;
  final int campaignTotal;
  final List<WeeklyAdRow> ads;
  final List<WeeklyEvent> recent;
  final WeeklyProduction production;
  final WeeklyRevenue revenue;
  final List<String> insights;
  final WeeklyStatus status;

  /// A seven-day range reads "last week"; anything else "previous period".
  bool get isWeek {
    final a = DateTime.tryParse(from);
    final z = DateTime.tryParse(to);
    return a != null && z != null && z.difference(a).inDays == 6;
  }

  String get against => isWeek ? 'vs last week' : 'vs previous period';

  factory WeeklyReport.fromJson(Map<String, dynamic> j) {
    final range = _m(j['range']);
    final prev = _m(j['previous']);
    final camp = _m(j['campaigns']);
    final sparks = _m(j['sparks']);
    return WeeklyReport(
      from: _s(range['from']),
      to: _s(range['to']),
      brand: _s(range['brand']).isEmpty ? 'all' : _s(range['brand']),
      previousFrom: _s(prev['from']),
      previousTo: _s(prev['to']),
      headline: WeeklyHeadline.fromJson(_m(j['headline'])),
      sparks: {for (final e in sparks.entries) e.key: _spark(e.value)},
      trend: _l(j['trend']).map(WeeklyDay.fromJson).toList(),
      quality: WeeklyDistribution.fromJson(_m(j['quality'])),
      sources: WeeklyDistribution.fromJson(_m(j['sources'])),
      members: WeeklyMembers.fromJson(_m(j['members'])),
      campaigns: _l(camp['rows']).map(WeeklyCampaignRow.fromJson).toList(),
      campaignTotal: _i(camp['total']),
      ads: _l(j['ads']).map(WeeklyAdRow.fromJson).toList(),
      recent: _l(j['recent']).map(WeeklyEvent.fromJson).toList(),
      production: WeeklyProduction.fromJson(_m(j['production'])),
      revenue: WeeklyRevenue.fromJson(_m(j['revenueCollection'])),
      insights: ((j['insights'] as List?) ?? const []).map((e) => e.toString()).toList(),
      status: WeeklyStatus.fromJson(_m(j['status'])),
    );
  }
}
