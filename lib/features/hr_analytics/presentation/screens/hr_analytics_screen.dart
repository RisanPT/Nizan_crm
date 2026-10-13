import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/hr_shared/hr_ui.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/hr_analytics/service/hr_analytics_service.dart';

/// HR Analytics — a headcount / workload dashboard: active vs inactive, new
/// hires, department breakdown, and the in-flight workload (onboarding, exits,
/// pending approvals/leave, open grievances).
class HrAnalyticsScreen extends ConsumerWidget {
  const HrAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crm = context.crmColors;
    final summary = ref.watch(hrAnalyticsSummaryProvider);
    return Scaffold(
      backgroundColor: crm.background,
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(hrAnalyticsSummaryProvider),
        child: summary.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(children: [AppErrorView(error: e, onRetry: () => ref.invalidate(hrAnalyticsSummaryProvider))]),
          data: (s) => ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              Text('People', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: crm.textPrimary)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _stat(crm, 'Active', s.active, Icons.groups_outlined, crm.success),
                  _stat(crm, 'Inactive', s.inactive, Icons.group_off_outlined, crm.textSecondary),
                  _stat(crm, 'New this month', s.newHiresThisMonth, Icons.person_add_alt, crm.primary),
                ],
              ),
              const SizedBox(height: 22),
              Text('Workload', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: crm.textPrimary)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _stat(crm, 'Onboarding', s.onboardingInProgress, Icons.assignment_turned_in_outlined, crm.primary),
                  _stat(crm, 'Exits', s.exitsInProgress, Icons.logout_outlined, crm.warning),
                  _stat(crm, 'Approvals', s.pendingApprovals, Icons.fact_check_outlined, crm.warning),
                  _stat(crm, 'Leave pending', s.pendingLeave, Icons.event_busy_outlined, crm.warning),
                  _stat(crm, 'Grievances', s.openGrievances, Icons.report_gmailerrorred_outlined, crm.destructive),
                ],
              ),
              const SizedBox(height: 22),
              Text('Headcount by department', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: crm.textPrimary)),
              const SizedBox(height: 10),
              _deptBreakdown(crm, s),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stat(CrmTheme crm, String label, int value, IconData icon, Color color) =>
      HrStatCard(icon: icon, value: '$value', label: label, color: color);

  Widget _deptBreakdown(CrmTheme crm, HrAnalyticsSummary s) {
    if (s.byDepartment.isEmpty) {
      return Padding(padding: const EdgeInsets.all(20), child: Center(child: Text('No department data.', style: TextStyle(color: crm.textSecondary))));
    }
    final maxCount = s.byDepartment.map((d) => d.count).fold<int>(1, (a, b) => a > b ? a : b);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: hrCardDecoration(crm),
      child: Column(
        children: s.byDepartment.map((d) {
          final frac = (d.count / maxCount).clamp(0.05, 1.0);
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(d.department, style: TextStyle(fontSize: 12.5, color: crm.textPrimary))),
                    Text('${d.count}', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: crm.textPrimary)),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: frac,
                    minHeight: 8,
                    backgroundColor: crm.border,
                    color: crm.primary,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
