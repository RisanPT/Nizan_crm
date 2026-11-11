import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/models/employee.dart';
import 'package:nizan_crm/core/widgets/employee_picker.dart';
import 'package:nizan_crm/core/auth/access_control.dart';
import 'package:nizan_crm/core/providers/auth_provider.dart';
import 'package:nizan_crm/core/providers/my_department_provider.dart';
import 'package:nizan_crm/features/it/services/strategic_vision_service.dart';
import 'package:nizan_crm/features/org/data/department.dart';
import 'package:nizan_crm/features/org/services/department_service.dart';
import 'package:nizan_crm/features/it/data/project.dart';
import 'package:nizan_crm/features/it/domain/project_tier.dart';
import 'package:nizan_crm/features/it/services/it_service.dart';
import 'package:nizan_crm/core/state/data_refresh.dart';
import 'package:nizan_crm/features/it/presentation/controllers/it_tasks_notifier.dart';
import 'package:nizan_crm/features/it/presentation/screens/it_projects_screen.dart' show projectStatusColor, priorityColor;
import 'package:nizan_crm/features/it/presentation/screens/widgets/company_planning_dashboard.dart';
import 'package:nizan_crm/features/it/presentation/screens/widgets/it_okr_view.dart';
import 'package:nizan_crm/features/it/presentation/screens/widgets/monthly_objectives_view.dart';
import 'package:nizan_crm/features/it/presentation/screens/widgets/project_cost_widgets.dart';
import 'package:nizan_crm/features/it/presentation/screens/widgets/project_departments.dart';
import 'package:nizan_crm/features/it/presentation/screens/widgets/strategic_roadmap_view.dart';

String _titleCase(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).replaceAll('-', ' ');

const _statusFilters = ['all', 'proposed', 'planning', 'active', 'on-hold', 'completed', 'cancelled'];

final _dayFmt = DateFormat('d MMM');
final _dayYearFmt = DateFormat('d MMM yyyy');
final _isoDay = DateFormat('yyyy-MM-dd');

/// One choice in a filter menu.
class _FilterOption {
  final String value;
  final String label;
  final Color? color;
  const _FilterOption(this.value, this.label, {this.color});
}

/// What colour a tier wears on its chip and its section header.
Color _tierColor(ProjectTier t, CrmTheme crm) => switch (t) {
      ProjectTier.mini => const Color(0xFF0D9488),
      ProjectTier.moderate => const Color(0xFFEA580C),
      ProjectTier.main => crm.primary,
      ProjectTier.unscheduled => crm.warning,
    };

/// "3 Nov → 17 Nov 2026", or "3 Nov 2026 → 31 Dec 2030" across years.
String _rangeText(DateTime s, DateTime e) =>
    s.year == e.year ? '${_dayFmt.format(s)} → ${_dayYearFmt.format(e)}' : '${_dayYearFmt.format(s)} → ${_dayYearFmt.format(e)}';

/// Company-wide, department-scoped project portfolio (outside IT). Reuses the
/// same Project system and detail screen; the server scopes what each user sees.
class CompanyProjectsScreen extends ConsumerStatefulWidget {
  const CompanyProjectsScreen({super.key, this.initialMode});

  /// Opens straight into a mode ('monthly' …) — from a notification's link.
  final String? initialMode;

  @override
  ConsumerState<CompanyProjectsScreen> createState() => _CompanyProjectsScreenState();
}

class _CompanyProjectsScreenState extends ConsumerState<CompanyProjectsScreen> {
  String _dept = 'all'; // department filter
  String _status = 'all';
  String _query = '';
  late String? _mode = widget.initialMode; // 'dashboard' (leadership only) | 'portfolio' | 'objectives' | 'monthly' | 'strategy'; null → default
  final _pills = ScrollController();
  String? _tierTab; // portfolio: 'mini' | 'long' (Moderate & Main); null → the one that has projects
  bool _isGridView = true; // toggle between Grid and Table view
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // on a phone the switcher scrolls: a link into the last pill must show it
    if (widget.initialMode == 'monthly') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_pills.hasClients) _pills.jumpTo(_pills.position.maxScrollExtent);
      });
    }
  }

  @override
  void dispose() {
    _pills.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final access = Access.of(ref.watch(authSessionProvider));
    final isLeadership =
        access.isFullAccess || access.isDepartmentHead || access.canManageAllPlanning;
    const canCreate = true;
    final mode = _mode == 'strategy'
        ? 'strategy'
        : _mode == 'objectives'
            ? 'objectives'
            : _mode == 'monthly'
                ? 'monthly'
                : (isLeadership ? (_mode ?? 'dashboard') : 'portfolio');
    final depts = (ref.watch(departmentsProvider).value ?? const <Department>[])
        .where((d) => d.active)
        .toList();

    return Scaffold(
      backgroundColor: crm.background,
      floatingActionButton: (mode == 'portfolio' && canCreate)
          ? FloatingActionButton.extended(
              onPressed: () => _editProject(context, access, depts),
              backgroundColor: crm.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: Text(isLeadership ? 'New Project' : 'Propose Project'),
            )
          : null,
      body: Column(children: [
        // Top Executive Header
        Container(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
          decoration: BoxDecoration(
            color: crm.surface,
            border: Border(bottom: BorderSide(color: crm.border)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [crm.primary.withValues(alpha: 0.16), crm.primary.withValues(alpha: 0.06)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: crm.primary.withValues(alpha: 0.22)),
                ),
                child: Icon(Icons.hub_rounded, color: crm.primary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          'Company Projects',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: crm.primary, letterSpacing: -0.3),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: crm.primary.withValues(alpha: 0.09),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'ENTERPRISE',
                          style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: crm.primary, letterSpacing: 0.5),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 1),
                  Text(
                    'Cross-department execution & multi-year roadmap',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: crm.textSecondary, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              ),
              const SizedBox(width: 8),
              if (canCreate && MediaQuery.sizeOf(context).width < 640)
                IconButton.filled(
                  onPressed: () => _editProject(context, access, depts),
                  tooltip: isLeadership ? 'New Project' : 'Propose Project',
                  style: IconButton.styleFrom(backgroundColor: crm.primary, foregroundColor: Colors.white),
                  icon: const Icon(Icons.add, size: 20),
                )
              else if (canCreate)
                FilledButton.icon(
                  onPressed: () => _editProject(context, access, depts),
                  style: FilledButton.styleFrom(
                    backgroundColor: crm.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(
                    isLeadership ? 'New Project' : 'Propose Project',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                onPressed: () => ref.invalidate(companyProjectsProvider),
                tooltip: 'Refresh portfolio',
                icon: const Icon(Icons.refresh_rounded, size: 18),
                style: IconButton.styleFrom(
                  backgroundColor: crm.background,
                  foregroundColor: crm.textPrimary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),

        // Navigation Tabs Strip
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: crm.surface,
            border: Border(bottom: BorderSide(color: crm.border)),
          ),
          child: SingleChildScrollView(
            controller: _pills,
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                if (isLeadership)
                  _navPill(
                    label: 'Dashboard',
                    icon: Icons.dashboard_outlined,
                    selected: mode == 'dashboard',
                    onTap: () => setState(() => _mode = 'dashboard'),
                    crm: crm,
                  ),
                if (isLeadership) const SizedBox(width: 6),
                _navPill(
                  label: 'Portfolio',
                  icon: Icons.grid_view_outlined,
                  selected: mode == 'portfolio',
                  onTap: () => setState(() => _mode = 'portfolio'),
                  crm: crm,
                ),
                const SizedBox(width: 6),
                _navPill(
                  label: 'Objectives & OKRs',
                  icon: Icons.track_changes_outlined,
                  selected: mode == 'objectives',
                  onTap: () => setState(() => _mode = 'objectives'),
                  crm: crm,
                ),
                const SizedBox(width: 6),
                _navPill(
                  key: const Key('mode_monthly'),
                  label: 'Monthly',
                  icon: Icons.event_available_outlined,
                  selected: mode == 'monthly',
                  onTap: () => setState(() => _mode = 'monthly'),
                  crm: crm,
                ),
                const SizedBox(width: 6),
                _navPill(
                  label: 'Strategic Roadmap',
                  icon: Icons.auto_graph_outlined,
                  selected: mode == 'strategy',
                  onTap: () => setState(() => _mode = 'strategy'),
                  crm: crm,
                ),
              ],
            ),
          ),
        ),

        // Body Content
        Expanded(
          child: mode == 'strategy'
              ? const StrategicRoadmapView()
              : mode == 'monthly'
                  ? const MonthlyObjectivesView()
                  : mode == 'objectives'
                  ? ITOkrView(projectId: null, projectName: 'the company', planningDepartments: [for (final d in depts) d.name])
                  : mode == 'dashboard'
                  ? CompanyPlanningDashboard(onOpenPortfolio: () => setState(() => _mode = 'portfolio'))
                  : _portfolio(context, crm, access, depts),
        ),
      ]),
    );
  }

  Widget _navPill({
    Key? key,
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
    required CrmTheme crm,
  }) {
    return InkWell(
      key: key,
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? crm.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: selected ? Colors.white : crm.textSecondary,
            ),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                color: selected ? Colors.white : crm.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _portfolio(BuildContext context, CrmTheme crm, Access access, List<Department> depts) {
    final async = ref.watch(companyProjectsProvider(_dept == 'all' ? null : _dept));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => AppErrorView(error: e, onRetry: () => ref.invalidate(companyProjectsProvider)),
      data: (projects) {
        final filtered = projects.where((p) {
          if (_status != 'all' && p.status != _status) return false;
          if (_query.isEmpty) return true;
          final q = _query.toLowerCase();
          return p.name.toLowerCase().contains(q) ||
              p.description.toLowerCase().contains(q) ||
              p.managerName.toLowerCase().contains(q) ||
              p.departments.any((d) => d.name.toLowerCase().contains(q)) ||
              p.targetDepartment.toLowerCase().contains(q);
        }).toList();

        final needsMe = projects
            .where((p) => p.access.pendingInvitations.isNotEmpty || (p.isProposed && p.access.canDecide))
            .toList();

        // What KIND of project each one is — from how long it runs (utils: project_tier.dart).
        final byTier = <ProjectTier, List<Project>>{for (final t in ProjectTier.values) t: <Project>[]};
        for (final p in filtered) {
          byTier[projectTierOf(p)]!.add(p);
        }
        for (final list in byTier.values) {
          list.sort(compareForList);
        }
        final mini = byTier[ProjectTier.mini]!;
        final longCount = filtered.length - mini.length; // moderate + main + not yet dated
        // First look: the tab that has projects (judged on ALL of them, so typing in the search box never flips the tab).
        final allMini = projects.where((p) => projectTierOf(p) == ProjectTier.mini).length;
        final tab = _tierTab ?? ((projects.length - allMini > 0 || allMini == 0) ? 'long' : 'mini');
        final hasFilter = _dept != 'all' || _status != 'all' || _query.isNotEmpty;

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(companyProjectsProvider),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 100),
            children: [
              if (needsMe.isNotEmpty) ...[
                _needsAnswer(crm, needsMe),
                const SizedBox(height: 16),
              ],

              // Metric Banner
              _summary(crm, projects),
              const SizedBox(height: 16),

              // Which kind of project: Mini  |  Moderate & Main
              _tierTabs(crm, tab, mini.length, longCount),
              const SizedBox(height: 12),

              // Filter & Search Hub (shared by both tabs)
              _controls(crm, depts, projects.length, filtered.length),
              const SizedBox(height: 16),

              // Projects Content
              if (filtered.isEmpty)
                _emptyState(
                  crm,
                  icon: Icons.folder_open_outlined,
                  title: projects.isEmpty ? 'No projects visible to you yet.' : 'No projects match your active filters.',
                  message: projects.isEmpty
                      ? 'Click "+ New Project" or "+ Propose Project" to initiate work.'
                      : 'Try adjusting your search query, department, or status filters.',
                  resetFilters: projects.isNotEmpty,
                )
              else if (tab == 'mini') ...[
                if (mini.isEmpty)
                  _emptyState(
                    crm,
                    icon: Icons.bolt_rounded,
                    title: hasFilter ? 'No mini projects match your filters.' : 'No mini projects yet.',
                    message: hasFilter
                        ? '$longCount ${longCount == 1 ? 'project is' : 'projects are'} in Moderate & Main.'
                        : 'Short pieces of work, from 7 days to 1 month, live here.',
                    switchTo: hasFilter ? ('long', 'Show Moderate & Main') : null,
                    createLabel: hasFilter ? null : 'New mini project',
                    createPreset: '2 weeks',
                    access: access,
                    depts: depts,
                  )
                else ...[
                  _sectionHeader(crm, ProjectTier.mini, mini.length, caption: 'Soonest end date first'),
                  _projectsBlock(context, crm, access, mini, depts),
                ],
              ] else ...[
                if (longCount == 0)
                  _emptyState(
                    crm,
                    icon: Icons.layers_rounded,
                    title: hasFilter ? 'No moderate or main projects match your filters.' : 'No moderate or main projects yet.',
                    message: hasFilter
                        ? '${mini.length} mini ${mini.length == 1 ? 'project is' : 'projects are'} in the Mini tab.'
                        : 'Projects that run 1 month or longer live here.',
                    switchTo: hasFilter ? ('mini', 'Show Mini projects') : null,
                    createLabel: hasFilter ? null : 'New project',
                    access: access,
                    depts: depts,
                  )
                else
                  for (final t in const [ProjectTier.main, ProjectTier.moderate, ProjectTier.unscheduled])
                    if (byTier[t]!.isNotEmpty) ...[
                      _sectionHeader(crm, t, byTier[t]!.length),
                      _projectsBlock(context, crm, access, byTier[t]!, depts),
                      const SizedBox(height: 22),
                    ],
              ],
            ],
          ),
        );
      },
    );
  }

  // ── Mini  |  Moderate & Main ───────────────────────────────────────────────────────────────

  Widget _tierTabs(CrmTheme crm, String tab, int miniCount, int longCount) {
    void pick(String t) => setState(() => _tierTab = t);
    // On a phone each card is only ~170 px wide: the icon goes, so the name and the range stay readable.
    final compact = MediaQuery.sizeOf(context).width < 640;
    // (IntrinsicHeight: the two cards stretch to the taller one, which a Row cannot do in a scrolling list on its own)
    return IntrinsicHeight(
      child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: _tierTabCard(
            crm: crm,
            tabKey: const Key('tier_tab_mini'),
            icon: Icons.bolt_rounded,
            compact: compact,
            title: 'Mini projects',
            subtitle: ProjectTier.mini.range,
            count: miniCount,
            selected: tab == 'mini',
            onTap: () => pick('mini'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _tierTabCard(
            crm: crm,
            tabKey: const Key('tier_tab_long'),
            icon: Icons.layers_rounded,
            compact: compact,
            title: 'Moderate & Main',
            subtitle: '1 month and above',
            count: longCount,
            selected: tab == 'long',
            onTap: () => pick('long'),
          ),
        ),
      ],
      ),
    );
  }

  Widget _tierTabCard({
    required CrmTheme crm,
    required Key tabKey,
    required bool compact,
    required IconData icon,
    required String title,
    required String subtitle,
    required int count,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Semantics(
      button: true,
      selected: selected,
      label: '$title, $count',
      child: Material(
        key: tabKey,
        color: selected ? crm.primary.withValues(alpha: 0.07) : crm.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: EdgeInsets.symmetric(horizontal: compact ? 11 : 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: selected ? crm.primary : crm.border, width: selected ? 1.6 : 1),
            ),
            child: Row(
              children: [
                if (!compact) ...[
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: selected ? crm.primary : crm.background,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, size: 19, color: selected ? Colors.white : crm.textSecondary),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: selected ? crm.primary : crm.textPrimary),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11.5, color: crm.textSecondary, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color: selected ? crm.primary : crm.background,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: selected ? Colors.white : crm.textSecondary),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// A tier's heading over its projects: colour dot, name, what it covers, how many.
  Widget _sectionHeader(CrmTheme crm, ProjectTier tier, int count, {String? caption}) {
    final color = _tierColor(tier, crm);
    return Padding(
      key: Key('tier_section_${tier.name}'),
      padding: const EdgeInsets.only(bottom: 10),
      // (a Wrap: on a phone the range drops under the name instead of running off the edge)
      child: Wrap(
        spacing: 8,
        runSpacing: 2,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          Text(tier.plural, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: crm.textPrimary)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1.5),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
            child: Text('$count', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: color)),
          ),
          Text(
            caption != null ? '${tier.range} · $caption' : tier.range,
            style: TextStyle(fontSize: 12, color: crm.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _tierChip(ProjectTier tier, CrmTheme crm) {
    final color = _tierColor(tier, crm);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(tier.label, style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.w800)),
    );
  }

  /// The projects of a section as the chosen view: cards, or a table.
  Widget _projectsBlock(BuildContext context, CrmTheme crm, Access access, List<Project> list, List<Department> depts) {
    if (!_isGridView) return _listView(context, crm, access, list, depts);
    return LayoutBuilder(builder: (ctx, c) {
      final cols = (c.maxWidth / 390).floor().clamp(1, 3);
      const gap = 16.0;
      final cardW = cols == 1 ? c.maxWidth : (c.maxWidth - (cols - 1) * gap) / cols;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final p in list) SizedBox(width: cardW, child: _card(context, crm, access, p, depts)),
        ],
      );
    });
  }

  Widget _emptyState(
    CrmTheme crm, {
    required IconData icon,
    required String title,
    required String message,
    bool resetFilters = false,
    (String, String)? switchTo,
    String? createLabel,
    String? createPreset,
    Access? access,
    List<Department>? depts,
  }) {
    return Container(
      key: const Key('portfolio_empty'),
      padding: const EdgeInsets.symmetric(vertical: 60),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: crm.textSecondary.withValues(alpha: 0.5)),
          const SizedBox(height: 12),
          Text(title, textAlign: TextAlign.center, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: crm.textPrimary)),
          const SizedBox(height: 6),
          Text(message, textAlign: TextAlign.center, style: TextStyle(fontSize: 12.5, color: crm.textSecondary)),
          if (resetFilters) ...[
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _dept = 'all';
                  _status = 'all';
                  _query = '';
                  _searchController.clear();
                });
              },
              icon: const Icon(Icons.clear_all, size: 16),
              label: const Text('Reset all filters'),
            ),
          ],
          if (switchTo != null) ...[
            const SizedBox(height: 14),
            OutlinedButton(
              key: const Key('empty_switch_tab'),
              onPressed: () => setState(() => _tierTab = switchTo.$1),
              child: Text(switchTo.$2),
            ),
          ],
          if (createLabel != null && access != null && depts != null) ...[
            const SizedBox(height: 14),
            FilledButton.icon(
              key: const Key('empty_create'),
              onPressed: () => _editProject(context, access, depts, preset: createPreset),
              style: FilledButton.styleFrom(backgroundColor: crm.primary, foregroundColor: Colors.white),
              icon: const Icon(Icons.add, size: 18),
              label: Text(createLabel),
            ),
          ],
        ],
      ),
    );
  }

  Widget _needsAnswer(CrmTheme crm, List<Project> projects) => Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
        decoration: BoxDecoration(
          color: crm.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: crm.warning.withValues(alpha: 0.55), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: crm.warning.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: crm.warning.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.notifications_active_rounded, size: 16, color: crm.warning),
            ),
            const SizedBox(width: 10),
            Text('Action Required (${projects.length})', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: crm.textPrimary)),
            const Spacer(),
            Text('Needs your approval or invitation decision', style: TextStyle(fontSize: 11.5, color: crm.textSecondary)),
          ]),
          const SizedBox(height: 12),
          for (final p in projects) ...[
            Text(p.name, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: crm.textPrimary)),
            const SizedBox(height: 6),
            ProjectDecisionBanner(project: p, compact: true),
            const SizedBox(height: 6),
          ],
        ]),
      );

  Widget _summary(CrmTheme crm, List<Project> all) {
    final total = all.length;
    final active = all.where((p) => p.status == 'active').length;
    final deptsCount = {
      for (final p in all)
        for (final d in p.departmentNames) d.toLowerCase(),
    }.length;
    final withTasks = all.where((p) => p.totalTasks > 0).toList();
    final avg = withTasks.isEmpty ? 0 : (withTasks.map((p) => p.progress).reduce((a, b) => a + b) / withTasks.length).round();

    final cards = <Widget>[

        _statCard(
          crm: crm,
          value: '$total',
          label: 'Total Projects',
          subtext: '$active active currently',
          icon: Icons.hub_rounded,
          color: crm.primary,
        ),
        _statCard(
          crm: crm,
          value: '$active',
          label: 'Active Initiatives',
          subtext: total == 0 ? '0%' : '${((active / total) * 100).round()}% active rate',
          icon: Icons.play_circle_fill_rounded,
          color: const Color(0xFF10B981),
        ),
        _statCard(
          crm: crm,
          value: '$deptsCount',
          label: 'Departments',
          subtext: 'Collaborating together',
          icon: Icons.corporate_fare_rounded,
          color: const Color(0xFF3B82F6),
        ),
        _statCard(
          crm: crm,
          value: '$avg%',
          label: 'Avg Attainment',
          subtext: 'Task completion',
          icon: Icons.trending_up_rounded,
          color: const Color(0xFF8B5CF6),
        ),
    ];
    return LayoutBuilder(builder: (context, c) {
      if (c.maxWidth >= 640) {
        return Row(children: [
          for (var i = 0; i < cards.length; i++) ...[
            if (i > 0) const SizedBox(width: 12),
            cards[i],
          ],
        ]);
      }
      // a phone: two by two
      return Column(children: [
        Row(children: [cards[0], const SizedBox(width: 10), cards[1]]),
        const SizedBox(height: 10),
        Row(children: [cards[2], const SizedBox(width: 10), cards[3]]),
      ]);
    });
  }

  Widget _statCard({
    required CrmTheme crm,
    required String value,
    required String label,
    required String subtext,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: crm.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: crm.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: crm.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: crm.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    subtext,
                    style: TextStyle(
                      fontSize: 10.5,
                      color: color,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Search, two compact filters (Department, Status) and the grid / table switch — one line on a desktop,
  /// two on a phone. The filters are menus, not a wall of chips: the button says what is chosen.
  Widget _controls(CrmTheme crm, List<Department> depts, int totalCount, int filteredCount) {
    final hasActiveFilter = _dept != 'all' || _status != 'all' || _query.isNotEmpty;
    final narrow = MediaQuery.sizeOf(context).width < 640;

    final search = TextField(
      controller: _searchController,
      onChanged: (v) => setState(() => _query = v.trim()),
      style: TextStyle(fontSize: 13.5, color: crm.textPrimary),
      decoration: InputDecoration(
        isDense: true,
        hintText: narrow ? 'Search projects…' : 'Search projects by name, manager, department…',
        hintStyle: TextStyle(fontSize: 13, color: crm.textSecondary.withValues(alpha: 0.7)),
        prefixIcon: const Icon(Icons.search_rounded, size: 19),
        suffixIcon: _query.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.close, size: 16),
                onPressed: () {
                  _searchController.clear();
                  setState(() => _query = '');
                },
              )
            : null,
        filled: true,
        fillColor: crm.background,
        contentPadding: const EdgeInsets.symmetric(vertical: 9, horizontal: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: crm.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: crm.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: crm.primary, width: 1.5)),
      ),
    );

    // View mode switcher: Grid vs List
    final viewToggle = Container(
      decoration: BoxDecoration(
        color: crm.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: crm.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Card Grid View',
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.grid_view_rounded, size: 18, color: _isGridView ? crm.primary : crm.textSecondary),
            onPressed: () => setState(() => _isGridView = true),
          ),
          IconButton(
            tooltip: 'Table List View',
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.table_rows_rounded, size: 18, color: !_isGridView ? crm.primary : crm.textSecondary),
            onPressed: () => setState(() => _isGridView = false),
          ),
        ],
      ),
    );

    final deptMenu = _filterMenu(
      crm: crm,
      menuKey: const Key('filter_dept'),
      icon: Icons.business_outlined,
      title: 'Department',
      chosen: _dept == 'all' ? null : _dept,
      expand: narrow,
      options: [
        const _FilterOption('all', 'All departments'),
        for (final d in depts) _FilterOption(d.name, d.name),
      ],
      isSelected: (v) => v == 'all' ? _dept == 'all' : _dept.toLowerCase() == v.toLowerCase(),
      onSelected: (v) => setState(() => _dept = v),
    );
    final statusMenu = _filterMenu(
      crm: crm,
      menuKey: const Key('filter_status'),
      icon: Icons.flag_outlined,
      title: 'Status',
      chosen: _status == 'all' ? null : _titleCase(_status),
      chosenColor: _status == 'all' ? null : projectStatusColor(_status),
      expand: narrow,
      options: [
        for (final st in _statusFilters)
          _FilterOption(st, st == 'all' ? 'Any status' : _titleCase(st), color: st == 'all' ? null : projectStatusColor(st)),
      ],
      isSelected: (v) => v == _status,
      onSelected: (v) => setState(() => _status = v),
    );

    final reset = hasActiveFilter
        ? TextButton.icon(
            key: const Key('filter_reset'),
            onPressed: () {
              setState(() {
                _dept = 'all';
                _status = 'all';
                _query = '';
                _searchController.clear();
              });
            },
            icon: const Icon(Icons.clear, size: 14),
            label: const Text('Reset', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            style: TextButton.styleFrom(foregroundColor: crm.primary, visualDensity: VisualDensity.compact),
          )
        : null;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: crm.border),
      ),
      child: narrow
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [Expanded(child: search), const SizedBox(width: 10), viewToggle]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: deptMenu),
                  const SizedBox(width: 8),
                  Expanded(child: statusMenu),
                ]),
                if (hasActiveFilter)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(children: [
                      Text('$filteredCount of $totalCount projects', key: const Key('filter_count'), style: TextStyle(fontSize: 12, color: crm.textSecondary)),
                      const Spacer(),
                      ?reset,
                    ]),
                  ),
              ],
            )
          : Row(
              children: [
                Expanded(child: search),
                const SizedBox(width: 10),
                deptMenu,
                const SizedBox(width: 8),
                statusMenu,
                if (hasActiveFilter) ...[
                  const SizedBox(width: 6),
                  Text('$filteredCount of $totalCount', key: const Key('filter_count'), style: TextStyle(fontSize: 12, color: crm.textSecondary)),
                  ?reset,
                ],
                const SizedBox(width: 10),
                viewToggle,
              ],
            ),
    );
  }

  /// A filter as one button that opens a menu: "Department ▾", or the choice ("Marketing ▾") once one is made.
  Widget _filterMenu({
    required CrmTheme crm,
    required Key menuKey,
    required IconData icon,
    required String title,
    required String? chosen,
    Color? chosenColor,
    required bool expand,
    required List<_FilterOption> options,
    required bool Function(String value) isSelected,
    required ValueChanged<String> onSelected,
  }) {
    final active = chosen != null;
    final accent = chosenColor ?? crm.primary;
    return PopupMenuButton<String>(
      key: menuKey,
      tooltip: title,
      position: PopupMenuPosition.under,
      offset: const Offset(0, 6),
      constraints: const BoxConstraints(minWidth: 200, maxWidth: 280),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: onSelected,
      itemBuilder: (_) => [
        for (final o in options)
          PopupMenuItem<String>(
            value: o.value,
            height: 38,
            child: Row(children: [
              SizedBox(width: 20, child: isSelected(o.value) ? Icon(Icons.check_rounded, size: 17, color: crm.primary) : null),
              if (o.color != null) ...[
                Container(width: 8, height: 8, decoration: BoxDecoration(color: o.color, shape: BoxShape.circle)),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  o.label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13.5, fontWeight: isSelected(o.value) ? FontWeight.w800 : FontWeight.w500),
                ),
              ),
            ]),
          ),
      ],
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: active ? accent.withValues(alpha: 0.10) : crm.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: active ? accent : crm.border, width: active ? 1.4 : 1),
        ),
        child: Row(
          mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: active ? accent : crm.textSecondary),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                chosen ?? title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, fontWeight: active ? FontWeight.w800 : FontWeight.w600, color: active ? accent : crm.textSecondary),
              ),
            ),
            const SizedBox(width: 2),
            Icon(Icons.arrow_drop_down_rounded, size: 22, color: active ? accent : crm.textSecondary),
          ],
        ),
      ),
    );
  }

  Widget _card(BuildContext context, CrmTheme crm, Access access, Project p, List<Department> depts) {
    final pct = p.progress / 100;
    final canManage = p.access.canManage;
    final timeline = timelineOf(p);

    // Horizon Color & Label
    final horizonColor = p.horizonNumber == 2
        ? const Color(0xFF7C3AED)
        : (p.horizonNumber == 3 ? const Color(0xFFE11D48) : const Color(0xFF2563EB));
    final horizonLabel = 'H${p.horizonNumber} · ${p.horizonNumber == 1 ? '2026-28' : (p.horizonNumber == 2 ? '2029-33' : '2034-41')}';

    return Material(
      color: crm.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.go('/projects/${p.id}'),
        hoverColor: crm.primary.withValues(alpha: 0.03),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: crm.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.025),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Badges Row: Kind (tier) + Horizon + Status + Priority + More
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 5,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _tierChip(timeline.tier, crm),
                        // A strategic wave means little for a short piece of work.
                        if (timeline.tier != ProjectTier.mini)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: horizonColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: horizonColor.withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              horizonLabel,
                              style: TextStyle(color: horizonColor, fontSize: 10.5, fontWeight: FontWeight.w800),
                            ),
                          ),
                        _statusDotPill(p.status, crm),
                        _priorityPill(p.priority, crm),
                      ],
                    ),
                  ),
                  if (canManage)
                    PopupMenuButton<String>(
                      padding: EdgeInsets.zero,
                      iconSize: 18,
                      tooltip: 'Project actions',
                      onSelected: (v) {
                        if (v == 'open') context.go('/projects/${p.id}');
                        if (v == 'edit') _editProject(context, access, depts, existing: p);
                        if (v == 'delete') _deleteProject(context, p);
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'open', child: Row(children: [Icon(Icons.open_in_new, size: 16), SizedBox(width: 8), Text('Open Project')])),
                        PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_outlined, size: 16), SizedBox(width: 8), Text('Edit Settings')])),
                        PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline, size: 16, color: Colors.red), SizedBox(width: 8), Text('Delete Project', style: TextStyle(color: Colors.red))])),
                      ],
                    )
                  else
                    Icon(Icons.arrow_forward_ios_rounded, size: 13, color: crm.textSecondary.withValues(alpha: 0.5)),
                ],
              ),
              const SizedBox(height: 12),

              // Title
              Text(
                p.name,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: crm.textPrimary, letterSpacing: -0.2),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),

              // Departments
              ProjectDepartmentChips(project: p),

              if (p.isProposed && !p.access.canDecide)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: crm.warning.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                    child: Row(children: [
                      Icon(Icons.hourglass_top, size: 13, color: crm.warning),
                      const SizedBox(width: 5),
                      Expanded(child: Text('Pending head approval for ${p.targetDepartment}', style: TextStyle(fontSize: 11, color: crm.warning, fontWeight: FontWeight.w600))),
                    ]),
                  ),
                ),

              // where the estimated cost stands: nothing starts before the finance head approves it (a proposal waits for its head first)
              if (!p.isProposed && (p.costWaiting || p.costReturned))
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Align(alignment: Alignment.centerLeft, child: CostStatusPill(p.costStatus, key: Key('card_cost_${p.id}'))),
                ),

              if (p.isRejected)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('Proposal declined: ${p.decisionNote}', style: TextStyle(fontSize: 11.5, color: crm.destructive, fontWeight: FontWeight.w600)),
                ),

              if (p.description.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    p.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12.5, color: crm.textSecondary, height: 1.35),
                  ),
                ),

              const SizedBox(height: 12),

              // When it runs: dates, how long, how long is left (or: no end date yet)
              _timelineRow(crm, p, timeline, canManage: canManage, access: access, depts: depts),

              const SizedBox(height: 12),

              // Progress Bar + Attainment Metric
              Row(children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: pct,
                      minHeight: 7,
                      backgroundColor: crm.background,
                      valueColor: AlwaysStoppedAnimation(
                        pct >= 1
                            ? const Color(0xFF10B981)
                            : (pct > 0.4 ? crm.primary : const Color(0xFFF59E0B)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${(pct * 100).round()}%',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: crm.textPrimary),
                ),
              ]),

              // Multi-department progress strip if cross-dept
              if (p.departmentProgress.length > 1)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: DepartmentProgressStrip(project: p, maxRows: 3),
                ),

              const SizedBox(height: 12),
              Divider(height: 1, color: crm.border.withValues(alpha: 0.6)),
              const SizedBox(height: 10),

              // Footer: Manager Avatar & Target Info
              Row(
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: crm.primary.withValues(alpha: 0.12),
                    child: Text(
                      _avatarInitials(p.managerName),
                      style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: crm.primary),
                    ),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      p.managerName.isEmpty ? 'Unassigned' : p.managerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: crm.textPrimary),
                    ),
                  ),
                  if (p.targetYear != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: crm.background,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: crm.border),
                      ),
                      child: Text(
                        '🎯 ${p.targetYear}',
                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: crm.textSecondary),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: crm.background,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${p.completedTasks}/${p.totalTasks} tasks',
                      style: TextStyle(fontSize: 11, color: crm.textSecondary, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The dates on a card: "3 Nov → 17 Nov 2026 · 15 days" and a badge for how long is left; a project with no end
  /// date says so and (for someone who can edit it) offers to set one.
  Widget _timelineRow(CrmTheme crm, Project p, ProjectTimeline t, {required bool canManage, required Access access, required List<Department> depts}) {
    if (!t.scheduled) {
      return Row(
        key: Key('timeline_none_${p.id}'),
        children: [
          Icon(Icons.event_busy_outlined, size: 14, color: crm.warning),
          const SizedBox(width: 6),
          Expanded(child: Text('No end date yet', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: crm.warning))),
          if (canManage)
            TextButton(
              key: Key('set_timeline_${p.id}'),
              onPressed: () => _editProject(context, access, depts, existing: p),
              style: TextButton.styleFrom(visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(horizontal: 8), minimumSize: const Size(0, 28)),
              child: const Text('Set timeline', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            ),
        ],
      );
    }
    final left = timeLeft(t.end, status: p.status, today: DateTime.now());
    final range = t.endFromTargetYear ? '${_dayYearFmt.format(t.start!)} → ${p.targetYear} target' : _rangeText(t.start!, t.end!);
    return Row(
      key: Key('timeline_${p.id}'),
      children: [
        Icon(Icons.calendar_today_outlined, size: 13, color: crm.textSecondary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            t.durationText.isEmpty ? range : '$range · ${t.durationText}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: crm.textSecondary),
          ),
        ),
        if (left != null) ...[
          const SizedBox(width: 8),
          _timeLeftChip(left, crm),
        ],
      ],
    );
  }

  Widget _timeLeftChip(TimeLeft left, CrmTheme crm) {
    final color = switch (left.kind) {
      TimeLeftKind.overdue => crm.destructive,
      TimeLeftKind.today || TimeLeftKind.soon => crm.warning,
      TimeLeftKind.done => crm.success,
      TimeLeftKind.normal => crm.textSecondary,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
      child: Text(left.label, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: color)),
    );
  }

  /// The TIMELINE cell of the table: dates and length, with the time left under it.
  Widget _tableTimeline(CrmTheme crm, Project p) {
    final t = timelineOf(p);
    if (!t.scheduled) return Text('No end date', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: crm.warning));
    final left = timeLeft(t.end, status: p.status, today: DateTime.now());
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t.endFromTargetYear ? '${_dayYearFmt.format(t.start!)} → ${p.targetYear}' : _rangeText(t.start!, t.end!),
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        if (left != null) Text(left.label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: left.kind == TimeLeftKind.overdue ? crm.destructive : crm.textSecondary)),
      ],
    );
  }

  // Modern Table / List View
  Widget _listView(BuildContext context, CrmTheme crm, Access access, List<Project> list, List<Department> depts) {
    return Container(
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: crm.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 800),
            child: DataTable(
              headingRowColor: WidgetStatePropertyAll(crm.background),
              dataRowMaxHeight: 56,
              horizontalMargin: 16,
              columnSpacing: 20,
              columns: const [
                DataColumn(label: Text('PROJECT NAME', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800))),
                DataColumn(label: Text('KIND', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800))),
                DataColumn(label: Text('TIMELINE', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800))),
                DataColumn(label: Text('HORIZON', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800))),
                DataColumn(label: Text('DEPARTMENT', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800))),
                DataColumn(label: Text('MANAGER', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800))),
                DataColumn(label: Text('STATUS', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800))),
                DataColumn(label: Text('PRIORITY', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800))),
                DataColumn(label: Text('PROGRESS', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800))),
                DataColumn(label: Text('ACTIONS', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800))),
              ],
              rows: [
                for (final p in list)
                  DataRow(
                    onSelectChanged: (_) => context.go('/projects/${p.id}'),
                    cells: [
                      DataCell(
                        Row(children: [
                          Icon(Icons.folder_outlined, size: 16, color: crm.primary),
                          const SizedBox(width: 8),
                          Text(p.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                        ]),
                      ),
                      DataCell(_tierChip(timelineOf(p).tier, crm)),
                      DataCell(_tableTimeline(crm, p)),
                      DataCell(
                        // (a mini project has no strategic wave: its card does not show one either)
                        timelineOf(p).tier == ProjectTier.mini
                            ? Text('—', style: TextStyle(color: crm.textSecondary))
                            : Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: (p.horizonNumber == 2 ? const Color(0xFF7C3AED) : (p.horizonNumber == 3 ? const Color(0xFFE11D48) : const Color(0xFF2563EB))).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text('H${p.horizonNumber}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: p.horizonNumber == 2 ? const Color(0xFF7C3AED) : (p.horizonNumber == 3 ? const Color(0xFFE11D48) : const Color(0xFF2563EB)))),
                        ),
                      ),
                      DataCell(Text(p.targetDepartment.toUpperCase(), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: crm.textSecondary))),
                      DataCell(Text(p.managerName.isEmpty ? '—' : p.managerName, style: const TextStyle(fontSize: 12))),
                      DataCell(_statusDotPill(p.status, crm)),
                      DataCell(_priorityPill(p.priority, crm)),
                      DataCell(
                        SizedBox(
                          width: 110,
                          child: Row(children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: p.progress / 100,
                                  minHeight: 6,
                                  backgroundColor: crm.background,
                                  valueColor: AlwaysStoppedAnimation(crm.primary),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text('${p.progress}%', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                          ]),
                        ),
                      ),
                      DataCell(
                        IconButton(
                          icon: const Icon(Icons.chevron_right, size: 18),
                          onPressed: () => context.go('/projects/${p.id}'),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _statusDotPill(String status, CrmTheme crm) {
    final color = projectStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 5.5, height: 5.5, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 4),
          Text(_titleCase(status), style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget _priorityPill(String priority, CrmTheme crm) {
    final color = priorityColor(priority);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        _titleCase(priority),
        style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.w700),
      ),
    );
  }

  String _avatarInitials(String name) {
    final clean = name.trim();
    if (clean.isEmpty) return '—';
    final parts = clean.split(RegExp(r'\s+'));
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
  }

  Future<void> _deleteProject(BuildContext context, Project p) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Delete "${p.name}"?'),
        content: const Text('The project and all its tasks will be removed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, true), style: FilledButton.styleFrom(backgroundColor: Colors.red), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(projectServiceProvider).deleteProject(p.id);
      refreshAllItTaskViews(ref); // projects + their (now deleted) tasks
      ref.refreshData.okrs();
      messenger.showSnackBar(const SnackBar(content: Text('Project deleted')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
    }
  }

  Future<void> _editProject(BuildContext context, Access access, List<Department> depts, {Project? existing, String? preset}) async {
    final isEdit = existing != null;
    final myDept = ref.read(myDepartmentNameProvider);
    final deptNames = depts.map((d) => d.name).toList();
    final leadership = access.isFullAccess || access.canManageAllPlanning;
    // Someone who is neither a head nor a planning lead PROPOSES: the owning
    // department's head approves it, and the proposer manages it meanwhile.
    final proposing = !isEdit && !leadership && !access.isDepartmentHead;
    // Heads create only for their own department; moving a project away is an admin's call.
    final lockDept = isEdit ? !leadership : (access.isDepartmentHead && !leadership);
    final waitingForApproval = existing?.isProposed ?? false;

    final name = TextEditingController(text: existing?.name ?? '');
    final desc = TextEditingController(text: existing?.description ?? '');
    String? managerId = (existing?.managerId.isEmpty ?? true) ? null : existing!.managerId;
    final selectedMembers = <String>{...(existing?.memberIds ?? const [])};
    String department = existing?.targetDepartment.isNotEmpty == true
        ? existing!.targetDepartment
        : (lockDept && myDept.isNotEmpty ? myDept : (_dept != 'all' ? _dept : (deptNames.isNotEmpty ? deptNames.first : 'General')));
    // The other departments on the project (the owner is `department`).
    final selectedDepts = <String>{
      for (final d in existing?.departments ?? const <ProjectDepartment>[])
        if (!d.isOwner && !d.isDeclined) d.name,
    };
    final declined = {for (final d in existing?.departments ?? const <ProjectDepartment>[]) if (d.isDeclined) d.name};
    String editMode = existing?.editMode ?? 'managed';
    // A new project says what it is expected to cost (the finance head approves it); changing it later is done on the project's cost card.
    var costInput = const CostInput();
    var costMissing = false;
    String status = existing?.status ?? 'planning';
    String priority = existing?.priority ?? 'medium';
    String phase = existing?.phase ?? 'discovery';
    int horizonNumber = existing?.horizonNumber ?? 1;
    String strategicPillar = (existing?.strategicPillar.isNotEmpty ?? false) ? existing!.strategicPillar : 'expansion';
    final targetYearCtrl = TextEditingController(text: existing?.targetYear != null ? existing!.targetYear.toString() : '');
    // The timeline: how long the project runs decides whether it is a mini, moderate or main project.
    var startDate = dateOnly(existing?.startDate ?? DateTime.now());
    DateTime? endDate = existing?.endDate == null ? null : dateOnly(existing!.endDate!);
    if (endDate == null && existing == null && preset != null) {
      endDate = kDurationPresets.firstWhere((x) => x.label == preset).endFor(startDate);
    }
    final hadEndDate = existing?.endDate != null;
    final tierBefore = existing == null ? null : timelineOf(existing).tier;
    final messenger = ScaffoldMessenger.of(context);

    final saved = await showModalBottomSheet<Project>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        var busy = false;
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            final crm = ctx.crmColors;
            final employees = ref.read(departmentEmployeesProvider(department));
            // The team can come from every department on the project.
            final pool = <String, Employee>{
              for (final dn in [department, ...selectedDepts])
                for (final e in ref.read(departmentEmployeesProvider(dn))) e.id: e,
            }.values.toList()
              ..sort((a, b) => a.name.compareTo(b.name));

            final timeline = timelineFor(start: startDate, end: endDate);
            final badRange = endDate != null && endDate!.isBefore(startDate);
            // A mini project is not placed on the strategic roadmap, so its wave / pillar are not asked.
            final showStrategic = timeline.tier != ProjectTier.mini;

            Future<void> pickDate({required bool start}) async {
              final picked = await showDatePicker(
                context: ctx,
                initialDate: start ? startDate : (endDate ?? startDate),
                firstDate: DateTime(2020),
                lastDate: DateTime(2050),
              );
              if (picked == null) return;
              setSheet(() {
                final day = dateOnly(picked);
                if (start) {
                  // Moving the start slides the end with it, so the length (and the kind) stays.
                  final length = endDate?.difference(startDate).inDays;
                  startDate = day;
                  if (length != null) endDate = DateTime(day.year, day.month, day.day + length);
                } else {
                  endDate = day;
                }
              });
            }

            return Padding(
              padding: EdgeInsets.fromLTRB(20, 18, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
              child: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(isEdit ? 'Edit project' : (proposing ? 'Propose a project' : 'New project'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  if (proposing)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('You will manage it. The head of the owning department approves it before it starts.', style: TextStyle(fontSize: 12, color: crm.textSecondary)),
                    ),
                  const SizedBox(height: 14),
                  TextField(controller: name, decoration: const InputDecoration(labelText: 'Project name *')),
                  const SizedBox(height: 10),
                  TextField(controller: desc, maxLines: 2, decoration: const InputDecoration(labelText: 'Description')),
                  const SizedBox(height: 14),
                  _timelineBlock(
                    crm: crm,
                    start: startDate,
                    end: endDate,
                    endRequired: !isEdit || hadEndDate,
                    timeline: timeline,
                    badRange: badRange,
                    tierBefore: tierBefore,
                    onPickStart: () => pickDate(start: true),
                    onPickEnd: () => pickDate(start: false),
                    onPreset: (preset) => setSheet(() => endDate = preset.endFor(startDate)),
                  ),
                  const SizedBox(height: 14),
                  if (!isEdit)
                    ProjectCostFields(
                      showError: costMissing,
                      onChanged: (v) {
                        costInput = v;
                        if (costMissing && v.valid) setSheet(() => costMissing = false);
                      },
                    )
                  else if (existing.costStatus != 'none')
                    Container(
                      key: const Key('form_cost_note'),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: crm.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: crm.border)),
                      child: Row(children: [
                        Icon(Icons.payments_outlined, size: 16, color: crm.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            existing.cost == null
                                ? 'Cost: ${costStatusLook(existing.costStatus).label}. The project manager changes it from the project\'s cost card.'
                                : 'Cost ${rupees(existing.cost!.budget)} · ${costStatusLook(existing.costStatus).label}. Change it from the project\'s cost card.',
                            style: TextStyle(fontSize: 12, color: crm.textSecondary),
                          ),
                        ),
                      ]),
                    ),
                  const SizedBox(height: 14),
                  // Owning department
                  DropdownButtonFormField<String>(
                    initialValue: deptNames.contains(department) ? department : null,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Owning department *', helperText: 'Accountable for the project; its head approves proposals'),
                    items: [
                      if (!deptNames.contains(department)) DropdownMenuItem(value: department, child: Text(department)),
                      for (final d in deptNames) DropdownMenuItem(value: d, child: Text(d)),
                    ],
                    onChanged: lockDept
                        ? null
                        : (v) => setSheet(() {
                              department = v ?? department;
                              selectedDepts.removeWhere((d) => d.toLowerCase() == department.toLowerCase());
                              // reset people who are no longer on the project's departments
                              final ids = {
                                for (final dn in [department, ...selectedDepts]) ...ref.read(departmentEmployeesProvider(dn)).map((e) => e.id),
                              };
                              final ownerIds = ref.read(departmentEmployeesProvider(department)).map((e) => e.id).toSet();
                              if (managerId != null && !ownerIds.contains(managerId)) managerId = null;
                              selectedMembers.removeWhere((m) => !ids.contains(m));
                            }),
                  ),
                  if (lockDept)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(isEdit ? 'Only an administrator can move a project to another department.' : 'Department heads create projects for their own department.',
                          style: TextStyle(fontSize: 11.5, color: crm.textSecondary)),
                    ),
                  const SizedBox(height: 14),
                  // Other departments
                  Text('Also involves', style: TextStyle(fontSize: 12.5, color: crm.textSecondary, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Wrap(spacing: 6, runSpacing: 6, children: [
                    for (final d in deptNames.where((d) => d.toLowerCase() != department.toLowerCase()))
                      FilterChip(
                        label: Text(declined.contains(d) && !selectedDepts.contains(d) ? '$d (declined)' : d, style: const TextStyle(fontSize: 12)),
                        selected: selectedDepts.contains(d),
                        onSelected: (v) => setSheet(() => v ? selectedDepts.add(d) : selectedDepts.remove(d)),
                      ),
                  ]),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      selectedDepts.isEmpty
                          ? 'Just ${department.isEmpty ? 'one department' : department}. Pick more if other departments work on it too.'
                          : 'Their heads are asked to accept. Their people work on the project once they do.',
                      style: TextStyle(fontSize: 11.5, color: crm.textSecondary),
                    ),
                  ),
                  if (!proposing) ...[
                    const SizedBox(height: 14),
                    EmployeePickerField(
                      employees: employees,
                      selectedId: managerId,
                      selectedName: existing?.managerName,
                      label: 'Project Head / Manager *',
                      allowUnassign: false,
                      onChanged: (e) => setSheet(() => managerId = e?.id),
                    ),
                    if (employees.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text('No active staff found for "$department". Pick another department or tag staff to it.',
                            style: TextStyle(fontSize: 11.5, color: Colors.orange.shade800)),
                      ),
                  ],
                  const SizedBox(height: 12),
                  Text('Team members', style: TextStyle(fontSize: 12.5, color: crm.textSecondary, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Wrap(spacing: 6, runSpacing: 6, children: [
                    for (final e in pool)
                      FilterChip(
                        label: Text(e.name, style: const TextStyle(fontSize: 12)),
                        selected: selectedMembers.contains(e.id),
                        onSelected: (v) => setSheet(() => v ? selectedMembers.add(e.id) : selectedMembers.remove(e.id)),
                      ),
                  ]),
                  const SizedBox(height: 14),
                  Text('Who can change the plan', style: TextStyle(fontSize: 12.5, color: crm.textSecondary, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  SegmentedButton<String>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(value: 'managed', label: Text('Manager decides'), icon: Icon(Icons.admin_panel_settings_outlined, size: 16)),
                      ButtonSegment(value: 'open', label: Text('Everyone edits'), icon: Icon(Icons.group_outlined, size: 16)),
                    ],
                    selected: {editMode},
                    onSelectionChanged: (v) => setSheet(() => editMode = v.first),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      editMode == 'managed'
                          ? 'The project manager defines the tasks and dates (a department lead for its own tasks). Everyone else only updates how their own tasks are going.'
                          : 'Anyone on the project can add and change any task.',
                      style: TextStyle(fontSize: 11.5, color: crm.textSecondary),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(children: [
                    if (!proposing && !waitingForApproval) ...[
                      Expanded(
                        child: _dd(
                          'Status',
                          status,
                          [
                            // a project cannot start before the finance head approves its cost (a project already running stays as it is)
                            for (final st in const ['planning', 'active', 'on-hold', 'completed', 'cancelled'])
                              if (st != 'active' || (existing != null && (existing.mayStart || existing.status == 'active'))) st,
                          ],
                          (v) => setSheet(() => status = v),
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Expanded(child: _dd('Priority', priority, const ['low', 'medium', 'high', 'critical'], (v) => setSheet(() => priority = v))),
                  ]),
                  const SizedBox(height: 10),
                  _dd('Phase', phase, const ['discovery', 'design', 'development', 'testing', 'deployment', 'maintenance'], (v) => setSheet(() => phase = v)),
                  if (showStrategic) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: crm.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: crm.border),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Icon(Icons.auto_graph_outlined, size: 16, color: crm.primary),
                        const SizedBox(width: 6),
                        Text('Strategic Roadmap Alignment',
                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: crm.primary)),
                      ]),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<int>(
                        initialValue: horizonNumber,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Strategic Horizon Wave'),
                        items: [
                          if (ref.read(strategicVisionProvider).value?.horizons.isNotEmpty ?? false)
                            for (final h in ref.read(strategicVisionProvider).value!.horizons)
                              DropdownMenuItem(
                                value: h.horizonNumber,
                                child: Text('Horizon ${h.horizonNumber} (${h.startYear}–${h.endYear}) · ${h.name}', overflow: TextOverflow.ellipsis),
                              )
                          else ...const [
                            DropdownMenuItem(value: 1, child: Text('Horizon 1: Foundation Wave')),
                            DropdownMenuItem(value: 2, child: Text('Horizon 2: Scaling Wave')),
                            DropdownMenuItem(value: 3, child: Text('Horizon 3: Transformation Wave')),
                          ],
                        ],
                        onChanged: (v) => setSheet(() => horizonNumber = v ?? 1),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        value: (ref.read(strategicVisionProvider).value?.pillars.any((p) => p.id == strategicPillar) ?? false)
                            ? strategicPillar
                            : (ref.read(strategicVisionProvider).value?.pillars.isNotEmpty ?? false
                                ? ref.read(strategicVisionProvider).value!.pillars.first.id
                                : 'expansion'),
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Strategic Pillar'),
                        items: [
                          if (ref.read(strategicVisionProvider).value?.pillars.isNotEmpty ?? false)
                            for (final p in ref.read(strategicVisionProvider).value!.pillars)
                              DropdownMenuItem(value: p.id, child: Text(p.name, overflow: TextOverflow.ellipsis))
                          else ...const [
                            DropdownMenuItem(value: 'expansion', child: Text('Pan-India & Global Expansion')),
                            DropdownMenuItem(value: 'tech', child: Text('AI & Digital Ecosystem')),
                            DropdownMenuItem(value: 'brand', child: Text('Brand & Luxury Experience')),
                            DropdownMenuItem(value: 'people', child: Text('Academy & Human Capital')),
                            DropdownMenuItem(value: 'general', child: Text('General Strategic Initiative')),
                          ],
                        ],
                        onChanged: (v) => setSheet(() => strategicPillar = v ?? 'expansion'),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: targetYearCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Target Completion Year (e.g. 2028)',
                          hintText: '2028',
                        ),
                      ),
                    ]),
                  ),
                  ],
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: busy
                          ? null
                          : () async {
                              if (name.text.trim().isEmpty) {
                                messenger.showSnackBar(const SnackBar(content: Text('Project name is required')));
                                return;
                              }
                              if (!proposing && managerId == null) {
                                messenger.showSnackBar(const SnackBar(content: Text('Pick a project manager')));
                                return;
                              }
                              final end = endDate;
                              if (end == null && (!isEdit || hadEndDate)) {
                                messenger.showSnackBar(const SnackBar(content: Text('Pick the end date — it decides whether this is a mini, moderate or main project')));
                                return;
                              }
                              if (end != null && end.isBefore(startDate)) {
                                messenger.showSnackBar(const SnackBar(content: Text('The end date is before the start date')));
                                return;
                              }
                              if (!isEdit && !costInput.valid) {
                                setSheet(() => costMissing = true);
                                messenger.showSnackBar(const SnackBar(content: Text('Enter the estimated cost of the project')));
                                return;
                              }
                              setSheet(() => busy = true);
                              try {
                                final result = await ref.read(projectServiceProvider).saveProject({
                                  'name': name.text.trim(),
                                  'description': desc.text.trim(),
                                  'targetDepartment': department,
                                  if (!proposing) 'managerId': managerId,
                                  'members': selectedMembers.toList(),
                                  'departments': selectedDepts.toList(),
                                  'editMode': editMode,
                                  if (!proposing && !waitingForApproval) 'status': status,
                                  'priority': priority,
                                  'phase': phase,
                                  'type': 'internal',
                                  if (!isEdit) ...{
                                    if (costInput.plan.isNotEmpty) 'costPlan': [for (final l in costInput.plan) l.toJson()] else 'budget': costInput.typed,
                                  },
                                  'startDate': _isoDay.format(startDate),
                                  if (end != null) 'endDate': _isoDay.format(end),
                                  if (showStrategic) ...{
                                    'horizonNumber': horizonNumber,
                                    'strategicPillar': strategicPillar,
                                    if (int.tryParse(targetYearCtrl.text.trim()) != null)
                                      'targetYear': int.parse(targetYearCtrl.text.trim()),
                                  },
                                }, id: existing?.id);
                                if (ctx.mounted) Navigator.pop(ctx, result);
                              } catch (e) {
                                setSheet(() => busy = false);
                                messenger.showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
                              }
                            },
                      child: Text(busy ? 'Saving…' : (isEdit ? 'Save changes' : (proposing ? 'Send proposal' : 'Create project'))),
                    ),
                  ),
                ]),
              ),
            );
          },
        );
      },
    );
    if (saved != null) {
      ref.refreshData.projects();
      final invited = saved.invitedDepartments.map((d) => d.name).toList();
      messenger.showSnackBar(SnackBar(
        content: Text(
          saved.isProposed && !isEdit
              ? 'Proposal sent to the head of ${saved.targetDepartment}'
              : invited.isNotEmpty
                  ? '${isEdit ? 'Project updated' : 'Project created'}. Waiting for ${invited.join(', ')} to accept.'
                  : (isEdit ? 'Project updated' : 'Project created. The finance head has to approve its cost before it can start.'),
        ),
      ));
    }
  }

  /// The "Timeline" part of the project form: start and end dates, ready-made lengths, and — as the dates
  /// change — what kind of project it makes.
  Widget _timelineBlock({
    required CrmTheme crm,
    required DateTime start,
    required DateTime? end,
    required bool endRequired,
    required ProjectTimeline timeline,
    required bool badRange,
    required ProjectTier? tierBefore,
    required VoidCallback onPickStart,
    required VoidCallback onPickEnd,
    required ValueChanged<DurationPreset> onPreset,
  }) {
    final kindColor = _tierColor(timeline.tier, crm);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: crm.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.date_range_outlined, size: 16, color: crm.primary),
          const SizedBox(width: 6),
          Text('Timeline', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: crm.primary)),
        ]),
        const SizedBox(height: 4),
        Text(
          'How long it runs decides its kind: Mini ${ProjectTier.mini.range} · Moderate ${ProjectTier.moderate.range} · Main ${ProjectTier.main.range}.',
          style: TextStyle(fontSize: 11.5, color: crm.textSecondary, height: 1.35),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _dateBox(const Key('timeline_start'), 'Start date *', start, onPickStart)),
          const SizedBox(width: 10),
          Expanded(child: _dateBox(const Key('timeline_end'), endRequired ? 'End date *' : 'End date', end, onPickEnd)),
        ]),
        const SizedBox(height: 10),
        Wrap(spacing: 6, runSpacing: 0, children: [
          for (final pr in kDurationPresets)
            ChoiceChip(
              key: Key('preset_${pr.label}'),
              label: Text(pr.label, style: const TextStyle(fontSize: 12)),
              visualDensity: VisualDensity.compact,
              selected: end != null && end == pr.endFor(start),
              onSelected: (_) => onPreset(pr),
            ),
        ]),
        const SizedBox(height: 10),
        if (badRange)
          Text('The end date is before the start date.', key: const Key('timeline_kind'), style: TextStyle(fontSize: 12, color: crm.destructive, fontWeight: FontWeight.w600))
        else if (end == null)
          Text('Pick an end date to see what kind of project this is.', key: const Key('timeline_kind'), style: TextStyle(fontSize: 12, color: crm.textSecondary))
        else
          Container(
            key: const Key('timeline_kind'),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: kindColor.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8), border: Border.all(color: kindColor.withValues(alpha: 0.25))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                _tierChip(timeline.tier, crm),
                const SizedBox(width: 8),
                Expanded(child: Text('${timeline.tier.plural.replaceFirst(' projects', ' project')} · ${timeline.durationText}', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: crm.textPrimary))),
              ]),
              if (timeline.underMinimum)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('Mini projects start at 7 days. Something this short may fit better as a task.', style: TextStyle(fontSize: 11.5, color: crm.warning, fontWeight: FontWeight.w600)),
                ),
              if (tierBefore != null && tierBefore != ProjectTier.unscheduled && tierBefore != timeline.tier)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('This moves the project from ${tierBefore.label} to ${timeline.tier.label}.', style: TextStyle(fontSize: 11.5, color: crm.textSecondary)),
                ),
            ]),
          ),
      ]),
    );
  }

  Widget _dateBox(Key key, String label, DateTime? value, VoidCallback onTap) {
    return InkWell(
      key: key,
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          suffixIcon: const Icon(Icons.calendar_today_outlined, size: 16),
        ),
        child: Text(value == null ? 'Pick a date' : _dayYearFmt.format(value), style: const TextStyle(fontSize: 13.5)),
      ),
    );
  }

  Widget _dd(String label, String value, List<String> options, ValueChanged<String> onChanged) =>
      DropdownButtonFormField<String>(
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(labelText: label),
        items: [for (final o in options) DropdownMenuItem(value: o, child: Text(_titleCase(o)))],
        onChanged: (v) => onChanged(v ?? value),
      );
}
