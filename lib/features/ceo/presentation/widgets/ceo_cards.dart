import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/ceo/data/ceo_inbox.dart';
import 'package:nizan_crm/features/dashboard/presentation/widgets/dashboard_widgets.dart' show inr, inrShort, kDashBad, kDashGood;

/// The warm "amber" the dashboards use for "watch" — alongside [kDashGood] / [kDashBad].
const kCeoWatch = Color(0xFFB7791F);

Color severityColor(CeoSeverity s) => switch (s) {
      CeoSeverity.alert => kDashBad,
      CeoSeverity.watch => kCeoWatch,
      CeoSeverity.ok => kDashGood,
    };

/// One card of the CEO home: a title, an optional "Open" link to the full screen, and a body.
class CeoCard extends StatelessWidget {
  const CeoCard({super.key, required this.title, required this.icon, required this.child, this.openRoute, this.badge, this.subtitle});

  final String title;
  final IconData icon;
  final Widget child;

  /// The full screen this card summarises; when set, the header says "Open" and goes there.
  final String? openRoute;
  final Widget? badge;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return Container(
      decoration: BoxDecoration(color: crm.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: crm.border.faded(2.5))),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: crm.primary.withValues(alpha: 0.09), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 19, color: crm.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: crm.textPrimary)),
              if (subtitle != null) Text(subtitle!, style: TextStyle(fontSize: 11.5, color: crm.textSecondary)),
            ]),
          ),
          if (badge != null) ...[badge!, const SizedBox(width: 6)],
          if (openRoute != null)
            TextButton(
              key: Key('ceo_open_${openRoute!}'),
              onPressed: () => context.go(openRoute!),
              style: TextButton.styleFrom(visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(horizontal: 8)),
              child: const Text('Open', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
        ]),
        const SizedBox(height: 12),
        child,
      ]),
    );
  }
}

/// A card body that is loading, failed (with its own retry — one broken endpoint never blanks the page) or has data.
class CeoAsync<T> extends StatelessWidget {
  const CeoAsync({super.key, required this.value, required this.onRetry, required this.builder});

  final AsyncValue<T> value;
  final VoidCallback onRetry;
  final Widget Function(T data) builder;

  @override
  Widget build(BuildContext context) => value.when(
        loading: () => const Padding(padding: EdgeInsets.symmetric(vertical: 18), child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4)))),
        error: (e, _) => AppErrorView(error: e, onRetry: onRetry, compact: true),
        data: builder,
      );
}

/// A big figure with its label and, when there is something to compare with, how it moved.
class CeoStat extends StatelessWidget {
  const CeoStat({super.key, required this.label, required this.value, this.hint, this.change, this.good, this.onTap});

  final String label;
  final String value;
  final String? hint;

  /// "+12%" / "−3 on before"
  final String? change;

  /// null = neutral; true/false colours the change green/red.
  final bool? good;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final changeColor = good == null ? crm.textSecondary : (good! ? kDashGood : kDashBad);
    final body = Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Text(label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: crm.textSecondary)),
      const SizedBox(height: 3),
      FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(value, style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: crm.textPrimary, letterSpacing: -0.3))),
      if (change != null) Text(change!, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: changeColor)),
      if (hint != null) Text(hint!, style: TextStyle(fontSize: 11, color: crm.textSecondary)),
    ]);
    return onTap == null ? body : InkWell(borderRadius: BorderRadius.circular(8), onTap: onTap, child: body);
  }
}

/// Stats laid out two (phone) or more (wide) to a row.
class CeoStatGrid extends StatelessWidget {
  const CeoStatGrid({super.key, required this.stats});
  final List<CeoStat> stats;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final cols = box.maxWidth >= 520 ? 3 : 2;
        final w = (box.maxWidth - (cols - 1) * 14) / cols;
        return Wrap(spacing: 14, runSpacing: 14, children: [for (final s in stats) SizedBox(width: w, child: s)]);
      });
}

String ageLabel(int? days) => days == null ? '' : days <= 0 ? 'today' : days == 1 ? '1 day' : '$days days';

// ── the inbox ────────────────────────────────────────────────────────────────

class CeoInboxRow extends StatelessWidget {
  const CeoInboxRow({super.key, required this.item});
  final CeoInboxItem item;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final stale = item.isStale;
    final sub = [
      if (item.withWhom != null) 'with ${item.withWhom}',
      if (item.amount != null && item.amount! > 0) inrShort(item.amount!),
      if (item.oldestDays != null && item.oldestDays! >= 1) 'oldest ${ageLabel(item.oldestDays)}',
    ].join(' · ');
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        Container(
          key: Key('ceo_count_${item.key}'),
          constraints: const BoxConstraints(minWidth: 34),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: item.isMine ? crm.primary.withValues(alpha: 0.12) : (stale ? kCeoWatch.withValues(alpha: 0.14) : crm.border.faded(1.2)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text('${item.count}', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: item.isMine ? crm.primary : (stale ? kCeoWatch : crm.textPrimary))),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item.label, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: crm.textPrimary)),
            if (sub.isNotEmpty) Text(sub, style: TextStyle(fontSize: 11.5, color: stale ? kCeoWatch : crm.textSecondary, fontWeight: stale ? FontWeight.w700 : FontWeight.w500)),
          ]),
        ),
        if (item.route != null) Icon(Icons.chevron_right_rounded, color: crm.textSecondary),
      ]),
    );
    return item.route == null ? row : InkWell(key: Key('ceo_item_${item.key}'), onTap: () => context.go(item.route!), child: row);
  }
}

class CeoInboxCards extends StatelessWidget {
  const CeoInboxCards({super.key, required this.inbox});
  final CeoInbox inbox;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final mine = inbox.mine;
    final team = inbox.team;
    final nothing = Row(children: [
      const Icon(Icons.check_circle_outline_rounded, color: kDashGood, size: 20),
      const SizedBox(width: 8),
      Expanded(child: Text('Nothing is waiting for your decision.', key: const Key('ceo_nothing_for_you'), style: TextStyle(color: crm.textSecondary, fontSize: 13))),
    ]);

    Widget list(List<CeoInboxItem> items) => Column(children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) Divider(height: 1, color: crm.border.faded(1.5)),
            CeoInboxRow(item: items[i]),
          ],
        ]);

    Widget count(int n, Color c) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
          decoration: BoxDecoration(color: c.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(20)),
          child: Text('$n', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: c)),
        );

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      CeoCard(
        title: 'Needs your decision',
        icon: Icons.gavel_rounded,
        badge: inbox.needsYou > 0 ? count(inbox.needsYou, crm.primary) : null,
        child: mine.isEmpty ? nothing : list(mine),
      ),
      if (team.isNotEmpty) ...[
        const SizedBox(height: 14),
        CeoCard(
          title: 'Waiting with the team',
          subtitle: inbox.oldestTeamDays >= 3 ? 'The longest has waited ${inbox.oldestTeamDays} days' : 'Approvals other people are handling',
          icon: Icons.hourglass_bottom_rounded,
          badge: count(inbox.withTeam, inbox.oldestTeamDays >= 3 ? kCeoWatch : crm.textSecondary),
          child: list(team),
        ),
      ],
    ]);
  }
}

// ── the watch list ───────────────────────────────────────────────────────────

class CeoSignalRow extends StatelessWidget {
  const CeoSignalRow({super.key, required this.signal});
  final CeoSignal signal;

  String get _value => signal.key == 'nps' ? signal.value.toStringAsFixed(0) : signal.value.toStringAsFixed(0);

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final color = severityColor(signal.severity);
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        Container(key: Key('ceo_signal_dot_${signal.key}'), width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(signal.label, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: crm.textPrimary)),
            if (signal.change != null) Text(signal.change!, style: TextStyle(fontSize: 11.5, color: crm.textSecondary)),
          ]),
        ),
        Text(_value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: signal.severity == CeoSeverity.ok ? crm.textPrimary : color)),
        if (signal.route != null) Icon(Icons.chevron_right_rounded, color: crm.textSecondary),
      ]),
    );
    return signal.route == null ? row : InkWell(key: Key('ceo_signal_${signal.key}'), onTap: () => context.go(signal.route!), child: row);
  }
}

class CeoWatchList extends StatelessWidget {
  const CeoWatchList({super.key, required this.signals});
  final List<CeoSignal> signals;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final worrying = signals.where((s) => s.severity != CeoSeverity.ok).length;
    if (signals.isEmpty) return Text('Nothing to watch.', style: TextStyle(color: crm.textSecondary));
    return Column(children: [
      for (var i = 0; i < signals.length; i++) ...[
        if (i > 0) Divider(height: 1, color: crm.border.faded(1.5)),
        CeoSignalRow(signal: signals[i]),
      ],
      if (worrying == 0)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(children: [
            const Icon(Icons.check_circle_outline_rounded, size: 16, color: kDashGood),
            const SizedBox(width: 6),
            Text('All quiet.', key: const Key('ceo_all_quiet'), style: TextStyle(fontSize: 12, color: crm.textSecondary)),
          ]),
        ),
    ]);
  }
}

String rupees(num v) => inr(v);
String rupeesShort(num v) => inrShort(v);
