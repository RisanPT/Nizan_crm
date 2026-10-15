import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/client_chat/controllers/chat_api_service.dart';
import 'package:nizan_crm/features/client_chat/data/conversation.dart';

/// The staff concierge-chat inbox: every client thread, newest activity first,
/// with search, an open/closed filter and unread badges. Tapping a row opens
/// the thread at `/client-chat/:id`.
class ClientChatInboxPage extends ConsumerStatefulWidget {
  const ClientChatInboxPage({super.key});

  @override
  ConsumerState<ClientChatInboxPage> createState() =>
      _ClientChatInboxPageState();
}

class _ClientChatInboxPageState extends ConsumerState<ClientChatInboxPage> {
  final _searchCtrl = TextEditingController();
  Timer? _searchDebounce;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    // Keep the inbox fresh while it's open (new client messages arrive here).
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) ref.invalidate(clientConversationsProvider);
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _refreshTimer?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      final notifier = ref.read(clientChatFilterProvider.notifier);
      notifier.state = notifier.state.copyWith(search: value.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final filter = ref.watch(clientChatFilterProvider);
    final convosAsync = ref.watch(clientConversationsProvider);

    return SelectionArea(
      child: Scaffold(
        backgroundColor: crm.background,
        appBar: AppBar(
          title: const Text('Client Chat'),
          actions: [
            IconButton(
              tooltip: 'Refresh',
              icon: const Icon(Icons.refresh),
              onPressed: () => ref.invalidate(clientConversationsProvider),
            ),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                children: [
                  TextField(
                    controller: _searchCtrl,
                    onChanged: _onSearchChanged,
                    decoration: InputDecoration(
                      hintText: 'Search by name or phone',
                      prefixIcon: const Icon(Icons.search),
                      isDense: true,
                      filled: true,
                      fillColor: crm.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: crm.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: crm.border),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _FilterChip(
                        label: 'All',
                        selected: filter.status == 'all',
                        onTap: () => _setStatus('all'),
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Open',
                        selected: filter.status == 'open',
                        onTap: () => _setStatus('open'),
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Closed',
                        selected: filter.status == 'closed',
                        onTap: () => _setStatus('closed'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: convosAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => AppErrorView(
                  error: e,
                  onRetry: () => ref.invalidate(clientConversationsProvider),
                ),
                data: (convos) {
                  if (convos.isEmpty) {
                    return _EmptyState(
                      hasSearch: filter.search.isNotEmpty ||
                          filter.status != 'all',
                    );
                  }
                  return RefreshIndicator(
                    onRefresh: () async =>
                        ref.invalidate(clientConversationsProvider),
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                      itemCount: convos.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, i) =>
                          _ConversationTile(convo: convos[i]),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _setStatus(String status) {
    final notifier = ref.read(clientChatFilterProvider.notifier);
    notifier.state = notifier.state.copyWith(status: status);
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({required this.convo});
  final ClientConversation convo;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final unread = convo.unreadForStaff;
    final hasUnread = unread > 0;
    final preview = convo.lastMessagePreview.isEmpty
        ? 'No messages yet'
        : (convo.lastMessageSenderType == 'staff'
            ? 'You: ${convo.lastMessagePreview}'
            : convo.lastMessagePreview);

    return Material(
      color: crm.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => context.go('/client-chat/${convo.id}'),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: hasUnread ? crm.primary.withValues(alpha: 0.4) : crm.border,
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: crm.primary.withValues(alpha: 0.12),
                child: Text(
                  _initials(convo.displayName),
                  style: TextStyle(
                    color: crm.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
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
                            convo.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: crm.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          timeAgo(convo.lastMessageAt),
                          style: TextStyle(
                            fontSize: 11,
                            color: crm.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            preview,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              color: hasUnread
                                  ? crm.textPrimary
                                  : crm.textSecondary,
                              fontWeight:
                                  hasUnread ? FontWeight.w600 : FontWeight.w400,
                            ),
                          ),
                        ),
                        if (hasUnread) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: crm.destructive,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            constraints: const BoxConstraints(minWidth: 20),
                            child: Text(
                              unread > 99 ? '99+' : '$unread',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                        if (convo.status == 'closed') ...[
                          const SizedBox(width: 8),
                          Icon(Icons.check_circle_outline,
                              size: 14, color: crm.textSecondary),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? crm.primary : crm.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? crm.primary : crm.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : crm.textSecondary,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.hasSearch});
  final bool hasSearch;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.forum_outlined, size: 48, color: crm.textSecondary),
          const SizedBox(height: 12),
          Text(
            hasSearch ? 'No chats match your filters' : 'No client chats yet',
            style: TextStyle(color: crm.textSecondary, fontSize: 15),
          ),
          const SizedBox(height: 4),
          Text(
            hasSearch
                ? 'Try a different search or filter.'
                : 'Messages from the client app will appear here.',
            style: TextStyle(color: crm.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

/// Short relative time for chat rows (e.g. "2m", "3h", "Mon", "12 Oct").
String timeAgo(DateTime? dt) {
  if (dt == null) return '';
  final now = DateTime.now();
  final diff = now.difference(dt);
  if (diff.inMinutes < 1) return 'now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m';
  if (diff.inHours < 24) return '${diff.inHours}h';
  if (diff.inDays < 7) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[dt.weekday - 1];
  }
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${dt.day} ${months[dt.month - 1]}';
}

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
  if (parts.isEmpty) return '?';
  if (parts.length == 1) {
    final p = parts.first;
    return p.substring(0, p.length >= 2 ? 2 : 1).toUpperCase();
  }
  return (parts.first[0] + parts.last[0]).toUpperCase();
}
