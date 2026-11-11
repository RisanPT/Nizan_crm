import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:nizan_crm/core/models/auth_session.dart';
import 'package:nizan_crm/core/models/employee.dart';
import 'package:nizan_crm/core/providers/auth_provider.dart';
import 'package:nizan_crm/core/theme/app_theme.dart';
import 'package:nizan_crm/features/it/data/it_task.dart';
import 'package:nizan_crm/features/it/data/project.dart';
import 'package:nizan_crm/features/it/domain/models/okr_model.dart';
import 'package:nizan_crm/features/it/domain/task_rights.dart';
import 'package:nizan_crm/features/it/presentation/screens/widgets/it_task_editor.dart';
import 'package:nizan_crm/features/it/presentation/screens/widgets/project_departments.dart';
import 'package:nizan_crm/features/it/services/it_service.dart';

// Company Projects across departments: what the app reads from a project, what it lets each
// person do on a ticket (the same rules the server applies), the invitation / proposal
// banners, and the ticket form for someone who may only report progress.

/// The form's submit button ('Save ticket' / 'Create task' …): what it is called is not what is tested.
Finder _submit(String verb) => find.textContaining(RegExp('^$verb (ticket|task)\$'));

Map<String, dynamic> _access({
  String role = 'viewer',
  bool canManage = false,
  String editMode = 'managed',
  bool canCreateTasks = false,
  bool canEditAllTasks = false,
  List<String> lead = const [],
  List<String> pending = const [],
  bool canDecide = false,
}) =>
    {
      'role': role,
      'canManage': canManage,
      'editMode': editMode,
      'canCreateTasks': canCreateTasks,
      'canEditAllTasks': canEditAllTasks,
      'leadDepartments': lead,
      'pendingInvitations': pending,
      'canDecide': canDecide,
    };

Project _project({
  String id = 'p1',
  String name = 'Diwali campaign',
  String status = 'active',
  String decisionNote = '',
  String manager = 'Mira',
  List<Map<String, dynamic>>? departments,
  List<Map<String, dynamic>>? progress,
  Map<String, dynamic>? access,
}) =>
    Project.fromJson({
      '_id': id,
      'name': name,
      'status': status,
      'decisionNote': decisionNote,
      'targetDepartment': 'Marketing',
      'managerId': {'_id': 'm1', 'name': manager},
      'editMode': 'managed',
      'departments': departments ??
          [
            {'name': 'Marketing', 'role': 'owner', 'status': 'accepted'},
            {'name': 'Finance', 'role': 'participant', 'status': 'accepted'},
          ],
      'departmentProgress': progress ?? const [],
      'access': access ?? _access(),
    });

ITTask _task({String id = 't1', String assignee = 'e1', String dept = ''}) => ITTask(
      id: id,
      projectId: 'p1',
      title: 'Print banners',
      assigneeId: assignee,
      departmentName: dept,
    );

class _FakeProjects extends ProjectService {
  _FakeProjects() : super(Dio());
  final calls = <String>[];

  @override
  Future<Project> respondToInvitation(String projectId, String department, {required bool accept}) async {
    calls.add('respond:$projectId:$department:$accept');
    return _project();
  }

  @override
  Future<Project> decideProposal(String projectId, {required bool approve, String note = ''}) async {
    calls.add('decide:$projectId:$approve:$note');
    return _project();
  }
}

class _FakeTasks extends ITTaskService {
  _FakeTasks() : super(Dio());
  final created = <Map<String, dynamic>>[];
  final updated = <Map<String, dynamic>>[];

  @override
  Future<void> createTask(Map<String, dynamic> body) async => created.add(body);

  @override
  Future<void> updateTask(String id, Map<String, dynamic> body) async => updated.add(body);
}

AuthSession _session({String employeeId = 'e1'}) =>
    AuthSession(token: 't', userId: 'u', name: 'U', email: 'u@x', role: 'crm', employeeId: employeeId);

Future<void> _show(
  WidgetTester tester,
  Widget child, {
  List<Override> overrides = const [],
}) async {
  tester.view.physicalSize = const Size(900, 1700);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [authSessionProvider.overrideWithValue(_session()), ...overrides],
    child: MaterialApp(theme: AppTheme.lightTheme, home: Scaffold(body: SingleChildScrollView(child: child))),
  ));
  await tester.pump();
}

void main() {
  group('reading a project', () {
    test('departments, per-department progress and what the caller may do', () {
      final p = Project.fromJson({
        '_id': 'p1',
        'name': 'Diwali',
        'targetDepartment': 'Marketing',
        'progress': 40,
        'totalTasks': 5,
        'completedTasks': 2,
        'editMode': 'managed',
        'decisionNote': '',
        'departments': [
          {'name': 'Marketing', 'role': 'owner', 'status': 'accepted', 'leadId': {'_id': 'l1', 'name': 'Asha'}},
          {'name': 'Finance', 'role': 'participant', 'status': 'invited'},
          {'name': 'HR', 'role': 'participant', 'status': 'declined'},
        ],
        'departmentProgress': [
          {'name': 'Marketing', 'progress': 60, 'tasks': 3, 'done': 2},
          {'name': 'Finance', 'progress': 0, 'tasks': 0, 'done': 0},
        ],
        'access': _access(role: 'dept_lead', lead: ['Finance'], pending: ['Finance'], canCreateTasks: true),
      });

      expect(p.progress, 40);
      expect(p.departments.map((d) => d.name), ['Marketing', 'Finance', 'HR']);
      expect(p.departments.first.isOwner, isTrue);
      expect(p.departments.first.leadName, 'Asha');
      expect(p.invitedDepartments.map((d) => d.name), ['Finance']);
      // only the owner has accepted: a department that has not answered or said no is not "on" it yet
      expect(p.departmentNames, ['Marketing']);
      expect(p.departmentProgress.first.progress, 60);
      expect(p.access.pendingInvitations, ['Finance']);
      expect(p.access.canCreateTasks, isTrue);
      expect(p.access.isManaged, isTrue);
    });

    test('a project saved before departments existed reads as one department, open to all', () {
      final p = Project.fromJson({'_id': 'p9', 'name': 'Old', 'targetDepartment': 'IT'});
      expect(p.departmentNames, ['IT']);
      expect(p.isCrossDepartment, isFalse);
      expect(p.editMode, 'open');
      expect(p.isProposed, isFalse);
      // no access info from the server: nothing is hidden (the server still decides)
      expect(p.access.canCreateTasks, isTrue);
      expect(p.access.canEditAllTasks, isTrue);
    });

    test('saving sends only the other departments, and the edit mode', () {
      final body = _project(departments: [
        {'name': 'Marketing', 'role': 'owner', 'status': 'accepted'},
        {'name': 'Finance', 'role': 'participant', 'status': 'invited', 'leadId': 'l2'},
        {'name': 'HR', 'role': 'participant', 'status': 'declined'},
      ]).toJson();
      expect(body['editMode'], 'managed');
      expect(body['departments'], [
        {'name': 'Finance', 'leadId': 'l2'},
      ]);
    });

    test('a proposal and a turned-down proposal are told apart', () {
      expect(_project(status: 'proposed').isProposed, isTrue);
      final no = _project(status: 'cancelled', decisionNote: 'No budget');
      expect(no.isRejected, isTrue);
      expect(_project(status: 'cancelled').isRejected, isFalse);
    });
  });

  group('what a person may do to a ticket', () {
    ProjectAccess managed({bool manage = false, List<String> lead = const []}) =>
        ProjectAccess.fromJson(_access(role: 'member', canManage: manage, lead: lead));

    Project withAccess(ProjectAccess a, {String editMode = 'managed'}) =>
        _project(access: _access(role: a.role, canManage: a.canManage, editMode: editMode, lead: a.leadDepartments));

    test('unknown project: nothing is hidden', () {
      expect(taskRightsFor(null, _task(), myEmployeeId: 'x').plan, isTrue);
    });

    test('an open project lets everyone edit everything', () {
      final r = taskRightsFor(withAccess(managed(), editMode: 'open'), _task(), myEmployeeId: 'x');
      expect([r.plan, r.progress, r.delete], [true, true, true]);
    });

    test('the manager changes anything', () {
      final r = taskRightsFor(withAccess(managed(manage: true)), _task(), myEmployeeId: 'x');
      expect([r.plan, r.progress, r.delete], [true, true, true]);
    });

    test('a department lead changes tickets of their own department only', () {
      final p = withAccess(managed(lead: ['Finance']));
      expect(taskRightsFor(p, _task(dept: 'Finance'), myEmployeeId: 'x').plan, isTrue);
      expect(taskRightsFor(p, _task(dept: 'finance'), myEmployeeId: 'x').plan, isTrue, reason: 'names match regardless of case');
      expect(taskRightsFor(p, _task(dept: 'Marketing'), myEmployeeId: 'x').plan, isFalse);
      // no department on the ticket = the owning department (Marketing), which this lead does not lead
      expect(taskRightsFor(p, _task(), myEmployeeId: 'x').plan, isFalse);
    });

    test('whoever it is assigned to reports progress only', () {
      final r = taskRightsFor(withAccess(managed()), _task(assignee: 'me'), myEmployeeId: 'me');
      expect([r.plan, r.progress, r.delete], [false, true, false]);
      expect(r.progressOnly, isTrue);
    });

    test('anyone else can only look', () {
      final r = taskRightsFor(withAccess(managed()), _task(assignee: 'someone'), myEmployeeId: 'me');
      expect(r.readOnly, isTrue);
      expect(taskRightsFor(withAccess(managed()), _task(assignee: ''), myEmployeeId: '').readOnly, isTrue,
          reason: 'an unassigned ticket is nobody\'s to report on');
    });
  });

  group('objectives', () {
    test('progress follows the key results; typed only when there are none', () {
      const done = KeyResultItem(id: 'a', title: 'A', completed: true);
      const half = KeyResultItem(id: 'b', title: 'B', targetValue: 200, currentValue: 100);
      const over = KeyResultItem(id: 'c', title: 'C', targetValue: 10, currentValue: 50);
      expect(done.attainment, 1);
      expect(half.attainment, 0.5);
      expect(over.attainment, 1, reason: 'beating the target does not count for more than 100%');
      expect(OKRModel.progressOf(const [done, half]), 75);
      expect(OKRModel.progressOf(const [], manual: 30), 30);
    });

    test('the level comes from the server', () {
      final o = OKRModel.fromJson({'_id': 'o1', 'objective': 'Grow', 'level': 'department', 'department': 'Sales'});
      expect(o.level, 'department');
      expect(o.toJson()['level'], 'department');
      expect(OKRModel.fromJson({'_id': 'o2', 'objective': 'Old'}).level, '');
    });
  });

  group('invitations and proposals', () {
    late _FakeProjects service;
    setUp(() => service = _FakeProjects());

    Future<void> pumpBanner(WidgetTester tester, Project p) =>
        _show(tester, ProjectDecisionBanner(project: p), overrides: [projectServiceProvider.overrideWithValue(service)]);

    testWidgets('an invited head accepts', (tester) async {
      await pumpBanner(tester, _project(access: _access(pending: ['Finance'], lead: ['Finance'])));
      expect(find.textContaining('invited Finance'), findsOneWidget);
      await tester.tap(find.text('Accept'));
      await tester.pump();
      expect(service.calls, ['respond:p1:Finance:true']);
      expect(find.text('Finance joined "Diwali campaign"'), findsOneWidget);
    });

    testWidgets('declining asks first, and Cancel does nothing', (tester) async {
      await pumpBanner(tester, _project(access: _access(pending: ['Finance'])));
      await tester.tap(find.text('Decline'));
      await tester.pumpAndSettle();
      expect(find.text('Decline "Diwali campaign"?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(service.calls, isEmpty);

      await tester.tap(find.text('Decline'));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Decline')));
      await tester.pumpAndSettle();
      expect(service.calls, ['respond:p1:Finance:false']);
    });

    testWidgets('the owning head approves a proposal', (tester) async {
      await pumpBanner(tester, _project(status: 'proposed', access: _access(canDecide: true)));
      expect(find.textContaining('proposed this project'), findsOneWidget);
      await tester.tap(find.text('Approve'));
      await tester.pump();
      expect(service.calls, ['decide:p1:true:']);
    });

    testWidgets('rejecting takes a reason, and cancelling the reason does not reject', (tester) async {
      await pumpBanner(tester, _project(status: 'proposed', access: _access(canDecide: true)));
      await tester.tap(find.text('Reject'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(service.calls, isEmpty);

      await tester.tap(find.text('Reject'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'No budget this quarter');
      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Reject')));
      await tester.pumpAndSettle();
      expect(service.calls, ['decide:p1:false:No budget this quarter']);
    });

    testWidgets('the proposer sees they are waiting, and no buttons to decide', (tester) async {
      await pumpBanner(tester, _project(status: 'proposed', access: _access(canManage: true)));
      expect(find.textContaining('Waiting for the head of Marketing'), findsOneWidget);
      expect(find.text('Approve'), findsNothing);
      expect(find.text('Reject'), findsNothing);
    });

    testWidgets('a turned-down proposal shows why', (tester) async {
      await pumpBanner(tester, _project(status: 'cancelled', decisionNote: 'No budget this quarter'));
      expect(find.text('Not approved: No budget this quarter'), findsOneWidget);
    });

    testWidgets('nothing to answer: nothing shown', (tester) async {
      await pumpBanner(tester, _project());
      expect(find.byType(FilledButton), findsNothing);
      expect(find.byIcon(Icons.mail_outline), findsNothing);
    });
  });

  group('showing the departments', () {
    testWidgets('chips say who owns it, who has not answered and who said no', (tester) async {
      await _show(
        tester,
        ProjectDepartmentChips(
          project: _project(departments: [
            {'name': 'Marketing', 'role': 'owner', 'status': 'accepted'},
            {'name': 'Finance', 'role': 'participant', 'status': 'invited'},
            {'name': 'HR', 'role': 'participant', 'status': 'declined'},
            {'name': 'Sales', 'role': 'participant', 'status': 'accepted'},
          ]),
        ),
      );
      expect(find.text('Marketing'), findsOneWidget);
      expect(find.text('Finance · invited'), findsOneWidget);
      expect(find.text('HR · declined'), findsOneWidget);
      expect(find.text('Sales'), findsOneWidget);
    });

    testWidgets('progress by department only when more than one department has work', (tester) async {
      await _show(tester, DepartmentProgressStrip(project: _project(progress: [
        {'name': 'Marketing', 'progress': 100, 'tasks': 2, 'done': 2},
      ])));
      expect(find.byType(LinearProgressIndicator), findsNothing);

      await _show(
        tester,
        DepartmentProgressStrip(
          project: _project(progress: [
            {'name': 'Marketing', 'progress': 60, 'tasks': 5, 'done': 3},
            {'name': 'Finance', 'progress': 0, 'tasks': 0, 'done': 0},
          ]),
        ),
      );
      expect(find.byType(LinearProgressIndicator), findsNWidgets(2));
      expect(find.text('60% · 3/5'), findsOneWidget);
      expect(find.text('no tasks'), findsOneWidget);
    });
  });

  group('the ticket form', () {
    late _FakeTasks tasks;
    setUp(() => tasks = _FakeTasks());

    Future<void> openEditor(
      WidgetTester tester,
      Project project, {
      ITTask? existing,
    }) async {
      await _show(
        tester,
        Consumer(builder: (context, ref, _) {
          return TextButton(
            onPressed: () => showTaskEditor(context, ref, 'p1', existing: existing, allTasks: existing == null ? const [] : [existing]),
            child: const Text('open'),
          );
        }),
        overrides: [
          projectByIdProvider('p1').overrideWithValue(project),
          projectEmployeesProvider('p1').overrideWithValue(const <Employee>[]),
          itTaskServiceProvider.overrideWithValue(tasks),
        ],
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('someone with no part in the ticket is told so, and no form opens', (tester) async {
      await openEditor(tester, _project(), existing: _task(assignee: 'someone-else'));
      expect(find.text('Edit Task'), findsNothing);
      expect(find.textContaining('Only the project manager'), findsOneWidget);
    });

    testWidgets('on a manager-planned project nobody else adds tickets', (tester) async {
      await openEditor(tester, _project(access: _access(canCreateTasks: false)));
      expect(find.text('New Task'), findsNothing);
      expect(find.textContaining('The project manager adds the tasks'), findsOneWidget);
    });

    testWidgets('the person it is assigned to updates progress only — and only progress is sent', (tester) async {
      await openEditor(tester, _project(), existing: _task(assignee: 'e1'));
      expect(find.text('Edit Task'), findsOneWidget);
      expect(find.textContaining('The project manager plans this task'), findsOneWidget);

      await tester.ensureVisible(_submit('Save'));
      await tester.tap(_submit('Save'));
      await tester.pumpAndSettle();

      expect(tasks.updated, hasLength(1));
      expect(tasks.updated.single.keys.toSet(), {'status', 'percentComplete'},
          reason: 'a plan field in the request would be refused by the server');
    });

    testWidgets('the manager of a two-department project chooses the ticket\'s department', (tester) async {
      await openEditor(tester, _project(access: _access(role: 'manager', canManage: true, canCreateTasks: true, canEditAllTasks: true)));
      expect(find.text('New Task'), findsOneWidget);
      expect(find.text('Department *'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextField, 'Title *'), 'Book the printer');
      await tester.ensureVisible(_submit('Create'));
      await tester.tap(_submit('Create'));
      await tester.pumpAndSettle();

      expect(tasks.created, hasLength(1));
      expect(tasks.created.single['departmentName'], 'Marketing');
      expect(tasks.created.single['title'], 'Book the printer');
    });

    testWidgets('a project owned by one department has no department to choose', (tester) async {
      await openEditor(
        tester,
        _project(
          departments: [
            {'name': 'Marketing', 'role': 'owner', 'status': 'accepted'},
          ],
          access: _access(role: 'manager', canManage: true, canCreateTasks: true, canEditAllTasks: true),
        ),
      );
      expect(find.text('Department *'), findsNothing);
      await tester.enterText(find.widgetWithText(TextField, 'Title *'), 'Solo task');
      await tester.ensureVisible(_submit('Create'));
      await tester.tap(_submit('Create'));
      await tester.pumpAndSettle();
      expect(tasks.created.single.containsKey('departmentName'), isFalse);
    });
  });
}
