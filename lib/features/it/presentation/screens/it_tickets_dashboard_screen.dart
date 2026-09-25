import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';

import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/it/data/ticket.dart';
import 'package:nizan_crm/features/it/services/ticket_service.dart';
import 'package:nizan_crm/features/it/presentation/screens/helpdesk_screen.dart';

/// IT-only triage queue: live counters + every ticket in the system.
class ITTicketsDashboardScreen extends HookConsumerWidget {
  const ITTicketsDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crm = context.crmColors;
    final statusFilter = useState<String?>(null);
    final stats = ref.watch(ticketStatsProvider);
    final async = ref.watch(ticketsProvider(TicketQuery(status: statusFilter.value)));

    void refresh() {
      ref.invalidate(ticketStatsProvider);
      ref.invalidate(ticketsProvider);
    }

    return Scaffold(
      backgroundColor: crm.background,
      body: Column(children: [
        Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          decoration: BoxDecoration(color: crm.surface, border: Border(bottom: BorderSide(color: crm.border))),
          child: Row(children: [
            Icon(Icons.confirmation_number_outlined, color: crm.primary),
            const SizedBox(width: 10),
            Text('IT Tickets', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: crm.primary)),
            const Spacer(),
            TextButton.icon(
              onPressed: () => context.go('/it/projects'),
              icon: const Icon(Icons.folder_special_outlined, size: 18),
              label: const Text('Projects'),
            ),
            IconButton(onPressed: refresh, icon: const Icon(Icons.refresh)),
          ]),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async => refresh(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                stats.when(
                  loading: () => const SizedBox(height: 90, child: Center(child: CircularProgressIndicator())),
                  error: (e, _) => AppErrorView(error: e, compact: true, onRetry: () => ref.invalidate(ticketStatsProvider)),
                  data: (s) => _statGrid(crm, s),
                ),
                const SizedBox(height: 16),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [
                    _filterChip(crm, 'All', statusFilter.value == null, () => statusFilter.value = null),
                    for (final st in ticketStatuses)
                      _filterChip(crm, ticketStatusLabel(st), statusFilter.value == st, () => statusFilter.value = st),
                  ]),
                ),
                const SizedBox(height: 12),
                async.when(
                  loading: () => const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator())),
                  error: (e, _) => Padding(
                    padding: const EdgeInsets.all(24),
                    child: AppErrorView(error: e, compact: true, onRetry: () => ref.invalidate(ticketsProvider)),
                  ),
                  data: (tickets) => tickets.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(32),
                          child: Center(child: Text('No tickets in this view.', style: TextStyle(color: crm.textSecondary))),
                        )
                      : Column(children: [for (final t in tickets) _queueRow(context, crm, t)]),
                ),
              ],
            ),
          ),
        ),
      ]),
    );
  }

  Widget _statGrid(CrmTheme crm, Map<String, int> s) {
    final cards = [
      _Stat('Total', s['total'] ?? 0, Icons.all_inbox_outlined, crm.primary),
      _Stat('Open', s['open'] ?? 0, Icons.markunread_outlined, Colors.blue.shade600),
      _Stat('In Progress', s['inProgress'] ?? 0, Icons.timelapse_outlined, Colors.orange.shade700),
      _Stat('Resolved', s['resolved'] ?? 0, Icons.check_circle_outline, const Color(0xFF2E8B57)),
      _Stat('Critical', s['critical'] ?? 0, Icons.priority_high, Colors.red.shade600),
      _Stat('Unassigned', s['unassigned'] ?? 0, Icons.person_off_outlined, Colors.blueGrey),
    ];
    return LayoutBuilder(builder: (ctx, c) {
      final cols = c.maxWidth > 720 ? 6 : (c.maxWidth > 480 ? 3 : 2);
      return GridView.count(
        crossAxisCount: cols,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.35,
        children: [for (final st in cards) _statCard(crm, st)],
      );
    });
  }

  Widget _statCard(CrmTheme crm, _Stat st) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: crm.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: crm.border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(st.icon, size: 18, color: st.color),
          const Spacer(),
          Text('${st.value}', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: st.color)),
          Text(st.label, style: TextStyle(fontSize: 11.5, color: crm.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
        ]),
      );

  Widget _filterChip(CrmTheme crm, String label, bool selected, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.only(right: 6),
        child: ChoiceChip(
          label: Text(label),
          selected: selected,
          onSelected: (_) => onTap(),
          selectedColor: crm.primary.withValues(alpha: 0.15),
          labelStyle: TextStyle(
            fontSize: 12.5,
            color: selected ? crm.primary : crm.textSecondary,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      );

  Widget _queueRow(BuildContext context, CrmTheme crm, Ticket t) => Card(
        margin: const EdgeInsets.only(bottom: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: crm.border)),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => context.go('/helpdesk/tickets/${t.id}'),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: ticketPriorityColor(t.priority).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(ticketTypeIcon(t.type), size: 17, color: ticketPriorityColor(t.priority)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Row(children: [
                    Text(t.ticketNumber, style: TextStyle(fontSize: 10.5, color: crm.textSecondary, fontWeight: FontWeight.w600)),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        t.assignedToName.isEmpty ? 'Unassigned · ${t.raisedByName}' : '→ ${t.assignedToName}',
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 10.5, color: crm.textSecondary),
                      ),
                    ),
                  ]),
                ]),
              ),
              const SizedBox(width: 8),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: ticketStatusColor(t.status).withValues(alpha: 0.14), borderRadius: BorderRadius.circular(7)),
                  child: Text(ticketStatusLabel(t.status), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: ticketStatusColor(t.status))),
                ),
                const SizedBox(height: 3),
                Text(ticketAgo(t.createdAt), style: TextStyle(fontSize: 10, color: crm.textSecondary)),
              ]),
            ]),
          ),
        ),
      );
}

class _Stat {
  final String label;
  final int value;
  final IconData icon;
  final Color color;
  const _Stat(this.label, this.value, this.icon, this.color);
}
