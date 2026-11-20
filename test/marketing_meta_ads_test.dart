import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nizan_crm/core/models/auth_session.dart';
import 'package:nizan_crm/core/providers/auth_provider.dart';
import 'package:nizan_crm/core/theme/app_theme.dart';
import 'package:nizan_crm/features/marketing/data/campaign_hub_models.dart';
import 'package:nizan_crm/features/marketing/data/meta_ads_models.dart';
import 'package:nizan_crm/features/marketing/data/meta_leads_models.dart';
import 'package:nizan_crm/features/marketing/presentation/campaignhub/meta_import.dart';
import 'package:nizan_crm/features/marketing/presentation/metaleads/meta_ads_tab.dart';
import 'package:nizan_crm/features/marketing/presentation/metaleads/meta_screen.dart';
import 'package:nizan_crm/features/marketing/services/meta_ads_service.dart';
import 'package:nizan_crm/features/marketing/services/meta_leads_service.dart';

// The live Meta ad spend sync on the Meta screen: whether the server is set up (never its secrets), what the last run brought in or why it
// failed, Sync now, the automatic sync (only a manager switches it), Meta campaigns not linked yet (link, add, add all, hide, show again),
// the two tabs, and the Campaigns hub's Meta card in each state.

Map<String, dynamic> _status({bool ready = true, bool manager = true, bool ok = true, bool auto = true, List<Map<String, dynamic>>? unlinked, List<String> ignored = const [], bool lastRun = true}) => {
  'config': {'appSecret': ready, 'token': ready, 'accounts': ready ? [{'id': 'act_111', 'brand': 'kerala'}, {'id': 'act_222', 'brand': 'main'}] : [], 'ready': ready, 'version': 'v25.0'},
  'settings': {'autoSync': auto, 'everyHours': 6, 'daysBack': 3, 'maxDays': 92},
  'canManage': manager,
  'running': false,
  'lastRun': lastRun
      ? {'at': '2026-11-18T08:40:00.000Z', 'trigger': 'auto', 'byName': 'Automatic sync', 'from': '2026-11-16', 'to': '2026-11-18', 'ok': ok, 'problemCode': ok ? '' : 'token', 'problem': ok ? '' : 'Meta refused the access token (expired, changed or withdrawn).', 'campaigns': 5, 'campaignDays': 15, 'adDays': 42, 'segments': 120, 'adsCreated': 2, 'spend': 12340, 'unlinkedSpend': ok ? 960 : 0}
      : null,
  'lastOkAt': '2026-11-18T02:40:00.000Z',
  'nextAutoAt': '2026-11-18T14:40:00.000Z',
  'unlinked': unlinked ??
      [
        {'metaId': '3003', 'name': 'Main Diwali', 'accountId': 'act_222', 'brand': 'main', 'reason': 'no_match', 'firstDay': '2026-11-01', 'lastDay': '2026-11-18', 'spend': 900, 'runFrom': '2026-11-16', 'runTo': '2026-11-18'},
        {'metaId': '3004', 'name': 'Bridal Reels', 'accountId': 'act_111', 'brand': 'kerala', 'reason': 'ambiguous', 'firstDay': '2026-11-17', 'lastDay': '2026-11-18', 'spend': 60, 'runFrom': '2026-11-16', 'runTo': '2026-11-18'},
      ],
  'ignored': ignored,
  'campaignChoices': [{'id': 'c1', 'title': 'Diwali promo', 'brand': 'main'}, {'id': 'c2', 'title': 'Party season', 'brand': 'kerala'}],
  'history': [{'id': 'h1', 'at': '2026-11-18T08:40:00.000Z', 'byName': 'Automatic sync', 'from': '2026-11-16', 'to': '2026-11-18', 'written': 177}],
};

class _Fake extends MetaAdsService {
  _Fake() : super(Dio());
  final calls = <String>[];
  @override
  Future<MetaSyncRun> syncNow(int days) async {
    calls.add('sync $days');
    return MetaSyncRun.fromJson(const {'ok': true, 'from': '2026-10-20', 'to': '2026-11-18', 'campaigns': 2, 'spend': 4500});
  }

  @override
  Future<MetaAdsStatus> setAutoSync(bool on) async {
    calls.add('auto $on');
    return MetaAdsStatus.fromJson(_status(auto: on));
  }

  @override
  Future<MetaLinkResult> link(String metaId, String campaignId) async {
    calls.add('link $metaId $campaignId');
    return MetaLinkResult.fromJson(const {'linked': [{}], 'leadsTagged': 1, 'run': {'ok': true}});
  }

  @override
  Future<MetaLinkResult> add(String metaId) async {
    calls.add('add $metaId');
    return MetaLinkResult.fromJson(const {'linked': [{}], 'leadsTagged': 0, 'run': {'ok': true}});
  }

  @override
  Future<MetaLinkResult> addAll() async {
    calls.add('add all');
    return MetaLinkResult.fromJson(const {'linked': [{}, {}], 'run': {'busy': true}});
  }

  @override
  Future<MetaAdsStatus> ignore(String metaId) async {
    calls.add('ignore $metaId');
    return MetaAdsStatus.fromJson(_status());
  }

  @override
  Future<MetaAdsStatus> restore(String metaId) async {
    calls.add('restore $metaId');
    return MetaAdsStatus.fromJson(_status());
  }
}

Future<_Fake> _pump(WidgetTester t, Map<String, dynamic> status, {double width = 1300, Widget? child}) async {
  t.view.physicalSize = Size(width, 2200);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final svc = _Fake();
  await t.pumpWidget(ProviderScope(
    overrides: [
      authSessionProvider.overrideWithValue(const AuthSession(token: 't', userId: 'u', name: 'U', email: 'u@x', role: 'admin')),
      metaAdsServiceProvider.overrideWithValue(svc),
      metaAdsStatusProvider.overrideWith((ref) async => MetaAdsStatus.fromJson(status)),
      metaLeadsStatusProvider.overrideWith((ref) async => const MetaLeadsStatus()),
      metaEventsProvider.overrideWith((ref) async => const MetaEventPage()),
    ],
    child: MaterialApp(theme: AppTheme.lightTheme, home: Scaffold(body: child ?? const MetaAdSpendTab())),
  ));
  await t.pumpAndSettle();
  return svc;
}

FilledButton _filled(WidgetTester t, String key) => t.widget<FilledButton>(find.descendant(of: find.byKey(Key(key)), matching: find.byWidgetPredicate((w) => w is FilledButton)));

void main() {
  test('a run in words: what it brought in, or why it failed; who ran it', () {
    final ok = MetaSyncRun.fromJson(_status()['lastRun'] as Map<String, dynamic>);
    expect(ok.summary, '₹12,340 on 5 campaigns, 16 – 18 Nov.');
    expect(ok.details, '15 campaign-days · 42 ad-days · 120 audience rows · 2 new ads');
    expect(ok.how, 'automatic');
    expect(MetaSyncRun.fromJson(const {'ok': true, 'from': '2026-11-18', 'to': '2026-11-18'}).summary, 'No spend on a linked campaign, 18 Nov.');
    expect(MetaSyncRun.fromJson(const {'ok': false, 'problem': 'Meta refused.'}).summary, 'Meta refused.');
    expect(MetaSyncRun.fromJson(const {'trigger': 'manual', 'byName': 'Saeeda'}).how, 'by Saeeda');
    expect(metaDays('2026-10-30', '2026-11-02'), '30 Oct – 2 Nov');
    expect(MetaLinkResult.fromJson(const {'linked': [{}], 'leadsTagged': 2, 'run': {'ok': true}}).message, 'Linked; 2 Meta leads now carry the campaign; figures brought in.');
    expect(MetaLinkResult.fromJson(const {'linked': [{}, {}], 'run': {'busy': true}}).message, '2 campaigns linked; their figures come with the next sync.');
  });

  testWidgets('set up and synced: the accounts with their brands, the last run, the next automatic one, spend not linked', (t) async {
    await _pump(t, _status());
    expect(find.text('Connected'), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('meta_ads_has_accounts')), matching: find.text('2')), findsOneWidget);
    expect(find.text('act_222 · new campaigns go to Main'), findsOneWidget);
    expect(find.byKey(const Key('meta_ads_setup_steps')), findsNothing);
    expect(find.text('₹12,340 on 5 campaigns, 16 – 18 Nov.'), findsOneWidget);
    expect(find.text('₹960 more was spent on Meta campaigns not linked yet (below).'), findsOneWidget);
    expect(find.textContaining('Runs on its own every 6 hours (the last 3 days) · next'), findsOneWidget);
    expect(find.text('Last sync worked'), findsOneWidget);
    expect(find.byKey(const Key('meta_ads_history')), findsOneWidget);
  });

  testWidgets('not set up: what is missing, the steps, and no Sync now', (t) async {
    await _pump(t, _status(ready: false, lastRun: false, unlinked: const []));
    expect(find.text('Not set up'), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('meta_ads_has_accounts')), matching: find.text('Missing')), findsOneWidget);
    expect(find.byKey(const Key('meta_ads_setup_steps')), findsOneWidget);
    expect(find.text('Nothing synced: the server is not set up.'), findsOneWidget);
    expect(_filled(t, 'meta_ads_sync_button').onPressed, isNull);
  });

  testWidgets('a failed run says why, in red, with the last good sync', (t) async {
    await _pump(t, _status(ok: false));
    expect(find.text('Last sync failed'), findsOneWidget);
    expect(find.text('Meta refused the access token (expired, changed or withdrawn).'), findsOneWidget);
    expect(find.textContaining('Last good sync:'), findsOneWidget);
  });

  testWidgets('Sync now with the days chosen', (t) async {
    final svc = await _pump(t, _status());
    await t.tap(find.byKey(const Key('meta_ads_days')));
    await t.pumpAndSettle();
    await t.tap(find.text('Last 30 days').last);
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('meta_ads_sync_button')));
    await t.pumpAndSettle();
    expect(svc.calls, ['sync 30']);
    expect(find.text('Synced: ₹4,500 on 2 campaigns, 20 Oct – 18 Nov.'), findsOneWidget);
  });

  testWidgets('a manager switches the automatic sync; a member only reads it', (t) async {
    final svc = await _pump(t, _status());
    await t.tap(find.byKey(const Key('meta_ads_auto')));
    await t.pumpAndSettle();
    expect(svc.calls, ['auto false']);
  });

  testWidgets('a member cannot switch the automatic sync', (t) async {
    await _pump(t, _status(manager: false, auto: false));
    expect(find.byKey(const Key('meta_ads_auto')), findsNothing);
    expect(find.text('Automatic sync is off'), findsOneWidget);
    expect(find.text('Only the Marketing Manager or Admin can switch it.'), findsOneWidget);
  });

  testWidgets('not linked: each with its brand and spend; link to a chosen campaign, add, hide, add all', (t) async {
    final svc = await _pump(t, _status());
    expect(find.text('2 waiting'), findsOneWidget);
    expect(find.text('Main Diwali'), findsOneWidget);
    expect(find.textContaining('₹900 spent 16 – 18 Nov (last sync) · first seen 1 Nov · act_222'), findsOneWidget);
    expect(find.text('two campaigns share this name'), findsOneWidget);
    await t.tap(find.byKey(const Key('meta_link_3003')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('meta_link_dialog')), findsOneWidget);
    await t.tap(find.byKey(const Key('meta_link_choice_c1')));
    await t.pumpAndSettle();
    expect(find.text('Linked; 1 Meta lead now carries the campaign; figures brought in.'), findsOneWidget);
    await t.tap(find.byKey(const Key('meta_add_3004')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('meta_ignore_3003')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('meta_add_all')));
    await t.pumpAndSettle();
    expect(svc.calls, ['link 3003 c1', 'add 3004', 'ignore 3003', 'add all']);
  });

  testWidgets('closing the link list without choosing links nothing', (t) async {
    final svc = await _pump(t, _status());
    await t.tap(find.byKey(const Key('meta_link_3003')));
    await t.pumpAndSettle();
    await t.tapAt(const Offset(5, 5));
    await t.pumpAndSettle();
    expect(svc.calls, isEmpty);
  });

  testWidgets('hidden campaigns can be shown again', (t) async {
    final svc = await _pump(t, _status(unlinked: const [], ignored: const ['3009']));
    expect(find.text('All linked'), findsOneWidget);
    await t.tap(find.byKey(const Key('meta_ignored_toggle')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('meta_restore_3009')));
    await t.pumpAndSettle();
    expect(svc.calls, ['restore 3009']);
  });

  testWidgets('phone width: everything fits', (t) async {
    await _pump(t, _status(), width: 380);
    expect(t.takeException(), isNull);
  });

  testWidgets('the Meta screen: two tabs; ?tab=leads opens Lead Ads', (t) async {
    await _pump(t, _status(), child: const MetaScreen(initialTab: 'leads'));
    expect(find.byKey(const Key('meta_leads_list')), findsOneWidget);
    await t.tap(find.byKey(const Key('meta_tab_spend')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('meta_ads_list')), findsOneWidget);
  });

  group('the Campaigns hub\'s Meta card', () {
    Future<List<String>> card(WidgetTester t, Map<String, dynamic> meta) async {
      t.view.physicalSize = const Size(900, 1200);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final went = <String>[];
      final router = GoRouter(routes: [
        GoRoute(path: '/', builder: (_, _) => Scaffold(body: SingleChildScrollView(child: MetaCard(meta: HubMeta.fromJson(meta), onImport: () => went.add('import'), onTypeDay: () {})))),
        GoRoute(path: '/marketing/meta', builder: (_, s) {
          went.add('meta?tab=${s.uri.queryParameters['tab']}');
          return const Scaffold(body: Text('meta screen'));
        }),
      ]);
      await t.pumpWidget(MaterialApp.router(routerConfig: router));
      await t.pumpAndSettle();
      return went;
    }

    testWidgets('live: when it last synced, what waits to be linked, straight to the sync', (t) async {
      final went = await card(t, const {'connected': true, 'status': 'connected', 'sync': {'lastOkAt': '2026-11-18T08:40:00.000Z', 'ok': true, 'unlinked': 2, 'autoSync': true}, 'lastImport': {'id': 'l', 'at': '2026-11-18T08:40:00.000Z', 'source': 'api'}});
      expect(find.text('Live sync on'), findsOneWidget);
      expect(find.textContaining('Figures come from Meta on their own every 6 hours'), findsOneWidget);
      expect(find.text('2 Meta campaigns not linked: their spend is not counted yet'), findsOneWidget);
      expect(find.textContaining('(Meta sync)'), findsOneWidget);
      await t.tap(find.byKey(const Key('hub_meta_sync_button')));
      await t.pumpAndSettle();
      expect(went, ['meta?tab=spend']);
    });

    testWidgets('a failed sync says why', (t) async {
      await card(t, const {'connected': true, 'status': 'error', 'sync': {'ok': false, 'problem': 'Meta refused the access token.', 'unlinked': 0}});
      expect(find.text('Sync failed'), findsOneWidget);
      expect(find.text('Meta refused the access token.'), findsOneWidget);
    });

    testWidgets('no sync on the server: the file import as before, and the way to set it up', (t) async {
      final went = await card(t, const {'connected': false, 'status': 'not_connected'});
      expect(find.text('Not connected'), findsOneWidget);
      expect(find.textContaining('Ad figures have no live Meta sync yet'), findsOneWidget);
      expect(find.byKey(const Key('hub_meta_sync_button')), findsNothing);
      await t.tap(find.byKey(const Key('hub_import_button')));
      await t.tap(find.byKey(const Key('hub_meta_setup_button')));
      await t.pumpAndSettle();
      expect(went, ['import', 'meta?tab=spend']);
    });
  });
}
