import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/it/data/it_task.dart';
import 'package:nizan_crm/features/it/data/project.dart';
import 'package:nizan_crm/features/it/services/it_service.dart';
import 'package:nizan_crm/features/it/presentation/controllers/it_tasks_notifier.dart';
import 'package:nizan_crm/features/it/presentation/screens/it_projects_screen.dart' show priorityColor, projectStatusColor;
import 'package:nizan_crm/features/it/presentation/screens/widgets/it_common.dart';
import 'package:nizan_crm/features/it/presentation/screens/widgets/it_task_editor.dart';
import 'package:nizan_crm/features/it/presentation/screens/widgets/it_task_detail_sheet.dart';

/// Hierarchical WBS table: WBS# · Title · Owner · Start · Due · Duration · %.
class ITWbsView extends ConsumerStatefulWidget {
  const ITWbsView({super.key, required this.projectId, required this.tasks});
  final String projectId;
  final List<ITTask> tasks;

  @override
  ConsumerState<ITWbsView> createState() => _ITWbsViewState();
}

class _ITWbsViewState extends ConsumerState<ITWbsView> {
  final Set<String> _collapsed = {};

  // Fixed column widths (title flexes). Kept in sync between header and rows.
  static const double _wWbs = 46;
  static const double _wOwner = 124;
  static const double _wDate = 74;
  static const double _wDur = 48;
  static const double _wPct = 60;
  static const double _wActions = 40;
  static const double _titleMin = 220;
  double get _minWidth => _wWbs + _wOwner + _wDate * 2 + _wDur + _wPct + _wActions + _titleMin;

  void _refreshIf(bool? saved) {
    if (saved == true) {
      getITTasksNotifier(ref, widget.projectId).refresh();
      ref.invalidate(projectsProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final project = ref.watch(projectsProvider).value?.where((p) => p.id == widget.projectId).firstOrNull;
    final forest = buildWbsForest(widget.tasks);

    // Overall project % = average of all leaf tasks.
    final leaves = widget.tasks.where((t) {
      final hasChild = widget.tasks.any((o) => o.parentTaskId == t.id);
      return !hasChild;
    }).toList();
    final overall = leaves.isEmpty
        ? 0
        : (leaves.map((t) => t.percentComplete.clamp(0, 100)).reduce((a, b) => a + b) / leaves.length).round();
    final phaseCount = forest.length;

    // Rows visible given collapse state.
    final rows = <WbsNode>[];
    void addVisible(WbsNode n) {
      rows.add(n);
      if (!_collapsed.contains(n.task.id)) {
        for (final c in n.children) {
          addVisible(c);
        }
      }
    }

    for (final r in forest) {
      addVisible(r);
    }

    return Column(children: [
      _header(crm, project, overall, widget.tasks.length, phaseCount),
      _toolbar(crm),
      Expanded(
        child: widget.tasks.isEmpty
            ? _empty(crm)
            : LayoutBuilder(
                builder: (ctx, c) {
                  final w = math.max(c.maxWidth, _minWidth);
                  return Scrollbar(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: w,
                        child: Column(children: [
                          _headerRow(crm),
                          Expanded(
                            child: ListView.builder(
                              physics: const AlwaysScrollableScrollPhysics(),
                              itemCount: rows.length,
                              itemBuilder: (_, i) => _dataRow(crm, rows[i]),
                            ),
                          ),
                        ]),
                      ),
                    ),
                  );
                },
              ),
      ),
    ]);
  }

  Widget _header(CrmTheme crm, Project? p, int overall, int taskCount, int phases) => Container(
        margin: const EdgeInsets.fromLTRB(12, 12, 12, 6),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: crm.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: crm.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Title + status/priority
          Row(children: [
            Expanded(
              child: Text(p?.name ?? 'Project', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
            ),
            if (p != null) ...[
              _statusPill(_titleCase(p.status), projectStatusColor(p.status)),
              const SizedBox(width: 6),
              _statusPill(_titleCase(p.priority), priorityColor(p.priority)),
            ],
          ]),
          const SizedBox(height: 10),
          // Manager · dates · phase — the template's project meta block.
          Wrap(spacing: 18, runSpacing: 6, children: [
            _meta(crm, Icons.person_outline, 'Manager', (p?.managerName.isEmpty ?? true) ? '—' : p!.managerName),
            _meta(crm, Icons.play_arrow_outlined, 'Start', shortDate(p?.startDate)),
            _meta(crm, Icons.event_outlined, 'Due', shortDate(p?.endDate)),
            _meta(crm, Icons.flag_outlined, 'Phase', _titleCase(p?.phase ?? '')),
          ]),
          const Divider(height: 22),
          // Overall progress
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Overall progress', style: TextStyle(fontSize: 12, color: crm.textSecondary, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: overall / 100,
                    minHeight: 10,
                    backgroundColor: crm.background,
                    valueColor: AlwaysStoppedAnimation(percentFill(overall) == const Color(0xFFF1F1F1) ? crm.border : percentFill(overall)),
                  ),
                ),
                const SizedBox(height: 6),
                Text('$phases phase${phases == 1 ? '' : 's'} · $taskCount item${taskCount == 1 ? '' : 's'}',
                    style: TextStyle(fontSize: 11.5, color: crm.textSecondary)),
              ]),
            ),
            const SizedBox(width: 16),
            Text('$overall%', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: crm.primary)),
          ]),
        ]),
      );

  Widget _meta(CrmTheme crm, IconData icon, String label, String value) => Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: crm.textSecondary),
        const SizedBox(width: 5),
        Text('$label: ', style: TextStyle(fontSize: 11.5, color: crm.textSecondary)),
        Text(value, style: TextStyle(fontSize: 11.5, color: crm.textPrimary, fontWeight: FontWeight.w700)),
      ]);

  Widget _statusPill(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
        child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
      );

  static String _titleCase(String s) => s.isEmpty ? '—' : s[0].toUpperCase() + s.substring(1).replaceAll('-', ' ');

  Widget _toolbar(CrmTheme crm) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
        child: Row(children: [
          Text('Work breakdown', style: TextStyle(fontWeight: FontWeight.w800, color: crm.textPrimary)),
          const Spacer(),
          TextButton.icon(
            onPressed: () => showTaskEditor(context, ref, widget.projectId, allTasks: widget.tasks).then(_refreshIf),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add phase'),
          ),
        ]),
      );

  Widget _empty(CrmTheme crm) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.account_tree_outlined, size: 48, color: crm.textSecondary),
          const SizedBox(height: 10),
          Text('No tasks yet', style: TextStyle(color: crm.textSecondary, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('Add a phase, then break it into sub-tasks.', style: TextStyle(color: crm.textSecondary, fontSize: 12)),
          const SizedBox(height: 14),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: crm.primary),
            onPressed: () => showTaskEditor(context, ref, widget.projectId, allTasks: widget.tasks).then(_refreshIf),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add phase'),
          ),
        ]),
      );

  Widget _headerRow(CrmTheme crm) {
    TextStyle h() => TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: crm.textSecondary, letterSpacing: 0.3);
    return Container(
      decoration: BoxDecoration(color: crm.background, border: Border(bottom: BorderSide(color: crm.border))),
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(children: [
        _cell(_wWbs, Text('WBS', style: h())),
        Expanded(child: Padding(padding: const EdgeInsets.only(left: 4), child: Text('TASK', style: h()))),
        _cell(_wOwner, Text('OWNER', style: h())),
        _cell(_wDate, Text('START', style: h())),
        _cell(_wDate, Text('DUE', style: h())),
        _cell(_wDur, Text('DUR', style: h(), textAlign: TextAlign.center)),
        _cell(_wPct, Text('%', style: h(), textAlign: TextAlign.center)),
        const SizedBox(width: _wActions),
      ]),
    );
  }

  Widget _dataRow(CrmTheme crm, WbsNode node) {
    final t = node.task;
    final isGroup = node.isGroup;
    final collapsed = _collapsed.contains(t.id);
    final pct = rolledUpPercent(node);
    final dur = durationDays(t);
    // phase 1 → blue, 2 → teal, 3 → orange … (matches the template palette).
    final accent = phaseColor((int.tryParse(node.wbs.split('.').first) ?? 1) - 1);
    final isTopPhase = node.depth == 0 && isGroup;

    return InkWell(
      onTap: isGroup
          ? () => setState(() => collapsed ? _collapsed.remove(t.id) : _collapsed.add(t.id))
          : () => showITTaskDetailSheet(context, ref, task: t, allTasks: widget.tasks).then(_refreshIf),
      child: Container(
        decoration: BoxDecoration(
          color: isTopPhase ? accent.withValues(alpha: 0.08) : (isGroup ? crm.background : crm.surface),
          border: Border(
            left: isTopPhase ? BorderSide(color: accent, width: 3) : BorderSide.none,
            bottom: BorderSide(color: crm.border.withValues(alpha: 0.6)),
          ),
        ),
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          _cell(
            _wWbs,
            isTopPhase
                ? Container(
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(6)),
                    child: Text(node.wbs, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white)),
                  )
                : Text(node.wbs, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: isGroup ? accent : crm.textSecondary)),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(left: 4 + node.depth * 16),
              child: Row(children: [
                if (isGroup)
                  Icon(collapsed ? Icons.chevron_right : Icons.expand_more, size: 18, color: crm.textSecondary)
                else
                  Container(width: 7, height: 7, margin: const EdgeInsets.only(left: 5, right: 8), decoration: BoxDecoration(shape: BoxShape.circle, color: t.status.color)),
                Expanded(
                  child: Text(t.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, fontWeight: isGroup ? FontWeight.w800 : FontWeight.w500, color: crm.textPrimary)),
                ),
                if (!isGroup && t.priority != 'medium') Padding(padding: const EdgeInsets.only(left: 6), child: itTag(cap(t.priority), priorityColor(t.priority))),
              ]),
            ),
          ),
          _cell(_wOwner, Text(t.assignedToName.isEmpty ? '—' : t.assignedToName, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, color: crm.textSecondary))),
          _cell(_wDate, Text(shortDate(t.startDate), style: TextStyle(fontSize: 11.5, color: crm.textSecondary))),
          _cell(_wDate, Text(shortDate(t.deadline), style: TextStyle(fontSize: 11.5, color: crm.textSecondary))),
          _cell(_wDur, Text(dur?.toString() ?? '—', textAlign: TextAlign.center, style: TextStyle(fontSize: 11.5, color: crm.textSecondary))),
          _cell(_wPct, _pctChip(pct)),
          SizedBox(width: _wActions, child: _rowMenu(node)),
        ]),
      ),
    );
  }

  Widget _pctChip(int pct) => Center(
        child: Container(
          width: 46,
          padding: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(color: percentFill(pct), borderRadius: BorderRadius.circular(7)),
          child: Text('$pct%', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: percentText(pct))),
        ),
      );

  Widget _rowMenu(WbsNode node) => PopupMenuButton<String>(
        padding: EdgeInsets.zero,
        iconSize: 18,
        onSelected: (v) async {
          switch (v) {
            case 'child':
              _refreshIf(await showTaskEditor(context, ref, widget.projectId, defaultParentId: node.task.id, allTasks: widget.tasks));
            case 'sibling':
              _refreshIf(await showTaskEditor(context, ref, widget.projectId, defaultParentId: node.task.parentTaskId, allTasks: widget.tasks));
            case 'edit':
              _refreshIf(await showTaskEditor(context, ref, widget.projectId, existing: node.task, allTasks: widget.tasks));
            case 'delete':
              await _delete(node);
          }
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'child', child: Text('Add sub-task')),
          PopupMenuItem(value: 'sibling', child: Text('Add sibling')),
          PopupMenuDivider(),
          PopupMenuItem(value: 'edit', child: Text('Edit')),
          PopupMenuItem(value: 'delete', child: Text('Delete')),
        ],
      );

  Future<void> _delete(WbsNode node) async {
    final messenger = ScaffoldMessenger.of(context);
    if (node.isGroup) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Delete phase?'),
          content: Text('“${node.task.title}” and all ${flattenWbs(node.children).length} item(s) under it will be deleted.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(c, true), style: FilledButton.styleFrom(backgroundColor: Colors.red), child: const Text('Delete')),
          ],
        ),
      );
      if (ok != true) return;
    }
    try {
      final notifier = getITTasksNotifier(ref, widget.projectId);
      await notifier.deleteTask(node.task.id);
      ref.invalidate(projectsProvider);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
    }
  }

  Widget _cell(double w, Widget child) => SizedBox(width: w, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: child));
}
