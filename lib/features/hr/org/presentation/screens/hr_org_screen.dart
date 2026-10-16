import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/hr/shared/hr_ui.dart';
import 'package:nizan_crm/features/hr/shared/hr_person_picker.dart';
import 'package:nizan_crm/features/hr/org/data/org_node.dart';
import 'package:nizan_crm/features/hr/org/service/org_service.dart';
import 'package:nizan_crm/features/hr/designations/service/designation_service.dart';

enum OrgViewMode { hierarchy, teams, grid, table }

/// HR Organization — the company reporting hierarchy. Assign who each person
/// reports to (CEO → CTO/CFO → IT Head → Project Head → team) and view it as a
/// top-down chart, or browse everyone as a directory.
class HrOrgScreen extends ConsumerStatefulWidget {
  const HrOrgScreen({super.key});
  @override
  ConsumerState<HrOrgScreen> createState() => _HrOrgScreenState();
}

class _HrOrgScreenState extends ConsumerState<HrOrgScreen> {
  OrgViewMode _viewMode = OrgViewMode.hierarchy;
  final TextEditingController _searchCtrl = TextEditingController();
  String _search = '';
  String _department = 'All';
  String _reportingFilter = 'All'; // 'All', 'needs_manager', 'has_manager', 'is_manager'
  bool _allExpanded = true;
  int _expandVersion = 0;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _resetFilters() {
    setState(() {
      _search = '';
      _searchCtrl.clear();
      _department = 'All';
      _reportingFilter = 'All';
    });
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final tree = ref.watch(orgTreeProvider);

    return Scaffold(
      backgroundColor: crm.background,
      body: tree.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ListView(children: [AppErrorView(error: e, onRetry: () => ref.invalidate(orgTreeProvider))]),
        data: (nodes) {
          // Pre-calculate manager and reporting maps
          final childrenByManager = <String, List<OrgNode>>{};
          final ids = {for (final n in nodes) n.id};
          for (final n in nodes) {
            final mgr = n.reportingManagerId;
            if (mgr != null && mgr.isNotEmpty && ids.contains(mgr)) {
              childrenByManager.putIfAbsent(mgr, () => []).add(n);
            }
          }

          // Distinct departments
          final departments = <String>{
            for (final n in nodes)
              if (n.department.trim().isNotEmpty) n.department.trim()
          }.toList()..sort();

          // Filter nodes
          final filteredNodes = _applyFilters(nodes, childrenByManager);

          // Metric stats
          final totalCount = nodes.length;
          final withManagerCount = nodes.where((n) => n.reportingManagerId != null && n.reportingManagerId!.isNotEmpty).length;
          final needsManagerCount = nodes.where((n) {
            final hasMgr = n.reportingManagerId != null && n.reportingManagerId!.isNotEmpty;
            final isMgr = childrenByManager.containsKey(n.id);
            return !hasMgr && !isMgr;
          }).length;
          final managersCount = childrenByManager.keys.length;

          final hasActiveFilter = _search.isNotEmpty || _department != 'All' || _reportingFilter != 'All';

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(orgTreeProvider),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Header Banner
                _buildHeader(crm, totalCount),

                // KPI Metric Cards
                _buildMetricsBar(
                  crm,
                  totalCount: totalCount,
                  withManagerCount: withManagerCount,
                  needsManagerCount: needsManagerCount,
                  managersCount: managersCount,
                  deptCount: departments.length,
                ),

                // Sticky Control & Search Bar
                _buildFilterBar(
                  crm,
                  departments: departments,
                  totalCount: totalCount,
                  filteredCount: filteredNodes.length,
                  hasActiveFilter: hasActiveFilter,
                ),

                // Main Content View
                Expanded(
                  child: _buildBody(
                    crm: crm,
                    allNodes: nodes,
                    filteredNodes: filteredNodes,
                    childrenByManager: childrenByManager,
                    hasActiveFilter: hasActiveFilter,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  List<OrgNode> _applyFilters(List<OrgNode> nodes, Map<String, List<OrgNode>> childrenByManager) {
    var result = nodes;
    final q = _search.trim().toLowerCase();
    if (q.isNotEmpty) {
      result = result.where((n) {
        final nameMatch = n.name.toLowerCase().contains(q);
        final desigMatch = n.designation.toLowerCase().contains(q);
        final deptMatch = n.department.toLowerCase().contains(q);
        final emailMatch = n.email.toLowerCase().contains(q);
        return nameMatch || desigMatch || deptMatch || emailMatch;
      }).toList();
    }

    if (_department != 'All') {
      result = result.where((n) => n.department.trim().toLowerCase() == _department.trim().toLowerCase()).toList();
    }

    if (_reportingFilter == 'has_manager') {
      result = result.where((n) => n.reportingManagerId != null && n.reportingManagerId!.isNotEmpty).toList();
    } else if (_reportingFilter == 'needs_manager') {
      result = result.where((n) {
        final hasMgr = n.reportingManagerId != null && n.reportingManagerId!.isNotEmpty;
        final isMgr = childrenByManager.containsKey(n.id);
        return !hasMgr && !isMgr;
      }).toList();
    } else if (_reportingFilter == 'is_manager') {
      result = result.where((n) => childrenByManager.containsKey(n.id)).toList();
    }

    return result;
  }

  Widget _buildHeader(CrmTheme crm, int totalCount) {
    return Container(
      color: crm.surface,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: LayoutBuilder(builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 650;
        final titleSection = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: crm.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.account_tree_rounded, color: crm.primary, size: 22),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Organization & Hierarchy',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: crm.textPrimary,
                  ),
                ),
                Text(
                  'Manage reporting lines, team hierarchy, and personnel directory',
                  style: TextStyle(fontSize: 12, color: crm.textSecondary),
                ),
              ],
            ),
          ],
        );

        final viewToggle = _buildViewModeToggle(crm);

        if (isNarrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              titleSection,
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  viewToggle,
                  IconButton(
                    icon: Icon(Icons.refresh_rounded, color: crm.textSecondary, size: 20),
                    tooltip: 'Refresh',
                    onPressed: () => ref.invalidate(orgTreeProvider),
                  ),
                ],
              ),
            ],
          );
        }

        return Row(
          children: [
            titleSection,
            const Spacer(),
            viewToggle,
            const SizedBox(width: 10),
            IconButton(
              icon: Icon(Icons.refresh_rounded, color: crm.textSecondary, size: 20),
              tooltip: 'Refresh',
              onPressed: () => ref.invalidate(orgTreeProvider),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildViewModeToggle(CrmTheme crm) {
    Widget tab(String label, IconData icon, OrgViewMode mode) {
      final selected = _viewMode == mode;
      return InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () => setState(() => _viewMode = mode),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? crm.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: crm.primary.withValues(alpha: 0.25),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: selected ? Colors.white : crm.textSecondary),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  color: selected ? Colors.white : crm.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: crm.background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: crm.border.faded(0.8)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          tab('Hierarchy', Icons.account_tree_outlined, OrgViewMode.hierarchy),
          tab('Teams', Icons.groups_rounded, OrgViewMode.teams),
          tab('Grid', Icons.grid_view_rounded, OrgViewMode.grid),
          tab('Directory', Icons.table_rows_outlined, OrgViewMode.table),
        ],
      ),
    );
  }

  Widget _buildMetricsBar(
    CrmTheme crm, {
    required int totalCount,
    required int withManagerCount,
    required int needsManagerCount,
    required int managersCount,
    required int deptCount,
  }) {
    Widget statTile({
      required IconData icon,
      required String label,
      required String value,
      required Color color,
      VoidCallback? onTap,
      bool isActive = false,
    }) {
      return Expanded(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isActive ? color.withValues(alpha: 0.08) : crm.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isActive ? color.withValues(alpha: 0.4) : crm.border.faded(0.6),
                width: isActive ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        value,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: crm.textPrimary,
                        ),
                      ),
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, color: crm.textSecondary, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      color: crm.surface,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      child: LayoutBuilder(builder: (context, constraints) {
        if (constraints.maxWidth < 680) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                SizedBox(
                  width: 160,
                  child: statTile(
                    icon: Icons.people_alt_outlined,
                    label: 'Total People',
                    value: '$totalCount',
                    color: crm.primary,
                    onTap: () => setState(() => _reportingFilter = 'All'),
                    isActive: _reportingFilter == 'All',
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 160,
                  child: statTile(
                    icon: Icons.check_circle_outline_rounded,
                    label: 'Configured Reports',
                    value: '$withManagerCount',
                    color: crm.success,
                    onTap: () => setState(() => _reportingFilter = 'has_manager'),
                    isActive: _reportingFilter == 'has_manager',
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 160,
                  child: statTile(
                    icon: Icons.warning_amber_rounded,
                    label: 'Needs Manager',
                    value: '$needsManagerCount',
                    color: crm.warning,
                    onTap: () => setState(() => _reportingFilter = 'needs_manager'),
                    isActive: _reportingFilter == 'needs_manager',
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 160,
                  child: statTile(
                    icon: Icons.supervisor_account_outlined,
                    label: 'People Managers',
                    value: '$managersCount',
                    color: crm.accent,
                    onTap: () => setState(() => _reportingFilter = 'is_manager'),
                    isActive: _reportingFilter == 'is_manager',
                  ),
                ),
              ],
            ),
          );
        }

        return Row(
          children: [
            statTile(
              icon: Icons.people_alt_outlined,
              label: 'Total People',
              value: '$totalCount',
              color: crm.primary,
              onTap: () => setState(() => _reportingFilter = 'All'),
              isActive: _reportingFilter == 'All',
            ),
            const SizedBox(width: 10),
            statTile(
              icon: Icons.check_circle_outline_rounded,
              label: 'Configured Reports',
              value: '$withManagerCount',
              color: crm.success,
              onTap: () => setState(() => _reportingFilter = 'has_manager'),
              isActive: _reportingFilter == 'has_manager',
            ),
            const SizedBox(width: 10),
            statTile(
              icon: Icons.warning_amber_rounded,
              label: 'Needs Manager',
              value: '$needsManagerCount',
              color: crm.warning,
              onTap: () => setState(() => _reportingFilter = 'needs_manager'),
              isActive: _reportingFilter == 'needs_manager',
            ),
            const SizedBox(width: 10),
            statTile(
              icon: Icons.supervisor_account_outlined,
              label: 'People Managers',
              value: '$managersCount',
              color: crm.accent,
              onTap: () => setState(() => _reportingFilter = 'is_manager'),
              isActive: _reportingFilter == 'is_manager',
            ),
            const SizedBox(width: 10),
            statTile(
              icon: Icons.apartment_outlined,
              label: 'Departments',
              value: '$deptCount',
              color: Colors.blueGrey,
            ),
          ],
        );
      }),
    );
  }

  Widget _buildFilterBar(
    CrmTheme crm, {
    required List<String> departments,
    required int totalCount,
    required int filteredCount,
    required bool hasActiveFilter,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: crm.surface,
        border: Border(
          top: BorderSide(color: crm.border.faded(0.5)),
          bottom: BorderSide(color: crm.border.faded(0.5)),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 600;

            final searchField = Container(
              height: 42,
              decoration: BoxDecoration(
                color: crm.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: crm.border.faded(0.7)),
              ),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _search = v),
                style: TextStyle(fontSize: 13.5, color: crm.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Search people by name, designation, department…',
                  hintStyle: TextStyle(fontSize: 13, color: crm.textSecondary.withValues(alpha: 0.8)),
                  prefixIcon: Icon(Icons.search_rounded, size: 20, color: crm.textSecondary),
                  suffixIcon: _search.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear_rounded, size: 18, color: crm.textSecondary),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _search = '');
                          },
                        )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
              ),
            );

            // Department Dropdown
            final departmentDropdown = Container(
              height: 42,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: crm.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: crm.border.faded(0.7)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _department,
                  icon: Icon(Icons.arrow_drop_down_rounded, color: crm.textSecondary),
                  style: TextStyle(fontSize: 13, color: crm.textPrimary, fontWeight: FontWeight.w600),
                  items: [
                    const DropdownMenuItem(value: 'All', child: Text('All Departments')),
                    ...departments.map((d) => DropdownMenuItem(value: d, child: Text(d))),
                  ],
                  onChanged: (v) => setState(() => _department = v ?? 'All'),
                ),
              ),
            );

            // Reporting Status Dropdown
            final statusDropdown = Container(
              height: 42,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: crm.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: crm.border.faded(0.7)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _reportingFilter,
                  icon: Icon(Icons.arrow_drop_down_rounded, color: crm.textSecondary),
                  style: TextStyle(fontSize: 13, color: crm.textPrimary, fontWeight: FontWeight.w600),
                  items: const [
                    DropdownMenuItem(value: 'All', child: Text('All Reporting Status')),
                    DropdownMenuItem(value: 'needs_manager', child: Text('Needs Manager')),
                    DropdownMenuItem(value: 'has_manager', child: Text('Has Manager')),
                    DropdownMenuItem(value: 'is_manager', child: Text('People Managers')),
                  ],
                  onChanged: (v) => setState(() => _reportingFilter = v ?? 'All'),
                ),
              ),
            );

            // Hierarchy-specific Expand/Collapse button
            final expandCollapseButton = _viewMode == OrgViewMode.hierarchy
                ? Tooltip(
                    message: _allExpanded ? 'Collapse all tree branches' : 'Expand all tree branches',
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                        side: BorderSide(color: crm.border.faded(0.7)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        backgroundColor: crm.background,
                      ),
                      icon: Icon(
                        _allExpanded ? Icons.unfold_less_rounded : Icons.unfold_more_rounded,
                        size: 16,
                        color: crm.textSecondary,
                      ),
                      label: Text(
                        _allExpanded ? 'Collapse All' : 'Expand All',
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: crm.textSecondary),
                      ),
                      onPressed: () {
                        setState(() {
                          _allExpanded = !_allExpanded;
                          _expandVersion++;
                        });
                      },
                    ),
                  )
                : const SizedBox.shrink();

            if (isMobile) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  searchField,
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: departmentDropdown),
                      const SizedBox(width: 8),
                      Expanded(child: statusDropdown),
                    ],
                  ),
                  if (_viewMode == OrgViewMode.hierarchy) ...[
                    const SizedBox(height: 8),
                    expandCollapseButton,
                  ],
                ],
              );
            }

            return Row(
              children: [
                Expanded(child: searchField),
                const SizedBox(width: 10),
                departmentDropdown,
                const SizedBox(width: 10),
                statusDropdown,
                if (_viewMode == OrgViewMode.hierarchy) ...[
                  const SizedBox(width: 10),
                  expandCollapseButton,
                ],
              ],
            );
          }),

          // Active filter tags and results count row
          if (hasActiveFilter) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  'Showing $filteredCount of $totalCount people',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: crm.textSecondary),
                ),
                const SizedBox(width: 12),
                if (_search.isNotEmpty)
                  _filterBadge(crm, 'Search: "$_search"', () {
                    _searchCtrl.clear();
                    setState(() => _search = '');
                  }),
                if (_department != 'All')
                  _filterBadge(crm, 'Dept: $_department', () {
                    setState(() => _department = 'All');
                  }),
                if (_reportingFilter != 'All')
                  _filterBadge(
                    crm,
                    _reportingFilter == 'needs_manager'
                        ? 'Needs Manager'
                        : (_reportingFilter == 'has_manager' ? 'Has Manager' : 'Managers'),
                    () => setState(() => _reportingFilter = 'All'),
                  ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _resetFilters,
                  icon: const Icon(Icons.refresh_rounded, size: 14),
                  label: const Text('Clear all filters', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  style: TextButton.styleFrom(
                    foregroundColor: crm.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _filterBadge(CrmTheme crm, String label, VoidCallback onRemove) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: crm.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: crm.primary.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: crm.primary)),
          const SizedBox(width: 4),
          InkWell(
            onTap: onRemove,
            borderRadius: BorderRadius.circular(10),
            child: Icon(Icons.close_rounded, size: 13, color: crm.primary),
          ),
        ],
      ),
    );
  }

  Widget _buildBody({
    required CrmTheme crm,
    required List<OrgNode> allNodes,
    required List<OrgNode> filteredNodes,
    required Map<String, List<OrgNode>> childrenByManager,
    required bool hasActiveFilter,
  }) {
    if (filteredNodes.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: crm.surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: crm.border.faded(0.8)),
                ),
                child: Icon(Icons.person_search_outlined, size: 40, color: crm.textSecondary),
              ),
              const SizedBox(height: 16),
              Text(
                'No employees found',
                style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w800, color: crm.textPrimary),
              ),
              const SizedBox(height: 6),
              Text(
                'Try adjusting your search query or filters to find what you are looking for.',
                style: TextStyle(fontSize: 13, color: crm.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _resetFilters,
                icon: const Icon(Icons.clear_all_rounded, size: 16),
                label: const Text('Reset All Filters'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    switch (_viewMode) {
      case OrgViewMode.hierarchy:
        return _HierarchyView(
          allNodes: allNodes,
          filteredNodes: filteredNodes,
          childrenByManager: childrenByManager,
          hasActiveFilter: hasActiveFilter,
          departmentFilter: _department,
          initialExpanded: _allExpanded,
          expandVersion: _expandVersion,
          onEdit: _openEditor,
        );
      case OrgViewMode.teams:
        return _DepartmentTeamsView(
          allNodes: allNodes,
          filteredNodes: filteredNodes,
          childrenByManager: childrenByManager,
          initialExpanded: _allExpanded,
          expandVersion: _expandVersion,
          onEdit: _openEditor,
        );
      case OrgViewMode.grid:
        return _DirectoryGridView(
          nodes: filteredNodes,
          allNodes: allNodes,
          childrenByManager: childrenByManager,
          onEdit: _openEditor,
        );
      case OrgViewMode.table:
        return _DirectoryTableView(
          nodes: filteredNodes,
          allNodes: allNodes,
          childrenByManager: childrenByManager,
          onEdit: _openEditor,
        );
    }
  }

  Future<void> _openEditor(OrgNode node, List<OrgNode> all) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _ReportingEditor(node: node, all: all),
    );
    if (ok == true) ref.invalidate(orgTreeProvider);
  }
}

// ─── Hierarchy (Tree View) ───────────────────────────────────────────────────

class _HierarchyView extends StatelessWidget {
  const _HierarchyView({
    required this.allNodes,
    required this.filteredNodes,
    required this.childrenByManager,
    required this.hasActiveFilter,
    required this.departmentFilter,
    required this.initialExpanded,
    required this.expandVersion,
    required this.onEdit,
  });

  final List<OrgNode> allNodes;
  final List<OrgNode> filteredNodes;
  final Map<String, List<OrgNode>> childrenByManager;
  final bool hasActiveFilter;
  final String departmentFilter;
  final bool initialExpanded;
  final int expandVersion;
  final void Function(OrgNode, List<OrgNode>) onEdit;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final ids = {for (final n in allNodes) n.id};
    final filteredIdSet = {for (final n in filteredNodes) n.id};
    final isDeptFilterActive = hasActiveFilter && departmentFilter != 'All';

    // Roots = nodes with no manager or an invalid manager
    // When filtering by a department, roots are members whose manager is outside this department (e.g. the Team Head)
    final roots = <OrgNode>[];
    if (isDeptFilterActive) {
      for (final n in filteredNodes) {
        final mgr = n.reportingManagerId;
        if (mgr == null || mgr.isEmpty || !filteredIdSet.contains(mgr)) {
          roots.add(n);
        }
      }
    } else {
      for (final n in allNodes) {
        final mgr = n.reportingManagerId;
        if (mgr == null || mgr.isEmpty || !ids.contains(mgr)) {
          roots.add(n);
        }
      }
    }

    int byLevelThenName(OrgNode a, OrgNode b) {
      final la = a.designationLevel ?? 0;
      final lb = b.designationLevel ?? 0;
      if (la != lb) return lb.compareTo(la); // Higher level first
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    }

    roots.sort(byLevelThenName);

    // If filters are active (and not dept-specific root list), identify nodes with matching descendants
    final nodesWithMatchingDescendants = <String>{};

    bool checkMatches(OrgNode node) {
      final matchesSelf = filteredIdSet.contains(node.id);
      var childMatches = false;
      final children = childrenByManager[node.id] ?? const [];
      for (final c in children) {
        if (checkMatches(c)) childMatches = true;
      }
      if (matchesSelf || childMatches) {
        nodesWithMatchingDescendants.add(node.id);
        return true;
      }
      return false;
    }

    if (hasActiveFilter && !isDeptFilterActive) {
      for (final r in roots) {
        checkMatches(r);
      }
    }

    final visibleRoots = isDeptFilterActive
        ? roots
        : (hasActiveFilter
            ? roots.where((r) => nodesWithMatchingDescendants.contains(r.id)).toList()
            : roots);

    final noHierarchyConfigured = childrenByManager.isEmpty;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      children: [
        if (noHierarchyConfigured && !hasActiveFilter)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: crm.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: crm.warning.withValues(alpha: 0.4)),
              boxShadow: hrCardShadow(),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: crm.warning.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.account_tree_outlined, color: crm.warning, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Reporting lines have not been configured yet',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: crm.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'All employees are currently listed at the top level. Tap "Assign Manager" on any person to establish their reporting hierarchy (e.g. CEO → Department Head → Team).',
                        style: TextStyle(fontSize: 12, color: crm.textSecondary, height: 1.3),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

        // Section header for roots
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Row(
            children: [
              Text(
                isDeptFilterActive
                    ? '$departmentFilter TEAM HIERARCHY'
                    : (hasActiveFilter ? 'MATCHING HIERARCHY BRANCHES' : 'TOP-LEVEL LEADERSHIP & STAFF'),
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 0.9,
                  fontWeight: FontWeight.w700,
                  color: crm.textSecondary,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                decoration: BoxDecoration(
                  color: crm.border.faded(0.5),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${visibleRoots.length}',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: crm.textSecondary),
                ),
              ),
            ],
          ),
        ),

        // Tree rendering
        ...visibleRoots.map((root) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _OrgTreeNode(
              node: root,
              level: 0,
              childrenByManager: childrenByManager,
              all: allNodes,
              hasActiveFilter: hasActiveFilter,
              matchedIds: filteredIdSet,
              descendantMatchedIds: nodesWithMatchingDescendants,
              initialExpanded: hasActiveFilter ? true : initialExpanded,
              expandVersion: expandVersion,
              onEdit: onEdit,
            ),
          );
        }),
      ],
    );
  }
}

class _OrgTreeNode extends StatefulWidget {
  const _OrgTreeNode({
    required this.node,
    required this.level,
    required this.childrenByManager,
    required this.all,
    required this.hasActiveFilter,
    required this.matchedIds,
    required this.descendantMatchedIds,
    required this.initialExpanded,
    required this.expandVersion,
    required this.onEdit,
  });

  final OrgNode node;
  final int level;
  final Map<String, List<OrgNode>> childrenByManager;
  final List<OrgNode> all;
  final bool hasActiveFilter;
  final Set<String> matchedIds;
  final Set<String> descendantMatchedIds;
  final bool initialExpanded;
  final int expandVersion;
  final void Function(OrgNode, List<OrgNode>) onEdit;

  @override
  State<_OrgTreeNode> createState() => _OrgTreeNodeState();
}

class _OrgTreeNodeState extends State<_OrgTreeNode> {
  late bool _expanded;
  int _lastExpandVersion = 0;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initialExpanded;
    _lastExpandVersion = widget.expandVersion;
  }

  @override
  void didUpdateWidget(covariant _OrgTreeNode oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.expandVersion != _lastExpandVersion) {
      _expanded = widget.initialExpanded;
      _lastExpandVersion = widget.expandVersion;
    } else if (widget.hasActiveFilter && widget.descendantMatchedIds.contains(widget.node.id)) {
      _expanded = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final node = widget.node;
    final allChildren = widget.childrenByManager[node.id] ?? const <OrgNode>[];
    
    // Sort children
    final sortedChildren = [...allChildren]..sort((a, b) {
      final la = a.designationLevel ?? 0;
      final lb = b.designationLevel ?? 0;
      if (la != lb) return lb.compareTo(la);
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    final visibleChildren = widget.hasActiveFilter
        ? sortedChildren.where((c) => widget.descendantMatchedIds.contains(c.id)).toList()
        : sortedChildren;

    final hasChildren = visibleChildren.isNotEmpty;
    final isMatched = widget.hasActiveFilter && widget.matchedIds.contains(node.id);
    final isRoot = widget.level == 0;
    final hasNoManager = node.reportingManagerId == null || node.reportingManagerId!.isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: BoxDecoration(
            color: crm.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isMatched
                  ? crm.primary
                  : (node.isDepartmentHead
                      ? const Color(0xFFF59E0B).withValues(alpha: 0.55)
                      : (isRoot && hasChildren
                          ? crm.primary.withValues(alpha: 0.35)
                          : crm.border.faded(0.8))),
              width: isMatched ? 2 : (node.isDepartmentHead ? 1.5 : 1),
            ),
            boxShadow: isMatched
                ? [
                    BoxShadow(
                      color: crm.primary.withValues(alpha: 0.12),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    )
                  ]
                : (node.isDepartmentHead
                    ? [
                        BoxShadow(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        )
                      ]
                    : hrCardShadow()),
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => widget.onEdit(node, widget.all),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    // Expand/Collapse toggle or dot
                    SizedBox(
                      width: 28,
                      child: hasChildren
                          ? InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: () => setState(() => _expanded = !_expanded),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: crm.background,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: crm.border.faded(0.8)),
                                ),
                                child: Icon(
                                  _expanded ? Icons.expand_more_rounded : Icons.chevron_right_rounded,
                                  size: 16,
                                  color: crm.textPrimary,
                                ),
                              ),
                            )
                          : Center(
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: crm.border.faded(0.9),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                    ),
                    const SizedBox(width: 8),

                    // Avatar
                    _personAvatar(crm, node, radius: 19),
                    const SizedBox(width: 12),

                    // Name, designation & department tags
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  node.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: crm.textPrimary,
                                  ),
                                ),
                              ),
                              if (isMatched) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: crm.primary.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text('MATCH', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: crm.primary)),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              if (node.designation.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: crm.background,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: crm.border.faded(0.7)),
                                  ),
                                  child: Text(
                                    node.designationLevel != null
                                        ? '${node.designation} (L${node.designationLevel})'
                                        : node.designation,
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: crm.textPrimary),
                                  ),
                                ),
                              if (node.department.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: crm.primary.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    node.department,
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: crm.primary),
                                  ),
                                ),
                              if (node.isDepartmentHead)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.45)),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.stars_rounded, size: 12, color: Color(0xFFD97706)),
                                      SizedBox(width: 4),
                                      Text(
                                        'Team Head',
                                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFFD97706)),
                                      ),
                                    ],
                                  ),
                                )
                              else if (allChildren.isNotEmpty && !isRoot)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: crm.primary.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: crm.primary.withValues(alpha: 0.35)),
                                  ),
                                  child: Text(
                                    'Team Lead',
                                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: crm.primary),
                                  ),
                                ),
                              if (hasNoManager && isRoot)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: allChildren.isNotEmpty
                                        ? crm.success.withValues(alpha: 0.1)
                                        : crm.warning.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    allChildren.isNotEmpty ? 'Leadership' : 'No Manager',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      color: allChildren.isNotEmpty ? crm.success : crm.warning,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Direct reports counter pill
                    if (allChildren.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () => setState(() => _expanded = !_expanded),
                        borderRadius: BorderRadius.circular(999),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: crm.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: crm.primary.withValues(alpha: 0.2)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.people_alt_outlined, size: 14, color: crm.primary),
                              const SizedBox(width: 4),
                              Text(
                                '${allChildren.length} reports',
                                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: crm.primary),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],

                    // Action: Edit / Assign
                    const SizedBox(width: 10),
                    hasNoManager && allChildren.isEmpty
                        ? OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              side: BorderSide(color: crm.primary.withValues(alpha: 0.4)),
                              visualDensity: VisualDensity.compact,
                            ),
                            icon: Icon(Icons.add_link_rounded, size: 14, color: crm.primary),
                            label: Text(
                              'Assign Manager',
                              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: crm.primary),
                            ),
                            onPressed: () => widget.onEdit(node, widget.all),
                          )
                        : IconButton(
                            icon: Icon(Icons.edit_outlined, size: 17, color: crm.textSecondary.withValues(alpha: 0.7)),
                            tooltip: 'Edit reporting line',
                            onPressed: () => widget.onEdit(node, widget.all),
                          ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Recursive tree children with connector styling
        if (_expanded && hasChildren)
          Padding(
            padding: const EdgeInsets.only(left: 22, top: 8),
            child: Container(
              decoration: BoxDecoration(
                border: Border(left: BorderSide(color: crm.border.faded(0.9), width: 1.5)),
              ),
              padding: const EdgeInsets.only(left: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: visibleChildren
                    .map((child) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _OrgTreeNode(
                            node: child,
                            level: widget.level + 1,
                            childrenByManager: widget.childrenByManager,
                            all: widget.all,
                            hasActiveFilter: widget.hasActiveFilter,
                            matchedIds: widget.matchedIds,
                            descendantMatchedIds: widget.descendantMatchedIds,
                            initialExpanded: widget.initialExpanded,
                            expandVersion: widget.expandVersion,
                            onEdit: widget.onEdit,
                          ),
                        ))
                    .toList(),
              ),
            ),
          ),
      ],
    );
  }
}

// ─── Department Teams View (Hierarchy by Team) ──────────────────────────────

class _DepartmentTeamsView extends StatefulWidget {
  const _DepartmentTeamsView({
    required this.allNodes,
    required this.filteredNodes,
    required this.childrenByManager,
    required this.initialExpanded,
    required this.expandVersion,
    required this.onEdit,
  });

  final List<OrgNode> allNodes;
  final List<OrgNode> filteredNodes;
  final Map<String, List<OrgNode>> childrenByManager;
  final bool initialExpanded;
  final int expandVersion;
  final void Function(OrgNode, List<OrgNode>) onEdit;

  @override
  State<_DepartmentTeamsView> createState() => _DepartmentTeamsViewState();
}

class _DepartmentTeamsViewState extends State<_DepartmentTeamsView> {
  final Map<String, bool> _expandedTeams = {};

  IconData _departmentIcon(String dept) {
    final d = dept.toLowerCase();
    if (d.contains('it') || d.contains('tech')) return Icons.terminal_rounded;
    if (d.contains('sales')) return Icons.trending_up_rounded;
    if (d.contains('market')) return Icons.campaign_rounded;
    if (d.contains('hr')) return Icons.badge_rounded;
    if (d.contains('finance') || d.contains('account')) return Icons.account_balance_wallet_rounded;
    if (d.contains('crm')) return Icons.support_agent_rounded;
    if (d.contains('operation') || d.contains('artist')) return Icons.brush_rounded;
    if (d.contains('fleet')) return Icons.local_shipping_rounded;
    if (d.contains('management')) return Icons.workspace_premium_rounded;
    return Icons.corporate_fare_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;

    // Group filtered nodes by department
    final deptMap = <String, List<OrgNode>>{};
    for (final node in widget.filteredNodes) {
      final dept = node.department.trim().isNotEmpty ? node.department.trim() : 'Other';
      deptMap.putIfAbsent(dept, () => []).add(node);
    }

    final depts = deptMap.keys.toList()..sort();

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      itemCount: depts.length,
      itemBuilder: (context, index) {
        final dept = depts[index];
        final members = deptMap[dept] ?? [];
        final memberIdSet = {for (final m in members) m.id};

        // Find Department/Team Head (isDepartmentHead, or root within team, or highest level)
        OrgNode? head = members.where((m) => m.isDepartmentHead).firstOrNull;
        head ??= members.where((m) {
          final mgr = m.reportingManagerId;
          return mgr == null || mgr.isEmpty || !memberIdSet.contains(mgr);
        }).firstOrNull;
        head ??= members.first;

        // Team roots for hierarchy tree inside this department
        final teamRoots = members.where((m) {
          final mgr = m.reportingManagerId;
          return mgr == null || mgr.isEmpty || !memberIdSet.contains(mgr);
        }).toList();

        int byLevelThenName(OrgNode a, OrgNode b) {
          final la = a.designationLevel ?? 0;
          final lb = b.designationLevel ?? 0;
          if (la != lb) return lb.compareTo(la);
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        }
        teamRoots.sort(byLevelThenName);

        final isExpanded = _expandedTeams[dept] ?? widget.initialExpanded;

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: crm.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: head.isDepartmentHead
                  ? const Color(0xFFF59E0B).withValues(alpha: 0.35)
                  : crm.border.faded(0.8),
            ),
            boxShadow: hrCardShadow(),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Team Header Card
              InkWell(
                borderRadius: BorderRadius.vertical(
                  top: const Radius.circular(16),
                  bottom: Radius.circular(isExpanded ? 0 : 16),
                ),
                onTap: () => setState(() => _expandedTeams[dept] = !isExpanded),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      // Department icon
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: crm.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(_departmentIcon(dept), color: crm.primary, size: 22),
                      ),
                      const SizedBox(width: 14),

                      // Department & Team Head info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  '$dept Team',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: crm.textPrimary,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: crm.primary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    '${members.length} members',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: crm.primary),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.stars_rounded, size: 14, color: Color(0xFFD97706)),
                                const SizedBox(width: 4),
                                Text(
                                  'Team Head: ',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: crm.textSecondary),
                                ),
                                Flexible(
                                  child: Text(
                                    head.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: crm.textPrimary),
                                  ),
                                ),
                                if (head.designation.isNotEmpty) ...[
                                  Flexible(
                                    child: Text(
                                      ' • ${head.designation}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontSize: 12, color: crm.textSecondary),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Expand/collapse icon
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: crm.background,
                          shape: BoxShape.circle,
                          border: Border.all(color: crm.border.faded(0.8)),
                        ),
                        child: Icon(
                          isExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                          size: 18,
                          color: crm.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Divider & Team Hierarchy Tree
              if (isExpanded) ...[
                Divider(height: 1, color: crm.border.faded(0.7)),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: teamRoots.map((root) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _OrgTreeNode(
                          node: root,
                          level: 0,
                          childrenByManager: widget.childrenByManager,
                          all: widget.allNodes,
                          hasActiveFilter: false,
                          matchedIds: const {},
                          descendantMatchedIds: const {},
                          initialExpanded: widget.initialExpanded,
                          expandVersion: widget.expandVersion,
                          onEdit: widget.onEdit,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

// ─── Directory Grid View ─────────────────────────────────────────────────────

class _DirectoryGridView extends StatelessWidget {
  const _DirectoryGridView({
    required this.nodes,
    required this.allNodes,
    required this.childrenByManager,
    required this.onEdit,
  });

  final List<OrgNode> nodes;
  final List<OrgNode> allNodes;
  final Map<String, List<OrgNode>> childrenByManager;
  final void Function(OrgNode, List<OrgNode>) onEdit;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final nameById = {for (final n in allNodes) n.id: n.name};

    return LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth > 960 ? 3 : (c.maxWidth > 600 ? 2 : 1);
      const gap = 14.0;
      final w = (c.maxWidth - (gap * (cols - 1)) - 40) / cols;

      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        children: [
          Wrap(
            spacing: gap,
            runSpacing: gap,
            children: nodes.map((n) {
              final mgrName = nameById[n.reportingManagerId ?? ''];
              final directReports = childrenByManager[n.id]?.length ?? 0;
              return SizedBox(
                width: w,
                child: _buildCard(context, crm, n, mgrName, directReports),
              );
            }).toList(),
          ),
        ],
      );
    });
  }

  Widget _buildCard(BuildContext context, CrmTheme crm, OrgNode n, String? managerName, int reportsCount) {
    final hasManager = managerName != null && managerName.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: crm.border.faded(0.8)),
        boxShadow: hrCardShadow(),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => onEdit(n, allNodes),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: Avatar + Name + Edit icon
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _personAvatar(crm, n, radius: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            n.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: crm.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            n.designation.isNotEmpty ? n.designation : 'No designation',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: n.designation.isNotEmpty ? crm.textSecondary : crm.textSecondary.withValues(alpha: 0.6),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.edit_outlined, size: 16, color: crm.textSecondary.withValues(alpha: 0.6)),
                      onPressed: () => onEdit(n, allNodes),
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Edit Reporting',
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Tags: Department and Reports count
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (n.department.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: crm.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          n.department,
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: crm.primary),
                        ),
                      ),
                    if (reportsCount > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.teal.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.supervisor_account_rounded, size: 12, color: Colors.teal),
                            const SizedBox(width: 4),
                            Text(
                              '$reportsCount reports',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.teal),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 14),
                Divider(height: 1, color: crm.border.faded(0.5)),
                const SizedBox(height: 12),

                // Reporting line status
                Row(
                  children: [
                    Icon(
                      hasManager ? Icons.subdirectory_arrow_right_rounded : Icons.info_outline_rounded,
                      size: 15,
                      color: hasManager ? crm.textSecondary : crm.warning,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        hasManager ? 'Reports to: $managerName' : 'Top Level (No manager set)',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: hasManager ? FontWeight.w600 : FontWeight.w500,
                          color: hasManager ? crm.textSecondary : crm.warning,
                        ),
                      ),
                    ),
                    if (!hasManager)
                      Text(
                        'Set',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: crm.primary),
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
}

// ─── Directory Table View ────────────────────────────────────────────────────

class _DirectoryTableView extends StatelessWidget {
  const _DirectoryTableView({
    required this.nodes,
    required this.allNodes,
    required this.childrenByManager,
    required this.onEdit,
  });

  final List<OrgNode> nodes;
  final List<OrgNode> allNodes;
  final Map<String, List<OrgNode>> childrenByManager;
  final void Function(OrgNode, List<OrgNode>) onEdit;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final nameById = {for (final n in allNodes) n.id: n.name};

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      children: [
        Container(
          decoration: BoxDecoration(
            color: crm.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: crm.border.faded(0.8)),
            boxShadow: hrCardShadow(),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Table Header
                Container(
                  color: crm.background,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      const Expanded(flex: 3, child: _TableHeaderText('EMPLOYEE')),
                      const Expanded(flex: 2, child: _TableHeaderText('DEPARTMENT')),
                      const Expanded(flex: 2, child: _TableHeaderText('DESIGNATION')),
                      const Expanded(flex: 2, child: _TableHeaderText('REPORTS TO')),
                      const SizedBox(width: 80, child: _TableHeaderText('TEAM')),
                      const SizedBox(width: 50, child: _TableHeaderText('ACTION')),
                    ],
                  ),
                ),
                Divider(height: 1, color: crm.border.faded(0.8)),

                // Table Rows
                ...nodes.asMap().entries.map((entry) {
                  final index = entry.key;
                  final n = entry.value;
                  final mgrName = nameById[n.reportingManagerId ?? ''];
                  final reportsCount = childrenByManager[n.id]?.length ?? 0;
                  final hasManager = mgrName != null && mgrName.isNotEmpty;

                  return Container(
                    color: index.isOdd ? crm.background.withValues(alpha: 0.3) : crm.surface,
                    child: InkWell(
                      onTap: () => onEdit(n, allNodes),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                        child: Row(
                          children: [
                            // Employee info
                            Expanded(
                              flex: 3,
                              child: Row(
                                children: [
                                  _personAvatar(crm, n, radius: 16),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      n.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: crm.textPrimary),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Department
                            Expanded(
                              flex: 2,
                              child: Text(
                                n.department.isNotEmpty ? n.department : '—',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 12.5, color: crm.textSecondary),
                              ),
                            ),

                            // Designation
                            Expanded(
                              flex: 2,
                              child: Text(
                                n.designation.isNotEmpty
                                    ? (n.designationLevel != null ? '${n.designation} (L${n.designationLevel})' : n.designation)
                                    : '—',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 12.5, color: crm.textSecondary),
                              ),
                            ),

                            // Reports To
                            Expanded(
                              flex: 2,
                              child: Row(
                                children: [
                                  Icon(
                                    hasManager ? Icons.subdirectory_arrow_right : Icons.fiber_manual_record,
                                    size: hasManager ? 14 : 7,
                                    color: hasManager ? crm.textSecondary : crm.warning,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      hasManager ? mgrName : 'Top Level',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: hasManager ? FontWeight.w600 : FontWeight.w500,
                                        color: hasManager ? crm.textPrimary : crm.warning,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Team / Reports
                            SizedBox(
                              width: 80,
                              child: reportsCount > 0
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: crm.primary.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(999),
                                      ),
                                      child: Text(
                                        '$reportsCount directs',
                                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: crm.primary),
                                        textAlign: TextAlign.center,
                                      ),
                                    )
                                  : Text('—', style: TextStyle(fontSize: 12, color: crm.textSecondary), textAlign: TextAlign.center),
                            ),

                            // Action button
                            SizedBox(
                              width: 50,
                              child: IconButton(
                                icon: Icon(Icons.edit_outlined, size: 16, color: crm.textSecondary),
                                onPressed: () => onEdit(n, allNodes),
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TableHeaderText extends StatelessWidget {
  const _TableHeaderText(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 11,
        letterSpacing: 0.8,
        fontWeight: FontWeight.w700,
        color: context.crmColors.textSecondary,
      ),
    );
  }
}

// ─── Shared Avatar Helper ────────────────────────────────────────────────────

Widget _personAvatar(CrmTheme crm, OrgNode node, {double radius = 18}) {
  return CircleAvatar(
    radius: radius,
    backgroundColor: crm.primary.withValues(alpha: 0.12),
    backgroundImage: node.profileImage.isNotEmpty ? NetworkImage(node.profileImage) : null,
    child: node.profileImage.isEmpty
        ? Text(
            node.name.isNotEmpty ? node.name[0].toUpperCase() : '?',
            style: TextStyle(color: crm.primary, fontWeight: FontWeight.w800, fontSize: radius * 0.85),
          )
        : null,
  );
}

// ─── Reporting Line Editor Dialog ────────────────────────────────────────────

class _ReportingEditor extends ConsumerStatefulWidget {
  const _ReportingEditor({required this.node, required this.all});
  final OrgNode node;
  final List<OrgNode> all;

  @override
  ConsumerState<_ReportingEditor> createState() => _ReportingEditorState();
}

class _ReportingEditorState extends ConsumerState<_ReportingEditor> {
  String? _managerId;
  String? _designationId;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _managerId = (widget.node.reportingManagerId?.isNotEmpty ?? false) ? widget.node.reportingManagerId : null;
    _designationId = (widget.node.designationId?.isNotEmpty ?? false) ? widget.node.designationId : null;
  }

  // Candidates = everyone except this person and anyone who (directly or
  // indirectly) reports to them — strictly avoids creating an org loop.
  Set<String> _descendantsOf(String id) {
    final childrenByManager = <String, List<OrgNode>>{};
    for (final n in widget.all) {
      final m = n.reportingManagerId;
      if (m != null && m.isNotEmpty) childrenByManager.putIfAbsent(m, () => []).add(n);
    }
    final out = <String>{id};
    final queue = [id];
    while (queue.isNotEmpty) {
      final cur = queue.removeLast();
      for (final c in childrenByManager[cur] ?? const <OrgNode>[]) {
        if (out.add(c.id)) queue.add(c.id);
      }
    }
    return out;
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      await ref.read(orgServiceProvider).setReporting(
            widget.node.id,
            managerId: _managerId,
            designationId: _designationId ?? '',
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final excluded = _descendantsOf(widget.node.id);
    final candidates = widget.all.where((n) => !excluded.contains(n.id)).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final designations = ref.watch(designationsProvider);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
      title: Row(
        children: [
          _personAvatar(crm, widget.node, radius: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.node.name,
                  style: GoogleFonts.plusJakartaSans(fontSize: 17, fontWeight: FontWeight.w800, color: crm.textPrimary),
                ),
                if (widget.node.department.isNotEmpty || widget.node.designation.isNotEmpty)
                  Text(
                    [
                      if (widget.node.designation.isNotEmpty) widget.node.designation,
                      if (widget.node.department.isNotEmpty) widget.node.department,
                    ].join(' · '),
                    style: TextStyle(fontSize: 12, color: crm.textSecondary),
                  ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: crm.background,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: crm.border.faded(0.6)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, size: 18, color: crm.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Choose who this person reports to directly. Select "Top level" if they report to no one (e.g. CEO or Founder).',
                      style: TextStyle(fontSize: 11.5, color: crm.textSecondary, height: 1.3),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            PersonPickerField(
              label: 'Reports To (Direct Manager)',
              icon: Icons.account_tree_outlined,
              allowNone: true,
              noneLabel: 'Top level (No manager / CEO)',
              hint: 'Select direct manager',
              selectedId: _managerId,
              items: candidates
                  .map((n) => PickerItem(id: n.id, name: n.name, department: n.department, designation: n.designation))
                  .toList(),
              onChanged: (v) => setState(() => _managerId = v),
            ),
            const SizedBox(height: 14),
            designations.when(
              loading: () => const LinearProgressIndicator(),
              error: (_, _) => const SizedBox.shrink(),
              data: (list) => DropdownButtonFormField<String?>(
                initialValue: list.any((d) => d.id == _designationId) ? _designationId : null,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Designation & Grade',
                  prefixIcon: Icon(Icons.workspace_premium_outlined),
                ),
                items: [
                  const DropdownMenuItem<String?>(value: null, child: Text('— None —')),
                  ...list.map((d) => DropdownMenuItem<String?>(
                        value: d.id,
                        child: Text('${d.name} (Level ${d.level})'),
                      )),
                ],
                onChanged: (v) => setState(() => _designationId = v),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _busy ? null : _save,
          style: FilledButton.styleFrom(
            backgroundColor: crm.primary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          ),
          icon: _busy
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.check_rounded, size: 18),
          label: const Text('Save Reporting Line'),
        ),
      ],
    );
  }
}
