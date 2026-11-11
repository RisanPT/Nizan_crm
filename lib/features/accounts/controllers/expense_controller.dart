import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nizan_crm/features/accounts/data/artist_expense.dart';
import 'package:nizan_crm/features/accounts/data/finance_list.dart';
import 'package:nizan_crm/features/accounts/data/work_cost.dart';
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

/// ACCOUNTS: one filtered, sorted page of artist expenses with whole-set totals.
final financeExpensesPageProvider =
    FutureProvider.autoDispose.family<FinancePage<ArtistExpense>, FinanceQuery>((ref, query) {
  return ref.watch(expenseServiceProvider).getExpensePage(query);
});

/// While adding a meal: which of the artist's works that day it would be counted under.
/// Keyed by the meal's instant (ISO), the meal — or several, comma-separated ("breakfast,lunch,dinner")
/// when one bill covers more than one — and, when Accounts adds for someone, the artist.
/// [bookingId] is the work the artist chose ('' = let the app pick), [excludeId] an expense being
/// edited ('' = none) — left out of what the team has already logged.
typedef MealPreviewKey = ({String at, String meal, String employeeId, String bookingId, String excludeId});
final mealPreviewProvider = FutureProvider.autoDispose.family<MealPreview, MealPreviewKey>((ref, key) {
  return ref.watch(expenseServiceProvider).getMealPreview(
        at: DateTime.parse(key.at),
        meal: key.meal,
        employeeId: key.employeeId.isEmpty ? null : key.employeeId,
        bookingId: key.bookingId.isEmpty ? null : key.bookingId,
        excludeId: key.excludeId.isEmpty ? null : key.excludeId,
      );
});

/// One artist's day as a timeline (works in order, the costs under each).
typedef ArtistDayKey = ({String employeeId, String day});
final artistDayProvider = FutureProvider.autoDispose.family<ArtistDay, ArtistDayKey>((ref, key) {
  return ref.watch(expenseServiceProvider).getArtistDay(employeeId: key.employeeId, day: key.day);
});

/// ACCOUNTS: what each work cost over a period, with the artists' food placed by the time of the meal.
final workCostsPageProvider = FutureProvider.autoDispose.family<WorkCostPage, WorkCostQuery>((ref, query) {
  return ref.watch(expenseServiceProvider).getWorkCosts(query);
});
