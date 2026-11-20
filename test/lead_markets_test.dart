import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:nizan_crm/core/models/auth_session.dart';
import 'package:nizan_crm/core/models/district.dart';
import 'package:nizan_crm/core/models/paginated_response.dart';
import 'package:nizan_crm/core/models/pincode_lookup.dart';
import 'package:nizan_crm/core/providers/auth_provider.dart';
import 'package:nizan_crm/core/theme/app_theme.dart';
import 'package:nizan_crm/features/marketing/data/campaign.dart';
import 'package:nizan_crm/features/marketing/data/market_models.dart';
import 'package:nizan_crm/features/marketing/services/campaign_service.dart';
import 'package:nizan_crm/features/marketing/services/market_service.dart';
import 'package:nizan_crm/features/sales/controllers/lead_controller.dart';
import 'package:nizan_crm/features/sales/data/lead.dart';
import 'package:nizan_crm/features/sales/presentation/screens/sales_leads_screen.dart';
import 'package:nizan_crm/providers/dio_provider.dart';
import 'package:nizan_crm/services/district_service.dart';
import 'package:nizan_crm/services/pincode_service.dart';
import 'package:nizan_crm/services/user_service.dart';

// A lead can be placed in a country and city (the marketing list) and carry a WhatsApp number, an e-mail, a budget in that country's
// currency, a language, who referred her and the creative she came from. Everything is optional: the form sends what is in its boxes,
// the server checks it. A lead with none of it is saved exactly as before.

const _markets = MarketList(
  canManage: false,
  countries: [
    MarketCountry(
      id: 'c-in',
      name: 'India',
      code: 'IN',
      dialCode: '+91',
      currency: 'INR',
      cities: [MarketCity(id: 'k-mum', name: 'Mumbai', state: 'Maharashtra'), MarketCity(id: 'k-cal', name: 'Calicut', state: 'Kerala')],
    ),
    MarketCountry(
      id: 'c-ae',
      name: 'UAE',
      code: 'AE',
      dialCode: '+971',
      currency: 'AED',
      cities: [MarketCity(id: 'k-dxb', name: 'Dubai'), MarketCity(id: 'k-auh', name: 'Abu Dhabi')],
    ),
    MarketCountry(id: 'c-my', name: 'Malaysia', code: 'MY', dialCode: '+60', currency: 'MYR', cities: [MarketCity(id: 'k-kl', name: 'Kuala Lumpur')]),
  ],
);

Map<String, dynamic> _json({Map<String, dynamic> extra = const {}}) => {
  '_id': 'L1',
  'name': 'Aisha',
  'phone': '9876543210',
  'source': 'Instagram',
  'location': 'Calicut',
  'status': 'New',
  'createdAt': '2026-10-01T05:00:00.000Z',
  'updatedAt': '2026-10-01T05:00:00.000Z',
  ...extra,
};

class _Capture implements HttpClientAdapter {
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode({'_id': 'NEW1'}),
      options.method == 'POST' ? 201 : 200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}

  Map<String, dynamic> get saved => Map<String, dynamic>.from(
    requests.lastWhere((r) => r.path.startsWith('/leads') && (r.method == 'POST' || r.method == 'PUT')).data as Map,
  );
}

Widget _app(_Capture cap, {List<Lead> leads = const []}) => ProviderScope(
  overrides: <Override>[
    dioProvider.overrideWithValue(Dio(BaseOptions(baseUrl: 'http://x/api'))..httpClientAdapter = cap),
    authSessionProvider.overrideWithValue(const AuthSession(token: 't', userId: 'u', name: 'Boss', email: 'b@x', role: 'admin')),
    paginatedLeadsProvider.overrideWith(
      (ref, f) async => PaginatedResponse<Lead>(items: leads, totalItems: leads.length, totalPages: 1, page: 1, limit: 20),
    ),
    leadClustersProvider.overrideWith((ref) async => []),
    crmUsersProvider.overrideWith((ref) async => []),
    campaignOptionsProvider.overrideWith((ref) async => <CampaignOption>[]),
    districtsProvider.overrideWith((ref) async => <District>[]),
    pincodeLookupProvider.overrideWith((ref, code) async => PincodeLookup.fromJson({'code': code, 'found': false, 'source': 'none'})),
    marketsProvider.overrideWith((ref) async => _markets),
  ],
  child: MaterialApp(theme: AppTheme.lightTheme, home: const Scaffold(body: SalesLeadsScreen())),
);

Future<void> _open(WidgetTester t, Widget app) async {
  t.view.physicalSize = const Size(1500, 3200);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(app);
  await t.pumpAndSettle();
}

Finder _dd(String label) => find.byWidgetPredicate((w) => w is DropdownButtonFormField && w.decoration.labelText == label);

/// What a dropdown shows now ('Not set' when none).
String _shown(WidgetTester t, String label) =>
    t.widgetList<Text>(find.descendant(of: _dd(label).first, matching: find.byType(Text))).first.data ?? '';

Future<void> _pick(WidgetTester t, String label, String option) async {
  await t.ensureVisible(_dd(label).first);
  await t.tap(_dd(label).first);
  await t.pumpAndSettle();
  await t.tap(find.text(option).last);
  await t.pumpAndSettle();
}

Future<void> _type(WidgetTester t, String key, String value) async {
  final f = find.byKey(Key(key));
  await t.ensureVisible(f);
  await t.enterText(f, value);
  await t.pump();
}

Future<void> _fillAndSave(WidgetTester t) async {
  await t.enterText(find.widgetWithText(TextFormField, 'Name *').first, 'Aisha');
  await t.enterText(find.widgetWithText(TextFormField, 'Phone Number *').first, '9876543210');
  await t.pump();
  final save = find.text('Save Lead');
  await t.ensureVisible(save.first);
  await t.tap(save.first);
  await t.pumpAndSettle();
}

void main() {
  group('the models', () {
    test('a currency is written with its sign; no currency means rupees', () {
      expect(currencySign('INR'), '₹');
      expect(currencySign(''), '₹');
      expect(currencySign('aed'), 'AED ');
      expect(currencySign('MYR'), 'RM ');
      expect(currencySign('USD'), r'$');
      expect(currencySign('OMR'), 'OMR ');
    });

    test('the list is read with who may change it', () {
      final l = MarketList.fromJson({
        'canManage': true,
        'countries': [
          {
            'id': 'c1',
            'name': 'UAE',
            'code': 'AE',
            'dialCode': '+971',
            'currency': 'AED',
            'status': 'active',
            'leads': 4,
            'cities': [
              {'id': 'k1', 'name': 'Dubai', 'state': '', 'status': 'active', 'leads': 3},
            ],
          },
        ],
      });
      expect(l.canManage, isTrue);
      expect(l.countries.single.detail, 'AE · +971 · AED');
      expect((l.countries.single.leads, l.countries.single.cities.single.leads), (4, 3));
      expect(l.countryOfCity('k1')?.name, 'UAE');
      expect(l.city('k1')?.name, 'Dubai');
      expect(l.country('c1')?.name, 'UAE');
    });

    test('nothing, or nonsense, is an empty list that nobody can change', () {
      for (final bad in [null, 'x', 5, <String, dynamic>{}, {'countries': null}]) {
        final l = MarketList.fromJson(bad);
        expect(l.countries, isEmpty, reason: '$bad');
        expect(l.canManage, isFalse, reason: '$bad');
      }
      expect(_markets.country(null), isNull);
      expect(_markets.city(''), isNull);
      expect(_markets.countryOfCity('nope'), isNull);
    });

    test('a lead reads its market and marketing details; an older lead has none', () {
      final l = Lead.fromJson(_json(extra: {
        'countryId': 'c-ae',
        'country': 'UAE',
        'cityId': {'_id': 'k-dxb', 'name': 'Dubai'},
        'city': 'Dubai',
        'whatsapp': '+971501234567',
        'email': 'a@b.co',
        'budget': 120000,
        'budgetCurrency': 'AED',
        'language': 'Malayalam',
        'referralPartner': 'Aysha Weddings',
        'creative': 'Reel #17',
      }));
      expect((l.countryId, l.country, l.cityId, l.city), ('c-ae', 'UAE', 'k-dxb', 'Dubai'));
      expect((l.whatsapp, l.email, l.budget, l.budgetCurrency), ('+971501234567', 'a@b.co', 120000.0, 'AED'));
      expect((l.language, l.referralPartner, l.creative), ('Malayalam', 'Aysha Weddings', 'Reel #17'));
      final old = Lead.fromJson(_json());
      expect((old.countryId, old.country, old.cityId, old.city, old.whatsapp, old.budget, old.language, old.referralPartner, old.creative), ('', '', '', '', '', null, '', '', ''));
      expect(Lead.fromJson(_json(extra: {'budget': null, 'cityId': null})).budget, isNull);
    });

    test('copyWith keeps the marketing details', () {
      final l = Lead.fromJson(_json(extra: {'countryId': 'c-ae', 'country': 'UAE', 'budget': 5000.5, 'creative': 'Reel #17'}));
      final c = l.copyWith(status: 'Contacted');
      expect((c.countryId, c.country, c.budget, c.creative), ('c-ae', 'UAE', 5000.5, 'Reel #17'));
    });
  });

  group('the Add Lead form', () {
    testWidgets('has the marketing boxes', (t) async {
      await _open(t, _app(_Capture()));
      for (final label in ['Country', 'City']) {
        expect(_dd(label), findsWidgets, reason: label);
      }
      for (final key in ['lead_whatsapp', 'lead_email', 'lead_budget', 'lead_language', 'lead_referral', 'lead_creative']) {
        expect(find.byKey(Key(key)), findsOneWidget, reason: key);
      }
      expect(_shown(t, 'Country'), 'Not set');
      expect(_shown(t, 'City'), 'Not set');
    });

    testWidgets('a country narrows the cities, and the budget is written in its currency', (t) async {
      await _open(t, _app(_Capture()));
      expect(find.widgetWithText(TextFormField, 'Budget (₹)'), findsOneWidget, reason: 'no country yet: rupees');
      await _pick(t, 'Country', 'UAE');
      expect(_shown(t, 'Country'), 'UAE');
      expect(find.widgetWithText(TextFormField, 'Budget (AED)'), findsOneWidget);
      await t.ensureVisible(_dd('City').first);
      await t.tap(_dd('City').first);
      await t.pumpAndSettle();
      expect(find.text('Dubai'), findsWidgets);
      expect(find.text('Abu Dhabi'), findsWidgets);
      expect(find.text('Mumbai'), findsNothing);
      expect(find.text('Mumbai (India)'), findsNothing);
    });

    testWidgets('with no country, every city is offered with its country, and picking one brings the country', (t) async {
      await _open(t, _app(_Capture()));
      await _pick(t, 'City', 'Mumbai (India)');
      expect(_shown(t, 'City'), 'Mumbai');
      expect(_shown(t, 'Country'), 'India');
    });

    testWidgets('changing the country drops a city that is not in it', (t) async {
      await _open(t, _app(_Capture()));
      await _pick(t, 'Country', 'UAE');
      await _pick(t, 'City', 'Dubai');
      expect(_shown(t, 'City'), 'Dubai');
      await _pick(t, 'Country', 'Malaysia');
      expect(_shown(t, 'Country'), 'Malaysia');
      expect(_shown(t, 'City'), 'Not set');
    });

    testWidgets('a city left behind by a country change is not sent either (the server would refuse the pair)', (t) async {
      final cap = _Capture();
      await _open(t, _app(cap));
      await _pick(t, 'Country', 'UAE');
      await _pick(t, 'City', 'Dubai');
      await _pick(t, 'Country', 'Malaysia');
      await _fillAndSave(t);
      expect((cap.saved['countryId'], cap.saved['cityId']), ('c-my', null));
    });

    testWidgets('the save carries every detail', (t) async {
      final cap = _Capture();
      await _open(t, _app(cap));
      await _pick(t, 'Country', 'UAE');
      await _pick(t, 'City', 'Dubai');
      await _type(t, 'lead_whatsapp', ' +971 50 123 4567 ');
      await _type(t, 'lead_email', 'bride@example.com');
      await _type(t, 'lead_budget', '1,20,000');
      await _type(t, 'lead_language', 'Malayalam');
      await _type(t, 'lead_referral', 'Aysha Weddings');
      await _type(t, 'lead_creative', 'Reel #17');
      await _fillAndSave(t);
      final s = cap.saved;
      expect((s['countryId'], s['cityId']), ('c-ae', 'k-dxb'));
      expect((s['whatsapp'], s['email']), ('+971 50 123 4567', 'bride@example.com'));
      expect((s['budget'], s['budgetCurrency']), ('120000', 'AED'));
      expect((s['language'], s['referralPartner'], s['creative']), ('Malayalam', 'Aysha Weddings', 'Reel #17'));
    });

    testWidgets('a lead with none of it sends them empty — never a made-up value, never a currency without a budget', (t) async {
      final cap = _Capture();
      await _open(t, _app(cap));
      await _fillAndSave(t);
      final s = cap.saved;
      expect((s['countryId'], s['cityId'], s['budget']), (null, null, null));
      expect((s['whatsapp'], s['email'], s['language'], s['referralPartner'], s['creative']), ('', '', '', '', ''));
      expect(s.containsKey('budgetCurrency'), isFalse);
    });

    testWidgets('a budget in a country with no currency set sends no currency (the server decides)', (t) async {
      final cap = _Capture();
      await _open(t, _app(cap));
      await _type(t, 'lead_budget', '50000');
      await _fillAndSave(t);
      expect(cap.saved['budget'], '50000');
      expect(cap.saved.containsKey('budgetCurrency'), isFalse);
    });

    testWidgets('the budget box takes only digits, commas and a point', (t) async {
      await _open(t, _app(_Capture()));
      await _type(t, 'lead_budget', 'abc1,2x.5');
      expect(t.widget<TextFormField>(find.byKey(const Key('lead_budget'))).controller!.text, '1,2.5');
    });

    testWidgets('after a lead is added the marketing boxes are cleared', (t) async {
      await _open(t, _app(_Capture()));
      await _pick(t, 'Country', 'UAE');
      await _pick(t, 'City', 'Dubai');
      await _type(t, 'lead_whatsapp', '+971501234567');
      await _type(t, 'lead_budget', '9000');
      await _type(t, 'lead_creative', 'Reel #17');
      await _fillAndSave(t);
      expect(_shown(t, 'Country'), 'Not set');
      expect(_shown(t, 'City'), 'Not set');
      for (final key in ['lead_whatsapp', 'lead_budget', 'lead_creative']) {
        expect(t.widget<TextFormField>(find.byKey(Key(key))).controller!.text, '', reason: key);
      }
    });
  });

  group('a lead that has them', () {
    Lead placed() => Lead.fromJson(_json(extra: {
      'countryId': 'c-ae',
      'country': 'UAE',
      'cityId': 'k-dxb',
      'city': 'Dubai',
      'whatsapp': '+971501234567',
      'email': 'a@b.co',
      'budget': 120000,
      'budgetCurrency': 'AED',
      'language': 'Malayalam',
      'referralPartner': 'Aysha Weddings',
      'creative': 'Reel #17',
    }));

    testWidgets('shows them on its card, and only the ones filled in', (t) async {
      await _open(t, _app(_Capture(), leads: [placed()]));
      for (final text in ['Dubai, UAE', '+971501234567', 'a@b.co', 'AED 1,20,000', 'Malayalam', 'Aysha Weddings', 'Reel #17']) {
        expect(find.text(text), findsWidgets, reason: text);
      }
      await t.pumpWidget(const SizedBox());
      await _open(t, _app(_Capture(), leads: [Lead.fromJson(_json())]));
      for (final label in ['Market', 'WhatsApp', 'Budget', 'Language', 'Referred by', 'Creative']) {
        expect(find.text(label), findsNothing, reason: label);
      }
    });

    testWidgets('keeps its place in the edit form and sends it back unchanged', (t) async {
      final cap = _Capture();
      await _open(t, _app(cap, leads: [placed()]));
      await t.tap(find.byTooltip('Edit').first);
      await t.pumpAndSettle();
      final inDialog = find.byType(Dialog);
      final country = find.descendant(of: inDialog, matching: _dd('Country'));
      final city = find.descendant(of: inDialog, matching: _dd('City'));
      String shown(Finder f) => t.widgetList<Text>(find.descendant(of: f.first, matching: find.byType(Text))).first.data ?? '';
      expect((shown(country), shown(city)), ('UAE', 'Dubai'));
      expect(t.widget<TextFormField>(find.descendant(of: inDialog, matching: find.byKey(const Key('lead_budget')))).controller!.text, '120000');
      final save = find.descendant(of: inDialog, matching: find.text('Update Lead'));
      await t.ensureVisible(save.first);
      await t.tap(save.first);
      await t.pumpAndSettle();
      final s = cap.saved;
      expect((s['countryId'], s['cityId'], s['budget'], s['budgetCurrency']), ('c-ae', 'k-dxb', '120000', 'AED'));
      expect((s['whatsapp'], s['creative']), ('+971501234567', 'Reel #17'));
    });
  });
}
