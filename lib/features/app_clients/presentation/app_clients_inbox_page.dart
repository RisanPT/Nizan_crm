import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/app_clients/controllers/app_clients_service.dart';
import 'package:nizan_crm/features/app_clients/data/app_client.dart';

/// Staff view of every bridal-app client (bride): search, then open a client to
/// see their preferences, saved looks and bookings.
class AppClientsInboxPage extends ConsumerStatefulWidget {
  const AppClientsInboxPage({super.key});

  @override
  ConsumerState<AppClientsInboxPage> createState() =>
      _AppClientsInboxPageState();
}

class _AppClientsInboxPageState extends ConsumerState<AppClientsInboxPage> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearch(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      ref.read(appClientsSearchProvider.notifier).state = value.trim();
    });
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final clientsAsync = ref.watch(appClientsProvider);
    return SelectionArea(
      child: Scaffold(
        backgroundColor: crm.background,
        appBar: AppBar(
          title: const Text('App Clients'),
          actions: [
            IconButton(
              tooltip: 'Refresh',
              icon: const Icon(Icons.refresh),
              onPressed: () => ref.invalidate(appClientsProvider),
            ),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _searchCtrl,
                onChanged: _onSearch,
                decoration: InputDecoration(
                  hintText: 'Search brides by name, phone or email',
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
            ),
            Expanded(
              child: clientsAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => AppErrorView(
                  error: e,
                  onRetry: () => ref.invalidate(appClientsProvider),
                ),
                data: (clients) {
                  if (clients.isEmpty) {
                    return Center(
                      child: Text('No app clients yet',
                          style: TextStyle(color: crm.textSecondary)),
                    );
                  }
                  return RefreshIndicator(
                    onRefresh: () async => ref.invalidate(appClientsProvider),
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                      itemCount: clients.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (_, i) =>
                          _ClientTile(client: clients[i]),
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
}

class _ClientTile extends StatelessWidget {
  const _ClientTile({required this.client});
  final AppClient client;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final meta = <String>[
      if (client.savedLookCount > 0) '${client.savedLookCount} looks',
      if (client.hasPreferences) 'preferences set',
      if (client.phone.isNotEmpty) client.phone,
    ].join(' · ');
    return Material(
      color: crm.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => context.go('/app-clients/${client.id}'),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: crm.border),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: crm.primary.withValues(alpha: 0.12),
                child: Text(_initials(client.displayName),
                    style: TextStyle(
                        color: crm.primary, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(client.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: crm.textPrimary)),
                    const SizedBox(height: 2),
                    Text(meta.isEmpty ? 'New client' : meta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12.5, color: crm.textSecondary)),
                  ],
                ),
              ),
              if (client.status == 'blocked')
                Icon(Icons.block, size: 16, color: crm.destructive)
              else
                Icon(Icons.chevron_right, color: crm.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
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
