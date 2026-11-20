// Strategies & Developments' payloads (backend controllers/marketingStrategiesController.js, /api/marketing/strategies). A missing part parses
// to an empty value, never a crash. Progress, status, owner and due day of an initiative / project are COUNTED on the server from the tasks
// tied to it — the app only shows them (and says where each came from).

int _i(dynamic v) => (v as num?)?.toInt() ?? 0;
int? _in(dynamic v) => (v as num?)?.toInt();
double _d(dynamic v) => (v as num?)?.toDouble() ?? 0;
String _s(dynamic v) => v?.toString() ?? '';
String? _sn(dynamic v) => v == null || v.toString().isEmpty ? null : v.toString();
DateTime? _dt(dynamic v) => v == null ? null : DateTime.tryParse(v.toString())?.toLocal();
Map<String, dynamic> _m(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
List<Map<String, dynamic>> _l(dynamic v) => ((v as List?) ?? const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
List<String> _ls(dynamic v) => ((v as List?) ?? const []).map(_s).toList();

/// The statuses an initiative or project shows, in the document's words.
const kWorkStatusLabels = {
  'on_track': 'On Track',
  'in_progress': 'In Progress',
  'at_risk': 'At Risk',
  'on_hold': 'On Hold',
  'completed': 'Completed',
  'cancelled': 'Cancelled',
};
String workStatusLabel(String s) => kWorkStatusLabels[s] ?? s;

/// The status a manager can set by hand (the rest is worked out from the work).
const kInitiativeStoredStatuses = [('planned', 'Planned'), ('active', 'Active'), ('on_hold', 'On hold'), ('completed', 'Completed'), ('cancelled', 'Cancelled')];
const kProjectStoredStatuses = [('planned', 'Planned'), ('in_progress', 'In progress'), ('on_hold', 'On hold'), ('completed', 'Completed'), ('cancelled', 'Cancelled')];
const kPlanStatuses = [('active', 'Active'), ('in_progress', 'In Progress'), ('on_hold', 'On Hold'), ('completed', 'Completed')];
String planStatusLabel(String s) => kPlanStatuses.firstWhere((e) => e.$1 == s, orElse: () => (s, s)).$2;

const kImpacts = [('high', 'High'), ('medium', 'Medium'), ('low', 'Low')];
String impactLabel(String s) => kImpacts.firstWhere((e) => e.$1 == s, orElse: () => (s, s)).$2;

const kFindingKinds = [('report', 'Research report'), ('market_insight', 'Market insight'), ('competitor', 'Competitor analysis'), ('opportunity', 'Opportunity')];
String findingKindLabel(String s) => kFindingKinds.firstWhere((e) => e.$1 == s, orElse: () => (s, s)).$2;

const kReviewTypes = [('strategy', 'Strategy Review'), ('project', 'Project Review'), ('campaign', 'Campaign Review'), ('quarterly', 'Quarterly Review')];
String reviewTypeLabel(String s) => kReviewTypes.firstWhere((e) => e.$1 == s, orElse: () => (s, s)).$2;

const kOutcomeStates = [('achieved', 'Achieved'), ('partial', 'Partially achieved'), ('missed', 'Not achieved')];
const kActionStatuses = [('open', 'Open'), ('in_progress', 'In Progress'), ('done', 'Done')];
String actionStatusLabel(String s) => kActionStatuses.firstWhere((e) => e.$1 == s, orElse: () => (s, s)).$2;
const kPriorities = [('high', 'High'), ('medium', 'Medium'), ('low', 'Low')];
String actionPriorityLabel(String s) => kPriorities.firstWhere((e) => e.$1 == s, orElse: () => (s, s)).$2;

// ── setup ────────────────────────────────────────────────────────────────────

/// What the forms need and who is looking: managers may do everything; a member is a team member (or not).
class StrategySetup {
  const StrategySetup({this.canManage = false, this.meId, this.meName = '', this.members = const [], this.plans = const [], this.initiatives = const [], this.projects = const [], this.focusAreas = const [], this.categories = const []});
  final bool canManage;
  final String? meId;
  final String meName;
  final List<({String id, String name})> members;
  final List<({String id, String title, int year})> plans;
  final List<({String id, String title})> initiatives;

  /// The development projects (not cancelled) a review can be about.
  final List<({String id, String title})> projects;
  final List<String> focusAreas, categories;

  factory StrategySetup.fromJson(Map<String, dynamic> j) {
    final me = j['me'] is Map ? _m(j['me']) : null;
    return StrategySetup(
      canManage: j['canManage'] == true,
      meId: me == null ? null : _sn(me['id']),
      meName: me == null ? '' : _s(me['name']),
      members: _l(j['members']).map((m) => (id: _s(m['id']), name: _s(m['name']))).toList(),
      plans: _l(j['plans']).map((p) => (id: _s(p['id']), title: _s(p['title']), year: _i(p['year']))).toList(),
      initiatives: _l(j['initiatives']).map((p) => (id: _s(p['id']), title: _s(p['title']))).toList(),
      projects: _l(j['projects']).map((p) => (id: _s(p['id']), title: _s(p['title']))).toList(),
      focusAreas: _ls(j['focusAreas']),
      categories: _ls(j['categories']),
    );
  }
}

// ── initiatives and development projects ─────────────────────────────────────

class WorkOwner {
  const WorkOwner({required this.id, this.name = '', this.source = 'set'});
  final String id, name, source; // source: set | tasks
  factory WorkOwner.fromJson(Map<String, dynamic> j) => WorkOwner(id: _s(j['id']), name: _s(j['name']), source: _s(j['source']).isEmpty ? 'set' : _s(j['source']));
}

/// The Strategies log types (projects worked on, first drafts, meetings, final drafts, executions) counted from the logs tied to an
/// initiative or project — or, on the Overview, logged in the range.
class StrategyWork {
  const StrategyWork({this.total = 0, this.minutes = 0, this.logs = 0, this.counts = const [], this.types = const [], this.tracked = false});
  final int total, minutes, logs;
  final List<({String metric, int total})> counts;

  /// Every Strategies log type (the Overview lists them all, so a step nobody logged reads 0), and whether the types exist at all.
  final List<String> types;
  final bool tracked;
  int of(String metric) => counts.where((c) => c.metric == metric).map((c) => c.total).firstOrNull ?? 0;
  factory StrategyWork.fromJson(Map<String, dynamic> j) => StrategyWork(
        total: _i(j['total']),
        minutes: _i(j['minutes']),
        logs: _i(j['logs']),
        counts: _l(j['counts']).map((c) => (metric: _s(c['metric']), total: _i(c['total']))).toList(),
        types: _ls(j['types']),
        tracked: j['tracked'] == true,
      );
}

/// One initiative or development project (`kind` 'initiative' | 'project'), worked out by the server.
class WorkItem {
  const WorkItem({
    required this.kind, required this.id, required this.title, this.brand = 'main', this.focusArea = '', this.category = '', this.impact = '', this.description = '', this.notes = '', this.planId, this.planTitle = '',
    this.storedStatus = '', this.status = 'in_progress', this.owner, this.progress = 0, this.progressSource = 'none', this.typedProgress, this.taskCount = 0, this.doneCount = 0, this.start = '', this.typedStart,
    this.due, this.dueSource = 'none', this.closedDay, this.minutes = 0, this.strategyWork = const StrategyWork(),
  });
  final StrategyWork strategyWork;
  final String kind, id, title, brand, focusArea, category, impact, description, notes, planTitle, storedStatus, status, progressSource, start, dueSource;
  final String? planId, typedStart, due, closedDay;
  final WorkOwner? owner;
  final int progress, taskCount, doneCount, minutes;
  final int? typedProgress;

  bool get isProject => kind == 'project';
  bool get hasProgress => progressSource != 'none';
  String get ownerName => owner?.name ?? '';
  bool get isOpen => const {'on_track', 'in_progress', 'at_risk'}.contains(status);

  /// Where the progress figure came from, in words ("3 of 5 tasks done", "set by owner", "no tasks tied yet").
  String get progressNote => switch (progressSource) {
        'tasks' => '$doneCount of $taskCount ${taskCount == 1 ? 'task' : 'tasks'} done',
        'owner' => 'set by owner',
        _ => 'no tasks tied yet',
      };

  factory WorkItem.fromJson(Map<String, dynamic> j) {
    final plan = j['plan'] is Map ? _m(j['plan']) : null;
    return WorkItem(
      kind: _s(j['kind']).isEmpty ? 'initiative' : _s(j['kind']),
      id: _s(j['id']),
      title: _s(j['title']),
      brand: _s(j['brand']).isEmpty ? 'main' : _s(j['brand']),
      focusArea: _s(j['focusArea']),
      category: _s(j['category']),
      impact: _s(j['impact']),
      description: _s(j['description']),
      notes: _s(j['notes']),
      planId: plan == null ? null : _sn(plan['id']),
      planTitle: plan == null ? '' : _s(plan['title']),
      storedStatus: _s(j['storedStatus']),
      status: _s(j['status']).isEmpty ? 'in_progress' : _s(j['status']),
      owner: j['owner'] is Map ? WorkOwner.fromJson(_m(j['owner'])) : null,
      progress: _i(j['progress']),
      progressSource: _s(j['progressSource']).isEmpty ? 'none' : _s(j['progressSource']),
      typedProgress: _in(j['typedProgress']),
      taskCount: _i(j['taskCount']),
      doneCount: _i(j['doneCount']),
      start: _s(j['start']),
      typedStart: _sn(j['typedStart']),
      due: _sn(j['due']),
      dueSource: _s(j['dueSource']).isEmpty ? 'none' : _s(j['dueSource']),
      closedDay: _sn(j['closedDay']),
      minutes: _i(j['minutes']),
      strategyWork: StrategyWork.fromJson(_m(j['strategyWork'])),
    );
  }
}

class WorkTask {
  const WorkTask({required this.id, this.title = '', this.assignee = '', this.status = '', this.progress = 0, this.dueDate, this.completedAt});
  final String id, title, assignee, status;
  final int progress;
  final String? dueDate;
  final DateTime? completedAt;
  factory WorkTask.fromJson(Map<String, dynamic> j) => WorkTask(id: _s(j['id']), title: _s(j['title']), assignee: _s(j['assignee']), status: _s(j['status']), progress: _i(j['progress']), dueDate: _sn(j['dueDate']), completedAt: _dt(j['completedAt']));
}

class WorkLog {
  const WorkLog({required this.id, this.member = '', this.workedOn = '', this.minutes = 0, this.day = '', this.status = ''});
  final String id, member, workedOn, day, status;
  final int minutes;
  factory WorkLog.fromJson(Map<String, dynamic> j) => WorkLog(id: _s(j['id']), member: _s(j['member']), workedOn: _s(j['workedOn']), minutes: _i(j['minutes']), day: _s(j['day']), status: _s(j['status']));
}

class WorkDetail {
  const WorkDetail({required this.item, this.tasks = const [], this.logs = const []});
  final WorkItem item;
  final List<WorkTask> tasks;
  final List<WorkLog> logs;
  factory WorkDetail.fromJson(Map<String, dynamic> j) => WorkDetail(item: WorkItem.fromJson(j), tasks: _l(j['tasks']).map(WorkTask.fromJson).toList(), logs: _l(j['logs']).map(WorkLog.fromJson).toList());
}

class WorkCounts {
  const WorkCounts({this.total = 0, this.open = 0, this.completed = 0, this.onHold = 0, this.onTrack = 0, this.atRisk = 0, this.inProgress = 0});
  final int total, open, completed, onHold, onTrack, atRisk, inProgress;
  factory WorkCounts.fromJson(Map<String, dynamic> j) => WorkCounts(total: _i(j['total']), open: _i(j['open']), completed: _i(j['completed']), onHold: _i(j['onHold']), onTrack: _i(j['onTrack']), atRisk: _i(j['atRisk']), inProgress: _i(j['inProgress']));
}

class WorkList {
  const WorkList({this.counts = const WorkCounts(), this.focusAreas = const [], this.items = const [], this.total = 0, this.page = 1, this.pageSize = 10});
  final WorkCounts counts;
  final List<String> focusAreas;
  final List<WorkItem> items;
  final int total, page, pageSize;
  factory WorkList.fromJson(Map<String, dynamic> j) => WorkList(
        counts: WorkCounts.fromJson(_m(j['counts'])),
        focusAreas: _ls(j['focusAreas']),
        items: _l(j['items']).map(WorkItem.fromJson).toList(),
        total: _i(j['total']),
        page: _i(j['page']) == 0 ? 1 : _i(j['page']),
        pageSize: _i(j['pageSize']) == 0 ? 10 : _i(j['pageSize']),
      );
}

/// How the initiatives / projects table is cut: status chip, focus area, search and page.
class WorkQuery {
  const WorkQuery({this.status = 'all', this.focusArea = '', this.q = '', this.page = 1});
  final String status, focusArea, q;
  final int page;
  WorkQuery copyWith({String? status, String? focusArea, String? q, int? page}) => WorkQuery(status: status ?? this.status, focusArea: focusArea ?? this.focusArea, q: q ?? this.q, page: page ?? this.page);
  @override
  bool operator ==(Object other) => other is WorkQuery && other.status == status && other.focusArea == focusArea && other.q == q && other.page == page;
  @override
  int get hashCode => Object.hash(status, focusArea, q, page);
}

// ── plans ────────────────────────────────────────────────────────────────────

class PlanItem {
  const PlanItem({required this.id, required this.title, this.focusArea = '', this.year = 0, this.brand = 'main', this.status = 'active', this.goals = const [], this.description = '', this.ownerId, this.ownerName = '', this.initiativeCount = 0, this.projectCount = 0});
  final String id, title, focusArea, brand, status, description, ownerName;
  final int year, initiativeCount, projectCount;
  final List<String> goals;
  final String? ownerId;
  factory PlanItem.fromJson(Map<String, dynamic> j) {
    final owner = j['owner'] is Map ? _m(j['owner']) : null;
    return PlanItem(
      id: _s(j['id']),
      title: _s(j['title']),
      focusArea: _s(j['focusArea']),
      year: _i(j['year']),
      brand: _s(j['brand']).isEmpty ? 'main' : _s(j['brand']),
      status: _s(j['status']),
      goals: _ls(j['goals']),
      description: _s(j['description']),
      ownerId: owner == null ? null : _sn(owner['id']),
      ownerName: owner == null ? '' : _s(owner['name']),
      initiativeCount: _i(j['initiativeCount']),
      projectCount: _i(j['projectCount']),
    );
  }
}

class PlanCounts {
  const PlanCounts({this.total = 0, this.active = 0, this.inProgress = 0, this.onHold = 0, this.completed = 0});
  final int total, active, inProgress, onHold, completed;
  factory PlanCounts.fromJson(Map<String, dynamic> j) => PlanCounts(total: _i(j['total']), active: _i(j['active']), inProgress: _i(j['inProgress']), onHold: _i(j['onHold']), completed: _i(j['completed']));
}

class FocusRow {
  const FocusRow({required this.focusArea, this.count = 0});
  final String focusArea;
  final int count;
  factory FocusRow.fromJson(Map<String, dynamic> j) => FocusRow(focusArea: _s(j['focusArea']), count: _i(j['count']));
}

class PlanStatusSlice {
  const PlanStatusSlice({required this.key, required this.label, this.count = 0, this.pct = 0});
  final String key, label;
  final int count, pct;
  factory PlanStatusSlice.fromJson(Map<String, dynamic> j) => PlanStatusSlice(key: _s(j['key']), label: _s(j['label']), count: _i(j['count']), pct: _i(j['pct']));
}

class PlansData {
  const PlansData({this.counts = const PlanCounts(), this.focusTotal = 0, this.focus = const [], this.progressTotal = 0, this.slices = const [], this.goals = const [], this.items = const []});
  final PlanCounts counts;
  final int focusTotal, progressTotal;
  final List<FocusRow> focus;
  final List<PlanStatusSlice> slices;
  final List<({String text, String plan, String focusArea})> goals;
  final List<PlanItem> items;
  factory PlansData.fromJson(Map<String, dynamic> j) => PlansData(
        counts: PlanCounts.fromJson(_m(j['counts'])),
        focusTotal: _i(_m(j['focusAreas'])['total']),
        focus: _l(_m(j['focusAreas'])['rows']).map(FocusRow.fromJson).toList(),
        progressTotal: _i(_m(j['progress'])['total']),
        slices: _l(_m(j['progress'])['slices']).map(PlanStatusSlice.fromJson).toList(),
        goals: _l(j['goals']).map((g) => (text: _s(g['text']), plan: _s(g['plan']), focusArea: _s(g['focusArea']))).toList(),
        items: _l(j['items']).map(PlanItem.fromJson).toList(),
      );
}

// ── roadmap ──────────────────────────────────────────────────────────────────

class RoadmapLine {
  const RoadmapLine({required this.id, this.year = 0, this.quarter = 1, this.theme = '', this.title = '', this.brand = 'main', this.done = false, this.doneBy = '', this.doneAt, this.planId, this.initiativeId, this.link = ''});
  final String id, theme, title, brand, doneBy, link;
  final int year, quarter;
  final bool done;
  final DateTime? doneAt;
  final String? planId, initiativeId;
  factory RoadmapLine.fromJson(Map<String, dynamic> j) => RoadmapLine(
        id: _s(j['id']),
        year: _i(j['year']),
        quarter: _i(j['quarter']) == 0 ? 1 : _i(j['quarter']),
        theme: _s(j['theme']),
        title: _s(j['title']),
        brand: _s(j['brand']).isEmpty ? 'main' : _s(j['brand']),
        done: j['done'] == true,
        doneBy: _s(j['doneBy']),
        doneAt: _dt(j['doneAt']),
        planId: _sn(j['planId']),
        initiativeId: _sn(j['initiativeId']),
        link: _s(j['link']),
      );
}

class RoadmapQuarter {
  const RoadmapQuarter({required this.quarter, this.label = '', this.months = '', this.theme = '', this.total = 0, this.done = 0, this.pct, this.items = const []});
  final int quarter, total, done;
  final String label, months, theme;
  final int? pct;
  final List<RoadmapLine> items;
  factory RoadmapQuarter.fromJson(Map<String, dynamic> j) => RoadmapQuarter(
        quarter: _i(j['quarter']),
        label: _s(j['label']),
        months: _s(j['months']),
        theme: _s(j['theme']),
        total: _i(j['total']),
        done: _i(j['done']),
        pct: _in(j['pct']),
        items: _l(j['items']).map(RoadmapLine.fromJson).toList(),
      );
}

/// A bar of the year's timeline: `from`/`to` are fractions (0–1) of the year.
class TimelineBar {
  const TimelineBar({required this.kind, required this.id, this.title = '', this.owner = '', this.progress = 0, this.progressSource = 'none', this.status = 'in_progress', this.start = '', this.end, this.from = 0, this.to = 1, this.startsBefore = false, this.endsAfter = false});
  final String kind, id, title, owner, progressSource, status, start;
  final String? end;
  final int progress;
  final double from, to;
  final bool startsBefore, endsAfter;
  factory TimelineBar.fromJson(Map<String, dynamic> j) => TimelineBar(
        kind: _s(j['kind']),
        id: _s(j['id']),
        title: _s(j['title']),
        owner: _s(j['owner']),
        progress: _i(j['progress']),
        progressSource: _s(j['progressSource']).isEmpty ? 'none' : _s(j['progressSource']),
        status: _s(j['status']),
        start: _s(j['start']),
        end: _sn(j['end']),
        from: _d(j['from']),
        to: j['to'] == null ? 1 : _d(j['to']),
        startsBefore: j['startsBefore'] == true,
        endsAfter: j['endsAfter'] == true,
      );
}

class RoadmapData {
  const RoadmapData({this.year = 0, this.items = 0, this.done = 0, this.pct, this.quarters = const [], this.bars = const [], this.undated = const []});
  final int year, items, done;
  final int? pct;
  final List<RoadmapQuarter> quarters;
  final List<TimelineBar> bars, undated;
  factory RoadmapData.fromJson(Map<String, dynamic> j) {
    final c = _m(j['counts']);
    final t = _m(j['timeline']);
    return RoadmapData(
      year: _i(j['year']),
      items: _i(c['items']),
      done: _i(c['done']),
      pct: _in(c['pct']),
      quarters: _l(j['quarters']).map(RoadmapQuarter.fromJson).toList(),
      bars: _l(t['bars']).map(TimelineBar.fromJson).toList(),
      undated: _l(t['undated']).map(TimelineBar.fromJson).toList(),
    );
  }
}

// ── research ─────────────────────────────────────────────────────────────────

class Finding {
  const Finding({required this.id, this.title = '', this.kind = 'report', this.summary = '', this.link = '', this.brand = 'main', this.date = '', this.tags = const [], this.author = '', this.authorId});
  final String id, title, kind, summary, link, brand, date, author;
  final List<String> tags;
  final String? authorId;
  factory Finding.fromJson(Map<String, dynamic> j) => Finding(
        id: _s(j['id']),
        title: _s(j['title']),
        kind: _s(j['kind']),
        summary: _s(j['summary']),
        link: _s(j['link']),
        brand: _s(j['brand']).isEmpty ? 'main' : _s(j['brand']),
        date: _s(j['date']),
        tags: _ls(j['tags']),
        author: _s(j['author']),
        authorId: _sn(j['authorId']),
      );
}

class ResearchCounts {
  const ResearchCounts({this.total = 0, this.report = 0, this.marketInsight = 0, this.competitor = 0, this.opportunity = 0});
  final int total, report, marketInsight, competitor, opportunity;
  factory ResearchCounts.fromJson(Map<String, dynamic> j) => ResearchCounts(total: _i(j['total']), report: _i(j['report']), marketInsight: _i(j['marketInsight']), competitor: _i(j['competitor']), opportunity: _i(j['opportunity']));
}

/// The enquiry trend vs last quarter (the document's "Market Trend Index", from our own leads): leads so far this quarter against the same
/// number of days at the start of the quarter before. [change] is null when there is nothing to compare with ("—", never 0).
class EnquiryTrend {
  const EnquiryTrend({this.label = 'Enquiry trend vs last quarter', this.quarter = '', this.previousQuarter = '', this.elapsedDays = 0, this.now = 0, this.before = 0, this.change, this.beforeTo = ''});
  final String label, quarter, previousQuarter, beforeTo;
  final int elapsedDays, now, before;
  final int? change;
  bool get known => quarter.isNotEmpty;
  factory EnquiryTrend.fromJson(Map<String, dynamic> j) => EnquiryTrend(
        label: _s(j['label']).isEmpty ? 'Enquiry trend vs last quarter' : _s(j['label']),
        quarter: _s(j['quarter']),
        previousQuarter: _s(j['previousQuarter']),
        elapsedDays: _i(j['elapsedDays']),
        now: _i(_m(j['now'])['leads']),
        before: _i(_m(j['before'])['leads']),
        beforeTo: _s(_m(j['before'])['to']),
        change: _in(j['change']),
      );
}

class ResearchData {
  const ResearchData({this.counts = const ResearchCounts(), this.keyInsights = const [], this.opportunities = const [], this.items = const [], this.total = 0, this.page = 1, this.pageSize = 10, this.enquiryTrend = const EnquiryTrend()});
  final EnquiryTrend enquiryTrend;
  final ResearchCounts counts;
  final List<Finding> keyInsights, opportunities, items;
  final int total, page, pageSize;
  factory ResearchData.fromJson(Map<String, dynamic> j) => ResearchData(
        counts: ResearchCounts.fromJson(_m(j['counts'])),
        enquiryTrend: EnquiryTrend.fromJson(_m(j['enquiryTrend'])),
        keyInsights: _l(j['keyInsights']).map(Finding.fromJson).toList(),
        opportunities: _l(j['opportunities']).map(Finding.fromJson).toList(),
        items: _l(j['items']).map(Finding.fromJson).toList(),
        total: _i(j['total']),
        page: _i(j['page']) == 0 ? 1 : _i(j['page']),
        pageSize: _i(j['pageSize']) == 0 ? 10 : _i(j['pageSize']),
      );
}

class ResearchQuery {
  const ResearchQuery({this.kind = 'all', this.q = '', this.page = 1});
  final String kind, q;
  final int page;
  @override
  bool operator ==(Object other) => other is ResearchQuery && other.kind == kind && other.q == q && other.page == page;
  @override
  int get hashCode => Object.hash(kind, q, page);
}

// ── reviews ──────────────────────────────────────────────────────────────────

class ReviewOutcome {
  const ReviewOutcome({required this.text, this.state = 'achieved'});
  final String text, state;
  factory ReviewOutcome.fromJson(Map<String, dynamic> j) => ReviewOutcome(text: _s(j['text']), state: _s(j['state']).isEmpty ? 'achieved' : _s(j['state']));
}

class ReviewScores {
  const ReviewScores({this.total = 0, this.achieved = 0, this.partial = 0, this.missed = 0, this.achievedPct, this.partialPct, this.missedPct, this.overall});
  final int total, achieved, partial, missed;
  final int? achievedPct, partialPct, missedPct, overall;
  factory ReviewScores.fromJson(Map<String, dynamic> j) => ReviewScores(total: _i(j['total']), achieved: _i(j['achieved']), partial: _i(j['partial']), missed: _i(j['missed']), achievedPct: _in(j['achievedPct']), partialPct: _in(j['partialPct']), missedPct: _in(j['missedPct']), overall: _in(j['overall']));
}

class ActionItem {
  const ActionItem({required this.id, this.text = '', this.ownerId, this.ownerName = '', this.priority = 'medium', this.targetDate, this.status = 'open', this.overdue = false});
  final String id, text, ownerName, priority, status;
  final String? ownerId, targetDate;
  final bool overdue;
  factory ActionItem.fromJson(Map<String, dynamic> j) {
    final owner = j['owner'] is Map ? _m(j['owner']) : null;
    return ActionItem(id: _s(j['id']), text: _s(j['text']), ownerId: owner == null ? null : _sn(owner['id']), ownerName: owner == null ? '' : _s(owner['name']), priority: _s(j['priority']).isEmpty ? 'medium' : _s(j['priority']), targetDate: _sn(j['targetDate']), status: _s(j['status']).isEmpty ? 'open' : _s(j['status']), overdue: j['overdue'] == true);
  }
}

/// What a review is about — a plan, a development project or an initiative — as it stands NOW (the server works it out on every read).
class ReviewLink {
  const ReviewLink({required this.kind, required this.id, this.title = '', this.status = '', this.statusLabel = '', this.progress, this.progressSource = 'none', this.missing = false});
  final String kind, id, title, status, statusLabel, progressSource;
  final int? progress;
  final bool missing;
  bool get hasProgress => progressSource != 'none' && progress != null;
  String get kindLabel => switch (kind) { 'plan' => 'Strategic plan', 'project' => 'Development project', _ => 'Initiative' };
  static ReviewLink? fromJson(dynamic v) {
    if (v is! Map) return null;
    final j = Map<String, dynamic>.from(v);
    return ReviewLink(kind: _s(j['kind']), id: _s(j['id']), title: _s(j['title']), status: _s(j['status']), statusLabel: _s(j['statusLabel']), progress: _in(j['progress']), progressSource: _s(j['progressSource']).isEmpty ? 'none' : _s(j['progressSource']), missing: j['missing'] == true);
  }
}

class StrategyReview {
  const StrategyReview({required this.id, this.type = 'strategy', this.periodLabel = '', this.reviewDate = '', this.brand = 'main', this.summary = '', this.outcomes = const [], this.scores = const ReviewScores(), this.actionItems = const [], this.createdBy = '', this.linked});
  final String id, type, periodLabel, reviewDate, brand, summary, createdBy;
  final ReviewLink? linked;
  final List<ReviewOutcome> outcomes;
  final ReviewScores scores;
  final List<ActionItem> actionItems;
  factory StrategyReview.fromJson(Map<String, dynamic> j) => StrategyReview(
        id: _s(j['id']),
        type: _s(j['type']),
        periodLabel: _s(j['periodLabel']),
        reviewDate: _s(j['reviewDate']),
        brand: _s(j['brand']).isEmpty ? 'main' : _s(j['brand']),
        summary: _s(j['summary']),
        outcomes: _l(j['outcomes']).map(ReviewOutcome.fromJson).toList(),
        scores: ReviewScores.fromJson(_m(j['scores'])),
        actionItems: _l(j['actionItems']).map(ActionItem.fromJson).toList(),
        createdBy: _s(j['createdBy']),
        linked: ReviewLink.fromJson(j['linked']),
      );
}

class ReviewsData {
  const ReviewsData({this.type = 'all', this.counts = const {}, this.items = const []});
  final String type;
  final Map<String, int> counts;
  final List<StrategyReview> items;
  factory ReviewsData.fromJson(Map<String, dynamic> j) => ReviewsData(type: _s(j['type']).isEmpty ? 'all' : _s(j['type']), counts: _m(j['counts']).map((k, v) => MapEntry(k, _i(v))), items: _l(j['items']).map(StrategyReview.fromJson).toList());
}

// ── overview ─────────────────────────────────────────────────────────────────

class StrategyKpis {
  const StrategyKpis({this.activeStrategies = 0, this.developmentProjects = 0, this.totalInitiatives = 0, this.onTrack = 0, this.atRisk = 0, this.newThisWeek = 0});
  final int activeStrategies, developmentProjects, totalInitiatives, onTrack, atRisk, newThisWeek;
  factory StrategyKpis.fromJson(Map<String, dynamic> j) => StrategyKpis(activeStrategies: _i(j['activeStrategies']), developmentProjects: _i(j['developmentProjects']), totalInitiatives: _i(j['totalInitiatives']), onTrack: _i(j['onTrack']), atRisk: _i(j['atRisk']), newThisWeek: _i(j['newThisWeek']));
}

class FocusPerformance {
  const FocusPerformance({required this.focusArea, this.progress, this.initiatives = 0, this.measured = 0});
  final String focusArea;
  final int? progress;
  final int initiatives, measured;
  factory FocusPerformance.fromJson(Map<String, dynamic> j) => FocusPerformance(focusArea: _s(j['focusArea']), progress: _in(j['progress']), initiatives: _i(j['initiatives']), measured: _i(j['measured']));
}

class UpdateEvent {
  const UpdateEvent({required this.kind, this.at, this.text = '', this.subtitle = '', this.by = ''});
  final String kind, text, subtitle, by;
  final DateTime? at;
  factory UpdateEvent.fromJson(Map<String, dynamic> j) => UpdateEvent(kind: _s(j['kind']), at: _dt(j['at']), text: _s(j['text']), subtitle: _s(j['subtitle']), by: _s(j['by']));
}

class KeyOutcomes {
  const KeyOutcomes({this.reviewId = '', this.type = '', this.periodLabel = '', this.reviewDate = '', this.outcomes = const [], this.scores = const ReviewScores()});
  final String reviewId, type, periodLabel, reviewDate;
  final List<ReviewOutcome> outcomes;
  final ReviewScores scores;
  static KeyOutcomes? fromJson(dynamic v) {
    if (v is! Map) return null;
    final j = Map<String, dynamic>.from(v);
    final r = _m(j['review']);
    return KeyOutcomes(reviewId: _s(r['id']), type: _s(r['type']), periodLabel: _s(r['periodLabel']), reviewDate: _s(r['reviewDate']), outcomes: _l(j['outcomes']).map(ReviewOutcome.fromJson).toList(), scores: ReviewScores.fromJson(_m(j['scores'])));
  }
}

class StrategyOverview {
  const StrategyOverview({this.year = 0, this.kpis = const StrategyKpis(), this.focusTotal = 0, this.focus = const [], this.quarters = const [], this.initiatives = const [], this.projects = const [], this.performance = const [], this.updates = const [], this.research = const [], this.keyOutcomes, this.strategyWork = const StrategyWork()});
  final int year, focusTotal;

  /// The Strategies log types logged in the range.
  final StrategyWork strategyWork;
  final StrategyKpis kpis;
  final List<FocusRow> focus;
  final List<RoadmapQuarter> quarters;
  final List<WorkItem> initiatives, projects;
  final List<FocusPerformance> performance;
  final List<UpdateEvent> updates;
  final List<Finding> research;
  final KeyOutcomes? keyOutcomes;
  factory StrategyOverview.fromJson(Map<String, dynamic> j) => StrategyOverview(
        year: _i(j['year']),
        kpis: StrategyKpis.fromJson(_m(j['kpis'])),
        focusTotal: _i(_m(j['focusAreas'])['total']),
        focus: _l(_m(j['focusAreas'])['rows']).map(FocusRow.fromJson).toList(),
        quarters: _l(_m(j['roadmap'])['quarters']).map(RoadmapQuarter.fromJson).toList(),
        initiatives: _l(j['initiatives']).map(WorkItem.fromJson).toList(),
        projects: _l(j['projects']).map(WorkItem.fromJson).toList(),
        performance: _l(j['performance']).map(FocusPerformance.fromJson).toList(),
        updates: _l(j['recentUpdates']).map(UpdateEvent.fromJson).toList(),
        research: _l(j['research']).map(Finding.fromJson).toList(),
        keyOutcomes: KeyOutcomes.fromJson(j['keyOutcomes']),
        strategyWork: StrategyWork.fromJson(_m(j['strategyWork'])),
      );
}
