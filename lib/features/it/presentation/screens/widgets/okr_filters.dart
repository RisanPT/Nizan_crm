import 'package:flutter/material.dart';

import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/it/domain/models/okr_model.dart';
import 'package:nizan_crm/features/it/domain/okr_pace.dart';
import 'package:nizan_crm/features/it/presentation/screens/widgets/okr_timeline_style.dart';

/// What the timeline, the tree and the scorecard are narrowed to: some states, one level, one
/// owner. One of these is shared by all three views, so switching view keeps it.
class OkrFilter {
  const OkrFilter({this.health = const {}, this.level, this.owner});

  final Set<OkrHealth> health;
  final String? level;
  final String? owner;

  bool get active => health.isNotEmpty || level != null || owner != null;

  OkrFilter withHealth(OkrHealth h) => OkrFilter(health: health.contains(h) ? ({...health}..remove(h)) : {...health, h}, level: level, owner: owner);
  OkrFilter withLevel(String? v) => OkrFilter(health: health, level: v, owner: owner);
  OkrFilter withOwner(String? v) => OkrFilter(health: health, level: level, owner: v);

  /// Level and owner only — what the state chips count within.
  bool inScope(OKRModel o) => (level == null || o.effectiveLevel == level) && (owner == null || o.projectHeadName == owner);

  /// [okrs] narrowed to this filter on [now].
  List<OKRModel> apply(List<OKRModel> okrs, DateTime now) {
    final scoped = okrs.where(inScope);
    return (health.isEmpty ? scoped : scoped.where((o) => health.contains(okrPace(o, now).health))).toList();
  }
}

/// The state chips (with counts), the level and owner pickers, and whatever the view adds after
/// them ([trailing]): the strip across the top of the timeline, the tree and the scorecard.
class OkrFilterBar extends StatelessWidget {
  const OkrFilterBar({super.key, required this.okrs, required this.filter, required this.onChanged, required this.now, this.trailing = const []});

  /// Every objective, before any filter.
  final List<OKRModel> okrs;
  final OkrFilter filter;
  final ValueChanged<OkrFilter> onChanged;
  final DateTime now;
  final List<Widget> trailing;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final counts = okrHealthCounts(okrs.where(filter.inScope), now);
    final levels = {for (final o in okrs) o.effectiveLevel}.toList()..sort((a, b) => okrLevelOrder(a).compareTo(okrLevelOrder(b)));
    final owners = {
      for (final o in okrs)
        if (o.projectHeadName.isNotEmpty) o.projectHeadName,
    }.toList()..sort();
    const order = [
      OkrHealth.offTrack,
      OkrHealth.atRisk,
      OkrHealth.blocked,
      OkrHealth.onTrack,
      OkrHealth.done,
      OkrHealth.notStarted,
      OkrHealth.unscheduled,
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: crm.surface,
        border: Border(bottom: BorderSide(color: crm.border)),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final h in order)
            if ((counts[h] ?? 0) > 0) _healthChip(h, counts[h]!),
          if (levels.length > 1)
            _menu(
              crm,
              icon: Icons.layers_outlined,
              label: filter.level == null ? 'All levels' : okrLevelName(filter.level!).replaceAll(' objective', ''),
              active: filter.level != null,
              values: levels,
              text: okrLevelName,
              onPick: (v) => onChanged(filter.withLevel(v)),
              clearLabel: 'All levels',
            ),
          if (owners.length > 1)
            _menu(
              crm,
              icon: Icons.person_outline,
              label: filter.owner ?? 'Everyone',
              active: filter.owner != null,
              values: owners,
              text: (v) => v,
              onPick: (v) => onChanged(filter.withOwner(v)),
              clearLabel: 'Everyone',
            ),
          ...trailing,
        ],
      ),
    );
  }

  Widget _healthChip(OkrHealth h, int n) {
    final color = okrHealthColor(h);
    final on = filter.health.contains(h);
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => onChanged(filter.withHealth(h)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: on ? color : color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: on ? 1 : 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: on ? Colors.white : color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(
              '${h.label}  $n',
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: on ? Colors.white : color),
            ),
          ],
        ),
      ),
    );
  }

  Widget _menu(
    CrmTheme crm, {
    required IconData icon,
    required String label,
    required bool active,
    required List<String> values,
    required String Function(String) text,
    required void Function(String?) onPick,
    required String clearLabel,
  }) {
    // by position: -1 is "clear", so a real value can never be mistaken for it
    return PopupMenuButton<int>(
      tooltip: '',
      onSelected: (i) => onPick(i < 0 ? null : values[i]),
      itemBuilder: (_) => [
        PopupMenuItem<int>(value: -1, child: Text(clearLabel)),
        for (var i = 0; i < values.length; i++) PopupMenuItem<int>(value: i, child: Text(text(values[i]))),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: active ? crm.primary.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: active ? crm.primary : crm.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: active ? crm.primary : crm.textSecondary),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: active ? crm.primary : crm.textSecondary),
            ),
            Icon(Icons.arrow_drop_down, size: 16, color: crm.textSecondary),
          ],
        ),
      ),
    );
  }
}
