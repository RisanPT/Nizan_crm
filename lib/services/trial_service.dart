import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/models/trial.dart';
import '../providers/dio_provider.dart';

// ── Provider ─────────────────────────────────────────────────────────────────
final trialServiceProvider = Provider<TrialService>((ref) {
  return TrialService(ref.watch(dioProvider));
});

// ── Service ──────────────────────────────────────────────────────────────────
class TrialService {
  final Dio _dio;

  TrialService(this._dio);

  String _extractError(DioException e, String fallback) {
    final data = e.response?.data;
    if (data is Map<String, dynamic>) {
      final msg = data['message']?.toString().trim() ?? '';
      if (msg.isNotEmpty) return msg;
    }
    final dioMsg = e.message?.trim() ?? '';
    return dioMsg.isNotEmpty ? dioMsg : fallback;
  }

  // GET /api/trials  — optionally filter by month=YYYY-MM
  Future<List<Trial>> getTrials({String? month}) async {
    try {
      final response = await _dio.get(
        '/trials',
        queryParameters: {
          if (month != null && month.isNotEmpty) 'month': month,
        },
      );
      final data = response.data as List;
      return data.map((e) => Trial.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw Exception('Failed to load trials: ${_extractError(e, 'Unable to load trials.')}');
    }
  }

  // GET /api/trials/:id
  Future<Trial> getTrialById(String id) async {
    try {
      final response = await _dio.get('/trials/$id');
      return Trial.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception('Failed to load trial: ${_extractError(e, 'Unable to load trial.')}');
    }
  }

  // POST /api/trials
  Future<Trial> createTrial(Trial trial) async {
    try {
      final response = await _dio.post('/trials', data: trial.toJson());
      return Trial.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception('Failed to create trial: ${_extractError(e, 'Unable to create trial.')}');
    }
  }

  // PUT /api/trials/:id
  Future<Trial> updateTrial(Trial trial) async {
    try {
      final response = await _dio.put('/trials/${trial.id}', data: trial.toJson());
      return Trial.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception('Failed to update trial: ${_extractError(e, 'Unable to update trial.')}');
    }
  }

  // DELETE /api/trials/:id
  Future<void> deleteTrial(String id) async {
    try {
      await _dio.delete('/trials/$id');
    } on DioException catch (e) {
      throw Exception('Failed to delete trial: ${_extractError(e, 'Unable to delete trial.')}');
    }
  }
}
