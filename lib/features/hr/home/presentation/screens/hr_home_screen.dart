import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/core/auth/access_control.dart';
import 'package:nizan_crm/core/providers/auth_provider.dart';
import 'package:nizan_crm/features/hr/shared/hr_ui.dart';
import 'package:nizan_crm/features/hr/shared/hr_services_launcher.dart';
import 'package:nizan_crm/features/hr/leave/service/leave_service.dart';
import 'package:nizan_crm/features/hr/approvals/service/approval_service.dart';

/// HR Home — the self-service hub with a Me / My Team / Organization lens.
/// Styled to the approved HRMS design: warm ground, soft-shadow cards, a pill
/// lens switcher and the display face for titles.
class HrHomeScreen extends ConsumerWidget {
  const HrHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crm = context.crmColors;
    final session = ref.watch(authSessionProvider);
    final access = Access.of(session);
    final hasEmployee = (session?.employeeId ?? '').isNotEmpty;
    final isManager = access.isFullAccess || access.isDepartmentHead;
    final isOrg = access.isFullAccess || access.has('staff', false);

    final tabs = <Tab>[
      if (hasEmployee) const Tab(text: 'Me'),
      if (isManager) const Tab(text: 'My Team'),
      if (isOrg) const Tab(text: 'Organization'),
    ];
    final views = <Widget>[
      if (hasEmployee) const _MeScope(),
      if (isManager) const _TeamScope(),
      if (isOrg) const _OrgScope(),
    ];

    if (tabs.isEmpty) {
      return Scaffold(backgroundColor: crm.background, body: const _OrgScope());
    }

    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        backgroundColor: crm.background,
        body: Column(
          children: [
            _LensBar(tabs: tabs, crm: crm),
            Expanded(child: TabBarView(children: views)),
          ],
        ),
      ),
    );
  }
}

/// The Me / My Team / Organization pill switcher (design "lens switch").
class _LensBar extends StatelessWidget {
  const _LensBar({required this.tabs, required this.crm});
  final List<Tab> tabs;
  final CrmTheme crm;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: crm.surface,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 600;
          final tabSwitcher = Container(
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
                color: crm.primary,
                borderRadius: BorderRadius.circular(999),
                boxShadow: hrCardShadow(),
              ),
              labelPadding: const EdgeInsets.symmetric(horizontal: 18),
              tabs: tabs,
            ),
          );

          final launcherBtn = OutlinedButton.icon(
            onPressed: () => showHrServicesLauncher(context),
            icon: Icon(Icons.grid_view_rounded, size: 16, color: crm.primary),
            label: const Text('All HR Services'),
            style: OutlinedButton.styleFrom(
              foregroundColor: crm.primary,
              side: BorderSide(color: crm.primary.withValues(alpha: 0.35)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
            ),
          );

          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(alignment: Alignment.centerLeft, child: tabSwitcher),
                const SizedBox(height: 10),
                Align(alignment: Alignment.centerLeft, child: launcherBtn),
              ],
            );
          }

          return Row(
            children: [
              tabSwitcher,
              const Spacer(),
              launcherBtn,
            ],
          );
        },
      ),
    );
  }
}

class _Tile {
  final IconData icon;
  final String title;
  final String subtitle;
  final String route;
  const _Tile(this.icon, this.title, this.subtitle, this.route);
}

Widget _tileCard(BuildContext context, CrmTheme crm, _Tile t) {
  return HrCard(
    padding: const EdgeInsets.all(14),
    onTap: () => context.go(t.route),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(color: crm.primary.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(11)),
              child: Icon(t.icon, color: crm.primary, size: 21),
            ),
            const Spacer(),
            Icon(Icons.arrow_outward, size: 15, color: crm.textSecondary.withValues(alpha: 0.6)),
          ],
        ),
        const Spacer(),
        Text(t.title, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: crm.textPrimary)),
        const SizedBox(height: 2),
        Text(t.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, color: crm.textSecondary)),
      ],
    ),
  );
}

Widget _tileGridView(BuildContext context, CrmTheme crm, List<_Tile> tiles) {
  return LayoutBuilder(builder: (context, c) {
    final cols = c.maxWidth > 680 ? 4 : (c.maxWidth > 460 ? 3 : 2);
    return GridView.count(
      crossAxisCount: cols,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.25,
      children: tiles.map((t) => _tileCard(context, crm, t)).toList(),
    );
  });
}

// ─── Me ───────────────────────────────────────────────────────────────────
class _MeScope extends ConsumerWidget {
  const _MeScope();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crm = context.crmColors;
    final balances = ref.watch(myBalancesProvider);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
      children: [
        const HrTitle('My workspace'),
        const SizedBox(height: 2),
        Text('Self-service — your leave, time, pay and requests',
            style: TextStyle(fontSize: 12.5, color: crm.textSecondary)),
        const SizedBox(height: 18),
        balances.when(
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
          data: (list) {
            final paid = list.where((b) => b.paid).toList();
            if (paid.isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const HrSectionLabel('Leave balance'),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: paid
                        .map((b) => HrStatCard(
                              width: 138,
                              icon: Icons.event_available_outlined,
                              value: b.available.toStringAsFixed(b.available % 1 == 0 ? 0 : 1),
                              label: '${b.name} left',
                            ))
                        .toList(),
                  ),
                ],
              ),
            );
          },
        ),
        const HrSectionLabel('Quick actions'),
        _tileGridView(context, crm, const [
          _Tile(Icons.event_busy_outlined, 'Apply for leave', 'Request time off', '/hr/leave'),
          _Tile(Icons.receipt_long, 'My payslips', 'Download salary slips', '/hr/my-payslips'),
          _Tile(Icons.timer_outlined, 'My timesheet', 'Log & submit hours', '/hr/timesheet'),
          _Tile(Icons.event_available_outlined, 'Regularize', 'Fix an attendance day', '/hr/regularization'),
          _Tile(Icons.receipt_long_outlined, 'Claim expense', 'Reimbursements', '/hr/reimbursements'),
          _Tile(Icons.flight_takeoff_outlined, 'Travel request', 'Trips & advances', '/hr/travel'),
          _Tile(Icons.campaign_outlined, 'Company feed', 'News & events', '/hr/engagement'),
          _Tile(Icons.school_outlined, 'My learning', 'Courses & training', '/hr/lms'),
          _Tile(Icons.report_gmailerrorred_outlined, 'Raise a concern', 'Grievance', '/hr/grievance'),
          _Tile(Icons.folder_shared_outlined, 'My documents', 'Files & letters', '/hr/files'),
          _Tile(Icons.fact_check_outlined, 'My requests', 'Track approvals', '/hr/approvals'),
        ]),
      ],
    );
  }
}

// ─── My Team ────────────────────────────────────────────────────────────────
class _TeamScope extends ConsumerWidget {
  const _TeamScope();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crm = context.crmColors;
    final inbox = ref.watch(approvalInboxProvider);
    final pending = inbox.maybeWhen(data: (l) => l.length, orElse: () => 0);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
      children: [
        const HrTitle('My team'),
        const SizedBox(height: 2),
        Text('Approve requests and keep an eye on your team',
            style: TextStyle(fontSize: 12.5, color: crm.textSecondary)),
        const SizedBox(height: 18),
        _tileGridView(context, crm, [
          _Tile(Icons.fact_check_outlined, 'Approvals inbox', pending > 0 ? '$pending awaiting you' : 'Up to date', '/hr/approvals'),
          const _Tile(Icons.event_note_outlined, 'Team leave', 'Requests & calendar', '/hr/leave'),
          const _Tile(Icons.account_tree_outlined, 'Organization', 'Reporting structure', '/hr/org'),
          const _Tile(Icons.timer_outlined, 'Timesheets', 'Review submissions', '/hr/timesheet'),
        ]),
      ],
    );
  }
}

// ─── Organization (HR / admin) ──────────────────────────────────────────────
class _OrgScope extends StatelessWidget {
  const _OrgScope();

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    Widget section(String label, List<_Tile> tiles) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [HrSectionLabel(label), _tileGridView(context, crm, tiles)],
          ),
        );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
      children: [
        const HrTitle('Organization'),
        const SizedBox(height: 2),
        Text('The full HR toolkit for your people and processes',
            style: TextStyle(fontSize: 12.5, color: crm.textSecondary)),
        const SizedBox(height: 18),
        section('People', const [
          _Tile(Icons.badge_outlined, 'Staff', 'Employee directory', '/staff'),
          _Tile(Icons.account_tree_outlined, 'Organization', 'Reporting chart', '/hr/org'),
          _Tile(Icons.workspace_premium_outlined, 'Designations', 'Titles & grades', '/hr/designations'),
          _Tile(Icons.folder_shared_outlined, 'Files', 'Document vault', '/hr/files'),
          _Tile(Icons.badge_outlined, 'Employee logins', 'Invite to ESS', '/hr/logins'),
        ]),
        section('Time & attendance', const [
          _Tile(Icons.fingerprint_outlined, 'Attendance', 'Timebox attendance', '/hr/attendance'),
          _Tile(Icons.event_seat_outlined, 'Slot management', 'Capacity & slots', '/hr/slots'),
          _Tile(Icons.schedule_outlined, 'Shifts & roster', 'Shifts & assignments', '/hr/shift'),
          _Tile(Icons.timer_outlined, 'Time tracker', 'Submitted timesheets', '/hr/timesheet'),
        ]),
        section('Payroll & pay', const [
          _Tile(Icons.account_balance_wallet_outlined, 'Salaries & payroll', 'Run & review', '/hr/salaries'),
          _Tile(Icons.payments_outlined, 'Compensation', 'Bands & revisions', '/hr/compensation'),
          _Tile(Icons.receipt_long_outlined, 'Reimbursements', 'Expense claims', '/hr/reimbursements'),
          _Tile(Icons.flight_takeoff_outlined, 'Travel desk', 'Trip requests', '/hr/travel'),
        ]),
        section('Hiring & lifecycle', const [
          _Tile(Icons.work_outline, 'Recruitment', 'Jobs & offers', '/hr/recruitment'),
          _Tile(Icons.assignment_turned_in_outlined, 'Onboarding', 'New-hire checklists', '/hr/onboarding'),
          _Tile(Icons.logout_outlined, 'Offboarding', 'Exits & clearance', '/hr/offboarding'),
        ]),
        section('Growth', const [
          _Tile(Icons.star_outline, '5-Pillar evaluation', 'Scorecards', '/hr/evaluation'),
          _Tile(Icons.school_outlined, 'Learning', 'Course catalogue', '/hr/lms'),
        ]),
        section('Workplace', const [
          _Tile(Icons.campaign_outlined, 'Engagement', 'Post to the feed', '/hr/engagement'),
          _Tile(Icons.report_gmailerrorred_outlined, 'Grievances', 'Case queue', '/hr/grievance'),
          _Tile(Icons.description_outlined, 'HR letters', 'Templates & generation', '/hr/letters'),
        ]),
        section('Insights & workflow', const [
          _Tile(Icons.insights_outlined, 'Analytics', 'Headcount & workload', '/hr/analytics'),
          _Tile(Icons.fact_check_outlined, 'Approvals', 'Decide requests', '/hr/approvals'),
        ]),
      ],
    );
  }
}
