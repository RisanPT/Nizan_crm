import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/ceo/data/decision_models.dart';
import 'package:nizan_crm/features/ceo/presentation/widgets/ceo_cards.dart' show kCeoWatch;
import 'package:nizan_crm/features/ceo/presentation/widgets/decision_actions.dart';
import 'package:nizan_crm/features/ceo/services/decision_service.dart';
import 'package:nizan_crm/features/dashboard/presentation/widgets/dashboard_widgets.dart' show inr, kDashBad, kDashGood;

IconData kindIcon(DecisionKind k) => switch (k) {
      DecisionKind.projectProposal => Icons.rocket_launch_outlined,
      DecisionKind.hiringPlan => Icons.person_add_alt_1_outlined,
      DecisionKind.spendExpense => Icons.receipt_long_outlined,
      DecisionKind.spendPayout => Icons.brush_outlined,
      DecisionKind.projectBudget => Icons.account_balance_wallet_outlined,
    };

String _ago(int days) => days <= 0 ? 'today' : '$days d';
String _day(DateTime? d) => d == null ? '' : DateFormat('d MMM').format(d);

/// One thing that needs a leader (or, once decided, the record of it): what it is, how much, who asked, who checked it, and the
/// three things a leader does with it. Tapping the body opens the detail with everything the team attached.
class DecisionCard extends ConsumerWidget {
  const DecisionCard({super.key, required this.request});

  final DecisionRequest request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crm = context.crmColors;
    final r = request;
    final open = r.isOpen;
    return Container(
      key: Key('ceo_decision_${r.id}'),
      decoration: BoxDecoration(color: crm.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: crm.border.faded(2.5))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        InkWell(
          key: Key('ceo_decision_open_${r.id}'),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
          onTap: () => showDecisionDetail(context, ref, r.id),
          child: Padding(
            padding: EdgeInsets.fromLTRB(14, 12, 14, open ? 8 : 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(kindIcon(r.kind), size: 16, color: crm.primary),
                const SizedBox(width: 6),
                Flexible(child: Text(r.kind.label.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 0.6, color: crm.textSecondary))),
                const Spacer(),
                if (r.amount != null) Text(inr(r.amount!), key: Key('ceo_decision_amount_${r.id}'), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: crm.textPrimary)),
              ]),
              const SizedBox(height: 6),
              Text(r.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: crm.textPrimary)),
              if (r.subtitle.isNotEmpty || r.department.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text([r.subtitle, if (!r.subtitle.contains(r.department)) r.department].where((x) => x.isNotEmpty).join(' · '),
                      maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: crm.textSecondary)),
                ),
              const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 4, children: [
                if (r.requestedBy != null) _Chip(text: 'Asked by ${r.requestedBy!.name} · ${_ago(r.waitingDays)}', color: crm.textSecondary),
                if (r.checkedBy != null) _Chip(key: Key('ceo_verified_${r.id}'), icon: Icons.verified_outlined, text: r.checkedLine, color: kDashGood),
                if (open && r.isDeferredNow) _Chip(key: Key('ceo_deferred_${r.id}'), icon: Icons.schedule_rounded, text: 'Put off to ${_day(r.deferredUntil)}', color: kCeoWatch),
                if (!open) _OutcomeChip(r),
              ]),
              if (r.checkNote.isNotEmpty && open)
                Padding(padding: const EdgeInsets.only(top: 6), child: Text('“${r.checkNote}”', maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: crm.textSecondary))),
              if (!open && r.decision != null) _OutcomeLine(r),
              if (r.applyError.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text('Decided, but not yet applied. It will be tried again.', style: const TextStyle(fontSize: 12, color: kDashBad))),
            ]),
          ),
        ),
        if (open && r.canDecide)
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            child: Row(children: [
              Expanded(
                child: FilledButton.icon(
                  key: Key('ceo_approve_${r.id}'),
                  style: FilledButton.styleFrom(backgroundColor: kDashGood, visualDensity: VisualDensity.compact),
                  onPressed: () => runDecision(context, ref, r, DecisionAction.approve),
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const FittedBox(fit: BoxFit.scaleDown, child: Text('Approve')),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  key: Key('ceo_reject_${r.id}'),
                  style: OutlinedButton.styleFrom(foregroundColor: kDashBad, side: const BorderSide(color: kDashBad), visualDensity: VisualDensity.compact),
                  onPressed: () => runDecision(context, ref, r, DecisionAction.reject),
                  icon: const Icon(Icons.close_rounded, size: 18),
                  label: const FittedBox(fit: BoxFit.scaleDown, child: Text('Reject')),
                ),
              ),
              const SizedBox(width: 4),
              TextButton(key: Key('ceo_defer_${r.id}'), onPressed: () => runDecision(context, ref, r, DecisionAction.defer), child: const FittedBox(fit: BoxFit.scaleDown, child: Text('Later'))),
            ]),
          ),
      ]),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({super.key, required this.text, required this.color, this.icon});
  final String text;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon, size: 13, color: color), const SizedBox(width: 4)],
          Flexible(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: color))),
        ]),
      );
}

class _OutcomeChip extends StatelessWidget {
  const _OutcomeChip(this.r);
  final DecisionRequest r;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (r.status) {
      DecisionStatus.approved => ('Approved', kDashGood),
      DecisionStatus.rejected => ('Rejected', kDashBad),
      DecisionStatus.withdrawn => ('Withdrawn', kCeoWatch),
      DecisionStatus.superseded => ('Changed — checked again', kCeoWatch),
      _ => ('', kCeoWatch),
    };
    return _Chip(key: Key('ceo_outcome_${r.id}'), text: label, color: color);
  }
}

class _OutcomeLine extends StatelessWidget {
  const _OutcomeLine(this.r);
  final DecisionRequest r;

  @override
  Widget build(BuildContext context) {
    final d = r.decision!;
    final crm = context.crmColors;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        '${d.by.nameWithTitle}${d.at == null ? '' : ' · ${_day(d.at)}'}${d.note.isEmpty ? '' : ': “${d.note}”'}',
        key: Key('ceo_outcome_line_${r.id}'),
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 12.5, color: crm.textSecondary),
      ),
    );
  }
}

/// Everything about one request: the numbers behind it, what the team attached, who checked it and what has happened to it.
Future<void> showDecisionDetail(BuildContext context, WidgetRef ref, String id) {
  final wide = MediaQuery.sizeOf(context).width >= 700;
  final body = _DecisionDetail(id: id);
  if (wide) {
    return showDialog<void>(context: context, builder: (_) => Dialog(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 560, maxHeight: 640), child: body)));
  }
  return showModalBottomSheet<void>(context: context, isScrollControlled: true, useSafeArea: true, showDragHandle: true, builder: (_) => body);
}

class _DecisionDetail extends ConsumerWidget {
  const _DecisionDetail({required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crm = context.crmColors;
    final detail = ref.watch(decisionDetailProvider(id));
    return detail.when(
      loading: () => const SizedBox(height: 200, child: Center(child: CircularProgressIndicator())),
      error: (e, _) => Padding(padding: const EdgeInsets.all(24), child: Text('Could not load this decision.', style: TextStyle(color: crm.textSecondary))),
      data: (r) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(r.kind.label.toUpperCase(), style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 0.6, color: crm.textSecondary)),
          const SizedBox(height: 4),
          Text(r.title, key: const Key('ceo_detail_title'), style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: crm.textPrimary)),
          if (r.amount != null) Padding(padding: const EdgeInsets.only(top: 2), child: Text(inr(r.amount!), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: crm.textPrimary))),
          const SizedBox(height: 12),
          if (r.checkedBy != null)
            _Chip(icon: Icons.verified_outlined, text: '${r.checkedLine}${r.checkedAt == null ? '' : ' · ${_day(r.checkedAt)}'}', color: kDashGood),
          if (r.checkNote.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text('“${r.checkNote}”', style: TextStyle(fontStyle: FontStyle.italic, color: crm.textSecondary))),
          const SizedBox(height: 12),
          for (final row in r.summary)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(width: 120, child: Text(row.label.trim(), style: TextStyle(fontSize: 12.5, color: crm.textSecondary))),
                Expanded(child: Text(row.value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: crm.textPrimary))),
              ]),
            ),
          for (final a in r.attachments)
            Padding(padding: const EdgeInsets.only(top: 6), child: Row(children: [const Icon(Icons.attach_file_rounded, size: 16), const SizedBox(width: 4), Text(a.label, style: TextStyle(color: crm.textSecondary))])),
          if (r.history.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text('WHAT HAS HAPPENED', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 0.6, color: crm.textSecondary)),
            const SizedBox(height: 4),
            for (final h in r.history)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text('${_day(h.at)} · ${_historyLine(h)}', style: TextStyle(fontSize: 12.5, color: crm.textPrimary)),
              ),
          ],
          const SizedBox(height: 14),
          Row(children: [
            if (r.sourceRoute != null)
              TextButton(key: const Key('ceo_detail_source'), onPressed: () {
                Navigator.pop(context);
                context.go(r.sourceRoute!);
              }, child: const Text('Open the source')),
            const Spacer(),
            if (r.isOpen && r.canDecide) ...[
              OutlinedButton(
                key: const Key('ceo_detail_reject'),
                style: OutlinedButton.styleFrom(foregroundColor: kDashBad),
                onPressed: () async {
                  Navigator.pop(context);
                  await runDecision(context, ref, r, DecisionAction.reject);
                },
                child: const Text('Reject'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                key: const Key('ceo_detail_approve'),
                style: FilledButton.styleFrom(backgroundColor: kDashGood),
                onPressed: () async {
                  Navigator.pop(context);
                  await runDecision(context, ref, r, DecisionAction.approve);
                },
                child: const Text('Approve'),
              ),
            ],
          ]),
        ]),
      ),
    );
  }
}

String _historyLine(DecisionEvent h) {
  final who = h.by?.name.isNotEmpty == true ? h.by!.nameWithTitle : '';
  final verb = switch (h.action) {
    'requested' => 'Asked',
    'checked' => 'Checked',
    'approved' => 'Approved',
    'rejected' => 'Rejected',
    'deferred' => 'Put off',
    'withdrawn' => 'Withdrawn',
    'superseded' => 'Changed, so checked again',
    'applied' => 'Carried out',
    'apply_failed' => 'Could not be carried out yet',
    _ => h.action,
  };
  return [if (who.isNotEmpty) '$verb by $who' else verb, if (h.note.isNotEmpty) '“${h.note}”'].join(' ');
}
