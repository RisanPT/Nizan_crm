import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:nizan_crm/core/error/app_exception.dart';
import 'package:nizan_crm/core/models/auth_session.dart';
import 'package:nizan_crm/core/models/employee.dart';
import 'package:nizan_crm/core/providers/auth_provider.dart';
import 'package:nizan_crm/core/theme/app_theme.dart';
import 'package:nizan_crm/core/widgets/employee_multi_picker.dart';
import 'package:nizan_crm/features/it/data/project.dart';
import 'package:nizan_crm/features/it/domain/models/strategic_vision_model.dart';
import 'package:nizan_crm/features/it/presentation/screens/company_projects_screen.dart';
import 'package:nizan_crm/features/it/presentation/screens/it_projects_screen.dart';
import 'package:nizan_crm/features/it/presentation/screens/widgets/project_people.dart';
import 'package:nizan_crm/features/it/services/it_service.dart';
import 'package:nizan_crm/features/it/services/strategic_vision_service.dart';
import 'package:nizan_crm/features/org/data/department.dart';
import 'package:nizan_crm/features/org/services/department_service.dart';
import 'package:nizan_crm/services/employee_service.dart';

// The people on a project:
// - the team is picked with a SEARCH (name, role, department, employee code), not from a wall of every employee's name;
// - after a project is created its manager and team can be changed from the project's Overview ("Edit team");
// - someone on the team who is no longer in the departments' staff still shows (and can be removed) instead of staying unseen;
// - the pickers fill in when the staff list arrives after the form opened;
// - the IT Projects form asks for the cost the server requires (it used to fail on every new project).

Employee _e(String id, String name, String dept, {String code = '', String role = ''}) => Employee.fromJson({
      '_id': id,
      'name': name,
      'department': dept,
      'employeeCode': code,
      'role': role,
      'status': 'active',
      'phone': '90000$id',
    });

final _mira = _e('m1', 'Mira Nair', 'Marketing');
final _arun = _e('e2', 'Arun Das', 'Marketing', code: 'NZ-0002');
final _chitra = _e('e4', 'Chitra Menon', 'Marketing', role: 'Designer');
final _bindu = _e('e3', 'Bindu Paul', 'Finance', role: 'Accountant');
final _dev = _e('e5', 'Dev Raj', 'HR');
final _staff = [_mira, _arun, _chitra, _bindu, _dev];

Project _project({
  List<Map<String, dynamic>> members = const [],
  bool canManage = true,
  String status = 'active',
  List<Map<String, dynamic>>? departments,
}) =>
    Project.fromJson({
      '_id': 'p1',
      'name': 'Winter campaign',
      'status': status,
      'priority': 'medium',
      'targetDepartment': 'Marketing',
      'managerId': {'_id': 'm1', 'name': 'Mira Nair'},
      'members': members,
      'startDate': '2026-11-01',
      'endDate': '2026-11-20',
      'departments': departments ??
          [
            {'name': 'Marketing', 'role': 'owner', 'status': 'accepted'},
            {'name': 'Finance', 'role': 'participant', 'status': 'accepted'},
          ],
      'access': {'role': canManage ? 'manager' : 'viewer', 'canManage': canManage},
    });

/// What the server answers when someone taken off still has work on the project.
AppException _hasWork() => AppException(DioException(
      requestOptions: RequestOptions(path: '/projects/p1/team'),
      response: Response(
        requestOptions: RequestOptions(path: '/projects/p1/team'),
        statusCode: 409,
        data: {
          'code': 'TEAM_REMOVAL_HAS_WORK',
          'message': 'Chitra Menon still has work on this project. Take them off anyway?',
          'people': [
            {'id': 'e4', 'name': 'Chitra Menon', 'openTasks': 2, 'placement': {'to': '2026-12-24T00:00:00.000Z', 'percent': 50}},
          ],
        },
      ),
    ));

class _Projects extends ProjectService {
  _Projects([this.projects = const []]) : super(Dio());
  final List<Project> projects;
  final saved = <Map<String, dynamic>>[];
  final teams = <Map<String, dynamic>>[];

  /// Answer the first save (team or project) without a confirmation with "still has work".
  bool askFirst = false;

  @override
  Future<List<Project>> getProjects({String? status, String? priority, String? search, String? department, bool ownerOnly = false}) async => projects;

  @override
  Future<Project> saveProject(Map<String, dynamic> body, {String? id}) async {
    saved.add({...body, '_id': ?id});
    if (askFirst && body['confirmRemoval'] != true) throw _hasWork();
    return _project();
  }

  @override
  Future<Project> saveTeam(String id, Map<String, dynamic> body) async {
    teams.add({...body, '_id': id});
    if (askFirst && body['confirmRemoval'] != true) throw _hasWork();
    return _project();
  }
}

AuthSession _session({String role = 'artist', String emp = 'e9'}) =>
    AuthSession(token: 't', userId: 'u', name: 'U', email: 'u@x', role: role, employeeId: emp, permissions: const ['calendar']);

void _size(WidgetTester t, [Size s = const Size(1300, 1500)]) {
  t.view.physicalSize = s;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
}

Future<void> _pick(WidgetTester t, {String search = '', required List<String> tick}) async {
  await t.ensureVisible(find.byKey(const Key('emp_multi_add')));
  await t.tap(find.byKey(const Key('emp_multi_add')));
  await t.pumpAndSettle();
  if (search.isNotEmpty) {
    await t.enterText(find.byKey(const Key('emp_multi_search')), search);
    await t.pumpAndSettle();
  }
  for (final id in tick) {
    await t.tap(find.byKey(Key('emp_multi_$id')));
    await t.pump();
  }
  await t.tap(find.byKey(const Key('emp_multi_done')));
  await t.pumpAndSettle();
}

List<String> _listed(WidgetTester t) => t
    .widgetList<CheckboxListTile>(find.byType(CheckboxListTile))
    .map((c) => (c.key as ValueKey<String>).value.replaceFirst('emp_multi_', ''))
    .toList();

void main() {
  group('the rules', () {
    test('search: every word must match the name, code, role or department', () {
      expect(employeeMatches(_arun, 'arun'), isTrue);
      expect(employeeMatches(_arun, 'nz-0002'), isTrue, reason: 'employee code');
      expect(employeeMatches(_chitra, 'designer'), isTrue, reason: 'role');
      expect(employeeMatches(_bindu, 'finance bindu'), isTrue, reason: 'department + name, any order');
      expect(employeeMatches(_bindu, 'finance arun'), isFalse);
      expect(employeeMatches(_dev, '  '), isTrue);
    });

    test('the pool: everyone in the project\'s departments, each once, by name', () {
      List<Employee> staffOf(String d) => _staff.where((e) => e.department!.toLowerCase() == d.toLowerCase()).toList();
      expect(projectPeoplePool(staffOf, ['Marketing', 'finance', 'MARKETING', '']).map((e) => e.name),
          ['Arun Das', 'Bindu Paul', 'Chitra Menon', 'Mira Nair']);
    });

    test('the names a project already knows its members by; the note says who can be picked', () {
      final p = _project(members: [
        {'_id': 'e2', 'name': 'Arun Das'},
        {'_id': 'x9', 'name': 'Old Hand'},
      ]);
      expect(memberNamesOf(p), {'e2': 'Arun Das', 'x9': 'Old Hand'});
      expect(teamPoolNote('Marketing', ['Finance', 'marketing']), startsWith('People from Marketing, Finance.'));
      expect(teamPoolNote('Accounts', const []), startsWith('People from Accounts.'));
      expect(teamPoolNote('', const []), startsWith('Pick the owning department first'));
      expect(teamPoolNote('', ['Finance']), startsWith('People from Finance.'), reason: 'no stray comma');
    });
  });

  group('the project form (Company Projects)', () {
    Future<_Projects> open(WidgetTester t, {List<Project> projects = const [], Future<List<Employee>>? staff, String role = 'artist', bool askFirst = false}) async {
      _size(t);
      final fake = _Projects(projects)..askFirst = askFirst;
      await t.pumpWidget(ProviderScope(
        overrides: <Override>[
          authSessionProvider.overrideWithValue(_session(role: role)),
          projectServiceProvider.overrideWithValue(fake),
          departmentsProvider.overrideWith((ref) async => const [Department(id: 'd1', name: 'Marketing'), Department(id: 'd2', name: 'Finance')]),
          employeesProvider.overrideWith((ref) => staff ?? Future.value(_staff)),
          strategicVisionProvider.overrideWith((ref) => Completer<StrategicVisionModel>().future),
        ],
        child: MaterialApp(theme: AppTheme.lightTheme, home: const CompanyProjectsScreen()),
      ));
      await t.pumpAndSettle();
      return fake;
    }

    Future<void> openNew(WidgetTester t, {String? owner = 'Marketing'}) async {
      await t.tap(find.widgetWithText(FilledButton, 'Propose Project').first);
      await t.pumpAndSettle();
      if (owner != null) {
        await t.tap(find.byKey(const Key('form_owner_dept')));
        await t.pumpAndSettle();
        await t.tap(find.text(owner).last);
        await t.pumpAndSettle();
      }
    }

    testWidgets('a new project starts with NO owning department; nothing is saved until one is picked', (t) async {
      final fake = await open(t);
      await openNew(t, owner: null);
      final owner = t.widget<DropdownButtonFormField<String>>(find.byKey(const Key('form_owner_dept')));
      expect(owner.initialValue, isNull, reason: 'not simply the first department in the list');
      expect(find.text('Pick a department'), findsOneWidget);
      expect(find.textContaining('Pick the owning department first'), findsOneWidget, reason: 'the team note');
      // the search has nobody to offer until a department is on the project (an empty name used to mean everyone)
      await t.tap(find.byKey(const Key('emp_multi_add')));
      await t.pumpAndSettle();
      expect(_listed(t), isEmpty);
      await t.tap(find.byKey(const Key('emp_multi_done')));
      await t.pumpAndSettle();
      await t.enterText(find.widgetWithText(TextField, 'Project name *'), 'Winter shoot');
      await t.enterText(find.byKey(const Key('cost_total')), '50000');
      await t.ensureVisible(find.byKey(const Key('preset_2 weeks')));
      await t.tap(find.byKey(const Key('preset_2 weeks')));
      await t.pumpAndSettle();
      await t.ensureVisible(find.text('Send proposal'));
      await t.tap(find.text('Send proposal'));
      await t.pumpAndSettle();
      expect(fake.saved, isEmpty);
      expect(find.text('Pick the owning department'), findsOneWidget);
      // picking one fills the team search with its people, and it saves
      await t.ensureVisible(find.byKey(const Key('form_owner_dept')));
      await t.tap(find.byKey(const Key('form_owner_dept')));
      await t.pumpAndSettle();
      await t.tap(find.text('Finance').last);
      await t.pumpAndSettle();
      expect(find.textContaining('People from Finance.'), findsOneWidget);
      await t.ensureVisible(find.text('Send proposal'));
      await t.tap(find.text('Send proposal'));
      await t.pumpAndSettle();
      expect(fake.saved.single['targetDepartment'], 'Finance');
    });

    testWidgets('an administrator\'s new project: no manager to pick until the owning department is chosen', (t) async {
      await open(t, role: 'admin');
      await t.tap(find.text('New Project').first);
      await t.pumpAndSettle();
      expect(find.textContaining('Pick the owning department first — its people are the ones who can manage'), findsOneWidget);
      await t.tap(find.byKey(const Key('form_owner_dept')));
      await t.pumpAndSettle();
      await t.tap(find.text('Marketing').last);
      await t.pumpAndSettle();
      expect(find.byKey(const Key('form_manager_note')), findsNothing, reason: 'Marketing has people to pick');
      await t.tap(find.text('Tap to select'));
      await t.pumpAndSettle();
      expect(find.text('Mira Nair'), findsWidgets);
      expect(find.text('Bindu Paul'), findsNothing, reason: 'only the owning department\'s people manage it');
    });

    testWidgets('the team is a search, not a chip for every employee; the people picked are sent', (t) async {
      final fake = await open(t);
      await openNew(t);
      expect(find.byType(FilterChip).evaluate().where((e) => ((e.widget as FilterChip).label as Text).data == 'Arun Das'), isEmpty,
          reason: 'no wall of names');
      expect(find.text('Nobody yet — search and add people'), findsOneWidget);
      await t.tap(find.byKey(const Key('emp_multi_add')));
      await t.pumpAndSettle();
      expect(_listed(t), ['e2', 'e4', 'm1'], reason: 'Marketing\'s people');
      await t.enterText(find.byKey(const Key('emp_multi_search')), 'nz-0002');
      await t.pumpAndSettle();
      expect(_listed(t), ['e2'], reason: 'found by employee code');
      await t.tap(find.byKey(const Key('emp_multi_e2')));
      await t.pump();
      await t.enterText(find.byKey(const Key('emp_multi_search')), 'designer');
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('emp_multi_e4')));
      await t.pump();
      expect(find.text('2 picked'), findsOneWidget);
      await t.tap(find.byKey(const Key('emp_multi_done')));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('emp_multi_chip_e2')), findsOneWidget);
      expect(find.byKey(const Key('emp_multi_chip_e4')), findsOneWidget);
      // and saving the proposal sends them
      await t.enterText(find.widgetWithText(TextField, 'Project name *'), 'Winter shoot');
      await t.enterText(find.byKey(const Key('cost_total')), '50000');
      await t.ensureVisible(find.byKey(const Key('preset_2 weeks')));
      await t.tap(find.byKey(const Key('preset_2 weeks')));
      await t.pumpAndSettle();
      await t.ensureVisible(find.text('Send proposal'));
      await t.tap(find.text('Send proposal'));
      await t.pumpAndSettle();
      expect((fake.saved.single['members'] as List).toSet(), {'e2', 'e4'});
    });

    testWidgets('picking a department under "Also involves" brings its people into the search', (t) async {
      await open(t);
      await openNew(t);
      await t.ensureVisible(find.widgetWithText(FilterChip, 'Finance'));
      await t.tap(find.widgetWithText(FilterChip, 'Finance'));
      await t.pumpAndSettle();
      expect(find.textContaining('People from Marketing, Finance.'), findsOneWidget);
      await _pick(t, search: 'bindu', tick: ['e3']);
      expect(find.byKey(const Key('emp_multi_chip_e3')), findsOneWidget);
    });

    testWidgets('the staff list arriving after the form opened fills the team search', (t) async {
      final staff = Completer<List<Employee>>();
      await open(t, staff: staff.future);
      await openNew(t);
      staff.complete(_staff);
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('emp_multi_add')));
      await t.pumpAndSettle();
      expect(_listed(t), ['e2', 'e4', 'm1']);
    });

    testWidgets('editing: someone on the team who is no longer in the departments still shows, and can be removed', (t) async {
      final fake = await open(t, projects: [
        _project(members: [
          {'_id': 'm1', 'name': 'Mira Nair'}, // the manager, listed as a member too
          {'_id': 'e2', 'name': 'Arun Das'},
          {'_id': 'x9', 'name': 'Old Hand'},
        ]),
      ]);
      await t.tap(find.byTooltip('Project actions').first);
      await t.pumpAndSettle();
      await t.tap(find.text('Edit Settings'));
      await t.pumpAndSettle();
      expect(find.text('Old Hand'), findsOneWidget, reason: 'not hidden any more');
      expect(find.byKey(const Key('emp_multi_chip_m1')), findsNothing, reason: 'the manager is not listed as a member');
      await t.tap(find.byTooltip('Remove Old Hand'));
      await t.pumpAndSettle();
      expect(find.text('Old Hand'), findsNothing);
      await t.ensureVisible(find.text('Save changes'));
      await t.tap(find.text('Save changes'));
      await t.pumpAndSettle();
      expect(fake.saved.single['members'], ['e2']);
      expect(fake.saved.single['managerId'], 'm1');
    });
  });

  group('the project form: taking someone off who has work', () {
    testWidgets('Save changes asks first, then sends the answer with the project', (t) async {
      _size(t);
      final fake = _Projects([
        _project(members: [
          {'_id': 'e2', 'name': 'Arun Das'},
          {'_id': 'e4', 'name': 'Chitra Menon'},
        ]),
      ])
        ..askFirst = true;
      await t.pumpWidget(ProviderScope(
        overrides: <Override>[
          authSessionProvider.overrideWithValue(_session()),
          projectServiceProvider.overrideWithValue(fake),
          departmentsProvider.overrideWith((ref) async => const [Department(id: 'd1', name: 'Marketing'), Department(id: 'd2', name: 'Finance')]),
          employeesProvider.overrideWith((ref) async => _staff),
          strategicVisionProvider.overrideWith((ref) => Completer<StrategicVisionModel>().future),
        ],
        child: MaterialApp(theme: AppTheme.lightTheme, home: const CompanyProjectsScreen()),
      ));
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('Project actions').first);
      await t.pumpAndSettle();
      await t.tap(find.text('Edit Settings'));
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('Remove Chitra Menon'));
      await t.pumpAndSettle();
      await t.ensureVisible(find.text('Save changes'));
      await t.tap(find.text('Save changes'));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('team_removal_dialog')), findsOneWidget);
      await t.tap(find.byKey(const Key('team_removal_confirm')));
      await t.pumpAndSettle();
      expect(fake.saved.length, 2);
      expect([fake.saved.last['confirmRemoval'], fake.saved.last['unassignTasks']], [true, true]);
      expect(fake.saved.last['name'], 'Winter campaign', reason: 'the whole project, with the answer');
      expect(find.text('Project updated'), findsOneWidget);
    });
  });

  group('the project\'s team on its Overview', () {
    Future<_Projects> card(WidgetTester t, Project p, {String me = 'e9', Size size = const Size(1100, 1000), bool askFirst = false}) async {
      _size(t, size);
      final fake = _Projects()..askFirst = askFirst;
      await t.pumpWidget(const SizedBox.shrink());
      await t.pumpWidget(ProviderScope(
        overrides: <Override>[
          authSessionProvider.overrideWithValue(_session(role: 'admin', emp: me)),
          projectServiceProvider.overrideWithValue(fake),
          employeesProvider.overrideWith((ref) async => _staff),
        ],
        child: MaterialApp(theme: AppTheme.lightTheme, home: Scaffold(body: SingleChildScrollView(child: ProjectPeopleCard(project: p)))),
      ));
      await t.pumpAndSettle();
      return fake;
    }

    final team = _project(members: [
      {'_id': 'e2', 'name': 'Arun Das'},
      {'_id': 'e4', 'name': 'Chitra Menon'},
      {'_id': 'x9', 'name': 'Old Hand'},
    ]);

    testWidgets('shows the manager and the members, everyone by name', (t) async {
      await card(t, team);
      expect(find.text('Project team · 4'), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('people_chip_manager')), matching: find.text('Mira Nair')), findsOneWidget);
      for (final n in ['Arun Das', 'Chitra Menon', 'Old Hand']) {
        expect(find.text(n), findsOneWidget);
      }
      expect(find.byKey(const Key('people_edit')), findsOneWidget);
    });

    testWidgets('no team yet: says so and how to add one', (t) async {
      await card(t, _project());
      expect(find.text('Project team · 1'), findsOneWidget);
      expect(find.textContaining('No team members yet. Add the people'), findsOneWidget);
    });

    testWidgets('only those who run the project may edit the team, and not once it is cancelled', (t) async {
      await card(t, _project(canManage: false));
      expect(find.byKey(const Key('people_edit')), findsNothing);
      expect(find.text('No team members yet.'), findsOneWidget);
      await card(t, _project(status: 'cancelled'));
      expect(find.byKey(const Key('people_edit')), findsNothing);
    });

    testWidgets('Edit team: add from the search, remove with ×, and only the manager and the team are saved', (t) async {
      final fake = await card(t, team);
      await t.tap(find.byKey(const Key('people_edit')));
      await t.pumpAndSettle();
      expect(find.descendant(of: find.byType(BottomSheet), matching: find.text('Edit team')), findsOneWidget);
      expect(find.textContaining('People from Marketing, Finance.'), findsOneWidget);
      await _pick(t, search: 'bindu', tick: ['e3']);
      await t.tap(find.byTooltip('Remove Chitra Menon'));
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('Remove Old Hand'));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('people_save')));
      await t.pumpAndSettle();
      expect(fake.saved, isEmpty, reason: 'not the whole project');
      expect(fake.teams.single.keys.toSet(), {'managerId', 'members', '_id'}, reason: 'nothing else about the project is touched');
      expect(fake.teams.single['_id'], 'p1');
      expect(fake.teams.single['managerId'], 'm1');
      expect((fake.teams.single['members'] as List).toSet(), {'e2', 'e3'});
      expect(find.text('Team updated'), findsOneWidget);
    });

    testWidgets('a new manager: picked from the owning department, and no longer listed as a member', (t) async {
      final fake = await card(t, team);
      await t.tap(find.byKey(const Key('people_edit')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('people_manager')));
      await t.pumpAndSettle();
      await t.tap(find.text('Arun Das').last);
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('people_save')));
      await t.pumpAndSettle();
      expect(fake.teams.single['managerId'], 'e2');
      expect(fake.teams.single['members'], isNot(contains('e2')));
    });

    testWidgets('taking off someone with work: asked first; "Keep them" saves nothing, "Take off" unassigns their tasks', (t) async {
      final fake = await card(t, team, askFirst: true);
      await t.tap(find.byKey(const Key('people_edit')));
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('Remove Chitra Menon'));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('people_save')));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('team_removal_dialog')), findsOneWidget);
      expect(find.text('Take Chitra Menon off the project?'), findsOneWidget);
      expect(find.textContaining('2 open tasks · HR placement (50%) until 24 Dec'), findsOneWidget);
      expect(find.text('Their HR placement on this project ends today, and HR is told.'), findsOneWidget);
      await t.tap(find.text('Keep them'));
      await t.pumpAndSettle();
      expect(fake.teams.length, 1, reason: 'only the first try');
      expect(find.byKey(const Key('people_save')), findsOneWidget, reason: 'the sheet stays open, nothing saved');
      expect(find.text('Team updated'), findsNothing);
      // again, and this time take her off (her open tasks unassigned — ticked by default)
      await t.tap(find.byKey(const Key('people_save')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('team_removal_confirm')));
      await t.pumpAndSettle();
      expect(fake.teams.last['confirmRemoval'], isTrue);
      expect(fake.teams.last['unassignTasks'], isTrue);
      expect(fake.teams.last['members'], isNot(contains('e4')));
      expect(find.text('Team updated'), findsOneWidget);
    });

    testWidgets('…or leaves her tasks with her when "Unassign" is unticked', (t) async {
      final fake = await card(t, team, askFirst: true);
      await t.tap(find.byKey(const Key('people_edit')));
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('Remove Chitra Menon'));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('people_save')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('team_removal_unassign')));
      await t.pump();
      expect(find.text('They stay assigned to them.'), findsOneWidget);
      await t.tap(find.byKey(const Key('team_removal_confirm')));
      await t.pumpAndSettle();
      expect([fake.teams.last['confirmRemoval'], fake.teams.last['unassignTasks']], [true, false]);
    });

    testWidgets('the lead of another department on it: Edit team for their own people only, the manager shown not picked', (t) async {
      final p = Project.fromJson({
        '_id': 'p1',
        'name': 'Winter campaign',
        'status': 'active',
        'targetDepartment': 'Marketing',
        'managerId': {'_id': 'm1', 'name': 'Mira Nair'},
        'members': [
          {'_id': 'e2', 'name': 'Arun Das'},
          {'_id': 'e3', 'name': 'Bindu Paul'},
        ],
        'departments': [
          {'name': 'Marketing', 'role': 'owner', 'status': 'accepted'},
          {'name': 'Finance', 'role': 'participant', 'status': 'accepted'},
        ],
        'access': {'role': 'dept_lead', 'canManage': false, 'leadDepartments': ['Finance']},
      });
      final fake = await card(t, p);
      expect(find.byKey(const Key('people_edit')), findsOneWidget);
      await t.tap(find.byKey(const Key('people_edit')));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('people_manager')), findsNothing);
      expect(find.byKey(const Key('people_manager_fixed')), findsOneWidget);
      expect(find.textContaining('You lead Finance on this project'), findsOneWidget);
      // Arun (Marketing) is shown locked; Bindu (Finance) can be taken off
      expect(find.byTooltip('Remove Arun Das'), findsNothing);
      expect(find.byTooltip('Remove Bindu Paul'), findsOneWidget);
      // the search offers Finance's people only
      await t.tap(find.byKey(const Key('emp_multi_add')));
      await t.pumpAndSettle();
      expect(_listed(t), ['e3']);
      await t.tap(find.byKey(const Key('emp_multi_done')));
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('Remove Bindu Paul'));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('people_save')));
      await t.pumpAndSettle();
      expect(fake.teams.single.containsKey('managerId'), isFalse, reason: 'a lead does not send a manager');
      expect(fake.teams.single['members'], ['e2'], reason: 'the rest of the team is kept');
    });


    testWidgets('a lead whose department has nobody tagged to it is offered nobody (not the whole company)', (t) async {
      final p = Project.fromJson({
        '_id': 'p1',
        'name': 'Winter campaign',
        'status': 'active',
        'targetDepartment': 'Marketing',
        'managerId': {'_id': 'm1', 'name': 'Mira Nair'},
        'members': const [],
        'departments': [
          {'name': 'Marketing', 'role': 'owner', 'status': 'accepted'},
          {'name': 'Accounts', 'role': 'participant', 'status': 'accepted'},
        ],
        'access': {'role': 'dept_lead', 'canManage': false, 'leadDepartments': ['Accounts']},
      });
      await card(t, p);
      await t.tap(find.byKey(const Key('people_edit')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('emp_multi_add')));
      await t.pumpAndSettle();
      expect(_listed(t), isEmpty, reason: 'the server refuses anyone outside Accounts, so they are not offered');
      expect(find.text('No staff to pick from yet.'), findsOneWidget);
    });

    testWidgets('the manager handing the project over is told so', (t) async {
      await card(t, team, me: 'm1');
      await t.tap(find.byKey(const Key('people_edit')));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('people_handover')), findsNothing);
      await t.tap(find.byKey(const Key('people_manager')));
      await t.pumpAndSettle();
      await t.tap(find.text('Arun Das').last);
      await t.pumpAndSettle();
      expect(find.byKey(const Key('people_handover')), findsOneWidget);
    });

    testWidgets('on a phone the picker opens as a sheet and the card fits', (t) async {
      await card(t, team, size: const Size(390, 900));
      expect(t.takeException(), isNull);
      await t.tap(find.byKey(const Key('people_edit')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('emp_multi_add')));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('emp_multi_search')), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  });

  group('the IT Projects form', () {
    final itStaff = [_e('i1', 'Ivan IT', 'IT'), _e('i2', 'Isha IT', 'IT'), _e('i3', 'Imran IT', 'IT')];

    Future<_Projects> open(WidgetTester t) async {
      _size(t);
      final fake = _Projects();
      await t.pumpWidget(ProviderScope(
        overrides: <Override>[
          authSessionProvider.overrideWithValue(_session(role: 'admin')),
          projectServiceProvider.overrideWithValue(fake),
          itProjectsProvider.overrideWith((ref) async => const <Project>[]),
          employeesProvider.overrideWith((ref) async => itStaff),
        ],
        child: MaterialApp(theme: AppTheme.lightTheme, home: const ITProjectsScreen()),
      ));
      await t.pumpAndSettle();
      await t.tap(find.text('New Project').first);
      await t.pumpAndSettle();
      return fake;
    }

    testWidgets('asks for the cost the server requires, and sends it with a searched team', (t) async {
      final fake = await open(t);
      await t.enterText(find.widgetWithText(TextField, 'Project name *'), 'Billing revamp');
      await t.tap(find.text('Tap to select'));
      await t.pumpAndSettle();
      await t.tap(find.text('Ivan IT').last);
      await t.pumpAndSettle();
      await _pick(t, search: 'isha', tick: ['i2']);
      await t.ensureVisible(find.text('Create project'));
      await t.tap(find.text('Create project'));
      await t.pumpAndSettle();
      expect(fake.saved, isEmpty, reason: 'no cost yet');
      expect(find.text('Enter the estimated cost of the project'), findsWidgets);
      await t.enterText(find.byKey(const Key('cost_total')), '80000');
      await t.ensureVisible(find.text('Create project'));
      await t.tap(find.text('Create project'));
      await t.pumpAndSettle();
      expect(fake.saved.single['budget'], 80000.0);
      expect(fake.saved.single['members'], ['i2']);
      expect(fake.saved.single['managerId'], 'i1');
    });
  });
}
