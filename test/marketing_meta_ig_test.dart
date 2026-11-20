import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nizan_crm/core/models/auth_session.dart';
import 'package:nizan_crm/core/providers/auth_provider.dart';
import 'package:nizan_crm/core/theme/app_theme.dart';
import 'package:nizan_crm/features/marketing/data/meta_ads_models.dart';
import 'package:nizan_crm/features/marketing/data/meta_capi_models.dart';
import 'package:nizan_crm/features/marketing/data/meta_ig_models.dart';
import 'package:nizan_crm/features/marketing/data/meta_leads_models.dart';
import 'package:nizan_crm/features/marketing/presentation/metaleads/meta_ig_tab.dart';
import 'package:nizan_crm/features/marketing/presentation/metaleads/meta_screen.dart';
import 'package:nizan_crm/features/marketing/services/meta_ads_service.dart';
import 'package:nizan_crm/features/marketing/services/meta_capi_service.dart';
import 'package:nizan_crm/features/marketing/services/meta_ig_service.dart';
import 'package:nizan_crm/features/marketing/services/meta_leads_service.dart';

// Instagram insights on the Meta screen: what is set on the server (never its secrets), the accounts with their followers, finding the
// Pages' accounts, the last run in words, Sync now, the automatic sync (only a manager switches it), and posts no Socials post matched
// (link to a planned post of the same brand, add, add all, hide, show again).

Map<String, dynamic> _status({bool ready = true, bool manager = true, bool ok = true, List<Map<String, dynamic>>? unmatched, List<String> ignored = const [], bool lastRun = true}) => {
  'config': {
    'appSecret': true,
    'token': true,
    'accounts': ready ? [{'id': '17841400000000001', 'brand': 'main', 'username': '@teamn.makeovers', 'followers': 15230}, {'id': '17841400000000002', 'brand': 'kerala', 'username': '', 'followers': null}] : [],
    'ready': ready,
    'canFind': true,
    'version': 'v25.0',
  },
  'settings': {'autoSync': true, 'everyHours': 6, 'days': 30, 'maxDays': 90},
  'canManage': manager,
  'running': false,
  'lastRun': lastRun ? {'at': '2026-11-18T08:40:00.000Z', 'trigger': 'auto', 'days': 30, 'ok': ok, 'problemCode': ok ? '' : 'permission', 'problem': ok ? '' : 'The token may not read this Instagram account.', 'accounts': 2, 'media': 24, 'updated': 20, 'linked': 3, 'unmatched': 4, 'gaps': 2} : null,
  'lastOkAt': '2026-11-18T02:40:00.000Z',
  'nextAutoAt': '2026-11-18T14:40:00.000Z',
  'syncedPosts': 57,
  'unmatched': unmatched ??
      [
        {'mediaId': '9003', 'username': 'teamn.makeovers', 'brand': 'main', 'contentType': 'reel', 'caption': 'Reel A #party', 'at': '2026-11-15T05:00:00.000Z', 'metrics': {'reach': 1200, 'views': 3400, 'likes': 210}},
        {'mediaId': '9101', 'username': 'teamn.kerala', 'brand': 'kerala', 'contentType': 'post', 'caption': '', 'at': '2026-11-17T05:00:00.000Z', 'metrics': {'reach': 80, 'views': 0, 'likes': 9}},
      ],
  'ignored': ignored,
  'postChoices': [
    {'id': 'c1', 'title': 'Party reel', 'brand': 'main', 'contentType': 'reel', 'status': 'scheduled', 'scheduledDate': '2026-11-15T04:00:00.000Z'},
    {'id': 'c2', 'title': 'Kerala bride', 'brand': 'kerala', 'contentType': 'post', 'status': 'planned', 'scheduledDate': '2026-11-17T04:00:00.000Z'},
  ],
};

class _Fake extends MetaIgService {
  _Fake() : super(Dio());
  final calls = <String>[];
  @override
  Future<MetaIgRun> syncNow(int days) async {
    calls.add('sync $days');
    return MetaIgRun.fromJson({'ok': true, 'days': days, 'media': 40, 'updated': 38, 'linked': 1, 'unmatched': 2});
  }

  @override
  Future<MetaIgStatus> setAutoSync(bool on) async {
    calls.add('auto $on');
    return MetaIgStatus.fromJson(_status());
  }

  @override
  Future<List<MetaIgFound>> find() async {
    calls.add('find');
    return [MetaIgFound.fromJson(const {'pageId': '111', 'pageName': 'Team N Makeovers', 'igId': '17841400000000001', 'username': 'teamn.makeovers'}), MetaIgFound.fromJson(const {'pageId': '222', 'pageName': 'Team N Academy', 'problem': 'No Instagram business account is linked to this Page.'})];
  }

  @override
  Future<int> add(String mediaId) async {
    calls.add('add $mediaId');
    return 1;
  }

  @override
  Future<int> addAll() async {
    calls.add('add all');
    return 2;
  }

  @override
  Future<void> link(String mediaId, String contentId) async => calls.add('link $mediaId $contentId');
  @override
  Future<void> ignore(String mediaId) async => calls.add('ignore $mediaId');
  @override
  Future<void> restore(String mediaId) async => calls.add('restore $mediaId');
}

Future<_Fake> _pump(WidgetTester t, Map<String, dynamic> status, {double width = 1300, Widget child = const MetaIgTab()}) async {
  t.view.physicalSize = Size(width, 2400);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final svc = _Fake();
  await t.pumpWidget(ProviderScope(
    overrides: [
      authSessionProvider.overrideWithValue(const AuthSession(token: 't', userId: 'u', name: 'U', email: 'u@x', role: 'admin')),
      metaIgServiceProvider.overrideWithValue(svc),
      metaIgStatusProvider.overrideWith((ref) async => MetaIgStatus.fromJson(status)),
      metaAdsServiceProvider.overrideWithValue(MetaAdsService(Dio())),
      metaAdsStatusProvider.overrideWith((ref) async => const MetaAdsStatus()),
      metaCapiStatusProvider.overrideWith((ref) async => const MetaCapiStatus()),
      metaLeadsStatusProvider.overrideWith((ref) async => const MetaLeadsStatus()),
      metaEventsProvider.overrideWith((ref) async => const MetaEventPage()),
    ],
    child: MaterialApp(theme: AppTheme.lightTheme, home: Scaffold(body: child)),
  ));
  await t.pumpAndSettle();
  return svc;
}

FilledButton _filled(WidgetTester t, String key) => t.widget<FilledButton>(find.descendant(of: find.byKey(Key(key)), matching: find.byWidgetPredicate((w) => w is FilledButton)));

void main() {
  test('a run in words', () {
    expect(MetaIgRun.fromJson(const {'ok': true, 'days': 30, 'media': 24, 'updated': 20, 'linked': 3, 'unmatched': 4}).summary, '24 posts read (last 30 days): 20 posts updated (3 newly linked); 4 to add or link.');
    expect(MetaIgRun.fromJson(const {'ok': true, 'days': 7, 'media': 1, 'updated': 1}).summary, '1 post read (last 7 days): 1 post updated.');
    expect(MetaIgRun.fromJson(const {'ok': false, 'problem': 'Meta refused.'}).summary, 'Meta refused.');
    expect(MetaIgUnmatched.fromJson(const {'mediaId': '1', 'caption': '\n  First line\nsecond'}).firstLine, 'First line');
  });

  testWidgets('set up and synced: accounts with followers, the last run, gaps, the next automatic run', (t) async {
    await _pump(t, _status());
    expect(find.text('Connected'), findsOneWidget);
    expect(find.text('@teamn.makeovers · Main'), findsOneWidget);
    expect(find.text('15,230 followers'), findsOneWidget);
    expect(find.text('17841400000000002 · Kerala · not synced yet'), findsOneWidget);
    expect(find.text('24 posts read (last 30 days): 20 posts updated (3 newly linked); 4 to add or link.'), findsOneWidget);
    expect(find.byKey(const Key('meta_ig_gaps')), findsOneWidget);
    expect(find.textContaining('57 posts take their figures from Instagram'), findsOneWidget);
    expect(find.textContaining('Runs on its own every 6 hours (the last 30 days) · next'), findsOneWidget);
    expect(find.byKey(const Key('meta_ig_setup_steps')), findsNothing);
  });

  testWidgets('not set up: the steps; finding the accounts still works, and shows the ids to copy', (t) async {
    final svc = await _pump(t, _status(ready: false, lastRun: false, unmatched: const []));
    expect(find.text('Not set up'), findsOneWidget);
    expect(find.byKey(const Key('meta_ig_setup_steps')), findsOneWidget);
    expect(_filled(t, 'meta_ig_sync_button').onPressed, isNull);
    await t.tap(find.byKey(const Key('meta_ig_find')));
    await t.pumpAndSettle();
    expect(svc.calls, ['find']);
    expect(find.text('Team N Makeovers → @teamn.makeovers · 17841400000000001'), findsOneWidget);
    expect(find.textContaining('No Instagram business account'), findsOneWidget);
  });

  testWidgets('Sync now with the days chosen; a manager switches the automatic sync', (t) async {
    final svc = await _pump(t, _status());
    await t.tap(find.byKey(const Key('meta_ig_days')));
    await t.pumpAndSettle();
    await t.tap(find.text('Last 90 days').last);
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('meta_ig_sync_button')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('meta_ig_auto')));
    await t.pumpAndSettle();
    expect(svc.calls, ['sync 90', 'auto false']);
    expect(find.text('40 posts read (last 90 days): 38 posts updated (1 newly linked); 2 to add or link.'), findsOneWidget);
  });

  testWidgets('a member cannot switch the automatic sync; a failed run in red', (t) async {
    await _pump(t, _status(manager: false, ok: false));
    expect(find.byKey(const Key('meta_ig_auto')), findsNothing);
    expect(find.text('Only the Marketing Manager or Admin can switch it.'), findsOneWidget);
    expect(find.text('Last sync failed'), findsOneWidget);
    expect(find.text('The token may not read this Instagram account.'), findsOneWidget);
  });

  testWidgets('not in Socials: linking offers only the same brand\'s planned posts; add, hide, add all', (t) async {
    final svc = await _pump(t, _status());
    expect(find.text('2 waiting'), findsOneWidget);
    expect(find.text('Reel A #party'), findsOneWidget);
    expect(find.text('Untitled post'), findsOneWidget);
    expect(find.textContaining('reach 1,200 · views 3,400 · likes 210'), findsOneWidget);
    await t.tap(find.byKey(const Key('meta_ig_link_9003')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('meta_ig_choice_c1')), findsOneWidget);
    expect(find.byKey(const Key('meta_ig_choice_c2')), findsNothing, reason: 'a Kerala post is not offered for a Main post');
    await t.tap(find.byKey(const Key('meta_ig_choice_c1')));
    await t.pumpAndSettle();
    expect(find.textContaining('Linked: "Party reel"'), findsOneWidget);
    await t.tap(find.byKey(const Key('meta_ig_add_9101')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('meta_ig_ignore_9003')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('meta_ig_add_all')));
    await t.pumpAndSettle();
    expect(svc.calls, ['link 9003 c1', 'add 9101', 'ignore 9003', 'add all']);
  });

  testWidgets('hidden posts can be shown again', (t) async {
    final svc = await _pump(t, _status(unmatched: const [], ignored: const ['9008']));
    expect(find.text('All matched'), findsOneWidget);
    await t.tap(find.byKey(const Key('meta_ig_ignored_toggle')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('meta_ig_restore_9008')));
    await t.pumpAndSettle();
    expect(svc.calls, ['restore 9008']);
  });

  testWidgets('phone width: everything fits', (t) async {
    await _pump(t, _status(), width: 380);
    expect(t.takeException(), isNull);
  });

  testWidgets('the Meta screen has it as its fourth tab', (t) async {
    await _pump(t, _status(), child: const MetaScreen(initialTab: 'instagram'));
    expect(find.byKey(const Key('meta_ig_list')), findsOneWidget);
  });
}
