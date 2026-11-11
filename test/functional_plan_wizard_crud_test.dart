import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:nizan_crm/core/models/employee.dart';
import 'package:nizan_crm/core/theme/app_theme.dart';
import 'package:nizan_crm/features/it/data/it_task.dart';
import 'package:nizan_crm/features/it/data/project.dart';
import 'package:nizan_crm/features/it/domain/repositories/it_task_repository.dart';
import 'package:nizan_crm/features/it/presentation/controllers/it_tasks_notifier.dart';
import 'package:nizan_crm/features/it/presentation/screens/widgets/functional_plan_wizard_dialog.dart';
import 'package:nizan_crm/features/it/services/it_service.dart';

// The Gantt Plan Wizard: nothing is pre-filled — the phases and tasks are the ones you add, rename, reorder and delete;
// a task can have sub-tasks (and a task with them spans them); it adds to a plan that is already there instead of laying a
// second copy beside it; and what it sends to the server has every parent made before its children.

class _Repo implements IITTaskRepository {
  final created = <Map<String, dynamic>>[];
  final updated = <String, Map<String, dynamic>>{};
  var _n = 0;
  @override
  Future<ITTask> createTask(Map<String, dynamic> data) async {
    created.add(data);
    return ITTask(id: 'c${++_n}', projectId: 'p1', title: (data['title'] ?? '').toString());
  }

  @override
  Future<ITTask> updateTask(String id, Map<String, dynamic> data) async {
    updated[id] = data;
    return ITTask(id: id, projectId: 'p1', title: '');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError('${invocation.memberName}');
}

Project _project({List<String> departments = const ['IT'], String owner = 'IT'}) => Project.fromJson({
      '_id': 'p1',
      'name': 'Lifestyle brand at 2030',
      'targetDepartment': owner,
      'managerId': {'_id': 'm1', 'name': 'Amna'},
      'editMode': 'managed',
      'departments': [
        for (var i = 0; i < departments.length; i++) {'name': departments[i], 'role': i == 0 ? 'owner' : 'participant', 'status': 'accepted'}
      ],
      'access': {'role': 'manager', 'canManage': true, 'editMode': 'managed', 'canCreateTasks': true, 'canEditAllTasks': true, 'leadDepartments': <String>[], 'pendingInvitations': <String>[], 'canDecide': false},
    });

ITTask _existing(String id, String title, {String? parent, int order = 0}) => ITTask(id: id, projectId: 'p1', title: title, parentTaskId: parent, order: order);

typedef _Seed = ({List<PlanPhaseDraft> phases, List<PlanTaskDraft> tasks});

/// A plan to start from (the wizard pre-fills none of its own): four phases, a task in each, each waiting for the one before.
_Seed _four() => (
      phases: [
        PlanPhaseDraft(id: 'ph1', name: 'Discovery & Planning'),
        PlanPhaseDraft(id: 'ph2', name: 'Implementation & Build'),
        PlanPhaseDraft(id: 'ph3', name: 'Testing & Review'),
        PlanPhaseDraft(id: 'ph4', name: 'Launch & Handoff'),
      ],
      tasks: [
        PlanTaskDraft(id: 'tk1', phaseId: 'ph1', title: 'Requirements & Scope Approval', durationDays: 3),
        PlanTaskDraft(id: 'tk2', phaseId: 'ph2', title: 'Execution & Deliverable Build', durationDays: 7, predecessorIds: ['tk1']),
        PlanTaskDraft(id: 'tk3', phaseId: 'ph3', title: 'Quality Assurance & Stakeholder Review', durationDays: 3, predecessorIds: ['tk2']),
        PlanTaskDraft(id: 'tk4', phaseId: 'ph4', title: 'Go-Live Release & Milestone Sign-off', durationDays: 1, isMilestone: true, predecessorIds: ['tk3']),
      ],
    );

/// One phase with two tasks, to try moving things about.
_Seed _two() => (
      phases: [PlanPhaseDraft(id: 'ph1', name: 'Design')],
      tasks: [
        PlanTaskDraft(id: 'tk1', phaseId: 'ph1', title: 'First', durationDays: 2),
        PlanTaskDraft(id: 'tk2', phaseId: 'ph1', title: 'Second', durationDays: 2),
      ],
    );

Future<_Repo> _open(
  WidgetTester tester, {
  List<ITTask> existing = const [],
  Project? project,
  String? department,
  _Seed? seed,
}) async {
  tester.view.physicalSize = const Size(1500, 1100);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final repo = _Repo();
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpWidget(ProviderScope(
    overrides: <Override>[
      projectEmployeesProvider('p1').overrideWith((ref) => const <Employee>[]),
      itTaskRepositoryProvider.overrideWithValue(repo),
    ],
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: Builder(
          builder: (context) => FilledButton(
            onPressed: () => showDialog<void>(
              context: context,
              barrierDismissible: false,
              builder: (_) => FunctionalPlanWizardDialog(
                projectId: 'p1',
                projectName: 'Lifestyle brand at 2030',
                existingTasks: existing,
                project: project ?? _project(),
                initialDepartment: department,
                seed: seed,
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return repo;
}

Future<void> _continue(WidgetTester tester, [int times = 1]) async {
  for (var i = 0; i < times; i++) {
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
  }
}

/// How many tasks the plan holds, as the last step counts them (the list builds only the rows on screen).
Future<int> _total(WidgetTester tester) async {
  await _continue(tester); // to the last step
  final item = find.ancestor(of: find.text('Total Tasks'), matching: find.byType(Column)).first;
  final n = int.parse(tester.widget<Text>(find.descendant(of: item, matching: find.byType(Text)).last).data!);
  await tester.tap(find.text('Back'));
  await tester.pumpAndSettle();
  return n;
}

Finder _keyed(String part) => find.byWidgetPredicate((w) => w.key.toString().contains(part));
Finder _row(String id) => find.byKey(ValueKey('task_$id'));
Finder _titleField(String id) => find.descendant(of: _row(id), matching: find.byType(TextFormField)).first;
Future<void> _name(WidgetTester tester, String id, String title) async {
  await tester.enterText(_titleField(id), title);
  await tester.pumpAndSettle();
}

Finder _button(String label) => find.ancestor(of: find.text(label), matching: find.bySubtype<FilledButton>()).first;
String _day(DateTime d) => DateFormat('MMM dd, yyyy').format(d);
DateTime _from(int offset) {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day + offset);
}

Future<void> _generate(WidgetTester tester) async {
  await tester.tap(find.text('Generate Gantt Plan'));
  await tester.pumpAndSettle();
}

void main() {
  group('nothing is pre-filled', () {
    testWidgets('a new plan has no phases, no tasks and no templates to pick from', (tester) async {
      await _open(tester);
      for (final gone in ['Quick WBS Template', 'Standard', 'Operations', 'Marketing', 'Blank']) {
        expect(find.text(gone), findsNothing, reason: gone);
      }
      await _continue(tester);
      expect(find.text('No phases yet. Add the first phase of this plan.'), findsOneWidget);
      expect(find.text('Discovery & Planning'), findsNothing);
      await _continue(tester);
      expect(find.text('Add a phase first (step 2), then add its tasks here.'), findsOneWidget);
    });

    testWidgets('a task needs a phase, so Add Task waits until there is one', (tester) async {
      await _open(tester);
      await _continue(tester, 2);
      expect(tester.widget<FilledButton>(_button('Add Task')).onPressed, isNull);
    });

    testWidgets('a project that already has a plan gets none of the wizard\'s own either', (tester) async {
      await _open(tester, existing: [_existing('a', 'Build', order: 1)]);
      await _continue(tester);
      expect(find.text('No phases yet. Add the first phase of this plan.'), findsOneWidget);
    });
  });

  group('phases: add, rename, reorder, delete', () {
    testWidgets('Add Phase gives an empty phase to name — a hint, not a made-up name', (tester) async {
      await _open(tester);
      await _continue(tester);
      await tester.tap(find.text('Add Phase'));
      await tester.pumpAndSettle();
      expect(find.text('Name this phase'), findsOneWidget);
      expect(tester.widget<TextFormField>(find.byType(TextFormField)).controller?.text ?? tester.widget<TextFormField>(find.byType(TextFormField)).initialValue, isEmpty);
      expect(find.text('0 tasks'), findsOneWidget);
    });

    testWidgets('a phase can be named, and is offered by that name when adding a task', (tester) async {
      await _open(tester);
      await _continue(tester);
      await tester.tap(find.text('Add Phase'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'Design');
      await _continue(tester);
      expect(tester.widget<FilledButton>(_button('Add Task')).onPressed, isNotNull);
      await tester.tap(find.text('Add Task'));
      await tester.pumpAndSettle();
      expect(find.text('Design'), findsWidgets); // the phase picker of the new task
    });

    testWidgets('even the last phase can be removed', (tester) async {
      await _open(tester);
      await _continue(tester);
      await tester.tap(find.text('Add Phase'));
      await tester.pumpAndSettle();
      await tester.tap(_keyed('wizard_phase_remove_'));
      await tester.pumpAndSettle();
      expect(find.text('No phases yet. Add the first phase of this plan.'), findsOneWidget);
    });

    testWidgets('phases move up and down, and the ends cannot go further', (tester) async {
      await _open(tester, seed: _four());
      await _continue(tester);
      double y(String t) => tester.getTopLeft(find.text(t)).dy;
      expect(y('Discovery & Planning'), lessThan(y('Implementation & Build')));
      expect(tester.widget<IconButton>(find.byKey(const Key('wizard_phase_up_ph1'))).onPressed, isNull);
      expect(tester.widget<IconButton>(find.byKey(const Key('wizard_phase_down_ph4'))).onPressed, isNull);

      await tester.tap(find.byKey(const Key('wizard_phase_down_ph1')));
      await tester.pumpAndSettle();
      expect(y('Implementation & Build'), lessThan(y('Discovery & Planning')));
      await tester.tap(find.byKey(const Key('wizard_phase_up_ph1')));
      await tester.pumpAndSettle();
      expect(y('Discovery & Planning'), lessThan(y('Implementation & Build')));
    });

    testWidgets('a phase moved up is made first, with its own tasks under it', (tester) async {
      final repo = await _open(tester, seed: _four());
      await _continue(tester);
      await tester.tap(find.byKey(const Key('wizard_phase_up_ph2')));
      await tester.pumpAndSettle();
      await _continue(tester, 2);
      await _generate(tester);
      final phases = repo.created.where((b) => b['parentTaskId'] == null).toList();
      expect([for (final p in phases) p['title']], ['Implementation & Build', 'Discovery & Planning', 'Testing & Review', 'Launch & Handoff']);
      expect([for (final p in phases) p['order'] as int], [for (final p in phases) p['order'] as int]..sort()); // in ascending order of the plan
      // "Execution & Deliverable Build" went with its phase: under the first phase made (c1)
      expect(repo.created.firstWhere((b) => b['title'] == 'Execution & Deliverable Build')['parentTaskId'], 'c1');
      expect(repo.created.firstWhere((b) => b['title'] == 'Requirements & Scope Approval')['parentTaskId'], 'c2');
    });

    testWidgets('removing a phase takes its tasks, and removing the first leaves the others\' names where they were', (tester) async {
      await _open(tester, seed: _four());
      await _continue(tester);
      expect(find.text('Discovery & Planning'), findsOneWidget);
      await tester.tap(find.byTooltip('Remove Phase').first);
      await tester.pumpAndSettle();
      expect(find.text('Discovery & Planning'), findsNothing);
      for (final name in ['Implementation & Build', 'Testing & Review', 'Launch & Handoff']) {
        expect(find.text(name), findsOneWidget, reason: name);
      }
      await _continue(tester);
      expect(find.text('Requirements & Scope Approval'), findsNothing); // its task went with it
    });
  });

  group('tasks: add, rename, reorder, delete', () {
    testWidgets('a task is added to the phase of the last one, nameless until you name it', (tester) async {
      final repo = await _open(tester, seed: _four());
      await _continue(tester, 2);
      await tester.tap(find.text('Add Task'));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView), const Offset(0, -900));
      await tester.pumpAndSettle();
      final field = find.descendant(of: _row('tsk_1'), matching: find.byType(EditableText)).first;
      expect(tester.widget<EditableText>(field).controller.text, isEmpty); // it has no name until you give it one
      await _name(tester, 'tsk_1', 'Handover pack');
      await _continue(tester);
      await _generate(tester);
      final made = repo.created.firstWhere((b) => b['title'] == 'Handover pack');
      expect(made['parentTaskId'], 'c4'); // under "Launch & Handoff", where the last task was
    });

    testWidgets('tasks of a phase move up and down among themselves', (tester) async {
      final repo = await _open(tester, seed: _two());
      await _continue(tester, 2);
      double y(String t) => tester.getTopLeft(find.text(t)).dy;
      expect(y('First'), lessThan(y('Second')));
      // the first cannot go up, the last cannot go down
      await tester.tap(find.byKey(const Key('wizard_task_move_tk1')));
      await tester.pumpAndSettle();
      expect(tester.widget<PopupMenuItem<String>>(find.byKey(const Key('wizard_move_up'))).enabled, isFalse);
      expect(tester.widget<PopupMenuItem<String>>(find.byKey(const Key('wizard_move_down'))).enabled, isTrue);
      await tester.tap(find.text('Move down'));
      await tester.pumpAndSettle();
      expect(y('Second'), lessThan(y('First')));

      await _continue(tester);
      await _generate(tester);
      final tasks = repo.created.where((b) => b['parentTaskId'] != null).toList();
      expect([for (final t in tasks) t['title']], ['Second', 'First']);
      expect(tasks[0]['order'] as int, lessThan(tasks[1]['order'] as int));
    });

    testWidgets('a task can be renamed, and removed', (tester) async {
      final repo = await _open(tester, seed: _two());
      await _continue(tester, 2);
      await _name(tester, 'tk1', 'Wireframes');
      await tester.tap(find.byKey(const Key('wizard_remove_tk2')));
      await tester.pumpAndSettle();
      expect(find.text('Second'), findsNothing);
      await _continue(tester);
      await _generate(tester);
      expect([for (final b in repo.created) b['title']], ['Design', 'Wireframes']);
    });
  });

  group('what stops the plan being made', () {
    testWidgets('no tasks: says so, and takes you to the tasks', (tester) async {
      final repo = await _open(tester, seed: (phases: [PlanPhaseDraft(id: 'ph1', name: 'Design')], tasks: <PlanTaskDraft>[]));
      await _continue(tester, 3);
      await _generate(tester);
      expect(find.text('Please add at least one task before generating the Gantt plan.'), findsOneWidget);
      expect(find.text('Tasks & Ownership'), findsOneWidget);
      expect(repo.created, isEmpty);
    });

    testWidgets('a phase with tasks but no name: says so, and takes you to the phases', (tester) async {
      final repo = await _open(tester, seed: (phases: [PlanPhaseDraft(id: 'ph1', name: '')], tasks: [PlanTaskDraft(id: 'tk1', phaseId: 'ph1', title: 'Wireframes')]));
      await _continue(tester, 3);
      expect(find.text('Untitled phase'), findsWidgets); // shown as such on the last step, not as a blank
      await _generate(tester);
      expect(find.text('Give every phase a name.'), findsOneWidget);
      expect(find.text('Milestones & Phases (WBS)'), findsOneWidget);
      expect(repo.created, isEmpty);
    });

    testWidgets('a task with no title: says so, and takes you to the tasks', (tester) async {
      final repo = await _open(tester, seed: (phases: [PlanPhaseDraft(id: 'ph1', name: 'Design')], tasks: [PlanTaskDraft(id: 'tk1', phaseId: 'ph1', title: '  ')]));
      await _continue(tester, 3);
      expect(find.text('Untitled task'), findsWidgets);
      await _generate(tester);
      expect(find.text('Give every task and sub-task a title.'), findsOneWidget);
      expect(find.text('Tasks & Ownership'), findsOneWidget);
      expect(repo.created, isEmpty);
    });

    testWidgets('a nameless phase with nothing in it is no problem — it is simply not made', (tester) async {
      final repo = await _open(tester, seed: (
        phases: [PlanPhaseDraft(id: 'ph1', name: 'Design'), PlanPhaseDraft(id: 'ph2', name: '')],
        tasks: [PlanTaskDraft(id: 'tk1', phaseId: 'ph1', title: 'Wireframes')],
      ));
      await _continue(tester, 3);
      await _generate(tester);
      expect([for (final b in repo.created) b['title']], ['Design', 'Wireframes']);
    });

    testWidgets('pressing Generate twice in a row makes the plan once, not twice', (tester) async {
      final repo = await _open(tester, seed: _four());
      await _continue(tester, 3);
      final generate = find.text('Generate Gantt Plan');
      await tester.tap(generate);
      await tester.tap(generate); // before the screen has had a frame to grey the button out
      await tester.pumpAndSettle();
      expect(repo.created, hasLength(8)); // 4 phases + 4 tasks, once
    });
  });

  group('a whole plan, built from nothing', () {
    testWidgets('add phases, add tasks to them, name it all — and that is what is made, under the right phase', (tester) async {
      final repo = await _open(tester);
      await _continue(tester);
      await tester.tap(find.text('Add Phase'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add Phase'));
      await tester.pumpAndSettle();
      final names = find.byType(TextFormField);
      await tester.enterText(names.at(0), 'Design');
      await tester.enterText(names.at(1), 'Build');
      await _continue(tester);

      await tester.tap(find.text('Add Task'));
      await tester.pumpAndSettle();
      await _name(tester, 'tsk_3', 'Wireframes');
      await tester.tap(find.text('Add Task'));
      await tester.pumpAndSettle();
      await _name(tester, 'tsk_4', 'Prototype');
      // the second task goes in the second phase
      await tester.tap(find.descendant(of: _row('tsk_4'), matching: find.byType(DropdownButtonFormField<String>)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Build').last);
      await tester.pumpAndSettle();

      await _continue(tester);
      await _generate(tester);

      expect([for (final b in repo.created) b['title']], ['Design', 'Build', 'Wireframes', 'Prototype']);
      expect(repo.created[2]['parentTaskId'], 'c1');
      expect(repo.created[3]['parentTaskId'], 'c2');
      expect(repo.created[2]['startDate'], isNotNull);
      expect(find.text('Functional Plan & Gantt Auto-Scheduler'), findsNothing);
    });
  });

  group('sub-tasks', () {
    testWidgets('a task gets sub-tasks of its own, under it; its own length gives way to theirs', (tester) async {
      await _open(tester, seed: _four());
      await _continue(tester, 2);
      expect(await _total(tester), 4);
      expect(find.text('from sub-tasks'), findsNothing);

      await tester.tap(_keyed('wizard_add_sub_').first);
      await tester.pumpAndSettle();

      expect(await _total(tester), 5);
      expect(find.text('from sub-tasks'), findsOneWidget);
      expect(find.byTooltip('Remove sub-task'), findsOneWidget);
      expect(find.text('Sub-task title'), findsOneWidget); // nameless until you name it
    });

    testWidgets('a sub-task cannot be given sub-tasks here, and a milestone cannot have them at all', (tester) async {
      await _open(tester, seed: _four());
      await _continue(tester, 2);
      await tester.tap(_keyed('wizard_add_sub_').first);
      await tester.pumpAndSettle();
      // the last task is a milestone: scroll down to it
      await tester.drag(find.byType(ListView), const Offset(0, -600));
      await tester.pumpAndSettle();
      final milestone = tester.widgetList<IconButton>(find.byType(IconButton)).where((b) => b.tooltip == 'A milestone cannot have sub-tasks');
      expect(milestone, hasLength(1));
      expect(milestone.single.onPressed, isNull);
      await tester.drag(find.byType(ListView), const Offset(0, 600));
      await tester.pumpAndSettle();
      expect(find.descendant(of: _row('tsk_1'), matching: _keyed('wizard_add_sub_')), findsNothing);
    });

    testWidgets('the first sub-task keeps the task\'s length, the next follows it — and the plan adds up', (tester) async {
      await _open(tester, seed: _four());
      await _continue(tester, 2);
      final firstTask = _keyed('wizard_add_sub_').first; // "Requirements & Scope Approval", 3 days
      await tester.tap(firstTask);
      await tester.pumpAndSettle();
      await tester.tap(firstTask);
      await tester.pumpAndSettle();
      await _continue(tester);

      // 3 + 7 + 3 days, then a milestone that takes none = 13; the first task now runs 3 (first sub-task) + 2 (second) = 5, so 15
      expect(find.text('15 Days'), findsOneWidget);
      expect(find.text('Summary'), findsOneWidget);
      expect(find.text('6'), findsOneWidget); // 4 tasks + 2 sub-tasks
      expect(find.text('${_day(_from(0))} → ${_day(_from(3))} (3d)'), findsOneWidget); // the first sub-task
      expect(find.text('${_day(_from(3))} → ${_day(_from(5))} (2d)'), findsOneWidget);
      expect(find.text('${_day(_from(0))} → ${_day(_from(5))} (5d)'), findsOneWidget);
    });

    testWidgets('removing a task removes its sub-tasks, and removing the last sub-task gives it back its own length', (tester) async {
      await _open(tester, seed: _four());
      await _continue(tester, 2);
      await tester.tap(_keyed('wizard_add_sub_').first);
      await tester.pumpAndSettle();
      expect(await _total(tester), 5);

      await tester.tap(find.byTooltip('Remove sub-task'));
      await tester.pumpAndSettle();
      expect(await _total(tester), 4);
      expect(find.text('from sub-tasks'), findsNothing);

      await tester.tap(_keyed('wizard_add_sub_').first);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Remove task and its sub-tasks'));
      await tester.pumpAndSettle();
      expect(await _total(tester), 3); // the task and its sub-task are both gone
    });

    testWidgets('a task\'s dependencies are cleaned up when what it waited for is removed', (tester) async {
      await _open(tester, seed: _four());
      await _continue(tester, 2);
      await tester.tap(find.byKey(const Key('wizard_remove_tk1'))); // the second waited for it
      await tester.pumpAndSettle();
      await _continue(tester);
      expect(find.text('Requirements & Scope Approval'), findsNothing);
      expect(find.textContaining('Task tk1'), findsNothing); // no chip left pointing at a task that is gone
      expect(find.byType(Chip), findsNWidgets(2)); // the third still waits for the second, the fourth for the third
      expect(tester.takeException(), isNull);
    });
  });

  group('what is sent to the server', () {
    testWidgets('every parent is made before what hangs under it, and each child points at its own parent', (tester) async {
      final repo = await _open(tester, seed: _four());
      await _continue(tester, 2);
      await tester.tap(_keyed('wizard_add_sub_').first); // a sub-task under "Requirements & Scope Approval"
      await tester.pumpAndSettle();
      await _name(tester, 'tsk_1', 'Interviews');
      await _continue(tester);
      await _generate(tester);

      expect([for (final b in repo.created) b['title']], [
        'Discovery & Planning', 'Implementation & Build', 'Testing & Review', 'Launch & Handoff', // phases c1..c4
        'Requirements & Scope Approval', 'Interviews', // c5, c6
        'Execution & Deliverable Build', 'Quality Assurance & Stakeholder Review', 'Go-Live Release & Milestone Sign-off',
      ]);
      expect(repo.created.take(4).map((b) => b['parentTaskId']), everyElement(isNull));
      expect(repo.created[4]['parentTaskId'], 'c1'); // the task, under its phase
      expect(repo.created[5]['parentTaskId'], 'c5'); // the sub-task, under the TASK — not under the phase
      expect(repo.created[6]['parentTaskId'], 'c2');
      expect(repo.created[7]['parentTaskId'], 'c3');
      expect(repo.created[8]['parentTaskId'], 'c4');
      expect(find.text('Functional Plan & Gantt Auto-Scheduler'), findsNothing); // the dialog closes once it is done
    });

    testWidgets('a task that waited for a task with sub-tasks still waits for it, by its new id', (tester) async {
      final repo = await _open(tester, seed: _four());
      await _continue(tester, 2);
      await tester.tap(_keyed('wizard_add_sub_').first);
      await tester.pumpAndSettle();
      await _name(tester, 'tsk_1', 'Interviews');
      await _continue(tester);
      await _generate(tester);
      // "Execution & Deliverable Build" (c7) waited for "Requirements & Scope Approval" (c5)
      expect(repo.updated['c7']!['predecessorIds'], ['c5']);
    });

    testWidgets('a task with sub-tasks is dated across them, and carries their span', (tester) async {
      final repo = await _open(tester, seed: _four());
      await _continue(tester, 2);
      await tester.tap(_keyed('wizard_add_sub_').first);
      await tester.pumpAndSettle();
      await tester.tap(_keyed('wizard_add_sub_').first);
      await tester.pumpAndSettle();
      await _name(tester, 'tsk_1', 'Interviews');
      await _name(tester, 'tsk_2', 'Summary of findings');
      await _continue(tester);
      await _generate(tester);

      DateTime at(Map<String, dynamic> b, String k) => DateTime.parse(b[k] as String);
      final task = repo.created[4];
      final sub1 = repo.created[5];
      final sub2 = repo.created[6];
      expect(at(task, 'startDate'), at(sub1, 'startDate'));
      expect(at(task, 'dueDate'), at(sub2, 'dueDate'));
      expect(at(sub2, 'startDate'), at(sub1, 'dueDate')); // back to back
      expect(at(repo.created[0], 'dueDate'), at(sub2, 'dueDate')); // and the phase spans its task
    });

    testWidgets('a phase with no tasks is not made, and is not counted', (tester) async {
      final repo = await _open(tester, seed: _four());
      await _continue(tester);
      await tester.tap(find.text('Add Phase')); // a fifth phase, left empty
      await tester.pumpAndSettle();
      await _continue(tester, 2);
      await _generate(tester);
      expect(repo.created.where((b) => b['parentTaskId'] == null), hasLength(4));
      expect(find.textContaining('Added 4 phases and 4 tasks'), findsOneWidget);
    });
  });

  group('adding to a plan that is already there', () {
    final existing = [
      _existing('a', 'Discovery & Planning', order: 3),
      _existing('b', 'Build', order: 25),
      _existing('c', 'Requirements', parent: 'a', order: 1),
    ];

    testWidgets('says what is already there and that nothing in it changes', (tester) async {
      await _open(tester, existing: existing);
      expect(find.byKey(const Key('wizard_existing_note')), findsOneWidget);
      expect(find.textContaining('already has 2 phases and 1 task'), findsOneWidget);
      expect(find.textContaining('nothing that is there changes'), findsOneWidget);
    });

    testWidgets('a project with nothing yet gets no such note', (tester) async {
      await _open(tester);
      expect(find.byKey(const Key('wizard_existing_note')), findsNothing);
    });

    testWidgets('a phase that is in the project already is flagged — once, on the one that repeats it', (tester) async {
      await _open(tester, existing: existing, seed: _four());
      await _continue(tester);
      expect(find.text('Already in the project'), findsOneWidget); // "Discovery & Planning"; the others are new
      expect(find.byTooltip('The project already has a phase with this name'), findsOneWidget);
    });

    testWidgets('what is made goes after what exists in the order of the plan', (tester) async {
      final repo = await _open(tester, existing: existing, seed: _four());
      await _continue(tester, 3);
      await _generate(tester);
      final orders = [for (final b in repo.created) b['order'] as int];
      expect(orders.every((o) => o > 25), isTrue, reason: 'the existing plan goes up to 25: $orders');
      expect(orders.toSet(), hasLength(orders.length)); // and none repeats
    });
  });

  group('the form keeps what you typed in the right row', () {
    testWidgets('removing the first task leaves the others\' titles where they were', (tester) async {
      await _open(tester, seed: _four());
      await _continue(tester, 2);
      await tester.tap(find.byKey(const Key('wizard_remove_tk1')));
      await tester.pumpAndSettle();
      expect(find.text('Requirements & Scope Approval'), findsNothing);
      expect(find.text('Execution & Deliverable Build'), findsOneWidget);
      expect(find.text('Quality Assurance & Stakeholder Review'), findsOneWidget);
    });
  });

  group('planning for a department', () {
    final cross = _project(departments: ['Marketing', 'IT'], owner: 'Marketing');

    String? chosen(WidgetTester tester) => tester.widget<DropdownButtonFormField<String>>(find.byType(DropdownButtonFormField<String>).first).initialValue;

    testWidgets('opened from a department\'s lane, it plans for that department', (tester) async {
      await _open(tester, project: cross, department: 'IT');
      expect(chosen(tester), 'IT');
    });

    testWidgets('however the name is spelled, and one the project does not have is ignored', (tester) async {
      await _open(tester, project: cross, department: 'it');
      expect(chosen(tester), 'IT');
      await _open(tester, project: cross, department: 'Finance');
      expect(chosen(tester), 'Marketing'); // the owning department
    });

    testWidgets('what it makes belongs to that department', (tester) async {
      final repo = await _open(tester, project: cross, department: 'IT', seed: _four());
      await _continue(tester, 3);
      await _generate(tester);
      expect(repo.created.map((b) => b['departmentName']), everyElement('IT'));
    });
  });
}
