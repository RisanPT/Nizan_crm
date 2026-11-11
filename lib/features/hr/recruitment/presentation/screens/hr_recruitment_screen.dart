import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher_string.dart';

import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/hr/shared/hr_ui.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/hr/recruitment/data/recruitment_models.dart';
import 'package:nizan_crm/features/hr/recruitment/service/recruitment_service.dart';
import 'package:nizan_crm/features/hr/recruitment/utils/recruitment_file_import.dart';
import 'package:nizan_crm/features/hr/letters/utils/nizan_hr_document_pdf.dart';

String _fmt(DateTime? d) {
  if (d == null) return '';
  const m = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${d.day.toString().padLeft(2, '0')} ${m[d.month]} ${d.year}';
}

Color _stageColor(String s, CrmTheme crm) {
  switch (s) {
    case 'hired':
      return crm.success;
    case 'rejected':
      return crm.destructive;
    case 'offer':
      return const Color(0xFFC9A66B); // Gold
    case 'interview':
      return crm.warning;
    case 'screening':
      return const Color(0xFF3B5BA5); // Info Blue
    case 'applied':
    default:
      return crm.textSecondary;
  }
}

Color _tierColor(int tier) {
  switch (tier) {
    case 1:
      return const Color(0xFF601A29); // Board (Maroon)
    case 2:
      return const Color(0xFFB58500); // CEO (Gold)
    case 3:
      return const Color(0xFF2563EB); // C-Suite (Blue)
    case 4:
      return const Color(0xFF059669); // Heads (Emerald)
    case 5:
    default:
      return const Color(0xFF4B5563); // Teams (Slate)
  }
}

String _tierLabel(int tier) {
  switch (tier) {
    case 1:
      return 'T1 Board';
    case 2:
      return 'T2 CEO';
    case 3:
      return 'T3 C-Suite';
    case 4:
      return 'T4 Heads';
    case 5:
    default:
      return 'T5 Teams';
  }
}

IconData _tierIcon(int tier) {
  switch (tier) {
    case 1:
      return Icons.shield_outlined;
    case 2:
      return Icons.military_tech_outlined;
    case 3:
      return Icons.workspace_premium_outlined;
    case 4:
      return Icons.supervisor_account_outlined;
    case 5:
    default:
      return Icons.badge_outlined;
  }
}

Color _bandColor(String band) {
  switch (band.toUpperCase()) {
    case 'L6':
      return const Color(0xFF601A29);
    case 'L5':
      return const Color(0xFFC9A66B);
    case 'L4':
      return const Color(0xFF059669);
    case 'L3':
      return const Color(0xFF2563EB);
    case 'L2':
    case 'L1':
    default:
      return const Color(0xFF6B7280);
  }
}

Widget _chip(String text, Color c) => hrStatusChip(text, c);

const kRecruitmentDepartments = <String>[
  'Bridal Styling',
  'Academy',
  'Studio Ops',
  'Studio & Services Ops',
  'Finance & Accounts',
  'Technology & Systems (IT)',
  'Fleet',
  'Executive / Governance',
];

String resolveDepartmentForRole({
  required String roleTitle,
  String? jobPostId,
  List<JobPost> posts = const [],
  List<JobRole> roles = const [],
  List<HiringPlan> plans = const [],
  String fallback = 'Bridal Styling',
}) {
  if (jobPostId != null && jobPostId.isNotEmpty) {
    final p = posts.where((x) => x.id == jobPostId).firstOrNull;
    if (p != null && p.department.isNotEmpty) return p.department;
  }
  final normalized = roleTitle.trim().toLowerCase();
  if (normalized.isEmpty) return fallback;

  // 1. Direct match with Job Posts
  final matchPost = posts.where((p) => p.title.trim().toLowerCase() == normalized).firstOrNull;
  if (matchPost != null && matchPost.department.isNotEmpty) return matchPost.department;

  // 2. Direct match with Job Roles
  final matchRole = roles.where((r) => r.designation.trim().toLowerCase() == normalized).firstOrNull;
  if (matchRole != null && matchRole.dept.isNotEmpty) return matchRole.dept;

  // 3. Direct match with Hiring Plans
  final matchPlan = plans.where((p) => p.designation.trim().toLowerCase() == normalized).firstOrNull;
  if (matchPlan != null && matchPlan.department.isNotEmpty) return matchPlan.department;

  // 4. Keyword heuristic based on organizational structure
  if (normalized.contains('dev-ops') ||
      normalized.contains('devops') ||
      normalized.contains('tech') ||
      normalized.contains('system') ||
      normalized.contains('engineer') ||
      normalized.contains('developer') ||
      normalized.contains('software') ||
      normalized.contains('it ') ||
      normalized == 'it') {
    return 'Technology & Systems (IT)';
  }
  if (normalized.contains('bridal') ||
      normalized.contains('makeup') ||
      normalized.contains('stylist') ||
      normalized.contains('drape') ||
      normalized.contains('hair')) {
    return 'Bridal Styling';
  }
  if (normalized.contains('academy') ||
      normalized.contains('trainer') ||
      normalized.contains('faculty') ||
      normalized.contains('principal') ||
      normalized.contains('instructor')) {
    return 'Academy';
  }
  if (normalized.contains('fleet') ||
      normalized.contains('driver') ||
      normalized.contains('transport') ||
      normalized.contains('vehicle')) {
    return 'Fleet';
  }
  if (normalized.contains('finance') ||
      normalized.contains('account') ||
      normalized.contains('billing') ||
      normalized.contains('audit') ||
      normalized.contains('tax') ||
      normalized.contains('cfo')) {
    return 'Finance & Accounts';
  }
  if (normalized.contains('studio') ||
      normalized.contains('service') ||
      normalized.contains('salon') ||
      normalized.contains('ops') ||
      normalized.contains('coordinator')) {
    return 'Studio Ops';
  }
  if (normalized.contains('director') ||
      normalized.contains('ceo') ||
      normalized.contains('coo') ||
      normalized.contains('board') ||
      normalized.contains('executive')) {
    return 'Executive / Governance';
  }

  return fallback;
}

/// HR Recruitment & Hiring Process — pipeline funnel, role hierarchy & analysis,
/// hiring plans approval workflow, candidate kanban, job posts, and offer letters.
/// Fully aligned with HRMS_Design.html (FR-1.1 through FR-1.23).
class HrRecruitmentScreen extends ConsumerStatefulWidget {
  const HrRecruitmentScreen({super.key});

  @override
  ConsumerState<HrRecruitmentScreen> createState() => _HrRecruitmentScreenState();
}

class _HrRecruitmentScreenState extends ConsumerState<HrRecruitmentScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final candidatesAsync = ref.watch(candidatesProvider);
    final postsAsync = ref.watch(jobPostsProvider);
    final offersAsync = ref.watch(offersProvider);
    final rolesAsync = ref.watch(jobRolesProvider);
    // Phones: the two header buttons go under the title instead of beside it.
    final narrowHeader = MediaQuery.sizeOf(context).width < 700;
    final headerActions = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        OutlinedButton.icon(
          onPressed: () => _openCandidateDialog(context, null),
          icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
          label: const Text('Add Candidate', style: TextStyle(fontWeight: FontWeight.w700)),
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: crm.border.faded(0.8)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          ),
        ),
        FilledButton.icon(
          onPressed: () => _openHiringPlanDialog(context),
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('New Hiring Plan', style: TextStyle(fontWeight: FontWeight.w700)),
          style: FilledButton.styleFrom(
            backgroundColor: crm.primary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          ),
        ),
      ],
    );

    return Scaffold(
      backgroundColor: crm.background,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header Banner ──
          Container(
            color: crm.surface,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: crm.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.work_outline_rounded, color: crm.primary, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Recruitment & Hiring Pipeline',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: crm.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Role hierarchy, requisitions, pipeline funnel, and candidate lifecycle',
                            style: TextStyle(fontSize: 12, color: crm.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    if (!narrowHeader) ...[const SizedBox(width: 12), headerActions],
                  ],
                ),
                if (narrowHeader) ...[const SizedBox(height: 12), headerActions],
                const SizedBox(height: 14),
                // ── Navigation Tabs ──
                Container(
                  decoration: BoxDecoration(
                    color: crm.background,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: crm.border.faded(0.8)),
                  ),
                  padding: const EdgeInsets.all(3),
                  child: TabBar(
                    controller: _tabCtrl,
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    labelColor: Colors.white,
                    unselectedLabelColor: crm.textSecondary,
                    labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    splashBorderRadius: BorderRadius.circular(999),
                    indicator: BoxDecoration(
                      color: crm.primary,
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: hrCardShadow(),
                    ),
                    labelPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 2),
                    tabs: [
                      Tab(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.alt_route_rounded, size: 16),
                            const SizedBox(width: 6),
                            const Text('Pipeline'),
                            candidatesAsync.maybeWhen(
                              data: (c) => Container(
                                margin: const EdgeInsets.only(left: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(999)),
                                child: Text('${c.length}', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800)),
                              ),
                              orElse: () => const SizedBox.shrink(),
                            ),
                          ],
                        ),
                      ),
                      Tab(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.account_tree_outlined, size: 16),
                            const SizedBox(width: 6),
                            const Text('Job Roles & Analysis'),
                            rolesAsync.maybeWhen(
                              data: (r) => Container(
                                margin: const EdgeInsets.only(left: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(999)),
                                child: Text('${r.length}', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800)),
                              ),
                              orElse: () => const SizedBox.shrink(),
                            ),
                          ],
                        ),
                      ),
                      Tab(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.campaign_outlined, size: 16),
                            const SizedBox(width: 6),
                            const Text('Job Posts'),
                            postsAsync.maybeWhen(
                              data: (p) => Container(
                                margin: const EdgeInsets.only(left: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(999)),
                                child: Text('${p.length}', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800)),
                              ),
                              orElse: () => const SizedBox.shrink(),
                            ),
                          ],
                        ),
                      ),
                      const Tab(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.people_outline_rounded, size: 16),
                            SizedBox(width: 6),
                            Text('Candidates'),
                          ],
                        ),
                      ),
                      Tab(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.description_outlined, size: 16),
                            const SizedBox(width: 6),
                            const Text('Offers'),
                            offersAsync.maybeWhen(
                              data: (o) => Container(
                                margin: const EdgeInsets.only(left: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(999)),
                                child: Text('${o.length}', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800)),
                              ),
                              orElse: () => const SizedBox.shrink(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Tab Views ──
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                _PipelineKanbanTab(
                  crm: crm,
                  onAddCandidate: () => _openCandidateDialog(context, null),
                  onOpenPost: (id) => _tabCtrl.animateTo(2),
                  onCreateOffer: (c) => _openOfferDialog(context, c),
                  onEditCandidate: (c) => _openCandidateDialog(context, c),
                  onNewPlan: () => _openHiringPlanDialog(context),
                  onPlanToPost: (plan) => _openJobPostDialog(
                    context,
                    null,
                    defaultTitle: plan.designation,
                    defaultDept: plan.department,
                    defaultOpenings: plan.openings,
                  ),
                ),
                _JobRolesHierarchyTab(
                  crm: crm,
                  onNewRole: () => _openRoleDialog(context),
                  onEditRole: (role) => _openRoleDialog(context, existing: role),
                  onCreatePlanFromRole: (role) => _openHiringPlanDialog(context, fromRole: role),
                ),
                _JobPostsTab(
                  crm: crm,
                  onNewPost: () => _openJobPostDialog(context, null),
                  onEditPost: (p) => _openJobPostDialog(context, p),
                ),
                _CandidatesListTab(
                  crm: crm,
                  onAddCandidate: () => _openCandidateDialog(context, null),
                  onEditCandidate: (c) => _openCandidateDialog(context, c),
                  onCreateOffer: (c) => _openOfferDialog(context, c),
                ),
                _OffersTab(crm: crm),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openHiringPlanDialog(BuildContext context, {HiringPlan? existing, JobRole? fromRole}) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _HiringPlanDialog(existing: existing, fromRole: fromRole),
    );
    if (ok == true) {
      ref.invalidate(hiringPlansProvider);
    }
  }

  Future<void> _openRoleDialog(BuildContext context, {JobRole? existing}) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _RoleDefDialog(existing: existing),
    );
    if (ok == true) {
      ref.invalidate(jobRolesProvider);
    }
  }

  Future<void> _openJobPostDialog(
    BuildContext context,
    JobPost? existing, {
    String? defaultTitle,
    String? defaultDept,
    int? defaultOpenings,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _JobPostDialog(
        existing: existing,
        defaultTitle: defaultTitle,
        defaultDept: defaultDept,
        defaultOpenings: defaultOpenings,
      ),
    );
    if (ok == true) ref.invalidate(jobPostsProvider);
  }

  Future<void> _openCandidateDialog(BuildContext context, Candidate? existing) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _CandidateDialog(existing: existing),
    );
    if (ok == true) {
      ref.invalidate(candidatesProvider);
      ref.invalidate(jobPostsProvider);
    }
  }

  Future<void> _openOfferDialog(BuildContext context, Candidate candidate) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _OfferDialog(candidate: candidate),
    );
    if (ok == true) {
      ref.invalidate(offersProvider);
      ref.invalidate(candidatesProvider);
    }
  }
}

Future<void> _confirmDeleteCandidate(BuildContext context, WidgetRef ref, Candidate c) async {
  bool deleteLinked = c.stage == 'hired';
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setDlgState) {
          return AlertDialog(
            title: Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.red.shade700, size: 24),
                const SizedBox(width: 8),
                const Text('Delete Candidate'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Are you sure you want to delete "${c.name}" from recruitment?',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  'This will permanently delete this applicant and their draft offers.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                if (c.stage == 'hired') ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Candidate was marked as HIRED',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orange),
                        ),
                        const SizedBox(height: 4),
                        Material(
                          color: Colors.transparent,
                          child: CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            title: const Text(
                              'Also remove mistakenly created Employee & Onboarding record',
                              style: TextStyle(fontSize: 12),
                            ),
                            value: deleteLinked,
                            onChanged: (val) => setDlgState(() => deleteLinked = val ?? false),
                            controlAffinity: ListTileControlAffinity.leading,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Delete'),
              ),
            ],
          );
        },
      );
    },
  );

  if (confirmed == true) {
    try {
      await ref.read(recruitmentServiceProvider).deleteCandidate(c.id, deleteLinkedEmployee: deleteLinked);
      ref.invalidate(candidatesProvider);
      ref.invalidate(offersProvider);
      ref.invalidate(jobPostsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Candidate "${c.name}" deleted successfully')),
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

Future<void> _confirmDeleteOffer(BuildContext context, WidgetRef ref, Offer o) async {
  bool deleteLinked = o.status == 'accepted';
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setDlgState) {
          return AlertDialog(
            title: Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.red.shade700, size: 24),
                const SizedBox(width: 8),
                const Text('Delete Offer Letter'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Are you sure you want to delete the offer for "${o.candidateName}"?',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                if (o.status == 'accepted') ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'This offer was already ACCEPTED',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orange),
                        ),
                        const SizedBox(height: 4),
                        Material(
                          color: Colors.transparent,
                          child: CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            title: const Text(
                              'Also remove mistakenly created Employee & Onboarding record',
                              style: TextStyle(fontSize: 12),
                            ),
                            value: deleteLinked,
                            onChanged: (val) => setDlgState(() => deleteLinked = val ?? false),
                            controlAffinity: ListTileControlAffinity.leading,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Delete'),
              ),
            ],
          );
        },
      );
    },
  );

  if (confirmed == true) {
    try {
      await ref.read(recruitmentServiceProvider).deleteOffer(o.id, deleteLinkedEmployee: deleteLinked);
      ref.invalidate(offersProvider);
      ref.invalidate(candidatesProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Offer for "${o.candidateName}" deleted')),
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

// ─── Pipeline & Kanban Tab ───────────────────────────────────────────────────

class _PipelineKanbanTab extends ConsumerWidget {
  const _PipelineKanbanTab({
    required this.crm,
    required this.onAddCandidate,
    required this.onOpenPost,
    required this.onCreateOffer,
    required this.onEditCandidate,
    required this.onNewPlan,
    required this.onPlanToPost,
  });

  final CrmTheme crm;
  final VoidCallback onAddCandidate;
  final ValueChanged<String> onOpenPost;
  final ValueChanged<Candidate> onCreateOffer;
  final ValueChanged<Candidate> onEditCandidate;
  final VoidCallback onNewPlan;
  final ValueChanged<HiringPlan> onPlanToPost;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final candidatesAsync = ref.watch(candidatesProvider);
    final plansAsync = ref.watch(hiringPlansProvider);
    final postsAsync = ref.watch(jobPostsProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(candidatesProvider);
        ref.invalidate(hiringPlansProvider);
        ref.invalidate(jobPostsProvider);
      },
      child: candidatesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ListView(children: [AppErrorView(error: e, onRetry: () => ref.invalidate(candidatesProvider))]),
        data: (candidates) {
          // Group candidates by stage
          final byStage = <String, List<Candidate>>{};
          for (final s in ['applied', 'screening', 'interview', 'offer', 'hired']) {
            byStage[s] = [];
          }
          for (final c in candidates) {
            final st = c.stage.toLowerCase();
            if (byStage.containsKey(st)) {
              byStage[st]!.add(c);
            } else if (st != 'rejected') {
              byStage['applied']!.add(c);
            }
          }

          final appliedCount = byStage['applied']!.length;
          final screeningCount = byStage['screening']!.length;
          final interviewCount = byStage['interview']!.length;
          final offerCount = byStage['offer']!.length;
          final hiredCount = byStage['hired']!.length;

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
            children: [
              // ── Funnel KPI Card (from HRMS Design FR-1.23) ──
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: crm.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: crm.border.faded(0.8)),
                  boxShadow: hrCardShadow(),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Recruitment Funnel',
                                style: GoogleFonts.plusJakartaSans(fontSize: 14.5, fontWeight: FontWeight.w800, color: crm.textPrimary),
                              ),
                              Text(
                                'Derived automatically from candidate pipeline stages · FR-1.23',
                                style: TextStyle(fontSize: 12, color: crm.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: crm.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${candidates.length} active in pipeline',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: crm.primary),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    // Funnel Step Badges
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _funnelStep(crm, 'Applications', '$appliedCount', crm.primary, false),
                          _funnelArrow(crm),
                          _funnelStep(crm, 'Shortlisted', '$screeningCount', const Color(0xFF3B5BA5), false),
                          _funnelArrow(crm),
                          _funnelStep(crm, 'Interviewed', '$interviewCount', crm.warning, false),
                          _funnelArrow(crm),
                          _funnelStep(crm, 'Offered', '$offerCount', const Color(0xFFC9A66B), true),
                          _funnelArrow(crm),
                          _funnelStep(crm, 'Hired / Joined', '$hiredCount', crm.success, false, isGood: true),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // ── Hiring Plans & Job Posts Dual Overview (from HRMS Design FR-1.4 & FR-1.5) ──
              plansAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (err, st) => const SizedBox.shrink(),
                data: (plans) {
                  final approvedCount = plans.where((p) => p.status == 'approved').length;
                  final posts = postsAsync.asData?.value ?? [];

                  return LayoutBuilder(builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 900;
                    return Flex(
                      direction: isWide ? Axis.horizontal : Axis.vertical,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left Card: Hiring Plans Requisitions
                        Expanded(
                          flex: isWide ? 3 : 0,
                          child: Container(
                            margin: EdgeInsets.only(bottom: isWide ? 0 : 16, right: isWide ? 14 : 0),
                            decoration: BoxDecoration(
                              color: crm.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: crm.border.faded(0.8)),
                              boxShadow: hrCardShadow(),
                            ),
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Hiring Plans (Requisitions)',
                                            style: GoogleFonts.plusJakartaSans(fontSize: 14.5, fontWeight: FontWeight.w800, color: crm.textPrimary),
                                          ),
                                          Text(
                                            'HR plan · draft → raised → approved (FR-1.4)',
                                            style: TextStyle(fontSize: 11.5, color: crm.textSecondary),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: crm.success.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        '$approvedCount approved',
                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: crm.success),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                // Plans Table
                                if (plans.isEmpty)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 20),
                                    child: Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.assignment_outlined, size: 36, color: crm.textSecondary.faded(0.6)),
                                          const SizedBox(height: 8),
                                          Text(
                                            'No hiring plans created yet',
                                            style: GoogleFonts.plusJakartaSans(fontSize: 13.5, fontWeight: FontWeight.w700, color: crm.textPrimary),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Raise an approved plan before publishing job postings.',
                                            style: TextStyle(fontSize: 11.5, color: crm.textSecondary),
                                          ),
                                          const SizedBox(height: 10),
                                          OutlinedButton.icon(
                                            onPressed: onNewPlan,
                                            icon: const Icon(Icons.add, size: 14),
                                            label: const Text('New Hiring Plan', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                                            style: OutlinedButton.styleFrom(
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                              minimumSize: Size.zero,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                else
                                  ListView.separated(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    itemCount: plans.length > 4 ? 4 : plans.length,
                                    separatorBuilder: (context, index) => Divider(color: crm.border.faded(0.5), height: 16),
                                    itemBuilder: (context, idx) {
                                      final p = plans[idx];
                                      final isApproved = p.status == 'approved';
                                      final isRaised = p.status == 'raised';
                                      final isDraft = p.status == 'draft';

                                      return Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  p.designation,
                                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: crm.textPrimary),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  '${p.department} · ${p.employmentType} · ${p.openings} open · Reports to: ${p.reportingLine.isNotEmpty ? p.reportingLine : 'Direct'}',
                                                  style: TextStyle(fontSize: 11, color: crm.textSecondary),
                                                ),
                                              ],
                                            ),
                                          ),
                                          _planStatusChip(p.status, crm),
                                          const SizedBox(width: 8),
                                          if (isDraft)
                                            OutlinedButton(
                                              onPressed: () async {
                                                await ref.read(recruitmentServiceProvider).raiseHiringPlan(p.id);
                                                ref.invalidate(hiringPlansProvider);
                                              },
                                              style: OutlinedButton.styleFrom(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                minimumSize: Size.zero,
                                              ),
                                              child: const Text('Raise', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                                            ),
                                          if (isRaised) ...[
                                            OutlinedButton(
                                              onPressed: () async {
                                                await ref.read(recruitmentServiceProvider).approveHiringPlan(p.id);
                                                ref.invalidate(hiringPlansProvider);
                                              },
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor: crm.success,
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                minimumSize: Size.zero,
                                              ),
                                              child: const Text('Approve', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                                            ),
                                            const SizedBox(width: 4),
                                            OutlinedButton(
                                              onPressed: () async {
                                                await ref.read(recruitmentServiceProvider).rejectHiringPlan(p.id);
                                                ref.invalidate(hiringPlansProvider);
                                              },
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor: crm.destructive,
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                minimumSize: Size.zero,
                                              ),
                                              child: const Text('Reject', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                                            ),
                                          ],
                                          if (isApproved)
                                            FilledButton(
                                              onPressed: () => onPlanToPost(p),
                                              style: FilledButton.styleFrom(
                                                backgroundColor: crm.primary,
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                minimumSize: Size.zero,
                                              ),
                                              child: const Text('Create Post', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                                            ),
                                        ],
                                      );
                                    },
                                  ),
                                const SizedBox(height: 10),
                                Text(
                                  'Job posts and candidates can be created only against an approved plan (FR-1.5).',
                                  style: TextStyle(fontSize: 11, color: crm.textSecondary, fontStyle: FontStyle.italic),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Right Card: Job Posts
                        Expanded(
                          flex: isWide ? 2 : 0,
                          child: Container(
                            decoration: BoxDecoration(
                              color: crm.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: crm.border.faded(0.8)),
                              boxShadow: hrCardShadow(),
                            ),
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Job Posts',
                                            style: GoogleFonts.plusJakartaSans(fontSize: 14.5, fontWeight: FontWeight.w800, color: crm.textPrimary),
                                          ),
                                          Text(
                                            'Per approved plan · channels & status',
                                            style: TextStyle(fontSize: 11.5, color: crm.textSecondary),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF3B5BA5).withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        '${posts.where((x) => x.status == 'open').length} live',
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF3B5BA5)),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                if (posts.isEmpty)
                                  const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 16),
                                    child: Center(child: Text('No active job postings.')),
                                  )
                                else
                                  ListView.separated(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    itemCount: posts.length > 4 ? 4 : posts.length,
                                    separatorBuilder: (context, index) => Divider(color: crm.border.faded(0.5), height: 14),
                                    itemBuilder: (context, idx) {
                                      final p = posts[idx];
                                      return Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                              color: crm.primary.withValues(alpha: 0.08),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Icon(Icons.campaign_outlined, size: 16, color: crm.primary),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(p.title, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: crm.textPrimary)),
                                                Text(
                                                  '${p.department} · ${p.candidateCount} applicants',
                                                  style: TextStyle(fontSize: 11, color: crm.textSecondary),
                                                ),
                                              ],
                                            ),
                                          ),
                                          _chip(p.status == 'open' ? 'Published' : titleCase(p.status), p.status == 'open' ? crm.success : crm.textSecondary),
                                        ],
                                      );
                                    },
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  });
                },
              ),

              const SizedBox(height: 18),

              // ── Kanban Board Header ──
              Row(
                children: [
                  Text(
                    'PIPELINE KANBAN BOARD',
                    style: TextStyle(fontSize: 11, letterSpacing: 0.9, fontWeight: FontWeight.w700, color: crm.textSecondary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Tip: Tap on any card menu to advance stages or create offer letters',
                      style: TextStyle(fontSize: 11.5, color: crm.textSecondary, fontStyle: FontStyle.italic),
                      textAlign: TextAlign.right,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // ── Interactive Kanban Columns ──
              // Columns stretch to share the available width (200–320px each)
              // so all five stages fit on laptop screens; only narrower
              // screens scroll sideways. Previously a fixed 250px width made
              // the board wider than the page, so it scrolled and the
              // "Applied" column ended up half hidden on the left.
              LayoutBuilder(
                builder: (context, box) {
                  const gap = 14.0;
                  final colWidth = ((box.maxWidth - gap * 4) / 5).clamp(200.0, 320.0);
                  final cols = [
                    _kanbanColumn(context, ref, 'Applied', 'applied', byStage['applied']!, crm.textSecondary, colWidth),
                    _kanbanColumn(context, ref, 'Screening', 'screening', byStage['screening']!, const Color(0xFF3B5BA5), colWidth),
                    _kanbanColumn(context, ref, 'Interview', 'interview', byStage['interview']!, crm.warning, colWidth),
                    _kanbanColumn(context, ref, 'Offer', 'offer', byStage['offer']!, const Color(0xFFC9A66B), colWidth),
                    _kanbanColumn(context, ref, 'Hired', 'hired', byStage['hired']!, crm.success, colWidth),
                  ];
                  return SizedBox(
                    height: 520,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (var i = 0; i < cols.length; i++) ...[
                            if (i > 0) const SizedBox(width: gap),
                            cols[i],
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  static Widget _planStatusChip(String status, CrmTheme crm) {
    Color col;
    switch (status.toLowerCase()) {
      case 'approved':
        col = crm.success;
        break;
      case 'raised':
        col = crm.warning;
        break;
      case 'rejected':
        col = crm.destructive;
        break;
      case 'draft':
      default:
        col = crm.textSecondary;
    }
    return hrStatusChip(titleCase(status), col);
  }

  Widget _funnelStep(CrmTheme crm, String label, String value, Color color, bool isGold, {bool isGood = false}) {
    return Container(
      width: 110,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: isGold
            ? const Color(0xFFF7EFE0)
            : isGood
                ? crm.success.withValues(alpha: 0.1)
                : crm.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isGold
              ? const Color(0xFFEAD6A8)
              : isGood
                  ? crm.success.withValues(alpha: 0.3)
                  : crm.border.faded(0.6),
        ),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isGold ? const Color(0xFFB58500) : crm.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _funnelArrow(CrmTheme crm) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Icon(Icons.chevron_right_rounded, color: crm.textSecondary.withValues(alpha: 0.4), size: 18),
    );
  }

  Widget _kanbanColumn(BuildContext context, WidgetRef ref, String title, String stageKey, List<Candidate> items, Color accent, double width) {
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: crm.border.faded(0.8)),
        boxShadow: hrCardShadow(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Column Header
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: crm.border.faded(0.6))),
            ),
            child: Row(
              children: [
                Container(width: 8, height: 8, decoration: BoxDecoration(color: accent, shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(fontSize: 13.5, fontWeight: FontWeight.w800, color: crm.textPrimary),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: crm.background,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: crm.border.faded(0.8)),
                  ),
                  child: Text(
                    '${items.length}',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: crm.textPrimary),
                  ),
                ),
              ],
            ),
          ),
          // Column Cards List
          Expanded(
            child: items.isEmpty
                ? Center(
                    child: Text('No candidates', style: TextStyle(fontSize: 11.5, color: crm.textSecondary.withValues(alpha: 0.7))),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(10),
                    itemCount: items.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 10),
                    itemBuilder: (ctx, i) {
                      final c = items[i];
                      return _kanbanCard(context, ref, c, accent);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _kanbanCard(BuildContext context, WidgetRef ref, Candidate c, Color accent) {
    return Container(
      decoration: BoxDecoration(
        color: crm.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: crm.border.faded(0.8)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 13,
                backgroundColor: crm.primary.withValues(alpha: 0.15),
                child: Text(
                  c.name.isNotEmpty ? c.name[0].toUpperCase() : '?',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: crm.primary),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.name,
                      style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700, color: crm.textPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      c.jobTitle.isNotEmpty ? c.jobTitle : 'Applicant',
                      style: TextStyle(fontSize: 11, color: crm.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_horiz_rounded, size: 18, color: crm.textSecondary),
                padding: EdgeInsets.zero,
                onSelected: (action) async {
                  if (action == 'whatsapp') {
                    openCandidateWhatsAppDialog(context, c, crm);
                  } else if (action == 'offer') {
                    onCreateOffer(c);
                  } else if (action == 'edit') {
                    onEditCandidate(c);
                  } else if (action == 'delete') {
                    _confirmDeleteCandidate(context, ref, c);
                  } else {
                    // Update stage
                    await ref.read(recruitmentServiceProvider).saveCandidate({'stage': action}, id: c.id);
                    ref.invalidate(candidatesProvider);
                  }
                },
                itemBuilder: (ctx) => [
                  if (c.phone.isNotEmpty)
                    const PopupMenuItem(
                      value: 'whatsapp',
                      child: Row(
                        children: [
                          Icon(Icons.chat_bubble_rounded, size: 14, color: Color(0xFF128C7E)),
                          SizedBox(width: 8),
                          Text('WhatsApp Chat'),
                        ],
                      ),
                    ),
                  const PopupMenuItem(value: 'edit', child: Text('Edit Candidate Details')),
                  const PopupMenuItem(value: 'offer', child: Text('Generate Offer Letter')),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, size: 14, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Delete Candidate', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(enabled: false, child: Text('Move Stage: ', style: TextStyle(fontWeight: FontWeight.bold))),
                  ...kCandidateStages.where((s) => s != c.stage).map((s) => PopupMenuItem(value: s, child: Text('→ ${titleCase(s)}'))),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _chip(titleCase(c.source), crm.textSecondary),
              if (c.referrer.isNotEmpty) ...[
                const SizedBox(width: 4),
                // Long referrers ("Meta & LinkedIn Ad Campaign") must shrink
                // inside the 250px card instead of overflowing it.
                Expanded(
                  child: Tooltip(
                    message: 'ref: ${c.referrer}',
                    child: Text(
                      'ref: ${c.referrer}',
                      style: TextStyle(fontSize: 10.5, color: crm.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ] else
                const Spacer(),
              if (c.rating > 0) ...[
                Icon(Icons.star_rounded, size: 14, color: const Color(0xFFC9A66B)),
                const SizedBox(width: 2),
                Text('${c.rating}', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: crm.textPrimary)),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Divider(height: 1, color: crm.border.faded(0.5)),
          const SizedBox(height: 6),
          Row(
            children: [
              if (c.phone.isNotEmpty)
                InkWell(
                  onTap: () => openCandidateWhatsAppDialog(context, c, crm),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF25D366).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFF25D366).withValues(alpha: 0.35)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.chat_bubble_rounded, size: 11, color: Color(0xFF128C7E)),
                        SizedBox(width: 4),
                        Text('WhatsApp', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF128C7E))),
                      ],
                    ),
                  ),
                ),
              if (c.resumeUrl.isNotEmpty) ...[
                const SizedBox(width: 5),
                InkWell(
                  onTap: () async {
                    if (await canLaunchUrlString(c.resumeUrl)) {
                      await launchUrlString(c.resumeUrl, mode: LaunchMode.externalApplication);
                    }
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.description_outlined, size: 11, color: Colors.blue),
                        SizedBox(width: 3),
                        Text('CV', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Colors.blue)),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  c.phone,
                  style: TextStyle(fontSize: 10.5, color: crm.textSecondary),
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Job Roles & Organizational Hierarchy Tab ────────────────────────────────

class _JobRolesHierarchyTab extends ConsumerStatefulWidget {
  const _JobRolesHierarchyTab({
    required this.crm,
    required this.onNewRole,
    required this.onEditRole,
    required this.onCreatePlanFromRole,
  });

  final CrmTheme crm;
  final VoidCallback onNewRole;
  final ValueChanged<JobRole> onEditRole;
  final ValueChanged<JobRole> onCreatePlanFromRole;

  @override
  ConsumerState<_JobRolesHierarchyTab> createState() => _JobRolesHierarchyTabState();
}

class _JobRolesHierarchyTabState extends ConsumerState<_JobRolesHierarchyTab> {
  String _selectedDept = '';
  String _viewMode = 'hierarchy'; // 'hierarchy' | 'catalogue'
  String _searchQuery = '';
  String? _selectedRoleId;

  @override
  Widget build(BuildContext context) {
    final rolesAsync = ref.watch(jobRolesProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(jobRolesProvider),
      child: rolesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ListView(children: [AppErrorView(error: e, onRetry: () => ref.invalidate(jobRolesProvider))]),
        data: (allRoles) {
          if (allRoles.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('No organizational roles configured yet.'),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: widget.onNewRole,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Role & Analysis'),
                  ),
                ],
              ),
            );
          }

          // Compute selected role
          final selectedRole = allRoles.firstWhere(
            (r) => r.id == _selectedRoleId || r.roleCode == _selectedRoleId,
            orElse: () => allRoles.firstWhere((r) => r.tier == 3, orElse: () => allRoles.first),
          );

          // Filtering
          final filteredRoles = allRoles.where((r) {
            final matchDept = _selectedDept.isEmpty || r.dept == _selectedDept;
            final matchQuery = _searchQuery.isEmpty ||
                r.designation.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                r.dept.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                r.reportsTo.toLowerCase().contains(_searchQuery.toLowerCase());
            return matchDept && matchQuery;
          }).toList();

          final totalHeadcount = allRoles.fold<int>(0, (sum, r) => sum + r.headcount);
          final depts = allRoles.map((r) => r.dept).toSet().toList()..sort();

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
            children: [
              // ── Header Controls & KPIs ──
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Organizational Role Hierarchy',
                          style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w800, color: widget.crm.textPrimary),
                        ),
                        Text(
                          'Role specifications, reporting lines & unified job analysis rubric (FR-1.1 - FR-1.3)',
                          style: TextStyle(fontSize: 12, color: widget.crm.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  // Dept Filter Dropdown
                  Container(
                    height: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: widget.crm.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: widget.crm.border.faded(0.8)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: (depts.contains(_selectedDept) || _selectedDept.isEmpty) ? _selectedDept : '',
                        dropdownColor: widget.crm.surface,
                        style: TextStyle(fontSize: 12.5, color: widget.crm.textPrimary),
                        items: [
                          DropdownMenuItem(value: '', child: Text('All departments', style: TextStyle(color: widget.crm.textPrimary))),
                          ...depts.map((d) => DropdownMenuItem(value: d, child: Text(d, style: TextStyle(color: widget.crm.textPrimary)))),
                        ],
                        onChanged: (v) => setState(() => _selectedDept = v ?? ''),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // View Switcher
                  Container(
                    decoration: BoxDecoration(
                      color: widget.crm.background,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: widget.crm.border.faded(0.8)),
                    ),
                    padding: const EdgeInsets.all(2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _viewToggleBtn('hierarchy', Icons.account_tree_outlined, 'Hierarchy'),
                        _viewToggleBtn('catalogue', Icons.table_chart_outlined, 'Catalogue'),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    onPressed: widget.onNewRole,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('New Role', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
                    style: FilledButton.styleFrom(
                      backgroundColor: widget.crm.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // ── 4 KPI Summary Cards (Matching HRMS Design) ──
              LayoutBuilder(builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 800;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _kpiStatCard('Hierarchy Structure', 'Board → Teams', '5 Tiers · Apex to Frontline', Icons.account_tree_outlined, widget.crm.primary, isWide),
                    _kpiStatCard('Configured Roles', '${allRoles.length}', 'Across ${depts.length} operational divisions', Icons.badge_outlined, const Color(0xFFC9A66B), isWide),
                    _kpiStatCard('Blueprint Headcount', '$totalHeadcount HC', 'Positions structured in hierarchy', Icons.people_outline, widget.crm.success, isWide),
                    _kpiStatCard('Job Analysis Rubric', '100% Active', 'Feeds CV screening & interviews', Icons.verified_outlined, const Color(0xFF3B5BA5), isWide),
                  ],
                );
              }),

              const SizedBox(height: 20),

              // ── Split Layout: Tree/Catalogue on Left, Inspector on Right ──
              LayoutBuilder(builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 950;

                final leftView = _viewMode == 'hierarchy'
                    ? _buildHierarchyTree(allRoles, filteredRoles, selectedRole)
                    : _buildCatalogueTable(filteredRoles, selectedRole);

                final rightInspector = _buildRoleInspector(selectedRole, allRoles);

                if (isWide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: leftView),
                      const SizedBox(width: 18),
                      SizedBox(width: 400, child: rightInspector),
                    ],
                  );
                } else {
                  return Column(
                    children: [
                      leftView,
                      const SizedBox(height: 20),
                      rightInspector,
                    ],
                  );
                }
              }),
            ],
          );
        },
      ),
    );
  }

  Widget _viewToggleBtn(String mode, IconData icon, String label) {
    final active = _viewMode == mode;
    return InkWell(
      onTap: () => setState(() => _viewMode = mode),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active ? widget.crm.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: active ? hrCardShadow() : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: active ? widget.crm.primary : widget.crm.textSecondary),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                color: active ? widget.crm.primary : widget.crm.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kpiStatCard(String label, String value, String sub, IconData icon, Color color, bool isWide) {
    return Container(
      width: isWide ? 220 : double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: widget.crm.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: widget.crm.border.faded(0.8)),
        boxShadow: hrCardShadow(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, size: 16, color: color),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: widget.crm.textSecondary),
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(value, style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w800, color: widget.crm.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(sub, style: TextStyle(fontSize: 11, color: widget.crm.textSecondary), maxLines: 2, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildHierarchyTree(List<JobRole> allRoles, List<JobRole> filteredRoles, JobRole selectedRole) {
    // Group roles by tier
    final byTier = <int, List<JobRole>>{};
    for (int t = 1; t <= 5; t++) {
      byTier[t] = filteredRoles.where((r) => r.tier == t).toList();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: widget.crm.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: widget.crm.border.faded(0.8)),
        boxShadow: hrCardShadow(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tier Legend
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (int t = 1; t <= 5; t++) ...[
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 8, height: 8, decoration: BoxDecoration(color: _tierColor(t), shape: BoxShape.circle)),
                      const SizedBox(width: 4),
                      Text(_tierLabel(t), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                    ],
                  ),
                  if (t < 5)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Icon(Icons.chevron_right, size: 14, color: widget.crm.textSecondary.faded(0.5)),
                    ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Tiered nodes
          for (int t = 1; t <= 5; t++) ...[
            if (byTier[t]!.isNotEmpty) ...[
              Container(
                margin: const EdgeInsets.only(top: 8, bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _tierColor(t).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_tierIcon(t), size: 14, color: _tierColor(t)),
                    const SizedBox(width: 6),
                    Text(
                      '${_tierLabel(t).toUpperCase()} (${byTier[t]!.length} roles)',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _tierColor(t), letterSpacing: 0.5),
                    ),
                  ],
                ),
              ),
              ...byTier[t]!.map((role) {
                final isSelected = role.id == selectedRole.id || role.roleCode == selectedRole.roleCode;
                // Count direct reports
                final directReports = allRoles.where((r) => r.parentId == role.id || r.parentId == role.roleCode).length;

                return InkWell(
                  onTap: () => setState(() => _selectedRoleId = role.id),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSelected ? widget.crm.primary.withValues(alpha: 0.06) : widget.crm.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? widget.crm.primary : widget.crm.border.faded(0.6),
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(color: _tierColor(role.tier), shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    role.designation,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 13,
                                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
                                      color: widget.crm.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: _bandColor(role.band).withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      role.band,
                                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: _bandColor(role.band)),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Text(role.dept, style: TextStyle(fontSize: 11, color: widget.crm.textSecondary)),
                                  if (role.reportsTo.isNotEmpty) ...[
                                    const SizedBox(width: 6),
                                    Text('•', style: TextStyle(fontSize: 11, color: widget.crm.textSecondary)),
                                    const SizedBox(width: 6),
                                    Icon(Icons.subdirectory_arrow_right_rounded, size: 12, color: widget.crm.textSecondary),
                                    const SizedBox(width: 2),
                                    Text('Reports to: ${role.reportsTo}', style: TextStyle(fontSize: 11, color: widget.crm.textSecondary)),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                        if (directReports > 0)
                          Container(
                            margin: const EdgeInsets.only(right: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: widget.crm.surface,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: widget.crm.border.faded(0.8)),
                            ),
                            child: Text('$directReports direct', style: TextStyle(fontSize: 10.5, color: widget.crm.textSecondary)),
                          ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: widget.crm.surface,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: widget.crm.border.faded(0.8)),
                          ),
                          child: Text('${role.headcount} HC', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: widget.crm.textPrimary)),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildCatalogueTable(List<JobRole> roles, JobRole selectedRole) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: widget.crm.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: widget.crm.border.faded(0.8)),
        boxShadow: hrCardShadow(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            onChanged: (v) => setState(() => _searchQuery = v),
            decoration: InputDecoration(
              hintText: 'Search designation, skills, reporting manager...',
              prefixIcon: const Icon(Icons.search, size: 18),
              isDense: true,
              filled: true,
              fillColor: widget.crm.background,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStatePropertyAll(widget.crm.background),
              dataRowMinHeight: 48,
              dataRowMaxHeight: 56,
              columns: const [
                DataColumn(label: Text('Designation', style: TextStyle(fontWeight: FontWeight.w800))),
                DataColumn(label: Text('Reports To (Hierarchy)', style: TextStyle(fontWeight: FontWeight.w800))),
                DataColumn(label: Text('Department', style: TextStyle(fontWeight: FontWeight.w800))),
                DataColumn(label: Text('Band', style: TextStyle(fontWeight: FontWeight.w800))),
                DataColumn(label: Text('Experience', style: TextStyle(fontWeight: FontWeight.w800))),
                DataColumn(label: Text('Action', style: TextStyle(fontWeight: FontWeight.w800))),
              ],
              rows: roles.map((r) {
                final isSelected = r.id == selectedRole.id || r.roleCode == selectedRole.roleCode;
                return DataRow(
                  selected: isSelected,
                  onSelectChanged: (_) => setState(() => _selectedRoleId = r.id),
                  cells: [
                    DataCell(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(r.designation, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                          Text('Tier ${r.tier} · ${r.team.isNotEmpty ? r.team : 'Core'}', style: TextStyle(fontSize: 11, color: widget.crm.textSecondary)),
                        ],
                      ),
                    ),
                    DataCell(Text(r.reportsTo.isNotEmpty ? r.reportsTo : '—', style: const TextStyle(fontSize: 12))),
                    DataCell(Text(r.dept, style: const TextStyle(fontSize: 12))),
                    DataCell(_chip(r.band, _bandColor(r.band))),
                    DataCell(Text(r.exp, style: const TextStyle(fontSize: 12))),
                    DataCell(
                      OutlinedButton(
                        onPressed: () => setState(() => _selectedRoleId = r.id),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          minimumSize: Size.zero,
                        ),
                        child: const Text('Inspect', style: TextStyle(fontSize: 11)),
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

  Widget _buildRoleInspector(JobRole role, List<JobRole> allRoles) {
    // Compute hierarchy breadcrumb trail: e.g. Board -> CEO -> CTO
    final trail = <JobRole>[];
    JobRole? curr = role;
    int safety = 0;
    while (curr != null && safety < 10) {
      trail.insert(0, curr);
      if (curr.parentId != null && curr.parentId!.isNotEmpty) {
        curr = allRoles.cast<JobRole?>().firstWhere(
              (x) => x?.id == curr?.parentId || x?.roleCode == curr?.parentId,
              orElse: () => null,
            );
      } else {
        break;
      }
      safety++;
    }

    return Container(
      decoration: BoxDecoration(
        color: widget.crm.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: widget.crm.border.faded(0.8)),
        boxShadow: hrCardShadow(elevated: true),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Eyebrow & Badges
          Row(
            children: [
              Expanded(
                child: Text(
                  'ROLE CHARTER & JOB ANALYSIS',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: const Color(0xFFC9A66B)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(color: widget.crm.success.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                child: Text('Active Blueprint', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: widget.crm.success)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            role.designation,
            style: GoogleFonts.plusJakartaSans(fontSize: 16.5, fontWeight: FontWeight.w800, color: widget.crm.textPrimary),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              _chip(role.band, _bandColor(role.band)),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  role.dept,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: widget.crm.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Text('•', style: TextStyle(fontSize: 12, color: widget.crm.textSecondary)),
              const SizedBox(width: 6),
              Text('${role.headcount} ${role.headcount > 1 ? 'Positions' : 'Position'}', style: TextStyle(fontSize: 11.5, color: widget.crm.textSecondary)),
            ],
          ),

          const SizedBox(height: 12),
          // Breadcrumbs
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (int i = 0; i < trail.length; i++) ...[
                  Text(
                    trail[i].shortTitle.isNotEmpty ? trail[i].shortTitle : trail[i].designation,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: i == trail.length - 1 ? FontWeight.w800 : FontWeight.w500,
                      color: i == trail.length - 1 ? widget.crm.primary : widget.crm.textSecondary,
                    ),
                  ),
                  if (i < trail.length - 1)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(Icons.chevron_right, size: 12, color: widget.crm.textSecondary.faded(0.5)),
                    ),
                ],
              ],
            ),
          ),

          const Divider(height: 24),

          // Part 1: Role Purpose & Responsibilities
          Row(
            children: [
              Icon(Icons.explore_outlined, size: 14, color: widget.crm.primary),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  '1. ROLE PURPOSE & CHARTERED DUTIES',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: widget.crm.textSecondary, letterSpacing: 0.6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: widget.crm.background, borderRadius: BorderRadius.circular(8)),
            child: Text(
              role.purpose.isNotEmpty ? role.purpose : 'Operational responsibilities and deliverables per department standards.',
              style: TextStyle(fontSize: 12, color: widget.crm.textPrimary, height: 1.45),
            ),
          ),
          if (role.responsibilities.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('Core Responsibilities:', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: widget.crm.textPrimary)),
            const SizedBox(height: 4),
            ...role.responsibilities.map((resp) => Padding(
                  padding: const EdgeInsets.only(bottom: 4, left: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('• ', style: TextStyle(fontSize: 12, color: widget.crm.primary, fontWeight: FontWeight.w800)),
                      Expanded(child: Text(resp, style: TextStyle(fontSize: 11.5, color: widget.crm.textPrimary, height: 1.35))),
                    ],
                  ),
                )),
          ],
          if (role.deliverables.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Key Deliverables & KPIs:', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: widget.crm.textPrimary)),
            const SizedBox(height: 2),
            Text(role.deliverables, style: TextStyle(fontSize: 11.5, color: widget.crm.textSecondary)),
          ],

          const Divider(height: 24),

          // Part 2: Job Analysis & Screening Requisites
          Row(
            children: [
              Icon(Icons.checklist_rounded, size: 15, color: const Color(0xFFC9A66B)),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  '2. JOB ANALYSIS & SCREENING RUBRIC',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: widget.crm.textSecondary, letterSpacing: 0.6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: widget.crm.background, borderRadius: BorderRadius.circular(8)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Experience Band', style: TextStyle(fontSize: 10.5, color: widget.crm.textSecondary)),
                      const SizedBox(height: 2),
                      Text(role.exp, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: widget.crm.textPrimary)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: widget.crm.background, borderRadius: BorderRadius.circular(8)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Qualification', style: TextStyle(fontSize: 10.5, color: widget.crm.textSecondary)),
                      const SizedBox(height: 2),
                      Text(role.qual.isNotEmpty ? role.qual : 'Relevant Degree', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: widget.crm.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ),
            ],
          ),

          if (role.skills.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Required Skill Proficiency Matrix (0 - 5.0):', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: widget.crm.textPrimary)),
            const SizedBox(height: 6),
            ...role.skills.map((s) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(s.name, style: TextStyle(fontSize: 11.5, color: widget.crm.textPrimary)),
                          Text('${s.score}', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: widget.crm.primary)),
                        ],
                      ),
                      const SizedBox(height: 3),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: s.score / 5.0,
                          backgroundColor: widget.crm.border.faded(0.5),
                          valueColor: AlwaysStoppedAnimation(widget.crm.primary),
                          minHeight: 4,
                        ),
                      ),
                    ],
                  ),
                )),
          ],

          if (role.competencies.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('Competencies for Interview Scorecard:', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: widget.crm.textPrimary)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: role.competencies.map((c) => _chip(c, widget.crm.textSecondary)).toList(),
            ),
          ],

          const SizedBox(height: 18),

          // CTAs
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => widget.onCreatePlanFromRole(role),
                  icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
                  label: const Text('Create Hiring Plan', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFC9A66B),
                    foregroundColor: const Color(0xFF4A101D),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () => widget.onEditRole(role),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Edit', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Job Posts Tab ───────────────────────────────────────────────────────────

class _JobPostsTab extends ConsumerStatefulWidget {
  const _JobPostsTab({
    required this.crm,
    required this.onNewPost,
    required this.onEditPost,
  });

  final CrmTheme crm;
  final VoidCallback onNewPost;
  final ValueChanged<JobPost> onEditPost;

  @override
  ConsumerState<_JobPostsTab> createState() => _JobPostsTabState();
}

class _JobPostsTabState extends ConsumerState<_JobPostsTab> {
  String _filter = 'all';
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final postsAsync = ref.watch(jobPostsProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(jobPostsProvider),
      child: postsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ListView(children: [AppErrorView(error: e, onRetry: () => ref.invalidate(jobPostsProvider))]),
        data: (allPosts) {
          final posts = allPosts.where((p) {
            if (_filter != 'all' && p.status != _filter) return false;
            if (_search.isNotEmpty &&
                !p.title.toLowerCase().contains(_search.toLowerCase()) &&
                !p.department.toLowerCase().contains(_search.toLowerCase())) {
              return false;
            }
            return true;
          }).toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
            children: [
              // Search & Filter Bar
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: widget.crm.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: widget.crm.border.faded(0.8)),
                  boxShadow: hrCardShadow(),
                ),
                // Wide: one row. Narrow: search on top, chips + button wrap below.
                child: LayoutBuilder(builder: (context, box) {
                  final search = TextField(
                    onChanged: (v) => setState(() => _search = v.trim()),
                    decoration: InputDecoration(
                      hintText: 'Search job title or department...',
                      prefixIcon: const Icon(Icons.search_rounded, size: 18),
                      isDense: true,
                      filled: true,
                      fillColor: widget.crm.background,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  );
                  final controls = Wrap(
                    spacing: 6,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _filterChip('all', 'All (${allPosts.length})'),
                      _filterChip('open', 'Open'),
                      _filterChip('on_hold', 'On Hold'),
                      _filterChip('closed', 'Closed'),
                      OutlinedButton.icon(
                        onPressed: () => _openWebhookDialog(context),
                        icon: const Icon(Icons.hub_outlined, size: 16),
                        label: const Text('Webhooks & Integrations', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: widget.crm.primary,
                          side: BorderSide(color: widget.crm.primary.faded(0.5)),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                    ],
                  );
                  if (box.maxWidth < 900) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [search, const SizedBox(height: 10), controls],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: search),
                      const SizedBox(width: 12),
                      controls,
                    ],
                  );
                }),
              ),

              const SizedBox(height: 16),

              if (posts.isEmpty)
                Container(
                  padding: const EdgeInsets.all(40),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: widget.crm.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: widget.crm.border.faded(0.8)),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.work_off_outlined, size: 48, color: widget.crm.textSecondary.faded(0.6)),
                      const SizedBox(height: 12),
                      Text('No job posts found', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w800, color: widget.crm.textPrimary)),
                      const SizedBox(height: 4),
                      Text('Create an opening against an approved hiring plan.', style: TextStyle(fontSize: 12.5, color: widget.crm.textSecondary)),
                      const SizedBox(height: 14),
                      FilledButton.icon(
                        onPressed: widget.onNewPost,
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Create Job Post'),
                        style: FilledButton.styleFrom(backgroundColor: widget.crm.primary),
                      ),
                    ],
                  ),
                )
              else
                ...posts.map((p) => _jobPostCard(p)),
            ],
          );
        },
      ),
    );
  }

  void _openWebhookDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => _WebhookAutomationDialog(crm: widget.crm),
    );
  }

  void _openShareSocialDialog(BuildContext context, JobPost p) {
    showDialog(
      context: context,
      builder: (_) => _ShareJobDialog(crm: widget.crm, jobPost: p),
    );
  }

  Widget _filterChip(String key, String label) {
    final active = _filter == key;
    return ChoiceChip(
      label: Text(label),
      selected: active,
      onSelected: (_) => setState(() => _filter = key),
      selectedColor: widget.crm.primary,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: active ? Colors.white : widget.crm.textPrimary,
      ),
      backgroundColor: widget.crm.background,
      side: BorderSide(color: widget.crm.border.faded(0.8)),
    );
  }

  Widget _jobPostCard(JobPost p) {
    // Phones: the applicant count and buttons move under the title block.
    final narrow = MediaQuery.sizeOf(context).width < 700;
    final info = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                p.title,
                style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w800, color: widget.crm.textPrimary),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            _chip(p.status == 'open' ? 'Published' : titleCase(p.status), p.status == 'open' ? widget.crm.success : widget.crm.textSecondary),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '${p.department} · ${titleCase(p.type)} · ${p.openings} opening(s)',
          style: TextStyle(fontSize: 12, color: widget.crm.textSecondary),
        ),
        if (p.description.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            p.description,
            style: TextStyle(fontSize: 12, color: widget.crm.textPrimary.faded(0.9)),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
    final applicants = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: widget.crm.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: widget.crm.border.faded(0.8)),
      ),
      child: Text(
        '${p.candidateCount} applicants',
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: widget.crm.primary),
      ),
    );
    final shareBtn = FilledButton.icon(
      onPressed: () => _openShareSocialDialog(context, p),
      icon: const Icon(Icons.share_outlined, size: 14),
      label: const Text('Share to LinkedIn/Meta', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFF0077B5),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        minimumSize: Size.zero,
      ),
    );
    final editBtn = OutlinedButton.icon(
      onPressed: () => widget.onEditPost(p),
      icon: const Icon(Icons.edit_outlined, size: 14),
      label: const Text('Edit', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        minimumSize: Size.zero,
      ),
    );
    final icon = Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: widget.crm.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(Icons.campaign_outlined, color: widget.crm.primary, size: 22),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: widget.crm.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: widget.crm.border.faded(0.8)),
        boxShadow: hrCardShadow(),
      ),
      child: narrow
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [icon, const SizedBox(width: 14), Expanded(child: info)],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [applicants, shareBtn, editBtn],
                ),
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                icon,
                const SizedBox(width: 14),
                Expanded(child: info),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    applicants,
                    const SizedBox(height: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [shareBtn, const SizedBox(width: 6), editBtn],
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}

// ─── Social Sharing & Webhook Automation Dialogs ──────────────────────────────

class _ShareJobDialog extends ConsumerStatefulWidget {
  const _ShareJobDialog({required this.crm, required this.jobPost});
  final CrmTheme crm;
  final JobPost jobPost;

  @override
  ConsumerState<_ShareJobDialog> createState() => _ShareJobDialogState();
}

class _ShareJobDialogState extends ConsumerState<_ShareJobDialog> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _data;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final res = await ref.read(recruitmentServiceProvider).getSocialCopy(widget.jobPost.id);
      if (mounted) setState(() { _data = res; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = friendlyErrorMessage(e); _loading = false; });
    }
  }

  void _copy(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$label copied to clipboard!')));
  }

  Future<void> _openUrl(String? url) async {
    if (url == null || url.isEmpty) return;
    if (await canLaunchUrlString(url)) {
      await launchUrlString(url);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF0077B5).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.campaign_rounded, color: Color(0xFF0077B5), size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Share Opening to Social Media', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w800)),
                Text(widget.jobPost.title, style: TextStyle(fontSize: 12, color: widget.crm.textSecondary)),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 620,
        height: 480,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text(_error!))
                : Column(
                    children: [
                      TabBar(
                        controller: _tabCtrl,
                        labelColor: widget.crm.primary,
                        unselectedLabelColor: widget.crm.textSecondary,
                        indicatorColor: widget.crm.primary,
                        tabs: const [
                          Tab(icon: Icon(Icons.business_center_rounded, size: 16), text: 'LinkedIn'),
                          Tab(icon: Icon(Icons.camera_alt_outlined, size: 16), text: 'Meta (IG & FB)'),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: TabBarView(
                          controller: _tabCtrl,
                          children: [
                            _buildPlatformTab(
                              title: 'LinkedIn Company / Personal Post',
                              platformColor: const Color(0xFF0077B5),
                              copy: _data?['linkedin']?['copy'] ?? '',
                              shareUrl: _data?['linkedin']?['shareUrl'] ?? '',
                              shareBtnLabel: 'Open LinkedIn Share Window',
                            ),
                            _buildPlatformTab(
                              title: 'Instagram & Facebook Hiring Post',
                              platformColor: const Color(0xFFE1306C),
                              copy: _data?['meta']?['copy'] ?? '',
                              shareUrl: _data?['meta']?['facebookShareUrl'] ?? '',
                              shareBtnLabel: 'Share on Facebook',
                              secondaryShareUrl: _data?['meta']?['whatsappShareUrl'],
                              secondaryShareLabel: 'Share on WhatsApp',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
      ],
    );
  }

  Widget _buildPlatformTab({
    required String title,
    required Color platformColor,
    required String copy,
    required String shareUrl,
    required String shareBtnLabel,
    String? secondaryShareUrl,
    String? secondaryShareLabel,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: widget.crm.background,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: widget.crm.border.faded(0.8)),
            ),
            child: SingleChildScrollView(
              child: SelectableText(
                copy,
                style: GoogleFonts.robotoMono(fontSize: 12, height: 1.45, color: widget.crm.textPrimary),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          alignment: WrapAlignment.end,
          children: [
            OutlinedButton.icon(
              onPressed: () => _copy(copy, 'Job Post text'),
              icon: const Icon(Icons.copy_rounded, size: 15),
              label: const Text('Copy Text'),
            ),
            FilledButton.icon(
              onPressed: () => _openUrl(shareUrl),
              icon: const Icon(Icons.open_in_new_rounded, size: 15),
              label: Text(shareBtnLabel),
              style: FilledButton.styleFrom(backgroundColor: platformColor),
            ),
            if (secondaryShareUrl != null && secondaryShareLabel != null)
              FilledButton.icon(
                onPressed: () => _openUrl(secondaryShareUrl),
                icon: const Icon(Icons.send_rounded, size: 15),
                label: Text(secondaryShareLabel),
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF25D366)),
              ),
          ],
        ),
      ],
    );
  }
}

class _WebhookAutomationDialog extends ConsumerStatefulWidget {
  const _WebhookAutomationDialog({required this.crm});
  final CrmTheme crm;

  @override
  ConsumerState<_WebhookAutomationDialog> createState() => _WebhookAutomationDialogState();
}

class _WebhookAutomationDialogState extends ConsumerState<_WebhookAutomationDialog> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _config;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await ref.read(recruitmentServiceProvider).getWebhookConfig();
      if (mounted) setState(() { _config = res; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = friendlyErrorMessage(e); _loading = false; });
    }
  }

  void _copy(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$label copied!')));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: widget.crm.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.hub_outlined, color: widget.crm.primary, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Recruitment Automation & Webhooks', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w800)),
                Text('Automate applicant intake from LinkedIn Easy Apply & Meta Lead Ads', style: TextStyle(fontSize: 12, color: widget.crm.textSecondary)),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 650,
        height: 520,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text(_error!))
                : SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionTitle('1. Universal Applicant Webhook (Zapier / Make / Custom)'),
                        const SizedBox(height: 6),
                        _infoRow('Webhook Endpoint', _config?['webhookUrl'] ?? ''),
                        const SizedBox(height: 8),
                        _infoRow('Secret Header', '${_config?['secretHeader']}: ${_config?['secret']}'),
                        const SizedBox(height: 16),

                        _sectionTitle('2. Meta Webhook Verification (Direct Facebook & IG Ads)'),
                        const SizedBox(height: 6),
                        _infoRow('Meta Callback URL', _config?['metaWebhookUrl'] ?? ''),
                        const SizedBox(height: 8),
                        _infoRow('Verify Token', _config?['metaVerifyToken'] ?? ''),
                        const SizedBox(height: 16),

                        _sectionTitle('3. How It Automates Your Hiring:'),
                        const SizedBox(height: 8),
                        _stepCard(
                          icon: Icons.flash_on_rounded,
                          title: 'Zero Manual CV Entry',
                          desc: 'Applicants from LinkedIn Lead Gen or Instagram Story Lead Ads hit the webhook and appear in your CRM Pipeline immediately in the "Applied" stage.',
                        ),
                        const SizedBox(height: 8),
                        _stepCard(
                          icon: Icons.notifications_active_outlined,
                          title: 'Instant HR Alerts',
                          desc: 'Admins and HR recruiters receive real-time in-app notifications whenever a candidate submits their portfolio.',
                        ),
                        const SizedBox(height: 8),
                        _stepCard(
                          icon: Icons.description_outlined,
                          title: '1-Click Official Offer Letter',
                          desc: 'Move candidates from Interview to Offer, and generate the Nizan letterhead PDF with compensation breakdown and signatures.',
                        ),
                      ],
                    ),
                  ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
      ],
    );
  }

  Widget _sectionTitle(String text) {
    return Text(text, style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w800, color: widget.crm.primary));
  }

  Widget _infoRow(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: widget.crm.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: widget.crm.border.faded(0.8)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: widget.crm.textSecondary)),
                const SizedBox(height: 2),
                SelectableText(value, style: GoogleFonts.robotoMono(fontSize: 11.5, fontWeight: FontWeight.w600, color: widget.crm.textPrimary)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy_rounded, size: 16),
            tooltip: 'Copy $label',
            onPressed: () => _copy(value, label),
          ),
        ],
      ),
    );
  }

  Widget _stepCard({required IconData icon, required String title, required String desc}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: widget.crm.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: widget.crm.border.faded(0.6)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: widget.crm.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: widget.crm.textPrimary)),
                const SizedBox(height: 2),
                Text(desc, style: TextStyle(fontSize: 11.5, color: widget.crm.textSecondary, height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Candidate WhatsApp Quick Chat Dialog ────────────────────────────────────

void openCandidateWhatsAppDialog(BuildContext context, Candidate candidate, CrmTheme crm) {
  showDialog(
    context: context,
    builder: (_) => _CandidateWhatsAppDialog(crm: crm, candidate: candidate),
  );
}

class _CandidateWhatsAppDialog extends StatefulWidget {
  const _CandidateWhatsAppDialog({required this.crm, required this.candidate});
  final CrmTheme crm;
  final Candidate candidate;

  @override
  State<_CandidateWhatsAppDialog> createState() => _CandidateWhatsAppDialogState();
}

class _CandidateWhatsAppDialogState extends State<_CandidateWhatsAppDialog> {
  late TextEditingController _msgCtrl;
  int _selectedTemplateIdx = 0;
  late List<Map<String, String>> _templates;

  @override
  void initState() {
    super.initState();
    final name = widget.candidate.name;
    final role = widget.candidate.jobTitle.isNotEmpty ? widget.candidate.jobTitle : 'Job Application';

    _templates = [
      {
        'title': 'Screening Call',
        'subtitle': 'Request 10-min phone screening',
        'text': 'Hi $name, greetings from Nizan HR! We reviewed your application for the $role role and would like to schedule a quick 10-minute screening call with you. What time works best for you today?',
      },
      {
        'title': 'Interview Invitation',
        'subtitle': 'Invite shortlisted applicant',
        'text': 'Hi $name, congratulations! Your profile has been shortlisted for an interview for the $role position at Nizan. Could you please share your availability for tomorrow?',
      },
      {
        'title': 'Request CV / Portfolio',
        'subtitle': 'Ask candidate to upload resume',
        'text': 'Hi $name, thank you for applying for the $role position at Nizan. Could you please share your updated resume/portfolio PDF here on WhatsApp?',
      },
      {
        'title': 'Offer Discussion',
        'subtitle': 'Discuss compensation & joining',
        'text': 'Hi $name, greetings from Nizan HR! We are pleased to discuss your offer details and compensation for the $role position. Are you available for a brief call?',
      },
    ];

    _msgCtrl = TextEditingController(text: _templates[0]['text']);
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    super.dispose();
  }

  void _selectTemplate(int idx) {
    setState(() {
      _selectedTemplateIdx = idx;
      _msgCtrl.text = _templates[idx]['text']!;
    });
  }

  String _cleanPhoneDigits(String raw) {
    var digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 10) {
      digits = '91$digits';
    }
    return digits;
  }

  Future<void> _launchWhatsApp() async {
    final phone = widget.candidate.phone.trim();
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No phone number recorded for this candidate.')),
      );
      return;
    }
    final digits = _cleanPhoneDigits(phone);
    final text = _msgCtrl.text.trim();
    final url = 'https://wa.me/$digits?text=${Uri.encodeComponent(text)}';

    try {
      if (await canLaunchUrlString(url)) {
        await launchUrlString(url, mode: LaunchMode.externalApplication);
      } else {
        await launchUrlString(url);
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not open WhatsApp: $e')));
      }
    }
  }

  void _copy() {
    Clipboard.setData(ClipboardData(text: _msgCtrl.text.trim()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('WhatsApp message copied to clipboard!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.candidate;
    final hasPhone = c.phone.trim().isNotEmpty;

    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      contentPadding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
      actionsPadding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF25D366).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.chat_bubble_rounded, color: Color(0xFF128C7E), size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('WhatsApp Recruiter Quick Chat', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w800)),
                Text(
                  hasPhone ? '${c.name} (${c.phone}) • ${c.jobTitle.isNotEmpty ? c.jobTitle : 'Applicant'}' : '${c.name} • No phone number',
                  style: TextStyle(fontSize: 11.5, color: widget.crm.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 580,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!hasPhone)
                Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: widget.crm.destructive.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: widget.crm.destructive.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, size: 18, color: widget.crm.destructive),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'This candidate has no phone number recorded. Please edit the candidate to add their phone number.',
                          style: TextStyle(fontSize: 11.5, color: widget.crm.destructive, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),

              Text('Choose Message Template:', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: widget.crm.textSecondary)),
              const SizedBox(height: 8),

              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(_templates.length, (i) {
                  final t = _templates[i];
                  final isSelected = _selectedTemplateIdx == i;
                  return ChoiceChip(
                    label: Text(t['title']!),
                    selected: isSelected,
                    onSelected: (_) => _selectTemplate(i),
                    selectedColor: const Color(0xFF25D366).withValues(alpha: 0.2),
                    labelStyle: TextStyle(
                      fontSize: 11.5,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                      color: isSelected ? const Color(0xFF128C7E) : widget.crm.textPrimary,
                    ),
                    side: BorderSide(
                      color: isSelected ? const Color(0xFF128C7E) : widget.crm.border.faded(0.8),
                    ),
                  );
                }),
              ),

              const SizedBox(height: 12),
              Text('Message Preview (Editable):', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: widget.crm.textSecondary)),
              const SizedBox(height: 6),

              TextField(
                controller: _msgCtrl,
                maxLines: 5,
                style: GoogleFonts.plusJakartaSans(fontSize: 12.5, height: 1.4),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: widget.crm.background,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),

              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.bolt_rounded, size: 14, color: const Color(0xFF128C7E)),
                  const SizedBox(width: 4),
                  Text(
                    'Opens WhatsApp Web or App with this text ready to send. No contact saving needed.',
                    style: TextStyle(fontSize: 11, color: widget.crm.textSecondary),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        OutlinedButton.icon(
          onPressed: _copy,
          icon: const Icon(Icons.copy_rounded, size: 14),
          label: const Text('Copy Text'),
        ),
        FilledButton.icon(
          onPressed: hasPhone ? _launchWhatsApp : null,
          icon: const Icon(Icons.send_rounded, size: 15),
          label: const Text('Open in WhatsApp'),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF25D366),
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}

// ─── Candidates Directory Tab ────────────────────────────────────────────────

class _CandidatesListTab extends ConsumerStatefulWidget {
  const _CandidatesListTab({
    required this.crm,
    required this.onAddCandidate,
    required this.onEditCandidate,
    required this.onCreateOffer,
  });

  final CrmTheme crm;
  final VoidCallback onAddCandidate;
  final ValueChanged<Candidate> onEditCandidate;
  final ValueChanged<Candidate> onCreateOffer;

  @override
  ConsumerState<_CandidatesListTab> createState() => _CandidatesListTabState();
}

class _CandidatesListTabState extends ConsumerState<_CandidatesListTab> {
  String _selectedStage = 'all';
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final candidatesAsync = ref.watch(candidatesProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(candidatesProvider),
      child: candidatesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ListView(children: [AppErrorView(error: e, onRetry: () => ref.invalidate(candidatesProvider))]),
        data: (allCandidates) {
          final candidates = allCandidates.where((c) {
            if (_selectedStage != 'all' && c.stage != _selectedStage) return false;
            final q = _search.toLowerCase();
            if (q.isNotEmpty &&
                !c.name.toLowerCase().contains(q) &&
                !c.email.toLowerCase().contains(q) &&
                !c.jobTitle.toLowerCase().contains(q)) {
              return false;
            }
            return true;
          }).toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
            children: [
              // Search & Stage Filter Bar
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: widget.crm.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: widget.crm.border.faded(0.8)),
                  boxShadow: hrCardShadow(),
                ),
                child: Column(
                  children: [
                    TextField(
                      onChanged: (v) => setState(() => _search = v.trim()),
                      decoration: InputDecoration(
                        hintText: 'Search candidate name, email, or applied role...',
                        prefixIcon: const Icon(Icons.search_rounded, size: 18),
                        isDense: true,
                        filled: true,
                        fillColor: widget.crm.background,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _stageFilterChip('all', 'All (${allCandidates.length})'),
                                ...kCandidateStages.map((s) => Padding(
                                      padding: const EdgeInsets.only(left: 6),
                                      child: _stageFilterChip(s, titleCase(s)),
                                    )),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        FilledButton.icon(
                          onPressed: () => _openBulkImportDialog(context),
                          icon: const Icon(Icons.table_chart_outlined, size: 15),
                          label: const Text('Import Excel / CSV Leads', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF107C41), // Excel Forest Green
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            minimumSize: Size.zero,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              if (candidates.isEmpty)
                Container(
                  padding: const EdgeInsets.all(40),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: widget.crm.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: widget.crm.border.faded(0.8)),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.person_search_outlined, size: 48, color: widget.crm.textSecondary.faded(0.6)),
                      const SizedBox(height: 12),
                      Text('No candidates matched', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w800, color: widget.crm.textPrimary)),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: widget.onAddCandidate,
                        icon: const Icon(Icons.person_add_alt_1_rounded),
                        label: const Text('Add Candidate'),
                        style: FilledButton.styleFrom(backgroundColor: widget.crm.primary),
                      ),
                    ],
                  ),
                )
              else
                ...candidates.map((c) => _candidateCard(c)),
            ],
          );
        },
      ),
    );
  }

  void _openBulkImportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => _BulkImportDialog(crm: widget.crm),
    ).then((val) {
      if (val == true) {
        ref.invalidate(candidatesProvider);
      }
    });
  }

  Widget _stageFilterChip(String key, String label) {
    final active = _selectedStage == key;
    return ChoiceChip(
      label: Text(label),
      selected: active,
      onSelected: (_) => setState(() => _selectedStage = key),
      selectedColor: widget.crm.primary,
      labelStyle: TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w700,
        color: active ? Colors.white : widget.crm.textPrimary,
      ),
      backgroundColor: widget.crm.background,
      side: BorderSide(color: widget.crm.border.faded(0.8)),
    );
  }

  Widget _candidateCard(Candidate c) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: widget.crm.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: widget.crm.border.faded(0.8)),
        boxShadow: hrCardShadow(),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: widget.crm.primary.withValues(alpha: 0.12),
            child: Text(
              c.name.isNotEmpty ? c.name[0].toUpperCase() : '?',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: widget.crm.primary),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      c.name,
                      style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700, color: widget.crm.textPrimary),
                    ),
                    const SizedBox(width: 8),
                    _chip(titleCase(c.stage), _stageColor(c.stage, widget.crm)),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  c.jobTitle.isNotEmpty ? c.jobTitle : 'Applicant',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: widget.crm.primary),
                ),
                const SizedBox(height: 4),
                Text(
                  '${c.email} · ${c.phone.isNotEmpty ? c.phone : 'No phone'} · Source: ${titleCase(c.source)}${c.referrer.isNotEmpty ? ' (Ref: ${c.referrer})' : ''}',
                  style: TextStyle(fontSize: 11.5, color: widget.crm.textSecondary),
                ),
              ],
            ),
          ),
          Wrap(
            spacing: 6,
            children: [
              if (c.phone.isNotEmpty)
                FilledButton.icon(
                  onPressed: () => openCandidateWhatsAppDialog(context, c, widget.crm),
                  icon: const Icon(Icons.chat_bubble_rounded, size: 12),
                  label: const Text('WhatsApp', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    minimumSize: Size.zero,
                  ),
                ),
              if (c.resumeUrl.isNotEmpty)
                OutlinedButton.icon(
                  onPressed: () async {
                    if (await canLaunchUrlString(c.resumeUrl)) {
                      await launchUrlString(c.resumeUrl, mode: LaunchMode.externalApplication);
                    }
                  },
                  icon: const Icon(Icons.description_outlined, size: 14),
                  label: const Text('View CV', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4)),
                ),
              OutlinedButton.icon(
                onPressed: () => widget.onCreateOffer(c),
                icon: const Icon(Icons.description_outlined, size: 14),
                label: const Text('Offer', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4)),
              ),
              OutlinedButton(
                onPressed: () => widget.onEditCandidate(c),
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4)),
                child: const Text('Edit', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                tooltip: 'Delete Candidate',
                onPressed: () => _confirmDeleteCandidate(context, ref, c),
                style: IconButton.styleFrom(
                  padding: const EdgeInsets.all(6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Bulk Import Candidates Dialog ──────────────────────────────────────────

class _BulkImportDialog extends ConsumerStatefulWidget {
  const _BulkImportDialog({required this.crm});
  final CrmTheme crm;

  @override
  ConsumerState<_BulkImportDialog> createState() => _BulkImportDialogState();
}

class _BulkImportDialogState extends ConsumerState<_BulkImportDialog> {
  bool _isFileMode = true;
  String? _jobPostId;
  String _source = 'meta';
  final _campaignCtrl = TextEditingController(text: 'Meta & LinkedIn Ad Campaign');
  final _rawTextCtrl = TextEditingController();

  // File upload state
  String? _fileName;
  int? _fileSizeBytes;
  CandidateFileImportResult? _fileResult;
  bool _onlyRecruited = false;
  bool _pickingFile = false;
  bool _importing = false;

  @override
  void dispose() {
    _campaignCtrl.dispose();
    _rawTextCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _pickingFile = true);
    try {
      final picked = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['xlsx', 'xls', 'csv'],
        withData: true,
      );
      if (picked == null || !mounted) {
        setState(() => _pickingFile = false);
        return;
      }
      final file = picked.files.single;
      final bytes = file.bytes;
      if (bytes == null) {
        setState(() => _pickingFile = false);
        messenger.showSnackBar(const SnackBar(content: Text('Could not read file data from device.')));
        return;
      }

      final parsed = parseCandidateFile(bytes, file.name);
      setState(() {
        _fileName = file.name;
        _fileSizeBytes = file.size;
        _fileResult = parsed;
        _onlyRecruited = parsed.recruitedCount > 0;
        _pickingFile = false;
      });

      if (parsed.warnings.isNotEmpty && mounted) {
        messenger.showSnackBar(SnackBar(content: Text(parsed.warnings.first)));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _pickingFile = false);
        messenger.showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e, fallback: 'Failed to read file.'))));
      }
    }
  }

  void _clearFile() {
    setState(() {
      _fileName = null;
      _fileSizeBytes = null;
      _fileResult = null;
      _onlyRecruited = false;
    });
  }

  void _copySampleCsv() {
    Clipboard.setData(ClipboardData(text: getRecruitmentSampleCsvTemplate()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sample CSV template copied to clipboard! You can paste it into Excel or Google Sheets.')),
    );
  }

  List<Map<String, dynamic>> _parsePastedCandidates() {
    final text = _rawTextCtrl.text.trim();
    if (text.isEmpty) return [];

    final lines = text.split('\n');
    final List<Map<String, dynamic>> list = [];

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;

      if (line.toLowerCase().startsWith('name,') || line.toLowerCase().startsWith('full name,')) {
        continue;
      }

      final parts = line.contains('\t')
          ? line.split('\t')
          : line.contains('|')
              ? line.split('|')
              : line.split(',');

      if (parts.isNotEmpty) {
        final name = parts[0].trim();
        if (name.isEmpty) continue;

        String phone = '';
        String email = '';
        String resumeUrl = '';
        String notes = '';

        for (int i = 1; i < parts.length; i++) {
          final p = parts[i].trim();
          if (p.contains('@')) {
            email = p;
          } else if (RegExp(r'^\+?[0-9\s-]{8,15}$').hasMatch(p)) {
            phone = p;
          } else if (p.startsWith('http://') || p.startsWith('https://')) {
            resumeUrl = p;
          } else if (p.isNotEmpty) {
            notes = notes.isEmpty ? p : '$notes; $p';
          }
        }

        list.add({
          'fullName': name,
          'email': email,
          'phone': phone,
          'resumeUrl': resumeUrl,
          'notes': notes,
        });
      }
    }
    return list;
  }

  int get _candidateCount {
    if (_isFileMode) {
      if (_fileResult == null) return 0;
      if (_onlyRecruited && _fileResult!.recruitedCount > 0) {
        return _fileResult!.recruitedCount;
      }
      return _fileResult!.candidates.length;
    } else {
      return _parsePastedCandidates().length;
    }
  }

  Future<void> _submit() async {
    final List<Map<String, dynamic>> payload;
    if (_isFileMode) {
      if (_fileResult == null || _fileResult!.candidates.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a valid Excel or CSV file with candidate rows.')),
        );
        return;
      }
      final list = (_onlyRecruited && _fileResult!.recruitedCount > 0)
          ? _fileResult!.recruitedCandidates
          : _fileResult!.candidates;
      payload = list.map((c) => c.toJson()).toList();
    } else {
      payload = _parsePastedCandidates();
      if (payload.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please paste at least one candidate record.')),
        );
        return;
      }
    }

    setState(() => _importing = true);
    try {
      final res = await ref.read(recruitmentServiceProvider).bulkImportCandidates(
            candidates: payload,
            jobPostId: _jobPostId,
            source: _source,
            campaignName: _campaignCtrl.text.trim(),
          );

      if (mounted) {
        setState(() => _importing = false);
        final msg = res['message'] ?? 'Imported successfully!';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _importing = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final postsAsync = ref.watch(jobPostsProvider);
    final count = _candidateCount;

    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      contentPadding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
      actionsPadding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF107C41).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.table_chart_rounded, color: Color(0xFF107C41), size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Import Candidates from Excel / CSV', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w800)),
                Text('Upload spreadsheet exports or paste leads from Meta Ads & LinkedIn', style: TextStyle(fontSize: 11.5, color: widget.crm.textSecondary)),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 640,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Mode Switcher ──
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: widget.crm.background,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: widget.crm.border.faded(0.7)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _isFileMode = true),
                        borderRadius: BorderRadius.circular(7),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _isFileMode ? widget.crm.surface : Colors.transparent,
                            borderRadius: BorderRadius.circular(7),
                            boxShadow: _isFileMode ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 1))] : null,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.file_upload_outlined, size: 16, color: _isFileMode ? const Color(0xFF107C41) : widget.crm.textSecondary),
                              const SizedBox(width: 6),
                              Text(
                                'Upload Excel / CSV File',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: _isFileMode ? FontWeight.w800 : FontWeight.w500,
                                  color: _isFileMode ? widget.crm.textPrimary : widget.crm.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _isFileMode = false),
                        borderRadius: BorderRadius.circular(7),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: !_isFileMode ? widget.crm.surface : Colors.transparent,
                            borderRadius: BorderRadius.circular(7),
                            boxShadow: !_isFileMode ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 1))] : null,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.edit_note_rounded, size: 16, color: !_isFileMode ? widget.crm.primary : widget.crm.textSecondary),
                              const SizedBox(width: 6),
                              Text(
                                'Paste Text / Quick Copy',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: !_isFileMode ? FontWeight.w800 : FontWeight.w500,
                                  color: !_isFileMode ? widget.crm.textPrimary : widget.crm.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // ── Destination & Source Controls ──
              postsAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text(friendlyErrorMessage(e)),
                data: (posts) {
                  return DropdownButtonFormField<String?>(
                    initialValue: posts.any((p) => p.id == _jobPostId) ? _jobPostId : null,
                    isExpanded: true,
                    dropdownColor: widget.crm.surface,
                    style: TextStyle(fontSize: 13, color: widget.crm.textPrimary),
                    decoration: const InputDecoration(
                      labelText: 'Assign to Job Opening (optional)',
                      isDense: true,
                    ),
                    items: [
                      DropdownMenuItem<String?>(
                        value: null,
                        child: Text('No specific job (General Applicant Pool)', style: TextStyle(color: widget.crm.textPrimary)),
                      ),
                      ...posts.map((p) => DropdownMenuItem<String?>(
                            value: p.id,
                            child: Text('${p.title} (${p.department})', style: TextStyle(color: widget.crm.textPrimary)),
                          )),
                    ],
                    onChanged: (v) => setState(() => _jobPostId = v),
                  );
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _source,
                      isExpanded: true,
                      dropdownColor: widget.crm.surface,
                      style: TextStyle(fontSize: 13, color: widget.crm.textPrimary),
                      decoration: const InputDecoration(labelText: 'Lead Source', isDense: true),
                      items: [
                        DropdownMenuItem(value: 'meta', child: Text('Meta (Facebook / Instagram Ads)', style: TextStyle(color: widget.crm.textPrimary))),
                        DropdownMenuItem(value: 'linkedin', child: Text('LinkedIn (Easy Apply / Ads)', style: TextStyle(color: widget.crm.textPrimary))),
                        DropdownMenuItem(value: 'job_portal', child: Text('Job Portal (Indeed / Naukri)', style: TextStyle(color: widget.crm.textPrimary))),
                        DropdownMenuItem(value: 'agency', child: Text('Staffing Agency', style: TextStyle(color: widget.crm.textPrimary))),
                        DropdownMenuItem(value: 'website', child: Text('Direct Website', style: TextStyle(color: widget.crm.textPrimary))),
                      ],
                      onChanged: (v) => setState(() => _source = v ?? 'meta'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _campaignCtrl,
                      decoration: const InputDecoration(labelText: 'Campaign / Tag', isDense: true),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // ── Body: File Mode vs Paste Mode ──
              if (_isFileMode) ...[
                if (_fileName == null)
                  InkWell(
                    onTap: _pickingFile ? null : _pickFile,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
                      decoration: BoxDecoration(
                        color: widget.crm.background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF107C41).withValues(alpha: 0.4), style: BorderStyle.solid, width: 1.5),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_pickingFile)
                            const SizedBox(width: 32, height: 32, child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF107C41)))
                          else
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF107C41).withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.cloud_upload_outlined, size: 30, color: Color(0xFF107C41)),
                            ),
                          const SizedBox(height: 10),
                          Text(
                            _pickingFile ? 'Reading file...' : 'Click to Select Excel (.xlsx, .xls) or CSV file',
                            style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700, color: widget.crm.textPrimary),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Supports standard exports from Facebook Lead Ads, LinkedIn Ads, Indeed, or Google Sheets',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 11.5, color: widget.crm.textSecondary),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: _copySampleCsv,
                            icon: const Icon(Icons.copy_rounded, size: 14),
                            label: const Text('Copy Sample CSV Template', style: TextStyle(fontSize: 11)),
                            style: OutlinedButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else ...[
                  // File info card
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF107C41).withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF107C41).withValues(alpha: 0.25)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF107C41),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.description, color: Colors.white, size: 18),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(_fileName!, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13), overflow: TextOverflow.ellipsis),
                                  Text(
                                    '${((_fileSizeBytes ?? 0) / 1024).toStringAsFixed(1)} KB • Detected ${_fileResult?.candidates.length ?? 0} candidate(s)',
                                    style: TextStyle(fontSize: 11, color: widget.crm.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                            TextButton.icon(
                              onPressed: _pickFile,
                              icon: const Icon(Icons.sync, size: 14),
                              label: const Text('Change', style: TextStyle(fontSize: 11.5)),
                              style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                            ),
                            IconButton(
                              onPressed: _clearFile,
                              icon: const Icon(Icons.close, size: 16),
                              tooltip: 'Remove File',
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                        ),
                        if (_fileResult?.detectedHeaders != null && _fileResult!.detectedHeaders!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.check_circle_outline, size: 13, color: const Color(0xFF107C41)),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  'Columns matched: ${_fileResult!.detectedHeaders}',
                                  style: const TextStyle(fontSize: 11, color: Color(0xFF107C41), fontWeight: FontWeight.w600),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Candidate preview snippet
                  if (_fileResult != null && _fileResult!.candidates.isNotEmpty) ...[
                    if (_fileResult!.recruitedCount > 0) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF107C41).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF107C41).withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_rounded, color: Color(0xFF107C41), size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Found ${_fileResult!.recruitedCount} Recruited / Green-marked employee (${_fileResult!.recruitedCandidates.map((c) => c.fullName).join(", ")})',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF107C41)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          ChoiceChip(
                            label: Text('Import ONLY Selected (${_fileResult!.recruitedCount})'),
                            selected: _onlyRecruited,
                            onSelected: (_) => setState(() => _onlyRecruited = true),
                            selectedColor: const Color(0xFF107C41).withValues(alpha: 0.2),
                            labelStyle: TextStyle(
                              fontSize: 11,
                              fontWeight: _onlyRecruited ? FontWeight.w800 : FontWeight.w500,
                              color: _onlyRecruited ? const Color(0xFF107C41) : widget.crm.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: Text('Import All (${_fileResult!.candidates.length}) with Interview Statuses'),
                            selected: !_onlyRecruited,
                            onSelected: (_) => setState(() => _onlyRecruited = false),
                            selectedColor: widget.crm.primary.withValues(alpha: 0.15),
                            labelStyle: TextStyle(
                              fontSize: 11,
                              fontWeight: !_onlyRecruited ? FontWeight.w800 : FontWeight.w500,
                              color: !_onlyRecruited ? widget.crm.primary : widget.crm.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                    ],

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _onlyRecruited && _fileResult!.recruitedCount > 0
                              ? 'Recruited Candidates (${_fileResult!.recruitedCandidates.length}):'
                              : 'Candidate Preview (First ${_fileResult!.candidates.take(6).length} of ${_fileResult!.candidates.length}):',
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: widget.crm.textSecondary),
                        ),
                        Text(
                          'Duplicates will be skipped automatically',
                          style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: widget.crm.textSecondary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 190),
                      decoration: BoxDecoration(
                        color: widget.crm.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: widget.crm.border.faded(0.8)),
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: (_onlyRecruited && _fileResult!.recruitedCount > 0
                                ? _fileResult!.recruitedCandidates
                                : _fileResult!.candidates)
                            .take(8)
                            .length,
                        separatorBuilder: (context, index) => Divider(height: 1, color: widget.crm.border.faded(0.4)),
                        itemBuilder: (context, idx) {
                          final list = _onlyRecruited && _fileResult!.recruitedCount > 0
                              ? _fileResult!.recruitedCandidates
                              : _fileResult!.candidates;
                          final c = list[idx];
                          return Container(
                            color: c.isRecruited ? const Color(0xFF107C41).withValues(alpha: 0.08) : Colors.transparent,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 12,
                                  backgroundColor: c.isRecruited
                                      ? const Color(0xFF107C41)
                                      : widget.crm.primary.withValues(alpha: 0.15),
                                  child: Text(
                                    c.fullName.isNotEmpty ? c.fullName[0].toUpperCase() : '?',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w800,
                                      color: c.isRecruited ? Colors.white : widget.crm.primary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  flex: 3,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(c.fullName, style: TextStyle(fontSize: 12, fontWeight: c.isRecruited ? FontWeight.w800 : FontWeight.w700), overflow: TextOverflow.ellipsis),
                                      if (c.location != null)
                                        Text(c.location!, style: TextStyle(fontSize: 10, color: widget.crm.textSecondary)),
                                    ],
                                  ),
                                ),
                                if (c.phone != null) ...[
                                  const SizedBox(width: 6),
                                  Expanded(
                                    flex: 2,
                                    child: Text(c.phone!, style: TextStyle(fontSize: 11, color: widget.crm.textSecondary), overflow: TextOverflow.ellipsis),
                                  ),
                                ],
                                if (c.isRecruited)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF107C41),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text('SELECTED / HIRED', style: TextStyle(fontSize: 9.5, color: Colors.white, fontWeight: FontWeight.w800)),
                                  )
                                else if (c.status != null && c.status!.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: c.stage == 'rejected' ? Colors.red.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      c.status!,
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        color: c.stage == 'rejected' ? Colors.red.shade700 : Colors.orange.shade800,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ] else ...[
                // Paste Mode
                Text(
                  'Paste Candidate Rows (One per line: Name, Phone, Email, Resume/Drive Link):',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: widget.crm.textSecondary),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _rawTextCtrl,
                  maxLines: 7,
                  onChanged: (_) => setState(() {}),
                  style: GoogleFonts.robotoMono(fontSize: 12),
                  decoration: InputDecoration(
                    hintText: 'Ananya Sharma, +91 9876543210, ananya@gmail.com, https://drive.google.com/cv.pdf\nFatima Noor, +91 9845112233, fatima@outlook.com, Portfolio: instagram.com/fatima_mua\nSneha Menon, +91 9744556677, sneha@gmail.com',
                    filled: true,
                    fillColor: widget.crm.background,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.info_outline, size: 14, color: widget.crm.textSecondary),
                    const SizedBox(width: 6),
                    Text(
                      'Detected ${_parsePastedCandidates().length} candidate(s) to import. Duplicates are auto-skipped.',
                      style: TextStyle(fontSize: 11.5, color: widget.crm.textSecondary),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _importing ? null : () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton.icon(
          onPressed: (_importing || count == 0) ? null : _submit,
          icon: _importing
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.check_rounded, size: 16),
          label: Text(_importing ? 'Importing...' : 'Import $count Candidates'),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF107C41),
          ),
        ),
      ],
    );
  }
}

// ─── Offer Letters Tab ───────────────────────────────────────────────────────

class _OffersTab extends ConsumerStatefulWidget {
  const _OffersTab({required this.crm});
  final CrmTheme crm;

  @override
  ConsumerState<_OffersTab> createState() => _OffersTabState();
}

class _OffersTabState extends ConsumerState<_OffersTab> {
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    final offersAsync = ref.watch(offersProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(offersProvider),
      child: offersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ListView(children: [AppErrorView(error: e, onRetry: () => ref.invalidate(offersProvider))]),
        data: (allOffers) {
          final offers = allOffers.where((o) => _filter == 'all' || o.status == _filter).toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
            children: [
              // Filter Chips
              Row(
                children: [
                  _chipBtn('all', 'All (${allOffers.length})'),
                  const SizedBox(width: 8),
                  _chipBtn('sent', 'Sent / Pending'),
                  const SizedBox(width: 8),
                  _chipBtn('accepted', 'Accepted'),
                  const SizedBox(width: 8),
                  _chipBtn('declined', 'Declined'),
                ],
              ),
              const SizedBox(height: 16),
              if (offers.isEmpty)
                Container(
                  padding: const EdgeInsets.all(40),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: widget.crm.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: widget.crm.border.faded(0.8)),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.description_outlined, size: 48, color: widget.crm.textSecondary.faded(0.6)),
                      const SizedBox(height: 12),
                      Text('No offer letters issued yet', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w800, color: widget.crm.textPrimary)),
                      const SizedBox(height: 4),
                      Text('Generate offers from the Candidate cards or directory.', style: TextStyle(fontSize: 12, color: widget.crm.textSecondary)),
                    ],
                  ),
                )
              else
                ...offers.map((o) => _offerCard(o)),
            ],
          );
        },
      ),
    );
  }

  Widget _chipBtn(String key, String label) {
    final active = _filter == key;
    return ChoiceChip(
      label: Text(label),
      selected: active,
      onSelected: (_) => setState(() => _filter = key),
      selectedColor: widget.crm.primary,
      labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: active ? Colors.white : widget.crm.textPrimary),
      backgroundColor: widget.crm.surface,
      side: BorderSide(color: widget.crm.border.faded(0.8)),
    );
  }

  Widget _offerCard(Offer o) {
    final isAccepted = o.status == 'accepted';
    final isPending = o.status == 'sent' || o.status == 'draft';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: widget.crm.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isAccepted ? widget.crm.success.withValues(alpha: 0.4) : widget.crm.border.faded(0.8)),
        boxShadow: hrCardShadow(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'OFFER OF EMPLOYMENT · ${o.candidateName}',
                      style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w800, color: widget.crm.textPrimary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${o.designation} · ${o.department.isNotEmpty ? o.department : 'General'}',
                      style: TextStyle(fontSize: 12, color: widget.crm.textSecondary),
                    ),
                  ],
                ),
              ),
              _chip(titleCase(o.status), isAccepted ? widget.crm.success : (o.status == 'declined' ? widget.crm.destructive : const Color(0xFFC9A66B))),
            ],
          ),
          const Divider(height: 20),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('NET SALARY', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: widget.crm.textSecondary)),
                    const SizedBox(height: 2),
                    Text('₹ ${o.salary.toStringAsFixed(0)}', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w800, color: widget.crm.primary)),
                    if (o.hra > 0 || o.incentive > 0) ...[
                      const SizedBox(height: 2),
                      Wrap(
                        spacing: 6,
                        children: [
                          if (o.hra > 0)
                            Text('HRA: ₹${o.hra.toStringAsFixed(0)}', style: TextStyle(fontSize: 10.5, color: widget.crm.textSecondary)),
                          if (o.incentive > 0)
                            Text('Incentive: ₹${o.incentive.toStringAsFixed(0)}', style: TextStyle(fontSize: 10.5, color: widget.crm.success, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (o.joiningDate != null)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('PROPOSED JOINING', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: widget.crm.textSecondary)),
                      const SizedBox(height: 2),
                      Text(_fmt(o.joiningDate), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              OutlinedButton.icon(
                onPressed: () async {
                  try {
                    final safeName = o.candidateName.replaceAll(RegExp(r'\s+'), '_');
                    await previewOrDownloadNizanHrDocument(
                      filename: 'Offer_Letter_$safeName',
                      documentBuilder: () => generateOfferLetterPdf(offer: o),
                    );
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
                    }
                  }
                },
                icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
                label: const Text('Download Letter'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: widget.crm.primary,
                  side: BorderSide(color: widget.crm.primary.withValues(alpha: 0.5)),
                ),
              ),
              const SizedBox(width: 8),
              if (isPending) ...[
                OutlinedButton(
                  onPressed: () async {
                    await ref.read(recruitmentServiceProvider).declineOffer(o.id);
                    ref.invalidate(offersProvider);
                  },
                  style: OutlinedButton.styleFrom(foregroundColor: widget.crm.destructive),
                  child: const Text('Decline'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: () async {
                    await ref.read(recruitmentServiceProvider).acceptOffer(o.id);
                    ref.invalidate(offersProvider);
                    ref.invalidate(candidatesProvider);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Offer accepted! Employee onboarded and synced.')),
                      );
                    }
                  },
                  icon: const Icon(Icons.check_rounded, size: 16),
                  label: const Text('Accept & Hire'),
                  style: FilledButton.styleFrom(backgroundColor: widget.crm.success),
                ),
              ],
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                tooltip: 'Delete Offer',
                onPressed: () => _confirmDeleteOffer(context, ref, o),
                style: IconButton.styleFrom(
                  padding: const EdgeInsets.all(6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Dialogs ─────────────────────────────────────────────────────────────────

/// New Hiring Plan Dialog matching user screenshot and HRMS_Design.html FR-1.1 - FR-1.5.
class _HiringPlanDialog extends ConsumerStatefulWidget {
  const _HiringPlanDialog({this.existing, this.fromRole});
  final HiringPlan? existing;
  final JobRole? fromRole;

  @override
  ConsumerState<_HiringPlanDialog> createState() => _HiringPlanDialogState();
}

class _HiringPlanDialogState extends ConsumerState<_HiringPlanDialog> {
  late final TextEditingController _desig;
  late final TextEditingController _openings;
  late final TextEditingController _justification;
  late final TextEditingController _jd;
  late final TextEditingController _skills;
  late final TextEditingController _exp;
  late final TextEditingController _comp;

  String _dept = 'Bridal Styling';
  String _type = 'Full-time';
  String _selectedReporting = 'Studio Operations Head';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final p = widget.existing;
    final r = widget.fromRole;

    _desig = TextEditingController(text: p?.designation ?? r?.designation ?? '');
    _openings = TextEditingController(text: p != null ? '${p.openings}' : (r != null ? '${r.headcount}' : '2'));
    _selectedReporting = p != null && p.reportingLine.isNotEmpty
        ? p.reportingLine
        : (r != null && r.reportsTo.isNotEmpty ? r.reportsTo : 'Studio Operations Head');
    _justification = TextEditingController(text: p?.businessJustification ?? '');
    _jd = TextEditingController(
      text: p?.jobDescription ?? (r != null ? '${r.purpose}\n\nKey Responsibilities:\n${r.responsibilities.join('\n')}' : ''),
    );
    _skills = TextEditingController(text: p?.requiredSkills ?? (r != null ? r.skills.map((s) => s.name).join(', ') : ''));
    _exp = TextEditingController(text: p?.experienceBand ?? r?.exp ?? '4-6 yrs');
    _comp = TextEditingController(text: p?.competencies ?? (r != null ? r.competencies.join(', ') : 'Client handling, speed, hygiene'));

    if (p != null && p.department.isNotEmpty) {
      _dept = p.department;
    } else if (r != null && r.dept.isNotEmpty) {
      _dept = r.dept;
    }
    if (p != null && p.employmentType.isNotEmpty) {
      _type = p.employmentType;
    }
  }

  @override
  void dispose() {
    _desig.dispose();
    _openings.dispose();
    _justification.dispose();
    _jd.dispose();
    _skills.dispose();
    _exp.dispose();
    _comp.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final desigText = _desig.text.trim();
    if (desigText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a designation title')));
      return;
    }

    setState(() => _busy = true);
    try {
      final body = {
        'designation': desigText,
        'department': _dept,
        'openings': int.tryParse(_openings.text.trim()) ?? 1,
        'employmentType': _type,
        'reportingLine': _selectedReporting,
        'businessJustification': _justification.text.trim(),
        'jobDescription': _jd.text.trim(),
        'requiredSkills': _skills.text.trim(),
        'experienceBand': _exp.text.trim(),
        'competencies': _comp.text.trim(),
        'status': widget.existing?.status ?? 'draft',
        if (widget.fromRole != null) 'roleId': widget.fromRole!.id,
      };

      await ref.read(recruitmentServiceProvider).saveHiringPlan(body, id: widget.existing?.id);
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
    final rolesAsync = ref.watch(jobRolesProvider);
    final roles = rolesAsync.asData?.value ?? [];

    // Distinct list of hierarchy reporting manager options
    final reportingOptions = <String>[
      'Studio Operations Head',
      'Head of Bridal',
      'Academy Head (Principal)',
      'IT Head',
      'Finance Head',
      'Chief Operating Officer (COO)',
      'Chief Technology Officer (CTO)',
      'Chief Financial Officer (CFO)',
      'Chief Executive Officer (CEO)',
      'Board of Directors / Apex',
    ];

    for (final role in roles) {
      if (role.designation.isNotEmpty && !reportingOptions.contains(role.designation)) {
        reportingOptions.add(role.designation);
      }
    }

    if (_selectedReporting.isNotEmpty && !reportingOptions.contains(_selectedReporting)) {
      reportingOptions.insert(0, _selectedReporting);
    }

    const depts = [
      'Bridal Styling',
      'Academy',
      'Studio Ops',
      'Studio & Services Ops',
      'Finance & Accounts',
      'Technology & Systems (IT)',
      'Fleet',
      'Executive / Governance',
    ];

    return Dialog(
      backgroundColor: crm.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Modal Header (matching design file)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: crm.primary,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.note_add_outlined, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    widget.existing == null ? 'New hiring plan' : 'Edit hiring plan',
                    style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 20),
                    onPressed: () => Navigator.of(context).pop(false),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),

            // Form Body
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _desig,
                      decoration: InputDecoration(
                        labelText: 'Designation *',
                        hintText: 'e.g. Senior Bridal Stylist',
                        border: const OutlineInputBorder(),
                        isDense: true,
                        suffixIcon: roles.isNotEmpty
                            ? PopupMenuButton<String>(
                                tooltip: 'Select from Job Roles',
                                icon: const Icon(Icons.arrow_drop_down, size: 22),
                                onSelected: (roleTitle) {
                                  final match = roles.where((r) => r.designation == roleTitle).firstOrNull;
                                  setState(() {
                                    _desig.text = roleTitle;
                                    if (match != null) {
                                      if (match.dept.isNotEmpty) _dept = match.dept;
                                      if (match.purpose.isNotEmpty) {
                                        _jd.text = '${match.purpose}\n\nKey Responsibilities:\n${match.responsibilities.join('\n')}';
                                      }
                                      if (match.skills.isNotEmpty) _skills.text = match.skills.map((s) => s.name).join(', ');
                                      if (match.exp.isNotEmpty) _exp.text = match.exp;
                                      if (match.competencies.isNotEmpty) _comp.text = match.competencies.join(', ');
                                      if (match.reportsTo.isNotEmpty) _selectedReporting = match.reportsTo;
                                    } else {
                                      _dept = resolveDepartmentForRole(roleTitle: roleTitle, roles: roles);
                                    }
                                  });
                                },
                                itemBuilder: (_) => roles
                                    .map((r) => PopupMenuItem(value: r.designation, child: Text('${r.designation} (${r.dept})', style: const TextStyle(fontSize: 13))))
                                    .toList(),
                              )
                            : null,
                      ),
                      onChanged: (val) {
                        final autoDept = resolveDepartmentForRole(roleTitle: val, roles: roles);
                        if (autoDept != _dept) {
                          setState(() => _dept = autoDept);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            key: ValueKey('hiring_plan_dept_$_dept'),
                            initialValue: depts.contains(_dept) ? _dept : depts.first,
                            isExpanded: true,
                            dropdownColor: crm.surface,
                            style: TextStyle(fontSize: 13, color: crm.textPrimary),
                            decoration: const InputDecoration(labelText: 'Department (Auto-linked)', border: OutlineInputBorder(), isDense: true),
                            items: depts.map((d) => DropdownMenuItem(value: d, child: Text(d, style: TextStyle(fontSize: 13, color: crm.textPrimary)))).toList(),
                            onChanged: (v) => setState(() => _dept = v ?? 'Bridal Styling'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _openings,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Openings', hintText: 'e.g. 2', border: OutlineInputBorder(), isDense: true),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _type,
                            dropdownColor: crm.surface,
                            style: TextStyle(fontSize: 13, color: crm.textPrimary),
                            decoration: const InputDecoration(labelText: 'Employment type', border: OutlineInputBorder(), isDense: true),
                            items: const ['Full-time', 'Probation', 'Contract', 'Internship', 'Part-time']
                                .map((t) => DropdownMenuItem(value: t, child: Text(t, style: TextStyle(fontSize: 13, color: crm.textPrimary))))
                                .toList(),
                            onChanged: (v) => setState(() => _type = v ?? 'Full-time'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            key: ValueKey('hiring_plan_reporting_$_selectedReporting'),
                            initialValue: reportingOptions.contains(_selectedReporting)
                                ? _selectedReporting
                                : (reportingOptions.isNotEmpty ? reportingOptions.first : null),
                            isExpanded: true,
                            dropdownColor: crm.surface,
                            style: TextStyle(fontSize: 13, color: crm.textPrimary),
                            decoration: const InputDecoration(
                              labelText: 'Reporting line (Hierarchy)',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            items: reportingOptions.map((opt) {
                              final match = roles.where((x) => x.designation == opt).firstOrNull;
                              final meta = match != null ? ' (Tier ${match.tier})' : '';
                              return DropdownMenuItem<String>(
                                value: opt,
                                child: Text(
                                  '$opt$meta',
                                  style: const TextStyle(fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: (v) {
                              if (v != null) {
                                setState(() => _selectedReporting = v);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _justification,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Business justification · FR-1.1',
                        hintText: 'Why this role is needed now',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _jd,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Job description — purpose & responsibilities · FR-1.2',
                        hintText: 'Role purpose, key responsibilities, deliverables',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _skills,
                            decoration: const InputDecoration(
                              labelText: 'Required skills / qualifications · FR-1.3',
                              hintText: 'e.g. HD bridal, airbrush; diploma',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _exp,
                            decoration: const InputDecoration(
                              labelText: 'Experience band',
                              hintText: 'e.g. 4-6 yrs',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _comp,
                      decoration: const InputDecoration(
                        labelText: 'Key competencies to assess',
                        hintText: 'e.g. Client handling, speed, hygiene',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Modal Footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: crm.border.faded(0.6)))),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: _busy ? null : () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    onPressed: _busy ? null : _save,
                    icon: _busy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.check, size: 16),
                    label: Text(widget.existing == null ? 'Create as draft' : 'Save changes'),
                    style: FilledButton.styleFrom(
                      backgroundColor: crm.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Role Definition Modal to add / edit a role in the organizational hierarchy.
class _RoleDefDialog extends ConsumerStatefulWidget {
  const _RoleDefDialog({this.existing});
  final JobRole? existing;

  @override
  ConsumerState<_RoleDefDialog> createState() => _RoleDefDialogState();
}

class _RoleDefDialogState extends ConsumerState<_RoleDefDialog> {
  late final TextEditingController _desig;
  late final TextEditingController _shortTitle;
  late final TextEditingController _reportsTo;
  late final TextEditingController _headcount;
  late final TextEditingController _purpose;
  late final TextEditingController _resp;
  late final TextEditingController _deliv;
  late final TextEditingController _exp;
  late final TextEditingController _qual;
  late final TextEditingController _skills;
  late final TextEditingController _comp;

  String _dept = 'Bridal Styling';
  int _tier = 5;
  String _band = 'L3';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final r = widget.existing;
    _desig = TextEditingController(text: r?.designation ?? '');
    _shortTitle = TextEditingController(text: r?.shortTitle ?? '');
    _reportsTo = TextEditingController(text: r?.reportsTo ?? '');
    _headcount = TextEditingController(text: r != null ? '${r.headcount}' : '1');
    _purpose = TextEditingController(text: r?.purpose ?? '');
    _resp = TextEditingController(text: r?.responsibilities.join('\n') ?? '');
    _deliv = TextEditingController(text: r?.deliverables ?? '');
    _exp = TextEditingController(text: r?.exp ?? '2-4 yrs');
    _qual = TextEditingController(text: r?.qual ?? '');
    _skills = TextEditingController(text: r?.skills.map((s) => s.name).join(', ') ?? '');
    _comp = TextEditingController(text: r?.competencies.join(', ') ?? '');

    if (r != null) {
      _dept = r.dept;
      _tier = r.tier;
      _band = r.band;
    }
  }

  @override
  void dispose() {
    _desig.dispose();
    _shortTitle.dispose();
    _reportsTo.dispose();
    _headcount.dispose();
    _purpose.dispose();
    _resp.dispose();
    _deliv.dispose();
    _exp.dispose();
    _qual.dispose();
    _skills.dispose();
    _comp.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final desigText = _desig.text.trim();
    if (desigText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a designation title')));
      return;
    }

    setState(() => _busy = true);
    try {
      final skillNames = _skills.text.split(',').map((s) => s.trim()).filter((s) => s.isNotEmpty).toList();
      final body = {
        'designation': desigText,
        'shortTitle': _shortTitle.text.trim().isNotEmpty ? _shortTitle.text.trim() : desigText,
        'dept': _dept,
        'tier': _tier,
        'band': _band,
        'reportsTo': _reportsTo.text.trim(),
        'headcount': int.tryParse(_headcount.text.trim()) ?? 1,
        'purpose': _purpose.text.trim(),
        'responsibilities': _resp.text.split('\n').map((s) => s.trim()).filter((s) => s.isNotEmpty).toList(),
        'deliverables': _deliv.text.trim(),
        'exp': _exp.text.trim(),
        'qual': _qual.text.trim(),
        'skills': skillNames.map((n) => {'name': n, 'score': 4.5}).toList(),
        'competencies': _comp.text.split(',').map((s) => s.trim()).filter((s) => s.isNotEmpty).toList(),
      };

      await ref.read(recruitmentServiceProvider).saveJobRole(body, id: widget.existing?.id);
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
    final rolesAsync = ref.watch(jobRolesProvider);
    final allRoles = rolesAsync.asData?.value ?? [];

    final reportsToOptions = <String>[
      'Studio Operations Head',
      'Head of Bridal',
      'IT Head',
      'Finance Head',
      'Academy Head (Principal)',
      'Chief Operating Officer (COO)',
      'Chief Technology Officer (CTO)',
      'Chief Financial Officer (CFO)',
      'Chief Executive Officer (CEO)',
      'Board of Directors / Apex',
    ];

    for (final r in allRoles) {
      if (r.designation.isNotEmpty && !reportsToOptions.contains(r.designation)) {
        reportsToOptions.add(r.designation);
      }
    }

    final curReportsTo = _reportsTo.text.trim();
    if (curReportsTo.isNotEmpty && !reportsToOptions.contains(curReportsTo)) {
      reportsToOptions.insert(0, curReportsTo);
    }

    const depts = [
      'Bridal Styling',
      'Academy',
      'Studio Ops',
      'Studio & Services Ops',
      'Finance & Accounts',
      'Technology & Systems (IT)',
      'Fleet',
      'Executive / Governance',
    ];

    return Dialog(
      backgroundColor: crm.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: crm.primary,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.account_tree_outlined, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    widget.existing == null ? 'New Role & Analysis' : 'Edit Role & Analysis',
                    style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 20),
                    onPressed: () => Navigator.of(context).pop(false),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    TextField(controller: _desig, decoration: const InputDecoration(labelText: 'Designation Title *', border: OutlineInputBorder(), isDense: true)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: depts.contains(_dept) ? _dept : depts.first,
                            decoration: const InputDecoration(labelText: 'Department', border: OutlineInputBorder(), isDense: true),
                            items: depts.map((d) => DropdownMenuItem(value: d, child: Text(d, style: const TextStyle(fontSize: 13)))).toList(),
                            onChanged: (v) => setState(() => _dept = v ?? 'Bridal Styling'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            initialValue: _tier,
                            decoration: const InputDecoration(labelText: 'Hierarchy Tier', border: OutlineInputBorder(), isDense: true),
                            items: const [
                              DropdownMenuItem(value: 1, child: Text('Tier 1: Board')),
                              DropdownMenuItem(value: 2, child: Text('Tier 2: CEO')),
                              DropdownMenuItem(value: 3, child: Text('Tier 3: C-Suite')),
                              DropdownMenuItem(value: 4, child: Text('Tier 4: Head')),
                              DropdownMenuItem(value: 5, child: Text('Tier 5: Team')),
                            ],
                            onChanged: (v) => setState(() => _tier = v ?? 5),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _band,
                            decoration: const InputDecoration(labelText: 'Grade Band', border: OutlineInputBorder(), isDense: true),
                            items: const ['L6', 'L5', 'L4', 'L3', 'L2', 'L1']
                                .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                                .toList(),
                            onChanged: (v) => setState(() => _band = v ?? 'L3'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            key: ValueKey('role_def_reports_to_$curReportsTo'),
                            initialValue: reportsToOptions.contains(curReportsTo)
                                ? curReportsTo
                                : (reportsToOptions.isNotEmpty ? reportsToOptions.first : null),
                            isExpanded: true,
                            decoration: const InputDecoration(labelText: 'Reports To (Hierarchy)', border: OutlineInputBorder(), isDense: true),
                            items: reportsToOptions.map((p) {
                              final match = allRoles.where((x) => x.designation == p).firstOrNull;
                              final meta = match != null ? ' (Tier ${match.tier})' : '';
                              return DropdownMenuItem<String>(
                                value: p,
                                child: Text('$p$meta', style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
                              );
                            }).toList(),
                            onChanged: (v) {
                              if (v != null) {
                                setState(() => _reportsTo.text = v);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 90,
                          child: TextField(
                            controller: _headcount,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Headcount', border: OutlineInputBorder(), isDense: true),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(controller: _purpose, maxLines: 2, decoration: const InputDecoration(labelText: 'Role Purpose', border: OutlineInputBorder())),
                    const SizedBox(height: 12),
                    TextField(controller: _resp, maxLines: 3, decoration: const InputDecoration(labelText: 'Core Responsibilities (one per line)', border: OutlineInputBorder())),
                    const SizedBox(height: 12),
                    TextField(controller: _deliv, decoration: const InputDecoration(labelText: 'Deliverables & KPIs', border: OutlineInputBorder(), isDense: true)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: TextField(controller: _exp, decoration: const InputDecoration(labelText: 'Experience Band', hintText: 'e.g. 4-6 yrs', border: OutlineInputBorder(), isDense: true))),
                        const SizedBox(width: 12),
                        Expanded(child: TextField(controller: _qual, decoration: const InputDecoration(labelText: 'Qualification', border: OutlineInputBorder(), isDense: true))),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(controller: _skills, decoration: const InputDecoration(labelText: 'Key Skills (comma-separated)', border: OutlineInputBorder(), isDense: true)),
                    const SizedBox(height: 12),
                    TextField(controller: _comp, decoration: const InputDecoration(labelText: 'Competencies for Scorecard (comma-separated)', border: OutlineInputBorder(), isDense: true)),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: crm.border.faded(0.6)))),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(onPressed: _busy ? null : () => Navigator.of(context).pop(false), child: const Text('Cancel')),
                  const SizedBox(width: 10),
                  FilledButton(
                    onPressed: _busy ? null : _save,
                    style: FilledButton.styleFrom(backgroundColor: crm.primary),
                    child: _busy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Save Role'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

extension _IterableFilter<T> on Iterable<T> {
  Iterable<T> filter(bool Function(T) test) => where(test);
}

class _JobPostDialog extends ConsumerStatefulWidget {
  const _JobPostDialog({
    this.existing,
    this.defaultTitle,
    this.defaultDept,
    this.defaultOpenings,
  });

  final JobPost? existing;
  final String? defaultTitle;
  final String? defaultDept;
  final int? defaultOpenings;

  @override
  ConsumerState<_JobPostDialog> createState() => _JobPostDialogState();
}

class _JobPostDialogState extends ConsumerState<_JobPostDialog> {
  late final TextEditingController _title;
  late final TextEditingController _openings;
  late final TextEditingController _desc;
  String _selectedDept = 'Bridal Styling';
  bool _deptInitialized = false;
  String _type = 'full-time';
  String _status = 'open';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final p = widget.existing;
    _title = TextEditingController(text: p?.title ?? widget.defaultTitle ?? '');
    _openings = TextEditingController(text: p != null ? '${p.openings}' : (widget.defaultOpenings != null ? '${widget.defaultOpenings}' : '1'));
    _desc = TextEditingController(text: p?.description ?? '');
    if (p != null && p.department.isNotEmpty) {
      _selectedDept = p.department;
      _deptInitialized = true;
    } else if (widget.defaultDept != null && widget.defaultDept!.isNotEmpty) {
      _selectedDept = widget.defaultDept!;
      _deptInitialized = true;
    }
    if (p != null) {
      _type = p.type;
      _status = p.status;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _openings.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please provide a job title')));
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(recruitmentServiceProvider).saveJobPost(
        {
          'title': title,
          'department': _selectedDept,
          'type': _type,
          'openings': int.tryParse(_openings.text.trim()) ?? 1,
          'description': _desc.text.trim(),
          'status': _status,
        },
        id: widget.existing?.id,
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
    final roles = ref.watch(jobRolesProvider).asData?.value ?? [];
    final plans = ref.watch(hiringPlansProvider).asData?.value ?? [];

    if (!_deptInitialized && _title.text.trim().isNotEmpty) {
      _selectedDept = resolveDepartmentForRole(
        roleTitle: _title.text.trim(),
        roles: roles,
        plans: plans,
      );
      _deptInitialized = true;
    }

    final deptOptions = <String>[...kRecruitmentDepartments];
    if (_selectedDept.isNotEmpty && !deptOptions.contains(_selectedDept)) {
      deptOptions.insert(0, _selectedDept);
    }

    void onRoleSelected(String roleTitle) {
      _title.text = roleTitle;
      final autoDept = resolveDepartmentForRole(
        roleTitle: roleTitle,
        roles: roles,
        plans: plans,
      );
      setState(() => _selectedDept = autoDept);
    }

    return Dialog(
      backgroundColor: crm.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Modal Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: crm.primary,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.campaign_outlined, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    widget.existing == null ? 'New Job Post · FR-1.6' : 'Edit Job Post',
                    style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 20),
                    onPressed: () => Navigator.of(context).pop(false),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),

            // Form Body
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _title,
                      decoration: InputDecoration(
                        labelText: 'Job Title *',
                        hintText: 'e.g. Senior Dev-ops engineer',
                        border: const OutlineInputBorder(),
                        isDense: true,
                        suffixIcon: (plans.isNotEmpty || roles.isNotEmpty)
                            ? PopupMenuButton<String>(
                                tooltip: 'Select from Roles or Approved Plans',
                                icon: const Icon(Icons.arrow_drop_down, size: 22),
                                onSelected: onRoleSelected,
                                itemBuilder: (_) => [
                                  if (plans.isNotEmpty) ...[
                                    const PopupMenuItem(
                                      enabled: false,
                                      child: Text('APPROVED HIRING PLANS', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.grey)),
                                    ),
                                    ...plans.map((p) => PopupMenuItem(
                                          value: p.designation,
                                          child: Text('${p.designation} (${p.department})', style: const TextStyle(fontSize: 13)),
                                        )),
                                  ],
                                  if (roles.isNotEmpty) ...[
                                    const PopupMenuItem(
                                      enabled: false,
                                      child: Text('ORGANIZATIONAL ROLES', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.grey)),
                                    ),
                                    ...roles.map((r) => PopupMenuItem(
                                          value: r.designation,
                                          child: Text('${r.designation} (${r.dept})', style: const TextStyle(fontSize: 13)),
                                        )),
                                  ],
                                ],
                              )
                            : null,
                      ),
                      onChanged: (val) {
                        final autoDept = resolveDepartmentForRole(roleTitle: val, roles: roles, plans: plans);
                        if (autoDept != _selectedDept) {
                          setState(() => _selectedDept = autoDept);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      key: ValueKey('job_post_dept_$_selectedDept'),
                      initialValue: _selectedDept,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Department (Auto-linked from Role) *',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: deptOptions
                          .map((d) => DropdownMenuItem(value: d, child: Text(d, style: const TextStyle(fontSize: 13))))
                          .toList(),
                      onChanged: (v) => setState(() => _selectedDept = v ?? 'Bridal Styling'),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            key: ValueKey('job_post_type_$_type'),
                            initialValue: _type,
                            decoration: const InputDecoration(labelText: 'Type', border: OutlineInputBorder(), isDense: true),
                            items: const ['full-time', 'contract', 'intern', 'part-time']
                                .map((t) => DropdownMenuItem(value: t, child: Text(titleCase(t), style: const TextStyle(fontSize: 13))))
                                .toList(),
                            onChanged: (v) => setState(() => _type = v ?? 'full-time'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _openings,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Openings', hintText: 'e.g. 1', border: OutlineInputBorder(), isDense: true),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      key: ValueKey('job_post_status_$_status'),
                      initialValue: _status,
                      decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder(), isDense: true),
                      items: kJobPostStatuses
                          .map((s) => DropdownMenuItem(value: s, child: Text(titleCase(s), style: const TextStyle(fontSize: 13))))
                          .toList(),
                      onChanged: (v) => setState(() => _status = v ?? 'open'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _desc,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Description / Role Scope',
                        hintText: 'Core responsibilities, requirements, and benefits...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Modal Footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: crm.background,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                border: Border(top: BorderSide(color: crm.border.faded(0.8))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: _busy ? null : () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    onPressed: _busy ? null : _save,
                    icon: _busy
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.check_rounded, size: 16),
                    label: Text(widget.existing == null ? 'Publish Job Post' : 'Save Changes'),
                    style: FilledButton.styleFrom(backgroundColor: crm.primary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CandidateDialog extends ConsumerStatefulWidget {
  const _CandidateDialog({this.existing});
  final Candidate? existing;

  @override
  ConsumerState<_CandidateDialog> createState() => _CandidateDialogState();
}

class _CandidateDialogState extends ConsumerState<_CandidateDialog> {
  late final TextEditingController _name;
  late final TextEditingController _email;
  late final TextEditingController _phone;
  late final TextEditingController _jobTitle;
  late final TextEditingController _referrer;
  late final TextEditingController _resumeUrl;
  late final TextEditingController _notes;
  String? _selectedJobPostId;
  String _source = 'website';
  String _stage = 'applied';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final c = widget.existing;
    _name = TextEditingController(text: c?.name ?? '');
    _email = TextEditingController(text: c?.email ?? '');
    _phone = TextEditingController(text: c?.phone ?? '');
    _jobTitle = TextEditingController(text: c?.jobTitle ?? '');
    _referrer = TextEditingController(text: c?.referrer ?? '');
    _resumeUrl = TextEditingController(text: c?.resumeUrl ?? '');
    _notes = TextEditingController(text: c?.notes ?? '');
    _selectedJobPostId = (c != null && c.jobPostId.isNotEmpty) ? c.jobPostId : null;
    if (c != null) {
      _source = c.source;
      _stage = c.stage;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _jobTitle.dispose();
    _referrer.dispose();
    _resumeUrl.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please provide candidate name')));
      return;
    }
    setState(() => _busy = true);
    try {
      final body = {
        'name': name,
        'email': _email.text.trim(),
        'phone': _phone.text.trim(),
        'jobPostId': _selectedJobPostId,
        'jobTitle': _jobTitle.text.trim(),
        'source': _source,
        'referrer': _referrer.text.trim(),
        'stage': _stage,
        'resumeUrl': _resumeUrl.text.trim(),
        'notes': _notes.text.trim(),
      };
      await ref.read(recruitmentServiceProvider).saveCandidate(
        body,
        id: widget.existing?.id,
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
    final posts = ref.watch(jobPostsProvider).asData?.value ?? [];
    final roles = ref.watch(jobRolesProvider).asData?.value ?? [];

    return Dialog(
      backgroundColor: crm.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Modal Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: crm.primary,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.person_add_alt_1_outlined, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    widget.existing == null ? 'Add candidate · FR-1.13' : 'Edit candidate',
                    style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 20),
                    onPressed: () => Navigator.of(context).pop(false),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),

            // Form Body
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _name,
                      decoration: const InputDecoration(
                        labelText: 'Full name *',
                        hintText: 'Candidate full name',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _email,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              hintText: 'name@email.com',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _phone,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              labelText: 'Phone',
                              hintText: '+91 ...',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Against Job Post selector
                    if (posts.isNotEmpty) ...[
                      DropdownButtonFormField<String?>(
                        key: ValueKey('cand_job_post_$_selectedJobPostId'),
                        initialValue: posts.any((p) => p.id == _selectedJobPostId) ? _selectedJobPostId : null,
                        isExpanded: true,
                        dropdownColor: crm.surface,
                        style: TextStyle(fontSize: 13, color: crm.textPrimary),
                        decoration: const InputDecoration(
                          labelText: 'Against job post · FR-1.13',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: [
                          DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Custom / Direct Application', style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: crm.textPrimary)),
                          ),
                          ...posts.map((p) => DropdownMenuItem<String?>(
                                value: p.id,
                                child: Text(
                                  '${p.title} (${p.department})',
                                  style: TextStyle(fontSize: 13, color: crm.textPrimary),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              )),
                        ],
                        onChanged: (v) {
                          setState(() {
                            _selectedJobPostId = v;
                            if (v != null) {
                              final matched = posts.where((p) => p.id == v).firstOrNull;
                              if (matched != null && matched.title.isNotEmpty) {
                                _jobTitle.text = matched.title;
                              }
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextField(
                      controller: _jobTitle,
                      decoration: InputDecoration(
                        labelText: 'Applied Role / Designation',
                        hintText: 'e.g. Senior Bridal Stylist',
                        border: const OutlineInputBorder(),
                        isDense: true,
                        suffixIcon: (roles.isNotEmpty && _selectedJobPostId == null)
                            ? PopupMenuButton<String>(
                                tooltip: 'Select from Job Roles',
                                icon: const Icon(Icons.arrow_drop_down, size: 22),
                                onSelected: (roleTitle) => setState(() => _jobTitle.text = roleTitle),
                                itemBuilder: (_) => roles
                                    .map((r) => PopupMenuItem(value: r.designation, child: Text(r.designation, style: const TextStyle(fontSize: 13))))
                                    .toList(),
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Builder(
                      builder: (context) {
                        final sourceSet = <String>{...kCandidateSources, if (_source.isNotEmpty) _source};
                        final stageSet = <String>{...kCandidateStages, if (_stage.isNotEmpty) _stage};

                        return Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                key: ValueKey('cand_source_$_source'),
                                initialValue: _source,
                                dropdownColor: crm.surface,
                                style: TextStyle(fontSize: 13, color: crm.textPrimary),
                                decoration: const InputDecoration(labelText: 'Source channel · FR-1.10', border: OutlineInputBorder(), isDense: true),
                                items: sourceSet.map((s) => DropdownMenuItem(value: s, child: Text(titleCase(s), style: TextStyle(fontSize: 13, color: crm.textPrimary)))).toList(),
                                onChanged: (v) => setState(() => _source = v ?? 'website'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                key: ValueKey('cand_stage_$_stage'),
                                initialValue: _stage,
                                dropdownColor: crm.surface,
                                style: TextStyle(fontSize: 13, color: crm.textPrimary),
                                decoration: const InputDecoration(labelText: 'Pipeline Stage', border: OutlineInputBorder(), isDense: true),
                                items: stageSet.map((s) => DropdownMenuItem(value: s, child: Text(titleCase(s), style: TextStyle(fontSize: 13, color: crm.textPrimary)))).toList(),
                                onChanged: (v) => setState(() => _stage = v ?? 'applied'),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    if (_source == 'referral') ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: _referrer,
                        decoration: const InputDecoration(
                          labelText: 'Referring employee · FR-1.11',
                          hintText: 'Name of employee who referred candidate',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextField(
                      controller: _resumeUrl,
                      decoration: const InputDecoration(
                        labelText: 'CV / Resume link or file path',
                        hintText: 'e.g. https://... or /resumes/candidate.pdf',
                        border: OutlineInputBorder(),
                        isDense: true,
                        prefixIcon: Icon(Icons.attach_file_rounded, size: 18),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _notes,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Interview Notes / Remarks',
                        hintText: 'Initial impressions, screening feedback...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Modal Footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: crm.background,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                border: Border(top: BorderSide(color: crm.border.faded(0.8))),
              ),
              child: Row(
                children: [
                  if (widget.existing != null) ...[
                    TextButton.icon(
                      onPressed: _busy
                          ? null
                          : () async {
                              final existing = widget.existing!;
                              Navigator.of(context).pop(false);
                              _confirmDeleteCandidate(context, ref, existing);
                            },
                      icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                      label: const Text('Delete Candidate', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                  const Spacer(),
                  OutlinedButton(
                    onPressed: _busy ? null : () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    onPressed: _busy ? null : _save,
                    icon: _busy
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.check_rounded, size: 16),
                    label: Text(widget.existing == null ? 'Add to pipeline' : 'Save Candidate'),
                    style: FilledButton.styleFrom(backgroundColor: crm.primary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OfferDialog extends ConsumerStatefulWidget {
  const _OfferDialog({required this.candidate});
  final Candidate candidate;

  @override
  ConsumerState<_OfferDialog> createState() => _OfferDialogState();
}

class _OfferDialogState extends ConsumerState<_OfferDialog> {
  late final TextEditingController _designation;
  late final TextEditingController _reportingTo;
  late final TextEditingController _salary;
  late final TextEditingController _basicSalary;
  late final TextEditingController _hra;
  late final TextEditingController _incentive;
  late final TextEditingController _incentiveNote;
  String _selectedDept = 'Bridal Styling';
  bool _deptInitialized = false;
  DateTime? _joining;
  String _status = 'sent';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _designation = TextEditingController(text: widget.candidate.jobTitle);
    _reportingTo = TextEditingController(text: 'HR Manager');
    _salary = TextEditingController();
    _basicSalary = TextEditingController();
    _hra = TextEditingController();
    _incentive = TextEditingController();
    _incentiveNote = TextEditingController();
  }

  @override
  void dispose() {
    _designation.dispose();
    _reportingTo.dispose();
    _salary.dispose();
    _basicSalary.dispose();
    _hra.dispose();
    _incentive.dispose();
    _incentiveNote.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final desig = _designation.text.trim();
    if (desig.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please specify offered designation')));
      return;
    }
    final totalSalary = double.tryParse(_salary.text.trim()) ?? 0;
    final hraVal = double.tryParse(_hra.text.trim()) ?? 0;
    final basicParsed = double.tryParse(_basicSalary.text.trim());
    final basicVal = (basicParsed != null && basicParsed > 0)
        ? basicParsed
        : (hraVal > 0 && totalSalary >= hraVal ? (totalSalary - hraVal) : totalSalary);
    final incVal = double.tryParse(_incentive.text.trim()) ?? 0;
    final reporting = _reportingTo.text.trim().isNotEmpty ? _reportingTo.text.trim() : 'HR Manager';

    setState(() => _busy = true);
    try {
      await ref.read(recruitmentServiceProvider).createOffer({
        'candidateId': widget.candidate.id,
        'designation': desig,
        'department': _selectedDept,
        'salary': totalSalary,
        'basicSalary': basicVal,
        'hra': hraVal,
        'incentive': incVal,
        'incentiveNote': _incentiveNote.text.trim(),
        'reportingTo': reporting,
        if (_joining != null) 'joiningDate': _joining!.toIso8601String(),
        'status': _status,
      });
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
    final posts = ref.watch(jobPostsProvider).asData?.value ?? [];
    final roles = ref.watch(jobRolesProvider).asData?.value ?? [];
    final plans = ref.watch(hiringPlansProvider).asData?.value ?? [];

    if (!_deptInitialized) {
      _selectedDept = resolveDepartmentForRole(
        roleTitle: widget.candidate.jobTitle,
        jobPostId: widget.candidate.jobPostId,
        posts: posts,
        roles: roles,
        plans: plans,
      );
      _deptInitialized = true;
    }

    final deptOptions = <String>[...kRecruitmentDepartments];
    if (_selectedDept.isNotEmpty && !deptOptions.contains(_selectedDept)) {
      deptOptions.insert(0, _selectedDept);
    }

    void onRoleSelected(String roleTitle) {
      _designation.text = roleTitle;
      final matchingRole = roles.cast<JobRole?>().firstWhere(
            (r) => r?.designation.toLowerCase() == roleTitle.toLowerCase(),
            orElse: () => null,
          );
      if (matchingRole != null && matchingRole.reportsTo.isNotEmpty) {
        _reportingTo.text = matchingRole.reportsTo;
      }
      final autoDept = resolveDepartmentForRole(
        roleTitle: roleTitle,
        jobPostId: widget.candidate.jobPostId,
        posts: posts,
        roles: roles,
        plans: plans,
      );
      setState(() => _selectedDept = autoDept);
    }

    return Dialog(
      backgroundColor: crm.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Modal Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: crm.primary,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.description_outlined, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Generate Offer for ${widget.candidate.name}',
                      style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 20),
                    onPressed: () => Navigator.of(context).pop(false),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),

            // Form Body
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _designation,
                      decoration: InputDecoration(
                        labelText: 'Offered Designation *',
                        hintText: 'e.g. Marketing Manager',
                        border: const OutlineInputBorder(),
                        isDense: true,
                        suffixIcon: (roles.isNotEmpty || posts.isNotEmpty)
                            ? PopupMenuButton<String>(
                                tooltip: 'Select from Active Roles',
                                icon: const Icon(Icons.arrow_drop_down, size: 22),
                                onSelected: onRoleSelected,
                                itemBuilder: (_) => [
                                  if (posts.isNotEmpty) ...[
                                    const PopupMenuItem(
                                      enabled: false,
                                      child: Text('JOB POSTS', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.grey)),
                                    ),
                                    ...posts.map((p) => PopupMenuItem(
                                          value: p.title,
                                          child: Text('${p.title} (${p.department})', style: const TextStyle(fontSize: 13)),
                                        )),
                                  ],
                                  if (roles.isNotEmpty) ...[
                                    const PopupMenuItem(
                                      enabled: false,
                                      child: Text('ORGANIZATIONAL ROLES', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.grey)),
                                    ),
                                    ...roles.map((r) => PopupMenuItem(
                                          value: r.designation,
                                          child: Text('${r.designation} (${r.dept})', style: const TextStyle(fontSize: 13)),
                                        )),
                                  ],
                                ],
                              )
                            : null,
                      ),
                      onChanged: (val) {
                        final autoDept = resolveDepartmentForRole(
                          roleTitle: val,
                          posts: posts,
                          roles: roles,
                          plans: plans,
                        );
                        if (autoDept != _selectedDept) {
                          setState(() => _selectedDept = autoDept);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      key: ValueKey('offer_dept_$_selectedDept'),
                      initialValue: _selectedDept,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Department (Auto-linked from Role)',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: deptOptions
                          .map((d) => DropdownMenuItem(value: d, child: Text(d, style: const TextStyle(fontSize: 13))))
                          .toList(),
                      onChanged: (v) => setState(() => _selectedDept = v ?? 'Bridal Styling'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _reportingTo,
                      decoration: const InputDecoration(
                        labelText: 'Reports To (Direct Manager)',
                        hintText: 'e.g. HR Manager',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _salary,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Net Monthly Salary (₹) *',
                              hintText: 'e.g. 75000',
                              prefixText: '₹ ',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _basicSalary,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Basic Salary (₹, Optional)',
                              hintText: 'Defaults to Net',
                              prefixText: '₹ ',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _hra,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'HRA (₹, Optional)',
                              hintText: 'e.g. 15000',
                              prefixText: '₹ ',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _incentive,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Monthly Incentive (₹, Optional)',
                              hintText: 'e.g. 5000',
                              prefixText: '₹ ',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _incentiveNote,
                      decoration: const InputDecoration(
                        labelText: 'Incentive Note / Criteria (Optional)',
                        hintText: 'Leave empty for default performance criteria note',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: const Icon(Icons.calendar_today_rounded, size: 16),
                            onPressed: () async {
                              final now = DateTime.now();
                              final d = await showDatePicker(
                                context: context,
                                initialDate: _joining ?? now,
                                firstDate: now,
                                lastDate: DateTime(now.year + 2),
                              );
                              if (d != null) setState(() => _joining = d);
                            },
                            label: Text(
                              _joining == null ? 'Select Joining Date' : 'Joins: ${_fmt(_joining)}',
                              style: const TextStyle(fontSize: 12.5),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            key: ValueKey('offer_status_$_status'),
                            initialValue: _status,
                            decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder(), isDense: true),
                            items: const ['draft', 'sent']
                                .map((s) => DropdownMenuItem(value: s, child: Text(titleCase(s), style: const TextStyle(fontSize: 13))))
                                .toList(),
                            onChanged: (v) => setState(() => _status = v ?? 'sent'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Modal Footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: crm.background,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                border: Border(top: BorderSide(color: crm.border.faded(0.8))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: _busy ? null : () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    onPressed: _busy ? null : _save,
                    icon: _busy
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.check_rounded, size: 16),
                    label: const Text('Issue Offer Letter'),
                    style: FilledButton.styleFrom(backgroundColor: crm.primary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
