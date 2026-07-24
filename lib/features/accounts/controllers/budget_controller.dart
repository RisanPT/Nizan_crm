import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nizan_crm/features/accounts/data/budget.dart';
import 'package:nizan_crm/providers/dio_provider.dart';
import 'package:nizan_crm/features/accounts/services/budget_service.dart';

final budgetServiceProvider = Provider<BudgetService>((ref) {
  return BudgetService(ref.watch(dioProvider));
});

final currentBudgetProvider = FutureProvider<Budget?>((ref) async {
  final service = ref.watch(budgetServiceProvider);
  final now = DateTime.now();
  final budgets = await service.getBudgets(month: now.month, year: now.year);
  if (budgets.isNotEmpty) {
    return budgets.first; // Returning 'General' or first budget found
  }
  return null;
});
