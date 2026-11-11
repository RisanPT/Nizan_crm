import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nizan_crm/core/models/list_page_params.dart';
import 'package:nizan_crm/core/models/paginated_list_response.dart';
import 'package:nizan_crm/features/fleet/data/fuel_expense.dart';
import 'package:nizan_crm/features/fleet/data/fuel_expense_page.dart';
import 'package:nizan_crm/providers/dio_provider.dart';
import 'package:nizan_crm/features/fleet/services/fuel_expense_service.dart';

final fuelExpenseServiceProvider = Provider<FuelExpenseService>((ref) {
  return FuelExpenseService(ref.watch(dioProvider));
});

final fuelExpensesProvider = FutureProvider<List<FuelExpense>>((ref) async {
  return ref.watch(fuelExpenseServiceProvider).getFuelExpenses();
});

/// The expense list for ACCOUNTS: one filtered, sorted page with whole-set totals,
/// each expense with its day's works (client, artist, share) and km check. One cached
/// request per distinct query; the fleet screens use [fuelExpensesProvider] instead.
final accountsFuelExpensePageProvider =
    FutureProvider.autoDispose.family<FuelExpensePage, FuelExpenseQuery>((ref, query) {
  return ref.watch(fuelExpenseServiceProvider).getFuelExpensePage(query);
});

final paginatedFuelExpensesProvider =
    FutureProvider.family<PaginatedListResponse<FuelExpense>, ListPageParams>((
      ref,
      params,
    ) async {
      return ref.watch(fuelExpenseServiceProvider).getPaginatedFuelExpenses(
            page: params.page,
            limit: params.limit,
          );
    });
