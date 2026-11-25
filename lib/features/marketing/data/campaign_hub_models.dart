// The Campaigns hub's payloads (backend controllers/marketingCampaignHubController.js, /api/marketing/campaign-hub). Every figure is defined once on
// the server (utils/marketingCampaignStats.js; bookings, booking value, qualified and cost per lead in utils/marketingOutcomes.js, shared with
// the Lead Report and the Weekly Report); these only read it. A missing part parses to an empty value, never a crash.
//  • A booking is a lead linked to a LIVE booking (one per lead); booking value ("revenue") is after discount with GST backed out.
//  • Lead quality: Hot / Warm / Nurture / Cold, and "Not rated" (a lead with no priority) only when some lead has none.

int _i(dynamic v) => (v as num?)?.toInt() ?? 0;
int? _inn(dynamic v) => (v as num?)?.toInt();
double _d(dynamic v) => (v as num?)?.toDouble() ?? 0;
double? _dn(dynamic v) => (v as num?)?.toDouble();
String _s(dynamic v) => v?.toString() ?? '';
DateTime? _dt(dynamic v) => v == null ? null : DateTime.tryParse(v.toString())?.toLocal();
Map<String, dynamic> _m(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
List<Map<String, dynamic>> _l(dynamic v) => ((v as List?) ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
List<String> _ls(dynamic v) => ((v as List?) ?? const []).map(_s).toList();

// ── the lists the forms and filters use (the same keys as the server) ─────────────────────────────────────────────────────────

const kHubStatuses = [('planned', 'Planned'), ('active', 'Active'), ('paused', 'Paused'), ('completed', 'Completed')];
const kHubObjectives = [
  ('lead_generation', 'Lead Generation'),
  ('messages', 'Messages'),
  ('engagement', 'Engagement'),
  ('reach', 'Reach'),
  ('traffic', 'Traffic'),
  ('conversions', 'Conversions'),
  ('other', 'Other'),
];
const kHubPlatforms = [('meta', 'Meta'), ('instagram', 'Instagram'), ('facebook', 'Facebook'), ('google', 'Google'), ('youtube', 'YouTube'), ('whatsapp', 'WhatsApp'), ('other', 'Other')];
const kAdFormats = [('image', 'Image'), ('video', 'Video'), ('reel', 'Reel'), ('carousel', 'Carousel'), ('story', 'Story'), ('other', 'Other')];
const kAdStatuses = [('active', 'Active'), ('paused', 'Paused'), ('ended', 'Ended')];
const kAdVerdicts = [('top', 'Top performing'), ('under', 'Underperforming'), ('needs_attention', 'Needs attention'), ('ok', 'Average'), ('early', 'Too early')];

String _label(List<(String, String)> list, String key, String fallback) => list.firstWhere((e) => e.$1 == key, orElse: () => (key, fallback)).$2;
String hubStatusLabel(String s) => _label(kHubStatuses, s, s);
String hubObjectiveLabel(String s) => s.isEmpty || s == 'not_set' ? 'Not set' : _label(kHubObjectives, s, s);
String hubPlatformLabel(String s) => s.isEmpty ? 'Not set' : _label(kHubPlatforms, s, s);
String adFormatLabel(String s) => _label(kAdFormats, s, s);
String adStatusLabel(String s) => _label(kAdStatuses, s, s);
String adVerdictLabel(String s) => _label(kAdVerdicts, s, s);

/// The lead-quality buckets, in the order they are shown ("Not rated" only when some lead has no priority).
const kHubQualities = ['Hot', 'Warm', 'Nurture', 'Cold'];
const kHubNotRated = 'Not rated';

/// The kinds of report the server makes (GET /reports/:type) — each tab's Export downloads one of these.
const kHubReportTypes = ['campaign', 'creative', 'lead', 'conversion', 'spend', 'audience', 'overview', 'performance'];

// ── a period's figures ────────────────────────────────────────────────────────────────────────────────────────────────────────

/// Every headline figure of one period: the paid-ads sums (imported or typed) and the CRM's leads, bookings and revenue.
class HubTotals {
  const HubTotals({
    this.spend = 0,
    this.reach = 0,
    this.impressions = 0,
    this.clicks = 0,
    this.results = 0,
    this.leads = 0,
    this.qualified = 0,
    this.hot = 0,
    this.bookedLeads = 0,
    this.bookings = 0,
    this.revenue = 0,
    this.ctr,
    this.cpm,
    this.cpl,
    this.conversionRate,
    this.roas,
  });
  final double spend, revenue;
  final int reach, impressions, clicks, results, leads, qualified, hot, bookedLeads, bookings;
  final double? ctr, cpm, cpl, conversionRate, roas;

  factory HubTotals.fromJson(Map<String, dynamic> j) => HubTotals(
        spend: _d(j['spend']),
        reach: _i(j['reach']),
        impressions: _i(j['impressions']),
        clicks: _i(j['clicks']),
        results: _i(j['results']),
        leads: _i(j['leads']),
        qualified: _i(j['qualified']),
        hot: _i(j['hot']),
        bookedLeads: _i(j['bookedLeads']),
        bookings: _i(j['bookings']),
        revenue: _d(j['revenue']),
        ctr: _dn(j['ctr']),
        cpm: _dn(j['cpm']),
        cpl: _dn(j['cpl']),
        conversionRate: _dn(j['conversionRate']),
        roas: _dn(j['roas']),
      );
}

/// The period, the same-length period before it, and the change of each figure (percent; for the conversion rate, percentage points).
class HubKpis {
  const HubKpis({this.now = const HubTotals(), this.before = const HubTotals(), this.change = const {}});
  final HubTotals now, before;
  final Map<String, double?> change;
  double? changeOf(String key) => change[key];

  factory HubKpis.fromJson(Map<String, dynamic> j) => HubKpis(
        now: HubTotals.fromJson(_m(j['now'])),
        before: HubTotals.fromJson(_m(j['before'])),
        change: _m(j['change']).map((k, v) => MapEntry(k, _dn(v))),
      );
}

/// One point of the trend chart: a day (or a week's first day when the range is long).
class HubTrendPoint {
  const HubTrendPoint({required this.day, this.days = 1, this.spend = 0, this.reach = 0, this.impressions = 0, this.clicks = 0, this.results = 0, this.leads = 0, this.qualified = 0, this.bookings = 0, this.cpl});
  final String day;
  final int days, reach, impressions, clicks, results, leads, qualified, bookings;
  final double spend;
  final double? cpl;
  factory HubTrendPoint.fromJson(Map<String, dynamic> j) => HubTrendPoint(
        day: _s(j['day']),
        days: _i(j['days']),
        spend: _d(j['spend']),
        reach: _i(j['reach']),
        impressions: _i(j['impressions']),
        clicks: _i(j['clicks']),
        results: _i(j['results']),
        leads: _i(j['leads']),
        qualified: _i(j['qualified']),
        bookings: _i(j['bookings']),
        cpl: _dn(j['cpl']),
      );
}

List<HubTrendPoint> _trend(dynamic v) => _l(v).map(HubTrendPoint.fromJson).toList();

class LeadTypeSlice {
  const LeadTypeSlice({required this.key, required this.label, this.leads = 0, this.pct = 0});
  final String key, label;
  final int leads, pct;
  factory LeadTypeSlice.fromJson(Map<String, dynamic> j) => LeadTypeSlice(key: _s(j['key']), label: _s(j['label']), leads: _i(j['leads']), pct: _i(j['pct']));
}

class HubInsight {
  const HubInsight({required this.kind, required this.text});
  final String kind; // good | warn | info
  final String text;
  factory HubInsight.fromJson(Map<String, dynamic> j) => HubInsight(kind: _s(j['kind']), text: _s(j['text']));
}

// ── imports and the Meta card ─────────────────────────────────────────────────────────────────────────────────────────────────

/// One entry of the history of figures brought in (an imported Meta Ads Manager export, or a day typed by hand).
class ImportInfo {
  const ImportInfo({required this.id, this.at, this.source = 'csv', this.level = 'campaign', this.byName = '', this.fileName = '', this.rows = 0, this.matched = 0, this.unmatched = 0, this.unmatchedNames = const [], this.created = 0, this.written = 0, this.adsCreated = 0, this.skipped = 0, this.from = '', this.to = ''});
  final String id, source, level, byName, fileName, from, to;
  final DateTime? at;
  final int rows, matched, unmatched, created, written, adsCreated, skipped;
  final List<String> unmatchedNames;
  factory ImportInfo.fromJson(Map<String, dynamic> j) => ImportInfo(
        id: _s(j['id']),
        at: _dt(j['at']),
        source: _s(j['source']).isEmpty ? 'csv' : _s(j['source']),
        level: _s(j['level']).isEmpty ? 'campaign' : _s(j['level']),
        byName: _s(j['byName']),
        fileName: _s(j['fileName']),
        rows: _i(j['rows']),
        matched: _i(j['matched']),
        unmatched: _i(j['unmatched']),
        unmatchedNames: _ls(j['unmatchedNames']),
        created: _i(j['created']),
        written: _i(j['written']),
        adsCreated: _i(j['adsCreated']),
        skipped: _i(j['skipped']),
        from: _s(j['from']),
        to: _s(j['to']),
      );
}

/// The Overview's Meta card. There is no live Meta connection: [connected] is false and the card says when figures were last brought in.
/// The live Meta ad spend sync as the hub's Meta card shows it (null when the server is not set up for it).
class HubMetaSync {
  const HubMetaSync({this.lastOkAt, this.lastRunAt, this.ok = true, this.problem = '', this.unlinked = 0, this.autoSync = true});
  final DateTime? lastOkAt, lastRunAt;
  final bool ok, autoSync;
  final String problem;
  final int unlinked;
  factory HubMetaSync.fromJson(Map<String, dynamic> j) => HubMetaSync(
        lastOkAt: _dt(j['lastOkAt']),
        lastRunAt: _dt(j['lastRunAt']),
        ok: j['ok'] != false,
        problem: _s(j['problem']),
        unlinked: (j['unlinked'] as num?)?.toInt() ?? 0,
        autoSync: j['autoSync'] != false,
      );
}

class HubMeta {
  const HubMeta({this.connected = false, this.status = 'not_connected', this.lastImport, this.leadAds = false, this.sync});
  final bool connected;

  /// not_connected | not_synced | connected | error
  final String status;
  final ImportInfo? lastImport;

  /// Lead Ads forms reach the CRM on their own (the server is set up for Meta Lead Ads).
  final bool leadAds;
  final HubMetaSync? sync;
  factory HubMeta.fromJson(Map<String, dynamic> j) => HubMeta(
        connected: j['connected'] == true,
        status: _s(j['status']).isEmpty ? 'not_connected' : _s(j['status']),
        lastImport: j['lastImport'] == null ? null : ImportInfo.fromJson(_m(j['lastImport'])),
        leadAds: j['leadAds'] == true,
        sync: j['sync'] is Map ? HubMetaSync.fromJson(_m(j['sync'])) : null,
      );
}

// ── campaigns and ads ─────────────────────────────────────────────────────────────────────────────────────────────────────────

/// A campaign's settings (what the form edits).
class HubCampaign {
  const HubCampaign({required this.id, required this.title, this.brand = 'main', this.platform = '', this.channel = '', this.objective = '', this.status = 'active', this.startDate, this.endDate, this.budget = 0, this.dailyBudget = 0, this.metaCampaignId = '', this.metaStatus = '', this.audienceNote = '', this.notes = ''});
  final String id, title, brand, platform, channel, objective, status, metaCampaignId, audienceNote, notes;

  /// The status Meta shows for it, in words ("Paused", "Ended") — '' when the live sync has not read it (the status is the team's own).
  final String metaStatus;
  final String? startDate, endDate;
  final double budget, dailyBudget;
  factory HubCampaign.fromJson(Map<String, dynamic> j) => HubCampaign(
        id: _s(j['id']),
        title: _s(j['title']),
        brand: _s(j['brand']).isEmpty ? 'main' : _s(j['brand']),
        platform: _s(j['platform']),
        channel: _s(j['channel']),
        objective: _s(j['objective']),
        status: _s(j['status']).isEmpty ? 'active' : _s(j['status']),
        startDate: j['startDate'] == null ? null : _s(j['startDate']),
        endDate: j['endDate'] == null ? null : _s(j['endDate']),
        budget: _d(j['budget']),
        dailyBudget: _d(j['dailyBudget']),
        metaCampaignId: _s(j['metaCampaignId']),
        metaStatus: _s(j['metaStatus']),
        audienceNote: _s(j['audienceNote']),
        notes: _s(j['notes']),
      );
}

/// One campaign with its figures for the range (the All Campaigns table, the Overview's Active Campaigns, the Leads & Conversions table).
class HubCampaignRow {
  const HubCampaignRow({
    required this.id,
    required this.title,
    this.brand = 'main',
    this.platform = '',
    this.objective = '',
    this.status = 'active',
    this.budget = 0,
    this.metaCampaignId = '',
    this.metaStatus = '',
    this.spend = 0,
    this.reach = 0,
    this.impressions = 0,
    this.clicks = 0,
    this.results = 0,
    this.ctr,
    this.leads = 0,
    this.qualified = 0,
    this.hot = 0,
    this.warm = 0,
    this.nurture = 0,
    this.cold = 0,
    this.notRated = 0,
    this.bookedLeads = 0,
    this.bookings = 0,
    this.revenue = 0,
    this.cpl,
    this.conversionRate,
    this.roas,
    this.workMinutes = 0,
    this.workEntries = 0,
    this.thumbUrl = '',
  });
  final String id, title, brand, platform, objective, status, metaCampaignId, thumbUrl;

  /// The status Meta shows for it ("Paused", "Ended"…); '' = not read from Meta.
  final String metaStatus;
  final double budget, spend, revenue;
  final int reach, impressions, clicks, results, leads, qualified, hot, warm, nurture, cold, notRated, bookedLeads, bookings, workMinutes, workEntries;
  final double? ctr, cpl, conversionRate, roas;
  bool get hasBudget => budget > 0;

  factory HubCampaignRow.fromJson(Map<String, dynamic> j) => HubCampaignRow(
        id: _s(j['id']),
        title: _s(j['title']),
        brand: _s(j['brand']).isEmpty ? 'main' : _s(j['brand']),
        platform: _s(j['platform']),
        objective: _s(j['objective']),
        status: _s(j['status']).isEmpty ? 'active' : _s(j['status']),
        budget: _d(j['budget']),
        metaCampaignId: _s(j['metaCampaignId']),
        metaStatus: _s(j['metaStatus']),
        spend: _d(j['spend']),
        reach: _i(j['reach']),
        impressions: _i(j['impressions']),
        clicks: _i(j['clicks']),
        results: _i(j['results']),
        ctr: _dn(j['ctr']),
        leads: _i(j['leads']),
        qualified: _i(j['qualified']),
        hot: _i(j['hot']),
        warm: _i(j['warm']),
        nurture: _i(j['nurture']),
        cold: _i(j['cold']),
        notRated: _i(j['notRated']),
        bookedLeads: _i(j['bookedLeads']),
        bookings: _i(j['bookings']),
        revenue: _d(j['revenue']),
        cpl: _dn(j['cpl']),
        conversionRate: _dn(j['conversionRate']),
        roas: _dn(j['roas']),
        workMinutes: _i(j['workMinutes']),
        workEntries: _i(j['workEntries']),
        thumbUrl: _s(j['thumbUrl']),
      );
}

/// How many campaigns are in each status (the All Campaigns KPI strip and the Overview's chips).
class HubCampaignCounts {
  const HubCampaignCounts({this.total = 0, this.planned = 0, this.active = 0, this.paused = 0, this.completed = 0});
  final int total, planned, active, paused, completed;
  factory HubCampaignCounts.fromJson(Map<String, dynamic> j) => HubCampaignCounts(total: _i(j['total']), planned: _i(j['planned']), active: _i(j['active']), paused: _i(j['paused']), completed: _i(j['completed']));
}

/// One ad: its ratios, its CRM leads and where it stands against the brand's average (the server's verdict).
///  • [figures] 'range' = an ad imported from Ads Manager's ad-level export: the days of the selected dates. 'lifetime' = an ad typed by
///    hand: the cumulative figures typed on it (the dates do not narrow them).
///  • [leads] = the CRM leads of the dates whose "creative" names this ad (null when the server did not count them); [cpl] = the ad's spend
///    ÷ those leads, only for an ad with daily figures (null otherwise — shown as "—").
class HubAdRow {
  const HubAdRow({required this.id, required this.name, this.campaignId = '', this.campaign = '', this.adSetName = '', this.metaAdId = '', this.format = 'image', this.status = 'active', this.metaStatus = '', this.creativeUrl = '', this.thumbUrl = '', this.thumbFromMeta = false, this.figures = 'lifetime', this.impressions = 0, this.reach = 0, this.clicks = 0, this.spend = 0, this.results = 0, this.ctr, this.cpm, this.costPerResult, this.leads, this.cpl, this.verdict = 'ok'});
  final String id, name, campaignId, campaign, adSetName, metaAdId, format, status, creativeUrl, thumbUrl, figures, verdict;

  /// Meta's own word for the ad ("Ad set paused", "Rejected by Meta", "In review"…); '' = not read from Meta.
  final String metaStatus;

  /// The picture is the ad's own on Meta (each sync refreshes it).
  final bool thumbFromMeta;
  final int impressions, reach, clicks, results;
  final int? leads;
  final double spend;
  final double? ctr, cpm, costPerResult, cpl;
  bool get isLifetime => figures != 'range';
  factory HubAdRow.fromJson(Map<String, dynamic> j) => HubAdRow(
        id: _s(j['id']),
        name: _s(j['name']),
        campaignId: _s(j['campaignId']),
        campaign: _s(j['campaign']),
        adSetName: _s(j['adSetName']),
        metaAdId: _s(j['metaAdId']),
        format: _s(j['format']).isEmpty ? 'image' : _s(j['format']),
        status: _s(j['status']).isEmpty ? 'active' : _s(j['status']),
        metaStatus: _s(j['metaStatus']),
        creativeUrl: _s(j['creativeUrl']),
        thumbUrl: _s(j['thumbUrl']),
        thumbFromMeta: j['thumbFromMeta'] == true,
        figures: _s(j['figures']) == 'range' ? 'range' : 'lifetime',
        impressions: _i(j['impressions']),
        reach: _i(j['reach']),
        clicks: _i(j['clicks']),
        spend: _d(j['spend']),
        results: _i(j['results']),
        ctr: _dn(j['ctr']),
        cpm: _dn(j['cpm']),
        costPerResult: _dn(j['costPerResult']),
        leads: _inn(j['leads']),
        cpl: _dn(j['cpl']),
        verdict: _s(j['verdict']).isEmpty ? 'ok' : _s(j['verdict']),
      );
}

// ── Audiences & placements (Ads Manager breakdown exports) ────────────────────────────────────────────────────────────────────

/// The breakdowns, in the order they are shown.
const kAudienceFields = [('age', 'Age'), ('gender', 'Gender'), ('placement', 'Placement')];

/// One audience / placement segment of the range: its spend and the platform's results (Meta's — the CRM does not record a lead's age
/// or placement).
class AudienceSegment {
  const AudienceSegment({required this.segment, this.spend = 0, this.impressions = 0, this.clicks = 0, this.results = 0, this.ctr, this.costPerResult, this.spendPct});
  final String segment;
  final double spend;
  final int impressions, clicks, results;
  final double? ctr, costPerResult, spendPct;
  factory AudienceSegment.fromJson(Map<String, dynamic> j) => AudienceSegment(
        segment: _s(j['segment']).isEmpty ? 'Unknown' : _s(j['segment']),
        spend: _d(j['spend']),
        impressions: _i(j['impressions']),
        clicks: _i(j['clicks']),
        results: _i(j['results']),
        ctr: _dn(j['ctr']),
        costPerResult: _dn(j['costPerResult']),
        spendPct: _dn(j['spendPct']),
      );
}

/// The top segments of one breakdown, and the dimension of the file they were read from ('age', 'age+gender', 'placement'…).
class AudienceField {
  const AudienceField({this.dimension = '', this.rows = const []});
  final String dimension;
  final List<AudienceSegment> rows;
  factory AudienceField.fromJson(Map<String, dynamic> j) => AudienceField(dimension: _s(j['dimension']), rows: _l(j['rows']).map(AudienceSegment.fromJson).toList());
}

/// Audiences & placements of the range (GET /audiences, and the Overview's `audiences`): by age, gender and placement.
class HubAudiences {
  const HubAudiences({this.hasData = false, this.age = const AudienceField(), this.gender = const AudienceField(), this.placement = const AudienceField()});
  final bool hasData;
  final AudienceField age, gender, placement;
  AudienceField of(String key) => switch (key) {
        'gender' => gender,
        'placement' => placement,
        _ => age,
      };
  bool get isEmpty => age.rows.isEmpty && gender.rows.isEmpty && placement.rows.isEmpty;
  factory HubAudiences.fromJson(Map<String, dynamic> j) => HubAudiences(
        hasData: j['hasData'] == true,
        age: AudienceField.fromJson(_m(j['age'])),
        gender: AudienceField.fromJson(_m(j['gender'])),
        placement: AudienceField.fromJson(_m(j['placement'])),
      );
}

// ── Overview ──────────────────────────────────────────────────────────────────────────────────────────────────────────────────

class OverviewData {
  const OverviewData({
    this.kpis = const HubKpis(),
    this.trend = const [],
    this.leadsByType = const [],
    this.meta = const HubMeta(),
    this.counts = const HubCampaignCounts(),
    this.active = const [],
    this.paused = const [],
    this.completed = const [],
    this.topAds = const [],
    this.audiences = const HubAudiences(),
    this.insights = const [],
  });
  final HubKpis kpis;
  final List<HubTrendPoint> trend;

  /// Leads by campaign type (lead gen / WhatsApp / website form / calls / others — the server's keys and labels).
  final List<LeadTypeSlice> leadsByType;
  final HubMeta meta;
  final HubCampaignCounts counts;
  final List<HubCampaignRow> active, paused, completed;
  final List<HubAdRow> topAds;
  final HubAudiences audiences;
  final List<HubInsight> insights;

  List<HubCampaignRow> rowsFor(String status) => switch (status) {
        'paused' => paused,
        'completed' => completed,
        _ => active,
      };

  factory OverviewData.fromJson(Map<String, dynamic> j) {
    final c = _m(j['campaigns']);
    return OverviewData(
      kpis: HubKpis.fromJson(_m(j['kpis'])),
      trend: _trend(j['trend']),
      leadsByType: _l(j['leadsByType']).map(LeadTypeSlice.fromJson).toList(),
      meta: HubMeta.fromJson(_m(j['meta'])),
      counts: HubCampaignCounts.fromJson(_m(j['counts'])),
      active: _l(c['active']).map(HubCampaignRow.fromJson).toList(),
      paused: _l(c['paused']).map(HubCampaignRow.fromJson).toList(),
      completed: _l(c['completed']).map(HubCampaignRow.fromJson).toList(),
      topAds: _l(j['topAds']).map(HubAdRow.fromJson).toList(),
      audiences: HubAudiences.fromJson(_m(j['audiences'])),
      insights: _l(j['insights']).map(HubInsight.fromJson).toList(),
    );
  }
}

// ── All Campaigns ─────────────────────────────────────────────────────────────────────────────────────────────────────────────

class HubCampaignQuery {
  const HubCampaignQuery({this.q = '', this.status = 'all', this.platform = 'all', this.objective = 'all', this.page = 1});
  final String q, status, platform, objective;
  final int page;
  HubCampaignQuery copyWith({String? q, String? status, String? platform, String? objective, int? page}) => HubCampaignQuery(q: q ?? this.q, status: status ?? this.status, platform: platform ?? this.platform, objective: objective ?? this.objective, page: page ?? this.page);

  @override
  bool operator ==(Object other) => other is HubCampaignQuery && other.q == q && other.status == status && other.platform == platform && other.objective == objective && other.page == page;
  @override
  int get hashCode => Object.hash(q, status, platform, objective, page);
}

class HubCampaignPage {
  const HubCampaignPage({this.counts = const HubCampaignCounts(), this.items = const [], this.total = 0, this.page = 1, this.pageSize = 10});
  final HubCampaignCounts counts;
  final List<HubCampaignRow> items;
  final int total, page, pageSize;
  factory HubCampaignPage.fromJson(Map<String, dynamic> j) => HubCampaignPage(counts: HubCampaignCounts.fromJson(_m(j['counts'])), items: _l(j['items']).map(HubCampaignRow.fromJson).toList(), total: _i(j['total']), page: _i(j['page']) == 0 ? 1 : _i(j['page']), pageSize: _i(j['pageSize']) == 0 ? 10 : _i(j['pageSize']));
}

/// One day's figures of one campaign (typed or imported).
class DayRecord {
  const DayRecord({required this.id, required this.day, this.spend = 0, this.reach = 0, this.impressions = 0, this.clicks = 0, this.results = 0, this.source = 'manual'});
  final String id, day, source;
  final double spend;
  final int reach, impressions, clicks, results;
  factory DayRecord.fromJson(Map<String, dynamic> j) => DayRecord(id: _s(j['id']), day: _s(j['day']), spend: _d(j['spend']), reach: _i(j['reach']), impressions: _i(j['impressions']), clicks: _i(j['clicks']), results: _i(j['results']), source: _s(j['source']));
}

/// A campaign's budget against its spend (null budget = "No budget set").
class HubBudgetRow {
  const HubBudgetRow({required this.id, required this.title, this.brand = 'main', this.status = 'active', this.hasBudget = false, this.budget = 0, this.spentToDate = 0, this.remaining, this.overBy = 0, this.utilisationPct, this.spendInPeriod = 0});
  final String id, title, brand, status;
  final bool hasBudget;
  final double budget, spentToDate, overBy, spendInPeriod;
  final double? remaining, utilisationPct;
  factory HubBudgetRow.fromJson(Map<String, dynamic> j) => HubBudgetRow(
        id: _s(j['id']),
        title: _s(j['title']),
        brand: _s(j['brand']).isEmpty ? 'main' : _s(j['brand']),
        status: _s(j['status']).isEmpty ? 'active' : _s(j['status']),
        hasBudget: j['hasBudget'] == true,
        budget: _d(j['budget']),
        spentToDate: _d(j['spentToDate']),
        remaining: _dn(j['remaining']),
        overBy: _d(j['overBy']),
        utilisationPct: _dn(j['utilisationPct']),
        spendInPeriod: _d(j['spendInPeriod']),
      );
}

class WorkMember {
  const WorkMember({required this.memberId, required this.name, this.minutes = 0, this.entries = 0});
  final String memberId, name;
  final int minutes, entries;
  factory WorkMember.fromJson(Map<String, dynamic> j) => WorkMember(memberId: _s(j['memberId']), name: _s(j['name']), minutes: _i(j['minutes']), entries: _i(j['entries']));
}

class WorkEntry {
  const WorkEntry({required this.id, this.member = '', this.workedOn = '', this.status = 'completed', this.minutes = 0, this.day = ''});
  final String id, member, workedOn, status, day;
  final int minutes;
  factory WorkEntry.fromJson(Map<String, dynamic> j) => WorkEntry(id: _s(j['id']), member: _s(j['member']), workedOn: _s(j['workedOn']), status: _s(j['status']), minutes: _i(j['minutes']), day: _s(j['day']));
}

/// The work members logged against a campaign (Log Activity → Campaign): who, how long, and the latest entries.
class WorkSummary {
  const WorkSummary({this.minutes = 0, this.entries = 0, this.members = const [], this.recent = const []});
  final int minutes, entries;
  final List<WorkMember> members;
  final List<WorkEntry> recent;
  factory WorkSummary.fromJson(Map<String, dynamic> j) => WorkSummary(minutes: _i(j['minutes']), entries: _i(j['entries']), members: _l(j['members']).map(WorkMember.fromJson).toList(), recent: _l(j['recent']).map(WorkEntry.fromJson).toList());
}

class HubCampaignDetail {
  const HubCampaignDetail({required this.campaign, this.row, this.kpis = const HubKpis(), this.trend = const [], this.days = const [], this.budget, this.ads = const [], this.work = const WorkSummary()});
  final HubCampaign campaign;
  final HubCampaignRow? row;
  final HubKpis kpis;
  final List<HubTrendPoint> trend;
  final List<DayRecord> days;
  final HubBudgetRow? budget;
  final List<HubAdRow> ads;
  final WorkSummary work;
  factory HubCampaignDetail.fromJson(Map<String, dynamic> j) => HubCampaignDetail(
        campaign: HubCampaign.fromJson(_m(j['campaign'])),
        row: j['row'] == null ? null : HubCampaignRow.fromJson(_m(j['row'])),
        kpis: HubKpis.fromJson(_m(j['kpis'])),
        trend: _trend(j['trend']),
        days: _l(j['days']).map(DayRecord.fromJson).toList(),
        budget: j['budget'] == null ? null : HubBudgetRow.fromJson(_m(j['budget'])),
        ads: _l(j['ads']).map(HubAdRow.fromJson).toList(),
        work: WorkSummary.fromJson(_m(j['work'])),
      );
}

// ── Performance ───────────────────────────────────────────────────────────────────────────────────────────────────────────────

class ObjectiveRow {
  const ObjectiveRow({required this.key, required this.label, this.campaigns = 0, this.spend = 0, this.leads = 0, this.cpl, this.results = 0});
  final String key, label;
  final int campaigns, leads, results;
  final double spend;
  final double? cpl;
  factory ObjectiveRow.fromJson(Map<String, dynamic> j) => ObjectiveRow(key: _s(j['key']), label: _s(j['label']), campaigns: _i(j['campaigns']), spend: _d(j['spend']), leads: _i(j['leads']), cpl: _dn(j['cpl']), results: _i(j['results']));
}

class HubPerformance {
  const HubPerformance({this.kpis = const HubKpis(), this.trend = const [], this.objectives = const []});
  final HubKpis kpis;
  final List<HubTrendPoint> trend;
  final List<ObjectiveRow> objectives;
  factory HubPerformance.fromJson(Map<String, dynamic> j) => HubPerformance(kpis: HubKpis.fromJson(_m(j['kpis'])), trend: _trend(j['trend']), objectives: _l(j['objectives']).map(ObjectiveRow.fromJson).toList());
}

// ── Creatives & Ads ───────────────────────────────────────────────────────────────────────────────────────────────────────────

class HubAdQuery {
  const HubAdQuery({this.filter = 'all', this.q = '', this.campaignId, this.page = 1});
  final String filter, q;
  final String? campaignId;
  final int page;
  HubAdQuery copyWith({String? filter, String? q, String? campaignId, bool clearCampaign = false, int? page}) => HubAdQuery(filter: filter ?? this.filter, q: q ?? this.q, campaignId: clearCampaign ? null : (campaignId ?? this.campaignId), page: page ?? this.page);

  @override
  bool operator ==(Object other) => other is HubAdQuery && other.filter == filter && other.q == q && other.campaignId == campaignId && other.page == page;
  @override
  int get hashCode => Object.hash(filter, q, campaignId, page);
}

/// The Creatives & Ads strip: [leads] = the CRM leads matched to the ads; [cpl] = the imported ads' spend ÷ their CRM leads; [lifetimeAds] =
/// how many ads show typed lifetime figures.
class AdKpis {
  const AdKpis({this.total = 0, this.top = 0, this.ctr, this.cpm, this.costPerResult, this.spend = 0, this.results = 0, this.leads = 0, this.cpl, this.lifetimeAds = 0});
  final int total, top, results, leads, lifetimeAds;
  final double spend;
  final double? ctr, cpm, costPerResult, cpl;
  factory AdKpis.fromJson(Map<String, dynamic> j) => AdKpis(total: _i(j['total']), top: _i(j['top']), ctr: _dn(j['ctr']), cpm: _dn(j['cpm']), costPerResult: _dn(j['costPerResult']), spend: _d(j['spend']), results: _i(j['results']), leads: _i(j['leads']), cpl: _dn(j['cpl']), lifetimeAds: _i(j['lifetimeAds']));
}

class AdsData {
  const AdsData({this.kpis = const AdKpis(), this.counts = const {}, this.items = const [], this.total = 0, this.page = 1, this.pageSize = 10});
  final AdKpis kpis;
  final Map<String, int> counts;
  final List<HubAdRow> items;
  final int total, page, pageSize;
  int countOf(String key) => counts[key] ?? 0;
  factory AdsData.fromJson(Map<String, dynamic> j) => AdsData(
        kpis: AdKpis.fromJson(_m(j['kpis'])),
        counts: _m(j['counts']).map((k, v) => MapEntry(k, _i(v))),
        items: _l(j['items']).map(HubAdRow.fromJson).toList(),
        total: _i(j['total']),
        page: _i(j['page']) == 0 ? 1 : _i(j['page']),
        pageSize: _i(j['pageSize']) == 0 ? 10 : _i(j['pageSize']),
      );
}

// ── Budget & Spend ────────────────────────────────────────────────────────────────────────────────────────────────────────────

class BudgetSummary {
  const BudgetSummary({this.budgetedCampaigns = 0, this.unbudgetedCampaigns = 0, this.totalBudget = 0, this.spentToDate = 0, this.remaining = 0, this.overBy = 0, this.utilisationPct, this.remainingPct, this.utilisationChangePts, this.spendInPeriod = 0, this.unbudgetedSpendInPeriod = 0});
  final int budgetedCampaigns, unbudgetedCampaigns;
  final double totalBudget, spentToDate, remaining, overBy, spendInPeriod, unbudgetedSpendInPeriod;
  final double? utilisationPct, remainingPct, utilisationChangePts;
  factory BudgetSummary.fromJson(Map<String, dynamic> j) => BudgetSummary(
        budgetedCampaigns: _i(j['budgetedCampaigns']),
        unbudgetedCampaigns: _i(j['unbudgetedCampaigns']),
        totalBudget: _d(j['totalBudget']),
        spentToDate: _d(j['spentToDate']),
        remaining: _d(j['remaining']),
        overBy: _d(j['overBy']),
        utilisationPct: _dn(j['utilisationPct']),
        remainingPct: _dn(j['remainingPct']),
        utilisationChangePts: _dn(j['utilisationChangePts']),
        spendInPeriod: _d(j['spendInPeriod']),
        unbudgetedSpendInPeriod: _d(j['unbudgetedSpendInPeriod']),
      );
}

class DaySpend {
  const DaySpend({required this.day, this.spend = 0});
  final String day;
  final double spend;
  factory DaySpend.fromJson(Map<String, dynamic> j) => DaySpend(day: _s(j['day']), spend: _d(j['spend']));
}

class SpendSlice {
  const SpendSlice({this.id, required this.label, this.spend = 0, this.pct = 0});
  final String? id;
  final String label;
  final double spend, pct;
  factory SpendSlice.fromJson(Map<String, dynamic> j) => SpendSlice(id: j['id'] == null ? null : _s(j['id']), label: _s(j['label']), spend: _d(j['spend']), pct: _d(j['pct']));
}

class BudgetData {
  const BudgetData({this.summary = const BudgetSummary(), this.daily = const [], this.splitTotal = 0, this.split = const [], this.rows = const [], this.hasSpend = false});
  final BudgetSummary summary;
  final List<DaySpend> daily;
  final double splitTotal;
  final List<SpendSlice> split;
  final List<HubBudgetRow> rows;
  final bool hasSpend;
  factory BudgetData.fromJson(Map<String, dynamic> j) {
    final s = _m(j['split']);
    return BudgetData(
      summary: BudgetSummary.fromJson(_m(j['summary'])),
      daily: _l(j['daily']).map(DaySpend.fromJson).toList(),
      splitTotal: _d(s['total']),
      split: _l(s['slices']).map(SpendSlice.fromJson).toList(),
      rows: _l(j['rows']).map(HubBudgetRow.fromJson).toList(),
      hasSpend: j['hasSpend'] == true,
    );
  }
}

// ── Leads & Conversions ───────────────────────────────────────────────────────────────────────────────────────────────────────

class HubFunnelStep {
  const HubFunnelStep({required this.key, required this.label, this.count = 0, this.pct});
  final String key, label;
  final int count;
  final double? pct;
  factory HubFunnelStep.fromJson(Map<String, dynamic> j) => HubFunnelStep(key: _s(j['key']), label: _s(j['label']), count: _i(j['count']), pct: _dn(j['pct']));
}

class LeadsData {
  const LeadsData({this.kpis = const HubKpis(), this.funnel = const [], this.quality = const {}, this.trend = const [], this.rows = const []});
  final HubKpis kpis;
  final List<HubFunnelStep> funnel;
  final Map<String, int> quality;
  final List<HubTrendPoint> trend;
  final List<HubCampaignRow> rows;
  factory LeadsData.fromJson(Map<String, dynamic> j) => LeadsData(
        kpis: HubKpis.fromJson(_m(j['kpis'])),
        funnel: _l(j['funnel']).map(HubFunnelStep.fromJson).toList(),
        quality: _m(j['quality']).map((k, v) => MapEntry(k, _i(v))),
        trend: _trend(j['trend']),
        rows: _l(j['rows']).map(HubCampaignRow.fromJson).toList(),
      );
}

// ── Reports & Insights ────────────────────────────────────────────────────────────────────────────────────────────────────────

class ReportCard {
  const ReportCard({required this.type, required this.title, this.description = '', this.rows = 0});
  final String type, title, description;
  final int rows;
  factory ReportCard.fromJson(Map<String, dynamic> j) => ReportCard(type: _s(j['type']), title: _s(j['title']), description: _s(j['description']), rows: _i(j['rows']));
}

class ReportsData {
  const ReportsData({this.kpis = const HubKpis(), this.cards = const [], this.insights = const [], this.imports = const [], this.meta = const HubMeta(), this.scheduledReports = false});
  final HubKpis kpis;
  final List<ReportCard> cards;
  final List<HubInsight> insights;
  final List<ImportInfo> imports;
  final HubMeta meta;
  final bool scheduledReports;
  factory ReportsData.fromJson(Map<String, dynamic> j) => ReportsData(
        kpis: HubKpis.fromJson(_m(j['kpis'])),
        cards: _l(j['cards']).map(ReportCard.fromJson).toList(),
        insights: _l(j['insights']).map(HubInsight.fromJson).toList(),
        imports: _l(j['imports']).map(ImportInfo.fromJson).toList(),
        meta: HubMeta.fromJson(_m(j['meta'])),
        scheduledReports: j['scheduledReports'] == true,
      );
}

/// One report as a table, ready for a CSV.
class ReportTable {
  const ReportTable({required this.type, this.title = '', this.columns = const [], this.rows = const [], this.filename = 'report.csv'});
  final String type, title, filename;
  final List<String> columns;
  final List<List<Object?>> rows;
  factory ReportTable.fromJson(Map<String, dynamic> j) => ReportTable(
        type: _s(j['type']),
        title: _s(j['title']),
        columns: _ls(j['columns']),
        rows: ((j['rows'] as List?) ?? const []).map((r) => (r as List).cast<Object?>().toList()).toList(),
        filename: _s(j['filename']).isEmpty ? 'report.csv' : _s(j['filename']),
      );
}

// ── pickers ───────────────────────────────────────────────────────────────────────────────────────────────────────────────────

class HubCampaignOption {
  const HubCampaignOption({required this.id, required this.title, this.brand = 'main', this.status = 'active'});
  final String id, title, brand, status;
  factory HubCampaignOption.fromJson(Map<String, dynamic> j) => HubCampaignOption(id: _s(j['id']), title: _s(j['title']), brand: _s(j['brand']), status: _s(j['status']));
}

class HubSetup {
  const HubSetup({this.campaigns = const []});
  final List<HubCampaignOption> campaigns;
  factory HubSetup.fromJson(Map<String, dynamic> j) => HubSetup(campaigns: _l(j['campaigns']).map(HubCampaignOption.fromJson).toList());
}

// ── the import's answer ───────────────────────────────────────────────────────────────────────────────────────────────────────

/// Why a Meta campaign was not put on one of ours, in words ('' = simply not found).
String importReasonText(String reason) => switch (reason) {
      'ambiguous' => 'two of our campaigns share this name',
      'other_meta_id' => 'our campaign of this name is linked to another Meta campaign',
      'same_name' => 'two Meta campaigns have this name',
      _ => '',
    };

/// A campaign of the file: matched to one of ours (campaignId, title) or not (reason: no_match | ambiguous | other_meta_id | same_name).
class ImportGroup {
  const ImportGroup({required this.name, this.metaId = '', this.campaignId = '', this.title = '', this.reason = '', this.rows = 0, this.days = 0, this.ads = 0, this.segments = 0, this.spend = 0});
  final String name, metaId, campaignId, title, reason;
  final int rows, days, ads, segments;
  final double spend;
  factory ImportGroup.fromJson(Map<String, dynamic> j) => ImportGroup(name: _s(j['name']), metaId: _s(j['metaId']), campaignId: _s(j['campaignId']), title: _s(j['title']), reason: _s(j['reason']), rows: _i(j['rows']), days: _i(j['days']), ads: _i(j['ads']), segments: _i(j['segments']), spend: _d(j['spend']));
}

/// The answer to one import request. [level]: 'campaign' | 'ad' | 'breakdown' (what one row of the file was); [written] counts
/// campaign-days, ad-days or segment-days by level; [adsCreated] = ads added from an ad-level file.
class HubImportReport {
  const HubImportReport({this.dryRun = false, this.level = 'campaign', this.rows = 0, this.skipped = 0, this.skippedRows = const [], this.matched = const [], this.unmatched = const [], this.created = 0, this.written = 0, this.adsCreated = 0, this.adsSkipped = const [], this.importId, this.from, this.to});

  /// Ad rows NOT written: two of the campaign's ads share the name and the file has no Ad ID column to tell them apart.
  final List<({String campaign, String ad, double spend})> adsSkipped;
  final bool dryRun;
  final String level;
  final int rows, skipped, created, written, adsCreated;
  final List<({int index, String reason})> skippedRows;
  final List<ImportGroup> matched, unmatched;
  final String? importId, from, to;
  factory HubImportReport.fromJson(Map<String, dynamic> j) => HubImportReport(
        dryRun: j['dryRun'] == true,
        level: _s(j['level']).isEmpty ? 'campaign' : _s(j['level']),
        rows: _i(j['rows']),
        skipped: _i(j['skipped']),
        skippedRows: _l(j['skippedRows']).map((e) => (index: _i(e['index']), reason: _s(e['reason']))).toList(),
        matched: _l(j['matched']).map(ImportGroup.fromJson).toList(),
        unmatched: _l(j['unmatched']).map(ImportGroup.fromJson).toList(),
        created: _i(j['created']),
        written: _i(j['written']),
        adsCreated: _i(j['adsCreated']),
        adsSkipped: _l(j['adsSkipped']).map((e) => (campaign: _s(e['campaign']), ad: _s(e['ad']), spend: _d(e['spend']))).toList(),
        importId: j['importId'] == null ? null : _s(j['importId']),
        from: j['from'] == null ? null : _s(j['from']),
        to: j['to'] == null ? null : _s(j['to']),
      );
}
