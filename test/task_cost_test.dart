import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/models/auth_session.dart';
import 'package:nizan_crm/core/models/employee.dart';
import 'package:nizan_crm/core/providers/auth_provider.dart';
import 'package:nizan_crm/core/theme/app_theme.dart';
import 'package:nizan_crm/features/it/data/it_task.dart';
import 'package:nizan_crm/features/it/data/project.dart';
import 'package:nizan_crm/features/it/domain/repositories/it_task_repository.dart';
import 'package:nizan_crm/features/it/domain/task_cost.dart';
import 'package:nizan_crm/features/it/presentation/controllers/it_tasks_notifier.dart';
import 'package:nizan_crm/features/it/presentation/screens/project_budgets_screen.dart';
import 'package:nizan_crm/features/it/presentation/screens/widgets/it_task_editor.dart';
import 'package:nizan_crm/features/it/presentation/screens/widgets/it_wbs_view.dart';
import 'package:nizan_crm/features/it/presentation/screens/widgets/project_cost_widgets.dart';
import 'package:nizan_crm/features/it/services/it_service.dart';

// What a task costs, in the app: the cost boxes of the task editor, the ask for a budget increase when a task would take the project
// over its approved budget, the Cost column of the WBS, "planned by tasks" on the project's cost card, and the plan behind a request on
// Finance's list. The rules are the server's (backend utils/taskCost.js); these tests check what the app reads, shows and sends.

// ── builders ────────────────────────────────────────────────────────────────

Map<String, dynamic> _access({
  bool canEditCost = true,
  bool canSeeCost = true,
  bool manage = true,
}) => {
  'role': manage ? 'manager' : 'dept_lead',
  'canManage': manage,
  'editMode': 'managed',
  'canCreateTasks': true,
  'canEditAllTasks': manage,
  'leadDepartments': <String>[],
  'pendingInvitations': <String>[],
  'canDecide': false,
  'canSeeCost': canSeeCost,
  'canEditCost': canEditCost,
};

Map<String, dynamic> _plan({
  double planned = 90000,
  double ceiling = 100000,
  String level = 'warn',
  double over = 0,
  int leaves = 5,
  int priced = 4,
  bool awaiting = false,
}) => {
  'planned': planned,
  'ceiling': ceiling,
  'level': level,
  'over': over,
  'leaves': leaves,
  'priced': priced,
  'unpriced': leaves - priced,
  'byDepartment': [
    {'name': 'Marketing', 'planned': planned, 'tasks': leaves},
  ],
  'awaiting': awaiting,
};

Project _project({
  Map<String, dynamic>? access,
  Map<String, dynamic>? taskPlan,
  String costStatus = 'approved',
  Map<String, dynamic>? cost,
}) => Project.fromJson({
  '_id': 'p1',
  'name': 'Website redesign',
  'status': 'active',
  'targetDepartment': 'Marketing',
  'managerId': {'_id': 'm1', 'name': 'Mira'},
  'editMode': 'managed',
  'departments': [
    {'name': 'Marketing', 'role': 'owner', 'status': 'accepted'},
  ],
  'costStatus': costStatus,
  'cost':
      cost ??
      {'budget': 100000, 'approvedBudget': 100000, 'taskPlan': ?taskPlan},
  'access': access ?? _access(),
});

ITTask _t(
  String id, {
  String? parent,
  double cost = 0,
  String mode = '',
  double hours = 0,
  double rate = 0,
  double amount = 0,
  String assignee = '',
}) => ITTask(
  id: id,
  projectId: 'p1',
  title: 'Task $id',
  parentTaskId: parent,
  plannedCost: cost,
  costMode: mode,
  costAmount: amount,
  costRate: rate,
  estimatedHours: hours,
  assigneeId: assignee,
);

AppException _overBudget({
  bool seer = true,
  bool canRequest = true,
  String? message,
}) => AppException(
  DioException(
    requestOptions: RequestOptions(path: '/it-tasks'),
    type: DioExceptionType.badResponse,
    response: Response(
      requestOptions: RequestOptions(path: '/it-tasks'),
      statusCode: 409,
      data: {
        'code': 'TASK_COST_OVER_BUDGET',
        'message':
            message ??
            (seer
                ? 'With this the tasks add up to ₹1,17,200, which is ₹17,200 above the ₹1,00,000 the project has.'
                : 'This change would take the project over its approved budget. Ask the project manager to raise the budget first.'),
        if (seer)
          'plan': {
            'planned': 117200,
            'ceiling': 100000,
            'over': 17200,
            'approved': 100000,
            'canRequest': canRequest,
          },
      },
    ),
  ),
  action: 'create the task',
);

class _FakeTasks extends ITTaskService {
  _FakeTasks() : super(Dio());
  final created = <Map<String, dynamic>>[];
  final updated = <Map<String, dynamic>>[];

  /// What the next save throws, in order (then it succeeds).
  final failures = <Object>[];
  TaskSaveResult result = const TaskSaveResult();

  Future<TaskSaveResult> _save(
    List<Map<String, dynamic>> into,
    Map<String, dynamic> body,
  ) async {
    into.add(body);
    if (failures.isNotEmpty) throw failures.removeAt(0);
    return result;
  }

  @override
  Future<TaskSaveResult> createTask(Map<String, dynamic> body) =>
      _save(created, body);
  @override
  Future<TaskSaveResult> updateTask(String id, Map<String, dynamic> body) =>
      _save(updated, body);
}

class _Projects extends ProjectService {
  _Projects() : super(Dio());
  List<PendingProjectCost> pending = [];

  @override
  Future<List<PendingProjectCost>> pendingCosts() async => pending;
  @override
  Future<List<Project>> getProjects({
    String? status,
    String? priority,
    String? search,
    String? department,
    bool ownerOnly = false,
  }) async => const [];
}

AuthSession _session() => AuthSession(
  token: 't',
  userId: 'u',
  name: 'U',
  email: 'u@x',
  role: 'crm',
  employeeId: 'e1',
);

Finder _k(String key) => find.byKey(Key(key));
Finder _submit(String verb) =>
    find.textContaining(RegExp('^$verb (ticket|task)\$'));

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

void main() {
  // ── what the app reads ────────────────────────────────────────────────────
  group('reading costs', () {
    test(
      'a task reads its cost; an older task has none; the whole task sent back carries no cost keys',
      () {
        final t = ITTask.fromJson({
          '_id': 't1',
          'projectId': 'p1',
          'title': 'Build',
          'costMode': 'rate',
          'costAmount': 0,
          'costRate': 500,
          'plannedCost': 10000,
          'estimatedHours': 20,
        });
        expect(
          (t.costMode, t.costRate, t.plannedCost, t.estimatedHours),
          ('rate', 500.0, 10000.0, 20.0),
        );
        final old = ITTask.fromJson({
          '_id': 't2',
          'projectId': 'p1',
          'title': 'Old',
        });
        expect(
          (old.costMode, old.costAmount, old.costRate, old.plannedCost),
          ('', 0.0, 0.0, 0.0),
        );
        // an echo of a task must never carry — or clear — a cost
        final json = t.toJson();
        for (final k in ['costMode', 'costAmount', 'costRate', 'plannedCost']) {
          expect(json.containsKey(k), isFalse, reason: k);
        }
        // and copying a task keeps its cost
        final c = t.copyWith(title: 'Renamed');
        expect(
          (c.costMode, c.costRate, c.plannedCost),
          ('rate', 500.0, 10000.0),
        );
        expect(t.copyWith(plannedCost: 5).plannedCost, 5);
      },
    );

    test(
      'the project says where the tasks stand against the budget; a project without it has none',
      () {
        final p = _project(
          taskPlan: _plan(
            planned: 117200,
            level: 'over',
            over: 17200,
            awaiting: true,
          ),
        );
        final plan = p.cost!.taskPlan!;
        expect(
          (plan.planned, plan.ceiling, plan.level, plan.over, plan.awaiting),
          (117200.0, 100000.0, 'over', 17200.0, true),
        );
        expect((plan.leaves, plan.priced, plan.unpriced), (5, 4, 1));
        expect(plan.byDepartment.single.name, 'Marketing');
        expect(plan.usedFraction, closeTo(1.172, 1e-9));
        expect(plan.hasTasks, isTrue);
        expect(_project().cost!.taskPlan, isNull);
        expect(const TaskPlan().usedFraction, isNull);
        expect(const TaskPlan().hasTasks, isFalse);
      },
    );

    test('Finance\'s row carries the plan behind the request', () {
      final r = PendingProjectCost.fromJson({
        'id': 'a',
        'name': 'A',
        'taskPlanned': 117200,
        'taskCount': 6,
        'taskUnpriced': 2,
      });
      expect((r.taskPlanned, r.taskCount, r.taskUnpriced), (117200.0, 6, 2));
      final old = PendingProjectCost.fromJson({'id': 'b', 'name': 'B'});
      expect((old.taskPlanned, old.taskCount, old.taskUnpriced), (0.0, 0, 0));
    });

    test('a save result says whether a budget increase went out', () {
      expect(
        TaskSaveResult.fromResponse({
          '_id': 't',
          'costRequest': {'sent': true, 'amount': 120000, 'status': 'pending'},
        }).costRequestSent,
        isTrue,
      );
      expect(
        TaskSaveResult.fromResponse({
          'costRequest': {'sent': true, 'amount': 120000},
        }).costRequestAmount,
        120000,
      );
      for (final none in [
        null,
        'x',
        <String, dynamic>{},
        {'costRequest': null},
        {
          'costRequest': {'sent': false},
        },
      ]) {
        expect(
          TaskSaveResult.fromResponse(none).costRequestSent,
          isFalse,
          reason: '$none',
        );
      }
    });

    test(
      'the cost boxes become the request\'s cost keys, and say what they work out to',
      () {
        expect(const TaskCostInput().toBody(), {
          'costMode': '',
          'costAmount': 0,
          'costRate': 0,
        });
        expect(
          const TaskCostInput(mode: 'amount', amount: 12500, rate: 99).toBody(),
          {'costMode': 'amount', 'costAmount': 12500, 'costRate': 0},
        );
        expect(
          const TaskCostInput(mode: 'rate', amount: 7, rate: 500).toBody(),
          {'costMode': 'rate', 'costAmount': 0, 'costRate': 500},
        );
        expect(
          const TaskCostInput(mode: 'amount', amount: 12500).planned(40),
          12500,
        );
        expect(const TaskCostInput(mode: 'rate', rate: 500).planned(20), 10000);
        expect(
          const TaskCostInput(mode: 'rate', rate: 333.33).planned(3),
          999.99,
        );
        expect(const TaskCostInput(mode: 'rate', rate: 500).planned(-4), 0);
        expect(const TaskCostInput().planned(10), isNull);
      },
    );

    test('hours × rate as typed', () {
      expect(hoursTimesRate('20', '500'), 10000);
      expect(hoursTimesRate('12.5', '1,000'), 12500);
      for (final bad in [
        ('', '500'),
        ('20', ''),
        ('x', '500'),
        ('20', 'y'),
        ('-3', '500'),
      ]) {
        expect(hoursTimesRate(bad.$1, bad.$2), isNull, reason: '$bad');
      }
    });

    test(
      'the plan is counted by leaf tasks; a phase shows the total of what is under it',
      () {
        final tasks = [
          _t('p1', cost: 999), // a phase: its own number is ignored
          _t('a', parent: 'p1', cost: 1000),
          _t('b', parent: 'p1', cost: 2500.5),
          _t('p2'),
          _t('c', parent: 'p2', cost: 400),
          _t('solo', cost: 50),
        ];
        final r = rolledTaskCosts(tasks);
        expect(r['p1'], 3500.5);
        expect(r['p2'], 400);
        expect(r['a'], 1000);
        expect(r['solo'], 50);
        expect(r.values.fold<double>(0, (s, v) => s) >= 0, isTrue);
      },
    );

    test(
      'through every level, to the paisa; an orphan is a leaf; a loop in bad data does not hang',
      () {
        final deep = rolledTaskCosts([
          _t('p'),
          _t('q', parent: 'p'),
          _t('x', parent: 'q', cost: 100.1),
          _t('y', parent: 'q', cost: 250.2),
          _t('z', parent: 'p', cost: 40),
        ]);
        expect(deep['q'], closeTo(350.3, 1e-9));
        expect(deep['p'], closeTo(390.3, 1e-9));
        expect(rolledTaskCosts([_t('a', parent: 'gone', cost: 10)])['a'], 10);
        expect(
          rolledTaskCosts([
            _t('a', parent: 'b', cost: 10),
            _t('b', parent: 'a', cost: 20),
          ]),
          isA<Map<String, double>>(),
        );
        expect(rolledTaskCosts(const []), isEmpty);
      },
    );

    test('an hours-based task says how it was worked out', () {
      expect(
        costBasisText(_t('a', mode: 'rate', hours: 20, rate: 500)),
        '20 h × ₹500',
      );
      expect(
        costBasisText(_t('a', mode: 'rate', hours: 12.5, rate: 750)),
        '12.5 h × ₹750',
      );
      expect(costBasisText(_t('a', mode: 'amount', amount: 500)), '');
      expect(costBasisText(_t('a')), '');
    });
  });

  group('the server\'s refusal', () {
    test(
      'is read from the error, with the numbers when the person may see them',
      () {
        final o = OverBudget.tryParse(_overBudget())!;
        expect(
          (o.planned, o.ceiling, o.over, o.canRequest, o.hasAmounts),
          (117200.0, 100000.0, 17200.0, true, true),
        );
        expect(o.message, contains('₹1,17,200'));
        expect(
          OverBudget.tryParse(_overBudget(canRequest: false))!.canRequest,
          isFalse,
        );
      },
    );

    test('carries no amounts for someone who may not see them', () {
      final o = OverBudget.tryParse(_overBudget(seer: false))!;
      expect(
        (o.planned, o.ceiling, o.over, o.hasAmounts, o.canRequest),
        (null, null, null, false, false),
      );
    });

    test(
      'is found inside the Dio error too, and nothing else is mistaken for it',
      () {
        final bare = (_overBudget().cause as DioException);
        expect(OverBudget.tryParse(bare), isNotNull);
        for (final other in [
          null,
          'x',
          Exception('boom'),
          AppException(
            DioException(
              requestOptions: RequestOptions(path: '/x'),
              response: Response(
                requestOptions: RequestOptions(path: '/x'),
                statusCode: 409,
                data: {'code': 'FLEET_CONFLICT'},
              ),
            ),
          ),
          AppException(
            DioException(
              requestOptions: RequestOptions(path: '/x'),
              response: Response(
                requestOptions: RequestOptions(path: '/x'),
                statusCode: 500,
                data: {'code': 'TASK_COST_OVER_BUDGET'},
              ),
            ),
          ),
          AppException(
            DioException(requestOptions: RequestOptions(path: '/x')),
          ),
        ]) {
          expect(OverBudget.tryParse(other), isNull, reason: '$other');
        }
      },
    );
  });

  // ── the task editor ───────────────────────────────────────────────────────
  group('the task editor', () {
    late _FakeTasks tasks;
    setUp(() => tasks = _FakeTasks());

    Future<void> open(
      WidgetTester t,
      Project project, {
      ITTask? existing,
      List<ITTask>? all,
    }) async {
      t.view.physicalSize = const Size(900, 2200);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(
        ProviderScope(
          retry: (_, _) => null,
          overrides: <Override>[
            authSessionProvider.overrideWithValue(_session()),
            projectByIdProvider('p1').overrideWithValue(project),
            projectEmployeesProvider(
              'p1',
            ).overrideWithValue(const <Employee>[]),
            itTaskServiceProvider.overrideWithValue(tasks),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) => TextButton(
                  onPressed: () => showTaskEditor(
                    context,
                    ref,
                    'p1',
                    existing: existing,
                    allTasks: all ?? (existing == null ? const [] : [existing]),
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

    Future<void> create(WidgetTester t, {String title = 'Vendor build'}) async {
      await _type(t, find.widgetWithText(TextField, 'Title *'), title);
      await _tap(t, _submit('Create'));
    }

    testWidgets(
      'the person who runs the project sets a cost: none, an amount, or hours × a rate',
      (t) async {
        await open(t, _project());
        expect(_k('task_cost_fields'), findsOneWidget);
        for (final m in ['none', 'amount', 'rate']) {
          expect(_k('task_cost_mode_$m'), findsOneWidget, reason: m);
        }
        expect(
          _k('task_cost_amount'),
          findsNothing,
          reason: 'no cost to type until one is chosen',
        );
      },
    );

    testWidgets('an amount is sent as typed, commas and all', (t) async {
      await open(t, _project());
      await _tap(t, _k('task_cost_mode_amount'));
      await _type(t, _k('task_cost_amount'), '12,500');
      expect(
        t.widget<Text>(_k('task_cost_preview')).data,
        'Planned cost: ₹12,500',
      );
      await create(t);
      final b = tasks.created.single;
      expect(
        (b['costMode'], b['costAmount'], b['costRate']),
        ('amount', 12500.0, 0),
      );
    });

    testWidgets('hours × a rate follows the hours as they are typed', (
      t,
    ) async {
      await open(t, _project());
      await _tap(t, _k('task_cost_mode_rate'));
      await _type(t, _k('task_cost_rate'), '500');
      expect(find.textContaining('Enter the estimated hours'), findsOneWidget);
      await _type(t, find.widgetWithText(TextField, 'Est. hours'), '20');
      expect(
        t.widget<Text>(_k('task_cost_preview')).data,
        'Planned cost: ₹10,000',
      );
      await _type(t, find.widgetWithText(TextField, 'Est. hours'), '30');
      expect(
        t.widget<Text>(_k('task_cost_preview')).data,
        'Planned cost: ₹15,000',
      );
      await create(t);
      final b = tasks.created.single;
      expect(
        (b['costMode'], b['costAmount'], b['costRate'], b['estimatedHours']),
        ('rate', 0, 500.0, 30.0),
      );
    });

    testWidgets('a task with no cost says so, never a made-up one', (t) async {
      await open(t, _project());
      await create(t);
      final b = tasks.created.single;
      expect((b['costMode'], b['costAmount'], b['costRate']), ('', 0, 0));
    });

    testWidgets('an existing task starts from what it has', (t) async {
      await open(
        t,
        _project(),
        existing: _t('t1', mode: 'rate', hours: 20, rate: 500, cost: 10000),
      );
      expect(t.widget<ChoiceChip>(_k('task_cost_mode_rate')).selected, isTrue);
      expect(t.widget<TextField>(_k('task_cost_rate')).controller!.text, '500');
      await _tap(t, _submit('Save'));
      final b = tasks.updated.single;
      expect((b['costMode'], b['costRate']), ('rate', 500.0));
    });

    testWidgets('something typed that is not an amount stops the save', (
      t,
    ) async {
      await open(t, _project());
      await _tap(t, _k('task_cost_mode_amount'));
      await _type(t, _k('task_cost_amount'), '1.2.3');
      await create(t);
      expect(find.text('The cost has to be an amount'), findsOneWidget);
      expect(tasks.created, isEmpty);
    });

    testWidgets(
      'someone who may not set costs sees no cost boxes and sends no cost keys',
      (t) async {
        await open(
          t,
          _project(access: _access(canEditCost: false, canSeeCost: false)),
        );
        expect(_k('task_cost_fields'), findsNothing);
        await create(t);
        final b = tasks.created.single;
        for (final k in [
          'costMode',
          'costAmount',
          'costRate',
          'plannedCost',
          'budgetIncrease',
        ]) {
          expect(b.containsKey(k), isFalse, reason: k);
        }
      },
    );

    testWidgets(
      'someone who may see costs but not set them (Finance) gets no cost boxes either',
      (t) async {
        await open(t, _project(access: _access(canEditCost: false)));
        expect(_k('task_cost_fields'), findsNothing);
      },
    );

    testWidgets(
      'the person a task is given to updates progress only: no cost boxes, no cost keys',
      (t) async {
        await open(
          t,
          _project(
            access: _access(
              canEditCost: false,
              canSeeCost: false,
              manage: false,
            ),
          ),
          existing: _t('t1', assignee: 'e1'),
        );
        expect(_k('task_cost_fields'), findsNothing);
        await _tap(t, _submit('Save'));
        expect(tasks.updated.single.keys.toSet(), {
          'status',
          'percentComplete',
        });
      },
    );

    testWidgets(
      'a task that has sub-tasks has no cost of its own: it shows their total, and sends no cost keys',
      (t) async {
        final phase = _t('p');
        final all = [
          phase,
          _t('a', parent: 'p', cost: 1000),
          _t('b', parent: 'p', cost: 2500),
        ];
        await open(t, _project(), existing: phase, all: all);
        expect(_k('task_cost_phase'), findsOneWidget);
        expect(find.textContaining('₹3,500'), findsOneWidget);
        expect(_k('task_cost_fields'), findsNothing);
        await _tap(t, _submit('Save'));
        for (final k in ['costMode', 'costAmount', 'costRate']) {
          expect(tasks.updated.single.containsKey(k), isFalse, reason: k);
        }
      },
    );

    testWidgets(
      'says what the change does to the plan, and warns when it would go over',
      (t) async {
        await open(
          t,
          _project(taskPlan: _plan(planned: 90000, ceiling: 100000)),
        );
        await _tap(t, _k('task_cost_mode_amount'));
        await _type(t, _k('task_cost_amount'), '5,000');
        expect(
          t.widget<Text>(_k('task_cost_plan_effect')).data,
          'With this the tasks add up to ₹95,000 of the ₹1,00,000 approved.',
        );
        await _type(t, _k('task_cost_amount'), '20,000');
        final over = t.widget<Text>(_k('task_cost_plan_effect')).data!;
        expect(over, contains('₹1,10,000'));
        expect(over, contains('₹10,000 above'));
        expect(over, contains('A budget increase will be asked'));
      },
    );

    testWidgets(
      'taking cost out of a plan that is already over the budget is not warned about as an increase',
      (t) async {
        await open(
          t,
          _project(
            taskPlan: _plan(planned: 117200, level: 'over', over: 17200),
          ),
          existing: _t('t1', mode: 'amount', amount: 30000, cost: 30000),
        );
        await _type(t, _k('task_cost_amount'), '25,000');
        final line = t.widget<Text>(_k('task_cost_plan_effect')).data!;
        expect(
          line,
          'With this the tasks add up to ₹1,12,200 of the ₹1,00,000 approved.',
        );
        expect(line, isNot(contains('budget increase')));
        // and adding to it is warned about
        await _type(t, _k('task_cost_amount'), '35,000');
        expect(
          t.widget<Text>(_k('task_cost_plan_effect')).data,
          contains('A budget increase will be asked'),
        );
      },
    );

    testWidgets(
      'editing a task counts its own cost out of the plan before adding the new one',
      (t) async {
        await open(
          t,
          _project(taskPlan: _plan(planned: 90000, ceiling: 100000)),
          existing: _t('t1', mode: 'amount', amount: 30000, cost: 30000),
        );
        await _type(t, _k('task_cost_amount'), '35,000');
        expect(
          t.widget<Text>(_k('task_cost_plan_effect')).data,
          'With this the tasks add up to ₹95,000 of the ₹1,00,000 approved.',
        );
      },
    );

    testWidgets(
      'over the budget: the manager is asked for the reason and the new budget, and the SAME task is sent again with it',
      (t) async {
        tasks.failures.add(_overBudget());
        tasks.result = const TaskSaveResult(
          costRequestSent: true,
          costRequestAmount: 120000,
        );
        await open(t, _project());
        await _tap(t, _k('task_cost_mode_amount'));
        await _type(t, _k('task_cost_amount'), '70,000');
        await create(t);

        expect(_k('over_budget_dialog'), findsOneWidget);
        expect(
          t.widget<Text>(_k('over_budget_message')).data,
          contains('₹17,200 above'),
        );
        expect(
          t.widget<TextField>(_k('over_budget_amount')).controller!.text,
          '117200',
          reason: 'what the tasks add up to',
        );
        expect(
          tasks.created,
          hasLength(1),
          reason: 'nothing sent again until the person says so',
        );

        await _type(t, _k('over_budget_amount'), '1,20,000');
        await _type(
          t,
          _k('over_budget_reason'),
          'Vendor build was not in the first estimate',
        );
        await _tap(t, _k('over_budget_send'));

        expect(tasks.created, hasLength(2));
        expect(tasks.created.last['title'], 'Vendor build');
        expect(tasks.created.last['costAmount'], 70000.0);
        expect(tasks.created.last['budgetIncrease'], {
          'reason': 'Vendor build was not in the first estimate',
          'amount': 120000.0,
        });
        expect(
          tasks.created.first.containsKey('budgetIncrease'),
          isFalse,
          reason: 'the first try asked for nothing',
        );
        expect(
          find.textContaining(
            'A budget of ₹1,20,000 was sent to the finance head',
          ),
          findsOneWidget,
        );
        expect(find.text('New Task'), findsNothing, reason: 'the form closed');
      },
    );

    testWidgets(
      'the ask is checked before it is sent: an amount that does not cover the tasks, and a missing reason',
      (t) async {
        tasks.failures.add(_overBudget());
        await open(t, _project());
        await create(t);
        await _type(t, _k('over_budget_amount'), '1,00,000');
        await _type(t, _k('over_budget_reason'), 'More work');
        await _tap(t, _k('over_budget_send'));
        expect(
          t.widget<Text>(_k('over_budget_error')).data,
          contains('at least ₹1,17,200'),
        );
        await _type(t, _k('over_budget_amount'), '1,20,000');
        await _type(t, _k('over_budget_reason'), '  ');
        await _tap(t, _k('over_budget_send'));
        expect(
          t.widget<Text>(_k('over_budget_error')).data,
          'Say why more is needed.',
        );
        await _type(t, _k('over_budget_amount'), '');
        await _tap(t, _k('over_budget_send'));
        expect(
          t.widget<Text>(_k('over_budget_error')).data,
          'Enter the new budget as an amount.',
        );
        expect(tasks.created, hasLength(1), reason: 'still only the first try');
      },
    );

    testWidgets(
      'backing out of the ask sends nothing more and leaves the form open',
      (t) async {
        tasks.failures.add(_overBudget());
        await open(t, _project());
        await create(t);
        await _tap(t, _k('over_budget_cancel'));
        expect(_k('over_budget_dialog'), findsNothing);
        expect(tasks.created, hasLength(1));
        expect(
          find.text('New Task'),
          findsOneWidget,
          reason: 'the form is still there to change',
        );
        expect(
          find.text('Saving…'),
          findsNothing,
          reason: 'and can be saved again',
        );
      },
    );

    testWidgets(
      'someone who cannot ask for an increase is told, with no form to fill in',
      (t) async {
        tasks.failures.add(
          _overBudget(
            canRequest: false,
            message:
                'With this the tasks add up to ₹1,17,200. Ask the project manager to raise the budget.',
          ),
        );
        await open(t, _project());
        await create(t);
        expect(_k('over_budget_notice'), findsOneWidget);
        expect(_k('over_budget_amount'), findsNothing);
        expect(find.textContaining('Ask the project manager'), findsOneWidget);
        await _tap(t, _k('over_budget_ok'));
        expect(tasks.created, hasLength(1));
        expect(find.text('New Task'), findsOneWidget);
      },
    );

    testWidgets('someone who may not see the amounts is told without any', (
      t,
    ) async {
      tasks.failures.add(_overBudget(seer: false));
      await open(
        t,
        _project(access: _access(canEditCost: false, canSeeCost: false)),
      );
      await create(t);
      final msg = t.widget<Text>(_k('over_budget_message')).data!;
      expect(msg, contains('Ask the project manager'));
      expect(RegExp(r'₹|\d{4}').hasMatch(msg), isFalse, reason: msg);
    });

    testWidgets(
      'any other failure is still shown as an ordinary error, and the form stays',
      (t) async {
        tasks.failures.add(
          AppException(
            DioException(
              requestOptions: RequestOptions(path: '/it-tasks'),
              type: DioExceptionType.connectionError,
            ),
            action: 'create the task',
          ),
        );
        await open(t, _project());
        await create(t);
        expect(_k('over_budget_dialog'), findsNothing);
        expect(find.text('New Task'), findsOneWidget);
        expect(find.byType(SnackBar), findsOneWidget);
      },
    );
  });

  // ── the WBS ───────────────────────────────────────────────────────────────
  group('the WBS Cost column', () {
    Future<void> showWbs(
      WidgetTester t,
      List<ITTask> list,
      Project project,
    ) async {
      t.view.physicalSize = const Size(1700, 1100);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(const SizedBox.shrink());
      await t.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            authSessionProvider.overrideWithValue(_session()),
            projectsProvider.overrideWith((ref) async => [project]),
            projectEmployeesProvider(
              'p1',
            ).overrideWith((ref) => const <Employee>[]),
            itTaskRepositoryProvider.overrideWithValue(_Repo(list)),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: ITWbsView(projectId: 'p1', tasks: list),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
    }

    final list = [
      _t('ph', cost: 0),
      _t('a', parent: 'ph', mode: 'amount', amount: 30000, cost: 30000),
      _t('b', parent: 'ph', mode: 'rate', hours: 20, rate: 500, cost: 10000),
      _t('c', parent: 'ph'),
      _t('ph2'),
    ];

    testWidgets(
      'shows each task\'s planned cost, a phase the total of its tasks, and a dash where there is none',
      (t) async {
        await showWbs(t, list, _project());
        expect(_k('wbs_cost_header'), findsOneWidget);
        expect(t.widget<Text>(_k('wbs_cost_ph')).data, '₹40,000');
        expect(t.widget<Text>(_k('wbs_cost_a')).data, '₹30,000');
        expect(t.widget<Text>(_k('wbs_cost_b')).data, '₹10,000');
        expect(t.widget<Text>(_k('wbs_cost_c')).data, '—');
        expect(t.widget<Text>(_k('wbs_cost_ph2')).data, '—');
      },
    );

    testWidgets('an hours-based cost says how it was worked out', (t) async {
      await showWbs(t, list, _project());
      expect(find.byTooltip('20 h × ₹500'), findsOneWidget);
      expect(
        find.byTooltip('20 h × ₹500').evaluate().length,
        1,
        reason: 'only the hours-based task has one',
      );
    });

    testWidgets(
      'is not there for someone who may not see what the project costs',
      (t) async {
        await showWbs(
          t,
          list,
          _project(access: _access(canEditCost: false, canSeeCost: false)),
        );
        expect(_k('wbs_cost_header'), findsNothing);
        expect(_k('wbs_cost_a'), findsNothing);
        expect(
          find.text('Task a'),
          findsOneWidget,
          reason: 'the rest of the table is unchanged',
        );
      },
    );
  });

  // ── the cost card ─────────────────────────────────────────────────────────
  group('planned by tasks on the cost card', () {
    Future<void> showCard(
      WidgetTester t,
      Project p, {
      Size size = const Size(900, 1600),
    }) async {
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(
        ProviderScope(
          retry: (_, _) => null,
          overrides: <Override>[
            projectServiceProvider.overrideWithValue(_Projects()),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: SingleChildScrollView(child: ProjectCostCard(project: p)),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
    }

    testWidgets(
      'shows what the tasks add up to, the share of the budget, and how many have no cost yet',
      (t) async {
        await showCard(
          t,
          _project(taskPlan: _plan(planned: 90000, ceiling: 100000)),
        );
        expect(_k('task_plan_block'), findsOneWidget);
        expect(t.widget<Text>(_k('task_plan_planned')).data, '₹90,000');
        expect(t.widget<Text>(_k('task_plan_level')).data, '90% of the budget');
        expect(find.text('of ₹1,00,000 approved'), findsOneWidget);
        expect(
          t.widget<Text>(_k('task_plan_unpriced')).data,
          '1 of 5 tasks have no cost yet — the plan will grow.',
        );
        expect(_k('task_plan_over'), findsNothing);
      },
    );

    testWidgets('says plainly when the plan is over the budget', (t) async {
      await showCard(
        t,
        _project(taskPlan: _plan(planned: 117200, level: 'over', over: 17200)),
      );
      expect(t.widget<Text>(_k('task_plan_level')).data, 'Over budget');
      expect(
        t.widget<Text>(_k('task_plan_over')).data,
        contains('₹17,200 above the budget'),
      );
    });

    testWidgets(
      'while an increase waits, the plan is held against what is asked for, and says so',
      (t) async {
        await showCard(
          t,
          _project(
            taskPlan: _plan(planned: 117200, ceiling: 120000, awaiting: true),
          ),
        );
        expect(
          find.text('of ₹1,20,000 asked for (waiting for the finance head)'),
          findsOneWidget,
        );
        expect(
          t.widget<Text>(_k('task_plan_level')).data,
          '98% of the request',
        );
      },
    );

    testWidgets(
      'a project whose tasks have no cost at all is told so, with no bar',
      (t) async {
        await showCard(
          t,
          _project(
            taskPlan: _plan(
              planned: 0,
              ceiling: 100000,
              level: 'ok',
              leaves: 3,
              priced: 0,
            ),
          ),
        );
        expect(t.widget<Text>(_k('task_plan_planned')).data, '₹0');
        expect(
          t.widget<Text>(_k('task_plan_unpriced')).data,
          '3 of 3 tasks have no cost yet.',
        );
      },
    );

    testWidgets(
      'a project with no ceiling yet shows the plan without a bar or a share',
      (t) async {
        await showCard(
          t,
          _project(taskPlan: _plan(planned: 40000, ceiling: 0, level: 'none')),
        );
        expect(t.widget<Text>(_k('task_plan_planned')).data, '₹40,000');
        expect(_k('task_plan_bar'), findsNothing);
        expect(_k('task_plan_level'), findsNothing);
      },
    );

    testWidgets(
      'a project with no tasks, or no figure from the server, shows no block',
      (t) async {
        await showCard(
          t,
          _project(taskPlan: _plan(planned: 0, leaves: 0, priced: 0)),
        );
        expect(_k('task_plan_block'), findsNothing);
        await showCard(t, _project());
        expect(_k('task_plan_block'), findsNothing);
      },
    );

    testWidgets('someone who may not see the cost sees no plan', (t) async {
      await showCard(
        t,
        _project(
          access: _access(canEditCost: false, canSeeCost: false),
          cost: null,
        ),
      );
      expect(_k('task_plan_block'), findsNothing);
    });

    testWidgets('fits a phone', (t) async {
      await showCard(
        t,
        _project(
          taskPlan: _plan(
            planned: 117200,
            level: 'over',
            over: 17200,
            leaves: 12,
            priced: 3,
          ),
        ),
        size: const Size(360, 1600),
      );
      expect(t.takeException(), isNull);
      expect(_k('task_plan_block'), findsOneWidget);
    });
  });

  // ── Finance ───────────────────────────────────────────────────────────────
  group('Finance sees the plan behind a request', () {
    PendingProjectCost row(
      String id, {
      double planned = 117200,
      int count = 6,
      int unpriced = 2,
    }) => PendingProjectCost(
      id: id,
      name: 'Project $id',
      budget: 120000,
      approvedBudget: 100000,
      isChange: true,
      canDecide: true,
      taskPlanned: planned,
      taskCount: count,
      taskUnpriced: unpriced,
    );

    Future<void> showList(WidgetTester t, List<PendingProjectCost> rows) async {
      t.view.physicalSize = const Size(900, 1600);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final svc = _Projects()..pending = rows;
      await t.pumpWidget(
        ProviderScope(
          retry: (_, _) => null,
          overrides: <Override>[projectServiceProvider.overrideWithValue(svc)],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const Scaffold(body: ProjectBudgetsScreen()),
          ),
        ),
      );
      await t.pumpAndSettle();
    }

    testWidgets(
      'the row says what the tasks add up to and how many have no cost yet',
      (t) async {
        await showList(t, [row('a')]);
        expect(
          t.widget<Text>(_k('pb_task_plan_a')).data,
          'The tasks add up to ₹1,17,200 · 2 of 6 tasks have no cost yet',
        );
      },
    );

    testWidgets(
      'without the unpriced part when every task has a cost, and not at all for a project with no tasks',
      (t) async {
        await showList(t, [
          row('a', unpriced: 0),
          row('b', count: 0, planned: 0, unpriced: 0),
        ]);
        expect(
          t.widget<Text>(_k('pb_task_plan_a')).data,
          'The tasks add up to ₹1,17,200',
        );
        expect(_k('pb_task_plan_b'), findsNothing);
      },
    );

    testWidgets(
      'the decision dialog repeats it, so the head decides with the plan in front of them',
      (t) async {
        await showList(t, [row('a')]);
        await _tap(t, _k('pb_decide_a'));
        expect(
          t.widget<Text>(_k('cost_dialog_task_plan')).data,
          'The tasks add up to ₹1,17,200 (2 still have no cost).',
        );
      },
    );

    testWidgets('and leaves it out when there are no tasks to speak of', (
      t,
    ) async {
      await showList(t, [row('a', count: 0, planned: 0, unpriced: 0)]);
      await _tap(t, _k('pb_decide_a'));
      expect(_k('cost_dialog_task_plan'), findsNothing);
    });
  });
}

/// A repository that only holds the tasks it is given (the WBS page shows the list it is handed).
class _Repo implements IITTaskRepository {
  _Repo(this.tasks);
  final List<ITTask> tasks;

  @override
  Future<List<ITTask>> getTasks({
    String? projectId,
    String? status,
    String? assignedTo,
    String? ticketType,
    String? severity,
    String? subTeam,
    String? search,
    bool mine = false,
  }) async => tasks;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}
