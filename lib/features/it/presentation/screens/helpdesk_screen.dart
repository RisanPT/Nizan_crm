import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';

import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/it/data/ticket.dart';
import 'package:nizan_crm/features/it/services/ticket_service.dart';
import 'package:nizan_crm/features/it/presentation/screens/widgets/raise_ticket_dialog.dart';

// ── Shared ticket colours (reused by the detail screen) ───────────────────────
Color ticketStatusColor(String s) => switch (s) {
      'open' => Colors.blue.shade600,
      'in-progress' => Colors.orange.shade700,
      'resolved' => const Color(0xFF2E8B57),
      'closed' => Colors.teal,
      'rejected' => Colors.red.shade600,
      _ => Colors.blueGrey,
    };

Color ticketPriorityColor(String p) => switch (p) {
      'critical' => Colors.red.shade600,
      'high' => Colors.orange.shade700,
      'medium' => Colors.blue.shade600,
      _ => Colors.grey,
    };

IconData ticketTypeIcon(String t) => switch (t) {
      'feature' => Icons.lightbulb_outline,
      'support' => Icons.help_outline,
      _ => Icons.bug_report_outlined,
    };

String ticketAgo(DateTime? d) {
  if (d == null) return '';
  final diff = DateTime.now().difference(d);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 30) return '${diff.inDays}d ago';
  return '${d.day}/${d.month}/${d.year}';
}

class HelpDeskScreen extends HookConsumerWidget {
  const HelpDeskScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crm = context.crmColors;
    final statusFilter = useState<String?>(null); // null = all
    final mineOnly = useState(false);
    final query = TicketQuery(status: statusFilter.value, mine: mineOnly.value);
    final async = ref.watch(ticketsProvider(query));

    return Scaffold(
      backgroundColor: crm.background,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => raiseTicketSheet(context, ref),
        backgroundColor: crm.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Raise Ticket'),
      ),
      body: Column(children: [
        Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          decoration: BoxDecoration(color: crm.surface, border: Border(bottom: BorderSide(color: crm.border))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.support_agent_outlined, color: crm.primary),
              const SizedBox(width: 10),
              Text('Help Desk', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: crm.primary)),
              const Spacer(),
              IconButton(onPressed: () => ref.invalidate(ticketsProvider), icon: const Icon(Icons.refresh)),
            ]),
            const SizedBox(height: 4),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                _filterChip(crm, 'All', statusFilter.value == null, () => statusFilter.value = null),
                for (final s in ticketStatuses)
                  _filterChip(crm, ticketStatusLabel(s), statusFilter.value == s, () => statusFilter.value = s),
                const SizedBox(width: 6),
                FilterChip(
                  label: const Text('My tickets'),
                  selected: mineOnly.value,
                  onSelected: (v) => mineOnly.value = v,
                  selectedColor: crm.primary.withValues(alpha: 0.15),
                  checkmarkColor: crm.primary,
                ),
              ]),
            ),
          ]),
        ),
        Expanded(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => AppErrorView(error: e, onRetry: () => ref.invalidate(ticketsProvider)),
            data: (tickets) => tickets.isEmpty
                ? _empty(crm)
                : RefreshIndicator(
                    onRefresh: () async => ref.invalidate(ticketsProvider),
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                      children: [for (final t in tickets) _ticketCard(context, crm, t)],
                    ),
                  ),
          ),
        ),
      ]),
    );
  }

  Widget _empty(CrmTheme crm) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.inbox_outlined, size: 48, color: crm.textSecondary.withValues(alpha: 0.5)),
          const SizedBox(height: 10),
          Text('No tickets here yet.', style: TextStyle(color: crm.textSecondary)),
          const SizedBox(height: 4),
          Text('Tap "Raise Ticket" to report a bug or request a feature.',
              style: TextStyle(color: crm.textSecondary, fontSize: 12)),
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

  Widget _ticketCard(BuildContext context, CrmTheme crm, Ticket t) => Card(
        margin: const EdgeInsets.only(bottom: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: crm.border)),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => context.go('/helpdesk/tickets/${t.id}'),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(ticketTypeIcon(t.type), size: 16, color: ticketPriorityColor(t.priority)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(t.title,
                      style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                ),
                _chip(ticketStatusLabel(t.status), ticketStatusColor(t.status)),
              ]),
              const SizedBox(height: 6),
              Row(children: [
                Text(t.ticketNumber, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: crm.textSecondary)),
                const SizedBox(width: 8),
                _chip(ticketTypeLabel(t.type), crm.textSecondary, subtle: true),
                const SizedBox(width: 6),
                _chip(t.priority, ticketPriorityColor(t.priority), subtle: true),
                if (t.module.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Flexible(child: _chip(t.module, crm.textSecondary, subtle: true)),
                ],
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Icon(Icons.person_outline, size: 13, color: crm.textSecondary),
                const SizedBox(width: 3),
                Flexible(
                  child: Text(t.raisedByName.isEmpty ? 'Someone' : t.raisedByName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11.5, color: crm.textSecondary)),
                ),
                if (t.assignedToName.isNotEmpty) ...[
                  const SizedBox(width: 10),
                  Icon(Icons.engineering_outlined, size: 13, color: crm.textSecondary),
                  const SizedBox(width: 3),
                  Flexible(
                    child: Text(t.assignedToName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11.5, color: crm.textSecondary)),
                  ),
                ],
                const SizedBox(width: 8),
                const Spacer(),
                Text(ticketAgo(t.createdAt), style: TextStyle(fontSize: 11, color: crm.textSecondary)),
              ]),
            ]),
          ),
        ),
      );

  Widget _chip(String label, Color color, {bool subtle = false}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: subtle ? 0.10 : 0.14),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Text(subtle ? _cap(label) : label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.w700)),
      );
}

String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

/// The "Raise Ticket" modal — available to every department.
Future<void> raiseTicketSheet(BuildContext context, WidgetRef ref, {String? defaultModule}) async {
  await showRaiseTicketDialog(context, ref, defaultModule: defaultModule);
}
