import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:nizan_crm/features/marketing/presentation/kit/mkt_kit.dart';
import 'package:nizan_crm/features/marketing/presentation/metaleads/meta_ads_tab.dart';
import 'package:nizan_crm/features/marketing/presentation/metaleads/meta_capi_tab.dart';
import 'package:nizan_crm/features/marketing/presentation/metaleads/meta_ig_tab.dart';
import 'package:nizan_crm/features/marketing/presentation/metaleads/meta_leads_screen.dart';

/// The tabs of Marketing → Campaigns → Meta (the keys are `?tab=`).
const kMetaTabs = [('spend', 'Ad spend', Icons.payments_outlined), ('leads', 'Lead Ads', Icons.person_add_alt_1_outlined), ('results', 'Results to Meta', Icons.ios_share_rounded), ('instagram', 'Instagram', Icons.camera_alt_outlined)];

/// Marketing → Campaigns → Meta: the live ad spend sync, Lead Ads, lead results sent back to Meta, and Instagram insights.
class MetaScreen extends StatefulWidget {
  const MetaScreen({super.key, this.initialTab = 'spend'});
  final String initialTab;

  @override
  State<MetaScreen> createState() => _MetaScreenState();
}

class _MetaScreenState extends State<MetaScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: kMetaTabs.length, vsync: this, initialIndex: _indexOf(widget.initialTab));

  static int _indexOf(String tab) {
    final i = kMetaTabs.indexWhere((t) => t.$1 == tab);
    return i < 0 ? 0 : i;
  }

  void _go(String tab) => _tabs.animateTo(_indexOf(tab));

  @override
  void didUpdateWidget(covariant MetaScreen old) {
    super.didUpdateWidget(old);
    if (old.initialTab != widget.initialTab) _go(widget.initialTab);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MktPage(
    child: Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          MktHeader(
            icon: Icons.all_inclusive_rounded,
            breadcrumb: 'Campaigns',
            title: 'Meta',
            subtitle: 'Ad spend, Lead Ads and Instagram from Meta; lead results back to it',
            actions: [
              OutlinedButton.icon(
                key: const Key('meta_back_to_campaigns'),
                onPressed: () => GoRouter.maybeOf(context)?.go('/marketing/campaigns'),
                icon: const Icon(Icons.arrow_back_rounded, size: 17),
                label: const Text('Campaigns'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AnimatedBuilder(
            animation: _tabs,
            builder: (context, _) => MktTabPills(keyPrefix: 'meta_tab', tabs: [for (final t in kMetaTabs) MktTabSpec(t.$1, t.$2, t.$3)], selected: kMetaTabs[_tabs.index].$1, onSelect: _go),
          ),
        ]),
      ),
      const SizedBox(height: 10),
      Expanded(child: TabBarView(controller: _tabs, children: const [MetaAdSpendTab(), MetaLeadAdsTab(), MetaCapiTab(), MetaIgTab()])),
    ]),
  );
}
