import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/models/auth_session.dart';
import 'package:nizan_crm/core/providers/auth_provider.dart';
import 'package:nizan_crm/core/theme/app_theme.dart';
import 'package:nizan_crm/features/it/data/it_task.dart';
import 'package:nizan_crm/features/it/data/project.dart';
import 'package:nizan_crm/features/it/domain/repositories/it_task_repository.dart';
import 'package:nizan_crm/features/it/presentation/controllers/it_tasks_notifier.dart';
import 'package:nizan_crm/features/it/presentation/screens/it_project_screen.dart';
import 'package:nizan_crm/features/it/presentation/screens/widgets/project_overview.dart';
import 'package:nizan_crm/features/it/presentation/screens/widgets/project_tabs.dart';
import 'package:nizan_crm/features/it/services/it_service.dart';

// A project's Overview tab: where it stands, the departments yet to answer (with Resend), its details,
// its activity and its phases — and the screen around it (header, tabs, opening on Overview).

Map<String, dynamic> _access({bool canManage = true, bool canCreateTasks = true, String editMode = 'managed', List<String> lead = const []}) => {
      'role': canManage ? 'manager' : 'viewer',
      'canManage': canManage,
      'editMode': editMode,
      'canCreateTasks': canCreateTasks,
      'canEditAllTasks': canManage,
      'leadDepartments': lead,
      'pendingInvitations': const <String>[],
      'canDecide': false,
    };

Project _project({
  String status = 'planning',
  int progress = 40,
  int total = 5,
  int done = 2,
  String description = 'Strategic project to build our lifestyle brand.',
  String? endDate,
  String targetDepartment = 'Marketing',
  List<Map<String, dynamic>>? departments,
  Map<String, dynamic>? access,
}) =>
    Project.fromJson({
      '_id': 'p1',
      'name': 'Lifestyle brand at 2030',
      'description': description,
      'status': status,
      'priority': 'medium',
      'phase': 'discovery',
      'horizonNumber': 2,
      'targetDepartment': targetDepartment,
      'managerId': {'_id': 'm1', 'name': 'Amna'},
      'startDate': '2026-11-03T00:00:00.000Z',
      'endDate': ?endDate,
      'progress': progress,
      'totalTasks': total,
      'completedTasks': done,
      'editMode': 'managed',
      'departments': departments ??
          [
            {'name': 'Marketing', 'role': 'owner', 'status': 'accepted'},
            {'name': 'Accounts', 'role': 'participant', 'status': 'invited'},
            {'name': 'Finance', 'role': 'participant', 'status': 'invited'},
            {'name': 'HR', 'role': 'participant', 'status': 'accepted'},
            {'name': 'Sales', 'role': 'participant', 'status': 'declined'},
          ],
      'access': access ?? _access(),
    });

ITTask _task(String id, String title, {String? parent, int pct = 0, String owner = '', DateTime? start, DateTime? due, int order = 0}) =>
    ITTask(id: id, projectId: 'p1', title: title, parentTaskId: parent, percentComplete: pct, assigneeName: owner, startDate: start, dueDate: due, order: order);

List<ITTask> _plan() => [
      _task('a', 'Discovery & Planning', pct: 50, owner: 'Amna', start: DateTime(2026, 11, 5), due: DateTime(2026, 11, 8), order: 1),
      _task('a1', 'Market study', parent: 'a', pct: 100, order: 1),
      _task('a2', 'Brand audit', parent: 'a', pct: 0, order: 2),
      _task('b', 'Design', order: 2),
      _task('c', 'Launch', order: 3),
    ];

ProjectActivity _event(String text, int minute, {String by = ''}) =>
    ProjectActivity(kind: 'note', text: text, by: by, at: DateTime(2026, 11, 3, 10, minute));

class _Service extends ProjectService {
  _Service() : super(Dio());
  final resent = <String>[];
  Completer<void>? hold;
  Object? failWith;

  @override
  Future<Project> resendInvitation(String projectId, String department) async {
    resent.add('$projectId:$department');
    if (hold != null) await hold!.future;
    if (failWith != null) throw failWith!;
    return _project();
  }
}

class _Repo implements IITTaskRepository {
  _Repo(this.tasks);
  final List<ITTask> tasks;
  @override
  Future<List<ITTask>> getTasks({String? projectId, String? status, String? assignedTo, String? ticketType, String? severity, String? subTeam, String? search, bool mine = false}) async => tasks;
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError('${invocation.memberName}');
}

AuthSession _session() => AuthSession(token: 't', userId: 'u', name: 'U', email: 'u@x', role: 'crm', employeeId: 'e1');

List<Override> _overrides({
  Project? project,
  List<ProjectActivity> events = const [],
  _Service? service,
  List<ITTask>? tasks,
  Object? activityError,
}) =>
    [
      authSessionProvider.overrideWithValue(_session()),
      projectsProvider.overrideWith((ref) async => project == null ? <Project>[] : [project]),
      projectServiceProvider.overrideWithValue(service ?? _Service()),
      projectActivityProvider('p1').overrideWith((ref) async {
        if (activityError != null) throw activityError;
        return events;
      }),
      itTaskRepositoryProvider.overrideWithValue(_Repo(tasks ?? _plan())),
    ];

Future<void> _size(WidgetTester tester, Size s) async {
  tester.view.physicalSize = s;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> _pumpOverview(
  WidgetTester tester, {
  Project? project,
  bool noProject = false,
  List<ITTask>? tasks,
  List<ProjectActivity> events = const [],
  _Service? service,
  Object? activityError,
  Size size = const Size(1400, 1200),
  ValueChanged<int>? onOpenTab,
}) async {
  await _size(tester, size);
  await tester.pumpWidget(const SizedBox.shrink());
  final p = noProject ? null : (project ?? _project());
  await tester.pumpWidget(ProviderScope(
    overrides: _overrides(project: p, events: events, service: service, tasks: tasks, activityError: activityError),
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: ProjectOverview(projectId: 'p1', project: p, tasks: tasks ?? _plan(), onOpenTab: onOpenTab ?? (_) {}),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

Future<void> _pumpScreen(
  WidgetTester tester, {
  Project? project,
  int initialIndex = 0,
  List<ProjectActivity> events = const [],
  Size size = const Size(1400, 1000),
}) async {
  await _size(tester, size);
  await tester.pumpWidget(const SizedBox.shrink());
  final p = project ?? _project();
  await tester.pumpWidget(ProviderScope(
    overrides: _overrides(project: p, events: events),
    child: MaterialApp(theme: AppTheme.lightTheme, home: ITProjectScreen(projectId: 'p1', initialIndex: initialIndex, backRoute: '/projects')),
  ));
  await tester.pumpAndSettle();
}

void main() {
  group('the tab a link asks for', () {
    test('names, aliases and positions; anything else is Overview', () {
      expect(projectTabIndex(null), ProjectTab.overview.index);
      expect(projectTabIndex(''), ProjectTab.overview.index);
      expect(projectTabIndex('okr'), ProjectTab.okr.index);
      expect(projectTabIndex('OKR'), ProjectTab.okr.index);
      expect(projectTabIndex('docs'), ProjectTab.docs.index);
      expect(projectTabIndex('srs'), ProjectTab.docs.index);
      expect(projectTabIndex('gantt'), ProjectTab.timeline.index);
      expect(projectTabIndex('kanban'), ProjectTab.board.index);
      expect(projectTabIndex('3'), ProjectTab.wbs.index);
      expect(projectTabIndex('99'), ProjectTab.overview.index);
      expect(projectTabIndex('-1'), ProjectTab.overview.index);
      expect(projectTabIndex('nonsense'), ProjectTab.overview.index);
    });

    test('Overview is first, and the order is the screen\'s', () {
      expect(ProjectTab.values.map((t) => t.name), ['overview', 'spreadsheet', 'timeline', 'wbs', 'board', 'okr', 'docs']);
    });
  });

  group('reading a project with activity', () {
    test('the feed is read in order; a line without a time or text is dropped; a list response has none', () {
      final p = Project.fromJson({
        '_id': 'p1',
        'name': 'x',
        'activity': [
          {'kind': 'created', 'text': 'Project created', 'by': 'Amna', 'at': '2026-11-03T04:54:00.000Z'},
          {'kind': 'note', 'text': 'no time'},
          {'kind': 'note', 'text': '', 'at': '2026-11-03T05:00:00.000Z'},
          {'text': 'Project moved to Planning', 'at': '2026-11-03T05:10:00.000Z'},
        ],
      });
      expect(p.activity.map((e) => e.text), ['Project created', 'Project moved to Planning']);
      expect(p.activity.first.by, 'Amna');
      expect(p.activity.last.kind, 'note');
      expect(Project.fromJson({'_id': 'p2', 'name': 'y'}).activity, isEmpty);
    });
  });

  group('progress and the four numbers', () {
    testWidgets('the progress card says how far, how many tasks, and the status', (tester) async {
      await _pumpOverview(tester);
      final hero = find.byKey(const Key('overview_hero'));
      expect(find.descendant(of: hero, matching: find.text('Project Progress')), findsOneWidget);
      expect(find.descendant(of: hero, matching: find.text('40%')), findsOneWidget);
      expect(find.descendant(of: hero, matching: find.text('2 of 5 tasks completed')), findsOneWidget);
      expect(find.descendant(of: hero, matching: find.text('Planning')), findsOneWidget);
    });

    testWidgets('phases are the top-level items; tasks, departments (not the declined) and the due date follow', (tester) async {
      await _pumpOverview(tester, project: _project(endDate: '2030-12-31T00:00:00.000Z'));
      Finder stat(String key) => find.byKey(Key('overview_stat_$key'));
      expect(find.descendant(of: stat('phases'), matching: find.text('3')), findsOneWidget); // a, b, c
      expect(find.descendant(of: stat('tasks'), matching: find.text('5')), findsOneWidget);
      // Marketing (owner) + Accounts + Finance + HR; Sales declined
      expect(find.descendant(of: stat('departments'), matching: find.text('4')), findsOneWidget);
      expect(find.descendant(of: stat('due'), matching: find.text('31 Dec 2030')), findsOneWidget);
      expect(find.descendant(of: stat('due'), matching: find.text('Due Date')), findsOneWidget);
    });

    testWidgets('no end date reads "—"; a past end date on a running project reads Overdue, a finished one does not', (tester) async {
      await _pumpOverview(tester);
      expect(find.descendant(of: find.byKey(const Key('overview_stat_due')), matching: find.text('—')), findsOneWidget);

      await _pumpOverview(tester, project: _project(endDate: '2020-01-15T00:00:00.000Z'));
      expect(find.descendant(of: find.byKey(const Key('overview_stat_due')), matching: find.text('Overdue')), findsOneWidget);

      await _pumpOverview(tester, project: _project(status: 'completed', endDate: '2020-01-15T00:00:00.000Z'));
      expect(find.descendant(of: find.byKey(const Key('overview_stat_due')), matching: find.text('Due Date')), findsOneWidget);
    });

    testWidgets('before the project list has loaded, progress and counts come from the tasks', (tester) async {
      await _pumpOverview(tester, noProject: true);
      // leaves: a1 100, a2 0, b 0, c 0 → 25%
      expect(find.descendant(of: find.byKey(const Key('overview_hero')), matching: find.text('25%')), findsOneWidget);
      expect(find.byKey(const Key('overview_invitations')), findsNothing);
      expect(find.byKey(const Key('overview_details')), findsNothing);
      expect(find.byKey(const Key('overview_activity')), findsNothing);
      expect(find.byKey(const Key('overview_wbs')), findsOneWidget);
    });
  });

  group('department invitations', () {
    testWidgets('each department with where it stands; the count of those still waiting', (tester) async {
      await _pumpOverview(tester);
      final card = find.byKey(const Key('overview_invitations'));
      expect(find.descendant(of: card, matching: find.text('Project Departments')), findsOneWidget);
      expect(find.descendant(of: card, matching: find.text('2 Pending')), findsOneWidget);
      expect(find.descendant(of: card, matching: find.text('Departments collaborating on this project.')), findsOneWidget);
      // the owner is not an invitation
      expect(find.byKey(const Key('invitation_Marketing')), findsNothing);
      for (final d in ['Accounts', 'Finance', 'HR', 'Sales']) {
        expect(find.byKey(Key('invitation_$d')), findsOneWidget, reason: d);
      }
      Finder inRow(String d, String text) => find.descendant(of: find.byKey(Key('invitation_$d')), matching: find.text(text));
      expect(inRow('Accounts', 'Awaiting approval'), findsOneWidget);
      expect(inRow('Finance', 'Awaiting approval'), findsOneWidget);
      expect(inRow('HR', 'Joined'), findsOneWidget);
      expect(inRow('Sales', 'Declined'), findsOneWidget);
    });

    testWidgets('Resend is on the departments still waiting, for someone who manages the project', (tester) async {
      await _pumpOverview(tester);
      expect(find.byKey(const Key('resend_Accounts')), findsOneWidget);
      expect(find.byKey(const Key('resend_Finance')), findsOneWidget);
      expect(find.byKey(const Key('resend_HR')), findsNothing);
      expect(find.byKey(const Key('resend_Sales')), findsNothing);
    });

    testWidgets('someone who does not manage it sees the status but no Resend', (tester) async {
      await _pumpOverview(tester, project: _project(access: _access(canManage: false)));
      expect(find.text('2 Pending'), findsOneWidget);
      expect(find.byKey(const Key('resend_Accounts')), findsNothing);
    });

    testWidgets('Resend asks the server for that department only, then says so', (tester) async {
      final service = _Service();
      await _pumpOverview(tester, service: service);
      await tester.tap(find.byKey(const Key('resend_Finance')));
      await tester.pumpAndSettle();
      expect(service.resent, ['p1:Finance']);
      expect(find.text('Reminder sent to Finance'), findsOneWidget);
    });

    testWidgets('while it is being sent the button cannot be pressed twice', (tester) async {
      final service = _Service()..hold = Completer<void>();
      await _pumpOverview(tester, service: service);
      await tester.tap(find.byKey(const Key('resend_Accounts')));
      await tester.pump();
      expect(tester.widget<OutlinedButton>(find.byKey(const Key('resend_Accounts'))).onPressed, isNull);
      expect(tester.widget<OutlinedButton>(find.byKey(const Key('resend_Finance'))).onPressed, isNotNull); // others unaffected
      service.hold!.complete();
      await tester.pumpAndSettle();
      expect(tester.widget<OutlinedButton>(find.byKey(const Key('resend_Accounts'))).onPressed, isNotNull);
      expect(service.resent, ['p1:Accounts']);
    });

    testWidgets('when the server says it is too soon, that message is shown and nothing else changes', (tester) async {
      const message = 'Accounts was reminded a moment ago. You can remind them again in 30 minutes.';
      final req = RequestOptions(path: '/projects/p1/departments/Accounts/resend');
      final service = _Service()
        ..failWith = AppException(
          DioException(requestOptions: req, type: DioExceptionType.badResponse, response: Response(requestOptions: req, statusCode: 429, data: {'message': message})),
          action: 'resend the invitation',
        );
      await _pumpOverview(tester, service: service);
      await tester.tap(find.byKey(const Key('resend_Accounts')));
      await tester.pumpAndSettle();
      expect(find.text(message), findsOneWidget);
      expect(find.text('Reminder sent to Accounts'), findsNothing);
      expect(tester.widget<OutlinedButton>(find.byKey(const Key('resend_Accounts'))).onPressed, isNotNull);
    });

    testWidgets('once every department has answered the card says so, with no Resend', (tester) async {
      await _pumpOverview(tester, project: _project(departments: [
        {'name': 'Marketing', 'role': 'owner', 'status': 'accepted'},
        {'name': 'HR', 'role': 'participant', 'status': 'accepted'},
      ]));
      expect(find.text('1 Active'), findsOneWidget);
      expect(find.text('Every participating department is active on this project.'), findsOneWidget);
      expect(find.textContaining('Pending'), findsNothing);
      expect(find.textContaining('Resend'), findsNothing);
    });

    testWidgets('a project nobody was invited to has no invitation card; details and activity sit side by side', (tester) async {
      await _pumpOverview(tester, project: _project(departments: [
        {'name': 'Marketing', 'role': 'owner', 'status': 'accepted'},
      ]));
      expect(find.byKey(const Key('overview_invitations')), findsNothing);
      final details = tester.getTopLeft(find.byKey(const Key('overview_details')));
      final activity = tester.getTopLeft(find.byKey(const Key('overview_activity')));
      expect(details.dy, activity.dy);
      expect(details.dx, lessThan(activity.dx));
    });
  });

  group('project details', () {
    testWidgets('manager, department, dates, phase and priority', (tester) async {
      await _pumpOverview(tester, project: _project(endDate: '2027-03-15T00:00:00.000Z'));
      final card = find.byKey(const Key('overview_details'));
      for (final t in ['Project Details', 'Manager', 'Amna', 'Department', 'Marketing', 'Start Date', 'Due Date', '15 Mar 2027', 'Phase', 'Discovery', 'Priority', 'Medium']) {
        expect(find.descendant(of: card, matching: find.text(t)), findsOneWidget, reason: t);
      }
      expect(find.descendant(of: card, matching: find.text('3 Nov 2026')), findsOneWidget);
    });

    testWidgets('a person who may only update their own tickets is told so; a manager is not', (tester) async {
      await _pumpOverview(tester, project: _project(access: _access(canManage: false)));
      expect(find.textContaining('The project manager plans the tickets'), findsOneWidget);
      await _pumpOverview(tester);
      expect(find.textContaining('The project manager plans the tickets'), findsNothing);
    });
  });

  group('project activity', () {
    testWidgets('the latest four, oldest first, with who and when', (tester) async {
      final events = [
        _event('Project created', 24, by: 'Amna'),
        _event('Invitations sent to 3 departments', 26),
        _event('Project moved to Planning', 27, by: 'Amna'),
      ];
      await _pumpOverview(tester, events: events);
      final card = find.byKey(const Key('overview_activity'));
      expect(find.descendant(of: card, matching: find.text('Project created')), findsOneWidget);
      expect(find.descendant(of: card, matching: find.text('by Amna · 3 Nov 2026, 10:24 AM')), findsOneWidget);
      expect(find.descendant(of: card, matching: find.text('3 Nov 2026, 10:26 AM')), findsOneWidget); // nobody recorded: just the time
      expect(find.byKey(const Key('activity_view_all')), findsNothing);
      final y = [for (final t in ['Project created', 'Invitations sent to 3 departments', 'Project moved to Planning']) tester.getTopLeft(find.text(t)).dy];
      expect(y, [...y]..sort());
    });

    testWidgets('a long history shows the latest four; View all opens everything, newest first', (tester) async {
      final events = [for (var i = 0; i < 7; i++) _event('Step $i', i)];
      await _pumpOverview(tester, events: events);
      final card = find.byKey(const Key('overview_activity'));
      for (var i = 0; i < 3; i++) {
        expect(find.descendant(of: card, matching: find.text('Step $i')), findsNothing, reason: 'Step $i is older than the latest four');
      }
      for (var i = 3; i < 7; i++) {
        expect(find.descendant(of: card, matching: find.text('Step $i')), findsOneWidget);
      }

      await tester.tap(find.byKey(const Key('activity_view_all')));
      await tester.pumpAndSettle();
      final dialog = find.byType(AlertDialog);
      expect(find.descendant(of: dialog, matching: find.text('Project activity')), findsOneWidget);
      for (var i = 0; i < 7; i++) {
        expect(find.descendant(of: dialog, matching: find.text('Step $i')), findsOneWidget, reason: 'Step $i');
      }
      expect(tester.getTopLeft(find.descendant(of: dialog, matching: find.text('Step 6'))).dy,
          lessThan(tester.getTopLeft(find.descendant(of: dialog, matching: find.text('Step 0'))).dy));
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('no activity yet, and a feed that cannot load (with a way to try again)', (tester) async {
      await _pumpOverview(tester);
      expect(find.text('No activity yet.'), findsOneWidget);

      await _pumpOverview(tester, activityError: Exception('boom'));
      expect(find.text("Couldn't load the activity."), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });
  });

  group('work breakdown', () {
    testWidgets('the phases with number, owner, dates, duration and how far each has got', (tester) async {
      await _pumpOverview(tester);
      final card = find.byKey(const Key('overview_wbs'));
      expect(find.descendant(of: card, matching: find.text('Work Breakdown (WBS)')), findsOneWidget);
      for (final t in ['Discovery & Planning', 'Design', 'Launch']) {
        expect(find.descendant(of: card, matching: find.text(t)), findsOneWidget, reason: t);
      }
      final first = find.byKey(const Key('wbs_row_a'));
      expect(find.descendant(of: first, matching: find.text('1')), findsOneWidget);
      expect(find.descendant(of: first, matching: find.text('Amna')), findsOneWidget);
      expect(find.descendant(of: first, matching: find.text('5 Nov 2026')), findsOneWidget);
      expect(find.descendant(of: first, matching: find.text('8 Nov 2026')), findsOneWidget);
      expect(find.descendant(of: first, matching: find.text('3')), findsOneWidget); // days
      expect(find.descendant(of: first, matching: find.text('50%')), findsOneWidget); // (100 + 0) / 2 rolled up
      expect(find.descendant(of: card, matching: find.text('Dur (Days)')), findsOneWidget);
    });

    testWidgets('tapping a phase opens its tasks; tapping again folds them away', (tester) async {
      await _pumpOverview(tester);
      expect(find.text('Market study'), findsNothing);
      await tester.tap(find.byKey(const Key('wbs_row_a')));
      await tester.pumpAndSettle();
      expect(find.text('Market study'), findsOneWidget);
      expect(find.text('Brand audit'), findsOneWidget);
      expect(find.text('1.1'), findsOneWidget);
      await tester.tap(find.byKey(const Key('wbs_row_a')));
      await tester.pumpAndSettle();
      expect(find.text('Market study'), findsNothing);
    });

    testWidgets('Add Phase is for people who may add tasks; the link opens the full WBS tab', (tester) async {
      int? opened;
      await _pumpOverview(tester, onOpenTab: (i) => opened = i);
      expect(find.byKey(const Key('wbs_add_phase')), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('wbs_open_full')));
      await tester.tap(find.byKey(const Key('wbs_open_full')));
      expect(opened, ProjectTab.wbs.index);

      await _pumpOverview(tester, project: _project(access: _access(canManage: false, canCreateTasks: false)));
      expect(find.byKey(const Key('wbs_add_phase')), findsNothing);
    });

    testWidgets('no tasks: says so, and who can add the first phase', (tester) async {
      await _pumpOverview(tester, tasks: const []);
      expect(find.text('No phases yet'), findsOneWidget);
      expect(find.text('Add a phase, then break it into tasks.'), findsOneWidget);
      expect(find.byKey(const Key('wbs_open_full')), findsNothing);

      await _pumpOverview(tester, tasks: const [], project: _project(access: _access(canManage: false, canCreateTasks: false)));
      expect(find.text('The project manager adds the work to this project.'), findsOneWidget);
    });
  });

  group('layout', () {
    testWidgets('wide: progress and the four numbers share a row, invitations sit beside details + activity', (tester) async {
      await _pumpOverview(tester, events: [_event('Project created', 24, by: 'Amna')]);
      final hero = tester.getRect(find.byKey(const Key('overview_hero')));
      for (final k in ['phases', 'tasks', 'departments', 'due']) {
        final r = tester.getRect(find.byKey(Key('overview_stat_$k')));
        expect(r.top, hero.top, reason: k);
        expect(r.left, greaterThan(hero.right - 1), reason: k);
        expect(r.height, hero.height, reason: '$k is as tall as the progress card');
      }
      final inv = tester.getRect(find.byKey(const Key('overview_invitations')));
      final det = tester.getRect(find.byKey(const Key('overview_details')));
      final act = tester.getRect(find.byKey(const Key('overview_activity')));
      expect(inv.top, det.top);
      expect(det.left, greaterThan(inv.right - 1));
      expect(act.top, greaterThan(det.bottom - 1));
      expect(tester.takeException(), isNull);
    });

    testWidgets('tablet: progress on top, four numbers across, cards stacked', (tester) async {
      await _pumpOverview(tester, size: const Size(760, 1400), events: [_event('Project created', 24)]);
      final hero = tester.getRect(find.byKey(const Key('overview_hero')));
      final tops = {for (final k in ['phases', 'tasks', 'departments', 'due']) tester.getRect(find.byKey(Key('overview_stat_$k'))).top};
      expect(tops.length, 1);
      expect(tops.single, greaterThan(hero.bottom - 1));
      expect(tester.getTopLeft(find.byKey(const Key('overview_details'))).dy, greaterThan(tester.getRect(find.byKey(const Key('overview_invitations'))).bottom - 1));
      expect(tester.takeException(), isNull);
    });

    testWidgets('phone: four numbers in two rows of two, everything in one column, nothing overflows', (tester) async {
      await _pumpOverview(tester, size: const Size(390, 900), events: [_event('Project created', 24, by: 'Amna'), _event('Invitations sent to 3 departments', 26)]);
      Rect r(String k) => tester.getRect(find.byKey(Key('overview_stat_$k')));
      expect(r('phases').top, r('tasks').top);
      expect(r('departments').top, r('due').top);
      expect(r('departments').top, greaterThan(r('phases').bottom - 1));
      expect(r('phases').right, lessThan(r('tasks').left + 1));
      for (final k in ['overview_invitations', 'overview_details', 'overview_activity', 'overview_wbs']) {
        await tester.ensureVisible(find.byKey(Key(k)));
        final box = tester.getRect(find.byKey(Key(k)));
        expect(box.left, greaterThanOrEqualTo(0), reason: k);
        expect(box.right, lessThanOrEqualTo(390), reason: k);
      }
      expect(tester.takeException(), isNull);
    });
  });

  group('the screen', () {
    testWidgets('opens on Overview; the tabs are Overview, Spreadsheet, Timeline, WBS, Board, OKR, Docs', (tester) async {
      await _pumpScreen(tester);
      expect(find.byKey(const Key('overview_hero')), findsOneWidget);
      for (final t in ProjectTab.values) {
        expect(find.byKey(Key('tab_${t.name}')), findsOneWidget, reason: t.name);
        expect(find.descendant(of: find.byKey(Key('tab_${t.name}')), matching: find.text(t.label)), findsOneWidget);
      }
      final order = [for (final t in ProjectTab.values) tester.getTopLeft(find.byKey(Key('tab_${t.name}'))).dx];
      expect(order, [...order]..sort());
    });

    testWidgets('the header: breadcrumb, horizon badge, title, what it is for, and the actions', (tester) async {
      await _pumpScreen(tester);
      expect(find.text('Projects'), findsOneWidget);
      expect(find.text('H2'), findsOneWidget);
      expect(find.byKey(const Key('project_title')), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const Key('project_title'))).data, 'Lifestyle brand at 2030');
      expect(find.text('Strategic project to build our lifestyle brand.'), findsOneWidget);
      expect(find.text('Gantt Plan Wizard'), findsOneWidget);
      expect(find.text('Add Task'), findsOneWidget); // not an IT project: Task, not Ticket
      expect(find.byKey(const Key('project_more')), findsOneWidget);
    });

    testWidgets('an IT project says Add Ticket; with no description the line says what kind of project it is', (tester) async {
      await _pumpScreen(tester, project: _project(targetDepartment: 'IT', description: ''));
      expect(find.text('Add Ticket'), findsOneWidget);
      expect(find.text('Software project · IT'), findsOneWidget);
    });

    testWidgets('a company project with no description says its department, not the IT category ("Software project")', (tester) async {
      await _pumpScreen(tester, project: _project(targetDepartment: 'Management', description: ''));
      expect(find.text('Management project'), findsOneWidget);
      expect(find.textContaining('Software'), findsNothing);
    });

    testWidgets('someone who may not add tasks has neither the wizard nor Add Task', (tester) async {
      await _pumpScreen(tester, project: _project(access: _access(canManage: false, canCreateTasks: false)));
      expect(find.text('Gantt Plan Wizard'), findsNothing);
      expect(find.text('Add Task'), findsNothing);
      expect(find.byKey(const Key('project_more')), findsOneWidget);
    });

    testWidgets('the ⋯ menu offers Refresh and View activity, and View activity opens the history', (tester) async {
      await _pumpScreen(tester, events: [_event('Project created', 24, by: 'Amna')]);
      await tester.tap(find.byKey(const Key('project_more')));
      await tester.pumpAndSettle();
      expect(find.text('Refresh'), findsOneWidget);
      await tester.tap(find.text('View activity'));
      await tester.pumpAndSettle();
      expect(find.descendant(of: find.byType(AlertDialog), matching: find.text('Project created')), findsOneWidget);
    });

    testWidgets('"Open the full work breakdown" moves to the WBS tab', (tester) async {
      await _pumpScreen(tester);
      await tester.ensureVisible(find.byKey(const Key('wbs_open_full')));
      await tester.tap(find.byKey(const Key('wbs_open_full')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('overview_hero')), findsNothing);
      expect(find.text('Work Breakdown Structure (WBS)'), findsOneWidget); // the WBS tab's own toolbar
    });

    testWidgets('a link to a tab (initialIndex) opens that tab, not Overview', (tester) async {
      await _pumpScreen(tester, initialIndex: ProjectTab.wbs.index);
      expect(find.byKey(const Key('overview_hero')), findsNothing);
      expect(find.text('Work Breakdown Structure (WBS)'), findsOneWidget);
    });

    testWidgets('on a phone the header stacks and nothing overflows', (tester) async {
      await _pumpScreen(tester, size: const Size(390, 900), events: [_event('Project created', 24)]);
      expect(find.text('Gantt Plan Wizard'), findsOneWidget);
      expect(find.byKey(const Key('overview_hero')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
