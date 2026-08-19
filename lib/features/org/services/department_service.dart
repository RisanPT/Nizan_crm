import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/core/error/error_message.dart';
import 'package:nizan_crm/features/org/data/department.dart';
import 'package:nizan_crm/providers/dio_provider.dart';

class DepartmentService {
  final Dio _dio;
  DepartmentService(this._dio);

  Future<List<Department>> getDepartments() async {
    try {
      final res = await _dio.get('/departments');
      return (res.data as List).map((e) => Department.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw Exception(friendlyErrorMessage(e, fallback: 'Failed to load departments'));
    }
  }

  Future<int> seed() async {
    try {
      final res = await _dio.post('/departments/seed');
      return (res.data as Map)['created'] as int? ?? 0;
    } on DioException catch (e) {
      throw Exception(friendlyErrorMessage(e, fallback: 'Failed to seed departments'));
    }
  }

  Future<Department> save(Department d) async {
    try {
      final res = d.id.isEmpty
          ? await _dio.post('/departments', data: d.toJson())
          : await _dio.put('/departments/${d.id}', data: d.toJson());
      return Department.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(friendlyErrorMessage(e, fallback: 'Failed to save the department'));
    }
  }

  Future<void> delete(String id) async {
    try {
      await _dio.delete('/departments/$id');
    } on DioException catch (e) {
      throw Exception(friendlyErrorMessage(e, fallback: 'Failed to delete the department'));
    }
  }

  Future<List<DeptMember>> getMembers(String id) async {
    try {
      final res = await _dio.get('/departments/$id/members');
      return (res.data as List).map((e) => DeptMember.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw Exception(friendlyErrorMessage(e, fallback: 'Failed to load members'));
    }
  }

  /// Import/sync the Timebox attendance-software staff into our DB and slot them
  /// into their departments. Returns the summary message.
  Future<String> syncFromTimebox() async {
    try {
      final res = await _dio.post('/timebox/sync-employees');
      return (res.data as Map)['message'] as String? ?? 'Sync complete';
    } on DioException catch (e) {
      throw Exception(friendlyErrorMessage(e, fallback: 'Failed to sync from Timebox'));
    }
  }

  /// Slot existing artists → Artist and drivers → Fleet (Creative division).
  Future<String> assignByRole() async {
    try {
      final res = await _dio.post('/departments/assign-by-role');
      return (res.data as Map)['message'] as String? ?? 'Assigned staff';
    } on DioException catch (e) {
      throw Exception(friendlyErrorMessage(e, fallback: 'Failed to assign staff'));
    }
  }
}

final departmentServiceProvider =
    Provider<DepartmentService>((ref) => DepartmentService(ref.watch(dioProvider)));

final departmentsProvider = FutureProvider<List<Department>>((ref) async {
  return ref.watch(departmentServiceProvider).getDepartments();
});

final departmentMembersProvider =
    FutureProvider.family<List<DeptMember>, String>((ref, id) async {
  return ref.watch(departmentServiceProvider).getMembers(id);
});
