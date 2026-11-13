import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nizan_crm/core/models/auth_session.dart';
import 'package:nizan_crm/core/providers/auth_provider.dart';
import 'package:nizan_crm/core/theme/app_theme.dart';
import 'package:nizan_crm/features/it/data/it_task.dart';
import 'package:nizan_crm/features/it/data/project.dart';
import 'package:nizan_crm/features/it/domain/models/okr_model.dart';
import 'package:nizan_crm/features/it/presentation/screens/widgets/company_planning_dashboard.dart';
import 'package:nizan_crm/features/it/services/it_service.dart';
import 'package:nizan_crm/features/it/services/okr_service.dart';
import 'package:nizan_crm/features/notifications/controllers/notification_providers.dart';
import 'package:nizan_crm/features/notifications/data/app_notification.dart';
import 'package:nizan_crm/features/org/data/department.dart';
import 'package:nizan_crm/features/org/services/department_service.dart';

// Company Projects → Dashboard: the headline numbers, progress, insights, departments, timeline, my tasks and
// notifications for a chosen period. "Today" is fixed (Wed 11 Nov 2026) so nothing depends on the day this runs.

final _now = DateTime(2026, 11, 11, 10, 30);
String _iso(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

Project _p(
  String id, {
  required String status,
  required String dept,
  required DateTime start,
  required DateTime end,
  int progress = 0,
  int tasks = 0,
  int done = 0,
  String manager = 'm1',
  List<String> members = const [],
  Map<String, dynamic>? cost,
}) => Project.fromJson({
  '_id': id,
  'name': 'Project $id',
  'cost': ?cost,
  if (cost != null) 'costStatus': 'approved',
  'status': status,
  'targetDepartment': dept,
  'managerId': {'_id': manager, 'name': 'M'},
  'members': [
    for (final m in members) {'_id': m, 'name': m},
  ],
  'startDate': _iso(start),
  'endDate': _iso(end),
  'progress': progress,
  'totalTasks': tasks,
  'completedTasks': done,
  'departments': [
    {'name': dept, 'role': 'owner', 'status': 'accepted'},
  ],
  'departmentProgress': tasks == 0
      ? const []
      : [
          {'name': dept, 'progress': progress, 'tasks': tasks, 'done': done},
        ],
});

// a: running, b: done, c: on hold and past its end (overdue), d: not started, e: cancelled
final _projects = [
  _p(
    'a',
    status: 'active',
    dept: 'IT',
    start: DateTime(2026, 2, 1),
    end: DateTime(2026, 12, 1),
    progress: 60,
    tasks: 10,
    done: 6,
    members: ['a', 'b'],
  ),
  _p(
    'b',
    status: 'completed',
    dept: 'IT',
    start: DateTime(2026, 1, 10),
    end: DateTime(2026, 5, 1),
    progress: 100,
    tasks: 4,
    done: 4,
    members: ['b', 'c'],
  ),
  _p('c', status: 'on-hold', dept: 'Finance', start: DateTime(2026, 6, 1), end: DateTime(2026, 9, 1), progress: 20, tasks: 5, done: 1, manager: 'm2'),
  _p('d', status: 'planning', dept: 'HR', start: DateTime(2026, 12, 1), end: DateTime(2027, 3, 1), manager: 'm2'),
  _p('e', status: 'cancelled', dept: 'Marketing', start: DateTime(2026, 3, 1), end: DateTime(2026, 4, 1), progress: 80, manager: 'm3'),
];

ITTask _t(String id, {String project = 'a', String status = 'todo', DateTime? due, DateTime? created, DateTime? completed, String title = ''}) =>
    ITTask.fromJson({
      '_id': id,
      'projectId': {'_id': project, 'name': 'Project $project'},
      'title': title.isEmpty ? 'Task $id' : title,
      'status': status,
      if (due != null) 'dueDate': due.toIso8601String(),
      if (created != null) 'createdAt': created.toIso8601String(),
      if (completed != null) 'completedAt': completed.toIso8601String(),
    });

// the tasks of the projects above: 4 in the year (3 done, 1 overdue) — only 2 of them (both done) belong to the one project running in November — plus one on a project not shown
final _allTasks = [
  _t('t1', project: 'a', status: 'closed', created: DateTime(2026, 9, 1), completed: DateTime(2026, 9, 20)),
  _t('t2', project: 'a', status: 'closed', created: DateTime(2026, 9, 1), completed: DateTime(2026, 10, 1)),
  _t('t3', project: 'b', status: 'closed', created: DateTime(2026, 8, 1), completed: DateTime(2026, 10, 15)),
  _t('t4', project: 'c', status: 'todo', created: DateTime(2026, 10, 5), due: DateTime(2026, 11, 1)),
  _t('x', project: 'elsewhere', status: 'todo', created: DateTime(2026, 10, 5)),
];

final _myTasks = [
  _t('m1', project: 'a', status: 'todo', due: DateTime(2026, 11, 10), title: 'Prepare UAT report'),
  _t('m2', project: 'a', status: 'in-progress', due: DateTime(2026, 11, 12), title: 'Fix API issues'),
  _t('m3', project: 'c', status: 'in-progress', due: DateTime(2026, 11, 16), title: 'Client presentation'),
  _t('m4', project: 'a', status: 'closed', due: DateTime(2026, 11, 7), title: 'Update documentation'),
  _t('m5', project: 'd', status: 'todo', title: 'Review contracts'),
];

NotificationPage _notifs(List<String> titles) => NotificationPage(
  totalPages: 1,
  page: 1,
  unreadCount: titles.length,
  items: [
    for (var i = 0; i < titles.length; i++)
      AppNotification(
        id: 'n$i',
        type: 'new_lead',
        title: titles[i],
        body: '',
        createdAt: _now.subtract(Duration(hours: 2 + i)),
      ),
  ],
);

class _Opened {
  _Opened();
  int portfolio = 0;
  final List<Object> errors = [];
}

Future<_Opened> _open(
  WidgetTester tester, {
  List<Project>? projects,
  List<ITTask>? allTasks,
  Object? tasksError,
  List<ITTask>? myTasks,
  NotificationPage? notifications,
  Size size = const Size(1360, 2400),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final o = _Opened();
  final home = Scaffold(
    body: CompanyPlanningDashboard(now: _now, onOpenPortfolio: () => o.portfolio++),
  );
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => home),
      GoRoute(
        path: '/projects/:id',
        builder: (_, s) => Scaffold(body: Text('PROJECT PAGE ${s.pathParameters['id']}')),
      ),
      GoRoute(
        path: '/my-tasks',
        builder: (_, _) => const Scaffold(body: Text('MY TASKS PAGE')),
      ),
      GoRoute(
        path: '/notifications',
        builder: (_, _) => const Scaffold(body: Text('NOTIFICATIONS PAGE')),
      ),
    ],
  );
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null, // a failure shows at once instead of being tried again in the background
      overrides: <Override>[
        authSessionProvider.overrideWithValue(AuthSession(token: 't', userId: 'u', name: 'U', email: 'u@x', role: 'admin')),
        companyProjectsProvider.overrideWith((ref, d) async => projects ?? _projects),
        planningOkrsProvider.overrideWith((ref) async => <OKRModel>[]),
        departmentsProvider.overrideWith((ref) async => const <Department>[]),
        allTasksProvider.overrideWith((ref) async {
          if (tasksError != null) throw tasksError;
          return allTasks ?? _allTasks;
        }),
        myTasksProvider.overrideWith((ref) async => myTasks ?? _myTasks),
        notificationsProvider.overrideWith((ref) async => notifications ?? _notifs(['Mobile App moved to In Progress', 'New task assigned to you'])),
      ],
      child: MaterialApp.router(theme: AppTheme.lightTheme, routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return o;
}

Finder _k(String key) => find.byKey(Key(key));
Finder _in(String key, Finder what) => find.descendant(of: _k(key), matching: what);
Future<void> _tap(WidgetTester t, Finder f) async {
  await t.ensureVisible(f);
  await t.pumpAndSettle();
  await t.tap(f);
  await t.pumpAndSettle();
}

String _txt(WidgetTester t, Finder f) => t.widget<Text>(f).data!;

void main() {
  group('the headline numbers', () {
    testWidgets('are for the projects that run this year, and say so', (tester) async {
      await _open(tester);
      expect(_k('pd_title'), findsOneWidget);
      expect(_txt(tester, _k('pd_range_text')), 'Jan 2026 – Dec 2026');
      expect(_in('pd_kpi_total', find.text('5')), findsOneWidget);
      expect(_in('pd_kpi_active', find.text('1')), findsOneWidget);
      expect(_in('pd_kpi_completed', find.text('1')), findsOneWidget);
      expect(_in('pd_kpi_hold', find.text('1')), findsOneWidget);
      expect(_in('pd_kpi_people', find.text('6')), findsOneWidget); // m1, m2, m3, a, b, c — each counted once
    });

    testWidgets('the small chips are real numbers: share of the total, overdue, departments', (tester) async {
      await _open(tester);
      expect(_in('pd_kpi_active', find.text('20%')), findsOneWidget);
      expect(_in('pd_kpi_completed', find.text('20%')), findsOneWidget);
      expect(_in('pd_kpi_hold', find.text('1 overdue')), findsOneWidget);
      expect(_in('pd_kpi_people', find.text('4 depts')), findsOneWidget);
      expect(_in('pd_kpi_total', find.text('+5 new')), findsOneWidget);
    });

    testWidgets('no money is shown when none of the projects\' amounts can be seen — never an invented figure', (tester) async {
      await _open(tester);
      expect(find.byKey(const Key('pd_budget_card')), findsNothing);
      expect(find.textContaining('Budget'), findsNothing);
    });
  });

  group('budget vs actual', () {
    Map<String, dynamic> money(double approved, double spent, [double committed = 0]) => {
      'budget': approved,
      'approvedBudget': approved,
      'spent': spent,
      'committed': committed,
      'plan': <dynamic>[],
      'changes': <dynamic>[],
    };

    // a: IT, 60% used · c: Finance, 112% (over) · d: HR, no approved limit yet · e: cancelled (left out)
    final withMoney = [
      _p(
        'a',
        status: 'active',
        dept: 'IT',
        start: DateTime(2026, 2, 1),
        end: DateTime(2026, 12, 1),
        progress: 60,
        tasks: 10,
        done: 6,
        cost: money(100000, 50000, 10000),
      ),
      _projects[1],
      _p(
        'c',
        status: 'on-hold',
        dept: 'Finance',
        start: DateTime(2026, 6, 1),
        end: DateTime(2026, 9, 1),
        progress: 20,
        tasks: 5,
        done: 1,
        manager: 'm2',
        cost: money(50000, 56000),
      ),
      _p(
        'd',
        status: 'planning',
        dept: 'HR',
        start: DateTime(2026, 12, 1),
        end: DateTime(2027, 3, 1),
        manager: 'm2',
        cost: const {'budget': 30000, 'approvedBudget': 0, 'spent': 0, 'committed': 0},
      ),
      _p(
        'e',
        status: 'cancelled',
        dept: 'Marketing',
        start: DateTime(2026, 3, 1),
        end: DateTime(2026, 4, 1),
        progress: 80,
        manager: 'm3',
        cost: money(99999, 5),
      ),
    ];

    testWidgets('approved, spent, committed and what is left, over the projects whose amounts can be seen', (tester) async {
      await _open(tester, projects: withMoney);
      expect(find.byKey(const Key('pd_budget_card')), findsOneWidget);
      expect(find.text('Budget vs Actual'), findsOneWidget);
      expect(_txt(tester, _k('pd_budget_approved')), '₹1,50,000'); // 1,00,000 + 50,000: not the one with no limit, not the cancelled
      expect(_txt(tester, _k('pd_budget_spent')), '₹1,06,000');
      expect(_txt(tester, _k('pd_budget_committed')), '₹10,000');
      // overall there is room (1,16,000 of 1,50,000) although one project is over its own budget
      expect(find.text('Left'), findsOneWidget);
      expect(_txt(tester, _k('pd_budget_left')), '₹34,000');
      expect(_txt(tester, _k('pd_budget_pct')), '77%');
    });

    testWidgets('it is for the period: projects outside it are not counted', (tester) async {
      await _open(tester, projects: withMoney);
      await _tap(tester, _k('pd_period_1')); // November: only a runs
      expect(_txt(tester, _k('pd_budget_approved')), '₹1,00,000');
      expect(_txt(tester, _k('pd_budget_spent')), '₹50,000');
    });

    testWidgets('by department, and the projects that need a look', (tester) async {
      await _open(tester, projects: withMoney);
      expect(_k('pd_budget_dept_IT'), findsOneWidget);
      expect(_k('pd_budget_dept_Finance'), findsOneWidget);
      expect(_k('pd_budget_watch_c'), findsOneWidget);
      expect(find.text('Over · 112%'), findsOneWidget);
      expect(_k('pd_budget_watch_a'), findsNothing, reason: '60% is fine');
    });

    testWidgets('an over-budget project is what stands out first', (tester) async {
      await _open(tester, projects: withMoney);
      expect(_in('pd_insight_0', find.text('1 project is over budget')), findsOneWidget);
      expect(_in('pd_insight_0', find.text('Project c')), findsOneWidget);
    });

    testWidgets('tapping a project that needs a look opens it', (tester) async {
      await _open(tester, projects: withMoney);
      await _tap(tester, _k('pd_budget_watch_c'));
      expect(find.text('PROJECT PAGE c'), findsOneWidget);
    });

    testWidgets('fits a phone and a tablet', (tester) async {
      await _open(tester, projects: withMoney, size: const Size(360, 4600));
      expect(tester.takeException(), isNull);
      expect(_k('pd_budget_card'), findsOneWidget);
      await _open(tester, projects: withMoney, size: const Size(860, 3200));
      expect(tester.takeException(), isNull);
      expect(_k('pd_budget_card'), findsOneWidget);
    });

    testWidgets('within budget: no warning rows, and the ring says how much is used', (tester) async {
      await _open(
        tester,
        projects: [_p('a', status: 'active', dept: 'IT', start: DateTime(2026, 2, 1), end: DateTime(2026, 12, 1), cost: money(100000, 25000))],
      );
      expect(_txt(tester, _k('pd_budget_pct')), '25%');
      expect(find.text('Needs a look'), findsNothing);
      expect(find.text('Left'), findsOneWidget);
    });
  });

  group('progress', () {
    testWidgets('the ring says the overall % and each status its count', (tester) async {
      await _open(tester);
      expect(_txt(tester, _k('pd_overall')), '45%'); // (60 + 100 + 20 + 0) / 4: the cancelled one is not "progress"
      expect(_txt(tester, _k('pd_status_inProgress')), '1');
      expect(_txt(tester, _k('pd_status_completed')), '1');
      expect(_txt(tester, _k('pd_status_onHold')), '1');
      expect(_txt(tester, _k('pd_status_notStarted')), '1');
      expect(_txt(tester, _k('pd_status_cancelled')), '1');
    });

    testWidgets('a status nobody is in is not listed — cancelled only appears once there is one', (tester) async {
      await _open(tester, projects: [_projects[0], _projects[1]]);
      expect(_k('pd_status_cancelled'), findsNothing);
      expect(_k('pd_status_inProgress'), findsOneWidget);
    });

    testWidgets('the trend is drawn from the tasks, in each of its three windows', (tester) async {
      await _open(tester);
      expect(_k('pd_trend_chart'), findsOneWidget);
      await _tap(tester, _k('pd_trend_1'));
      expect(_k('pd_trend_chart'), findsOneWidget);
      await _tap(tester, _k('pd_trend_2'));
      expect(_k('pd_trend_chart'), findsOneWidget);
    });

    testWidgets('with no task history it says so instead of drawing a flat line', (tester) async {
      await _open(tester, allTasks: const []);
      expect(_k('pd_trend_chart'), findsNothing);
      expect(find.textContaining('Not enough task history yet'), findsOneWidget);
    });

    testWidgets('tasks that could not be loaded: those cards say so, the rest of the page stays', (tester) async {
      await _open(tester, tasksError: Exception('down'));
      expect(find.text('Could not load this.'), findsNWidgets(2)); // the trend and the task overview
      expect(find.text('Retry'), findsNWidgets(2));
      expect(_in('pd_kpi_total', find.text('5')), findsOneWidget);
      expect(_txt(tester, _k('pd_overall')), '45%');
      expect(find.text('No tasks in these projects yet.'), findsNothing); // a failure is not "no tasks"
    });
  });

  group('the period', () {
    testWidgets('This Month keeps only what runs in November, and the range says it', (tester) async {
      await _open(tester);
      await _tap(tester, _k('pd_period_1'));
      expect(_txt(tester, _k('pd_range_text')), '1 Nov – 30 Nov 2026');
      expect(_in('pd_kpi_total', find.text('1')), findsOneWidget);
      expect(_in('pd_kpi_active', find.text('1')), findsOneWidget);
      expect(_in('pd_kpi_completed', find.text('0')), findsOneWidget);
    });

    testWidgets('This Week is Monday to Sunday', (tester) async {
      await _open(tester);
      await _tap(tester, _k('pd_period_0'));
      expect(_txt(tester, _k('pd_range_text')), '9 Nov – 15 Nov 2026');
    });

    testWidgets('This Quarter is Oct–Dec; back to This Year restores everything', (tester) async {
      await _open(tester);
      await _tap(tester, _k('pd_period_2'));
      expect(_txt(tester, _k('pd_range_text')), 'Oct 2026 – Dec 2026');
      expect(_in('pd_kpi_total', find.text('2')), findsOneWidget); // a and d
      await _tap(tester, _k('pd_period_3'));
      expect(_in('pd_kpi_total', find.text('5')), findsOneWidget);
    });

    testWidgets('the tasks follow the period: a project outside it brings no tasks', (tester) async {
      await _open(tester);
      expect(_txt(tester, _k('pd_tasks_done_pct')), '75%'); // the year: 3 of 4 done
      await _tap(tester, _k('pd_period_1')); // November: only project a runs — its 2 tasks, both done
      expect(_txt(tester, _k('pd_tasks_done_pct')), '100%');
      await _tap(tester, _k('pd_period_3'));
      expect(_txt(tester, _k('pd_tasks_done_pct')), '75%');
    });

    testWidgets('a custom range: pick two days and only the projects running then are shown', (tester) async {
      await _open(tester);
      await _tap(tester, _k('pd_range'));
      expect(find.text('Show projects running between'), findsOneWidget);
      final picker = find.byType(DateRangePickerDialog);
      await tester.tap(find.descendant(of: picker, matching: find.text('5')).first);
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: picker, matching: find.text('20')).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(_txt(tester, _k('pd_range_text')), '5 Jan – 20 Jan 2026');
      expect(_in('pd_kpi_total', find.text('1')), findsOneWidget); // only b (10 Jan – 1 May)
      expect(_in('pd_kpi_completed', find.text('1')), findsOneWidget);
    });

    testWidgets('closing the range picker changes nothing', (tester) async {
      await _open(tester);
      await _tap(tester, _k('pd_range'));
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      expect(_txt(tester, _k('pd_range_text')), 'Jan 2026 – Dec 2026');
    });
  });

  group('what stands out', () {
    testWidgets('trouble comes first, named', (tester) async {
      await _open(tester);
      expect(_in('pd_insight_0', find.text('1 project is overdue')), findsOneWidget);
      expect(_in('pd_insight_0', find.text('Project c')), findsOneWidget);
      expect(find.text('1 project is on hold'), findsOneWidget);
    });

    testWidgets('nothing to point out for an empty period', (tester) async {
      await _open(tester, projects: const []);
      expect(find.text('Nothing to point out yet.'), findsOneWidget);
    });
  });

  group('departments', () {
    testWidgets('by count: how many projects each is on, and its share', (tester) async {
      await _open(tester);
      expect(_in('pd_dept_card', find.text('IT')), findsOneWidget);
      expect(_in('pd_dept_card', find.text('40%')), findsOneWidget); // IT: 2 of 5
      expect(_in('pd_dept_total', find.text('4')), findsNothing); // (the number sits in the ring, not a legend row)
      expect(_txt(tester, _k('pd_dept_total')), '4');
    });

    testWidgets('by progress: how far each has got', (tester) async {
      await _open(tester);
      expect(_in('pd_dept_card', find.text('71%')), findsNothing);
      await _tap(tester, _k('pd_dept_view_1'));
      expect(_in('pd_dept_card', find.text('71%')), findsOneWidget); // IT: (60×10 + 100×4) / 14
      expect(_in('pd_dept_card', find.text('20%')), findsOneWidget); // Finance
      expect(_in('pd_dept_card', find.text('80%')), findsOneWidget); // Marketing: no tasks yet, its own progress
    });

    testWidgets('the best departments are ranked by their tasks, and one without tasks is left out', (tester) async {
      await _open(tester);
      expect(_in('pd_top_0', find.text('IT')), findsOneWidget);
      expect(_in('pd_top_0', find.text('71%')), findsOneWidget);
      expect(_in('pd_top_1', find.text('Finance')), findsOneWidget);
      expect(_k('pd_top_2'), findsNothing); // HR and Marketing have no tasks to measure
    });
  });

  group('the timeline', () {
    testWidgets('draws the projects still to finish that have dates — not the finished or cancelled', (tester) async {
      await _open(tester);
      expect(_k('pd_bar_a'), findsOneWidget);
      expect(_k('pd_bar_c'), findsOneWidget);
      expect(_k('pd_bar_d'), findsOneWidget);
      expect(_k('pd_bar_b'), findsNothing); // completed
      expect(_k('pd_bar_e'), findsNothing); // cancelled
      expect(_in('pd_bar_c', find.text('Overdue')), findsOneWidget);
      expect(_in('pd_bar_a', find.text('In Progress')), findsOneWidget);
      expect(_k('pd_today'), findsOneWidget);
    });

    testWidgets('a project that has not started yet is drawn after today, not before', (tester) async {
      await _open(tester);
      final today = tester.getCenter(_k('pd_today')).dx;
      expect(tester.getRect(_k('pd_bar_d')).left, greaterThan(today));
      expect(tester.getRect(_k('pd_bar_a')).left, lessThan(today));
    });

    testWidgets('tapping a project opens it', (tester) async {
      await _open(tester);
      await _tap(tester, _k('pd_up_a'));
      expect(find.text('PROJECT PAGE a'), findsOneWidget);
    });

    testWidgets('View All opens the full portfolio', (tester) async {
      final o = await _open(tester);
      await _tap(tester, _in('pd_upcoming_card', find.text('View All')));
      expect(o.portfolio, 1);
    });

    testWidgets('with nothing dated it says so', (tester) async {
      await _open(tester, projects: [_projects[1]]);
      expect(find.textContaining('No dated projects still to finish'), findsOneWidget);
    });
  });

  group('my tasks', () {
    testWidgets('tabs count the tasks, and Completed shows only those', (tester) async {
      await _open(tester);
      expect(find.text('All (5)'), findsOneWidget);
      expect(find.text('To Do (2)'), findsOneWidget);
      expect(find.text('In Progress (2)'), findsOneWidget);
      expect(find.text('Completed (1)'), findsOneWidget);
      await _tap(tester, _k('pd_tasks_tab_3'));
      expect(_in('pd_task_0', find.text('Update documentation')), findsOneWidget);
      expect(_k('pd_task_1'), findsNothing);
    });

    testWidgets('what still needs doing comes first, soonest due first; finished last; undated after dated', (tester) async {
      await _open(tester);
      expect(_in('pd_task_0', find.text('Prepare UAT report')), findsOneWidget); // due 10 Nov (past)
      expect(_in('pd_task_1', find.text('Fix API issues')), findsOneWidget);
      expect(_in('pd_task_2', find.text('Client presentation')), findsOneWidget);
      expect(_in('pd_task_3', find.text('Review contracts')), findsOneWidget); // no date
      expect(_in('pd_task_4', find.text('Update documentation')), findsOneWidget); // done
    });

    testWidgets('only five are listed, with View All for the rest', (tester) async {
      await _open(
        tester,
        myTasks: [for (var i = 0; i < 8; i++) _t('q$i', title: 'Job $i', due: DateTime(2026, 11, 12 + i))],
      );
      expect(_k('pd_task_4'), findsOneWidget);
      expect(_k('pd_task_5'), findsNothing);
      expect(find.text('All (8)'), findsOneWidget);
    });

    testWidgets('View All goes to My Tasks', (tester) async {
      await _open(tester);
      await _tap(tester, _in('pd_mytasks_card', find.text('View All')));
      expect(find.text('MY TASKS PAGE'), findsOneWidget);
    });

    testWidgets('no tasks assigned: says so', (tester) async {
      await _open(tester, myTasks: const []);
      expect(find.text('No tasks are assigned to you.'), findsOneWidget);
    });
  });

  group('the task overview', () {
    testWidgets('done, open and overdue add up, and the bars show the departments', (tester) async {
      await _open(tester);
      expect(_txt(tester, _k('pd_tasks_done_pct')), '75%');
      expect(find.text('Completed'), findsWidgets);
      expect(_k('pd_taskdept_IT'), findsOneWidget);
      expect(_k('pd_taskdept_Finance'), findsOneWidget);
    });

    testWidgets('no tasks in the projects: says so', (tester) async {
      await _open(tester, allTasks: const []);
      expect(find.text('No tasks in these projects yet.'), findsOneWidget);
    });
  });

  group('notifications', () {
    testWidgets('lists the latest, and a tap opens the page', (tester) async {
      await _open(tester);
      expect(find.text('Mobile App moved to In Progress'), findsOneWidget);
      expect(find.text('New task assigned to you'), findsOneWidget);
      await _tap(tester, _k('pd_notif_0'));
      expect(find.text('NOTIFICATIONS PAGE'), findsOneWidget);
    });

    testWidgets('only five, and a clear line when there are none', (tester) async {
      await _open(tester, notifications: _notifs([for (var i = 0; i < 8; i++) 'Note $i']));
      expect(_k('pd_notif_4'), findsOneWidget);
      expect(_k('pd_notif_5'), findsNothing);
    });

    testWidgets('none: "all caught up"', (tester) async {
      await _open(tester, notifications: _notifs(const []));
      expect(find.text('You are all caught up.'), findsOneWidget);
    });
  });

  group('what was there before is still there', () {
    testWidgets('needs-attention, the strategic horizon and the objectives', (tester) async {
      await _open(tester);
      expect(find.text('Needs attention'), findsOneWidget);
      expect(find.text('15-Year Strategic Horizon Distribution (Vision 2040)'), findsOneWidget);
      expect(find.text('Objectives & Key Results'), findsOneWidget);
    });
  });

  group('empty and fitting', () {
    testWidgets('no projects at all: zeros, an explanation, no errors', (tester) async {
      await _open(tester, projects: const []);
      expect(tester.takeException(), isNull);
      expect(_in('pd_kpi_total', find.text('0')), findsOneWidget);
      expect(find.text('No projects run in this period.'), findsWidgets);
    });

    for (final (name, size) in [
      ('desktop', const Size(1360, 2400)),
      ('tablet', const Size(860, 3000)),
      ('phone', const Size(360, 4200)),
      ('small phone', const Size(320, 4400)),
    ]) {
      testWidgets('fits a $name without overflow', (tester) async {
        await _open(tester, size: size);
        expect(tester.takeException(), isNull);
        expect(_k('pd_kpi_people'), findsOneWidget);
        expect(_k('pd_bar_a'), findsOneWidget);
      });
    }

    testWidgets('the five numbers are one row on a desktop and two to a row on a phone', (tester) async {
      await _open(tester);
      final y = {
        for (final k in ['total', 'active', 'completed', 'hold', 'people']) k: tester.getTopLeft(_k('pd_kpi_$k')).dy,
      };
      expect(y.values.toSet().length, 1);
      await _open(tester, size: const Size(360, 4200));
      expect(tester.getTopLeft(_k('pd_kpi_total')).dy, tester.getTopLeft(_k('pd_kpi_active')).dy);
      expect(tester.getTopLeft(_k('pd_kpi_people')).dy, greaterThan(tester.getTopLeft(_k('pd_kpi_total')).dy));
    });

    testWidgets('a narrow card uses the short name, a wide one the full name', (tester) async {
      await _open(tester);
      expect(_in('pd_kpi_completed', find.text('Completed Projects')), findsOneWidget);
      await _open(tester, size: const Size(360, 4200));
      expect(_in('pd_kpi_completed', find.text('Completed')), findsOneWidget);
      expect(_in('pd_kpi_completed', find.text('Completed Projects')), findsNothing);
    });

    testWidgets('the wide layout puts insights and notifications in a column beside the rest', (tester) async {
      await _open(tester);
      final insights = tester.getTopLeft(_k('pd_insight_0')).dx;
      final progress = tester.getTopLeft(_k('pd_progress_card')).dx;
      expect(insights, greaterThan(tester.getRect(_k('pd_progress_card')).right - 1));
      expect(progress, lessThan(insights));
    });
  });
}
