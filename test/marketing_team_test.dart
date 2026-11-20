import 'package:nizan_crm/features/marketing/services/marketing_reports_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:nizan_crm/core/theme/app_theme.dart';
import 'package:nizan_crm/features/marketing/data/team_models.dart';
import 'package:nizan_crm/features/marketing/presentation/kit/mkt_kit.dart';
import 'package:nizan_crm/features/marketing/presentation/team/log_activity_sheet.dart';
import 'package:nizan_crm/features/marketing/presentation/team/team_activity_tab.dart';
import 'package:nizan_crm/features/marketing/presentation/team/team_dashboard_screen.dart';
import 'package:nizan_crm/features/marketing/presentation/team/team_overview_tab.dart';
import 'package:nizan_crm/features/marketing/presentation/team/team_reports_tabs.dart';
import 'package:nizan_crm/features/marketing/services/team_service.dart';
import 'package:dio/dio.dart';

import 'fakes/marketing_reports_fake.dart';

// The Marketing Team Dashboard (Overview, Team Activity, Tasks, Timesheet, Performance, Attendance, Reports) and the Log Activity form.

Map<String, dynamic> _feed(String id, {String member = 'Preethi', String work = 'Edited the bridal reel', String status = 'completed', String kind = 'task', int minutes = 120, String project = 'Bridal Campaign', String brand = 'main'}) => {
      'id': id, 'memberId': 'm1', 'member': member, 'workedOn': work, 'at': '2026-11-12T05:00:00.000Z', 'day': '2026-11-12', 'projectLabel': project, 'kind': kind, 'status': status, 'minutes': minutes, 'brand': brand, 'group': 'Content', 'legacy': false,
    };

Map<String, dynamic> _overview() => {
      'from': '2026-11-09', 'to': '2026-11-15', 'brand': 'all', 'today': '2026-11-12',
      'kpis': {'members': 2, 'membersJoined': 1, 'tasksCompleted': 42, 'tasksCompletedChange': 33, 'inProgress': 12, 'pendingBlocked': 4, 'activityRate': 94, 'onTimeDelivery': 87},
      'members': [
        {'memberId': 'm1', 'name': 'Preethi', 'shortName': 'Preethi', 'role': 'Brand Manager', 'tasks': 8, 'completed': 8, 'progress': 100, 'state': 'Active'},
        {'memberId': 'm2', 'name': 'Ashique', 'shortName': 'Ashique', 'role': 'Videographer', 'tasks': 5, 'completed': 4, 'progress': 80, 'state': 'On Shoot'},
      ],
      'todayFeed': [_feed('a1'), _feed('a2', member: 'Ashique', work: 'Shot the studio tour', kind: 'shoot', status: 'in_progress')],
      'todayDay': '2026-11-12',
      'workload': [{'group': 'Content', 'count': 18, 'pct': 28}, {'group': 'Campaigns', 'count': 14, 'pct': 22}],
      'totalItems': 64,
      'progressByCategory': [{'group': 'Content', 'total': 10, 'completed': 9, 'pct': 90}],
      'trend': [for (var i = 0; i < 7; i++) {'day': '2026-11-${(9 + i).toString().padLeft(2, '0')}', 'completed': i, 'activityPct': i == 6 ? null : 80}],
      'attendance': {'day': '2026-11-12', 'present': 7, 'onShoot': 1, 'onLeave': 0, 'absent': 0},
      'deadlines': [{'id': 'd1', 'title': 'Bridal Campaign – Final Assets', 'project': 'Bridal Campaign', 'dueDate': '2026-11-13', 'assignee': 'Preethi', 'priority': 'high'}],
      'recentUpdates': [_feed('a1')],
      'insights': ['Team completed 42 tasks (+33% against the previous period).', 'Overall activity rate is 94%.'],
    };

Map<String, dynamic> _task(String id, {String title = 'Studio tour reel', String status = 'in_progress', int progress = 40, String priority = 'high', String? due = '2026-11-14', String assignee = 'Preethi'}) => {
      'id': id, 'title': title, 'description': '', 'assigneeId': 'm1', 'assignee': assignee, 'brand': 'main', 'group': 'Content', 'projectLabel': 'Studio Tour', 'isDeliverable': false, 'dueDate': due, 'priority': priority, 'status': status, 'progress': progress, 'overdue': false, 'comments': [],
    };

Map<String, dynamic> _setup({bool canEdit = true, bool self = true, bool manager = false, String notice = '', bool shoots = true, bool links = true}) => {
      'member': {'id': 'm1', 'name': 'Preethi'}, 'self': self, 'canLogForOthers': manager, 'members': manager ? [{'id': 'm1', 'name': 'Preethi'}, {'id': 'm2', 'name': 'Ashique'}] : [], 'date': '2026-11-12',
      'groups': [{'id': 'g1', 'name': 'Content', 'metrics': [{'id': 'mt1', 'name': 'Reels edited', 'unitType': 'count', 'maxPerDay': 6}, {'id': 'mt2', 'name': 'Stories posted', 'unitType': 'count'}]}],
      'tasks': [{'id': 't1', 'title': 'Studio tour reel', 'dueDate': '2026-11-14', 'status': 'in_progress', 'progress': 40}],
      'projects': [{'id': 'p1', 'name': 'Bridal Campaign'}, {'id': 'p2', 'name': 'Studio Tour'}],
      'campaigns': links ? [{'id': 'c1', 'title': 'Festive Offers', 'status': 'active'}] : [],
      'initiatives': links ? [{'id': 'i1', 'title': 'CRM & Lead Automation', 'status': 'active'}] : [],
      'devProjects': links ? [{'id': 'd1', 'name': 'Website v2', 'status': 'in_progress'}] : [],
      'shoots': shoots ? [{'id': 'sh1', 'title': 'Bridal Transformation', 'brand': 'main', 'shootDate': '2026-11-14', 'status': 'planned'}] : [],
      'logs': [{'id': 'l1', 'workedOn': 'Edited the bridal reel', 'loggedAt': '2026-11-12T05:00:00.000Z', 'brand': 'main', 'kind': 'task', 'status': 'completed', 'timeSpentMinutes': 120, 'projectLabel': 'Bridal Campaign', 'values': [], 'attachments': []}],
      'totals': {'hours': 2, 'minutes': 120, 'values': []},
      'canEdit': canEdit, 'notice': notice,
    };

class _FakeTeam extends MarketingTeamService {
  _FakeTeam() : super(Dio());
  Map<String, dynamic> overviewJson = _overview();
  Map<String, dynamic> setupJson = _setup();
  List<Map<String, dynamic>> tasksJson = [_task('t1'), _task('t2', title: 'Festive offers ad set', status: 'blocked', progress: 10, priority: 'medium', due: null), _task('t3', title: 'Monthly report', status: 'completed', progress: 100, priority: 'low')];
  final filters = <TeamFilter>[];
  final savedLogs = <({LogDraft draft, String? id})>[];
  final savedTasks = <({Map<String, dynamic> body, String? id})>[];
  final deletedLogs = <String>[];
  TeamRefusal? refuse;
  bool overviewFails = false;

  @override
  Future<TeamOverview> overview(TeamFilter f) async {
    filters.add(f);
    if (overviewFails) throw Exception('boom');
    return TeamOverview.fromJson(overviewJson);
  }

  final activityQueries = <ActivityQuery>[];

  @override
  Future<TeamActivityFeed> activity(TeamFilter f, {ActivityQuery q = const ActivityQuery(), int limit = 100, int page = 1}) async {
    activityQueries.add(q);
    // the server cuts the feed (kind / category / project / member); the views and the summary are always the whole period
    final all = [_feed('a1'), _feed('a2', kind: 'meeting', work: 'Campaign review', status: 'in_progress'), _feed('a3', brand: 'kerala', work: 'Kerala story')];
    final items = all.where((a) => q.kind == null || a['kind'] == q.kind!.wire).toList();
    return TeamActivityFeed.fromJson({
      'summary': {'day': '2026-11-12', 'logged': 3, 'completed': 2, 'inProgress': 1, 'meetings': 1, 'minutes': 195},
      'total': items.length,
      'items': items,
      'views': {
        'byMember': [{'key': 'm1', 'label': 'Preethi', 'logs': 2, 'minutes': 240, 'completed': 2}, {'key': 'm2', 'label': 'Ashique', 'logs': 1, 'minutes': 120, 'completed': 0}],
        'byProject': [{'key': 'label:bridal campaign', 'label': 'Bridal Campaign', 'logs': 3, 'minutes': 360, 'completed': 2}],
        'byCategory': [{'key': 'g1', 'label': 'Content', 'logs': 2, 'minutes': 240, 'completed': 2}, {'key': 'others', 'label': 'Others', 'logs': 1, 'minutes': 120, 'completed': 0}],
      },
    });
  }

  @override
  Future<DailyLogs> logs(TeamFilter f, {int page = 1, int limit = 50}) async => DailyLogs.fromJson({
        'total': 1,
        'totalMinutes': 120,
        'items': [{..._feed('a1'), 'completed': 'Reel 1 and 2', 'pending': 'Reel 3', 'nextPriority': 'Stories', 'counts': [{'metric': 'Reels edited', 'value': 2, 'details': ''}]}],
      });

  final workModes = <({WorkMode? mode, String? day, String? memberId})>[];

  @override
  Future<void> setWorkMode(WorkMode? mode, {String? day, String? memberId}) async {
    if (refuse != null) throw refuse!;
    workModes.add((mode: mode, day: day, memberId: memberId));
  }

  @override
  Future<Timesheet> timesheet(TeamFilter f) async => Timesheet.fromJson({
        'days': ['2026-11-11', '2026-11-12'], 'totalMinutes': 465, 'totalLabel': '7h 45m',
        'split': [{'group': 'Content', 'minutes': 300, 'pct': 65}, {'group': 'Others', 'minutes': 165, 'pct': 35}],
        'rows': [{'memberId': 'm1', 'name': 'Preethi', 'role': 'Brand Manager', 'minutes': 465, 'label': '7h 45m', 'logs': 4, 'daysLogged': 2, 'byDay': {'2026-11-11': 300, '2026-11-12': 165}, 'status': 'Submitted'}],
        'workSummary': [
          {'memberId': 'm1', 'name': 'Preethi', 'logs': 4, 'minutes': 465, 'completedCount': 3, 'completed': ['Cut the teaser', 'Posted the reel'], 'pending': 'Colour grade', 'nextPriority': 'Stories', 'lastDay': '2026-11-12'},
          {'memberId': 'm2', 'name': 'Ashique', 'logs': 0, 'minutes': 0, 'completedCount': 0, 'completed': [], 'pending': '', 'nextPriority': '', 'lastDay': null},
        ],
        'activityReport': {
          'rows': [{'metricId': 'mt1', 'metric': 'Reels edited', 'group': 'Content', 'unitType': 'count', 'total': 5, 'logs': 2, 'members': 2}, {'metricId': 'mt9', 'metric': 'Ad spend', 'group': 'Campaigns', 'unitType': 'currency', 'total': 1500, 'logs': 1, 'members': 1}],
          'groups': [{'group': 'Content', 'total': 5, 'logs': 2}, {'group': 'Campaigns', 'total': 0, 'logs': 1}],
        },
      });

  @override
  Future<PerformanceData> performance(TeamFilter f) async => PerformanceData.fromJson({
        'kpis': {'activityRate': 94, 'tasksCompleted': 42, 'onTimeDelivery': 87, 'leads': 6, 'leadToBooking': 33.3},
        'rows': [
          {'memberId': 'm1', 'name': 'Preethi', 'role': 'Brand Manager', 'completion': 100, 'onTime': 98, 'activityRate': 100, 'overall': 99, 'tasks': 8, 'leads': 4, 'booked': 1, 'leadToBooking': 25, 'trend': [{'week': 1, 'activityPct': 80, 'completion': 50}, {'week': 2, 'activityPct': 100, 'completion': null}]},
          {'memberId': 'm2', 'name': 'Ashique', 'role': 'Videographer', 'completion': 80, 'onTime': null, 'activityRate': 90, 'overall': 85, 'tasks': 5, 'leads': 2, 'booked': 1, 'leadToBooking': 50, 'trend': [{'week': 1, 'activityPct': 90}, {'week': 2, 'activityPct': 85}]},
        ],
        'trend': [{'week': 1, 'completion': 90, 'onTime': 80, 'tasks': 5}, {'week': 2, 'completion': null, 'onTime': null, 'tasks': 0}],
      });

  Map<String, dynamic> attendanceExtra = {};
  final attendanceFilters = <TeamFilter?>[];

  @override
  Future<AttendanceData> attendance(String date, {TeamFilter? f}) async {
    attendanceFilters.add(f);
    return AttendanceData.fromJson({
      'date': date, 'summary': {'present': 1, 'onShoot': 1, 'wfh': 1, 'onLeave': 0, 'absent': 0}, 'rate': 92, 'linked': 2,
      'rows': [
        {'memberId': 'm1', 'name': 'Preethi', 'role': 'Brand Manager', 'checkIn': '2026-11-12T04:00:00.000Z', 'checkOut': '2026-11-12T12:30:00.000Z', 'hours': 8.5, 'workMode': 'office', 'state': 'Active', 'status': 'Present', 'monthRate': 92, 'daysAttended': 11, 'daysExpected': 12, 'self': true},
        {'memberId': 'm2', 'name': 'Ashique', 'role': 'Videographer', 'workMode': 'on_shoot', 'state': 'On Shoot', 'status': 'Logged', 'monthRate': null},
        {'memberId': 'm3', 'name': 'Jithya', 'role': 'Designer', 'workMode': 'wfh', 'modeSet': true, 'state': 'Work From Home', 'status': 'Set by member', 'monthRate': 100, 'daysAttended': 5, 'daysExpected': 5},
      ],
      ...attendanceExtra,
    });
  }

  final reports = <({String type, String? day, String? month})>[];

  @override
  Future<TeamReport> report(String type, TeamFilter f, {String? day, String? month}) async {
    reports.add((type: type, day: day, month: month));
    return TeamReport.fromJson({'title': type == 'monthly' ? 'Monthly report — 2026-11' : 'Weekly report — 2026-11-09 to 2026-11-15', 'columns': ['Member', 'Logs'], 'rows': [['Preethi', 4]]});
  }

  @override
  Future<LogSetup> logSetup({required String date, String? memberId}) async => LogSetup.fromJson({...setupJson, if (memberId != null) 'self': false}); // another member's day is "not yours"


  final taskScopes = <TaskScope>[];

  @override
  Future<TeamTaskList> tasks(TeamFilter f, {String status = 'all', String priority = 'all', String? q, TaskScope scope = TaskScope.all}) async {
    taskScopes.add(scope);
    final counts = <String, int>{'all': tasksJson.length, 'requests': tasksJson.where((t) => t['source'] == 'request').length};
    for (final t in tasksJson) {
      counts[t['status'] as String] = (counts[t['status']] ?? 0) + 1;
    }
    return TeamTaskList.fromJson({'counts': counts, 'items': tasksJson});
  }

  @override
  Future<List<String>> saveLog(LogDraft draft, {String? id}) async {
    if (refuse != null) throw refuse!;
    savedLogs.add((draft: draft, id: id));
    return const [];
  }

  @override
  Future<void> deleteLog(String id, {String reason = ''}) async => deletedLogs.add(id);

  @override
  Future<TeamTask> saveTask(Map<String, dynamic> body, {String? id}) async {
    if (refuse != null) throw refuse!;
    savedTasks.add((body: body, id: id));
    return TeamTask.fromJson(_task(id ?? 'new', title: body['title'] as String));
  }
}

Future<_FakeTeam> _pump(WidgetTester tester, Widget screen, {_FakeTeam? fake, Size size = const Size(1280, 1400), FakeMarketingReports? reports}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final f = fake ?? _FakeTeam();
  final overrides = <Override>[marketingTeamServiceProvider.overrideWithValue(f), marketingReportsServiceProvider.overrideWithValue(reports ?? FakeMarketingReports())];
  await tester.pumpWidget(ProviderScope(overrides: overrides, child: MaterialApp(theme: AppTheme.lightTheme, home: Scaffold(body: screen))));
  await tester.pumpAndSettle();
  return f;
}

Finder _k(String key) => find.byKey(Key(key));

/// Bring a control of a form into view, then tap it. The form's fields scroll (typing scrolls the field being typed in), so the
/// control may be above or below the visible part: move the form's own scroll view until the control is inside it.
Future<void> _tapV(WidgetTester tester, String key) async {
  final target = _k(key);
  await tester.pumpAndSettle(); // typing in a field scrolls it into view a frame later: let that happen before measuring
  final dialogScroll = find.descendant(of: find.byType(Dialog), matching: find.byType(Scrollable));
  final inForm = find.ancestor(of: target, matching: find.byType(SingleChildScrollView)).evaluate().isNotEmpty && dialogScroll.evaluate().isNotEmpty;
  if (inForm) {
    final state = tester.state<ScrollableState>(dialogScroll.first);
    final viewport = tester.getRect(find.byWidget(state.widget).first);
    for (var i = 0; i < 6; i++) {
      final c = tester.getCenter(target).dy;
      if (c > viewport.top + 40 && c < viewport.bottom - 40) break;
      final p = state.position;
      p.jumpTo((p.pixels + (c - viewport.center.dy)).clamp(p.minScrollExtent, p.maxScrollExtent));
      await tester.pump();
    }
  } else {
    await tester.ensureVisible(target);
  }
  await tester.pumpAndSettle();
  await tester.tap(target);
}

String _text(WidgetTester t, Finder f) => t.widget<Text>(f).data!;

void main() {
  group('how the server\'s payloads read', () {
    test('this week runs Monday to Sunday, whatever day it is', () {
      for (final d in [DateTime(2026, 11, 9), DateTime(2026, 11, 12), DateTime(2026, 11, 15)]) {
        final f = TeamFilter.thisWeek(now: d);
        expect(f.fromDay, '2026-11-09', reason: '$d');
        expect(f.toDay, '2026-11-15', reason: '$d');
      }
    });

    test('a filter is compared by its days, brand and member — and sends the brand and member the server expects', () {
      final a = TeamFilter(from: DateTime(2026, 11, 9, 8), to: DateTime(2026, 11, 15), brand: TeamBrand.kerala, memberId: 'm1');
      final b = TeamFilter(from: DateTime(2026, 11, 9, 20), to: DateTime(2026, 11, 15), brand: TeamBrand.kerala, memberId: 'm1');
      expect(a, b);
      expect(a == a.copyWith(brand: TeamBrand.main), isFalse);
      expect(a.query, {'from': '2026-11-09', 'to': '2026-11-15', 'brand': 'kerala', 'memberId': 'm1'});
      expect(a.copyWith(clearMember: true).query.containsKey('memberId'), isFalse);
    });

    test('minutes read as hours and minutes', () {
      expect(hoursLabel(465), '7h 45m');
      expect(hoursLabel(120), '2h');
      expect(hoursLabel(45), '45m');
      expect(hoursLabel(0), '—');
    });

    test('the overview: KPIs, the member rows, the feed and the insights', () {
      final o = TeamOverview.fromJson(_overview());
      expect(o.kpis.tasksCompleted, 42);
      expect(o.kpis.tasksCompletedChange, 33);
      expect(o.members.first.state, 'Active');
      expect(o.todayFeed.first.workedOn, 'Edited the bridal reel');
      expect(o.workload.first.group, 'Content');
      expect(o.trend.last.activityPct, isNull);
      expect(o.insights.length, 2);
    });

    test('unknown or missing parts do not crash a read (an older server, a brand-new field)', () {
      final o = TeamOverview.fromJson({'kpis': {}, 'members': [], 'insights': null});
      expect(o.kpis.members, 0);
      expect(TeamFeedItem.fromJson({'kind': 'dance', 'status': 'odd', 'brand': 'x'}).kind, ActivityKind.task);
      expect(LogSetup.fromJson(const {}).canEdit, isTrue);
    });

    test('a log draft sends only what was counted, with its details, and only real links', () {
      final json = LogDraft(entryDate: '2026-11-12', workedOn: 'Edited', minutes: 90, counts: {'mt1': 3, 'mt2': 0}, details: {'mt1': 'reel 1, 2, 3'}, attachments: ['https://drive.google.com/x', '  '], taskId: 't1', taskProgress: 60, overrideReason: ' because ').toJson();
      expect(json['timeSpentMinutes'], 90);
      expect(json['values'], [{'metricId': 'mt1', 'value': 3, 'details': 'reel 1, 2, 3'}]);
      expect(json['attachments'], [{'url': 'https://drive.google.com/x'}]);
      expect(json['taskId'], 't1');
      expect(json['taskProgress'], 60);
      expect(json['overrideReason'], 'because');
      expect(json.containsKey('memberId'), isFalse);
    });
  });

  group('the Team Dashboard', () {
    testWidgets('has the seven tabs the document draws, and the Log Activity button', (tester) async {
      await _pump(tester, const TeamDashboardScreen());
      for (final t in kTeamTabs) {
        expect(_k('team_tab_${t.$1}'), findsOneWidget, reason: t.$1);
      }
      expect(kTeamTabs.map((t) => t.$1).toList(), ['overview', 'activity', 'tasks', 'timesheet', 'performance', 'attendance', 'reports']);
      expect(_k('team_log_button'), findsOneWidget);
      expect(_k('mkt_title'), findsOneWidget);
    });

    testWidgets('Overview: the KPI strip counts what the server counted', (tester) async {
      await _pump(tester, const TeamDashboardScreen());
      expect(find.descendant(of: _k('team_kpi_completed'), matching: find.text('42')), findsOneWidget);
      expect(find.descendant(of: _k('team_kpi_completed'), matching: find.text('↑ +33% vs before')), findsOneWidget);
      expect(find.descendant(of: _k('team_kpi_members'), matching: find.text('↑ +1 this month')), findsOneWidget);
      expect(find.descendant(of: _k('team_kpi_progress'), matching: find.text('12')), findsOneWidget);
      expect(find.descendant(of: _k('team_kpi_blocked'), matching: find.text('4')), findsOneWidget);
      expect(find.descendant(of: _k('team_kpi_activity'), matching: find.text('94%')), findsOneWidget);
      expect(find.descendant(of: _k('team_kpi_ontime'), matching: find.text('87%')), findsOneWidget);
    });

    testWidgets('Overview: member rows with their state, today\'s feed, the workload total, deadlines and insights', (tester) async {
      await _pump(tester, const TeamDashboardScreen());
      expect(_k('team_member_m1'), findsOneWidget);
      expect(find.descendant(of: _k('team_member_m2'), matching: find.text('On Shoot')), findsOneWidget);
      expect(find.descendant(of: _k('team_member_m1'), matching: find.text('Brand Manager')), findsOneWidget);
      expect(_k('team_feed_a1'), findsOneWidget);
      expect(find.textContaining('Preethi · Edited the bridal reel'), findsWidgets);
      expect(_text(tester, _k('team_workload_total')), '64');
      expect(_k('team_deadline_d1'), findsOneWidget);
      expect(find.descendant(of: _k('team_insights'), matching: find.textContaining('Team completed 42 tasks')), findsOneWidget);
      expect(find.descendant(of: _k('team_attendance_strip'), matching: find.text('7')), findsOneWidget);
    });

    testWidgets('Overview: nothing logged yet says so, and a failing source says so with Try again', (tester) async {
      final fake = _FakeTeam()..overviewJson = {..._overview(), 'todayFeed': [], 'members': [], 'workload': [], 'deadlines': [], 'recentUpdates': []};
      await _pump(tester, const TeamDashboardScreen(), fake: fake);
      expect(find.text('Nothing has been logged for the day yet.'), findsOneWidget);
      expect(find.textContaining('No team members yet'), findsOneWidget);
      final down = _FakeTeam()..overviewFails = true;
      await _pump(tester, const TeamDashboardScreen(), fake: down);
      expect(find.text('Try again'), findsOneWidget);
    });

    testWidgets('the brand filter re-reads the dashboard for that brand; the range stays', (tester) async {
      final fake = await _pump(tester, const TeamDashboardScreen());
      expect(fake.filters.last.brand, TeamBrand.all);
      await tester.tap(_k('team_brand_pill'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kerala').last);
      await tester.pumpAndSettle();
      expect(fake.filters.last.brand, TeamBrand.kerala);
      expect(fake.filters.last.fromDay, fake.filters.first.fromDay);
    });

    testWidgets('a "View all" link jumps to that tab', (tester) async {
      await _pump(tester, const TeamDashboardScreen());
      await tester.tap(_k('team_feed_view_all'));
      await tester.pumpAndSettle();
      expect(_k('team_activity_summary'), findsOneWidget);
    });

    testWidgets('a tab can be opened from a link (?tab=…)', (tester) async {
      await _pump(tester, const TeamDashboardScreen(initialTab: 'timesheet'));
      expect(_k('team_logs_daily'), findsOneWidget, reason: 'Logs & Timesheet opens on its Daily Logs');
      expect(_k('team_log_a1'), findsOneWidget);
    });

    testWidgets('Team Activity: the feed with its summary, filterable by kind; Kerala work is marked', (tester) async {
      await _pump(tester, const TeamDashboardScreen(initialTab: 'activity'));
      expect(find.descendant(of: _k('team_activity_summary'), matching: find.text('Activities logged')), findsOneWidget);
      expect(_k('team_activity_a1'), findsOneWidget);
      expect(_k('team_activity_a3'), findsOneWidget);
      expect(find.text('Kerala'), findsWidgets);
      final fake = ProviderScope.containerOf(tester.element(_k('team_kind_meeting'))).read(marketingTeamServiceProvider) as _FakeTeam;
      await tester.tap(_k('team_kind_meeting'));
      await tester.pumpAndSettle();
      expect(_k('team_activity_a1'), findsNothing);
      expect(_k('team_activity_a2'), findsOneWidget);
      expect(fake.activityQueries.last.kind, ActivityKind.meeting, reason: 'the kind is cut on the server, not over the first page');
    });

    testWidgets('Logs & Timesheet: hours per person with the daily cells, the total and the split', (tester) async {
      await _pump(tester, const TeamDashboardScreen(initialTab: 'timesheet'));
      await tester.tap(_k('team_logs_timesheet'));
      await tester.pumpAndSettle();
      final table = _k('team_timesheet_table');
      expect(find.descendant(of: table, matching: find.text('Preethi')), findsOneWidget);
      expect(find.descendant(of: table, matching: find.text('7h 45m')), findsOneWidget);
      expect(find.descendant(of: table, matching: find.text('5h')), findsOneWidget);
      expect(find.descendant(of: table, matching: find.text('2h 45m')), findsOneWidget);
      expect(find.descendant(of: table, matching: find.text('Submitted')), findsOneWidget);
      expect(_text(tester, _k('team_timesheet_total')), '7h 45m');
      expect(find.textContaining('65%'), findsOneWidget);
    });

    testWidgets('Performance: the score table, best first, with a dash where nothing was due', (tester) async {
      await _pump(tester, const TeamDashboardScreen(initialTab: 'performance'));
      final table = _k('team_performance_table');
      expect(find.descendant(of: table, matching: find.text('99%')), findsOneWidget);
      expect(find.descendant(of: table, matching: find.text('85%')), findsOneWidget);
      expect(find.descendant(of: table, matching: find.text('—')), findsOneWidget, reason: 'no task of Ashique\'s was due, so there is no on-time figure');
      expect(tester.getTopLeft(find.text('Preethi')).dy, lessThan(tester.getTopLeft(find.text('Ashique')).dy), reason: 'best first');
      expect(find.descendant(of: _k('team_perf_activity'), matching: find.text('94%')), findsOneWidget);
      expect(_k('team_performance_trend'), findsOneWidget);
    });

    testWidgets('Attendance: the day\'s counts, check-in and out, the work mode and the month\'s rate', (tester) async {
      await _pump(tester, const TeamDashboardScreen(initialTab: 'attendance'));
      expect(find.descendant(of: _k('team_att_present'), matching: find.text('1')), findsOneWidget);
      expect(find.descendant(of: _k('team_att_rate'), matching: find.text('92%')), findsOneWidget);
      final table = _k('team_attendance_table');
      expect(find.descendant(of: table, matching: find.text('8.5h')), findsOneWidget);
      expect(find.descendant(of: table, matching: find.text('Office')), findsOneWidget);
      expect(find.descendant(of: table, matching: find.text('On shoot')), findsOneWidget);
      expect(find.descendant(of: table, matching: find.text('On Shoot')), findsOneWidget, reason: 'the status pill');
    });

    testWidgets('Reports: pick one, see its rows, and export', (tester) async {
      await _pump(tester, const TeamDashboardScreen(initialTab: 'reports'));
      await tester.tap(_k('team_report_weekly'));
      await tester.pumpAndSettle();
      expect(find.text('Weekly report — 2026-11-09 to 2026-11-15'), findsOneWidget);
      expect(_k('team_report_table'), findsOneWidget);
      expect(_k('team_report_export'), findsOneWidget);
    });

    testWidgets('a phone (390) and a laptop (1280) both fit, on every tab', (tester) async {
      for (final size in [const Size(390, 900), const Size(1280, 900)]) {
        for (final t in kTeamTabs) {
          await _pump(tester, TeamDashboardScreen(initialTab: t.$1), size: size);
          expect(tester.takeException(), isNull, reason: '${t.$1} at ${size.width}');
        }
      }
    });
  });

  group('Log Activity', () {
    Future<_FakeTeam> openForm(WidgetTester tester, {_FakeTeam? fake}) async {
      final f = await _pump(tester, Builder(builder: (context) => Center(child: ElevatedButton(key: const Key('open'), onPressed: () => showLogActivity(context, date: DateTime(2026, 11, 12)), child: const Text('open')))), fake: fake, size: const Size(1280, 1500));
      await tester.tap(_k('open'));
      await tester.pumpAndSettle();
      return f;
    }

    testWidgets('the header button opens the form, with the document\'s fields', (tester) async {
      await _pump(tester, const TeamDashboardScreen());
      await tester.tap(_k('team_log_button'));
      await tester.pumpAndSettle();
      for (final k in ['log_worked_on', 'log_project', 'log_completed', 'log_pending', 'log_next', 'log_hours', 'log_minutes', 'log_comment', 'log_attach_add', 'log_save']) {
        expect(_k(k), findsOneWidget, reason: k);
      }
      expect(_k('log_count_mt1'), findsOneWidget);
      expect(_k('log_details_mt1'), findsOneWidget, reason: 'a details box sits beside every count');
      expect(_k('log_task'), findsOneWidget);
      expect(find.text('Reels edited'), findsOneWidget);
    });

    testWidgets('it asks what you worked on before anything is sent', (tester) async {
      final f = await openForm(tester);
      await _tapV(tester, 'log_save');
      await tester.pumpAndSettle();
      expect(_text(tester, _k('log_error')), 'Say what you worked on.');
      expect(f.savedLogs, isEmpty);
    });

    testWidgets('24 hours and some minutes is more than a day', (tester) async {
      final f = await openForm(tester);
      await tester.enterText(_k('log_worked_on'), 'Edited a reel');
      await tester.enterText(_k('log_hours'), '24');
      await tester.enterText(_k('log_minutes'), '30');
      await _tapV(tester, 'log_save');
      await tester.pumpAndSettle();
      expect(_text(tester, _k('log_error')), 'A day has only 24 hours.');
      expect(f.savedLogs, isEmpty);
    });

    testWidgets('it will not take more than 24 hours, a bad count or a link that is not a link', (tester) async {
      final f = await openForm(tester);
      await tester.enterText(_k('log_worked_on'), 'Edited a reel');
      await tester.enterText(_k('log_hours'), '25');
      await _tapV(tester, 'log_save');
      await tester.pumpAndSettle();
      expect(_text(tester, _k('log_error')), contains('hours 0–24'));
      await tester.enterText(_k('log_hours'), '2');
      await tester.enterText(_k('log_count_mt1'), '-3');
      await _tapV(tester, 'log_save');
      await tester.pumpAndSettle();
      expect(_text(tester, _k('log_error')), contains('Counts must be numbers'));
      await tester.enterText(_k('log_count_mt1'), '3');
      await _tapV(tester, 'log_attach_add');
      await tester.pump();
      await tester.enterText(_k('log_attach_0'), 'javascript:alert(1)');
      await _tapV(tester, 'log_save');
      await tester.pumpAndSettle();
      expect(_text(tester, _k('log_error')), contains('http'));
      expect(f.savedLogs, isEmpty);
    });

    testWidgets('a filled form is sent once, with the time, status, brand, counts with their details, links and task', (tester) async {
      final f = await openForm(tester);
      await tester.enterText(_k('log_worked_on'), 'Edited the bridal reel');
      await tester.enterText(_k('log_project'), 'Bridal Campaign');
      await tester.enterText(_k('log_completed'), 'Colour grade');
      await tester.enterText(_k('log_pending'), 'Captions');
      await tester.enterText(_k('log_next'), 'Post on Friday');
      await tester.enterText(_k('log_hours'), '2');
      await tester.enterText(_k('log_minutes'), '30');
      await tester.enterText(_k('log_count_mt1'), '3');
      await tester.enterText(_k('log_details_mt1'), 'reels 1, 2, 3');
      await _tapV(tester, 'log_brand_1'); // Kerala
      await _tapV(tester, 'log_kind_post');
      await _tapV(tester, 'log_status_in_progress');
      await _tapV(tester, 'log_attach_add');
      await tester.pump();
      await tester.enterText(_k('log_attach_0'), 'https://drive.google.com/final');
      await tester.pump();
      await _tapV(tester, 'log_save');
      await tester.pumpAndSettle();
      expect(f.savedLogs, hasLength(1));
      final d = f.savedLogs.single.draft;
      expect(d.workedOn, 'Edited the bridal reel');
      expect(d.projectLabel, 'Bridal Campaign');
      expect([d.completed, d.pending, d.nextPriority], ['Colour grade', 'Captions', 'Post on Friday']);
      expect(d.minutes, 150);
      expect([d.brand, d.kind, d.status], [TeamBrand.kerala, ActivityKind.post, WorkStatus.inProgress]);
      expect(d.counts, {'mt1': 3});
      expect(d.details['mt1'], 'reels 1, 2, 3');
      expect(d.attachments, ['https://drive.google.com/final']);
      expect(d.entryDate, '2026-11-12');
      expect(_k('log_save'), findsNothing, reason: 'the form closed');
      expect(_k('log_saved'), findsOneWidget);
    });

    testWidgets('a log can be tied to a task, and its progress goes with it', (tester) async {
      final f = await openForm(tester);
      await tester.enterText(_k('log_worked_on'), 'Shot the studio tour');
      await _tapV(tester, 'log_task');
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Studio tour reel').last);
      await tester.pumpAndSettle();
      await _tapV(tester, 'log_status_in_progress');
      await tester.pump();
      expect(_k('log_task_progress'), findsOneWidget);
      await _tapV(tester, 'log_save');
      await tester.pumpAndSettle();
      expect(f.savedLogs.single.draft.taskId, 't1');
      expect(f.savedLogs.single.draft.taskProgress, 40, reason: 'it starts at the task\'s own progress');
    });

    testWidgets('a log can be tied to a shoot with the stage of work; the shoot\'s progress then moves', (tester) async {
      final f = await openForm(tester);
      await tester.enterText(_k('log_worked_on'), 'Prepared the moodboard');
      expect(_k('log_shoot_stage_production'), findsNothing, reason: 'the stage appears once a shoot is chosen');
      await _tapV(tester, 'log_shoot');
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Bridal Transformation').last);
      await tester.pumpAndSettle();
      await _tapV(tester, 'log_shoot_stage_pre_production');
      await tester.pump();
      await _tapV(tester, 'log_save');
      await tester.pumpAndSettle();
      expect(f.savedLogs.single.draft.shootId, 'sh1');
      expect(f.savedLogs.single.draft.shootStage, 'pre_production');
      expect(f.savedLogs.single.draft.toJson(), containsPair('shootStage', 'pre_production'));
    });

    testWidgets('a log can be tied to a campaign and to a strategic initiative', (tester) async {
      final f = await openForm(tester);
      await tester.enterText(_k('log_worked_on'), 'Updated the ad sets');
      await _tapV(tester, 'log_campaign');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Festive Offers').last);
      await tester.pumpAndSettle();
      await _tapV(tester, 'log_initiative');
      await tester.pumpAndSettle();
      await tester.tap(find.text('CRM & Lead Automation').last);
      await tester.pumpAndSettle();
      await _tapV(tester, 'log_save');
      await tester.pumpAndSettle();
      expect(f.savedLogs.single.draft.campaignId, 'c1');
      expect(f.savedLogs.single.draft.initiativeId, 'i1');
      expect(f.savedLogs.single.draft.toJson(), containsPair('campaignId', 'c1'));
      expect(f.savedLogs.single.draft.toJson(), containsPair('initiativeId', 'i1'));
    });

    testWidgets('with no campaigns or initiatives open there is no picker, and a plain log sends neither', (tester) async {
      final f = await openForm(tester, fake: _FakeTeam()..setupJson = _setup(links: false));
      expect(_k('log_campaign'), findsNothing);
      expect(_k('log_initiative'), findsNothing);
      await tester.enterText(_k('log_worked_on'), 'Plain work');
      await _tapV(tester, 'log_save');
      await tester.pumpAndSettle();
      final json = f.savedLogs.single.draft.toJson();
      expect(json.containsKey('campaignId'), isFalse);
      expect(json.containsKey('initiativeId'), isFalse);
    });

    testWidgets('a log without a shoot sends neither a shoot nor a stage; with no shoots to pick there is no picker', (tester) async {
      final f = await openForm(tester);
      await tester.enterText(_k('log_worked_on'), 'Edited a reel');
      await _tapV(tester, 'log_save');
      await tester.pumpAndSettle();
      expect(f.savedLogs.single.draft.shootId, isNull);
      expect(f.savedLogs.single.draft.shootStage, isNull);
      final json = f.savedLogs.single.draft.toJson();
      expect(json.containsKey('shootId'), isFalse);
      expect(json.containsKey('shootStage'), isFalse);
      await openForm(tester, fake: _FakeTeam()..setupJson = _setup(shoots: false));
      expect(_k('log_shoot'), findsNothing);
    });

    testWidgets('what the server refuses is shown as it says it; "needs a reason" opens the reason box', (tester) async {
      final fake = _FakeTeam()..refuse = const TeamRefusal('A reason is required when logging for someone else or for an older day.', reasonRequired: true, status: 400);
      await openForm(tester, fake: fake);
      await tester.enterText(_k('log_worked_on'), 'Edited a reel');
      expect(_k('log_reason'), findsNothing);
      await _tapV(tester, 'log_save');
      await tester.pumpAndSettle();
      expect(_text(tester, _k('log_error')), contains('A reason is required'));
      expect(_k('log_reason'), findsOneWidget);
      expect(_k('log_save'), findsOneWidget, reason: 'the form stays open so nothing typed is lost');
      expect(tester.widget<TextField>(_k('log_worked_on')).controller!.text, 'Edited a reel');
    });

    testWidgets('a day that cannot be changed (closed month, outside the edit window) says why and cannot be saved', (tester) async {
      final fake = _FakeTeam()..setupJson = _setup(canEdit: false, notice: 'This month is closed. A manager has to reopen it before anything changes.');
      await openForm(tester, fake: fake);
      expect(find.textContaining('This month is closed'), findsOneWidget);
      expect(tester.widget<FilledButton>(_k('log_save')).onPressed, isNull);
    });

    testWidgets('a manager can log for someone else — and must say why', (tester) async {
      final fake = _FakeTeam()..setupJson = _setup(manager: true);
      await openForm(tester, fake: fake);
      expect(_k('log_member'), findsOneWidget);
      await _tapV(tester, 'log_member');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ashique').last);
      await tester.pumpAndSettle();
      await tester.enterText(_k('log_worked_on'), 'Covered the shoot log');
      await _tapV(tester, 'log_save');
      await tester.pumpAndSettle();
      expect(fake.savedLogs, isEmpty, reason: 'no reason given yet');
    });

    testWidgets('a member sees no "Logging for" box', (tester) async {
      await openForm(tester);
      expect(_k('log_member'), findsNothing);
    });

    testWidgets('editing a log opens it filled in and saves over it', (tester) async {
      final f = await _pump(tester, Builder(builder: (context) => Center(child: ElevatedButton(key: const Key('open'), onPressed: () => showLogActivity(context, date: DateTime(2026, 11, 12), editing: const SavedLog(id: 'l1', workedOn: 'Edited the bridal reel', minutes: 150, projectLabel: 'Bridal Campaign', counts: {'mt1': 2}, details: {'mt1': 'a, b'}, status: WorkStatus.inProgress, brand: TeamBrand.kerala)), child: const Text('open')))), size: const Size(1280, 1500));
      await tester.tap(_k('open'));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(_k('log_worked_on')).controller!.text, 'Edited the bridal reel');
      expect(tester.widget<TextField>(_k('log_hours')).controller!.text, '2');
      expect(tester.widget<TextField>(_k('log_minutes')).controller!.text, '30');
      expect(tester.widget<TextField>(_k('log_count_mt1')).controller!.text, '2');
      expect(find.text('Change this log'), findsOneWidget);
      await _tapV(tester, 'log_save');
      await tester.pumpAndSettle();
      expect(f.savedLogs.single.id, 'l1');
      expect(f.savedLogs.single.draft.counts, {'mt1': 2});
    });
  });

  group('My day', () {
    testWidgets('the day\'s logs with their time, a way to add one, and deleting asks first', (tester) async {
      final f = await _pump(tester, const MyDayPanel());
      expect(_k('my_day_log_l1'), findsOneWidget);
      expect(find.text('Edited the bridal reel'), findsOneWidget);
      expect(find.textContaining('1 log · 2h'), findsOneWidget);
      expect(_k('my_day_log'), findsOneWidget);
      await _tapV(tester, 'my_day_delete_l1');
      await tester.pumpAndSettle();
      expect(f.deletedLogs, isEmpty, reason: 'asks first');
      await _tapV(tester, 'my_day_delete_confirm');
      await tester.pumpAndSettle();
      expect(f.deletedLogs, ['l1']);
    });

    testWidgets('cancelling the delete question deletes nothing', (tester) async {
      final f = await _pump(tester, const MyDayPanel());
      await _tapV(tester, 'my_day_delete_l1');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(f.deletedLogs, isEmpty);
      expect(_k('my_day_log_l1'), findsOneWidget);
    });

    testWidgets('an earlier whole-day entry is shown but cannot be edited or deleted', (tester) async {
      final fake = _FakeTeam();
      fake.setupJson = {..._setup(), 'logs': [{'id': 'old', 'workedOn': 'Earlier daily entry', 'loggedAt': '2026-11-11T05:00:00.000Z', 'timeSpentMinutes': 240, 'status': 'completed', 'legacy': true, 'values': [], 'attachments': []}]};
      await _pump(tester, const MyDayPanel(), fake: fake);
      expect(find.text('Earlier entry'), findsOneWidget);
      expect(_k('my_day_edit_old'), findsNothing);
      expect(_k('my_day_delete_old'), findsNothing);
    });

    testWidgets('a day that is locked disables the buttons and says why', (tester) async {
      final fake = _FakeTeam()..setupJson = _setup(canEdit: false, notice: 'This month is closed.');
      await _pump(tester, const MyDayPanel(), fake: fake);
      expect(tester.widget<MktPrimaryButton>(_k('my_day_log')).onPressed, isNull);
      expect(find.text('This month is closed.'), findsOneWidget);
    });
  });

  group('Tasks & Deliverables', () {
    testWidgets('the list, with a status tab for each and its count', (tester) async {
      await _pump(tester, const TeamDashboardScreen(initialTab: 'tasks'));
      expect(find.descendant(of: _k('team_task_status_all'), matching: find.text('3')), findsOneWidget);
      expect(find.descendant(of: _k('team_task_status_blocked'), matching: find.text('1')), findsOneWidget);
      expect(_k('team_task_t1'), findsOneWidget);
      expect(_k('team_task_t3'), findsOneWidget);
      await _tapV(tester, 'team_task_status_blocked');
      await tester.pumpAndSettle();
      expect(_k('team_task_t1'), findsNothing);
      expect(_k('team_task_t2'), findsOneWidget);
    });

    testWidgets('priority and search narrow the list', (tester) async {
      await _pump(tester, const TeamDashboardScreen(initialTab: 'tasks'));
      await tester.enterText(_k('team_task_search'), 'festive');
      await tester.pumpAndSettle();
      expect(_k('team_task_t2'), findsOneWidget);
      expect(_k('team_task_t1'), findsNothing);
      await tester.enterText(_k('team_task_search'), '');
      await tester.pumpAndSettle();
      await _tapV(tester, 'team_task_priority');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Low').last);
      await tester.pumpAndSettle();
      expect(_k('team_task_t3'), findsOneWidget);
      expect(_k('team_task_t1'), findsNothing);
    });

    testWidgets('kanban: a column per status with its count, a card in the right one', (tester) async {
      await _pump(tester, const TeamDashboardScreen(initialTab: 'tasks'));
      await _tapV(tester, 'team_task_view_1');
      await tester.pumpAndSettle();
      expect(_text(tester, _k('team_kanban_count_in_progress')), '1');
      expect(_text(tester, _k('team_kanban_count_blocked')), '1');
      expect(_text(tester, _k('team_kanban_count_not_started')), '0');
      expect(find.descendant(of: _k('team_kanban'), matching: find.text('Festive offers ad set')), findsOneWidget);
    });

    testWidgets('calendar: a task sits on its due date', (tester) async {
      final fake = _FakeTeam();
      final now = DateTime.now();
      final due = '${now.year}-${now.month.toString().padLeft(2, '0')}-15';
      fake.tasksJson = [_task('t1', due: due)];
      await _pump(tester, const TeamDashboardScreen(initialTab: 'tasks'), fake: fake);
      await _tapV(tester, 'team_task_view_2');
      await tester.pumpAndSettle();
      expect(find.descendant(of: _k('team_cal_$due'), matching: find.text('Studio tour reel')), findsOneWidget);
    });

    testWidgets('a new task needs a title; saved, it is sent with its priority, due date and brand', (tester) async {
      final f = await _pump(tester, const TeamDashboardScreen(initialTab: 'tasks'));
      await _tapV(tester, 'team_task_new');
      await tester.pumpAndSettle();
      await _tapV(tester, 'team_task_save');
      await tester.pumpAndSettle();
      expect(_text(tester, _k('team_task_error')), 'Give the task a title.');
      expect(f.savedTasks, isEmpty);
      await tester.enterText(_k('team_task_title'), 'Brand video');
      await _tapV(tester, 'team_task_prio_2'); // low
      await _tapV(tester, 'team_task_brand_1'); // kerala
      await _tapV(tester, 'team_task_deliverable');
      await tester.pump();
      await _tapV(tester, 'team_task_save');
      await tester.pumpAndSettle();
      final body = f.savedTasks.single.body;
      expect([body['title'], body['priority'], body['brand'], body['isDeliverable']], ['Brand video', 'low', 'kerala', true]);
      expect(f.savedTasks.single.id, isNull);
    });

    testWidgets('a task can be tied to a strategic initiative and a development project; none sends null so it can be cleared', (tester) async {
      final f = await _pump(tester, const TeamDashboardScreen(initialTab: 'tasks'));
      await _tapV(tester, 'team_task_new');
      await tester.pumpAndSettle();
      await tester.enterText(_k('team_task_title'), 'Wire the CRM form');
      await _tapV(tester, 'team_task_initiative');
      await tester.pumpAndSettle();
      await tester.tap(find.text('CRM & Lead Automation').last);
      await tester.pumpAndSettle();
      await _tapV(tester, 'team_task_devproject');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Website v2').last);
      await tester.pumpAndSettle();
      await _tapV(tester, 'team_task_save');
      await tester.pumpAndSettle();
      expect(f.savedTasks.single.body['initiativeId'], 'i1');
      expect(f.savedTasks.single.body['devProjectId'], 'd1');
      await _tapV(tester, 'team_task_new');
      await tester.pumpAndSettle();
      await tester.enterText(_k('team_task_title'), 'Plain task');
      await _tapV(tester, 'team_task_save');
      await tester.pumpAndSettle();
      expect(f.savedTasks.last.body, containsPair('initiativeId', null));
      expect(f.savedTasks.last.body, containsPair('devProjectId', null));
    });

    testWidgets('opening a task changes it (and 100% completes it)', (tester) async {
      final f = await _pump(tester, const TeamDashboardScreen(initialTab: 'tasks'));
      await _tapV(tester, 'team_task_t1');
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(_k('team_task_title')).controller!.text, 'Studio tour reel');
      await _tapV(tester, 'team_task_set_completed');
      await tester.pump();
      await _tapV(tester, 'team_task_save');
      await tester.pumpAndSettle();
      expect(f.savedTasks.single.id, 't1');
      expect(f.savedTasks.single.body['status'], 'completed');
      expect(f.savedTasks.single.body['progress'], 100);
    });

    testWidgets('a refusal from the server (a member cannot assign to others) is shown in the form', (tester) async {
      final fake = _FakeTeam()..refuse = const TeamRefusal('Only the Marketing Manager or Admin can assign a task to someone else.', status: 403);
      await _pump(tester, const TeamDashboardScreen(initialTab: 'tasks'), fake: fake);
      await _tapV(tester, 'team_task_new');
      await tester.pumpAndSettle();
      await tester.enterText(_k('team_task_title'), 'For Ashique');
      await _tapV(tester, 'team_task_save');
      await tester.pumpAndSettle();
      expect(_text(tester, _k('team_task_error')), contains('Only the Marketing Manager'));
    });
  });

  // ── the audit's fixes (T1–T11) ──────────────────────────────────────────────
  group('audit fixes: how the new payloads read', () {
    test('Team Activity: the By Member / By Project / By Category views; the query the server cuts by', () {
      final d = TeamActivityFeed.fromJson({'views': {'byMember': [{'key': 'm1', 'label': 'Preethi', 'logs': 2, 'minutes': 90, 'completed': 1}], 'byProject': [], 'byCategory': [{'key': 'others', 'label': 'Others', 'logs': 1}]}});
      expect(d.byMember.single.label, 'Preethi');
      expect(d.byCategory.single.key, 'others');
      expect(TeamActivityFeed.fromJson(const {}).byProject, isEmpty);
      expect(const ActivityQuery(kind: ActivityKind.meeting, project: 'id:p1').query, {'kind': 'meeting', 'project': 'id:p1'});
      expect(const ActivityQuery(memberId: 'm1').narrowed, isTrue);
      expect(const ActivityQuery(kind: ActivityKind.post, group: 'g1').cleared, const ActivityQuery(kind: ActivityKind.post));
    });

    test('a log sends its category, CRM project, Socials post and development project', () {
      final json = LogDraft(entryDate: '2026-11-12', workedOn: 'Posted', projectId: 'p1', groupId: 'g2', contentId: 'c1', devProjectId: 'd1').toJson();
      expect([json['projectId'], json['groupId'], json['contentId'], json['devProjectId']], ['p1', 'g2', 'c1', 'd1']);
      final plain = LogDraft(entryDate: '2026-11-12', workedOn: 'x').toJson();
      expect(plain.containsKey('groupId') || plain.containsKey('contentId') || plain.containsKey('devProjectId'), isFalse);
    });

    test('a kind of work suggests its category by name; nothing fits → none', () {
      const cats = [(id: 'g1', name: 'Production'), (id: 'g2', name: 'Posting'), (id: 'g3', name: 'Ads'), (id: 'g4', name: 'Coordination'), (id: 'g5', name: 'Strategies')];
      expect(suggestCategory(ActivityKind.post, cats), 'g2');
      expect(suggestCategory(ActivityKind.shoot, cats), 'g1');
      expect(suggestCategory(ActivityKind.campaign, cats), 'g3');
      expect(suggestCategory(ActivityKind.meeting, cats), 'g4');
      expect(suggestCategory(ActivityKind.strategy, cats), 'g5');
      expect(suggestCategory(ActivityKind.task, cats), isNull);
      expect(suggestCategory(ActivityKind.post, const []), isNull);
    });

    test('a Coordinations request in the task list is marked, read-only here, and says where it lives', () {
      final t = TeamTask.fromJson({..._task('r1'), 'source': 'request', 'requestStatus': 'waiting_input', 'link': '/marketing/coordinations?tab=requests', 'canEdit': false});
      expect([t.isRequest, t.canEdit, t.link], [true, false, '/marketing/coordinations?tab=requests']);
      expect(TeamTask.fromJson(_task('t1')).isRequest, isFalse);
      expect(TaskScope.values.map((s) => s.wire), ['all', 'mine', 'assigned_by_me']);
    });

    test('attendance: Work From Home is counted; a month rate nobody can know stays "—"', () {
      final a = AttendanceData.fromJson({'summary': {'wfh': 2}, 'rows': [{'memberId': 'm1', 'name': 'P', 'monthRate': null, 'modeSet': true, 'workMode': 'wfh'}], 'canSetOwn': true});
      expect(a.summary.wfh, 2);
      expect(a.rows.single.monthRate, isNull);
      expect(a.canSetOwn, isTrue);
      expect(workModeLabel('wfh'), 'Work from home');
      expect(workModeLabel(''), '—');
      expect(WorkMode.parse('on_shoot'), WorkMode.onShoot);
      final csv = attendanceCsv(a);
      expect(csv[1][8], '', reason: 'an unknown month rate is blank in the CSV, never 0');
    });

    test('performance: lead → booking with one decimal, "—" when there are no leads; the CSV leaves unknowns blank', () {
      final r = PerformanceRow.fromJson({'memberId': 'm1', 'name': 'P', 'leads': 3, 'booked': 1, 'leadToBooking': 33.3, 'trend': [{'week': 1, 'activityPct': 50}]});
      expect([r.leads, r.booked, r.leadToBooking, r.trend.single.activityPct], [3, 1, 33.3, 50]);
      expect(rateText(33.3), '33.3%');
      expect(rateText(50), '50%');
      expect(rateText(null), '—');
      final csv = performanceCsv([const PerformanceRow(memberId: 'm2', name: 'A')]);
      expect(csv[1].sublist(3), ['', '', '', '', '', '', '']);
    });

    test('the daily report is for today, or the last day of a range that ended before today — never its first day', () {
      final now = DateTime(2026, 11, 18);
      expect(reportDay(TeamFilter(from: DateTime(2026, 11, 1), to: DateTime(2026, 11, 30)), now: now), '2026-11-18');
      expect(reportDay(TeamFilter(from: DateTime(2026, 11, 1), to: DateTime(2026, 11, 7)), now: now), '2026-11-07');
      expect(reportDay(TeamFilter(from: DateTime(2026, 12, 1), to: DateTime(2026, 12, 7)), now: now), '2026-11-18', reason: 'never a future day');
    });

    test('the Overview exports its headline figures, members, workload, attendance (with WFH) and deadlines', () {
      final o = TeamOverview.fromJson({..._overview(), 'attendance': {'day': '2026-11-12', 'present': 7, 'onShoot': 1, 'wfh': 2, 'onLeave': 0, 'absent': 0}});
      final csv = overviewCsv(o);
      expect(csv.first, ['Section', 'Item', 'Value', 'Detail']);
      expect(csv.firstWhere((r) => r[1] == 'Tasks completed')[2], 42);
      expect(csv.firstWhere((r) => r[1] == 'Work from home')[2], 2);
      expect(csv.where((r) => r[0] == 'Member').length, 2);
      expect(TeamOverview.fromJson({'kpis': {'activityRate': null}}).kpis.activityRate, isNull);
      expect(overviewCsv(TeamOverview.fromJson({'kpis': {}})).firstWhere((r) => r[1] == 'Team activity rate %')[2], '', reason: 'unknown is blank, not 0');
    });
  });

  group('audit fixes: the screens', () {
    testWidgets('Overview: the Activity Logging strip asks the log\'s questions and its button opens the form; a member sets today\'s work mode', (tester) async {
      final f = await _pump(tester, const TeamDashboardScreen());
      expect(_k('team_logging_strip'), findsOneWidget);
      for (var i = 0; i < kLogQuestions.length; i++) {
        expect(_k('team_log_q_$i'), findsOneWidget);
      }
      await tester.tap(_k('team_strip_mode_wfh'));
      await tester.pumpAndSettle();
      expect(f.workModes.single.mode, WorkMode.wfh);
      expect(f.workModes.single.memberId, isNull, reason: 'their own');
      await tester.tap(_k('team_log_daily'));
      await tester.pumpAndSettle();
      expect(_k('log_worked_on'), findsOneWidget);
    });

    testWidgets('Overview: Work From Home is a tile of its own, and the page exports', (tester) async {
      final fake = _FakeTeam()..overviewJson = {..._overview(), 'attendance': {'day': '2026-11-12', 'present': 5, 'onShoot': 1, 'wfh': 3, 'onLeave': 0, 'absent': 0}};
      await _pump(tester, const TeamDashboardScreen(), fake: fake);
      expect(find.descendant(of: _k('team_strip_wfh'), matching: find.text('3')), findsOneWidget);
      expect(_k('team_overview_export'), findsOneWidget);
    });

    testWidgets('Team Activity: By Member / By Project / By Category; a row narrows the feed on the server, and the chip takes it back', (tester) async {
      final f = await _pump(tester, const TeamDashboardScreen(initialTab: 'activity'));
      await tester.tap(_k('team_view_member'));
      await tester.pumpAndSettle();
      expect(_k('team_by_member_m1'), findsOneWidget);
      expect(_k('team_by_member_m2'), findsOneWidget);
      await tester.tap(_k('team_by_member_m2'));
      await tester.pumpAndSettle();
      expect(f.activityQueries.last.memberId, 'm2');
      expect(_k('team_activity_narrowed'), findsOneWidget);
      await tester.tap(_k('team_activity_narrowed_clear'));
      await tester.pumpAndSettle();
      expect(f.activityQueries.last.narrowed, isFalse);
      await tester.tap(_k('team_view_project'));
      await tester.pumpAndSettle();
      await tester.tap(_k('team_by_project_label:bridal campaign'));
      await tester.pumpAndSettle();
      expect(f.activityQueries.last.project, 'label:bridal campaign');
      await tester.tap(_k('team_view_category'));
      await tester.pumpAndSettle();
      expect(_k('team_by_category_others'), findsOneWidget);
      expect(_k('team_activity_export'), findsOneWidget);
    });

    testWidgets('Tasks: All / My Tasks / Assigned by me go to the server; a Coordinations request is marked and opens as one', (tester) async {
      final fake = _FakeTeam()..tasksJson = [_task('t1'), {..._task('r1', title: 'Need the expo reel', status: 'pending'), 'source': 'request', 'requestStatus': 'waiting_input', 'link': '/marketing/coordinations?tab=requests', 'canEdit': false}];
      await _pump(tester, const TeamDashboardScreen(initialTab: 'tasks'), fake: fake);
      expect(find.textContaining('1 from Coordinations'), findsOneWidget);
      expect(find.text('Coordination'), findsOneWidget);
      await tester.tap(_k('team_task_scope_mine'));
      await tester.pumpAndSettle();
      expect(fake.taskScopes.last, TaskScope.mine);
      await tester.tap(_k('team_task_scope_assigned_by_me'));
      await tester.pumpAndSettle();
      expect(fake.taskScopes.last, TaskScope.assignedByMe);
      await _tapV(tester, 'team_task_r1');
      await tester.pumpAndSettle();
      expect(_k('team_request_dialog'), findsOneWidget, reason: 'a request is changed in Coordinations, not here');
      expect(_k('team_task_title'), findsNothing);
    });

    testWidgets('Tasks: the By project view groups them, with how many are done', (tester) async {
      await _pump(tester, const TeamDashboardScreen(initialTab: 'tasks'));
      await tester.tap(_k('team_task_view_3'));
      await tester.pumpAndSettle();
      expect(_k('team_tasks_by_project'), findsOneWidget);
      expect(_k('team_project_group_Studio Tour'), findsOneWidget);
      expect(find.text('1 of 3 done'), findsOneWidget);
    });

    testWidgets('a task gets a category — the dashboard counts it there, not under Others', (tester) async {
      final fake = _FakeTeam()..setupJson = {..._setup(manager: true), 'categories': [{'id': 'g1', 'name': 'Content'}, {'id': 'g2', 'name': 'Campaigns'}]};
      await _pump(tester, const TeamDashboardScreen(initialTab: 'tasks'), fake: fake);
      await _tapV(tester, 'team_task_new');
      await tester.pumpAndSettle();
      await tester.enterText(_k('team_task_title'), 'Plan the Diwali ads');
      await _tapV(tester, 'team_task_group');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Campaigns').last);
      await tester.pumpAndSettle();
      await _tapV(tester, 'team_task_save');
      await tester.pumpAndSettle();
      expect(fake.savedTasks.single.body['groupId'], 'g2');
    });

    testWidgets('Logs & Timesheet: Daily Logs (everything a log says), Work Summary and Activity Report, each with an export', (tester) async {
      await _pump(tester, const TeamDashboardScreen(initialTab: 'timesheet'));
      expect(_k('team_log_a1'), findsOneWidget);
      expect(find.textContaining('Reel 3'), findsOneWidget);
      expect(_k('team_logs_export'), findsOneWidget);
      await tester.tap(_k('team_logs_summary'));
      await tester.pumpAndSettle();
      expect(find.descendant(of: _k('team_summary_m1'), matching: find.text('Colour grade')), findsOneWidget);
      expect(find.descendant(of: _k('team_summary_m1'), matching: find.text('• Cut the teaser')), findsOneWidget);
      expect(find.descendant(of: _k('team_summary_m2'), matching: find.text('—')), findsNWidgets(3), reason: 'nothing logged → dashes, not blanks');
      await tester.tap(_k('team_logs_report'));
      await tester.pumpAndSettle();
      expect(_k('team_activity_report_table'), findsOneWidget);
      expect(find.text('₹1500'), findsOneWidget);
      expect(find.text('Content: 5'), findsOneWidget);
      expect(_k('team_report_activity_export'), findsOneWidget);
    });

    testWidgets('Performance: lead → booking per member (booked / leads), a weekly trend each, and an export', (tester) async {
      await _pump(tester, const TeamDashboardScreen(initialTab: 'performance'));
      expect(find.text('25%  (1/4)'), findsOneWidget);
      expect(find.text('50%  (1/2)'), findsOneWidget);
      expect(find.descendant(of: _k('team_perf_l2b'), matching: find.text('33.3%')), findsOneWidget);
      expect(_k('team_perf_trend_m1'), findsOneWidget);
      expect(_k('team_perf_export'), findsOneWidget);
    });

    testWidgets('Attendance: a WFH tile, each person\'s month %, "—" when unknown; a member sets their own mode, a manager anyone\'s', (tester) async {
      final fake = _FakeTeam()..attendanceExtra = {'canSetOwn': true, 'canSetOthers': true};
      await _pump(tester, const TeamDashboardScreen(initialTab: 'attendance'), fake: fake);
      expect(find.descendant(of: _k('team_att_wfh'), matching: find.text('1')), findsOneWidget);
      expect(_text(tester, _k('team_att_month_m1')), '92%');
      expect(_text(tester, _k('team_att_month_m2')), '—');
      expect(fake.attendanceFilters.last, isNotNull, reason: 'the brand and member filter go to the server');
      await tester.tap(_k('team_my_mode_on_shoot'));
      await tester.pumpAndSettle();
      expect(fake.workModes.last.mode, WorkMode.onShoot);
      expect(fake.workModes.last.memberId, isNull);
      await tester.tap(_k('team_att_mode_m2'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Work From Home').last);
      await tester.pumpAndSettle();
      expect(fake.workModes.last.mode, WorkMode.wfh);
      expect(fake.workModes.last.memberId, 'm2');
      expect(_k('team_att_export'), findsOneWidget);
    });

    testWidgets('Reports: the monthly report is there; the daily one asks for a day (not the range\'s first)', (tester) async {
      final f = await _pump(tester, const TeamDashboardScreen(initialTab: 'reports'));
      expect(_k('team_report_monthly'), findsOneWidget);
      await tester.tap(_k('team_report_monthly'));
      await tester.pumpAndSettle();
      expect(find.text('Monthly report — 2026-11'), findsOneWidget);
      await tester.tap(_k('team_report_daily'));
      await tester.pumpAndSettle();
      expect(f.reports.last.type, 'daily');
      expect(f.reports.last.day, TeamFilter.day(DateTime.now()));
    });

    testWidgets('Reports: a report made here is kept in Saved reports (a daily one for its day); opening a scheduled one makes it again', (tester) async {
      final reports = FakeMarketingReports(savedList: [MarketingSavedReport.fromJson(const {'id': 'r9', 'module': 'team', 'kind': 'campaign-summary', 'name': 'Scheduled one', 'from': '2026-10-01', 'to': '2026-10-31', 'brand': 'kerala', 'scheduled': true, 'createdByName': 'Scheduled'})]);
      final f = await _pump(tester, const TeamDashboardScreen(initialTab: 'reports'), reports: reports);
      expect(_k('mktSavedReports_team'), findsOneWidget);
      await tester.tap(_k('team_report_monthly'));
      await tester.pumpAndSettle();
      expect(reports.kept.single, containsPair('kind', 'monthly'));
      expect(reports.kept.single['name'], 'Monthly report — 2026-11');
      final today = TeamFilter.day(DateTime.now());
      await tester.tap(_k('team_report_daily'));
      await tester.pumpAndSettle();
      expect([reports.kept.last['kind'], reports.kept.last['from'], reports.kept.last['to']], ['daily', today, today]);
      await tester.scrollUntilVisible(_k('mktSavedReportOpen_r9'), 300, scrollable: find.descendant(of: _k('team_reports_list'), matching: find.byType(Scrollable)).first);
      await tester.tap(_k('mktSavedReportOpen_r9'));
      await tester.pumpAndSettle();
      expect(f.reports.last.type, 'weekly', reason: 'a scheduled Campaign Summary opens the weekly report');
      expect(reports.kept, hasLength(2), reason: 'opening is not making a new one');
    });
  });

  group('audit fixes: the log form', () {
    Future<_FakeTeam> openForm(WidgetTester tester, _FakeTeam fake) async {
      final f = await _pump(tester, Builder(builder: (context) => Center(child: ElevatedButton(key: const Key('open'), onPressed: () => showLogActivity(context, date: DateTime(2026, 11, 12)), child: const Text('open')))), fake: fake, size: const Size(1280, 1500));
      await tester.tap(_k('open'));
      await tester.pumpAndSettle();
      return f;
    }

    _FakeTeam withExtras() => _FakeTeam()
      ..setupJson = {
        ..._setup(),
        'categories': [{'id': 'g1', 'name': 'Content'}, {'id': 'g2', 'name': 'Posting'}],
        'posts': [{'id': 'c1', 'title': 'Bridal reel #12', 'platform': 'instagram', 'contentType': 'reel', 'status': 'scheduled', 'day': '2026-11-14'}],
      };

    testWidgets('a category chosen, a CRM project picked and a Socials post published are all sent', (tester) async {
      final f = await openForm(tester, withExtras());
      await tester.enterText(_k('log_worked_on'), 'Posted the bridal reel');
      await tester.enterText(_k('log_project'), 'Bri');
      await tester.pumpAndSettle();
      await _tapV(tester, 'log_project_p1');
      await tester.pumpAndSettle();
      await _tapV(tester, 'log_post');
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Bridal reel #12').last);
      await tester.pumpAndSettle();
      expect(tester.widget<ChoiceChip>(_k('log_kind_post')).selected, isTrue, reason: 'publishing a post makes it a post');
      expect(tester.widget<ChoiceChip>(_k('log_group_g2')).selected, isTrue, reason: 'and suggests the Posting category');
      await _tapV(tester, 'log_group_g1');
      await tester.pumpAndSettle();
      await _tapV(tester, 'log_save');
      await tester.pumpAndSettle();
      final d = f.savedLogs.single.draft;
      expect([d.projectId, d.contentId, d.groupId, d.kind], ['p1', 'c1', 'g1', ActivityKind.post]);
      expect(find.textContaining('marked published in Socials'), findsOneWidget);
    });

    testWidgets('typing a different project name drops the picked CRM project (the text is kept as typed)', (tester) async {
      final f = await openForm(tester, withExtras());
      await tester.enterText(_k('log_worked_on'), 'Something');
      await tester.enterText(_k('log_project'), 'Bri');
      await tester.pumpAndSettle();
      await _tapV(tester, 'log_project_p1');
      await tester.pumpAndSettle();
      await tester.enterText(_k('log_project'), 'Bridal Campaign 2');
      await tester.pumpAndSettle();
      await _tapV(tester, 'log_save');
      await tester.pumpAndSettle();
      expect(f.savedLogs.single.draft.projectId, isNull);
      expect(f.savedLogs.single.draft.projectLabel, 'Bridal Campaign 2');
    });
  });
}
