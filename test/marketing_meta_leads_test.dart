import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nizan_crm/core/models/auth_session.dart';
import 'package:nizan_crm/core/providers/auth_provider.dart';
import 'package:nizan_crm/core/theme/app_theme.dart';
import 'package:nizan_crm/features/marketing/data/campaign_hub_models.dart';
import 'package:nizan_crm/features/marketing/data/meta_leads_models.dart';
import 'package:nizan_crm/features/marketing/presentation/campaignhub/meta_import.dart';
import 'package:nizan_crm/features/marketing/presentation/metaleads/meta_leads_screen.dart';
import 'package:nizan_crm/features/marketing/services/meta_leads_service.dart';

// Meta Lead Ads: whether the server is set up (never its secrets), who gets new leads (only a manager changes it), what came in and why
// a lead could not be taken in, Try again, Check for missed leads, and the way in from the Campaigns hub's Meta card.

Map<String, dynamic> _statusJson({bool ready = true, bool manager = true, String mode = 'none', List<Map<String, dynamic>> rotate = const [], Map<String, dynamic>? lastCheck}) => {
  'config': {'appSecret': ready, 'token': ready, 'verifyToken': true, 'ready': ready, 'version': 'v25.0', 'webhookPath': '/api/meta/webhook'},
  'canManage': manager,
  'settings': {'assignMode': mode, 'rotateUsers': rotate, 'updatedByName': mode == 'rotate' ? 'Meera' : ''},
  'pageIds': ['111'],
  'lastCheck': lastCheck,
  'lastLeadAt': '2026-11-18T05:00:00.000Z',
  'counts30': {'created': 12, 'existing': 3, 'failed': 2, 'waiting': 1},
  'assignees': [
    {'id': 's1', 'name': 'Sam One', 'role': 'sales'},
    {'id': 's2', 'name': 'Sara Two', 'role': 'sales_executive'},
  ],
};

final _events = MetaEventPage.fromJson({
  'items': [
    {'id': 'e1', 'leadgenId': '9001', 'via': 'webhook', 'status': 'created', 'submittedAt': '2026-11-18T05:00:00.000Z', 'leadName': 'Asha Nair', 'formName': 'Bridal Nov', 'adName': 'Reel 17', 'campaignName': 'Kerala Nov', 'platform': 'ig', 'leadId': 'L1', 'assignedToName': 'Sam One'},
    {'id': 'e2', 'leadgenId': '9100', 'via': 'webhook', 'status': 'failed', 'attempts': 2, 'retry': true, 'nextTryAt': '2026-11-18T06:00:00.000Z', 'problemCode': 'token', 'problemText': 'Meta refused the access token (expired, changed or withdrawn).', 'leadName': 'Esha', 'formName': 'Bridal Nov', 'platform': 'fb'},
    {'id': 'e3', 'leadgenId': '9300', 'via': 'check', 'status': 'failed', 'attempts': 1, 'retry': false, 'problemCode': 'no_phone', 'problemText': 'The form had no phone number, so no CRM lead could be made.', 'leadName': 'Fida', 'email': 'fida@example.com'},
    {'id': 'e4', 'leadgenId': '9004', 'via': 'webhook', 'status': 'existing', 'leadName': 'Deepa', 'leadId': 'L9', 'isOrganic': true, 'platform': 'fb'},
  ],
  'total': 4,
  'page': 1,
  'pages': 1,
});

class _Fake extends MetaLeadsService {
  _Fake() : super(Dio());
  final saved = <(String, List<String>)>[];
  final retried = <String>[];
  final checked = <int>[];
  int tests = 0;
  @override
  Future<MetaLeadsStatus> saveAssignment(String mode, List<String> userIds) async {
    saved.add((mode, userIds));
    return MetaLeadsStatus.fromJson(_statusJson(mode: mode));
  }

  @override
  Future<MetaLeadEvent> retry(String id) async {
    retried.add(id);
    return MetaLeadEvent.fromJson(const {'id': 'e2', 'status': 'created', 'leadName': 'Esha'});
  }

  @override
  Future<MetaCheckResult> checkMissed(int days) async {
    checked.add(days);
    return MetaCheckResult.fromJson({'days': days, 'forms': 3, 'found': 12, 'added': 2, 'already': 10, 'failed': 0, 'at': '2026-11-18T06:00:00.000Z', 'byName': 'Saeeda'});
  }

  @override
  Future<MetaTestResult> test() async {
    tests += 1;
    return MetaTestResult.fromJson(const {'ok': true, 'name': 'Nizan Leads Bot', 'pages': [{'id': '111', 'name': 'Team N Makeovers', 'ok': true, 'problem': ''}]});
  }
}

Future<(_Fake, List<String>)> _pump(WidgetTester t, {Map<String, dynamic>? status, String role = 'admin', double width = 1300}) async {
  t.view.physicalSize = Size(width, 2400);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final svc = _Fake();
  final went = <String>[];
  final router = GoRouter(
    initialLocation: '/marketing/meta-leads',
    routes: [
      GoRoute(path: '/marketing/meta-leads', builder: (_, _) => const Scaffold(body: MetaLeadAdsTab())),
      GoRoute(path: '/sales/leads/:id', builder: (_, s) {
        went.add('/sales/leads/${s.pathParameters['id']}');
        return const Scaffold(body: Text('lead page'));
      }),
      GoRoute(path: '/marketing/campaigns', builder: (_, _) {
        went.add('/marketing/campaigns');
        return const Scaffold(body: Text('campaigns'));
      }),
    ],
  );
  await t.pumpWidget(ProviderScope(
    overrides: [
      authSessionProvider.overrideWithValue(AuthSession(token: 't', userId: 'u', name: 'U', email: 'u@x', role: role)),
      metaLeadsServiceProvider.overrideWithValue(svc),
      metaLeadsStatusProvider.overrideWith((ref) async => MetaLeadsStatus.fromJson(status ?? _statusJson())),
      metaEventsProvider.overrideWith((ref) async => _events),
    ],
    child: MaterialApp.router(theme: AppTheme.lightTheme, routerConfig: router),
  ));
  await t.pumpAndSettle();
  return (svc, went);
}

void main() {
  test('webhook address: the API base + /meta/webhook, whatever the trailing slash', () {
    expect(metaWebhookAddress('https://api.teamn.example/api'), 'https://api.teamn.example/api/meta/webhook');
    expect(metaWebhookAddress('https://api.teamn.example/api/'), 'https://api.teamn.example/api/meta/webhook');
  });

  test('a check says what it found in plain words; a check with no Page says why', () {
    final r = MetaCheckResult.fromJson(const {'days': 7, 'forms': 3, 'found': 12, 'added': 2, 'already': 10});
    expect(r.summary, 'Found 12 leads in 3 forms (last 7 days): 2 taken in now, 10 already here.');
    expect(MetaCheckResult.fromJson(const {'days': 1, 'forms': 1, 'found': 1, 'already': 1}).summary, 'Found 1 lead in 1 form (last 1 day): 1 already here.');
    expect(MetaCheckResult.fromJson(const {'forms': 0, 'problem': 'No Facebook Page is known yet.'}).summary, 'No Facebook Page is known yet.');
  });

  test('a lead\'s origin and status read as the team says them', () {
    final e = _events.items;
    expect(e[0].origin, 'Instagram · form "Bridal Nov" · ad "Reel 17" · campaign "Kerala Nov"');
    expect(e[3].origin, 'Facebook (no ad)');
    expect(e.map((x) => x.statusLabel).toList(), ['New lead', 'Not taken in', 'Not taken in', 'Already a lead']);
  });

  testWidgets('set up: the counts, each setting as Set (never its value), the webhook address, the test', (t) async {
    final (svc, _) = await _pump(t);
    expect(find.byKey(const Key('meta_ready_chip')), findsOneWidget);
    expect(find.text('Receiving leads'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    expect(find.text('Not taken in'), findsWidgets);
    for (final k in ['appSecret', 'token', 'verifyToken']) {
      expect(find.descendant(of: find.byKey(Key('meta_has_$k')), matching: find.text('Set')), findsOneWidget);
    }
    expect(find.byKey(const Key('meta_setup_steps')), findsNothing);
    expect((t.widget<SelectableText>(find.byKey(const Key('meta_webhook_address')))).data, endsWith('/meta/webhook'));
    await t.tap(find.byKey(const Key('meta_test_button')));
    await t.pumpAndSettle();
    expect(svc.tests, 1);
    expect(find.text('Connected as Nizan Leads Bot'), findsOneWidget);
    expect(find.text('Page Team N Makeovers: can be read'), findsOneWidget);
  });

  testWidgets('not set up: what is missing, the steps, and nothing to test or check', (t) async {
    await _pump(t, status: _statusJson(ready: false));
    expect(find.text('Not set up'), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('meta_has_token')), matching: find.text('Missing')), findsOneWidget);
    expect(find.byKey(const Key('meta_setup_steps')), findsOneWidget);
    expect(t.widget<ButtonStyleButton>(find.byKey(const Key('meta_test_button'))).onPressed, isNull);
    expect(t.widget<FilledButton>(find.descendant(of: find.byKey(const Key('meta_check_button')), matching: find.byWidgetPredicate((w) => w is FilledButton))).onPressed, isNull);
  });

  testWidgets('a manager makes Sales take turns: picks people, saves in the list\'s order', (t) async {
    final (svc, _) = await _pump(t);
    expect(find.text('New Meta leads wait unassigned until a manager gives them out.'), findsOneWidget);
    FilledButton save() => t.widget<FilledButton>(find.descendant(of: find.byKey(const Key('meta_assign_save')), matching: find.byWidgetPredicate((w) => w is FilledButton)));
    expect(save().onPressed, isNull, reason: 'nothing changed yet');
    await t.tap(find.byKey(const Key('meta_mode_rotate')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('meta_assignee_s2')));
    await t.tap(find.byKey(const Key('meta_assignee_s1')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('meta_assign_save')));
    await t.pumpAndSettle();
    expect(svc.saved.single.$1, 'rotate');
    expect(svc.saved.single.$2, ['s1', 's2']);
  });

  testWidgets('taking turns with nobody picked is not sent', (t) async {
    final (svc, _) = await _pump(t);
    await t.tap(find.byKey(const Key('meta_mode_rotate')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('meta_assign_save')));
    await t.pumpAndSettle();
    expect(svc.saved, isEmpty);
    expect(find.text('Choose at least one Sales person to take turns.'), findsOneWidget);
  });

  testWidgets('a member sees who gets leads but cannot change it', (t) async {
    await _pump(t, status: _statusJson(manager: false, mode: 'rotate', rotate: const [{'id': 's1', 'name': 'Sam One', 'active': true}, {'id': 'x', 'name': 'Old Sales', 'active': false}]));
    expect(find.text('Sales take turns: Sam One, Old Sales (no longer active).'), findsOneWidget);
    expect(find.byKey(const Key('meta_assign_readonly')), findsOneWidget);
    expect(find.byKey(const Key('meta_assign_save')), findsNothing);
    expect(find.byKey(const Key('meta_mode_rotate')), findsNothing);
  });

  testWidgets('what came in: the reason a lead was not taken in, its next try, Try again; Open lead for those that made one', (t) async {
    final (svc, went) = await _pump(t);
    expect(find.text('Asha Nair'), findsOneWidget);
    expect(find.text('Instagram · form "Bridal Nov" · ad "Reel 17" · campaign "Kerala Nov"'), findsOneWidget);
    expect(find.textContaining('given to Sam One'), findsOneWidget);
    expect(find.byKey(const Key('meta_problem_e2')), findsOneWidget);
    expect(find.textContaining('Tried 2 times · next try'), findsOneWidget);
    expect(find.text('Will not be tried again on its own'), findsOneWidget);
    expect(find.textContaining('fida@example.com'), findsOneWidget, reason: 'a form without a phone shows its e-mail');
    expect(find.text('found by a check'), findsOneWidget);
    expect(find.byKey(const Key('meta_open_e2')), findsNothing);
    expect(find.byKey(const Key('meta_retry_e1')), findsNothing);
    await t.tap(find.byKey(const Key('meta_retry_e2')));
    await t.pumpAndSettle();
    expect(svc.retried, ['e2']);
    expect(find.text('Taken in as a new lead.'), findsOneWidget);
    await t.tap(find.byKey(const Key('meta_open_e1')));
    await t.pumpAndSettle();
    expect(went, ['/sales/leads/L1']);
  });

  testWidgets('without the Sales leads screen there is no Open lead link', (t) async {
    await _pump(t, role: 'marketing_staff_custom');
    expect(find.byKey(const Key('meta_open_e1')), findsNothing);
  });

  testWidgets('check for missed leads: the days chosen are sent; the result is said in words', (t) async {
    final (svc, _) = await _pump(t, status: _statusJson(lastCheck: const {'at': '2026-11-17T06:00:00.000Z', 'byName': 'Meera', 'days': 7, 'forms': 2, 'found': 5, 'added': 0, 'already': 5}));
    expect(find.text('Found 5 leads in 2 forms (last 7 days): 5 already here.'), findsOneWidget);
    await t.tap(find.byKey(const Key('meta_check_days')));
    await t.pumpAndSettle();
    await t.tap(find.text('Last 30 days').last);
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('meta_check_button')));
    await t.pumpAndSettle();
    expect(svc.checked, [30]);
    expect(find.text('Found 12 leads in 3 forms (last 30 days): 2 taken in now, 10 already here.'), findsOneWidget);
  });

  testWidgets('phone width: everything fits', (t) async {
    await _pump(t, width: 380);
    expect(t.takeException(), isNull);
    expect(find.byKey(const Key('meta_events_card')), findsOneWidget);
  });

  testWidgets('the Campaigns hub\'s Meta card says whether Lead Ads is connected and opens its screen', (t) async {
    t.view.physicalSize = const Size(900, 1200);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final went = <String>[];
    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, _) => Scaffold(body: SingleChildScrollView(child: MetaCard(meta: HubMeta.fromJson(const {'leadAds': true}), onImport: () {})))),
      GoRoute(path: '/marketing/meta', builder: (_, s) {
        went.add('meta?tab=${s.uri.queryParameters['tab']}');
        return const Scaffold(body: Text('meta screen'));
      }),
    ]);
    await t.pumpWidget(MaterialApp.router(routerConfig: router));
    await t.pumpAndSettle();
    expect(find.text('Lead Ads forms arrive as CRM leads on their own'), findsOneWidget);
    await t.tap(find.byKey(const Key('hub_meta_leads_button')));
    await t.pumpAndSettle();
    expect(went, ['meta?tab=leads']);
    expect(HubMeta.fromJson(const {}).leadAds, isFalse);
  });
}
