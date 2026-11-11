import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nizan_crm/core/models/auth_session.dart';
import 'package:nizan_crm/core/models/employee.dart';
import 'package:nizan_crm/core/providers/auth_provider.dart';
import 'package:nizan_crm/core/theme/app_theme.dart';
import 'package:nizan_crm/features/accounts/controllers/admin_expense_controller.dart';
import 'package:nizan_crm/features/accounts/data/admin_expense.dart';
import 'package:nizan_crm/features/accounts/presentation/screens/administrative_expenses_screen.dart';
import 'package:nizan_crm/features/accounts/services/admin_expense_service.dart';
import 'package:nizan_crm/features/accounts/services/expense_category_service.dart';
import 'package:nizan_crm/services/employee_service.dart';

// The Administrative Expenses screen and the expense heads: who gets the Heads button, a head Accounts added
// naming the expenses filed under it, and an expense whose head was archived since still opening for edit.

final _active = [
  const ExpenseHead('FOO-01', 'Food Expense', 'Operating Expense', id: '1', system: true),
  const ExpenseHead('COU-01', 'Courier Charges', 'Operating Expense', id: '2', used: 1),
];
final _everything = [..._active, const ExpenseHead('OLD-01', 'Old Head', 'Operating Expense', id: '3', active: false, used: 1)];

AdminExpense _expense(String id, String title, String head) => AdminExpense.fromJson({
      '_id': id,
      'title': title,
      'department': 'Accounts',
      'category': 'other',
      'expenseHead': head,
      'amount': 250,
      'date': '2026-11-01T10:00:00.000Z',
      'status': 'approved',
      'paymentMethod': 'cash',
    });

Future<void> _open(WidgetTester tester, {String role = 'accounts', Size size = const Size(1500, 1100)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authSessionProvider.overrideWithValue(AuthSession(token: 't', userId: 'u', name: 'U', email: 'u@x', role: role)),
        adminExpensesProvider.overrideWith((ref) async => [_expense('e1', 'Courier May', 'COU-01'), _expense('e2', 'Old thing', 'OLD-01')]),
        adminExpenseStatsProvider.overrideWith(
          (ref) async => const AdminExpenseStats(totalCount: 2, totalAmount: 500, thisMonthAmount: 500, pendingCount: 0, pendingAmount: 0, approvedAmount: 500, departmentBreakdown: {}),
        ),
        expenseHeadsProvider.overrideWith((ref) async => _active),
        allExpenseHeadsProvider.overrideWith((ref) async => _everything),
        employeesProvider.overrideWith((ref) async => <Employee>[]),
        expenseCategoriesProvider.overrideWith((ref, dept) async => []),
      ],
      child: MaterialApp(theme: AppTheme.lightTheme, home: const AdministrativeExpensesScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Accounts gets a Heads button that opens the heads manager', (tester) async {
    await _open(tester);
    expect(find.byKey(const Key('manage_heads')), findsOneWidget);
    await tester.tap(find.byKey(const Key('manage_heads')));
    await tester.pumpAndSettle();
    expect(find.text('Manage Expense Heads'), findsOneWidget);
    expect(find.text('Courier Charges'), findsWidgets);
  });

  testWidgets('admin too; on a phone it is a full-width button under the others', (tester) async {
    await _open(tester, role: 'admin', size: const Size(390, 900));
    expect(find.byKey(const Key('manage_heads')), findsNothing, reason: 'the desktop button is not in the phone layout');
    expect(find.byKey(const Key('manage_heads_mobile')), findsOneWidget);
    expect(find.text('Manage expense heads'), findsOneWidget);
  });

  testWidgets('somebody who is not Accounts / admin has no Heads button', (tester) async {
    await _open(tester, role: 'manager');
    expect(find.byKey(const Key('manage_heads')), findsNothing);
    expect(find.byKey(const Key('manage_heads_mobile')), findsNothing);
  });

  testWidgets('expenses are named by the live heads — a head Accounts added, even one archived since', (tester) async {
    await _open(tester);
    expect(find.text('Courier Charges'), findsOneWidget, reason: 'COU-01 is not in the built-in list');
    expect(find.text('Old Head'), findsOneWidget, reason: 'an archived head still names the expense filed under it');
  });

  testWidgets('an expense filed under an ARCHIVED head still opens for editing, with that head selected', (tester) async {
    await _open(tester);
    // the second card is the one under OLD-01 (the first edit pencil belongs to the first card)
    await tester.tap(find.byTooltip('Edit').last);
    await tester.pumpAndSettle();
    // (the test font makes this dialog overflow a little on ANY expense, so only the dropdown's own assertion counts)
    expect('${tester.takeException()}', isNot(contains('exactly one item')), reason: 'a dropdown whose value is not one of its items asserts');
    expect(find.text('OLD-01 · Old Head'), findsOneWidget);
  });
}
