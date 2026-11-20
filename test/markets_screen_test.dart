import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nizan_crm/core/theme/app_theme.dart';
import 'package:nizan_crm/features/marketing/presentation/markets/markets_screen.dart';
import 'package:nizan_crm/features/marketing/presentation/shell/marketing_sidebar.dart';
import 'package:nizan_crm/providers/dio_provider.dart';

// Marketing → Countries & Cities. Everybody in Marketing reads the list; the Marketing Manager / Admin change it (the server says who).
// What is in use is switched off, not removed; a refusal from the server is shown in the dialog in plain words.

Map<String, dynamic> _list({bool canManage = true}) => {
  'canManage': canManage,
  'countries': [
    {
      'id': 'c-ae',
      'name': 'UAE',
      'code': 'AE',
      'dialCode': '+971',
      'currency': 'AED',
      'status': 'active',
      'leads': 5,
      'cities': [
        {'id': 'k-dxb', 'name': 'Dubai', 'state': '', 'status': 'active', 'leads': 4},
        {'id': 'k-shj', 'name': 'Sharjah', 'state': '', 'status': 'inactive', 'leads': 0},
      ],
    },
    {
      'id': 'c-my',
      'name': 'Malaysia',
      'code': 'MY',
      'dialCode': '+60',
      'currency': 'MYR',
      'status': 'inactive',
      'leads': 0,
      'cities': <Map<String, dynamic>>[],
    },
  ],
};

class _Api implements HttpClientAdapter {
  _Api({this.canManage = true});
  final bool canManage;
  final requests = <RequestOptions>[];

  /// Set to make the next change (POST / PUT / DELETE) fail.
  int? failStatus;
  String failMessage = '';

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    final headers = {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    };
    if (options.method != 'GET' && failStatus != null) {
      return ResponseBody.fromString(jsonEncode({'message': failMessage}), failStatus!, headers: headers);
    }
    return ResponseBody.fromString(jsonEncode(options.method == 'GET' ? _list(canManage: canManage) : {'ok': true}), options.method == 'POST' ? 201 : 200, headers: headers);
  }

  @override
  void close({bool force = false}) {}

  Iterable<RequestOptions> get changes => requests.where((r) => r.method != 'GET');
}

Future<_Api> _open(WidgetTester t, {bool canManage = true, int width = 1200}) async {
  final api = _Api(canManage: canManage);
  t.view.physicalSize = Size(width.toDouble(), 1600);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    ProviderScope(
      overrides: [dioProvider.overrideWithValue(Dio(BaseOptions(baseUrl: 'http://x/api'))..httpClientAdapter = api)],
      child: MaterialApp(theme: AppTheme.lightTheme, home: const Scaffold(body: MarketsScreen())),
    ),
  );
  await t.pumpAndSettle();
  return api;
}

Future<void> _menu(WidgetTester t, String key, String item) async {
  await t.tap(find.byKey(Key(key)));
  await t.pumpAndSettle();
  await t.tap(find.text(item).last);
  await t.pumpAndSettle();
}

void main() {
  group('reading the list', () {
    testWidgets('shows each country with its cities, lead counts and what is switched off', (t) async {
      await _open(t);
      expect(find.text('Countries & Cities'), findsOneWidget);
      expect(find.byKey(const Key('mk_country_c-ae')), findsOneWidget);
      expect(find.text('UAE'), findsOneWidget);
      expect(find.text('AE · +971 · AED  ·  5 leads'), findsOneWidget);
      expect(find.text('Dubai'), findsOneWidget);
      expect(find.text('Sharjah'), findsOneWidget);
      expect(find.text('  off'), findsOneWidget, reason: 'a switched-off city says so');
      expect(find.text('Switched off'), findsOneWidget, reason: 'a switched-off country says so');
      expect(find.text('No cities yet.'), findsOneWidget);
      expect(find.byKey(const Key('mk_summary')), findsOneWidget);
      expect(t.widget<Text>(find.byKey(const Key('mk_summary'))).data, '1 country · 1 city · 5 leads placed');
    });

    testWidgets('a manager gets the add and edit controls', (t) async {
      await _open(t);
      expect(find.byKey(const Key('mk_add_country')), findsOneWidget);
      expect(find.byKey(const Key('mk_add_city_c-ae')), findsOneWidget);
      expect(find.byKey(const Key('mk_country_menu_c-ae')), findsOneWidget);
    });

    testWidgets('anybody else only reads: no add, edit or remove controls', (t) async {
      await _open(t, canManage: false);
      expect(find.text('UAE'), findsOneWidget);
      expect(find.text('Dubai'), findsOneWidget);
      expect(find.byKey(const Key('mk_add_country')), findsNothing);
      expect(find.byKey(const Key('mk_add_city_c-ae')), findsNothing);
      expect(find.byKey(const Key('mk_country_menu_c-ae')), findsNothing);
      expect(find.byType(PopupMenuButton<String>), findsNothing);
    });

    testWidgets('fits a phone', (t) async {
      await _open(t, width: 390);
      expect(tester(t), isNull);
      expect(find.text('UAE'), findsOneWidget);
      expect(find.byKey(const Key('mk_add_country')), findsOneWidget);
    });
  });

  group('changing the list', () {
    testWidgets('adding a country sends what was typed and refreshes', (t) async {
      final api = await _open(t);
      await t.tap(find.byKey(const Key('mk_add_country')));
      await t.pumpAndSettle();
      await t.enterText(find.byKey(const Key('mk_f_name')), '  Oman ');
      await t.enterText(find.byKey(const Key('mk_f_code')), 'om');
      await t.enterText(find.byKey(const Key('mk_f_dialCode')), '+968');
      await t.enterText(find.byKey(const Key('mk_f_currency')), 'omr');
      final gets = api.requests.where((r) => r.method == 'GET').length;
      await t.tap(find.byKey(const Key('mk_save')));
      await t.pumpAndSettle();
      final post = api.changes.single;
      expect((post.method, post.path), ('POST', '/countries'));
      expect(post.data, {'name': 'Oman', 'code': 'om', 'dialCode': '+968', 'currency': 'omr'});
      expect(find.byKey(const Key('mk_save')), findsNothing, reason: 'the dialog closed');
      expect(api.requests.where((r) => r.method == 'GET').length, greaterThan(gets), reason: 'the list was fetched again');
    });

    testWidgets('a name that is too short is refused before anything is sent', (t) async {
      final api = await _open(t);
      await t.tap(find.byKey(const Key('mk_add_country')));
      await t.pumpAndSettle();
      await t.enterText(find.byKey(const Key('mk_f_name')), 'O');
      await t.tap(find.byKey(const Key('mk_save')));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('mk_error')), findsOneWidget);
      expect(api.changes, isEmpty);
      expect(find.byKey(const Key('mk_save')), findsOneWidget, reason: 'the dialog stays open');
    });

    testWidgets('a refusal from the server is shown in the dialog, which stays open', (t) async {
      final api = await _open(t);
      api.failStatus = 409;
      api.failMessage = 'Oman is already in the list.';
      await t.tap(find.byKey(const Key('mk_add_country')));
      await t.pumpAndSettle();
      await t.enterText(find.byKey(const Key('mk_f_name')), 'Oman');
      await t.tap(find.byKey(const Key('mk_save')));
      await t.pumpAndSettle();
      expect(find.text('Oman is already in the list.'), findsOneWidget);
      expect(find.byKey(const Key('mk_save')), findsOneWidget);
      // and it can be tried again
      api.failStatus = null;
      await t.tap(find.byKey(const Key('mk_save')));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('mk_save')), findsNothing);
    });

    testWidgets('adding a city goes to its country', (t) async {
      final api = await _open(t);
      await t.tap(find.byKey(const Key('mk_add_city_c-ae')));
      await t.pumpAndSettle();
      await t.enterText(find.byKey(const Key('mk_f_name')), 'Ajman');
      await t.enterText(find.byKey(const Key('mk_f_state')), 'Ajman');
      await t.tap(find.byKey(const Key('mk_save')));
      await t.pumpAndSettle();
      final post = api.changes.single;
      expect((post.method, post.path), ('POST', '/countries/c-ae/cities'));
      expect(post.data, {'name': 'Ajman', 'state': 'Ajman'});
    });

    testWidgets('editing a country starts from what it has and sends the change', (t) async {
      final api = await _open(t);
      await _menu(t, 'mk_country_menu_c-ae', 'Edit country');
      expect(t.widget<TextField>(find.byKey(const Key('mk_f_name'))).controller!.text, 'UAE');
      expect(t.widget<TextField>(find.byKey(const Key('mk_f_currency'))).controller!.text, 'AED');
      await t.enterText(find.byKey(const Key('mk_f_name')), 'United Arab Emirates');
      await t.tap(find.byKey(const Key('mk_save')));
      await t.pumpAndSettle();
      final put = api.changes.single;
      expect((put.method, put.path), ('PUT', '/countries/c-ae'));
      expect(put.data['name'], 'United Arab Emirates');
      expect(put.data.containsKey('status'), isFalse, reason: 'an edit never flips the on / off switch');
    });

    testWidgets('switching a country or city off (and on) sends its status with its own details', (t) async {
      final api = await _open(t);
      await _menu(t, 'mk_country_menu_c-ae', 'Switch off');
      var put = api.changes.last;
      expect((put.method, put.path), ('PUT', '/countries/c-ae'));
      expect((put.data['status'], put.data['name'], put.data['currency']), ('inactive', 'UAE', 'AED'));
      await _menu(t, 'mk_country_menu_c-my', 'Switch on');
      expect(api.changes.last.data['status'], 'active');
      await _menu(t, 'mk_city_k-shj', 'Switch on');
      put = api.changes.last;
      expect((put.method, put.path, put.data['status']), ('PUT', '/countries/cities/k-shj', 'active'));
    });

    testWidgets('removing asks first, then sends the delete; cancelling sends nothing', (t) async {
      final api = await _open(t);
      await _menu(t, 'mk_city_k-dxb', 'Remove');
      expect(find.text('Remove Dubai?'), findsOneWidget);
      await t.tap(find.text('Cancel'));
      await t.pumpAndSettle();
      expect(api.changes, isEmpty);
      await _menu(t, 'mk_city_k-dxb', 'Remove');
      await t.tap(find.byKey(const Key('mk_confirm')));
      await t.pumpAndSettle();
      final del = api.changes.single;
      expect((del.method, del.path), ('DELETE', '/countries/cities/k-dxb'));
    });

    testWidgets('a country that cannot be removed says why', (t) async {
      final api = await _open(t);
      api.failStatus = 409;
      api.failMessage = 'UAE still has 2 cities. Remove them first, or switch the country off.';
      await _menu(t, 'mk_country_menu_c-ae', 'Remove');
      await t.tap(find.byKey(const Key('mk_confirm')));
      await t.pumpAndSettle();
      expect(find.textContaining('still has 2 cities'), findsOneWidget);
    });
  });

  group('the menu', () {
    test('Countries & Cities is in the Marketing menu, once, at its own address', () {
      final hits = kMarketingNav.where((i) => i.route == '/marketing/markets').toList();
      expect(hits, hasLength(1));
      expect(hits.single.label, 'Countries & Cities');
    });
  });
}

// (kept as a function so a phone-width overflow shows up as a test error, not a silent yellow stripe)
Object? tester(WidgetTester t) => t.takeException();
