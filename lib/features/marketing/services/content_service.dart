import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/errors.dart';
import '../../../providers/dio_provider.dart';
import '../data/content_item.dart';

final contentServiceProvider = Provider<ContentService>((ref) {
  return ContentService(ref.watch(dioProvider));
});

/// The 42-day grid window for a month (Sunday-start, matching the CRM calendar).
DateTimeRangeKey monthGridRange(DateTime month) {
  final monthStart = DateTime(month.year, month.month, 1);
  final gridStart = monthStart.subtract(Duration(days: monthStart.weekday % 7));
  final gridEnd = gridStart.add(const Duration(days: 41));
  return DateTimeRangeKey(gridStart, gridEnd, month.year, month.month);
}

/// Stable, equatable key so the FutureProvider.family caches per month.
class DateTimeRangeKey {
  final DateTime from;
  final DateTime to;
  final int year;
  final int month;
  const DateTimeRangeKey(this.from, this.to, this.year, this.month);

  @override
  bool operator ==(Object other) =>
      other is DateTimeRangeKey && other.year == year && other.month == month;
  @override
  int get hashCode => Object.hash(year, month);
}

/// Content items whose scheduledDate falls in a month's calendar grid.
final contentByMonthProvider =
    FutureProvider.family<List<ContentItem>, DateTimeRangeKey>((ref, key) {
  return ref.watch(contentServiceProvider).getItems(from: key.from, to: key.to);
});

/// Dashboard counters.
final contentStatsProvider = FutureProvider<ContentStats>((ref) {
  return ref.watch(contentServiceProvider).getStats();
});

class ContentService {
  final Dio _dio;
  ContentService(this._dio);

  Future<List<ContentItem>> getItems({
    DateTime? from,
    DateTime? to,
    String? status,
    String? platform,
  }) =>
      _guard('load content', () async {
        final res = await _dio.get('/content', queryParameters: {
          if (from != null) 'from': from.toIso8601String(),
          if (to != null) 'to': to.toIso8601String(),
          if (status != null && status.isNotEmpty) 'status': status,
          if (platform != null && platform.isNotEmpty) 'platform': platform,
        });
        return (res.data as List)
            .map((e) => ContentItem.fromJson((e as Map).cast<String, dynamic>()))
            .toList();
      });

  Future<ContentItem> createItem(Map<String, dynamic> body) => _guard('create the post', () async {
        final res = await _dio.post('/content', data: body);
        return ContentItem.fromJson((res.data as Map).cast<String, dynamic>());
      });

  Future<ContentItem> updateItem(String id, Map<String, dynamic> body) => _guard('update the post', () async {
        final res = await _dio.put('/content/$id', data: body);
        return ContentItem.fromJson((res.data as Map).cast<String, dynamic>());
      });

  Future<void> deleteItem(String id) => _guard('delete the post', () => _dio.delete('/content/$id'));

  Future<ContentStats> getStats() => _guard('load content stats', () async {
        final res = await _dio.get('/content/stats');
        return ContentStats.fromJson((res.data as Map).cast<String, dynamic>());
      });

  /// Runs an API call and rethrows any failure as an [AppException].
  Future<T> _guard<T>(String action, Future<T> Function() call) async {
    try {
      return await call();
    } catch (e) {
      throw AppException(e, action: action);
    }
  }
}
