import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:nizan_crm/core/theme/app_theme.dart';
import 'package:nizan_crm/features/marketing/data/coordination_models.dart';
import 'package:nizan_crm/features/marketing/data/team_models.dart';
import 'package:nizan_crm/features/marketing/presentation/coordinations/coord_widgets.dart';
import 'package:nizan_crm/features/marketing/presentation/coordinations/coordinations_screen.dart';
import 'package:nizan_crm/features/marketing/services/coordination_service.dart';
import 'package:nizan_crm/features/marketing/services/team_service.dart';

// Coordinations: Overview, Requests & Tasks, Inter-Department, Approvals, Meetings, Follow-ups — payloads, every tab's numbers and rows,
// every filter, every form, the refusals, the service's requests and a phone-width pass. Days are built from "today" so the run does not
// depend on the date it is run.

String _d(int n) => TeamFilter.day(DateTime.now().add(Duration(days: n)));
final _created = DateTime.now().subtract(const Duration(minutes: 32)).toUtc().toIso8601String();

Map<String, dynamic> _req(String id, {String title = 'Edit bridal campaign v2', String kind = 'request', String from = 'Marketing', String to = 'Production', String status = 'in_progress', String priority = 'high', String? due, String assignee = 'Abhiram', String requestedBy = 'Preethi', int progress = 40, bool canEdit = true, bool canDelete = true, List<String>? moveTo, List<String>? next, bool overdue = false, String? stage, String? closed}) => {
      'id': id, 'kind': kind, 'title': title, 'detail': 'Three reels', 'fromDept': from, 'toDept': to, 'requestedById': 'm1', 'requestedBy': requestedBy, 'assigneeId': 'm2', 'assignee': assignee, 'priority': priority,
      'dueDate': due ?? _d(1), 'status': status, 'progress': progress, 'brand': 'main', 'stage': stage, 'overdue': overdue, 'onTime': null, 'createdAt': _created, 'closedAt': closed,
      'nextStatuses': next ?? ['in_review', 'completed'], 'moveTo': moveTo ?? ['in_review', 'completed'], 'canEdit': canEdit, 'canDelete': canDelete,
    };

Map<String, dynamic> _approval(String id, {String title = 'Campaign ad budget – Nov', String category = 'Marketing', double amount = 20000, String impact = 'Reach +20%', String status = 'pending', bool canDecide = false, bool canEdit = false, bool canDelete = false, String requestedBy = 'Preethi', String? requestId, String decisionNote = '', String decidedBy = ''}) => {
      'id': id, 'title': title, 'category': category, 'amount': amount, 'impact': impact, 'requestedById': 'm1', 'requestedBy': requestedBy, 'status': status, 'dueDate': _d(5), 'brand': 'main', 'requestId': requestId, 'requestedOn': _d(-1),
      'decidedAt': null, 'decidedBy': decidedBy, 'decisionNote': decisionNote, 'overdue': false, 'canDecide': canDecide, 'canEdit': canEdit, 'canDelete': canDelete,
    };

Map<String, dynamic> _review(String id, {String type = 'content', String title = 'Bridal reel', String link = '/marketing/socials?tab=publishing', String brand = 'main'}) => {'type': type, 'id': id, 'title': title, 'brand': brand, 'label': type == 'asset' ? 'reel' : 'instagram · reel', 'thumbUrl': '', 'day': _d(1), 'link': link};

Map<String, dynamic> _overview() => {
      'today': _d(0),
      'kpis': {'total': 15, 'requests': 9, 'approvals': 6, 'completed': 4, 'inProgress': 2, 'pending': 4, 'pendingApprovals': 4, 'overdue': 2, 'onTimeRate': 67, 'onTimeOf': 3},
      'change': {'total': 400, 'completed': 100},
      'tabCounts': {'my': 2, 'team': 7, 'all': 9},
      'tasks': {
        'my': [_req('r1'), _req('r2', title: 'Studio tour reel publishing', status: 'open', priority: 'medium', from: 'Production', to: 'Socials')],
        'team': [_req('r1'), _req('r3', title: 'Provide artist availability', status: 'completed', canEdit: false, canDelete: false)],
        'all': [_req('r1'), _req('r3', title: 'Provide artist availability', status: 'completed', canEdit: false, canDelete: false), _req('r4', title: 'Send product details & pricing', status: 'open')],
      },
      'byDepartment': {'by': 'both', 'total': 9, 'rows': [{'label': 'Marketing', 'count': 7, 'pct': 39}, {'label': 'Production', 'count': 5, 'pct': 28}, {'label': 'Socials', 'count': 4, 'pct': 22}, {'label': 'Sales', 'count': 2, 'pct': 11}]},
      'recent': [_req('r9', title: 'Need raw footage from the shoot', from: 'Production', to: 'Socials', status: 'in_progress'), _req('r10', title: 'Confirm studio slot', status: 'completed')],
      'interDepartment': [_req('h1', kind: 'handover', title: 'Content handover & posting schedule', from: 'Production', to: 'Socials', progress: 100, status: 'completed'), _req('h2', kind: 'handover', title: 'Campaign assets & lead integration', from: 'Marketing', to: 'Sales', progress: 75, status: 'in_review')],
      'approvalsPending': {
        'approvals': [_approval('a1', canDecide: true, canEdit: true), _approval('a2', title: 'Equipment purchase (SD Card)', category: 'Production', amount: 8500, status: 'in_review')],
        'approvalCount': 4,
        'review': {'total': 3, 'content': 2, 'assets': 1, 'items': [_review('c1'), _review('as1', type: 'asset', title: 'Final cut – bridal', link: '/marketing/portfolio?tab=gallery')]},
      },
      'upcoming': {'period': 'week', 'items': [
        {'type': 'meeting', 'id': 'mt1', 'title': 'Content sync', 'day': _d(0), 'time': '11:00', 'endTime': '12:00', 'subtitle': 'Marketing, Socials', 'location': ''},
        {'type': 'request', 'id': 'r2', 'title': 'Studio tour reel publishing', 'day': _d(1), 'time': '', 'endTime': '', 'subtitle': 'Production → Socials', 'location': ''},
      ]},
      'keyUpdates': [{'tone': 'info', 'text': '4 of 15 items completed (27%).'}, {'tone': 'bad', 'text': '2 items overdue.'}, {'tone': 'warn', 'text': '1 escalated approval needs attention.'}],
    };

Map<String, dynamic> _requests() => {
      'kpis': {'total': 9, 'requests': 9, 'approvals': 0, 'completed': 3, 'inProgress': 2, 'pending': 4, 'pendingApprovals': 0, 'overdue': 1, 'onTimeRate': 50, 'onTimeOf': 2},
      'tabCounts': {'my': 2, 'team': 7, 'all': 9},
      'total': 23, 'page': 1, 'pageSize': 10,
      'items': [
        _req('r1', overdue: true, due: _d(-1)),
        _req('r2', title: 'Studio tour reel publishing', status: 'open', priority: 'medium', from: 'Production', to: 'Socials', requestedBy: 'Abhiram', due: _d(0)),
        _req('r3', title: 'Provide artist availability', status: 'completed', canEdit: false, canDelete: false, priority: 'low', next: ['in_progress'], moveTo: ['in_progress']),
        _req('h2', kind: 'handover', title: 'Campaign assets & lead integration', from: 'Marketing', to: 'Sales', status: 'in_review'),
      ],
    };

Map<String, dynamic> _board() => {
      'kpis': {'active': 3, 'awaitingAction': 1, 'inReview': 1, 'overdue': 1, 'completed': 2},
      'stages': [
        {'key': 'requested', 'label': 'Requested', 'count': 1, 'items': [_req('h1', kind: 'handover', title: 'Campaign leads', from: 'Marketing', to: 'Sales', status: 'open', progress: 0, moveTo: ['in_progress', 'completed'], stage: 'requested')]},
        {'key': 'in_progress', 'label': 'In Progress', 'count': 1, 'items': [_req('h2', kind: 'handover', title: 'Shoot footage', from: 'Production', to: 'Socials', progress: 60, moveTo: ['in_review', 'completed'], stage: 'in_progress', overdue: true, due: _d(-2))]},
        {'key': 'in_review', 'label': 'In Review', 'count': 1, 'items': [_req('h3', kind: 'handover', title: 'Campaign plan', from: 'Marketing', to: 'Production', status: 'in_review', progress: 80, moveTo: ['in_progress', 'completed'], stage: 'in_review', canEdit: false)]},
        {'key': 'completed', 'label': 'Completed', 'count': 1, 'items': [_req('h4', kind: 'handover', title: 'Event coverage assets', from: 'Production', to: 'Marketing', status: 'completed', progress: 100, moveTo: ['in_progress'], stage: 'completed', closed: DateTime.now().toUtc().toIso8601String())]},
      ],
    };

Map<String, dynamic> _approvals({bool manager = true}) => {
      'kpis': {'total': 6, 'pending': 2, 'inReview': 1, 'escalated': 1, 'approved': 1, 'rejected': 1, 'awaitingAmount': 80500},
      'tabCounts': {'pending': 2, 'in_review': 2, 'approved': 1, 'rejected': 1},
      'total': 14, 'page': 1, 'pageSize': 10,
      'items': [
        _approval('a1', canDecide: manager, canEdit: true, canDelete: true),
        _approval('a2', title: 'Equipment purchase (SD Card)', category: 'Production', amount: 8500, impact: '', canDecide: manager, requestedBy: 'Jithya'),
        _approval('a3', title: 'Brand shoot location booking', category: 'Production', amount: 12000, status: 'approved', decisionNote: 'Go ahead', decidedBy: 'Meera'),
      ],
      'review': {'total': 2, 'content': 1, 'assets': 1, 'items': [_review('c1'), _review('as1', type: 'asset', title: 'Final cut – bridal', link: '/marketing/portfolio?tab=gallery')]},
    };

Map<String, dynamic> _mtRow(String id, {String title = 'Marketing Sync', String state = 'upcoming', String status = 'upcoming', String time = '11:00', String endTime = '12:00', int? day, bool canEdit = true}) => {
      'id': id, 'title': title, 'startAt': DateTime.now().toUtc().toIso8601String(), 'endAt': DateTime.now().toUtc().toIso8601String(), 'day': _d(day ?? 0), 'time': time, 'endTime': endTime, 'location': 'Conference Room', 'link': 'https://meet.google.com/abc',
      'status': status, 'state': state, 'departments': ['Marketing', 'Socials'], 'brand': 'main', 'agendaCount': 2, 'attendeeCount': 3, 'openActions': 1, 'canEdit': canEdit, 'canDelete': canEdit,
    };

Map<String, dynamic> _mtDetail(String id, {String title = 'Marketing Sync', String state = 'upcoming', String status = 'upcoming', bool canEdit = true, bool withItems = true}) => {
      ..._mtRow(id, title: title, state: state, status: status, canEdit: canEdit),
      'agenda': ['Campaign performance review', 'Upcoming creatives and content pipeline'],
      'notes': status == 'completed' ? 'Agreed the festive pipeline.' : '',
      'attendees': [{'memberId': 'm1', 'name': 'Ashique'}, {'memberId': 'm2', 'name': 'Abhiram'}, {'memberId': null, 'name': 'Client rep'}],
      'actionItems': withItems
          ? [
              {'id': 'i1', 'text': 'Send the revised plan', 'ownerId': 'm1', 'owner': 'Ashique', 'due': _d(3), 'done': false, 'followUpId': null},
              {'id': 'i2', 'text': 'Book the studio', 'ownerId': null, 'owner': 'Vendor', 'due': null, 'done': false, 'followUpId': null},
              {'id': 'i3', 'text': 'Share the numbers', 'ownerId': 'm2', 'owner': 'Abhiram', 'due': _d(1), 'done': false, 'followUpId': 'f9'},
            ]
          : [],
    };

Map<String, dynamic> _meetings() => {
      'kpis': {'total': 8, 'thisWeek': 3, 'completed': 5, 'upcoming': 2, 'toClose': 1},
      'total': 3,
      'items': [_mtRow('mt1'), _mtRow('mt2', title: 'Campaign Review – SkyCity', state: 'to_close', time: '15:00', endTime: '16:00', day: -1), _mtRow('mt3', title: 'Production Planning', state: 'completed', status: 'completed', day: 2)],
    };

Map<String, dynamic> _fu(String id, {String item = 'Get final content approval', String state = 'due_today', String status = 'open', String dept = 'Marketing', int? due, int daysAgo = 0, bool reminder = true, bool canEdit = true, String owner = 'Preethi', String related = 'Bridal Campaign'}) => {
      'id': id, 'item': item, 'relatedTo': related, 'ownerId': 'm1', 'owner': owner, 'department': dept, 'dueDate': _d(due ?? 0), 'status': status, 'state': state, 'daysAgo': daysAgo, 'reminder': reminder, 'meetingId': null, 'brand': 'main', 'doneAt': null, 'canEdit': canEdit, 'canDelete': canEdit,
    };

Map<String, dynamic> _followUps() => {
      'kpis': {'total': 36, 'dueToday': 12, 'upcoming': 14, 'overdue': 8, 'completed': 20},
      'total': 25, 'page': 1, 'pageSize': 10,
      'items': [
        _fu('f1'),
        _fu('f2', item: 'Share revised video (v2)', related: 'Studio Shoot', owner: 'Abhiram', dept: 'Production', state: 'upcoming', due: 1, reminder: false),
        _fu('f3', item: 'Collect campaign leads report', state: 'overdue', due: -3, daysAgo: 3, dept: 'Sales', owner: 'Jithya', canEdit: false),
        _fu('f4', item: 'Send moodboard', state: 'completed', status: 'done', due: -2),
      ],
      'overdue': {'total': 8, 'items': [_fu('f3', item: 'Collect campaign leads report', state: 'overdue', due: -3, daysAgo: 3), _fu('f5', item: 'Chase the print vendor', state: 'overdue', due: -1, daysAgo: 1)]},
    };

Map<String, dynamic> _calendar() => {
      'month': TeamFilter.day(DateTime.now()).substring(0, 7),
      'days': [
        {'day': _d(0), 'total': 1, 'open': 1, 'done': 0, 'overdue': 0},
      ],
    };

class _FakeCoord extends MarketingCoordinationService {
  _FakeCoord({this.manager = true}) : super(Dio());
  final bool manager;
  final overviews = <({TeamFilter f, String dept, OverviewOptions o})>[];
  final requestQueries = <({TeamFilter f, String dept, RequestQuery q})>[];
  final boards = <({TeamFilter f, String dept})>[];
  final approvalQueries = <ApprovalQuery>[];
  final meetingQueries = <MeetingQuery>[];
  final followUpQueries = <FollowUpQuery>[];
  final calendars = <({String month, String? ownerId})>[];
  final exports = <({String type, Map<String, dynamic>? extra})>[];
  final savedRequests = <({Map<String, dynamic> body, String? id})>[];
  final moves = <({String id, String stage})>[];
  final deletedRequests = <String>[];
  final savedApprovals = <({Map<String, dynamic> body, String? id})>[];
  final decisions = <({String id, String decision, String note})>[];
  final deletedApprovals = <String>[];
  final savedMeetings = <({Map<String, dynamic> body, String? id})>[];
  final deletedMeetings = <String>[];
  final conversions = <({String meetingId, String itemId})>[];
  final savedFollowUps = <({Map<String, dynamic> body, String? id})>[];
  final deletedFollowUps = <String>[];
  TeamRefusal? refuse;
  bool overviewFails = false;
  Map<String, dynamic> overviewJson = _overview();
  Map<String, dynamic>? requestsJson, boardJson, approvalsJson, meetingsJson, followUpsJson;
  final details = <String, Map<String, dynamic>>{};

  @override
  Future<CoordSetup> setup() async => CoordSetup.fromJson({
        'departments': kCoordDepartments,
        'members': [{'id': 'm1', 'name': 'Ashique', 'role': 'Video Editor'}, {'id': 'm2', 'name': 'Abhiram', 'role': 'Videographer'}],
        'waitingRequests': [{'id': 'q1', 'title': 'Waiting for the budget'}],
        'me': {'memberId': 'm1', 'name': 'Ashique', 'isManager': manager},
      });

  @override
  Future<CoordOverview> overview(TeamFilter f, String dept, OverviewOptions o) async {
    overviews.add((f: f, dept: dept, o: o));
    if (overviewFails) throw Exception('boom');
    return CoordOverview.fromJson(overviewJson);
  }

  @override
  Future<RequestList> requests(TeamFilter f, String dept, RequestQuery q) async {
    requestQueries.add((f: f, dept: dept, q: q));
    return RequestList.fromJson(requestsJson ?? _requests());
  }

  @override
  Future<HandoverBoard> board(TeamFilter f, String dept) async {
    boards.add((f: f, dept: dept));
    return HandoverBoard.fromJson(boardJson ?? _board());
  }

  @override
  Future<ApprovalList> approvals(TeamFilter f, String dept, ApprovalQuery q) async {
    approvalQueries.add(q);
    return ApprovalList.fromJson(approvalsJson ?? _approvals(manager: manager));
  }

  @override
  Future<MeetingList> meetings(TeamFilter f, String dept, MeetingQuery q) async {
    meetingQueries.add(q);
    return MeetingList.fromJson(meetingsJson ?? _meetings());
  }

  @override
  Future<MeetingRow> meeting(String id) async => MeetingRow.fromJson(details[id] ?? _mtDetail(id, state: id == 'mt2' ? 'to_close' : (id == 'mt3' ? 'completed' : 'upcoming'), status: id == 'mt3' ? 'completed' : 'upcoming', title: id == 'mt2' ? 'Campaign Review – SkyCity' : (id == 'mt3' ? 'Production Planning' : 'Marketing Sync')));

  @override
  Future<FollowUpList> followUps(TeamFilter f, String dept, FollowUpQuery q) async {
    followUpQueries.add(q);
    return FollowUpList.fromJson(followUpsJson ?? _followUps());
  }

  @override
  Future<FollowUpCalendar> followUpCalendar(TeamFilter f, String dept, String month, {String? ownerId}) async {
    calendars.add((month: month, ownerId: ownerId));
    return FollowUpCalendar.fromJson({..._calendar(), 'month': month});
  }

  @override
  Future<CoordExport> export(String type, TeamFilter f, String dept, {Map<String, dynamic>? extra}) async {
    exports.add((type: type, extra: extra));
    return const CoordExport(title: 'x', columns: ['A'], rows: [['1']]);
  }

  void _maybeRefuse() {
    if (refuse != null) throw refuse!;
  }

  @override
  Future<CoordRequestRow> saveRequest(Map<String, dynamic> body, {String? id}) async {
    _maybeRefuse();
    savedRequests.add((body: body, id: id));
    return CoordRequestRow.fromJson(_req(id ?? 'new'));
  }

  @override
  Future<CoordRequestRow> moveRequest(String id, String stage) async {
    _maybeRefuse();
    moves.add((id: id, stage: stage));
    return CoordRequestRow.fromJson(_req(id));
  }

  @override
  Future<void> deleteRequest(String id) async {
    _maybeRefuse();
    deletedRequests.add(id);
  }

  @override
  Future<ApprovalRow> saveApproval(Map<String, dynamic> body, {String? id}) async {
    _maybeRefuse();
    savedApprovals.add((body: body, id: id));
    return ApprovalRow.fromJson(_approval(id ?? 'new'));
  }

  @override
  Future<ApprovalRow> decideApproval(String id, String decision, {String note = ''}) async {
    _maybeRefuse();
    decisions.add((id: id, decision: decision, note: note));
    return ApprovalRow.fromJson(_approval(id));
  }

  @override
  Future<void> deleteApproval(String id) async {
    _maybeRefuse();
    deletedApprovals.add(id);
  }

  @override
  Future<MeetingRow> saveMeeting(Map<String, dynamic> body, {String? id}) async {
    _maybeRefuse();
    savedMeetings.add((body: body, id: id));
    return MeetingRow.fromJson(_mtDetail(id ?? 'new'));
  }

  @override
  Future<void> deleteMeeting(String id) async {
    _maybeRefuse();
    deletedMeetings.add(id);
  }

  @override
  Future<FollowUpRow> actionItemToFollowUp(String meetingId, String itemId) async {
    _maybeRefuse();
    conversions.add((meetingId: meetingId, itemId: itemId));
    return FollowUpRow.fromJson(_fu('fx'));
  }

  @override
  Future<FollowUpRow> saveFollowUp(Map<String, dynamic> body, {String? id}) async {
    _maybeRefuse();
    savedFollowUps.add((body: body, id: id));
    return FollowUpRow.fromJson(_fu(id ?? 'new'));
  }

  @override
  Future<void> deleteFollowUp(String id) async {
    _maybeRefuse();
    deletedFollowUps.add(id);
  }
}

class _NoTeam extends MarketingTeamService {
  _NoTeam() : super(Dio());
  @override
  Future<LogSetup> logSetup({required String date, String? memberId}) async => throw Exception('no team in this test');
}

/// The Team Dashboard's service, recording the task changes the Coordinations table sends to it.
class _TeamTasks extends _NoTeam {
  final saved = <({Map<String, dynamic> body, String? id})>[];
  @override
  Future<TeamTask> saveTask(Map<String, dynamic> body, {String? id}) async {
    saved.add((body: body, id: id));
    return TeamTask.fromJson({'id': id ?? 'new', 'title': 'x', 'status': body['status']});
  }
}

Map<String, dynamic> _teamTaskRow(String id, {String status = 'waiting_input', String taskStatus = 'blocked'}) => {
      ..._req(id, title: 'Cut the expo teaser', from: 'Marketing', to: 'Marketing', status: status, requestedBy: 'Meera', canDelete: false, next: const [], moveTo: const []),
      'kind': 'task',
      'taskStatus': taskStatus,
      'taskStatuses': ['not_started', 'in_progress', 'pending', 'completed'],
      'link': '/marketing/team?tab=tasks',
    };

class _Capture implements HttpClientAdapter {
  _Capture(this.seen, {this.status = 200, this.body = '{}'});
  final List<RequestOptions> seen;
  final int status;
  final String body;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<List<int>>? requestStream, Future<void>? cancelFuture) async {
    seen.add(options);
    return ResponseBody.fromString(body, status, headers: {Headers.contentTypeHeader: ['application/json']});
  }

  @override
  void close({bool force = false}) {}
}

Future<_FakeCoord> _pump(WidgetTester tester, {String tab = 'overview', _FakeCoord? fake, Size size = const Size(1280, 3200), MarketingTeamService? team}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final f = fake ?? _FakeCoord();
  final overrides = <Override>[marketingCoordinationServiceProvider.overrideWithValue(f), marketingTeamServiceProvider.overrideWithValue(team ?? _NoTeam())];
  await tester.pumpWidget(ProviderScope(overrides: overrides, child: MaterialApp(theme: AppTheme.lightTheme, home: Scaffold(body: CoordinationsScreen(initialTab: tab)))));
  await tester.pumpAndSettle();
  return f;
}

Finder _k(String key) => find.byKey(Key(key));
Finder _in(String key, String text) => find.descendant(of: _k(key), matching: find.text(text));
ProviderContainer _container(WidgetTester t) => ProviderScope.containerOf(t.element(find.byType(CoordinationsScreen)));
Future<void> _tap(WidgetTester t, Finder f) async {
  await t.ensureVisible(f);
  await t.pump(); // the scroll lands on the next frame
  await t.tap(f);
  await t.pumpAndSettle();
}

Future<void> _pickMenu(WidgetTester t, String pillKey, String label) async {
  await t.ensureVisible(_k(pillKey));
  await t.tap(_k(pillKey));
  await t.pumpAndSettle();
  await t.tap(find.text(label).last);
  await t.pumpAndSettle();
}

void main() {
  group('how the payloads read', () {
    test('a request row reads its teams, people, status and what the person may do; a missing part is empty, never a crash', () {
      final r = CoordRequestRow.fromJson(_req('r1', overdue: true));
      expect([r.id, r.kind, r.fromDept, r.toDept, r.requestedBy, r.assignee, r.priority, r.status, r.progress], ['r1', 'request', 'Marketing', 'Production', 'Preethi', 'Abhiram', 'high', 'in_progress', 40]);
      expect([r.overdue, r.canEdit, r.canDelete, r.isHandover], [true, true, true, false]);
      expect(r.nextStatuses, ['in_review', 'completed']);
      expect(r.createdAt, isNotNull);
      final empty = CoordRequestRow.fromJson(const {'id': 'x', 'title': 'x'});
      expect([empty.kind, empty.status, empty.priority, empty.brand, empty.progress, empty.canEdit, empty.dueDate, empty.onTime], ['request', 'open', 'medium', 'main', 0, false, null, null]);
      expect(empty.nextStatuses, isEmpty);
      expect(CoordRequestRow.fromJson(const {'id': 'h', 'title': 'h', 'kind': 'handover'}).isHandover, isTrue);
    });

    test('the overview reads the figures, the three task lists, the split, approvals and review, upcoming and the updates; nothing at all is an empty overview', () {
      final o = CoordOverview.fromJson(_overview());
      expect([o.kpis.total, o.kpis.requests, o.kpis.approvals, o.kpis.completed, o.kpis.inProgress, o.kpis.pending, o.kpis.pendingApprovals, o.kpis.overdue, o.kpis.onTimeRate, o.kpis.onTimeOf], [15, 9, 6, 4, 2, 4, 4, 2, 67, 3]);
      expect([o.changeTotal, o.changeCompleted], [400, 100]);
      expect([o.tabCounts.my, o.tabCounts.team, o.tabCounts.all, o.tabCounts.of('team')], [2, 7, 9, 7]);
      expect([o.tasks['my']!.length, o.tasks['team']!.length, o.tasks['all']!.length], [2, 2, 3]);
      expect(o.byDepartment.rows.map((r) => r.label), ['Marketing', 'Production', 'Socials', 'Sales']);
      expect(o.approvalsPending.approvals.length, 2);
      expect([o.approvalsPending.review.total, o.approvalsPending.review.items.last.type, o.approvalsPending.review.items.last.link], [3, 'asset', '/marketing/portfolio?tab=gallery']);
      expect(o.upcoming.map((u) => u.isMeeting), [true, false]);
      expect(o.keyUpdates.map((u) => u.tone), ['info', 'bad', 'warn']);
      final none = CoordOverview.fromJson(const {});
      expect([none.kpis.total, none.kpis.onTimeRate, none.tasks['my'], none.byDepartment.rows, none.upcomingPeriod, none.keyUpdates, none.approvalsPending.review.items], [0, null, isEmpty, isEmpty, 'week', isEmpty, isEmpty]);
    });

    test('approvals, meetings, follow-ups and the board read their parts; a meeting carries its detail when it was read one by one', () {
      final a = ApprovalList.fromJson(_approvals());
      expect([a.kpis.awaitingAmount, a.tabCounts['in_review'], a.items.first.amount, a.items.first.canDecide, a.items.first.awaiting, a.items.last.awaiting, a.review.total], [80500, 2, 20000, true, true, false, 2]);
      final m = MeetingRow.fromJson(_mtDetail('mt1'));
      expect([m.title, m.timeRange, m.agenda.length, m.attendees.length, m.actionItems.length, m.actionItems.first.owner, m.actionItems.last.followUpId, m.attendees.last.memberId], ['Marketing Sync', '11:00 – 12:00', 2, 3, 3, 'Ashique', 'f9', null]);
      expect(MeetingRow.fromJson(_mtRow('x')).agenda, isEmpty, reason: 'a list row has no detail');
      expect(MeetingList.fromJson(_meetings()).kpis.toClose, 1);
      final f = FollowUpList.fromJson(_followUps());
      expect([f.kpis.dueToday, f.items.first.state, f.items.last.done, f.overdueTotal, f.overdue.last.daysAgo], [12, 'due_today', true, 8, 1]);
      final cal = FollowUpCalendar.fromJson(_calendar());
      expect([cal.on(_d(0))?.open, cal.on('1999-01-01')], [1, null]);
      final b = HandoverBoard.fromJson(_board());
      expect([b.kpis.active, b.stages.map((s) => s.key).toList(), b.stages.first.items.first.moveTo], [3, ['requested', 'in_progress', 'in_review', 'completed'], ['in_progress', 'completed']]);
      final s = CoordSetup.fromJson(const {});
      expect([s.departments, s.members, s.isManager, s.meId], [kCoordDepartments, isEmpty, false, null]);
      expect(CoordSetup.fromJson({'me': {'memberId': 'm1', 'isManager': true}, 'waitingRequests': [{'id': 'q', 'title': 'T'}]}).waitingRequests.single.title, 'T');
      expect(CoordExport.fromJson(const {'columns': ['A'], 'rows': [[1, 'x']]}).rows.single, [1, 'x']);
    });

    test('the ten teams and the labels are the server\'s', () {
      expect(kCoordDepartments, ['Production', 'Socials', 'Marketing', 'Sales', 'Operations', 'HR', 'Finance', 'IT', 'Design', 'Others']);
      expect(kApprovalCategories, [...kCoordDepartments, 'Brand']);
      expect(kRequestStatuses.map((s) => s.$1), ['open', 'in_progress', 'waiting_input', 'in_review', 'pending_approval', 'completed', 'cancelled']);
      expect([requestStatusLabel('waiting_input'), requestStatusLabel('weird'), priorityLabel('high'), stageLabel('in_review'), approvalStatusLabel('escalated')], ['Waiting Input', 'weird', 'High', 'In Review', 'Escalated']);
      expect(kMeetingStateLabels['to_close'], 'Needs notes');
      expect(kFollowUpStateLabels['due_today'], 'Due Today');
    });

    test('query objects compare by their parts', () {
      expect(const RequestQuery(status: 'overdue') == const RequestQuery(status: 'overdue'), isTrue);
      expect(const RequestQuery(scope: 'all') == const RequestQuery(), isFalse);
      expect(const RequestQuery(page: 2) == const RequestQuery(), isFalse);
      expect(const RequestQuery(q: 'a') == const RequestQuery(), isFalse);
      expect(const RequestQuery(priority: 'high') == const RequestQuery(), isFalse);
      expect(const RequestQuery().copyWith(page: 2) == const RequestQuery(page: 2), isTrue);
      expect(const ApprovalQuery(status: 'approved') == const ApprovalQuery(), isFalse);
      expect(const OverviewOptions(by: 'receiving') == const OverviewOptions(), isFalse);
      expect(const MeetingQuery(q: 'a').hashCode == const MeetingQuery(q: 'a').hashCode, isTrue);
      expect(const FollowUpQuery(ownerId: 'm1') == const FollowUpQuery(), isFalse);
      expect(const FollowUpQuery(ownerId: 'm1').copyWith(clearOwner: true).ownerId, isNull);
    });

    test('formatting: money, days, relative time, change notes, IST instants', () {
      expect([inr(20000), inr(1500.5), inr(0), inr(1250000)], ['₹20,000', '₹1,500.50', '₹0', '₹12,50,000']);
      expect([dueLabel(null), dueLabel(''), dueLabel(_d(0)), dueLabel('2026-11-10')], ['—', '—', 'Today', '10 Nov 2026']);
      expect(coordDay('nonsense'), 'nonsense');
      expect(coordDay('2026-11-10', pattern: 'd MMM'), '10 Nov');
      final now = DateTime(2026, 11, 13, 12);
      expect([coordAgo(now.subtract(const Duration(seconds: 20)), now: now), coordAgo(now.subtract(const Duration(minutes: 1)), now: now), coordAgo(now.subtract(const Duration(minutes: 32)), now: now), coordAgo(now.subtract(const Duration(hours: 3)), now: now), coordAgo(now.subtract(const Duration(days: 2)), now: now), coordAgo(null)], ['just now', '1 min ago', '32 mins ago', '3 hrs ago', '2 days ago', '']);
      expect([meetingWhen('2026-11-13', '11:00', now: now), meetingWhen('2026-11-14', '11:00', now: now), meetingWhen('2026-11-20', '', now: now)], ['Today, 11:00', 'Tomorrow, 11:00', '20 Nov']);
      expect(changeNote(33).note, '↑ +33% vs last period');
      expect(changeNote(33).good, isTrue);
      expect(changeNote(-50).note, '↓ −50% vs last period');
      expect(changeNote(-50).good, isFalse);
      expect(changeNote(-50, higherIsGood: false).good, isTrue);
      expect(changeNote(0).good, isNull);
      expect(changeNote(null).note, isNull);
      expect(istInstant(DateTime(2026, 11, 13), const TimeOfDay(hour: 11, minute: 0)), '2026-11-13T05:30:00.000Z');
      expect(istInstant(DateTime(2026, 11, 13), const TimeOfDay(hour: 0, minute: 15)), '2026-11-12T18:45:00.000Z', reason: 'past midnight IST is the evening before in UTC');
      expect(hhmm(const TimeOfDay(hour: 9, minute: 5)), '09:05');
      expect(deptColor('Production') != deptColor('Socials'), isTrue);
    });
  });

  group('the Coordinations screen', () {
    testWidgets('has the six tabs the sidebar links to, the header, the New Request button and the three filters', (tester) async {
      await _pump(tester);
      expect(kCoordinationTabs.map((t) => t.$1).toList(), ['overview', 'requests', 'interdepartment', 'approvals', 'meetings', 'followups']);
      expect(kCoordinationTabs.map((t) => t.$2).toList(), ['Overview', 'Requests & Tasks', 'Inter-Department', 'Approvals', 'Meetings', 'Follow-ups']);
      for (final t in kCoordinationTabs) {
        expect(_k('co_tab_${t.$1}'), findsOneWidget, reason: t.$1);
      }
      expect(find.text('Coordinations'), findsWidgets);
      expect(_k('co_new_request'), findsOneWidget);
      expect(_k('team_filter_quick'), findsOneWidget, reason: 'the shared date range');
      expect(_k('co_dept_pill'), findsOneWidget);
      expect(find.text('All Departments'), findsOneWidget);
      expect(_k('team_brand_pill'), findsOneWidget, reason: 'the brand filter still works');
    });

    testWidgets('a tab can be opened from a link (?tab=…), and from the tab pills', (tester) async {
      final ids = {'requests': 'coord_requests_list', 'interdepartment': 'coord_board_list', 'approvals': 'coord_approvals_list', 'meetings': 'coord_meetings_list', 'followups': 'coord_followups_list'};
      for (final e in ids.entries) {
        await _pump(tester, tab: e.key);
        expect(_k(e.value), findsOneWidget, reason: e.key);
      }
      await _pump(tester, tab: 'nonsense');
      expect(_k('coord_overview_list'), findsOneWidget, reason: 'an unknown tab is the overview');
      await _tap(tester, _k('co_tab_approvals'));
      expect(_k('coord_approvals_list'), findsOneWidget);
    });

    testWidgets('the date range, the department and the brand are one shared choice: every read carries them', (tester) async {
      final f = await _pump(tester);
      expect(f.overviews.last.dept, 'all');
      await _pickMenu(tester, 'co_dept_pill', 'Sales');
      expect(f.overviews.last.dept, 'Sales');
      expect(find.text('Sales'), findsWidgets);
      await _pickMenu(tester, 'team_brand_pill', 'Kerala');
      expect(f.overviews.last.f.brand, TeamBrand.kerala);
      expect(f.overviews.last.dept, 'Sales', reason: 'filters add up');
      await _pickMenu(tester, 'team_filter_quick', 'Today');
      expect(f.overviews.last.f.fromDay, _d(0));
      expect(f.overviews.last.f.toDay, _d(0));
      await _tap(tester, _k('co_tab_requests'));
      expect(f.requestQueries.last.dept, 'Sales', reason: 'the next tab reads the same filters');
      expect(f.requestQueries.last.f.brand, TeamBrand.kerala);
      expect(f.requestQueries.last.f.fromDay, _d(0));
      await _pickMenu(tester, 'co_dept_pill', 'All Departments');
      expect(f.requestQueries.last.dept, 'all');
    });
  });

  group('Overview', () {
    testWidgets('the six figures, with what they are made of and how they moved', (tester) async {
      await _pump(tester);
      expect(_in('co_kpi_total', '15'), findsOneWidget);
      expect(_in('co_kpi_total', '9 requests + 6 approvals'), findsOneWidget, reason: 'approvals count too, and the card says so');
      expect(_in('co_kpi_completed', '4'), findsOneWidget);
      expect(_in('co_kpi_completed', '↑ +100% vs last period'), findsOneWidget);
      expect(tester.widget<Text>(find.descendant(of: _k('co_kpi_completed'), matching: find.text('↑ +100% vs last period'))).style!.color, const Color(0xFF22A06B));
      expect(_in('co_kpi_progress', '2'), findsOneWidget);
      expect(_in('co_kpi_approvals', '4'), findsOneWidget);
      expect(_in('co_kpi_overdue', '2'), findsOneWidget);
      expect(_in('co_kpi_ontime', '67%'), findsOneWidget);
      expect(_in('co_kpi_ontime', 'of 3 with a due date'), findsOneWidget);
    });

    testWidgets('nothing finished with a due date shows a dash, not a fake rate; nothing overdue says so', (tester) async {
      final f = _FakeCoord()..overviewJson = {..._overview(), 'kpis': {'total': 3, 'requests': 3, 'approvals': 0, 'completed': 0, 'inProgress': 1, 'pending': 2, 'pendingApprovals': 0, 'overdue': 0, 'onTimeRate': null, 'onTimeOf': 0}, 'change': {'total': null, 'completed': null}};
      await _pump(tester, fake: f);
      expect(_in('co_kpi_ontime', '—'), findsOneWidget);
      expect(_in('co_kpi_ontime', 'No due dates finished yet'), findsOneWidget);
      expect(_in('co_kpi_overdue', 'Nothing overdue'), findsOneWidget);
      expect(find.descendant(of: _k('co_kpi_completed'), matching: find.textContaining('vs last period')), findsNothing, reason: 'nothing to compare with');
    });

    testWidgets('Coordination Tasks: My / All / Team with their counts; a row opens the form when it is yours, the facts when it is not', (tester) async {
      await _pump(tester);
      expect(_in('co_tasks_my', '2'), findsOneWidget);
      expect(_in('co_tasks_all', '9'), findsOneWidget);
      expect(_in('co_tasks_team', '7'), findsOneWidget);
      expect(_k('co_task_r1'), findsOneWidget);
      expect(_k('co_task_r2'), findsOneWidget);
      expect(_k('co_task_r4'), findsNothing);
      await _tap(tester, _k('co_tasks_all'));
      expect(_k('co_task_r4'), findsOneWidget);
      await _tap(tester, _k('co_tasks_team'));
      expect(_k('co_task_r3'), findsOneWidget);
      expect(_k('co_task_r4'), findsNothing);
      await _tap(tester, _k('co_task_r3'));
      expect(_k('co_req_detail_view'), findsOneWidget, reason: 'not yours: the facts to read');
      expect(find.textContaining('Ask the Marketing Manager'), findsOneWidget);
      Navigator.of(tester.element(_k('co_req_detail_view'))).pop();
      await tester.pumpAndSettle();
      await _tap(tester, _k('co_tasks_my'));
      await _tap(tester, _k('co_task_r1'));
      expect(_k('co_req_title'), findsOneWidget, reason: 'yours: the form');
      expect(tester.widget<TextField>(_k('co_req_title')).controller!.text, 'Edit bridal campaign v2');
    });

    testWidgets('the task table\'s View All opens Requests & Tasks on the same tab', (tester) async {
      final f = await _pump(tester);
      await _tap(tester, _k('co_tasks_team'));
      await _tap(tester, _k('co_tasks_all_link'));
      expect(_k('coord_requests_list'), findsOneWidget);
      expect(f.requestQueries.last.q.scope, 'team');
    });

    testWidgets('Request by Department: the total in the middle, each team with its share and count; the toggle regroups', (tester) async {
      final f = await _pump(tester);
      expect(tester.widget<Text>(_k('co_dept_total')).data, '9');
      expect(find.text('39% (7)'), findsOneWidget);
      expect(find.text('Sales'), findsWidgets);
      expect(f.overviews.last.o.by, 'both');
      await _pickMenu(tester, 'co_by_pill', 'Requesting');
      expect(f.overviews.last.o.by, 'requesting');
      await _pickMenu(tester, 'co_by_pill', 'Receiving');
      expect(f.overviews.last.o.by, 'receiving');
    });

    testWidgets('Recent requests (with how long ago), Inter-Department rows with progress, Key Updates', (tester) async {
      await _pump(tester);
      expect(find.text('Need raw footage from the shoot'), findsOneWidget);
      expect(find.textContaining('32 mins ago'), findsWidgets);
      expect(_in('co_recent_r9', 'In Progress'), findsOneWidget);
      expect(_in('co_inter_h2', 'Campaign assets & lead integration'), findsOneWidget);
      expect(_in('co_inter_h2', '75%'), findsOneWidget);
      expect(_in('co_inter_h1', '100%'), findsOneWidget);
      expect(find.text('4 of 15 items completed (27%).'), findsOneWidget);
      expect(find.text('2 items overdue.'), findsOneWidget);
      expect(find.text('1 escalated approval needs attention.'), findsOneWidget);
    });

    testWidgets('Approvals Pending: approvals with the amount and posts and assets in review; Review goes where each is decided', (tester) async {
      final f = await _pump(tester);
      expect(_in('co_pending_a1', 'Campaign ad budget – Nov'), findsOneWidget);
      expect(_in('co_pending_a1', 'Marketing · ₹20,000'), findsOneWidget);
      expect(_in('co_review_c1', 'Bridal reel'), findsOneWidget);
      expect(_in('co_review_c1', 'Socials'), findsOneWidget);
      expect(_in('co_review_as1', 'Creative Portfolio'), findsOneWidget);
      expect(_k('co_review_go_c1'), findsOneWidget);
      expect(find.text('4 waiting for a decision · 3 posts and assets in review'), findsOneWidget);
      await _tap(tester, _k('co_pending_review_a1'));
      expect(_k('coord_approvals_list'), findsOneWidget, reason: 'an approval is decided on the Approvals tab');
      expect(f.approvalQueries, isNotEmpty);
    });

    testWidgets('Upcoming Coordinations merges meetings and due days; the period dropdown asks for that period', (tester) async {
      final f = await _pump(tester);
      expect(find.text('Content sync'), findsOneWidget);
      expect(find.text('Studio tour reel publishing'), findsWidgets);
      expect(find.textContaining('11:00–12:00'), findsOneWidget);
      expect(find.textContaining('Due · Production → Socials'), findsOneWidget);
      expect(f.overviews.last.o.upcoming, 'week');
      await _pickMenu(tester, 'co_upcoming_pill', 'This Month');
      expect(f.overviews.last.o.upcoming, 'month');
      await _pickMenu(tester, 'co_upcoming_pill', 'Today');
      expect(f.overviews.last.o.upcoming, 'today');
    });

    testWidgets('the cards\' View All links go to their tabs', (tester) async {
      await _pump(tester);
      await _tap(tester, _k('co_inter_all_link'));
      expect(_k('coord_board_list'), findsOneWidget);
      await _tap(tester, _k('co_tab_overview'));
      await _tap(tester, _k('co_approvals_all_link'));
      expect(_k('coord_approvals_list'), findsOneWidget);
      await _tap(tester, _k('co_tab_overview'));
      await _tap(tester, _k('co_recent_all_link'));
      expect(_k('coord_requests_list'), findsOneWidget);
    });

    testWidgets('an empty period says so card by card; a failing source says so with Try again', (tester) async {
      await _pump(tester, fake: _FakeCoord()..overviewJson = const {'kpis': {}, 'tabCounts': {}, 'tasks': {}, 'byDepartment': {}, 'upcoming': {}});
      expect(find.textContaining('Nothing here yet'), findsOneWidget);
      expect(find.text('No requests in this period.'), findsWidgets);
      expect(find.textContaining('No handovers between teams'), findsOneWidget);
      expect(find.textContaining('Nothing is waiting for a decision or a review'), findsOneWidget);
      expect(find.textContaining('Nothing is scheduled or due'), findsOneWidget);
      expect(find.text('No updates yet.'), findsOneWidget);
      await _pump(tester, fake: _FakeCoord()..overviewFails = true);
      expect(find.text('Try again'), findsOneWidget);
    });
  });

  group('Requests & Tasks', () {
    testWidgets('the strip counts requests only: total, in progress, pending, overdue, completed', (tester) async {
      await _pump(tester, tab: 'requests');
      expect(_in('co_rq_kpi_total', '9'), findsOneWidget);
      expect(_in('co_rq_kpi_progress', '2'), findsOneWidget);
      expect(_in('co_rq_kpi_pending', '4'), findsOneWidget);
      expect(_in('co_rq_kpi_overdue', '1'), findsOneWidget);
      expect(_in('co_rq_kpi_completed', '3'), findsOneWidget);
    });

    testWidgets('the three tabs carry their counts and ask for that tab; My Tasks is the first', (tester) async {
      final f = await _pump(tester, tab: 'requests');
      expect(f.requestQueries.last.q.scope, 'my');
      expect(_in('co_rq_scope_my', '2'), findsOneWidget);
      expect(_in('co_rq_scope_team', '7'), findsOneWidget);
      expect(_in('co_rq_scope_all', '9'), findsOneWidget);
      await _tap(tester, _k('co_rq_scope_team'));
      expect(f.requestQueries.last.q.scope, 'team');
      await _tap(tester, _k('co_rq_scope_all'));
      expect(f.requestQueries.last.q.scope, 'all');
    });

    testWidgets('a row says what, who asked, which teams, priority, due and status; handovers are marked; "Today" and overdue are red', (tester) async {
      await _pump(tester, tab: 'requests');
      expect(_in('co_row_r1', 'Edit bridal campaign v2'), findsOneWidget);
      expect(_in('co_row_r1', 'Preethi'), findsOneWidget);
      expect(_in('co_row_r1', 'High'), findsOneWidget);
      expect(_in('co_row_r1', 'In Progress'), findsOneWidget);
      expect(_in('co_row_r2', 'Abhiram'), findsOneWidget);
      expect(_in('co_row_r2', 'Today'), findsOneWidget);
      expect(tester.widget<Text>(find.descendant(of: _k('co_row_r2'), matching: find.text('Today'))).style!.color, const Color(0xFFE5484D));
      expect(tester.widget<Text>(find.descendant(of: _k('co_row_r1'), matching: find.text(dueLabel(_d(-1))))).style!.color, const Color(0xFFE5484D), reason: 'overdue');
      expect(_in('co_row_h2', 'Handover'), findsOneWidget);
      expect(_in('co_row_r3', 'Completed'), findsOneWidget);
      expect(find.text('Showing 1–4 of 23'), findsOneWidget);
    });

    testWidgets('the tiles filter the table; the priority and status pills and the search ask for exactly that', (tester) async {
      final f = await _pump(tester, tab: 'requests');
      await _tap(tester, _k('co_rq_kpi_overdue'));
      expect(f.requestQueries.last.q.status, 'overdue');
      await _tap(tester, _k('co_rq_kpi_pending'));
      expect(f.requestQueries.last.q.status, 'pending');
      await _tap(tester, _k('co_rq_kpi_total'));
      expect(f.requestQueries.last.q.status, 'all');
      await _pickMenu(tester, 'co_rq_priority_pill', 'Medium');
      expect(f.requestQueries.last.q.priority, 'medium');
      await _pickMenu(tester, 'co_rq_status_pill', 'In Review');
      expect(f.requestQueries.last.q.status, 'in_review');
      expect(f.requestQueries.last.q.priority, 'medium', reason: 'filters add up');
      await tester.enterText(_k('co_rq_search'), 'bridal');
      await tester.pumpAndSettle();
      expect(f.requestQueries.last.q.q, 'bridal');
      expect(f.requestQueries.last.q.status, 'in_review');
    });

    testWidgets('paging: next goes to page 2; a new filter starts again at page 1', (tester) async {
      final f = await _pump(tester, tab: 'requests');
      expect(tester.widget<IconButton>(_k('co_rq_prev')).onPressed, isNull);
      expect(tester.widget<IconButton>(_k('co_rq_next')).onPressed, isNotNull);
      await _tap(tester, _k('co_rq_next'));
      expect(f.requestQueries.last.q.page, 2);
      await _tap(tester, _k('co_rq_scope_all'));
      expect(f.requestQueries.last.q.page, 1);
    });

    testWidgets('the row menu offers only what the person may do: edit, mark the next statuses, delete', (tester) async {
      final f = await _pump(tester, tab: 'requests');
      await _tap(tester, _k('co_menu_r1'));
      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Mark In Review'), findsOneWidget);
      expect(find.text('Mark Completed'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
      await tester.tap(find.text('Mark Completed'));
      await tester.pumpAndSettle();
      expect(f.savedRequests.single.id, 'r1');
      expect(f.savedRequests.single.body, {'status': 'completed'});
      expect(_k('co_menu_r3'), findsNothing, reason: 'a request you may not change has no menu');
    });

    testWidgets('delete asks first and deletes only on confirm; a refusal is shown in words', (tester) async {
      final f = await _pump(tester, tab: 'requests');
      await _tap(tester, _k('co_menu_r1'));
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(f.deletedRequests, isEmpty);
      f.refuse = const TeamRefusal('Only the person who raised a request, or the Marketing Manager, can delete it.', status: 403);
      await _tap(tester, _k('co_menu_r1'));
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(_k('co_delete_confirm'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Only the person who raised a request'), findsOneWidget);
      f.refuse = null;
      await _tap(tester, _k('co_menu_r1'));
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(_k('co_delete_confirm'));
      await tester.pumpAndSettle();
      expect(f.deletedRequests, ['r1']);
    });

    testWidgets('an empty list says how to start; a filter with no match says so; a failing source says Try again', (tester) async {
      await _pump(tester, tab: 'requests', fake: _FakeCoord()..requestsJson = {'kpis': {}, 'tabCounts': {}, 'items': [], 'total': 0});
      expect(find.textContaining('No requests in this period'), findsOneWidget);
      await _pump(tester, tab: 'requests', fake: _FakeCoord()..requestsJson = {'kpis': {}, 'tabCounts': {'my': 0, 'team': 0, 'all': 5}, 'items': [], 'total': 0});
      expect(find.textContaining('No request matches'), findsOneWidget);
    });

    testWidgets('Export CSV asks the server for the rows of this tab', (tester) async {
      final f = await _pump(tester, tab: 'requests');
      await _tap(tester, _k('co_export_requests'));
      expect(f.exports.single.type, 'requests');
    });
  });

  group('the request form', () {
    testWidgets('a title and the team it is for are needed; a filled one is sent with its people, priority, brand and due day', (tester) async {
      final f = await _pump(tester);
      await _tap(tester, _k('co_new_request'));
      expect(find.text('New request'), findsOneWidget);
      await tester.tap(_k('co_req_save'));
      await tester.pumpAndSettle();
      expect(find.text('Give the request a title.'), findsOneWidget);
      await tester.enterText(_k('co_req_title'), 'Raw footage from the shoot');
      await tester.tap(_k('co_req_save'));
      await tester.pumpAndSettle();
      expect(find.text('Choose the team the request is for.'), findsOneWidget);
      expect(f.savedRequests, isEmpty);
      await tester.tap(_k('co_req_to'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Socials').last);
      await tester.pumpAndSettle();
      await tester.tap(_k('co_req_assignee'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Abhiram').last);
      await tester.pumpAndSettle();
      await tester.tap(_k('co_req_priority'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('High').last);
      await tester.pumpAndSettle();
      await tester.tap(_k('co_req_save'));
      await tester.pumpAndSettle();
      final b = f.savedRequests.single.body;
      expect(f.savedRequests.single.id, isNull);
      expect([b['kind'], b['title'], b['fromDept'], b['toDept'], b['priority'], b['brand'], b['assigneeId'], b['dueDate']], ['request', 'Raw footage from the shoot', 'Marketing', 'Socials', 'high', 'main', 'm2', null]);
      expect(b.containsKey('status'), isFalse, reason: 'a new request starts open');
      expect(b.containsKey('progress'), isFalse);
      expect(b.containsKey('requestedById'), isFalse, reason: 'it is raised as you');
      expect(_k('co_req_title'), findsNothing, reason: 'the form closed');
    });

    testWidgets('a refusal from the server is shown inside the form, and Save can be tried again', (tester) async {
      final f = _FakeCoord()..refuse = const TeamRefusal('The due date must be a real day.');
      await _pump(tester, fake: f);
      await _tap(tester, _k('co_new_request'));
      await tester.enterText(_k('co_req_title'), 'Raw footage');
      await tester.tap(_k('co_req_to'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sales').last);
      await tester.pumpAndSettle();
      await tester.tap(_k('co_req_save'));
      await tester.pumpAndSettle();
      expect(find.text('The due date must be a real day.'), findsOneWidget);
      expect(tester.widget<FilledButton>(_k('co_req_save')).onPressed, isNotNull, reason: 'not stuck saving');
      f.refuse = null;
      await tester.tap(_k('co_req_save'));
      await tester.pumpAndSettle();
      expect(f.savedRequests.single.body['toDept'], 'Sales');
    });

    testWidgets('editing opens the request filled in; only what changed (status, progress) is sent; the status offers the next steps', (tester) async {
      final f = await _pump(tester, tab: 'requests');
      await _tap(tester, _k('co_row_r1'));
      expect(find.text('Edit request'), findsOneWidget);
      expect(tester.widget<TextField>(_k('co_req_title')).controller!.text, 'Edit bridal campaign v2');
      expect(tester.widget<TextField>(_k('co_req_detail')).controller!.text, 'Three reels');
      await tester.enterText(_k('co_req_title'), 'Edit bridal campaign v3');
      await tester.tap(_k('co_req_status'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(DropdownMenuItem<String>, 'Open'), findsNothing, reason: 'work that has started cannot go back to Open');
      await tester.tap(find.text('In Review').last);
      await tester.pumpAndSettle();
      await tester.tap(_k('co_req_save'));
      await tester.pumpAndSettle();
      expect(f.savedRequests.single.id, 'r1');
      final b = f.savedRequests.single.body;
      expect([b['title'], b['status'], b['toDept']], ['Edit bridal campaign v3', 'in_review', 'Production']);
      expect(b.containsKey('progress'), isFalse, reason: 'the slider was not touched, so the server\'s stage floor applies');
      expect(b['dueDate'], _d(-1));
    });

    testWidgets('moving the progress slider sends the figure; a manager can change who raised it, a member cannot', (tester) async {
      final f = await _pump(tester, tab: 'requests');
      await _tap(tester, _k('co_row_r1'));
      expect(_k('co_req_requester'), findsOneWidget, reason: 'the fake user is a manager');
      await tester.drag(_k('co_req_progress'), const Offset(60, 0));
      await tester.pumpAndSettle();
      await tester.tap(_k('co_req_save'));
      await tester.pumpAndSettle();
      expect(f.savedRequests.single.body['progress'], isA<int>());
      expect(f.savedRequests.single.body['progress'], isNot(40));
      expect(f.savedRequests.single.body.containsKey('status'), isFalse, reason: 'the status was not changed, so it is not sent (a same-status "move" is not a change)');
      final member = _FakeCoord(manager: false);
      await _pump(tester, tab: 'requests', fake: member);
      await _tap(tester, _k('co_row_r1'));
      expect(_k('co_req_requester'), findsNothing);
    });

    testWidgets('a handover is raised from the board: its own title and kind; the due day can be set and taken away', (tester) async {
      final f = await _pump(tester, tab: 'interdepartment');
      await _tap(tester, _k('co_ib_new'));
      expect(find.text('New handover'), findsOneWidget);
      expect(find.text('What is being handed over'), findsOneWidget);
      await tester.enterText(_k('co_req_title'), 'Campaign leads');
      await tester.tap(_k('co_req_to'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sales').last);
      await tester.pumpAndSettle();
      await tester.tap(_k('co_req_due'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(_k('co_req_due_clear'), findsOneWidget);
      await tester.tap(_k('co_req_save'));
      await tester.pumpAndSettle();
      expect(f.savedRequests.single.body['kind'], 'handover');
      expect(f.savedRequests.single.body['dueDate'], isNotNull);
    });
  });

  group('Inter-Department', () {
    testWidgets('the strip and a column per stage with its count and its cards', (tester) async {
      await _pump(tester, tab: 'interdepartment');
      expect(_in('co_ib_kpi_active', '3'), findsOneWidget);
      expect(_in('co_ib_kpi_awaiting', '1'), findsOneWidget);
      expect(_in('co_ib_kpi_review', '1'), findsOneWidget);
      expect(_in('co_ib_kpi_overdue', '1'), findsOneWidget);
      expect(_in('co_ib_kpi_completed', '2'), findsOneWidget);
      for (final s in [('requested', 'Requested (1)'), ('in_progress', 'In Progress (1)'), ('in_review', 'In Review (1)'), ('completed', 'Completed (1)')]) {
        expect(tester.widget<Text>(_k('co_stage_title_${s.$1}')).data, s.$2);
      }
      expect(_in('co_card_h1', 'Campaign leads'), findsOneWidget);
      expect(_in('co_card_h1', 'Due: ${dueLabel(_d(1))}'), findsOneWidget);
      expect(_in('co_card_h2', 'Due: ${dueLabel(_d(-2))}'), findsOneWidget);
      expect(tester.widget<Text>(find.descendant(of: _k('co_card_h2'), matching: find.text('Due: ${dueLabel(_d(-2))}'))).style!.color, const Color(0xFFE5484D), reason: 'overdue is red');
      expect(find.descendant(of: _k('co_card_h4'), matching: find.textContaining('Completed: ')), findsOneWidget);
      expect(find.descendant(of: _k('co_card_h2'), matching: find.text('60%')), findsOneWidget);
      expect(find.descendant(of: _k('co_card_h4'), matching: find.byType(LinearProgressIndicator)), findsNothing, reason: 'a finished card has no progress bar');
    });

    testWidgets('a card\'s menu offers only the stages it may move to; choosing one asks the server to move it', (tester) async {
      final f = await _pump(tester, tab: 'interdepartment');
      await _tap(tester, _k('co_move_h1'));
      expect(find.text('Move to In Progress'), findsOneWidget);
      expect(find.text('Move to Completed'), findsOneWidget);
      expect(find.text('Move to In Review'), findsNothing, reason: 'Requested → In Review skips a stage');
      await tester.tap(find.text('Move to In Progress'));
      await tester.pumpAndSettle();
      expect(f.moves.single.id, 'h1');
      expect(f.moves.single.stage, 'in_progress');
    });

    testWidgets('a move the server refuses is explained; a card you may not edit still moves if allowed but has no Edit', (tester) async {
      final f = _FakeCoord()..refuse = const TeamRefusal('A request that is Open cannot be moved to In Review.', status: 400);
      await _pump(tester, tab: 'interdepartment', fake: f);
      await _tap(tester, _k('co_move_h2'));
      await tester.tap(find.text('Move to In Review'));
      await tester.pumpAndSettle();
      expect(find.text('A request that is Open cannot be moved to In Review.'), findsOneWidget);
      f.refuse = null;
      await _tap(tester, _k('co_move_h3'));
      expect(find.text('Edit'), findsNothing);
      expect(find.text('Move to In Progress'), findsOneWidget);
    });

    testWidgets('a card opens the form when it is yours; an empty board says how to start', (tester) async {
      await _pump(tester, tab: 'interdepartment');
      await _tap(tester, _k('co_card_h1'));
      expect(find.text('Edit handover'), findsOneWidget);
      await _pump(tester, tab: 'interdepartment', fake: _FakeCoord()..boardJson = {'kpis': {}, 'stages': []});
      expect(find.textContaining('No handovers between teams'), findsOneWidget);
    });
  });

  group('Approvals', () {
    testWidgets('the strip, with the amount still waiting; the tabs carry their counts and ask for that tab', (tester) async {
      final f = await _pump(tester, tab: 'approvals');
      expect(_in('co_ap_kpi_total', '6'), findsOneWidget);
      expect(_in('co_ap_kpi_total', '₹80,500 still waiting'), findsOneWidget);
      expect(_in('co_ap_kpi_pending', '2'), findsOneWidget);
      expect(_in('co_ap_kpi_review', '1'), findsOneWidget);
      expect(_in('co_ap_kpi_escalated', '1'), findsOneWidget);
      expect(_in('co_ap_kpi_approved', '1'), findsOneWidget);
      expect(f.approvalQueries.last.status, 'pending');
      expect(_in('co_ap_tab_pending', '2'), findsOneWidget);
      expect(_in('co_ap_tab_in_review', '2'), findsOneWidget, reason: 'escalated ones are in review');
      expect(_in('co_ap_tab_approved', '1'), findsOneWidget);
      expect(_in('co_ap_tab_rejected', '1'), findsOneWidget);
      await _tap(tester, _k('co_ap_tab_approved'));
      expect(f.approvalQueries.last.status, 'approved');
      await _tap(tester, _k('co_ap_kpi_escalated'));
      expect(f.approvalQueries.last.status, 'in_review');
      await _tap(tester, _k('co_ap_kpi_pending'));
      expect(f.approvalQueries.last.status, 'pending');
    });

    testWidgets('a row shows who asked, the category, the amount and impact, when it was asked and its status', (tester) async {
      await _pump(tester, tab: 'approvals');
      expect(_in('co_ap_row_a1', 'Campaign ad budget – Nov'), findsOneWidget);
      expect(_in('co_ap_row_a1', 'Preethi'), findsOneWidget);
      expect(_in('co_ap_row_a1', 'Marketing'), findsOneWidget);
      expect(_in('co_ap_row_a1', '₹20,000'), findsOneWidget);
      expect(_in('co_ap_row_a1', 'Reach +20%'), findsOneWidget);
      expect(_in('co_ap_row_a1', coordDay(_d(-1))), findsOneWidget);
      expect(_in('co_ap_row_a1', 'Pending'), findsOneWidget);
      expect(_in('co_ap_row_a3', 'Approved'), findsOneWidget);
      expect(find.text('Showing 1–3 of 14'), findsOneWidget);
    });

    testWidgets('a manager approves and rejects from the row; a member only reads (and changes their own pending one)', (tester) async {
      await _pump(tester, tab: 'approvals');
      expect(_k('co_ap_approve_a1'), findsOneWidget);
      expect(_k('co_ap_reject_a2'), findsOneWidget);
      expect(_k('co_ap_approve_a3'), findsNothing, reason: 'a decided approval is final');
      await _pump(tester, tab: 'approvals', fake: _FakeCoord(manager: false));
      expect(_k('co_ap_approve_a1'), findsNothing);
      expect(_k('co_ap_reject_a1'), findsNothing);
      expect(_k('co_ap_view_a2'), findsOneWidget, reason: 'someone else\'s: view only');
      expect(_k('co_ap_menu_a1'), findsOneWidget, reason: 'their own pending one: edit or withdraw');
      await _tap(tester, _k('co_ap_view_a2'));
      expect(_k('co_ap_detail_view'), findsOneWidget);
      expect(find.text('Equipment purchase (SD Card)'), findsWidgets);
    });

    testWidgets('approving asks for an optional note and shows what is being decided; confirming sends the decision', (tester) async {
      final f = await _pump(tester, tab: 'approvals');
      await _tap(tester, _k('co_ap_approve_a1'));
      expect(find.textContaining('Approve: Campaign ad budget – Nov'), findsOneWidget);
      expect(find.text('₹20,000'), findsWidgets);
      expect(find.textContaining('Impact: Reach +20%'), findsOneWidget);
      await tester.enterText(_k('co_decide_note'), 'Go ahead');
      await tester.tap(_k('co_decide_save'));
      await tester.pumpAndSettle();
      expect(f.decisions.single, (id: 'a1', decision: 'approve', note: 'Go ahead'));
      expect(_k('co_decide_note'), findsNothing, reason: 'closed');
    });

    testWidgets('rejecting needs a reason before anything is sent; the server\'s refusal is shown in the dialog', (tester) async {
      final f = await _pump(tester, tab: 'approvals');
      await _tap(tester, _k('co_ap_reject_a2'));
      await tester.tap(_k('co_decide_save'));
      await tester.pumpAndSettle();
      expect(find.text('Say why it is rejected, so the requester knows.'), findsOneWidget);
      expect(f.decisions, isEmpty);
      f.refuse = const TeamRefusal('This approval is already approved, so it is final. Raise a new one if something changed.', status: 409);
      await tester.enterText(_k('co_decide_note'), 'Over the cap');
      await tester.tap(_k('co_decide_save'));
      await tester.pumpAndSettle();
      expect(find.textContaining('so it is final'), findsOneWidget);
      expect(tester.widget<FilledButton>(_k('co_decide_save')).onPressed, isNotNull);
      f.refuse = null;
      await tester.tap(_k('co_decide_save'));
      await tester.pumpAndSettle();
      expect(f.decisions.single, (id: 'a2', decision: 'reject', note: 'Over the cap'));
    });

    testWidgets('the more menu: mark in review and escalate for a pending one; delete asks first', (tester) async {
      final f = await _pump(tester, tab: 'approvals');
      await _tap(tester, _k('co_ap_menu_a1'));
      expect(find.text('Mark in review'), findsOneWidget);
      expect(find.text('Escalate'), findsOneWidget);
      await tester.tap(find.text('Escalate'));
      await tester.pumpAndSettle();
      await tester.tap(_k('co_decide_save'));
      await tester.pumpAndSettle();
      expect(f.decisions.single.decision, 'escalate');
      await _tap(tester, _k('co_ap_menu_a1'));
      await tester.tap(find.text('Mark in review'));
      await tester.pumpAndSettle();
      await tester.tap(_k('co_decide_save'));
      await tester.pumpAndSettle();
      expect(f.decisions.last.decision, 'review');
      await _tap(tester, _k('co_ap_menu_a1'));
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(_k('co_ap_delete_confirm'));
      await tester.pumpAndSettle();
      expect(f.deletedApprovals, ['a1']);
    });

    testWidgets('raising an approval: what and a category are needed; the amount must be a number; the payload carries the amount, impact and the request it unblocks', (tester) async {
      final f = await _pump(tester, tab: 'approvals');
      await _tap(tester, _k('co_ap_new'));
      await tester.tap(_k('co_ap_save'));
      await tester.pumpAndSettle();
      expect(find.text('Say what needs approving.'), findsOneWidget);
      await tester.enterText(_k('co_ap_title'), 'Print magazine');
      await tester.tap(_k('co_ap_save'));
      await tester.pumpAndSettle();
      expect(find.text('Choose a category.'), findsOneWidget);
      await tester.tap(_k('co_ap_category'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Brand').last);
      await tester.pumpAndSettle();
      await tester.enterText(_k('co_ap_amount'), 'lots');
      await tester.tap(_k('co_ap_save'));
      await tester.pumpAndSettle();
      expect(find.text('The amount must be a number.'), findsOneWidget);
      expect(f.savedApprovals, isEmpty);
      await tester.enterText(_k('co_ap_amount'), '45,000');
      await tester.enterText(_k('co_ap_impact'), 'Brand visibility');
      await tester.tap(_k('co_ap_request'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Waiting for the budget').last);
      await tester.pumpAndSettle();
      await tester.tap(_k('co_ap_save'));
      await tester.pumpAndSettle();
      final b = f.savedApprovals.single.body;
      expect([b['title'], b['category'], b['amount'], b['impact'], b['brand'], b['requestId'], b['dueDate']], ['Print magazine', 'Brand', 45000.0, 'Brand visibility', 'main', 'q1', null]);
      expect(f.savedApprovals.single.id, isNull);
    });

    testWidgets('editing your own pending approval opens it filled in and sends the change with its id; a server refusal shows in the form', (tester) async {
      final f = _FakeCoord(manager: false);
      await _pump(tester, tab: 'approvals', fake: f);
      await _tap(tester, _k('co_ap_row_a1'));
      expect(find.text('Edit approval'), findsOneWidget);
      expect(tester.widget<TextField>(_k('co_ap_amount')).controller!.text, '20000');
      await tester.enterText(_k('co_ap_amount'), '25000');
      f.refuse = const TeamRefusal('You can change your own approval until it is being reviewed. Ask the Marketing Manager.', status: 403);
      await tester.tap(_k('co_ap_save'));
      await tester.pumpAndSettle();
      expect(find.textContaining('until it is being reviewed'), findsOneWidget);
      f.refuse = null;
      await tester.tap(_k('co_ap_save'));
      await tester.pumpAndSettle();
      expect(f.savedApprovals.single.id, 'a1');
      expect(f.savedApprovals.single.body['amount'], 25000.0);
    });

    testWidgets('content awaiting review comes from posts and assets in review, with a Review button for each', (tester) async {
      await _pump(tester, tab: 'approvals');
      expect(find.text('Content awaiting review'), findsOneWidget);
      expect(find.text('1 posts in Socials · 1 assets in the Creative Portfolio'), findsOneWidget);
      expect(_in('co_ap_review_c1', 'Bridal reel'), findsOneWidget);
      expect(_in('co_ap_review_as1', 'Final cut – bridal'), findsOneWidget);
      expect(_k('co_ap_review_go_c1'), findsOneWidget);
      expect(_k('co_ap_review_go_as1'), findsOneWidget);
      await _pump(tester, tab: 'approvals', fake: _FakeCoord()..approvalsJson = {..._approvals(), 'review': {'total': 0, 'items': []}});
      expect(find.textContaining('Nothing is waiting for review'), findsOneWidget);
    });

    testWidgets('search and paging ask for exactly that; an empty tab and an empty period say so', (tester) async {
      final f = await _pump(tester, tab: 'approvals');
      await tester.enterText(_k('co_ap_search'), 'magazine');
      await tester.pumpAndSettle();
      expect(f.approvalQueries.last.q, 'magazine');
      expect(f.approvalQueries.last.status, 'pending');
      await _tap(tester, _k('co_ap_next'));
      expect(f.approvalQueries.last.page, 2);
      await _pump(tester, tab: 'approvals', fake: _FakeCoord()..approvalsJson = {'kpis': {}, 'tabCounts': {}, 'items': [], 'total': 0});
      expect(find.textContaining('No approvals in this period'), findsOneWidget);
      await _pump(tester, tab: 'approvals', fake: _FakeCoord()..approvalsJson = {'kpis': {'total': 4}, 'tabCounts': {}, 'items': [], 'total': 0});
      expect(find.text('No approval in this tab.'), findsOneWidget);
    });
  });

  group('Meetings', () {
    testWidgets('the strip, the list with each meeting\'s state, and the first upcoming one open with its agenda, attendees and action items', (tester) async {
      await _pump(tester, tab: 'meetings');
      expect(_in('co_mt_kpi_total', '8'), findsOneWidget);
      expect(_in('co_mt_kpi_week', '3'), findsOneWidget);
      expect(_in('co_mt_kpi_completed', '5'), findsOneWidget);
      expect(_in('co_mt_kpi_upcoming', '2'), findsOneWidget);
      expect(_in('co_mt_kpi_upcoming', '1 ended without notes'), findsOneWidget);
      expect(_in('co_mt_mt1', 'Marketing Sync'), findsOneWidget);
      expect(_in('co_mt_mt1', 'Today, 11:00 – 12:00'), findsOneWidget);
      expect(_in('co_mt_mt1', 'Upcoming'), findsOneWidget);
      expect(_in('co_mt_mt2', 'Needs notes'), findsOneWidget);
      expect(_in('co_mt_mt3', 'Completed'), findsOneWidget);
      expect(find.byKey(const ValueKey('mt_mt1')), findsOneWidget, reason: 'the first upcoming meeting is open');
      expect(find.text('•  Campaign performance review'), findsOneWidget);
      expect(find.text('Attendees (3)'), findsOneWidget);
      expect(find.text('Ashique'), findsWidgets);
      expect(find.text('Client rep'), findsOneWidget);
      expect(_k('co_mt_join'), findsOneWidget);
      expect(find.text('Conference Room'), findsWidgets);
      expect(find.text('Send the revised plan'), findsOneWidget);
    });

    testWidgets('picking another meeting opens it; a meeting that is not over has no "Mark completed", one that ended has', (tester) async {
      await _pump(tester, tab: 'meetings');
      expect(_k('co_mt_complete'), findsNothing);
      await _tap(tester, _k('co_mt_mt2'));
      expect(find.byKey(const ValueKey('mt_mt2')), findsOneWidget);
      expect(_k('co_mt_complete'), findsOneWidget);
      await _tap(tester, _k('co_mt_mt3'));
      expect(find.text('Agreed the festive pipeline.'), findsOneWidget, reason: 'the discussion notes of a completed meeting');
      expect(_k('co_mt_complete'), findsNothing);
    });

    testWidgets('the status chips and the search ask for exactly that', (tester) async {
      final f = await _pump(tester, tab: 'meetings');
      await _tap(tester, _k('co_mt_filter_upcoming'));
      expect(f.meetingQueries.last.status, 'upcoming');
      await _tap(tester, _k('co_mt_filter_to_close'));
      expect(f.meetingQueries.last.status, 'to_close');
      await tester.enterText(_k('co_mt_search'), 'sky');
      await tester.pumpAndSettle();
      expect(f.meetingQueries.last.q, 'sky');
      expect(f.meetingQueries.last.status, 'to_close');
    });

    testWidgets('scheduling: a title is needed; the times go to the server as IST instants with the teams, attendees, agenda and link', (tester) async {
      final f = await _pump(tester, tab: 'meetings');
      await _tap(tester, _k('co_mt_new'));
      expect(find.text('Schedule meeting'), findsOneWidget);
      expect(_k('co_mt_notes'), findsNothing, reason: 'notes and action items come when the meeting is closed');
      await tester.tap(_k('co_mt_save'));
      await tester.pumpAndSettle();
      expect(find.text('Give the meeting a title.'), findsOneWidget);
      await tester.enterText(_k('co_mt_title'), 'Production Planning');
      await tester.enterText(_k('co_mt_location'), 'Studio 1');
      await tester.enterText(_k('co_mt_link'), 'https://meet.google.com/xyz');
      await tester.enterText(_k('co_mt_agenda'), 'Shoot logistics\n\nCrew plan');
      await tester.enterText(_k('co_mt_others'), 'Client rep, Vendor');
      await tester.ensureVisible(_k('co_mt_dept_Production'));
      await tester.tap(_k('co_mt_dept_Production'));
      await tester.tap(_k('co_mt_dept_Sales'));
      await tester.ensureVisible(_k('co_mt_member_m1'));
      await tester.tap(_k('co_mt_member_m1'));
      await tester.pumpAndSettle();
      await tester.tap(_k('co_mt_save'));
      await tester.pumpAndSettle();
      final b = f.savedMeetings.single.body;
      expect(f.savedMeetings.single.id, isNull);
      final today = DateTime.now();
      expect(b['startAt'], istInstant(DateTime(today.year, today.month, today.day), const TimeOfDay(hour: 10, minute: 0)));
      expect(b['endAt'], istInstant(DateTime(today.year, today.month, today.day), const TimeOfDay(hour: 11, minute: 0)));
      expect([b['title'], b['location'], b['link'], b['brand']], ['Production Planning', 'Studio 1', 'https://meet.google.com/xyz', 'main']);
      expect((b['departments'] as List).toSet(), {'Production', 'Sales'});
      expect(b['agenda'], ['Shoot logistics', 'Crew plan']);
      expect(b['attendees'], [{'memberId': 'm1'}, {'name': 'Client rep'}, {'name': 'Vendor'}]);
      expect(b.containsKey('status'), isFalse);
    });

    testWidgets('a refusal shows inside the schedule form', (tester) async {
      final f = _FakeCoord()..refuse = const TeamRefusal('The meeting has to end after it starts.');
      await _pump(tester, tab: 'meetings', fake: f);
      await _tap(tester, _k('co_mt_new'));
      await tester.enterText(_k('co_mt_title'), 'Sync');
      await tester.tap(_k('co_mt_save'));
      await tester.pumpAndSettle();
      expect(find.text('The meeting has to end after it starts.'), findsOneWidget);
    });

    testWidgets('closing a meeting: Mark completed opens it ready to close; notes and action items are sent with the Completed status', (tester) async {
      final f = await _pump(tester, tab: 'meetings');
      await _tap(tester, _k('co_mt_mt2'));
      await _tap(tester, _k('co_mt_complete'));
      expect(find.text('Close the meeting'), findsOneWidget);
      expect(tester.widget<TextField>(_k('co_mt_title')).controller!.text, 'Campaign Review – SkyCity');
      expect(tester.widget<TextField>(_k('co_mt_agenda')).controller!.text, 'Campaign performance review\nUpcoming creatives and content pipeline');
      await tester.enterText(_k('co_mt_notes'), 'Agreed the pipeline.');
      await tester.ensureVisible(_k('co_mt_add_item'));
      await tester.tap(_k('co_mt_add_item'));
      await tester.pumpAndSettle();
      await tester.enterText(_k('co_mt_item_text_3'), 'Share the deck');
      await tester.tap(_k('co_mt_item_remove_1'));
      await tester.pumpAndSettle();
      await tester.tap(_k('co_mt_save'));
      await tester.pumpAndSettle();
      expect(f.savedMeetings.single.id, 'mt2');
      final b = f.savedMeetings.single.body;
      expect([b['status'], b['notes']], ['completed', 'Agreed the pipeline.']);
      final items = (b['actionItems'] as List).cast<Map<String, dynamic>>();
      expect(items.map((i) => i['text']), ['Send the revised plan', 'Share the numbers', 'Share the deck'], reason: 'the removed one is gone, the new one is in');
      expect(items.first['id'], 'i1', reason: 'kept items keep their id (and so their follow-up)');
      expect(items.first['ownerId'], 'm1');
      expect(items.first['due'], _d(3));
    });

    testWidgets('an action item becomes a follow-up once; one that already is says so and has no button; an item without a due day cannot', (tester) async {
      final f = await _pump(tester, tab: 'meetings');
      expect(_k('co_mt_followup_i1'), findsOneWidget);
      expect(_k('co_mt_followup_i2'), findsNothing, reason: 'no due day to follow up');
      expect(_in('co_mt_action_i3', 'In Follow-ups'), findsOneWidget);
      expect(_k('co_mt_followup_i3'), findsNothing);
      await tester.tap(_k('co_mt_followup_i1'));
      await tester.pumpAndSettle();
      expect(f.conversions.single, (meetingId: 'mt1', itemId: 'i1'));
      f.refuse = const TeamRefusal('That action item is already a follow-up.', status: 409);
      await tester.tap(_k('co_mt_followup_i1'));
      await tester.pumpAndSettle();
      expect(find.text('That action item is already a follow-up.'), findsOneWidget);
    });

    testWidgets('ticking an action item saves the list; one that is tracked as a follow-up cannot be ticked here', (tester) async {
      final f = await _pump(tester, tab: 'meetings');
      await tester.tap(_k('co_mt_action_done_i2'));
      await tester.pumpAndSettle();
      expect(f.savedMeetings.single.id, 'mt1');
      final items = (f.savedMeetings.single.body['actionItems'] as List).cast<Map<String, dynamic>>();
      expect(items.map((i) => [i['id'], i['done']]), [['i1', false], ['i2', true], ['i3', false]]);
      expect(items[1]['ownerName'], 'Vendor');
      expect(items[0].containsKey('ownerName'), isFalse);
      f.savedMeetings.clear();
      await tester.tap(_k('co_mt_action_done_i3'));
      await tester.pumpAndSettle();
      expect(f.savedMeetings, isEmpty);
    });

    testWidgets('the menu: cancel the meeting, or delete it after asking', (tester) async {
      final f = await _pump(tester, tab: 'meetings');
      await _tap(tester, _k('co_mt_menu'));
      expect(find.text('Cancel meeting'), findsOneWidget);
      expect(find.text('Reopen'), findsNothing);
      await tester.tap(find.text('Cancel meeting'));
      await tester.pumpAndSettle();
      expect(f.savedMeetings.single.body, {'status': 'cancelled'});
      await _tap(tester, _k('co_mt_menu'));
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(f.deletedMeetings, isEmpty);
      await _tap(tester, _k('co_mt_menu'));
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(_k('co_mt_delete_confirm'));
      await tester.pumpAndSettle();
      expect(f.deletedMeetings, ['mt1']);
    });

    testWidgets('a meeting you may not change has no menu, no Mark completed and no follow-up buttons; no meetings says how to start', (tester) async {
      final f = _FakeCoord();
      f.details['mt1'] = _mtDetail('mt1', canEdit: false);
      await _pump(tester, tab: 'meetings', fake: f);
      expect(_k('co_mt_menu'), findsNothing);
      expect(_k('co_mt_followup_i1'), findsNothing);
      await _pump(tester, tab: 'meetings', fake: _FakeCoord()..meetingsJson = {'kpis': {}, 'items': [], 'total': 0});
      expect(find.textContaining('No meetings in this period'), findsOneWidget);
      expect(find.textContaining('Schedule a meeting to see'), findsOneWidget);
    });
  });

  group('Follow-ups', () {
    testWidgets('the strip, and each row with its owner, team, due day, state and reminder; Today and overdue are red', (tester) async {
      await _pump(tester, tab: 'followups');
      expect(_in('co_fu_kpi_total', '36'), findsOneWidget);
      expect(_in('co_fu_kpi_today', '12'), findsOneWidget);
      expect(_in('co_fu_kpi_upcoming', '14'), findsOneWidget);
      expect(_in('co_fu_kpi_overdue', '8'), findsOneWidget);
      expect(_in('co_fu_kpi_completed', '20'), findsOneWidget);
      expect(_in('co_fu_row_f1', 'Get final content approval'), findsOneWidget);
      expect(_in('co_fu_row_f1', 'Bridal Campaign'), findsOneWidget);
      expect(_in('co_fu_row_f1', 'Today'), findsOneWidget);
      expect(_in('co_fu_row_f1', 'Due Today'), findsOneWidget);
      expect(_in('co_fu_row_f2', 'Upcoming'), findsOneWidget);
      expect(_in('co_fu_row_f3', 'Overdue'), findsOneWidget);
      expect(_in('co_fu_row_f4', 'Completed'), findsOneWidget);
      expect(tester.widget<Text>(find.descendant(of: _k('co_fu_row_f1'), matching: find.text('Today'))).style!.color, const Color(0xFFE5484D));
      expect(find.descendant(of: _k('co_fu_row_f1'), matching: find.byIcon(Icons.notifications_active_rounded)), findsOneWidget);
      expect(find.descendant(of: _k('co_fu_row_f2'), matching: find.byIcon(Icons.notifications_none_rounded)), findsOneWidget, reason: 'no reminder flag');
      expect(find.text('Showing 1–4 of 25'), findsOneWidget);
    });

    testWidgets('the tiles and the status chips filter; the owner pill and the search ask for exactly that', (tester) async {
      final f = await _pump(tester, tab: 'followups');
      await _tap(tester, _k('co_fu_kpi_overdue'));
      expect(f.followUpQueries.last.status, 'overdue');
      await _tap(tester, _k('co_fu_status_completed'));
      expect(f.followUpQueries.last.status, 'completed');
      await _tap(tester, _k('co_fu_kpi_total'));
      expect(f.followUpQueries.last.status, 'all');
      await _pickMenu(tester, 'co_fu_owner_pill', 'Abhiram');
      expect(f.followUpQueries.last.ownerId, 'm2');
      expect(f.calendars.last.ownerId, 'm2', reason: 'the calendar follows the owner');
      expect(find.text('Showing Abhiram’s follow-ups'), findsOneWidget);
      await tester.enterText(_k('co_fu_search'), 'moodboard');
      await tester.pumpAndSettle();
      expect(f.followUpQueries.last.q, 'moodboard');
      expect(f.followUpQueries.last.ownerId, 'm2');
      await _pickMenu(tester, 'co_fu_owner_pill', 'All Owners');
      expect(f.followUpQueries.last.ownerId, isNull);
    });

    testWidgets('ticking a follow-up marks it done (or open again); one you may not change cannot be ticked', (tester) async {
      final f = await _pump(tester, tab: 'followups');
      await tester.tap(_k('co_fu_done_f1'));
      await tester.pumpAndSettle();
      expect(f.savedFollowUps.single.id, 'f1');
      expect(f.savedFollowUps.single.body, {'status': 'done'});
      await tester.tap(_k('co_fu_done_f4'));
      await tester.pumpAndSettle();
      expect(f.savedFollowUps.last.id, 'f4');
      expect(f.savedFollowUps.last.body, {'status': 'open'});
      f.savedFollowUps.clear();
      await tester.tap(_k('co_fu_done_f3'));
      await tester.pumpAndSettle();
      expect(f.savedFollowUps, isEmpty);
    });

    testWidgets('the Overdue panel lists them with how long ago; View All shows only the overdue ones', (tester) async {
      final f = await _pump(tester, tab: 'followups');
      expect(find.text('Overdue (8)'), findsOneWidget);
      expect(_in('co_overdue_f3', '3 days ago'), findsOneWidget);
      expect(_in('co_overdue_f5', '1 day ago'), findsOneWidget);
      await _tap(tester, _k('co_overdue_all_link'));
      expect(f.followUpQueries.last.status, 'overdue');
    });

    testWidgets('the month calendar is a view over the same follow-ups: the month, a dot on the days, month by month, a day narrows every list', (tester) async {
      final f = await _pump(tester, tab: 'followups');
      final now = DateTime.now();
      final first = DateTime(now.year, now.month);
      expect(tester.widget<Text>(_k('co_cal_title')).data, startsWith(_monthName(first.month)));
      expect(f.calendars.last.month, '${first.year}-${first.month.toString().padLeft(2, '0')}');
      expect(_k('co_cal_day_${_d(0)}'), findsOneWidget);
      await _tap(tester, _k('co_cal_next'));
      final next = DateTime(now.year, now.month + 1);
      expect(f.calendars.last.month, '${next.year}-${next.month.toString().padLeft(2, '0')}');
      expect(tester.widget<Text>(_k('co_cal_title')).data, startsWith(_monthName(next.month)));
      await _tap(tester, _k('co_cal_prev'));
      await _tap(tester, _k('co_cal_prev'));
      final prev = DateTime(now.year, now.month - 1);
      expect(f.calendars.last.month, '${prev.year}-${prev.month.toString().padLeft(2, '0')}');
      await _tap(tester, _k('co_cal_next'));
      await _tap(tester, _k('co_cal_day_${TeamFilter.day(DateTime(now.year, now.month, 1))}'));
      final shared = _container(tester).read(teamFilterProvider);
      expect([shared.fromDay, shared.toDay], [TeamFilter.day(DateTime(now.year, now.month, 1)), TeamFilter.day(DateTime(now.year, now.month, 1))]);
    });

    testWidgets('adding a follow-up: what and the due day are needed; it is yours unless you pick someone; the payload carries the team, reminder and brand', (tester) async {
      final f = await _pump(tester, tab: 'followups');
      await _tap(tester, _k('co_fu_new'));
      await tester.tap(_k('co_fu_save'));
      await tester.pumpAndSettle();
      expect(find.text('Say what needs following up.'), findsOneWidget);
      await tester.enterText(_k('co_fu_item'), 'Confirm the venue');
      await tester.tap(_k('co_fu_save'));
      await tester.pumpAndSettle();
      expect(find.text('Choose the day it is due.'), findsOneWidget);
      await tester.enterText(_k('co_fu_related'), 'Brand Shoot');
      await tester.tap(_k('co_fu_dept'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Production').last);
      await tester.pumpAndSettle();
      await tester.tap(_k('co_fu_due'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(_k('co_fu_reminder'));
      await tester.pumpAndSettle();
      await tester.tap(_k('co_fu_save'));
      await tester.pumpAndSettle();
      final b = f.savedFollowUps.single.body;
      expect(f.savedFollowUps.single.id, isNull);
      expect([b['item'], b['relatedTo'], b['department'], b['reminder'], b['brand'], b['ownerId']], ['Confirm the venue', 'Brand Shoot', 'Production', true, 'main', 'm1']);
      expect(b['dueDate'], TeamFilter.day(DateTime.now()));
      expect(b.containsKey('status'), isFalse);
    });

    testWidgets('editing opens it filled in and sends the change with its id; a refusal shows in the form', (tester) async {
      final f = await _pump(tester, tab: 'followups');
      await _tap(tester, _k('co_fu_row_f2'));
      expect(find.text('Edit follow-up'), findsOneWidget);
      expect(tester.widget<TextField>(_k('co_fu_item')).controller!.text, 'Share revised video (v2)');
      f.refuse = const TeamRefusal('The due date must be a real day.');
      await tester.enterText(_k('co_fu_item'), 'Share revised video (v3)');
      await tester.tap(_k('co_fu_save'));
      await tester.pumpAndSettle();
      expect(find.text('The due date must be a real day.'), findsOneWidget);
      f.refuse = null;
      await tester.tap(_k('co_fu_save'));
      await tester.pumpAndSettle();
      expect(f.savedFollowUps.single.id, 'f2');
      expect(f.savedFollowUps.single.body['item'], 'Share revised video (v3)');
      expect(f.savedFollowUps.single.body['ownerId'], 'm1');
      expect(f.savedFollowUps.single.body.containsKey('status'), isFalse, reason: 'the status did not change');
    });

    testWidgets('Export CSV carries the owner cut; empty and failing states', (tester) async {
      final f = await _pump(tester, tab: 'followups');
      await _pickMenu(tester, 'co_fu_owner_pill', 'Abhiram');
      await _tap(tester, _k('co_export_followups'));
      expect(f.exports.single.type, 'followups');
      expect(f.exports.single.extra, {'ownerId': 'm2'});
      await _pump(tester, tab: 'followups', fake: _FakeCoord()..followUpsJson = {'kpis': {}, 'items': [], 'total': 0, 'overdue': {'total': 0, 'items': []}});
      expect(find.textContaining('No follow-ups in this period'), findsOneWidget);
      expect(find.text('Nothing is overdue.'), findsOneWidget);
    });
  });

  group('what the service asks the server for', () {
    Future<List<RequestOptions>> capture(Future<void> Function(MarketingCoordinationService s) run, {String body = '{}'}) async {
      final seen = <RequestOptions>[];
      await run(MarketingCoordinationService(Dio()..httpClientAdapter = _Capture(seen, body: body)));
      return seen;
    }

    final f = TeamFilter(from: DateTime(2026, 11, 1), to: DateTime(2026, 11, 30), brand: TeamBrand.kerala);

    test('every read carries the shared range and brand; the department only when one is chosen', () async {
      final reqs = await capture((s) async {
        await s.overview(f, 'Sales', const OverviewOptions(by: 'receiving', upcoming: 'month'));
        await s.requests(f, 'all', const RequestQuery(scope: 'team', status: 'overdue', priority: 'high', q: ' reel ', page: 2));
        await s.board(f, 'all');
        await s.approvals(f, 'HR', const ApprovalQuery(status: 'in_review', q: 'x', page: 3));
        await s.meetings(f, 'all', const MeetingQuery(status: 'to_close', q: 'sky'));
        await s.followUps(f, 'all', const FollowUpQuery(status: 'overdue', ownerId: 'm1', q: 'v', page: 2));
        await s.followUpCalendar(f, 'all', '2026-11', ownerId: 'm1');
        await s.export('approvals', f, 'IT', extra: {'kind': 'handover'});
      }, body: '{"kpis":{},"items":[],"stages":[],"days":[]}');
      expect(reqs.map((r) => r.path), [
        '/marketing/coordinations/overview', '/marketing/coordinations/requests', '/marketing/coordinations/interdepartment', '/marketing/coordinations/approvals',
        '/marketing/coordinations/meetings', '/marketing/coordinations/followups', '/marketing/coordinations/followups/calendar', '/marketing/coordinations/export/approvals',
      ]);
      for (final r in reqs) {
        expect(r.queryParameters, containsPair('from', '2026-11-01'), reason: r.path);
        expect(r.queryParameters, containsPair('to', '2026-11-30'), reason: r.path);
        expect(r.queryParameters, containsPair('brand', 'kerala'), reason: r.path);
      }
      expect(reqs[0].queryParameters, containsPair('dept', 'Sales'));
      expect(reqs[0].queryParameters, containsPair('by', 'receiving'));
      expect(reqs[0].queryParameters, containsPair('upcoming', 'month'));
      expect(reqs[1].queryParameters.containsKey('dept'), isFalse, reason: '"all" is not a filter');
      expect(reqs[1].queryParameters, containsPair('scope', 'team'));
      expect(reqs[1].queryParameters, containsPair('status', 'overdue'));
      expect(reqs[1].queryParameters, containsPair('priority', 'high'));
      expect(reqs[1].queryParameters, containsPair('q', 'reel'));
      expect(reqs[1].queryParameters, containsPair('page', 2));
      expect(reqs[3].queryParameters, containsPair('status', 'in_review'));
      expect(reqs[3].queryParameters, containsPair('dept', 'HR'));
      expect(reqs[4].queryParameters, containsPair('status', 'to_close'));
      expect(reqs[5].queryParameters, containsPair('ownerId', 'm1'));
      expect(reqs[6].queryParameters, containsPair('month', '2026-11'));
      expect(reqs[6].queryParameters, containsPair('ownerId', 'm1'));
      expect(reqs[7].queryParameters, containsPair('kind', 'handover'));
    });

    test('"all" statuses and priorities and empty searches are not sent', () async {
      final reqs = await capture((s) async {
        await s.requests(f, 'all', const RequestQuery());
        await s.meetings(f, 'all', const MeetingQuery());
        await s.followUps(f, 'all', const FollowUpQuery());
      }, body: '{"kpis":{},"items":[]}');
      for (final r in reqs) {
        for (final k in ['status', 'priority', 'q', 'ownerId']) {
          expect(r.queryParameters.containsKey(k), isFalse, reason: '${r.path} $k');
        }
      }
    });

    test('writes post, put or delete by whether there is an id; moves, decisions and follow-ups have their own paths', () async {
      final reqs = await capture((s) async {
        await s.saveRequest({'title': 'x'});
        await s.saveRequest({'title': 'y'}, id: 'r1');
        await s.moveRequest('r1', 'in_review');
        await s.deleteRequest('r1');
        await s.saveApproval({'title': 'x'});
        await s.saveApproval({'title': 'y'}, id: 'a1');
        await s.decideApproval('a1', 'reject', note: ' Over the cap ');
        await s.decideApproval('a1', 'approve');
        await s.deleteApproval('a1');
        await s.saveMeeting({'title': 'x'});
        await s.saveMeeting({'title': 'y'}, id: 'mt1');
        await s.deleteMeeting('mt1');
        await s.actionItemToFollowUp('mt1', 'i1');
        await s.saveFollowUp({'item': 'x'});
        await s.saveFollowUp({'item': 'y'}, id: 'f1');
        await s.deleteFollowUp('f1');
      }, body: '{"followUp":{"id":"f"}}');
      expect(reqs.map((r) => '${r.method} ${r.path.replaceFirst('/marketing/coordinations', '')}'), [
        'POST /requests', 'PUT /requests/r1', 'POST /requests/r1/move', 'DELETE /requests/r1',
        'POST /approvals', 'PUT /approvals/a1', 'POST /approvals/a1/decide', 'POST /approvals/a1/decide', 'DELETE /approvals/a1',
        'POST /meetings', 'PUT /meetings/mt1', 'DELETE /meetings/mt1', 'POST /meetings/mt1/action-items/i1/follow-up',
        'POST /followups', 'PUT /followups/f1', 'DELETE /followups/f1',
      ]);
      expect(reqs[2].data, {'stage': 'in_review'});
      expect(reqs[6].data, {'decision': 'reject', 'note': 'Over the cap'});
      expect(reqs[7].data, {'decision': 'approve'}, reason: 'no note, no note field');
    });

    test('a server refusal comes back as its own words; anything else is a friendly error', () async {
      final dio = Dio()..httpClientAdapter = _Capture([], status: 403, body: '{"message":"Only the Marketing Manager or Admin can decide an approval."}');
      await expectLater(MarketingCoordinationService(dio).decideApproval('a1', 'approve'), throwsA(isA<TeamRefusal>().having((e) => e.message, 'message', 'Only the Marketing Manager or Admin can decide an approval.').having((e) => e.status, 'status', 403)));
      final conflict = Dio()..httpClientAdapter = _Capture([], status: 409, body: '{"message":"That action item is already a follow-up."}');
      await expectLater(MarketingCoordinationService(conflict).actionItemToFollowUp('mt1', 'i1'), throwsA(isA<TeamRefusal>()));
      final broken = Dio()..httpClientAdapter = _Capture([], status: 500, body: '{"message":"boom"}');
      await expectLater(MarketingCoordinationService(broken).saveRequest({'title': 'x'}), throwsA(isNot(isA<TeamRefusal>())));
    });
  });

  group('a phone', () {
    testWidgets('every tab fits a 390-wide screen without overflow, with data in it', (tester) async {
      await _pump(tester, size: const Size(390, 3600));
      expect(tester.takeException(), isNull);
      for (final t in ['requests', 'interdepartment', 'approvals', 'meetings', 'followups', 'overview']) {
        await _tap(tester, _k('co_tab_$t'));
        expect(tester.takeException(), isNull, reason: t);
        expect(_k({'requests': 'coord_requests_list', 'interdepartment': 'coord_board_list', 'approvals': 'coord_approvals_list', 'meetings': 'coord_meetings_list', 'followups': 'coord_followups_list', 'overview': 'coord_overview_list'}[t]!), findsOneWidget, reason: '$t really opened');
      }
    });

    testWidgets('the forms fit a phone as sheets, with their full content', (tester) async {
      await _pump(tester, size: const Size(390, 900));
      await _tap(tester, _k('co_new_request'));
      expect(tester.takeException(), isNull, reason: 'request');
      await tester.tap(_k('co_req_cancel'));
      await tester.pumpAndSettle();
      await _tap(tester, _k('co_tab_approvals'));
      await _tap(tester, _k('co_ap_new'));
      expect(tester.takeException(), isNull, reason: 'approval');
      await tester.tap(_k('co_ap_cancel'));
      await tester.pumpAndSettle();
      await _tap(tester, _k('co_tab_meetings'));
      await _tap(tester, _k('co_mt_new'));
      expect(tester.takeException(), isNull, reason: 'meeting');
      await tester.tap(_k('co_mt_cancel'));
      await tester.pumpAndSettle();
      await _tap(tester, _k('co_tab_followups'));
      await _tap(tester, _k('co_fu_new'));
      expect(tester.takeException(), isNull, reason: 'follow-up');
    });

    testWidgets('the meeting closing form and the decision dialog fit a phone', (tester) async {
      await _pump(tester, tab: 'meetings', size: const Size(390, 900));
      await _tap(tester, _k('co_mt_mt2'));
      await _tap(tester, _k('co_mt_complete'));
      expect(tester.takeException(), isNull);
      await tester.tap(_k('co_mt_cancel'));
      await tester.pumpAndSettle();
      await _tap(tester, _k('co_tab_approvals'));
      await _tap(tester, _k('co_ap_approve_a1'));
      expect(tester.takeException(), isNull);
    });
  });

  // ── the audit's fixes (T10, C2, C3) ─────────────────────────────────────────
  group('audit fixes', () {
    test('a team task row reads its own status; an approval says who it was escalated to', () {
      final r = CoordRequestRow.fromJson(_teamTaskRow('t9'));
      expect([r.isTask, r.taskStatus, rowStatusLabel(r), r.link], [true, 'blocked', 'Blocked', '/marketing/team?tab=tasks']);
      expect(rowStatusLabel(CoordRequestRow.fromJson(_req('r1'))), 'In Progress');
      final a = ApprovalRow.fromJson({..._approval('a9', status: 'escalated'), 'escalatedToLabel': 'Escalated to Anjali (CEO)', 'escalatedBy': 'Meera'});
      expect([a.escalatedToLabel, a.escalatedBy], ['Escalated to Anjali (CEO)', 'Meera']);
      expect(ApprovalRow.fromJson(_approval('a1')).escalatedToLabel, '');
      expect(RequestList.fromJson({..._requests(), 'teamTasks': 2}).teamTasks, 2);
    });

    testWidgets('Requests & Tasks: a Team Dashboard task is marked, moves through its own statuses (through the Team Dashboard), and opens as a task', (tester) async {
      final team = _TeamTasks();
      final f = _FakeCoord()..requestsJson = {..._requests(), 'teamTasks': 1, 'items': [..._requests()['items'] as List, _teamTaskRow('t9')]};
      await _pump(tester, tab: 'requests', fake: f, team: team);
      expect(find.text('Team task'), findsOneWidget);
      expect(_in('co_row_t9', 'Blocked'), findsOneWidget);
      expect(find.textContaining('the strip above counts requests only'), findsOneWidget);
      await _tap(tester, _k('co_menu_t9'));
      await tester.pumpAndSettle();
      expect(find.text('Open in Team Dashboard'), findsOneWidget);
      await tester.tap(find.text('Mark Completed'));
      await tester.pumpAndSettle();
      expect(team.saved.single.id, 't9');
      expect(team.saved.single.body, {'status': 'completed'});
      expect(f.savedRequests, isEmpty, reason: 'it is not a request: the Coordinations endpoint is not used');
      await _tap(tester, _k('co_row_t9'));
      await tester.pumpAndSettle();
      expect(_k('co_task_open_team'), findsOneWidget);
      expect(_k('co_req_title'), findsNothing, reason: 'not the request form');
    });

    testWidgets('Approvals: an escalated one says who it went up to', (tester) async {
      final f = _FakeCoord()..approvalsJson = {..._approvals(), 'items': [{..._approval('a4', title: 'Billboard on MG Road', status: 'escalated'), 'escalatedToLabel': 'Escalated to Anjali (CEO) and 2 Marketing Managers', 'escalatedBy': 'Meera'}]};
      await _pump(tester, tab: 'approvals', fake: f);
      expect(_k('co_ap_escalated_a4'), findsOneWidget);
      expect(find.text('Escalated to Anjali (CEO) and 2 Marketing Managers'), findsOneWidget);
    });

    testWidgets('Overview: Export CSV asks the server for the Overview\'s own rows', (tester) async {
      final f = await _pump(tester);
      await _tap(tester, _k('co_export_overview'));
      expect(f.exports.single.type, 'overview');
    });
  });
}

String _monthName(int m) => const ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'][m - 1];
