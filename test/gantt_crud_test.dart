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
import 'package:nizan_crm/features/it/domain/repositories/it_task_repository.dart';
import 'package:nizan_crm/features/it/domain/task_tree.dart';
import 'package:nizan_crm/features/it/presentation/controllers/it_tasks_notifier.dart';
import 'package:nizan_crm/features/it/presentation/screens/widgets/it_interactive_gantt.dart';
import 'package:nizan_crm/features/it/services/it_service.dart';

// Adding, editing and deleting from the Timeline itself: a + for phases and for a department's function, a menu on each row
// (add under it, add another, edit, delete), an empty timeline that offers a way to start, and rows that read as a plan.

final _today = DateTime.now();
DateTime _d(int offset) => DateTime(_today.year, _today.month, _today.day + offset);

ITTask _t(String id, String title, {String? parent, int order = 0, int from = 0, int days = 3, String dept = '', String owner = ''}) => ITTask(
      id: id,
      projectId: 'p1',
      title: title,
      parentTaskId: parent,
      order: order,
      departmentName: dept,
      assigneeId: owner,
      startDate: _d(from),
      dueDate: _d(from + days - 1),
    );

// Discovery (Requirements (Interviews)) · Build
List<ITTask> _plan() => [
      _t('p1', 'Discovery', order: 1),
      _t('t1', 'Requirements', parent: 'p1', order: 1),
      _t('s1', 'Interviews', parent: 't1', order: 1),
      _t('p2', 'Build', order: 2, from: 5),
    ];

/// The server, as far as these tests need: tasks come and go, and a delete takes the whole branch with it.
class _Repo implements IITTaskRepository {
  _Repo(this.tasks);
  List<ITTask> tasks;
  final deleted = <String>[];
  final updates = <String, Map<String, dynamic>>{};
  @override
  Future<ITTask> updateTask(String id, Map<String, dynamic> data) async {
    updates[id] = data;
    final i = tasks.indexWhere((t) => t.id == id);
    final saved = tasks[i].copyWith(order: (data['order'] as num?)?.toInt());
    tasks = [...tasks]..[i] = saved;
    return saved;
  }

  @override
  Future<List<ITTask>> getTasks({String? projectId, String? status, String? assignedTo, String? ticketType, String? severity, String? subTeam, String? search, bool mine = false}) async => tasks;
  @override
  Future<void> deleteTask(String id) async {
    deleted.add(id);
    final gone = {id, ...descendantIds(tasks, id)};
    tasks = tasks.where((t) => !gone.contains(t.id)).toList();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError('${invocation.memberName}');
}

class _Service implements ITTaskService {
  final created = <Map<String, dynamic>>[];
  @override
  Future<void> createTask(Map<String, dynamic> body) async => created.add(body);
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError('${invocation.memberName}');
}

Project _project({
  bool manager = true,
  List<String> departments = const ['Management'],
  String owner = 'Management',
  List<String> leads = const [],
}) =>
    Project.fromJson({
      '_id': 'p1',
      'name': 'Lifestyle brand at 2030',
      'targetDepartment': owner,
      'managerId': {'_id': 'm1', 'name': 'Amna'},
      'editMode': 'managed',
      'departments': [
        for (var i = 0; i < departments.length; i++) {'name': departments[i], 'role': i == 0 ? 'owner' : 'participant', 'status': 'accepted'}
      ],
      'access': {
        'role': manager ? 'manager' : 'member',
        'canManage': manager,
        'editMode': 'managed',
        'canCreateTasks': manager,
        'canEditAllTasks': manager,
        'leadDepartments': leads,
        'pendingInvitations': <String>[],
        'canDecide': false,
      },
    });

class _Host extends ConsumerWidget {
  const _Host({required this.editable, this.mode = GanttSwimlaneMode.bySubTeam});
  final bool editable;
  final GanttSwimlaneMode mode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(itProjectTasksControllerProvider('p1')).value ?? const <ITTask>[];
    return ITInteractiveGantt(tasks: list, allTasks: list, projectId: 'p1', swimlaneMode: mode, showToolbar: true, editable: editable);
  }
}

Future<({_Repo repo, _Service service})> _pump(
  WidgetTester tester, {
  List<ITTask>? tasks,
  Project? project,
  bool editable = true,
  GanttSwimlaneMode mode = GanttSwimlaneMode.bySubTeam,
  Size size = const Size(1500, 1000),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final repo = _Repo(tasks ?? _plan());
  final service = _Service();
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpWidget(ProviderScope(
    overrides: <Override>[
      authSessionProvider.overrideWithValue(AuthSession(token: 't', userId: 'u', name: 'U', email: 'u@x', role: 'crm', employeeId: 'e1')),
      projectsProvider.overrideWith((ref) async => [project ?? _project()]),
      projectEmployeesProvider('p1').overrideWith((ref) => const <Employee>[]),
      itTaskRepositoryProvider.overrideWithValue(repo),
      itTaskServiceProvider.overrideWithValue(service),
    ],
    child: MaterialApp(theme: AppTheme.lightTheme, home: Scaffold(body: _Host(editable: editable, mode: mode))),
  ));
  await tester.pumpAndSettle();
  return (repo: repo, service: service);
}

Finder _k(String key) => find.byKey(Key(key));

Future<void> _openMenu(WidgetTester tester, String key) async {
  await tester.tap(_k(key));
  await tester.pumpAndSettle();
}

Future<void> _pick(WidgetTester tester, String menuKey, String itemText) async {
  await _openMenu(tester, menuKey);
  await tester.tap(find.text(itemText));
  await tester.pumpAndSettle();
}

/// Types a title into the editor sheet and presses its Create button.
Future<void> _createInEditor(WidgetTester tester, String title) async {
  await tester.enterText(find.widgetWithText(TextField, 'Title *'), title);
  final create = find.widgetWithText(FilledButton, 'Create task');
  await tester.ensureVisible(create);
  await tester.pumpAndSettle();
  await tester.tap(create);
  await tester.pumpAndSettle();
}

void main() {
  group('the rows read as a plan', () {
    testWidgets('a phase, then its tasks, then their sub-tasks — each one in from the one above', (tester) async {
      await _pump(tester);
      final title = {for (final x in ['Discovery', 'Requirements', 'Interviews', 'Build']) x: tester.getTopLeft(find.text(x).first)};
      // top to bottom in plan order
      expect(title['Discovery']!.dy, lessThan(title['Requirements']!.dy));
      expect(title['Requirements']!.dy, lessThan(title['Interviews']!.dy));
      expect(title['Interviews']!.dy, lessThan(title['Build']!.dy));
      // and in: a task sits right of its phase, a sub-task right of its task
      expect(title['Requirements']!.dx, greaterThan(title['Discovery']!.dx));
      expect(title['Interviews']!.dx, greaterThan(title['Requirements']!.dx));
    });

    testWidgets('a phase that was created last but ordered first still comes first', (tester) async {
      await _pump(tester, tasks: [_t('late', 'Later phase', order: 5), _t('early', 'Earlier phase', order: 1)]);
      expect(tester.getTopLeft(find.text('Earlier phase').first).dy, lessThan(tester.getTopLeft(find.text('Later phase').first).dy));
    });
  });

  group('the + above the rows', () {
    testWidgets('offers a new phase and the plan wizard', (tester) async {
      await _pump(tester);
      await _openMenu(tester, 'gantt_add');
      expect(_k('gantt_add_phase'), findsOneWidget);
      expect(find.text('Add phase'), findsOneWidget);
      expect(_k('gantt_add_wizard'), findsOneWidget);
    });

    testWidgets('Add phase opens the editor with no parent, and saving sends a top-level task', (tester) async {
      final s = await _pump(tester);
      await _pick(tester, 'gantt_add', 'Add phase');
      expect(find.text('New Task'), findsOneWidget);
      await _createInEditor(tester, 'Launch');
      expect(s.service.created, hasLength(1));
      expect(s.service.created.single['title'], 'Launch');
      expect(s.service.created.single['parentTaskId'], isNull);
    });

    testWidgets('the wizard opens from it', (tester) async {
      await _pump(tester);
      await _pick(tester, 'gantt_add', 'Plan a function (wizard)…');
      expect(find.text('Functional Plan & Gantt Auto-Scheduler'), findsOneWidget);
      // it knows the plan is already there
      expect(_k('wizard_existing_note'), findsOneWidget);
    });
  });

  group('the menu on a row', () {
    testWidgets('on a phase: add a task to it, add another phase, edit, delete', (tester) async {
      await _pump(tester);
      await _openMenu(tester, 'gantt_row_menu_p1');
      expect(find.text('Add task to this phase'), findsOneWidget);
      expect(find.text('Add another phase'), findsOneWidget);
      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
    });

    testWidgets('on a task: add a sub-task, add another task; on a sub-task: another sub-task', (tester) async {
      await _pump(tester);
      await _openMenu(tester, 'gantt_row_menu_t1');
      expect(find.text('Add sub-task'), findsOneWidget);
      expect(find.text('Add another task'), findsOneWidget);
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      await _openMenu(tester, 'gantt_row_menu_s1');
      expect(find.text('Add another sub-task'), findsOneWidget);
    });

    testWidgets('Add sub-task opens the editor under that task, and what is saved hangs under it', (tester) async {
      final s = await _pump(tester);
      await _pick(tester, 'gantt_row_menu_t1', 'Add sub-task');
      expect(find.text('New Task'), findsOneWidget);
      // the parent is filled in: its WBS number and title
      expect(find.textContaining('Requirements'), findsWidgets);
      await _createInEditor(tester, 'Book rooms');
      expect(s.service.created.single['parentTaskId'], 't1');
      expect(s.service.created.single['title'], 'Book rooms');
    });

    testWidgets('Add another task puts the new one beside it, under the same phase', (tester) async {
      final s = await _pump(tester);
      await _pick(tester, 'gantt_row_menu_t1', 'Add another task');
      await _createInEditor(tester, 'Budget');
      expect(s.service.created.single['parentTaskId'], 'p1');
    });

    testWidgets('Edit opens the task\'s details', (tester) async {
      await _pump(tester);
      await _pick(tester, 'gantt_row_menu_t1', 'Edit');
      expect(find.text('Requirements'), findsWidgets);
      expect(find.byType(Dialog), findsOneWidget);
    });
  });

  group('moving up and down', () {
    double y(WidgetTester t, String title) => t.getTopLeft(find.text(title).first).dy;
    bool enabled(WidgetTester t, String key) => t.widget<PopupMenuItem<String>>(find.byKey(Key(key))).enabled;

    testWidgets('the first phase cannot go up and the last cannot go down; the ones between can go either way', (tester) async {
      await _pump(tester, tasks: [_t('a', 'Alpha', order: 1), _t('b', 'Beta', order: 2), _t('c', 'Gamma', order: 3)]);
      await _openMenu(tester, 'gantt_row_menu_a');
      expect(enabled(tester, 'gantt_menu_up'), isFalse);
      expect(enabled(tester, 'gantt_menu_down'), isTrue);
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      await _openMenu(tester, 'gantt_row_menu_b');
      expect(enabled(tester, 'gantt_menu_up'), isTrue);
      expect(enabled(tester, 'gantt_menu_down'), isTrue);
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      await _openMenu(tester, 'gantt_row_menu_c');
      expect(enabled(tester, 'gantt_menu_down'), isFalse);
    });

    testWidgets('Move down swaps the phase with the next one — written to the server, and the rows follow', (tester) async {
      final s = await _pump(tester, tasks: [_t('a', 'Alpha', order: 1), _t('b', 'Beta', order: 2), _t('c', 'Gamma', order: 3)]);
      expect(y(tester, 'Alpha'), lessThan(y(tester, 'Beta')));
      await _pick(tester, 'gantt_row_menu_a', 'Move down');
      expect(s.repo.updates, {'a': {'order': 2}, 'b': {'order': 1}}); // only the two that traded
      expect(y(tester, 'Beta'), lessThan(y(tester, 'Alpha')));
      expect(y(tester, 'Alpha'), lessThan(y(tester, 'Gamma')));
    });

    testWidgets('a phase takes its tasks with it', (tester) async {
      await _pump(tester, tasks: [_t('a', 'Alpha', order: 1), _t('a1', 'Alpha task', parent: 'a', order: 1), _t('b', 'Beta', order: 2)]);
      await _pick(tester, 'gantt_row_menu_b', 'Move up');
      expect(y(tester, 'Beta'), lessThan(y(tester, 'Alpha')));
      expect(y(tester, 'Alpha'), lessThan(y(tester, 'Alpha task'))); // still right under its own phase
    });

    testWidgets('a task moves only among the tasks of its own phase', (tester) async {
      final s = await _pump(tester, tasks: [_t('a', 'Alpha', order: 1), _t('a1', 'One', parent: 'a', order: 1), _t('a2', 'Two', parent: 'a', order: 2), _t('b', 'Beta', order: 2)]);
      await _pick(tester, 'gantt_row_menu_a2', 'Move up');
      expect(s.repo.updates, {'a2': {'order': 1}, 'a1': {'order': 2}}); // never Beta, another phase's
      expect(y(tester, 'Two'), lessThan(y(tester, 'One')));
    });

    testWidgets('siblings with the same order (a plan made before they were kept apart) still move', (tester) async {
      await _pump(tester, tasks: [_t('a', 'Alpha'), _t('b', 'Beta')]); // both order 0
      expect(y(tester, 'Alpha'), lessThan(y(tester, 'Beta')));
      await _pick(tester, 'gantt_row_menu_b', 'Move up');
      expect(y(tester, 'Beta'), lessThan(y(tester, 'Alpha')));
    });

    testWidgets('no Move for someone with no say in the plan', (tester) async {
      await _pump(tester, tasks: [_t('a', 'Alpha', order: 1), _t('b', 'Beta', order: 2)], project: _project(manager: false));
      await _openMenu(tester, 'gantt_row_menu_a');
      expect(find.text('Move up'), findsNothing);
      expect(find.text('Move down'), findsNothing);
    });

    testWidgets('a department lead cannot reorder past another department\'s phase', (tester) async {
      final tasks = [_t('a', 'IT work', order: 1, dept: 'IT'), _t('b', 'Marketing work', order: 2, dept: 'Marketing')];
      await _pump(
        tester,
        tasks: tasks,
        mode: GanttSwimlaneMode.byDepartment,
        project: Project.fromJson({
          '_id': 'p1',
          'name': 'Omnichannel',
          'targetDepartment': 'Marketing',
          'editMode': 'managed',
          'departments': [
            {'name': 'Marketing', 'role': 'owner', 'status': 'accepted'},
            {'name': 'IT', 'role': 'participant', 'status': 'accepted'},
          ],
          'access': {'role': 'dept_lead', 'canManage': false, 'editMode': 'managed', 'canCreateTasks': true, 'canEditAllTasks': false, 'leadDepartments': ['IT'], 'pendingInvitations': <String>[], 'canDecide': false},
        }),
      );
      await _openMenu(tester, 'gantt_row_menu_a');
      expect(enabled(tester, 'gantt_menu_down'), isFalse); // it would have to change Marketing's phase too
    });
  });

  group('deleting', () {
    testWidgets('asks first and says how much goes with a phase; Cancel deletes nothing', (tester) async {
      final s = await _pump(tester);
      await _pick(tester, 'gantt_row_menu_p1', 'Delete');
      expect(find.text('Delete phase?'), findsOneWidget);
      expect(find.textContaining('and all 2 item(s) under it will be deleted'), findsOneWidget);
      await tester.tap(_k('gantt_delete_cancel'));
      await tester.pumpAndSettle();
      expect(s.repo.deleted, isEmpty);
      expect(find.text('Requirements'), findsWidgets);
    });

    testWidgets('a task asks too, and a leaf has nothing going with it', (tester) async {
      await _pump(tester);
      await _pick(tester, 'gantt_row_menu_s1', 'Delete');
      expect(find.text('Delete task?'), findsOneWidget);
      expect(find.textContaining('“Interviews” will be deleted.'), findsOneWidget);
    });

    testWidgets('Delete removes the phase AND everything under it from the chart at once', (tester) async {
      final s = await _pump(tester);
      await _pick(tester, 'gantt_row_menu_p1', 'Delete');
      await tester.tap(_k('gantt_delete_confirm'));
      await tester.pumpAndSettle();
      expect(s.repo.deleted, ['p1']);
      // not left behind as orphans until the next refresh
      expect(find.text('Discovery'), findsNothing);
      expect(find.text('Requirements'), findsNothing);
      expect(find.text('Interviews'), findsNothing);
      expect(find.text('Build'), findsWidgets);
    });
  });

  group('an empty timeline', () {
    testWidgets('offers a first phase and the wizard instead of a dead end', (tester) async {
      final s = await _pump(tester, tasks: const []);
      expect(find.text('Nothing on the timeline yet'), findsOneWidget);
      expect(find.textContaining('No IT tasks match'), findsNothing);
      expect(_k('gantt_empty_wizard'), findsOneWidget);
      await tester.tap(_k('gantt_empty_add_phase'));
      await tester.pumpAndSettle();
      await _createInEditor(tester, 'Kick-off');
      expect(s.service.created.single['title'], 'Kick-off');
    });

    testWidgets('someone who cannot add is told who does', (tester) async {
      await _pump(tester, tasks: const [], project: _project(manager: false));
      expect(find.text('The project manager adds the work to this project.'), findsOneWidget);
      expect(_k('gantt_empty_add_phase'), findsNothing);
      expect(_k('gantt_empty_wizard'), findsNothing);
    });

    testWidgets('the Roadmap, which filters tasks, keeps its own wording and has nothing to add', (tester) async {
      await _pump(tester, tasks: const [], editable: false);
      expect(find.text('No IT tasks match the current filters'), findsOneWidget);
      expect(_k('gantt_empty_add_phase'), findsNothing);
    });
  });

  group('who sees what', () {
    testWidgets('someone with no say in the plan: no +, no add or delete — only the task\'s details', (tester) async {
      await _pump(tester, project: _project(manager: false));
      expect(_k('gantt_add'), findsNothing);
      await _openMenu(tester, 'gantt_row_menu_t1');
      expect(find.text('View details'), findsOneWidget);
      expect(find.text('Add sub-task'), findsNothing);
      expect(find.text('Delete'), findsNothing);
    });

    testWidgets('the Roadmap has no + and no row menus', (tester) async {
      await _pump(tester, editable: false);
      expect(_k('gantt_add'), findsNothing);
      expect(_k('gantt_row_menu_t1'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a department lead can add in their own department, and not in another', (tester) async {
      final tasks = [_t('a', 'IT work', dept: 'IT'), _t('b', 'Marketing work', dept: 'Marketing')];
      await _pump(
        tester,
        tasks: tasks,
        mode: GanttSwimlaneMode.byDepartment,
        project: Project.fromJson({
          '_id': 'p1',
          'name': 'Omnichannel',
          'targetDepartment': 'Marketing',
          'editMode': 'managed',
          'departments': [
            {'name': 'Marketing', 'role': 'owner', 'status': 'accepted'},
            {'name': 'IT', 'role': 'participant', 'status': 'accepted'},
          ],
          'access': {'role': 'dept_lead', 'canManage': false, 'editMode': 'managed', 'canCreateTasks': true, 'canEditAllTasks': false, 'leadDepartments': ['IT'], 'pendingInvitations': <String>[], 'canDecide': false},
        }),
      );
      expect(_k('gantt_lane_add_dept-IT'), findsOneWidget);
      expect(_k('gantt_lane_add_dept-Marketing'), findsNothing);
    });
  });

  group('a department\'s own lane', () {
    final tasks = [_t('a', 'IT work', dept: 'IT'), _t('b', 'Marketing work', dept: 'Marketing')];
    final cross = _project(departments: ['Marketing', 'IT'], owner: 'Marketing');

    testWidgets('has a + to add a phase for it, or plan its function', (tester) async {
      await _pump(tester, tasks: tasks, mode: GanttSwimlaneMode.byDepartment, project: cross);
      await _openMenu(tester, 'gantt_lane_add_dept-IT');
      expect(find.text('Add phase for IT'), findsOneWidget);
      expect(find.text('Plan IT function…'), findsOneWidget);
    });

    testWidgets('Add phase for IT opens the editor already in IT', (tester) async {
      final s = await _pump(tester, tasks: tasks, mode: GanttSwimlaneMode.byDepartment, project: cross);
      await _pick(tester, 'gantt_lane_add_dept-IT', 'Add phase for IT');
      final dept = tester.widget<DropdownButtonFormField<String>>(find.byType(DropdownButtonFormField<String>).first);
      expect(dept.initialValue, 'IT');
      await _createInEditor(tester, 'Infrastructure');
      expect(s.service.created.single['departmentName'], 'IT');
      expect(s.service.created.single['parentTaskId'], isNull);
    });

    testWidgets('a task added under an IT task starts in IT too', (tester) async {
      final s = await _pump(tester, tasks: tasks, mode: GanttSwimlaneMode.byDepartment, project: cross);
      await _pick(tester, 'gantt_row_menu_a', 'Add task to this phase');
      await _createInEditor(tester, 'Servers');
      expect(s.service.created.single['departmentName'], 'IT');
      expect(s.service.created.single['parentTaskId'], 'a');
    });

    testWidgets('Plan IT function… opens the wizard planning for IT', (tester) async {
      await _pump(tester, tasks: tasks, mode: GanttSwimlaneMode.byDepartment, project: cross);
      await _pick(tester, 'gantt_lane_add_dept-IT', 'Plan IT function…');
      expect(find.text('Functional Plan & Gantt Auto-Scheduler'), findsOneWidget);
      final dept = tester.widget<DropdownButtonFormField<String>>(find.byType(DropdownButtonFormField<String>).first);
      expect(dept.initialValue, 'IT');
    });

    testWidgets('a single-department project has no lane +', (tester) async {
      await _pump(tester, mode: GanttSwimlaneMode.bySubTeam);
      expect(find.byWidgetPredicate((w) => w.key.toString().contains('gantt_lane_add_')), findsNothing);
    });
  });
}
