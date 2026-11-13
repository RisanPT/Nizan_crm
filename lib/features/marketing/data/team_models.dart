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
  const TeamFeedItem({required this.id, required this.member, required this.workedOn, this.memberId = '', this.at, this.day = '', this.projectLabel = '', this.kind = ActivityKind.task, this.status = WorkStatus.completed, this.minutes = 0, this.brand = TeamBrand.main, this.group = '', this.legacy = false});
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
  const AttendanceCounts({this.day = '', this.present = 0, this.onShoot = 0, this.onLeave = 0, this.absent = 0});
  final String day;
  final int present;
  final int onShoot;
  final int onLeave;
  final int absent;
  factory AttendanceCounts.fromJson(Map<String, dynamic> j) => AttendanceCounts(day: _s(j['day']), present: _i(j['present']), onShoot: _i(j['onShoot']), onLeave: _i(j['onLeave']), absent: _i(j['absent']));
}

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

class TeamActivityFeed {
  const TeamActivityFeed({this.summary = const ActivitySummary(), this.total = 0, this.items = const []});
  final ActivitySummary summary;
  final int total;
  final List<TeamFeedItem> items;
  factory TeamActivityFeed.fromJson(Map<String, dynamic> j) =>
      TeamActivityFeed(summary: ActivitySummary.fromJson(_m(j['summary'])), total: _i(j['total']), items: _l(j['items']).map(TeamFeedItem.fromJson).toList());
}

class TeamTask {
  const TeamTask({
    required this.id, required this.title, this.description = '', this.assigneeId = '', this.assignee = '', this.brand = TeamBrand.main, this.group = '', this.groupId,
    this.projectLabel = '', this.isDeliverable = false, this.dueDate, this.priority = 'medium', this.status = WorkStatus.notStarted, this.progress = 0, this.overdue = false,
    this.comments = const [],
  });
  final String id;
  final String title;
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
      );
}

class TeamTaskList {
  const TeamTaskList({this.counts = const {}, this.items = const []});
  final Map<String, int> counts;
  final List<TeamTask> items;
  factory TeamTaskList.fromJson(Map<String, dynamic> j) =>
      TeamTaskList(counts: {for (final e in _m(j['counts']).entries) e.key: _i(e.value)}, items: _l(j['items']).map(TeamTask.fromJson).toList());
}

class TimesheetRow {
  const TimesheetRow({required this.memberId, required this.name, this.role = '', this.minutes = 0, this.label = '—', this.logs = 0, this.daysLogged = 0, this.byDay = const {}, this.status = ''});
  final String memberId;
  final String name;
  final String role;
  final int minutes;
  final String label;
  final int logs;
  final int daysLogged;
  final Map<String, int> byDay;
  final String status;
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
      );
}

class TimeSplit {
  const TimeSplit({required this.group, required this.minutes, required this.pct});
  final String group;
  final int minutes;
  final int pct;
  factory TimeSplit.fromJson(Map<String, dynamic> j) => TimeSplit(group: _s(j['group']), minutes: _i(j['minutes']), pct: _i(j['pct']));
}

class Timesheet {
  const Timesheet({this.days = const [], this.totalMinutes = 0, this.totalLabel = '—', this.split = const [], this.rows = const []});
  final List<String> days;
  final int totalMinutes;
  final String totalLabel;
  final List<TimeSplit> split;
  final List<TimesheetRow> rows;
  factory Timesheet.fromJson(Map<String, dynamic> j) => Timesheet(
        days: ((j['days'] as List?) ?? const []).map(_s).toList(),
        totalMinutes: _i(j['totalMinutes']),
        totalLabel: _s(j['totalLabel']),
        split: _l(j['split']).map(TimeSplit.fromJson).toList(),
        rows: _l(j['rows']).map(TimesheetRow.fromJson).toList(),
      );
}

class PerformanceRow {
  const PerformanceRow({required this.memberId, required this.name, this.role = '', this.completion, this.onTime, this.activityRate, this.overall, this.tasks = 0});
  final String memberId;
  final String name;
  final String role;
  final int? completion;
  final int? onTime;
  final int? activityRate;
  final int? overall;
  final int tasks;
  factory PerformanceRow.fromJson(Map<String, dynamic> j) => PerformanceRow(
        memberId: _s(j['memberId']),
        name: _s(j['name']),
        role: _s(j['role']),
        completion: _in(j['completion']),
        onTime: _in(j['onTime']),
        activityRate: _in(j['activityRate']),
        overall: _in(j['overall']),
        tasks: _i(j['tasks']),
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
  const PerformanceData({this.activityRate, this.tasksCompleted = 0, this.onTimeDelivery, this.rows = const [], this.trend = const []});
  final int? activityRate;
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
      rows: _l(j['rows']).map(PerformanceRow.fromJson).toList(),
      trend: _l(j['trend']).map(WeekPerformance.fromJson).toList(),
    );
  }
}

class AttendanceRow {
  const AttendanceRow({required this.memberId, required this.name, this.role = '', this.checkIn, this.checkOut, this.hours, this.workMode = '', this.state = '', this.status = ''});
  final String memberId;
  final String name;
  final String role;
  final DateTime? checkIn;
  final DateTime? checkOut;
  final double? hours;
  final String workMode;
  final String state;
  final String status;
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
      );
}

class AttendanceData {
  const AttendanceData({this.date = '', this.summary = const AttendanceCounts(), this.rate, this.linked = 0, this.rows = const []});
  final String date;
  final AttendanceCounts summary;
  final int? rate;
  final int linked;
  final List<AttendanceRow> rows;
  factory AttendanceData.fromJson(Map<String, dynamic> j) => AttendanceData(
        date: _s(j['date']),
        summary: AttendanceCounts.fromJson(_m(j['summary'])),
        rate: _in(j['rate']),
        linked: _i(j['linked']),
        rows: _l(j['rows']).map(AttendanceRow.fromJson).toList(),
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
  const LogTaskOption({required this.id, required this.title, this.dueDate, this.progress = 0});
  final String id;
  final String title;
  final String? dueDate;
  final int progress;
  factory LogTaskOption.fromJson(Map<String, dynamic> j) => LogTaskOption(id: _s(j['id']), title: _s(j['title']), dueDate: j['dueDate']?.toString(), progress: _i(j['progress']));
}

/// A log already saved for the day (for the "my day" list and for editing).
class SavedLog {
  const SavedLog({
    required this.id, required this.workedOn, this.loggedAt, this.brand = TeamBrand.main, this.kind = ActivityKind.task, this.status = WorkStatus.completed, this.minutes = 0,
    this.projectLabel = '', this.completed = '', this.pending = '', this.nextPriority = '', this.comment = '', this.counts = const {}, this.details = const {}, this.attachments = const [],
    this.taskId, this.shootId, this.shootStage, this.legacy = false,
  });
  final String id;
  final String workedOn;
  final DateTime? loggedAt;
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
  final String? shootId, shootStage;
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
      legacy: j['legacy'] == true,
    );
  }
}

class LogSetup {
  const LogSetup({
    this.memberId = '', this.memberName = '', this.self = true, this.canLogForOthers = false, this.members = const [], this.date = '', this.groups = const [], this.tasks = const [],
    this.projects = const [], this.shoots = const [], this.logs = const [], this.dayMinutes = 0, this.canEdit = true, this.notice = '',
  });
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
      logs: _l(j['logs']).map(SavedLog.fromJson).toList(),
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
    this.taskId, this.taskProgress, this.shootId, this.shootStage, this.overrideReason = '',
  });
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
  final String? shootId, shootStage;
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
