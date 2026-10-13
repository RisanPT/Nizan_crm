import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/hr_shared/hr_ui.dart';
import 'package:nizan_crm/features/hr_shared/hr_person_picker.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/services/employee_service.dart';
import 'package:nizan_crm/features/hr_offboarding/data/offboarding_models.dart';
import 'package:nizan_crm/features/hr_offboarding/service/offboarding_service.dart';

String _fmt(DateTime? d) {
  if (d == null) return '—';
  const m = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${d.day.toString().padLeft(2, '0')} ${m[d.month]} ${d.year}';
}

/// HR Offboarding & Lifecycle Exit Management — SRS §3.8 compliance.
/// Covers notice period tracking, last working day countdown, multi-department
/// clearance checklists, final settlements, and Experience Certificate generation.
class HrOffboardingScreen extends ConsumerStatefulWidget {
  const HrOffboardingScreen({super.key});

  @override
  ConsumerState<HrOffboardingScreen> createState() => _HrOffboardingScreenState();
}

class _HrOffboardingScreenState extends ConsumerState<HrOffboardingScreen> {
  String _selectedFilter = 'all'; // 'all', 'in_progress', 'completed'

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final rowsAsync = ref.watch(offboardingsProvider);

    return Scaffold(
      backgroundColor: crm.background,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF601A29),
        foregroundColor: const Color(0xFFF5F3EF),
        elevation: 4,
        onPressed: () => _startExit(context, ref),
        icon: const Icon(Icons.logout_rounded),
        label: const Text('Initiate Exit', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(offboardingsProvider),
        child: rowsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(children: [
            AppErrorView(error: e, onRetry: () => ref.invalidate(offboardingsProvider))
          ]),
          data: (allOffboardings) {
            final inProgress = allOffboardings.where((o) => o.status == 'in_progress').toList();
            final completed = allOffboardings.where((o) => o.status == 'completed').toList();
            final pendingSettlement = allOffboardings.where((o) => !o.settlementPaid).length;

            var displayed = allOffboardings;
            if (_selectedFilter == 'in_progress') {
              displayed = inProgress;
            } else if (_selectedFilter == 'completed') {
              displayed = completed;
            }

            return ListView(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 90),
              children: [
                // Screen Title
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Offboarding & Exits',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: crm.textPrimary,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Exit clearance checklists, notice period, settlements & certificates',
                          style: TextStyle(fontSize: 12.5, color: crm.textSecondary),
                        ),
                      ],
                    ),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF601A29),
                        foregroundColor: const Color(0xFFF5F3EF),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                      onPressed: () => _startExit(context, ref),
                      icon: const Icon(Icons.person_remove_rounded, size: 18),
                      label: const Text('Initiate Exit', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // KPI Stat Cards
                LayoutBuilder(builder: (ctx, constraints) {
                  final isNarrow = constraints.maxWidth < 640;
                  final cards = [
                    _kpiCard(crm, 'Total Exits', '${allOffboardings.length}', Icons.badge_outlined, const Color(0xFF601A29)),
                    _kpiCard(crm, 'In Notice / Active', '${inProgress.length}', Icons.pending_actions_rounded, const Color(0xFFD97706)),
                    _kpiCard(crm, 'Settlements Due', '$pendingSettlement', Icons.account_balance_wallet_outlined, const Color(0xFFDC2626)),
                    _kpiCard(crm, 'Completed Exits', '${completed.length}', Icons.check_circle_outline_rounded, const Color(0xFF0D9488)),
                  ];
                  if (isNarrow) {
                    return Wrap(spacing: 10, runSpacing: 10, children: cards);
                  }
                  return Row(
                    children: cards.map((c) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 5), child: c))).toList(),
                  );
                }),
                const SizedBox(height: 18),

                // Filter Pill Switcher
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: hrCardDecoration(crm),
                  child: Row(
                    children: [
                      _pill('all', 'All Exits (${allOffboardings.length})', crm),
                      _pill('in_progress', 'In Notice / Active (${inProgress.length})', crm),
                      _pill('completed', 'Completed (${completed.length})', crm),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Exits List
                if (displayed.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(48),
                    decoration: hrCardDecoration(crm),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle_outline, size: 48, color: crm.textSecondary.withValues(alpha: 0.4)),
                          const SizedBox(height: 12),
                          Text(
                            _selectedFilter == 'all'
                                ? 'No employee exits in progress.'
                                : 'No ${_selectedFilter.replaceAll('_', ' ')} exits.',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: crm.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ...displayed.map((o) => _ModernOffboardingCard(off: o, crm: crm)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _pill(String key, String label, CrmTheme crm) {
    final selected = _selectedFilter == key;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedFilter = key),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF601A29) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? Colors.white : crm.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _kpiCard(CrmTheme crm, String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: hrCardDecoration(crm),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: crm.textPrimary)),
                Text(label, style: TextStyle(fontSize: 11, color: crm.textSecondary, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _startExit(BuildContext context, WidgetRef ref) async {
    final employees = await ref.read(employeesProvider.future);
    if (!context.mounted) return;
    final active = employees.where((e) => e.status == 'active').toList();
    String? selected;
    String reason = 'resignation';
    DateTime? lwd = DateTime.now().add(const Duration(days: 30));
    final notesCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDlg) => AlertDialog(
          title: Text(
            'Initiate Employee Exit',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800),
          ),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PersonPickerField(
                  label: 'Select Employee *',
                  icon: Icons.person_outline,
                  selectedId: selected,
                  items: active.map((e) => PickerItem(id: e.id, name: e.name, department: e.department ?? '')).toList(),
                  onChanged: (v) => setStateDlg(() => selected = v),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: reason,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Exit Reason'),
                  items: offboardingReasons.map((r) => DropdownMenuItem(value: r, child: Text(offboardingReasonLabel(r)))).toList(),
                  onChanged: (v) => setStateDlg(() => reason = v ?? 'resignation'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    final now = DateTime.now();
                    final d = await showDatePicker(
                      context: ctx,
                      initialDate: lwd ?? now.add(const Duration(days: 30)),
                      firstDate: DateTime(now.year - 1),
                      lastDate: DateTime(now.year + 2),
                    );
                    if (d != null) setStateDlg(() => lwd = d);
                  },
                  icon: const Icon(Icons.event_outlined, size: 18),
                  label: Text(lwd == null ? 'Set Last Working Day (LWD)' : 'LWD: ${_fmt(lwd)}'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Notes / Handover comments (optional)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
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
              onPressed: selected == null ? null : () => Navigator.of(ctx).pop(true),
              child: const Text('Initiate Exit'),
            ),
          ],
        ),
      ),
    );

    if (ok == true && selected != null) {
      try {
        await ref.read(offboardingServiceProvider).create(
              employeeId: selected!,
              reason: reason,
              lastWorkingDay: lwd,
            );
        ref.invalidate(offboardingsProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Exit process initiated')));
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
        }
      }
    }
  }
}

class _ModernOffboardingCard extends ConsumerWidget {
  const _ModernOffboardingCard({required this.off, required this.crm});
  final Offboarding off;
  final CrmTheme crm;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final completed = off.status == 'completed';
    final cleared = off.clearedCount;
    final total = off.clearanceItems.length;
    final progress = total > 0 ? (cleared / total) : 0.0;
    final allCleared = total > 0 && cleared == total;

    // LWD countdown calculation
    String lwdLabel = 'No LWD';
    Color lwdColor = crm.textSecondary;
    if (off.lastWorkingDay != null) {
      final now = DateTime.now();
      final diff = off.lastWorkingDay!.difference(DateTime(now.year, now.month, now.day)).inDays;
      if (completed) {
        lwdLabel = 'Exited';
        lwdColor = const Color(0xFF0D9488);
      } else if (diff < 0) {
        lwdLabel = 'Overdue by ${-diff}d';
        lwdColor = Colors.red;
      } else if (diff == 0) {
        lwdLabel = 'Today is LWD';
        lwdColor = Colors.orange;
      } else {
        lwdLabel = '$diff days left';
        lwdColor = const Color(0xFFD97706);
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: hrCardDecoration(crm),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: !completed,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: CircleAvatar(
            radius: 20,
            backgroundColor: completed
                ? const Color(0xFF0D9488).withValues(alpha: 0.15)
                : const Color(0xFF601A29).withValues(alpha: 0.15),
            child: Icon(
              completed ? Icons.check_circle_rounded : Icons.person_off_rounded,
              color: completed ? const Color(0xFF0D9488) : const Color(0xFF601A29),
              size: 20,
            ),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  off.employeeName,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: crm.textPrimary,
                  ),
                ),
              ),
              // LWD Countdown Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: lwdColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.schedule_rounded, size: 12, color: lwdColor),
                    const SizedBox(width: 4),
                    Text(
                      lwdLabel,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: lwdColor),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (off.employeeId.isNotEmpty)
                IconButton(
                  tooltip: 'View Profile',
                  icon: const Icon(Icons.open_in_new_rounded, size: 16),
                  onPressed: () => context.push('/staff/${off.employeeId}'),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: crm.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      offboardingReasonLabel(off.reason),
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: crm.primary),
                    ),
                  ),
                  if (off.department.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Text('·  ${off.department}', style: TextStyle(fontSize: 11.5, color: crm.textSecondary)),
                  ],
                  const SizedBox(width: 6),
                  Text('·  LWD: ${_fmt(off.lastWorkingDay)}', style: TextStyle(fontSize: 11.5, color: crm.textSecondary)),
                ],
              ),
              const SizedBox(height: 8),
              // Clearance Progress Bar
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 6,
                        backgroundColor: crm.border,
                        color: allCleared ? const Color(0xFF0D9488) : const Color(0xFF601A29),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '$cleared / $total clearance signed off',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: crm.textSecondary),
                  ),
                ],
              ),
            ],
          ),
          children: [
            const Divider(height: 1),
            // Department Clearance Checklist Section
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'CLEARANCE CHECKLIST BY DEPARTMENT',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: Color(0xFF601A29)),
                  ),
                  const SizedBox(height: 6),
                  ...List.generate(off.clearanceItems.length, (i) {
                    final it = off.clearanceItems[i];
                    return CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      value: it.cleared,
                      title: Text(
                        it.label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: it.cleared ? FontWeight.w500 : FontWeight.w600,
                          color: it.cleared ? crm.textSecondary : crm.textPrimary,
                          decoration: it.cleared ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      controlAffinity: ListTileControlAffinity.leading,
                      onChanged: completed ? null : (v) => _toggleClearance(ref, context, i, v ?? false),
                    );
                  }),
                ],
              ),
            ),
            const Divider(height: 1),

            // Settlement & Certificate Action Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
              child: Column(
                children: [
                  // Final settlement row
                  Row(
                    children: [
                      Icon(Icons.payments_outlined, size: 18, color: crm.textSecondary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Final Settlement Dues', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                            Text(
                              off.finalSettlementAmount > 0
                                  ? 'Amount: ₹${off.finalSettlementAmount.toStringAsFixed(0)}'
                                  : 'Dues calculation pending accounts review',
                              style: TextStyle(fontSize: 11.5, color: crm.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: off.settlementPaid,
                        onChanged: completed ? null : (v) => _flag(ref, context, settlementPaid: v),
                      ),
                      Text(
                        off.settlementPaid ? 'Settled' : 'Unpaid',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: off.settlementPaid ? const Color(0xFF0D9488) : Colors.red,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Bottom Action Buttons: Experience Certificate & Complete Exit
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Experience Certificate Button (SRS FR-8.1, FR-8.2)
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: allCleared ? const Color(0xFFC9A66B) : crm.border,
                          ),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        onPressed: () => _showExperienceCertificate(context, ref),
                        icon: Icon(
                          Icons.workspace_premium_rounded,
                          size: 16,
                          color: allCleared ? const Color(0xFFC9A66B) : crm.textSecondary,
                        ),
                        label: Text(
                          'Experience Certificate',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: allCleared ? const Color(0xFF601A29) : crm.textSecondary,
                          ),
                        ),
                      ),

                      // Exit State Completion
                      if (!completed)
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: allCleared ? const Color(0xFF0D9488) : Colors.grey,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          ),
                          onPressed: allCleared ? () => _completeExit(ref, context) : null,
                          icon: const Icon(Icons.check_rounded, size: 16),
                          label: const Text('Finalize Exit', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0D9488).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF0D9488)),
                              SizedBox(width: 6),
                              Text(
                                'Employee Exited & Archived',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0D9488)),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showExperienceCertificate(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.workspace_premium_rounded, color: Color(0xFFC9A66B)),
            const SizedBox(width: 8),
            Text(
              'Experience Certificate Preview',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 16),
            ),
          ],
        ),
        content: SizedBox(
          width: 520,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFFBF9F5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFC9A66B), width: 1.5),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'NIZAN CRM / VENTURES',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    color: const Color(0xFF601A29),
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'CERTIFICATE OF EXPERIENCE & RELIEVING',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1),
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 14),
                Text(
                  'This is to certify that ${off.employeeName} served in the ${off.department.isNotEmpty ? off.department : "Operations"} department with our organization. Their designated last working day was ${_fmt(off.lastWorkingDay)}.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, height: 1.5),
                ),
                const SizedBox(height: 14),
                const Text(
                  'During their tenure with us, they demonstrated professional conduct and fulfilled all departmental clearance requirements. We wish them all success in their future endeavors.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12.5, height: 1.4, color: Colors.black87),
                ),
                const SizedBox(height: 24),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Authorized Signatory', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        Text('Head of Human Resources', style: TextStyle(fontSize: 10, color: Colors.grey)),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Official Seal', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        Text('Nizan CRM HR Desk', style: TextStyle(fontSize: 10, color: Colors.grey)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Close')),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF601A29),
              foregroundColor: const Color(0xFFF5F3EF),
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Experience certificate generated and sent to employee files')),
              );
            },
            icon: const Icon(Icons.print_rounded, size: 16),
            label: const Text('Issue & Export'),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleClearance(WidgetRef ref, BuildContext context, int index, bool cleared) async {
    final next = [...off.clearanceItems];
    next[index] = next[index].copyWith(cleared: cleared);
    try {
      await ref.read(offboardingServiceProvider).update(off.id, clearanceItems: next);
      ref.invalidate(offboardingsProvider);
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
    }
  }

  Future<void> _flag(WidgetRef ref, BuildContext context, {bool? settlementPaid, bool? experienceLetterIssued}) async {
    try {
      await ref.read(offboardingServiceProvider).update(off.id, settlementPaid: settlementPaid, experienceLetterIssued: experienceLetterIssued);
      ref.invalidate(offboardingsProvider);
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
    }
  }

  Future<void> _completeExit(WidgetRef ref, BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Complete & Finalize Exit'),
        content: Text(
          'All clearance items have been verified. Finalizing this exit will archive ${off.employeeName} and mark their employee profile as inactive. Continue?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0D9488)),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Confirm & Archive'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(offboardingServiceProvider).update(off.id, status: 'completed');
      ref.invalidate(offboardingsProvider);
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Exit successfully completed')));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
    }
  }
}
