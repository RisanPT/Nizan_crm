import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/models/blocked_date.dart';
import '../providers/dio_provider.dart';
import 'package:nizan_crm/core/error/errors.dart';

final blockedDateServiceProvider = Provider<BlockedDateService>((ref) {
  return BlockedDateService(ref.watch(dioProvider));
});

final blockedDatesProvider = FutureProvider<List<BlockedDate>>((ref) async {
  return ref.watch(blockedDateServiceProvider).getBlockedDates(activeOnly: true);
});

class BlockedDateService {
  final Dio _dio;

  BlockedDateService(this._dio);

  Future<List<BlockedDate>> getBlockedDates({bool activeOnly = false}) async {
    try {
      final response = await _dio.get(
        '/blocked-dates',
        queryParameters: activeOnly ? {'active': 'true'} : null,
      );
      final data = response.data as List;
      return data
          .map((item) => BlockedDate.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw AppException(e, action: 'load blocked dates');
    }
  }

  Future<BlockedDate> saveBlockedDate({
    String? id,
    required DateTime date,
    required String reason,
    bool active = true,
  }) async {
    try {
      final payload = {
        if (id != null && id.isNotEmpty) 'id': id,
        'date': date.toIso8601String(),
        'reason': reason,
        'active': active,
      };

      final response = id != null && id.isNotEmpty
          ? await _dio.put('/blocked-dates/$id', data: payload)
          : await _dio.post('/blocked-dates', data: payload);

      return BlockedDate.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      throw AppException(e, action: 'save blocked date');
    }
  }

  Future<void> deleteBlockedDate(String id) async {
    try {
      await _dio.delete('/blocked-dates/$id');
    } catch (e) {
      throw AppException(e, action: 'delete blocked date');
    }
  }
}
