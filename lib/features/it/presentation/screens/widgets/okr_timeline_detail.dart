import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/it/domain/models/okr_model.dart';
import 'package:nizan_crm/features/it/domain/okr_pace.dart';
import 'package:nizan_crm/features/it/presentation/screens/widgets/okr_timeline_style.dart';

/// What the detail sheet can ask the screen to do. Each is optional; the sheet only offers
/// what is given AND what the server says the caller may do.
class OkrDetailActions {
  const OkrDetailActions({this.onEdit, this.onCheckIn, this.onAddChild, this.canAddUnder, this.onDelete});

  final void Function(OKRModel okr)? onEdit;
  final void Function(OKRModel okr, KeyResultItem kr)? onCheckIn;
  final void Function(OKRModel parent)? onAddChild;
  final bool Function(OKRModel okr)? canAddUnder;
  final void Function(OKRModel okr)? onDelete;
}

/// Opens objective details for a view (timeline, tree, scorecard) and keeps the open sheet in step with
/// the list: hand it each new list with [update]. One per view, disposed with it.
class OkrDetailLauncher {
  OkrDetailLauncher(List<OKRModel> initial) : _live = ValueNotifier(initial);

  final ValueNotifier<List<OKRModel>> _live;
  var _disposed = false;

  /// The sheet listens to the list; telling it while the view is being built is not allowed (Flutter
  /// refuses to rebuild a listener mid-build), so it hears at the end of the frame.
  void update(List<OKRModel> next) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_disposed) _live.value = next;
    });
  }

  Future<void> open(BuildContext context, OKRModel okr, {required DateTime now, required OkrDetailActions actions}) =>
      showOkrDetailSheet(context, okrs: _live, okrId: okr.id, now: now, actions: actions);

  void dispose() {
    _disposed = true;
    _live.dispose();
  }
}

/// Opens an objective's detail: where it stands against the calendar, its key results (with a
/// check-in button and the last report), and — for those who manage it — edit / add under it /
/// delete. [okrs] is the live list, so the sheet follows a check-in or an edit made from it; if
/// the objective goes away (deleted) the sheet closes itself.
Future<void> showOkrDetailSheet(
  BuildContext context, {
  required ValueListenable<List<OKRModel>> okrs,
  required String okrId,
  required DateTime now,
  required OkrDetailActions actions,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    constraints: const BoxConstraints(maxWidth: 680),
    showDragHandle: true,
    builder: (ctx) => ValueListenableBuilder<List<OKRModel>>(
      valueListenable: okrs,
      builder: (ctx, list, _) {
        final okr = list.where((o) => o.id == okrId).firstOrNull;
        if (okr == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (ctx.mounted && Navigator.of(ctx).canPop()) Navigator.of(ctx).pop();
          });
          return const SizedBox(height: 120);
        }
        return _OkrDetail(okr: okr, all: list, now: now, actions: actions);
      },
    ),
  );
}

class _OkrDetail extends StatelessWidget {
  const _OkrDetail({required this.okr, required this.all, required this.now, required this.actions});

  final OKRModel okr;
  final List<OKRModel> all;
  final DateTime now;
  final OkrDetailActions actions;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final pace = okrPace(okr, now);
    final span = okrSpan(okr, now: now);
    final fmt = DateFormat('d MMM yyyy');
    final parent = okr.parentObjectiveId == null ? null : all.where((o) => o.id == okr.parentObjectiveId).firstOrNull;
    final below = all.where((o) => o.parentObjectiveId == okr.id).toList();
    final level = okr.effectiveLevel;
    final scope = switch (level) {
      'company' => 'Company-wide',
      'department' => okr.department,
      _ => okr.projectName.isNotEmpty ? 'Project · ${okr.projectName}' : 'Project',
    };
    final note = okrPaceNote(pace);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 22),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(padding: const EdgeInsets.only(top: 3), child: OkrLevelChip(level: level, size: 22)),
          const SizedBox(width: 10),
          Expanded(child: Text(okr.objective, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: crm.textPrimary, height: 1.25))),
        ]),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
          OkrHealthChip(pace: pace),
          Text(okr.status.label, style: TextStyle(fontSize: 12, color: crm.textSecondary)),
          Text('·', style: TextStyle(color: crm.textSecondary)),
          Text('${okr.priority.label} priority', style: TextStyle(fontSize: 12, color: crm.textSecondary)),
        ]),
        const SizedBox(height: 16),

        // Progress against the calendar
        Row(children: [
          Text('${pace.progress}%', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: okrHealthColor(pace.health))),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              [
                if (pace.expectedPercent != null && pace.health != OkrHealth.done) 'should be at ${pace.expectedPercent}% by today',
                if (note.isNotEmpty) note,
              ].join(' · '),
              style: TextStyle(fontSize: 12.5, color: crm.textSecondary),
            ),
          ),
        ]),
        const SizedBox(height: 6),
        OkrProgressBar(pace: pace, height: 10),
        if (okr.progressFromKeyResults)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('Worked out from its ${okr.keyResults.length} key result${okr.keyResults.length == 1 ? '' : 's'}', style: TextStyle(fontSize: 11.5, color: crm.textSecondary)),
          ),
        const SizedBox(height: 16),

        _meta(crm, Icons.layers_outlined, 'Scope', scope),
        _meta(crm, Icons.person_outline, 'Owner', okr.projectHeadName.isEmpty ? 'Nobody named' : okr.projectHeadName),
        _meta(
          crm,
          Icons.event_outlined,
          'Dates',
          span.dated
              ? '${fmt.format(span.start)}  →  ${fmt.format(span.end)}  ·  ${span.end.difference(span.start).inDays + 1} days'
              : 'No dates set — drawn from when it was created',
        ),
        if (parent != null) _meta(crm, Icons.subdirectory_arrow_right, 'Contributes to', parent.objective),
        if (below.isNotEmpty) _meta(crm, Icons.account_tree_outlined, 'Fed by', '${below.length} objective${below.length == 1 ? '' : 's'}: ${below.take(3).map((o) => o.objective).join(', ')}${below.length > 3 ? '…' : ''}'),
        if (okr.description.trim().isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(okr.description.trim(), style: TextStyle(fontSize: 13, color: crm.textPrimary, height: 1.4)),
        ],

        const SizedBox(height: 20),
        Text('Key results', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: crm.textPrimary)),
        const SizedBox(height: 8),
        if (okr.keyResults.isEmpty)
          Text('No key results yet. Progress is set on the objective itself.', style: TextStyle(fontSize: 12.5, color: crm.textSecondary))
        else
          for (final kr in okr.keyResults) _KeyResultTile(okr: okr, kr: kr, now: now, onCheckIn: actions.onCheckIn),

        if (okr.access.canManage && (actions.onEdit != null || actions.onAddChild != null || actions.onDelete != null)) ...[
          const SizedBox(height: 22),
          Wrap(spacing: 10, runSpacing: 8, children: [
            if (actions.onEdit != null)
              FilledButton.icon(onPressed: () => actions.onEdit!(okr), icon: const Icon(Icons.edit_outlined, size: 16), label: const Text('Edit objective')),
            if (actions.onAddChild != null && (actions.canAddUnder?.call(okr) ?? true))
              OutlinedButton.icon(onPressed: () => actions.onAddChild!(okr), icon: const Icon(Icons.add, size: 16), label: const Text('Add a contributing objective')),
            if (actions.onDelete != null)
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: Colors.red.shade700),
                onPressed: () => actions.onDelete!(okr),
                icon: const Icon(Icons.delete_outline, size: 16),
                label: const Text('Delete'),
              ),
          ]),
        ],
      ]),
    );
  }

  Widget _meta(CrmTheme crm, IconData icon, String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 15, color: crm.textSecondary),
          const SizedBox(width: 8),
          SizedBox(width: 96, child: Text(label, style: TextStyle(fontSize: 12.5, color: crm.textSecondary))),
          Expanded(child: Text(value, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: crm.textPrimary))),
        ]),
      );
}

class _KeyResultTile extends StatelessWidget {
  const _KeyResultTile({required this.okr, required this.kr, required this.now, required this.onCheckIn});

  final OKRModel okr;
  final KeyResultItem kr;
  final DateTime now;
  final void Function(OKRModel okr, KeyResultItem kr)? onCheckIn;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final color = okrKeyResultColor(kr);
    final stale = krIsStale(okr, kr, now);
    final last = kr.lastCheckInAt;
    final day = DateFormat('d MMM');
    final lastBy = kr.checkIns.isEmpty ? '' : kr.checkIns.last.by;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(color: crm.background, borderRadius: BorderRadius.circular(10), border: Border.all(color: crm.border)),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(kr.completed ? Icons.check_circle : Icons.radio_button_unchecked, size: 15, color: color),
              const SizedBox(width: 6),
              Expanded(child: Text(kr.title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: crm.textPrimary))),
            ]),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(value: kr.attainment, minHeight: 6, backgroundColor: color.withValues(alpha: 0.15), valueColor: AlwaysStoppedAnimation(color)),
            ),
            const SizedBox(height: 5),
            Wrap(spacing: 8, runSpacing: 2, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Text(
                '${okrNumber(kr.currentValue)} / ${okrNumber(kr.targetValue)} ${kr.unit}  ·  ${(kr.attainment * 100).round()}%',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: crm.textPrimary),
              ),
              Text(
                last == null ? 'no reports yet' : 'last report ${day.format(last)}${lastBy.isEmpty ? '' : ' by $lastBy'}',
                style: TextStyle(fontSize: 11.5, color: crm.textSecondary),
              ),
              if (stale)
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.schedule, size: 13, color: okrHealthColor(OkrHealth.atRisk)),
                  const SizedBox(width: 3),
                  Flexible(child: Text('needs a check-in', overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: okrHealthColor(OkrHealth.atRisk)))),
                ]),
            ]),
          ]),
        ),
        if (onCheckIn != null && okr.access.canCheckIn)
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: FilledButton.tonal(
              style: FilledButton.styleFrom(visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(horizontal: 12)),
              onPressed: () => onCheckIn!(okr, kr),
              child: const Text('Check in', style: TextStyle(fontSize: 12.5)),
            ),
          ),
      ]),
    );
  }
}
