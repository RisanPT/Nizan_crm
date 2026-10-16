import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/hr/shared/hr_ui.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/auth/access_control.dart';
import 'package:nizan_crm/core/providers/auth_provider.dart';
import 'package:nizan_crm/features/hr/lms/data/lms_models.dart';
import 'package:nizan_crm/features/hr/lms/service/lms_service.dart';
import 'package:nizan_crm/features/hr/lms/presentation/widgets/training_modules_tabs.dart';
import 'package:nizan_crm/services/employee_service.dart';

/// Redesigned HR Learning & Orientation screen matching HRMS_Design.html (#s-training).
/// Includes:
/// 1. Comprehensive 7-Day Job Role Orientation plans with executive Document Mode for HR.
/// 2. Active 7-day orientation timeline tracking with interactive topic checklists & trainer sign-offs.
/// 3. Course catalogue & Enrolment LMS.
/// 4. Role Skill Matrix & development plans.

const kCompanyDepartments = <String>[
  'Technology & Systems (IT)',
  'Bridal Styling',
  'Academy & Training',
  'Studio & Services Ops',
  'Sales & Marketing',
  'Finance & Accounts',
  'HR & People Operations',
  'Fleet & Logistics',
  'Executive / Governance',
];

IconData hrDepartmentIcon(String d) {
  final name = d.toLowerCase();
  if (name.contains('tech') || name.contains('system') || name.contains('it')) return Icons.terminal_rounded;
  if (name.contains('bridal') || name.contains('style')) return Icons.auto_fix_high;
  if (name.contains('academy') || name.contains('train')) return Icons.school_outlined;
  if (name.contains('studio') || name.contains('ops')) return Icons.store_outlined;
  if (name.contains('sale') || name.contains('market')) return Icons.trending_up;
  if (name.contains('finance') || name.contains('account')) return Icons.account_balance_wallet_outlined;
  if (name.contains('hr') || name.contains('people')) return Icons.groups_outlined;
  return Icons.folder_outlined;
}

Color hrDepartmentColor(String d, CrmTheme crm) {
  final name = d.toLowerCase();
  if (name.contains('tech') || name.contains('system') || name.contains('it')) return const Color(0xFF0284C7);
  if (name.contains('bridal') || name.contains('style')) return const Color(0xFF831843);
  if (name.contains('academy') || name.contains('train')) return const Color(0xFF4338CA);
  if (name.contains('studio') || name.contains('ops')) return const Color(0xFFB45309);
  if (name.contains('sale') || name.contains('market')) return const Color(0xFF059669);
  if (name.contains('finance') || name.contains('account')) return const Color(0xFF475569);
  if (name.contains('hr') || name.contains('people')) return const Color(0xFF7C3AED);
  return crm.primary;
}

class HrLmsScreen extends ConsumerStatefulWidget {
  const HrLmsScreen({super.key});

  @override
  ConsumerState<HrLmsScreen> createState() => _HrLmsScreenState();
}

class _HrLmsScreenState extends ConsumerState<HrLmsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _activeTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 8, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index != _activeTabIndex && mounted) {
        setState(() => _activeTabIndex = _tabController.index);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final access = Access.of(ref.watch(authSessionProvider));
    final canManage = access.isFullAccess ||
        access.isDepartmentHead ||
        access.has('lms', false) ||
        access.has('staff', false);

    return Scaffold(
      backgroundColor: crm.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context, crm, canManage),
            const SizedBox(height: 18),
            _buildCustomTabBar(crm),
            const SizedBox(height: 18),
            IndexedStack(
              index: _activeTabIndex,
              children: [
                _OrientationTab(crm: crm, canManage: canManage),
                SyllabusTutorialsTab(crm: crm, canManage: canManage),
                MentorTrainerFlowTab(crm: crm, canManage: canManage),
                EvaluationScoringTab(crm: crm, canManage: canManage),
                QualityIndexTab(crm: crm),
                GalpAmoBundleTab(crm: crm, canManage: canManage),
                _CoursesTab(crm: crm, canManage: canManage),
                _SkillsMatrixTab(crm: crm),
              ],
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // ── Header (Matching .phead in HRMS_Design.html) ────────────────────────────
  Widget _buildHeader(BuildContext context, CrmTheme crm, bool canManage) {
    return LayoutBuilder(
      builder: (ctx, constraints) {
        final isNarrow = constraints.maxWidth < 650;
        final info = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'TRAINING & DEVELOPMENT',
              style: TextStyle(
                fontSize: 11,
                letterSpacing: 0.9,
                fontWeight: FontWeight.w700,
                color: crm.primary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Orientation & skills',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: crm.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '7-day onboarding, role skill matrix and development plans',
              style: TextStyle(fontSize: 13, color: crm.textSecondary),
            ),
          ],
        );

        final actions = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            OutlinedButton.icon(
              onPressed: () => _showSkillCatalogueModal(context, crm),
              icon: const Icon(Icons.menu_book_outlined, size: 16),
              label: const Text('Skill catalogue'),
              style: OutlinedButton.styleFrom(
                foregroundColor: crm.textPrimary,
                side: BorderSide(color: crm.border),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            if (canManage) ...[
              const SizedBox(width: 10),
              FilledButton.icon(
                onPressed: () => _showAssignOrientationModal(context, ref, crm),
                icon: const Icon(Icons.calendar_month_outlined, size: 16),
                label: const Text('Assign orientation'),
                style: FilledButton.styleFrom(
                  backgroundColor: crm.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ],
        );

        if (isNarrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [info, const SizedBox(height: 12), actions],
          );
        }

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [Expanded(child: info), const SizedBox(width: 16), actions],
        );
      },
    );
  }

  // ── Clean Segmented Tab Bar ─────────────────────────────────────────────────
  Widget _buildCustomTabBar(CrmTheme crm) {
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
        physics: const BouncingScrollPhysics(),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _tabPill(crm, 0, 'Orientation Plan', Icons.calendar_today_outlined),
            const SizedBox(width: 4),
            _tabPill(crm, 1, 'Syllabus & Tutorials', Icons.menu_book_rounded),
            const SizedBox(width: 4),
            _tabPill(crm, 2, 'Mentor & Trainer Flow', Icons.people_alt_outlined),
            const SizedBox(width: 4),
            _tabPill(crm, 3, 'Evaluation & Scoring', Icons.fact_check_outlined),
            const SizedBox(width: 4),
            _tabPill(crm, 4, 'Quality Index', Icons.speed_rounded),
            const SizedBox(width: 4),
            _tabPill(crm, 5, 'GALP & AMO Bundles', Icons.military_tech_outlined),
            const SizedBox(width: 4),
            _tabPill(crm, 6, 'Courses & LMS', Icons.school_outlined),
            const SizedBox(width: 4),
            _tabPill(crm, 7, 'Skills Matrix', Icons.auto_awesome_outlined),
          ],
        ),
      ),
    );
  }

  Widget _tabPill(CrmTheme crm, int index, String label, IconData icon) {
    final active = _activeTabIndex == index;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () {
        _tabController.animateTo(index);
        setState(() => _activeTabIndex = index);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: active ? crm.primary.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active ? crm.primary.withValues(alpha: 0.35) : Colors.transparent,
            width: 1.2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: active ? crm.primary : crm.textSecondary),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                color: active ? crm.primary : crm.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSkillCatalogueModal(BuildContext context, CrmTheme crm) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.menu_book, color: Color(0xFF601A29)),
            const SizedBox(width: 8),
            Text('Skill Catalogue & Matrix (FR-3.11)', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700)),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('42 standard organizational competencies across 6 core categories:', style: TextStyle(fontSize: 12.5, color: crm.textSecondary)),
              const SizedBox(height: 14),
              ...[
                '1. Technical & Systems (DevOps, Cloud, CI/CD, Containerization, ITIL)',
                '2. Creative Craftsmanship (Bridal Makeup, Airbrush, Saree Draping, Hair)',
                '3. Client Consultation (Luxury Hospitality, Conflict Resolution, Empathy)',
                '4. Safety & Compliance (Sterilization, OSHA, Data Privacy, First Aid)',
                '5. Business Operations (ERP Billing, Inventory Cycle Counting, POS)',
                '6. Leadership & Mentorship (Peer Pairing, Code Review, Team OKRs)',
              ].map((s) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(s, style: TextStyle(fontSize: 12, color: crm.textPrimary)),
                  )),
            ],
          ),
        ),
        actions: [
          FilledButton(onPressed: () => Navigator.of(ctx).pop(), style: FilledButton.styleFrom(backgroundColor: crm.primary), child: const Text('Close')),
        ],
      ),
    );
  }

  Future<void> _showAssignOrientationModal(BuildContext context, WidgetRef ref, CrmTheme crm) async {
    final employees = await ref.read(employeesProvider.future);
    final plans = await ref.read(orientationPlansProvider.future);
    if (!context.mounted) return;

    String? selectedEmpId;
    String? selectedPlanId = plans.isNotEmpty ? plans.first.id : null;
    final trainerCtrl = TextEditingController(text: 'Department Lead');

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: Text('Assign 1-Week Orientation', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700)),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Select employee:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: crm.textPrimary)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: selectedEmpId,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  hint: const Text('Choose employee'),
                  items: employees.map((e) => DropdownMenuItem(value: e.id, child: Text('${e.name} (${e.role ?? 'Staff'})'))).toList(),
                  onChanged: (v) => setDlg(() => selectedEmpId = v),
                ),
                const SizedBox(height: 14),
                Text('Select Job Role Plan:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: crm.textPrimary)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: selectedPlanId,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  items: plans.map((p) => DropdownMenuItem(value: p.id, child: Text('${p.roleTitle} (${p.department})'))).toList(),
                  onChanged: (v) => setDlg(() => selectedPlanId = v),
                ),
                const SizedBox(height: 14),
                Text('Trainer / Mentor Name:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: crm.textPrimary)),
                const SizedBox(height: 6),
                TextField(
                  controller: trainerCtrl,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
            FilledButton(
              onPressed: selectedEmpId == null ? null : () => Navigator.of(ctx).pop(true),
              style: FilledButton.styleFrom(backgroundColor: crm.primary),
              child: const Text('Assign Plan'),
            ),
          ],
        ),
      ),
    );

    if (ok == true && selectedEmpId != null) {
      try {
        await ref.read(lmsServiceProvider).assignOrientation(
              employeeId: selectedEmpId!,
              planId: selectedPlanId,
              trainerName: trainerCtrl.text.trim(),
            );
        ref.invalidate(activeOrientationsProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Orientation plan assigned successfully!')));
        }
      } catch (e) {
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
      }
    }
  }
}

// =============================================================================
// TAB 1: ORIENTATION (1-WEEK PLAN AS DOC & REAL-TIME PROGRESS TRACKER)
// =============================================================================
class _OrientationTab extends ConsumerStatefulWidget {
  const _OrientationTab({required this.crm, required this.canManage});
  final CrmTheme crm;
  final bool canManage;

  @override
  ConsumerState<_OrientationTab> createState() => _OrientationTabState();
}

class _OrientationTabState extends ConsumerState<_OrientationTab> {
  String? _selectedAssignmentId;
  int? _inspectedDayNumber;

  @override
  Widget build(BuildContext context) {
    final activeAsync = ref.watch(activeOrientationsProvider);
    final plansAsync = ref.watch(orientationPlansProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Active Orientation Tracker (Day 1 - 7 Cards)
        activeAsync.when(
          loading: () => const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator())),
          error: (e, _) => AppErrorView(error: e, onRetry: () => ref.invalidate(activeOrientationsProvider)),
          data: (assignments) {
            if (assignments.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(24),
                decoration: hrCardDecoration(widget.crm),
                child: Center(
                  child: Text('No active orientations in progress.', style: TextStyle(color: widget.crm.textSecondary)),
                ),
              );
            }

            final current = assignments.firstWhere(
              (a) => a.id == _selectedAssignmentId,
              orElse: () => assignments.first,
            );

            return _buildActiveOrientationCard(context, ref, current, assignments);
          },
        ),

        const SizedBox(height: 18),

        // 2. Role-Based 1-Week Orientation Plans (Doc Mode & Editor for HR)
        plansAsync.when(
          loading: () => const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator())),
          error: (e, _) => AppErrorView(error: e, onRetry: () => ref.invalidate(orientationPlansProvider)),
          data: (plans) => _buildOrientationPlansSection(context, ref, plans),
        ),

        const SizedBox(height: 18),

        // 3. Orientations In Progress Table
        activeAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (e, st) => const SizedBox.shrink(),
          data: (assignments) => _buildOrientationsTable(context, assignments),
        ),
      ],
    );
  }

  // ── Active Orientation Card (Matches HTML 1969-1983) ────────────────────────
  Widget _buildActiveOrientationCard(
    BuildContext context,
    WidgetRef ref,
    OrientationAssignment a,
    List<OrientationAssignment> allAssignments,
  ) {
    final crm = widget.crm;
    final signedCount = a.signedOffCount;
    final total = a.days.length;

    // Selected inspected day (defaults to current active day)
    final activeDayNum = _inspectedDayNumber ?? a.currentDay;
    final inspectedDay = a.days.firstWhere(
      (d) => d.dayNumber == activeDayNum,
      orElse: () => a.days.first,
    );

    return Container(
      decoration: hrCardDecoration(crm),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Trainee Switcher Pills (If multiple active enrollments)
          if (allAssignments.length > 1) ...[
            Row(
              children: [
                Text(
                  'ACTIVE TRAINEES:',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: crm.textSecondary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: allAssignments.map((asgn) {
                        final isSelected = asgn.id == a.id;
                        final isComplete = asgn.signedOffCount == asgn.days.length;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () => setState(() {
                              _selectedAssignmentId = asgn.id;
                              _inspectedDayNumber = asgn.currentDay;
                            }),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                              decoration: BoxDecoration(
                                color: isSelected ? crm.primary : crm.surface,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isSelected ? crm.primary : crm.border,
                                  width: isSelected ? 1.5 : 1.0,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.person_pin,
                                    size: 14,
                                    color: isSelected ? Colors.white : crm.textSecondary,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    asgn.employeeName,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                                      color: isSelected ? Colors.white : crm.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? Colors.white.withValues(alpha: 0.22)
                                          : (isComplete
                                              ? const Color(0xFF059669).withValues(alpha: 0.12)
                                              : const Color(0xFFD97706).withValues(alpha: 0.12)),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      isComplete ? 'Certified' : 'Day ${asgn.currentDay}/$total',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: isSelected
                                            ? Colors.white
                                            : (isComplete ? const Color(0xFF059669) : const Color(0xFFD97706)),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 14),
          ],

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Active orientation · ${a.roleTitle}',
                          style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w800, color: crm.textPrimary),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: crm.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            a.department,
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: crm.primary),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Trainee: ${a.employeeName} · Assigned Mentor: ${a.trainerName} · 7-Day Plan',
                      style: TextStyle(fontSize: 12.5, color: crm.textSecondary),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: (signedCount == total ? const Color(0xFF059669) : const Color(0xFFD97706)).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      signedCount == total ? Icons.check_circle : Icons.schedule,
                      size: 14,
                      color: signedCount == total ? const Color(0xFF059669) : const Color(0xFFD97706),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      signedCount == total ? 'Fully Certified' : 'Day ${a.currentDay} of $total',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: signedCount == total ? const Color(0xFF059669) : const Color(0xFFD97706),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Progress Bar with Certified Count
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Certification progress: $signedCount of $total days certified (${total == 0 ? 0 : ((signedCount / total) * 100).round()}%)',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: crm.textSecondary),
              ),
              Text(
                'Mandatory trainer sign-off required for each day',
                style: TextStyle(fontSize: 11, color: crm.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: total == 0 ? 0 : signedCount / total,
              minHeight: 6,
              backgroundColor: crm.border,
              valueColor: AlwaysStoppedAnimation<Color>(
                signedCount == total ? const Color(0xFF059669) : crm.primary,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 7-Day Timeline Cards Grid
          LayoutBuilder(
            builder: (ctx, constraints) {
              final w = constraints.maxWidth;
              final cols = w >= 900 ? 7 : (w >= 520 ? 4 : 2);
              final itemW = (w - (cols - 1) * 8) / cols;

              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: a.days.map((d) {
                  final isSigned = d.signedOff;
                  final isCurrent = d.dayNumber == a.currentDay && !isSigned;
                  final isSelected = d.dayNumber == activeDayNum;

                  Color bg;
                  Color border;
                  Color chipBg;
                  Color chipColor;
                  String chipText;
                  IconData icon;

                  if (isSigned) {
                    bg = const Color(0xFF059669).withValues(alpha: 0.08);
                    border = const Color(0xFF059669).withValues(alpha: 0.40);
                    chipBg = const Color(0xFF059669).withValues(alpha: 0.15);
                    chipColor = const Color(0xFF059669);
                    chipText = 'Signed';
                    icon = Icons.check_circle;
                  } else if (isCurrent) {
                    bg = const Color(0xFFD97706).withValues(alpha: 0.10);
                    border = const Color(0xFFD97706).withValues(alpha: 0.55);
                    chipBg = const Color(0xFFD97706).withValues(alpha: 0.20);
                    chipColor = const Color(0xFFD97706);
                    chipText = 'In progress';
                    icon = Icons.play_circle_fill;
                  } else {
                    bg = crm.background;
                    border = crm.border;
                    chipBg = crm.border.withValues(alpha: 0.5);
                    chipColor = crm.textSecondary;
                    chipText = d.dayNumber > a.currentDay ? 'Upcoming' : 'Pending';
                    icon = Icons.radio_button_unchecked;
                  }

                  return InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => setState(() => _inspectedDayNumber = d.dayNumber),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: itemW,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected ? border.withValues(alpha: 0.16) : bg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected ? crm.primary : border,
                          width: isSelected ? 2.0 : 1.0,
                        ),
                        boxShadow: isSelected
                            ? [BoxShadow(color: crm.primary.withValues(alpha: 0.18), blurRadius: 6, offset: const Offset(0, 2))]
                            : null,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(icon, size: 13, color: chipColor),
                              const SizedBox(width: 4),
                              Text('Day ${d.dayNumber}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: crm.textPrimary)),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Text(
                            d.title,
                            style: TextStyle(fontSize: 10.5, color: crm.textSecondary, height: 1.25),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: chipBg, borderRadius: BorderRadius.circular(999)),
                            child: Text(chipText, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: chipColor)),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),

          const SizedBox(height: 16),

          // ── In-Card Inspector for the Selected Day ─────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: crm.background,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: crm.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: crm.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'DAY ${inspectedDay.dayNumber}',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: crm.primary),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              inspectedDay.title,
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: crm.textPrimary),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (widget.canManage)
                      if (!inspectedDay.signedOff)
                        FilledButton.icon(
                          onPressed: () => _toggleDaySignOff(a, inspectedDay.dayNumber, true),
                          icon: const Icon(Icons.check, size: 14),
                          label: const Text('Sign off this day', style: TextStyle(fontSize: 11.5)),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF059669),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            visualDensity: VisualDensity.compact,
                          ),
                        )
                      else
                        OutlinedButton.icon(
                          onPressed: () => _toggleDaySignOff(a, inspectedDay.dayNumber, false),
                          icon: const Icon(Icons.close, size: 14),
                          label: const Text('Revoke sign-off', style: TextStyle(fontSize: 11.5)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFDC2626),
                            side: BorderSide(color: const Color(0xFFDC2626).withValues(alpha: 0.4)),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                  ],
                ),
                const SizedBox(height: 10),
                Text('Job-Specific Learning Checkpoints & Tasks:', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: crm.textSecondary)),
                const SizedBox(height: 6),
                ...inspectedDay.topics.map((t) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          inspectedDay.signedOff ? Icons.check_circle : Icons.circle_outlined,
                          size: 14,
                          color: inspectedDay.signedOff ? const Color(0xFF059669) : crm.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            t,
                            style: TextStyle(fontSize: 12.5, color: crm.textPrimary, height: 1.3),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                if (inspectedDay.signedOff) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF059669).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.verified, size: 15, color: Color(0xFF059669)),
                        const SizedBox(width: 6),
                        Text(
                          'Certified by ${inspectedDay.signedOffBy.isNotEmpty ? inspectedDay.signedOffBy : a.trainerName} · Completed',
                          style: const TextStyle(fontSize: 11.5, color: Color(0xFF059669), fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Sign-off compliance banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: (signedCount == total ? const Color(0xFF059669) : const Color(0xFFD97706)).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: (signedCount == total ? const Color(0xFF059669) : const Color(0xFFD97706)).withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  signedCount == total ? Icons.celebration_outlined : Icons.verified_user_outlined,
                  size: 16,
                  color: signedCount == total ? const Color(0xFF059669) : const Color(0xFFD97706),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    signedCount == total
                        ? '🎉 7-Day Orientation Certified! ${a.employeeName} has completed all required job training checkpoints and is certified for production.'
                        : 'Orientation cannot be marked complete until every mandatory topic carries a trainer sign-off ($signedCount of $total days certified).',
                    style: TextStyle(
                      fontSize: 12,
                      color: signedCount == total ? const Color(0xFF059669) : const Color(0xFFD97706),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Role-Based 1-Week Plans & Doc Mode (Matches HTML 1984-2002) ─────────────
  Widget _buildOrientationPlansSection(BuildContext context, WidgetRef ref, List<OrientationPlan> plans) {
    final crm = widget.crm;

    // Group plans by department (merging IT into Technology & Systems (IT))
    final grouped = <String, List<OrientationPlan>>{};
    for (final p in plans) {
      String d = p.department.trim();
      if (d == 'Technology & Systems' || d == 'IT') {
        d = 'Technology & Systems (IT)';
      }
      grouped.putIfAbsent(d, () => []).add(p);
    }

    // Helper for department visual styling
    IconData deptIcon(String d) {
      final name = d.toLowerCase();
      if (name.contains('tech') || name.contains('system')) return Icons.terminal_rounded;
      if (name.contains('bridal') || name.contains('style')) return Icons.auto_fix_high;
      if (name.contains('academy') || name.contains('training')) return Icons.school_outlined;
      if (name.contains('studio') || name.contains('ops')) return Icons.store_outlined;
      if (name.contains('sales') || name.contains('market')) return Icons.trending_up;
      if (name.contains('finance') || name.contains('account')) return Icons.account_balance_wallet_outlined;
      return Icons.folder_outlined;
    }

    Color deptColor(String d) {
      final name = d.toLowerCase();
      if (name.contains('tech') || name.contains('system')) return const Color(0xFF0284C7);
      if (name.contains('bridal') || name.contains('style')) return const Color(0xFF831843);
      if (name.contains('academy') || name.contains('training')) return const Color(0xFF4338CA);
      if (name.contains('studio') || name.contains('ops')) return const Color(0xFFB45309);
      if (name.contains('sales') || name.contains('market')) return const Color(0xFF059669);
      if (name.contains('finance') || name.contains('account')) return const Color(0xFF475569);
      return crm.primary;
    }

    return Container(
      decoration: hrCardDecoration(crm),
      padding: const EdgeInsets.all(20),
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
                    'Orientation plans by job role',
                    style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w800, color: crm.textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Comprehensive 7-day job-related syllabi organised by department → role hierarchy (FR-3.2, FR-3.4)',
                    style: TextStyle(fontSize: 12, color: crm.textSecondary),
                  ),
                ],
              ),
              if (widget.canManage)
                OutlinedButton.icon(
                  onPressed: () => _editPlanDialog(context, ref, null),
                  icon: const Icon(Icons.create_new_folder_outlined, size: 15),
                  label: const Text('New plan doc', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: crm.primary,
                    side: BorderSide(color: crm.border),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Department Trees with custom styling
          ...grouped.entries.map((entry) {
            final dept = entry.key;
            final deptPlans = entry.value;
            final color = deptColor(dept);
            final icon = deptIcon(dept);

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: crm.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: crm.border),
              ),
              child: ExpansionTile(
                initiallyExpanded: true,
                tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 18, color: color),
                ),
                title: Row(
                  children: [
                    Text(
                      dept,
                      style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700, color: crm.textPrimary),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: color.withValues(alpha: 0.25)),
                      ),
                      child: Text(
                        '${deptPlans.length} roles',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
                      ),
                    ),
                  ],
                ),
                children: deptPlans.map((plan) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: crm.border.withValues(alpha: 0.5))),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.badge_outlined, size: 16, color: color),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                plan.roleTitle,
                                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: crm.textPrimary),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '7-day structured training · Lead Mentor: ${plan.trainerName}',
                                style: TextStyle(fontSize: 11.5, color: crm.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        // Quick Assign Action
                        if (widget.canManage) ...[
                          OutlinedButton.icon(
                            onPressed: () => _showAssignPlanToEmployeeModal(context, ref, plan),
                            icon: const Icon(Icons.person_add_alt_outlined, size: 13),
                            label: const Text('Assign', style: TextStyle(fontSize: 11.5)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: crm.textPrimary,
                              side: BorderSide(color: crm.border),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        // View Plan as Doc Button
                        FilledButton.tonalIcon(
                          onPressed: () => _openPlanDocViewer(context, plan),
                          icon: const Icon(Icons.description_outlined, size: 14),
                          label: const Text('Doc mode', style: TextStyle(fontSize: 11.5)),
                          style: FilledButton.styleFrom(
                            backgroundColor: color.withValues(alpha: 0.12),
                            foregroundColor: color,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                        if (widget.canManage) ...[
                          const SizedBox(width: 6),
                          IconButton(
                            icon: Icon(Icons.edit_outlined, size: 16, color: crm.textSecondary),
                            tooltip: 'Edit 7-Day Syllabus',
                            onPressed: () => _editPlanDialog(context, ref, plan),
                          ),
                        ],
                      ],
                    ),
                  );
                }).toList(),
              ),
            );
          }),
        ],
      ),
    );
  }

  Future<void> _showAssignPlanToEmployeeModal(BuildContext context, WidgetRef ref, OrientationPlan plan) async {
    final employees = await ref.read(employeesProvider.future);
    if (!context.mounted) return;
    final crm = widget.crm;

    String? selectedEmpId;
    final trainerCtrl = TextEditingController(text: plan.trainerName.isNotEmpty ? plan.trainerName : 'Department Lead');

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.assignment_ind_outlined, color: Color(0xFF601A29)),
              const SizedBox(width: 8),
              Text('Assign ${plan.roleTitle}', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700)),
            ],
          ),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Enroll an employee into this 7-day orientation syllabus:', style: TextStyle(fontSize: 12.5, color: crm.textSecondary)),
                const SizedBox(height: 14),
                Text('Select employee:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: crm.textPrimary)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: selectedEmpId,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  hint: const Text('Choose employee to enroll'),
                  items: employees.map((e) => DropdownMenuItem(value: e.id, child: Text('${e.name} (${e.role ?? 'Staff'})'))).toList(),
                  onChanged: (v) => setDlg(() => selectedEmpId = v),
                ),
                const SizedBox(height: 14),
                Text('Assigned Mentor / Lead Trainer:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: crm.textPrimary)),
                const SizedBox(height: 6),
                TextField(
                  controller: trainerCtrl,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
            FilledButton(
              onPressed: selectedEmpId == null ? null : () => Navigator.of(ctx).pop(true),
              style: FilledButton.styleFrom(backgroundColor: crm.primary),
              child: const Text('Enroll & Start Day 1'),
            ),
          ],
        ),
      ),
    );

    if (ok == true && selectedEmpId != null) {
      try {
        await ref.read(lmsServiceProvider).assignOrientation(
              employeeId: selectedEmpId!,
              planId: plan.id,
              trainerName: trainerCtrl.text.trim(),
            );
        ref.invalidate(activeOrientationsProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Assigned ${plan.roleTitle} 7-day orientation successfully!')));
        }
      } catch (e) {
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
      }
    }
  }

  // ── Orientations In Progress Table (Matches HTML 2003-2014) ─────────────────
  Widget _buildOrientationsTable(BuildContext context, List<OrientationAssignment> list) {
    final crm = widget.crm;
    return Container(
      decoration: hrCardDecoration(crm),
      padding: const EdgeInsets.all(18),
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
                    'Orientations in progress',
                    style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w800, color: crm.textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text('Days elapsed, topics outstanding · click to inspect in active tracker (FR-3.9)', style: TextStyle(fontSize: 12, color: crm.textSecondary)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF059669).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text('${list.length} active', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF059669))),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: crm.border)),
            clipBehavior: Clip.antiAlias,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(crm.background),
              columns: const [
                DataColumn(label: Text('TRAINEE')),
                DataColumn(label: Text('ROLE / PLAN')),
                DataColumn(label: Text('DAY')),
                DataColumn(label: Text('OUTSTANDING')),
                DataColumn(label: Text('STATUS')),
              ],
              rows: list.map((a) {
                final outstanding = a.days.where((d) => !d.signedOff).length;
                Color stColor = const Color(0xFF059669);
                if (a.status == 'Due today') stColor = const Color(0xFFD97706);
                if (a.status == 'Overdue') stColor = const Color(0xFFDC2626);

                return DataRow(
                  onSelectChanged: (_) {
                    setState(() {
                      _selectedAssignmentId = a.id;
                      _inspectedDayNumber = a.currentDay;
                    });
                  },
                  cells: [
                    DataCell(Text(a.employeeName, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: crm.textPrimary))),
                    DataCell(Text(a.roleTitle, style: TextStyle(fontSize: 12.5, color: crm.textPrimary))),
                    DataCell(Text('${a.currentDay} / ${a.totalDays}', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600))),
                    DataCell(Text('$outstanding topics', style: TextStyle(fontSize: 12, color: crm.textSecondary))),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: stColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
                        child: Text(a.status, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: stColor)),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ── Document Mode Viewer (1-Week Plan as Formal Doc) ─────────────────────────
  void _openPlanDocViewer(BuildContext context, OrientationPlan plan) {
    final crm = widget.crm;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 760,
          constraints: const BoxConstraints(maxHeight: 740),
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: crm.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                    child: Icon(Icons.article_outlined, color: crm.primary, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${plan.roleTitle} — 1-Week Orientation Plan',
                          style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w800, color: crm.textPrimary),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Department: ${plan.department} · Mentor: ${plan.trainerName} · Duration: 7 Days',
                          style: TextStyle(fontSize: 12, color: crm.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  IconButton(onPressed: () => Navigator.of(ctx).pop(), icon: const Icon(Icons.close)),
                ],
              ),
              const Divider(height: 28),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: crm.background,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: crm.border),
                        ),
                        child: Text(
                          plan.overview,
                          style: TextStyle(fontSize: 13, color: crm.textPrimary, height: 1.45),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text('7-Day Detailed Syllabus & Objectives:', style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700, color: crm.textPrimary)),
                      const SizedBox(height: 12),
                      ...plan.days.map((d) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: crm.surface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: crm.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(color: crm.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                                    child: Text('DAY ${d.dayNumber}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: crm.primary)),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(child: Text(d.title, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: crm.textPrimary))),
                                  if (d.mandatorySignOff)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(color: const Color(0xFFD97706).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
                                      child: const Text('Sign-off Required', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFFD97706))),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              ...d.topics.map((t) => Padding(
                                    padding: const EdgeInsets.only(left: 4, top: 4),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
                                        Expanded(child: Text(t, style: TextStyle(fontSize: 12.5, color: crm.textSecondary, height: 1.3))),
                                      ],
                                    ),
                                  )),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Document exported / ready for printing!')));
                      Navigator.of(ctx).pop();
                    },
                    icon: const Icon(Icons.print_outlined, size: 16),
                    label: const Text('Print / Export PDF'),
                  ),
                  if (widget.canManage) ...[
                    const SizedBox(width: 10),
                    FilledButton.icon(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        _showAssignPlanToEmployeeModal(context, ref, plan);
                      },
                      icon: const Icon(Icons.assignment_ind_outlined, size: 16),
                      label: const Text('Assign to Trainee'),
                      style: FilledButton.styleFrom(backgroundColor: crm.primary),
                    ),
                  ],
                  const SizedBox(width: 10),
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Close Document'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _toggleDaySignOff(OrientationAssignment a, int dayNum, bool signed) async {
    try {
      final nextDays = a.days.map((d) {
        if (d.dayNumber == dayNum) {
          return OrientationDayProgress(
            dayNumber: d.dayNumber,
            title: d.title,
            topics: d.topics,
            signedOff: signed,
            signedOffBy: signed ? 'Trainer' : '',
            signedOffAt: signed ? DateTime.now() : null,
            status: signed ? 'Signed' : 'In progress',
          );
        }
        return d;
      }).toList();

      // Determine next active day
      int nextCurrentDay = a.currentDay;
      if (signed && dayNum >= a.currentDay && dayNum < 7) {
        nextCurrentDay = dayNum + 1;
      }

      await ref.read(lmsServiceProvider).updateOrientationProgress(
            a.id,
            signOffDay: dayNum,
            signedOff: signed,
            currentDay: nextCurrentDay,
            days: nextDays.map((d) => {
              'dayNumber': d.dayNumber,
              'title': d.title,
              'topics': d.topics,
              'signedOff': d.signedOff,
              'signedOffBy': d.signedOffBy,
              'signedOffAt': d.signedOffAt?.toIso8601String(),
              'status': d.status,
            }).toList(),
          );
      ref.invalidate(activeOrientationsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(signed ? 'Day $dayNum certified and signed off!' : 'Day $dayNum reopened.')),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
    }
  }

  Future<void> _editPlanDialog(BuildContext context, WidgetRef ref, OrientationPlan? plan) async {
    final crm = widget.crm;
    final isNew = plan == null;
    final roleCtrl = TextEditingController(text: plan?.roleTitle ?? '');
    String initialDept = plan?.department.trim() ?? 'Technology & Systems (IT)';
    if (initialDept == 'Technology & Systems' || initialDept == 'IT' || initialDept.isEmpty) {
      initialDept = 'Technology & Systems (IT)';
    }
    if (!kCompanyDepartments.contains(initialDept)) {
      initialDept = 'Technology & Systems (IT)';
    }
    String selectedDept = initialDept;
    final trainerCtrl = TextEditingController(text: plan?.trainerName ?? 'Department Lead');
    final overviewCtrl = TextEditingController(text: plan?.overview ?? '');

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: Text(isNew ? 'New 1-Week Orientation Plan' : 'Edit Orientation Plan', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700)),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Job Role Title:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: crm.textPrimary)),
                  const SizedBox(height: 6),
                  TextField(controller: roleCtrl, decoration: InputDecoration(hintText: 'e.g. Senior Dev-ops engineer', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)))),
                  const SizedBox(height: 12),
                  Text('Department (Hierarchy):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: crm.textPrimary)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: selectedDept,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    items: kCompanyDepartments.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                    onChanged: (v) => setDlg(() => selectedDept = v ?? selectedDept),
                  ),
                  const SizedBox(height: 12),
                  Text('Lead Trainer / Mentor:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: crm.textPrimary)),
                  const SizedBox(height: 6),
                  TextField(controller: trainerCtrl, decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)))),
                  const SizedBox(height: 12),
                  Text('Document Overview & Purpose:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: crm.textPrimary)),
                  const SizedBox(height: 6),
                  TextField(controller: overviewCtrl, maxLines: 3, decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)))),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: FilledButton.styleFrom(backgroundColor: crm.primary),
              child: Text(isNew ? 'Create Plan' : 'Save Plan'),
            ),
          ],
        ),
      ),
    );

    if (ok == true && roleCtrl.text.trim().isNotEmpty) {
      try {
        final body = {
          'roleTitle': roleCtrl.text.trim(),
          'department': selectedDept,
          'trainerName': trainerCtrl.text.trim(),
          'overview': overviewCtrl.text.trim(),
        };
        await ref.read(lmsServiceProvider).saveOrientationPlan(body, id: plan?.id);
        ref.invalidate(orientationPlansProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Orientation plan saved!')));
        }
      } catch (e) {
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
      }
    }
  }
}

// =============================================================================
// TAB 2: COURSES & LMS
// =============================================================================
class _CoursesTab extends ConsumerStatefulWidget {
  const _CoursesTab({required this.crm, required this.canManage});
  final CrmTheme crm;
  final bool canManage;

  @override
  ConsumerState<_CoursesTab> createState() => _CoursesTabState();
}

class _CoursesTabState extends ConsumerState<_CoursesTab> {
  String _selectedDept = "All";

  @override
  Widget build(BuildContext context) {
    final crm = widget.crm;
    final coursesAsync = ref.watch(coursesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Course Catalogue by Department",
                  style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w800, color: crm.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  "Structured learning modules categorized under organizational hierarchy & departments",
                  style: TextStyle(fontSize: 12, color: crm.textSecondary),
                ),
              ],
            ),
            if (widget.canManage)
              FilledButton.icon(
                onPressed: () => _editCourseDialog(context, null),
                icon: const Icon(Icons.add, size: 16),
                label: const Text("New course"),
                style: FilledButton.styleFrom(backgroundColor: crm.primary),
              ),
          ],
        ),
        const SizedBox(height: 16),
        coursesAsync.when(
          loading: () => const Center(child: Padding(padding: EdgeInsets.all(30), child: CircularProgressIndicator())),
          error: (e, _) => AppErrorView(error: e, onRetry: () => ref.invalidate(coursesProvider)),
          data: (courses) {
            if (courses.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(40),
                decoration: hrCardDecoration(crm),
                child: Center(child: Text("No courses available yet.", style: TextStyle(color: crm.textSecondary))),
              );
            }

            // Group courses by normalized department
            final grouped = <String, List<Course>>{};
            for (final c in courses) {
              String d = c.department.trim();
              if (d.isEmpty || d == "Technology & Systems" || d == "IT") {
                d = "Technology & Systems (IT)";
              }
              grouped.putIfAbsent(d, () => []).add(c);
            }

            // Department filter chips
            final deptsWithCourses = grouped.keys.toList()..sort();
            final allDeptChips = ["All", ...deptsWithCourses];

            final visibleEntries = grouped.entries.where((e) => _selectedDept == "All" || e.key == _selectedDept).toList();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Department filter pills
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: allDeptChips.map((deptName) {
                      final isSelected = _selectedDept == deptName;
                      final count = deptName == "All" ? courses.length : (grouped[deptName]?.length ?? 0);
                      final col = deptName == "All" ? crm.primary : hrDepartmentColor(deptName, crm);

                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          selected: isSelected,
                          showCheckmark: false,
                          avatar: deptName == "All"
                              ? null
                              : Icon(hrDepartmentIcon(deptName), size: 14, color: isSelected ? Colors.white : col),
                          label: Text("$deptName ($count)", style: TextStyle(fontSize: 11.5, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500)),
                          labelStyle: TextStyle(color: isSelected ? Colors.white : crm.textPrimary),
                          selectedColor: col,
                          backgroundColor: crm.surface,
                          side: BorderSide(color: isSelected ? col : crm.border),
                          onSelected: (_) => setState(() => _selectedDept = deptName),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 16),

                // Department Trees / Accordions
                if (visibleEntries.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: hrCardDecoration(crm),
                    child: Center(child: Text("No courses found for this department.", style: TextStyle(color: crm.textSecondary))),
                  )
                else
                  ...visibleEntries.map((entry) {
                    final deptName = entry.key;
                    final deptCourses = entry.value;
                    final col = hrDepartmentColor(deptName, crm);
                    final icon = hrDepartmentIcon(deptName);
                    final totalHours = deptCourses.fold<double>(0, (sum, c) => sum + c.durationHours).toInt();

                    return Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: crm.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: crm.border),
                      ),
                      child: ExpansionTile(
                        initiallyExpanded: true,
                        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        leading: Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: col.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(icon, size: 18, color: col),
                        ),
                        title: Row(
                          children: [
                            Text(
                              deptName,
                              style: GoogleFonts.plusJakartaSans(fontSize: 14.5, fontWeight: FontWeight.w700, color: crm.textPrimary),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: col.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: col.withValues(alpha: 0.25)),
                              ),
                              child: Text(
                                "${deptCourses.length} modules · ${totalHours}h total",
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: col),
                              ),
                            ),
                          ],
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: LayoutBuilder(
                              builder: (ctx, constraints) {
                                final w = constraints.maxWidth;
                                final cols = w >= 960 ? 3 : (w >= 600 ? 2 : 1);
                                final itemW = (w - (cols - 1) * 14) / cols;

                                return Wrap(
                                  spacing: 14,
                                  runSpacing: 14,
                                  children: deptCourses.map((c) {
                                    return Container(
                                      width: itemW,
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: crm.background,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: crm.border.withValues(alpha: 0.7)),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                decoration: BoxDecoration(color: col.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                                                child: Text(courseCategoryLabel(c.category), style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: col)),
                                              ),
                                              Text("${c.durationHours.toInt()}h", style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: crm.textSecondary)),
                                            ],
                                          ),
                                          const SizedBox(height: 10),
                                          Text(c.title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: crm.textPrimary)),
                                          if (c.targetRole.isNotEmpty) ...[
                                            const SizedBox(height: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: crm.border.withValues(alpha: 0.3),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(Icons.person_pin_outlined, size: 12, color: crm.textSecondary),
                                                  const SizedBox(width: 4),
                                                  Flexible(
                                                    child: Text(
                                                      "Target: ${c.targetRole}",
                                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: crm.textSecondary),
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                          const SizedBox(height: 8),
                                          Text(c.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: crm.textSecondary)),
                                          const SizedBox(height: 14),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              OutlinedButton(
                                                onPressed: () async {
                                                  try {
                                                    await ref.read(lmsServiceProvider).enroll(c.id);
                                                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Enrolled in course!")));
                                                  } catch (e) {
                                                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
                                                  }
                                                },
                                                style: OutlinedButton.styleFrom(
                                                  side: BorderSide(color: crm.border),
                                                  visualDensity: VisualDensity.compact,
                                                ),
                                                child: const Text("Enrol", style: TextStyle(fontSize: 12)),
                                              ),
                                              if (widget.canManage)
                                                Row(
                                                  children: [
                                                    IconButton(
                                                      icon: const Icon(Icons.edit_outlined, size: 16),
                                                      tooltip: "Edit Course",
                                                      onPressed: () => _editCourseDialog(context, c),
                                                    ),
                                                    IconButton(
                                                      icon: const Icon(Icons.delete_outline, size: 16),
                                                      tooltip: "Delete Course",
                                                      onPressed: () async {
                                                        await ref.read(lmsServiceProvider).deleteCourse(c.id);
                                                        ref.invalidate(coursesProvider);
                                                      },
                                                    ),
                                                  ],
                                                ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            );
          },
        ),
      ],
    );
  }

  Future<void> _editCourseDialog(BuildContext context, Course? c) async {
    final crm = widget.crm;
    final titleCtrl = TextEditingController(text: c?.title ?? "");
    final descCtrl = TextEditingController(text: c?.description ?? "");
    final roleCtrl = TextEditingController(text: c?.targetRole ?? "");
    String cat = c?.category ?? "skills";
    String initialDept = c?.department.trim() ?? "Technology & Systems (IT)";
    if (initialDept == "Technology & Systems" || initialDept == "IT" || initialDept.isEmpty) {
      initialDept = "Technology & Systems (IT)";
    }
    if (!kCompanyDepartments.contains(initialDept)) {
      initialDept = "Technology & Systems (IT)";
    }
    String selectedDept = initialDept;
    final durCtrl = TextEditingController(text: c != null ? "${c.durationHours}" : "8");

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: Text(c == null ? "New Course" : "Edit Course", style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700)),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: "Course Title")),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedDept,
                    decoration: const InputDecoration(labelText: "Department (Hierarchy)"),
                    items: kCompanyDepartments.map((k) => DropdownMenuItem(value: k, child: Text(k))).toList(),
                    onChanged: (v) => setDlg(() => selectedDept = v ?? selectedDept),
                  ),
                  const SizedBox(height: 12),
                  TextField(controller: roleCtrl, decoration: const InputDecoration(labelText: "Target Job Role (e.g. Senior Dev-ops engineer)")),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: cat,
                    decoration: const InputDecoration(labelText: "Category"),
                    items: kCourseCategories.map((k) => DropdownMenuItem(value: k, child: Text(courseCategoryLabel(k)))).toList(),
                    onChanged: (v) => setDlg(() => cat = v ?? cat),
                  ),
                  const SizedBox(height: 12),
                  TextField(controller: durCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Duration (hours)")),
                  const SizedBox(height: 12),
                  TextField(controller: descCtrl, maxLines: 3, decoration: const InputDecoration(labelText: "Description")),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text("Cancel")),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: FilledButton.styleFrom(backgroundColor: crm.primary),
              child: const Text("Save Course"),
            ),
          ],
        ),
      ),
    );

    if (ok == true && titleCtrl.text.trim().isNotEmpty) {
      final body = {
        "title": titleCtrl.text.trim(),
        "description": descCtrl.text.trim(),
        "category": cat,
        "department": selectedDept,
        "targetRole": roleCtrl.text.trim(),
        "durationHours": double.tryParse(durCtrl.text) ?? 4,
      };
      await ref.read(lmsServiceProvider).saveCourse(body, id: c?.id);
      ref.invalidate(coursesProvider);
    }
  }
}


// =============================================================================
// TAB 3: SKILLS MATRIX (Required vs Held)
// =============================================================================
class _SkillsMatrixTab extends StatelessWidget {
  const _SkillsMatrixTab({required this.crm});
  final CrmTheme crm;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: hrCardDecoration(crm),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Skill matrix · required vs held', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w800, color: crm.textPrimary)),
                  const SizedBox(height: 2),
                  Text('Required proficiency per role, actual per team member (FR-3.12, FR-3.13)', style: TextStyle(fontSize: 12, color: crm.textSecondary)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: crm.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                child: Text('Avg Proficiency 4.2 / 5.0', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: crm.primary)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: crm.border)),
            clipBehavior: Clip.antiAlias,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(crm.background),
              columns: const [
                DataColumn(label: Text('ROLE / SKILL')),
                DataColumn(label: Text('CATEGORY')),
                DataColumn(label: Text('REQUIRED')),
                DataColumn(label: Text('ACTUAL')),
                DataColumn(label: Text('STATUS')),
              ],
              rows: const [
                DataRow(cells: [
                  DataCell(Text('Kubernetes & Cloud Infra', style: TextStyle(fontWeight: FontWeight.w600))),
                  DataCell(Text('Technology & Systems (IT)')),
                  DataCell(Text('4.5 / 5.0')),
                  DataCell(Text('4.8 / 5.0')),
                  DataCell(Text('Meets benchmark', style: TextStyle(color: Color(0xFF059669), fontWeight: FontWeight.bold))),
                ]),
                DataRow(cells: [
                  DataCell(Text('Airbrush HD Foundation', style: TextStyle(fontWeight: FontWeight.w600))),
                  DataCell(Text('Bridal Styling')),
                  DataCell(Text('4.5 / 5.0')),
                  DataCell(Text('4.2 / 5.0')),
                  DataCell(Text('Target in progress', style: TextStyle(color: Color(0xFFD97706), fontWeight: FontWeight.bold))),
                ]),
                DataRow(cells: [
                  DataCell(Text('Hospital-Grade Sterilization', style: TextStyle(fontWeight: FontWeight.w600))),
                  DataCell(Text('Compliance')),
                  DataCell(Text('5.0 / 5.0')),
                  DataCell(Text('5.0 / 5.0')),
                  DataCell(Text('Certified', style: TextStyle(color: Color(0xFF059669), fontWeight: FontWeight.bold))),
                ]),
                DataRow(cells: [
                  DataCell(Text('POS ERP Cycle Counting', style: TextStyle(fontWeight: FontWeight.w600))),
                  DataCell(Text('Operations')),
                  DataCell(Text('4.0 / 5.0')),
                  DataCell(Text('4.0 / 5.0')),
                  DataCell(Text('Meets benchmark', style: TextStyle(color: Color(0xFF059669), fontWeight: FontWeight.bold))),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
