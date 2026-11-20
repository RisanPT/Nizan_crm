import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nizan_crm/core/models/auth_session.dart';
import 'package:nizan_crm/core/providers/auth_provider.dart';
import 'package:nizan_crm/core/theme/app_theme.dart';
import 'package:nizan_crm/features/marketing/data/meta_ads_models.dart';
import 'package:nizan_crm/features/marketing/data/meta_capi_models.dart';
import 'package:nizan_crm/features/marketing/data/meta_leads_models.dart';
import 'package:nizan_crm/features/marketing/presentation/kit/mkt_kit.dart';
import 'package:nizan_crm/features/marketing/presentation/metaleads/meta_capi_tab.dart';
import 'package:nizan_crm/features/marketing/presentation/metaleads/meta_screen.dart';
import 'package:nizan_crm/features/marketing/services/meta_ads_service.dart';
import 'package:nizan_crm/features/marketing/services/meta_capi_service.dart';
import 'package:nizan_crm/features/marketing/services/meta_leads_service.dart';

// Lead results back to Meta on the Meta screen: off until a manager switches it on (after saying what is shared); what is set on the
// server (never its secrets) and test mode; Send now only while on; what the last run did or why it failed; what was sent, waits or
// was not taken, with the reason.

Map<String, dynamic> _status({bool ready = true, bool enabled = true, bool manager = true, bool testMode = false, bool ownToken = true, bool ok = true, bool recent = true}) => {
  'config': {'dataset': ready, 'token': ready, 'ownToken': ownToken, 'testMode': testMode, 'ready': ready, 'version': 'v25.0'},
  'settings': {'enabled': enabled, 'enabledAt': enabled ? '2026-11-10T05:00:00.000Z' : null, 'updatedByName': enabled ? 'Meera' : '', 'everyMinutes': 60, 'maxAgeDays': 7, 'windowDays': 35, 'crmName': 'Team N CRM'},
  'canManage': manager,
  'running': false,
  'lastRun': {'at': '2026-11-18T08:00:00.000Z', 'trigger': 'auto', 'ok': ok, 'problemCode': ok ? '' : 'token', 'problem': ok ? '' : 'Meta refused the access token (expired, changed or withdrawn).', 'planned': 12, 'sent': ok ? 11 : 0, 'failed': ok ? 0 : 12, 'skipped': 1, 'expired': 0},
  'lastSentAt': '2026-11-18T08:00:00.000Z',
  'counts30': {'pending': 0, 'sent': 64, 'failed': 1, 'skipped': 3, 'expired': 1},
  'sentByStage30': {'Lead': 30, 'Contacted': 18, 'Qualified': 9, 'Follow-up': 4, 'Converted': 3, 'Lost': 0},
  'followed': 42,
  'recent': recent
      ? [
          {'id': 'e1', 'leadgenId': '120000000000001', 'leadName': 'Asha Nair', 'stage': 'Converted', 'eventAt': '2026-11-18T06:00:00.000Z', 'status': 'sent', 'sentAt': '2026-11-18T08:00:00.000Z'},
          {'id': 'e2', 'leadgenId': '120000000000002', 'leadName': 'Bindu', 'stage': 'Lead', 'eventAt': '2026-11-18T05:00:00.000Z', 'status': 'failed', 'retry': true, 'attempts': 1, 'nextTryAt': '2026-11-18T08:10:00.000Z', 'problem': 'Meta had a problem answering.'},
          {'id': 'e3', 'leadgenId': '120000000000003', 'leadName': 'Chitra', 'stage': 'Lead', 'eventAt': '2026-11-08T05:00:00.000Z', 'status': 'skipped', 'problem': 'It was already older than Meta\'s 7 days when the CRM first saw it, so it was not sent.'},
          {'id': 'e4', 'leadgenId': '120000000000004', 'leadName': 'Deepa', 'stage': 'Qualified', 'eventAt': '2026-11-18T07:00:00.000Z', 'status': 'sent', 'test': true, 'sentAt': '2026-11-18T08:00:00.000Z'},
        ]
      : [],
};

class _Fake extends MetaCapiService {
  _Fake() : super(Dio());
  final calls = <String>[];
  @override
  Future<MetaCapiStatus> setEnabled(bool on) async {
    calls.add('enabled $on');
    return MetaCapiStatus.fromJson(_status(enabled: on));
  }

  @override
  Future<MetaCapiRun> sendNow() async {
    calls.add('send');
    return MetaCapiRun.fromJson(const {'ok': true, 'sent': 3, 'skipped': 1});
  }
}

Future<_Fake> _pump(WidgetTester t, Map<String, dynamic> status, {double width = 1300, Widget child = const MetaCapiTab()}) async {
  t.view.physicalSize = Size(width, 2200);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final svc = _Fake();
  await t.pumpWidget(ProviderScope(
    overrides: [
      authSessionProvider.overrideWithValue(const AuthSession(token: 't', userId: 'u', name: 'U', email: 'u@x', role: 'admin')),
      metaCapiServiceProvider.overrideWithValue(svc),
      metaCapiStatusProvider.overrideWith((ref) async => MetaCapiStatus.fromJson(status)),
      metaAdsServiceProvider.overrideWithValue(MetaAdsService(Dio())),
      metaAdsStatusProvider.overrideWith((ref) async => const MetaAdsStatus()),
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
  test('a run and an event in words', () {
    expect(MetaCapiRun.fromJson(const {'ok': true, 'sent': 11, 'skipped': 1}).summary, 'Sent 11 · 1 too old to send');
    expect(MetaCapiRun.fromJson(const {'ok': true}).summary, 'Nothing new to send');
    expect(MetaCapiRun.fromJson(const {'ok': false, 'problem': 'Meta refused.', 'failed': 3}).summary, 'Meta refused.');
    expect(MetaCapiRun.fromJson(const {'ok': true, 'sent': 2, 'failed': 1, 'expired': 1}).summary, 'Sent 2 · 1 not taken · 1 grew too old');
    final rows = (_status()['recent'] as List).map((e) => MetaCapiEventRow.fromJson(e as Map<String, dynamic>)).toList();
    expect(rows.map((r) => r.statusLabel).toList(), ['Sent', 'Will try again', 'Too old to send', 'Sent (test)']);
    expect(MetaCapiEventRow.fromJson(const {'id': 'x', 'status': 'failed', 'retry': false}).statusLabel, 'Not taken');
  });

  testWidgets('on: what Meta learns, the counts, the last run, what was sent and why some were not', (t) async {
    await _pump(t, _status());
    expect(find.text('On'), findsOneWidget);
    expect(find.textContaining('On since'), findsOneWidget);
    expect(find.text('42'), findsOneWidget);
    expect(find.text('Bookings sent'), findsOneWidget);
    expect(find.text('Sent 11 · 1 too old to send'), findsOneWidget);
    expect(find.text('Asha Nair'), findsOneWidget);
    expect(find.text('Will try again'), findsOneWidget);
    expect(find.byKey(const Key('meta_capi_problem_e3')), findsOneWidget);
    expect(find.byKey(const Key('meta_capi_problem_e1')), findsNothing, reason: 'a sent event has no problem to show');
    expect(find.text('Sent (test)'), findsOneWidget);
    expect(find.byKey(const Key('meta_capi_setup_steps')), findsNothing);
    expect(find.text('Conversions API token (META_CAPI_TOKEN)'), findsOneWidget);
  });

  testWidgets('Send now while on', (t) async {
    final svc = await _pump(t, _status());
    await t.tap(find.byKey(const Key('meta_capi_send')));
    await t.pumpAndSettle();
    expect(svc.calls, ['send']);
    expect(find.text('Sent 3 · 1 too old to send'), findsOneWidget);
  });

  testWidgets('switching on asks first — and Cancel leaves it off', (t) async {
    final svc = await _pump(t, _status(enabled: false, recent: false));
    expect(find.text('Off: nothing is sent to Meta'), findsOneWidget);
    expect(_filled(t, 'meta_capi_send').onPressed, isNull, reason: 'nothing to send while off');
    expect(find.text('Nothing sent: it is switched off.'), findsOneWidget);
    await t.tap(find.byKey(const Key('meta_capi_switch')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('meta_capi_confirm')), findsOneWidget);
    expect(find.textContaining('privacy notice'), findsOneWidget);
    await t.tap(find.text('Cancel'));
    await t.pumpAndSettle();
    expect(svc.calls, isEmpty);
    await t.tap(find.byKey(const Key('meta_capi_switch')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('meta_capi_confirm_yes')));
    await t.pumpAndSettle();
    expect(svc.calls, ['enabled true']);
  });

  testWidgets('switching off needs no question', (t) async {
    final svc = await _pump(t, _status());
    await t.tap(find.byKey(const Key('meta_capi_switch')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('meta_capi_confirm')), findsNothing);
    expect(svc.calls, ['enabled false']);
  });

  testWidgets('a member sees it but cannot switch it', (t) async {
    await _pump(t, _status(manager: false));
    expect(find.byKey(const Key('meta_capi_switch')), findsNothing);
    expect(find.text('Only the Marketing Manager or Admin can switch it.'), findsOneWidget);
  });

  testWidgets('not set up: what is missing, the steps; it cannot be switched on', (t) async {
    await _pump(t, _status(ready: false, enabled: false, ownToken: false, recent: false));
    expect(find.text('Not set up'), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('meta_capi_has_dataset')), matching: find.text('Missing')), findsOneWidget);
    expect(find.text('Access token (META_ACCESS_TOKEN)'), findsOneWidget);
    expect(find.byKey(const Key('meta_capi_setup_steps')), findsOneWidget);
    expect(t.widget<Switch>(find.byKey(const Key('meta_capi_switch'))).onChanged, isNull);
  });

  testWidgets('test mode is said plainly; a failed run in red', (t) async {
    await _pump(t, _status(testMode: true, ok: false));
    expect(find.text('Test mode'), findsOneWidget);
    expect(find.textContaining('Remove META_CAPI_TEST_CODE to send for real'), findsOneWidget);
    expect(t.widget<Text>(find.byKey(const Key('meta_capi_last_run'))).style?.color, Mkt.bad);
    expect(find.text('Meta refused the access token (expired, changed or withdrawn).'), findsOneWidget);
  });

  testWidgets('phone width: everything fits', (t) async {
    await _pump(t, _status(), width: 380);
    expect(t.takeException(), isNull);
  });

  testWidgets('the Meta screen has it as its third tab', (t) async {
    await _pump(t, _status(), child: const MetaScreen(initialTab: 'results'));
    expect(find.byKey(const Key('meta_capi_list')), findsOneWidget);
    expect(find.text('Results to Meta'), findsWidgets);
  });
}
