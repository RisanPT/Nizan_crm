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
import 'package:nizan_crm/features/marketing/services/campaign_service.dart';
import 'package:nizan_crm/features/sales/controllers/lead_controller.dart';
import 'package:nizan_crm/features/sales/data/lead.dart';
import 'package:nizan_crm/features/sales/presentation/screens/sales_leads_screen.dart';
import 'package:nizan_crm/features/sales/utils/lead_pincode.dart';
import 'package:nizan_crm/providers/dio_provider.dart';
import 'package:nizan_crm/services/district_service.dart';
import 'package:nizan_crm/services/pincode_service.dart';
import 'package:nizan_crm/services/user_service.dart';

// A lead can carry an optional pincode and district: the form says where the pincode is, fills the
// district in from our pincode list, and sends only what the user changed.

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

Map<String, dynamic> _place(String id, String name) => {'id': id, 'name': name};

PincodeLookup _listed(String code) => PincodeLookup.fromJson({
  'code': code,
  'found': true,
  'source': 'master',
  'active': true,
  'district': _place('d1', 'Kozhikode'),
  'region': _place('r1', 'Calicut'),
  'state': _place('s1', 'Kerala'),
  'zone': _place('z1', 'South'),
});

PincodeLookup _mapOnly(String code) => PincodeLookup.fromJson({
  'code': code,
  'found': true,
  'source': 'geocode',
  'active': true,
  'district': _place('d2', 'Wayanad'),
  'region': _place('r1', 'Calicut'),
  'state': _place('s1', 'Kerala'),
  'zone': _place('z1', 'South'),
  'area': 'Kalpetta',
});

PincodeLookup _unknown(String code) =>
    PincodeLookup.fromJson({'code': code, 'found': false, 'source': 'none'});

const _districts = [
  District(
    id: 'd1',
    name: 'Kozhikode',
    regionId: 'r1',
    regionName: 'Calicut',
    status: 'active',
  ),
  District(
    id: 'd2',
    name: 'Wayanad',
    regionId: 'r1',
    regionName: 'Calicut',
    status: 'active',
  ),
  District(
    id: 'd3',
    name: 'Ernakulam',
    regionId: 'r2',
    regionName: 'Kochi',
    status: 'active',
  ),
];

class _Capture implements HttpClientAdapter {
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
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

  /// The body of the last save (POST /leads or PUT /leads/:id).
  Map<String, dynamic> get saved => Map<String, dynamic>.from(
    requests
            .lastWhere(
              (r) =>
                  r.path.startsWith('/leads') &&
                  (r.method == 'POST' || r.method == 'PUT'),
            )
            .data
        as Map,
  );
}

Widget _app(_Capture cap, {List<Lead> leads = const [], List<String>? asked}) =>
    ProviderScope(
      overrides: <Override>[
        dioProvider.overrideWithValue(
          Dio(BaseOptions(baseUrl: 'http://x/api'))..httpClientAdapter = cap,
        ),
        authSessionProvider.overrideWithValue(
          const AuthSession(
            token: 't',
            userId: 'u',
            name: 'Boss',
            email: 'b@x',
            role: 'admin',
          ),
        ),
        paginatedLeadsProvider.overrideWith(
          (ref, f) async => PaginatedResponse<Lead>(
            items: leads,
            totalItems: leads.length,
            totalPages: 1,
            page: 1,
            limit: 20,
          ),
        ),
        leadClustersProvider.overrideWith((ref) async => []),
        crmUsersProvider.overrideWith((ref) async => []),
        campaignOptionsProvider.overrideWith((ref) async => <CampaignOption>[]),
        districtsProvider.overrideWith((ref) async => _districts),
        pincodeLookupProvider.overrideWith((ref, code) async {
          asked?.add(code);
          return switch (code) {
            '673001' || '673002' => _listed(code),
            '673577' => _mapOnly(code),
            _ => _unknown(code),
          };
        }),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: const Scaffold(body: SalesLeadsScreen()),
      ),
    );

Future<void> _open(WidgetTester t, Widget app) async {
  t.view.physicalSize = const Size(1500, 2600);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(app);
  await t.pumpAndSettle();
}

final _pincode = find.widgetWithText(TextFormField, 'Pincode');
final _district = find.byWidgetPredicate(
  (w) => w is DropdownButtonFormField && w.decoration.labelText == 'District',
);

Future<void> _typePin(WidgetTester t, String v) async {
  await t.ensureVisible(_pincode.first);
  await t.enterText(_pincode.first, v);
  await t.pump(const Duration(milliseconds: 450));
  await t.pump();
  await t.pump();
}

/// The district the dropdown is showing ('Not set' when none).
String _shownDistrict(WidgetTester t) =>
    t
        .widgetList<Text>(
          find.descendant(of: _district.first, matching: find.byType(Text)),
        )
        .first
        .data ??
    '';

Future<void> _fillAndSave(
  WidgetTester t, {
  String name = 'Aisha',
  String phone = '9876543210',
}) async {
  await t.enterText(find.widgetWithText(TextFormField, 'Name *').first, name);
  await t.enterText(
    find.widgetWithText(TextFormField, 'Phone Number *').first,
    phone,
  );
  await t.pump();
  final save = find.text('Save Lead');
  await t.ensureVisible(save.first);
  await t.tap(save.first);
  await t.pumpAndSettle();
}

void main() {
  group('a pincode written in pasted text', () {
    test('is found in an address', () {
      expect(pincodeIn('Beach Road, Calicut 673001'), '673001');
      expect(pincodeIn('Calicut - 673 001'), '673001');
      expect(pincodeIn('673001'), '673001');
      expect(pincodeIn('Feroke, Kozhikode, Kerala, 673631.'), '673631');
    });

    test(
      'is not taken from a phone number, a date, or an amount of other digits',
      () {
        expect(pincodeIn('+91 98765 43210'), isNull);
        expect(pincodeIn('9876543210'), isNull);
        expect(pincodeIn('Date: 12/10/2026'), isNull);
        expect(pincodeIn('Calicut'), isNull);
        expect(
          pincodeIn('1234567'),
          isNull,
          reason: 'seven digits is not a pincode',
        );
        expect(
          pincodeIn('012345'),
          isNull,
          reason: 'a pincode never starts with 0',
        );
        expect(pincodeIn(''), isNull);
      },
    );

    test('a "Pincode: …" label is told from other words', () {
      for (final k in [
        'pincode',
        'Pin code',
        'PIN',
        'zip',
        'Postal Code',
        'pin-code',
      ]) {
        expect(isPincodeLabel(k), isTrue, reason: k);
      }
      for (final k in [
        'pinterest',
        'mapping',
        'phone',
        'location',
        'spin',
        '',
      ]) {
        expect(isPincodeLabel(k), isFalse, reason: k);
      }
    });
  });

  group('the Lead model', () {
    test('reads the pincode, the district and the region', () {
      final l = Lead.fromJson(
        _json(
          extra: {
            'pincode': '673001',
            'districtId': 'd1',
            'regionId': 'r1',
            'district': 'Kozhikode',
            'region': 'Calicut',
          },
        ),
      );
      expect(
        (l.pincode, l.districtId, l.regionId, l.district, l.region),
        ('673001', 'd1', 'r1', 'Kozhikode', 'Calicut'),
      );
    });

    test(
      'a populated { _id } district is read too, and an older lead has none',
      () {
        expect(
          Lead.fromJson(
            _json(
              extra: {
                'districtId': {'_id': 'd9', 'name': 'X'},
              },
            ),
          ).districtId,
          'd9',
        );
        final old = Lead.fromJson(_json());
        expect(
          (old.pincode, old.districtId, old.regionId, old.district),
          ('', '', '', ''),
        );
        expect(
          Lead.fromJson(_json(extra: {'districtId': null})).districtId,
          '',
        );
      },
    );

    test('copyWith keeps the geography unless it is changed', () {
      final l = Lead.fromJson(
        _json(
          extra: {
            'pincode': '673001',
            'districtId': 'd1',
            'regionId': 'r1',
            'district': 'Kozhikode',
            'region': 'Calicut',
            'address': 'Beach Rd',
          },
        ),
      );
      final c = l.copyWith(status: 'Contacted');
      expect(
        (c.pincode, c.districtId, c.regionId, c.district, c.region, c.address),
        ('673001', 'd1', 'r1', 'Kozhikode', 'Calicut', 'Beach Rd'),
      );
      expect(l.copyWith(pincode: '682001', districtId: 'd3').pincode, '682001');
    });
  });

  group('the Add Lead form', () {
    testWidgets('has an optional Pincode box and District box', (t) async {
      await _open(t, _app(_Capture()));
      expect(_pincode, findsOneWidget);
      expect(_district, findsOneWidget);
      expect(_shownDistrict(t), 'Not set');
    });

    testWidgets(
      'a pincode in our list says where it is and fills the district in',
      (t) async {
        final asked = <String>[];
        await _open(t, _app(_Capture(), asked: asked));
        await _typePin(t, '673001');
        expect(asked, ['673001']);
        expect(find.text('Kozhikode · Calicut · Kerala'), findsOneWidget);
        expect(_shownDistrict(t), 'Kozhikode (Calicut)');
      },
    );

    testWidgets(
      'saving sends the pincode and the district — and nothing about a region (the server works it out)',
      (t) async {
        final cap = _Capture();
        await _open(t, _app(cap));
        await _typePin(t, '673001');
        await _fillAndSave(t);
        final body = cap.saved;
        expect((body['pincode'], body['districtId']), ('673001', 'd1'));
        expect(body.containsKey('regionId'), isFalse);
        expect(body.containsKey('region'), isFalse);
        expect(body.containsKey('district'), isFalse);
      },
    );

    testWidgets(
      'a lead saved with neither sends neither (an empty form behaves as before)',
      (t) async {
        final cap = _Capture();
        await _open(t, _app(cap));
        await _fillAndSave(t);
        expect(cap.saved.containsKey('pincode'), isFalse);
        expect(cap.saved.containsKey('districtId'), isFalse);
        expect(cap.saved['location'], '');
      },
    );

    testWidgets('choosing a district yourself wins over the pincode\'s', (
      t,
    ) async {
      final cap = _Capture();
      await _open(t, _app(cap));
      await t.ensureVisible(_district);
      await t.tap(_district);
      await t.pumpAndSettle();
      await t.tap(find.text('Ernakulam (Kochi)').last);
      await t.pumpAndSettle();
      await _typePin(t, '673001');
      expect(
        _shownDistrict(t),
        'Ernakulam (Kochi)',
        reason: 'the pincode must not overwrite their choice',
      );
      await _fillAndSave(t);
      expect((cap.saved['pincode'], cap.saved['districtId']), ('673001', 'd3'));
    });

    testWidgets('changing the pincode takes back a district it filled in', (
      t,
    ) async {
      await _open(t, _app(_Capture()));
      await _typePin(t, '673001');
      expect(_shownDistrict(t), 'Kozhikode (Calicut)');
      await _typePin(t, '67300');
      expect(_shownDistrict(t), 'Not set');
    });

    testWidgets('…and moves to the new pincode\'s district', (t) async {
      await _open(t, _app(_Capture()));
      await _typePin(t, '673001');
      await _typePin(t, '67300');
      await _typePin(t, '673002');
      expect(_shownDistrict(t), 'Kozhikode (Calicut)');
    });

    testWidgets('but never takes back a district they picked', (t) async {
      await _open(t, _app(_Capture()));
      await t.ensureVisible(_district);
      await t.tap(_district);
      await t.pumpAndSettle();
      await t.tap(find.text('Ernakulam (Kochi)').last);
      await t.pumpAndSettle();
      await _typePin(t, '673001');
      await _typePin(t, '');
      expect(_shownDistrict(t), 'Ernakulam (Kochi)');
    });

    testWidgets(
      'a pincode only the map could place is a suggestion: not filled in until accepted',
      (t) async {
        final cap = _Capture();
        await _open(t, _app(cap));
        await _typePin(t, '673577');
        expect(_shownDistrict(t), 'Not set');
        expect(
          find.byKey(const Key('leadUseSuggestedDistrict')),
          findsOneWidget,
        );
        await t.tap(find.byKey(const Key('leadUseSuggestedDistrict')));
        await t.pumpAndSettle();
        expect(_shownDistrict(t), 'Wayanad (Calicut)');
        expect(find.byKey(const Key('leadUseSuggestedDistrict')), findsNothing);
        await _fillAndSave(t);
        expect(
          (cap.saved['pincode'], cap.saved['districtId']),
          ('673577', 'd2'),
        );
      },
    );

    testWidgets(
      'an unknown pincode is kept with no district, and does not stop the save',
      (t) async {
        final cap = _Capture();
        await _open(t, _app(cap));
        await _typePin(t, '560001');
        expect(_shownDistrict(t), 'Not set');
        await _fillAndSave(t);
        expect(
          (cap.saved['pincode'], cap.saved['districtId']),
          ('560001', null),
        );
      },
    );

    testWidgets('a half-typed pincode is not saved: the user is told', (
      t,
    ) async {
      final cap = _Capture();
      await _open(t, _app(cap));
      await t.ensureVisible(_pincode.first);
      await t.enterText(_pincode.first, '6730');
      await _fillAndSave(t);
      expect(
        find.text('Enter a 6-digit pincode, or leave it empty.'),
        findsOneWidget,
      );
      expect(
        cap.requests.where(
          (r) => r.method == 'POST' && r.path.startsWith('/leads'),
        ),
        isEmpty,
      );
    });

    testWidgets(
      'after a lead is added the form is cleared, pincode and district included',
      (t) async {
        await _open(t, _app(_Capture()));
        await _typePin(t, '673001');
        await _fillAndSave(t);
        expect(t.widget<TextFormField>(_pincode.first).controller!.text, '');
        expect(_shownDistrict(t), 'Not set');
      },
    );
  });

  group('Smart Paste', () {
    /// Puts [text] on the (pretend) clipboard, taps Smart Paste.
    Future<void> paste(WidgetTester t, String text) async {
      t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.getData') return {'text': text};
          return null;
        },
      );
      addTearDown(
        () => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      final button = find.text('Smart Paste');
      await t.ensureVisible(button.first);
      await t.tap(button.first);
      await t.pump();
      await t.pump(const Duration(milliseconds: 450));
      await t.pump();
      await t.pump();
    }

    String pinText(WidgetTester t) =>
        t.widget<TextFormField>(_pincode.first).controller!.text;

    testWidgets(
      'a "Pincode:" line fills the pincode, which then fills the district',
      (t) async {
        await _open(t, _app(_Capture()));
        await paste(
          t,
          'Name: Aisha\nPhone: 9876543210\nLocation: Calicut\nPincode: 673001',
        );
        expect(pinText(t), '673001');
        expect(_shownDistrict(t), 'Kozhikode (Calicut)');
      },
    );

    testWidgets('a pincode at the end of the address is picked up too', (
      t,
    ) async {
      await _open(t, _app(_Capture()));
      await paste(
        t,
        'Name: Aisha\nPhone: 9876543210\nAddress: Beach Road, Calicut 673 002',
      );
      expect(pinText(t), '673002');
    });

    testWidgets('a phone number is never mistaken for a pincode', (t) async {
      await _open(t, _app(_Capture()));
      await paste(t, 'Name: Aisha\nPhone: +91 98765 43210\nLocation: Calicut');
      expect(pinText(t), '');
    });
  });

  group('editing a lead', () {
    Lead withGeo() => Lead.fromJson(
      _json(
        extra: {
          'pincode': '673001',
          'districtId': 'd1',
          'regionId': 'r1',
          'district': 'Kozhikode',
          'region': 'Calicut',
        },
      ),
    );

    // the edit dialog sits over the page, which has its own Add card — look only inside the dialog
    final inDialog = find.byType(Dialog);
    final dPin = find.descendant(of: inDialog, matching: _pincode);
    final dDistrict = find.descendant(of: inDialog, matching: _district);

    Future<void> openEdit(WidgetTester t, _Capture cap, Lead lead) async {
      await _open(t, _app(cap, leads: [lead]));
      await t.tap(find.byTooltip('Edit').first);
      await t.pumpAndSettle();
    }

    testWidgets('the lead\'s details show its area', (t) async {
      await _open(t, _app(_Capture(), leads: [withGeo()]));
      expect(find.text('673001 · Kozhikode · Calicut'), findsWidgets);
    });

    testWidgets('an untouched pincode and district are not sent again', (
      t,
    ) async {
      final cap = _Capture();
      await openEdit(t, cap, withGeo());
      expect(t.widget<TextFormField>(dPin).controller!.text, '673001');
      expect(
        t
            .widgetList<Text>(
              find.descendant(of: dDistrict, matching: find.byType(Text)),
            )
            .first
            .data,
        'Kozhikode (Calicut)',
      );
      final save = find.descendant(
        of: inDialog,
        matching: find.text('Update Lead'),
      );
      await t.ensureVisible(save.first);
      await t.tap(save.first);
      await t.pumpAndSettle();
      expect(cap.saved.containsKey('pincode'), isFalse);
      expect(cap.saved.containsKey('districtId'), isFalse);
    });

    testWidgets(
      'changing the pincode sends the new pincode with its district',
      (t) async {
        final cap = _Capture();
        await openEdit(t, cap, withGeo());
        await t.ensureVisible(dPin);
        await t.enterText(dPin, '673002');
        await t.pump(const Duration(milliseconds: 450));
        await t.pump();
        final save = find.descendant(
          of: inDialog,
          matching: find.text('Update Lead'),
        );
        await t.ensureVisible(save.first);
        await t.tap(save.first);
        await t.pumpAndSettle();
        expect(
          (cap.saved['pincode'], cap.saved['districtId']),
          ('673002', 'd1'),
        );
      },
    );

    testWidgets(
      'a lead that belongs to a booking has no pincode / district to edit (the booking\'s are used)',
      (t) async {
        final cap = _Capture();
        final linked = Lead.fromJson(
          _json(
            extra: {
              'bookingId': 'B1',
              'status': 'Converted',
              'pincode': '673001',
              'districtId': 'd1',
              'district': 'Kozhikode',
              'region': 'Calicut',
            },
          ),
        );
        await openEdit(t, cap, linked);
        expect(dPin, findsNothing);
        expect(dDistrict, findsNothing);
        final save = find.descendant(
          of: inDialog,
          matching: find.text('Update Lead'),
        );
        await t.ensureVisible(save.first);
        await t.tap(save.first);
        await t.pumpAndSettle();
        expect(cap.saved.containsKey('pincode'), isFalse);
        expect(cap.saved.containsKey('districtId'), isFalse);
      },
    );

    testWidgets(
      'an older lead with odd pincode text can still be saved untouched',
      (t) async {
        final cap = _Capture();
        await openEdit(t, cap, Lead.fromJson(_json(extra: {'pincode': 'N/A'})));
        final save = find.descendant(
          of: inDialog,
          matching: find.text('Update Lead'),
        );
        await t.ensureVisible(save.first);
        await t.tap(save.first);
        await t.pumpAndSettle();
        expect(cap.saved.containsKey('pincode'), isFalse);
        expect(
          find.text('Enter a 6-digit pincode, or leave it empty.'),
          findsNothing,
        );
      },
    );
  });
}
