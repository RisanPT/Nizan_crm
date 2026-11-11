import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/it/domain/models/okr_model.dart';
import 'package:nizan_crm/features/it/domain/okr_pace.dart';
import 'package:nizan_crm/features/it/domain/okr_scorecard.dart';
import 'package:nizan_crm/features/it/presentation/screens/widgets/okr_filters.dart';
import 'package:nizan_crm/features/it/presentation/screens/widgets/okr_timeline_detail.dart';
import 'package:nizan_crm/features/it/presentation/screens/widgets/okr_timeline_style.dart';

/// The OKR scorecard: the numbers a leader reads first. Headline figures, then a line for each
/// department (or owner, level, project) with its average progress and a bar of how its objectives are
/// doing — worst first, tap one to see them — and underneath, what needs somebody now: the objectives
/// in trouble and the key results nobody has reported on.
class OkrScorecardView extends StatefulWidget {
  const OkrScorecardView({
    super.key,
    required this.okrs,
    this.actions = const OkrDetailActions(),
    this.onAddOkr,
    this.filter,
    this.onFilterChanged,
    this.now,
  });

  final List<OKRModel> okrs;
  final OkrDetailActions actions;
  final VoidCallback? onAddOkr;

  /// Shared with the other views when given; otherwise the scorecard keeps its own.
  final OkrFilter? filter;
  final ValueChanged<OkrFilter>? onFilterChanged;

  /// The clock (tests, screenshots); defaults to now.
  final DateTime? now;

  @override
  State<OkrScorecardView> createState() => _OkrScorecardViewState();
}

/// How many entries the two action lists show before "Show all".
const _listLimit = 6;

class _OkrScorecardViewState extends State<OkrScorecardView> {
  late final OkrDetailLauncher _detail = OkrDetailLauncher(widget.okrs);
  OkrFilter _ownFilter = const OkrFilter();
  OkrGroupBy _by = OkrGroupBy.department;
  final Set<String> _open = {};
  bool _allAttention = false;
  bool _allStale = false;

  DateTime get _now => widget.now ?? DateTime.now();
  OkrFilter get _filter => widget.filter ?? _ownFilter;

  void _setFilter(OkrFilter f) {
    widget.onFilterChanged?.call(f);
    if (widget.filter == null) setState(() => _ownFilter = f);
  }

  @override
  void didUpdateWidget(covariant OkrScorecardView old) {
    super.didUpdateWidget(old);
    if (!identical(old.okrs, widget.okrs)) _detail.update(widget.okrs);
  }

  @override
  void dispose() {
    _detail.dispose();
    super.dispose();
  }

  void _openDetail(OKRModel o) => _detail.open(context, o, now: _now, actions: widget.actions);

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    if (widget.okrs.isEmpty) return _empty(crm);

    final now = _now;
    final visible = _filter.apply(widget.okrs, now);
    final sc = buildOkrScorecard(visible, now, _by);

    return LayoutBuilder(
      builder: (context, c) {
        final phone = c.maxWidth < 720;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OkrFilterBar(okrs: widget.okrs, filter: _filter, onChanged: _setFilter, now: now, trailing: [_groupBy(crm, phone)]),
            Expanded(
              child: visible.isEmpty
                  ? _noMatch(crm)
                  : ListView(
                      padding: EdgeInsets.fromLTRB(phone ? 10 : 16, 14, phone ? 10 : 16, 28),
                      children: [
                        _kpis(crm, sc, c.maxWidth - (phone ? 20 : 32)),
                        const SizedBox(height: 16),
                        _table(crm, sc, phone, now),
                        const SizedBox(height: 16),
                        if (c.maxWidth >= 960)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: _attentionCard(crm, sc, now)),
                              const SizedBox(width: 16),
                              Expanded(child: _staleCard(crm, sc, now)),
                            ],
                          )
                        else ...[
                          _attentionCard(crm, sc, now),
                          const SizedBox(height: 16),
                          _staleCard(crm, sc, now),
                        ],
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _empty(CrmTheme crm) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.leaderboard_outlined, size: 54, color: crm.textSecondary.withValues(alpha: 0.5)),
          const SizedBox(height: 12),
          Text(
            'No objectives to score yet',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: crm.textPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            'Once objectives have dates and progress, this adds them up by department and shows what needs attention.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, color: crm.textSecondary),
          ),
          const SizedBox(height: 16),
          if (widget.onAddOkr != null)
            FilledButton.icon(onPressed: widget.onAddOkr, icon: const Icon(Icons.add, size: 16), label: const Text('New objective')),
        ],
      ),
    ),
  );

  Widget _noMatch(CrmTheme crm) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Nothing matches these filters',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: crm.textPrimary),
        ),
        const SizedBox(height: 8),
        TextButton(onPressed: () => _setFilter(const OkrFilter()), child: const Text('Clear filters')),
      ],
    ),
  );

  // ── group by ──────────────────────────────────────────────────────────────

  Widget _groupBy(CrmTheme crm, bool phone) {
    if (!phone) {
      return SegmentedButton<OkrGroupBy>(
        showSelectedIcon: false,
        style: const ButtonStyle(visualDensity: VisualDensity.compact, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
        segments: [
          for (final g in OkrGroupBy.values)
            ButtonSegment(
              value: g,
              label: Text(g.label, style: const TextStyle(fontSize: 11.5)),
            ),
        ],
        selected: {_by},
        onSelectionChanged: (s) => setState(() {
          _by = s.first;
          _open.clear();
        }),
      );
    }
    return PopupMenuButton<OkrGroupBy>(
      tooltip: '',
      onSelected: (g) => setState(() {
        _by = g;
        _open.clear();
      }),
      itemBuilder: (_) => [for (final g in OkrGroupBy.values) PopupMenuItem(value: g, child: Text(g.label))],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: crm.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.groups_outlined, size: 14, color: crm.textSecondary),
            const SizedBox(width: 5),
            Text(
              'Group by ${_by.label.toLowerCase()}',
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: crm.textSecondary),
            ),
            Icon(Icons.arrow_drop_down, size: 16, color: crm.textSecondary),
          ],
        ),
      ),
    );
  }

  // ── headline numbers ──────────────────────────────────────────────────────

  Widget _kpis(CrmTheme crm, OkrScorecard sc, double width) {
    final o = sc.overall;
    final cols = width >= 900 ? 6 : (width >= 520 ? 3 : 2);
    const gap = 10.0;
    final w = (width - gap * (cols - 1)) / cols;
    final healthy = o.healthyPercent;
    final done = o.count(OkrHealth.done);

    Widget kpi(String label, String value, String sub, Color color, {double? bar}) => SizedBox(
      width: w,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: crm.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: crm.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: crm.textSecondary),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: color, height: 1.1),
            ),
            if (bar != null) ...[
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: bar,
                  minHeight: 5,
                  backgroundColor: color.withValues(alpha: 0.15),
                  valueColor: AlwaysStoppedAnimation(color),
                ),
              ),
            ],
            const SizedBox(height: 4),
            Text(
              sub,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: crm.textSecondary, height: 1.25),
            ),
          ],
        ),
      ),
    );

    return Wrap(
      spacing: gap,
      runSpacing: gap,
      children: [
        kpi(
          'Attainment',
          '${o.avgProgress}%',
          'average over ${o.okrs.length} objective${o.okrs.length == 1 ? '' : 's'}',
          crm.primary,
          bar: o.avgProgress / 100,
        ),
        kpi(
          'Healthy',
          healthy == null ? '—' : '$healthy%',
          healthy == null ? 'nothing to judge yet' : 'of those that can be judged are done or on track',
          okrHealthColor(OkrHealth.onTrack),
        ),
        kpi(
          'Need attention',
          '${o.attention}',
          '${o.count(OkrHealth.atRisk)} at risk · ${o.count(OkrHealth.offTrack)} off track · ${o.count(OkrHealth.blocked)} blocked',
          o.attention > 0 ? okrHealthColor(OkrHealth.offTrack) : crm.textPrimary,
        ),
        kpi('Overdue', '${o.overdue}', 'past their deadline, not finished', o.overdue > 0 ? okrHealthColor(OkrHealth.offTrack) : crm.textPrimary),
        kpi(
          'Check-ins due',
          '${o.staleKeyResults}',
          'of ${o.keyResults} key results, nobody has reported lately',
          o.staleKeyResults > 0 ? okrHealthColor(OkrHealth.atRisk) : crm.textPrimary,
        ),
        kpi('Done', '$done', 'of ${o.okrs.length} objectives', okrHealthColor(OkrHealth.done)),
      ],
    );
  }

  // ── the table ─────────────────────────────────────────────────────────────

  Widget _table(CrmTheme crm, OkrScorecard sc, bool phone, DateTime now) {
    return _Panel(
      title: 'By ${_by.label.toLowerCase()}',
      trailing: const _Legend(),
      trailingBelow: phone, // no room beside the title on a phone
      child: Column(
        children: [
          for (var i = 0; i < sc.groups.length; i++) ...[
            if (i > 0) Divider(height: 1, color: crm.border.withValues(alpha: 0.6)),
            _groupRow(crm, sc.groups[i], phone, now),
          ],
        ],
      ),
    );
  }

  Widget _groupRow(CrmTheme crm, OkrScoreGroup g, bool phone, DateTime now) {
    final open = _open.contains(g.name);
    final attention = g.attention > 0 ? okrHealthColor(OkrHealth.offTrack) : crm.textSecondary;

    final name = Row(
      children: [
        Icon(open ? Icons.expand_more : Icons.chevron_right, size: 20, color: crm.textSecondary),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            g.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: crm.textPrimary),
          ),
        ),
        const SizedBox(width: 6),
        Text('${g.okrs.length}', style: TextStyle(fontSize: 11.5, color: crm.textSecondary)),
      ],
    );
    final attain = Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: g.avgProgress / 100,
              minHeight: 7,
              backgroundColor: crm.border.withValues(alpha: 0.7),
              valueColor: AlwaysStoppedAnimation(crm.primary),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 36,
          child: Text(
            '${g.avgProgress}%',
            textAlign: TextAlign.right,
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: crm.textPrimary),
          ),
        ),
      ],
    );
    final flags = Wrap(
      spacing: 10,
      runSpacing: 2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (g.attention > 0) _flag(Icons.warning_amber_rounded, '${g.attention}', 'need attention', attention),
        if (g.overdue > 0) _flag(Icons.event_busy_outlined, '${g.overdue}', 'overdue', okrHealthColor(OkrHealth.offTrack)),
        if (g.staleKeyResults > 0) _flag(Icons.schedule, '${g.staleKeyResults}', 'check-ins due', okrHealthColor(OkrHealth.atRisk)),
        if (g.attention == 0 && g.overdue == 0 && g.staleKeyResults == 0)
          Text(
            'all clear',
            style: TextStyle(fontSize: 11.5, color: okrHealthColor(OkrHealth.onTrack), fontWeight: FontWeight.w600),
          ),
      ],
    );

    return Column(
      children: [
        InkWell(
          onTap: () => setState(() => open ? _open.remove(g.name) : _open.add(g.name)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: phone
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      name,
                      const SizedBox(height: 8),
                      attain,
                      const SizedBox(height: 8),
                      _HealthBar(group: g),
                      const SizedBox(height: 6),
                      flags,
                    ],
                  )
                : Row(
                    children: [
                      Expanded(flex: 26, child: name),
                      const SizedBox(width: 14),
                      Expanded(flex: 24, child: attain),
                      const SizedBox(width: 18),
                      Expanded(flex: 30, child: _HealthBar(group: g)),
                      const SizedBox(width: 18),
                      Expanded(flex: 26, child: flags),
                    ],
                  ),
          ),
        ),
        if (open)
          Container(
            color: crm.background.withValues(alpha: 0.6),
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: Column(children: [for (final o in _worstFirst(g.okrs, now)) _objectiveRow(crm, o, now, phone)]),
          ),
      ],
    );
  }

  /// Objectives that need attention first, then the least progressed.
  List<OKRModel> _worstFirst(List<OKRModel> list, DateTime now) {
    final out = [...list];
    out.sort((a, b) {
      final pa = okrPace(a, now);
      final pb = okrPace(b, now);
      if (pa.health.needsAttention != pb.health.needsAttention) return pa.health.needsAttention ? -1 : 1;
      final c = pa.progress.compareTo(pb.progress);
      return c != 0 ? c : a.objective.toLowerCase().compareTo(b.objective.toLowerCase());
    });
    return out;
  }

  Widget _flag(IconData icon, String n, String tip, Color color) => Tooltip(
    message: '$n $tip',
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 3),
        Text(
          n,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color),
        ),
      ],
    ),
  );

  Widget _objectiveRow(CrmTheme crm, OKRModel o, DateTime now, bool phone, {bool showNote = false}) {
    final pace = okrPace(o, now);
    final color = okrHealthColor(pace.health);
    final owner = o.projectHeadName;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => _openDetail(o),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Row(
          children: [
            OkrLevelChip(level: o.effectiveLevel),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    o.objective,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: crm.textPrimary),
                  ),
                  if (owner.isNotEmpty || showNote)
                    Text(
                      [if (owner.isNotEmpty) owner, if (showNote && okrPaceNote(pace).isNotEmpty) okrPaceNote(pace)].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: crm.textSecondary),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (!phone) Flexible(flex: 0, child: OkrHealthChip(pace: pace)),
            if (!phone) const SizedBox(width: 10),
            if (phone)
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
            if (phone) const SizedBox(width: 8),
            SizedBox(
              width: 38,
              child: Text(
                '${pace.progress}%',
                textAlign: TextAlign.right,
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── what needs somebody ───────────────────────────────────────────────────

  Widget _attentionCard(CrmTheme crm, OkrScorecard sc, DateTime now) {
    final items = _allAttention ? sc.attention : sc.attention.take(_listLimit).toList();
    return _Panel(
      title: 'Needs attention',
      count: sc.attention.length,
      child: sc.attention.isEmpty
          ? _allClear(crm, 'Nothing is at risk, off track or blocked.')
          : Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 6),
              child: Column(
                children: [
                  for (final a in items) _objectiveRow(crm, a.okr, now, false, showNote: true),
                  if (sc.attention.length > _listLimit)
                    TextButton(
                      onPressed: () => setState(() => _allAttention = !_allAttention),
                      child: Text(_allAttention ? 'Show fewer' : 'Show all ${sc.attention.length}'),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _staleCard(CrmTheme crm, OkrScorecard sc, DateTime now) {
    final items = _allStale ? sc.stale : sc.stale.take(_listLimit).toList();
    final day = DateFormat('d MMM');
    return _Panel(
      title: 'Needs a check-in',
      count: sc.stale.length,
      child: sc.stale.isEmpty
          ? _allClear(crm, 'Every running key result has been reported on lately.')
          : Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 6),
              child: Column(
                children: [
                  for (final s in items)
                    InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => _openDetail(s.okr),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                        child: Row(
                          children: [
                            Icon(Icons.schedule, size: 16, color: okrHealthColor(OkrHealth.atRisk)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    s.kr.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: crm.textPrimary),
                                  ),
                                  Text(
                                    '${s.okr.objective} · ${s.lastCheckIn == null ? 'never reported on' : 'last report ${day.format(s.lastCheckIn!)} (${now.difference(s.lastCheckIn!).inDays} days ago)'}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 11, color: crm.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                            if (widget.actions.onCheckIn != null && s.okr.access.canCheckIn)
                              Padding(
                                padding: const EdgeInsets.only(left: 8),
                                child: FilledButton.tonal(
                                  style: FilledButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.symmetric(horizontal: 10),
                                  ),
                                  onPressed: () => widget.actions.onCheckIn!(s.okr, s.kr),
                                  child: const Text('Check in', style: TextStyle(fontSize: 12)),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  if (sc.stale.length > _listLimit)
                    TextButton(
                      onPressed: () => setState(() => _allStale = !_allStale),
                      child: Text(_allStale ? 'Show fewer' : 'Show all ${sc.stale.length}'),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _allClear(CrmTheme crm, String text) => Padding(
    padding: const EdgeInsets.all(16),
    child: Row(
      children: [
        Icon(Icons.check_circle_outline, size: 18, color: okrHealthColor(OkrHealth.onTrack)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: TextStyle(fontSize: 12.5, color: crm.textSecondary)),
        ),
      ],
    ),
  );
}

/// A titled white card.
class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.child, this.count, this.trailing, this.trailingBelow = false});

  final String title;
  final Widget child;
  final int? count;
  final Widget? trailing;

  /// Put [trailing] on its own line under the title instead of beside it.
  final bool trailingBelow;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return Container(
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: crm.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: crm.textPrimary),
                  ),
                ),
                if (count != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                    decoration: BoxDecoration(color: crm.border.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(8)),
                    child: Text(
                      '$count',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: crm.textSecondary),
                    ),
                  ),
                ],
                const Spacer(),
                if (trailing != null && !trailingBelow) Flexible(child: trailing!),
              ],
            ),
          ),
          if (trailing != null && trailingBelow)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
              child: Align(alignment: Alignment.centerLeft, child: trailing!),
            ),
          Divider(height: 1, color: crm.border.withValues(alpha: 0.6)),
          child,
        ],
      ),
    );
  }
}

const _barOrder = [
  OkrHealth.done,
  OkrHealth.onTrack,
  OkrHealth.atRisk,
  OkrHealth.offTrack,
  OkrHealth.blocked,
  OkrHealth.notStarted,
  OkrHealth.unscheduled,
];

/// One bar for a line: a segment per state, as wide as its share of the objectives.
class _HealthBar extends StatelessWidget {
  const _HealthBar({required this.group});

  final OkrScoreGroup group;

  @override
  Widget build(BuildContext context) {
    final parts = [
      for (final h in _barOrder)
        if (group.count(h) > 0) h,
    ];
    return Tooltip(
      message: [for (final h in parts) '${group.count(h)} ${h.label.toLowerCase()}'].join(' · '),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(5),
        child: SizedBox(
          height: 10,
          child: Row(
            children: [
              for (final h in parts)
                Expanded(
                  flex: group.count(h),
                  child: Container(color: okrHealthColor(h), margin: const EdgeInsets.only(right: 1)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return Wrap(
      alignment: WrapAlignment.end,
      spacing: 10,
      runSpacing: 2,
      children: [
        for (final h in _barOrder.take(5))
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: okrHealthColor(h), borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  h.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 10.5, color: crm.textSecondary),
                ),
              ),
            ],
          ),
      ],
    );
  }
}
