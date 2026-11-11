import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/dashboard/presentation/widgets/dashboard_widgets.dart' show kDashGood;
import 'package:nizan_crm/features/it/domain/models/monthly_objective.dart';
import 'package:nizan_crm/features/it/domain/monthly_objective_stats.dart';
import 'package:nizan_crm/features/it/presentation/screens/widgets/monthly_objective_dialogs.dart';
import 'package:nizan_crm/features/it/presentation/screens/widgets/monthly_objectives_cards.dart';
import 'package:nizan_crm/features/it/presentation/screens/widgets/project_dashboard_kit.dart';
import 'package:nizan_crm/features/it/services/monthly_objective_service.dart';

// The objectives of the month as a table (and, on a phone, as cards): title, department, owner, priority, progress and status, with a
// search box, filters and "Set Objective". Opening a row shows its key results (and, for those who may, the buttons to report on them);
// the menu on a row edits, postpones, cancels, reopens or deletes it. Also the Key Results tab, which lists every key result of the month.

// ── the table ────────────────────────────────────────────────────────────────

class ObjectivesTable extends StatelessWidget {
  const ObjectivesTable({
    super.key,
    required this.objectives,
    required this.departments,
    required this.month,
    required this.filter,
    required this.onFilterChanged,
    required this.canSet,
    required this.onSet,
    required this.onToast,
    this.inScope = 0,
  });

  /// What the filter lets through.
  final List<MonthlyObjective> objectives;
  final List<MonthlyDepartment> departments;
  final MonthKey month;
  final ObjectiveFilter filter;
  final ValueChanged<ObjectiveFilter> onFilterChanged;

  /// May this person set an objective for some department (the button is not shown otherwise).
  final bool canSet;
  final VoidCallback onSet;
  final void Function(String) onToast;

  /// How many objectives there are before the filter (to tell "nothing set" from "nothing matches").
  final int inScope;

  Future<void> _filters(BuildContext context) async {
    final next = await showObjectiveFilters(context, filter);
    if (next != null) onFilterChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final title = 'Objectives – ${monthTitle(month)}';
    return Container(
      key: const Key('mo_table'),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: crm.border),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.025), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: LayoutBuilder(
        builder: (context, box) {
          final wide = box.maxWidth >= 900;
          final search = SizedBox(
            width: wide ? 250 : double.infinity,
            height: 40,
            child: TextField(
              key: const Key('mo_search'),
              onChanged: (v) => onFilterChanged(filter.copyWith(query: v)),
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search objectives…',
                prefixIcon: const Icon(Icons.search_rounded, size: 18),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: crm.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: crm.border)),
              ),
            ),
          );
          final filters = OutlinedButton.icon(
            key: const Key('mo_filters'),
            onPressed: () => _filters(context),
            icon: const Icon(Icons.filter_list_rounded, size: 18),
            label: Text(filter.activeCount == 0 ? 'Filters' : 'Filters · ${filter.activeCount}', key: const Key('mo_filters_label')),
            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40), foregroundColor: crm.textPrimary, side: BorderSide(color: crm.border)),
          );
          final set = canSet
              ? FilledButton.icon(
                  key: const Key('mo_set'),
                  onPressed: onSet,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Set Objective'),
                  style: FilledButton.styleFrom(backgroundColor: crm.primary, minimumSize: const Size(0, 40)),
                )
              : null;
          final heading = Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(color: crm.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(9)),
                child: Icon(Icons.track_changes_rounded, size: 17, color: crm.primary),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  title,
                  key: const Key('mo_table_title'),
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: crm.textPrimary, letterSpacing: -0.2),
                ),
              ),
            ],
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (wide)
                Row(children: [Expanded(child: heading), search, const SizedBox(width: 10), filters, if (set != null) ...[const SizedBox(width: 10), set]])
              else ...[
                heading,
                const SizedBox(height: 10),
                search,
                const SizedBox(height: 8),
                Row(children: [filters, if (set != null) ...[const SizedBox(width: 10), Expanded(child: set)]]),
              ],
              const SizedBox(height: 12),
              if (objectives.isEmpty)
                _empty(crm)
              else ...[
                if (wide) _head(crm),
                for (final o in objectives)
                  _ObjectiveRow(
                    key: ValueKey('mo_row_${o.id}'),
                    objective: o,
                    department: departments.where((d) => d.departmentId == o.departmentId).firstOrNull,
                    deptIndex: departments.indexWhere((d) => d.departmentId == o.departmentId),
                    month: month,
                    wide: wide,
                    onToast: onToast,
                  ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _empty(CrmTheme crm) {
    final filtered = inScope > 0;
    return Container(
      key: const Key('mo_table_empty'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 34),
      child: Column(
        children: [
          Icon(filtered ? Icons.filter_alt_off_outlined : Icons.flag_outlined, size: 30, color: crm.textSecondary.withValues(alpha: 0.6)),
          const SizedBox(height: 8),
          Text(
            filtered ? 'No objectives match.' : 'No objectives set for ${kMonthNames[month.month - 1]}.',
            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: crm.textPrimary),
          ),
          const SizedBox(height: 2),
          Text(
            filtered ? 'Clear the search or the filters to see them all.' : (canSet ? 'Use “Set Objective” to plan the month.' : 'Its department\'s head sets them.'),
            style: TextStyle(fontSize: 12.5, color: crm.textSecondary),
          ),
          if (filtered && !filter.isEmpty)
            TextButton(key: const Key('mo_clear_filters'), onPressed: () => onFilterChanged(ObjectiveFilter(departmentId: filter.departmentId)), child: const Text('Clear search and filters')),
        ],
      ),
    );
  }

  Widget _head(CrmTheme crm) {
    Widget h(String text, int flex) => Expanded(flex: flex, child: Text(text, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: crm.textSecondary)));
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 0, 8),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: crm.border), top: BorderSide(color: crm.border))),
      child: Row(children: [h('Objective', _cObjective), h('Department', _cDept), h('Owner', _cOwner), h('Priority', _cPriority), h('Progress', _cProgress), h('Status', _cStatus), const SizedBox(width: 38)]),
    );
  }
}

const _cObjective = 52;
const _cDept = 20;
const _cOwner = 20;
const _cPriority = 15;
const _cProgress = 24;
const _cStatus = 19;

// ── one objective ────────────────────────────────────────────────────────────

class _ObjectiveRow extends ConsumerStatefulWidget {
  const _ObjectiveRow({super.key, required this.objective, required this.department, required this.deptIndex, required this.month, required this.wide, required this.onToast});
  final MonthlyObjective objective;
  final MonthlyDepartment? department;
  final int deptIndex;
  final MonthKey month;
  final bool wide;
  final void Function(String) onToast;

  @override
  ConsumerState<_ObjectiveRow> createState() => _ObjectiveRowState();
}

class _ObjectiveRowState extends ConsumerState<_ObjectiveRow> {
  bool _open = false;

  Future<void> _run(Future<void> Function() action, String done) async {
    try {
      await action();
      ref.invalidate(monthlyObjectivesProvider);
      ref.invalidate(monthlyTrendProvider);
      widget.onToast(done);
    } catch (e) {
      widget.onToast(friendlyErrorMessage(e));
    }
  }

  /// Every key result is done: close it as achieved (no note — it is what the progress says). Reopen undoes it.
  Future<void> _closeAchieved() => _run(() => ref.read(monthlyObjectiveServiceProvider).close(widget.objective.id, ObjectiveResult.achieved), 'Closed as achieved');

  Future<void> _menu(String v) async {
    final o = widget.objective;
    final service = ref.read(monthlyObjectiveServiceProvider);
    switch (v) {
      case 'edit':
        final dept = widget.department;
        if (dept != null && await showMonthlyObjectiveEditor(context, department: dept, month: widget.month, existing: o) == true) widget.onToast('Objective saved');
      case 'reopen':
        await _run(() => service.reopen(o.id), 'Objective reopened');
      case 'cancel':
        final why = await showReasonDialog(
          context,
          title: 'Cancel “${o.objective}”?',
          message: 'It stops being this month\'s plan and is left out of the month\'s progress. The reason is kept.',
          confirmLabel: 'Cancel objective',
          hint: 'Why is it being cancelled?',
        );
        if (why != null) await _run(() => service.close(o.id, ObjectiveResult.cancelled, note: why), 'Objective cancelled');
      case 'postpone':
        final next = nextMonthOf(widget.month);
        final why = await showReasonDialog(
          context,
          title: 'Postpone “${o.objective}”?',
          message: 'It moves to ${monthTitle(next)} with what is not done yet, and is left out of this month\'s progress. The reason is kept.',
          confirmLabel: 'Postpone',
          hint: 'Why is it being postponed?',
        );
        if (why == null) return;
        try {
          await service.close(o.id, ObjectiveResult.deferred, note: why);
        } catch (e) {
          widget.onToast(friendlyErrorMessage(e));
          return;
        }
        try {
          await service.carryOver(departmentId: o.departmentId, month: widget.month, ids: [o.id]);
          ref.invalidate(monthlyObjectivesProvider);
          ref.invalidate(monthlyTrendProvider);
          widget.onToast('Postponed to ${monthTitle(next)}');
        } catch (e) {
          ref.invalidate(monthlyObjectivesProvider);
          widget.onToast('Postponed, but not moved into ${monthTitle(next)}: ${friendlyErrorMessage(e)} Use “Close out month” to carry it.');
        }
      case 'delete':
        final ok = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('Delete this objective?'),
            content: Text('“${o.objective}” and its key results will be deleted.'),
            actions: [
              TextButton(key: const Key('mo_delete_cancel'), onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
              FilledButton(key: const Key('mo_delete_confirm'), onPressed: () => Navigator.pop(c, true), style: FilledButton.styleFrom(backgroundColor: Colors.red), child: const Text('Delete')),
            ],
          ),
        );
        if (ok == true) await _run(() => service.delete(o.id), 'Objective deleted');
    }
  }

  Widget _menuButton(CrmTheme crm) {
    final o = widget.objective;
    if (!o.access.canManage) {
      return SizedBox(width: 38, child: Icon(_open ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: crm.textSecondary));
    }
    return PopupMenuButton<String>(
      key: Key('mo_menu_${o.id}'),
      tooltip: 'More',
      onSelected: _menu,
      itemBuilder: (_) => [
        if (!o.isClosed) const PopupMenuItem(value: 'edit', child: Text('Edit')),
        if (!o.isClosed) const PopupMenuItem(value: 'postpone', child: Text('Postpone to next month')),
        if (!o.isClosed) const PopupMenuItem(value: 'cancel', child: Text('Cancel objective')),
        if (o.isClosed) const PopupMenuItem(value: 'reopen', child: Text('Reopen')),
        if (!o.isClosed) const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
      ],
      child: SizedBox(width: 38, height: 38, child: Icon(Icons.more_horiz_rounded, size: 20, color: crm.textSecondary)),
    );
  }

  Widget _deptChip(CrmTheme crm) {
    final o = widget.objective;
    final color = deptColor(widget.deptIndex < 0 ? 0 : widget.deptIndex);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(departmentIcon(o.departmentName), size: 13, color: color),
          const SizedBox(width: 5),
          Flexible(child: Text(o.departmentName, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: color))),
        ],
      ),
    );
  }

  Widget _title(CrmTheme crm) {
    final o = widget.objective;
    final status = statusOf(o);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(padding: const EdgeInsets.only(top: 1), child: Icon(statusIcon(status), size: 19, color: statusColor(status))),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(o.objective, key: Key('mo_title_${o.id}'), style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: crm.textPrimary)),
              const SizedBox(height: 3),
              Wrap(
                spacing: 8,
                runSpacing: 2,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (o.keyResults.isNotEmpty) Text('${o.keyResults.where((k) => k.completed).length} of ${o.keyResults.length} key results done', style: TextStyle(fontSize: 11.5, color: crm.textSecondary)),
                  if (o.carriedFrom) const Text('carried over', style: TextStyle(fontSize: 11.5, color: kObjectiveAmber, fontWeight: FontWeight.w700)),
                  if (o.span != null)
                    Text(
                      'Month ${o.span!.number} of ${o.span!.total}${o.span!.overran ? ' · over plan' : ''}',
                      key: Key('mo_span_${o.id}'),
                      style: TextStyle(fontSize: 11.5, color: o.span!.overran ? kObjectiveAmber : crm.primary, fontWeight: FontWeight.w700),
                    ),
                ],
              ),
              if (o.readyToClose)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  // wraps, so the button drops under the words on a narrow phone instead of overflowing
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 4,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.check_circle_rounded, size: 15, color: kDashGood),
                          const SizedBox(width: 5),
                          Flexible(child: Text('Every key result is done', key: Key('mo_ready_${o.id}'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kDashGood))),
                        ],
                      ),
                      if (o.access.canManage)
                        TextButton(
                          key: Key('mo_close_achieved_${o.id}'),
                          onPressed: _closeAchieved,
                          style: TextButton.styleFrom(visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(horizontal: 8)),
                          child: const Text('Close as achieved'),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _progress(CrmTheme crm) {
    final o = widget.objective;
    final status = statusOf(o);
    return Row(
      children: [
        Expanded(child: progressBar(crm, o.progress, color: status.isDropped ? statusColor(status) : (o.result == null ? null : resultColor(o.result!)))),
        const SizedBox(width: 8),
        SizedBox(
          width: 38,
          child: Text('${o.progress}%', key: Key('mo_progress_${o.id}'), textAlign: TextAlign.right, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: crm.textPrimary)),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final o = widget.objective;
    final status = statusOf(o);

    final line = widget.wide
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(flex: _cObjective, child: Padding(padding: const EdgeInsets.only(right: 12), child: _title(crm))),
              Expanded(flex: _cDept, child: Align(alignment: Alignment.centerLeft, child: Padding(padding: const EdgeInsets.only(right: 10), child: _deptChip(crm)))),
              Expanded(flex: _cOwner, child: Padding(padding: const EdgeInsets.only(right: 10), child: OwnerChip(name: o.ownerName, mine: o.assignedToMe))),
              Expanded(flex: _cPriority, child: Align(alignment: Alignment.centerLeft, child: PriorityPill(o.priority))),
              Expanded(flex: _cProgress, child: Padding(padding: const EdgeInsets.only(right: 14), child: _progress(crm))),
              Expanded(flex: _cStatus, child: Align(alignment: Alignment.centerLeft, child: ObjectiveStatusPill(status, key: Key('mo_status_${o.id}')))),
              _menuButton(crm),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: _title(crm)), _menuButton(crm)]),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _deptChip(crm),
                  PriorityPill(o.priority),
                  ObjectiveStatusPill(status, key: Key('mo_status_${o.id}')),
                  OwnerChip(name: o.ownerName, mine: o.assignedToMe),
                ],
              ),
              const SizedBox(height: 8),
              _progress(crm),
            ],
          );

    return Container(
      key: Key('mo_obj_${o.id}'),
      decoration: BoxDecoration(
        color: widget.wide ? null : crm.background,
        borderRadius: widget.wide ? null : BorderRadius.circular(12),
        border: widget.wide ? Border(bottom: BorderSide(color: crm.border.faded(2))) : Border.all(color: crm.border.faded(2.5)),
      ),
      margin: EdgeInsets.only(bottom: widget.wide ? 0 : 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            key: Key('mo_toggle_${o.id}'),
            borderRadius: BorderRadius.circular(10),
            onTap: () => setState(() => _open = !_open),
            child: Padding(padding: EdgeInsets.fromLTRB(widget.wide ? 8 : 12, 12, widget.wide ? 0 : 4, 12), child: line),
          ),
          if (_open) _details(crm, o),
        ],
      ),
    );
  }

  Widget _details(CrmTheme crm, MonthlyObjective o) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(37, 0, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (o.description.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(o.description, style: TextStyle(fontSize: 12.5, color: crm.textSecondary))),
          if (o.result != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Text('Closed as ', style: TextStyle(fontSize: 12, color: crm.textSecondary)),
                  _resultPill(o.result!),
                ],
              ),
            ),
          if (o.keyResults.isEmpty)
            Text(
              'No key results yet.${o.access.canManage && !o.isClosed ? ' Edit the objective to add what it should reach.' : ''}',
              key: Key('mo_no_kr_${o.id}'),
              style: TextStyle(fontSize: 12.5, color: crm.textSecondary),
            ),
          for (final k in o.keyResults)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Icon(k.completed ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded, size: 18, color: k.completed ? kDashGood : crm.textSecondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(k.title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: crm.textPrimary)),
                        Text(progressText(k), key: Key('mo_kr_text_${k.id}'), style: TextStyle(fontSize: 12, color: crm.textSecondary)),
                        if (k.completed && k.completedAt != null)
                          Text(
                            'Done ${k.completedAt!.day} ${kMonthNames[k.completedAt!.month - 1].substring(0, 3)}${k.completedByName.isEmpty ? '' : ' · ${k.completedByName}'}',
                            key: Key('mo_kr_done_${k.id}'),
                            style: const TextStyle(fontSize: 11.5, color: kDashGood, fontWeight: FontWeight.w600),
                          ),
                      ],
                    ),
                  ),
                  if (o.access.canCheckIn && !o.isClosed)
                    TextButton(
                      key: Key('mo_kr_checkin_${o.id}_${k.id}'),
                      onPressed: () async {
                        if (await showKeyResultProgress(context, objective: o, kr: k) == true) widget.onToast('Progress saved');
                      },
                      style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                      child: const Text('Update'),
                    ),
                ],
              ),
            ),
          if (o.result != null && o.overridden && o.progressAtClose != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('Progress was ${o.progressAtClose}% — it ended ${o.result!.label.toLowerCase()}.', key: Key('mo_overridden_${o.id}'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kObjectiveAmber)),
            ),
          if (o.result != null && o.resultNote.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('“${o.resultNote}”', key: Key('mo_note_${o.id}'), style: TextStyle(fontSize: 12.5, fontStyle: FontStyle.italic, color: crm.textSecondary)),
            ),
          if (o.changes.isNotEmpty) _changes(crm, o),
        ],
      ),
    );
  }

  /// The plan changing after its month had started: each time, what changed and the reason it was given.
  Widget _changes(CrmTheme crm, MonthlyObjective o) => Padding(
    key: Key('mo_changes_${o.id}'),
    padding: const EdgeInsets.only(top: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Plan changed ${o.changes.length} time${o.changes.length == 1 ? '' : 's'}', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: crm.textSecondary)),
        for (final c in o.changes)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '“${c.reason}”${c.byName.isEmpty ? '' : ' — ${c.byName}'}${c.at == null ? '' : ', ${c.at!.day} ${kMonthNames[c.at!.month - 1].substring(0, 3)}'}',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: crm.textPrimary),
                ),
                for (final line in c.summary) Text('• $line', style: TextStyle(fontSize: 11.5, color: crm.textSecondary)),
              ],
            ),
          ),
      ],
    ),
  );

  Widget _resultPill(ObjectiveResult r) {
    final c = resultColor(r);
    return Container(
      key: Key('mo_result_${widget.objective.id}'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(20)),
      child: Text(r.label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: c)),
    );
  }
}

// ── the filters ──────────────────────────────────────────────────────────────

/// Choose which statuses and priorities to see, and whether only what is given to you. Returns the new filter (the search and the
/// department it came with are kept), or null when cancelled.
Future<ObjectiveFilter?> showObjectiveFilters(BuildContext context, ObjectiveFilter current) {
  var statuses = {...current.statuses};
  var priorities = {...current.priorities};
  var mine = current.onlyMine;
  return showDialog<ObjectiveFilter>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setD) {
        final crm = ctx.crmColors;
        Widget chip({required Key key, required String label, required bool on, required Color color, required VoidCallback tap}) => FilterChip(
          key: key,
          label: Text(label),
          selected: on,
          showCheckmark: false,
          onSelected: (_) => setD(tap),
          selectedColor: color.withValues(alpha: 0.16),
          labelStyle: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: on ? color : crm.textSecondary),
          side: BorderSide(color: on ? color : crm.border),
        );
        return AlertDialog(
          key: const Key('mo_filters_dialog'),
          title: const Text('Filters'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Status', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: crm.textSecondary)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      for (final s in ObjectiveStatus.values)
                        chip(
                          key: Key('mo_f_status_${s.name}'),
                          label: s.label,
                          on: statuses.contains(s),
                          color: statusColor(s),
                          tap: () => statuses.contains(s) ? statuses.remove(s) : statuses.add(s),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text('Priority', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: crm.textSecondary)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      for (final p in const ['critical', 'high', 'medium', 'low'])
                        chip(key: Key('mo_f_prio_$p'), label: priorityLabel(p), on: priorities.contains(p), color: priorityColor(p), tap: () => priorities.contains(p) ? priorities.remove(p) : priorities.add(p)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    key: const Key('mo_f_mine'),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text('Only what is given to me', style: TextStyle(fontSize: 13.5)),
                    value: mine,
                    onChanged: (v) => setD(() => mine = v),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              key: const Key('mo_f_reset'),
              onPressed: () => setD(() {
                statuses = {};
                priorities = {};
                mine = false;
              }),
              child: const Text('Reset'),
            ),
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(key: const Key('mo_f_apply'), onPressed: () => Navigator.pop(ctx, current.copyWith(statuses: statuses, priorities: priorities, onlyMine: mine)), child: const Text('Apply')),
          ],
        );
      },
    ),
  );
}

// ── the key results of the month ─────────────────────────────────────────────

/// Every key result of the month's objectives, unfinished ones first — with the objective and department each belongs to.
class KeyResultsPanel extends StatefulWidget {
  const KeyResultsPanel({super.key, required this.objectives, required this.departments, required this.onToast});
  final List<MonthlyObjective> objectives;
  final List<MonthlyDepartment> departments;
  final void Function(String) onToast;

  @override
  State<KeyResultsPanel> createState() => _KeyResultsPanelState();
}

class _KeyResultsPanelState extends State<KeyResultsPanel> {
  KeyResultFilter _filter = KeyResultFilter.all;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final all = keyResultRows(widget.objectives);
    final rows = keyResultRows(widget.objectives, filter: _filter);
    final done = all.where((r) => r.done).length;
    return DashCard(
      key: const Key('mo_kr_panel'),
      title: 'Key Results',
      subtitle: all.isEmpty ? 'What each objective has to reach' : '$done of ${all.length} done',
      icon: Icons.flag_outlined,
      trailing: DashSegmented<KeyResultFilter>(
        keyPrefix: 'mo_kr_filter',
        dense: true,
        value: _filter,
        options: const [(KeyResultFilter.all, 'All'), (KeyResultFilter.open, 'Open'), (KeyResultFilter.done, 'Done')],
        onChanged: (f) => setState(() => _filter = f),
      ),
      child: rows.isEmpty
          ? DashEmpty(all.isEmpty ? 'No key results yet — they are added when an objective is set.' : 'No key results here.', icon: Icons.flag_outlined, height: 140)
          : Column(
              children: [
                for (var i = 0; i < rows.length; i++) ...[
                  if (i > 0) Divider(height: 1, color: crm.border.faded(2)),
                  _row(context, crm, rows[i]),
                ],
              ],
            ),
    );
  }

  Widget _row(BuildContext context, CrmTheme crm, KeyResultRow r) {
    final k = r.keyResult;
    final o = r.objective;
    final index = widget.departments.indexWhere((d) => d.departmentId == o.departmentId);
    final color = deptColor(index < 0 ? 0 : index);
    return Padding(
      key: Key('mo_kr_row_${k.id}'),
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(padding: const EdgeInsets.only(top: 1), child: Icon(r.done ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded, size: 19, color: r.done ? kDashGood : crm.textSecondary)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(k.title, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: crm.textPrimary)),
                const SizedBox(height: 2),
                Wrap(
                  spacing: 8,
                  runSpacing: 2,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(o.departmentName, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: color)),
                    Text(o.objective, style: TextStyle(fontSize: 11.5, color: crm.textSecondary)),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(child: progressBar(crm, k.attainment.round(), height: 6)),
                    const SizedBox(width: 10),
                    Text(progressText(k), key: Key('mo_kr_row_text_${k.id}'), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: crm.textPrimary)),
                  ],
                ),
                if (k.completed && k.completedAt != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'Done ${k.completedAt!.day} ${kMonthNames[k.completedAt!.month - 1].substring(0, 3)}${k.completedByName.isEmpty ? '' : ' · ${k.completedByName}'}',
                      style: const TextStyle(fontSize: 11.5, color: kDashGood, fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
          ),
          if (o.access.canCheckIn && !o.isClosed)
            TextButton(
              key: Key('mo_kr_checkin_${o.id}_${k.id}'),
              onPressed: () async {
                if (await showKeyResultProgress(context, objective: o, kr: k) == true) widget.onToast('Progress saved');
              },
              style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
              child: const Text('Update'),
            ),
        ],
      ),
    );
  }
}
