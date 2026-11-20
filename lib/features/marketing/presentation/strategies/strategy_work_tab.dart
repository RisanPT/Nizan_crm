import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart' show StateProvider;

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/finance/utils/csv_export.dart';
import 'package:nizan_crm/features/marketing/data/strategy_models.dart';
import 'package:nizan_crm/features/marketing/data/team_models.dart' show TeamRefusal;
import 'package:nizan_crm/features/marketing/presentation/kit/mkt_kit.dart';
import 'package:nizan_crm/features/marketing/presentation/strategies/strategy_editors.dart';
import 'package:nizan_crm/features/marketing/presentation/strategies/strategy_exports.dart';
import 'package:nizan_crm/features/marketing/presentation/strategies/strategy_widgets.dart';
import 'package:nizan_crm/features/marketing/services/strategy_service.dart';
import 'package:nizan_crm/features/marketing/services/team_service.dart' show teamFilterProvider;

/// Strategies & Developments → Initiatives: growth initiatives, experiments and improvement programmes. Owner, progress, due date and
/// status are counted from the tasks tied to each one (Tasks & Deliverables → Initiative, or Log Activity → Initiative).
class InitiativesTab extends StatelessWidget {
  const InitiativesTab({super.key});
  @override
  Widget build(BuildContext context) => const _WorkTab(kind: 'initiative');
}

/// Strategies & Developments → Development Projects: key business and marketing development projects, counted the same way.
class DevProjectsTab extends StatelessWidget {
  const DevProjectsTab({super.key});
  @override
  Widget build(BuildContext context) => const _WorkTab(kind: 'project');
}

class _WorkTab extends ConsumerWidget {
  const _WorkTab({required this.kind});
  final String kind;
  bool get _project => kind == 'project';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_project ? projectsProvider : initiativesProvider);
    final setup = strategySetupOf(ref);
    final p = _project ? 'dp' : 'in'; // key prefix
    // a new date range or brand starts the table on its first page again
    ref.listen(teamFilterProvider, (_, _) {
      final qp = _project ? projectQueryProvider : initiativeQueryProvider;
      final q = ref.read(qp);
      if (q.page != 1) ref.read(qp.notifier).state = q.copyWith(page: 1);
    });
    return RefreshIndicator(
      onRefresh: () async => refreshStrategies(ref),
      child: async.when(
        loading: () => ListView(children: const [SizedBox(height: 200), Center(child: CircularProgressIndicator())]),
        error: (e, _) => ListView(children: [AppErrorView(error: e, onRetry: () => refreshStrategies(ref))]),
        data: (d) {
          final c = d.counts;
          return ListView(
            key: Key('strategies_${kind}_list'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            children: [
              MktKpiRow(minWidth: 180, children: [
                MktKpiCard(key: Key('${p}_kpi_total'), icon: _project ? Icons.layers_outlined : Icons.flag_outlined, value: '${c.total}', label: _project ? 'Total Projects' : 'Total Initiatives', tint: Mkt.primary),
                MktKpiCard(key: Key('${p}_kpi_open'), icon: _project ? Icons.sync_rounded : Icons.play_circle_outline_rounded, value: '${c.open}', label: _project ? 'In Progress' : 'Active', tint: Mkt.blue),
                MktKpiCard(key: Key('${p}_kpi_completed'), icon: Icons.check_circle_outline_rounded, value: '${c.completed}', label: 'Completed', tint: Mkt.good),
                MktKpiCard(key: Key('${p}_kpi_hold'), icon: Icons.pause_circle_outline_rounded, value: '${c.onHold}', label: _project ? 'On Hold' : 'Paused', tint: Mkt.warn),
              ]),
              const SizedBox(height: 12),
              _WorkTable(kind: kind, data: d, setup: setup),
            ],
          );
        },
      ),
    );
  }
}

class _WorkTable extends ConsumerStatefulWidget {
  const _WorkTable({required this.kind, required this.data, required this.setup});
  final String kind;
  final WorkList data;
  final StrategySetup setup;
  @override
  ConsumerState<_WorkTable> createState() => _WorkTableState();
}

class _WorkTableState extends ConsumerState<_WorkTable> {
  bool get _project => widget.kind == 'project';
  StateProvider<WorkQuery> get _queryProvider => _project ? projectQueryProvider : initiativeQueryProvider;
  late final _search = TextEditingController(text: ref.read(_queryProvider).q);
  bool _exporting = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _set(WorkQuery q) => ref.read(_queryProvider.notifier).state = q;

  Future<void> _export() async {
    setState(() => _exporting = true);
    try {
      final svc = ref.read(marketingStrategyServiceProvider);
      final f = ref.read(teamFilterProvider);
      final q = ref.read(_queryProvider).copyWith(page: 1);
      final all = _project ? await svc.projects(f, q, limit: 100) : await svc.initiatives(f, q, limit: 100);
      await downloadCsv(_project ? 'development-projects.csv' : 'initiatives.csv', workCsv(all.items, project: _project));
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final q = ref.watch(_queryProvider);
    final p = _project ? 'dp' : 'in';
    final mayAdd = _project ? widget.setup.canManage : true;
    final chips = [
      ('all', 'All'),
      ('open', _project ? 'In Progress' : 'Active'),
      ('at_risk', 'At Risk'),
      ('on_hold', _project ? 'On Hold' : 'Paused'),
      ('completed', 'Completed'),
      if (widget.setup.canManage) ('cancelled', 'Cancelled'),
    ];
    final columns = _project
        ? const [MktCol('Project', flex: 5), MktCol('Category', flex: 3), MktCol('Owner', flex: 3), MktCol('Progress', flex: 4), MktCol('Status', flex: 3), MktCol('Due Date', flex: 3)]
        : const [MktCol('Initiative', flex: 5), MktCol('Focus Area', flex: 3), MktCol('Impact', flex: 2), MktCol('Owner', flex: 3), MktCol('Progress', flex: 4), MktCol('Status', flex: 3), MktCol('Due Date', flex: 3)];
    return MktCard(
      title: _project ? 'Development Projects' : 'Initiatives',
      subtitle: _project ? 'Owner, progress, due date and status come from the tasks tied to each project' : 'Owner, progress, due date and status come from the tasks tied to each initiative',
      icon: _project ? Icons.layers_outlined : Icons.flag_outlined,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Align(
          alignment: Alignment.centerRight,
          child: Wrap(spacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
            TextButton.icon(key: Key('${p}_export'), onPressed: _exporting ? null : _export, icon: const Icon(Icons.download_rounded, size: 16), label: const Text('Export')),
            if (mayAdd) TextButton(key: Key(_project ? 'st_new_project' : 'st_new_initiative_inline'), onPressed: () => showWorkEditor(context, ref, kind: widget.kind), child: Text(_project ? '+ New Project' : '+ New Initiative', style: mktText(11.5, weight: FontWeight.w700, color: Mkt.primary))),
          ]),
        ),
        Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
          for (final c in chips) MktFilterChip(key: Key('${p}_status_${c.$1}'), label: c.$2, selected: q.status == c.$1, onTap: () => _set(q.copyWith(status: c.$1, page: 1))),
          if (!_project && d.focusAreas.isNotEmpty)
            KeyedSubtree(key: const Key('in_focus_filter'), child: MktDropdownPill<String>(value: q.focusArea, icon: Icons.filter_alt_outlined, options: [('', 'All focus areas'), for (final f in d.focusAreas) (f, f)], onChanged: (v) => _set(q.copyWith(focusArea: v, page: 1)))),
          SizedBox(width: 220, child: TextField(key: Key('${p}_search'), controller: _search, onChanged: (v) => _set(q.copyWith(q: v, page: 1)), style: mktText(13), decoration: strategySearchDec(_project ? 'Search project, category…' : 'Search initiative, focus area…'))),
        ]),
        const SizedBox(height: 8),
        if (d.items.isEmpty)
          MktEmpty(q.status == 'all' && q.q.isEmpty && q.focusArea.isEmpty ? (_project ? 'No development project in this period.' : 'No initiative in this period. Use New Initiative.') : 'Nothing matches these filters.', icon: _project ? Icons.layers_outlined : Icons.flag_outlined, height: 130)
        else
          MktTable(
            minWidth: _project ? 760 : 880,
            rowHeight: 54,
            columns: columns,
            onRowTap: (i) => showWorkDetail(context, ref, kind: widget.kind, id: d.items[i].id),
            rowKeys: [for (final i in d.items) Key('${p}_row_${i.id}')],
            rows: [
              for (final i in d.items)
                [
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                      Text(i.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: mktText(12, weight: FontWeight.w700)),
                      if (i.brand == 'kerala') Text('Kerala', style: mktText(10, color: Mkt.inkSoft)),
                    ]),
                  ),
                  Padding(padding: const EdgeInsets.only(right: 6), child: (_project ? i.category : i.focusArea).isEmpty ? Text('—', style: mktText(12, color: Mkt.inkSoft)) : MktChip(_project ? i.category : i.focusArea, color: Mkt.primaryLight)),
                  if (!_project) MktChip(impactLabel(i.impact), color: priorityColor(i.impact)),
                  Padding(padding: const EdgeInsets.only(right: 6), child: OwnerCell(owner: i.owner)),
                  Padding(padding: const EdgeInsets.only(right: 8), child: WorkProgressCell(item: i)),
                  WorkStatusChip(i.status),
                  Text(strategyDay(i.due, pattern: 'd MMM yyyy'), maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(11.5)),
                ],
            ],
          ),
        const SizedBox(height: 4),
        StrategyPager(keyPrefix: p, page: d.page, pageSize: d.pageSize, total: d.total, shown: d.items.length, onPage: (n) => _set(q.copyWith(page: n))),
      ]),
    );
  }
}

// ── one initiative / project ─────────────────────────────────────────────────

/// Opens an initiative or a project: where its progress, owner and due date come from, the tasks tied to it and (initiatives) the hours
/// logged against it.
Future<void> showWorkDetail(BuildContext context, WidgetRef ref, {required String kind, required String id}) async {
  // "Edit" closes the detail and hands the record back, so the form opens from the screen (not from a closed dialog)
  final edit = await showStrategySheet<WorkItem>(context, _WorkDetail(kind: kind, id: id), maxWidth: 720);
  if (edit != null && context.mounted) await showWorkEditor(context, ref, kind: kind, item: edit);
}

class _WorkDetail extends ConsumerWidget {
  const _WorkDetail({required this.kind, required this.id});
  final String kind, id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(workDetailProvider((kind: kind, id: id)));
    final setup = strategySetupOf(ref);
    return async.when(
      loading: () => const SizedBox(height: 240, child: Center(child: CircularProgressIndicator())),
      error: (e, _) => Padding(padding: const EdgeInsets.all(12), child: AppErrorView(error: e, compact: true, onRetry: () => ref.invalidate(workDetailProvider((kind: kind, id: id))))),
      data: (d) => _body(context, ref, d, setup),
    );
  }

  Widget _body(BuildContext context, WidgetRef ref, WorkDetail d, StrategySetup setup) {
    final w = d.item;
    final project = w.isProject;
    Widget fact(String label, Widget value, {Key? key}) => SizedBox(
          width: 190,
          child: Column(key: key, crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: mktText(10.5, weight: FontWeight.w700, color: Mkt.inkSoft)), const SizedBox(height: 3), value]),
        );
    Future<void> delete() async {
      final yes = await confirmStrategyDelete(context, title: 'Delete this ${project ? 'project' : 'initiative'}?', body: '"${w.title}" is removed. One that has tasks or logged work tied to it cannot be deleted — mark it Cancelled instead, so the record stays.');
      if (!yes) return;
      try {
        final svc = ref.read(marketingStrategyServiceProvider);
        if (project) {
          await svc.deleteProject(w.id);
        } else {
          await svc.deleteInitiative(w.id);
        }
        refreshStrategies(ref);
        if (context.mounted) Navigator.pop(context);
      } on TeamRefusal catch (r) {
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(r.message)));
      } catch (e) {
        if (context.mounted) showErrorSnackBar(context, e);
      }
    }

    return Column(mainAxisSize: MainAxisSize.min, children: [
      Flexible(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Expanded(child: Text(w.title, key: const Key('wd_title'), maxLines: 2, overflow: TextOverflow.ellipsis, style: mktText(19, weight: FontWeight.w800))),
              const SizedBox(width: 8),
              WorkStatusChip(w.status, key: const Key('wd_status')),
            ]),
            Text([project ? 'Development project' : 'Initiative', if ((project ? w.category : w.focusArea).isNotEmpty) project ? w.category : w.focusArea, if (w.planTitle.isNotEmpty) 'Plan: ${w.planTitle}', if (w.brand == 'kerala') 'Kerala'].join(' · '), style: mktText(12, color: Mkt.inkSoft)),
            if (w.description.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(w.description, style: mktText(12.5))),
            const SizedBox(height: 14),
            Wrap(spacing: 14, runSpacing: 12, children: [
              fact('Owner', Row(mainAxisSize: MainAxisSize.min, children: [Flexible(child: OwnerCell(owner: w.owner)), if (w.owner?.source == 'tasks') Text(' (from tasks)', style: mktText(10.5, color: Mkt.inkSoft))]), key: const Key('wd_owner')),
              fact('Progress', WorkProgressCell(item: w), key: const Key('wd_progress')),
              fact('Start', Text(strategyDay(w.start), style: mktText(12.5))),
              fact('Due date', Text(w.due == null ? '—' : '${strategyDay(w.due)}${w.dueSource == 'tasks' ? ' (latest task)' : ''}', style: mktText(12.5)), key: const Key('wd_due')),
              fact('Hours logged', Text(w.minutes == 0 ? 'None yet' : hoursText(w.minutes), style: mktText(12.5, weight: FontWeight.w700)), key: const Key('wd_hours')),
              if (!project && w.impact.isNotEmpty) fact('Impact', MktChip(impactLabel(w.impact), color: priorityColor(w.impact))),
              if (w.closedDay != null) fact('Completed on', Text(strategyDay(w.closedDay), style: mktText(12.5))),
            ]),
            if (w.notes.isNotEmpty) ...[const SizedBox(height: 12), Text('Notes', style: mktText(11, weight: FontWeight.w700, color: Mkt.inkSoft)), Text(w.notes, style: mktText(12.5))],
            const SizedBox(height: 16),
            Text('Tasks tied to it (${d.tasks.length})', style: mktText(13, weight: FontWeight.w800)),
            const SizedBox(height: 6),
            if (d.tasks.isEmpty)
              Text('No task is tied to this ${project ? 'project' : 'initiative'} yet. Tie one from Tasks & Deliverables${project ? '' : ' or the Log Activity form'} and its progress counts itself.', key: const Key('wd_no_tasks'), style: mktText(12, color: Mkt.inkSoft))
            else
              for (final t in d.tasks)
                Container(
                  key: Key('wd_task_${t.id}'),
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Mkt.border))),
                  child: Row(children: [
                    Icon(t.status == 'completed' ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded, size: 16, color: t.status == 'completed' ? Mkt.good : Mkt.inkSoft),
                    const SizedBox(width: 8),
                    Expanded(child: Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(12.5, weight: FontWeight.w600))),
                    const SizedBox(width: 8),
                    Flexible(child: Text([if (t.assignee.isNotEmpty) t.assignee, if (t.dueDate != null) strategyDay(t.dueDate, pattern: 'd MMM')].join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(11, color: Mkt.inkSoft))),
                    const SizedBox(width: 8),
                    Text('${t.progress}%', style: mktText(11.5, weight: FontWeight.w700)),
                  ]),
                ),
            const SizedBox(height: 16),
            Text('Strategy work logged', style: mktText(13, weight: FontWeight.w800)),
            const SizedBox(height: 6),
            StrategyWorkChips(work: w.strategyWork, emptyText: 'No strategy step (project worked on, first draft, meeting, final draft, execution) has been counted on a log tied to it yet.'),
            ...[
              const SizedBox(height: 16),
              Text('Logged work', style: mktText(13, weight: FontWeight.w800)),
              const SizedBox(height: 6),
              if (d.logs.isEmpty) Text('Nothing has been logged against it yet (Log Activity → ${project ? 'Development project' : 'Initiative'}).', style: mktText(12, color: Mkt.inkSoft)),
              for (final l in d.logs)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(children: [
                    Expanded(child: Text('${l.member} · ${l.workedOn}', maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(12))),
                    const SizedBox(width: 8),
                    Text('${hoursText(l.minutes)} · ${strategyDay(l.day, pattern: 'd MMM')}', style: mktText(11, color: Mkt.inkSoft)),
                  ]),
                ),
            ],
          ]),
        ),
      ),
      Container(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: Mkt.border))),
        child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          if (setup.canManage) TextButton(key: const Key('wd_delete'), onPressed: delete, child: Text('Delete', style: mktText(13, weight: FontWeight.w700, color: Mkt.bad))),
          const Spacer(),
          if (canChangeWork(setup, w))
            OutlinedButton(
              key: const Key('wd_edit'),
              onPressed: () => Navigator.pop(context, w),
              child: const Text('Edit'),
            ),
          const SizedBox(width: 10),
          FilledButton(key: const Key('wd_close'), style: FilledButton.styleFrom(backgroundColor: Mkt.maroon), onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ]),
      ),
    ]);
  }
}
