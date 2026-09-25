import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/providers/auth_provider.dart';
import 'package:nizan_crm/features/notifications/controllers/notification_providers.dart';
import 'package:nizan_crm/features/sales/controllers/lead_controller.dart';
import 'package:nizan_crm/features/sales/data/lead.dart';

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
];
const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

String _greeting(int hour) {
  if (hour < 12) return 'Good morning';
  if (hour < 17) return 'Good afternoon';
  return 'Good evening';
}

String _fmtTime(DateTime d) {
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final m = d.minute.toString().padLeft(2, '0');
  return '$h:$m ${d.hour < 12 ? 'AM' : 'PM'}';
}

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
    final initial = firstName.isEmpty ? '?' : firstName[0].toUpperCase();
    final unread = ref.watch(unreadCountProvider).asData?.value ?? 0;

    // Backend scopes leads to req.user for the 'sales' role, so the default
    // filter already returns only this salesperson's leads + their stats.
    final asyncLeads = ref.watch(paginatedLeadsProvider(LeadFilter(limit: 100)));

    return Scaffold(
      backgroundColor: crm.background,
      body: RefreshIndicator(
        color: crm.primary,
        onRefresh: () async {
          ref.invalidate(paginatedLeadsProvider);
          try {
            await ref.read(paginatedLeadsProvider(LeadFilter(limit: 100)).future);
          } catch (_) {
            // The failure is shown by the error branch below.
          }
        },
        child: asyncLeads.when(
          loading: () => Center(child: CircularProgressIndicator(color: crm.primary)),
          // Kept inside a ListView so pull-to-refresh still works.
          error: (e, _) => ListView(children: [
            const SizedBox(height: 80),
            AppErrorView(
              error: e,
              onRetry: () => ref.invalidate(paginatedLeadsProvider),
            ),
          ]),
          data: (page) {
            final stats = page.stats ?? const {};
            final leads = page.items;
            final now = DateTime.now();
            final todayEnd = DateTime(now.year, now.month, now.day)
                .add(const Duration(days: 1));

            // Follow-ups needing attention (overdue + due today), soonest first.
            final dueFollowUps = leads
                .where((l) =>
                    l.status == 'Follow-up' &&
                    l.followUpDate != null &&
                    l.followUpDate!.isBefore(todayEnd))
                .toList()
              ..sort((a, b) => a.followUpDate!.compareTo(b.followUpDate!));

            return ListView(
              padding: EdgeInsets.zero,
              children: [
                _Hero(
                  crm: crm,
                  greeting: _greeting(now.hour),
                  firstName: firstName,
                  initial: initial,
                  now: now,
                  dueCount: dueFollowUps.length,
                  unread: unread,
                  onBell: () => context.go('/notifications'),
                  onView: () => context.go('/sales/leads'),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionLabel('Overview', crm: crm),
                      const SizedBox(height: 12),
                      _KpiGrid(stats: stats, totalLeads: page.totalItems, crm: crm),
                      const SizedBox(height: 24),

                      _SectionLabel('Quick actions', crm: crm),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _ActionCard(
                              icon: Icons.person_add_alt_1_rounded,
                              label: 'Add / View\nLeads',
                              filled: true,
                              color: crm.primary,
                              onTap: () => context.go('/sales/leads'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _ActionCard(
                              icon: Icons.receipt_long_rounded,
                              label: 'Quote &\nInvoice',
                              filled: false,
                              color: const Color(0xFF0D9488),
                              onTap: () => context.go('/sales/leads'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 26),

                      Row(
                        children: [
                          _SectionLabel('Follow-ups due', crm: crm),
                          const Spacer(),
                          if (dueFollowUps.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 9, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDC2626).withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text('${dueFollowUps.length} due',
                                  style: const TextStyle(
                                      color: Color(0xFFDC2626),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (dueFollowUps.isEmpty)
                        _EmptyFollowUps(crm: crm)
                      else
                        ...dueFollowUps.take(8).map((l) => _FollowUpTile(
                              lead: l,
                              crm: crm,
                              overdue: l.followUpDate!.isBefore(now),
                              onTap: () => context.go('/sales/leads/${l.id}'),
                            )),
                    ],
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

/// Gradient maroon hero with greeting, avatar and an actionable follow-up strip.
class _Hero extends StatelessWidget {
  final CrmTheme crm;
  final String greeting;
  final String firstName;
  final String initial;
  final DateTime now;
  final int dueCount;
  final int unread;
  final VoidCallback onBell;
  final VoidCallback onView;

  const _Hero({
    required this.crm,
    required this.greeting,
    required this.firstName,
    required this.initial,
    required this.now,
    required this.dueCount,
    required this.unread,
    required this.onBell,
    required this.onView,
  });

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    const gold = Color(0xFFC9A66B);
    final dateStr =
        '${_weekdays[now.weekday - 1]}, ${now.day} ${_months[now.month - 1]} ${now.year}';

    return Container(
      padding: EdgeInsets.fromLTRB(20, topPad + 18, 20, 22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [crm.primary, const Color(0xFF3A101A)],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
        boxShadow: [
          BoxShadow(
            color: crm.primary.withValues(alpha: 0.28),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(greeting,
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.72),
                            fontSize: 13,
                            fontWeight: FontWeight.w500)),
                    const SizedBox(height: 3),
                    Text('$firstName 👋',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 23,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.2)),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Icon(Icons.calendar_today_rounded,
                            size: 12, color: Colors.white.withValues(alpha: 0.6)),
                        const SizedBox(width: 6),
                        Text(dateStr,
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.6),
                                fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ),
              // Notification bell (moved out of the shell app bar for this tab).
              _HeroBell(unread: unread, onTap: onBell),
              const SizedBox(width: 10),
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [gold, Color(0xFFB08D4F)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: gold.withValues(alpha: 0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Text(initial,
                    style: const TextStyle(
                        color: Color(0xFF3A101A),
                        fontSize: 22,
                        fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 18),
          // Actionable status strip — ties the hero to today's follow-ups.
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onView,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
              ),
              child: Row(
                children: [
                  Icon(
                    dueCount > 0
                        ? Icons.notifications_active_rounded
                        : Icons.check_circle_rounded,
                    color: dueCount > 0 ? gold : Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      dueCount > 0
                          ? '$dueCount follow-up${dueCount == 1 ? '' : 's'} need your attention'
                          : "You're all caught up — no follow-ups due",
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios_rounded,
                      size: 13, color: Colors.white.withValues(alpha: 0.7)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroBell extends StatelessWidget {
  final int unread;
  final VoidCallback onTap;
  const _HeroBell({required this.unread, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            const Icon(Icons.notifications_none_rounded,
                color: Colors.white, size: 22),
            if (unread > 0)
              Positioned(
                top: 8,
                right: 9,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Color(0xFFDC2626),
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(minWidth: 8, minHeight: 8),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  final CrmTheme crm;
  const _SectionLabel(this.text, {required this.crm});

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 16,
            color: crm.textPrimary,
            letterSpacing: 0.1));
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
      _kpi('My Leads', totalLeads, Icons.groups_rounded, const Color(0xFF2563EB)),
      _kpi('New', stats['New'] ?? 0, Icons.auto_awesome_rounded, const Color(0xFF7C3AED)),
      _kpi('Follow-up', stats['Follow-up'] ?? 0, Icons.autorenew_rounded, const Color(0xFFF59E0B)),
      _kpi('Today', stats['followUpsToday'] ?? 0, Icons.event_available_rounded, const Color(0xFF0D9488)),
      _kpi('Overdue', stats['followUpsOverdue'] ?? 0, Icons.notification_important_rounded, const Color(0xFFDC2626)),
      _kpi('Closed', stats['Closed'] ?? 0, Icons.verified_rounded, const Color(0xFF16A34A)),
    ];
    return LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth < 520 ? 2 : 3;
      final w = (c.maxWidth - (cols - 1) * 12) / cols;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [for (final card in cards) SizedBox(width: w, child: card)],
      );
    });
  }

  Widget _kpi(String label, int value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: crm.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: color, size: 21),
          ),
          const SizedBox(height: 14),
          Text('$value',
              style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: crm.textPrimary,
                  height: 1.0)),
          const SizedBox(height: 2),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  color: crm.textSecondary)),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool filled;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.filled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: filled
                ? LinearGradient(
                    colors: [color, Color.lerp(color, Colors.black, 0.22)!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: filled ? null : color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(18),
            border: filled
                ? null
                : Border.all(color: color.withValues(alpha: 0.28)),
            boxShadow: filled
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.30),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: filled
                      ? Colors.white.withValues(alpha: 0.18)
                      : color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(11),
                ),
                alignment: Alignment.center,
                child: Icon(icon,
                    color: filled ? Colors.white : color, size: 20),
              ),
              const SizedBox(height: 14),
              Text(label,
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      height: 1.15,
                      fontSize: 14.5,
                      color: filled ? Colors.white : crm.textPrimary)),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyFollowUps extends StatelessWidget {
  final CrmTheme crm;
  const _EmptyFollowUps({required this.crm});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: crm.border),
      ),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFF16A34A).withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.task_alt_rounded,
                color: Color(0xFF16A34A), size: 26),
          ),
          const SizedBox(height: 12),
          Text("You're all caught up",
              style: TextStyle(
                  fontWeight: FontWeight.w700, color: crm.textPrimary)),
          const SizedBox(height: 3),
          Text('No follow-ups due right now.',
              style: TextStyle(fontSize: 12.5, color: crm.textSecondary)),
        ],
      ),
    );
  }
}

class _FollowUpTile extends StatelessWidget {
  final Lead lead;
  final CrmTheme crm;
  final bool overdue;
  final VoidCallback onTap;

  const _FollowUpTile({
    required this.lead,
    required this.crm,
    required this.overdue,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final d = lead.followUpDate!;
    final when = '${d.day} ${_months[d.month - 1]}, ${_fmtTime(d)}';
    final color = overdue ? const Color(0xFFDC2626) : const Color(0xFFF59E0B);
    final initial = lead.name.trim().isEmpty
        ? '?'
        : lead.name.trim()[0].toUpperCase();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: crm.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: crm.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: crm.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(initial,
                    style: TextStyle(
                        color: crm.primary,
                        fontWeight: FontWeight.w800,
                        fontSize: 16)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(lead.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14.5,
                            color: crm.textPrimary)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                            overdue
                                ? Icons.error_rounded
                                : Icons.schedule_rounded,
                            size: 13,
                            color: color),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text('${overdue ? 'Overdue · ' : ''}$when',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: color)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: crm.input,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(Icons.chevron_right_rounded,
                    color: crm.textSecondary, size: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
