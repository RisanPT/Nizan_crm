import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/core/error/error_message.dart';
import 'package:nizan_crm/features/slots/data/slot_models.dart';
import 'package:nizan_crm/providers/dio_provider.dart';

class SlotService {
  final Dio _dio;
  SlotService(this._dio);

  Future<MonthAvailability> getMonth(int year, int month) async {
    try {
      final res = await _dio.get('/slots/month', queryParameters: {'year': year, 'month': month});
      return MonthAvailability.fromJson((res.data as Map).cast<String, dynamic>());
    } on DioException catch (e) {
      throw Exception(friendlyErrorMessage(e, fallback: 'Failed to load slot availability'));
    }
  }

  Future<SlotDefaults> getDefaults() async {
    try {
      final res = await _dio.get('/slots/defaults');
      return SlotDefaults.fromJson((res.data as Map).cast<String, dynamic>());
    } on DioException catch (e) {
      throw Exception(friendlyErrorMessage(e, fallback: 'Failed to load defaults'));
    }
  }

  Future<SlotDefaults> updateDefaults({required int morning, required int evening}) async {
    try {
      final res = await _dio.put('/slots/defaults', data: {'morning': morning, 'evening': evening});
      return SlotDefaults.fromJson((res.data as Map).cast<String, dynamic>());
    } on DioException catch (e) {
      throw Exception(friendlyErrorMessage(e, fallback: 'Failed to update default capacity'));
    }
  }

  /// Override one day's capacity (date as YYYY-MM-DD).
  Future<void> setDay({required DateTime date, required int morning, required int evening}) async {
    try {
      await _dio.put('/slots/day', data: {
        'date': date.toIso8601String(),
        'morning': morning,
        'evening': evening,
      });
    } on DioException catch (e) {
      throw Exception(friendlyErrorMessage(e, fallback: 'Failed to set the day\'s capacity'));
    }
  }

  /// Remove a day's override (revert to the default).
  Future<void> clearDay(DateTime date) async {
    try {
      await _dio.delete('/slots/day', queryParameters: {'date': date.toIso8601String()});
    } on DioException catch (e) {
      throw Exception(friendlyErrorMessage(e, fallback: 'Failed to reset the day'));
    }
  }
}

final slotServiceProvider = Provider<SlotService>((ref) => SlotService(ref.watch(dioProvider)));

/// Month availability, keyed by (year, month) so switching months refetches.
final monthAvailabilityProvider =
    FutureProvider.family<MonthAvailability, ({int year, int month})>((ref, key) async {
  return ref.watch(slotServiceProvider).getMonth(key.year, key.month);
});

final slotDefaultsProvider = FutureProvider<SlotDefaults>((ref) async {
  return ref.watch(slotServiceProvider).getDefaults();
});
