import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:nizan_crm/features/marketing/presentation/kit/mkt_kit.dart';
import 'package:nizan_crm/features/marketing/presentation/leadreport/lead_conversion_tab.dart';
import 'package:nizan_crm/features/marketing/presentation/leadreport/lead_followups_tab.dart';
import 'package:nizan_crm/features/marketing/presentation/leadreport/lead_list_tab.dart';
import 'package:nizan_crm/features/marketing/presentation/leadreport/lead_overview_tab.dart';
import 'package:nizan_crm/features/marketing/presentation/leadreport/lead_report_widgets.dart';
import 'package:nizan_crm/features/marketing/presentation/leadreport/lead_reports_tab.dart';
import 'package:nizan_crm/features/marketing/presentation/leadreport/lead_speed_tab.dart';
import 'package:nizan_crm/features/marketing/presentation/leadreport/lead_sources_tab.dart';
import 'package:nizan_crm/features/marketing/presentation/leadreport/lead_stages_tab.dart';
import 'package:nizan_crm/features/marketing/presentation/team/team_filter_bar.dart';

/// The seven screens of the Lead Report, in the order the marketing team's document draws them (the keys are `?tab=` and the sidebar's
/// sub-items).
const kLeadReportTabs = [
  ('overview', 'Overview', Icons.home_outlined),
  ('leads', 'All Leads', Icons.people_alt_outlined),
  ('stages', 'Lead Stages', Icons.filter_alt_outlined),
  ('sources', 'Sources', Icons.hub_outlined),
  ('followups', 'Follow-ups', Icons.notifications_active_outlined),
  ('speed', 'Speed to lead', Icons.timer_outlined),
  ('conversion', 'Conversion', Icons.trending_up_rounded),
  ('reports', 'Reports', Icons.description_outlined),
];

/// Marketing → Lead Report. The leads, follow-ups and bookings are the CRM's own (read-only here); every number is counted once on the
/// server. The date range and brand filters are shared with the rest of Marketing.
class LeadReportScreen extends ConsumerStatefulWidget {
  const LeadReportScreen({super.key, this.initialTab = 'overview'});

  final String initialTab;

  @override
  ConsumerState<LeadReportScreen> createState() => _LeadReportScreenState();
}

class _LeadReportScreenState extends ConsumerState<LeadReportScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: kLeadReportTabs.length, vsync: this, initialIndex: _indexOf(widget.initialTab));
  bool _exporting = false;

  static int _indexOf(String tab) {
    final i = kLeadReportTabs.indexWhere((t) => t.$1 == tab);
    return i < 0 ? 0 : i;
  }

  /// Open a tab — and put it in the address (`?tab=`), so the sidebar's sub-item, a refresh and a shared link all agree with the page.
  void _go(String tab) {
    _tabs.animateTo(_indexOf(tab));
    _syncUrl();
  }

  void _syncUrl() {
    final router = GoRouter.maybeOf(context);
    if (router == null) return; // not inside the app's router (a test)
    final want = kLeadReportTabs[_tabs.index].$1;
    if (GoRouterState.of(context).uri.queryParameters['tab'] != want) router.go('/marketing/leads-report?tab=$want');
  }

  Future<void> _export() async {
    final type = kLeadExportOf[kLeadReportTabs[_tabs.index].$1];
    if (type == null) return;
    setState(() => _exporting = true);
    try {
      await exportLeadReport(context, ref, type);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _tabs.addListener(() {
      if (!_tabs.indexIsChanging && mounted) _syncUrl();
    });
  }

  @override
  void didUpdateWidget(covariant LeadReportScreen old) {
    super.didUpdateWidget(old);
    if (old.initialTab != widget.initialTab) _go(widget.initialTab);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MktPage(
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            AnimatedBuilder(
              animation: _tabs,
              builder: (context, _) {
                final tab = kLeadReportTabs[_tabs.index].$1;
                return MktHeader(
                  icon: Icons.person_search_outlined,
                  breadcrumb: 'Lead Report',
                  title: kLeadReportTabs[_tabs.index].$2,
                  subtitle: 'Leads, stages, sources, follow-ups and conversion — read from the CRM',
                  actions: [
                    ...teamFilterActions(context, ref, showMember: false),
                    // the Reports tab has a download on every report; every other tab exports its own figures
                    if (kLeadExportOf.containsKey(tab))
                      OutlinedButton.icon(
                        key: const Key('lr_export'),
                        onPressed: _exporting ? null : _export,
                        style: OutlinedButton.styleFrom(minimumSize: const Size(0, 38), foregroundColor: Mkt.maroon, side: const BorderSide(color: Mkt.border), backgroundColor: Mkt.card, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9))),
                        icon: const Icon(Icons.download_rounded, size: 17),
                        label: Text(_exporting ? 'Building…' : 'Export CSV'),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 14),
            AnimatedBuilder(
              animation: _tabs,
              builder: (context, _) => MktTabPills(keyPrefix: 'lr_tab', tabs: [for (final t in kLeadReportTabs) MktTabSpec(t.$1, t.$2, t.$3)], selected: kLeadReportTabs[_tabs.index].$1, onSelect: _go),
            ),
          ]),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              LeadOverviewTab(onGo: _go),
              const LeadListTab(),
              const LeadStagesTab(),
              const LeadSourcesTab(),
              const LeadFollowUpsTab(),
              const LeadSpeedTab(),
              const LeadConversionTab(),
              const LeadReportsTab(),
            ],
          ),
        ),
      ]),
    );
  }
}
