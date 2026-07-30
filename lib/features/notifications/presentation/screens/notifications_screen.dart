import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/notifications/data/app_notification.dart';
import 'package:nizan_crm/features/notifications/controllers/notification_providers.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crm = context.crmColors;
    final async = ref.watch(notificationsProvider);

    Future<void> refresh() async {
      ref.invalidate(notificationsProvider);
      ref.invalidate(unreadCountProvider);
      await ref.read(notificationsProvider.future);
    }

    Future<void> markAll() async {
      await ref.read(notificationApiServiceProvider).markAllRead();
      await refresh();
    }

    Future<void> openNotification(AppNotification n) async {
      if (!n.read) {
        try {
          await ref.read(notificationApiServiceProvider).markRead(n.id);
        } catch (_) {}
        ref.invalidate(notificationsProvider);
        ref.invalidate(unreadCountProvider);
      }
      if (n.leadId != null && n.leadId!.isNotEmpty && context.mounted) {
        context.push('/sales/leads/${n.leadId}');
      }
    }

    return Scaffold(
      backgroundColor: crm.background,
      body: RefreshIndicator(
        onRefresh: refresh,
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(
            children: [
              const SizedBox(height: 120),
              Icon(Icons.error_outline, size: 48, color: crm.textSecondary),
              const SizedBox(height: 12),
              Center(
                child: Text('Could not load notifications',
                    style: TextStyle(color: crm.textSecondary)),
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton(onPressed: refresh, child: const Text('Retry')),
              ),
            ],
          ),
          data: (page) {
            final items = page.items;
            return Column(
              children: [
                _HeaderBar(
                  unreadCount: page.unreadCount,
                  onMarkAll: page.unreadCount > 0 ? markAll : null,
                ),
                Expanded(
                  child: items.isEmpty
                      ? ListView(
                          children: [
                            const SizedBox(height: 120),
                            Icon(Icons.notifications_off_outlined,
                                size: 48, color: crm.textSecondary),
                            const SizedBox(height: 12),
                            Center(
                              child: Text("You're all caught up",
                                  style: TextStyle(color: crm.textSecondary)),
                            ),
                          ],
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: items.length,
                          separatorBuilder: (context, index) =>
                              Divider(height: 1, color: crm.border),
                          itemBuilder: (context, i) => _NotificationTile(
                            notification: items[i],
                            onTap: () => openNotification(items[i]),
                          ),
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _HeaderBar extends StatelessWidget {
  final int unreadCount;
  final VoidCallback? onMarkAll;

  const _HeaderBar({required this.unreadCount, this.onMarkAll});

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: crm.surface,
        border: Border(bottom: BorderSide(color: crm.border)),
      ),
      child: Row(
        children: [
          const Icon(Icons.notifications_active_outlined, size: 20),
          const SizedBox(width: 8),
          Text(
            unreadCount > 0 ? '$unreadCount unread' : 'All read',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const Spacer(),
          if (onMarkAll != null)
            TextButton.icon(
              onPressed: onMarkAll,
              icon: const Icon(Icons.done_all, size: 18),
              label: const Text('Mark all read'),
            ),
        ],
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;

  const _NotificationTile({required this.notification, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final meta = _typeMeta(notification.type);
    return InkWell(
      onTap: onTap,
      child: Container(
        color: notification.read ? null : meta.color.withValues(alpha: 0.04),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: meta.color.withValues(alpha: 0.12),
              child: Icon(meta.icon, size: 18, color: meta.color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          style: TextStyle(
                            fontWeight: notification.read
                                ? FontWeight.w500
                                : FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      if (!notification.read)
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(left: 8, top: 4),
                          decoration: BoxDecoration(
                            color: meta.color,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  if (notification.body.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      notification.body,
                      style: TextStyle(fontSize: 12.5, color: crm.textSecondary, height: 1.3),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    _relativeTime(notification.createdAt),
                    style: TextStyle(fontSize: 11, color: crm.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeMeta {
  final IconData icon;
  final Color color;
  const _TypeMeta(this.icon, this.color);
}

_TypeMeta _typeMeta(String type) {
  switch (type) {
    case 'new_lead':
      return const _TypeMeta(Icons.person_add_alt_1_outlined, Color(0xFF2563EB));
    case 'followup_assigned':
      return const _TypeMeta(Icons.event_note_outlined, Color(0xFFF97316));
    case 'followup_due':
      return const _TypeMeta(Icons.alarm_on_outlined, Color(0xFFF59E0B));
    case 'followup_missed':
      return const _TypeMeta(Icons.alarm_off_outlined, Color(0xFFDC2626));
    case 'followup_completed':
      return const _TypeMeta(Icons.check_circle_outline, Color(0xFF16A34A));
    case 'lost_requested':
      return const _TypeMeta(Icons.report_problem_outlined, Color(0xFFB45309));
    case 'lost_result':
      return const _TypeMeta(Icons.gavel_outlined, Color(0xFF7C3AED));
    case 'booking_created':
      return const _TypeMeta(Icons.event_available_outlined, Color(0xFF0D9488));
    default:
      return const _TypeMeta(Icons.notifications_outlined, Color(0xFF6B7280));
  }
}

String _relativeTime(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inSeconds < 60) return 'Just now';
  if (d.inMinutes < 60) return '${d.inMinutes}m ago';
  if (d.inHours < 24) return '${d.inHours}h ago';
  if (d.inDays < 7) return '${d.inDays}d ago';
  const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  return '${t.day} ${months[t.month - 1]}';
}
