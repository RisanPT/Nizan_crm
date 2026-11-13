// The Socials module's payloads (backend controllers/marketingSocialsController.js).

int _i(dynamic v) => (v as num?)?.toInt() ?? 0;
int? _in(dynamic v) => (v as num?)?.toInt();
double? _dn(dynamic v) => (v as num?)?.toDouble();
String _s(dynamic v) => v?.toString() ?? '';
DateTime? _dt(dynamic v) => v == null ? null : DateTime.tryParse(v.toString())?.toLocal();
Map<String, dynamic> _m(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
List<Map<String, dynamic>> _l(dynamic v) => ((v as List?) ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
Map<String, int?> _changes(dynamic v) => _m(v).map((k, val) => MapEntry(k, _in(val)));

const kContentStageKeys = ['planned', 'producing', 'in_review', 'scheduled', 'published'];

/// The posts that went out in the range, by format, with the change on the period before.
class SocialsKpis {
  const SocialsKpis({this.total = 0, this.reels = 0, this.trialReels = 0, this.stories = 0, this.feed = 0, this.collab = 0, this.change = const {}});
  final int total, reels, trialReels, stories, feed, collab;
  final Map<String, int?> change;
  factory SocialsKpis.fromJson(Map<String, dynamic> j) => SocialsKpis(
        total: _i(j['total']),
        reels: _i(j['reels']),
        trialReels: _i(j['trialReels']),
        stories: _i(j['stories']),
        feed: _i(j['feed']),
        collab: _i(j['collab']),
        change: _changes(j['change']),
      );
}

class StageCount {
  const StageCount({required this.key, required this.label, this.count = 0, this.pct = 0});
  final String key, label;
  final int count, pct;
  factory StageCount.fromJson(Map<String, dynamic> j) => StageCount(key: _s(j['key']), label: _s(j['label']), count: _i(j['count']), pct: _i(j['pct']));
}

class Pipeline {
  const Pipeline({this.total = 0, this.stages = const []});
  final int total;
  final List<StageCount> stages;
  factory Pipeline.fromJson(Map<String, dynamic> j) => Pipeline(total: _i(j['total']), stages: _l(j['stages']).map(StageCount.fromJson).toList());
  int countOf(String key) => stages.where((s) => s.key == key).fold(0, (a, s) => a + s.count);
}

class PlatformRow {
  const PlatformRow({required this.platform, required this.brand, required this.label, this.count = 0, this.spark = const [], this.change});
  final String platform, brand, label;
  final int count;
  final List<int> spark;
  final int? change;
  factory PlatformRow.fromJson(Map<String, dynamic> j) => PlatformRow(
        platform: _s(j['platform']),
        brand: _s(j['brand']),
        label: _s(j['label']),
        count: _i(j['count']),
        spark: ((j['spark'] as List?) ?? const []).map(_i).toList(),
        change: _in(j['change']),
      );
}

class TrackerRow {
  const TrackerRow({required this.metricId, required this.name, this.target, this.completed = 0, this.progress});
  final String metricId, name;
  final double? target;
  final double completed;
  final int? progress;
  factory TrackerRow.fromJson(Map<String, dynamic> j) => TrackerRow(metricId: _s(j['metricId']), name: _s(j['name']), target: _dn(j['target']), completed: _dn(j['completed']) ?? 0, progress: _in(j['progress']));
}

/// One post in a calendar cell, the publishing queue or the recent list.
class SocialPost {
  const SocialPost({required this.id, required this.title, this.platform = 'instagram', this.contentType = 'reel', this.status = 'idea', this.brand = 'main', this.scheduledDate, this.publishedDate, this.thumbUrl = '', this.permalink = '', this.assignedToName = '', this.views = 0, this.caption = '', this.campaign = '', this.metrics = const {}});
  final String id, title, platform, contentType, status, brand, thumbUrl, permalink, assignedToName, caption, campaign;
  final Map<String, int> metrics;
  final DateTime? scheduledDate, publishedDate;
  final int views;
  factory SocialPost.fromJson(Map<String, dynamic> j) => SocialPost(
        id: _s(j['id']),
        title: _s(j['title']),
        platform: _s(j['platform']),
        contentType: _s(j['contentType']),
        status: _s(j['status']),
        brand: _s(j['brand']).isEmpty ? 'main' : _s(j['brand']),
        scheduledDate: _dt(j['scheduledDate']),
        publishedDate: _dt(j['publishedDate']),
        thumbUrl: _s(j['thumbUrl']),
        permalink: _s(j['permalink']),
        assignedToName: _s(j['assignedToName']),
        views: _i(j['views']),
        caption: _s(j['caption']),
        campaign: _s(j['campaign']),
        metrics: _m(j['metrics']).map((k, v) => MapEntry(k, _i(v))),
      );
  DateTime? get day => publishedDate ?? scheduledDate;
}

class CalendarDay {
  const CalendarDay({required this.day, this.items = const []});
  final String day;
  final List<SocialPost> items;
  factory CalendarDay.fromJson(Map<String, dynamic> j) => CalendarDay(day: _s(j['day']), items: _l(j['items']).map(SocialPost.fromJson).toList());
}

class TeamAct {
  const TeamAct({required this.memberId, required this.name, this.activities = const [], this.status = 'in_progress'});
  final String memberId, name, status;
  final List<String> activities;
  factory TeamAct.fromJson(Map<String, dynamic> j) => TeamAct(memberId: _s(j['memberId']), name: _s(j['name']), activities: ((j['activities'] as List?) ?? const []).map(_s).toList(), status: _s(j['status']));
}

class EngagementOverview {
  const EngagementOverview({this.reach = 0, this.impressions = 0, this.views = 0, this.likes = 0, this.comments = 0, this.reposts = 0, this.shares = 0, this.saves = 0, this.linkClicks = 0, this.engagements = 0, this.engagementRate, this.change = const {}, this.engagementsChange});
  final int reach, impressions, views, likes, comments, reposts, shares, saves, linkClicks, engagements;
  final double? engagementRate;
  final Map<String, int?> change;
  final int? engagementsChange;
  factory EngagementOverview.fromJson(Map<String, dynamic> j) => EngagementOverview(
        reach: _i(j['reach']),
        impressions: _i(j['impressions']),
        views: _i(j['views']),
        likes: _i(j['likes']),
        comments: _i(j['comments']),
        reposts: _i(j['reposts']),
        shares: _i(j['shares']),
        saves: _i(j['saves']),
        linkClicks: _i(j['linkClicks']),
        engagements: _i(j['engagements']),
        engagementRate: _dn(j['engagementRate']),
        change: _changes(j['change']),
        engagementsChange: _in(j['engagementsChange']),
      );
}

class OrganicLeads {
  const OrganicLeads({this.total = 0, this.main = 0, this.kerala = 0, this.change});
  final int total, main, kerala;
  final int? change;
  factory OrganicLeads.fromJson(Map<String, dynamic> j) => OrganicLeads(total: _i(j['total']), main: _i(j['main']), kerala: _i(j['kerala']), change: _in(j['change']));
}

class FocusItem {
  const FocusItem({required this.id, required this.title, this.progress = 0, this.done = false});
  final String id, title;
  final int progress;
  final bool done;
  factory FocusItem.fromJson(Map<String, dynamic> j) => FocusItem(id: _s(j['id']), title: _s(j['title']), progress: _i(j['progress']), done: j['done'] == true);
}

class SocialsOverview {
  const SocialsOverview({
    this.from = '', this.to = '', this.kpis = const SocialsKpis(), this.pipeline = const Pipeline(), this.platforms = const [], this.tracker = const [], this.hasMetrics = false,
    this.calendar = const [], this.teamActivities = const [], this.teamDay = '', this.engagement = const EngagementOverview(), this.recentPosts = const [], this.leads = const OrganicLeads(),
    this.focus = const [], this.insights = const [],
  });
  final String from, to, teamDay;
  final SocialsKpis kpis;
  final Pipeline pipeline;
  final List<PlatformRow> platforms;
  final List<TrackerRow> tracker;
  final bool hasMetrics;
  final List<CalendarDay> calendar;
  final List<TeamAct> teamActivities;
  final EngagementOverview engagement;
  final List<SocialPost> recentPosts;
  final OrganicLeads leads;
  final List<FocusItem> focus;
  final List<String> insights;

  factory SocialsOverview.fromJson(Map<String, dynamic> j) => SocialsOverview(
        from: _s(j['from']),
        to: _s(j['to']),
        kpis: SocialsKpis.fromJson(_m(j['kpis'])),
        pipeline: Pipeline.fromJson(_m(j['pipeline'])),
        platforms: _l(j['platforms']).map(PlatformRow.fromJson).toList(),
        tracker: _l(_m(j['tracker'])['rows']).map(TrackerRow.fromJson).toList(),
        hasMetrics: _m(j['tracker'])['hasMetrics'] == true,
        calendar: _l(j['calendar']).map(CalendarDay.fromJson).toList(),
        teamActivities: _l(j['teamActivities']).map(TeamAct.fromJson).toList(),
        teamDay: _s(j['teamDay']),
        engagement: EngagementOverview.fromJson(_m(j['engagement'])),
        recentPosts: _l(j['recentPosts']).map(SocialPost.fromJson).toList(),
        leads: OrganicLeads.fromJson(_m(j['leads'])),
        focus: _l(j['focus']).map(FocusItem.fromJson).toList(),
        insights: ((j['insights'] as List?) ?? const []).map(_s).toList(),
      );
}

class SocialsCalendar {
  const SocialsCalendar({this.items = const [], this.pipeline = const Pipeline()});
  final List<SocialPost> items;
  final Pipeline pipeline;
  factory SocialsCalendar.fromJson(Map<String, dynamic> j) => SocialsCalendar(items: _l(j['items']).map(SocialPost.fromJson).toList(), pipeline: Pipeline.fromJson(_m(j['pipeline'])));
}

// ── assets ───────────────────────────────────────────────────────────────────

const kAssetStages = [
  ('raw', 'Raw / Footage'),
  ('in_edit', 'In Edit'),
  ('post_produced', 'Post-produced'),
  ('in_review', 'In Review'),
  ('approved', 'Approved / Final'),
  ('rejected', 'Rejected'),
];
const kAssetKinds = [('reel', 'Reel'), ('still', 'Still'), ('film', 'Film'), ('carousel', 'Carousel'), ('bts', 'BTS'), ('design', 'Design'), ('document', 'Document'), ('other', 'Other')];

String assetStageLabel(String s) => kAssetStages.firstWhere((e) => e.$1 == s, orElse: () => (s, s)).$2;
String assetKindLabel(String s) => kAssetKinds.firstWhere((e) => e.$1 == s, orElse: () => (s, s)).$2;

class Asset {
  const Asset({required this.id, required this.title, this.brand = 'main', this.kind = 'still', this.media = 'image', this.stage = 'raw', this.url = '', this.thumbUrl = '', this.portfolio = '', this.page = '', this.tags = const [], this.durationSec = 0, this.sizeMb = 0, this.shootId, this.isFinal = false, this.ownerName = ''});
  final String id, title, brand, kind, media, stage, url, thumbUrl, portfolio, page, ownerName;
  final List<String> tags;
  final int durationSec;
  final double sizeMb;
  final String? shootId;
  final bool isFinal;
  factory Asset.fromJson(Map<String, dynamic> j) => Asset(
        id: _s(j['id']),
        title: _s(j['title']),
        brand: _s(j['brand']),
        kind: _s(j['kind']),
        media: _s(j['media']),
        stage: _s(j['stage']),
        url: _s(j['url']),
        thumbUrl: _s(j['thumbUrl']),
        portfolio: _s(j['portfolio']),
        page: _s(j['page']),
        tags: ((j['tags'] as List?) ?? const []).map(_s).toList(),
        durationSec: _i(j['durationSec']),
        sizeMb: _dn(j['sizeMb']) ?? 0,
        shootId: j['shootId'] == null ? null : _s(j['shootId']),
        isFinal: j['isFinal'] == true,
        ownerName: _s(j['ownerName']),
      );
}

class AssetCounts {
  const AssetCounts({this.total = 0, this.photos = 0, this.videos = 0, this.finals = 0, this.approved = 0, this.approvedPct, this.postProducedPct});
  final int total, photos, videos, finals, approved;
  final int? approvedPct, postProducedPct;
  factory AssetCounts.fromJson(Map<String, dynamic> j) => AssetCounts(total: _i(j['total']), photos: _i(j['photos']), videos: _i(j['videos']), finals: _i(j['finals']), approved: _i(j['approved']), approvedPct: _in(j['approvedPct']), postProducedPct: _in(j['postProducedPct']));
}

class AssetList {
  const AssetList({this.items = const [], this.counts = const AssetCounts(), this.portfolios = const {}, this.pages = const {}, this.stages = const {}, this.media = const {}, this.kinds = const {}});
  final List<Asset> items;
  final AssetCounts counts;
  final Map<String, int> portfolios, pages, stages, media, kinds;
  factory AssetList.fromJson(Map<String, dynamic> j) {
    Map<String, int> facet(String k) => _m(_m(j['facets'])[k]).map((a, b) => MapEntry(a, _i(b)));
    return AssetList(items: _l(j['items']).map(Asset.fromJson).toList(), counts: AssetCounts.fromJson(_m(j['counts'])), portfolios: facet('portfolios'), pages: facet('pages'), stages: facet('stages'), media: facet('media'), kinds: facet('kinds'));
  }
}

class AssetQuery {
  const AssetQuery({this.q = '', this.stage, this.kind, this.media, this.portfolio, this.page, this.brand = 'all', this.sort = 'newest', this.shootId});
  final String q;
  final String? stage, kind, media, portfolio, page, shootId;
  final String brand, sort;

  AssetQuery copyWith({String? q, Object? stage = _keep, Object? kind = _keep, Object? media = _keep, Object? portfolio = _keep, Object? page = _keep, String? brand, String? sort}) => AssetQuery(
        q: q ?? this.q,
        stage: identical(stage, _keep) ? this.stage : stage as String?,
        kind: identical(kind, _keep) ? this.kind : kind as String?,
        media: identical(media, _keep) ? this.media : media as String?,
        portfolio: identical(portfolio, _keep) ? this.portfolio : portfolio as String?,
        page: identical(page, _keep) ? this.page : page as String?,
        brand: brand ?? this.brand,
        sort: sort ?? this.sort,
        shootId: shootId,
      );

  Map<String, dynamic> get query => {
        if (q.trim().isNotEmpty) 'q': q.trim(),
        'stage': ?stage,
        'kind': ?kind,
        'media': ?media,
        'portfolio': ?portfolio,
        'page': ?page,
        'shootId': ?shootId,
        if (brand != 'all') 'brand': brand,
        if (sort != 'newest') 'sort': sort,
      };

  @override
  bool operator ==(Object other) => other is AssetQuery && other.q == q && other.stage == stage && other.kind == kind && other.media == media && other.portfolio == portfolio && other.page == page && other.brand == brand && other.sort == sort && other.shootId == shootId;
  @override
  int get hashCode => Object.hash(q, stage, kind, media, portfolio, page, brand, sort, shootId);
}

const Object _keep = Object();

// ── accounts, publishing, targets ────────────────────────────────────────────

class SocialAccount {
  const SocialAccount({required this.id, required this.platform, this.brand = 'main', this.handle = '', this.status = 'manual', this.followers = 0, this.note = ''});
  final String id, platform, brand, handle, status, note;
  final int followers;
  factory SocialAccount.fromJson(Map<String, dynamic> j) => SocialAccount(id: _s(j['id']), platform: _s(j['platform']), brand: _s(j['brand']), handle: _s(j['handle']), status: _s(j['status']), followers: _i(j['followers']), note: _s(j['note']));
}

class PublishingData {
  const PublishingData({this.accounts = const [], this.queue = const [], this.recent = const []});
  final List<SocialAccount> accounts;
  final List<SocialPost> queue, recent;
  factory PublishingData.fromJson(Map<String, dynamic> j) => PublishingData(accounts: _l(j['accounts']).map(SocialAccount.fromJson).toList(), queue: _l(j['queue']).map(SocialPost.fromJson).toList(), recent: _l(j['recent']).map(SocialPost.fromJson).toList());
}

class TargetMetric {
  const TargetMetric({required this.id, required this.name, this.target});
  final String id, name;
  final double? target;
  factory TargetMetric.fromJson(Map<String, dynamic> j) => TargetMetric(id: _s(j['id']), name: _s(j['name']), target: _dn(j['target']));
}

class TargetsData {
  const TargetsData({this.week = '', this.metrics = const []});
  final String week;
  final List<TargetMetric> metrics;
  factory TargetsData.fromJson(Map<String, dynamic> j) => TargetsData(week: _s(j['week']), metrics: _l(j['metrics']).map(TargetMetric.fromJson).toList());
}

// ── performance and reports ──────────────────────────────────────────────────

class PlatformPerf {
  const PlatformPerf({required this.platform, required this.label, this.posts = 0, this.reach = 0, this.impressions = 0, this.engagements = 0, this.er});
  final String platform, label;
  final int posts, reach, impressions, engagements;
  final double? er;
  factory PlatformPerf.fromJson(Map<String, dynamic> j) => PlatformPerf(platform: _s(j['platform']), label: _s(j['label']), posts: _i(j['posts']), reach: _i(j['reach']), impressions: _i(j['impressions']), engagements: _i(j['engagements']), er: _dn(j['er']));
}

class TopPost {
  const TopPost({required this.id, required this.title, this.platform = '', this.brand = 'main', this.contentType = '', this.thumbUrl = '', this.permalink = '', this.views = 0, this.engagements = 0});
  final String id, title, platform, brand, contentType, thumbUrl, permalink;
  final int views, engagements;
  factory TopPost.fromJson(Map<String, dynamic> j) => TopPost(id: _s(j['id']), title: _s(j['title']), platform: _s(j['platform']), brand: _s(j['brand']), contentType: _s(j['contentType']), thumbUrl: _s(j['thumbUrl']), permalink: _s(j['permalink']), views: _i(j['views']), engagements: _i(j['engagements']));
}

class ReachPoint {
  const ReachPoint({required this.day, this.reach = 0, this.impressions = 0});
  final String day;
  final int reach, impressions;
  factory ReachPoint.fromJson(Map<String, dynamic> j) => ReachPoint(day: _s(j['day']), reach: _i(j['reach']), impressions: _i(j['impressions']));
}

class PerformanceTotals {
  const PerformanceTotals({this.reach = 0, this.impressions = 0, this.engagements = 0, this.engagementRate, this.videoViews = 0, this.linkClicks = 0, this.change = const {}});
  final int reach, impressions, engagements, videoViews, linkClicks;
  final double? engagementRate;
  final Map<String, int?> change;
  factory PerformanceTotals.fromJson(Map<String, dynamic> j) => PerformanceTotals(reach: _i(j['reach']), impressions: _i(j['impressions']), engagements: _i(j['engagements']), engagementRate: _dn(j['engagementRate']), videoViews: _i(j['videoViews']), linkClicks: _i(j['linkClicks']), change: _changes(j['change']));
}

class SocialsPerformance {
  const SocialsPerformance({this.totals = const PerformanceTotals(), this.trend = const [], this.platforms = const [], this.top = const [], this.contentStatus = const Pipeline()});
  final PerformanceTotals totals;
  final List<ReachPoint> trend;
  final List<PlatformPerf> platforms;
  final List<TopPost> top;
  final Pipeline contentStatus;
  factory SocialsPerformance.fromJson(Map<String, dynamic> j) => SocialsPerformance(
        totals: PerformanceTotals.fromJson(_m(j['totals'])),
        trend: _l(j['trend']).map(ReachPoint.fromJson).toList(),
        platforms: _l(j['platforms']).map(PlatformPerf.fromJson).toList(),
        top: _l(j['top']).map(TopPost.fromJson).toList(),
        contentStatus: Pipeline.fromJson(_m(j['contentStatus'])),
      );
}

class SummaryFigure {
  const SummaryFigure({this.value = 0, this.change});
  final int value;
  final int? change;
  factory SummaryFigure.fromJson(Map<String, dynamic> j) => SummaryFigure(value: _i(j['value']), change: _in(j['change']));
}

class MonthPoint {
  const MonthPoint({required this.month, this.reach = 0, this.impressions = 0, this.engagements = 0, this.posts = 0});
  final String month;
  final int reach, impressions, engagements, posts;
  factory MonthPoint.fromJson(Map<String, dynamic> j) => MonthPoint(month: _s(j['month']), reach: _i(j['reach']), impressions: _i(j['impressions']), engagements: _i(j['engagements']), posts: _i(j['posts']));
}

class SocialsReports {
  const SocialsReports({this.from = '', this.to = '', this.overallGrowth, this.reach = const SummaryFigure(), this.impressions = const SummaryFigure(), this.engagements = const SummaryFigure(), this.followers = const SummaryFigure(), this.growthTrend = const [], this.insights = const [], this.platforms = const [], this.top = const [], this.kpis = const SocialsKpis()});
  final String from, to;
  final int? overallGrowth;
  final SummaryFigure reach, impressions, engagements, followers;
  final List<MonthPoint> growthTrend;
  final List<String> insights;
  final List<PlatformPerf> platforms;
  final List<TopPost> top;
  final SocialsKpis kpis;
  factory SocialsReports.fromJson(Map<String, dynamic> j) {
    final s = _m(j['summary']);
    return SocialsReports(
      from: _s(j['from']),
      to: _s(j['to']),
      overallGrowth: _in(s['overallGrowth']),
      reach: SummaryFigure.fromJson(_m(s['reach'])),
      impressions: SummaryFigure.fromJson(_m(s['impressions'])),
      engagements: SummaryFigure.fromJson(_m(s['engagements'])),
      followers: SummaryFigure.fromJson(_m(s['followers'])),
      growthTrend: _l(j['growthTrend']).map(MonthPoint.fromJson).toList(),
      insights: ((j['insights'] as List?) ?? const []).map(_s).toList(),
      platforms: _l(j['platforms']).map(PlatformPerf.fromJson).toList(),
      top: _l(j['top']).map(TopPost.fromJson).toList(),
      kpis: SocialsKpis.fromJson(_m(j['kpis'])),
    );
  }
}

/// 27200 → "27.2K", 4500 → "4.5K", 1092450 → "1.09M", 312 → "312" — compact, for tiles and lists where the shape matters more than the last digit.
String compactCount(num n) {
  final v = n.toDouble();
  if (v >= 1e6 || v >= 999950) return '${(v / 1e6).toStringAsFixed(v >= 1e7 ? 1 : 2)}M';
  if (v >= 1e3) return '${(v / 1e3).toStringAsFixed(1)}K';
  return v.round().toString();
}

/// 468320 → "468,320": the exact figure with thousands separators, for the headline numbers and tables.
String groupedCount(num n) => n.round().toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');
