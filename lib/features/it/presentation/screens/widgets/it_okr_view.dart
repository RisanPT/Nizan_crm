import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/it/domain/models/okr_model.dart';
import 'package:nizan_crm/features/it/presentation/controllers/okr_notifier.dart';
import 'package:nizan_crm/features/it/presentation/screens/widgets/okr_editor_dialog.dart';
import 'package:nizan_crm/features/it/services/it_service.dart';

class ITOkrView extends ConsumerStatefulWidget {
  final String? projectId;
  final String projectName;

  const ITOkrView({
    super.key,
    required this.projectId,
    this.projectName = 'Research & Development',
  });

  @override
  ConsumerState<ITOkrView> createState() => _ITOkrViewState();
}

class _ITOkrViewState extends ConsumerState<ITOkrView> {
  final Set<String> _expandedIds = {};
  String _searchQuery = '';
  OKRStatus? _statusFilter;
  bool? _completedFilter;
  DateTime? _startDateFilter;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final asyncOkrs = ref.watch(projectOKRsNotifierProvider(widget.projectId));
    final employees = ref.watch(itEmployeesProvider);

    return Scaffold(
      backgroundColor: crm.background,
      body: asyncOkrs.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(friendlyErrorMessage(e), style: TextStyle(color: crm.textSecondary)),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => ref.read(projectOKRsNotifierProvider(widget.projectId).notifier).refresh(),
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (allOkrs) {
          // Filter OKRs
          var filtered = allOkrs.where((item) {
            if (_searchQuery.isNotEmpty &&
                !item.objective.toLowerCase().contains(_searchQuery.toLowerCase()) &&
                !item.projectHeadName.toLowerCase().contains(_searchQuery.toLowerCase())) {
              return false;
            }
            if (_statusFilter != null && item.status != _statusFilter) {
              return false;
            }
            if (_completedFilter == true && item.status != OKRStatus.completed) {
              return false;
            } else if (_completedFilter == false && item.status == OKRStatus.completed) {
              return false;
            }
            if (_startDateFilter != null && item.startDate != null) {
              if (item.startDate!.isBefore(_startDateFilter!)) return false;
            }
            return true;
          }).toList();

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header Section
                Row(
                  children: [
                    const Text('🎯', style: TextStyle(fontSize: 24)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "OKR's & KR's for ${widget.projectName}",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: crm.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Table Title and Action Bar
                Row(
                  children: [
                    const Text('🎯', style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 6),
                    Text(
                      "OKR's Table",
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: crm.textPrimary),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline, size: 18),
                      tooltip: 'Add Objective',
                      onPressed: () => _openEditor(),
                    ),
                    const Spacer(),

                    // Search Box
                    SizedBox(
                      width: 180,
                      height: 34,
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Search OKRs...',
                          prefixIcon: const Icon(Icons.search, size: 16),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: EdgeInsets.zero,
                        ),
                        onChanged: (v) => setState(() => _searchQuery = v.trim()),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // + New Button
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: crm.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      ),
                      onPressed: () => _openEditor(),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('New', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Filter Buttons Row (Matching Notion / Screenshot Style)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip(
                        crm: crm,
                        label: 'Objective',
                        icon: '📌',
                        isActive: _searchQuery.isNotEmpty,
                        onTap: () {},
                      ),
                      const SizedBox(width: 8),
                      _buildStatusFilterMenu(crm),
                      const SizedBox(width: 8),
                      _buildStartDateFilterChip(crm),
                      const SizedBox(width: 8),
                      _buildCompletedFilterChip(crm),
                      if (_searchQuery.isNotEmpty ||
                          _statusFilter != null ||
                          _completedFilter != null ||
                          _startDateFilter != null) ...[
                        const SizedBox(width: 10),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _searchQuery = '';
                              _statusFilter = null;
                              _completedFilter = null;
                              _startDateFilter = null;
                            });
                          },
                          child: const Text('Reset filters', style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Main Dense Interactive OKR Table
                Container(
                  decoration: BoxDecoration(
                    color: crm.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: crm.border),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: IntrinsicWidth(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Table Header Row
                            _buildTableHeader(crm),
                            Divider(height: 1, color: crm.border),

                            // Table Data Rows
                            if (filtered.isEmpty)
                              Padding(
                                padding: const EdgeInsets.all(40),
                                child: Center(
                                  child: Column(
                                    children: [
                                      Icon(Icons.track_changes_outlined, size: 40, color: crm.textSecondary.withValues(alpha: 0.4)),
                                      const SizedBox(height: 8),
                                      Text('No OKRs matching criteria', style: TextStyle(color: crm.textSecondary)),
                                    ],
                                  ),
                                ),
                              )
                            else
                              for (int i = 0; i < filtered.length; i++)
                                _buildTableRow(crm, filtered[i], i + 1, employees),

                            // Bottom '+ New row' Action
                            InkWell(
                              onTap: () => _openEditor(),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                decoration: BoxDecoration(
                                  border: Border(top: BorderSide(color: crm.border)),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.add, size: 16, color: crm.textSecondary),
                                    const SizedBox(width: 8),
                                    Text(
                                      'New row',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        color: crm.textSecondary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilterChip({
    required CrmTheme crm,
    required String label,
    required String icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isActive ? crm.primary.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isActive ? crm.primary : crm.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(icon, style: const TextStyle(fontSize: 11)),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive ? crm.primary : crm.textSecondary,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.keyboard_arrow_down, size: 14, color: crm.textSecondary),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusFilterMenu(CrmTheme crm) {
    return PopupMenuButton<OKRStatus?>(
      initialValue: _statusFilter,
      onSelected: (s) => setState(() => _statusFilter = s),
      itemBuilder: (ctx) => [
        const PopupMenuItem(value: null, child: Text('All Statuses')),
        for (final s in OKRStatus.values)
          PopupMenuItem(
            value: s,
            child: Row(
              children: [
                Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: s.color)),
                const SizedBox(width: 8),
                Text(s.label),
              ],
            ),
          ),
      ],
      child: _buildFilterChip(
        crm: crm,
        label: _statusFilter != null ? _statusFilter!.label : 'Status',
        icon: '📌',
        isActive: _statusFilter != null,
        onTap: () {},
      ),
    );
  }

  Widget _buildStartDateFilterChip(CrmTheme crm) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () async {
        final d = await showDatePicker(
          context: context,
          initialDate: _startDateFilter ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime(2035),
          builder: (ctx, child) => Theme(
            data: Theme.of(ctx).copyWith(
              colorScheme: ColorScheme.light(primary: crm.primary, onPrimary: Colors.white, onSurface: crm.textPrimary, surface: crm.surface),
            ),
            child: child!,
          ),
        );
        if (d != null) setState(() => _startDateFilter = d);
      },
      child: _buildFilterChip(
        crm: crm,
        label: _startDateFilter != null ? DateFormat('dd/MM/yyyy').format(_startDateFilter!) : 'Starting Date',
        icon: '📅',
        isActive: _startDateFilter != null,
        onTap: () {},
      ),
    );
  }

  Widget _buildCompletedFilterChip(CrmTheme crm) {
    return PopupMenuButton<bool?>(
      initialValue: _completedFilter,
      onSelected: (c) => setState(() => _completedFilter = c),
      itemBuilder: (ctx) => const [
        PopupMenuItem(value: null, child: Text('All')),
        PopupMenuItem(value: true, child: Text('Completed Only')),
        PopupMenuItem(value: false, child: Text('Incomplete Only')),
      ],
      child: _buildFilterChip(
        crm: crm,
        label: _completedFilter == true ? 'Completed' : (_completedFilter == false ? 'Incomplete' : 'Completed'),
        icon: '✅',
        isActive: _completedFilter != null,
        onTap: () {},
      ),
    );
  }

  Widget _buildTableHeader(CrmTheme crm) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      child: Row(
        children: [
          const SizedBox(width: 32, child: Text('#', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700))),
          const SizedBox(width: 240, child: Row(children: [Text('📌', style: TextStyle(fontSize: 11)), SizedBox(width: 5), Text('Objective', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700))])),
          const SizedBox(width: 140, child: Row(children: [Text('👤', style: TextStyle(fontSize: 11)), SizedBox(width: 5), Text('Project Head', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700))])),
          const SizedBox(width: 120, child: Row(children: [Text('📅', style: TextStyle(fontSize: 11)), SizedBox(width: 5), Text('Starting Date', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700))])),
          const SizedBox(width: 130, child: Row(children: [Text('📌', style: TextStyle(fontSize: 11)), SizedBox(width: 5), Text('Status', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700))])),
          const SizedBox(width: 120, child: Row(children: [Text('🚦', style: TextStyle(fontSize: 11)), SizedBox(width: 5), Text('Priority', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700))])),
          const SizedBox(width: 120, child: Row(children: [Text('⌛', style: TextStyle(fontSize: 11)), SizedBox(width: 5), Text('Deadline', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700))])),
          const SizedBox(width: 140, child: Row(children: [Text('📎', style: TextStyle(fontSize: 11)), SizedBox(width: 5), Text('Documents', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700))])),
          const SizedBox(width: 110, child: Row(children: [Text('📈', style: TextStyle(fontSize: 11)), SizedBox(width: 5), Text('Progress', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700))])),
          const SizedBox(width: 220, child: Row(children: [Text('🎯', style: TextStyle(fontSize: 11)), SizedBox(width: 5), Text("KR's", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700))])),
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _buildTableRow(CrmTheme crm, OKRModel item, int index, List<dynamic> employees) {
    final isExpanded = _expandedIds.contains(item.id);
    final hasKeyResults = item.keyResults.isNotEmpty;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: crm.border.withValues(alpha: 0.5))),
          ),
          child: Row(
            children: [
              // Index
              SizedBox(
                width: 32,
                child: Text('$index', style: TextStyle(fontSize: 12, color: crm.textSecondary)),
              ),

              // Objective (Expandable tree)
              SizedBox(
                width: 240,
                child: Row(
                  children: [
                    if (hasKeyResults)
                      InkWell(
                        onTap: () {
                          setState(() {
                            if (isExpanded) {
                              _expandedIds.remove(item.id);
                            } else {
                              _expandedIds.add(item.id);
                            }
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Icon(
                            isExpanded ? Icons.arrow_drop_down : Icons.arrow_right,
                            size: 18,
                            color: crm.textSecondary,
                          ),
                        ),
                      )
                    else
                      const SizedBox(width: 18),
                    Expanded(
                      child: InkWell(
                        onTap: () => _openEditor(existing: item),
                        child: Text(
                          item.objective,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: crm.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Project Head
              SizedBox(
                width: 140,
                child: PopupMenuButton<dynamic>(
                  onSelected: (e) {
                    ref.read(projectOKRsNotifierProvider(widget.projectId).notifier).updateOKRField(
                      item.id,
                      {'projectHeadId': e.id, 'projectHeadName': e.name},
                    );
                  },
                  itemBuilder: (ctx) => [
                    for (final emp in employees)
                      PopupMenuItem(
                        value: emp,
                        child: Row(
                          children: [
                            const Icon(Icons.person_outline, size: 16),
                            const SizedBox(width: 8),
                            Text(emp.name),
                          ],
                        ),
                      ),
                  ],
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          item.projectHeadName.isNotEmpty ? item.projectHeadName : 'Assign',
                          style: TextStyle(
                            fontSize: 12,
                            color: item.projectHeadName.isNotEmpty ? crm.textPrimary : crm.textSecondary.withValues(alpha: 0.6),
                            fontWeight: item.projectHeadName.isNotEmpty ? FontWeight.w600 : FontWeight.normal,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Starting Date
              SizedBox(
                width: 120,
                child: InkWell(
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: item.startDate ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2035),
                      builder: (ctx, child) => Theme(
                        data: Theme.of(ctx).copyWith(
                          colorScheme: ColorScheme.light(primary: crm.primary, onPrimary: Colors.white, onSurface: crm.textPrimary, surface: crm.surface),
                        ),
                        child: child!,
                      ),
                    );
                    if (d != null) {
                      ref.read(projectOKRsNotifierProvider(widget.projectId).notifier).updateOKRField(
                        item.id,
                        {'startDate': d.toIso8601String()},
                      );
                    }
                  },
                  child: Text(
                    item.startDate != null ? DateFormat('dd/MM/yyyy').format(item.startDate!) : 'Set date',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: item.startDate != null ? crm.textPrimary : crm.textSecondary.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ),

              // Status Dropdown Badge
              SizedBox(
                width: 130,
                child: PopupMenuButton<OKRStatus>(
                  initialValue: item.status,
                  onSelected: (st) {
                    ref.read(projectOKRsNotifierProvider(widget.projectId).notifier).updateOKRField(
                      item.id,
                      {'status': st.slug},
                    );
                  },
                  itemBuilder: (ctx) => [
                    for (final s in OKRStatus.values)
                      PopupMenuItem(
                        value: s,
                        child: Row(
                          children: [
                            Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: s.color)),
                            const SizedBox(width: 8),
                            Text(s.label),
                          ],
                        ),
                      ),
                  ],
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: item.status.bgColor,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            item.status.label,
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: item.status.color),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.keyboard_arrow_down, size: 12, color: item.status.color),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Priority Traffic Light Badge
              SizedBox(
                width: 120,
                child: PopupMenuButton<OKRPriority>(
                  initialValue: item.priority,
                  onSelected: (pr) {
                    ref.read(projectOKRsNotifierProvider(widget.projectId).notifier).updateOKRField(
                      item.id,
                      {'priority': pr.slug},
                    );
                  },
                  itemBuilder: (ctx) => [
                    for (final p in OKRPriority.values)
                      PopupMenuItem(
                        value: p,
                        child: Row(
                          children: [
                            Icon(Icons.traffic_rounded, size: 15, color: p.color),
                            const SizedBox(width: 8),
                            Text(p.label),
                          ],
                        ),
                      ),
                  ],
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: item.priority.color.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.circle, size: 8, color: item.priority.color),
                          const SizedBox(width: 6),
                          Text(
                            item.priority.label,
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: item.priority.color),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.keyboard_arrow_down, size: 12, color: item.priority.color),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Deadline
              SizedBox(
                width: 120,
                child: InkWell(
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: item.deadline ?? item.startDate ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2035),
                      builder: (ctx, child) => Theme(
                        data: Theme.of(ctx).copyWith(
                          colorScheme: ColorScheme.light(primary: crm.primary, onPrimary: Colors.white, onSurface: crm.textPrimary, surface: crm.surface),
                        ),
                        child: child!,
                      ),
                    );
                    if (d != null) {
                      ref.read(projectOKRsNotifierProvider(widget.projectId).notifier).updateOKRField(
                        item.id,
                        {'deadline': d.toIso8601String()},
                      );
                    }
                  },
                  child: Text(
                    item.deadline != null ? DateFormat('dd/MM/yyyy').format(item.deadline!) : 'Set date',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: item.deadline != null ? crm.textPrimary : crm.textSecondary.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ),

              // Documents
              SizedBox(
                width: 140,
                child: item.documents.isEmpty
                    ? Text('—', style: TextStyle(color: crm.textSecondary.withValues(alpha: 0.4), fontSize: 12))
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (final doc in item.documents)
                              Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: InkWell(
                                  onTap: () async {
                                    final uri = Uri.tryParse(doc.url);
                                    if (uri != null) launchUrl(uri);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.picture_as_pdf, size: 12, color: Colors.blue),
                                        const SizedBox(width: 4),
                                        Text(
                                          doc.name.length > 12 ? '${doc.name.substring(0, 10)}...' : doc.name,
                                          style: const TextStyle(fontSize: 10.5, color: Colors.blue, fontWeight: FontWeight.w600),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
              ),

              // Progress
              SizedBox(
                width: 110,
                child: Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: item.progress / 100,
                          minHeight: 5,
                          backgroundColor: crm.background,
                          valueColor: AlwaysStoppedAnimation(
                            item.progress >= 100 ? const Color(0xFF10B981) : crm.primary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${item.progress}%',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: crm.textPrimary),
                    ),
                  ],
                ),
              ),

              // Key Results Tags
              SizedBox(
                width: 220,
                child: item.keyResults.isEmpty
                    ? Text('No KR targets', style: TextStyle(color: crm.textSecondary.withValues(alpha: 0.4), fontSize: 11.5))
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (final kr in item.keyResults)
                              Container(
                                margin: const EdgeInsets.only(right: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.06),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: crm.border),
                                ),
                                child: Text(
                                  kr.title,
                                  style: TextStyle(fontSize: 11, color: crm.textPrimary, fontWeight: FontWeight.w600),
                                ),
                              ),
                          ],
                        ),
                      ),
              ),

              // Actions Popup
              SizedBox(
                width: 40,
                child: PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'edit') {
                      _openEditor(existing: item);
                    } else if (v == 'delete') {
                      ref.read(projectOKRsNotifierProvider(widget.projectId).notifier).deleteOKR(item.id);
                    }
                  },
                  itemBuilder: (ctx) => const [
                    PopupMenuItem(value: 'edit', child: Text('Edit Objective')),
                    PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
                  ],
                  child: Icon(Icons.more_vert, size: 16, color: crm.textSecondary),
                ),
              ),
            ],
          ),
        ),

        // Expanded Nested Sub-Key Results Rows (Tree Accordion)
        if (isExpanded && hasKeyResults)
          for (final kr in item.keyResults)
            Container(
              padding: const EdgeInsets.fromLTRB(46, 6, 14, 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.015),
                border: Border(bottom: BorderSide(color: crm.border.withValues(alpha: 0.3))),
              ),
              child: Row(
                children: [
                  const Text('↳', style: TextStyle(fontSize: 14, color: Colors.blueGrey)),
                  const SizedBox(width: 8),
                  Text(
                    kr.title,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: crm.textSecondary),
                  ),
                  const Spacer(),
                  Text(
                    kr.metric.isNotEmpty ? kr.metric : '${kr.currentValue} / ${kr.targetValue} ${kr.unit}',
                    style: TextStyle(fontSize: 11, color: crm.textSecondary),
                  ),
                  const SizedBox(width: 16),
                ],
              ),
            ),
      ],
    );
  }

  void _openEditor({OKRModel? existing}) {
    showOKREditorDialog(
      context,
      ref,
      projectId: widget.projectId,
      existing: existing,
    );
  }
}
