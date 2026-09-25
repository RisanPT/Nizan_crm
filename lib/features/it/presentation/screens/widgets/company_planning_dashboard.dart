import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/utils/responsive_builder.dart';
import 'package:nizan_crm/core/auth/access_control.dart';
import 'package:nizan_crm/core/providers/auth_provider.dart';
import 'package:nizan_crm/core/providers/my_department_provider.dart';
import 'package:nizan_crm/features/org/data/department.dart';
import 'package:nizan_crm/features/org/services/department_service.dart';
import 'package:nizan_crm/features/inventory/presentation/widgets/inventory_widgets.dart' show InvStat, InvStatGrid;
import 'package:nizan_crm/features/it/data/project.dart';
import 'package:nizan_crm/features/it/services/it_service.dart';
import 'package:nizan_crm/features/it/services/okr_service.dart';
import 'package:nizan_crm/features/it/domain/models/okr_model.dart';
import 'package:nizan_crm/features/it/presentation/screens/it_projects_screen.dart' show projectStatusColor;
import 'package:nizan_crm/features/it/presentation/screens/widgets/okr_editor_dialog.dart';

const _companyBucket = 'Company-wide';

/// Leadership planning overview shown as the "Dashboard" mode of Company
/// Projects: cross-department portfolio roll-up + company/department OKRs.
class CompanyPlanningDashboard extends ConsumerWidget {
  const CompanyPlanningDashboard({super.key, required this.onOpenPortfolio});
  final VoidCallback onOpenPortfolio;

  bool _eqDept(String a, String b) => a.trim().toLowerCase() == b.trim().toLowerCase();
  bool _isCompanyOkr(OKRModel o) {
    final d = o.department.trim().toLowerCase();
    return d.isEmpty || d == 'company' || d == 'research-and-development';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crm = context.crmColors;
    final isMobile = ResponsiveBuilder.isMobile(context);
    final access = Access.of(ref.watch(authSessionProvider));
    // "Sees all" = admin/manager OR an Executive Coordinator (planning.manage):
    // company-wide scope. A department head is scoped to their own department.
    final isFull = access.isFullAccess || access.canManageAllPlanning;
    final myDept = ref.watch(myDepartmentNameProvider);
    final scopeDept = isFull ? null : (myDept.isEmpty ? null : myDept);

    final projectsAsync = ref.watch(companyProjectsProvider(scopeDept));
    final okrsAsync = ref.watch(planningOkrsProvider);
    final loading = projectsAsync.isLoading || okrsAsync.isLoading;

    final projects = projectsAsync.value ?? const <Project>[];
    final allOkrs = okrsAsync.value ?? const <OKRModel>[];
    // Dept heads only see their department's OKRs + company-wide ones.
    final okrs = isFull
        ? allOkrs
        : allOkrs.where((o) => _isCompanyOkr(o) || _eqDept(o.department, myDept)).toList();

    final depts = (ref.watch(departmentsProvider).value ?? const <Department>[])
        .where((d) => d.active)
        .map((d) => d.name)
        .toList();

    final now = DateTime.now();
    final active = projects.where((p) => p.status == 'active').length;
    final overdue = projects
        .where((p) => p.endDate != null && p.endDate!.isBefore(now) && p.status != 'completed')
        .toList();
    final avgProg = projects.isEmpty ? 0 : (projects.map((p) => p.progress).reduce((a, b) => a + b) / projects.length).round();
    final avgOkr = okrs.isEmpty ? 0 : (okrs.map((o) => o.progress).reduce((a, b) => a + b) / okrs.length).round();
    final blocked = okrs.where((o) => o.status == OKRStatus.blocked).toList();

    Future<void> openOkr({OKRModel? existing}) async {
      final planningDepts = isFull ? depts : (myDept.isEmpty ? depts : [myDept]);
      final saved = await showOKREditorDialog(context, ref,
          projectId: null, existing: existing, planningDepartments: planningDepts);
      if (saved == true) ref.invalidate(planningOkrsProvider);
    }

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(companyProjectsProvider);
        ref.invalidate(planningOkrsProvider);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(isMobile ? 12 : 16, 14, isMobile ? 12 : 16, 40),
        children: [
          Row(children: [
            Text(isFull ? 'Company overview' : '$myDept overview',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: crm.textPrimary)),
            const SizedBox(width: 8),
            if (loading) const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
            const Spacer(),
            TextButton.icon(
              onPressed: onOpenPortfolio,
              icon: const Icon(Icons.grid_view_outlined, size: 16),
              label: const Text('Full portfolio'),
            ),
          ]),
          // Don't let a failed load masquerade as "0 projects / 0 OKRs".
          if (projectsAsync.hasError || okrsAsync.hasError) ...[
            const SizedBox(height: 10),
            AppErrorView(
              error: projectsAsync.error ?? okrsAsync.error,
              compact: true,
              onRetry: () {
                ref.invalidate(companyProjectsProvider);
                ref.invalidate(planningOkrsProvider);
              },
            ),
          ],
          const SizedBox(height: 10),
          InvStatGrid(isMobile: isMobile, stats: [
            InvStat('${projects.length}', 'Projects', Icons.hub_outlined, crm.primary),
            InvStat('$active', 'Active', Icons.play_circle_outline, const Color(0xFF2E8B57)),
            InvStat('${overdue.length}', 'Overdue', Icons.warning_amber_outlined, Colors.red.shade600),
            InvStat('$avgProg%', 'Avg progress', Icons.donut_large_outlined, Colors.blue.shade600),
            InvStat('${okrs.length}', 'Objectives', Icons.flag_outlined, const Color(0xFF7C3AED)),
            InvStat('$avgOkr%', 'OKR progress', Icons.trending_up, const Color(0xFF0EA5E9)),
          ]),
          const SizedBox(height: 16),

          // Charts
          if (isFull) ...[
            _section(crm, 'Projects by department', _deptBar(crm, projects)),
            const SizedBox(height: 14),
          ],
          _section(crm, 'Project status', _statusDonut(crm, projects, isMobile)),
          const SizedBox(height: 16),

          // Attention
          if (overdue.isNotEmpty || blocked.isNotEmpty) ...[
            _attention(context, crm, overdue, blocked, openOkr),
            const SizedBox(height: 16),
          ],

          // OKRs
          _okrSection(context, crm, access, okrs, openOkr),
        ],
      ),
    );
  }

  // ── Sections ────────────────────────────────────────────────────────────────

  Widget _section(CrmTheme crm, String title, Widget child) => Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        decoration: BoxDecoration(color: crm.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: crm.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: crm.textPrimary)),
          const SizedBox(height: 12),
          child,
        ]),
      );

  Widget _deptBar(CrmTheme crm, List<Project> projects) {
    final counts = <String, int>{};
    for (final p in projects) {
      final d = p.targetDepartment.isEmpty ? 'Unassigned' : p.targetDepartment;
      counts[d] = (counts[d] ?? 0) + 1;
    }
    if (counts.isEmpty) return _emptyHint(crm, 'No projects yet.');
    final entries = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final maxV = entries.map((e) => e.value).reduce((a, b) => a > b ? a : b).toDouble();
    return SizedBox(
      height: 180,
      child: BarChart(BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxV * 1.2,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => crm.textPrimary,
            getTooltipItem: (group, _, rod, _) => BarTooltipItem(
              '${entries[group.x].key}\n',
              const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 11),
              children: [TextSpan(text: '${entries[group.x].value} projects', style: const TextStyle(color: Colors.white, fontSize: 11))],
            ),
          ),
        ),
        gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (_) => FlLine(color: crm.border, strokeWidth: 0.6)),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 26, getTitlesWidget: (v, _) => Text(v.toInt().toString(), style: TextStyle(fontSize: 9, color: crm.textSecondary)))),
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30, getTitlesWidget: (v, _) {
            final i = v.toInt();
            if (i < 0 || i >= entries.length) return const SizedBox.shrink();
            final name = entries[i].key;
            return Padding(padding: const EdgeInsets.only(top: 4), child: Text(name.length > 6 ? name.substring(0, 6) : name, style: TextStyle(fontSize: 9, color: crm.textSecondary)));
          })),
        ),
        barGroups: [
          for (var i = 0; i < entries.length; i++)
            BarChartGroupData(x: i, barRods: [
              BarChartRodData(toY: entries[i].value.toDouble(), width: 16, borderRadius: const BorderRadius.vertical(top: Radius.circular(4)), color: crm.primary),
            ]),
        ],
      )),
    );
  }

  Widget _statusDonut(CrmTheme crm, List<Project> projects, bool isMobile) {
    const order = ['planning', 'active', 'on-hold', 'completed', 'cancelled'];
    final counts = <String, int>{};
    for (final p in projects) {
      counts[p.status] = (counts[p.status] ?? 0) + 1;
    }
    final present = order.where((s) => (counts[s] ?? 0) > 0).toList();
    if (present.isEmpty) return _emptyHint(crm, 'No projects yet.');
    return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
      SizedBox(
        width: 120,
        height: 120,
        child: PieChart(PieChartData(
          sectionsSpace: 2,
          centerSpaceRadius: 34,
          sections: [
            for (final s in present)
              PieChartSectionData(value: counts[s]!.toDouble(), color: projectStatusColor(s), radius: 18, showTitle: false),
          ],
        )),
      ),
      const SizedBox(width: 16),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (final s in present)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(children: [
                Container(width: 10, height: 10, decoration: BoxDecoration(color: projectStatusColor(s), borderRadius: BorderRadius.circular(3))),
                const SizedBox(width: 8),
                Expanded(child: Text(_titleCase(s), style: TextStyle(fontSize: 12.5, color: crm.textPrimary))),
                Text('${counts[s]}', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: crm.textSecondary)),
              ]),
            ),
        ]),
      ),
    ]);
  }

  Widget _attention(BuildContext context, CrmTheme crm, List<Project> overdue, List<OKRModel> blocked, Future<void> Function({OKRModel? existing}) openOkr) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.red.withValues(alpha: 0.25))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.notification_important_outlined, size: 16, color: Colors.red.shade700),
          const SizedBox(width: 6),
          Text('Needs attention', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: crm.textPrimary)),
        ]),
        const SizedBox(height: 8),
        for (final p in overdue.take(5))
          _attnRow(crm, Icons.event_busy_outlined, Colors.red.shade600, p.name, 'Overdue · ${p.targetDepartment}', () => context.go('/projects/${p.id}')),
        for (final o in blocked.take(5))
          _attnRow(crm, Icons.block, const Color(0xFFEF4444), o.objective, 'Blocked OKR · ${o.department}', () => openOkr(existing: o)),
      ]),
    );
  }

  Widget _attnRow(CrmTheme crm, IconData icon, Color color, String title, String sub, VoidCallback onTap) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: crm.textSecondary)),
              ]),
            ),
            Icon(Icons.chevron_right, size: 16, color: crm.textSecondary),
          ]),
        ),
      );

  Widget _okrSection(BuildContext context, CrmTheme crm, Access access, List<OKRModel> okrs, Future<void> Function({OKRModel? existing}) openOkr) {
    final canManage = access.isFullAccess || access.isDepartmentHead || access.canManageAllPlanning;
    // Group by bucket.
    final groups = <String, List<OKRModel>>{};
    for (final o in okrs) {
      final key = _isCompanyOkr(o) ? _companyBucket : o.department;
      (groups[key] ??= []).add(o);
    }
    final keys = groups.keys.toList()
      ..sort((a, b) => a == _companyBucket ? -1 : (b == _companyBucket ? 1 : a.compareTo(b)));

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(color: crm.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: crm.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.track_changes_outlined, size: 16, color: crm.primary),
          const SizedBox(width: 6),
          Text('Objectives & Key Results', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: crm.textPrimary)),
          const Spacer(),
          if (canManage)
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: crm.primary, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), minimumSize: const Size(0, 34)),
              onPressed: () => openOkr(),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add objective'),
            ),
        ]),
        const SizedBox(height: 10),
        if (okrs.isEmpty)
          _emptyHint(crm, 'No company or department objectives yet.')
        else
          for (final k in keys) ...[
            Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 4),
              child: Text(k, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: crm.textSecondary, letterSpacing: 0.3)),
            ),
            for (final o in groups[k]!) _okrRow(crm, o, canManage ? () => openOkr(existing: o) : null),
          ],
      ]),
    );
  }

  Widget _okrRow(CrmTheme crm, OKRModel o, VoidCallback? onTap) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(color: crm.background, borderRadius: BorderRadius.circular(10), border: Border.all(color: crm.border)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(o.objective, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700))),
              const SizedBox(width: 8),
              _pill(o.status.label, o.status.color),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(value: o.progress / 100, minHeight: 7, backgroundColor: crm.border, valueColor: AlwaysStoppedAnimation(o.status.color)),
                ),
              ),
              const SizedBox(width: 8),
              Text('${o.progress}%', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: crm.textPrimary)),
            ]),
            const SizedBox(height: 6),
            Row(children: [
              _pill(o.priority.label, o.priority.color),
              const SizedBox(width: 6),
              Icon(Icons.checklist_rtl, size: 13, color: crm.textSecondary),
              const SizedBox(width: 3),
              Text('${o.keyResults.length} KR${o.keyResults.length == 1 ? '' : 's'}', style: TextStyle(fontSize: 11, color: crm.textSecondary)),
              if (o.projectHeadName.isNotEmpty) ...[
                const Spacer(),
                Icon(Icons.person_outline, size: 13, color: crm.textSecondary),
                const SizedBox(width: 3),
                Flexible(child: Text(o.projectHeadName, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: crm.textSecondary))),
              ],
            ]),
          ]),
        ),
      );

  Widget _pill(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(7)),
        child: Text(label, style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.w700)),
      );

  Widget _emptyHint(CrmTheme crm, String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Center(child: Text(text, style: TextStyle(fontSize: 12.5, color: crm.textSecondary))),
      );

  static String _titleCase(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).replaceAll('-', ' ');
}
