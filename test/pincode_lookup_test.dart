import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/models/pincode_lookup.dart';
import 'package:nizan_crm/core/theme/app_theme.dart';
import 'package:nizan_crm/core/widgets/pincode_field.dart';
import 'package:nizan_crm/services/pincode_service.dart';

// The shared pincode field: it says where a pincode is (from our pincode list, else the map as a
// suggestion), and never stops anyone saving over a pincode we don't know.

Map<String, dynamic> _place(String id, String name) => {'id': id, 'name': name};

Map<String, dynamic> _master({
  String code = '673001',
  bool active = true,
  String area = '',
}) => {
  'code': code,
  'valid': true,
  'found': true,
  'source': 'master',
  'active': active,
  'district': _place('d1', 'Kozhikode'),
  'region': _place('r1', 'Calicut'),
  'state': _place('s1', 'Kerala'),
  'zone': _place('z1', 'South'),
  'area': area,
  'lat': area.isEmpty ? null : 11.25,
  'lng': area.isEmpty ? null : 75.78,
};

Map<String, dynamic> _suggested({String code = '673999'}) => {
  ..._master(code: code, area: 'Elathur'),
  'source': 'geocode',
};

Map<String, dynamic> _unknown({String code = '999999', String area = ''}) => {
  'code': code,
  'valid': true,
  'found': false,
  'source': 'none',
  'active': true,
  'district': null,
  'region': null,
  'state': null,
  'zone': null,
  'area': area,
  'lat': null,
  'lng': null,
};

class _Capture implements HttpClientAdapter {
  RequestOptions? last;
  final Object body;
  final int status;
  _Capture(this.body, {this.status = 200});

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    last = options;
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// A pretend server: what it knows per pincode, and every pincode it was asked about.
class _Server {
  final asked = <String>[];
  final Map<String, Map<String, dynamic>> known = {
    '673001': _master(),
    '673002': _master(code: '673002', area: 'Mavoor Road'),
    '673003': _master(code: '673003', active: false),
    '673999': _suggested(),
    '686001': _unknown(code: '686001', area: 'Kottayam'),
    '999999': _unknown(),
  };

  /// Hold an answer back (or throw) per pincode.
  final gates = <String, Future<void> Function()>{};

  Future<PincodeLookup> lookup(String code) async {
    asked.add(code);
    await gates[code]?.call();
    return PincodeLookup.fromJson(known[code] ?? _unknown(code: code));
  }
}

Widget _host(
  _Server server,
  TextEditingController ctrl, {
  bool required = false,
  bool strict = true,
  ValueChanged<PincodeLookup?>? onResolved,
  Widget? Function(BuildContext, PincodeLookup)? actionBuilder,
  GlobalKey<FormState>? formKey,
}) => ProviderScope(
  overrides: <Override>[
    pincodeLookupProvider.overrideWith((ref, code) => server.lookup(code)),
  ],
  child: MaterialApp(
    theme: AppTheme.lightTheme,
    home: Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: formKey,
          child: PincodeField(
            controller: ctrl,
            decoration: const InputDecoration(labelText: 'Pincode'),
            required: required,
            strict: strict,
            onResolved: onResolved,
            actionBuilder: actionBuilder,
          ),
        ),
      ),
    ),
  ),
);

final _box = find.byType(TextFormField);

/// Types into the box, then waits out the pause before the lookup.
Future<void> _type(WidgetTester t, String text, {bool settle = true}) async {
  await t.enterText(_box, text);
  await t.pump();
  if (settle) {
    await t.pump(const Duration(milliseconds: 450));
    await t.pump();
  }
}

String _shown(WidgetTester t, String key) => t
    .widget<Text>(
      find
          .descendant(of: find.byKey(Key(key)), matching: find.byType(Text))
          .first,
    )
    .data!;

void main() {
  group('parsing', () {
    test('a pincode that is in our list, with its whole chain', () {
      final l = PincodeLookup.fromJson(_master(area: 'Kozhikode'));
      expect(
        (l.code, l.found, l.source, l.inOurList, l.isSuggestion, l.active),
        ('673001', true, 'master', true, false, true),
      );
      expect(
        (
          l.district!.id,
          l.district!.name,
          l.region!.name,
          l.state!.name,
          l.zone!.name,
        ),
        ('d1', 'Kozhikode', 'Calicut', 'Kerala', 'South'),
      );
      expect((l.area, l.lat, l.lng), ('Kozhikode', 11.25, 75.78));
      expect(l.placeLine, 'Kozhikode · Calicut · Kerala');
    });

    test('a suggestion from the map is not "in our list"', () {
      final l = PincodeLookup.fromJson(_suggested());
      expect(
        (l.found, l.inOurList, l.isSuggestion, l.district!.name),
        (true, false, true, 'Kozhikode'),
      );
    });

    test('nothing known: no places, the area may still be there', () {
      final l = PincodeLookup.fromJson(_unknown(area: 'Kottayam'));
      expect(
        (
          l.found,
          l.source,
          l.district,
          l.region,
          l.state,
          l.zone,
          l.area,
          l.placeLine,
        ),
        (false, 'none', null, null, null, null, 'Kottayam', ''),
      );
    });

    test('an inactive pincode, and a chain cut short', () {
      expect(PincodeLookup.fromJson(_master(active: false)).active, isFalse);
      final cut = PincodeLookup.fromJson({
        'code': '1',
        'found': true,
        'source': 'master',
        'district': _place('d', 'Lone'),
        'region': null,
      });
      expect((cut.placeLine, cut.region, cut.state), ('Lone', null, null));
    });

    test('a thin or odd answer never throws', () {
      final l = PincodeLookup.fromJson({});
      expect(
        (l.code, l.found, l.source, l.active, l.area, l.lat),
        ('', false, 'none', true, '', null),
      );
      expect(PlaceRef.tryParse('x'), isNull);
      expect(PlaceRef.tryParse({'_id': 'a', 'name': 'N'})!.id, 'a');
    });
  });

  group('service', () {
    test('asks GET /pincodes/lookup/<code>', () async {
      final cap = _Capture(_master());
      final l = await PincodeService(
        Dio()..httpClientAdapter = cap,
      ).lookup(' 673001 ');
      expect(
        (cap.last!.method, cap.last!.path),
        ('GET', '/pincodes/lookup/673001'),
      );
      expect(l.district!.name, 'Kozhikode');
    });

    test('a refusal is a friendly AppException', () async {
      final cap = _Capture({
        'message': 'Enter a 6-digit pincode.',
      }, status: 400);
      await expectLater(
        PincodeService(Dio()..httpClientAdapter = cap).lookup('12'),
        throwsA(isA<AppException>()),
      );
    });
  });

  group('the pincode box', () {
    testWidgets('digits only, six at most', (t) async {
      final ctrl = TextEditingController();
      await t.pumpWidget(_host(_Server(), ctrl));
      await _type(t, '67 3a0-01x99', settle: false);
      expect(ctrl.text, '673001');
    });

    testWidgets('nothing is looked up until the pincode is complete', (
      t,
    ) async {
      final server = _Server();
      await t.pumpWidget(_host(server, TextEditingController()));
      await _type(t, '6730');
      expect(server.asked, isEmpty);
      expect(find.byKey(const Key('pincodeResult')), findsNothing);
      expect(find.byKey(const Key('pincodeChecking')), findsNothing);
    });

    testWidgets('a full pincode waits out the pause, then says where it is', (
      t,
    ) async {
      final server = _Server();
      await t.pumpWidget(_host(server, TextEditingController()));
      await _type(t, '673001', settle: false);
      expect(find.byKey(const Key('pincodeChecking')), findsOneWidget);
      expect(server.asked, isEmpty, reason: 'still inside the pause');
      await t.pump(const Duration(milliseconds: 450));
      await t.pump();
      expect(server.asked, ['673001']);
      expect(_shown(t, 'pincodeResult'), 'Kozhikode · Calicut · Kerala');
      expect(find.byKey(const Key('pincodeChecking')), findsNothing);
    });

    testWidgets('typing on does not fire a lookup per keystroke', (t) async {
      final server = _Server();
      await t.pumpWidget(_host(server, TextEditingController()));
      await _type(t, '673001', settle: false);
      await t.pump(const Duration(milliseconds: 100));
      await _type(t, '673002', settle: false);
      await t.pump(const Duration(milliseconds: 450));
      await t.pump();
      expect(server.asked, [
        '673002',
      ], reason: 'only the one that was left standing');
    });

    testWidgets(
      'a pre-filled pincode (e.g. from a lead) is looked up straight away',
      (t) async {
        final server = _Server();
        await t.pumpWidget(
          _host(server, TextEditingController(text: '673001')),
        );
        await t.pump();
        expect(server.asked, ['673001']);
        expect(find.byKey(const Key('pincodeResult')), findsOneWidget);
      },
    );

    testWidgets('a slow answer shows "Checking pincode…" until it arrives', (
      t,
    ) async {
      final server = _Server();
      final gate = Completer<void>();
      server.gates['673001'] = () => gate.future;
      await t.pumpWidget(_host(server, TextEditingController()));
      await _type(t, '673001');
      expect(find.byKey(const Key('pincodeChecking')), findsOneWidget);
      gate.complete();
      await t.pump();
      await t.pump();
      expect(find.byKey(const Key('pincodeChecking')), findsNothing);
      expect(find.byKey(const Key('pincodeResult')), findsOneWidget);
    });

    group('what it says', () {
      testWidgets('in our list → the district, region and state', (t) async {
        await t.pumpWidget(_host(_Server(), TextEditingController()));
        await _type(t, '673001');
        expect(_shown(t, 'pincodeResult'), 'Kozhikode · Calicut · Kerala');
      });

      testWidgets('in our list but inactive → says so', (t) async {
        await t.pumpWidget(_host(_Server(), TextEditingController()));
        await _type(t, '673003');
        expect(
          _shown(t, 'pincodeInactive'),
          'Kozhikode · Calicut · Kerala — this pincode is marked inactive in our pincode list',
        );
      });

      testWidgets(
        'not in our list but the map names a district of ours → a suggestion, labelled as one',
        (t) async {
          await t.pumpWidget(_host(_Server(), TextEditingController()));
          await _type(t, '673999');
          expect(
            _shown(t, 'pincodeSuggestion'),
            'Looks like Kozhikode · Calicut · Kerala (from the map — not in our pincode list yet)',
          );
          expect(find.byKey(const Key('pincodeResult')), findsNothing);
        },
      );

      testWidgets(
        'not in our list, the map knows the area only → asks them to choose the district',
        (t) async {
          await t.pumpWidget(_host(_Server(), TextEditingController()));
          await _type(t, '686001');
          expect(
            _shown(t, 'pincodeNotListed'),
            'Not in our pincode list. The map puts it near Kottayam — choose the district yourself.',
          );
        },
      );

      testWidgets(
        'known to nobody → says to check the number, and does not block',
        (t) async {
          final ctrl = TextEditingController();
          final key = GlobalKey<FormState>();
          await t.pumpWidget(_host(_Server(), ctrl, formKey: key));
          await _type(t, '999999');
          expect(
            _shown(t, 'pincodeNotListed'),
            'Not in our pincode list, and the map does not know it — check the number.',
          );
          expect(
            key.currentState!.validate(),
            isTrue,
            reason: 'an unknown pincode can still be saved',
          );
        },
      );

      testWidgets(
        'a lookup that fails → a plain line, Retry asks again, and nothing is blocked',
        (t) async {
          final server = _Server();
          var fail = true;
          server.gates['673001'] = () async {
            if (fail) throw StateError('network down');
          };
          final ctrl = TextEditingController();
          final key = GlobalKey<FormState>();
          await t.pumpWidget(_host(server, ctrl, formKey: key));
          await _type(t, '673001');
          expect(find.byKey(const Key('pincodeError')), findsOneWidget);
          expect(
            find.textContaining("Couldn't check this pincode right now"),
            findsOneWidget,
          );
          expect(
            find.textContaining('network down'),
            findsNothing,
            reason: 'no raw errors for people',
          );
          expect(key.currentState!.validate(), isTrue);

          fail = false;
          await t.tap(find.byKey(const Key('pincodeRetry')));
          await t.pump();
          await t.pump();
          expect(server.asked, ['673001', '673001']);
          expect(find.byKey(const Key('pincodeResult')), findsOneWidget);
        },
      );
    });

    group('changing the pincode', () {
      testWidgets(
        'editing it drops the old answer at once, before the new one is looked up',
        (t) async {
          await t.pumpWidget(_host(_Server(), TextEditingController()));
          await _type(t, '673001');
          expect(find.byKey(const Key('pincodeResult')), findsOneWidget);
          await _type(t, '67300', settle: false);
          expect(
            find.byKey(const Key('pincodeResult')),
            findsNothing,
            reason: 'no longer the same pincode',
          );
          await _type(t, '673002', settle: false);
          expect(find.byKey(const Key('pincodeResult')), findsNothing);
          expect(find.byKey(const Key('pincodeChecking')), findsOneWidget);
          await t.pump(const Duration(milliseconds: 450));
          await t.pump();
          expect(find.byKey(const Key('pincodeResult')), findsOneWidget);
        },
      );

      testWidgets('clearing it clears the answer', (t) async {
        await t.pumpWidget(_host(_Server(), TextEditingController()));
        await _type(t, '673001');
        await _type(t, '');
        expect(find.byKey(const Key('pincodeResult')), findsNothing);
      });

      testWidgets(
        'an answer that comes back late for an old pincode is not shown',
        (t) async {
          final server = _Server();
          final slow = Completer<void>();
          server.gates['673001'] = () => slow.future;
          await t.pumpWidget(_host(server, TextEditingController()));
          await _type(t, '673001');
          await _type(t, '673002');
          slow.complete();
          await t.pump();
          await t.pump();
          expect(_shown(t, 'pincodeResult'), 'Kozhikode · Calicut · Kerala');
          expect(server.asked, ['673001', '673002']);
          expect(t.widget<TextFormField>(_box).controller!.text, '673002');
        },
      );
    });

    group('for the screen using it', () {
      testWidgets(
        'onResolved gets the lookup, and null when the pincode changes',
        (t) async {
          final got = <String?>[];
          await t.pumpWidget(
            _host(
              _Server(),
              TextEditingController(),
              onResolved: (l) => got.add(l?.district?.name),
            ),
          );
          await _type(t, '673001');
          expect(got, ['Kozhikode']);
          await _type(t, '67300', settle: false);
          expect(got, ['Kozhikode', null]);
        },
      );

      testWidgets(
        'a screen\'s action shows beside a placed pincode — not for one we could not place',
        (t) async {
          Widget? act(BuildContext c, PincodeLookup l) => TextButton(
            key: const Key('useIt'),
            onPressed: () {},
            child: Text('Use ${l.district!.name}'),
          );
          await t.pumpWidget(
            _host(_Server(), TextEditingController(), actionBuilder: act),
          );
          await _type(t, '673001');
          expect(find.text('Use Kozhikode'), findsOneWidget);
          await _type(t, '673999');
          expect(
            find.text('Use Kozhikode'),
            findsOneWidget,
            reason: 'a suggestion can be acted on too',
          );
          await _type(t, '999999');
          expect(find.byKey(const Key('useIt')), findsNothing);
          await _type(t, '686001');
          expect(find.byKey(const Key('useIt')), findsNothing);
        },
      );
    });

    group('checking the form', () {
      testWidgets('required: empty is refused, a complete pincode passes', (
        t,
      ) async {
        final ctrl = TextEditingController();
        final key = GlobalKey<FormState>();
        await t.pumpWidget(
          _host(_Server(), ctrl, required: true, formKey: key),
        );
        expect(key.currentState!.validate(), isFalse);
        await t.pump();
        expect(find.text('Required'), findsOneWidget);
        await _type(t, '673001');
        expect(key.currentState!.validate(), isTrue);
      });

      testWidgets('not required: empty is fine', (t) async {
        final key = GlobalKey<FormState>();
        await t.pumpWidget(
          _host(_Server(), TextEditingController(), formKey: key),
        );
        expect(key.currentState!.validate(), isTrue);
      });

      testWidgets('strict: five digits is refused with a plain message', (
        t,
      ) async {
        final key = GlobalKey<FormState>();
        await t.pumpWidget(
          _host(
            _Server(),
            TextEditingController(),
            required: true,
            formKey: key,
          ),
        );
        await _type(t, '67300');
        expect(key.currentState!.validate(), isFalse);
        await t.pump();
        expect(find.text('Enter a 6-digit pincode'), findsOneWidget);
      });

      testWidgets(
        'not strict (old records): odd text is allowed, and said so once the box is left',
        (t) async {
          final ctrl = TextEditingController(text: 'N/A');
          final key = GlobalKey<FormState>();
          await t.pumpWidget(
            _host(_Server(), ctrl, strict: false, formKey: key),
          );
          expect(
            key.currentState!.validate(),
            isTrue,
            reason: 'an old booking can still be saved',
          );
          expect(find.byKey(const Key('pincodeFormat')), findsOneWidget);
          expect(find.text('Not a 6-digit pincode'), findsOneWidget);
        },
      );

      testWidgets(
        'not strict: a half-typed pincode is not nagged while the box has focus',
        (t) async {
          await t.pumpWidget(
            _host(_Server(), TextEditingController(), strict: false),
          );
          await t.tap(_box);
          await t.pump();
          await _type(t, '6730', settle: false);
          expect(find.byKey(const Key('pincodeFormat')), findsNothing);
        },
      );
    });

    testWidgets('on a phone the longest line wraps and nothing overflows', (
      t,
    ) async {
      t.view.physicalSize = const Size(320, 700);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final errors = <String>[];
      final previous = FlutterError.onError;
      FlutterError.onError = (d) =>
          errors.add(d.toDiagnosticsNode().toStringDeep());
      try {
        Widget? act(BuildContext c, PincodeLookup l) => TextButton(
          onPressed: () {},
          child: Text('Use ${l.district!.name} pricing for all packages'),
        );
        await t.pumpWidget(
          _host(_Server(), TextEditingController(), actionBuilder: act),
        );
        await _type(t, '673999');
        await _type(t, '673003');
      } finally {
        FlutterError.onError = previous;
      }
      expect(find.byKey(const Key('pincodeInactive')), findsOneWidget);
      expect(errors.where((e) => e.contains('pincode_field.dart')), isEmpty);
    });
  });
}
