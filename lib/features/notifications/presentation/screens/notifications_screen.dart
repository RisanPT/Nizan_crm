import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/notifications/data/app_notification.dart';
import 'package:nizan_crm/features/notifications/controllers/notification_providers.dart';
import 'package:nizan_crm/core/state/data_refresh.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  /// Ids cleared locally but possibly still in the last fetched page — hidden
  /// immediately so the list (and Dismissible) never shows a cleared item.
  final Set<String> _hidden = {};

  /// True while a "Clear all" is in flight: the inbox renders empty at once.
  bool _clearingAll = false;
  bool _busy = false;

  Future<void> _refresh() async {
    ref.refreshData.notifications();
    try {
      await ref.read(notificationsProvider.future);
    } catch (_) {
      // A failed reload is shown by the list's error state; never let it
      // escape pull-to-refresh or turn a successful action into an error.
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _markAll() async {
    setState(() => _busy = true);
    try {
      await ref.read(notificationApiServiceProvider).markAllRead();
      await _refresh();
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, e,
            fallback: 'Could not mark notifications as read. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _clearAll(int count) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear all notifications?'),
        content: Text(
            'This removes all $count notification${count == 1 ? '' : 's'} from your inbox.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Clear all')),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() {
      _clearingAll = true;
      _busy = true;
    });
    try {
      await ref.read(notificationApiServiceProvider).clearAll();
      await _refresh();
      _toast('Notifications cleared');
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, e,
            fallback: 'Could not clear notifications. Please try again.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _clearingAll = false;
          _busy = false;
        });
      }
    }
  }

  Future<void> _clearOne(AppNotification n) async {
    setState(() => _hidden.add(n.id));
    try {
      await ref.read(notificationApiServiceProvider).clearOne(n.id);
      ref.refreshData.notifications();
    } catch (e) {
      if (!mounted) return;
      setState(() => _hidden.remove(n.id));
      showErrorSnackBar(context, e,
          fallback: 'Could not clear notification. Please try again.');
    }
  }

  Future<void> _open(AppNotification n) async {
    if (!n.read) {
      try {
        await ref.read(notificationApiServiceProvider).markRead(n.id);
      } catch (_) {
        // Best-effort: failing to mark it read must not block opening it.
      }
      ref.refreshData.notifications();
    }
    if (!mounted) return;
    // Prefer the generic deep-link; fall back to the lead route for older
    // lead notifications that predate the link field.
    if (n.link.isNotEmpty) {
      context.push(n.link);
    } else if (n.leadId != null && n.leadId!.isNotEmpty) {
      context.push('/sales/leads/${n.leadId}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final async = ref.watch(notificationsProvider);

    return Scaffold(
      backgroundColor: crm.background,
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          // Kept inside a ListView so pull-to-refresh still works.
          error: (e, _) => ListView(
            children: [
              const SizedBox(height: 80),
              AppErrorView(error: e, onRetry: _refresh),
            ],
          ),
          data: (page) {
            final items = _clearingAll
                ? const <AppNotification>[]
                : page.items.where((n) => !_hidden.contains(n.id)).toList();
            final hiddenUnread = page.items
                .where((n) => !n.read && _hidden.contains(n.id))
                .length;
            final unread =
                _clearingAll ? 0 : (page.unreadCount - hiddenUnread).clamp(0, 1 << 30);
            return Column(
              children: [
                _HeaderBar(
                  unreadCount: unread,
                  busy: _busy,
                  onMarkAll: unread > 0 && !_busy ? _markAll : null,
                  onClearAll: items.isNotEmpty && !_busy
                      ? () => _clearAll(items.length)
                      : null,
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
                          itemBuilder: (context, i) {
                            final n = items[i];
                            return Dismissible(
                              key: ValueKey('notif-${n.id}'),
                              direction: DismissDirection.endToStart,
                              onDismissed: (_) => _clearOne(n),
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 20),
                                color: crm.destructive.withValues(alpha: 0.12),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.delete_sweep_outlined,
                                        color: crm.destructive),
                                    const SizedBox(width: 6),
                                    Text('Clear',
                                        style: TextStyle(
                                            color: crm.destructive,
                                            fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ),
                              child: _NotificationTile(
                                notification: n,
                                onTap: () => _open(n),
                                onClear: () => _clearOne(n),
                              ),
                            );
                          },
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
  final bool busy;
  final VoidCallback? onMarkAll;
  final VoidCallback? onClearAll;

  const _HeaderBar({
    required this.unreadCount,
    required this.busy,
    this.onMarkAll,
    this.onClearAll,
  });

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: crm.surface,
        border: Border(bottom: BorderSide(color: crm.border)),
      ),
      child: Row(
        children: [
          const Icon(Icons.notifications_active_outlined, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              unreadCount > 0 ? '$unreadCount unread' : 'All read',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
          if (busy)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          if (onMarkAll != null)
            TextButton.icon(
              onPressed: onMarkAll,
              icon: const Icon(Icons.done_all, size: 18),
              label: const Text('Mark all read'),
            ),
          if (onClearAll != null)
            TextButton.icon(
              onPressed: onClearAll,
              style: TextButton.styleFrom(foregroundColor: crm.destructive),
              icon: const Icon(Icons.clear_all_rounded, size: 18),
              label: const Text('Clear all'),
            ),
        ],
      ),
    );
  }
}
class _NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;
  final VoidCallback onClear;

  const _NotificationTile({
    required this.notification,
    required this.onTap,
    required this.onClear,
  });

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
            const SizedBox(width: 4),
            IconButton(
              tooltip: 'Clear',
              visualDensity: VisualDensity.compact,
              icon: Icon(Icons.close_rounded,
                  size: 18, color: crm.textSecondary),
              onPressed: onClear,
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
    // Company Reports
    case 'report_uploaded':
      return const _TypeMeta(Icons.folder_shared_outlined, Color(0xFF7C3AED));
    // Accounts
    case 'payment_received':
      return const _TypeMeta(Icons.payments_outlined, Color(0xFF16A34A));
    case 'expense_recorded':
      return const _TypeMeta(Icons.receipt_long_outlined, Color(0xFFB45309));
    // Fleet
    case 'trip_assigned':
      return const _TypeMeta(Icons.local_shipping_outlined, Color(0xFF2563EB));
    case 'trip_completed':
      return const _TypeMeta(Icons.where_to_vote_outlined, Color(0xFF16A34A));
    case 'accident_reported':
      return const _TypeMeta(Icons.car_crash_outlined, Color(0xFFDC2626));
    // Inventory
    case 'low_stock':
      return const _TypeMeta(Icons.inventory_2_outlined, Color(0xFFEA580C));
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
