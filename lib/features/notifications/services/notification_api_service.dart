import 'package:dio/dio.dart';
import 'package:nizan_crm/features/notifications/data/app_notification.dart';

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
    } on DioException catch (e) {
      throw Exception('Failed to load notifications: ${e.message}');
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
    } on DioException catch (e) {
      throw Exception('Failed to mark notification read: ${e.message}');
    }
  }

  Future<void> markAllRead() async {
    try {
      await _dio.patch('/notifications/read-all');
    } on DioException catch (e) {
      throw Exception('Failed to mark all read: ${e.message}');
    }
  }
}
