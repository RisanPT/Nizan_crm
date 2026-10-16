import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/providers/dio_provider.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/hr/lms/data/lms_models.dart';

class LmsService {
  final Dio _dio;
  LmsService(this._dio);

  Future<List<Course>> getCourses() async {
    try {
      final res = await _dio.get('/lms/courses');
      final raw = res.data is List ? res.data as List : const [];
      return raw.map((e) => Course.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      throw AppException(e, action: 'load courses');
    }
  }

  Future<void> saveCourse(Map<String, dynamic> body, {String? id}) async {
    try {
      if (id == null) {
        await _dio.post('/lms/courses', data: body);
      } else {
        await _dio.put('/lms/courses/$id', data: body);
      }
    } catch (e) {
      throw AppException(e, action: 'save course');
    }
  }

  Future<void> deleteCourse(String id) async {
    try {
      await _dio.delete('/lms/courses/$id');
    } catch (e) {
      throw AppException(e, action: 'delete course');
    }
  }

  Future<List<Enrollment>> getMyEnrollments() async {
    try {
      final res = await _dio.get('/lms/enrollments/mine');
      final raw = res.data is List ? res.data as List : const [];
      return raw.map((e) => Enrollment.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      throw AppException(e, action: 'load my learning');
    }
  }

  Future<void> enroll(String courseId) async {
    try {
      await _dio.post('/lms/enroll', data: {'courseId': courseId});
    } catch (e) {
      throw AppException(e, action: 'enrol in course');
    }
  }

  Future<void> updateProgress(String enrollmentId, {int? progress, String? status}) async {
    try {
      final data = <String, dynamic>{};
      if (progress != null) data['progress'] = progress;
      if (status != null) data['status'] = status;
      await _dio.put('/lms/enrollments/$enrollmentId', data: data);
    } catch (e) {
      throw AppException(e, action: 'update progress');
    }
  }

  Future<void> unenroll(String enrollmentId) async {
    try {
      await _dio.delete('/lms/enrollments/$enrollmentId');
    } catch (e) {
      throw AppException(e, action: 'leave course');
    }
  }

  // ── Orientation Plans (1-Week Doc & Role Syllabus) ─────────────────────────
  Future<List<OrientationPlan>> getOrientationPlans() async {
    try {
      final res = await _dio.get('/lms/orientations/plans');
      final raw = res.data is List ? res.data as List : const [];
      return raw.map((e) => OrientationPlan.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      throw AppException(e, action: 'load orientation plans');
    }
  }

  Future<void> saveOrientationPlan(Map<String, dynamic> body, {String? id}) async {
    try {
      if (id == null) {
        await _dio.post('/lms/orientations/plans', data: body);
      } else {
        await _dio.put('/lms/orientations/plans/$id', data: body);
      }
    } catch (e) {
      throw AppException(e, action: 'save orientation plan');
    }
  }

  Future<List<OrientationAssignment>> getActiveOrientations() async {
    try {
      final res = await _dio.get('/lms/orientations/active');
      final raw = res.data is List ? res.data as List : const [];
      return raw.map((e) => OrientationAssignment.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      throw AppException(e, action: 'load active orientations');
    }
  }

  Future<void> assignOrientation({
    required String employeeId,
    String? planId,
    String? trainerName,
  }) async {
    try {
      await _dio.post('/lms/orientations/assign', data: {
        'employeeId': employeeId,
        'planId': ?planId,
        'trainerName': ?trainerName,
      });
    } catch (e) {
      throw AppException(e, action: 'assign orientation');
    }
  }

  Future<void> updateOrientationProgress(
    String id, {
    int? currentDay,
    String? status,
    int? signOffDay,
    bool? signedOff,
    List<Map<String, dynamic>>? days,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (currentDay != null) data['currentDay'] = currentDay;
      if (status != null) data['status'] = status;
      if (signOffDay != null) data['signOffDay'] = signOffDay;
      if (signedOff != null) data['signedOff'] = signedOff;
      if (days != null) data['days'] = days;
      await _dio.put('/lms/orientations/active/$id', data: data);
    } catch (e) {
      throw AppException(e, action: 'update orientation progress');
    }
  }
}

final lmsServiceProvider = Provider<LmsService>((ref) => LmsService(ref.watch(dioProvider)));

final coursesProvider = FutureProvider<List<Course>>((ref) => ref.watch(lmsServiceProvider).getCourses());

final myEnrollmentsProvider =
    FutureProvider<List<Enrollment>>((ref) => ref.watch(lmsServiceProvider).getMyEnrollments());

final orientationPlansProvider =
    FutureProvider<List<OrientationPlan>>((ref) => ref.watch(lmsServiceProvider).getOrientationPlans());

final activeOrientationsProvider =
    FutureProvider<List<OrientationAssignment>>((ref) => ref.watch(lmsServiceProvider).getActiveOrientations());
