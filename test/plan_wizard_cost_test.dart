import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:nizan_crm/core/models/employee.dart';
import 'package:nizan_crm/core/theme/app_theme.dart';
import 'package:nizan_crm/features/it/data/it_task.dart';
import 'package:nizan_crm/features/it/data/project.dart';
import 'package:nizan_crm/features/it/domain/repositories/it_task_repository.dart';
import 'package:nizan_crm/features/it/domain/task_cost.dart';
import 'package:nizan_crm/features/it/presentation/controllers/it_tasks_notifier.dart';
import 'package:nizan_crm/features/it/presentation/screens/widgets/functional_plan_wizard_dialog.dart';
import 'package:nizan_crm/features/it/services/it_service.dart';

// The plan wizard with COSTS: a ₹ chip on each task (an amount, or hours × a rate), what the new tasks add up to against the approved
// budget, and — when they would take the plan over it — one question for the finance head's budget BEFORE any task is made, so that every
// task then fits inside the request. Someone who may not set costs sees none of it and sends none.

// ── fakes ───────────────────────────────────────────────────────────────────
/// What happened, in order: `raise:amount` and `create:title`.
final _events = <String>[];

class _Repo implements IITTaskRepository {
  final created = <Map<String, dynamic>>[];
  var _n = 0;

  @override
  Future<ITTask> createTask(Map<String, dynamic> data) async {
    created.add(data);
    _events.add('create:${data['title']}');
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

class _Projects extends ProjectService {
  _Projects() : super(Dio());
  final raised = <({double amount, String reason})>[];
  Object? fail;

  @override
  Future<Project> raiseCost(
    String id, {
    required double amount,
    String reason = '',
  }) async {
    if (fail != null) throw fail!;
    raised.add((amount: amount, reason: reason));
    _events.add('raise:${amount.round()}');
    return _project();
  }

  @override
  Future<List<Project>> getProjects({
    String? status,
    String? priority,
    String? search,
    String? department,
    bool ownerOnly = false,
  }) async => const [];
}

Project _project({
  bool canEditCost = true,
  double? planned = 90000,
  double ceiling = 100000,
  bool withCost = true,
  bool awaiting = false,
}) => Project.fromJson({
  '_id': 'p1',
  'name': 'Lifestyle brand at 2030',
  'targetDepartment': 'IT',
  'managerId': {'_id': 'm1', 'name': 'Amna'},
  'editMode': 'managed',
  'costStatus': withCost ? 'approved' : 'none',
  'departments': [
    {'name': 'IT', 'role': 'owner', 'status': 'accepted'},
  ],
  if (withCost && canEditCost)
    'cost': {
      'budget': ceiling,
      'approvedBudget': ceiling,
      'taskPlan': {
        'planned': planned ?? 0,
        'ceiling': ceiling,
        'level': 'warn',
        'over': 0,
        'leaves': 4,
        'priced': 4,
        'unpriced': 0,
        'byDepartment': <Map<String, dynamic>>[],
        'awaiting': awaiting,
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

/// One phase, two plain tasks.
_Seed _two({double firstAmount = 0, double secondAmount = 0}) => (
  phases: [PlanPhaseDraft(id: 'ph1', name: 'Design')],
  tasks: [
    PlanTaskDraft(
      id: 'tk1',
      phaseId: 'ph1',
      title: 'Wireframes',
      durationDays: 2,
      costMode: firstAmount > 0 ? 'amount' : '',
      costAmount: firstAmount,
    ),
    PlanTaskDraft(
      id: 'tk2',
      phaseId: 'ph1',
      title: 'Mockups',
      durationDays: 2,
      costMode: secondAmount > 0 ? 'amount' : '',
      costAmount: secondAmount,
    ),
  ],
);

/// A task with two sub-tasks (the task itself carries a cost it should not keep).
_Seed _group() => (
  phases: [PlanPhaseDraft(id: 'ph1', name: 'Build')],
  tasks: [
    PlanTaskDraft(
      id: 'tk1',
      phaseId: 'ph1',
      title: 'Frontend',
      durationDays: 5,
      costMode: 'amount',
      costAmount: 9999,
    ),
    PlanTaskDraft(
      id: 'sb1',
      phaseId: 'ph1',
      parentId: 'tk1',
      title: 'Login screen',
      durationDays: 2,
      costMode: 'amount',
      costAmount: 3000,
    ),
    PlanTaskDraft(
      id: 'sb2',
      phaseId: 'ph1',
      parentId: 'tk1',
      title: 'Dashboard',
      durationDays: 3,
      costMode: 'rate',
      costRate: 500,
      hours: 10,
    ),
  ],
);

late _Repo _repo;
late _Projects _svc;

Future<void> _open(
  WidgetTester t, {
  Project? project,
  _Seed? seed,
  List<ITTask> existing = const [],
}) async {
  _events.clear();
  t.view.physicalSize = const Size(1500, 1100);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  _repo = _Repo();
  _svc = _Projects();
  await t.pumpWidget(const SizedBox.shrink());
  await t.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: <Override>[
        projectEmployeesProvider(
          'p1',
        ).overrideWith((ref) => const <Employee>[]),
        itTaskRepositoryProvider.overrideWithValue(_repo),
        projectServiceProvider.overrideWithValue(_svc),
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
                  seed: seed ?? _two(),
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

Future<void> _continue(WidgetTester t, [int times = 1]) async {
  for (var i = 0; i < times; i++) {
    await t.tap(find.byKey(const Key('wizard_next')));
    await t.pumpAndSettle();
  }
}

Finder _k(String key) => find.byKey(Key(key));

Future<void> _tap(WidgetTester t, Finder f) async {
  await t.ensureVisible(f);
  await t.pumpAndSettle();
  await t.tap(f);
  await t.pumpAndSettle();
}

Future<void> _type(WidgetTester t, Finder f, String text) async {
  await t.ensureVisible(f);
  await t.enterText(f, text);
  await t.pump();
}

String _text(WidgetTester t, String key) => t.widget<Text>(_k(key)).data ?? '';

/// Give a task an amount through the dialog.
Future<void> _setAmount(WidgetTester t, String taskId, String amount) async {
  await _tap(t, _k('wizard_cost_$taskId'));
  await _tap(t, _k('wizard_cost_mode_amount'));
  await _type(t, _k('wizard_cost_amount'), amount);
  await _tap(t, _k('wizard_cost_save'));
}

Future<void> _generate(WidgetTester t) async {
  await _continue(t, 3); // scope → phases → tasks → the last step
  await t.tap(find.text('Generate Gratt Plan'));
  await t.pumpAndSettle();
}

void main() {
  // ── pure ────────────────────────────────────────────────────────────────────
  group('what the new tasks add to the plan', () {
    PlanCostSummary sum(
      List<({double planned, bool isGroup})> tasks, {
      double existing = 0,
      double ceiling = 0,
    }) => summarizePlanCost(tasks: tasks, existing: existing, ceiling: ceiling);

    test(
      'a task\'s cost works out from the amount, or hours × the rate, to the paisa',
      () {
        expect(
          PlanTaskDraft(
            id: 'a',
            phaseId: 'p',
            title: 'x',
            costMode: 'amount',
            costAmount: 12500,
          ).plannedCost,
          12500,
        );
        expect(
          PlanTaskDraft(
            id: 'a',
            phaseId: 'p',
            title: 'x',
            costMode: 'rate',
            costRate: 750,
            hours: 12.5,
          ).plannedCost,
          9375,
        );
        expect(
          PlanTaskDraft(
            id: 'a',
            phaseId: 'p',
            title: 'x',
            costMode: 'rate',
            costRate: 333.33,
            hours: 3,
          ).plannedCost,
          999.99,
        );
        expect(PlanTaskDraft(id: 'a', phaseId: 'p', title: 'x').plannedCost, 0);
        expect(
          PlanTaskDraft(
            id: 'a',
            phaseId: 'p',
            title: 'x',
            costMode: '',
            costAmount: 500,
          ).plannedCost,
          0,
          reason: 'a mode of none ignores a stale amount',
        );
        final copy = PlanTaskDraft(
          id: 'a',
          phaseId: 'p',
          title: 'x',
          costMode: 'rate',
          costRate: 100,
          hours: 2,
        ).copyWith(title: 'y');
        expect(
          (copy.costMode, copy.costRate, copy.hours, copy.plannedCost),
          ('rate', 100.0, 2.0, 200.0),
        );
      },
    );

    test(
      'only tasks with no sub-tasks count; priced and unpriced are told apart',
      () {
        final s = sum([
          (planned: 5000, isGroup: false),
          (planned: 9999, isGroup: true),
          (planned: 0, isGroup: false),
          (planned: 2500.5, isGroup: false),
        ]);
        expect((s.newTotal, s.priced, s.unpriced), (7500.5, 2, 1));
      },
    );

    test(
      'against the budget: nothing to hold it against, ok, warn from 80%, over',
      () {
        expect(
          sum([(planned: 5000, isGroup: false)], existing: 90000).level,
          'none',
        );
        expect(
          sum(
            [(planned: 5000, isGroup: false)],
            existing: 0,
            ceiling: 100000,
          ).level,
          'ok',
        );
        expect(
          sum(
            [(planned: 5000, isGroup: false)],
            existing: 75000,
            ceiling: 100000,
          ).level,
          'warn',
        );
        expect(
          sum(
            [(planned: 10000, isGroup: false)],
            existing: 90000,
            ceiling: 100000,
          ).level,
          'warn',
          reason: 'exactly the budget is not over',
        );
        expect(
          sum(
            [(planned: 10000.01, isGroup: false)],
            existing: 90000,
            ceiling: 100000,
          ).level,
          'over',
        );
      },
    );

    test('it says how far over, and whether a budget increase is needed', () {
      final over = sum(
        [(planned: 30000, isGroup: false)],
        existing: 90000,
        ceiling: 100000,
      );
      expect(
        (over.after, over.over, over.needsIncrease),
        (120000.0, 20000.0, true),
      );
      final fits = sum(
        [(planned: 10000, isGroup: false)],
        existing: 90000,
        ceiling: 100000,
      );
      expect((fits.over, fits.needsIncrease), (0.0, false));
      expect(
        sum([(planned: 30000, isGroup: false)], existing: 90000).needsIncrease,
        isFalse,
        reason: 'no budget yet, nothing to ask more of',
      );
      expect(
        sum(
          [(planned: 0, isGroup: false)],
          existing: 120000,
          ceiling: 100000,
        ).needsIncrease,
        isFalse,
        reason: 'tasks with no cost add nothing, even to a plan already over',
      );
    });

    test('what a project\'s tasks already add up to, counting leaves only', () {
      ITTask t(String id, {String? parent, double cost = 0}) => ITTask(
        id: id,
        projectId: 'p1',
        title: id,
        parentTaskId: parent,
        plannedCost: cost,
      );
      expect(
        plannedTotal([
          t('ph', cost: 999),
          t('a', parent: 'ph', cost: 1000),
          t('b', parent: 'ph', cost: 2500.5),
          t('solo', cost: 50),
        ]),
        3550.5,
      );
      expect(plannedTotal([t('a', parent: 'gone', cost: 10)]), 10);
      expect(plannedTotal(const []), 0);
      expect(planLevel(79999, 100000), 'ok');
      expect(planLevel(80000, 100000), 'warn');
      expect(planLevel(1, 0), 'none');
    });
  });

  // ── the chip and its dialog ───────────────────────────────────────────────
  group('the cost chip on a task', () {
    testWidgets(
      'someone who may set costs sees a chip on each task and the strip above them',
      (t) async {
        await _open(t);
        await _continue(t, 2);
        expect(_k('wizard_cost_tk1'), findsOneWidget);
        expect(_k('wizard_cost_tk2'), findsOneWidget);
        expect(_k('wizard_cost_strip'), findsOneWidget);
        expect(find.text('Add cost'), findsNWidgets(2));
        expect(_text(t, 'wizard_cost_total'), '₹0');
        expect(
          _k('wizard_cost_hint'),
          findsOneWidget,
          reason: 'tells how to give a task a cost',
        );
      },
    );

    testWidgets('someone who may not sees none of it', (t) async {
      await _open(t, project: _project(canEditCost: false));
      await _continue(t, 2);
      expect(_k('wizard_cost_tk1'), findsNothing);
      expect(_k('wizard_cost_strip'), findsNothing);
      expect(find.text('Add cost'), findsNothing);
    });

    testWidgets(
      'an amount: the chip shows it, the strip adds it up, the cross takes it away',
      (t) async {
        await _open(t);
        await _continue(t, 2);
        await _setAmount(t, 'tk1', '12,500');
        expect(
          find.descendant(
            of: _k('wizard_cost_tk1'),
            matching: find.text('₹12,500'),
          ),
          findsOneWidget,
        );
        expect(_text(t, 'wizard_cost_total'), '₹12,500');
        await _setAmount(t, 'tk2', '7500');
        expect(_text(t, 'wizard_cost_total'), '₹20,000');
        await _tap(t, _k('wizard_cost_clear_tk1'));
        expect(_text(t, 'wizard_cost_total'), '₹7,500');
        expect(find.text('Add cost'), findsOneWidget);
        expect(_k('wizard_cost_clear_tk1'), findsNothing);
      },
    );

    testWidgets(
      'hours × a rate: the dialog says what it works out to, and the chip says how it was worked out',
      (t) async {
        await _open(t);
        await _continue(t, 2);
        await _tap(t, _k('wizard_cost_tk1'));
        await _tap(t, _k('wizard_cost_mode_rate'));
        await _type(t, _k('wizard_cost_hours'), '20');
        await _type(t, _k('wizard_cost_rate'), '500');
        expect(_text(t, 'wizard_cost_preview'), 'Planned cost: ₹10,000');
        await _tap(t, _k('wizard_cost_save'));
        expect(find.text('20 h × ₹500 = ₹10,000'), findsOneWidget);
        expect(_text(t, 'wizard_cost_total'), '₹10,000');
      },
    );

    testWidgets('the dialog opens on what the task already has', (t) async {
      await _open(t, seed: _two(firstAmount: 4000));
      await _continue(t, 2);
      await _tap(t, _k('wizard_cost_tk1'));
      expect(
        t.widget<ChoiceChip>(_k('wizard_cost_mode_amount')).selected,
        isTrue,
      );
      expect(
        t.widget<TextField>(_k('wizard_cost_amount')).controller!.text,
        '4000',
      );
    });

    testWidgets(
      'a cost that is not an amount, or hours without a rate, is refused in the dialog',
      (t) async {
        await _open(t);
        await _continue(t, 2);
        await _tap(t, _k('wizard_cost_tk1'));
        await _tap(t, _k('wizard_cost_mode_amount'));
        await _tap(t, _k('wizard_cost_save'));
        expect(
          _text(t, 'wizard_cost_error'),
          'Enter the cost as an amount above zero.',
        );
        await _tap(t, _k('wizard_cost_mode_rate'));
        await _type(t, _k('wizard_cost_hours'), '20');
        await _tap(t, _k('wizard_cost_save'));
        expect(
          _text(t, 'wizard_cost_error'),
          'Enter the hours and the rate per hour.',
        );
        expect(_k('wizard_cost_dialog'), findsOneWidget, reason: 'still open');
        await _tap(t, _k('wizard_cost_cancel'));
        expect(_text(t, 'wizard_cost_total'), '₹0');
      },
    );

    testWidgets('choosing "No cost" takes a cost away', (t) async {
      await _open(t, seed: _two(firstAmount: 4000));
      await _continue(t, 2);
      await _tap(t, _k('wizard_cost_tk1'));
      await _tap(t, _k('wizard_cost_mode_none'));
      await _tap(t, _k('wizard_cost_save'));
      expect(_text(t, 'wizard_cost_total'), '₹0');
    });

    testWidgets(
      'a task with sub-tasks has no chip of its own: it shows the total of theirs, and its own cost is not counted',
      (t) async {
        await _open(t, seed: _group());
        await _continue(t, 2);
        expect(_k('wizard_cost_tk1'), findsNothing);
        expect(_k('wizard_cost_sb1'), findsOneWidget);
        expect(
          _text(t, 'wizard_cost_group_tk1'),
          'Cost ₹8,000 from its sub-tasks',
        );
        expect(
          _text(t, 'wizard_cost_total'),
          '₹8,000',
          reason:
              '3,000 + 10 h × ₹500; the 9,999 on the task itself is not counted',
        );
      },
    );
  });

  // ── the strip against the budget ──────────────────────────────────────────
  group('the strip above the tasks', () {
    testWidgets(
      'says what the plan comes to against the approved budget, and how many tasks have no cost yet',
      (t) async {
        await _open(t, seed: _two(firstAmount: 5000));
        await _continue(t, 2);
        expect(
          _text(t, 'wizard_cost_plan'),
          'The plan so far ₹90,000 + these = ₹95,000 of the ₹1,00,000 approved.',
        );
        expect(
          _text(t, 'wizard_cost_unpriced'),
          '1 of 2 tasks have no cost yet.',
        );
        expect(_k('wizard_cost_over'), findsNothing);
      },
    );

    testWidgets(
      'warns plainly when the new tasks take it over, and says what will happen',
      (t) async {
        await _open(t, seed: _two(firstAmount: 20000));
        await _continue(t, 2);
        expect(
          _text(t, 'wizard_cost_over'),
          '₹10,000 above the budget. When you create the plan you will be asked for a budget increase for the finance head.',
        );
      },
    );

    testWidgets(
      'while an increase waits, the plan is held against what was asked for',
      (t) async {
        await _open(
          t,
          project: _project(planned: 90000, ceiling: 120000, awaiting: true),
          seed: _two(firstAmount: 20000),
        );
        await _continue(t, 2);
        expect(
          _text(t, 'wizard_cost_plan'),
          contains('of the ₹1,20,000 asked for'),
        );
        expect(_k('wizard_cost_over'), findsNothing);
      },
    );

    testWidgets(
      'a project with no budget yet has no plan line, and no warning',
      (t) async {
        await _open(
          t,
          project: _project(withCost: false),
          seed: _two(firstAmount: 20000),
        );
        await _continue(t, 2);
        expect(_text(t, 'wizard_cost_total'), '₹20,000');
        expect(_k('wizard_cost_plan'), findsNothing);
        expect(_k('wizard_cost_over'), findsNothing);
      },
    );

    testWidgets(
      'the last step shows the planned cost beside the other figures — and only when there is one',
      (t) async {
        await _open(t, seed: _two(firstAmount: 5000, secondAmount: 2500));
        await _continue(t, 3);
        expect(find.text('Planned Cost'), findsOneWidget);
        expect(find.text('₹7,500'), findsOneWidget);
        await _open(t);
        await _continue(t, 3);
        expect(find.text('Planned Cost'), findsNothing);
      },
    );
  });

  // ── making the plan ───────────────────────────────────────────────────────
  group('making the plan', () {
    testWidgets(
      'sends each task\'s cost, hours for the hours-based ones, and nothing for the phase or a task with sub-tasks',
      (t) async {
        await _open(t, seed: _group());
        await _generate(t);
        final bodies = {for (final b in _repo.created) b['title'] as String: b};
        expect(bodies.keys.toSet(), {
          'Build',
          'Frontend',
          'Login screen',
          'Dashboard',
        });
        for (final k in [
          'costMode',
          'costAmount',
          'costRate',
          'estimatedHours',
        ]) {
          expect(
            bodies['Build']!.containsKey(k),
            isFalse,
            reason: 'the phase: $k',
          );
          expect(
            bodies['Frontend']!.containsKey(k),
            isFalse,
            reason: 'a task with sub-tasks: $k',
          );
        }
        expect(
          (
            bodies['Login screen']!['costMode'],
            bodies['Login screen']!['costAmount'],
            bodies['Login screen']!['costRate'],
          ),
          ('amount', 3000.0, 0),
        );
        expect(bodies['Login screen']!.containsKey('estimatedHours'), isFalse);
        expect(
          (
            bodies['Dashboard']!['costMode'],
            bodies['Dashboard']!['costAmount'],
            bodies['Dashboard']!['costRate'],
            bodies['Dashboard']!['estimatedHours'],
          ),
          ('rate', 0, 500.0, 10.0),
        );
      },
    );

    testWidgets(
      'a task with no cost says so; someone who may not set costs sends no cost keys at all',
      (t) async {
        await _open(t);
        await _generate(t);
        final plain = _repo.created.firstWhere(
          (b) => b['title'] == 'Wireframes',
        );
        expect(
          (plain['costMode'], plain['costAmount'], plain['costRate']),
          ('', 0, 0),
        );

        await _open(t, project: _project(canEditCost: false), seed: _group());
        await _generate(t);
        for (final b in _repo.created) {
          for (final k in [
            'costMode',
            'costAmount',
            'costRate',
            'estimatedHours',
          ]) {
            expect(b.containsKey(k), isFalse, reason: '${b['title']}: $k');
          }
        }
        expect(_svc.raised, isEmpty);
      },
    );

    testWidgets(
      'inside the budget: no question, no request, the plan is made',
      (t) async {
        await _open(t, seed: _two(firstAmount: 5000, secondAmount: 5000));
        await _generate(t);
        expect(_k('over_budget_dialog'), findsNothing);
        expect(_svc.raised, isEmpty);
        expect(_repo.created, hasLength(3));
      },
    );

    testWidgets(
      'over the budget: asked first with the numbers; backing out makes nothing and sends nothing',
      (t) async {
        await _open(t, seed: _two(firstAmount: 20000));
        await _generate(t);
        expect(_k('over_budget_dialog'), findsOneWidget);
        expect(
          t.widget<Text>(_k('over_budget_message')).data,
          contains('₹1,10,000'),
        );
        expect(
          t.widget<Text>(_k('over_budget_message')).data,
          contains('₹10,000 above the ₹1,00,000'),
        );
        expect(
          t.widget<TextField>(_k('over_budget_amount')).controller!.text,
          '110000',
          reason: 'what the plan would come to',
        );
        await _tap(t, _k('over_budget_cancel'));
        expect(_repo.created, isEmpty);
        expect(_svc.raised, isEmpty);
        expect(
          find.text('Generate Gratt Plan'),
          findsOneWidget,
          reason: 'the wizard is still open',
        );
      },
    );

    testWidgets(
      'confirming asks the finance head for the bigger total BEFORE the first task is made, then makes them all',
      (t) async {
        await _open(t, seed: _two(firstAmount: 20000));
        await _generate(t);
        await _type(t, _k('over_budget_amount'), '1,25,000');
        await _type(
          t,
          _k('over_budget_reason'),
          'Two more vendors than planned',
        );
        await _tap(t, _k('over_budget_send'));
        expect(_svc.raised.single, (
          amount: 125000.0,
          reason: 'Two more vendors than planned',
        ));
        expect(_events.first, 'raise:125000', reason: 'asked first');
        expect(_events.where((e) => e.startsWith('create:')), hasLength(3));
        expect(
          _events.indexOf('raise:125000') < _events.indexOf('create:Design'),
          isTrue,
        );
        expect(
          find.textContaining(
            'A budget of ₹1,25,000 was sent to the finance head.',
          ),
          findsWidgets,
        );
        expect(
          find.text('Generate Gratt Plan'),
          findsNothing,
          reason: 'the wizard closed',
        );
      },
    );

    testWidgets(
      'the ask is checked before it is sent: a total that does not cover the tasks, and a missing reason',
      (t) async {
        await _open(t, seed: _two(firstAmount: 20000));
        await _generate(t);
        await _type(t, _k('over_budget_amount'), '1,00,000');
        await _type(t, _k('over_budget_reason'), 'More work');
        await _tap(t, _k('over_budget_send'));
        expect(_text(t, 'over_budget_error'), contains('at least ₹1,10,000'));
        await _type(t, _k('over_budget_amount'), '1,20,000');
        await _type(t, _k('over_budget_reason'), '');
        await _tap(t, _k('over_budget_send'));
        expect(_text(t, 'over_budget_error'), 'Say why more is needed.');
        expect(_svc.raised, isEmpty);
        expect(_repo.created, isEmpty);
      },
    );

    testWidgets(
      'if the server refuses the bigger total, the reason is shown and nothing is made',
      (t) async {
        await _open(t, seed: _two(firstAmount: 20000));
        await _generate(t);
        _svc.fail = Exception('boom');
        await _type(t, _k('over_budget_amount'), '1,20,000');
        await _type(t, _k('over_budget_reason'), 'More work');
        await _tap(t, _k('over_budget_send'));
        expect(_repo.created, isEmpty);
        expect(find.byType(SnackBar), findsWidgets);
        expect(
          find.text('Generate Gratt Plan'),
          findsOneWidget,
          reason: 'the wizard stays so it can be tried again',
        );
      },
    );

    testWidgets(
      'a project with no budget yet is never asked, whatever the tasks cost',
      (t) async {
        await _open(
          t,
          project: _project(withCost: false),
          seed: _two(firstAmount: 900000),
        );
        await _generate(t);
        expect(_k('over_budget_dialog'), findsNothing);
        expect(_svc.raised, isEmpty);
        expect(_repo.created, hasLength(3));
      },
    );

    testWidgets(
      'tasks with no cost are never the reason to ask, even when the plan is already over',
      (t) async {
        await _open(t, project: _project(planned: 120000));
        await _generate(t);
        expect(_k('over_budget_dialog'), findsNothing);
        expect(_svc.raised, isEmpty);
      },
    );

    testWidgets(
      'what the project already holds counts: tasks it already has are part of the plan',
      (t) async {
        await _open(
          t,
          project: _project(planned: 0),
          seed: _two(firstAmount: 60000, secondAmount: 50000),
          existing: [
            ITTask(id: 'e1', projectId: 'p1', title: 'Old', plannedCost: 5000),
          ],
        );
        await _continue(t, 2);
        // the project says 0 already planned; the wizard trusts that over its own sum
        expect(
          _text(t, 'wizard_cost_plan'),
          'The plan so far ₹0 + these = ₹1,10,000 of the ₹1,00,000 approved.',
        );
        expect(_k('wizard_cost_over'), findsOneWidget);
      },
    );
  });
}
