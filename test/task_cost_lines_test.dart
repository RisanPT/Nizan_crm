import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:nizan_crm/core/theme/app_theme.dart';
import 'package:nizan_crm/features/it/data/it_task.dart';
import 'package:nizan_crm/features/it/data/project.dart';
import 'package:nizan_crm/features/it/domain/task_cost.dart';
import 'package:nizan_crm/features/it/presentation/screens/project_budgets_screen.dart';
import 'package:nizan_crm/features/it/presentation/screens/widgets/project_cost_widgets.dart';
import 'package:nizan_crm/features/it/presentation/screens/widgets/task_cost_widgets.dart';
import 'package:nizan_crm/features/it/services/it_service.dart';

// The tasks BEHIND a project's budget: the cost card lists what each task is planned to cost (and which have none, to be opened and
// priced), the finance head sees the same list before deciding — with a warning when they would approve less than the tasks add up
// to — and a first request that is still waiting is called "asked for", never "approved".

// ── builders ────────────────────────────────────────────────────────────────
Map<String, dynamic> _access({bool canEditCost = true}) => {
  'role': 'manager',
  'canManage': true,
  'editMode': 'managed',
  'canCreateTasks': true,
  'canEditAllTasks': true,
  'leadDepartments': <String>[],
  'pendingInvitations': <String>[],
  'canDecide': false,
  'canSeeCost': true,
  'canEditCost': canEditCost,
  'canDecideCost': false,
};

Map<String, dynamic> _plan({
  double planned = 0,
  double ceiling = 100000,
  int leaves = 2,
  int priced = 0,
  bool awaiting = false,
}) => {
  'planned': planned,
  'ceiling': ceiling,
  'level': planned == 0 ? 'ok' : 'warn',
  'over': 0,
  'leaves': leaves,
  'priced': priced,
  'unpriced': leaves - priced,
  'byDepartment': <Map<String, dynamic>>[],
  'awaiting': awaiting,
};

Project _project({
  String costStatus = 'approved',
  bool canEditCost = true,
  Map<String, dynamic>? taskPlan,
}) => Project.fromJson({
  '_id': 'p1',
  'name': 'WedEasy',
  'status': 'planning',
  'targetDepartment': 'Marketing',
  'managerId': {'_id': 'm1', 'name': 'Mira'},
  'editMode': 'managed',
  'departments': [
    {'name': 'Marketing', 'role': 'owner', 'status': 'accepted'},
  ],
  'costStatus': costStatus,
  'cost': {
    'budget': 100000,
    'approvedBudget': costStatus == 'approved' ? 100000 : 0,
    'taskPlan': ?taskPlan,
  },
  'access': _access(canEditCost: canEditCost),
});

ITTask _t(
  String id,
  String title, {
  String? parent,
  double cost = 0,
  String dept = '',
}) => ITTask(
  id: id,
  projectId: 'p1',
  title: title,
  parentTaskId: parent,
  plannedCost: cost,
  departmentName: dept,
);

class _Projects extends ProjectService {
  _Projects() : super(Dio());
  List<PendingProjectCost> pending = [];
  final decided = <({String id, bool approve, double? amount, String note})>[];

  @override
  Future<List<PendingProjectCost>> pendingCosts() async => pending;

  @override
  Future<Project> decideCost(
    String id, {
    required bool approve,
    double? approvedAmount,
    String note = '',
  }) async {
    decided.add((id: id, approve: approve, amount: approvedAmount, note: note));
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

Finder _k(String key) => find.byKey(Key(key));

Future<void> _tap(WidgetTester t, Finder f) async {
  await t.ensureVisible(f);
  await t.pumpAndSettle();
  await t.tap(f);
  await t.pumpAndSettle();
}

Future<void> _pumpApp(WidgetTester t, Widget home, _Projects svc) async {
  t.view.physicalSize = const Size(900, 1800);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: <Override>[projectServiceProvider.overrideWithValue(svc)],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(body: home),
      ),
    ),
  );
  await t.pumpAndSettle();
}

void main() {
  group('the lines the app builds from the tasks', () {
    test(
      'one line for each leaf; a phase is its tasks\' total, not a line',
      () {
        final lines = taskCostLinesOf([
          _t('ph', 'Design'),
          _t('a', 'Wireframes', parent: 'ph', cost: 30000, dept: 'Design team'),
          _t('b', 'Mockups', parent: 'ph'),
          _t('solo', 'Kick-off', cost: 500),
        ], ownerDepartment: 'Marketing');
        expect(
          [for (final l in lines) (l.id, l.phase, l.department, l.planned)],
          [
            ('a', 'Design', 'Design team', 30000.0),
            ('solo', '', 'Marketing', 500.0),
            ('b', 'Design', 'Marketing', 0.0),
          ],
        );
      },
    );

    test('the biggest cost first, then those with none in the order given', () {
      final lines = taskCostLinesOf([
        _t('1', 'none-1'),
        _t('2', 'small', cost: 10),
        _t('3', 'none-2'),
        _t('4', 'big', cost: 900),
        _t('5', 'mid', cost: 100),
      ]);
      expect(
        [for (final l in lines) l.title],
        ['big', 'mid', 'small', 'none-1', 'none-2'],
      );
    });

    test('a phase is the top of the chain, however deep the task is', () {
      final lines = taskCostLinesOf([
        _t('p', 'Phase'),
        _t('t', 'Task', parent: 'p'),
        _t('s', 'Step', parent: 't', cost: 70),
      ]);
      expect([for (final l in lines) (l.title, l.phase)], [('Step', 'Phase')]);
      expect(taskCostLinesOf(const []), isEmpty);
    });

    test(
      'a request on the finance list carries its lines and how many were left off',
      () {
        final r = PendingProjectCost.fromJson({
          'id': 'p1',
          'name': 'WedEasy',
          'taskLines': [
            {
              'id': 'a',
              'title': 'Vendor build',
              'department': 'IT',
              'phase': 'Build',
              'planned': 70000,
            },
            {'id': 'b', 'title': 'Mockups', 'planned': 0},
          ],
          'taskLinesMore': 3,
        });
        expect(r.taskLines.length, 2);
        expect(
          (r.taskLines[0].title, r.taskLines[0].phase, r.taskLines[0].planned),
          ('Vendor build', 'Build', 70000.0),
        );
        expect(r.taskLines[1].hasCost, isFalse);
        expect(r.taskLinesMore, 3);
        // an older server sends none
        expect(
          PendingProjectCost.fromJson({'id': 'x', 'name': 'Old'}).taskLines,
          isEmpty,
        );
      },
    );
  });

  group('the list of task costs', () {
    List<TaskCostLine> lines(int n) => [
      for (var i = 0; i < n; i++)
        TaskCostLine(
          id: 't$i',
          title: 'Task $i',
          planned: i.isEven ? 1000.0 * (i + 1) : 0,
        ),
    ];

    testWidgets(
      'shows the first few, with the cost or "No cost yet", and opens the rest',
      (t) async {
        await _pumpApp(
          t,
          SingleChildScrollView(child: TaskCostList(lines: lines(8))),
          _Projects(),
        );
        expect(find.text('Task 0'), findsOneWidget);
        expect(t.widget<Text>(_k('task_cost_amount_t0')).data, '₹1,000');
        expect(t.widget<Text>(_k('task_cost_amount_t1')).data, 'No cost yet');
        expect(find.text('Task 4'), findsOneWidget);
        expect(find.text('Task 5'), findsNothing); // only five at first
        expect(find.text('Show all 8 tasks'), findsOneWidget);
        await _tap(t, _k('task_cost_show_all'));
        expect(find.text('Task 7'), findsOneWidget);
        expect(_k('task_cost_show_all'), findsNothing);
      },
    );

    testWidgets('says how many more the server left off', (t) async {
      await _pumpApp(
        t,
        SingleChildScrollView(
          child: TaskCostList(lines: lines(6), more: 4, initialShown: 2),
        ),
        _Projects(),
      );
      expect(find.text('Show all 10 tasks'), findsOneWidget);
      await _tap(t, _k('task_cost_show_all'));
      expect(t.widget<Text>(_k('task_cost_more')).data, '… and 4 more.');
    });

    testWidgets('a line is opened only when it can be priced', (t) async {
      final tapped = <String>[];
      await _pumpApp(
        t,
        SingleChildScrollView(
          child: Column(
            children: [
              TaskCostList(lines: lines(2), onTap: (l) => tapped.add(l.id)),
            ],
          ),
        ),
        _Projects(),
      );
      await _tap(t, _k('task_cost_line_t1'));
      expect(tapped, ['t1']);

      await _pumpApp(
        t,
        SingleChildScrollView(child: TaskCostList(lines: lines(2))),
        _Projects(),
      );
      expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
    });

    testWidgets('no lines, nothing on the screen', (t) async {
      await _pumpApp(t, const TaskCostList(lines: []), _Projects());
      expect(_k('task_cost_list'), findsNothing);
    });
  });

  group('on the project\'s cost card', () {
    final tasks = [
      _t('ph', 'Launch'),
      _t('a', 'Landing page', parent: 'ph'),
      _t('b', 'Invites', parent: 'ph'),
    ];

    testWidgets(
      'the tasks are listed, none with a cost yet, so there is something to open and price',
      (t) async {
        await _pumpApp(
          t,
          SingleChildScrollView(
            child: ProjectCostCard(
              project: _project(taskPlan: _plan()),
              tasks: tasks,
              onEditTask: (_) {},
            ),
          ),
          _Projects(),
        );
        expect(_k('task_plan_block'), findsOneWidget);
        expect(find.text('Landing page'), findsOneWidget);
        expect(find.text('Invites'), findsOneWidget);
        expect(find.text('No cost yet'), findsNWidgets(2));
        // the phase and the department sit under each line; the phase is not a line of its own
        expect(find.text('Launch · Marketing'), findsNWidgets(2));
        expect(_k('task_cost_line_ph'), findsNothing);
      },
    );

    testWidgets(
      'tapping a line opens that task for someone who may set costs',
      (t) async {
        final opened = <String>[];
        await _pumpApp(
          t,
          SingleChildScrollView(
            child: ProjectCostCard(
              project: _project(taskPlan: _plan()),
              tasks: tasks,
              onEditTask: (task) => opened.add(task.id),
            ),
          ),
          _Projects(),
        );
        await _tap(t, _k('task_cost_line_b'));
        expect(opened, ['b']);
      },
    );

    testWidgets('for someone who may not, the lines are only shown', (t) async {
      final opened = <String>[];
      await _pumpApp(
        t,
        SingleChildScrollView(
          child: ProjectCostCard(
            project: _project(canEditCost: false, taskPlan: _plan()),
            tasks: tasks,
            onEditTask: (task) => opened.add(task.id),
          ),
        ),
        _Projects(),
      );
      expect(find.text('Landing page'), findsOneWidget);
      await t.tap(_k('task_cost_line_b'), warnIfMissed: false);
      expect(opened, isEmpty);
      expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
    });

    testWidgets('a project with no tasks has no list', (t) async {
      await _pumpApp(
        t,
        SingleChildScrollView(
          child: ProjectCostCard(project: _project(taskPlan: _plan(leaves: 0))),
        ),
        _Projects(),
      );
      expect(_k('task_cost_list'), findsNothing);
    });

    testWidgets(
      'a first request that is still waiting is "asked for", not "approved"',
      (t) async {
        await _pumpApp(
          t,
          SingleChildScrollView(
            child: ProjectCostCard(
              project: _project(
                costStatus: 'pending',
                taskPlan: _plan(awaiting: true),
              ),
              tasks: tasks,
            ),
          ),
          _Projects(),
        );
        expect(
          find.text('of ₹1,00,000 asked for (waiting for the finance head)'),
          findsOneWidget,
        );
        expect(find.text('of ₹1,00,000 approved'), findsNothing);
      },
    );
  });

  group('the finance head decides with the tasks in front of them', () {
    PendingProjectCost row({
      List<TaskCostLine> lines = const [],
      double planned = 0,
      int count = 0,
      int unpriced = 0,
    }) => PendingProjectCost(
      id: 'a',
      name: 'WedEasy',
      department: 'Marketing',
      budget: 100000,
      canDecide: true,
      taskPlanned: planned,
      taskCount: count,
      taskUnpriced: unpriced,
      taskLines: lines,
    );

    final priced = [
      const TaskCostLine(
        id: 'x',
        title: 'Vendor build',
        planned: 70000,
        phase: 'Build',
      ),
      const TaskCostLine(id: 'y', title: 'Photography', planned: 50000),
    ];

    Future<_Projects> open(WidgetTester t, PendingProjectCost r) async {
      final svc = _Projects()..pending = [r];
      await _pumpApp(t, const ProjectBudgetsScreen(), svc);
      return svc;
    }

    testWidgets(
      'the request lists its tasks, and the dialog lists them again',
      (t) async {
        await open(t, row(lines: priced, planned: 120000, count: 2));
        expect(find.text('Vendor build'), findsOneWidget);
        expect(find.text('₹70,000'), findsOneWidget);
        await _tap(t, _k('pb_decide_a'));
        expect(
          find.text('Vendor build'),
          findsNWidgets(2),
        ); // behind the dialog, and in it
      },
    );

    testWidgets(
      'approving less than the tasks add up to is warned about, as it is typed',
      (t) async {
        await open(t, row(lines: priced, planned: 120000, count: 2));
        await _tap(t, _k('pb_decide_a'));
        // asked for ₹1,00,000 and the tasks add up to ₹1,20,000: the warning is there from the start
        expect(
          t.widget<Text>(_k('cost_dialog_under_plan')).data,
          'The tasks add up to ₹1,20,000 — more than the ₹1,00,000 you are approving. The plan would be over the budget.',
        );
        await t.enterText(_k('decide_amount'), '150000');
        await t.pump();
        expect(_k('cost_dialog_under_plan'), findsNothing);
        await t.enterText(_k('decide_amount'), '90000');
        await t.pump();
        expect(
          find.textContaining('more than the ₹90,000 you are approving'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'no warning when the tasks fit, and none when sending it back',
      (t) async {
        await open(t, row(lines: [priced.first], planned: 70000, count: 1));
        await _tap(t, _k('pb_decide_a'));
        expect(_k('cost_dialog_under_plan'), findsNothing);
        await t.enterText(_k('decide_amount'), '60000');
        await t.pump();
        expect(_k('cost_dialog_under_plan'), findsOneWidget);
        await _tap(t, find.text('Send back'));
        expect(
          _k('cost_dialog_under_plan'),
          findsNothing,
        ); // not approving anything
      },
    );

    testWidgets(
      'tasks with no cost at all: it says so, instead of showing a plan of nothing',
      (t) async {
        await open(
          t,
          row(
            lines: const [
              TaskCostLine(id: 'p', title: 'Landing page'),
              TaskCostLine(id: 'q', title: 'Invites'),
            ],
            count: 2,
            unpriced: 2,
          ),
        );
        await _tap(t, _k('pb_decide_a'));
        expect(
          t.widget<Text>(_k('cost_dialog_no_task_costs')).data,
          'None of the 2 tasks has a cost yet, so there is no task plan to check this against.',
        );
        expect(_k('cost_dialog_task_plan'), findsNothing);
        expect(_k('cost_dialog_under_plan'), findsNothing);
      },
    );

    testWidgets('a project with no tasks has nothing about them', (t) async {
      await open(t, row());
      await _tap(t, _k('pb_decide_a'));
      expect(_k('cost_dialog_no_task_costs'), findsNothing);
      expect(_k('cost_dialog_task_plan'), findsNothing);
    });

    testWidgets(
      'the decision still goes through: approve what was asked, with the plan shown',
      (t) async {
        final svc = await open(
          t,
          row(lines: [priced.first], planned: 70000, count: 1),
        );
        await _tap(t, _k('pb_decide_a'));
        await _tap(t, _k('decide_confirm'));
        expect(svc.decided.single.id, 'a');
        expect(svc.decided.single.approve, isTrue);
        expect(svc.decided.single.amount, 100000);
      },
    );
  });
}
