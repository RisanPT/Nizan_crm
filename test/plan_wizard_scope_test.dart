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

// Step 1 of the plan wizard (Scope & Lead): a "Function Overview" card on the left, a live "Plan Summary" card on the right, the
// steps bar with the names alone, and a footer whose next button says where it goes.

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

Project _project({
  List<String> departments = const ['IT'],
  String owner = 'IT',
}) => Project.fromJson({
  '_id': 'p1',
  'name': 'Lifestyle brand at 2030',
  'targetDepartment': owner,
  'managerId': {'_id': 'm1', 'name': 'Amna'},
  'editMode': 'managed',
  'departments': [
    for (var i = 0; i < departments.length; i++)
      {
        'name': departments[i],
        'role': i == 0 ? 'owner' : 'participant',
        'status': 'accepted',
      },
  ],
  'access': {
    'role': 'manager',
    'canManage': true,
    'editMode': 'managed',
    'canCreateTasks': true,
    'canEditAllTasks': true,
    'leadDepartments': <String>[],
    'pendingInvitations': <String>[],
    'canDecide': false,
  },
});

late _Repo _repo;

Future<void> _open(
  WidgetTester t, {
  Project? project,
  Size size = const Size(1500, 1100),
  List<ITTask> existing = const [],
  ({List<PlanPhaseDraft> phases, List<PlanTaskDraft> tasks})? seed,
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  _repo = _Repo();
  await t.pumpWidget(const SizedBox.shrink());
  await t.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: <Override>[
        projectEmployeesProvider(
          'p1',
        ).overrideWith((ref) => const <Employee>[]),
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
                  existingTasks: existing,
                  project: project ?? _project(),
                  seed: seed,
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
}

Finder _k(String key) => find.byKey(Key(key));
String _text(WidgetTester t, String key) => t.widget<Text>(_k(key)).data ?? '';
final _today = DateFormat.yMMMd().format(DateTime.now());

Future<void> _next(WidgetTester t) async {
  await t.tap(_k('wizard_next'));
  await t.pumpAndSettle();
}

void main() {
  group('the cards', () {
    testWidgets(
      'a Function Overview card and a Plan Summary card side by side',
      (t) async {
        await _open(t);
        expect(find.text('Function Overview'), findsOneWidget);
        expect(find.text('Plan Summary'), findsOneWidget);
        final main = t.getRect(_k('wizard_scope_card'));
        final summary = t.getRect(_k('wizard_summary_card'));
        expect(summary.left, greaterThan(main.right));
        expect(summary.width, 340);
        // the fields of the main card, in their places
        expect(
          find.descendant(
            of: _k('wizard_scope_card'),
            matching: find.text('Department'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: _k('wizard_summary_card'),
            matching: find.text('Department'),
          ),
          findsOneWidget,
        ); // and again as a row of the summary
        expect(find.text('Functional Lead / Head'), findsOneWidget);
        expect(find.text('Window Start Date'), findsOneWidget);
        expect(
          find.text('Key Deliverable / Objective Statement'),
          findsOneWidget,
        );
        expect(find.text('Project Owner'), findsOneWidget);
        expect(t.takeException(), isNull);
      },
    );

    testWidgets(
      'the summary starts with the department and the start day, and dashes for the rest',
      (t) async {
        await _open(t);
        expect(_text(t, 'wizard_summary_department'), 'IT');
        expect(_text(t, 'wizard_summary_lead'), '—');
        expect(_text(t, 'wizard_summary_start'), _today);
        expect(_text(t, 'wizard_summary_objective'), '—');
      },
    );

    testWidgets('what is typed shows in the summary as it is typed', (t) async {
      await _open(t);
      await t.enterText(_k('wizard_lead_field'), '  Amna Rahman ');
      await t.pump();
      expect(_text(t, 'wizard_summary_lead'), 'Amna Rahman');
      await t.enterText(_k('wizard_objective_field'), 'Ship the new site');
      await t.pump();
      expect(_text(t, 'wizard_summary_objective'), 'Ship the new site');
      // emptied again: back to a dash
      await t.enterText(_k('wizard_lead_field'), '   ');
      await t.pump();
      expect(_text(t, 'wizard_summary_lead'), '—');
    });

    testWidgets('the objective counts its characters and stops at 500', (
      t,
    ) async {
      await _open(t);
      expect(_text(t, 'wizard_objective_count'), '0 / 500');
      await t.enterText(_k('wizard_objective_field'), 'Ship it');
      await t.pump();
      expect(_text(t, 'wizard_objective_count'), '7 / 500');
      await t.enterText(_k('wizard_objective_field'), 'x' * 650);
      await t.pump();
      expect(_text(t, 'wizard_objective_count'), '500 / 500');
      expect(
        t.widget<TextField>(_k('wizard_objective_field')).controller!.text,
        hasLength(500),
      );
    });

    testWidgets('a start day picked from the calendar goes to the summary', (
      t,
    ) async {
      await _open(t);
      await t.tap(_k('wizard_start_window'));
      await t.pumpAndSettle();
      await t.tap(find.text('15'));
      await t.tap(find.text('OK'));
      await t.pumpAndSettle();
      final now = DateTime.now();
      final want = DateFormat.yMMMd().format(DateTime(now.year, now.month, 15));
      expect(_text(t, 'wizard_summary_start'), want);
      expect(
        find.descendant(
          of: _k('wizard_start_window'),
          matching: find.text(want),
        ),
        findsOneWidget,
      );
    });

    testWidgets(
      'with several departments the department is chosen, and the summary follows',
      (t) async {
        await _open(
          t,
          project: _project(
            departments: ['Marketing', 'IT'],
            owner: 'Marketing',
          ),
        );
        expect(
          find.text('Project Owner'),
          findsNothing,
        ); // no longer one fixed department
        expect(_text(t, 'wizard_summary_department'), 'Marketing');
        await t.tap(find.byType(DropdownButtonFormField<String>));
        await t.pumpAndSettle();
        await t.tap(find.text('IT').last);
        await t.pumpAndSettle();
        expect(_text(t, 'wizard_summary_department'), 'IT');
      },
    );

    testWidgets('a project that already has a plan says so in the card', (
      t,
    ) async {
      await _open(
        t,
        existing: [
          ITTask(id: 'e1', projectId: 'p1', title: 'Discovery'),
          ITTask(
            id: 'e2',
            projectId: 'p1',
            title: 'Interviews',
            parentTaskId: 'e1',
          ),
        ],
      );
      expect(
        find.descendant(
          of: _k('wizard_existing_note'),
          matching: find.textContaining('already has 1 phase and 1 task'),
        ),
        findsOneWidget,
      );
    });

    testWidgets(
      'in a narrow window the summary goes under the form, and nothing overflows',
      (t) async {
        await _open(t, size: const Size(800, 1000));
        final main = t.getRect(_k('wizard_scope_card'));
        final summary = t.getRect(_k('wizard_summary_card'));
        expect(summary.top, greaterThanOrEqualTo(main.bottom));
        expect(t.takeException(), isNull);
      },
    );

    testWidgets(
      'the objective still goes into the description of what is made',
      (t) async {
        await _open(
          t,
          seed: (
            phases: [PlanPhaseDraft(id: 'ph1', name: 'Design')],
            tasks: [
              PlanTaskDraft(
                id: 'tk1',
                phaseId: 'ph1',
                title: 'Wireframes',
                durationDays: 2,
              ),
            ],
          ),
        );
        await t.enterText(_k('wizard_objective_field'), 'Ship the new site');
        await t.pump();
        await _next(t);
        await _next(t);
        await _next(t);
        await t.tap(_k('wizard_generate'));
        await t.pumpAndSettle();
        expect(
          _repo.created.any(
            (b) => b['description'] == 'Objective: Ship the new site',
          ),
          isTrue,
        );
      },
    );
  });

  group('the steps bar and the footer', () {
    testWidgets('the steps are named without numbers in the names', (t) async {
      await _open(t);
      for (final name in [
        'Scope & Lead',
        'Phases & WBS',
        'Tasks & Team',
        'Dependencies & Gratt',
      ]) {
        expect(find.text(name), findsOneWidget, reason: name);
      }
      expect(find.text('1. Scope & Lead'), findsNothing);
    });

    testWidgets(
      'the first step has Cancel on the left and a next button that says where it goes',
      (t) async {
        await _open(t);
        expect(_k('wizard_cancel'), findsOneWidget);
        expect(find.text('Cancel'), findsOneWidget);
        expect(find.text('Back'), findsNothing);
        expect(find.text('Next: Phases & WBS'), findsOneWidget);
        expect(
          t.getRect(_k('wizard_cancel')).left,
          lessThan(t.getRect(_k('wizard_next')).left),
        );
      },
    );

    testWidgets(
      'each step names the one after it, with Back from the second on',
      (t) async {
        await _open(t);
        await _next(t);
        expect(find.text('Next: Tasks & Team'), findsOneWidget);
        expect(_k('wizard_back'), findsOneWidget);
        expect(
          find.text('Cancel'),
          findsOneWidget,
        ); // still there, on the right
        expect(_k('wizard_cancel'), findsNothing);
        await _next(t);
        expect(find.text('Next: Dependencies & Gratt'), findsOneWidget);
        await _next(t);
        expect(_k('wizard_next'), findsNothing);
        expect(find.text('Generate Gratt Plan'), findsOneWidget);
        await t.tap(_k('wizard_back'));
        await t.pumpAndSettle();
        expect(find.text('Next: Dependencies & Gratt'), findsOneWidget);
      },
    );

    testWidgets('Cancel closes the wizard', (t) async {
      await _open(t);
      await t.tap(_k('wizard_cancel'));
      await t.pumpAndSettle();
      expect(find.text('Functional Plan & Gratt Auto-Scheduler'), findsNothing);
    });

    testWidgets(
      'the steps bar takes you to a step, and a done step is ticked',
      (t) async {
        await _open(t);
        expect(find.byIcon(Icons.check), findsNothing);
        await t.tap(_k('wizard_step_2'));
        await t.pumpAndSettle();
        expect(find.text('Tasks & Ownership'), findsOneWidget);
        expect(
          find.byIcon(Icons.check),
          findsNWidgets(2),
        ); // steps 1 and 2 are behind
        await t.tap(_k('wizard_step_0'));
        await t.pumpAndSettle();
        expect(find.text('Function Overview'), findsOneWidget);
      },
    );
  });
}
