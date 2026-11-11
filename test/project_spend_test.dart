import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/theme/app_theme.dart';
import 'package:nizan_crm/features/accounts/presentation/widgets/project_charge_widgets.dart';
import 'package:nizan_crm/features/it/data/project.dart';
import 'package:nizan_crm/features/it/data/project_spend.dart';
import 'package:nizan_crm/features/it/presentation/screens/widgets/project_cost_widgets.dart';
import 'package:nizan_crm/features/it/presentation/screens/widgets/project_spend_widgets.dart';
import 'package:nizan_crm/features/it/services/it_service.dart';

// What a project has spent against the cost its finance head approved: the meter and sheet on the project, the project an
// expense is charged to, and what is said when an expense would take it over the budget.

class _Fake extends ProjectService {
  _Fake() : super(Dio());
  ProjectSpend spend = const ProjectSpend();
  List<ChargeableProject> chargeable = const [];
  Object? spendFails;
  Object? chargeableFails;

  @override
  Future<ProjectSpend> getSpend(String id) async {
    if (spendFails != null) throw spendFails!;
    return spend;
  }

  @override
  Future<List<ChargeableProject>> chargeableProjects() async {
    if (chargeableFails != null) throw chargeableFails!;
    return chargeable;
  }

  @override
  Future<List<Project>> getProjects({String? status, String? priority, String? search, String? department, bool ownerOnly = false}) async => const [];
}

Project _project({double budget = 100000, double approved = 100000, double spent = 0, double committed = 0, String costStatus = 'approved'}) =>
    Project.fromJson({
      '_id': 'p1',
      'name': 'Website redesign',
      'status': 'active',
      'targetDepartment': 'Marketing',
      'managerId': {'_id': 'm1', 'name': 'Mira'},
      'costStatus': costStatus,
      'cost': {'budget': budget, 'approvedBudget': approved, 'spent': spent, 'committed': committed, 'plan': <dynamic>[], 'changes': <dynamic>[]},
      'access': {'role': 'manager', 'canSeeCost': true},
    });

Future<_Fake> _pump(WidgetTester tester, Widget child, {_Fake? fake, Size size = const Size(900, 1400)}) async {
  final f = fake ?? _Fake();
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: <Override>[projectServiceProvider.overrideWithValue(f)],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return f;
}

Finder _k(String key) => find.byKey(Key(key));
String _txt(WidgetTester t, String key) => t.widget<Text>(_k(key)).data!;
Future<void> _tap(WidgetTester t, Finder f) async {
  await t.ensureVisible(f);
  await t.pumpAndSettle();
  await t.tap(f);
  await t.pumpAndSettle();
}

DioException _refusal(String code, {double limit = 100000, double used = 90000, double after = 120000}) => DioException(
  requestOptions: RequestOptions(path: '/x'),
  response: Response(
    requestOptions: RequestOptions(path: '/x'),
    statusCode: 409,
    data: {'code': code, 'message': 'It goes over.', 'limit': limit, 'used': used, 'after': after},
  ),
  type: DioExceptionType.badResponse,
);

void main() {
  group('reading the spending', () {
    test('a spending summary, with where it went and the expenses', () {
      final s = ProjectSpend.fromJson({
        'limit': 100000,
        'requested': 110000,
        'spent': 30000,
        'committed': 20000,
        'used': 50000,
        'available': 50000,
        'usedPercent': 50,
        'level': 'ok',
        'byHead': [
          {'key': 'OFF-01', 'spent': 30000, 'committed': 20000},
        ],
        'byDepartment': [
          {'key': 'Marketing', 'spent': 30000, 'committed': 20000},
        ],
        'byMonth': [
          {'key': '2026-11', 'spent': 30000, 'committed': 0},
        ],
        'expenses': [
          {
            'id': 'e1',
            'title': 'Stock photos',
            'amount': 1500,
            'date': '2026-11-05T00:00:00Z',
            'status': 'approved',
            'department': 'Marketing',
            'expenseHead': 'OFF-01',
            'filedByName': 'Asha',
            'overBudgetReason': '',
          },
        ],
      });
      expect(s.limit, 100000);
      expect(s.used, 50000);
      expect(s.usedPercent, 50);
      expect(s.isOver, isFalse);
      expect(s.byHead.single.total, 50000);
      expect(s.byDepartment.single.key, 'Marketing');
      expect(s.expenses.single.title, 'Stock photos');
      expect(s.expenses.single.filedByName, 'Asha');
    });

    test('over the budget', () {
      final s = ProjectSpend.fromJson({'limit': 1000, 'used': 1200, 'available': -200, 'level': 'over', 'usedPercent': 120});
      expect(s.isOver, isTrue);
      expect(s.available, -200);
    });

    test('an empty answer reads as nothing spent', () {
      final s = ProjectSpend.fromJson({});
      expect(s.spent, 0);
      expect(s.level, 'none');
      expect(s.usedPercent, isNull);
      expect(s.expenses, isEmpty);
    });

    test('a project an expense can be charged to — with the amounts only for those who may know them', () {
      final a = ChargeableProject.fromJson({
        'id': 'p',
        'name': 'x',
        'department': 'IT',
        'status': 'active',
        'level': 'warn',
        'limit': 1000,
        'used': 850,
        'available': 150,
      });
      expect(a.hasAmounts, isTrue);
      expect(a.available, 150);
      final b = ChargeableProject.fromJson({'id': 'p', 'name': 'x', 'level': 'ok'});
      expect(b.hasAmounts, isFalse);
      expect(b.limit, isNull);
    });

    test('the cost\'s own reading of where it stands, with the same words the server uses', () {
      ProjectCost c(double approved, double spent, [double committed = 0]) =>
          ProjectCost(approvedBudget: approved, spent: spent, committed: committed);
      expect(c(0, 100).level, 'none');
      expect(c(1000, 100).level, 'ok');
      expect(c(1000, 799).level, 'ok');
      expect(c(1000, 800).level, 'warn');
      expect(c(1000, 500, 300).level, 'warn', reason: 'committed counts');
      expect(c(1000, 1000).level, 'warn', reason: 'exactly the limit is not over');
      expect(c(1000, 1001).level, 'over');
      expect(c(1000, 300, 200).used, 500);
      expect(c(1000, 300, 200).available, 500);
      expect(c(1000, 1200).available, -200);
      expect(c(1000, 250).usedFraction, 0.25);
      expect(c(0, 250).usedFraction, isNull);
    });

    test('a refusal for going over the budget is told from every other failure', () {
      final needsReason = OverBudgetRefusal.of(_refusal('OVER_BUDGET_REASON'))!;
      expect(needsReason.needsReason, isTrue);
      expect(needsReason.after, 120000);
      expect(needsReason.message, 'It goes over.');
      final only = OverBudgetRefusal.of(AppException(_refusal('OVER_BUDGET')))!;
      expect(only.needsReason, isFalse);
      expect(OverBudgetRefusal.of(_refusal('SOMETHING_ELSE')), isNull);
      expect(
        OverBudgetRefusal.of(
          DioException(
            requestOptions: RequestOptions(path: '/x'),
            type: DioExceptionType.connectionError,
          ),
        ),
        isNull,
      );
      expect(OverBudgetRefusal.of(Exception('x')), isNull);
      expect(OverBudgetRefusal.of(null), isNull);
    });
  });

  group('the spend meter', () {
    testWidgets('what is spent and committed along the approved limit, and what is left', (tester) async {
      await _pump(tester, SpendMeter(cost: const ProjectCost(budget: 100000, approvedBudget: 100000, spent: 30000, committed: 20000)));
      expect(_txt(tester, 'cost_spent'), '₹30,000');
      expect(_txt(tester, 'cost_committed'), '₹20,000');
      expect(_txt(tester, 'cost_left'), '₹50,000');
      expect(_txt(tester, 'spend_level'), '50% used');
      expect(find.text('Left'), findsOneWidget);
    });

    testWidgets('nothing committed: that figure is not shown', (tester) async {
      await _pump(tester, SpendMeter(cost: const ProjectCost(budget: 100000, approvedBudget: 100000, spent: 30000)));
      expect(_k('cost_committed'), findsNothing);
    });

    testWidgets('from 80% it warns', (tester) async {
      await _pump(tester, SpendMeter(cost: const ProjectCost(budget: 100000, approvedBudget: 100000, spent: 85000)));
      expect(_txt(tester, 'spend_level'), '85% used');
      expect(tester.widget<Text>(_k('spend_level')).style!.color, const Color(0xFFB45309));
    });

    testWidgets('over: says so, and by how much', (tester) async {
      await _pump(tester, SpendMeter(cost: const ProjectCost(budget: 100000, approvedBudget: 100000, spent: 111000)));
      expect(_txt(tester, 'spend_level'), 'Over budget');
      expect(find.text('Over by'), findsOneWidget);
      expect(_txt(tester, 'cost_left'), '₹11,000');
      expect(tester.widget<Text>(_k('cost_left')).style!.color, const Color(0xFFB91C1C));
    });

    testWidgets('the bar never runs past its end, however far over', (tester) async {
      await _pump(tester, SpendMeter(cost: const ProjectCost(budget: 1000, approvedBudget: 1000, spent: 9000)));
      expect(tester.takeException(), isNull);
      final bar = tester.getSize(_k('spend_bar_spent'));
      final track = tester.getSize(find.ancestor(of: _k('spend_bar_spent'), matching: find.byType(SizedBox)).first);
      expect(bar.width, lessThanOrEqualTo(track.width + 0.5));
    });

    testWidgets('fits a phone', (tester) async {
      await _pump(
        tester,
        SpendMeter(cost: const ProjectCost(budget: 12345678, approvedBudget: 12345678, spent: 9876543, committed: 1234567)),
        size: const Size(320, 600),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('on the project\'s cost card', () {
    testWidgets('an approved cost shows the meter; a cost not yet approved has nothing to measure', (tester) async {
      await _pump(tester, ProjectCostCard(project: _project(spent: 30000)));
      expect(_k('spend_meter'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await _pump(tester, ProjectCostCard(project: _project(approved: 0, costStatus: 'pending')));
      expect(_k('spend_meter'), findsNothing);
      expect(_k('cost_spend_open'), findsNothing);
    });

    testWidgets('a change waiting: the meter still measures against the earlier approved amount', (tester) async {
      await _pump(tester, ProjectCostCard(project: _project(budget: 150000, approved: 100000, spent: 90000, costStatus: 'pending')));
      expect(_txt(tester, 'spend_level'), '90% used');
    });

    testWidgets('See spending opens where the money went and the expenses', (tester) async {
      final fake = _Fake()
        ..spend = ProjectSpend.fromJson({
          'limit': 100000,
          'spent': 30000,
          'committed': 20000,
          'used': 50000,
          'available': 50000,
          'level': 'ok',
          'byHead': [
            {'key': 'FOO-01', 'spent': 20000, 'committed': 0},
            {'key': 'other', 'spent': 10000, 'committed': 20000},
          ],
          'byDepartment': [
            {'key': 'Marketing', 'spent': 30000, 'committed': 0},
            {'key': 'Sales', 'spent': 0, 'committed': 20000},
          ],
          'expenses': [
            {
              'id': 'e1',
              'title': 'Stock photos',
              'amount': 20000,
              'date': '2026-11-05T00:00:00Z',
              'status': 'approved',
              'department': 'Marketing',
              'filedByName': 'Asha',
            },
            {'id': 'e2', 'title': 'Ad spend', 'amount': 20000, 'date': '2026-11-06T00:00:00Z', 'status': 'pending', 'department': 'Sales'},
            {'id': 'e3', 'title': 'Printing', 'amount': 500, 'date': '2026-11-07T00:00:00Z', 'status': 'rejected', 'department': 'Marketing'},
          ],
        });
      await _pump(tester, ProjectCostCard(project: _project(spent: 30000, committed: 20000)), fake: fake);
      await _tap(tester, _k('cost_spend_open'));
      expect(_k('spend_sheet'), findsOneWidget);
      expect(find.text('Spending · Website redesign'), findsOneWidget);
      expect(_txt(tester, 'sheet_spent'), '₹30,000');
      expect(_txt(tester, 'sheet_committed'), '₹20,000');
      expect(_txt(tester, 'sheet_left'), '₹50,000');
      expect(find.text('Food Expense'), findsOneWidget, reason: 'a head\'s code is shown as its name');
      expect(find.text('No expense head'), findsOneWidget);
      expect(_k('sheet_dept_Marketing'), findsOneWidget);
      expect(_k('sheet_dept_Sales'), findsOneWidget);
      expect(find.text('Stock photos'), findsOneWidget);
      expect(find.textContaining('filed by Asha'), findsOneWidget);
      expect(find.text('pending'), findsOneWidget);
      expect(find.text('rejected'), findsOneWidget);
    });

    testWidgets('the sheet says when nothing has been charged', (tester) async {
      final fake = _Fake()..spend = const ProjectSpend(limit: 100000, available: 100000, level: 'ok');
      await _pump(tester, ProjectCostCard(project: _project()), fake: fake);
      await _tap(tester, _k('cost_spend_open'));
      expect(_k('sheet_empty'), findsOneWidget);
      expect(find.text('Where it went'), findsNothing);
    });

    testWidgets('over the budget: the sheet says by how much, and shows why the expense was approved', (tester) async {
      final fake = _Fake()
        ..spend = ProjectSpend.fromJson({
          'limit': 100000,
          'spent': 111000,
          'used': 111000,
          'available': -11000,
          'level': 'over',
          'expenses': [
            {'id': 'e1', 'title': 'Launch ads', 'amount': 30000, 'status': 'approved', 'overBudgetReason': 'Launch deadline moved up'},
          ],
        });
      await _pump(tester, ProjectCostCard(project: _project(spent: 111000)), fake: fake);
      await _tap(tester, _k('cost_spend_open'));
      expect(find.text('Over the budget by'), findsOneWidget);
      expect(_txt(tester, 'sheet_left'), '₹11,000');
      expect(find.text('Approved over the budget: Launch deadline moved up'), findsOneWidget);
    });

    testWidgets('a failure to load is said plainly, with a retry', (tester) async {
      final fake = _Fake()
        ..spendFails = DioException(
          requestOptions: RequestOptions(path: '/x'),
          type: DioExceptionType.connectionError,
        );
      await _pump(tester, ProjectCostCard(project: _project()), fake: fake);
      await _tap(tester, _k('cost_spend_open'));
      expect(find.byType(AppErrorView), findsOneWidget);
      expect(find.textContaining('DioException'), findsNothing);
    });
  });

  group('charging an expense to a project', () {
    String? picked;
    Future<_Fake> open(
      WidgetTester tester,
      List<ChargeableProject> projects, {
      String? selected,
      double amount = 0,
      Object? fails,
      ({String id, String name})? keep,
    }) async {
      picked = selected;
      final fake = _Fake()
        ..chargeable = projects
        ..chargeableFails = fails;
      await _pump(
        tester,
        StatefulBuilder(
          builder: (context, setS) =>
              ProjectChargeField(selectedId: picked, amount: amount, keepName: keep, onChanged: (v) => setS(() => picked = v)),
        ),
        fake: fake,
      );
      return fake;
    }

    const roomy = ChargeableProject(
      id: 'a',
      name: 'Website redesign',
      department: 'Marketing',
      level: 'ok',
      limit: 100000,
      used: 30000,
      available: 70000,
    );
    const tight = ChargeableProject(
      id: 'b',
      name: 'Brand refresh',
      department: 'Marketing',
      level: 'warn',
      limit: 100000,
      used: 85000,
      available: 15000,
    );
    const over = ChargeableProject(id: 'c', name: 'Old campaign', department: 'Sales', level: 'over', limit: 100000, used: 110000, available: -10000);
    const noAmounts = ChargeableProject(id: 'd', name: 'Team offsite', department: 'HR', level: 'ok');

    testWidgets('the projects can be picked, or none', (tester) async {
      await open(tester, [roomy, tight]);
      expect(find.text('Charge to a project (optional)'), findsOneWidget);
      await _tap(tester, find.byType(DropdownButtonFormField<String?>));
      expect(find.text('No project'), findsWidgets); // the chosen value and the menu's entry
      expect(find.text('Website redesign · Marketing'), findsOneWidget);
      expect(find.text('Brand refresh · Marketing'), findsOneWidget);
      await _tap(tester, find.text('Website redesign · Marketing'));
      expect(picked, 'a');
      expect(_k('charge_project_note'), findsOneWidget);
    });

    testWidgets('what is left, and what would be left after this expense', (tester) async {
      await open(tester, [roomy], selected: 'a', amount: 20000);
      expect(find.textContaining('₹70,000 left of the approved ₹1,00,000 — ₹50,000 after this'), findsOneWidget);
    });

    testWidgets('without an amount typed yet, only what is left', (tester) async {
      await open(tester, [roomy], selected: 'a');
      expect(find.textContaining('₹70,000 left of the approved ₹1,00,000.'), findsOneWidget);
      expect(find.textContaining('after this'), findsNothing);
    });

    testWidgets('an expense that takes the project over: says by how much, and that only the finance head can approve it', (tester) async {
      await open(tester, [tight], selected: 'b', amount: 25000);
      expect(find.textContaining('takes the project ₹10,000 over its approved budget'), findsOneWidget);
      expect(find.textContaining('Only the finance head can approve it'), findsOneWidget);
    });

    testWidgets('a project already over its budget says so', (tester) async {
      await open(tester, [over], selected: 'c');
      expect(find.textContaining('over its approved budget'), findsOneWidget);
    });

    testWidgets('someone who may not know the amounts is still told when it is nearly used', (tester) async {
      await open(tester, [noAmounts, const ChargeableProject(id: 'e', name: 'Tight one', level: 'warn')], selected: 'e');
      expect(find.text('This project has used most of its approved budget.'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await open(tester, [noAmounts], selected: 'd');
      expect(_k('charge_project_note'), findsNothing, reason: 'nothing to say, and no amount to say it with');
    });

    testWidgets('an expense on a project that is no longer on the list keeps it, by name', (tester) async {
      await open(tester, [roomy], selected: 'gone', keep: (id: 'gone', name: 'Finished project'));
      await _tap(tester, find.byType(DropdownButtonFormField<String?>));
      expect(find.text('Finished project'), findsWidgets);
    });

    testWidgets('no list: the expense can still be filed, without a project', (tester) async {
      await open(
        tester,
        const [],
        fails: DioException(
          requestOptions: RequestOptions(path: '/x'),
          type: DioExceptionType.connectionError,
        ),
      );
      expect(find.textContaining('cannot be charged to one'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.byType(DropdownButtonFormField<String?>), findsNothing);
    });
  });

  group('going over the budget', () {
    Future<String?> show(WidgetTester tester, OverBudgetRefusal r) async {
      String? result = 'unset';
      await _pump(
        tester,
        Builder(
          builder: (context) => FilledButton(onPressed: () async => result = await showOverBudgetDialog(context, r), child: const Text('open')),
        ),
      );
      await _tap(tester, find.text('open'));
      return result;
    }

    testWidgets('Accounts is told only the finance head can approve it, and nothing is asked of them', (tester) async {
      await show(
        tester,
        const OverBudgetRefusal(code: 'OVER_BUDGET', message: 'Only the finance head can approve an expense that goes over the budget.'),
      );
      expect(find.text('Over the project\'s budget'), findsOneWidget);
      expect(find.textContaining('Only the finance head can approve'), findsOneWidget);
      expect(_k('over_reason'), findsNothing);
      expect(_k('over_confirm'), findsNothing);
      await _tap(tester, _k('over_cancel'));
      expect(_k('over_budget_dialog'), findsNothing);
    });

    testWidgets('the finance head must say why, and the reason comes back', (tester) async {
      String? got = 'unset';
      await _pump(
        tester,
        Builder(
          builder: (context) => FilledButton(
            onPressed: () async =>
                got = await showOverBudgetDialog(context, const OverBudgetRefusal(code: 'OVER_BUDGET_REASON', message: 'Say why.')),
            child: const Text('open'),
          ),
        ),
      );
      await _tap(tester, find.text('open'));
      expect(_k('over_reason'), findsOneWidget);
      await _tap(tester, _k('over_confirm'));
      expect(find.text('Say why'), findsWidgets, reason: 'refused without a reason');
      expect(_k('over_budget_dialog'), findsOneWidget);
      await tester.enterText(_k('over_reason'), 'Launch deadline moved up');
      await _tap(tester, _k('over_confirm'));
      expect(got, 'Launch deadline moved up');
    });

    testWidgets('cancelling gives no reason', (tester) async {
      String? got = 'unset';
      await _pump(
        tester,
        Builder(
          builder: (context) => FilledButton(
            onPressed: () async =>
                got = await showOverBudgetDialog(context, const OverBudgetRefusal(code: 'OVER_BUDGET_REASON', message: 'Say why.')),
            child: const Text('open'),
          ),
        ),
      );
      await _tap(tester, find.text('open'));
      await _tap(tester, _k('over_cancel'));
      expect(got, isNull);
    });
  });
}
