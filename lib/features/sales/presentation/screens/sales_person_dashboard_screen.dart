import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/core/providers/auth_provider.dart';
import 'package:nizan_crm/features/sales/controllers/lead_controller.dart';
import 'package:nizan_crm/features/sales/data/lead.dart';

/// Personal dashboard for a Sales Executive — scoped to their own leads (the
/// backend auto-restricts leads to the logged-in salesperson) plus follow-up
/// KPIs. Landing screen for the sales role.
class SalesPersonDashboardScreen extends ConsumerWidget {
  const SalesPersonDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crm = context.crmColors;
    final session = ref.watch(authSessionProvider);
    final name = (session?.name ?? '').trim();
    final firstName = name.isEmpty ? 'there' : name.split(' ').first;

    // Backend scopes leads to req.user for the 'sales' role, so the default
    // filter already returns only this salesperson's leads + their stats.
    final asyncLeads = ref.watch(paginatedLeadsProvider(LeadFilter(limit: 100)));

    return Scaffold(
      backgroundColor: crm.background,
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(paginatedLeadsProvider);
          await ref.read(paginatedLeadsProvider(LeadFilter(limit: 100)).future);
        },
        child: asyncLeads.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(children: [
            const SizedBox(height: 120),
            Center(child: Text('Could not load your dashboard',
                style: TextStyle(color: crm.textSecondary))),
          ]),
          data: (page) {
            final stats = page.stats ?? const {};
            final leads = page.items;
            final now = DateTime.now();
            final todayStart = DateTime(now.year, now.month, now.day);
            final todayEnd = todayStart.add(const Duration(days: 1));

            // Follow-ups needing attention (overdue + due today), soonest first.
            final dueFollowUps = leads
                .where((l) =>
                    l.status == 'Follow-up' &&
                    l.followUpDate != null &&
                    l.followUpDate!.isBefore(todayEnd))
                .toList()
              ..sort((a, b) => a.followUpDate!.compareTo(b.followUpDate!));

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                // Greeting
                Text('Hi, $firstName 👋',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold, color: crm.textPrimary)),
                const SizedBox(height: 2),
                Text('Here’s your sales snapshot.',
                    style: TextStyle(color: crm.textSecondary)),
                const SizedBox(height: 16),

                // KPI grid
                _KpiGrid(stats: stats, totalLeads: page.totalItems, crm: crm),
                const SizedBox(height: 20),

                // Quick actions
                Row(
                  children: [
                    Expanded(
                      child: _ActionCard(
                        icon: Icons.person_add_alt_1_outlined,
                        label: 'Add / View Leads',
                        color: crm.primary,
                        onTap: () => context.go('/sales/leads'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ActionCard(
                        icon: Icons.calculate_outlined,
                        label: 'Quote & Invoice',
                        color: const Color(0xFF0D9488),
                        onTap: () => context.go('/sales/leads'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),

                // Follow-ups due
                Row(
                  children: [
                    Text('Follow-ups due',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: crm.textPrimary)),
                    const Spacer(),
                    if (dueFollowUps.isNotEmpty)
                      Text('${dueFollowUps.length}',
                          style: TextStyle(
                              color: const Color(0xFFDC2626),
                              fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 8),
                if (dueFollowUps.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: crm.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: crm.border),
                    ),
                    child: Center(
                      child: Text('You’re all caught up — no follow-ups due.',
                          style: TextStyle(color: crm.textSecondary)),
                    ),
                  )
                else
                  ...dueFollowUps.take(8).map((l) => _FollowUpTile(
                        lead: l,
                        crm: crm,
                        overdue: l.followUpDate!.isBefore(now),
                        onTap: () => context.go('/sales/leads/${l.id}'),
                      )),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _KpiGrid extends StatelessWidget {
  final Map<String, int> stats;
  final int totalLeads;
  final CrmTheme crm;

  const _KpiGrid(
      {required this.stats, required this.totalLeads, required this.crm});

  @override
  Widget build(BuildContext context) {
    final cards = <Widget>[
      _kpi('My Leads', totalLeads, Icons.groups_outlined, const Color(0xFF2563EB)),
      _kpi('New', stats['New'] ?? 0, Icons.fiber_new_outlined, const Color(0xFF7C3AED)),
      _kpi('Follow-up', stats['Follow-up'] ?? 0, Icons.sync, const Color(0xFFF59E0B)),
      _kpi("Today", stats['followUpsToday'] ?? 0, Icons.today_outlined, const Color(0xFF0D9488)),
      _kpi('Overdue', stats['followUpsOverdue'] ?? 0, Icons.error_outline, const Color(0xFFDC2626)),
      _kpi('Closed', stats['Closed'] ?? 0, Icons.check_circle_outline, const Color(0xFF16A34A)),
    ];
    return LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth < 520 ? 2 : 3;
      final w = (c.maxWidth - (cols - 1) * 10) / cols;
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [for (final card in cards) SizedBox(width: w, child: card)],
      );
    });
  }

  Widget _kpi(String label, int value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: crm.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 10),
          Text('$value',
              style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w800, color: color)),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: crm.textSecondary)),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Text(label,
                  style: TextStyle(
                      fontWeight: FontWeight.w700, color: crm.textPrimary)),
            ),
          ],
        ),
      ),
    );
  }
}

class _FollowUpTile extends StatelessWidget {
  final Lead lead;
  final CrmTheme crm;
  final bool overdue;
  final VoidCallback onTap;

  const _FollowUpTile(
      {required this.lead,
      required this.crm,
      required this.overdue,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final d = lead.followUpDate!;
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final when =
        '${d.day} ${months[d.month - 1]}, ${_h(d)}:${d.minute.toString().padLeft(2, '0')} ${d.hour < 12 ? 'AM' : 'PM'}';
    final color = overdue ? const Color(0xFFDC2626) : const Color(0xFFF59E0B);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: crm.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: crm.border),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: color.withValues(alpha: 0.12),
              child: Icon(overdue ? Icons.error_outline : Icons.event_outlined,
                  size: 18, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(lead.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text('${overdue ? 'Overdue · ' : ''}$when',
                      style: TextStyle(fontSize: 12, color: color)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: crm.textSecondary),
          ],
        ),
      ),
    );
  }

  String _h(DateTime d) {
    final h = d.hour % 12;
    return (h == 0 ? 12 : h).toString();
  }
}
