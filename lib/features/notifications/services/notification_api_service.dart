import 'package:dio/dio.dart';
import 'package:nizan_crm/features/notifications/data/app_notification.dart';
import 'package:nizan_crm/core/error/errors.dart';

class NotificationApiService {
  final Dio _dio;

  NotificationApiService(this._dio);

  Future<NotificationPage> getNotifications({
    int page = 1,
    int limit = 30,
    bool unreadOnly = false,
  }) async {
    try {
      final res = await _dio.get('/notifications', queryParameters: {
        'page': page,
        'limit': limit,
        if (unreadOnly) 'unread': 'true',
      });
      return NotificationPage.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw AppException(e, action: 'load notifications');
    }
  }

  Future<int> getUnreadCount() async {
    try {
      final res = await _dio.get('/notifications/unread-count');
      return (res.data?['count'] as num?)?.toInt() ?? 0;
    } on DioException {
      // Non-fatal — a badge that can't load just shows nothing.
      return 0;
    }
  }

  Future<void> markRead(String id) async {
    try {
      await _dio.patch('/notifications/$id/read');
    } catch (e) {
      throw AppException(e, action: 'mark notification read');
    }
  }

  Future<void> markAllRead() async {
    try {
      await _dio.patch('/notifications/read-all');
    } catch (e) {
      throw AppException(e, action: 'mark all read');
    }
  }

  /// Removes one notification from the inbox (server soft-clears it).
  Future<void> clearOne(String id) async {
    try {
      await _dio.patch('/notifications/$id/clear');
    } catch (e) {
      throw AppException(e, action: 'clear notification');
    }
  }

  /// Removes every notification from the inbox.
  Future<void> clearAll() async {
    try {
      await _dio.patch('/notifications/clear-all');
    } catch (e) {
      throw AppException(e, action: 'clear notifications');
    }
  }
}
