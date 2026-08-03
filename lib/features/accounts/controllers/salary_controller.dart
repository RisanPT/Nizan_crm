import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:nizan_crm/features/accounts/services/salary_service.dart';

class SalaryFilter {
  final int month;
  final int year;
  final String category; // 'all' | 'administrative' | 'operations'
  final String department; // 'All' | specific
  final String status; // 'all' | 'approved_by_hr' | 'paid' | 'draft'
  final String search;

  SalaryFilter({
    int? month,
    int? year,
    this.category = 'all',
    this.department = 'All',
    this.status = 'all',
    this.search = '',
  })  : month = month ?? DateTime.now().month,
        year = year ?? DateTime.now().year;

  SalaryFilter copyWith({
    int? month,
    int? year,
    String? category,
    String? department,
    String? status,
    String? search,
  }) {
    return SalaryFilter(
      month: month ?? this.month,
      year: year ?? this.year,
      category: category ?? this.category,
      department: department ?? this.department,
      status: status ?? this.status,
      search: search ?? this.search,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SalaryFilter &&
          runtimeType == other.runtimeType &&
          month == other.month &&
          year == other.year &&
          category == other.category &&
          department == other.department &&
          status == other.status &&
          search == other.search;

  @override
  int get hashCode =>
      month.hashCode ^
      year.hashCode ^
      category.hashCode ^
      department.hashCode ^
      status.hashCode ^
      search.hashCode;
}

final salaryFilterProvider =
    StateProvider<SalaryFilter>((ref) => SalaryFilter());

final salariesProvider = FutureProvider<SalaryQueryResult>((ref) async {
  final filter = ref.watch(salaryFilterProvider);
  final service = ref.watch(salaryServiceProvider);
  return service.getSalaries(
    month: filter.month,
    year: filter.year,
    category: filter.category,
    department: filter.department,
    status: filter.status,
    search: filter.search,
  );
});

// Dedicated provider for Administrative Salaries in Accounts
final adminSalariesFilterProvider = StateProvider<SalaryFilter>((ref) =>
    SalaryFilter(category: 'administrative'));

final adminSalariesProvider = FutureProvider<SalaryQueryResult>((ref) async {
  final filter = ref.watch(adminSalariesFilterProvider);
  final service = ref.watch(salaryServiceProvider);
  return service.getSalaries(
    month: filter.month,
    year: filter.year,
    category: 'administrative',
    department: filter.department,
    status: filter.status,
    search: filter.search,
  );
});

// Dedicated provider for Operations Salaries in Accounts
final opsSalariesFilterProvider = StateProvider<SalaryFilter>((ref) =>
    SalaryFilter(category: 'operations'));

final opsSalariesProvider = FutureProvider<SalaryQueryResult>((ref) async {
  final filter = ref.watch(opsSalariesFilterProvider);
  final service = ref.watch(salaryServiceProvider);
  return service.getSalaries(
    month: filter.month,
    year: filter.year,
    category: 'operations',
    department: filter.department,
    status: filter.status,
    search: filter.search,
  );
});
