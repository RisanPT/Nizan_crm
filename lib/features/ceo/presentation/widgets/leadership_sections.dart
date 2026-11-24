import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/ceo/data/ceo_inbox.dart';
import 'package:nizan_crm/features/ceo/data/decision_models.dart';
import 'package:nizan_crm/features/ceo/presentation/widgets/ceo_cards.dart';
import 'package:nizan_crm/features/ceo/presentation/widgets/decision_card.dart';
import 'package:nizan_crm/features/dashboard/presentation/widgets/dashboard_widgets.dart' show inrShort, kDashBad, kDashGood;

/// The home's first section: what the team has checked and needs a leader for — real cards with Approve / Reject / Later on them,
/// not a count to go and look for.
class CeoDecisionsSection extends StatelessWidget {
  const CeoDecisionsSection({super.key, required this.inbox, this.shown = 3});

  final CeoInbox inbox;

  /// How many cards to show here; the rest are on the Decisions screen.
  final int shown;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final cards = inbox.preview.where((r) => r.isOpen && !r.isDeferredNow).take(shown).toList();
    final more = inbox.desk.pending - cards.length;
    Widget count(int n) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
          decoration: BoxDecoration(color: crm.primary.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(20)),
          child: Text('$n', key: const Key('ceo_needs_count'), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: crm.primary)),
        );

    return CeoCard(
      title: 'Needs your decision',
      subtitle: inbox.desk.pending > 0 && inbox.desk.oldestDays >= 2 ? 'The longest has waited ${inbox.desk.oldestDays} days' : 'Checked by the team, ready for you',
      icon: Icons.gavel_rounded,
      badge: inbox.needsYou > 0 ? count(inbox.needsYou) : null,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (cards.isEmpty && inbox.logOpen == 0)
          Row(children: [
            const Icon(Icons.check_circle_outline_rounded, color: kDashGood, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text('Nothing is waiting for your decision.', key: const Key('ceo_nothing_for_you'), style: TextStyle(color: crm.textSecondary, fontSize: 13))),
          ]),
        for (var i = 0; i < cards.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          DecisionCard(request: cards[i]),
        ],
        if (inbox.desk.deferred > 0)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text('${inbox.desk.deferred} put off to a later date', key: const Key('ceo_deferred_note'), style: TextStyle(fontSize: 12, color: crm.textSecondary)),
          ),
        if (inbox.logOpen > 0)
          InkWell(
            key: const Key('ceo_log_open'),
            onTap: () => context.go('/ceo/decisions?tab=log'),
            child: Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(children: [
                Icon(Icons.edit_note_rounded, size: 18, color: crm.textSecondary),
                const SizedBox(width: 8),
                Expanded(child: Text('${inbox.logOpen} open ${inbox.logOpen == 1 ? 'entry' : 'entries'} in your decisions log', style: TextStyle(fontSize: 13, color: crm.textPrimary))),
                Icon(Icons.chevron_right_rounded, color: crm.textSecondary),
              ]),
            ),
          ),
        if (more > 0 || cards.isNotEmpty)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              key: const Key('ceo_see_all_decisions'),
              onPressed: () => context.go('/ceo/decisions'),
              child: Text(more > 0 ? 'See all $more more' : 'Open the Decisions screen'),
            ),
          ),
      ]),
    );
  }
}

/// What deserves a second look today: alerts from the watch list, and approvals that have been stuck with the team for days.
class CeoAttention extends StatelessWidget {
  const CeoAttention({super.key, required this.inbox, required this.signals});

  final CeoInbox inbox;
  final List<CeoSignal> signals;

  @override
  Widget build(BuildContext context) {
    final alerts = signals.where((s) => s.severity == CeoSeverity.alert).take(3).toList();
    final stale = inbox.team.where((i) => i.isStale).take(3).toList();
    if (alerts.isEmpty && stale.isEmpty) return const SizedBox.shrink(key: Key('ceo_attention_none'));
    final rows = <Widget>[for (final a in alerts) CeoSignalRow(signal: a), for (final s in stale) CeoInboxRow(item: s)];
    final crm = context.crmColors;
    return CeoCard(
      title: 'Needs attention',
      subtitle: 'Alerts, and approvals stuck with the team',
      icon: Icons.priority_high_rounded,
      child: Column(children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) Divider(height: 1, color: crm.border.faded(1.5)),
          rows[i],
        ],
      ]),
    );
  }
}

/// Approvals other people are handling — shown so a stuck one is seen.
class CeoTeamWaiting extends StatelessWidget {
  const CeoTeamWaiting({super.key, required this.inbox});
  final CeoInbox inbox;

  @override
  Widget build(BuildContext context) {
    final team = inbox.team;
    if (team.isEmpty) return const SizedBox.shrink(key: Key('ceo_team_none'));
    final crm = context.crmColors;
    final late = inbox.oldestTeamDays >= 3;
    return CeoCard(
      title: 'Waiting with the team',
      subtitle: late ? 'The longest has waited ${inbox.oldestTeamDays} days' : 'Approvals other people are handling',
      icon: Icons.hourglass_bottom_rounded,
      badge: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(color: (late ? kCeoWatch : crm.textSecondary).withValues(alpha: 0.14), borderRadius: BorderRadius.circular(20)),
        child: Text('${inbox.withTeam}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: late ? kCeoWatch : crm.textSecondary)),
      ),
      child: Column(children: [
        for (var i = 0; i < team.length; i++) ...[
          if (i > 0) Divider(height: 1, color: crm.border.faded(1.5)),
          CeoInboxRow(item: team[i]),
        ],
      ]),
    );
  }
}

/// The last few decisions — by either leader, so neither wonders what the other did.
class CeoRecentDecisions extends StatelessWidget {
  const CeoRecentDecisions({super.key, required this.inbox});
  final CeoInbox inbox;

  @override
  Widget build(BuildContext context) {
    final recent = inbox.recent;
    if (recent.isEmpty) return const SizedBox.shrink(key: Key('ceo_recent_none'));
    final crm = context.crmColors;
    return CeoCard(
      title: 'Recently decided',
      icon: Icons.history_rounded,
      badge: TextButton(
        key: const Key('ceo_recent_all'),
        onPressed: () => context.go('/ceo/decisions?tab=decided'),
        style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
        child: const Text('All'),
      ),
      child: Column(children: [
        for (var i = 0; i < recent.length; i++) ...[
          if (i > 0) Divider(height: 1, color: crm.border.faded(1.5)),
          InkWell(
            key: Key('ceo_recent_${recent[i].id}'),
            onTap: () => context.go('/ceo/decisions?tab=decided&focus=${recent[i].id}'),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(children: [
                Icon(recent[i].status == DecisionStatus.approved ? Icons.check_circle_rounded : Icons.cancel_rounded, size: 18, color: recent[i].status == DecisionStatus.approved ? kDashGood : kDashBad),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(recent[i].title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: crm.textPrimary)),
                    Text(
                      [
                        if (recent[i].decision != null) recent[i].decision!.by.nameWithTitle,
                        if (recent[i].decision?.at != null) DateFormat('d MMM').format(recent[i].decision!.at!),
                        if (recent[i].amount != null) inrShort(recent[i].amount!),
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11.5, color: crm.textSecondary),
                    ),
                  ]),
                ),
              ]),
            ),
          ),
        ],
      ]),
    );
  }
}

/// One headline figure on the Pulse strip: tappable, with how it compares.
class PulseTile extends StatelessWidget {
  const PulseTile({super.key, required this.label, required this.value, this.change, this.good, this.route, this.loading = false});

  final String label;
  final String value;
  final String? change;

  /// null = neutral, true = green, false = red.
  final bool? good;
  final String? route;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final color = good == null ? crm.textSecondary : (good! ? kDashGood : kDashBad);
    final body = Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(color: crm.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: crm.border.faded(2.5))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 0.6, color: crm.textSecondary)),
        const SizedBox(height: 4),
        loading
            ? Container(height: 22, width: 70, decoration: BoxDecoration(color: crm.border.faded(1.5), borderRadius: BorderRadius.circular(6)))
            : FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: crm.textPrimary, letterSpacing: -0.3))),
        if (change != null && change!.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 2), child: Text(change!, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: color))),
      ]),
    );
    return route == null ? body : InkWell(borderRadius: BorderRadius.circular(14), onTap: () => context.go(route!), child: body);
  }
}
