import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nizan_crm/features/accounts/data/artist_expense.dart';
import 'package:nizan_crm/providers/dio_provider.dart';
import 'package:nizan_crm/features/accounts/services/expense_service.dart';

final expenseServiceProvider = Provider<ExpenseService>((ref) {
  return ExpenseService(ref.watch(dioProvider));
});

/// All artist expenses (accounts-team view).
final expensesProvider = FutureProvider<List<ArtistExpense>>((ref) async {
  return ref.watch(expenseServiceProvider).getExpenses();
});

/// Expenses scoped to a single artist.
final artistExpensesProvider =
    FutureProvider.family<List<ArtistExpense>, String>((ref, employeeId) async {
  return ref
      .watch(expenseServiceProvider)
      .getExpenses(employeeId: employeeId);
});
