import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/hr_shared/hr_ui.dart';
import 'package:nizan_crm/features/hr_shared/hr_person_picker.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/services/employee_service.dart';
import 'package:nizan_crm/features/hr_onboarding/data/onboarding_models.dart';
import 'package:nizan_crm/features/hr_onboarding/service/onboarding_service.dart';
import 'package:go_router/go_router.dart';

Color _avatarColor(String name) {
  final colors = [
    const Color(0xFF601A29), // Maroon
    const Color(0xFF3B5BA5), // Slate Blue
    const Color(0xFF0D9488), // Teal
    const Color(0xFFD97706), // Amber
    const Color(0xFF7C3AED), // Violet
    const Color(0xFF059669), // Emerald
  ];
  if (name.isEmpty) return colors[0];
  final hash = name.codeUnits.fold(0, (acc, c) => acc + c);
  return colors[hash % colors.length];
}

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty || parts[0].isEmpty) return 'EM';
  if (parts.length == 1) return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
  return (parts[0][0] + parts[1][0]).toUpperCase();
}

String _formatDate(DateTime? dt) {
  if (dt == null) return 'joins soon';
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return 'joins ${dt.day} ${months[dt.month - 1]}';
}

/// HR Onboarding screen redesign matching HRMS_Design.html (#s-onboarding).
class HrOnboardingScreen extends ConsumerStatefulWidget {
  const HrOnboardingScreen({super.key});

  @override
  ConsumerState<HrOnboardingScreen> createState() => _HrOnboardingScreenState();
}

class _HrOnboardingScreenState extends ConsumerState<HrOnboardingScreen> {
  String? _selectedId;
  String _filter = 'all'; // all, in_progress, completed

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final onboardingsAsync = ref.watch(onboardingsProvider);

    return Scaffold(
      backgroundColor: crm.background,
      body: onboardingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(onboardingsProvider),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              AppErrorView(error: e, onRetry: () => ref.invalidate(onboardingsProvider)),
            ],
          ),
        ),
        data: (allList) {
          // Ongoing vs Completed counts
          final ongoingList = allList.where((o) => o.status != 'completed' && (o.tasks.isEmpty || o.doneCount < o.tasks.length)).toList();
          final completedList = allList.where((o) => o.status == 'completed' || (o.tasks.isNotEmpty && o.doneCount == o.tasks.length)).toList();

          final list = _filter == 'in_progress'
              ? ongoingList
              : (_filter == 'completed' ? completedList : allList);

          // Auto-select first item if current selection invalid or not in current filter
          final selected = list.isNotEmpty
              ? (list.firstWhere((o) => o.id == _selectedId, orElse: () => list.first))
              : null;

          if (selected != null && _selectedId != selected.id) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _selectedId = selected.id);
            });
          }

          // KPI stats
          final inOnboardingCount = ongoingList.length;
          final preBoardingCount = allList.where((o) => o.doneCount < o.tasks.length).length;
          final pendingDocsCount = allList.fold<int>(0, (acc, o) => acc + o.pendingDocsCount);

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(onboardingsProvider),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(context, crm),
                  const SizedBox(height: 18),
                  _buildStatsGrid(crm, inOnboardingCount, preBoardingCount, pendingDocsCount),
                  const SizedBox(height: 18),
                  _buildTopFilterTabs(crm, ongoingList.length, completedList.length, allList.length),
                  const SizedBox(height: 16),
                  if (list.isEmpty)
                    _buildEmptyFilterState(crm, _filter)
                  else
                    LayoutBuilder(
                      builder: (ctx, constraints) {
                        final isDesktop = constraints.maxWidth >= 900;
                        if (isDesktop) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Left: New-hire board
                              Expanded(
                                flex: 5,
                                child: _buildNewHireBoard(crm, list, selected),
                              ),
                              const SizedBox(width: 18),
                              // Right: Interactive Checklist
                              Expanded(
                                flex: 6,
                                child: selected != null
                                    ? _buildChecklistCard(crm, selected)
                                    : const SizedBox.shrink(),
                              ),
                            ],
                          );
                        } else {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildNewHireBoard(crm, list, selected),
                              const SizedBox(height: 18),
                              if (selected != null) _buildChecklistCard(crm, selected),
                            ],
                          );
                        }
                      },
                    ),
                  const SizedBox(height: 18),
                  if (selected != null) _buildDocumentCollectionCard(crm, selected),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Header (Matching .phead in design) ───────────────────────────────────────
  Widget _buildHeader(BuildContext context, CrmTheme crm) {
    return LayoutBuilder(
      builder: (ctx, constraints) {
        final isNarrow = constraints.maxWidth < 650;
        final infoCol = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'RECRUIT & ONBOARD',
              style: TextStyle(
                fontSize: 11,
                letterSpacing: 0.9,
                fontWeight: FontWeight.w700,
                color: crm.primary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'New hire onboarding',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: crm.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Pre-boarding, checklists and document collection — from accepted offer to first day.',
              style: TextStyle(fontSize: 13, color: crm.textSecondary),
            ),
          ],
        );

        final btnRow = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            OutlinedButton.icon(
              onPressed: () => _showTemplatesDialog(context, crm),
              icon: const Icon(Icons.playlist_add_check, size: 16),
              label: const Text('Templates'),
              style: OutlinedButton.styleFrom(
                foregroundColor: crm.textPrimary,
                side: BorderSide(color: crm.border),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(width: 10),
            FilledButton.icon(
              onPressed: () => _startOnboarding(context, ref),
              icon: const Icon(Icons.person_add_alt_1, size: 16),
              label: const Text('Start onboarding'),
              style: FilledButton.styleFrom(
                backgroundColor: crm.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        );

        if (isNarrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              infoCol,
              const SizedBox(height: 12),
              btnRow,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(child: infoCol),
            const SizedBox(width: 16),
            btnRow,
          ],
        );
      },
    );
  }

  // ── 4 Stats Grid ────────────────────────────────────────────────────────────
  Widget _buildStatsGrid(
    CrmTheme crm,
    int inOnboarding,
    int preBoarding,
    int pendingDocs,
  ) {
    return LayoutBuilder(
      builder: (ctx, constraints) {
        final w = constraints.maxWidth;
        final int crossAxisCount = w >= 1000 ? 4 : (w >= 540 ? 2 : 1);
        final double itemWidth = (w - (crossAxisCount - 1) * 12) / crossAxisCount;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildStatCard(
              crm: crm,
              width: itemWidth,
              icon: Icons.person_pin_outlined,
              iconBg: crm.primary.withValues(alpha: 0.12),
              iconColor: crm.primary,
              label: 'In onboarding',
              val: '$inOnboarding',
              foot: 'joining this month',
            ),
            _buildStatCard(
              crm: crm,
              width: itemWidth,
              icon: Icons.hourglass_top_outlined,
              iconBg: const Color(0xFF2563EB).withValues(alpha: 0.12),
              iconColor: const Color(0xFF2563EB),
              label: 'Pre-boarding',
              val: '$preBoarding',
              foot: 'offer signed, awaiting day 1',
            ),
            _buildStatCard(
              crm: crm,
              width: itemWidth,
              icon: Icons.warning_amber_rounded,
              iconBg: const Color(0xFFD97706).withValues(alpha: 0.12),
              iconColor: const Color(0xFFD97706),
              label: 'Documents pending',
              val: '$pendingDocs',
              foot: 'across active hires',
            ),
            _buildStatCard(
              crm: crm,
              width: itemWidth,
              icon: Icons.rocket_launch_outlined,
              iconBg: const Color(0xFF059669).withValues(alpha: 0.12),
              iconColor: const Color(0xFF059669),
              label: 'Avg time to productive',
              val: '9d',
              foot: 'last 6 hires',
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard({
    required CrmTheme crm,
    required double width,
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String label,
    required String val,
    required String foot,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: hrCardDecoration(crm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(height: 12),
          Text(label, style: TextStyle(fontSize: 12, color: crm.textSecondary, fontWeight: FontWeight.w600)),
          const SizedBox(height: 3),
          Text(
            val,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: crm.textPrimary,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 4),
          Text(foot, style: TextStyle(fontSize: 11.5, color: crm.textSecondary)),
        ],
      ),
    );
  }

  // ── Top Filter Tabs (Ongoing vs Completed) ─────────────────────────────────
  Widget _buildTopFilterTabs(CrmTheme crm, int ongoingCount, int completedCount, int allCount) {
    return Container(
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: crm.border),
        boxShadow: hrCardShadow(),
      ),
      padding: const EdgeInsets.all(4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _topTabItem(
              crm: crm,
              label: 'Ongoing',
              subtitle: 'In progress',
              key: 'in_progress',
              count: ongoingCount,
              icon: Icons.timelapse_outlined,
              activeColor: const Color(0xFFD97706),
            ),
            const SizedBox(width: 4),
            _topTabItem(
              crm: crm,
              label: 'Completed',
              subtitle: 'Day 1 done',
              key: 'completed',
              count: completedCount,
              icon: Icons.check_circle_outline,
              activeColor: const Color(0xFF059669),
            ),
            const SizedBox(width: 4),
            _topTabItem(
              crm: crm,
              label: 'All Hires',
              subtitle: 'Total records',
              key: 'all',
              count: allCount,
              icon: Icons.people_outline,
              activeColor: crm.primary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _topTabItem({
    required CrmTheme crm,
    required String label,
    required String subtitle,
    required String key,
    required int count,
    required IconData icon,
    required Color activeColor,
  }) {
    final active = _filter == key;
    return InkWell(
      borderRadius: BorderRadius.circular(9),
      onTap: () => setState(() => _filter = key),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: active ? activeColor.withValues(alpha: 0.10) : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: active ? activeColor.withValues(alpha: 0.35) : Colors.transparent,
            width: 1.2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: active ? activeColor : crm.textSecondary,
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                    color: active ? activeColor : crm.textPrimary,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: active ? activeColor.withValues(alpha: 0.8) : crm.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: active ? activeColor : crm.border.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: active ? Colors.white : crm.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── New-hire Board (Left Card) ──────────────────────────────────────────────
  Widget _buildNewHireBoard(CrmTheme crm, List<Onboarding> list, Onboarding? selected) {
    return Container(
      decoration: hrCardDecoration(crm),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'New-hire board',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: crm.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text('Onboarding progress by stage', style: TextStyle(fontSize: 12, color: crm.textSecondary)),
                ],
              ),
              // Segmented filter chips
              Container(
                decoration: BoxDecoration(
                  color: crm.background,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: crm.border),
                ),
                padding: const EdgeInsets.all(2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _filterChip(crm, 'All', 'all'),
                    _filterChip(crm, 'Active', 'in_progress'),
                    _filterChip(crm, 'Done', 'completed'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...list.map((o) {
            final isSelected = selected?.id == o.id;
            final pct = o.tasks.isEmpty ? 0 : ((o.doneCount / o.tasks.length) * 100).round();
            final isDone = o.status == 'completed' || (o.tasks.isNotEmpty && o.doneCount == o.tasks.length);

            // Determine status label & color
            String statusText;
            Color statusColor;
            if (isDone) {
              statusText = 'Day 1 done';
              statusColor = const Color(0xFF059669);
            } else if (o.doneCount >= 3) {
              statusText = 'Pre-boarding';
              statusColor = const Color(0xFFD97706);
            } else {
              statusText = 'Offer signed';
              statusColor = const Color(0xFF3B5BA5);
            }

            final roleAndJoin = [
              if (o.role.isNotEmpty) o.role else 'Staff',
              if (o.joiningDate != null) _formatDate(o.joiningDate),
            ].join(' · ');

            return InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => setState(() => _selectedId = o.id),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isSelected ? crm.primary.withValues(alpha: 0.04) : crm.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? crm.primary : crm.border,
                    width: isSelected ? 1.8 : 1.0,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 19,
                          backgroundColor: _avatarColor(o.employeeName),
                          child: Text(
                            _initials(o.employeeName),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                o.employeeName,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: crm.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                roleAndJoin,
                                style: TextStyle(fontSize: 11.5, color: crm.textSecondary),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            statusText,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: statusColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        PopupMenuButton<String>(
                          tooltip: 'Options',
                          icon: Icon(Icons.more_vert, size: 18, color: crm.textSecondary),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onSelected: (val) {
                            if (val == 'edit') {
                              _editOnboarding(context, o);
                            } else if (val == 'delete') {
                              _deleteOnboarding(context, o);
                            }
                          },
                          itemBuilder: (ctx) => [
                            const PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(Icons.edit_outlined, size: 16),
                                  SizedBox(width: 8),
                                  Text('Edit details'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete_outline, size: 16, color: Colors.red),
                                  SizedBox(width: 8),
                                  Text('Remove from onboarding', style: TextStyle(color: Colors.red)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${o.doneCount} of ${o.tasks.length} steps done',
                          style: TextStyle(fontSize: 11.5, color: crm.textSecondary),
                        ),
                        Text(
                          '$pct%',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: crm.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: o.tasks.isEmpty ? 0 : o.doneCount / o.tasks.length,
                        minHeight: 5,
                        backgroundColor: crm.border,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isDone ? const Color(0xFF059669) : crm.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _filterChip(CrmTheme crm, String label, String key) {
    final active = _filter == key;
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: () => setState(() => _filter = key),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: active ? crm.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: active
              ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 1))]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            color: active ? crm.textPrimary : crm.textSecondary,
          ),
        ),
      ),
    );
  }

  // ── Checklist (Right Card) ──────────────────────────────────────────────────
  Widget _buildChecklistCard(CrmTheme crm, Onboarding o) {
    final done = o.doneCount;
    final total = o.tasks.length;
    final isAllDone = total > 0 && done == total;

    return Container(
      decoration: hrCardDecoration(crm),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Checklist',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: crm.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    o.employeeName,
                    style: TextStyle(fontSize: 12, color: crm.textSecondary),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: (isAllDone ? const Color(0xFF059669) : const Color(0xFFD97706)).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '$done / $total',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: isAllDone ? const Color(0xFF059669) : const Color(0xFFD97706),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    icon: Icon(Icons.edit_outlined, size: 18, color: crm.textSecondary),
                    tooltip: 'Edit hire details',
                    onPressed: () => _editOnboarding(context, o),
                    visualDensity: VisualDensity.compact,
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                    tooltip: 'Remove from onboarding',
                    onPressed: () => _deleteOnboarding(context, o),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 8),
          ...List.generate(o.tasks.length, (idx) {
            final t = o.tasks[idx];
            final isDone = t.done;
            final isLast = idx == o.tasks.length - 1;

            String pillLabel;
            Color pillColor;
            Color pillBg;

            if (isDone) {
              pillLabel = 'Done';
              pillColor = const Color(0xFF059669);
              pillBg = const Color(0xFF059669).withValues(alpha: 0.12);
            } else if (isLast) {
              pillLabel = 'Scheduled';
              pillColor = crm.textSecondary;
              pillBg = crm.border.withValues(alpha: 0.5);
            } else {
              pillLabel = 'Pending';
              pillColor = const Color(0xFFD97706);
              pillBg = const Color(0xFFD97706).withValues(alpha: 0.12);
            }

            return InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => _toggleTask(o, idx, !isDone),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: Row(
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: isDone ? const Color(0xFF059669) : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isDone ? const Color(0xFF059669) : crm.border,
                          width: 1.5,
                        ),
                      ),
                      child: isDone
                          ? const Icon(Icons.check, size: 14, color: Colors.white)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        t.title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isDone ? FontWeight.w500 : FontWeight.w600,
                          color: isDone ? crm.textSecondary : crm.textPrimary,
                          decoration: isDone ? TextDecoration.lineThrough : null,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: pillBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        pillLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: pillColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Department: ${o.department.isNotEmpty ? o.department : 'General'}',
                style: TextStyle(fontSize: 11.5, color: crm.textSecondary),
              ),
              if (!isAllDone)
                TextButton.icon(
                  onPressed: () => _markAllTasksDone(o),
                  icon: const Icon(Icons.done_all, size: 15),
                  label: const Text('Mark all done', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(foregroundColor: crm.primary),
                )
              else
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FilledButton.tonalIcon(
                      onPressed: () => context.go('/hr/lms'),
                      icon: const Icon(Icons.school_outlined, size: 14),
                      label: const Text('7-Day Orientation', style: TextStyle(fontSize: 11.5)),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: () => _reopenOnboarding(o),
                      icon: const Icon(Icons.restart_alt, size: 15),
                      label: const Text('Reopen', style: TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(foregroundColor: crm.textSecondary),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Document Collection (Bottom Card) ───────────────────────────────────────
  Widget _buildDocumentCollectionCard(CrmTheme crm, Onboarding o) {
    // If onboarding documents list is empty, supply standard document items
    final docs = o.documents.isNotEmpty
        ? o.documents
        : [
            OnboardingDocument(name: 'Signed offer letter', owner: o.employeeName, required: true, status: 'Received'),
            OnboardingDocument(name: 'Aadhaar & PAN', owner: o.employeeName, required: true, status: 'Received'),
            OnboardingDocument(name: 'Bank account proof', owner: o.employeeName, required: true, status: 'Pending'),
            OnboardingDocument(name: 'Previous experience letter', owner: o.employeeName, required: false, status: 'Not required'),
            OnboardingDocument(name: 'Education certificates', owner: o.employeeName, required: true, status: 'Pending'),
          ];

    return Container(
      decoration: hrCardDecoration(crm),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Document collection',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: crm.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Stored on the employee record · set-password link emailed on day 1',
                    style: TextStyle(fontSize: 12, color: crm.textSecondary),
                  ),
                ],
              ),
              OutlinedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Document reminder emailed to ${o.employeeName}!'),
                      backgroundColor: const Color(0xFF059669),
                    ),
                  );
                },
                icon: const Icon(Icons.send_outlined, size: 14),
                label: const Text('Send reminder', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: crm.textPrimary,
                  side: BorderSide(color: crm.border),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Responsive Table
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: crm.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 700),
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(crm.background),
                  headingTextStyle: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: crm.textSecondary,
                  ),
                  dataRowMinHeight: 48,
                  dataRowMaxHeight: 52,
                  columns: const [
                    DataColumn(label: Text('DOCUMENT')),
                    DataColumn(label: Text('OWNER')),
                    DataColumn(label: Text('REQUIRED')),
                    DataColumn(label: Text('STATUS')),
                    DataColumn(label: Text('ACTION')),
                  ],
                  rows: docs.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final doc = entry.value;

                    Color statusColor;
                    if (doc.status.toLowerCase() == 'received') {
                      statusColor = const Color(0xFF059669);
                    } else if (doc.status.toLowerCase() == 'pending') {
                      statusColor = const Color(0xFFD97706);
                    } else {
                      statusColor = crm.textSecondary;
                    }

                    return DataRow(
                      cells: [
                        DataCell(
                          Text(
                            doc.name,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: crm.textPrimary,
                            ),
                          ),
                        ),
                        DataCell(
                          Text(
                            doc.owner.isNotEmpty ? doc.owner : o.employeeName,
                            style: TextStyle(fontSize: 12.5, color: crm.textPrimary),
                          ),
                        ),
                        DataCell(
                          Text(
                            doc.required ? 'Yes' : 'Optional',
                            style: TextStyle(
                              fontSize: 12,
                              color: doc.required ? crm.textPrimary : crm.textSecondary,
                            ),
                          ),
                        ),
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              doc.status,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: statusColor,
                              ),
                            ),
                          ),
                        ),
                        DataCell(
                          PopupMenuButton<String>(
                            tooltip: 'Change document status',
                            icon: Icon(Icons.more_horiz, size: 18, color: crm.textSecondary),
                            onSelected: (val) => _updateDocStatus(o, idx, docs, val),
                            itemBuilder: (ctx) => [
                              const PopupMenuItem(value: 'Received', child: Text('Mark as Received')),
                              const PopupMenuItem(value: 'Pending', child: Text('Mark as Pending')),
                              const PopupMenuItem(value: 'Not required', child: Text('Mark as Not required')),
                            ],
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyFilterState(CrmTheme crm, String filter) {
    String msg = 'No new hires in this view';
    String sub = 'Try selecting another tab or start onboarding below.';
    if (filter == 'in_progress') {
      msg = 'No ongoing hires right now';
      sub = 'All current new hires have completed day 1 or none are in progress.';
    } else if (filter == 'completed') {
      msg = 'No completed hires yet';
      sub = 'Once a new hire completes all 7 checklist steps, they appear here.';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 50, horizontal: 20),
      decoration: hrCardDecoration(crm),
      child: Column(
        children: [
          Icon(Icons.filter_list_off, size: 42, color: crm.textSecondary),
          const SizedBox(height: 12),
          Text(
            msg,
            style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700, color: crm.textPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            sub,
            style: TextStyle(fontSize: 13, color: crm.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => _startOnboarding(context, ref),
            icon: const Icon(Icons.person_add_alt_1, size: 16),
            label: const Text('Start onboarding'),
            style: FilledButton.styleFrom(backgroundColor: crm.primary),
          ),
        ],
      ),
    );
  }

  // ── Actions & Dialogs ───────────────────────────────────────────────────────
  Future<void> _toggleTask(Onboarding o, int taskIdx, bool done) async {
    final nextTasks = [...o.tasks];
    nextTasks[taskIdx] = nextTasks[taskIdx].copyWith(done: done);
    try {
      await ref.read(onboardingServiceProvider).update(
            o.id,
            tasks: nextTasks,
            status: 'in_progress',
          );
      ref.invalidate(onboardingsProvider);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
    }
  }

  Future<void> _markAllTasksDone(Onboarding o) async {
    final nextTasks = o.tasks.map((t) => t.copyWith(done: true)).toList();
    try {
      await ref.read(onboardingServiceProvider).update(
            o.id,
            tasks: nextTasks,
            status: 'completed',
          );
      ref.invalidate(onboardingsProvider);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
    }
  }

  Future<void> _reopenOnboarding(Onboarding o) async {
    try {
      await ref.read(onboardingServiceProvider).update(o.id, status: 'in_progress');
      ref.invalidate(onboardingsProvider);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
    }
  }

  Future<void> _updateDocStatus(Onboarding o, int docIdx, List<OnboardingDocument> currentDocs, String newStatus) async {
    final nextDocs = [...currentDocs];
    nextDocs[docIdx] = nextDocs[docIdx].copyWith(status: newStatus);
    try {
      await ref.read(onboardingServiceProvider).update(o.id, documents: nextDocs);
      ref.invalidate(onboardingsProvider);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
    }
  }

  void _showTemplatesDialog(BuildContext context, CrmTheme crm) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.playlist_add_check, color: Color(0xFF601A29)),
            const SizedBox(width: 8),
            Text('Standard Onboarding Template', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700)),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Every hired employee is automatically seeded with these 7 milestone steps and 5 compliance document requests:',
                style: TextStyle(fontSize: 12.5, color: crm.textSecondary),
              ),
              const SizedBox(height: 14),
              Text('Checklist steps:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: crm.textPrimary)),
              const SizedBox(height: 6),
              ...[
                '1. Offer letter signed',
                '2. ID & address proof uploaded',
                '3. Welcome email sent',
                '4. Buddy assigned',
                '5. Bank & PF details collected',
                '6. Kit & workstation ready',
                '7. Day-1 orientation booked',
              ].map((s) => Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Text(s, style: TextStyle(fontSize: 12, color: crm.textPrimary)),
                  )),
              const SizedBox(height: 12),
              Text('Required documents:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: crm.textPrimary)),
              const SizedBox(height: 6),
              ...[
                '• Signed offer letter (Required)',
                '• Aadhaar & PAN (Required)',
                '• Bank account proof (Required)',
                '• Previous experience letter (Optional)',
                '• Education certificates (Required)',
              ].map((s) => Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Text(s, style: TextStyle(fontSize: 12, color: crm.textSecondary)),
                  )),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: FilledButton.styleFrom(backgroundColor: crm.primary),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _startOnboarding(BuildContext context, WidgetRef ref) async {
    final employees = await ref.read(employeesProvider.future);
    if (!context.mounted) return;
    final active = employees.where((e) => e.status == 'active').toList();
    String? selected;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDlg) => AlertDialog(
          title: const Text('Start onboarding'),
          content: PersonPickerField(
            label: 'Employee',
            icon: Icons.person_outline,
            selectedId: selected,
            items: active.map((e) => PickerItem(id: e.id, name: e.name, department: e.department ?? '')).toList(),
            onChanged: (v) => setStateDlg(() => selected = v),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
            FilledButton(
              onPressed: selected == null ? null : () => Navigator.of(ctx).pop(true),
              child: const Text('Start'),
            ),
          ],
        ),
      ),
    );

    if (ok == true && selected != null) {
      try {
        await ref.read(onboardingServiceProvider).create(employeeId: selected!);
        ref.invalidate(onboardingsProvider);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
        }
      }
    }
  }

  Future<void> _editOnboarding(BuildContext context, Onboarding o) async {
    final crm = context.crmColors;
    final roleCtrl = TextEditingController(text: o.role);
    final deptCtrl = TextEditingController(text: o.department);
    DateTime? selectedDate = o.joiningDate;
    String selectedStatus = o.status;

    final updated = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: crm.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.edit_outlined, color: crm.primary, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Edit Onboarding', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700)),
                    Text(o.employeeName, style: TextStyle(fontSize: 12, color: crm.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Job Title / Role', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: crm.textPrimary)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: roleCtrl,
                    decoration: InputDecoration(
                      hintText: 'e.g. Project Head, Developer',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text('Department', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: crm.textPrimary)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: deptCtrl,
                    decoration: InputDecoration(
                      hintText: 'e.g. IT, Operations, Marketing',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text('Joining Date', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: crm.textPrimary)),
                  const SizedBox(height: 6),
                  InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2035),
                      );
                      if (picked != null) {
                        setDlgState(() => selectedDate = picked);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: crm.border),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today_outlined, size: 16, color: crm.textSecondary),
                          const SizedBox(width: 8),
                          Text(
                            selectedDate != null
                                ? '${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}'
                                : 'Select joining date',
                            style: TextStyle(fontSize: 13, color: crm.textPrimary),
                          ),
                          const Spacer(),
                          const Icon(Icons.arrow_drop_down, size: 20),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text('Onboarding Status', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: crm.textPrimary)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: selectedStatus,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'in_progress', child: Text('In Progress (Ongoing)')),
                      DropdownMenuItem(value: 'completed', child: Text('Completed (Day 1 Done)')),
                    ],
                    onChanged: (v) {
                      if (v != null) setDlgState(() => selectedStatus = v);
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: FilledButton.styleFrom(backgroundColor: crm.primary),
              child: const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );

    if (updated == true) {
      try {
        await ref.read(onboardingServiceProvider).update(
              o.id,
              role: roleCtrl.text.trim(),
              department: deptCtrl.text.trim(),
              joiningDate: selectedDate,
              status: selectedStatus,
            );
        ref.invalidate(onboardingsProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Onboarding details updated successfully')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(friendlyErrorMessage(e))),
          );
        }
      }
    }
  }

  Future<void> _deleteOnboarding(BuildContext context, Onboarding o) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('Remove from Onboarding?'),
          ],
        ),
        content: Text(
          'Are you sure you want to remove ${o.employeeName} from the new-hire onboarding board?\n\nThis will remove their onboarding checklist and status. Their employee record in Staff Management will remain intact.',
          style: const TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ref.read(onboardingServiceProvider).remove(o.id);
        if (_selectedId == o.id) {
          setState(() => _selectedId = null);
        }
        ref.invalidate(onboardingsProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${o.employeeName} removed from onboarding')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(friendlyErrorMessage(e))),
          );
        }
      }
    }
  }
}
