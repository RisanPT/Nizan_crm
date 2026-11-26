import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:nizan_crm/core/models/employee.dart';
import 'package:nizan_crm/core/theme/app_theme.dart';
import 'package:nizan_crm/features/it/data/it_task.dart';
import 'package:nizan_crm/features/it/data/project.dart';
import 'package:nizan_crm/features/it/domain/repositories/it_task_repository.dart';
import 'package:nizan_crm/features/it/presentation/controllers/it_tasks_notifier.dart';
import 'package:nizan_crm/features/it/presentation/screens/widgets/functional_plan_wizard_dialog.dart';
import 'package:nizan_crm/features/it/presentation/screens/widgets/plan_wizard_table_widgets.dart';
import 'package:nizan_crm/features/it/services/it_service.dart';

// Step 3 of the plan wizard as ONE TABLE: a row for each task (a folder for a task that has sub-tasks, a document for one that has
// not), the columns Phase / Duration / Assignee / Start / End (/ Cost) and a ⋯ menu; rows can be ticked and moved, assigned or deleted
// together; tasks come in one at a time, or as a pasted list.

// ── fakes ───────────────────────────────────────────────────────────────────
class _Repo implements IITTaskRepository {
  final created = <Map<String, dynamic>>[];
  var _n = 0;

  @override
  Future<ITTask> createTask(Map<String, dynamic> data) async {
    created.add(data);
    return ITTask(
      id: 'c${++_n}',
      projectId: 'p1',
      title: (data['title'] ?? '').toString(),
    );
  }

  @override
  Future<ITTask> updateTask(String id, Map<String, dynamic> data) async =>
      ITTask(id: id, projectId: 'p1', title: '');

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

Project _project({bool canEditCost = false}) => Project.fromJson({
  '_id': 'p1',
  'name': 'Lifestyle brand at 2030',
  'targetDepartment': 'IT',
  'managerId': {'_id': 'm1', 'name': 'Amna'},
  'editMode': 'managed',
  'costStatus': canEditCost ? 'approved' : 'none',
  'departments': [
    {'name': 'IT', 'role': 'owner', 'status': 'accepted'},
  ],
  if (canEditCost)
    'cost': {
      'budget': 100000,
      'approvedBudget': 100000,
      'taskPlan': {
        'planned': 0,
        'ceiling': 100000,
        'level': 'ok',
        'over': 0,
        'leaves': 0,
        'priced': 0,
        'unpriced': 0,
        'byDepartment': <Map<String, dynamic>>[],
        'awaiting': false,
      },
    },
  'access': {
    'role': 'manager',
    'canManage': true,
    'editMode': 'managed',
    'canCreateTasks': true,
    'canEditAllTasks': true,
    'leadDepartments': <String>[],
    'pendingInvitations': <String>[],
    'canDecide': false,
    'canSeeCost': canEditCost,
    'canEditCost': canEditCost,
  },
});

typedef _Seed = ({List<PlanPhaseDraft> phases, List<PlanTaskDraft> tasks});

/// Two phases; the first has two plain tasks, the second a task with two sub-tasks.
_Seed _plan() => (
  phases: [
    PlanPhaseDraft(id: 'ph1', name: 'Design'),
    PlanPhaseDraft(id: 'ph2', name: 'Build', color: const Color(0xFF0EA5E9)),
  ],
  tasks: [
    PlanTaskDraft(
      id: 'tk1',
      phaseId: 'ph1',
      title: 'Wireframes',
      durationDays: 2,
    ),
    PlanTaskDraft(id: 'tk2', phaseId: 'ph1', title: 'Mockups', durationDays: 3),
    PlanTaskDraft(
      id: 'tk3',
      phaseId: 'ph2',
      title: 'Frontend',
      durationDays: 5,
    ),
    PlanTaskDraft(
      id: 'sb1',
      phaseId: 'ph2',
      parentId: 'tk3',
      title: 'Login screen',
      durationDays: 2,
    ),
    PlanTaskDraft(
      id: 'sb2',
      phaseId: 'ph2',
      parentId: 'tk3',
      title: 'Dashboard',
      durationDays: 3,
      predecessorIds: ['sb1'],
    ),
  ],
);

Employee _employee(String id, String name) => Employee.fromJson({
  '_id': id,
  'name': name,
  'artistRole': 'artist',
  'status': 'active',
});

late _Repo _repo;

/// Opens the wizard on its Tasks step.
Future<void> _open(
  WidgetTester t, {
  _Seed? seed,
  Project? project,
  Size size = const Size(1500, 1100),
  List<Employee>? employees,
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  _repo = _Repo();
  final people =
      employees ??
      [_employee('e1', 'Asha Nair'), _employee('e2', 'Meera Kurup')];
  await t.pumpWidget(const SizedBox.shrink());
  await t.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: <Override>[
        projectEmployeesProvider('p1').overrideWith((ref) => people),
        itTaskRepositoryProvider.overrideWithValue(_repo),
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
                  existingTasks: const [],
                  project: project ?? _project(),
                  seed: seed ?? _plan(),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await t.tap(find.text('open'));
  await t.pumpAndSettle();
  await t.tap(find.byKey(const Key('wizard_next')));
  await t.pumpAndSettle();
  await t.tap(find.byKey(const Key('wizard_next')));
  await t.pumpAndSettle();
}

Finder _k(String key) => find.byKey(Key(key));
Finder _row(String id) => find.byKey(ValueKey('task_$id'));

/// Brings [f] into view — scrolling the table down first when its row has not been built yet (the list builds only what is near) — and taps it.
Future<void> _tap(WidgetTester t, Finder f) async {
  if (f.evaluate().isEmpty) {
    await t.dragUntilVisible(f, find.byType(ListView).first, const Offset(0, -120));
  }
  await t.ensureVisible(f);
  await t.pumpAndSettle();
  await t.tap(f);
  await t.pumpAndSettle();
}

/// Opens a task's ⋯ menu and picks the item with [itemKey].
Future<void> _menu(WidgetTester t, String id, String itemKey) async {
  await _tap(t, _k('wizard_menu_$id'));
  await _tap(t, _k(itemKey));
}

String _text(WidgetTester t, String key) => t.widget<Text>(_k(key)).data ?? '';

String? _phaseOf(WidgetTester t, String id, String phaseId) => t
    .widget<DropdownButtonFormField<String>>(_k('wizard_phase_${id}_$phaseId'))
    .initialValue;

void main() {
  group('the table', () {
    testWidgets('has the columns, the two header buttons and the dashed row', (
      t,
    ) async {
      await _open(t);
      for (final h in [
        'Task / Deliverable',
        'Phase',
        'Duration',
        'Assignee',
        'Start Date',
        'End Date',
        'Actions',
      ]) {
        expect(find.text(h), findsOneWidget, reason: h);
      }
      expect(
        find.text('Cost'),
        findsNothing,
        reason: 'no costs for this person',
      );
      expect(_k('wizard_import_open'), findsOneWidget);
      expect(find.text('Import Tasks'), findsOneWidget);
      expect(find.text('Add Task'), findsOneWidget);
      expect(_k('wizard_add_row'), findsOneWidget);
      expect(find.text('Add a task'), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('someone who sets costs also gets the Cost column', (t) async {
      await _open(t, project: _project(canEditCost: true));
      expect(find.text('Cost'), findsOneWidget);
      expect(_k('wizard_cost_tk1'), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets(
      'a task with sub-tasks is a folder with a count and the span of what is under it',
      (t) async {
        await _open(t);
        expect(_text(t, 'wizard_group_count_tk3'), '2 tasks');
        expect(
          find.descendant(
            of: _k('wizard_span_tk3'),
            matching: find.text('5 days'),
          ),
          findsOneWidget,
        );
        expect(find.text('from sub-tasks'), findsOneWidget);
        expect(
          find.descendant(
            of: _row('tk3'),
            matching: find.byIcon(Icons.folder_outlined),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: _row('tk1'),
            matching: find.byIcon(Icons.description_outlined),
          ),
          findsOneWidget,
        );
        // no folder toggle on a task with nothing under it
        expect(_k('wizard_toggle_tk1'), findsNothing);
        expect(_k('wizard_group_count_tk1'), findsNothing);
      },
    );

    testWidgets('a folder folds its sub-tasks away and opens them again', (
      t,
    ) async {
      await _open(t);
      expect(_row('sb1'), findsOneWidget);
      await _tap(t, _k('wizard_toggle_tk3'));
      expect(_row('sb1'), findsNothing);
      expect(_row('sb2'), findsNothing);
      expect(_row('tk3'), findsOneWidget);
      expect(
        _text(t, 'wizard_group_count_tk3'),
        '2 tasks',
      ); // still counts them
      await _tap(t, _k('wizard_toggle_tk3'));
      expect(_row('sb1'), findsOneWidget);
      expect(_row('sb2'), findsOneWidget);
    });

    testWidgets('a sub-task added under a folded task opens it', (t) async {
      await _open(t);
      await _tap(t, _k('wizard_toggle_tk3'));
      await _menu(t, 'tk3', 'wizard_add_sub_tk3');
      expect(_row('tsk_1'), findsOneWidget);
      expect(_text(t, 'wizard_group_count_tk3'), '3 tasks');
    });

    testWidgets('a sub-task shows its task\'s phase and cannot change it', (
      t,
    ) async {
      await _open(t);
      expect(
        find.descendant(of: _row('sb1'), matching: find.text('Build')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: _row('sb1'),
          matching: find.byType(DropdownButtonFormField<String>),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: _row('tk1'),
          matching: find.byType(DropdownButtonFormField<String>),
        ),
        findsOneWidget,
      );
    });

    testWidgets(
      'a phase is changed from its pill, and the sub-tasks go with it',
      (t) async {
        await _open(t);
        expect(_phaseOf(t, 'tk3', 'ph2'), 'ph2');
        await _tap(
          t,
          find.descendant(
            of: _row('tk3'),
            matching: find.byType(DropdownButtonFormField<String>),
          ),
        );
        await _tap(t, find.text('Design').last);
        expect(_phaseOf(t, 'tk3', 'ph1'), 'ph1');
        expect(
          find.descendant(of: _row('sb1'), matching: find.text('Design')),
          findsOneWidget,
          reason: 'the sub-task follows its task',
        );
      },
    );

    testWidgets('the priority is kept, and goes to the server', (t) async {
      await _open(t);
      expect(
        find.descendant(of: _row('tk1'), matching: find.text('P2')),
        findsOneWidget,
      );
      await _tap(t, _k('wizard_priority_tk1'));
      await _tap(t, find.text('P1 - High'));
      expect(
        find.descendant(of: _row('tk1'), matching: find.text('P1')),
        findsOneWidget,
      );
      await t.tap(find.byKey(const Key('wizard_next')));
      await t.pumpAndSettle();
      await t.tap(find.text('Generate Gratt Plan'));
      await t.pumpAndSettle();
      final made = _repo.created.firstWhere((b) => b['title'] == 'Wireframes');
      expect(made['severity'], 'p1');
      final other = _repo.created.firstWhere((b) => b['title'] == 'Mockups');
      expect(other['severity'], 'p2');
    });
  });

  group('selecting rows', () {
    testWidgets('ticking a row turns the column names into the bulk bar', (
      t,
    ) async {
      await _open(t);
      expect(_k('wizard_bulk_bar'), findsNothing);
      await _tap(t, _k('wizard_select_tk1'));
      expect(_k('wizard_bulk_bar'), findsOneWidget);
      expect(_text(t, 'wizard_bulk_count'), '1 selected');
      expect(find.text('Task / Deliverable'), findsNothing);
      await _tap(t, _k('wizard_select_tk2'));
      expect(_text(t, 'wizard_bulk_count'), '2 selected');
      await _tap(t, _k('wizard_select_tk1'));
      await _tap(t, _k('wizard_select_tk2'));
      expect(
        _k('wizard_bulk_bar'),
        findsNothing,
      ); // nothing ticked: the names are back
      expect(find.text('Task / Deliverable'), findsOneWidget);
    });

    testWidgets(
      'the box at the top ticks every row on show, and unticks them',
      (t) async {
        await _open(t);
        await _tap(t, _k('wizard_select_all'));
        expect(_text(t, 'wizard_bulk_count'), '5 selected');
        await _tap(t, _k('wizard_select_all'));
        expect(_k('wizard_bulk_bar'), findsNothing);
        // a folded task's sub-tasks are not on show, so they are not ticked
        await _tap(t, _k('wizard_toggle_tk3'));
        await _tap(t, _k('wizard_select_all'));
        expect(_text(t, 'wizard_bulk_count'), '3 selected');
      },
    );

    testWidgets('"Clear selection" lets go of them all', (t) async {
      await _open(t);
      await _tap(t, _k('wizard_select_all'));
      await _tap(t, _k('wizard_bulk_clear'));
      expect(_k('wizard_bulk_bar'), findsNothing);
      expect(t.widget<Checkbox>(_k('wizard_select_tk1')).value, isFalse);
    });

    testWidgets('removing a ticked row takes it out of the selection', (
      t,
    ) async {
      await _open(t);
      await _tap(t, _k('wizard_select_tk1'));
      await _menu(t, 'tk1', 'wizard_remove_tk1');
      expect(_row('tk1'), findsNothing);
      expect(_k('wizard_bulk_bar'), findsNothing);
    });

    testWidgets(
      'move to phase: the ticked tasks go, a sub-task goes with its task',
      (t) async {
        await _open(t);
        await _tap(t, _k('wizard_select_tk1'));
        await _tap(t, _k('wizard_select_tk2'));
        await _tap(t, _k('wizard_bulk_move'));
        await _tap(t, _k('wizard_bulk_move_ph2'));
        expect(_phaseOf(t, 'tk1', 'ph2'), 'ph2');
        expect(_phaseOf(t, 'tk2', 'ph2'), 'ph2');
        expect(_k('wizard_phase_tk1_ph1'), findsNothing);

        // a folder moves with what is under it
        await _tap(t, _k('wizard_select_tk1'));
        await _tap(t, _k('wizard_select_tk2'));
        await _tap(t, _k('wizard_select_tk3'));
        await _tap(t, _k('wizard_bulk_move'));
        await _tap(t, _k('wizard_bulk_move_ph1'));
        expect(_phaseOf(t, 'tk3', 'ph1'), 'ph1');
        expect(
          find.descendant(of: _row('sb2'), matching: find.text('Design')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'a sub-task ticked on its own does not move away from its task',
      (t) async {
        await _open(t);
        await _tap(t, _k('wizard_select_sb1'));
        await _tap(t, _k('wizard_bulk_move'));
        await _tap(t, _k('wizard_bulk_move_ph1'));
        expect(
          find.descendant(of: _row('sb1'), matching: find.text('Build')),
          findsOneWidget,
        );
      },
    );

    testWidgets('assign to: one person for every ticked task', (t) async {
      await _open(t);
      await _tap(t, _k('wizard_select_tk1'));
      await _tap(t, _k('wizard_select_tk2'));
      await _tap(t, _k('wizard_bulk_assign'));
      await _tap(t, find.text('Asha Nair'));
      for (final id in ['tk1', 'tk2']) {
        expect(
          find.descendant(
            of: _k('wizard_assignee_$id'),
            matching: find.text('AN'),
          ),
          findsOneWidget,
          reason: id,
        );
      }
      expect(
        find.descendant(
          of: _k('wizard_assignee_tk3'),
          matching: find.text('AN'),
        ),
        findsNothing,
      );
    });

    testWidgets('delete asks first, and takes the sub-tasks with a task', (
      t,
    ) async {
      await _open(t);
      await _tap(t, _k('wizard_select_tk1'));
      await _tap(t, _k('wizard_select_tk3'));
      await _tap(t, _k('wizard_bulk_delete'));
      expect(
        find.text('Delete 4 tasks?'),
        findsOneWidget,
      ); // tk1, tk3 and tk3's two sub-tasks
      await _tap(t, find.text('Keep'));
      expect(_row('tk1'), findsOneWidget);
      expect(_row('tk3'), findsOneWidget);

      await _tap(t, _k('wizard_bulk_delete'));
      await _tap(t, _k('wizard_bulk_delete_ok'));
      expect(_row('tk1'), findsNothing);
      expect(_row('tk3'), findsNothing);
      expect(_row('sb1'), findsNothing);
      expect(_row('tk2'), findsOneWidget);
      expect(_k('wizard_bulk_bar'), findsNothing);
    });
  });

  group('the assignee', () {
    testWidgets(
      'is picked from the cell, shown as initials, and removed from the menu',
      (t) async {
        await _open(t);
        expect(
          find.descendant(
            of: _k('wizard_assignee_tk1'),
            matching: find.text('Assign'),
          ),
          findsOneWidget,
        );
        await _tap(t, _k('wizard_assignee_tk1'));
        await _tap(t, find.text('Meera Kurup'));
        expect(
          find.descendant(
            of: _k('wizard_assignee_tk1'),
            matching: find.text('MK'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: _k('wizard_assignee_tk1'),
            matching: find.text('Meera Kurup'),
          ),
          findsOneWidget,
        );

        await _menu(t, 'tk1', 'wizard_unassign_tk1');
        expect(
          find.descendant(
            of: _k('wizard_assignee_tk1'),
            matching: find.text('Assign'),
          ),
          findsOneWidget,
        );
        // a task with nobody has nothing to remove
        await _tap(t, _k('wizard_menu_tk1'));
        expect(_k('wizard_unassign_tk1'), findsNothing);
      },
    );

    testWidgets('a task with sub-tasks shows the people on them', (t) async {
      await _open(t);
      await _tap(t, _k('wizard_assignee_sb1'));
      await _tap(t, find.text('Asha Nair'));
      await _tap(t, _k('wizard_assignee_sb2'));
      await _tap(t, find.text('Meera Kurup'));
      final cell = _k('wizard_assignee_tk3');
      expect(
        find.descendant(of: cell, matching: find.text('AN')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: cell, matching: find.text('MK')),
        findsOneWidget,
      );
      // its own person, once given, is what it shows
      await _tap(t, cell);
      await _tap(
        t,
        find.descendant(
          of: find.byType(Dialog).last,
          matching: find.text('Asha Nair'),
        ),
      ); // (the name is also on the sub-task's row behind the picker)
      expect(
        find.descendant(of: cell, matching: find.text('MK')),
        findsNothing,
      );
    });

    testWidgets('goes to the server with the task', (t) async {
      await _open(t);
      await _tap(t, _k('wizard_assignee_tk1'));
      await _tap(t, find.text('Asha Nair'));
      await t.tap(find.byKey(const Key('wizard_next')));
      await t.pumpAndSettle();
      await t.tap(find.text('Generate Gratt Plan'));
      await t.pumpAndSettle();
      final made = _repo.created.firstWhere((b) => b['title'] == 'Wireframes');
      expect(made['assignedTo'], 'e1');
    });
  });

  group('adding tasks', () {
    testWidgets(
      'the button and the dashed row each add one, under the last phase used',
      (t) async {
        await _open(t);
        await _tap(t, find.text('Add Task'));
        expect(_row('tsk_1'), findsOneWidget);
        expect(_phaseOf(t, 'tsk_1', 'ph2'), 'ph2'); // where the last task was
        await _tap(t, _k('wizard_add_row'));
        expect(_row('tsk_2'), findsOneWidget);
        // nameless until named
        for (final id in ['tsk_1', 'tsk_2']) {
          final title = find
              .descendant(of: _row(id), matching: find.byType(TextFormField))
              .first;
          expect(t.widget<TextFormField>(title).initialValue, '', reason: id);
        }
      },
    );

    testWidgets('with no phase there is nothing to add to, and it says so', (
      t,
    ) async {
      await _open(
        t,
        seed: (phases: <PlanPhaseDraft>[], tasks: <PlanTaskDraft>[]),
      );
      expect(
        find.text('Add a phase first (step 2), then add its tasks here.'),
        findsOneWidget,
      );
      expect(t.widget<DashedAddRow>(_k('wizard_add_row')).onTap, isNull);
      expect(
        t
            .widget<FilledButton>(
              find.ancestor(
                of: find.text('Add Task'),
                matching: find.bySubtype<FilledButton>(),
              ),
            )
            .onPressed,
        isNull,
      );
      expect(
        t
            .widget<OutlinedButton>(
              find.ancestor(
                of: find.text('Import Tasks'),
                matching: find.bySubtype<OutlinedButton>(),
              ),
            )
            .onPressed,
        isNull,
      );
    });

    testWidgets('with a phase and no tasks the table says to add one', (
      t,
    ) async {
      await _open(
        t,
        seed: (
          phases: [PlanPhaseDraft(id: 'ph1', name: 'Design')],
          tasks: <PlanTaskDraft>[],
        ),
      );
      expect(find.text('No tasks yet. Add one under a phase.'), findsOneWidget);
      await _tap(t, _k('wizard_add_row'));
      expect(_row('tsk_1'), findsOneWidget);
      expect(find.text('No tasks yet. Add one under a phase.'), findsNothing);
    });
  });

  group('import', () {
    Future<void> openImport(WidgetTester t) async {
      await _tap(t, _k('wizard_import_open'));
      expect(_k('wizard_import_dialog'), findsOneWidget);
    }

    testWidgets('a pasted list becomes tasks under the chosen phase', (
      t,
    ) async {
      await _open(t);
      await openImport(t);
      expect(t.widget<FilledButton>(_k('wizard_import_ok')).onPressed, isNull);
      expect(_text(t, 'wizard_import_count'), 'Nothing to add yet.');

      await t.enterText(
        _k('wizard_import_text'),
        'Brand audit, 4\n- Moodboard 2d\n\n3. Final review',
      );
      await t.pump();
      expect(_text(t, 'wizard_import_count'), '3 tasks will be added.');

      // the phase they go under: the last used (Build), changed to Design
      await _tap(t, _k('wizard_import_phase'));
      await _tap(t, find.text('Design').last);
      await _tap(t, _k('wizard_import_ok'));

      expect(_k('wizard_import_dialog'), findsNothing);
      expect(find.text('3 tasks added.'), findsOneWidget);
      expect(find.text('Brand audit'), findsOneWidget);
      expect(find.text('Moodboard'), findsOneWidget);
      expect(find.text('Final review'), findsOneWidget);
      expect(
        t.widget<TextFormField>(_k('wizard_dur_tsk_1_0')).initialValue,
        '4',
      );
      expect(
        t.widget<TextFormField>(_k('wizard_dur_tsk_2_0')).initialValue,
        '2',
      );
      expect(
        t.widget<TextFormField>(_k('wizard_dur_tsk_3_0')).initialValue,
        '3',
      );
      for (final id in ['tsk_1', 'tsk_2', 'tsk_3']) {
        expect(_phaseOf(t, id, 'ph1'), 'ph1', reason: id);
      }
    });

    testWidgets('cancelling adds nothing, and a single line says "1 task"', (
      t,
    ) async {
      await _open(t);
      await openImport(t);
      await t.enterText(_k('wizard_import_text'), 'One only');
      await t.pump();
      expect(_text(t, 'wizard_import_count'), '1 task will be added.');
      await _tap(t, _k('wizard_import_cancel'));
      expect(_k('wizard_import_dialog'), findsNothing);
      expect(_row('tsk_1'), findsNothing);
    });

    testWidgets('lines with no title are not tasks', (t) async {
      await _open(t);
      await openImport(t);
      await t.enterText(_k('wizard_import_text'), '3\n, 4\n5 days\n   \n');
      await t.pump();
      expect(_text(t, 'wizard_import_count'), 'Nothing to add yet.');
      expect(t.widget<FilledButton>(_k('wizard_import_ok')).onPressed, isNull);
    });
  });

  group('a narrow window', () {
    testWidgets(
      'keeps every column: the table scrolls sideways and nothing overflows',
      (t) async {
        await _open(
          t,
          project: _project(canEditCost: true),
          size: const Size(900, 900),
        );
        expect(find.byType(Scrollbar), findsWidgets);
        // the cost column is off to the right, and reachable
        await _tap(t, _k('wizard_cost_tk1'));
        expect(_k('wizard_cost_mode_amount'), findsOneWidget);
        expect(t.takeException(), isNull);
      },
    );
  });

  group('the steps bar', () {
    testWidgets('a step is reached by its pill', (t) async {
      await _open(t);
      await _tap(t, _k('wizard_step_1'));
      expect(find.text('Milestones & Phases (WBS)'), findsOneWidget);
      await _tap(t, _k('wizard_step_2'));
      expect(find.text('Tasks & Ownership'), findsOneWidget);
      await _tap(t, _k('wizard_step_3'));
      expect(find.text('Total Tasks'), findsOneWidget);
    });
  });
}
