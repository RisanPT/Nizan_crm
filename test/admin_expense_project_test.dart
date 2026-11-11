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
import 'package:nizan_crm/features/accounts/controllers/admin_expense_controller.dart';
import 'package:nizan_crm/features/accounts/data/admin_expense.dart';
import 'package:nizan_crm/features/accounts/presentation/screens/administrative_expenses_screen.dart';
import 'package:nizan_crm/features/accounts/services/admin_expense_service.dart';
import 'package:nizan_crm/features/accounts/services/expense_category_service.dart';
import 'package:nizan_crm/features/finance/presentation/widgets/money_account_picker.dart';
import 'package:nizan_crm/features/finance/services/bank_account_service.dart';
import 'package:nizan_crm/features/it/data/project.dart';
import 'package:nizan_crm/features/it/data/project_spend.dart';
import 'package:nizan_crm/features/it/services/it_service.dart';
import 'package:nizan_crm/services/employee_service.dart';

// Administrative Expenses ↔ projects: an expense can be charged to a project whose cost the finance head approved; one that
// would take the project past its budget is refused to Accounts, and the finance head says why and it goes through; the
// list shows which project an expense is on.

class _Expenses extends AdminExpenseService {
  _Expenses() : super(Dio());
  final created = <Map<String, dynamic>>[];
  final updated = <String, Map<String, dynamic>>{};
  final verified = <Map<String, dynamic>>[];

  /// Refuse the first call this way (a 409 from the server), then accept.
  DioException? refuseOnce;

  AdminExpense _ok(Map<String, dynamic> body, {Map<String, dynamic>? extra}) => AdminExpense.fromJson({
    '_id': 'new',
    'title': body['title'],
    'department': body['department'] ?? 'Accounts',
    'amount': body['amount'],
    'date': '2026-11-05T00:00:00Z',
    'status': 'pending',
    'projectId': body['projectId'],
    'projectName': body['projectId'] == null ? '' : 'Website redesign',
    if (extra != null) ...extra,
  });

  @override
  Future<AdminExpense> createAdminExpense(Map<String, dynamic> payload) async {
    final r = refuseOnce;
    if (r != null) {
      refuseOnce = null;
      created.add({...payload, '_refused': true});
      throw AppException(r);
    }
    created.add(payload);
    return _ok(
      payload,
      extra: {
        if (payload['_warn'] == true) 'warning': {'code': 'OVER_BUDGET', 'after': 111000, 'limit': 100000},
      },
    );
  }

  @override
  Future<AdminExpense> updateAdminExpense(String id, Map<String, dynamic> payload) async {
    updated[id] = payload;
    return _ok(payload);
  }

  @override
  Future<AdminExpense> verifyAdminExpense(String id, String status, {MoneyChoice? money, String? overBudgetReason}) async {
    final r = refuseOnce;
    if (r != null) {
      refuseOnce = null;
      verified.add({'id': id, 'status': status, 'reason': overBudgetReason, '_refused': true});
      throw AppException(r);
    }
    verified.add({'id': id, 'status': status, 'reason': overBudgetReason});
    return _ok({'title': 'x', 'amount': 1});
  }
}

class _Projects extends ProjectService {
  _Projects() : super(Dio());
  @override
  Future<List<ChargeableProject>> chargeableProjects() async => const [
    ChargeableProject(id: 'p1', name: 'Website redesign', department: 'Marketing', level: 'ok', limit: 100000, used: 30000, available: 70000),
    ChargeableProject(id: 'p2', name: 'Brand refresh', department: 'Marketing', level: 'warn', limit: 100000, used: 90000, available: 10000),
  ];

  @override
  Future<List<Project>> getProjects({String? status, String? priority, String? search, String? department, bool ownerOnly = false}) async => const [];
}

DioException _refusal(String code, String message) => DioException(
  requestOptions: RequestOptions(path: '/x'),
  response: Response(
    requestOptions: RequestOptions(path: '/x'),
    statusCode: 409,
    data: {'code': code, 'message': message, 'limit': 100000, 'used': 90000, 'after': 120000},
  ),
  type: DioExceptionType.badResponse,
);

AdminExpense _listed(String id, String title, {String project = '', String projectId = '', String status = 'pending', double amount = 25000}) =>
    AdminExpense.fromJson({
      '_id': id,
      'title': title,
      'department': 'Marketing',
      'category': 'other',
      'expenseHead': 'FOO-01',
      'amount': amount,
      'date': '2026-11-01T10:00:00.000Z',
      'status': status,
      'paymentMethod': 'cash',
      // what the form insists on, so an expense from the list can be saved again
      'vendor': 'Shutterstock',
      'paidByName': 'Shutterstock',
      'invoiceNumber': 'INV-1',
      'receiptImage': 'https://example.com/bill.pdf',
      'projectId': projectId,
      'projectName': project,
    });

final _heads = [const ExpenseHead('FOO-01', 'Food Expense', 'Operating Expense', id: '1', system: true)];

Future<(_Expenses, _Projects)> _open(WidgetTester tester, {String role = 'accounts', List<AdminExpense> listed = const []}) async {
  final expenses = _Expenses();
  final projects = _Projects();
  tester.view.physicalSize = const Size(1500, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  // The test font is wider than the real one, so the existing expense form overflows a row or two here. That is not what is
  // under test: overflow is ignored, every other error still fails the test.
  final previous = FlutterError.onError;
  FlutterError.onError = (d) {
    if (d.exceptionAsString().contains('overflowed')) return;
    previous?.call(d);
  };
  addTearDown(() => FlutterError.onError = previous);
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: <Override>[
        authSessionProvider.overrideWithValue(AuthSession(token: 't', userId: 'u', name: 'U', email: 'u@x', role: role)),
        adminExpenseServiceProvider.overrideWithValue(expenses),
        projectServiceProvider.overrideWithValue(projects),
        adminExpensesProvider.overrideWith((ref) async => listed),
        adminExpenseStatsProvider.overrideWith(
          (ref) async => const AdminExpenseStats(
            totalCount: 1,
            totalAmount: 0,
            thisMonthAmount: 0,
            pendingCount: 0,
            pendingAmount: 0,
            approvedAmount: 0,
            departmentBreakdown: {},
          ),
        ),
        expenseHeadsProvider.overrideWith((ref) async => _heads),
        allExpenseHeadsProvider.overrideWith((ref) async => _heads),
        employeesProvider.overrideWith((ref) async => <Employee>[]),
        expenseCategoriesProvider.overrideWith((ref, dept) async => []),
        // approving asks which account paid it: none set up, so it just confirms
        bankAccountsProvider.overrideWith((ref) async => const BankAccountsResult(accounts: [], totalBalance: 0)),
      ],
      child: MaterialApp(theme: AppTheme.lightTheme, home: const AdministrativeExpensesScreen()),
    ),
  );
  await tester.pumpAndSettle();
  return (expenses, projects);
}

Finder _k(String key) => find.byKey(Key(key));

/// The "Charge to a project" dropdown (the form has other dropdowns of the same type).
final _chargeDropdown = find.byWidgetPredicate((w) => w.key.toString().contains('charge_project_') && !w.key.toString().contains('note'));
Future<void> _tap(WidgetTester t, Finder f) async {
  await t.ensureVisible(f);
  await t.pumpAndSettle();
  await t.tap(f);
  await t.pumpAndSettle();
}

/// Opens the form and fills what it needs: a title, a head, a vendor and an amount.
Future<void> _fill(WidgetTester tester, {String amount = '20000', String? project}) async {
  await _tap(tester, find.text('Record Expense').first);
  await tester.enterText(find.widgetWithText(TextFormField, 'Expense Title *'), 'Stock photos');
  await tester.enterText(find.widgetWithText(TextFormField, 'Vendor / Payee *'), 'Shutterstock');
  await tester.enterText(find.widgetWithText(TextFormField, 'Amount (₹) *'), amount);
  await tester.enterText(find.widgetWithText(TextFormField, 'Vendor / Payee Name'), 'Shutterstock'); // who was paid (no staff member)
  await tester.enterText(find.widgetWithText(TextFormField, 'Invoice / Bill # *'), 'INV-1');
  await tester.enterText(find.widgetWithText(TextFormField, 'Receipt / Bill URL *'), 'https://example.com/bill.pdf');
  await _tap(tester, find.widgetWithText(DropdownButtonFormField<String>, 'Expense Head *'));
  await _tap(tester, find.textContaining('Food Expense').last);
  if (project != null) {
    await _tap(tester, _chargeDropdown);
    await _tap(tester, find.text(project).last);
  }
}

Future<void> _save(WidgetTester tester) async {
  await _tap(tester, find.text('Save Expense'));
}

void main() {
  group('filing an expense', () {
    testWidgets('the form offers the projects, with what is left of the one chosen', (tester) async {
      await _open(tester);
      await _fill(tester, amount: '20000', project: 'Website redesign · Marketing');
      expect(find.textContaining('₹70,000 left of the approved ₹1,00,000'), findsOneWidget);
    });

    testWidgets('charged to a project: its id goes with the expense', (tester) async {
      final (expenses, _) = await _open(tester);
      await _fill(tester, project: 'Website redesign · Marketing');
      await _save(tester);
      expect(expenses.created.single['projectId'], 'p1');
      expect(expenses.created.single['amount'], 20000.0);
    });

    testWidgets('with no project nothing about a project is sent', (tester) async {
      final (expenses, _) = await _open(tester);
      await _fill(tester);
      await _save(tester);
      expect(expenses.created.single.containsKey('projectId'), isFalse);
    });

    testWidgets('an expense that takes the project over: Accounts is told, and nothing is saved', (tester) async {
      final (expenses, _) = await _open(tester);
      expenses.refuseOnce = _refusal('OVER_BUDGET', 'Only the finance head can approve an expense that goes over the budget.');
      await _fill(tester, amount: '50000', project: 'Brand refresh · Marketing');
      await _save(tester);
      expect(_k('over_budget_dialog'), findsOneWidget);
      expect(find.descendant(of: _k('over_budget_dialog'), matching: find.textContaining('Only the finance head can approve')), findsOneWidget);
      expect(_k('over_reason'), findsNothing);
      await _tap(tester, _k('over_cancel'));
      expect(expenses.created.where((c) => c['_refused'] != true), isEmpty);
    });

    testWidgets('the finance head says why, and it is sent again with the reason', (tester) async {
      final (expenses, _) = await _open(tester, role: 'finance_head');
      expenses.refuseOnce = _refusal('OVER_BUDGET_REASON', 'Say why it is approved over the budget.');
      await _fill(tester, amount: '50000', project: 'Brand refresh · Marketing');
      await _save(tester);
      expect(_k('over_reason'), findsOneWidget);
      await tester.enterText(_k('over_reason'), 'Launch deadline moved up');
      await _tap(tester, _k('over_confirm'));
      final sent = expenses.created.where((c) => c['_refused'] != true).single;
      expect(sent['overBudgetReason'], 'Launch deadline moved up');
      expect(sent['projectId'], 'p2');
      expect(find.text('Save Expense'), findsNothing, reason: 'the form closed');
    });

    testWidgets('cancelling the reason keeps the form open and saves nothing', (tester) async {
      final (expenses, _) = await _open(tester, role: 'finance_head');
      expenses.refuseOnce = _refusal('OVER_BUDGET_REASON', 'Say why.');
      await _fill(tester, amount: '50000', project: 'Brand refresh · Marketing');
      await _save(tester);
      await _tap(tester, _k('over_cancel'));
      expect(expenses.created.where((c) => c['_refused'] != true), isEmpty);
      expect(find.text('Save Expense'), findsOneWidget);
    });

    testWidgets('a different refusal is shown as an ordinary error, not as a budget question', (tester) async {
      final (expenses, _) = await _open(tester);
      expenses.refuseOnce = _refusal('PROJECT_NOT_APPROVED', 'The finance head has not approved the cost yet.');
      await _fill(tester, project: 'Website redesign · Marketing');
      await _save(tester);
      expect(_k('over_budget_dialog'), findsNothing);
    });
  });

  group('approving an expense that is charged to a project', () {
    Future<void> approve(WidgetTester tester) async {
      await _tap(tester, find.widgetWithText(FilledButton, 'Approve').first);
      await _tap(tester, find.widgetWithText(FilledButton, 'Approve').last); // the account picker's own Approve
    }

    final one = [_listed('e1', 'Launch ads', project: 'Brand refresh', projectId: 'p2')];

    testWidgets('within the budget it simply goes through', (tester) async {
      final (expenses, _) = await _open(tester, listed: one);
      await approve(tester);
      expect(expenses.verified.single, {'id': 'e1', 'status': 'approved', 'reason': null});
    });

    testWidgets('over the budget: Accounts is told it is the finance head\'s to approve, and nothing is approved', (tester) async {
      final (expenses, _) = await _open(tester, listed: one);
      expenses.refuseOnce = _refusal('OVER_BUDGET', 'Only the finance head can approve an expense that goes over the budget.');
      await approve(tester);
      expect(_k('over_budget_dialog'), findsOneWidget);
      expect(find.textContaining('Only the finance head can approve'), findsOneWidget);
      expect(_k('over_reason'), findsNothing);
      await _tap(tester, _k('over_cancel'));
      expect(expenses.verified.where((v) => v['_refused'] != true), isEmpty);
    });

    testWidgets('the finance head says why, and it is approved with the reason', (tester) async {
      final (expenses, _) = await _open(tester, role: 'finance_head', listed: one);
      expenses.refuseOnce = _refusal('OVER_BUDGET_REASON', 'Say why it is approved over the budget.');
      await approve(tester);
      await tester.enterText(_k('over_reason'), 'Launch deadline moved up');
      await _tap(tester, _k('over_confirm'));
      final done = expenses.verified.where((v) => v['_refused'] != true).single;
      expect(done['status'], 'approved');
      expect(done['reason'], 'Launch deadline moved up');
    });

    testWidgets('cancelling the reason approves nothing', (tester) async {
      final (expenses, _) = await _open(tester, role: 'finance_head', listed: one);
      expenses.refuseOnce = _refusal('OVER_BUDGET_REASON', 'Say why.');
      await approve(tester);
      await _tap(tester, _k('over_cancel'));
      expect(expenses.verified.where((v) => v['_refused'] != true), isEmpty);
    });
  });

  group('the list', () {
    testWidgets('says which project an expense is charged to', (tester) async {
      await _open(
        tester,
        listed: [
          _listed('e1', 'Launch ads', project: 'Brand refresh', projectId: 'p2'),
          _listed('e2', 'Paper'),
        ],
      );
      expect(find.text('Brand refresh'), findsOneWidget);
      expect(_k('exp_project_e1'), findsOneWidget);
      expect(_k('exp_project_e2'), findsNothing);
    });

    testWidgets('editing an expense that is on a project opens with it chosen, and can take it off', (tester) async {
      final (expenses, _) = await _open(
        tester,
        listed: [_listed('e1', 'Launch ads', project: 'Website redesign', projectId: 'p1')],
      );
      await _tap(tester, find.byIcon(Icons.edit_outlined).first);
      expect(find.text('Update Expense'), findsOneWidget);
      expect(find.textContaining('₹70,000 left'), findsOneWidget);
      await _tap(tester, _chargeDropdown);
      await _tap(tester, find.text('No project').last);
      await _tap(tester, find.text('Update Expense'));
      expect(expenses.updated['e1']!.containsKey('projectId'), isTrue);
      expect(expenses.updated['e1']!['projectId'], isNull, reason: 'taken off its project');
    });
  });

  group('reading an expense', () {
    test('the project it is charged to, and the reason it was approved over the budget', () {
      final e = AdminExpense.fromJson({
        '_id': 'x',
        'title': 't',
        'amount': 1,
        'projectId': 'p1',
        'projectName': 'Website redesign',
        'overBudgetReason': 'Launch',
      });
      expect(e.hasProject, isTrue);
      expect(e.projectId, 'p1');
      expect(e.projectName, 'Website redesign');
      expect(e.overBudgetReason, 'Launch');
      expect(e.budgetWarning, isNull);
    });

    test('a populated project reference reads as its id', () {
      final e = AdminExpense.fromJson({
        '_id': 'x',
        'title': 't',
        'amount': 1,
        'projectId': {'_id': 'p9', 'name': 'x'},
      });
      expect(e.projectId, 'p9');
    });

    test('no project: nothing', () {
      final e = AdminExpense.fromJson({'_id': 'x', 'title': 't', 'amount': 1, 'projectId': null});
      expect(e.hasProject, isFalse);
      expect(e.projectId, '');
    });

    test('the warning that comes back when a department expense goes over its project\'s budget', () {
      final e = AdminExpense.fromJson({
        '_id': 'x',
        'title': 't',
        'amount': 1,
        'projectName': 'Website redesign',
        'warning': {'code': 'OVER_BUDGET', 'after': 111000, 'limit': 100000},
      });
      expect(e.budgetWarning, 'It takes Website redesign to ₹1,11,000 of its approved ₹1,00,000. Only the finance head can approve it.');
    });
  });
}
