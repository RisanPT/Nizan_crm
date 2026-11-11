import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/providers/dio_provider.dart';
import 'package:nizan_crm/features/it/domain/models/strategic_vision_model.dart';

final strategicVisionServiceProvider = Provider((ref) => StrategicVisionService(ref.watch(dioProvider)));

final strategicVisionProvider = FutureProvider<StrategicVisionModel>((ref) async {
  return ref.watch(strategicVisionServiceProvider).getVision();
});

final strategicAlignmentProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  return ref.watch(strategicVisionServiceProvider).getAlignment();
});

class StrategicVisionService {
  final Dio _dio;
  StrategicVisionService(this._dio);

  Future<StrategicVisionModel> getVision() async {
    try {
      final res = await _dio.get('/strategic-vision');
      return StrategicVisionModel.fromJson(Map<String, dynamic>.from(res.data as Map));
    } catch (e) {
      throw AppException(e, action: 'load 15-year strategic vision');
    }
  }

  Future<StrategicVisionModel> updateVision(Map<String, dynamic> data) async {
    try {
      final res = await _dio.put('/strategic-vision', data: data);
      return StrategicVisionModel.fromJson(Map<String, dynamic>.from(res.data as Map));
    } catch (e) {
      throw AppException(e, action: 'update strategic vision');
    }
  }

  Future<StrategicVisionModel> addOrUpdateMilestone(Map<String, dynamic> data) async {
    try {
      final res = await _dio.post('/strategic-vision/milestones', data: data);
      return StrategicVisionModel.fromJson(Map<String, dynamic>.from(res.data as Map));
    } catch (e) {
      throw AppException(e, action: 'save milestone');
    }
  }

  Future<StrategicVisionModel> deleteMilestone(String id) async {
    try {
      final res = await _dio.delete('/strategic-vision/milestones/$id');
      return StrategicVisionModel.fromJson(Map<String, dynamic>.from(res.data as Map));
    } catch (e) {
      throw AppException(e, action: 'delete milestone');
    }
  }

  Future<Map<String, dynamic>> getAlignment() async {
    try {
      final res = await _dio.get('/strategic-vision/alignment');
      return Map<String, dynamic>.from(res.data as Map);
    } catch (e) {
      throw AppException(e, action: 'load strategic alignment');
    }
  }
}

