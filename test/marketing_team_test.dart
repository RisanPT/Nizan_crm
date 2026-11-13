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
import 'package:nizan_crm/features/marketing/services/team_service.dart';
import 'package:dio/dio.dart';

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

Map<String, dynamic> _setup({bool canEdit = true, bool self = true, bool manager = false, String notice = '', bool shoots = true}) => {
      'member': {'id': 'm1', 'name': 'Preethi'}, 'self': self, 'canLogForOthers': manager, 'members': manager ? [{'id': 'm1', 'name': 'Preethi'}, {'id': 'm2', 'name': 'Ashique'}] : [], 'date': '2026-11-12',
      'groups': [{'id': 'g1', 'name': 'Content', 'metrics': [{'id': 'mt1', 'name': 'Reels edited', 'unitType': 'count', 'maxPerDay': 6}, {'id': 'mt2', 'name': 'Stories posted', 'unitType': 'count'}]}],
      'tasks': [{'id': 't1', 'title': 'Studio tour reel', 'dueDate': '2026-11-14', 'status': 'in_progress', 'progress': 40}],
      'projects': [{'id': 'p1', 'name': 'Bridal Campaign'}, {'id': 'p2', 'name': 'Studio Tour'}],
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

  @override
  Future<TeamActivityFeed> activity(TeamFilter f, {String? group, String? kind, int limit = 100}) async =>
      TeamActivityFeed.fromJson({'summary': {'day': '2026-11-12', 'logged': 3, 'completed': 2, 'inProgress': 1, 'meetings': 1, 'minutes': 195}, 'total': 3, 'items': [_feed('a1'), _feed('a2', kind: 'meeting', work: 'Campaign review', status: 'in_progress'), _feed('a3', brand: 'kerala', work: 'Kerala story')]});

  @override
  Future<Timesheet> timesheet(TeamFilter f) async => Timesheet.fromJson({
        'days': ['2026-11-11', '2026-11-12'], 'totalMinutes': 465, 'totalLabel': '7h 45m',
        'split': [{'group': 'Content', 'minutes': 300, 'pct': 65}, {'group': 'Others', 'minutes': 165, 'pct': 35}],
        'rows': [{'memberId': 'm1', 'name': 'Preethi', 'role': 'Brand Manager', 'minutes': 465, 'label': '7h 45m', 'logs': 4, 'daysLogged': 2, 'byDay': {'2026-11-11': 300, '2026-11-12': 165}, 'status': 'Submitted'}],
      });

  @override
  Future<PerformanceData> performance(TeamFilter f) async => PerformanceData.fromJson({
        'kpis': {'activityRate': 94, 'tasksCompleted': 42, 'onTimeDelivery': 87},
        'rows': [{'memberId': 'm1', 'name': 'Preethi', 'role': 'Brand Manager', 'completion': 100, 'onTime': 98, 'activityRate': 100, 'overall': 99, 'tasks': 8}, {'memberId': 'm2', 'name': 'Ashique', 'role': 'Videographer', 'completion': 80, 'onTime': null, 'activityRate': 90, 'overall': 85, 'tasks': 5}],
        'trend': [{'week': 1, 'completion': 90, 'onTime': 80, 'tasks': 5}, {'week': 2, 'completion': null, 'onTime': null, 'tasks': 0}],
      });

  @override
  Future<AttendanceData> attendance(String date) async => AttendanceData.fromJson({
        'date': date, 'summary': {'present': 1, 'onShoot': 1, 'onLeave': 0, 'absent': 0}, 'rate': 92, 'linked': 2,
        'rows': [{'memberId': 'm1', 'name': 'Preethi', 'role': 'Brand Manager', 'checkIn': '2026-11-12T04:00:00.000Z', 'checkOut': '2026-11-12T12:30:00.000Z', 'hours': 8.5, 'workMode': 'office', 'state': 'Active', 'status': 'Present'}, {'memberId': 'm2', 'name': 'Ashique', 'role': 'Videographer', 'workMode': 'on_shoot', 'state': 'On Shoot', 'status': 'Logged'}],
      });

  @override
  Future<TeamReport> report(String type, TeamFilter f) async => TeamReport.fromJson({'title': 'Weekly report — 2026-11-09 to 2026-11-15', 'columns': ['Member', 'Logs'], 'rows': [['Preethi', 4]]});

  @override
  Future<LogSetup> logSetup({required String date, String? memberId}) async => LogSetup.fromJson({...setupJson, if (memberId != null) 'self': false}); // another member's day is "not yours"


  @override
  Future<TeamTaskList> tasks(TeamFilter f, {String status = 'all', String priority = 'all', String? q, bool mineOnly = false}) async {
    final counts = <String, int>{'all': tasksJson.length};
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

Future<_FakeTeam> _pump(WidgetTester tester, Widget screen, {_FakeTeam? fake, Size size = const Size(1280, 1400)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final f = fake ?? _FakeTeam();
  final overrides = <Override>[marketingTeamServiceProvider.overrideWithValue(f)];
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
      expect(_k('team_timesheet_table'), findsOneWidget);
    });

    testWidgets('Team Activity: the feed with its summary, filterable by kind; Kerala work is marked', (tester) async {
      await _pump(tester, const TeamDashboardScreen(initialTab: 'activity'));
      expect(find.descendant(of: _k('team_activity_summary'), matching: find.text('Activities logged')), findsOneWidget);
      expect(_k('team_activity_a1'), findsOneWidget);
      expect(_k('team_activity_a3'), findsOneWidget);
      expect(find.text('Kerala'), findsWidgets);
      await tester.tap(_k('team_kind_meeting'));
      await tester.pumpAndSettle();
      expect(_k('team_activity_a1'), findsNothing);
      expect(_k('team_activity_a2'), findsOneWidget);
    });

    testWidgets('Logs & Timesheet: hours per person with the daily cells, the total and the split', (tester) async {
      await _pump(tester, const TeamDashboardScreen(initialTab: 'timesheet'));
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
}
