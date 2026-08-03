import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:nizan_crm/features/accounts/data/admin_expense.dart';
import 'package:nizan_crm/features/accounts/services/admin_expense_service.dart';
import 'package:nizan_crm/providers/dio_provider.dart';

final adminExpenseServiceProvider = Provider<AdminExpenseService>((ref) {
  return AdminExpenseService(ref.watch(dioProvider));
});

class AdminExpenseFilter {
  final String department;
  final String category;
  final String status;
  final String search;
  final DateTime? startDate;
  final DateTime? endDate;

  const AdminExpenseFilter({
    this.department = 'All',
    this.category = 'All',
    this.status = 'all',
    this.search = '',
    this.startDate,
    this.endDate,
  });

  AdminExpenseFilter copyWith({
    String? department,
    String? category,
    String? status,
    String? search,
    DateTime? startDate,
    DateTime? endDate,
    bool clearDates = false,
  }) {
    return AdminExpenseFilter(
      department: department ?? this.department,
      category: category ?? this.category,
      status: status ?? this.status,
      search: search ?? this.search,
      startDate: clearDates ? null : (startDate ?? this.startDate),
      endDate: clearDates ? null : (endDate ?? this.endDate),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AdminExpenseFilter &&
          runtimeType == other.runtimeType &&
          department == other.department &&
          category == other.category &&
          status == other.status &&
          search == other.search &&
          startDate == other.startDate &&
          endDate == other.endDate;

  @override
  int get hashCode =>
      department.hashCode ^
      category.hashCode ^
      status.hashCode ^
      search.hashCode ^
      startDate.hashCode ^
      endDate.hashCode;
}

final adminExpenseFilterProvider =
    StateProvider<AdminExpenseFilter>((ref) => const AdminExpenseFilter());

final adminExpensesProvider = FutureProvider<List<AdminExpense>>((ref) async {
  final filter = ref.watch(adminExpenseFilterProvider);
  final service = ref.watch(adminExpenseServiceProvider);
  return service.getAdminExpenses(
    department: filter.department,
    category: filter.category,
    status: filter.status,
    search: filter.search,
    startDate: filter.startDate,
    endDate: filter.endDate,
  );
});

final adminExpenseStatsProvider = FutureProvider<AdminExpenseStats>((ref) async {
  final service = ref.watch(adminExpenseServiceProvider);
  return service.getStats();
});
