import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nizan_crm/core/models/salary.dart';
import 'package:nizan_crm/providers/dio_provider.dart';

final salaryServiceProvider = Provider<SalaryService>((ref) {
  return SalaryService(ref.watch(dioProvider));
});

class SalaryQueryResult {
  final List<Salary> salaries;
  final SalaryStats stats;

  const SalaryQueryResult({
    required this.salaries,
    required this.stats,
  });
}

class SalaryService {
  final Dio _dio;

  SalaryService(this._dio);

  Future<SalaryQueryResult> getSalaries({
    int? month,
    int? year,
    String? category,
    String? department,
    String? status,
    String? search,
  }) async {
    try {
      final Map<String, dynamic> query = {};
      if (month != null) query['month'] = month;
      if (year != null) query['year'] = year;
      if (category != null && category.isNotEmpty && category != 'all') {
        query['category'] = category;
      }
      if (department != null && department.isNotEmpty && department != 'all' && department != 'All') {
        query['department'] = department;
      }
      if (status != null && status.isNotEmpty && status != 'all' && status != 'All') {
        query['status'] = status;
      }
      if (search != null && search.trim().isNotEmpty) {
        query['search'] = search.trim();
      }

      final response = await _dio.get(
        '/salaries',
        queryParameters: query.isNotEmpty ? query : null,
      );

      final data = response.data as Map<String, dynamic>;
      final rawList = (data['salaries'] as List?) ?? [];
      final salaries = rawList
          .map((item) => Salary.fromJson(item as Map<String, dynamic>))
          .toList();

      final stats = data['stats'] != null
          ? SalaryStats.fromJson(data['stats'] as Map<String, dynamic>)
          : const SalaryStats();

      return SalaryQueryResult(salaries: salaries, stats: stats);
    } on DioException catch (e) {
      throw Exception('Failed to load salaries: ${e.message}');
    }
  }

  Future<Map<String, dynamic>> generateMonthlySalaries({
    required int month,
    required int year,
  }) async {
    try {
      final response = await _dio.post('/salaries/generate', data: {
        'month': month,
        'year': year,
      });
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      final data = e.response?.data;
      throw Exception(
        (data is Map && data['message'] != null)
            ? data['message'].toString()
            : 'Failed to generate monthly payroll: ${e.message}',
      );
    }
  }

  Future<Salary> createSalary(Map<String, dynamic> payload) async {
    try {
      final response = await _dio.post('/salaries', data: payload);
      return Salary.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      final data = e.response?.data;
      throw Exception(
        (data is Map && data['message'] != null)
            ? data['message'].toString()
            : 'Failed to create salary slip: ${e.message}',
      );
    }
  }

  Future<Salary> updateSalary(String id, Map<String, dynamic> payload) async {
    try {
      final response = await _dio.put('/salaries/$id', data: payload);
      return Salary.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      final data = e.response?.data;
      throw Exception(
        (data is Map && data['message'] != null)
            ? data['message'].toString()
            : 'Failed to update salary slip: ${e.message}',
      );
    }
  }

  Future<Salary> approveSalary(String id) async {
    try {
      final response = await _dio.put('/salaries/$id/approve');
      return Salary.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception('Failed to approve salary: ${e.message}');
    }
  }

  Future<Salary> paySalary(
    String id, {
    required String paymentMethod,
    String? transactionRef,
    DateTime? paymentDate,
    String? notes,
  }) async {
    try {
      final response = await _dio.put('/salaries/$id/pay', data: {
        'paymentMethod': paymentMethod,
        'transactionRef': transactionRef ?? '',
        'paymentDate': (paymentDate ?? DateTime.now()).toIso8601String(),
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      });
      return Salary.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      final data = e.response?.data;
      throw Exception(
        (data is Map && data['message'] != null)
            ? data['message'].toString()
            : 'Failed to record salary payment: ${e.message}',
      );
    }
  }

  Future<void> deleteSalary(String id) async {
    try {
      await _dio.delete('/salaries/$id');
    } on DioException catch (e) {
      throw Exception('Failed to delete salary slip: ${e.message}');
    }
  }

  Future<Map<String, dynamic>> submitToAccounts({
    required int month,
    required int year,
  }) async {
    try {
      final response = await _dio.post('/salaries/submit', data: {
        'month': month,
        'year': year,
      });
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      final data = e.response?.data;
      throw Exception(
        (data is Map && data['message'] != null)
            ? data['message'].toString()
            : 'Failed to submit payroll to accounts: ${e.message}',
      );
    }
  }
}
