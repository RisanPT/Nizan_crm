// Coordinations' payloads (backend controllers/marketingCoordinationsController.js). A missing part reads as an empty value, never a crash.

int _i(dynamic v) => (v as num?)?.toInt() ?? 0;
int? _in(dynamic v) => (v as num?)?.toInt();
double _d(dynamic v) => (v as num?)?.toDouble() ?? 0;
String _s(dynamic v) => v?.toString() ?? '';
String? _sn(dynamic v) => v?.toString();
DateTime? _dt(dynamic v) => v == null ? null : DateTime.tryParse(v.toString())?.toLocal();
Map<String, dynamic> _m(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
List<Map<String, dynamic>> _l(dynamic v) => ((v as List?) ?? const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
List<String> _ls(dynamic v) => ((v as List?) ?? const []).map(_s).toList();

/// The ten teams a request can come from or go to — the server's list (utils/marketingCoordinationStats.js DEPARTMENTS).
const kCoordDepartments = ['Production', 'Socials', 'Marketing', 'Sales', 'Operations', 'HR', 'Finance', 'IT', 'Design', 'Others'];
const kApprovalCategories = [...kCoordDepartments, 'Brand'];

const kRequestStatuses = [
  ('open', 'Open'),
  ('in_progress', 'In Progress'),
  ('waiting_input', 'Waiting Input'),
  ('in_review', 'In Review'),
  ('pending_approval', 'Pending Approval'),
  ('completed', 'Completed'),
  ('cancelled', 'Cancelled'),
];
String requestStatusLabel(String s) => kRequestStatuses.firstWhere((e) => e.$1 == s, orElse: () => (s, s)).$2;

const kPriorities = [('high', 'High'), ('medium', 'Medium'), ('low', 'Low')];
String priorityLabel(String s) => kPriorities.firstWhere((e) => e.$1 == s, orElse: () => (s, s)).$2;

const kHandoverStages = [('requested', 'Requested'), ('in_progress', 'In Progress'), ('in_review', 'In Review'), ('completed', 'Completed')];
String stageLabel(String s) => kHandoverStages.firstWhere((e) => e.$1 == s, orElse: () => (s, s)).$2;

const kApprovalStatusLabels = {'pending': 'Pending', 'in_review': 'In Review', 'approved': 'Approved', 'rejected': 'Rejected', 'escalated': 'Escalated'};
String approvalStatusLabel(String s) => kApprovalStatusLabels[s] ?? s;

const kMeetingStateLabels = {'upcoming': 'Upcoming', 'live': 'Happening now', 'to_close': 'Needs notes', 'completed': 'Completed', 'cancelled': 'Cancelled'};
const kFollowUpStateLabels = {'upcoming': 'Upcoming', 'due_today': 'Due Today', 'overdue': 'Overdue', 'completed': 'Completed'};

// ── requests ──────────────────────────────────────────────────────────────────

class CoordRequestRow {
  const CoordRequestRow({
    required this.id, this.kind = 'request', required this.title, this.detail = '', this.fromDept = '', this.toDept = '', this.requestedById, this.requestedBy = '', this.assigneeId, this.assignee = '',
    this.priority = 'medium', this.dueDate, this.status = 'open', this.progress = 0, this.brand = 'main', this.stage, this.overdue = false, this.onTime, this.createdAt, this.closedAt,
    this.nextStatuses = const [], this.moveTo = const [], this.canEdit = false, this.canDelete = false, this.taskStatus, this.taskStatuses = const [], this.link,
  });
  final String id, kind, title, detail, fromDept, toDept, requestedBy, assignee, priority, status, brand;

  /// A Team Dashboard task in the table (kind 'task'): its own status, the statuses it can move to, and where it lives.
  final String? taskStatus, link;
  final List<String> taskStatuses;
  bool get isTask => kind == 'task';
  final String? requestedById, assigneeId, dueDate, stage;
  final int progress;
  final bool overdue, canEdit, canDelete;
  final bool? onTime;
  final DateTime? createdAt, closedAt;
  final List<String> nextStatuses, moveTo;

  bool get isHandover => kind == 'handover';

  factory CoordRequestRow.fromJson(Map<String, dynamic> j) => CoordRequestRow(
        id: _s(j['id']),
        kind: _s(j['kind']).isEmpty ? 'request' : _s(j['kind']),
        title: _s(j['title']),
        detail: _s(j['detail']),
        fromDept: _s(j['fromDept']),
        toDept: _s(j['toDept']),
        requestedById: _sn(j['requestedById']),
        requestedBy: _s(j['requestedBy']),
        assigneeId: _sn(j['assigneeId']),
        assignee: _s(j['assignee']),
        priority: _s(j['priority']).isEmpty ? 'medium' : _s(j['priority']),
        dueDate: _sn(j['dueDate']),
        status: _s(j['status']).isEmpty ? 'open' : _s(j['status']),
        progress: _i(j['progress']),
        brand: _s(j['brand']).isEmpty ? 'main' : _s(j['brand']),
        stage: _sn(j['stage']),
        overdue: j['overdue'] == true,
        onTime: j['onTime'] is bool ? j['onTime'] as bool : null,
        createdAt: _dt(j['createdAt']),
        closedAt: _dt(j['closedAt']),
        nextStatuses: _ls(j['nextStatuses']),
        moveTo: _ls(j['moveTo']),
        canEdit: j['canEdit'] == true,
        canDelete: j['canDelete'] == true,
        taskStatus: _sn(j['taskStatus']),
        taskStatuses: _ls(j['taskStatuses']),
        link: _sn(j['link']),
      );
}

/// A Team Dashboard task's own status words (the table shows a team task the way the Team Dashboard does).
const kTeamTaskStatusLabels = {'not_started': 'Not started', 'in_progress': 'In progress', 'pending': 'Pending', 'blocked': 'Blocked', 'completed': 'Completed'};

/// The status a row of the task table shows: a team task's own word, else the request's.
String rowStatusLabel(CoordRequestRow r) => r.isTask ? kTeamTaskStatusLabels[r.taskStatus] ?? requestStatusLabel(r.status) : requestStatusLabel(r.status);

/// The headline figures (the server's coordKpis): one definition behind the Overview strip and the Requests strip.
class CoordKpis {
  const CoordKpis({this.total = 0, this.requests = 0, this.approvals = 0, this.completed = 0, this.inProgress = 0, this.pending = 0, this.pendingApprovals = 0, this.overdue = 0, this.onTimeRate, this.onTimeOf = 0});
  final int total, requests, approvals, completed, inProgress, pending, pendingApprovals, overdue, onTimeOf;
  final int? onTimeRate;
  factory CoordKpis.fromJson(Map<String, dynamic> j) => CoordKpis(
        total: _i(j['total']), requests: _i(j['requests']), approvals: _i(j['approvals']), completed: _i(j['completed']), inProgress: _i(j['inProgress']), pending: _i(j['pending']),
        pendingApprovals: _i(j['pendingApprovals']), overdue: _i(j['overdue']), onTimeRate: _in(j['onTimeRate']), onTimeOf: _i(j['onTimeOf']),
      );
}

class DeptSlice {
  const DeptSlice({required this.label, this.count = 0, this.pct = 0});
  final String label;
  final int count, pct;
  factory DeptSlice.fromJson(Map<String, dynamic> j) => DeptSlice(label: _s(j['label']), count: _i(j['count']), pct: _i(j['pct']));
}

class DeptBreakdown {
  const DeptBreakdown({this.by = 'both', this.total = 0, this.rows = const []});
  final String by;
  final int total;
  final List<DeptSlice> rows;
  factory DeptBreakdown.fromJson(Map<String, dynamic> j) => DeptBreakdown(by: _s(j['by']).isEmpty ? 'both' : _s(j['by']), total: _i(j['total']), rows: _l(j['rows']).map(DeptSlice.fromJson).toList());
}

class UpcomingItem {
  const UpcomingItem({required this.type, required this.id, required this.title, this.day = '', this.time = '', this.endTime = '', this.subtitle = '', this.location = ''});
  final String type, id, title, day, time, endTime, subtitle, location;
  bool get isMeeting => type == 'meeting';
  factory UpcomingItem.fromJson(Map<String, dynamic> j) => UpcomingItem(type: _s(j['type']), id: _s(j['id']), title: _s(j['title']), day: _s(j['day']), time: _s(j['time']), endTime: _s(j['endTime']), subtitle: _s(j['subtitle']), location: _s(j['location']));
}

class KeyUpdate {
  const KeyUpdate({required this.tone, required this.text});
  final String tone, text;
  factory KeyUpdate.fromJson(Map<String, dynamic> j) => KeyUpdate(tone: _s(j['tone']), text: _s(j['text']));
}

/// A post or asset waiting for review in Socials / the Creative Portfolio.
class ReviewItem {
  const ReviewItem({required this.type, required this.id, required this.title, this.brand = 'main', this.label = '', this.thumbUrl = '', this.day, this.link = ''});
  final String type, id, title, brand, label, thumbUrl, link;
  final String? day;
  factory ReviewItem.fromJson(Map<String, dynamic> j) => ReviewItem(type: _s(j['type']), id: _s(j['id']), title: _s(j['title']), brand: _s(j['brand']).isEmpty ? 'main' : _s(j['brand']), label: _s(j['label']), thumbUrl: _s(j['thumbUrl']), day: _sn(j['day']), link: _s(j['link']));
}

class ReviewQueue {
  const ReviewQueue({this.total = 0, this.content = 0, this.assets = 0, this.items = const []});
  final int total, content, assets;
  final List<ReviewItem> items;
  factory ReviewQueue.fromJson(Map<String, dynamic> j) => ReviewQueue(total: _i(j['total']), content: _i(j['content']), assets: _i(j['assets']), items: _l(j['items']).map(ReviewItem.fromJson).toList());
}

class TabCounts {
  const TabCounts({this.my = 0, this.team = 0, this.all = 0});
  final int my, team, all;
  factory TabCounts.fromJson(Map<String, dynamic> j) => TabCounts(my: _i(j['my']), team: _i(j['team']), all: _i(j['all']));
  int of(String scope) => scope == 'my' ? my : (scope == 'team' ? team : all);
}

class ApprovalsPending {
  const ApprovalsPending({this.approvals = const [], this.approvalCount = 0, this.review = const ReviewQueue()});
  final List<ApprovalRow> approvals;
  final int approvalCount;
  final ReviewQueue review;
  factory ApprovalsPending.fromJson(Map<String, dynamic> j) => ApprovalsPending(approvals: _l(j['approvals']).map(ApprovalRow.fromJson).toList(), approvalCount: _i(j['approvalCount']), review: ReviewQueue.fromJson(_m(j['review'])));
}

class CoordOverview {
  const CoordOverview({
    this.today = '', this.kpis = const CoordKpis(), this.changeTotal, this.changeCompleted, this.tabCounts = const TabCounts(), this.tasks = const {}, this.byDepartment = const DeptBreakdown(), this.recent = const [], this.interDepartment = const [],
    this.approvalsPending = const ApprovalsPending(), this.upcomingPeriod = 'week', this.upcoming = const [], this.keyUpdates = const [],
  });
  final String today, upcomingPeriod;
  final CoordKpis kpis;
  final int? changeTotal, changeCompleted;
  final TabCounts tabCounts;
  final Map<String, List<CoordRequestRow>> tasks;
  final DeptBreakdown byDepartment;
  final List<CoordRequestRow> recent, interDepartment;
  final ApprovalsPending approvalsPending;
  final List<UpcomingItem> upcoming;
  final List<KeyUpdate> keyUpdates;

  factory CoordOverview.fromJson(Map<String, dynamic> j) {
    final tasks = _m(j['tasks']);
    final change = _m(j['change']);
    final up = _m(j['upcoming']);
    return CoordOverview(
      today: _s(j['today']),
      kpis: CoordKpis.fromJson(_m(j['kpis'])),
      changeTotal: _in(change['total']),
      changeCompleted: _in(change['completed']),
      tabCounts: TabCounts.fromJson(_m(j['tabCounts'])),
      tasks: {for (final k in const ['my', 'team', 'all']) k: _l(tasks[k]).map(CoordRequestRow.fromJson).toList()},
      byDepartment: DeptBreakdown.fromJson(_m(j['byDepartment'])),
      recent: _l(j['recent']).map(CoordRequestRow.fromJson).toList(),
      interDepartment: _l(j['interDepartment']).map(CoordRequestRow.fromJson).toList(),
      approvalsPending: ApprovalsPending.fromJson(_m(j['approvalsPending'])),
      upcomingPeriod: _s(up['period']).isEmpty ? 'week' : _s(up['period']),
      upcoming: _l(up['items']).map(UpcomingItem.fromJson).toList(),
      keyUpdates: _l(j['keyUpdates']).map(KeyUpdate.fromJson).toList(),
    );
  }
}

class RequestList {
  const RequestList({this.kpis = const CoordKpis(), this.tabCounts = const TabCounts(), this.items = const [], this.total = 0, this.page = 1, this.pageSize = 10, this.teamTasks = 0});
  final CoordKpis kpis;
  final TabCounts tabCounts;
  final List<CoordRequestRow> items;
  final int total, page, pageSize;

  /// How many of the table's rows are Team Dashboard tasks (the strip counts requests only).
  final int teamTasks;
  factory RequestList.fromJson(Map<String, dynamic> j) => RequestList(
        kpis: CoordKpis.fromJson(_m(j['kpis'])),
        tabCounts: TabCounts.fromJson(_m(j['tabCounts'])),
        teamTasks: _i(j['teamTasks']),
        items: _l(j['items']).map(CoordRequestRow.fromJson).toList(),
        total: _i(j['total']),
        page: _i(j['page']) == 0 ? 1 : _i(j['page']),
        pageSize: _i(j['pageSize']) == 0 ? 10 : _i(j['pageSize']),
      );
}

// ── inter-department board ────────────────────────────────────────────────────

class BoardKpis {
  const BoardKpis({this.active = 0, this.awaitingAction = 0, this.inReview = 0, this.overdue = 0, this.completed = 0});
  final int active, awaitingAction, inReview, overdue, completed;
  factory BoardKpis.fromJson(Map<String, dynamic> j) => BoardKpis(active: _i(j['active']), awaitingAction: _i(j['awaitingAction']), inReview: _i(j['inReview']), overdue: _i(j['overdue']), completed: _i(j['completed']));
}

class BoardStage {
  const BoardStage({required this.key, required this.label, this.count = 0, this.items = const []});
  final String key, label;
  final int count;
  final List<CoordRequestRow> items;
  factory BoardStage.fromJson(Map<String, dynamic> j) => BoardStage(key: _s(j['key']), label: _s(j['label']), count: _i(j['count']), items: _l(j['items']).map(CoordRequestRow.fromJson).toList());
}

class HandoverBoard {
  const HandoverBoard({this.kpis = const BoardKpis(), this.stages = const []});
  final BoardKpis kpis;
  final List<BoardStage> stages;
  factory HandoverBoard.fromJson(Map<String, dynamic> j) => HandoverBoard(kpis: BoardKpis.fromJson(_m(j['kpis'])), stages: _l(j['stages']).map(BoardStage.fromJson).toList());
}

// ── approvals ─────────────────────────────────────────────────────────────────

class ApprovalRow {
  const ApprovalRow({
    required this.id, required this.title, this.category = '', this.amount = 0, this.impact = '', this.requestedById, this.requestedBy = '', this.status = 'pending', this.dueDate, this.brand = 'main', this.requestId,
    this.requestedOn, this.decidedAt, this.decidedBy = '', this.decisionNote = '', this.overdue = false, this.canDecide = false, this.canEdit = false, this.canDelete = false,
    this.escalatedToLabel = '', this.escalatedBy = '',
  });
  final String id, title, category, impact, requestedBy, status, brand, decidedBy, decisionNote;

  /// Who an escalation went up to ("Escalated to Anjali (CEO) and 2 Marketing Managers") and who escalated it — empty when it was not.
  final String escalatedToLabel, escalatedBy;
  final double amount;
  final String? requestedById, dueDate, requestId, requestedOn;
  final DateTime? decidedAt;
  final bool overdue, canDecide, canEdit, canDelete;
  bool get awaiting => status == 'pending' || status == 'in_review' || status == 'escalated';
  factory ApprovalRow.fromJson(Map<String, dynamic> j) => ApprovalRow(
        id: _s(j['id']),
        title: _s(j['title']),
        category: _s(j['category']),
        amount: _d(j['amount']),
        impact: _s(j['impact']),
        requestedById: _sn(j['requestedById']),
        requestedBy: _s(j['requestedBy']),
        status: _s(j['status']).isEmpty ? 'pending' : _s(j['status']),
        dueDate: _sn(j['dueDate']),
        brand: _s(j['brand']).isEmpty ? 'main' : _s(j['brand']),
        requestId: _sn(j['requestId']),
        requestedOn: _sn(j['requestedOn']),
        decidedAt: _dt(j['decidedAt']),
        decidedBy: _s(j['decidedBy']),
        decisionNote: _s(j['decisionNote']),
        overdue: j['overdue'] == true,
        canDecide: j['canDecide'] == true,
        canEdit: j['canEdit'] == true,
        canDelete: j['canDelete'] == true,
        escalatedToLabel: _s(j['escalatedToLabel']),
        escalatedBy: _s(j['escalatedBy']),
      );
}

class ApprovalKpis {
  const ApprovalKpis({this.total = 0, this.pending = 0, this.inReview = 0, this.escalated = 0, this.approved = 0, this.rejected = 0, this.awaitingAmount = 0});
  final int total, pending, inReview, escalated, approved, rejected;
  final double awaitingAmount;
  factory ApprovalKpis.fromJson(Map<String, dynamic> j) => ApprovalKpis(total: _i(j['total']), pending: _i(j['pending']), inReview: _i(j['inReview']), escalated: _i(j['escalated']), approved: _i(j['approved']), rejected: _i(j['rejected']), awaitingAmount: _d(j['awaitingAmount']));
}

class ApprovalList {
  const ApprovalList({this.kpis = const ApprovalKpis(), this.tabCounts = const {}, this.items = const [], this.total = 0, this.page = 1, this.pageSize = 10, this.review = const ReviewQueue()});
  final ApprovalKpis kpis;
  final Map<String, int> tabCounts;
  final List<ApprovalRow> items;
  final int total, page, pageSize;
  final ReviewQueue review;
  factory ApprovalList.fromJson(Map<String, dynamic> j) => ApprovalList(
        kpis: ApprovalKpis.fromJson(_m(j['kpis'])),
        tabCounts: _m(j['tabCounts']).map((k, v) => MapEntry(k, _i(v))),
        items: _l(j['items']).map(ApprovalRow.fromJson).toList(),
        total: _i(j['total']),
        page: _i(j['page']) == 0 ? 1 : _i(j['page']),
        pageSize: _i(j['pageSize']) == 0 ? 10 : _i(j['pageSize']),
        review: ReviewQueue.fromJson(_m(j['review'])),
      );
}

// ── meetings ──────────────────────────────────────────────────────────────────

class Attendee {
  const Attendee({this.memberId, this.name = ''});
  final String? memberId;
  final String name;
  factory Attendee.fromJson(Map<String, dynamic> j) => Attendee(memberId: _sn(j['memberId']), name: _s(j['name']));
}

class ActionItemRow {
  const ActionItemRow({this.id, required this.text, this.ownerId, this.owner = '', this.due, this.done = false, this.followUpId});
  final String? id, ownerId, due, followUpId;
  final String text, owner;
  final bool done;
  factory ActionItemRow.fromJson(Map<String, dynamic> j) => ActionItemRow(id: _sn(j['id']), text: _s(j['text']), ownerId: _sn(j['ownerId']), owner: _s(j['owner']), due: _sn(j['due']), done: j['done'] == true, followUpId: _sn(j['followUpId']));
}

/// A meeting: the list row, and — when it was read one by one — its agenda, attendees, notes and action items.
class MeetingRow {
  const MeetingRow({
    required this.id, required this.title, this.startAt, this.endAt, this.day = '', this.time = '', this.endTime = '', this.location = '', this.link = '', this.status = 'upcoming', this.state = 'upcoming',
    this.departments = const [], this.brand = 'main', this.agendaCount = 0, this.attendeeCount = 0, this.openActions = 0, this.canEdit = false, this.canDelete = false,
    this.agenda = const [], this.notes = '', this.attendees = const [], this.actionItems = const [], this.completedAt,
  });
  final String id, title, day, time, endTime, location, link, status, state, brand, notes;
  final DateTime? startAt, endAt, completedAt;
  final List<String> departments, agenda;
  final int agendaCount, attendeeCount, openActions;
  final bool canEdit, canDelete;
  final List<Attendee> attendees;
  final List<ActionItemRow> actionItems;

  String get timeRange => endTime.isEmpty ? time : '$time – $endTime';

  factory MeetingRow.fromJson(Map<String, dynamic> j) => MeetingRow(
        id: _s(j['id']),
        title: _s(j['title']),
        startAt: _dt(j['startAt']),
        endAt: _dt(j['endAt']),
        day: _s(j['day']),
        time: _s(j['time']),
        endTime: _s(j['endTime']),
        location: _s(j['location']),
        link: _s(j['link']),
        status: _s(j['status']).isEmpty ? 'upcoming' : _s(j['status']),
        state: _s(j['state']).isEmpty ? 'upcoming' : _s(j['state']),
        departments: _ls(j['departments']),
        brand: _s(j['brand']).isEmpty ? 'main' : _s(j['brand']),
        agendaCount: _i(j['agendaCount']),
        attendeeCount: _i(j['attendeeCount']),
        openActions: _i(j['openActions']),
        canEdit: j['canEdit'] == true,
        canDelete: j['canDelete'] == true,
        agenda: _ls(j['agenda']),
        notes: _s(j['notes']),
        attendees: _l(j['attendees']).map(Attendee.fromJson).toList(),
        actionItems: _l(j['actionItems']).map(ActionItemRow.fromJson).toList(),
        completedAt: _dt(j['completedAt']),
      );
}

class MeetingKpis {
  const MeetingKpis({this.total = 0, this.thisWeek = 0, this.completed = 0, this.upcoming = 0, this.toClose = 0});
  final int total, thisWeek, completed, upcoming, toClose;
  factory MeetingKpis.fromJson(Map<String, dynamic> j) => MeetingKpis(total: _i(j['total']), thisWeek: _i(j['thisWeek']), completed: _i(j['completed']), upcoming: _i(j['upcoming']), toClose: _i(j['toClose']));
}

class MeetingList {
  const MeetingList({this.kpis = const MeetingKpis(), this.items = const [], this.total = 0});
  final MeetingKpis kpis;
  final List<MeetingRow> items;
  final int total;
  factory MeetingList.fromJson(Map<String, dynamic> j) => MeetingList(kpis: MeetingKpis.fromJson(_m(j['kpis'])), items: _l(j['items']).map(MeetingRow.fromJson).toList(), total: _i(j['total']));
}

// ── follow-ups ────────────────────────────────────────────────────────────────

class FollowUpRow {
  const FollowUpRow({
    required this.id, required this.item, this.relatedTo = '', this.ownerId, this.owner = '', this.department = 'Marketing', this.dueDate = '', this.status = 'open', this.state = 'upcoming', this.daysAgo = 0,
    this.reminder = false, this.meetingId, this.brand = 'main', this.doneAt, this.canEdit = false, this.canDelete = false,
  });
  final String id, item, relatedTo, owner, department, dueDate, status, state, brand;
  final String? ownerId, meetingId;
  final int daysAgo;
  final bool reminder, canEdit, canDelete;
  final DateTime? doneAt;
  bool get done => status == 'done';
  factory FollowUpRow.fromJson(Map<String, dynamic> j) => FollowUpRow(
        id: _s(j['id']),
        item: _s(j['item']),
        relatedTo: _s(j['relatedTo']),
        ownerId: _sn(j['ownerId']),
        owner: _s(j['owner']),
        department: _s(j['department']).isEmpty ? 'Marketing' : _s(j['department']),
        dueDate: _s(j['dueDate']),
        status: _s(j['status']).isEmpty ? 'open' : _s(j['status']),
        state: _s(j['state']).isEmpty ? 'upcoming' : _s(j['state']),
        daysAgo: _i(j['daysAgo']),
        reminder: j['reminder'] == true,
        meetingId: _sn(j['meetingId']),
        brand: _s(j['brand']).isEmpty ? 'main' : _s(j['brand']),
        doneAt: _dt(j['doneAt']),
        canEdit: j['canEdit'] == true,
        canDelete: j['canDelete'] == true,
      );
}

class FollowUpKpis {
  const FollowUpKpis({this.total = 0, this.dueToday = 0, this.upcoming = 0, this.overdue = 0, this.completed = 0});
  final int total, dueToday, upcoming, overdue, completed;
  factory FollowUpKpis.fromJson(Map<String, dynamic> j) => FollowUpKpis(total: _i(j['total']), dueToday: _i(j['dueToday']), upcoming: _i(j['upcoming']), overdue: _i(j['overdue']), completed: _i(j['completed']));
}

class FollowUpList {
  const FollowUpList({this.kpis = const FollowUpKpis(), this.items = const [], this.total = 0, this.page = 1, this.pageSize = 10, this.overdueTotal = 0, this.overdue = const []});
  final FollowUpKpis kpis;
  final List<FollowUpRow> items, overdue;
  final int total, page, pageSize, overdueTotal;
  factory FollowUpList.fromJson(Map<String, dynamic> j) => FollowUpList(
        kpis: FollowUpKpis.fromJson(_m(j['kpis'])),
        items: _l(j['items']).map(FollowUpRow.fromJson).toList(),
        total: _i(j['total']),
        page: _i(j['page']) == 0 ? 1 : _i(j['page']),
        pageSize: _i(j['pageSize']) == 0 ? 10 : _i(j['pageSize']),
        overdueTotal: _i(_m(j['overdue'])['total']),
        overdue: _l(_m(j['overdue'])['items']).map(FollowUpRow.fromJson).toList(),
      );
}

class CalendarDay {
  const CalendarDay({required this.day, this.total = 0, this.open = 0, this.done = 0, this.overdue = 0});
  final String day;
  final int total, open, done, overdue;
  factory CalendarDay.fromJson(Map<String, dynamic> j) => CalendarDay(day: _s(j['day']), total: _i(j['total']), open: _i(j['open']), done: _i(j['done']), overdue: _i(j['overdue']));
}

class FollowUpCalendar {
  const FollowUpCalendar({this.month = '', this.days = const []});
  final String month;
  final List<CalendarDay> days;
  factory FollowUpCalendar.fromJson(Map<String, dynamic> j) => FollowUpCalendar(month: _s(j['month']), days: _l(j['days']).map(CalendarDay.fromJson).toList());
  CalendarDay? on(String day) => days.where((d) => d.day == day).firstOrNull;
}

// ── setup, export, queries ────────────────────────────────────────────────────

class CoordMember {
  const CoordMember({required this.id, required this.name, this.role = ''});
  final String id, name, role;
}

/// What the forms need: the teams, the marketing team, who is asking, and the requests waiting for an approval.
class CoordSetup {
  const CoordSetup({this.departments = kCoordDepartments, this.members = const [], this.waitingRequests = const [], this.meId, this.meName = '', this.isManager = false});
  final List<String> departments;
  final List<CoordMember> members;
  final List<({String id, String title})> waitingRequests;
  final String? meId;
  final String meName;
  final bool isManager;
  factory CoordSetup.fromJson(Map<String, dynamic> j) {
    final me = _m(j['me']);
    final depts = _ls(j['departments']);
    return CoordSetup(
      departments: depts.isEmpty ? kCoordDepartments : depts,
      members: _l(j['members']).map((m) => CoordMember(id: _s(m['id']), name: _s(m['name']), role: _s(m['role']))).toList(),
      waitingRequests: _l(j['waitingRequests']).map((r) => (id: _s(r['id']), title: _s(r['title']))).toList(),
      meId: _sn(me['memberId']),
      meName: _s(me['name']),
      isManager: me['isManager'] == true,
    );
  }
}

class CoordExport {
  const CoordExport({this.title = '', this.columns = const [], this.rows = const []});
  final String title;
  final List<String> columns;
  final List<List<Object?>> rows;
  factory CoordExport.fromJson(Map<String, dynamic> j) => CoordExport(
        title: _s(j['title']),
        columns: _ls(j['columns']),
        rows: ((j['rows'] as List?) ?? const []).whereType<List>().map((r) => r.map<Object?>((c) => c).toList()).toList(),
      );
}

/// How the Overview is cut: the department split's grouping and the upcoming card's period.
class OverviewOptions {
  const OverviewOptions({this.by = 'both', this.upcoming = 'week'});
  final String by, upcoming;
  OverviewOptions copyWith({String? by, String? upcoming}) => OverviewOptions(by: by ?? this.by, upcoming: upcoming ?? this.upcoming);
  @override
  bool operator ==(Object other) => other is OverviewOptions && other.by == by && other.upcoming == upcoming;
  @override
  int get hashCode => Object.hash(by, upcoming);
}

/// How the request table is cut: tab, status, priority, search, page.
class RequestQuery {
  const RequestQuery({this.scope = 'my', this.status = 'all', this.priority = 'all', this.q = '', this.page = 1});
  final String scope, status, priority, q;
  final int page;
  RequestQuery copyWith({String? scope, String? status, String? priority, String? q, int? page}) => RequestQuery(scope: scope ?? this.scope, status: status ?? this.status, priority: priority ?? this.priority, q: q ?? this.q, page: page ?? this.page);
  @override
  bool operator ==(Object other) => other is RequestQuery && other.scope == scope && other.status == status && other.priority == priority && other.q == q && other.page == page;
  @override
  int get hashCode => Object.hash(scope, status, priority, q, page);
}

class ApprovalQuery {
  const ApprovalQuery({this.status = 'pending', this.q = '', this.page = 1});
  final String status, q;
  final int page;
  ApprovalQuery copyWith({String? status, String? q, int? page}) => ApprovalQuery(status: status ?? this.status, q: q ?? this.q, page: page ?? this.page);
  @override
  bool operator ==(Object other) => other is ApprovalQuery && other.status == status && other.q == q && other.page == page;
  @override
  int get hashCode => Object.hash(status, q, page);
}

class MeetingQuery {
  const MeetingQuery({this.status = 'all', this.q = ''});
  final String status, q;
  @override
  bool operator ==(Object other) => other is MeetingQuery && other.status == status && other.q == q;
  @override
  int get hashCode => Object.hash(status, q);
}

class FollowUpQuery {
  const FollowUpQuery({this.status = 'all', this.ownerId, this.q = '', this.page = 1});
  final String status, q;
  final String? ownerId;
  final int page;
  FollowUpQuery copyWith({String? status, String? ownerId, bool clearOwner = false, String? q, int? page}) =>
      FollowUpQuery(status: status ?? this.status, ownerId: clearOwner ? null : (ownerId ?? this.ownerId), q: q ?? this.q, page: page ?? this.page);
  @override
  bool operator ==(Object other) => other is FollowUpQuery && other.status == status && other.ownerId == ownerId && other.q == q && other.page == page;
  @override
  int get hashCode => Object.hash(status, ownerId, q, page);
}
