import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/providers/auth_provider.dart';
import 'package:nizan_crm/core/utils/export_utils.dart';
import 'package:nizan_crm/features/it/data/it_task.dart';
import 'package:nizan_crm/features/it/domain/task_rights.dart';
import 'package:nizan_crm/features/it/domain/task_tree.dart';
import 'package:nizan_crm/features/it/data/project.dart';
import 'package:nizan_crm/features/it/services/it_service.dart';
import 'package:nizan_crm/features/it/presentation/controllers/it_tasks_notifier.dart';
import 'package:nizan_crm/features/it/presentation/screens/it_projects_screen.dart' show priorityColor, projectStatusColor;
import 'package:nizan_crm/features/it/presentation/screens/widgets/it_common.dart';
import 'package:nizan_crm/features/it/presentation/screens/widgets/it_task_editor.dart';
import 'package:nizan_crm/features/it/presentation/screens/widgets/it_task_detail_sheet.dart';
import 'package:nizan_crm/features/it/presentation/screens/widgets/wbs_rows.dart';

/// Saves an export. [kind] is 'csv' or 'pdf'; [fileName] has no extension.
typedef WbsExporter = Future<void> Function(String kind, String fileName, String title, List<String> headers, List<List<dynamic>> rows);

Future<void> _saveExport(String kind, String fileName, String title, List<String> headers, List<List<dynamic>> rows) =>
    kind == 'pdf' ? ExportUtils.exportPdf('$fileName.pdf', title, headers, rows) : ExportUtils.exportCsv('$fileName.csv', [headers, ...rows]);

/// The project's work breakdown: how far it has got, then every phase and the tasks under it as a tree (or one flat
/// table), searchable, filterable and exportable.
class ITWbsView extends ConsumerStatefulWidget {
  const ITWbsView({super.key, required this.projectId, required this.tasks, this.exporter = _saveExport});
  final String projectId;
  final List<ITTask> tasks;
  final WbsExporter exporter;

  @override
  ConsumerState<ITWbsView> createState() => _ITWbsViewState();
}

class _ITWbsViewState extends ConsumerState<ITWbsView> {
  Project? _project;
  String _me = '';

  /// May this person add tickets here? (a manager-planned project: the manager, or a lead)
  bool get _canAdd => _project?.access.canCreateTasks ?? true;
  TaskRights _rights(ITTask t) => taskRightsFor(_project, t, myEmployeeId: _me);
  bool get _isIt => (_project?.targetDepartment ?? 'it').toLowerCase().trim() == 'it';

  final Set<String> _collapsed = {};
  final _search = TextEditingController();
  final _hScroll = ScrollController();
  bool _tree = true;
  String _query = '';
  WbsFilter _filter = const WbsFilter();

  // Fixed column widths (the title flexes). Kept in sync between the header and the rows.
  static const double _wNo = 76;
  static const double _wOwner = 160;
  static const double _wDate = 92;
  static const double _wDur = 92;
  static const double _wProgress = 160;
  static const double _wStatus = 132;
  static const double _wActions = 44;
  static const double _titleMin = 280;
  static const double _phaseHeight = 52;
  static const double _rowHeight = 48;
  double get _minWidth => _wNo + _wOwner + _wDate * 2 + _wDur + _wProgress + _wStatus + _wActions + _titleMin;

  @override
  void dispose() {
    _search.dispose();
    _hScroll.dispose();
    super.dispose();
  }

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
    _project = project;
    _me = ref.watch(authSessionProvider)?.employeeId ?? '';
    final forest = buildWbsForest(widget.tasks);
    final summary = wbsSummary(widget.tasks, forest);
    final rows = wbsRows(forest, tree: _tree, collapsed: _collapsed, query: _query, filter: _filter);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _summaryStrip(crm, project, summary),
        const SizedBox(height: 22),
        _toolbar(crm),
        const SizedBox(height: 14),
        if (widget.tasks.isEmpty) _empty(crm) else _table(crm, rows),
      ]),
    );
  }

  // ── the strip: how far it has got ─────────────────────────────────────────

  Widget _summaryStrip(CrmTheme crm, Project? p, WbsSummary s) {
    final ring = SizedBox(
      key: const Key('wbs_ring'),
      width: 74,
      height: 74,
      child: CustomPaint(
        painter: _RingPainter(pct: s.overall, track: crm.border.faded(2.2), color: crm.primary),
        child: Center(child: Text('${s.overall}%', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: crm.textPrimary))),
      ),
    );

    final progress = Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Text('Overall Progress', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: crm.textPrimary)),
      const SizedBox(height: 3),
      Text('${s.completed} of ${s.total} items completed', key: const Key('wbs_progress_text'), style: TextStyle(fontSize: 13.5, color: crm.textSecondary)),
      const SizedBox(height: 10),
      ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: LinearProgressIndicator(value: s.overall / 100, minHeight: 8, backgroundColor: crm.border.faded(1.6), valueColor: AlwaysStoppedAnimation(crm.primary)),
      ),
    ]);

    Widget stat(String key, IconData icon, Color color, int value, String label) => Row(mainAxisSize: MainAxisSize.min, key: Key('wbs_stat_$key'), children: [
          Icon(icon, size: 24, color: color),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text('$value', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: crm.textPrimary, height: 1.1)),
            Text(label, style: TextStyle(fontSize: 12.5, color: crm.textSecondary)),
          ]),
        ]);
    final stats = [
      stat('phases', Icons.layers_outlined, crm.primary, s.phases, 'Phases'),
      stat('tasks', Icons.layers, crm.accent, s.tasks, 'Tasks'),
      stat('total', Icons.timer_outlined, const Color(0xFFF59E0B), s.total, 'Total Items'),
      stat('completed', Icons.flag_outlined, crm.success, s.completed, 'Completed'),
      stat('remaining', Icons.hourglass_empty_rounded, crm.textSecondary, s.remaining, 'Remaining'),
    ];

    Widget pill(Key key, String text, Color color) => Container(
          key: key,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(20)),
          child: Text(text, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
        );
    final pills = p == null
        ? const <Widget>[]
        : [
            pill(const Key('wbs_status_pill'), cap(p.status), p.status == 'planning' ? const Color(0xFF2563EB) : projectStatusColor(p.status)),
            pill(const Key('wbs_priority_pill'), cap(p.priority), p.priority == 'medium' ? const Color(0xFFD99700) : priorityColor(p.priority)),
          ];

    Widget divider() => Container(width: 1, height: 44, margin: const EdgeInsets.symmetric(horizontal: 12), color: crm.border);

    return Container(
      key: const Key('wbs_summary'),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(color: crm.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: crm.border)),
      child: LayoutBuilder(builder: (context, box) {
        if (box.maxWidth >= 1000) {
          return Row(children: [
            ring,
            const SizedBox(width: 16),
            Expanded(flex: 5, child: progress),
            for (final s in stats) ...[
              divider(),
              Expanded(flex: 2, child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: s)),
            ],
            if (pills.isNotEmpty) ...[
              divider(),
              Flexible(flex: 3, child: Wrap(spacing: 8, runSpacing: 8, children: pills)),
            ],
          ]);
        }
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [ring, const SizedBox(width: 16), Expanded(child: progress)]),
          const SizedBox(height: 16),
          Wrap(spacing: 28, runSpacing: 14, children: stats),
          if (pills.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(spacing: 8, runSpacing: 8, children: pills),
          ],
        ]);
      }),
    );
  }

  // ── title, view switch, search, filter, export, add ───────────────────────

  Widget _toolbar(CrmTheme crm) {
    final title = Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Text('Work Breakdown Structure (WBS)', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: crm.textPrimary)),
      const SizedBox(height: 3),
      Text('Hierarchical breakdown of project phases, tasks and deliverables.', style: TextStyle(fontSize: 13.5, color: crm.textSecondary)),
    ]);

    final border = BorderSide(color: crm.border.faded(2.5));
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(10));

    final viewSwitch = Row(mainAxisSize: MainAxisSize.min, children: [
      Text('View:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: crm.textPrimary)),
      const SizedBox(width: 10),
      Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(color: crm.surface, borderRadius: BorderRadius.circular(10), border: Border.fromBorderSide(border)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          _viewOption(crm, const Key('wbs_view_tree'), Icons.account_tree_outlined, 'Tree', _tree, () => setState(() => _tree = true)),
          _viewOption(crm, const Key('wbs_view_table'), Icons.grid_view_rounded, 'Table', !_tree, () => setState(() => _tree = false)),
        ]),
      ),
    ]);

    final search = SizedBox(
      width: 260,
      height: 44,
      child: TextField(
        key: const Key('wbs_search'),
        controller: _search,
        onChanged: (v) => setState(() => _query = v),
        decoration: InputDecoration(
          hintText: 'Search tasks...',
          hintStyle: TextStyle(color: crm.textSecondary.withValues(alpha: 0.8)),
          isDense: true,
          filled: true,
          fillColor: crm.surface,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          suffixIcon: _query.isEmpty
              ? Icon(Icons.search, size: 20, color: crm.textPrimary)
              : IconButton(
                  key: const Key('wbs_search_clear'),
                  tooltip: 'Clear search',
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => setState(() {
                    _search.clear();
                    _query = '';
                  }),
                ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: border),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: border),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: crm.primary)),
        ),
      ),
    );

    final filterButton = OutlinedButton.icon(
      key: const Key('wbs_filter'),
      onPressed: _openFilter,
      icon: Icon(Icons.filter_alt_outlined, size: 19, color: _filter.isActive ? crm.primary : crm.textPrimary),
      label: Text(_filter.isActive ? 'Filter (${_filter.count})' : 'Filter', style: const TextStyle(fontWeight: FontWeight.w600)),
      style: OutlinedButton.styleFrom(
        foregroundColor: _filter.isActive ? crm.primary : crm.textPrimary,
        side: _filter.isActive ? BorderSide(color: crm.primary) : border,
        shape: shape,
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 16),
      ),
    );

    final exportButton = PopupMenuButton<String>(
      key: const Key('wbs_export'),
      tooltip: 'Export what is listed',
      position: PopupMenuPosition.under,
      onSelected: _export,
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'csv', child: Text('Export as CSV')),
        PopupMenuItem(value: 'pdf', child: Text('Export as PDF')),
      ],
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.fromBorderSide(border)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.file_download_outlined, size: 19, color: crm.textPrimary),
          const SizedBox(width: 8),
          Text('Export', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: crm.textPrimary)),
        ]),
      ),
    );

    final addPhase = _canAdd
        ? FilledButton.icon(
            key: const Key('wbs_add_phase'),
            onPressed: () => showTaskEditor(context, ref, widget.projectId, allTasks: widget.tasks).then(_refreshIf),
            icon: const Icon(Icons.add, size: 19),
            label: const Text('Add Phase', style: TextStyle(fontWeight: FontWeight.w700)),
            style: FilledButton.styleFrom(backgroundColor: crm.primary, shape: shape, minimumSize: const Size(0, 44), padding: const EdgeInsets.symmetric(horizontal: 20)),
          )
        : null;

    final controls = Wrap(spacing: 12, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
      viewSwitch,
      search,
      filterButton,
      exportButton,
      ?addPhase,
    ]);

    return LayoutBuilder(builder: (context, box) {
      if (box.maxWidth >= 1240) {
        return Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(flex: 4, child: title),
          const SizedBox(width: 16),
          Flexible(flex: 7, child: Align(alignment: Alignment.centerRight, child: controls)),
        ]);
      }
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [title, const SizedBox(height: 14), controls]);
    });
  }

  Widget _viewOption(CrmTheme crm, Key key, IconData icon, String label, bool on, VoidCallback onTap) {
    return InkWell(
      key: key,
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(color: on ? crm.primary : Colors.transparent, borderRadius: BorderRadius.circular(8)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 17, color: on ? Colors.white : crm.textPrimary),
          const SizedBox(width: 7),
          Text(label, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: on ? Colors.white : crm.textPrimary)),
        ]),
      ),
    );
  }

  Future<void> _openFilter() async {
    final crm = context.crmColors;
    final statuses = [for (final s in ITTaskStatus.values) if (widget.tasks.any((t) => t.status == s)) s];
    final owners = <String, String>{};
    for (final t in widget.tasks) {
      if (t.assigneeId.isNotEmpty) owners[t.assigneeId] = t.assigneeName.isEmpty ? 'Team member' : t.assigneeName;
    }
    var picked = _filter.statuses;
    var owner = _filter.owner;

    final applied = await showDialog<WbsFilter>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Filter'),
          content: SizedBox(
            width: 420,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Status', style: TextStyle(fontWeight: FontWeight.w700, color: crm.textPrimary)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final s in statuses)
                  FilterChip(
                    key: Key('wbs_filter_status_${s.slug}'),
                    label: Text(s.labelFor(isIt: _isIt)),
                    selected: picked.contains(s),
                    onSelected: (on) => setLocal(() => picked = on ? {...picked, s} : ({...picked}..remove(s))),
                  ),
              ]),
              const SizedBox(height: 18),
              Text('Owner', style: TextStyle(fontWeight: FontWeight.w700, color: crm.textPrimary)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                key: const Key('wbs_filter_owner'),
                initialValue: owner,
                isExpanded: true,
                decoration: const InputDecoration(isDense: true),
                items: [
                  const DropdownMenuItem(value: '', child: Text('Anyone')),
                  const DropdownMenuItem(value: kWbsUnassigned, child: Text('Unassigned')),
                  for (final e in owners.entries) DropdownMenuItem(value: e.key, child: Text(e.value, overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (v) => setLocal(() => owner = v ?? ''),
              ),
            ]),
          ),
          actions: [
            TextButton(key: const Key('wbs_filter_reset'), onPressed: () => Navigator.pop(ctx, const WbsFilter()), child: const Text('Reset')),
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              key: const Key('wbs_filter_apply'),
              style: FilledButton.styleFrom(backgroundColor: crm.primary),
              onPressed: () => Navigator.pop(ctx, WbsFilter(statuses: picked, owner: owner)),
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
    if (applied != null && mounted) setState(() => _filter = applied);
  }

  Future<void> _export(String kind) async {
    final messenger = ScaffoldMessenger.of(context);
    final forest = buildWbsForest(widget.tasks);
    final rows = wbsExportRows(forest, query: _query, filter: _filter, isIt: _isIt);
    if (rows.isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text('Nothing to export: no item matches the search and filter.')));
      return;
    }
    final name = _project?.name ?? 'project';
    final slug = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_').replaceAll(RegExp(r'^_|_$'), '');
    try {
      await widget.exporter(kind, 'wbs_${slug}_${DateFormat('yyyyMMdd').format(DateTime.now())}', 'Work Breakdown Structure — $name', wbsExportHeaders, rows);
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    }
  }

  // ── the table ─────────────────────────────────────────────────────────────

  Widget _empty(CrmTheme crm) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.account_tree_outlined, size: 48, color: crm.textSecondary),
            const SizedBox(height: 10),
            Text('No tasks yet', style: TextStyle(color: crm.textSecondary, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(_canAdd ? 'Add a phase, then break it into sub-tasks.' : 'The project manager adds the work to this project.', style: TextStyle(color: crm.textSecondary, fontSize: 12)),
            const SizedBox(height: 14),
            if (_canAdd)
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: crm.primary),
                onPressed: () => showTaskEditor(context, ref, widget.projectId, allTasks: widget.tasks).then(_refreshIf),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add phase'),
              ),
          ]),
        ),
      );

  Widget _table(CrmTheme crm, List<WbsRow> rows) {
    return Container(
      key: const Key('wbs_table'),
      decoration: BoxDecoration(color: crm.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: crm.border)),
      clipBehavior: Clip.antiAlias,
      child: rows.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.search_off_rounded, size: 40, color: crm.textSecondary),
                  const SizedBox(height: 8),
                  Text('No item matches', style: TextStyle(fontWeight: FontWeight.w700, color: crm.textSecondary)),
                  const SizedBox(height: 10),
                  TextButton(
                    key: const Key('wbs_clear_filters'),
                    onPressed: () => setState(() {
                      _search.clear();
                      _query = '';
                      _filter = const WbsFilter();
                    }),
                    child: const Text('Clear search and filter'),
                  ),
                ]),
              ),
            )
          : LayoutBuilder(builder: (context, box) {
              final w = math.max(box.maxWidth, _minWidth);
              return Scrollbar(
                controller: _hScroll,
                child: SingleChildScrollView(
                  controller: _hScroll,
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: w,
                    child: Column(children: [
                      _headerRow(crm),
                      for (final r in rows) _dataRow(crm, r),
                    ]),
                  ),
                ),
              );
            }),
    );
  }

  Widget _headerRow(CrmTheme crm) {
    TextStyle h() => TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: crm.textPrimary);
    return Container(
      height: 46,
      color: crm.background,
      child: Row(children: [
        _cell(_wNo, Text('#', style: h())),
        Expanded(child: Padding(padding: const EdgeInsets.only(left: 4), child: Text('Task / Phase', style: h()))),
        _cell(_wOwner, Text('Owner', style: h())),
        _cell(_wDate, Text('Start Date', style: h())),
        _cell(_wDate, Text('Due Date', style: h())),
        _cell(_wDur, Text('Duration', style: h())),
        _cell(_wProgress, Text('Progress', style: h())),
        _cell(_wStatus, Text('Status', style: h())),
        const SizedBox(width: _wActions),
      ]),
    );
  }

  Widget _dataRow(CrmTheme crm, WbsRow r) {
    final node = r.node;
    final t = node.task;
    final isPhase = node.depth == 0;
    final foldable = _tree && r.hasChildren;
    final accent = phaseColor(r.phase);
    final pct = rolledUpPercent(node);
    final height = isPhase ? _phaseHeight : _rowHeight;
    final indent = _tree ? math.max(0, node.depth - 1) * 14.0 : 0.0;

    final number = isPhase
        ? Padding(
            padding: const EdgeInsets.only(left: 18),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: 30,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(7)),
                child: Text(node.wbs, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white)),
              ),
            ),
          )
        : (_tree
            ? Stack(children: [
                Positioned.fill(child: CustomPaint(painter: _ConnectorPainter(color: crm.border.faded(3), isLast: r.isLast, x: 26 + indent))),
                Positioned(left: 46 + indent, top: 0, bottom: 0, child: Center(child: Text(node.wbs, style: TextStyle(fontSize: 13.5, color: crm.textSecondary)))),
              ])
            : Padding(
                padding: const EdgeInsets.only(left: 22),
                child: Align(alignment: Alignment.centerLeft, child: Text(node.wbs, style: TextStyle(fontSize: 13.5, color: crm.textSecondary))),
              ));

    final title = Row(children: [
      SizedBox(width: indent),
      if (isPhase) ...[
        SizedBox(
          width: 24,
          child: foldable ? Icon(r.open ? Icons.expand_more : Icons.chevron_right, size: 20, color: crm.textSecondary) : null,
        ),
        Icon(r.open || !foldable ? Icons.folder_open_outlined : Icons.folder_outlined, size: 21, color: accent),
        const SizedBox(width: 9),
      ] else ...[
        if (foldable)
          SizedBox(width: 24, child: Icon(r.open ? Icons.expand_more : Icons.chevron_right, size: 20, color: crm.textSecondary))
        else
          const SizedBox(width: 4),
        Padding(padding: const EdgeInsets.only(right: 10), child: _statusDot(crm, t.status)),
      ],
      Expanded(
        child: Tooltip(
          message: t.title,
          waitDuration: const Duration(milliseconds: 600),
          child: Text(
            t.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 14.5, fontWeight: isPhase ? FontWeight.w800 : FontWeight.w500, color: crm.textPrimary),
          ),
        ),
      ),
    ]);

    return InkWell(
      key: Key('wbs_row_${t.id}'),
      onTap: foldable
          ? () => setState(() => _collapsed.contains(t.id) ? _collapsed.remove(t.id) : _collapsed.add(t.id))
          : () => showITTaskDetailSheet(context, ref, task: t, allTasks: widget.tasks).then(_refreshIf),
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: isPhase ? accent.withValues(alpha: 0.09) : crm.surface,
          border: Border(bottom: BorderSide(color: crm.border.faded(0.8))),
        ),
        child: Row(children: [
          SizedBox(width: _wNo, height: height, child: number),
          Expanded(child: Padding(padding: const EdgeInsets.only(left: 4), child: title)),
          _cell(_wOwner, _owner(crm, t)),
          _cell(_wDate, Text(shortDate(t.startDate), style: TextStyle(fontSize: 13.5, color: crm.textPrimary))),
          _cell(_wDate, Text(shortDate(t.deadline), style: TextStyle(fontSize: 13.5, color: crm.textPrimary))),
          _cell(_wDur, Text(durationText(t), style: TextStyle(fontSize: 13.5, color: crm.textPrimary))),
          _cell(_wProgress, _progress(crm, pct)),
          _cell(_wStatus, Align(alignment: Alignment.centerLeft, child: _statusPill(crm, t.status))),
          SizedBox(width: _wActions, child: _rowMenu(node)),
        ]),
      ),
    );
  }

  Widget _statusDot(CrmTheme crm, ITTaskStatus s) {
    final (icon, color) = switch (s) {
      ITTaskStatus.deployed || ITTaskStatus.closed => (Icons.check_circle, crm.success),
      ITTaskStatus.inProgress => (Icons.timelapse, s.color),
      _ => (Icons.radio_button_unchecked, crm.textSecondary),
    };
    return Icon(icon, size: 19, color: color);
  }

  Widget _statusPill(CrmTheme crm, ITTaskStatus s) {
    final (icon, color) = switch (s) {
      ITTaskStatus.deployed || ITTaskStatus.closed => (Icons.check_circle_outline, s.color),
      ITTaskStatus.inProgress => (Icons.timelapse, s.color),
      ITTaskStatus.codeReview || ITTaskStatus.qaTesting => (Icons.rate_review_outlined, s.color),
      ITTaskStatus.backlog => (Icons.inbox_outlined, s.color),
      ITTaskStatus.todo => (Icons.radio_button_unchecked, s.color),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 6),
        Flexible(child: Text(s.labelFor(isIt: _isIt), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: color))),
      ]),
    );
  }

  Widget _owner(CrmTheme crm, ITTask t) {
    if (t.assigneeName.isEmpty) return Text('—', style: TextStyle(fontSize: 14, color: crm.textSecondary));
    return Row(children: [
      _Avatar(name: t.assigneeName),
      const SizedBox(width: 9),
      Expanded(child: Text(t.assigneeName, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13.5, color: crm.textPrimary))),
    ]);
  }

  Widget _progress(CrmTheme crm, int pct) => Row(children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct / 100,
              minHeight: 7,
              backgroundColor: crm.border.faded(1.6),
              valueColor: AlwaysStoppedAnimation(pct >= 100 ? crm.success : crm.primary),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(width: 38, child: Text('$pct%', style: TextStyle(fontSize: 13, color: crm.textSecondary))),
      ]);

  Widget _rowMenu(WbsNode node) {
    final r = _rights(node.task);
    // Someone who may not plan or add here has nothing to open (the details sheet is on the row itself).
    if (!_canAdd && !r.plan && !r.delete) return const SizedBox.shrink();
    return PopupMenuButton<String>(
        key: Key('wbs_menu_${node.task.id}'),
        padding: EdgeInsets.zero,
        iconSize: 20,
        onSelected: (v) async {
          switch (v) {
            case 'child':
              _refreshIf(await showTaskEditor(context, ref, widget.projectId, defaultParentId: node.task.id, allTasks: widget.tasks));
            case 'sibling':
              _refreshIf(await showTaskEditor(context, ref, widget.projectId, defaultParentId: node.task.parentTaskId, allTasks: widget.tasks));
            case 'up':
              await _move(node, -1);
            case 'down':
              await _move(node, 1);
            case 'edit':
              _refreshIf(await showTaskEditor(context, ref, widget.projectId, existing: node.task, allTasks: widget.tasks));
            case 'delete':
              await _delete(node);
          }
        },
        itemBuilder: (_) => [
          if (_canAdd) ...const [
            PopupMenuItem(value: 'child', child: Text('Add sub-task')),
            PopupMenuItem(value: 'sibling', child: Text('Add sibling')),
            PopupMenuDivider(),
          ],
          if (r.plan) ...[
            PopupMenuItem(key: Key('wbs_menu_up_${node.task.id}'), value: 'up', enabled: _moveChanges(node, -1).isNotEmpty, child: const Text('Move up')),
            PopupMenuItem(key: Key('wbs_menu_down_${node.task.id}'), value: 'down', enabled: _moveChanges(node, 1).isNotEmpty, child: const Text('Move down')),
            const PopupMenuDivider(),
          ],
          if (!r.readOnly) const PopupMenuItem(value: 'edit', child: Text('Edit')),
          if (r.delete) const PopupMenuItem(value: 'delete', child: Text('Delete')),
        ],
      );
  }

  /// The sort positions to write for [node] to go one place up (-1) or down (+1) beside its siblings — only when this
  /// person may plan every one of them.
  Map<String, int> _moveChanges(WbsNode node, int delta) {
    final changes = orderAfterMove(widget.tasks, node.task.id, delta);
    if (changes.isEmpty) return const {};
    final byId = {for (final t in widget.tasks) t.id: t};
    return changes.keys.every((id) => byId[id] != null && _rights(byId[id]!).plan) ? changes : const {};
  }

  Future<void> _move(WbsNode node, int delta) async {
    final changes = _moveChanges(node, delta);
    if (changes.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final notifier = getITTasksNotifier(ref, widget.projectId);
      for (final e in changes.entries) {
        await notifier.updateTaskField(e.key, {'order': e.value});
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
    }
  }

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

  Widget _cell(double w, Widget child) => SizedBox(width: w, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: child));
}

/// A round badge with someone's initials, in a colour that stays the same for the same name.
class _Avatar extends StatelessWidget {
  const _Avatar({required this.name});
  final String name;

  static const _palette = [Color(0xFF6D28D9), Color(0xFF0E7490), Color(0xFFB45309), Color(0xFF15803D), Color(0xFFBE185D), Color(0xFF1D4ED8)];

  @override
  Widget build(BuildContext context) {
    final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    final initials = words.isEmpty ? '?' : words.take(2).map((w) => w[0].toUpperCase()).join();
    final color = _palette[name.codeUnits.fold<int>(0, (a, b) => a + b) % _palette.length];
    return Container(
      width: 26,
      height: 26,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color.withValues(alpha: 0.14), shape: BoxShape.circle),
      child: Text(initials, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: color)),
    );
  }
}

/// The ring in the strip: the whole circle in grey, the part that is done on top in the brand colour.
class _RingPainter extends CustomPainter {
  _RingPainter({required this.pct, required this.track, required this.color});
  final int pct;
  final Color track;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 8.0;
    final rect = Rect.fromLTWH(stroke / 2, stroke / 2, size.width - stroke, size.height - stroke);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = track;
    canvas.drawArc(rect, 0, 2 * math.pi, false, paint);
    if (pct > 0) {
      paint.color = color;
      canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * pct.clamp(0, 100) / 100, false, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.pct != pct || old.track != track || old.color != color;
}

/// The tree line beside a task: it runs down from the row above and turns toward the number; it stops there on the
/// last task of a phase, and runs on to the next row on the others.
class _ConnectorPainter extends CustomPainter {
  _ConnectorPainter({required this.color, required this.isLast, required this.x});
  final Color color;
  final bool isLast;
  final double x;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;
    final mid = size.height / 2;
    canvas.drawLine(Offset(x, 0), Offset(x, isLast ? mid : size.height), paint);
    canvas.drawLine(Offset(x, mid), Offset(x + 14, mid), paint);
  }

  @override
  bool shouldRepaint(covariant _ConnectorPainter old) => old.color != color || old.isLast != isLast || old.x != x;
}
