import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/providers/dio_provider.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/hr/onboarding/data/onboarding_models.dart';

class OnboardingService {
  final Dio _dio;
  OnboardingService(this._dio);

  Future<List<Onboarding>> getAll({String? status}) async {
    try {
      final res = await _dio.get('/onboarding', queryParameters: {'status': ?status});
      final raw = res.data is List ? res.data as List : const [];
      return raw.map((e) => Onboarding.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      throw AppException(e, action: 'load onboarding');
    }
  }

  Future<void> create({
    required String employeeId,
    String? role,
    String? department,
    DateTime? joiningDate,
    List<OnboardingTask>? tasks,
    List<OnboardingDocument>? documents,
  }) async {
    try {
      final data = <String, dynamic>{'employeeId': employeeId};
      if (role != null) data['role'] = role;
      if (department != null) data['department'] = department;
      if (joiningDate != null) data['joiningDate'] = joiningDate.toIso8601String();
      if (tasks != null) data['tasks'] = tasks.map((t) => t.toJson()).toList();
      if (documents != null) data['documents'] = documents.map((d) => d.toJson()).toList();
      await _dio.post('/onboarding', data: data);
    } catch (e) {
      throw AppException(e, action: 'start onboarding');
    }
  }

  Future<void> update(
    String id, {
    List<OnboardingTask>? tasks,
    List<OnboardingDocument>? documents,
    String? status,
    String? role,
    String? department,
    DateTime? joiningDate,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (tasks != null) data['tasks'] = tasks.map((t) => t.toJson()).toList();
      if (documents != null) data['documents'] = documents.map((d) => d.toJson()).toList();
      if (status != null) data['status'] = status;
      if (role != null) data['role'] = role;
      if (department != null) data['department'] = department;
      if (joiningDate != null) data['joiningDate'] = joiningDate.toIso8601String();
      await _dio.put('/onboarding/$id', data: data);
    } catch (e) {
      throw AppException(e, action: 'update onboarding');
    }
  }

  Future<void> remove(String id) async {
    try {
      await _dio.delete('/onboarding/$id');
    } catch (e) {
      throw AppException(e, action: 'delete onboarding');
    }
  }
}

final onboardingServiceProvider =
    Provider<OnboardingService>((ref) => OnboardingService(ref.watch(dioProvider)));

final onboardingsProvider =
    FutureProvider<List<Onboarding>>((ref) => ref.watch(onboardingServiceProvider).getAll());
