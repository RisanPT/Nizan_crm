import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/core/auth/access_control.dart';
import 'package:nizan_crm/core/providers/auth_provider.dart';
import 'package:nizan_crm/features/hr/shared/hr_ui.dart';

/// Single service descriptor for the HR launcher.
class HrServiceDescriptor {
  final String title;
  final String subtitle;
  final IconData icon;
  final String route;
  final String category;
  final List<String> tags;
  final bool Function(Access access)? isAllowed;

  const HrServiceDescriptor({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.route,
    required this.category,
    this.tags = const [],
    this.isAllowed,
  });
}

/// Registry of all 25+ HR modules mirroring the SRS and HRMS_Design.html.
final List<HrServiceDescriptor> kHrServices = [
  // ── My Space ──
  const HrServiceDescriptor(
    title: 'HR Home',
    subtitle: 'Me / My Team / Org self-service portal',
    icon: Icons.home_outlined,
    route: '/hr/home',
    category: 'My Space',
    tags: ['dashboard', 'home', 'me', 'portal', 'ess'],
  ),
  const HrServiceDescriptor(
    title: 'Approvals Inbox',
    subtitle: 'Decide pending leave, timesheet & claim requests',
    icon: Icons.fact_check_outlined,
    route: '/hr/approvals',
    category: 'My Space',
    tags: ['approvals', 'inbox', 'requests', 'approve', 'reject'],
  ),

  // ── Recruit & Onboard ──
  const HrServiceDescriptor(
    title: 'Recruitment',
    subtitle: 'Talent pipelines, job postings & offers',
    icon: Icons.work_outline,
    route: '/hr/recruitment',
    category: 'Recruit & Onboard',
    tags: ['recruitment', 'jobs', 'candidates', 'hiring', 'offers', 'pipeline', 'kanban'],
  ),
  const HrServiceDescriptor(
    title: 'New Hire Onboarding',
    subtitle: 'Checklists, document verification & asset kits',
    icon: Icons.assignment_turned_in_outlined,
    route: '/hr/onboarding',
    category: 'Recruit & Onboard',
    tags: ['onboarding', 'new hire', 'checklists', 'joining', 'welcome'],
  ),
  const HrServiceDescriptor(
    title: 'Offboarding & Clearance',
    subtitle: 'Exit clearance, final settlements & handovers',
    icon: Icons.logout_outlined,
    route: '/hr/offboarding',
    category: 'Recruit & Onboard',
    tags: ['offboarding', 'exit', 'resignation', 'clearance', 'settlement', 'lwd'],
  ),

  // ── People ──
  const HrServiceDescriptor(
    title: 'Staff Directory',
    subtitle: 'Full employee roster with filters & dossiers',
    icon: Icons.badge_outlined,
    route: '/staff',
    category: 'People',
    tags: ['staff', 'employees', 'directory', 'artists', 'team'],
  ),
  const HrServiceDescriptor(
    title: 'Organization Chart',
    subtitle: 'Interactive hierarchy & reporting tree',
    icon: Icons.account_tree_outlined,
    route: '/hr/org',
    category: 'People',
    tags: ['org', 'hierarchy', 'tree', 'reporting', 'structure', 'manager'],
  ),
  const HrServiceDescriptor(
    title: 'Designations',
    subtitle: 'Job titles, grade levels & responsibilities',
    icon: Icons.workspace_premium_outlined,
    route: '/hr/designations',
    category: 'People',
    tags: ['designations', 'titles', 'grades', 'roles', 'levels'],
  ),
  const HrServiceDescriptor(
    title: 'Employee Files',
    subtitle: 'Digital document vault (Aadhaar, PAN, agreements)',
    icon: Icons.folder_shared_outlined,
    route: '/hr/files',
    category: 'People',
    tags: ['files', 'documents', 'vault', 'aadhaar', 'pan', 'contracts'],
  ),
  const HrServiceDescriptor(
    title: 'Employee Logins',
    subtitle: 'Provision user accounts & ESS portal access',
    icon: Icons.key_outlined,
    route: '/hr/logins',
    category: 'People',
    tags: ['logins', 'ess', 'accounts', 'passwords', 'access'],
  ),

  // ── Time & Attendance ──
  const HrServiceDescriptor(
    title: 'Attendance Dashboard',
    subtitle: 'Timebox biometric check-in/out records',
    icon: Icons.fingerprint_outlined,
    route: '/hr/attendance',
    category: 'Time & Attendance',
    tags: ['attendance', 'biometric', 'timebox', 'present', 'absent', 'clock'],
  ),
  const HrServiceDescriptor(
    title: 'Attendance Regularization',
    subtitle: 'Fix missing punches & adjust punch timings',
    icon: Icons.event_available_outlined,
    route: '/hr/regularization',
    category: 'Time & Attendance',
    tags: ['regularization', 'punches', 'missing punch', 'fix', 'adjust'],
  ),
  const HrServiceDescriptor(
    title: 'Shifts & Roster',
    subtitle: 'Weekly shift schedules & employee allocations',
    icon: Icons.schedule_outlined,
    route: '/hr/shift',
    category: 'Time & Attendance',
    tags: ['shifts', 'roster', 'schedules', 'timing', 'allocation'],
  ),
  const HrServiceDescriptor(
    title: 'Time Tracker',
    subtitle: 'Log project hours & view weekly timesheets',
    icon: Icons.timer_outlined,
    route: '/hr/timesheet',
    category: 'Time & Attendance',
    tags: ['timesheet', 'hours', 'timer', 'projects', 'tasks', 'billable'],
  ),
  const HrServiceDescriptor(
    title: 'Leave & Time Off',
    subtitle: 'Leave balances, requests & holiday calendar',
    icon: Icons.event_busy_outlined,
    route: '/hr/leave',
    category: 'Time & Attendance',
    tags: ['leave', 'vacation', 'sick', 'casual', 'holidays', 'comp-off'],
  ),
  const HrServiceDescriptor(
    title: 'Slot Capacity',
    subtitle: 'Studio booking slot management & capacity tuning',
    icon: Icons.tune_outlined,
    route: '/hr/slot-capacity',
    category: 'Time & Attendance',
    tags: ['slots', 'capacity', 'booking slots', 'availability'],
  ),

  // ── Payroll & Operate ──
  const HrServiceDescriptor(
    title: 'Salaries & Payroll Run',
    subtitle: 'Generate monthly payroll & export payables',
    icon: Icons.payments_outlined,
    route: '/hr/salaries',
    category: 'Payroll & Operate',
    tags: ['salaries', 'payroll', 'payslips', 'wages', 'pay run', 'accounts'],
  ),
  const HrServiceDescriptor(
    title: 'Attendance Payroll',
    subtitle: 'Pro-rated attendance calculations & LOP preview',
    icon: Icons.timelapse_outlined,
    route: '/accounts/attendance-payroll',
    category: 'Payroll & Operate',
    tags: ['attendance payroll', 'timebox payroll', 'lop', 'pro-rated'],
  ),
  const HrServiceDescriptor(
    title: 'Compensation Bands',
    subtitle: 'Salary bands (L1–L6) & CTC revision proposals',
    icon: Icons.account_balance_wallet_outlined,
    route: '/hr/compensation',
    category: 'Payroll & Operate',
    tags: ['compensation', 'ctc', 'bands', 'salary bands', 'revisions', 'increment'],
  ),
  const HrServiceDescriptor(
    title: 'Reimbursements',
    subtitle: 'Employee expense claims & payment reconciliation',
    icon: Icons.receipt_long_outlined,
    route: '/hr/reimbursements',
    category: 'Payroll & Operate',
    tags: ['reimbursements', 'claims', 'expenses', 'receipts', 'bills'],
  ),
  const HrServiceDescriptor(
    title: 'Travel Desk',
    subtitle: 'Studio travel requests, transport & advances',
    icon: Icons.flight_takeoff_outlined,
    route: '/hr/travel',
    category: 'Payroll & Operate',
    tags: ['travel', 'trips', 'flights', 'cabs', 'hotels', 'advances'],
  ),

  // ── Growth & Workplace ──
  const HrServiceDescriptor(
    title: '5-Pillar Evaluation',
    subtitle: 'Appraisal scorecards & performance reviews',
    icon: Icons.star_outline,
    route: '/hr/evaluation',
    category: 'Growth & Workplace',
    tags: ['evaluation', 'performance', 'appraisal', 'scorecards', 'ratings', 'pillars'],
  ),
  const HrServiceDescriptor(
    title: 'Learning & Orientation (LMS)',
    subtitle: 'Course catalog & 1-week orientation plans',
    icon: Icons.school_outlined,
    route: '/hr/lms',
    category: 'Growth & Workplace',
    tags: ['learning', 'lms', 'courses', 'training', 'orientation', 'syllabus'],
  ),
  const HrServiceDescriptor(
    title: 'Company Engagement',
    subtitle: 'Internal announcements, feed & celebrations',
    icon: Icons.campaign_outlined,
    route: '/hr/engagement',
    category: 'Growth & Workplace',
    tags: ['engagement', 'feed', 'announcements', 'culture', 'celebrations'],
  ),
  const HrServiceDescriptor(
    title: 'Confidential Grievances',
    subtitle: 'Workplace conflict resolution & anonymous cases',
    icon: Icons.report_gmailerrorred_outlined,
    route: '/hr/grievance',
    category: 'Growth & Workplace',
    tags: ['grievances', 'conflict', 'complaint', 'harassment', 'cases', 'ethics'],
  ),
  const HrServiceDescriptor(
    title: 'HR Letters',
    subtitle: 'Generate offer, appointment & relieving letters',
    icon: Icons.description_outlined,
    route: '/hr/letters',
    category: 'Growth & Workplace',
    tags: ['letters', 'templates', 'experience', 'relieving', 'appointment', 'pdf'],
  ),
  const HrServiceDescriptor(
    title: 'Department & Employee Scoring',
    subtitle: 'Studio performance leaderboards, quality index & KPIs',
    icon: Icons.leaderboard_outlined,
    route: '/hr/department-scoring',
    category: 'Growth & Workplace',
    tags: ['scoring', 'department', 'leaderboard', 'quality', 'ranking', 'employee score'],
  ),
  const HrServiceDescriptor(
    title: 'Company & HR Policies',
    subtitle: 'Workplace handbook, code of conduct & digital acknowledgments',
    icon: Icons.policy_outlined,
    route: '/hr/policies',
    category: 'Growth & Workplace',
    tags: ['policy', 'policies', 'handbook', 'rules', 'posh', 'conduct', 'hygiene'],
  ),
  const HrServiceDescriptor(
    title: 'HR Analytics',
    subtitle: 'Headcount, attrition & department workload KPIs',
    icon: Icons.insights_outlined,
    route: '/hr/analytics',
    category: 'Growth & Workplace',
    tags: ['analytics', 'metrics', 'headcount', 'attrition', 'turnover', 'workload'],
  ),
];

/// Displays the "More Services" HR launcher modal dialog.
Future<void> showHrServicesLauncher(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => const _HrServicesLauncherDialog(),
  );
}

class _HrServicesLauncherDialog extends ConsumerStatefulWidget {
  const _HrServicesLauncherDialog();

  @override
  ConsumerState<_HrServicesLauncherDialog> createState() => _HrServicesLauncherDialogState();
}

class _HrServicesLauncherDialogState extends ConsumerState<_HrServicesLauncherDialog> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final session = ref.watch(authSessionProvider);
    final access = Access.of(session);

    // Filter services by user permissions
    final allowedServices = kHrServices.where((s) {
      if (s.isAllowed != null) return s.isAllowed!(access);
      // Fallback: everyone can see ESS / leave / approvals, manager gates handled on page
      return true;
    }).toList();

    // Filter by search query
    final filtered = _query.isEmpty
        ? allowedServices
        : allowedServices.where((s) {
            final q = _query.toLowerCase().trim();
            final matchesTitle = s.title.toLowerCase().contains(q);
            final matchesSub = s.subtitle.toLowerCase().contains(q);
            final matchesCat = s.category.toLowerCase().contains(q);
            final matchesTag = s.tags.any((t) => t.toLowerCase().contains(q));
            return matchesTitle || matchesSub || matchesCat || matchesTag;
          }).toList();

    // Group services by category when not searching
    final categories = <String, List<HrServiceDescriptor>>{};
    for (final s in filtered) {
      categories.putIfAbsent(s.category, () => []).add(s);
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820, maxHeight: 720),
          child: Container(
            decoration: BoxDecoration(
              color: crm.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: crm.border),
              boxShadow: hrCardShadow(elevated: true),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── HEADER ──
                Container(
                  padding: const EdgeInsets.fromLTRB(22, 18, 16, 16),
                  decoration: BoxDecoration(
                    color: crm.background,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    border: Border(bottom: BorderSide(color: crm.border)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: crm.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.grid_view_rounded, color: crm.primary, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'HR Services Launcher',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: crm.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Jump directly to any module, workflow or report',
                              style: TextStyle(fontSize: 12, color: crm.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close (Esc)',
                        icon: Icon(Icons.close_rounded, color: crm.textSecondary),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),

                // ── SEARCH BOX ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
                  child: TextField(
                    controller: _searchCtrl,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Search services (e.g. Leave, Payroll, LMS, Reimbursements, Letters)...',
                      hintStyle: TextStyle(fontSize: 13.5, color: crm.textSecondary),
                      prefixIcon: Icon(Icons.search_rounded, color: crm.primary, size: 20),
                      suffixIcon: _query.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() => _query = '');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: crm.background,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: crm.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: crm.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: crm.primary, width: 1.5),
                      ),
                    ),
                    onChanged: (v) => setState(() => _query = v),
                  ),
                ),

                // ── SERVICES CONTENT ──
                Expanded(
                  child: filtered.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.search_off_rounded, size: 48, color: crm.textSecondary.withValues(alpha: 0.5)),
                              const SizedBox(height: 12),
                              Text('No matching HR services found', style: TextStyle(color: crm.textPrimary, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 4),
                              Text('Try searching for leave, attendance, payroll, or staff', style: TextStyle(color: crm.textSecondary, fontSize: 12)),
                            ],
                          ),
                        )
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                          children: [
                            if (_query.isNotEmpty) ...[
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12, top: 4),
                                child: Text(
                                  'FOUND ${filtered.length} MATCHING SERVICES',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.8,
                                    color: crm.textSecondary,
                                  ),
                                ),
                              ),
                              _buildGrid(context, crm, filtered),
                            ] else ...[
                              for (final entry in categories.entries) ...[
                                Padding(
                                  padding: const EdgeInsets.only(top: 14, bottom: 8),
                                  child: Row(
                                    children: [
                                      Text(
                                        entry.key.toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.9,
                                          color: crm.textSecondary,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(child: Divider(color: crm.border)),
                                    ],
                                  ),
                                ),
                                _buildGrid(context, crm, entry.value),
                              ],
                            ],
                          ],
                        ),
                ),

                // ── FOOTER HINT ──
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: crm.background,
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                    border: Border(top: BorderSide(color: crm.border)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.keyboard_outlined, size: 16, color: crm.textSecondary),
                      const SizedBox(width: 6),
                      Text(
                        'Tip: Tap any service to launch it instantly.',
                        style: TextStyle(fontSize: 11.5, color: crm.textSecondary),
                      ),
                      const Spacer(),
                      Text(
                        '${allowedServices.length} modules configured',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: crm.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGrid(BuildContext context, CrmTheme crm, List<HrServiceDescriptor> items) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = constraints.maxWidth > 580 ? 3 : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 2.1,
          ),
          itemCount: items.length,
          itemBuilder: (context, i) {
            final s = items[i];
            return Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  Navigator.of(context).pop();
                  context.go(s.route);
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: crm.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: crm.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: crm.primary.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(s.icon, color: crm.primary, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              s.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: crm.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              s.subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: crm.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
