import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/providers/dio_provider.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/hr_engagement/data/announcement_models.dart';

class EngagementService {
  final Dio _dio;
  EngagementService(this._dio);

  Future<List<Announcement>> getFeed() async {
    try {
      final res = await _dio.get('/engagement');
      final raw = res.data is List ? res.data as List : const [];
      return raw.map((e) => Announcement.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      throw AppException(e, action: 'load the feed');
    }
  }

  Future<void> save(Map<String, dynamic> body, {String? id}) async {
    try {
      if (id == null) {
        await _dio.post('/engagement', data: body);
      } else {
        await _dio.put('/engagement/$id', data: body);
      }
    } catch (e) {
      throw AppException(e, action: 'save announcement');
    }
  }

  Future<void> delete(String id) async {
    try {
      await _dio.delete('/engagement/$id');
    } catch (e) {
      throw AppException(e, action: 'delete announcement');
    }
  }
}

final engagementServiceProvider =
    Provider<EngagementService>((ref) => EngagementService(ref.watch(dioProvider)));

final announcementsProvider =
    FutureProvider<List<Announcement>>((ref) => ref.watch(engagementServiceProvider).getFeed());
