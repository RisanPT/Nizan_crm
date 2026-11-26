// The Marketing Team Dashboard and Log Activity — the server's payloads (backend controllers/marketingTeamController.js).

int _i(dynamic v) => (v as num?)?.toInt() ?? 0;
int? _in(dynamic v) => (v as num?)?.toInt();
double? _dn(dynamic v) => (v as num?)?.toDouble();
String _s(dynamic v) => v?.toString() ?? '';
DateTime? _dt(dynamic v) => v == null ? null : DateTime.tryParse(v.toString())?.toLocal();
Map<String, dynamic> _m(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
List<Map<String, dynamic>> _l(dynamic v) => ((v as List?) ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();

/// Main (the company) or Kerala — every record carries one, and every screen can filter by it.
enum TeamBrand {
  all('all', 'All brands'),
  main('main', 'Main'),
  kerala('kerala', 'Kerala');

  const TeamBrand(this.wire, this.label);
  final String wire;
  final String label;
  static TeamBrand parse(String? s) => TeamBrand.values.firstWhere((b) => b.wire == s, orElse: () => TeamBrand.main);
}

/// How a log or work item stands.
enum WorkStatus {
  completed('completed', 'Completed'),
  inProgress('in_progress', 'In progress'),
  pending('pending', 'Pending'),
  blocked('blocked', 'Blocked'),
  notStarted('not_started', 'Not started');

  const WorkStatus(this.wire, this.label);
  final String wire;
  final String label;
  static WorkStatus parse(String? s) => WorkStatus.values.firstWhere((v) => v.wire == s, orElse: () => WorkStatus.inProgress);
}

/// What kind of work a log was (the feed icon, and what counts as a meeting).
enum ActivityKind {
  task('task', 'Task'),
  meeting('meeting', 'Meeting'),
  shoot('shoot', 'Shoot'),
  post('post', 'Post'),
  campaign('campaign', 'Campaign'),
  strategy('strategy', 'Strategy'),
  other('other', 'Other');

  const ActivityKind(this.wire, this.label);
  final String wire;
  final String label;
  static ActivityKind parse(String? s) => ActivityKind.values.firstWhere((v) => v.wire == s, orElse: () => ActivityKind.task);
}

/// "7h 45m" for minutes, "—" for none.
String hoursLabel(int minutes) {
  if (minutes <= 0) return '—';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h > 0 && m > 0) return '${h}h ${m}m';
  return h > 0 ? '${h}h' : '${m}m';
}

class TeamKpis {
  const TeamKpis({this.members = 0, this.membersJoined = 0, this.tasksCompleted = 0, this.tasksCompletedChange, this.inProgress = 0, this.pendingBlocked = 0, this.activityRate, this.onTimeDelivery});
  final int members;
  final int membersJoined;
  final int tasksCompleted;
  final int? tasksCompletedChange;
  final int inProgress;
  final int pendingBlocked;
  final int? activityRate;
  final int? onTimeDelivery;

  factory TeamKpis.fromJson(Map<String, dynamic> j) => TeamKpis(
        members: _i(j['members']),
        membersJoined: _i(j['membersJoined']),
        tasksCompleted: _i(j['tasksCompleted']),
        tasksCompletedChange: _in(j['tasksCompletedChange']),
        inProgress: _i(j['inProgress']),
        pendingBlocked: _i(j['pendingBlocked']),
        activityRate: _in(j['activityRate']),
        onTimeDelivery: _in(j['onTimeDelivery']),
      );
}

class TeamMemberRow {
  const TeamMemberRow({required this.memberId, required this.name, this.role = '', this.tasks = 0, this.completed = 0, this.progress = 0, this.state = ''});
  final String memberId;
  final String name;
  final String role;
  final int tasks;
  final int completed;
  final int progress;
  final String state;

  factory TeamMemberRow.fromJson(Map<String, dynamic> j) =>
      TeamMemberRow(memberId: _s(j['memberId']), name: _s(j['name']), role: _s(j['role']), tasks: _i(j['tasks']), completed: _i(j['completed']), progress: _i(j['progress']), state: _s(j['state']));
}

/// One log as it reads in a feed.
class TeamFeedItem {
  const TeamFeedItem({required this.id, required this.member, required this.workedOn, this.memberId = '', this.at, this.day = '', this.projectLabel = '', this.projectKey = 'none', this.kind = ActivityKind.task, this.status = WorkStatus.completed, this.minutes = 0, this.brand = TeamBrand.main, this.group = '', this.groupId, this.contentId, this.legacy = false});
  final String id;
  final String memberId;
  final String member;
  final String workedOn;
  final DateTime? at;
  final String day;
  final String projectLabel;
  final ActivityKind kind;
  final WorkStatus status;
  final int minutes;
  final TeamBrand brand;
  final String group;
  final bool legacy;

  /// Which project the log is for, as the key the server filters by (`id:<projectId>`, `label:<text>` or `none`).
  final String projectKey;
  final String? groupId;

  /// The Socials post the work published, when the log was tied to one.
  final String? contentId;

  factory TeamFeedItem.fromJson(Map<String, dynamic> j) => TeamFeedItem(
        id: _s(j['id']),
        memberId: _s(j['memberId']),
        member: _s(j['member']),
        workedOn: _s(j['workedOn']),
        at: _dt(j['at']),
        day: _s(j['day']),
        projectLabel: _s(j['projectLabel']),
        kind: ActivityKind.parse(_s(j['kind'])),
        status: WorkStatus.parse(_s(j['status'])),
        minutes: _i(j['minutes']),
        brand: TeamBrand.parse(_s(j['brand'])),
        group: _s(j['group']),
        groupId: j['groupId']?.toString(),
        projectKey: _s(j['projectKey']).isEmpty ? 'none' : _s(j['projectKey']),
        contentId: j['contentId']?.toString(),
        legacy: j['legacy'] == true,
      );
}

class WorkloadSlice {
  const WorkloadSlice({required this.group, required this.count, required this.pct});
  final String group;
  final int count;
  final int pct;
  factory WorkloadSlice.fromJson(Map<String, dynamic> j) => WorkloadSlice(group: _s(j['group']), count: _i(j['count']), pct: _i(j['pct']));
}

class CategoryProgress {
  const CategoryProgress({required this.group, required this.total, required this.completed, required this.pct});
  final String group;
  final int total;
  final int completed;
  final int pct;
  factory CategoryProgress.fromJson(Map<String, dynamic> j) => CategoryProgress(group: _s(j['group']), total: _i(j['total']), completed: _i(j['completed']), pct: _i(j['pct']));
}

class TrendPoint {
  const TrendPoint({required this.day, required this.completed, this.activityPct});
  final String day;
  final int completed;
  final int? activityPct;
  factory TrendPoint.fromJson(Map<String, dynamic> j) => TrendPoint(day: _s(j['day']), completed: _i(j['completed']), activityPct: _in(j['activityPct']));
}

class AttendanceCounts {
  const AttendanceCounts({this.day = '', this.present = 0, this.onShoot = 0, this.wfh = 0, this.onLeave = 0, this.absent = 0, this.timebox = const TimeboxInfo()});
  final String day;
  final int present;
  final int onShoot;

  /// Working from home (the member set it for the day).
  final int wfh;
  final int onLeave;
  final int absent;

  /// Where the counts come from (the Overview's card; the Attendance tab's summary carries it on AttendanceData).
  final TimeboxInfo timebox;
  factory AttendanceCounts.fromJson(Map<String, dynamic> j) => AttendanceCounts(day: _s(j['day']), present: _i(j['present']), onShoot: _i(j['onShoot']), wfh: _i(j['wfh']), onLeave: _i(j['onLeave']), absent: _i(j['absent']), timebox: TimeboxInfo.fromJson(_m(j['timebox'])));
}

/// The work modes a member can set for a day (backend models/MarketingWorkMode.js).
enum WorkMode {
  office('office', 'Office'),
  onShoot('on_shoot', 'On Shoot'),
  wfh('wfh', 'Work From Home');

  const WorkMode(this.wire, this.label);
  final String wire;
  final String label;
  static WorkMode? parse(String? s) => WorkMode.values.where((m) => m.wire == s).firstOrNull;
}

/// "Office", "On shoot", "Work from home", "On leave" — or "—".
String workModeLabel(String wire) => switch (wire) { 'office' => 'Office', 'on_shoot' => 'On shoot', 'wfh' => 'Work from home', 'on_leave' => 'On leave', _ => '—' };

class Deadline {
  const Deadline({required this.id, required this.title, this.project = '', this.dueDate = '', this.assignee = '', this.priority = 'medium'});
  final String id;
  final String title;
  final String project;
  final String dueDate;
  final String assignee;
  final String priority;
  factory Deadline.fromJson(Map<String, dynamic> j) => Deadline(id: _s(j['id']), title: _s(j['title']), project: _s(j['project']), dueDate: _s(j['dueDate']), assignee: _s(j['assignee']), priority: _s(j['priority']));
}

class TeamOverview {
  const TeamOverview({
    this.from = '', this.to = '', this.kpis = const TeamKpis(), this.members = const [], this.todayFeed = const [], this.todayDay = '', this.workload = const [],
    this.totalItems = 0, this.progressByCategory = const [], this.trend = const [], this.attendance = const AttendanceCounts(), this.deadlines = const [],
    this.recentUpdates = const [], this.insights = const [],
  });
  final String from;
  final String to;
  final TeamKpis kpis;
  final List<TeamMemberRow> members;
  final List<TeamFeedItem> todayFeed;
  final String todayDay;
  final List<WorkloadSlice> workload;
  final int totalItems;
  final List<CategoryProgress> progressByCategory;
  final List<TrendPoint> trend;
  final AttendanceCounts attendance;
  final List<Deadline> deadlines;
  final List<TeamFeedItem> recentUpdates;
  final List<String> insights;

  factory TeamOverview.fromJson(Map<String, dynamic> j) => TeamOverview(
        from: _s(j['from']),
        to: _s(j['to']),
        kpis: TeamKpis.fromJson(_m(j['kpis'])),
        members: _l(j['members']).map(TeamMemberRow.fromJson).toList(),
        todayFeed: _l(j['todayFeed']).map(TeamFeedItem.fromJson).toList(),
        todayDay: _s(j['todayDay']),
        workload: _l(j['workload']).map(WorkloadSlice.fromJson).toList(),
        totalItems: _i(j['totalItems']),
        progressByCategory: _l(j['progressByCategory']).map(CategoryProgress.fromJson).toList(),
        trend: _l(j['trend']).map(TrendPoint.fromJson).toList(),
        attendance: AttendanceCounts.fromJson(_m(j['attendance'])),
        deadlines: _l(j['deadlines']).map(Deadline.fromJson).toList(),
        recentUpdates: _l(j['recentUpdates']).map(TeamFeedItem.fromJson).toList(),
        insights: ((j['insights'] as List?) ?? const []).map(_s).toList(),
      );
}

class ActivitySummary {
  const ActivitySummary({this.day = '', this.logged = 0, this.completed = 0, this.inProgress = 0, this.meetings = 0, this.minutes = 0});
  final String day;
  final int logged;
  final int completed;
  final int inProgress;
  final int meetings;
  final int minutes;
  factory ActivitySummary.fromJson(Map<String, dynamic> j) => ActivitySummary(day: _s(j['day']), logged: _i(j['logged']), completed: _i(j['completed']), inProgress: _i(j['inProgress']), meetings: _i(j['meetings']), minutes: _i(j['minutes']));
}

/// One row of the By Member / By Project / By Category views: the logs, the time and the completed ones under it.
class ActivityViewRow {
  const ActivityViewRow({required this.key, required this.label, this.logs = 0, this.minutes = 0, this.completed = 0});
  final String key;
  final String label;
  final int logs;
  final int minutes;
  final int completed;
  factory ActivityViewRow.fromJson(Map<String, dynamic> j) => ActivityViewRow(key: _s(j['key']), label: _s(j['label']), logs: _i(j['logs']), minutes: _i(j['minutes']), completed: _i(j['completed']));
}

class TeamActivityFeed {
  const TeamActivityFeed({this.summary = const ActivitySummary(), this.total = 0, this.items = const [], this.byMember = const [], this.byProject = const [], this.byCategory = const [], this.page = 1, this.pageSize = 100});
  final ActivitySummary summary;
  final int total;
  final List<TeamFeedItem> items;

  /// The whole period three ways (the server counts them; the kind / category / project picked narrows only the feed).
  final List<ActivityViewRow> byMember, byProject, byCategory;
  final int page, pageSize;
  factory TeamActivityFeed.fromJson(Map<String, dynamic> j) {
    final v = _m(j['views']);
    return TeamActivityFeed(
      summary: ActivitySummary.fromJson(_m(j['summary'])),
      total: _i(j['total']),
      items: _l(j['items']).map(TeamFeedItem.fromJson).toList(),
      byMember: _l(v['byMember']).map(ActivityViewRow.fromJson).toList(),
      byProject: _l(v['byProject']).map(ActivityViewRow.fromJson).toList(),
      byCategory: _l(v['byCategory']).map(ActivityViewRow.fromJson).toList(),
      page: _in(j['page']) ?? 1,
      pageSize: _in(j['pageSize']) ?? 100,
    );
  }
}

/// How the Team Activity tab cuts its feed — every cut is made on the server.
class ActivityQuery {
  const ActivityQuery({this.kind, this.group, this.project, this.memberId, this.label = ''});
  final ActivityKind? kind;

  /// A category (group id, or 'others'), a project key, or a member — what a row of a view was tapped for.
  final String? group, project, memberId;

  /// What that row was called, for the "showing …" chip.
  final String label;
  bool get narrowed => group != null || project != null || memberId != null;
  ActivityQuery withKind(ActivityKind? k) => ActivityQuery(kind: k, group: group, project: project, memberId: memberId, label: label);
  ActivityQuery get cleared => ActivityQuery(kind: kind);
  Map<String, dynamic> get query => {'kind': ?kind?.wire, 'group': ?group, 'project': ?project};
  @override
  bool operator ==(Object other) => other is ActivityQuery && other.kind == kind && other.group == group && other.project == project && other.memberId == memberId;
  @override
  int get hashCode => Object.hash(kind, group, project, memberId);
}

class TeamTask {
  const TeamTask({
    required this.id, required this.title, this.description = '', this.assigneeId = '', this.assignee = '', this.brand = TeamBrand.main, this.group = '', this.groupId,
    this.projectLabel = '', this.isDeliverable = false, this.dueDate, this.priority = 'medium', this.status = WorkStatus.notStarted, this.progress = 0, this.overdue = false,
    this.comments = const [], this.initiativeId, this.devProjectId, this.source = 'task', this.requestStatus, this.link, this.canEdit = true, this.createdByMe = false,
  });
  final String id;
  final String title;

  /// 'task' — a Team Dashboard task — or 'request': a Coordinations request given to the member, changed in Coordinations ([link]).
  final String source;
  final String? requestStatus;
  final String? link;
  final bool canEdit;
  final bool createdByMe;
  bool get isRequest => source == 'request';
  final String description;
  final String assigneeId;
  final String assignee;
  final TeamBrand brand;
  final String group;
  final String? groupId;
  final String projectLabel;
  final bool isDeliverable;
  final String? dueDate;
  final String priority;
  final WorkStatus status;
  final int progress;
  final bool overdue;
  final List<({String by, String text})> comments;
  final String? initiativeId, devProjectId;

  factory TeamTask.fromJson(Map<String, dynamic> j) => TeamTask(
        id: _s(j['id']),
        title: _s(j['title']),
        description: _s(j['description']),
        assigneeId: _s(j['assigneeId']),
        assignee: _s(j['assignee']),
        brand: TeamBrand.parse(_s(j['brand'])),
        group: _s(j['group']),
        groupId: j['groupId']?.toString(),
        projectLabel: _s(j['projectLabel']),
        isDeliverable: j['isDeliverable'] == true,
        dueDate: j['dueDate']?.toString(),
        priority: _s(j['priority']).isEmpty ? 'medium' : _s(j['priority']),
        status: WorkStatus.parse(_s(j['status'])),
        progress: _i(j['progress']),
        overdue: j['overdue'] == true,
        comments: _l(j['comments']).map((c) => (by: _s(c['by']), text: _s(c['text']))).toList(),
        initiativeId: j['initiativeId']?.toString(),
        devProjectId: j['devProjectId']?.toString(),
        source: _s(j['source']).isEmpty ? 'task' : _s(j['source']),
        requestStatus: j['requestStatus']?.toString(),
        link: j['link']?.toString(),
        canEdit: j['canEdit'] != false,
        createdByMe: j['createdByMe'] == true,
      );
}

/// Which tasks the Tasks tab lists: everyone's (a member only ever gets their own), mine, or the ones I made.
enum TaskScope {
  all('all', 'All tasks'),
  mine('mine', 'My Tasks'),
  assignedByMe('assigned_by_me', 'Assigned by me');

  const TaskScope(this.wire, this.label);
  final String wire;
  final String label;
}

class TeamTaskList {
  const TeamTaskList({this.counts = const {}, this.items = const []});
  final Map<String, int> counts;
  final List<TeamTask> items;
  factory TeamTaskList.fromJson(Map<String, dynamic> j) =>
      TeamTaskList(counts: {for (final e in _m(j['counts']).entries) e.key: _i(e.value)}, items: _l(j['items']).map(TeamTask.fromJson).toList());
}

class TimesheetRow {
  const TimesheetRow({required this.memberId, required this.name, this.role = '', this.minutes = 0, this.label = '—', this.logs = 0, this.daysLogged = 0, this.byDay = const {}, this.status = '', this.timeboxMinutes, this.timeboxLabel = ''});
  final String memberId;
  final String name;
  final String role;
  final int minutes;
  final String label;
  final int logs;
  final int daysLogged;
  final Map<String, int> byDay;
  final String status;

  /// The hours Timebox counted from the member's punches in the period (null = not linked to Timebox, or Timebox not connected).
  final int? timeboxMinutes;
  final String timeboxLabel;
  factory TimesheetRow.fromJson(Map<String, dynamic> j) => TimesheetRow(
        memberId: _s(j['memberId']),
        name: _s(j['name']),
        role: _s(j['role']),
        minutes: _i(j['minutes']),
        label: _s(j['label']),
        logs: _i(j['logs']),
        daysLogged: _i(j['daysLogged']),
        byDay: {for (final e in _m(j['byDay']).entries) e.key: _i(e.value)},
        status: _s(j['status']),
        timeboxMinutes: _in(j['timeboxMinutes']),
        timeboxLabel: _s(j['timeboxLabel']),
      );
}

class TimeSplit {
  const TimeSplit({required this.group, required this.minutes, required this.pct});
  final String group;
  final int minutes;
  final int pct;
  factory TimeSplit.fromJson(Map<String, dynamic> j) => TimeSplit(group: _s(j['group']), minutes: _i(j['minutes']), pct: _i(j['pct']));
}

/// Logs & Timesheet → Work Summary: one member's period, from their logs.
class WorkSummaryRow {
  const WorkSummaryRow({required this.memberId, required this.name, this.role = '', this.logs = 0, this.minutes = 0, this.completedCount = 0, this.completed = const [], this.pending = '', this.nextPriority = '', this.lastDay});
  final String memberId, name, role, pending, nextPriority;
  final int logs, minutes, completedCount;
  final List<String> completed;
  final String? lastDay;
  factory WorkSummaryRow.fromJson(Map<String, dynamic> j) => WorkSummaryRow(
        memberId: _s(j['memberId']),
        name: _s(j['name']),
        role: _s(j['role']),
        logs: _i(j['logs']),
        minutes: _i(j['minutes']),
        completedCount: _i(j['completedCount']),
        completed: ((j['completed'] as List?) ?? const []).map(_s).toList(),
        pending: _s(j['pending']),
        nextPriority: _s(j['nextPriority']),
        lastDay: j['lastDay']?.toString(),
      );
}

/// Logs & Timesheet → Activity Report: the counts per activity, and per group.
class ActivityReportRow {
  const ActivityReportRow({required this.metric, this.group = '', this.unitType = 'count', this.total = 0, this.logs = 0, this.members = 0});
  final String metric, group, unitType;
  final num total;
  final int logs, members;
  bool get isMoney => unitType == 'currency';
  factory ActivityReportRow.fromJson(Map<String, dynamic> j) => ActivityReportRow(metric: _s(j['metric']), group: _s(j['group']), unitType: _s(j['unitType']).isEmpty ? 'count' : _s(j['unitType']), total: (j['total'] as num?) ?? 0, logs: _i(j['logs']), members: _i(j['members']));
}

class Timesheet {
  const Timesheet({this.days = const [], this.totalMinutes = 0, this.totalLabel = '—', this.split = const [], this.rows = const [], this.workSummary = const [], this.activityReport = const [], this.activityGroups = const [], this.timeboxTotalMinutes, this.timeboxTotalLabel = '', this.timebox = const TimeboxInfo()});
  final List<String> days;
  final int totalMinutes;
  final String totalLabel;
  final List<TimeSplit> split;
  final List<TimesheetRow> rows;
  final List<WorkSummaryRow> workSummary;
  final List<ActivityReportRow> activityReport;
  final List<({String group, num total, int logs})> activityGroups;
  final int? timeboxTotalMinutes;
  final String timeboxTotalLabel;
  final TimeboxInfo timebox;
  factory Timesheet.fromJson(Map<String, dynamic> j) {
    final report = _m(j['activityReport']);
    return Timesheet(
      days: ((j['days'] as List?) ?? const []).map(_s).toList(),
      totalMinutes: _i(j['totalMinutes']),
      totalLabel: _s(j['totalLabel']),
      split: _l(j['split']).map(TimeSplit.fromJson).toList(),
      rows: _l(j['rows']).map(TimesheetRow.fromJson).toList(),
      workSummary: _l(j['workSummary']).map(WorkSummaryRow.fromJson).toList(),
      activityReport: _l(report['rows']).map(ActivityReportRow.fromJson).toList(),
      activityGroups: _l(report['groups']).map((g) => (group: _s(g['group']), total: (g['total'] as num?) ?? 0, logs: _i(g['logs']))).toList(),
      timeboxTotalMinutes: _in(j['timeboxTotalMinutes']),
      timeboxTotalLabel: _s(j['timeboxTotalLabel']),
      timebox: TimeboxInfo.fromJson(_m(j['timebox'])),
    );
  }
}

/// Logs & Timesheet → Daily Logs: one log with everything it says.
class DailyLogEntry {
  const DailyLogEntry({required this.item, this.completed = '', this.pending = '', this.nextPriority = '', this.comment = '', this.counts = const []});
  final TeamFeedItem item;
  final String completed, pending, nextPriority, comment;
  final List<({String metric, num value, String details})> counts;
  factory DailyLogEntry.fromJson(Map<String, dynamic> j) => DailyLogEntry(
        item: TeamFeedItem.fromJson(j),
        completed: _s(j['completed']),
        pending: _s(j['pending']),
        nextPriority: _s(j['nextPriority']),
        comment: _s(j['comment']),
        counts: _l(j['counts']).map((c) => (metric: _s(c['metric']), value: (c['value'] as num?) ?? 0, details: _s(c['details']))).toList(),
      );
}

class DailyLogs {
  const DailyLogs({this.total = 0, this.totalMinutes = 0, this.page = 1, this.pageSize = 50, this.items = const []});
  final int total, totalMinutes, page, pageSize;
  final List<DailyLogEntry> items;
  factory DailyLogs.fromJson(Map<String, dynamic> j) => DailyLogs(total: _i(j['total']), totalMinutes: _i(j['totalMinutes']), page: _in(j['page']) ?? 1, pageSize: _in(j['pageSize']) ?? 50, items: _l(j['items']).map(DailyLogEntry.fromJson).toList());
}

/// One week of a member's trend: their activity rate and, of their tasks due that week, the share completed (null = nothing to measure).
class MemberWeek {
  const MemberWeek({required this.week, this.activityPct, this.completion});
  final int week;
  final int? activityPct, completion;
  factory MemberWeek.fromJson(Map<String, dynamic> j) => MemberWeek(week: _i(j['week']), activityPct: _in(j['activityPct']), completion: _in(j['completion']));
}

class PerformanceRow {
  const PerformanceRow({required this.memberId, required this.name, this.role = '', this.completion, this.onTime, this.activityRate, this.overall, this.tasks = 0, this.leads, this.booked, this.leadToBooking, this.trend = const []});
  final String memberId;
  final String name;
  final String role;
  final int? completion;
  final int? onTime;
  final int? activityRate;
  final int? overall;
  final int tasks;

  /// The CRM leads given to the member's login that arrived in the range, the booked ones, and booked ÷ leads (null = "—").
  final int? leads, booked;
  final double? leadToBooking;
  final List<MemberWeek> trend;
  factory PerformanceRow.fromJson(Map<String, dynamic> j) => PerformanceRow(
        memberId: _s(j['memberId']),
        name: _s(j['name']),
        role: _s(j['role']),
        completion: _in(j['completion']),
        onTime: _in(j['onTime']),
        activityRate: _in(j['activityRate']),
        overall: _in(j['overall']),
        tasks: _i(j['tasks']),
        leads: _in(j['leads']),
        booked: _in(j['booked']),
        leadToBooking: _dn(j['leadToBooking']),
        trend: _l(j['trend']).map(MemberWeek.fromJson).toList(),
      );
}

class WeekPerformance {
  const WeekPerformance({required this.week, this.completion, this.onTime, this.tasks = 0});
  final int week;
  final int? completion;
  final int? onTime;
  final int tasks;
  factory WeekPerformance.fromJson(Map<String, dynamic> j) => WeekPerformance(week: _i(j['week']), completion: _in(j['completion']), onTime: _in(j['onTime']), tasks: _i(j['tasks']));
}

class PerformanceData {
  const PerformanceData({this.activityRate, this.tasksCompleted = 0, this.onTimeDelivery, this.leads, this.leadToBooking, this.rows = const [], this.trend = const []});
  final int? activityRate;
  final int? leads;
  final double? leadToBooking;
  final int tasksCompleted;
  final int? onTimeDelivery;
  final List<PerformanceRow> rows;
  final List<WeekPerformance> trend;
  factory PerformanceData.fromJson(Map<String, dynamic> j) {
    final k = _m(j['kpis']);
    return PerformanceData(
      activityRate: _in(k['activityRate']),
      tasksCompleted: _i(k['tasksCompleted']),
      onTimeDelivery: _in(k['onTimeDelivery']),
      leads: _in(k['leads']),
      leadToBooking: _dn(k['leadToBooking']),
      rows: _l(j['rows']).map(PerformanceRow.fromJson).toList(),
      trend: _l(j['trend']).map(WeekPerformance.fromJson).toList(),
    );
  }
}

/// Where the team's attendance comes from: Timebox (the company's attendance software, exactly as it records) when it is connected and
/// answering; otherwise the CRM's own records and the work logs — and the screens say which, with any problem in words.
class TimeboxInfo {
  const TimeboxInfo({this.mode = 'off', this.ok = false, this.problem = '', this.linked = 0, this.unlinked = const []});
  final String mode, problem;
  final bool ok;
  final int linked;
  final List<String> unlinked;

  /// Timebox answered and covers at least one member.
  bool get live => ok && linked > 0;
  factory TimeboxInfo.fromJson(Map<String, dynamic> j) => TimeboxInfo(
        mode: _s(j['mode']).isEmpty ? 'off' : _s(j['mode']),
        ok: j['ok'] == true,
        problem: _s(j['problem']),
        linked: _i(j['linked']),
        unlinked: ((j['unlinked'] as List?) ?? const []).map(_s).where((x) => x.isNotEmpty).toList(),
      );
}

class AttendanceRow {
  const AttendanceRow({required this.memberId, required this.name, this.role = '', this.checkIn, this.checkOut, this.hours, this.workMode = '', this.state = '', this.status = '', this.modeSet = false, this.monthRate, this.daysAttended, this.daysExpected, this.self = false, this.source = '', this.stillIn = false, this.timeboxLink = '', this.monthSource = '', this.planTotal, this.planDone});
  final String memberId;
  final String name;
  final String role;
  final DateTime? checkIn;
  final DateTime? checkOut;
  final double? hours;
  final String workMode;
  final String state;
  final String status;

  /// The member set the day's work mode themselves (or a manager did).
  final bool modeSet;

  /// Their attendance rate for the month up to the day (null = "—": no HR login and no work mode set).
  final int? monthRate, daysAttended, daysExpected;
  final bool self;

  /// Where the day's figures come from: 'timebox' (exact), 'crm' (the CRM's own record), 'logs' (only a work log) or '' (nothing).
  final String source;

  /// Punched in on Timebox and not out yet.
  final bool stillIn;

  /// How the member is linked to Timebox: 'login' or 'name' ('' = not linked); and where the month's rate comes from ('timebox' or '').
  final String timeboxLink, monthSource;

  /// The day's Timebox plan (worklist): items and how many are done (null = none written).
  final int? planTotal, planDone;
  bool get fromTimebox => source == 'timebox';
  factory AttendanceRow.fromJson(Map<String, dynamic> j) => AttendanceRow(
        memberId: _s(j['memberId']),
        name: _s(j['name']),
        role: _s(j['role']),
        checkIn: _dt(j['checkIn']),
        checkOut: _dt(j['checkOut']),
        hours: _dn(j['hours']),
        workMode: _s(j['workMode']),
        state: _s(j['state']),
        status: _s(j['status']),
        modeSet: j['modeSet'] == true,
        monthRate: _in(j['monthRate']),
        daysAttended: _in(j['daysAttended']),
        daysExpected: _in(j['daysExpected']),
        self: j['self'] == true,
        source: _s(j['source']),
        stillIn: j['stillIn'] == true,
        timeboxLink: _s(j['timeboxLink']),
        monthSource: _s(j['monthSource']),
        planTotal: j['plan'] is Map ? _in((j['plan'] as Map)['total']) : null,
        planDone: j['plan'] is Map ? _in((j['plan'] as Map)['done']) : null,
      );
}

class AttendanceData {
  const AttendanceData({this.date = '', this.summary = const AttendanceCounts(), this.rate, this.linked = 0, this.rows = const [], this.canSetOwn = false, this.canSetOthers = false, this.timebox = const TimeboxInfo()});
  final String date;
  final AttendanceCounts summary;
  final int? rate;
  final int linked;
  final List<AttendanceRow> rows;

  /// Whether this viewer may set their own work mode for the day (inside the edit window), or anyone's (a manager).
  final bool canSetOwn, canSetOthers;
  final TimeboxInfo timebox;
  factory AttendanceData.fromJson(Map<String, dynamic> j) => AttendanceData(
        date: _s(j['date']),
        summary: AttendanceCounts.fromJson(_m(j['summary'])),
        rate: _in(j['rate']),
        linked: _i(j['linked']),
        rows: _l(j['rows']).map(AttendanceRow.fromJson).toList(),
        canSetOwn: j['canSetOwn'] == true,
        canSetOthers: j['canSetOthers'] == true,
        timebox: TimeboxInfo.fromJson(_m(j['timebox'])),
      );
}

class TeamReport {
  const TeamReport({required this.title, required this.columns, required this.rows});
  final String title;
  final List<String> columns;
  final List<List<Object?>> rows;
  factory TeamReport.fromJson(Map<String, dynamic> j) => TeamReport(
        title: _s(j['title']),
        columns: ((j['columns'] as List?) ?? const []).map(_s).toList(),
        rows: ((j['rows'] as List?) ?? const []).map((r) => (r as List).cast<Object?>()).toList(),
      );
}

// ── Log Activity ─────────────────────────────────────────────────────────────

/// One activity (a count in the member's role profile) the log can count.
class LogMetric {
  const LogMetric({required this.id, required this.name, this.unitType = 'count', this.maxPerDay});
  final String id;
  final String name;
  final String unitType;
  final int? maxPerDay;
  bool get isMoney => unitType == 'currency';
  factory LogMetric.fromJson(Map<String, dynamic> j) => LogMetric(id: _s(j['id']), name: _s(j['name']), unitType: _s(j['unitType']), maxPerDay: _in(j['maxPerDay']));
}

class LogGroup {
  const LogGroup({required this.id, required this.name, this.metrics = const []});
  final String id;
  final String name;
  final List<LogMetric> metrics;
  factory LogGroup.fromJson(Map<String, dynamic> j) => LogGroup(id: _s(j['id']), name: _s(j['name']), metrics: _l(j['metrics']).map(LogMetric.fromJson).toList());
}

class LogTaskOption {
  const LogTaskOption({required this.id, required this.title, this.dueDate, this.progress = 0, this.groupId});
  final String id;
  final String title;
  final String? dueDate;
  final int progress;
  final String? groupId;
  factory LogTaskOption.fromJson(Map<String, dynamic> j) => LogTaskOption(id: _s(j['id']), title: _s(j['title']), dueDate: j['dueDate']?.toString(), progress: _i(j['progress']), groupId: j['groupId']?.toString());
}

/// A Socials post a log can publish (planned near the day, not published or cancelled — or the one a log is already tied to).
class LogPostOption {
  const LogPostOption({required this.id, required this.title, this.platform = '', this.contentType = '', this.status = '', this.day});
  final String id, title, platform, contentType, status;
  final String? day;
  bool get published => status == 'published';
  factory LogPostOption.fromJson(Map<String, dynamic> j) => LogPostOption(id: _s(j['id']), title: _s(j['title']), platform: _s(j['platform']), contentType: _s(j['contentType']), status: _s(j['status']), day: j['day']?.toString());
}

/// A log already saved for the day (for the "my day" list and for editing).
class SavedLog {
  const SavedLog({
    required this.id, required this.workedOn, this.loggedAt, this.brand = TeamBrand.main, this.kind = ActivityKind.task, this.status = WorkStatus.completed, this.minutes = 0,
    this.projectLabel = '', this.completed = '', this.pending = '', this.nextPriority = '', this.comment = '', this.counts = const {}, this.details = const {}, this.attachments = const [],
    this.taskId, this.shootId, this.shootStage, this.campaignId, this.initiativeId, this.legacy = false, this.projectId, this.groupId, this.contentId, this.devProjectId,
  });
  final String id;
  final String workedOn;
  final DateTime? loggedAt;
  final String? projectId, groupId, contentId, devProjectId;
  final TeamBrand brand;
  final ActivityKind kind;
  final WorkStatus status;
  final int minutes;
  final String projectLabel;
  final String completed;
  final String pending;
  final String nextPriority;
  final String comment;
  final Map<String, num> counts; // metricId → count
  final Map<String, String> details; // metricId → details
  final List<String> attachments;
  final String? taskId;
  final String? shootId, shootStage, campaignId, initiativeId;
  final bool legacy;

  factory SavedLog.fromJson(Map<String, dynamic> j) {
    final values = _l(j['values']);
    return SavedLog(
      id: _s(j['id']),
      workedOn: _s(j['workedOn']),
      loggedAt: _dt(j['loggedAt']),
      brand: TeamBrand.parse(_s(j['brand'])),
      kind: ActivityKind.parse(_s(j['kind'])),
      status: WorkStatus.parse(_s(j['status'])),
      minutes: _i(j['timeSpentMinutes']),
      projectLabel: _s(j['projectLabel']),
      completed: _s(j['completed']),
      pending: _s(j['pending']),
      nextPriority: _s(j['nextPriority']),
      comment: _s(j['comment']),
      counts: {for (final v in values) _s(v['metricId']): (v['value'] as num?) ?? 0},
      details: {for (final v in values) _s(v['metricId']): _s(v['details'])},
      attachments: _l(j['attachments']).map((a) => _s(a['url'])).toList(),
      taskId: j['taskId']?.toString(),
      shootId: j['shootId']?.toString(),
      shootStage: j['shootStage']?.toString(),
      campaignId: j['campaignId']?.toString(),
      initiativeId: j['initiativeId']?.toString(),
      projectId: j['projectId']?.toString(),
      groupId: j['groupId']?.toString(),
      contentId: j['contentId']?.toString(),
      devProjectId: j['devProjectId']?.toString(),
      legacy: j['legacy'] == true,
    );
  }
}

class LogSetup {
  const LogSetup({
    this.memberId = '', this.memberName = '', this.self = true, this.canLogForOthers = false, this.members = const [], this.date = '', this.groups = const [], this.tasks = const [],
    this.projects = const [], this.shoots = const [], this.campaigns = const [], this.initiatives = const [], this.devProjects = const [], this.logs = const [], this.dayMinutes = 0, this.canEdit = true, this.notice = '',
    this.categories = const [], this.posts = const [], this.workMode,
  });

  /// Every activity group a log or a task can count under (the "category"), whether or not the member counts anything in it.
  final List<({String id, String name})> categories;

  /// The Socials posts a log can publish.
  final List<LogPostOption> posts;

  /// The work mode the member set for the day (null = not set).
  final WorkMode? workMode;
  final String memberId;
  final String memberName;
  final bool self;
  final bool canLogForOthers;
  final List<({String id, String name})> members;
  final String date;
  final List<LogGroup> groups;
  final List<LogTaskOption> tasks;
  final List<({String id, String name})> projects;

  /// Shoots a log can be tied to (not finished or cancelled, near the day) — the Creative Portfolio's plans.
  final List<({String id, String title, String shootDate})> shoots;

  /// Open campaigns, initiatives and development projects a log or a task can be tied to (Campaigns / Strategies & Developments).
  final List<({String id, String title})> campaigns, initiatives, devProjects;
  final List<SavedLog> logs;
  final int dayMinutes;
  final bool canEdit;
  final String notice;

  factory LogSetup.fromJson(Map<String, dynamic> j) {
    final member = _m(j['member']);
    return LogSetup(
      memberId: _s(member['id']),
      memberName: _s(member['name']),
      self: j['self'] != false,
      canLogForOthers: j['canLogForOthers'] == true,
      members: _l(j['members']).map((m) => (id: _s(m['id']), name: _s(m['name']))).toList(),
      date: _s(j['date']),
      groups: _l(j['groups']).map(LogGroup.fromJson).toList(),
      tasks: _l(j['tasks']).map(LogTaskOption.fromJson).toList(),
      projects: _l(j['projects']).map((p) => (id: _s(p['id']), name: _s(p['name']))).toList(),
      shoots: _l(j['shoots']).map((p) => (id: _s(p['id']), title: _s(p['title']), shootDate: _s(p['shootDate']))).toList(),
      campaigns: _l(j['campaigns']).map((p) => (id: _s(p['id']), title: _s(p['title']))).toList(),
      initiatives: _l(j['initiatives']).map((p) => (id: _s(p['id']), title: _s(p['title']))).toList(),
      devProjects: _l(j['devProjects']).map((p) => (id: _s(p['id']), title: _s(p['name']))).toList(),
      logs: _l(j['logs']).map(SavedLog.fromJson).toList(),
      categories: _l(j['categories']).map((c) => (id: _s(c['id']), name: _s(c['name']))).toList(),
      posts: _l(j['posts']).map(LogPostOption.fromJson).toList(),
      workMode: WorkMode.parse(j['workMode']?.toString()),
      dayMinutes: _i(_m(j['totals'])['minutes']),
      canEdit: j['canEdit'] != false,
      notice: _s(j['notice']),
    );
  }
}

/// What the Log Activity form sends.
class LogDraft {
  LogDraft({
    this.memberId, required this.entryDate, required this.workedOn, this.projectLabel = '', this.projectId, this.completed = '', this.pending = '', this.nextPriority = '', this.minutes = 0,
    this.status = WorkStatus.completed, this.kind = ActivityKind.task, this.brand = TeamBrand.main, this.comment = '', this.attachments = const [], this.counts = const {}, this.details = const {},
    this.taskId, this.taskProgress, this.shootId, this.shootStage, this.campaignId, this.initiativeId, this.overrideReason = '', this.groupId, this.contentId, this.devProjectId,
  });

  /// The category chosen (it wins over the group of the biggest count), the Socials post the work published, the development project.
  final String? groupId, contentId, devProjectId;
  final String? memberId;
  final String entryDate;
  final String workedOn;
  final String projectLabel;
  final String? projectId;
  final String completed;
  final String pending;
  final String nextPriority;
  final int minutes;
  final WorkStatus status;
  final ActivityKind kind;
  final TeamBrand brand;
  final String comment;
  final List<String> attachments;
  final Map<String, num> counts;
  final Map<String, String> details;
  final String? taskId;
  final int? taskProgress;
  final String? shootId, shootStage, campaignId, initiativeId;
  final String overrideReason;

  Map<String, dynamic> toJson() => {
        'memberId': ?memberId,
        'entryDate': entryDate,
        'workedOn': workedOn,
        'projectLabel': projectLabel,
        'projectId': ?projectId,
        'completed': completed,
        'pending': pending,
        'nextPriority': nextPriority,
        'timeSpentMinutes': minutes,
        'status': status.wire,
        'kind': kind.wire,
        'brand': brand.wire,
        'comment': comment,
        'attachments': [for (final a in attachments.where((a) => a.trim().isNotEmpty)) {'url': a.trim()}],
        'values': [for (final e in counts.entries.where((e) => e.value > 0)) {'metricId': e.key, 'value': e.value, 'details': details[e.key] ?? ''}],
        'taskId': ?taskId,
        'taskProgress': ?taskProgress,
        'shootId': ?shootId,
        'campaignId': ?campaignId,
        'initiativeId': ?initiativeId,
        'groupId': ?groupId,
        'contentId': ?contentId,
        'devProjectId': ?devProjectId,
        if (shootId != null) 'shootStage': ?shootStage,
        if (overrideReason.trim().isNotEmpty) 'overrideReason': overrideReason.trim(),
      };
}

/// The server refused a log or a task and said why: show [message]; [reasonRequired] means "ask for a reason and send again".
class TeamRefusal implements Exception {
  const TeamRefusal(this.message, {this.field, this.reasonRequired = false, this.status = 400});
  final String message;
  final String? field;
  final bool reasonRequired;
  final int status;
  @override
  String toString() => message;
}
