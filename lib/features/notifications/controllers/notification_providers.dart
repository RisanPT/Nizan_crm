import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nizan_crm/providers/dio_provider.dart';
import 'package:nizan_crm/features/notifications/data/app_notification.dart';
import 'package:nizan_crm/features/notifications/services/notification_api_service.dart';

final notificationApiServiceProvider = Provider<NotificationApiService>((ref) {
  return NotificationApiService(ref.watch(dioProvider));
});

/// The notifications inbox (first page) plus unread count.
final notificationsProvider =
    FutureProvider.autoDispose<NotificationPage>((ref) async {
  return ref.watch(notificationApiServiceProvider).getNotifications();
});

/// Unread badge count for the app-bar bell. Kept separate so the badge can
/// refresh without pulling the full list.
final unreadCountProvider = FutureProvider.autoDispose<int>((ref) async {
  return ref.watch(notificationApiServiceProvider).getUnreadCount();
});
