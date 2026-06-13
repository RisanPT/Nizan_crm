import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/models/lead_activity.dart';
import '../providers/dio_provider.dart';

final leadActivityServiceProvider = Provider<LeadActivityService>((ref) {
  return LeadActivityService(ref.watch(dioProvider));
});

final leadActivitiesProvider = FutureProvider.family<List<LeadActivity>, String>((ref, leadId) async {
  return ref.watch(leadActivityServiceProvider).getActivities(leadId);
});

class LeadActivityService {
  final Dio _dio;

  LeadActivityService(this._dio);

  Future<List<LeadActivity>> getActivities(String leadId) async {
    try {
      final response = await _dio.get('/leads/$leadId/activities');
      final data = response.data as List;
      return data.map((item) => LeadActivity.fromJson(item as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw Exception('Failed to load lead activities: ${e.message}');
    }
  }

  Future<void> createActivity(String leadId, Map<String, dynamic> data) async {
    try {
      await _dio.post('/leads/$leadId/activities', data: data);
    } on DioException catch (e) {
      throw Exception('Failed to log follow-up/outcome: ${e.message}');
    }
  }

  Future<void> deleteActivity(String leadId, String activityId) async {
    try {
      await _dio.delete('/leads/$leadId/activities/$activityId');
    } on DioException catch (e) {
      throw Exception('Failed to delete activity: ${e.message}');
    }
  }
}
