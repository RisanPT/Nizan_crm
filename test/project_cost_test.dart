import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/theme/app_theme.dart';
import 'package:nizan_crm/features/it/data/project.dart';
import 'package:nizan_crm/features/it/presentation/screens/project_budgets_screen.dart';
import 'package:nizan_crm/features/it/presentation/screens/widgets/project_cost_widgets.dart';
import 'package:nizan_crm/features/it/services/it_service.dart';

// A project's cost in the app: asked for in the form, shown on the project with the finance head's decision, changed with
// a reason once approved, and decided from Finance's "Project budgets". The rules are the server's; these tests check what
// the app asks for, shows and sends.

class _Fake extends ProjectService {
  _Fake() : super(Dio());
  final saves = <Map<String, dynamic>>[];
  final decisions = <Map<String, dynamic>>[];
  List<PendingProjectCost> pending = [];
  Object? failWith;
  Object? pendingFails;

  @override
  Future<Project> saveCost(String id, {double? budget, List<CostLine> plan = const [], String reason = ''}) async {
    if (failWith != null) throw failWith!;
    saves.add({
      'id': id,
      'budget': budget,
      'plan': [for (final l in plan) (l.category, l.amount)],
      'reason': reason,
    });
    return _project();
  }

  @override
  Future<Project> decideCost(String id, {required bool approve, double? approvedAmount, String note = ''}) async {
    if (failWith != null) throw failWith!;
    decisions.add({'id': id, 'approve': approve, 'amount': approvedAmount, 'note': note});
    pending = [
      for (final p in pending)
        if (p.id != id) p,
    ]; // decided: no longer waiting
    return _project();
  }

  @override
  Future<List<PendingProjectCost>> pendingCosts() async {
    if (pendingFails != null) throw pendingFails!;
    return pending;
  }

  @override
  Future<List<Project>> getProjects({String? status, String? priority, String? search, String? department, bool ownerOnly = false}) async => const [];
}

Project _project({
  String costStatus = 'pending',
  Map<String, dynamic>? cost = const {'budget': 125000, 'approvedBudget': 0},
  Map<String, dynamic> access = const {'canSeeCost': true},
  String status = 'planning',
}) => Project.fromJson({
  '_id': 'p1',
  'name': 'Website redesign',
  'status': status,
  'targetDepartment': 'Marketing',
  'managerId': {'_id': 'm1', 'name': 'Mira'},
  'costStatus': costStatus,
  'cost': cost,
  'access': {'role': 'manager', 'canManage': true, ...access},
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

/// A button that opens [open] — so a dialog can be tried on its own.
Widget _host(Future<Object?> Function(BuildContext, WidgetRef) open) => Consumer(
  builder: (context, ref, _) => FilledButton(onPressed: () => open(context, ref), child: const Text('open')),
);

Finder _k(String key) => find.byKey(Key(key));
Future<void> _tap(WidgetTester t, Finder f) async {
  await t.ensureVisible(f);
  await t.pumpAndSettle();
  await t.tap(f);
  await t.pumpAndSettle();
}

String _field(WidgetTester t, String key) => t.widget<TextField>(_k(key)).controller!.text;

void main() {
  group('amounts', () {
    test('rupees, grouped the Indian way', () {
      expect(rupees(0), '₹0');
      expect(rupees(999), '₹999');
      expect(rupees(1000), '₹1,000');
      expect(rupees(125000), '₹1,25,000');
      expect(rupees(12345678), '₹1,23,45,678');
      expect(rupees(1250.5), '₹1,250.50');
      expect(rupees(100000), '₹1,00,000');
    });

    test('an amount a person typed', () {
      expect(parseAmount('1,25,000'), 125000);
      expect(parseAmount('₹ 500'), 500);
      expect(parseAmount('1250.5'), 1250.5);
      for (final bad in ['', '  ', 'abc', '-5', '1.2.3']) {
        expect(parseAmount(bad), isNull, reason: bad);
      }
    });

    test('a cost input: a breakdown\'s total, else the typed amount; only above zero is valid', () {
      expect(const CostInput(typed: 500).total, 500);
      expect(const CostInput(typed: 500).valid, isTrue);
      expect(const CostInput().valid, isFalse);
      expect(const CostInput(typed: 0).valid, isFalse);
      const withLines = CostInput(
        typed: 1,
        plan: [
          CostLine(category: 'tools', amount: 300),
          CostLine(category: 'other', amount: 200),
        ],
      );
      expect(withLines.total, 500, reason: 'the breakdown wins over a typed amount');
    });

    test('every cost status has words', () {
      expect(costStatusLook('pending').label, 'Awaiting finance approval');
      expect(costStatusLook('approved').label, 'Cost approved');
      expect(costStatusLook('returned').label, 'Sent back by Finance');
      expect(costStatusLook('none').label, 'No cost set');
      expect(costStatusLook('whatever').label, 'No cost set');
    });

    test('the kinds of cost match the server\'s', () {
      expect(projectCostCategories.map((c) => c.$1), ['manpower', 'vendors', 'tools', 'travel', 'marketing', 'other']);
      expect(costCategoryLabel('vendors'), 'Vendors & services');
      expect(costCategoryLabel('mystery'), 'Other');
    });
  });

  group('reading a project\'s cost', () {
    test('status, amounts, breakdown, note, changes and what this person may do', () {
      final p = Project.fromJson({
        '_id': 'p',
        'name': 'x',
        'costStatus': 'pending',
        'cost': {
          'budget': 150000,
          'approvedBudget': 95000,
          'estimatedValue': 500000,
          'plan': [
            {'category': 'manpower', 'amount': 90000, 'note': 'two designers'},
            {'category': 'tools', 'amount': 60000},
          ],
          'note': 'Tools already licensed',
          'changes': [
            {
              'at': '2026-11-10T08:00:00.000Z',
              'byName': 'Mira',
              'reason': 'Scope grew',
              'lines': ['Estimated cost ₹1,10,000 → ₹1,50,000'],
            },
            {'at': 'not a date'},
          ],
        },
        'access': {'canSeeCost': true, 'canEditCost': true, 'canDecideCost': true},
      });
      expect(p.costStatus, 'pending');
      expect(p.costWaiting, isTrue);
      expect(p.mayStart, isFalse);
      final c = p.cost!;
      expect(c.budget, 150000);
      expect(c.approvedBudget, 95000);
      expect(c.hasApproval, isTrue);
      expect(c.estimatedValue, 500000);
      expect(c.plan.map((l) => (l.category, l.amount, l.note)), [('manpower', 90000.0, 'two designers'), ('tools', 60000.0, '')]);
      expect(c.note, 'Tools already licensed');
      expect(c.changes, hasLength(1), reason: 'a change with no usable date is dropped');
      expect(c.changes.single.reason, 'Scope grew');
      expect(p.access.canSeeCost && p.access.canEditCost && p.access.canDecideCost, isTrue);
    });

    test('someone who may not see money gets only the status', () {
      final p = Project.fromJson({
        '_id': 'p',
        'name': 'x',
        'costStatus': 'approved',
        'cost': null,
        'access': {'role': 'member'},
      });
      expect(p.cost, isNull);
      expect(p.costApproved, isTrue);
      expect(p.mayStart, isTrue);
      expect(p.access.canSeeCost, isFalse);
      expect(p.access.canEditCost, isFalse);
      expect(p.access.canDecideCost, isFalse);
    });

    test('a project from before costs existed: status none, and it may start', () {
      final p = Project.fromJson({'_id': 'p', 'name': 'x'});
      expect(p.costStatus, 'none');
      expect(p.mayStart, isTrue);
      expect(p.cost, isNull);
    });

    test('a project sent back may not start either', () {
      expect(_project(costStatus: 'returned').mayStart, isFalse);
      expect(_project(costStatus: 'returned').costReturned, isTrue);
    });
  });

  group('the cost section of a form', () {
    CostInput? last;
    Future<void> open(WidgetTester t, {CostInput initial = const CostInput(), bool showError = false}) async {
      last = null;
      await _pump(t, ProjectCostFields(initial: initial, showError: showError, onChanged: (v) => last = v));
    }

    testWidgets('one amount, which can be typed with commas', (tester) async {
      await open(tester);
      await tester.enterText(_k('cost_total'), '1,25,000');
      expect(last!.typed, 125000);
      expect(last!.valid, isTrue);
      expect(last!.plan, isEmpty);
    });

    testWidgets('only digits, commas and a point can be typed', (tester) async {
      await open(tester);
      await tester.enterText(_k('cost_total'), '12ab34');
      expect(_field(tester, 'cost_total'), '1234');
    });

    testWidgets('nothing typed is not valid', (tester) async {
      await open(tester);
      await tester.enterText(_k('cost_total'), '0');
      expect(last!.valid, isFalse);
    });

    testWidgets('a breakdown: its lines add up to the amount, which can no longer be typed over', (tester) async {
      await open(tester);
      await _tap(tester, _k('cost_breakdown_toggle'));
      expect(_k('cost_line_0'), findsOneWidget, reason: 'opening it gives the first line');
      await tester.enterText(_k('cost_line_amount_0'), '60,000');
      await _tap(tester, _k('cost_add_line'));
      await tester.enterText(_k('cost_line_amount_1'), '15500.50');
      expect(_field(tester, 'cost_total'), '75500.50');
      expect(tester.widget<TextField>(_k('cost_total')).readOnly, isTrue);
      expect(last!.total, 75500.5);
      expect(last!.plan.map((l) => l.amount), [60000, 15500.5]);
    });

    testWidgets('each line has a kind of cost', (tester) async {
      await open(tester);
      await _tap(tester, _k('cost_breakdown_toggle'));
      await tester.enterText(_k('cost_line_amount_0'), '1000');
      await _tap(tester, _k('cost_line_cat_0'));
      await _tap(tester, find.text('Tools & software').last);
      expect(last!.plan.single.category, 'tools');
    });

    testWidgets('an empty line counts for nothing; removing every line gives the amount back', (tester) async {
      await open(tester);
      await _tap(tester, _k('cost_breakdown_toggle'));
      await _tap(tester, _k('cost_add_line'));
      await tester.enterText(_k('cost_line_amount_1'), '500');
      expect(last!.plan, hasLength(1), reason: 'the empty first line is left out');
      await _tap(tester, _k('cost_line_remove_1'));
      expect(last!.plan, isEmpty);
      expect(tester.widget<TextField>(_k('cost_total')).readOnly, isFalse);
      await tester.enterText(_k('cost_total'), '700');
      expect(last!.typed, 700);
    });

    testWidgets('twelve lines at most', (tester) async {
      await open(tester);
      await _tap(tester, _k('cost_breakdown_toggle'));
      for (var i = 0; i < 11; i++) {
        await _tap(tester, _k('cost_add_line'));
      }
      expect(find.byKey(const Key('cost_add_line')), findsNothing);
      expect(
        find.byWidgetPredicate(
          (w) =>
              w.key.toString().startsWith("[<'cost_line_") &&
              !w.key.toString().contains('_cat_') &&
              !w.key.toString().contains('_amount_') &&
              !w.key.toString().contains('_remove_'),
        ),
        findsNWidgets(12),
      );
    });

    testWidgets('a cost that already has a breakdown opens with it', (tester) async {
      await open(
        tester,
        initial: const CostInput(
          plan: [
            CostLine(category: 'travel', amount: 4000),
            CostLine(category: 'other', amount: 1000),
          ],
        ),
      );
      expect(_k('cost_line_1'), findsOneWidget);
      expect(_field(tester, 'cost_line_amount_0'), '4000');
      expect(_field(tester, 'cost_total'), '5000');
    });

    testWidgets('after a try to save without a cost the field says so', (tester) async {
      await open(tester, showError: true);
      expect(find.text('Enter the estimated cost of this project'), findsOneWidget);
    });

    testWidgets('and the helper says Finance approves it', (tester) async {
      await open(tester);
      expect(find.textContaining('finance head approves it before the project can start'), findsOneWidget);
    });
  });

  group('the cost card', () {
    testWidgets('a project from before costs existed says nothing to someone who cannot set one', (tester) async {
      await _pump(
        tester,
        ProjectCostCard(
          project: _project(costStatus: 'none', cost: null, access: const {}),
        ),
      );
      expect(_k('project_cost_card'), findsNothing);
      expect(ProjectCostCard.shows(_project(costStatus: 'none', cost: null, access: const {})), isFalse);
    });

    testWidgets('…but offers to set one to the person who runs it', (tester) async {
      final p = _project(costStatus: 'none', cost: const {'budget': 0, 'approvedBudget': 0}, access: const {'canEditCost': true});
      await _pump(tester, ProjectCostCard(project: p));
      expect(_k('project_cost_card'), findsOneWidget);
      expect(find.text('No cost set'), findsOneWidget);
      expect(find.text('Set the cost'), findsOneWidget);
    });

    testWidgets('waiting for Finance: what was asked, no approved amount yet', (tester) async {
      await _pump(tester, ProjectCostCard(project: _project(access: const {'canSeeCost': true, 'canEditCost': true})));
      expect(find.text('Awaiting finance approval'), findsOneWidget);
      expect(tester.widget<Text>(_k('cost_budget')).data, '₹1,25,000');
      expect(_k('cost_approved'), findsNothing);
      expect(find.text('Change the cost'), findsOneWidget);
      expect(find.text('Review & decide'), findsNothing);
    });

    testWidgets('approved: what was asked, what was approved, the breakdown, Finance\'s note and the changes', (tester) async {
      final p = _project(
        costStatus: 'approved',
        status: 'active',
        access: const {'canSeeCost': true},
        cost: {
          'budget': 110000,
          'approvedBudget': 95000,
          'note': 'Tools already licensed',
          'plan': [
            {'category': 'manpower', 'amount': 70000},
            {'category': 'vendors', 'amount': 40000},
          ],
          'changes': [
            {
              'at': '2026-11-10T08:00:00.000Z',
              'byName': 'Mira',
              'reason': 'Scope grew',
              'lines': ['Manpower: ₹60,000 → ₹70,000'],
            },
          ],
        },
      );
      await _pump(tester, ProjectCostCard(project: p));
      expect(find.text('Cost approved'), findsOneWidget);
      expect(tester.widget<Text>(_k('cost_budget')).data, '₹1,10,000');
      expect(tester.widget<Text>(_k('cost_approved')).data, '₹95,000');
      expect(find.text('Approved by Finance'), findsOneWidget);
      expect(find.text('Manpower'), findsOneWidget);
      expect(find.text('Vendors & services'), findsOneWidget);
      expect(tester.widget<Text>(_k('cost_note')).data, 'Finance: Tools already licensed');
      expect(find.textContaining('Mira — Scope grew (Manpower: ₹60,000 → ₹70,000)'), findsOneWidget);
    });

    testWidgets('a change waiting: the earlier approved amount is said to be the limit meanwhile', (tester) async {
      await _pump(tester, ProjectCostCard(project: _project(cost: const {'budget': 150000, 'approvedBudget': 95000})));
      expect(find.text('Limit until the change is approved'), findsOneWidget);
      expect(tester.widget<Text>(_k('cost_approved')).data, '₹95,000');
    });

    testWidgets('sent back: says so, with Finance\'s note, and offers to revise', (tester) async {
      final p = _project(
        costStatus: 'returned',
        cost: const {'budget': 110000, 'approvedBudget': 0, 'note': 'Split out the vendor cost'},
        access: const {'canSeeCost': true, 'canEditCost': true},
      );
      await _pump(tester, ProjectCostCard(project: p));
      expect(find.text('Sent back by Finance'), findsOneWidget);
      expect(tester.widget<Text>(_k('cost_note')).data, 'Finance: Split out the vendor cost');
      expect(find.text('Revise the cost'), findsOneWidget);
    });

    testWidgets('someone who may not see money sees only where it stands — never an amount or a button', (tester) async {
      for (final (status, words) in [
        ('pending', 'waiting for the finance head'),
        ('returned', 'sent the cost back'),
        ('approved', 'The estimated cost is approved.'),
      ]) {
        await tester.pumpWidget(const SizedBox.shrink());
        await _pump(
          tester,
          ProjectCostCard(
            project: _project(costStatus: status, cost: null, access: const {}),
          ),
        );
        expect(find.textContaining(words), findsOneWidget, reason: status);
        expect(find.textContaining('₹'), findsNothing, reason: status);
        expect(find.byType(OutlinedButton), findsNothing);
        expect(find.byType(FilledButton), findsNothing);
      }
    });

    testWidgets('the finance head can decide while it waits', (tester) async {
      await _pump(tester, ProjectCostCard(project: _project(access: const {'canSeeCost': true, 'canDecideCost': true})));
      expect(_k('cost_decide'), findsOneWidget);
      expect(_k('cost_change'), findsNothing, reason: 'Finance decides, it does not edit the manager\'s estimate');
    });

    testWidgets('fits a phone', (tester) async {
      final p = _project(
        costStatus: 'approved',
        access: const {'canSeeCost': true, 'canEditCost': true, 'canDecideCost': true},
        cost: {
          'budget': 110000,
          'approvedBudget': 95000,
          'note': 'A long note from the finance head about why the amount differs from what was asked for',
          'plan': [
            {'category': 'manpower', 'amount': 70000},
            {'category': 'vendors', 'amount': 40000},
          ],
          'changes': [
            {
              'at': '2026-11-10T08:00:00.000Z',
              'byName': 'Mira',
              'reason': 'Scope grew a great deal this month',
              'lines': ['Estimated cost ₹1,10,000 → ₹1,50,000'],
            },
          ],
        },
      );
      await _pump(tester, ProjectCostCard(project: p), size: const Size(360, 900));
      expect(tester.takeException(), isNull);
    });
  });

  group('changing the cost', () {
    Future<_Fake> openChange(WidgetTester tester, Project p, {_Fake? fake}) async {
      final f = await _pump(tester, _host((c, ref) => showChangeCostDialog(c, ref, p)), fake: fake);
      await _tap(tester, find.text('open'));
      return f;
    }

    testWidgets('setting a first cost: sent for approval, with no reason asked', (tester) async {
      final fake = await openChange(tester, _project(costStatus: 'none', cost: const {'budget': 0, 'approvedBudget': 0}));
      expect(find.text('Set the cost'), findsWidgets);
      expect(_k('cost_reason'), findsNothing);
      await tester.enterText(_k('cost_total'), '40000');
      await _tap(tester, _k('cost_save'));
      expect(fake.saves.single, {'id': 'p1', 'budget': 40000.0, 'plan': <dynamic>[], 'reason': ''});
      expect(_k('cost_save'), findsNothing, reason: 'the dialog closed');
    });

    testWidgets('without a cost nothing is sent', (tester) async {
      final fake = await openChange(tester, _project(costStatus: 'none', cost: const {'budget': 0, 'approvedBudget': 0}));
      await _tap(tester, _k('cost_save'));
      expect(fake.saves, isEmpty);
      expect(find.text('Enter the estimated cost of this project'), findsOneWidget);
      expect(_k('cost_save'), findsOneWidget, reason: 'still open');
    });

    testWidgets('it opens with the cost that is there', (tester) async {
      await openChange(tester, _project(cost: const {'budget': 125000, 'approvedBudget': 0}));
      expect(_field(tester, 'cost_total'), '125000');
    });

    testWidgets('a cost that was approved needs a reason, and says the approved amount stays the limit', (tester) async {
      final p = _project(costStatus: 'approved', cost: const {'budget': 110000, 'approvedBudget': 95000});
      final fake = await openChange(tester, p);
      expect(find.textContaining('₹95,000 stays the limit until it is approved'), findsOneWidget);
      await tester.enterText(_k('cost_total'), '150000');
      await _tap(tester, _k('cost_save'));
      expect(fake.saves, isEmpty, reason: 'no reason given');
      expect(find.text('Say why the cost is changing'), findsOneWidget);
      await tester.enterText(_k('cost_reason'), 'Scope grew: two more pages');
      await _tap(tester, _k('cost_save'));
      expect(fake.saves.single['budget'], 150000.0);
      expect(fake.saves.single['reason'], 'Scope grew: two more pages');
    });

    testWidgets('a cost sent back is revised without a reason', (tester) async {
      final fake = await openChange(tester, _project(costStatus: 'returned', cost: const {'budget': 110000, 'approvedBudget': 0}));
      expect(find.text('Revise the cost'), findsWidgets);
      expect(_k('cost_reason'), findsNothing);
      await tester.enterText(_k('cost_total'), '100000');
      await _tap(tester, _k('cost_save'));
      expect(fake.saves.single['budget'], 100000.0);
    });

    testWidgets('a breakdown is sent as lines, not as an amount', (tester) async {
      final fake = await openChange(tester, _project(costStatus: 'none', cost: const {'budget': 0, 'approvedBudget': 0}));
      await _tap(tester, _k('cost_breakdown_toggle'));
      await tester.enterText(_k('cost_line_amount_0'), '30000');
      await _tap(tester, _k('cost_save'));
      expect(fake.saves.single['budget'], isNull);
      expect(fake.saves.single['plan'], [('manpower', 30000.0)]);
    });

    testWidgets('Cancel leaves it as it was', (tester) async {
      final fake = await openChange(tester, _project());
      await _tap(tester, _k('cost_cancel'));
      expect(fake.saves, isEmpty);
      expect(_k('cost_save'), findsNothing);
    });

    testWidgets('a failure is said plainly and the dialog stays for another try', (tester) async {
      final fake = _Fake()
        ..failWith = DioException(
          requestOptions: RequestOptions(path: '/x'),
          type: DioExceptionType.connectionError,
        );
      await openChange(tester, _project(), fake: fake);
      await _tap(tester, _k('cost_save'));
      expect(_k('cost_save'), findsOneWidget);
      expect(find.textContaining('DioException'), findsNothing);
    });
  });

  group('the finance head\'s decision', () {
    Future<_Fake> openDecide(WidgetTester tester, {double requested = 100000, double approved = 0, String reason = '', _Fake? fake}) async {
      final f = await _pump(
        tester,
        _host(
          (c, ref) => showCostDecisionDialog(
            c,
            ref,
            id: 'p1',
            name: 'Website redesign',
            department: 'Marketing',
            requested: requested,
            approvedBudget: approved,
            changeReason: reason,
          ),
        ),
        fake: fake,
      );
      await _tap(tester, find.text('open'));
      return f;
    }

    testWidgets('it says who asks for how much', (tester) async {
      await openDecide(tester);
      expect(find.text('Website redesign'), findsOneWidget);
      expect(find.text('Marketing asks for ₹1,00,000.'), findsOneWidget);
      expect(_field(tester, 'decide_amount'), '100000');
    });

    testWidgets('approving as asked needs no note', (tester) async {
      final fake = await openDecide(tester);
      await _tap(tester, _k('decide_confirm'));
      expect(fake.decisions.single, {'id': 'p1', 'approve': true, 'amount': 100000.0, 'note': ''});
    });

    testWidgets('a different amount needs a reason, and then goes', (tester) async {
      final fake = await openDecide(tester);
      await tester.enterText(_k('decide_amount'), '80000');
      await tester.pumpAndSettle();
      expect(find.text('Why a different amount? *'), findsOneWidget);
      await _tap(tester, _k('decide_confirm'));
      expect(fake.decisions, isEmpty);
      expect(find.text('Say why you approved a different amount'), findsOneWidget);
      await tester.enterText(_k('decide_note'), 'Tools already licensed');
      await _tap(tester, _k('decide_confirm'));
      expect(fake.decisions.single['amount'], 80000.0);
      expect(fake.decisions.single['note'], 'Tools already licensed');
    });

    testWidgets('an amount of zero, or none, is refused', (tester) async {
      final fake = await openDecide(tester);
      await tester.enterText(_k('decide_amount'), '0');
      await tester.enterText(_k('decide_note'), 'because');
      await _tap(tester, _k('decide_confirm'));
      expect(fake.decisions, isEmpty);
      expect(find.text('Enter an amount above zero'), findsOneWidget);
    });

    testWidgets('sending back hides the amount, and needs to say what to change', (tester) async {
      final fake = await openDecide(tester);
      await _tap(tester, find.text('Send back').first);
      expect(_k('decide_amount'), findsNothing);
      expect(find.text('What should be changed? *'), findsOneWidget);
      await _tap(tester, _k('decide_confirm'));
      expect(fake.decisions, isEmpty);
      expect(find.text('Say what should be changed'), findsOneWidget);
      await tester.enterText(_k('decide_note'), 'Split out the vendor cost');
      await _tap(tester, _k('decide_confirm'));
      expect(fake.decisions.single, {'id': 'p1', 'approve': false, 'amount': null, 'note': 'Split out the vendor cost'});
    });

    testWidgets('a change after approval shows what was approved and the reason given', (tester) async {
      await openDecide(tester, requested: 150000, approved: 95000, reason: 'Scope grew');
      expect(find.text('This is a change: ₹95,000 is approved so far.'), findsOneWidget);
      expect(find.text('Reason given: Scope grew'), findsOneWidget);
    });

    testWidgets('Cancel decides nothing', (tester) async {
      final fake = await openDecide(tester);
      await _tap(tester, _k('decide_cancel'));
      expect(fake.decisions, isEmpty);
    });

    testWidgets('a failure is said plainly and the dialog stays', (tester) async {
      final fake = _Fake()
        ..failWith = DioException(
          requestOptions: RequestOptions(path: '/x'),
          type: DioExceptionType.connectionError,
        );
      await openDecide(tester, fake: fake);
      await _tap(tester, _k('decide_confirm'));
      expect(_k('decide_confirm'), findsOneWidget);
      expect(find.textContaining('DioException'), findsNothing);
    });
  });

  group('Finance\'s Project budgets', () {
    PendingProjectCost row(
      String id, {
      double budget = 100000,
      double approved = 0,
      bool change = false,
      bool canDecide = true,
      String reason = '',
      List<String> lines = const [],
    }) => PendingProjectCost(
      id: id,
      name: 'Project $id',
      department: 'Marketing',
      managerName: 'Mira',
      requestedByName: 'Mira',
      requestedAt: DateTime(2026, 11, 9),
      startDate: DateTime(2026, 11, 20),
      endDate: DateTime(2026, 12, 20),
      budget: budget,
      approvedBudget: approved,
      plan: const [
        CostLine(category: 'manpower', amount: 60000),
        CostLine(category: 'tools', amount: 40000),
      ],
      isChange: change,
      changeReason: reason,
      changeLines: lines,
      canDecide: canDecide,
    );

    Future<_Fake> open(WidgetTester tester, List<PendingProjectCost> rows, {Object? error}) async {
      final fake = _Fake()
        ..pending = rows
        ..pendingFails = error;
      await _pump(tester, const SizedBox(height: 1400, child: ProjectBudgetsScreen()), fake: fake);
      return fake;
    }

    testWidgets('lists what waits: who, how much, the breakdown, and a button to decide', (tester) async {
      await open(tester, [row('a'), row('b', budget: 50000)]);
      expect(tester.widget<Text>(_k('pb_count')).data, '2 waiting');
      expect(find.text('Project a'), findsOneWidget);
      expect(tester.widget<Text>(_k('pb_budget_a')).data, '₹1,00,000');
      expect(tester.widget<Text>(_k('pb_budget_b')).data, '₹50,000');
      expect(find.textContaining('Marketing · managed by Mira · asked by Mira · 9 Nov 2026'), findsWidgets);
      expect(find.text('Manpower'), findsWidgets);
      expect(_k('pb_decide_a'), findsOneWidget);
      expect(find.text('Change'), findsNothing);
    });

    testWidgets('a change shows the approved amount, the reason and what moved', (tester) async {
      await open(tester, [
        row('a', budget: 150000, approved: 95000, change: true, reason: 'Scope grew', lines: ['Estimated cost ₹1,10,000 → ₹1,50,000']),
      ]);
      expect(find.text('Change'), findsOneWidget);
      expect(tester.widget<Text>(_k('pb_approved_a')).data, '₹95,000');
      expect(find.text('Why: Scope grew'), findsOneWidget);
      expect(find.text('• Estimated cost ₹1,10,000 → ₹1,50,000'), findsOneWidget);
    });

    testWidgets('someone who may look but not decide (Accounts) sees no button', (tester) async {
      await open(tester, [row('a', canDecide: false)]);
      expect(_k('pb_decide_a'), findsNothing);
      expect(_k('pb_view_only_a'), findsOneWidget);
    });

    testWidgets('deciding opens the decision, and a decided one leaves the list', (tester) async {
      final fake = await open(tester, [row('a'), row('b')]);
      await _tap(tester, _k('pb_decide_a'));
      expect(find.text('Marketing asks for ₹1,00,000.'), findsOneWidget);
      await _tap(tester, _k('decide_confirm'));
      expect(fake.decisions.single['id'], 'a');
      expect(find.text('Project a'), findsNothing);
      expect(find.text('Project b'), findsOneWidget);
      expect(tester.widget<Text>(_k('pb_count')).data, '1 waiting');
    });

    testWidgets('nothing waiting says so', (tester) async {
      await open(tester, const []);
      expect(_k('pb_empty'), findsOneWidget);
      expect(find.text('Nothing is waiting for a decision.'), findsOneWidget);
    });

    testWidgets('a failure is said plainly, with a retry', (tester) async {
      await open(
        tester,
        const [],
        error: DioException(
          requestOptions: RequestOptions(path: '/x'),
          type: DioExceptionType.connectionError,
        ),
      );
      expect(find.byType(AppErrorView), findsOneWidget);
      expect(find.textContaining('DioException'), findsNothing);
    });

    testWidgets('fits a phone', (tester) async {
      final fake = _Fake()
        ..pending = [
          row(
            'a',
            budget: 150000,
            approved: 95000,
            change: true,
            reason: 'Scope grew a great deal this month',
            lines: ['Estimated cost ₹1,10,000 → ₹1,50,000'],
          ),
        ];
      await _pump(
        tester,
        const SizedBox(height: 1400, child: ProjectBudgetsScreen()),
        fake: fake,
        size: const Size(360, 1400),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
