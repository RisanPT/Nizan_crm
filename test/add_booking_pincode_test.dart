import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nizan_crm/core/models/addon_service.dart';
import 'package:nizan_crm/core/models/district.dart';
import 'package:nizan_crm/core/models/pincode_lookup.dart';
import 'package:nizan_crm/core/models/service_package.dart';
import 'package:nizan_crm/core/theme/app_theme.dart';
import 'package:nizan_crm/core/widgets/pincode_field.dart';
import 'package:nizan_crm/features/bookings/presentation/screens/add_booking_screen.dart';
import 'package:nizan_crm/services/addon_service_service.dart';
import 'package:nizan_crm/services/district_service.dart';
import 'package:nizan_crm/services/package_service.dart';
import 'package:nizan_crm/services/pincode_service.dart';

// Add Booking uses the shared pincode field: it is required and must be 6 digits, it says where the
// pincode is, and — when the programme already has packages — offers to price them for that district.

Map<String, dynamic> _place(String id, String name) => {'id': id, 'name': name};

PincodeLookup _kozhikode(String code) => PincodeLookup.fromJson({
  'code': code,
  'found': true,
  'source': 'master',
  'active': true,
  'district': _place('d1', 'Kozhikode'),
  'region': _place('r1', 'Calicut'),
  'state': _place('s1', 'Kerala'),
  'zone': _place('z1', 'South'),
});

const _kozhikodeDistrict = District(
  id: 'd1',
  name: 'Kozhikode',
  regionId: 'r1',
  regionName: 'Calicut',
  status: 'active',
);

Widget _app({
  List<District> districts = const [_kozhikodeDistrict],
  List<String>? asked,
  Map<String, String> query = const {},
}) {
  final router = GoRouter(
    initialLocation: Uri(
      path: '/',
      queryParameters: query.isEmpty ? null : query,
    ).toString(),
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(body: AddBookingScreen()),
      ),
    ],
  );
  return ProviderScope(
    overrides: <Override>[
      packagesProvider.overrideWith((ref) async => <ServicePackage>[]),
      districtsProvider.overrideWith((ref) async => districts),
      addonServicesProvider.overrideWith((ref) async => <AddonService>[]),
      pincodeLookupProvider.overrideWith((ref, code) async {
        asked?.add(code);
        return code == '673001' || code == '673002'
            ? _kozhikode(code)
            : PincodeLookup.fromJson({
                'code': code,
                'found': false,
                'source': 'none',
              });
      }),
    ],
    child: MaterialApp.router(theme: AppTheme.lightTheme, routerConfig: router),
  );
}

Future<void> _open(WidgetTester t, Widget app) async {
  t.view.physicalSize = const Size(1200, 2600);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(app);
  await t.pumpAndSettle();
}

final _pincode = find.widgetWithText(TextFormField, 'Pincode');

Future<void> _typePin(WidgetTester t, String v) async {
  await t.ensureVisible(_pincode);
  await t.enterText(_pincode, v);
  await t.pump(const Duration(milliseconds: 450));
  await t.pump();
}

Future<void> _addDay(WidgetTester t) async {
  await t.ensureVisible(find.text('Add event day'));
  await t.tap(find.text('Add event day'));
  await t.pumpAndSettle();
  await t.tap(find.text('OK'));
  await t.pumpAndSettle();
}

void main() {
  testWidgets(
    'the pincode box is on the client section and says where a pincode is',
    (t) async {
      final asked = <String>[];
      await _open(t, _app(asked: asked));
      expect(_pincode, findsOneWidget);
      await _typePin(t, '673001');
      expect(asked, ['673001']);
      expect(find.text('Kozhikode · Calicut · Kerala'), findsOneWidget);
    },
  );

  testWidgets(
    'a pincode from a lead conversion is pre-filled and looked up at once',
    (t) async {
      final asked = <String>[];
      await _open(t, _app(asked: asked, query: {'pincode': '673002'}));
      expect(asked, ['673002']);
      expect(find.text('Kozhikode · Calicut · Kerala'), findsOneWidget);
      expect(t.widget<TextFormField>(_pincode).controller!.text, '673002');
    },
  );

  testWidgets(
    'creating without a pincode, or with 5 digits, is refused on the box',
    (t) async {
      await _open(t, _app());
      await t.ensureVisible(find.text('Create booking'));
      await t.tap(find.text('Create booking'));
      await t.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(PincodeField),
          matching: find.text('Required'),
        ),
        findsOneWidget,
        reason: 'on the pincode box itself',
      );
      // let the "fill the required details" note go, or it sits over the button
      await t.pump(const Duration(seconds: 8));
      await t.pumpAndSettle();
      await _typePin(t, '67300');
      await t.ensureVisible(find.text('Create booking'));
      await t.tap(find.text('Create booking'));
      await t.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(PincodeField),
          matching: find.text('Enter a 6-digit pincode'),
        ),
        findsOneWidget,
      );
    },
  );

  group('pricing for the pincode\'s district', () {
    testWidgets(
      'with no packages in the programme yet there is nothing to price, so no button',
      (t) async {
        await _open(t, _app());
        await _typePin(t, '673001');
        expect(find.byKey(const Key('pincodeUseDistrict')), findsNothing);
      },
    );

    testWidgets(
      'with a package line, one tap prices it for the district — and the button goes away',
      (t) async {
        await _open(t, _app());
        await _addDay(t);
        expect(
          find.text('Default (base price)'),
          findsOneWidget,
          reason: 'the new line starts on the base price',
        );
        await _typePin(t, '673001');
        expect(
          find.text('Use Kozhikode pricing for all packages'),
          findsOneWidget,
        );
        await t.ensureVisible(find.byKey(const Key('pincodeUseDistrict')));
        await t.tap(find.byKey(const Key('pincodeUseDistrict')));
        await t.pumpAndSettle();
        expect(find.text('Kozhikode (Calicut)'), findsOneWidget);
        expect(find.text('Default (base price)'), findsNothing);
        expect(
          find.byKey(const Key('pincodeUseDistrict')),
          findsNothing,
          reason: 'every line is already on that district',
        );
      },
    );

    testWidgets('it never changes the price on its own', (t) async {
      await _open(t, _app());
      await _addDay(t);
      await _typePin(t, '673001');
      expect(find.text('Default (base price)'), findsOneWidget);
      expect(find.text('Kozhikode (Calicut)'), findsNothing);
    });

    testWidgets('a district we have no pricing for is not offered', (t) async {
      await _open(t, _app(districts: const []));
      await _addDay(t);
      await _typePin(t, '673001');
      expect(find.byKey(const Key('pincodeUseDistrict')), findsNothing);
      expect(
        find.text('Kozhikode · Calicut · Kerala'),
        findsOneWidget,
        reason: 'the place is still shown',
      );
    });
  });
}
