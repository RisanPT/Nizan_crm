// The Creative Portfolio's payloads (backend controllers/marketingPortfolioController.js).

int _i(dynamic v) => (v as num?)?.toInt() ?? 0;
int? _in(dynamic v) => (v as num?)?.toInt();
double? _dn(dynamic v) => (v as num?)?.toDouble();
String _s(dynamic v) => v?.toString() ?? '';
DateTime? _dt(dynamic v) => v == null ? null : DateTime.tryParse(v.toString())?.toLocal();
Map<String, dynamic> _m(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
List<Map<String, dynamic>> _l(dynamic v) => ((v as List?) ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();

const kShootStatuses = [
  ('planned', 'Planned'),
  ('pre_production', 'Pre-production'),
  ('in_production', 'In Production'),
  ('post_production', 'Post-production'),
  ('completed', 'Completed'),
  ('cancelled', 'Cancelled'),
];
String shootStatusLabel(String s) => kShootStatuses.firstWhere((e) => e.$1 == s, orElse: () => (s, s)).$2;

const kMilestoneLabels = {'brief': 'Brief', 'pre_production': 'Pre-production', 'production': 'Production', 'post_production': 'Post-production', 'distribution': 'Distribution'};

/// The planned (and delivered) outputs of a shoot, in the order the document lists them.
const kOutputKeys = [
  ('reels', 'Reels'),
  ('stills', 'Stills'),
  ('films', 'Films'),
  ('carousels', 'Carousels'),
  ('storyFrames', 'Story frames'),
  ('decks', 'Sales decks'),
];

Map<String, int> _counts(dynamic v) => _m(v).map((k, val) => MapEntry(k, _i(val)));

class ShootSummary {
  const ShootSummary({
    required this.id, required this.title, this.brand = 'main', this.category = '', this.shootType = '', this.status = 'planned', this.shootDate = '', this.startTime = '', this.endTime = '',
    this.location = '', this.coverUrl = '', this.crewCount = 0, this.progress = 0, this.planned = const {}, this.plannedTotal = 0, this.delivered = const {}, this.deliveredTotal = 0, this.turnaround,
    this.rescheduleCount = 0, this.delayed = false,
  });
  final String id, title, brand, category, shootType, status, shootDate, startTime, endTime, location, coverUrl;
  final int crewCount, progress, plannedTotal, deliveredTotal, rescheduleCount;
  final Map<String, int> planned, delivered;
  final int? turnaround;
  final bool delayed;

  factory ShootSummary.fromJson(Map<String, dynamic> j) => ShootSummary(
        id: _s(j['id']),
        title: _s(j['title']),
        brand: _s(j['brand']).isEmpty ? 'main' : _s(j['brand']),
        category: _s(j['category']),
        shootType: _s(j['shootType']),
        status: _s(j['status']),
        shootDate: _s(j['shootDate']),
        startTime: _s(j['startTime']),
        endTime: _s(j['endTime']),
        location: _s(j['location']),
        coverUrl: _s(j['coverUrl']),
        crewCount: _i(j['crewCount']),
        progress: _i(j['progress']),
        planned: _counts(j['planned']),
        plannedTotal: _i(j['plannedTotal']),
        delivered: _counts(j['delivered']),
        deliveredTotal: _i(j['deliveredTotal']),
        turnaround: _in(j['turnaround']),
        rescheduleCount: _i(j['rescheduleCount']),
        delayed: j['delayed'] == true,
      );

  String get time => startTime.isEmpty ? '' : (endTime.isEmpty ? startTime : '$startTime – $endTime');
}

class ShootCounts {
  const ShootCounts({this.total = 0, this.planned = 0, this.inProduction = 0, this.postProduction = 0, this.completed = 0, this.rescheduled = 0, this.thisWeek = 0, this.today = 0});
  final int total, planned, inProduction, postProduction, completed, rescheduled, thisWeek, today;
  factory ShootCounts.fromJson(Map<String, dynamic> j) => ShootCounts(total: _i(j['total']), planned: _i(j['planned']), inProduction: _i(j['inProduction']), postProduction: _i(j['postProduction']), completed: _i(j['completed']), rescheduled: _i(j['rescheduled']), thisWeek: _i(j['thisWeek']), today: _i(j['today']));
}

class PlannerData {
  const PlannerData({this.counts = const ShootCounts(), this.items = const [], this.total = 0, this.page = 1, this.pageSize = 8});
  final ShootCounts counts;
  final List<ShootSummary> items;
  final int total, page, pageSize;
  factory PlannerData.fromJson(Map<String, dynamic> j) => PlannerData(counts: ShootCounts.fromJson(_m(j['counts'])), items: _l(j['items']).map(ShootSummary.fromJson).toList(), total: _i(j['total']), page: _i(j['page']) == 0 ? 1 : _i(j['page']), pageSize: _i(j['pageSize']) == 0 ? 8 : _i(j['pageSize']));
}

class Milestone {
  const Milestone({required this.key, required this.label, this.date, this.doneAt});
  final String key, label;
  final String? date;
  final DateTime? doneAt;
  bool get done => doneAt != null;
  factory Milestone.fromJson(Map<String, dynamic> j) => Milestone(key: _s(j['key']), label: _s(j['label']).isEmpty ? (kMilestoneLabels[_s(j['key'])] ?? _s(j['key'])) : _s(j['label']), date: j['date'] == null ? null : _s(j['date']), doneAt: _dt(j['doneAt']));
}

class CrewMember {
  const CrewMember({this.memberId, this.name = '', this.role = ''});
  final String? memberId;
  final String name, role;
  factory CrewMember.fromJson(Map<String, dynamic> j) => CrewMember(memberId: j['memberId'] == null ? null : _s(j['memberId']), name: _s(j['name']), role: _s(j['role']));
  Map<String, dynamic> toJson() => {if (memberId != null) 'memberId': memberId, 'name': name, 'role': role};
}

class ShootAsset {
  const ShootAsset({required this.id, required this.title, this.kind = 'still', this.media = 'image', this.stage = 'raw', this.url = '', this.thumbUrl = '', this.isFinal = false, this.durationSec = 0, this.sizeMb = 0});
  final String id, title, kind, media, stage, url, thumbUrl;
  final bool isFinal;
  final int durationSec;
  final double sizeMb;
  factory ShootAsset.fromJson(Map<String, dynamic> j) => ShootAsset(id: _s(j['id']), title: _s(j['title']), kind: _s(j['kind']), media: _s(j['media']), stage: _s(j['stage']), url: _s(j['url']), thumbUrl: _s(j['thumbUrl']), isFinal: j['isFinal'] == true, durationSec: _i(j['durationSec']), sizeMb: _dn(j['sizeMb']) ?? 0);
}

class ShootLog {
  const ShootLog({required this.id, this.member = '', this.workedOn = '', this.stage = '', this.status = '', this.day = ''});
  final String id, member, workedOn, stage, status, day;
  factory ShootLog.fromJson(Map<String, dynamic> j) => ShootLog(id: _s(j['id']), member: _s(j['member']), workedOn: _s(j['workedOn']), stage: _s(j['stage']), status: _s(j['status']), day: _s(j['day']));
}

class ShootDetail {
  const ShootDetail({required this.summary, this.pillar = '', this.objective = '', this.audience = '', this.notes = '', this.crew = const [], this.references = const [], this.milestones = const [], this.currentMilestone = '', this.assets = const [], this.footageMb = 0, this.takeaways = const [], this.activity = const []});
  final ShootSummary summary;
  final String pillar, objective, audience, notes, currentMilestone;
  final List<CrewMember> crew;
  final List<({String label, String url})> references;
  final List<Milestone> milestones;
  final List<ShootAsset> assets;
  final double footageMb;
  final List<String> takeaways;
  final List<ShootLog> activity;

  factory ShootDetail.fromJson(Map<String, dynamic> j) {
    final brief = _m(j['brief']);
    return ShootDetail(
      summary: ShootSummary.fromJson(j),
      pillar: _s(j['pillar']),
      objective: _s(brief['objective']),
      audience: _s(brief['audience']),
      notes: _s(brief['notes']),
      crew: _l(j['crew']).map(CrewMember.fromJson).toList(),
      references: _l(j['references']).map((r) => (label: _s(r['label']), url: _s(r['url']))).toList(),
      milestones: _l(j['milestones']).map(Milestone.fromJson).toList(),
      currentMilestone: _s(j['currentMilestone']),
      assets: _l(j['assets']).map(ShootAsset.fromJson).toList(),
      footageMb: _dn(j['footageMb']) ?? 0,
      takeaways: ((j['takeaways'] as List?) ?? const []).map(_s).toList(),
      activity: _l(j['activity']).map(ShootLog.fromJson).toList(),
    );
  }
}

class LoadRow {
  const LoadRow({required this.key, required this.label, this.count = 0, this.pct = 0});
  final String key, label;
  final int count, pct;
  factory LoadRow.fromJson(Map<String, dynamic> j) => LoadRow(key: _s(j['key']), label: _s(j['label']), count: _i(j['count']), pct: _i(j['pct']));
}

class RoleAvailability {
  const RoleAvailability({required this.role, this.total = 0, this.booked = 0, this.onLeave = 0, this.available = 0});
  final String role;
  final int total, booked, onLeave, available;
  factory RoleAvailability.fromJson(Map<String, dynamic> j) => RoleAvailability(role: _s(j['role']), total: _i(j['total']), booked: _i(j['booked']), onLeave: _i(j['onLeave']), available: _i(j['available']));
}

class TodayShoot {
  const TodayShoot({required this.summary, this.milestones = const []});
  final ShootSummary summary;
  final List<Milestone> milestones;
  factory TodayShoot.fromJson(Map<String, dynamic> j) => TodayShoot(summary: ShootSummary.fromJson(j), milestones: _l(j['milestones']).map(Milestone.fromJson).toList());
}

class ProductionCalendar {
  const ProductionCalendar({this.day = '', this.counts = const ShootCounts(), this.items = const [], this.today = const [], this.upcoming = const [], this.loadTotal = 0, this.load = const [], this.availability = const []});
  final String day;
  final ShootCounts counts;
  final List<ShootSummary> items, upcoming;
  final List<TodayShoot> today;
  final int loadTotal;
  final List<LoadRow> load;
  final List<RoleAvailability> availability;
  factory ProductionCalendar.fromJson(Map<String, dynamic> j) => ProductionCalendar(
        day: _s(j['day']),
        counts: ShootCounts.fromJson(_m(j['counts'])),
        items: _l(j['items']).map(ShootSummary.fromJson).toList(),
        today: _l(j['today']).map(TodayShoot.fromJson).toList(),
        upcoming: _l(j['upcoming']).map(ShootSummary.fromJson).toList(),
        loadTotal: _i(_m(j['load'])['total']),
        load: _l(_m(j['load'])['rows']).map(LoadRow.fromJson).toList(),
        availability: _l(j['availability']).map(RoleAvailability.fromJson).toList(),
      );
}

class ReportKpis {
  const ReportKpis({this.shoots = 0, this.completed = 0, this.outputs = 0, this.footageGb, this.turnaround, this.change = const {}});
  final int shoots, completed, outputs;
  final double? footageGb, turnaround;
  final Map<String, int?> change;
  factory ReportKpis.fromJson(Map<String, dynamic> j) => ReportKpis(shoots: _i(j['shoots']), completed: _i(j['completed']), outputs: _i(j['outputs']), footageGb: _dn(j['footageGb']), turnaround: _dn(j['turnaround']), change: _m(j['change']).map((k, v) => MapEntry(k, _in(v))));
}

class MonthBar {
  const MonthBar({required this.month, this.shoots = 0, this.planned = 0, this.delivered = 0, this.turnaround});
  final String month;
  final int shoots, planned, delivered;
  final double? turnaround;
  factory MonthBar.fromJson(Map<String, dynamic> j) => MonthBar(month: _s(j['month']), shoots: _i(j['shoots']), planned: _i(j['planned']), delivered: _i(j['delivered']), turnaround: _dn(j['turnaround']));
}

class ShootReports {
  const ShootReports({this.kpis = const ReportKpis(), this.monthly = const [], this.distTotal = 0, this.distribution = const [], this.filters = const {}, this.rows = const [], this.total = 0, this.page = 1, this.pageSize = 8});
  final ReportKpis kpis;
  final List<MonthBar> monthly;
  final int distTotal;
  final List<LoadRow> distribution;
  final Map<String, int> filters;
  final List<ShootSummary> rows;
  final int total, page, pageSize;
  factory ShootReports.fromJson(Map<String, dynamic> j) => ShootReports(
        kpis: ReportKpis.fromJson(_m(j['kpis'])),
        monthly: _l(j['monthly']).map(MonthBar.fromJson).toList(),
        distTotal: _i(_m(j['distribution'])['total']),
        distribution: _l(_m(j['distribution'])['rows']).map(LoadRow.fromJson).toList(),
        filters: _counts(j['filters']),
        rows: _l(j['rows']).map(ShootSummary.fromJson).toList(),
        total: _i(j['total']),
        page: _i(j['page']) == 0 ? 1 : _i(j['page']),
        pageSize: _i(j['pageSize']) == 0 ? 8 : _i(j['pageSize']),
      );
}

class ShootSetup {
  const ShootSetup({this.members = const [], this.categories = const [], this.pillars = const [], this.shootTypes = const ['Full Shoot']});
  final List<({String id, String name, String role})> members;
  final List<String> categories, pillars, shootTypes;
  factory ShootSetup.fromJson(Map<String, dynamic> j) => ShootSetup(
        members: _l(j['members']).map((m) => (id: _s(m['id']), name: _s(m['name']), role: _s(m['role']))).toList(),
        categories: ((j['categories'] as List?) ?? const []).map(_s).toList(),
        pillars: ((j['pillars'] as List?) ?? const []).map(_s).toList(),
        shootTypes: ((j['shootTypes'] as List?) ?? const ['Full Shoot']).map(_s).toList(),
      );
}

/// How the planner's list is cut: status, search and page.
class PlannerQuery {
  const PlannerQuery({this.status = 'all', this.q = '', this.page = 1});
  final String status, q;
  final int page;
  @override
  bool operator ==(Object other) => other is PlannerQuery && other.status == status && other.q == q && other.page == page;
  @override
  int get hashCode => Object.hash(status, q, page);
}

/// How the report list is cut.
class ReportQuery {
  const ReportQuery({this.filter = 'all', this.q = '', this.page = 1});
  final String filter, q;
  final int page;
  @override
  bool operator ==(Object other) => other is ReportQuery && other.filter == filter && other.q == q && other.page == page;
  @override
  int get hashCode => Object.hash(filter, q, page);
}
