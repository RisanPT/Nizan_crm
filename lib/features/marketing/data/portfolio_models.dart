// The Creative Portfolio's payloads (backend controllers/marketingPortfolioController.js).

int _i(dynamic v) => (v as num?)?.toInt() ?? 0;
int? _in(dynamic v) => (v as num?)?.toInt();
double? _dn(dynamic v) => (v as num?)?.toDouble();
String _s(dynamic v) => v?.toString() ?? '';
String? _sn(dynamic v) => v == null || v.toString().isEmpty ? null : v.toString();
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
    this.rescheduleCount = 0, this.delayed = false, this.deliveredPosts = const {}, this.bookingId,
  });
  final String id, title, brand, category, shootType, status, shootDate, startTime, endTime, location, coverUrl;
  final int crewCount, progress, plannedTotal, deliveredTotal, rescheduleCount;

  /// [delivered] = approved / final assets and published posts, each once; [deliveredPosts] = how many of those were posts.
  final Map<String, int> planned, delivered, deliveredPosts;

  /// The work (CRM booking) the shoot covers.
  final String? bookingId;
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
        deliveredPosts: _counts(j['deliveredPosts']),
        bookingId: _sn(j['bookingId']),
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

/// A crew line: a Marketing team member ([memberId]), a makeup artist from the staff list ([employeeId]), or just a name.
class CrewMember {
  const CrewMember({this.memberId, this.employeeId, this.name = '', this.role = ''});
  final String? memberId, employeeId;
  final String name, role;
  factory CrewMember.fromJson(Map<String, dynamic> j) => CrewMember(memberId: _sn(j['memberId']), employeeId: _sn(j['employeeId']), name: _s(j['name']), role: _s(j['role']));
  Map<String, dynamic> toJson() => {if (memberId != null) 'memberId': memberId, if (employeeId != null) 'employeeId': employeeId, 'name': name, 'role': role};
}

/// One frame of a shoot's storyboard, in shooting order.
/// One storyboard frame: the shot (number, what it is, type, duration), its picture (a sketch, a still, a moodboard picture), a reference
/// link and notes — and, on the shoot day, whether it was filmed (who ticked it, when). [key] is the frame's own id on the server: a tick
/// finds the frame by it, and an edit that keeps it keeps the frame's tick.
class StoryFrame {
  const StoryFrame({this.key = '', this.shotNo = '', this.description = '', this.shotType = '', this.durationSec = 0, this.referenceUrl = '', this.imageUrl = '', this.notes = '', this.shotAt, this.shotByName = ''});
  final String key, shotNo, description, shotType, referenceUrl, imageUrl, notes, shotByName;
  final int durationSec;
  final DateTime? shotAt;
  bool get shot => shotAt != null;
  factory StoryFrame.fromJson(Map<String, dynamic> j) => StoryFrame(
        key: _s(j['key']),
        shotNo: _s(j['shotNo']),
        description: _s(j['description']),
        shotType: _s(j['shotType']),
        durationSec: _i(j['durationSec']),
        referenceUrl: _s(j['referenceUrl']),
        imageUrl: _s(j['imageUrl']),
        notes: _s(j['notes']),
        shotAt: _dt(j['shotAt']),
        shotByName: _s(j['shotByName']),
      );

  /// What an edit sends (the tick is the server's own — never sent).
  Map<String, dynamic> toJson() => {if (key.isNotEmpty) 'key': key, 'shotNo': shotNo, 'description': description, 'shotType': shotType, 'durationSec': durationSec, 'referenceUrl': referenceUrl, 'imageUrl': imageUrl, 'notes': notes};
}

/// A PDF on a shoot's moodboard or storyboard. The file itself is fetched through the server ([key]) — its stored address is never sent.
class ShootDocument {
  const ShootDocument({required this.key, this.part = 'moodboard', this.name = '', this.label = '', this.sizeBytes = 0, this.pages, this.addedByName = '', this.addedAt});
  final String key, part, name, label, addedByName;
  final int sizeBytes;
  final int? pages;
  final DateTime? addedAt;
  factory ShootDocument.fromJson(Map<String, dynamic> j) => ShootDocument(
        key: _s(j['key']),
        part: _s(j['part']).isEmpty ? 'moodboard' : _s(j['part']),
        name: _s(j['name']),
        label: _s(j['label']),
        sizeBytes: _i(j['sizeBytes']),
        pages: j['pages'] == null ? null : _i(j['pages']),
        addedByName: _s(j['addedByName']),
        addedAt: _dt(j['addedAt']),
      );

  /// What it is called on screen: its label, else the file's name.
  String get title => label.isNotEmpty ? label : name;

  /// "12 pages · 2.4 MB".
  String get facts {
    final mb = sizeBytes / (1024 * 1024);
    final size = sizeBytes <= 0 ? '' : (mb >= 1 ? '${mb.toStringAsFixed(1)} MB' : '${(sizeBytes / 1024).ceil()} KB');
    return [if (pages != null) '$pages page${pages == 1 ? '' : 's'}', if (size.isNotEmpty) size].join(' · ');
  }
}

const kShotTypes = ['Wide', 'Medium', 'Close-up', 'Detail', 'Over the shoulder', 'Top angle', 'Drone', 'Slow motion', 'Transition'];

/// A work (CRM booking) as the shoot screens name it — its number, client, service and event day(s); never the phone or address.
class BookingBrief {
  const BookingBrief({required this.id, this.bookingNumber = '', this.customerName = '', this.service = '', this.status = '', this.eventDate, this.eventDates = const [], this.district = '', this.contentRequired = false});
  final String id, bookingNumber, customerName, service, status, district;
  final String? eventDate;
  final List<String> eventDates;
  final bool contentRequired;
  factory BookingBrief.fromJson(Map<String, dynamic> j) => BookingBrief(
        id: _s(j['id']),
        bookingNumber: _s(j['bookingNumber']),
        customerName: _s(j['customerName']),
        service: _s(j['service']),
        status: _s(j['status']),
        eventDate: _sn(j['eventDate']),
        eventDates: ((j['eventDates'] as List?) ?? const []).map(_s).toList(),
        district: _s(j['district']),
        contentRequired: j['contentRequired'] == true,
      );

  /// "2611 1234 · Anjali"
  String get label => [bookingNumber, customerName].where((x) => x.isNotEmpty).join(' · ');
}

/// A shoot a post or an asset can be attached to.
class ShootOption {
  const ShootOption({required this.id, required this.title, this.brand = 'main', this.category = '', this.shootDate = '', this.status = ''});
  final String id, title, brand, category, shootDate, status;
  factory ShootOption.fromJson(Map<String, dynamic> j) => ShootOption(id: _s(j['id']), title: _s(j['title']), brand: _s(j['brand']).isEmpty ? 'main' : _s(j['brand']), category: _s(j['category']), shootDate: _s(j['shootDate']), status: _s(j['status']));
}

/// A post linked to a shoot (the shoot detail, the report and the booking's Content card).
class ShootPost {
  const ShootPost({required this.id, required this.title, this.platform = '', this.contentType = '', this.status = '', this.brand = 'main', this.scheduledDate, this.publishedDate, this.permalink = '', this.assetId});
  final String id, title, platform, contentType, status, brand, permalink;
  final DateTime? scheduledDate, publishedDate;
  final String? assetId;
  factory ShootPost.fromJson(Map<String, dynamic> j) => ShootPost(id: _s(j['id']), title: _s(j['title']), platform: _s(j['platform']), contentType: _s(j['contentType']), status: _s(j['status']), brand: _s(j['brand']).isEmpty ? 'main' : _s(j['brand']), scheduledDate: _dt(j['scheduledDate']), publishedDate: _dt(j['publishedDate']), permalink: _s(j['permalink']), assetId: _sn(j['assetId']));
}

/// One line of a shoot's content checklist: planned against delivered (assets and posts, each once) and posted.
class ChecklistRow {
  const ChecklistRow({required this.key, required this.label, this.planned = 0, this.delivered = 0, this.posted = 0, this.done = false});
  final String key, label;
  final int planned, delivered, posted;
  final bool done;
  factory ChecklistRow.fromJson(Map<String, dynamic> j) => ChecklistRow(key: _s(j['key']), label: _s(j['label']), planned: _i(j['planned']), delivered: _i(j['delivered']), posted: _i(j['posted']), done: j['done'] == true);
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
  const ShootDetail({required this.summary, this.pillar = '', this.objective = '', this.audience = '', this.notes = '', this.crew = const [], this.references = const [], this.milestones = const [], this.currentMilestone = '', this.assets = const [], this.footageMb = 0, this.takeaways = const [], this.activity = const [], this.storyboard = const [], this.booking, this.posts = const [], this.checklist = const [], this.activityScope = 'team', this.logistics = const ShootLogistics(), this.footage = const [], this.documents = const []});

  /// PDFs on the moodboard and the storyboard (a lookbook, a drawn storyboard, a shot list) — read in the app.
  final List<ShootDocument> documents;
  List<ShootDocument> documentsOf(String part) => [for (final d in documents) if (d.part == part) d];

  /// Crew & Logistics: call time, map link, the checklist of what to bring or arrange, notes.
  final ShootLogistics logistics;

  /// The raw footage the artists handed in for the work this shoot covers (one line per work day).
  final List<ShootFootage> footage;
  final ShootSummary summary;
  final String pillar, objective, audience, notes, currentMilestone;
  final List<StoryFrame> storyboard;
  final BookingBrief? booking;
  final List<ShootPost> posts;
  final List<ChecklistRow> checklist;

  /// 'team' — a manager sees everyone's logged work on the shoot; 'own' — a member sees only their own.
  final String activityScope;
  final List<CrewMember> crew;
  /// The moodboard: pictures (shown), videos and links (opened outside).
  final List<MoodboardItem> references;
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
      references: _l(j['references']).map(MoodboardItem.fromJson).toList(),
      milestones: _l(j['milestones']).map(Milestone.fromJson).toList(),
      currentMilestone: _s(j['currentMilestone']),
      assets: _l(j['assets']).map(ShootAsset.fromJson).toList(),
      footageMb: _dn(j['footageMb']) ?? 0,
      takeaways: ((j['takeaways'] as List?) ?? const []).map(_s).toList(),
      activity: _l(j['activity']).map(ShootLog.fromJson).toList(),
      storyboard: _l(j['storyboard']).map(StoryFrame.fromJson).toList(),
      booking: j['booking'] is Map ? BookingBrief.fromJson(_m(j['booking'])) : null,
      posts: _l(j['posts']).map(ShootPost.fromJson).toList(),
      checklist: _l(j['checklist']).map(ChecklistRow.fromJson).toList(),
      activityScope: _s(j['activityScope']).isEmpty ? 'team' : _s(j['activityScope']),
      logistics: ShootLogistics.fromJson(_m(j['logistics'])),
      footage: _l(j['footage']).map(ShootFootage.fromJson).toList(),
      documents: _l(j['documents']).map(ShootDocument.fromJson).toList(),
    );
  }

  /// The moodboard's pictures (what a preview shows).
  List<MoodboardItem> get pictures => [for (final r in references) if (r.kind == 'image') r];
}

/// One thing on a shoot's moodboard: a picture, a video or a link, with its label and who added it.
class MoodboardItem {
  const MoodboardItem({required this.url, this.label = '', this.kind = 'link', this.addedByName = '', this.addedAt});
  final String url, label, kind, addedByName;
  final DateTime? addedAt;
  factory MoodboardItem.fromJson(Map<String, dynamic> j) => MoodboardItem(url: _s(j['url']), label: _s(j['label']), kind: _s(j['kind']).isEmpty ? 'link' : _s(j['kind']), addedByName: _s(j['addedByName']), addedAt: _dt(j['addedAt']));

  /// What the link is, for a link card: "Pinterest", "Instagram", "Google Drive", "Dropbox"… else the site's name.
  String get site {
    final host = Uri.tryParse(url)?.host.toLowerCase().replaceFirst('www.', '') ?? '';
    if (host.contains('pinterest') || host == 'pin.it') return 'Pinterest';
    if (host.contains('instagram')) return 'Instagram';
    if (host.contains('drive.google') || host.contains('docs.google')) return 'Google Drive';
    if (host.contains('dropbox')) return 'Dropbox';
    if (host.contains('youtube') || host == 'youtu.be') return 'YouTube';
    if (host.contains('cloudinary')) return 'Uploaded';
    return host;
  }
}

/// Crew & Logistics of a shoot.
class ShootLogistics {
  const ShootLogistics({this.callTime = '', this.mapUrl = '', this.notes = '', this.checklist = const []});
  final String callTime, mapUrl, notes;
  final List<({String text, bool done, String byName})> checklist;
  factory ShootLogistics.fromJson(Map<String, dynamic> j) => ShootLogistics(
        callTime: _s(j['callTime']),
        mapUrl: _s(j['mapUrl']),
        notes: _s(j['notes']),
        checklist: [for (final c in _l(j['checklist'])) (text: _s(c['text']), done: c['done'] == true, byName: _s(c['byName']))],
      );
  bool get isEmpty => callTime.isEmpty && mapUrl.isEmpty && notes.isEmpty && checklist.isEmpty;
}

/// A work day's raw footage on the shoot that covers the work.
class ShootFootage {
  const ShootFootage({required this.day, this.folderName = '', this.state = 'waiting', this.size = '', this.editorName = '', this.links = const []});
  final String day, folderName, state, size, editorName;
  final List<({String url, String label, String kind, String addedByName, String summary})> links;
  factory ShootFootage.fromJson(Map<String, dynamic> j) => ShootFootage(
        day: _s(j['day']),
        folderName: _s(j['folderName']),
        state: _s(j['state']).isEmpty ? 'waiting' : _s(j['state']),
        size: _s(j['size']),
        editorName: _s(j['editorName']),
        links: [for (final l in _l(j['links'])) (url: _s(l['url']), label: _s(l['label']), kind: _s(l['kind']), addedByName: _s(l['addedByName']), summary: _s(l['summary']))],
      );
}

class LoadRow {
  const LoadRow({required this.key, required this.label, this.count = 0, this.pct = 0});
  final String key, label;
  final int count, pct;
  factory LoadRow.fromJson(Map<String, dynamic> j) => LoadRow(key: _s(j['key']), label: _s(j['label']), count: _i(j['count']), pct: _i(j['pct']));
}

/// One role's people for a day: on a shoot ([booked]), on leave, marked absent in attendance, on a client work (a makeup artist on a
/// booking — [onWork]), and how many are left.
class RoleAvailability {
  const RoleAvailability({required this.role, this.total = 0, this.booked = 0, this.onLeave = 0, this.absent = 0, this.onWork = 0, this.available = 0});
  final String role;
  final int total, booked, onLeave, absent, onWork, available;
  factory RoleAvailability.fromJson(Map<String, dynamic> j) => RoleAvailability(role: _s(j['role']), total: _i(j['total']), booked: _i(j['booked']), onLeave: _i(j['onLeave']), absent: _i(j['absent']), onWork: _i(j['onWork']), available: _i(j['available']));
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
  const ShootSetup({this.members = const [], this.artists = const [], this.categories = const [], this.pillars = const [], this.shootTypes = const ['Full Shoot']});
  final List<({String id, String name, String role})> members;

  /// The makeup artists on the staff list, for the crew.
  final List<({String id, String name, String role})> artists;
  final List<String> categories, pillars, shootTypes;
  factory ShootSetup.fromJson(Map<String, dynamic> j) => ShootSetup(
        members: _l(j['members']).map((m) => (id: _s(m['id']), name: _s(m['name']), role: _s(m['role']))).toList(),
        artists: _l(j['artists']).map((m) => (id: _s(m['id']), name: _s(m['name']), role: _s(m['role']))).toList(),
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

/// A booking's content (the booking screen's Content card): the shoots linked to the work, each with its checklist and posts.
class BookingContent {
  const BookingContent({this.booking, this.shoots = const []});
  final BookingBrief? booking;
  final List<({ShootSummary summary, List<ChecklistRow> checklist, List<ShootPost> posts})> shoots;
  factory BookingContent.fromJson(Map<String, dynamic> j) => BookingContent(
        booking: j['booking'] is Map ? BookingBrief.fromJson(_m(j['booking'])) : null,
        shoots: _l(j['shoots']).map((x) => (summary: ShootSummary.fromJson(x), checklist: _l(x['checklist']).map(ChecklistRow.fromJson).toList(), posts: _l(x['posts']).map(ShootPost.fromJson).toList())).toList(),
      );
}
