import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/utils/responsive_builder.dart';
import 'package:nizan_crm/core/auth/access_control.dart';
import 'package:nizan_crm/core/providers/auth_provider.dart';
import 'package:nizan_crm/core/providers/my_department_provider.dart';
import 'package:nizan_crm/features/notifications/controllers/notification_providers.dart';
import 'package:nizan_crm/features/org/data/department.dart';
import 'package:nizan_crm/features/org/services/department_service.dart';
import 'package:nizan_crm/features/it/data/it_task.dart';
import 'package:nizan_crm/features/it/data/project.dart';
import 'package:nizan_crm/features/it/domain/project_dashboard_stats.dart';
import 'package:nizan_crm/features/it/services/it_service.dart';
import 'package:nizan_crm/features/it/services/okr_service.dart';
import 'package:nizan_crm/features/it/domain/models/okr_model.dart';
import 'package:nizan_crm/features/it/presentation/controllers/it_tasks_notifier.dart';
import 'package:nizan_crm/features/it/presentation/screens/widgets/it_task_detail_sheet.dart';
import 'package:nizan_crm/features/it/presentation/screens/widgets/okr_editor_dialog.dart';
import 'package:nizan_crm/features/it/presentation/screens/widgets/project_dashboard_activity.dart';
import 'package:nizan_crm/features/it/presentation/screens/widgets/project_dashboard_cards.dart';
import 'package:nizan_crm/features/it/presentation/screens/widgets/project_dashboard_kit.dart';

const _companyBucket = 'Company-wide';

/// Leadership planning overview shown as the "Dashboard" mode of Company Projects: the headline numbers, progress,
/// what stands out, departments, a timeline, my tasks and notifications for the chosen period — then the strategic
/// horizon and the company/department OKRs underneath.
class CompanyPlanningDashboard extends ConsumerStatefulWidget {
  const CompanyPlanningDashboard({super.key, required this.onOpenPortfolio, this.now});
  final VoidCallback onOpenPortfolio;

  /// "Today" — only a test sets it, so dates in a test never depend on the day it runs.
  final DateTime? now;

  @override
  ConsumerState<CompanyPlanningDashboard> createState() => _CompanyPlanningDashboardState();
}

class _CompanyPlanningDashboardState extends ConsumerState<CompanyPlanningDashboard> {
  static const _gap = 14.0;

  DashboardPeriod _period = DashboardPeriod.year;
  DaySpan? _custom;

  bool _eqDept(String a, String b) => a.trim().toLowerCase() == b.trim().toLowerCase();
  bool _isCompanyOkr(OKRModel o) {
    // The level is explicit now; only an older objective without one is judged by its department text.
    if (o.level.isNotEmpty) return o.level == 'company';
    final d = o.department.trim().toLowerCase();
    return d.isEmpty || d == 'company' || d == 'research-and-development';
  }

  void _refresh() {
    ref.invalidate(companyProjectsProvider);
    ref.invalidate(planningOkrsProvider);
    ref.invalidate(allTasksProvider);
    ref.invalidate(myTasksProvider);
    ref.invalidate(notificationsProvider);
  }

  Future<void> _pickRange(DaySpan current) async {
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(start: current.start, end: current.end),
      firstDate: DateTime(2020),
      lastDate: DateTime(2045),
      helpText: 'Show projects running between',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _custom = DaySpan(picked.start, picked.end);
      _period = DashboardPeriod.custom;
    });
  }

  void _openTask(ITTask t) {
    final all = ref.read(myTasksProvider).value ?? const <ITTask>[];
    final sameProject = all.where((e) => e.projectId == t.projectId).toList();
    showITTaskDetailSheet(context, ref, task: t, allTasks: sameProject).then((_) {
      ref.invalidate(myTasksProvider);
      ref.invalidate(allTasksProvider);
      if (mounted) refreshAllItTaskViews(ref);
    });
  }

  @override
  Widget build(BuildContext context) {
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
    final allTasksAsync = ref.watch(allTasksProvider);
    final myTasksAsync = ref.watch(myTasksProvider);
    final loading = projectsAsync.isLoading || okrsAsync.isLoading;

    final projects = projectsAsync.value ?? const <Project>[];
    final allOkrs = okrsAsync.value ?? const <OKRModel>[];
    // Dept heads only see their department's OKRs + company-wide ones.
    final okrs = isFull
        ? allOkrs
        : allOkrs
              .where((o) => _isCompanyOkr(o) || _eqDept(o.department, myDept) || (o.projectId != null && projects.any((p) => p.id == o.projectId)))
              .toList();

    final depts = (ref.watch(departmentsProvider).value ?? const <Department>[]).where((d) => d.active).map((d) => d.name).toList();

    final now = widget.now ?? DateTime.now();
    final span = periodSpan(_period, now, custom: _custom);
    final stats = ProjectDashboardStats.compute(projects, span, now);
    final blocked = okrs.where((o) => o.status == OKRStatus.blocked).toList();
    final avgOkr = okrs.isEmpty ? 0 : (okrs.map((o) => o.progress).reduce((a, b) => a + b) / okrs.length).round();

    // the tasks of the projects shown, and one colour per department that every chart agrees on
    final ids = {for (final p in stats.projects) p.id};
    final periodTasks = allTasksAsync.whenData(
      (all) => [
        for (final t in all)
          if (ids.contains(t.projectId)) t,
      ],
    );
    final byId = {for (final p in stats.projects) p.id: p};
    final order = {for (var i = 0; i < stats.departments.length; i++) stats.departments[i].name: i};
    Color colorOf(String name) => deptColor(order[name] ?? 7);
    final totals = periodTasks.hasValue ? taskTotals(periodTasks.value!, now) : const TaskTotals();
    final taskDepts = periodTasks.hasValue ? tasksByDepartment(periodTasks.value!, byId) : const <String, int>{};

    Future<void> openOkr({OKRModel? existing}) async {
      final planningDepts = isFull ? depts : (myDept.isEmpty ? depts : [myDept]);
      final saved = await showOKREditorDialog(context, ref, projectId: null, existing: existing, planningDepartments: planningDepts);
      if (saved == true) ref.invalidate(planningOkrsProvider);
    }

    final overdueAll = projects.where((p) => isOverdue(p, now)).toList();

    final progress = ProgressOverviewCard(stats: stats, tasks: periodTasks, now: now, onRetryTasks: () => ref.invalidate(allTasksProvider));
    final insights = KeyInsightsCard(insights: stats.insights(blockedObjectives: blocked.length));
    final byDept = DepartmentDonutCard(departments: stats.departments, colorOf: colorOf);
    final top = TopDepartmentsCard(top: topDepartments(stats.departments), colorOf: colorOf);
    final overview = TaskOverviewCard(
      totals: totals,
      byDepartment: taskDepts,
      colorOf: colorOf,
      loading: periodTasks.isLoading && !periodTasks.hasValue,
      failed: periodTasks.hasError && !periodTasks.hasValue,
      onRetry: () => ref.invalidate(allTasksProvider),
    );
    const notifications = NotificationsCard();
    // the money: only when this person may see some project's amounts
    final budget = stats.budget.projects > 0 ? BudgetVsActualCard(totals: stats.budget, onOpenProject: (id) => context.go('/projects/$id')) : null;
    UpcomingProjectsCard upcoming({required bool compact}) => UpcomingProjectsCard(
      rows: upcomingProjects(stats.projects, now),
      span: _ganttSpan(span),
      now: now,
      compact: compact,
      onOpen: (id) => context.go('/projects/$id'),
      onViewAll: widget.onOpenPortfolio,
    );
    MyTasksCard myTasks({required bool compact}) => MyTasksCard(
      tasks: myTasksAsync,
      now: now,
      compact: compact,
      onOpenTask: _openTask,
      onViewAll: () => context.go('/my-tasks'),
      onRetry: () => ref.invalidate(myTasksProvider),
    );

    return RefreshIndicator(
      onRefresh: () async => _refresh(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(isMobile ? 12 : 20, 16, isMobile ? 12 : 20, 40),
        children: [
          _header(crm, isFull ? 'Project Dashboard' : '$myDept Project Dashboard', span, isMobile),
          if (loading) const Padding(padding: EdgeInsets.only(top: 10), child: LinearProgressIndicator(minHeight: 2)),
          // Don't let a failed load masquerade as "0 projects / 0 OKRs".
          if (projectsAsync.hasError || okrsAsync.hasError) ...[
            const SizedBox(height: 10),
            AppErrorView(error: projectsAsync.error ?? okrsAsync.error, compact: true, onRetry: _refresh),
          ],
          const SizedBox(height: 16),
          DashKpiStrip(stats: stats),
          const SizedBox(height: _gap),
          LayoutBuilder(
            builder: (context, c) {
              final w = c.maxWidth;
              if (w >= 1080) {
                // the reference layout: the big cards on the left, the "what needs a look" column on the right
                final leftW = (w - _gap) * 0.73;
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 73,
                      child: Column(
                        children: [
                          progress,
                          const SizedBox(height: _gap),
                          _pair([(4, byDept), (6, upcoming(compact: (leftW - _gap) * 0.6 < 480))]),
                          const SizedBox(height: _gap),
                          _pair([(6, myTasks(compact: (leftW - _gap) * 0.6 < 440)), (4, overview)]),
                          if (budget != null) ...[const SizedBox(height: _gap), budget],
                        ],
                      ),
                    ),
                    const SizedBox(width: _gap),
                    Expanded(
                      flex: 27,
                      child: Column(
                        children: [
                          insights,
                          const SizedBox(height: _gap),
                          top,
                          const SizedBox(height: _gap),
                          notifications,
                        ],
                      ),
                    ),
                  ],
                );
              }
              if (w >= 700) {
                return Column(
                  children: [
                    progress,
                    const SizedBox(height: _gap),
                    _pair([(1, insights), (1, top)]),
                    const SizedBox(height: _gap),
                    _pair([(1, byDept), (1, overview)]),
                    const SizedBox(height: _gap),
                    upcoming(compact: w < 560),
                    const SizedBox(height: _gap),
                    _pair([(1, myTasks(compact: true)), (1, notifications)]),
                    if (budget != null) ...[const SizedBox(height: _gap), budget],
                  ],
                );
              }
              return Column(
                children: [
                  for (final card in [progress, insights, byDept, upcoming(compact: true), top, myTasks(compact: true), overview, ?budget, notifications]) ...[
                    card,
                    const SizedBox(height: _gap),
                  ],
                ],
              );
            },
          ),

          // ── strategy: what needs attention, the 15-year horizon and the objectives ──
          const SizedBox(height: 10),
          if (overdueAll.isNotEmpty || blocked.isNotEmpty) ...[_attention(context, crm, overdueAll, blocked, openOkr), const SizedBox(height: 16)],
          _section(
            crm,
            '15-Year Strategic Horizon Distribution (Vision 2040)',
            _horizonDistribution(crm, stats.projects),
            icon: Icons.auto_graph_outlined,
          ),
          const SizedBox(height: 16),
          _okrSection(context, crm, access, okrs, openOkr, avgOkr),
        ],
      ),
    );
  }

  /// The timeline needs room to show a bar: a week or a month is drawn against its whole quarter.
  DaySpan _ganttSpan(DaySpan span) {
    if (span.days > 100) return span;
    final q = (span.start.month - 1) ~/ 3;
    return DaySpan(DateTime(span.start.year, q * 3 + 1, 1), DateTime(span.start.year, q * 3 + 4, 0));
  }

  /// Equal-height cards side by side; each number is its share of the width.
  Widget _pair(List<(int, Widget)> cards) => IntrinsicHeight(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < cards.length; i++) ...[if (i > 0) const SizedBox(width: _gap), Expanded(flex: cards[i].$1, child: cards[i].$2)],
      ],
    ),
  );

  Widget _header(CrmTheme crm, String title, DaySpan span, bool isMobile) {
    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          key: const Key('pd_title'),
          style: TextStyle(fontSize: isMobile ? 20 : 24, fontWeight: FontWeight.w800, color: crm.textPrimary, letterSpacing: -0.6),
        ),
        const SizedBox(height: 2),
        Text('Track progress, performance and key insights across all your projects', style: TextStyle(fontSize: 12.5, color: crm.textSecondary)),
      ],
    );
    final controls = Wrap(
      spacing: 10,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        DashSegmented<DashboardPeriod>(
          keyPrefix: 'pd_period',
          value: _period,
          options: const [
            (DashboardPeriod.week, 'This Week'),
            (DashboardPeriod.month, 'This Month'),
            (DashboardPeriod.quarter, 'This Quarter'),
            (DashboardPeriod.year, 'This Year'),
          ],
          onChanged: (p) => setState(() => _period = p),
        ),
        InkWell(
          key: const Key('pd_range'),
          onTap: () => _pickRange(span),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: _period == DashboardPeriod.custom ? crm.primary.withValues(alpha: 0.08) : crm.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _period == DashboardPeriod.custom ? crm.primary : crm.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.calendar_month_outlined, size: 16, color: crm.textSecondary),
                const SizedBox(width: 7),
                Text(
                  _rangeText(span),
                  key: const Key('pd_range_text'),
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: crm.textPrimary),
                ),
                const SizedBox(width: 4),
                Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: crm.textSecondary),
              ],
            ),
          ),
        ),
      ],
    );
    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          titleBlock,
          const SizedBox(height: 12),
          SingleChildScrollView(scrollDirection: Axis.horizontal, child: controls),
        ],
      );
    }
    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth < 980) {
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [titleBlock, const SizedBox(height: 12), controls]);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: titleBlock),
            const SizedBox(width: 16),
            controls,
          ],
        );
      },
    );
  }

  /// "Jan 2026 – Dec 2026", or "3 Nov – 9 Nov 2026" when it is a matter of days.
  String _rangeText(DaySpan s) {
    if (s.days <= 62) {
      final a = shortDate(s.start, DateTime(s.end.year));
      return '$a – ${shortDate(s.end, DateTime(s.end.year + 1))}';
    }
    return '${monthYear(s.start)} – ${monthYear(s.end)}';
  }

  // ── Sections ────────────────────────────────────────────────────────────────

  Widget _section(CrmTheme crm, String title, Widget child, {IconData? icon}) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: crm.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: crm.border),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 6, offset: const Offset(0, 2))],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (icon != null) ...[Icon(icon, size: 17, color: crm.primary), const SizedBox(width: 8)],
            Expanded(
              child: Text(
                title,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: crm.textPrimary),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        child,
      ],
    ),
  );

  Widget _horizonDistribution(CrmTheme crm, List<Project> projects) {
    final h1 = projects.where((p) => (p.horizonNumber) == 1).toList();
    final h2 = projects.where((p) => p.horizonNumber == 2).toList();
    final h3 = projects.where((p) => p.horizonNumber == 3).toList();

    int avg(List<Project> l) => l.isEmpty ? 0 : (l.map((p) => p.progress).reduce((a, b) => a + b) / l.length).round();

    return LayoutBuilder(
      builder: (ctx, c) {
        final isNarrow = c.maxWidth < 650;
        final items = [
          _horizonTile(crm, 'Horizon 1 (2026–2028)', 'Foundation & Regional Hubs', h1.length, avg(h1), const Color(0xFF2563EB)),
          _horizonTile(crm, 'Horizon 2 (2029–2033)', 'Pan-India Scaling Engine', h2.length, avg(h2), const Color(0xFF7C3AED)),
          _horizonTile(crm, 'Horizon 3 (2034–2041)', 'Global Luxury Brand', h3.length, avg(h3), const Color(0xFFE11D48)),
        ];
        if (isNarrow) {
          return Column(
            children: [for (final it in items) Padding(padding: const EdgeInsets.only(bottom: 10), child: it)],
          );
        }
        return Row(
          children: [
            for (var i = 0; i < items.length; i++) ...[if (i > 0) const SizedBox(width: 12), Expanded(child: items[i])],
          ],
        );
      },
    );
  }

  Widget _horizonTile(CrmTheme crm, String title, String subtitle, int count, int progress, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: crm.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                child: Text(
                  '$count proj',
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: color),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: TextStyle(fontSize: 10.5, color: crm.textSecondary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress / 100,
                    minHeight: 6,
                    backgroundColor: crm.background,
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$progress%',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: crm.textPrimary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _attention(
    BuildContext context,
    CrmTheme crm,
    List<Project> overdue,
    List<OKRModel> blocked,
    Future<void> Function({OKRModel? existing}) openOkr,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.notification_important_outlined, size: 16, color: Colors.red.shade700),
              const SizedBox(width: 6),
              Text(
                'Needs attention',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: crm.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final p in overdue.take(5))
            _attnRow(
              crm,
              Icons.event_busy_outlined,
              Colors.red.shade600,
              p.name,
              'Overdue · ${p.targetDepartment}',
              () => context.go('/projects/${p.id}'),
            ),
          for (final o in blocked.take(5))
            _attnRow(crm, Icons.block, const Color(0xFFEF4444), o.objective, 'Blocked OKR · ${o.department}', () => openOkr(existing: o)),
        ],
      ),
    );
  }

  Widget _attnRow(CrmTheme crm, IconData icon, Color color, String title, String sub, VoidCallback onTap) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(8),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                ),
                Text(
                  sub,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: crm.textSecondary),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, size: 16, color: crm.textSecondary),
        ],
      ),
    ),
  );

  Widget _okrSection(
    BuildContext context,
    CrmTheme crm,
    Access access,
    List<OKRModel> okrs,
    Future<void> Function({OKRModel? existing}) openOkr,
    int avgProgress,
  ) {
    final canManage = access.isFullAccess || access.isDepartmentHead || access.canManageAllPlanning;
    // Group by bucket.
    final groups = <String, List<OKRModel>>{};
    for (final o in okrs) {
      final key = _isCompanyOkr(o)
          ? _companyBucket
          : (o.projectId != null && o.projectId!.isNotEmpty
                ? (o.projectName.isNotEmpty ? 'Project: ${o.projectName}' : 'Project Objectives')
                : _titleCase(o.department));
      (groups[key] ??= []).add(o);
    }
    final keys = groups.keys.toList()
      ..sort((a, b) {
        if (a == _companyBucket) return -1;
        if (b == _companyBucket) return 1;
        if (a.startsWith('Project') && !b.startsWith('Project')) return 1;
        if (!a.startsWith('Project') && b.startsWith('Project')) return -1;
        return a.compareTo(b);
      });

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: crm.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // a Wrap, not a Row: on a narrow phone the button drops below the title instead of running off the card
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.track_changes_outlined, size: 16, color: crm.primary),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Objectives & Key Results',
                      style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: crm.textPrimary),
                    ),
                  ),
                  if (okrs.isNotEmpty) ...[const SizedBox(width: 8), _pill('$avgProgress% average', crm.primary)],
                ],
              ),
              if (canManage)
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: crm.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    minimumSize: const Size(0, 34),
                  ),
                  onPressed: () => openOkr(),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add objective'),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (okrs.isEmpty)
            _emptyHint(crm, 'No objectives defined yet.')
          else
            for (final k in keys) ...[
              Padding(
                padding: const EdgeInsets.only(top: 6, bottom: 4),
                child: Text(
                  k,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: crm.textSecondary, letterSpacing: 0.3),
                ),
              ),
              for (final o in groups[k]!) _okrRow(crm, o, canManage ? () => openOkr(existing: o) : null),
            ],
        ],
      ),
    );
  }

  Widget _okrRow(CrmTheme crm, OKRModel o, VoidCallback? onTap) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(10),
    child: Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: crm.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: crm.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  o.objective,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 8),
              _pill(o.status.label, o.status.color),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: o.progress / 100,
                    minHeight: 7,
                    backgroundColor: crm.border,
                    valueColor: AlwaysStoppedAnimation(o.status.color),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${o.progress}%',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: crm.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _pill(o.priority.label, o.priority.color),
              const SizedBox(width: 6),
              Icon(Icons.checklist_rtl, size: 13, color: crm.textSecondary),
              const SizedBox(width: 3),
              Text('${o.keyResults.length} KR${o.keyResults.length == 1 ? '' : 's'}', style: TextStyle(fontSize: 11, color: crm.textSecondary)),
              if (o.projectHeadName.isNotEmpty) ...[
                const Spacer(),
                Icon(Icons.person_outline, size: 13, color: crm.textSecondary),
                const SizedBox(width: 3),
                Flexible(
                  child: Text(
                    o.projectHeadName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: crm.textSecondary),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    ),
  );

  Widget _pill(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(7)),
    child: Text(
      label,
      style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.w700),
    ),
  );

  Widget _emptyHint(CrmTheme crm, String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 14),
    child: Center(
      child: Text(text, style: TextStyle(fontSize: 12.5, color: crm.textSecondary)),
    ),
  );

  static String _titleCase(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).replaceAll('-', ' ');
}
