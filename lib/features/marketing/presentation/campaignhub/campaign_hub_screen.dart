import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:nizan_crm/features/marketing/presentation/campaignhub/campaign_editor.dart';
import 'package:nizan_crm/features/marketing/presentation/campaignhub/hub_ads_tab.dart';
import 'package:nizan_crm/features/marketing/presentation/campaignhub/hub_budget_tab.dart';
import 'package:nizan_crm/features/marketing/presentation/campaignhub/hub_campaigns_tab.dart';
import 'package:nizan_crm/features/marketing/presentation/campaignhub/hub_leads_tab.dart';
import 'package:nizan_crm/features/marketing/presentation/campaignhub/hub_overview_tab.dart';
import 'package:nizan_crm/features/marketing/presentation/campaignhub/hub_performance_tab.dart';
import 'package:nizan_crm/features/marketing/presentation/campaignhub/hub_reports_tab.dart';
import 'package:nizan_crm/features/marketing/presentation/kit/mkt_kit.dart';
import 'package:nizan_crm/features/marketing/presentation/team/team_filter_bar.dart';
import 'package:nizan_crm/features/marketing/services/team_service.dart';

/// The seven screens of the Campaigns hub, in the order the marketing team's document draws them (the keys are `?tab=` and the sidebar's
/// sub-items — they are fixed).
const kHubTabs = [
  ('overview', 'Overview', Icons.home_outlined),
  ('campaigns', 'All Campaigns', Icons.list_alt_rounded),
  ('performance', 'Performance', Icons.bar_chart_rounded),
  ('creatives', 'Creatives & Ads', Icons.image_outlined),
  ('budget', 'Budget & Spend', Icons.account_balance_wallet_outlined),
  ('leads', 'Leads & Conversions', Icons.filter_alt_outlined),
  ('reports', 'Reports & Insights', Icons.insights_outlined),
];

/// Marketing → Campaigns. Plan, run and track paid marketing campaigns. Spend, reach, impressions and clicks come from the live Meta sync
/// (when the server is set up for it — Marketing → Campaigns → Meta), an Ads Manager file import, or a day typed by hand; leads, bookings
/// and revenue are the CRM's; the work members log against a campaign attaches to it. The date range and brand filters are shared with the
/// rest of Marketing.
class CampaignHubScreen extends ConsumerStatefulWidget {
  const CampaignHubScreen({super.key, this.initialTab = 'overview'});

  /// The `?tab=` of /marketing/campaigns.
  final String initialTab;

  @override
  ConsumerState<CampaignHubScreen> createState() => _CampaignHubScreenState();
}

class _CampaignHubScreenState extends ConsumerState<CampaignHubScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: kHubTabs.length, vsync: this, initialIndex: _indexOf(widget.initialTab));

  static int _indexOf(String tab) {
    final i = kHubTabs.indexWhere((t) => t.$1 == tab);
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
    final want = kHubTabs[_tabs.index].$1;
    if (GoRouterState.of(context).uri.queryParameters['tab'] != want) router.go('/marketing/campaigns?tab=$want');
  }

  @override
  void initState() {
    super.initState();
    _tabs.addListener(() {
      if (!_tabs.indexIsChanging && mounted) _syncUrl();
    });
  }

  @override
  void didUpdateWidget(covariant CampaignHubScreen old) {
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
              builder: (context, _) => MktHeader(
                icon: Icons.campaign_outlined,
                breadcrumb: 'Campaigns',
                title: kHubTabs[_tabs.index].$2,
                subtitle: 'Plan, run and track paid marketing campaigns',
                actions: [
                  ...teamFilterActions(context, ref, showMember: false),
                  MktPrimaryButton(key: const Key('hub_new_campaign'), label: 'New Campaign', onPressed: () => showCampaignEditor(context, ref, defaultBrand: defaultBrandFor(ref.read(teamFilterProvider).brand.wire))),
                ],
              ),
            ),
            const SizedBox(height: 14),
            AnimatedBuilder(
              animation: _tabs,
              builder: (context, _) => MktTabPills(keyPrefix: 'hub_tab', tabs: [for (final t in kHubTabs) MktTabSpec(t.$1, t.$2, t.$3)], selected: kHubTabs[_tabs.index].$1, onSelect: _go),
            ),
          ]),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              HubOverviewTab(onGo: _go),
              const HubCampaignsTab(),
              const HubPerformanceTab(),
              const HubAdsTab(),
              const HubBudgetTab(),
              const HubLeadsTab(),
              const HubReportsTab(),
            ],
          ),
        ),
      ]),
    );
  }
}
