import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/core/providers/auth_provider.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/hr/leave/presentation/widgets/leave_calendar_tab.dart';
import 'package:nizan_crm/features/hr/leave/presentation/widgets/leave_common.dart';
import 'package:nizan_crm/features/hr/leave/presentation/widgets/leave_my_tab.dart';
import 'package:nizan_crm/features/hr/leave/presentation/widgets/leave_overview_tab.dart';
import 'package:nizan_crm/features/hr/leave/presentation/widgets/leave_requests_tab.dart';
import 'package:nizan_crm/features/hr/leave/presentation/widgets/leave_settings_tab.dart';
import 'package:nizan_crm/features/hr/leave/service/leave_service.dart';
import 'package:nizan_crm/features/hr/shared/hr_ui.dart';

/// Leave management.
///  • Leave desk (admin + hr role): Overview, Requests, Calendar,
///    My leave and Settings. Only they see other people's leave and decide it.
///  • Everyone else: their own leave (balances, upcoming, history). Leave is applied in Timebox.
/// Data reloads when the screen opens, every 30 seconds while it is open,
/// when the app comes back to the foreground, and right after any action.
class HrLeaveScreen extends ConsumerStatefulWidget {
  const HrLeaveScreen({super.key});
  @override
  ConsumerState<HrLeaveScreen> createState() => _HrLeaveScreenState();
}

class _HrLeaveScreenState extends ConsumerState<HrLeaveScreen> with TickerProviderStateMixin, WidgetsBindingObserver {
  static const _refreshEvery = Duration(seconds: 30);
  Timer? _refreshTimer;
  Timer? _clockTimer;
  TabController? _tabs;
  int _tabCount = 0;

  bool get _desk => ref.read(leaveDeskAccessProvider).value ?? false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Fresh data every time the screen opens (lists are cached app-wide).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) refreshLeaveData(ref, desk: _desk);
    });
    _refreshTimer = Timer.periodic(_refreshEvery, (_) {
      if (mounted) refreshLeaveData(ref, desk: _desk);
    });
    // Re-draws the "Updated … ago" label.
    _clockTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) refreshLeaveData(ref, desk: _desk);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    _clockTimer?.cancel();
    _tabs?.dispose();
    super.dispose();
  }

  TabController _controllerFor(int count) {
    if (_tabs == null || _tabCount != count) {
      final keep = _tabs?.index ?? 0;
      _tabs?.dispose();
      _tabs = TabController(length: count, vsync: this, initialIndex: keep < count ? keep : 0);
      _tabCount = count;
    }
    return _tabs!;
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final session = ref.watch(authSessionProvider);
    final ownEmployeeId = session?.employeeId ?? '';
    final hasEmployee = ownEmployeeId.isNotEmpty;
    final isAdmin = (session?.role ?? '') == 'admin';
    final deskAsync = ref.watch(leaveDeskAccessProvider);
    final isDesk = deskAsync.value ?? false;
    final canEditTypes = isDesk && (ref.watch(leaveMasterAccessProvider).value ?? false);

    final header = _Header(
      title: isDesk ? 'Leave management' : 'My leave',
      onRefresh: () => refreshLeaveData(ref, desk: isDesk),
    );

    // Still finding out who this is — avoid flashing the employee view to HR.
    if (deskAsync.isLoading && !deskAsync.hasValue) {
      return Scaffold(
        backgroundColor: crm.background,
        body: Column(children: [header, const Expanded(child: Center(child: CircularProgressIndicator()))]),
      );
    }

    if (!isDesk) {
      return Scaffold(
        backgroundColor: crm.background,
        body: Column(children: [
          header,
          Expanded(
            child: hasEmployee
                ? const LeaveMyTab()
                : const Center(
                    child: LeaveEmpty(
                      icon: Icons.badge_outlined,
                      title: 'No employee record linked',
                      body: 'Ask HR to link your login to your staff record to see your leave here.',
                    ),
                  ),
          ),
        ]),
      );
    }

    final tabs = <(String, IconData, Widget)>[
      (
        'Overview',
        Icons.dashboard_outlined,
        LeaveOverviewTab(
          ownEmployeeId: ownEmployeeId,
          isAdmin: isAdmin,
          onOpenRequests: () => _tabs?.animateTo(1),
        ),
      ),
      ('Requests', Icons.list_alt_rounded, LeaveRequestsTab(ownEmployeeId: ownEmployeeId, isAdmin: isAdmin)),
      ('Calendar', Icons.calendar_month_outlined, const LeaveCalendarTab()),
      if (hasEmployee) ('My leave', Icons.person_outline, const LeaveMyTab()),
      ('Settings', Icons.tune_rounded, LeaveSettingsTab(canEditTypes: canEditTypes)),
    ];
    final controller = _controllerFor(tabs.length);
    final pending = (ref.watch(leaveRequestsProvider).value ?? const []).where((r) => r.status == 'pending').length;

    return Scaffold(
      backgroundColor: crm.background,
      body: Column(children: [
        header,
        Material(
          color: crm.surface,
          child: TabBar(
            controller: controller,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: crm.primary,
            unselectedLabelColor: crm.textSecondary,
            indicatorColor: crm.primary,
            tabs: [
              for (final t in tabs)
                Tab(
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(t.$2, size: 17),
                    const SizedBox(width: 6),
                    Text(t.$1),
                    if (t.$1 == 'Requests' && pending > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(color: crm.warning, borderRadius: BorderRadius.circular(10)),
                        child: Text('$pending',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white)),
                      ),
                    ],
                  ]),
                ),
            ],
          ),
        ),
        Expanded(child: TabBarView(controller: controller, children: [for (final t in tabs) t.$3])),
      ]),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({required this.title, required this.onRefresh});
  final String title;
  final VoidCallback onRefresh;

  String _ago(DateTime? t) {
    if (t == null) return 'Loading…';
    final s = DateTime.now().difference(t).inSeconds;
    if (s < 10) return 'Updated just now';
    if (s < 60) return 'Updated ${s - s % 10} s ago';
    return 'Updated ${s ~/ 60} min ago';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crm = context.crmColors;
    final year = ref.watch(leaveYearProvider);
    final last = ref.watch(leaveLastSyncProvider);
    final now = DateTime.now().year;
    final years = {now - 1, now, now + 1, year}.toList()..sort();

    return Container(
      width: double.infinity,
      color: crm.surface,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: 10,
        spacing: 12,
        children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            HrTitle(title, size: 22),
            const SizedBox(height: 4),
            Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 7, height: 7, decoration: BoxDecoration(color: crm.success, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text('Live · ${_ago(last)}', style: TextStyle(fontSize: 11.5, color: crm.textSecondary)),
            ]),
          ]),
          Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                border: Border.all(color: crm.border),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: year,
                  isDense: true,
                  icon: const Icon(Icons.expand_more, size: 18),
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: crm.textPrimary),
                  items: years.map((y) => DropdownMenuItem(value: y, child: Text('$y'))).toList(),
                  onChanged: (v) {
                    if (v != null) ref.read(leaveYearProvider.notifier).state = v;
                  },
                ),
              ),
            ),
            IconButton(tooltip: 'Refresh now', onPressed: onRefresh, icon: Icon(Icons.refresh_rounded, color: crm.textSecondary)),
          ]),
        ],
      ),
    );
  }
}
