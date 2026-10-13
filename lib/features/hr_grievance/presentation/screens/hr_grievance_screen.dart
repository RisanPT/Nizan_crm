import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/hr_shared/hr_ui.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/auth/access_control.dart';
import 'package:nizan_crm/core/providers/auth_provider.dart';
import 'package:nizan_crm/features/hr_grievance/data/grievance_models.dart';
import 'package:nizan_crm/features/hr_grievance/service/grievance_service.dart';

String _fmt(DateTime? d) {
  if (d == null) return '';
  const m = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${d.day.toString().padLeft(2, '0')} ${m[d.month]} ${d.year}';
}

Color _statusColor(String s, CrmTheme crm) {
  switch (s) {
    case 'resolved':
    case 'closed':
      return const Color(0xFF0D9488); // Teal
    case 'in_review':
      return const Color(0xFFD97706); // Amber
    default:
      return const Color(0xFF601A29); // Open - Maroon
  }
}

IconData _categoryIcon(String c) {
  switch (c) {
    case 'harassment':
      return Icons.shield_outlined;
    case 'payroll':
      return Icons.payments_outlined;
    case 'facilities':
      return Icons.business_outlined;
    case 'management':
      return Icons.groups_outlined;
    default:
      return Icons.workspaces_outlined;
  }
}

/// HR Grievance & Conflict Resolution — SRS §3.7 compliance.
/// Supports employee case raising, confidential routing, HR queue management,
/// resolution logging, and category analytics.
class HrGrievanceScreen extends ConsumerStatefulWidget {
  const HrGrievanceScreen({super.key});

  @override
  ConsumerState<HrGrievanceScreen> createState() => _HrGrievanceScreenState();
}

class _HrGrievanceScreenState extends ConsumerState<HrGrievanceScreen> {
  String _queueFilter = 'all'; // 'all', 'open', 'confidential', 'resolved'

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final access = Access.of(ref.watch(authSessionProvider));
    final session = ref.watch(authSessionProvider);
    final hasEmployee = (session?.employeeId ?? '').isNotEmpty;
    final isManager = access.isFullAccess ||
        access.isDepartmentHead ||
        access.has('grievance', false) ||
        access.has('staff', false);

    final tabs = <Tab>[
      if (hasEmployee) const Tab(text: 'My Raised Cases'),
      if (isManager) const Tab(text: 'HR Resolution Queue'),
    ];

    if (tabs.isEmpty) {
      return Scaffold(
        backgroundColor: crm.background,
        body: Center(
          child: Text(
            'No employee record is linked to your account.',
            style: TextStyle(color: crm.textSecondary),
          ),
        ),
      );
    }

    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        backgroundColor: crm.background,
        body: Column(
          children: [
            // Top Tab Navigation Bar
            Container(
              color: crm.surface,
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  decoration: BoxDecoration(
                    color: crm.background,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: crm.border),
                  ),
                  padding: const EdgeInsets.all(3),
                  child: TabBar(
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
                      color: const Color(0xFF601A29),
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: hrCardShadow(),
                    ),
                    labelPadding: const EdgeInsets.symmetric(horizontal: 18),
                    tabs: tabs,
                  ),
                ),
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  if (hasEmployee) _buildMyCasesTab(crm),
                  if (isManager) _buildQueueTab(crm),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── My Raised Cases (ESS) ────────────────────────────────────────────────
  Widget _buildMyCasesTab(CrmTheme crm) {
    final mineAsync = ref.watch(myGrievancesProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF601A29),
        foregroundColor: const Color(0xFFF5F3EF),
        elevation: 4,
        onPressed: () => _raiseCase(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Raise a Case', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(myGrievancesProvider),
        child: mineAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(children: [
            AppErrorView(error: e, onRetry: () => ref.invalidate(myGrievancesProvider))
          ]),
          data: (cases) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 90),
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'My Grievances & Concerns',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: crm.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Privately raised workplace, payroll or facility concerns',
                          style: TextStyle(fontSize: 12, color: crm.textSecondary),
                        ),
                      ],
                    ),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF601A29),
                        foregroundColor: const Color(0xFFF5F3EF),
                      ),
                      onPressed: () => _raiseCase(context),
                      icon: const Icon(Icons.add_rounded, size: 16),
                      label: const Text('Raise Case', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (cases.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(48),
                    decoration: hrCardDecoration(crm),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.verified_user_outlined, size: 48, color: crm.textSecondary.withValues(alpha: 0.4)),
                          const SizedBox(height: 12),
                          Text('No active grievances filed.', style: TextStyle(fontWeight: FontWeight.w600, color: crm.textSecondary)),
                        ],
                      ),
                    ),
                  )
                else
                  ...cases.map((g) => _caseCard(g, crm, isMine: true)),
              ],
            );
          },
        ),
      ),
    );
  }

  // ─── HR Resolution Queue Tab ──────────────────────────────────────────────
  Widget _buildQueueTab(CrmTheme crm) {
    final queueAsync = ref.watch(grievanceQueueProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(grievanceQueueProvider),
      child: queueAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ListView(children: [
          AppErrorView(error: e, onRetry: () => ref.invalidate(grievanceQueueProvider))
        ]),
        data: (allCases) {
          final openCount = allCases.where((c) => c.status == 'open' || c.status == 'in_review').length;
          final confidentialCount = allCases.where((c) => c.confidential).length;
          final resolvedCount = allCases.where((c) => c.status == 'resolved' || c.status == 'closed').length;

          var displayed = allCases;
          if (_queueFilter == 'open') {
            displayed = allCases.where((c) => c.status == 'open' || c.status == 'in_review').toList();
          } else if (_queueFilter == 'confidential') {
            displayed = allCases.where((c) => c.confidential).toList();
          } else if (_queueFilter == 'resolved') {
            displayed = allCases.where((c) => c.status == 'resolved' || c.status == 'closed').toList();
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 32),
            children: [
              // Screen Header
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Conflict & Grievance Desk',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: crm.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Review, investigate, assign and resolve confidential employee concerns',
                    style: TextStyle(fontSize: 12, color: crm.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // KPI Cards
              Row(
                children: [
                  Expanded(child: _kpi(crm, 'Total In Queue', '${allCases.length}', Icons.inbox_rounded, const Color(0xFF601A29))),
                  const SizedBox(width: 10),
                  Expanded(child: _kpi(crm, 'Needs Action', '$openCount', Icons.pending_actions_rounded, const Color(0xFFD97706))),
                  const SizedBox(width: 10),
                  Expanded(child: _kpi(crm, 'Confidential', '$confidentialCount', Icons.lock_rounded, const Color(0xFF4F46E5))),
                  const SizedBox(width: 10),
                  Expanded(child: _kpi(crm, 'Resolved Cases', '$resolvedCount', Icons.check_circle_rounded, const Color(0xFF0D9488))),
                ],
              ),
              const SizedBox(height: 16),

              // Queue Filter Bar
              Container(
                padding: const EdgeInsets.all(4),
                decoration: hrCardDecoration(crm),
                child: Row(
                  children: [
                    _filterBtn('all', 'All Cases (${allCases.length})', crm),
                    _filterBtn('open', 'Open & In Review ($openCount)', crm),
                    _filterBtn('confidential', 'Confidential ($confidentialCount)', crm),
                    _filterBtn('resolved', 'Resolved ($resolvedCount)', crm),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Queue List
              if (displayed.isEmpty)
                Container(
                  padding: const EdgeInsets.all(48),
                  decoration: hrCardDecoration(crm),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.done_all_rounded, size: 48, color: crm.textSecondary.withValues(alpha: 0.4)),
                        const SizedBox(height: 12),
                        Text(
                          'No cases in this queue view.',
                          style: TextStyle(fontWeight: FontWeight.w600, color: crm.textSecondary),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...displayed.map((g) => _caseCard(g, crm, isMine: false)),
            ],
          );
        },
      ),
    );
  }

  Widget _filterBtn(String key, String label, CrmTheme crm) {
    final sel = _queueFilter == key;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _queueFilter = key),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: sel ? const Color(0xFF601A29) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                color: sel ? Colors.white : crm.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _kpi(CrmTheme crm, String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: hrCardDecoration(crm),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: crm.textPrimary)),
                Text(label, style: TextStyle(fontSize: 10.5, color: crm.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _caseCard(Grievance g, CrmTheme crm, {required bool isMine}) {
    final statusCol = _statusColor(g.status, crm);
    final refCode = g.id.length >= 4 ? '#GRV-${g.id.substring(g.id.length - 4).toUpperCase()}' : '#GRV-CASE';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: hrCardDecoration(crm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: Ref Code, Category, Confidential pill, Status Pill
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF601A29).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  refCode,
                  style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF601A29)),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: crm.surface,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: crm.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_categoryIcon(g.category), size: 12, color: crm.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      grievanceLabel(g.category),
                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: crm.textSecondary),
                    ),
                  ],
                ),
              ),
              if (g.confidential) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF601A29),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lock_rounded, size: 11, color: Color(0xFFC9A66B)),
                      SizedBox(width: 4),
                      Text(
                        'CONFIDENTIAL',
                        style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: Color(0xFFF5F3EF)),
                      ),
                    ],
                  ),
                ),
              ],
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusCol.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  grievanceLabel(g.status).toUpperCase(),
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: statusCol),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Subject & Raised By
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      g.subject,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: crm.textPrimary,
                      ),
                    ),
                    if (!isMine && g.employeeName.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.person_outline_rounded, size: 13, color: crm.textSecondary),
                          const SizedBox(width: 4),
                          Text(
                            'Filed by: ${g.employeeName} ${g.department.isNotEmpty ? '(${g.department})' : ''}',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: crm.textSecondary),
                          ),
                          if (g.employeeId.isNotEmpty)
                            IconButton(
                              tooltip: 'View Profile',
                              icon: const Icon(Icons.open_in_new_rounded, size: 14),
                              onPressed: () => context.push('/staff/${g.employeeId}'),
                              visualDensity: VisualDensity.compact,
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),

          if (g.description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: crm.background,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: crm.border.withValues(alpha: 0.6)),
              ),
              child: Text(
                g.description,
                style: TextStyle(fontSize: 12.5, height: 1.4, color: crm.textPrimary),
              ),
            ),
          ],

          // Resolution Box (if resolved/closed)
          if (g.resolutionNote.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF0D9488).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF0D9488).withValues(alpha: 0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF0D9488)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Decision & Resolution',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0D9488)),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          g.resolutionNote,
                          style: TextStyle(fontSize: 12, color: crm.textPrimary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Footer action bar
          const SizedBox(height: 12),
          Row(
            children: [
              if (g.createdAt != null) ...[
                Icon(Icons.calendar_today_outlined, size: 12, color: crm.textSecondary),
                const SizedBox(width: 4),
                Text('Raised: ${_fmt(g.createdAt)}', style: TextStyle(fontSize: 11, color: crm.textSecondary)),
              ],
              const Spacer(),
              if (isMine && g.status == 'open')
                TextButton.icon(
                  onPressed: () => _withdrawCase(g),
                  icon: const Icon(Icons.cancel_outlined, size: 14),
                  label: const Text('Withdraw Case'),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                ),
              if (!isMine && g.status != 'resolved' && g.status != 'closed')
                FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF601A29).withValues(alpha: 0.1),
                    foregroundColor: const Color(0xFF601A29),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  onPressed: () => _updateCase(g),
                  icon: const Icon(Icons.rate_review_outlined, size: 15),
                  label: const Text('Investigate / Resolve', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _withdrawCase(Grievance g) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Withdraw case?'),
        content: const Text('Are you sure you want to withdraw this grievance?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('No')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Withdraw')),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await ref.read(grievanceServiceProvider).withdraw(g.id);
      ref.invalidate(myGrievancesProvider);
      ref.invalidate(grievanceQueueProvider);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
    }
  }

  Future<void> _updateCase(Grievance g) async {
    var status = g.status == 'open' ? 'in_review' : g.status;
    final noteCtrl = TextEditingController(text: g.resolutionNote);

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDlg) => AlertDialog(
          title: Text(
            'Update Case Resolution',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800),
          ),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: status,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Case Status'),
                  items: grievanceStatuses.map((s) => DropdownMenuItem(value: s, child: Text(grievanceLabel(s)))).toList(),
                  onChanged: (v) => setStateDlg(() => status = v ?? status),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: noteCtrl,
                  minLines: 3,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Investigation / Resolution Notes',
                    hintText: 'Record outcome, actions taken, or meeting decisions...',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF601A29),
                foregroundColor: const Color(0xFFF5F3EF),
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Save Decision'),
            ),
          ],
        ),
      ),
    );

    if (ok == true) {
      try {
        await ref.read(grievanceServiceProvider).update(
              g.id,
              status: status,
              resolutionNote: noteCtrl.text.trim(),
            );
        ref.invalidate(grievanceQueueProvider);
        ref.invalidate(myGrievancesProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Case updated')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
        }
      }
    }
  }

  Future<void> _raiseCase(BuildContext context) async {
    final subCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String category = 'workplace';
    bool confidential = false;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDlg) => AlertDialog(
          title: Text(
            'Raise a Workplace Grievance',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800),
          ),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: subCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Subject *',
                      hintText: 'Brief summary of the issue',
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: category,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: grievanceCategories.map((c) => DropdownMenuItem(value: c, child: Text(grievanceLabel(c)))).toList(),
                    onChanged: (v) => setStateDlg(() => category = v ?? 'workplace'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descCtrl,
                    minLines: 3,
                    maxLines: 6,
                    decoration: const InputDecoration(
                      labelText: 'Detailed Explanation',
                      hintText: 'Describe what happened, dates, and people involved...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: confidential,
                    title: const Text('Confidential Report', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                    subtitle: const Text('Restricts visibility strictly to Senior HR & Management', style: TextStyle(fontSize: 11)),
                    onChanged: (v) => setStateDlg(() => confidential = v),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF601A29),
                foregroundColor: const Color(0xFFF5F3EF),
              ),
              onPressed: () {
                if (subCtrl.text.trim().isEmpty) return;
                Navigator.of(ctx).pop(true);
              },
              child: const Text('Submit Case'),
            ),
          ],
        ),
      ),
    );

    if (ok == true && subCtrl.text.trim().isNotEmpty) {
      try {
        await ref.read(grievanceServiceProvider).raise(
              subject: subCtrl.text.trim(),
              category: category,
              description: descCtrl.text.trim(),
              confidential: confidential,
            );
        ref.invalidate(myGrievancesProvider);
        ref.invalidate(grievanceQueueProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Case submitted successfully')));
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
        }
      }
    }
  }
}
