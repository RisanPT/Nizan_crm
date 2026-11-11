import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/dashboard/presentation/widgets/dashboard_widgets.dart' show kDashGood;
import 'package:nizan_crm/features/finance/presentation/widgets/month_year_picker.dart';
import 'package:nizan_crm/features/it/domain/models/monthly_objective.dart';
import 'package:nizan_crm/features/it/domain/monthly_objective_stats.dart';
import 'package:nizan_crm/features/it/presentation/screens/widgets/monthly_objective_dialogs.dart';
import 'package:nizan_crm/features/it/presentation/screens/widgets/monthly_objectives_cards.dart';
import 'package:nizan_crm/features/it/presentation/screens/widgets/monthly_objectives_table.dart';
import 'package:nizan_crm/features/it/services/monthly_objective_service.dart';

/// Company Projects → Monthly objectives: every department's objectives for a month, each with key results. A department's head sets
/// them, anyone in the department sees them, the objective's owner reports progress, and at the month's end the head closes each one
/// (achieved / partly / missed) and carries what is unfinished into the next month. An objective can also be cancelled or postponed,
/// can take several months (its total runs on), and keeps a record of why its plan changed. Separate from the open-ended company OKRs.
///
/// The page: a title, the month (and which department to look at), the five headline numbers, then four tabs — a card for each
/// department with the trend, target against achievement and what stands out; the objectives as a table; the progress matrix of the
/// last months; and the month's key results.
class MonthlyObjectivesView extends ConsumerStatefulWidget {
  const MonthlyObjectivesView({super.key});

  @override
  ConsumerState<MonthlyObjectivesView> createState() => _MonthlyObjectivesViewState();
}

enum _Tab { overview, list, matrix, keyResults }

class _MonthlyObjectivesViewState extends ConsumerState<MonthlyObjectivesView> {
  late MonthKey _month = (year: DateTime.now().year, month: DateTime.now().month);
  _Tab _tab = _Tab.overview;
  ObjectiveFilter _filter = const ObjectiveFilter();

  void _go(MonthKey m) => setState(() => _month = m);

  Future<void> _pick() async {
    final r = await showMonthYearPicker(context, month: _month.month, year: _month.year);
    if (r != null) _go((year: r.year, month: r.month));
  }

  void _toast(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  void _refresh() {
    ref.invalidate(monthlyObjectivesProvider(_month));
    ref.invalidate(monthlyTrendProvider(_month));
  }

  // ── setting objectives and closing the month out ──

  List<MonthlyDepartment> _manageable(MonthlyObjectivesPage p) => [for (final d in p.departments) if (d.canManage) d];

  /// Which department an action is for: the one the page is narrowed to when this person runs it, the only one they run, or the one
  /// they pick.
  Future<MonthlyDepartment?> _chooseDepartment(MonthlyObjectivesPage p, {required String title}) async {
    final options = _manageable(p);
    if (options.isEmpty) return null;
    final narrowed = options.where((d) => d.departmentId == _filter.departmentId).firstOrNull;
    if (narrowed != null) return narrowed;
    if (options.length == 1) return options.first;
    return showDialog<MonthlyDepartment>(
      context: context,
      builder: (ctx) => SimpleDialog(
        key: const Key('mo_pick_dialog'),
        title: Text(title),
        children: [
          for (final d in options)
            SimpleDialogOption(key: Key('mo_pick_${d.departmentId}'), onPressed: () => Navigator.pop(ctx, d), child: Text(d.name, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  Future<void> _set(MonthlyObjectivesPage p) async {
    final d = await _chooseDepartment(p, title: 'Set an objective for…');
    if (d == null || !mounted) return;
    if (await showMonthlyObjectiveEditor(context, department: d, month: _month) == true) {
      ref.invalidate(monthlyTrendProvider(_month));
      _toast('Objective added');
    }
  }

  Future<void> _closeOut(MonthlyObjectivesPage p) async {
    final d = await _chooseDepartment(p, title: 'Close out the month for…');
    if (d == null || !mounted) return;
    final said = await showCloseOut(context, department: d, month: _month);
    if (said != null) {
      ref.invalidate(monthlyTrendProvider(_month));
      _toast(said);
    }
  }

  // ── the page ──

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final page = ref.watch(monthlyObjectivesProvider(_month));
    final now = DateTime.now();
    final isThisMonth = _month.year == now.year && _month.month == now.month;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(monthlyTrendProvider(_month));
        await ref.refresh(monthlyObjectivesProvider(_month).future).then<void>((_) {}, onError: (_) {});
      },
      child: LayoutBuilder(
        builder: (context, box) {
          final pad = box.maxWidth >= 600 ? 24.0 : 14.0;
          final width = box.maxWidth - pad * 2;
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(pad, 16, pad, 32),
            children: [
              _header(crm, page.value),
              const SizedBox(height: 14),
              _monthBar(crm, page.value, isThisMonth),
              const SizedBox(height: 14),
              page.when(
                loading: () => const Padding(padding: EdgeInsets.symmetric(vertical: 60), child: Center(child: CircularProgressIndicator())),
                error: (e, _) => AppErrorView(error: e, onRetry: () => ref.invalidate(monthlyObjectivesProvider(_month))),
                data: (p) => p.departments.isEmpty && p.assigned.isEmpty ? _noDepartments(crm) : _content(crm, p, width, now),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _header(CrmTheme crm, MonthlyObjectivesPage? p) {
    final manageable = p == null ? const <MonthlyDepartment>[] : _manageable(p);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(color: crm.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(13)),
          child: Icon(Icons.track_changes_rounded, size: 24, color: crm.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Monthly Objectives', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: crm.textPrimary, letterSpacing: -0.5)),
              Text('Plan, track and close out each department\'s month.', style: TextStyle(fontSize: 12.5, color: crm.textSecondary)),
            ],
          ),
        ),
        PopupMenuButton<String>(
          key: const Key('mo_header_menu'),
          tooltip: 'More',
          onSelected: (v) {
            if (v == 'refresh') _refresh();
            if (v == 'closeout' && p != null) _closeOut(p);
          },
          itemBuilder: (_) => [
            const PopupMenuItem(key: Key('mo_refresh'), value: 'refresh', child: Text('Refresh')),
            if (manageable.isNotEmpty) const PopupMenuItem(key: Key('mo_closeout'), value: 'closeout', child: Text('Close out the month…')),
          ],
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: crm.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: crm.border)),
            child: Icon(Icons.more_horiz_rounded, color: crm.textSecondary),
          ),
        ),
      ],
    );
  }

  Widget _monthBar(CrmTheme crm, MonthlyObjectivesPage? p, bool isThisMonth) {
    final departments = p?.departments ?? const <MonthlyDepartment>[];
    final narrowed = departments.where((d) => d.departmentId == _filter.departmentId).firstOrNull;
    // On a phone the month shrinks to fit and the "This Month" pill and the department filter wrap onto the next line; wider, they sit
    // beside it and the filter goes to the far side.
    Widget navRow() {
      final label = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                key: const Key('mo_title'),
                borderRadius: BorderRadius.circular(8),
                onTap: _pick,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Text(monthTitle(_month), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: crm.textPrimary, letterSpacing: -0.3)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Text(rangeText(_month), key: const Key('mo_range'), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, color: crm.textSecondary)),
              ),
            ],
      );
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(key: const Key('mo_prev'), tooltip: 'Previous month', onPressed: () => _go(prevMonthOf(_month)), icon: const Icon(Icons.chevron_left_rounded)),
          Flexible(child: label),
          IconButton(key: const Key('mo_next'), tooltip: 'Next month', onPressed: () => _go(nextMonthOf(_month)), icon: const Icon(Icons.chevron_right_rounded)),
        ],
      );
    }

    final now = isThisMonth
        ? Container(
            key: const Key('mo_this_month'),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: crm.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
            child: Text('This Month', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: crm.primary)),
          )
        : TextButton(key: const Key('mo_go_now'), onPressed: () => _go((year: DateTime.now().year, month: DateTime.now().month)), child: const Text('This month'));
    final filter = departments.length > 1
        ? PopupMenuButton<String>(
            key: const Key('mo_dept_filter'),
            tooltip: 'Department',
            onSelected: (v) => setState(() => _filter = _filter.copyWith(departmentId: v.isEmpty ? null : v)),
            itemBuilder: (_) => [
              const PopupMenuItem(key: Key('mo_dept_filter_all'), value: '', child: Text('All Departments')),
              for (final d in departments) PopupMenuItem(key: Key('mo_dept_filter_${d.departmentId}'), value: d.departmentId, child: Text(d.name)),
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(color: crm.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: narrowed == null ? crm.border : crm.primary)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.layers_outlined, size: 17, color: crm.textSecondary),
                  const SizedBox(width: 8),
                  Text(narrowed?.name ?? 'All Departments', key: const Key('mo_dept_filter_label'), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: crm.textPrimary)),
                  const SizedBox(width: 6),
                  Icon(Icons.expand_more_rounded, size: 18, color: crm.textSecondary),
                ],
              ),
            ),
          )
        : null;
    return LayoutBuilder(
      builder: (context, c) => c.maxWidth >= 720
          ? Row(children: [Expanded(child: Row(children: [Flexible(child: navRow()), const SizedBox(width: 8), now])), ?filter])
          : Wrap(crossAxisAlignment: WrapCrossAlignment.center, runSpacing: 8, spacing: 12, children: [navRow(), now, ?filter]),
    );
  }

  Widget _noDepartments(CrmTheme crm) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 48),
    child: Column(
      children: [
        Icon(Icons.flag_outlined, size: 44, color: crm.textSecondary),
        const SizedBox(height: 10),
        Text('No monthly objectives to show', key: const Key('mo_no_departments'), style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: crm.textPrimary)),
        const SizedBox(height: 4),
        Text('You are not part of a department yet. Ask an administrator to add you to one.', textAlign: TextAlign.center, style: TextStyle(color: crm.textSecondary)),
      ],
    ),
  );

  Widget _content(CrmTheme crm, MonthlyObjectivesPage p, double width, DateTime now) {
    const gap = 14.0;
    // the page may be narrowed to one department (and forgets it if that department is not in this month's list)
    final narrowedId = p.departments.any((d) => d.departmentId == _filter.departmentId) ? _filter.departmentId : null;
    final scope = [for (final d in p.departments) if (narrowedId == null || d.departmentId == narrowedId) d];
    final inScope = [for (final d in scope) ...d.objectives];
    final previous = scope.fold<int>(0, (s, d) => s + d.lastMonth.count);
    final stats = MonthlyStats.of(inScope, previousCount: previous);
    final filter = _filter.copyWith(departmentId: narrowedId);
    final shown = filter.apply(inScope);
    final canSet = _manageable(p).isNotEmpty;

    final table = ObjectivesTable(
      objectives: shown,
      inScope: inScope.length,
      departments: p.departments,
      month: _month,
      filter: filter,
      onFilterChanged: (f) => setState(() => _filter = f),
      canSet: canSet,
      onSet: () => _set(p),
      onToast: _toast,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // what has been given to this person comes first: it is what they have to do
        if (p.assigned.isNotEmpty) ...[_assigned(crm, p), const SizedBox(height: gap)],
        if (p.departments.isNotEmpty) ...[
          MonthlyKpiStrip(stats: stats, month: _month),
          const SizedBox(height: gap),
          _tabs(crm),
          const SizedBox(height: gap),
          switch (_tab) {
            _Tab.overview => _overview(crm, p, scope, stats, narrowedId, table, width, now),
            _Tab.list => table,
            _Tab.matrix => MonthlyProgressMatrix(month: _month, departmentId: narrowedId),
            _Tab.keyResults => KeyResultsPanel(objectives: filter.copyWith(query: '', statuses: const {}, priorities: const {}).apply(inScope), departments: p.departments, onToast: _toast),
          },
        ],
      ],
    );
  }

  Widget _tabs(CrmTheme crm) {
    Widget tab(_Tab t, String key, IconData icon, String label) {
      final on = _tab == t;
      return InkWell(
        key: Key(key),
        onTap: () => setState(() => _tab = t),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: on ? crm.primary : Colors.transparent, width: 2.5))),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 17, color: on ? crm.primary : crm.textSecondary),
              const SizedBox(width: 7),
              Text(label, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: on ? crm.primary : crm.textSecondary)),
            ],
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: crm.border))),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            tab(_Tab.overview, 'mo_tab_overview', Icons.apartment_rounded, 'Department Overview'),
            tab(_Tab.list, 'mo_tab_list', Icons.format_list_bulleted_rounded, 'Objective List'),
            tab(_Tab.matrix, 'mo_tab_matrix', Icons.grid_view_rounded, 'Progress Matrix'),
            tab(_Tab.keyResults, 'mo_tab_krs', Icons.flag_outlined, 'Key Results'),
          ],
        ),
      ),
    );
  }

  Widget _overview(CrmTheme crm, MonthlyObjectivesPage p, List<MonthlyDepartment> scope, MonthlyStats stats, String? narrowedId, Widget table, double width, DateTime now) {
    const gap = 14.0;
    final cols = width >= 1100 ? 3 : (width >= 640 ? 2 : 1);
    final narrowedName = p.departments.where((d) => d.departmentId == narrowedId).firstOrNull?.name;

    final trend = MonthlyTrendCard(month: _month, departmentId: narrowedId, departmentName: narrowedName);
    final target = MonthlyTargetCard(stats: stats, month: _month);
    final takeaways = MonthlyTakeawaysCard(takeaways: takeawaysFor(scope, _month, now));

    final Widget analytics = width >= 1100
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 5, child: trend),
              const SizedBox(width: gap),
              Expanded(flex: 4, child: target),
              const SizedBox(width: gap),
              Expanded(flex: 4, child: takeaways),
            ],
          )
        : (width >= 720
              ? Column(
                  children: [
                    trend,
                    const SizedBox(height: gap),
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: target), const SizedBox(width: gap), Expanded(child: takeaways)]),
                  ],
                )
              : Column(children: [trend, const SizedBox(height: gap), target, const SizedBox(height: gap), takeaways]));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // the cards sit in rows of equal height, so a card with a "last month" line does not make its neighbours ragged
        for (var start = 0; start < p.departments.length; start += cols) ...[
          if (start > 0) const SizedBox(height: gap),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var j = 0; j < cols; j++) ...[
                  if (j > 0) const SizedBox(width: gap),
                  Expanded(
                    child: start + j < p.departments.length
                        ? MonthlyDepartmentCard(
                            department: p.departments[start + j],
                            index: start + j,
                            month: _month,
                            selected: narrowedId == p.departments[start + j].departmentId,
                            // tapping a department narrows the page to it (tap it again to see them all)
                            onTap: () => setState(() {
                              final id = p.departments[start + j].departmentId;
                              _filter = _filter.copyWith(departmentId: narrowedId == id ? null : id);
                            }),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ],
            ),
          ),
        ],
        const SizedBox(height: gap),
        analytics,
        const SizedBox(height: gap),
        table,
      ],
    );
  }

  /// "Assigned to you": the objectives this person owns this month, from any department, each with its key results and — while it is
  /// open — a button to report on them. (Being the owner is enough to see and report on one, even outside its department.)
  Widget _assigned(CrmTheme crm, MonthlyObjectivesPage p) {
    return Container(
      key: const Key('mo_assigned'),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      decoration: BoxDecoration(color: crm.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: crm.primary.withValues(alpha: 0.45))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.person_pin_rounded, size: 20, color: crm.primary),
              const SizedBox(width: 8),
              Expanded(child: Text('Assigned to you', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: crm.textPrimary))),
              Text('${p.assigned.length}', key: const Key('mo_assigned_count'), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: crm.textSecondary)),
            ],
          ),
          const SizedBox(height: 6),
          for (var i = 0; i < p.assigned.length; i++) _assignedRow(crm, p.assigned[i], last: i == p.assigned.length - 1),
        ],
      ),
    );
  }

  Widget _assignedRow(CrmTheme crm, MonthlyObjective o, {required bool last}) {
    final canReport = o.access.canCheckIn && !o.isClosed;
    return Padding(
      key: Key('mo_assigned_${o.id}'),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 2,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(o.departmentName, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: crm.textSecondary)),
              if (o.span != null) Text('Month ${o.span!.number} of ${o.span!.total}', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: crm.primary)),
              if (o.result != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                  decoration: BoxDecoration(color: resultColor(o.result!).withValues(alpha: 0.14), borderRadius: BorderRadius.circular(20)),
                  child: Text(o.result!.label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: resultColor(o.result!))),
                ),
            ],
          ),
          const SizedBox(height: 2),
          Text(o.objective, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: crm.textPrimary)),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(child: progressBar(crm, o.progress, color: o.result == null ? null : resultColor(o.result!))),
              const SizedBox(width: 8),
              SizedBox(width: 36, child: Text('${o.progress}%', textAlign: TextAlign.right, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: crm.textPrimary))),
            ],
          ),
          if (o.keyResults.isEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text('No key results yet.', style: TextStyle(fontSize: 12.5, color: crm.textSecondary))),
          for (final k in o.keyResults)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  Icon(k.completed ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded, size: 17, color: k.completed ? kDashGood : crm.textSecondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: k.title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: crm.textPrimary)),
                          TextSpan(text: '  ${progressText(k)}', style: TextStyle(fontSize: 12, color: crm.textSecondary)),
                        ],
                      ),
                    ),
                  ),
                  if (canReport)
                    TextButton(
                      key: Key('mo_assigned_checkin_${o.id}_${k.id}'),
                      onPressed: () async {
                        if (await showKeyResultProgress(context, objective: o, kr: k) == true) _toast('Progress saved');
                      },
                      style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                      child: const Text('Update'),
                    ),
                ],
              ),
            ),
          if (!last) Divider(height: 18, color: crm.border.faded(2.5)),
        ],
      ),
    );
  }
}
