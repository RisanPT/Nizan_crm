import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/models/trial.dart';
import '../providers/dio_provider.dart';
import 'package:nizan_crm/core/error/errors.dart';

// ── Provider ─────────────────────────────────────────────────────────────────
final trialServiceProvider = Provider<TrialService>((ref) {
  return TrialService(ref.watch(dioProvider));
});

// ── Service ──────────────────────────────────────────────────────────────────
class TrialService {
  final Dio _dio;

  TrialService(this._dio);


  // GET /api/trials  — optionally filter by month=YYYY-MM
  Future<List<Trial>> getTrials({String? month, String? artist}) async {
    try {
      final response = await _dio.get(
        '/trials',
        queryParameters: {
          if (month != null && month.isNotEmpty) 'month': month,
          if (artist != null && artist.isNotEmpty) 'artist': artist,
        },
      );
      final data = response.data as List;
      return data.map((e) => Trial.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      throw AppException(e, action: 'load trials');
    }
  }

  // GET /api/trials/:id
  Future<Trial> getTrialById(String id) async {
    try {
      final response = await _dio.get('/trials/$id');
      return Trial.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      throw AppException(e, action: 'load trial');
    }
  }

  // POST /api/trials
  Future<Trial> createTrial(Trial trial) async {
    try {
      final response = await _dio.post('/trials', data: trial.toJson());
      return Trial.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      throw AppException(e, action: 'create trial');
    }
  }

  // PUT /api/trials/:id
  Future<Trial> updateTrial(Trial trial) async {
    try {
      final response = await _dio.put('/trials/${trial.id}', data: trial.toJson());
      return Trial.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      throw AppException(e, action: 'update trial');
    }
  }

  // DELETE /api/trials/:id
  Future<void> deleteTrial(String id) async {
    try {
      await _dio.delete('/trials/$id');
    } catch (e) {
      throw AppException(e, action: 'delete trial');
    }
  }
}
