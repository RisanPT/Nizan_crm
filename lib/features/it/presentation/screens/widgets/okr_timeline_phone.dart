import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/it/domain/models/okr_model.dart';
import 'package:nizan_crm/features/it/domain/okr_pace.dart';
import 'package:nizan_crm/features/it/presentation/screens/widgets/okr_timeline_style.dart';

/// The timeline on a phone: a horizontal Gantt cannot work on a narrow screen, so objectives are
/// listed by the month they fall due, each with a progress ring, how it is doing against the
/// calendar, and its key results. Tap one for the detail.
class OkrPhoneTimeline extends StatelessWidget {
  const OkrPhoneTimeline({
    super.key,
    required this.okrs,
    required this.now,
    required this.onOpen,
  });

  final List<OKRModel> okrs;
  final DateTime now;
  final void Function(OKRModel okr) onOpen;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final byId = {for (final o in okrs) o.id: o};

    // by the month the deadline falls in; no deadline → last
    final groups = <DateTime?, List<OKRModel>>{};
    for (final o in okrs) {
      final d = o.deadline;
      (groups[d == null ? null : DateTime(d.year, d.month)] ??= []).add(o);
    }
    final months = groups.keys.whereType<DateTime>().toList()..sort();
    final keys = <DateTime?>[...months, if (groups.containsKey(null)) null];

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      children: [
        for (final k in keys) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
            child: Row(children: [
              Text(
                k == null ? 'No deadline' : DateFormat('MMMM yyyy').format(k),
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: crm.textPrimary),
              ),
              if (k != null && k.year == now.year && k.month == now.month) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                  decoration: BoxDecoration(color: crm.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                  child: Text('this month', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: crm.primary)),
                ),
              ],
              const Spacer(),
              Text('${groups[k]!.length}', style: TextStyle(fontSize: 12, color: crm.textSecondary)),
            ]),
          ),
          for (final o in (groups[k]!..sort((a, b) => (a.deadline ?? DateTime(2100)).compareTo(b.deadline ?? DateTime(2100)))))
            _card(context, crm, o, byId),
        ],
      ],
    );
  }

  Widget _card(BuildContext context, CrmTheme crm, OKRModel o, Map<String, OKRModel> byId) {
    final pace = okrPace(o, now);
    final color = okrHealthColor(pace.health);
    final span = okrSpan(o, now: now);
    final day = DateFormat('d MMM');
    final parent = o.parentObjectiveId == null ? null : byId[o.parentObjectiveId];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(color: crm.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: crm.border)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => onOpen(o),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            OkrProgressRing(percent: pace.progress, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Padding(padding: const EdgeInsets.only(top: 1), child: OkrLevelChip(level: o.effectiveLevel)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(o.objective, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: crm.textPrimary, height: 1.25)),
                  ),
                ]),
                const SizedBox(height: 6),
                Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  OkrHealthChip(pace: pace, withNote: true),
                  Text(
                    span.dated ? '${day.format(span.start)} → ${day.format(span.end)}' : 'no dates',
                    style: TextStyle(fontSize: 11.5, color: crm.textSecondary),
                  ),
                ]),
                if (parent != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Row(children: [
                      Icon(Icons.subdirectory_arrow_right, size: 14, color: crm.textSecondary),
                      const SizedBox(width: 3),
                      Expanded(child: Text('contributes to ${parent.objective}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, color: crm.textSecondary))),
                    ]),
                  ),
                if (o.keyResults.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  for (final kr in o.keyResults.take(3)) _keyResult(crm, o, kr),
                  if (o.keyResults.length > 3)
                    Text('+ ${o.keyResults.length - 3} more key result${o.keyResults.length - 3 == 1 ? '' : 's'}', style: TextStyle(fontSize: 11.5, color: crm.textSecondary)),
                ],
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _keyResult(CrmTheme crm, OKRModel o, KeyResultItem kr) {
    final color = okrKeyResultColor(kr);
    final stale = krIsStale(o, kr, now);
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(children: [
        Expanded(
          flex: 5,
          child: Text(kr.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: crm.textPrimary)),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 3,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(value: kr.attainment, minHeight: 5, backgroundColor: color.withValues(alpha: 0.15), valueColor: AlwaysStoppedAnimation(color)),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 38,
          child: Text('${(kr.attainment * 100).round()}%', textAlign: TextAlign.right, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: crm.textSecondary)),
        ),
        if (stale) ...[
          const SizedBox(width: 4),
          Tooltip(message: 'Needs a check-in', child: Icon(Icons.schedule, size: 14, color: okrHealthColor(OkrHealth.atRisk))),
        ],
      ]),
    );
  }
}
