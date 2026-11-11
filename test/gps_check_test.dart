import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:nizan_crm/core/theme/app_theme.dart';
import 'package:nizan_crm/features/fleet/controllers/gps_km_controller.dart';
import 'package:nizan_crm/features/fleet/data/fleet_models.dart' show formatKm;
import 'package:nizan_crm/features/fleet/data/gps_km.dart';
import 'package:nizan_crm/features/fleet/data/gps_report_parser.dart';
import 'package:nizan_crm/features/fleet/presentation/screens/fleet_gps_check_screen.dart';
import 'package:nizan_crm/features/fleet/presentation/widgets/gps_upload.dart';

Map<String, dynamic> _day(String date, String status, {double? gps, double? driver, double ret = 0, double? diff, double? tol, List<Map<String, dynamic>> trips = const [], String reason = ''}) => {
      'date': date, 'vehicleId': 'v1', 'registrationNumber': 'KL 57 Y 6100', 'vehicleName': 'Innova',
      'gpsKm': gps, 'driverKm': driver, 'returnLegKm': ret, 'returnLegSource': ret > 0 ? 'route' : 'none',
      'diffKm': diff, 'toleranceKm': tol, 'status': status, 'reason': reason,
      'driverNames': driver == null ? <String>[] : ['Ravi'], 'trips': trips,
      'runningHours': 2.5, 'stopHours': 20.0, 'idleHours': 1.5, 'startAddress': 'Mathara, Kozhikode', 'endAddress': 'Mathara, Kozhikode',
    };

Map<String, dynamic> _payload({bool uploads = true}) => {
      'from': '2026-10-20', 'to': '2026-10-31', 'defaulted': true,
      'tolerance': {'percent': 10, 'minKm': 5, 'movedKm': 5},
      'totals': {
        'gpsKm': 890.2, 'comparedGpsKm': 330, 'comparedDriverKm': 260, 'comparedDays': 3, 'okDays': 1, 'lowDays': 1,
        'highDays': 1, 'noTripDays': 1, 'noGpsDays': 0, 'reviewDays': 3, 'unloggedKm': 560, 'netDiffKm': 42, 'accuracyPct': 69.1,
      },
      'vehicles': [
        {'vehicleId': 'v1', 'name': 'Innova', 'registrationNumber': 'KL 57 Y 6100', 'gpsKm': 890.2, 'comparedDays': 3, 'okDays': 1,
         'lowDays': 1, 'highDays': 1, 'noTripDays': 1, 'noGpsDays': 0, 'unloggedKm': 560, 'netDiffKm': 42, 'accuracyPct': 69.1},
      ],
      'drivers': [
        {'driverId': 'd1', 'name': 'Ravi', 'comparedDays': 3, 'okDays': 1, 'lowDays': 1, 'highDays': 1, 'netDiffKm': 42, 'accuracyPct': 69.1},
      ],
      'days': [
        _day('2026-10-28', 'no_trip', gps: 559.1),
        _day('2026-10-24', 'driver_high', gps: 100, driver: 130, diff: -30, tol: 10),
        _day('2026-10-23', 'driver_low', gps: 130, driver: 60, diff: 70, tol: 13),
        _day('2026-10-22', 'ok', gps: 100, driver: 70, ret: 28, diff: 2, tol: 10, trips: [
          {'bookingNumber': '2610 1', 'customerName': 'Anjali', 'driverName': 'Ravi', 'startKm': 1000, 'endKm': 1040, 'km': 40},
          {'bookingNumber': '2610 2', 'customerName': 'Meera', 'driverName': 'Ravi', 'startKm': 1040, 'endKm': 1070, 'km': 30},
        ]),
      ],
      'vehiclesWithoutGps': [
        {'vehicleId': 'v3', 'registrationNumber': 'KL 01 ZZ 0001', 'name': 'Tempo', 'trips': 1, 'driverKm': 50},
      ],
      'unmatchedGps': [
        {'registrationNumber': 'MH-12-XX-9999', 'days': 2, 'gpsKm': 42.5},
      ],
      'uploads': uploads
          ? [
              {'id': 'u1', 'fileName': '866221071468727-02 Nov 2026.xlsx', 'uploadedByName': 'Fleet Manager', 'from': '2026-10-05', 'to': '2026-10-29',
               'rows': 22, 'created': 22, 'updated': 0, 'uploadedAt': '2026-11-02T07:06:00.000Z'},
            ]
          : <Map<String, dynamic>>[],
    };

Widget _screen(Map<String, dynamic> payload) => ProviderScope(
      overrides: [gpsCheckProvider.overrideWith((ref, q) async => GpsCheck.fromJson(payload))],
      child: MaterialApp(theme: AppTheme.lightTheme, home: const Scaffold(body: FleetGpsCheckScreen())),
    );

void _desktop(WidgetTester tester) {
  tester.view.physicalSize = const Size(1300, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  group('plates', () {
    test('the app and the server agree on what is the same vehicle', () {
      expect(gpsRegKey('KL-57-Y-6100'), 'KL57Y6100');
      expect(gpsRegKey('KL 57 Y 6100'), gpsRegKey('kl57y6100'));
      expect(gpsRegKey('KL-07-AB-1'), gpsRegKey('KL 7 AB 0001'));
      expect(gpsRegKey('Innova Crysta #2'), 'INNOVACRYSTA2');
    });
  });

  group('km are written the way people read them', () {
    test('rounded to one decimal, with thousands separators', () {
      expect(formatKm(1234.5), '1,234.5');
      expect(formatKm(592.89), '592.9');
      expect(formatKm(23.77), '23.8');
      expect(formatKm(0), '0');
      expect(formatKm(1000000), '1,000,000');
    });

    test('a figure just under a whole number rounds up to it (99.96 was "99.10")', () {
      expect(formatKm(99.96), '100');
      expect(formatKm(559.99), '560');
      expect(formatKm(999.96), '1,000');
    });
  });

  group('parsing the answer', () {
    test('days, standings and totals come through', () {
      final c = GpsCheck.fromJson(_payload());
      expect(c.hasUploads, isTrue);
      expect(c.totals.accuracyPct, 69.1);
      expect(c.totals.reviewDays, 3);
      expect(c.days.map((d) => d.status), [GpsDayStatus.noTrip, GpsDayStatus.driverHigh, GpsDayStatus.driverLow, GpsDayStatus.ok]);
      expect(c.days.last.trips.length, 2);
      expect(c.days.last.returnLegKm, 28);
      expect(c.vehicles.single.label, 'Innova · KL 57 Y 6100');
      expect(c.drivers.single.name, 'Ravi');
      expect(c.uploads.single.rows, 22);
      expect(c.from, DateTime(2026, 10, 20));
    });

    test('an unknown status is "no data", never a crash', () {
      expect(GpsDayStatus.parse('something new'), GpsDayStatus.noGps);
      expect(GpsDayStatus.parse(null), GpsDayStatus.noGps);
    });

    test('what counts as a comparison, and what needs a look', () {
      expect([for (final s in GpsDayStatus.values) s.compared], [true, true, true, false, false]);
      expect([for (final s in GpsDayStatus.values) s.needsReview], [false, true, true, true, true]);
    });
  });

  group('the screen', () {
    testWidgets('shows the accuracy, the standings and only the days to review at first', (tester) async {
      _desktop(tester);
      await tester.pumpWidget(_screen(_payload()));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Km accuracy'), findsOneWidget);
      expect(find.text('69.1%'), findsWidgets);
      expect(find.text('Innova · KL 57 Y 6100'), findsWidgets); // the standing and each day
      expect(find.text('Ravi'), findsOneWidget);
      expect(find.text('Needs review (3)'), findsOneWidget);
      expect(find.text('No trip logged'), findsOneWidget);
      expect(find.text('Driver km low'), findsOneWidget);
      expect(find.text('Driver km high'), findsOneWidget);
      expect(find.text('Matches'), findsNothing); // the matching day is filtered out
      expect(find.textContaining('Last upload: 866221071468727-02 Nov 2026.xlsx'), findsOneWidget);
    });

    testWidgets('"All" brings the matching day back; tapping a day explains it', (tester) async {
      _desktop(tester);
      await tester.pumpWidget(_screen(_payload()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('All (4)'));
      await tester.pumpAndSettle();
      expect(find.text('Matches'), findsOneWidget);

      await tester.tap(find.text(DateFormat('EEE, d MMM').format(DateTime(2026, 10, 22))));
      await tester.pumpAndSettle();
      expect(find.text('Within ±10 km of GPS'), findsOneWidget);
      expect(find.textContaining('#2610 1 · Anjali'), findsOneWidget);
      expect(find.textContaining('1,000'), findsWidgets);
      expect(find.textContaining('Way back to the office ≈ 28 km'), findsOneWidget);
      expect(find.textContaining("from the day's route"), findsOneWidget);
    });

    testWidgets('each kind of day says what is wrong in words', (tester) async {
      _desktop(tester);
      await tester.pumpWidget(_screen(_payload()));
      await tester.pumpAndSettle();

      await tester.tap(find.text(DateFormat('EEE, d MMM').format(DateTime(2026, 10, 23))));
      await tester.pumpAndSettle();
      expect(find.textContaining('GPS shows 70 km more than the driver entered'), findsOneWidget);

      await tester.tap(find.text(DateFormat('EEE, d MMM').format(DateTime(2026, 10, 24))));
      await tester.pumpAndSettle();
      expect(find.textContaining('The driver entered 30 km more than GPS shows'), findsOneWidget);

      await tester.tap(find.text(DateFormat('EEE, d MMM').format(DateTime(2026, 10, 28))));
      await tester.pumpAndSettle();
      expect(find.textContaining('moved 559.1 km but no driver km was entered'), findsOneWidget);
    });

    testWidgets('what could not be checked is listed, not hidden', (tester) async {
      _desktop(tester);
      await tester.pumpWidget(_screen(_payload()));
      await tester.pumpAndSettle();
      expect(find.textContaining('Tempo · KL 01 ZZ 0001 has 1 trip'), findsOneWidget);
      expect(find.textContaining('MH-12-XX-9999 is in the GPS report'), findsOneWidget);
    });

    testWidgets('nothing uploaded yet → how to get the file, and the upload button', (tester) async {
      _desktop(tester);
      await tester.pumpWidget(_screen(_payload(uploads: false)));
      await tester.pumpAndSettle();
      expect(find.text('Upload your GPS km report'), findsOneWidget);
      expect(find.textContaining('export it as Excel'), findsOneWidget);
      expect(find.text('Upload GPS report'), findsWidgets);
      expect(find.text('Km accuracy'), findsNothing);
    });

    testWidgets('a phone-width screen lays out without errors', (tester) async {
      tester.view.physicalSize = const Size(390, 2600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(_screen(_payload()));
      await tester.pumpAndSettle();
      expect(find.text('Km accuracy'), findsOneWidget);
      expect(find.text('No trip logged'), findsOneWidget);
    });
  });

  group('the upload preview', () {
    GpsReportParse vendor() => parseGpsTable([
          ['Vehicle No.', 'Date', 'Distance'],
          ['KL-57-Y-6100', 'Oct 29, 2026', '23.77'],
          ['KL-57-Y-6100', 'Oct 28, 2026', '559.12'],
          ['MH-12-XX-9999', 'Oct 28, 2026', '10'],
          ['KL-57-Y-6100', 'someday', '5'],
        ]);

    Widget host(Widget dialog) => MaterialApp(theme: AppTheme.lightTheme, home: Scaffold(body: dialog));

    testWidgets('says how many days, which vehicles are known, and what will be skipped', (tester) async {
      await tester.pumpWidget(host(GpsUploadPreview(
        fileName: 'oct.xlsx',
        parse: vendor(),
        knownVehicles: {gpsRegKey('KL 57 Y 6100'): 'Innova'},
      )));
      expect(find.text('3 days · 2 vehicles · 592.9 km'), findsOneWidget);
      expect(find.text('28 Oct 2026 → 29 Oct 2026'), findsOneWidget);
      expect(find.text('KL-57-Y-6100 · Innova'), findsOneWidget);
      expect(find.text('MH-12-XX-9999 · not one of your vehicles yet'), findsOneWidget);
      expect(find.textContaining('1 row will be skipped'), findsOneWidget);
      expect(find.text('Upload 3 days'), findsOneWidget);
    });

    testWidgets('a file that cannot be used says why and offers no upload', (tester) async {
      await tester.pumpWidget(host(GpsUploadPreview(
        fileName: 'contacts.xlsx',
        parse: parseGpsTable([['Name', 'Phone'], ['Anu', '1']]),
        knownVehicles: const {},
      )));
      expect(find.textContaining('Could not find the columns'), findsOneWidget);
      expect(find.byType(FilledButton), findsNothing);
      expect(find.text('Close'), findsOneWidget);
    });

    test('the result is summed up in a sentence', () {
      expect(
        gpsUploadSummary(const GpsUploadResult(rows: 22, created: 12, updated: 10, unchanged: 0, skipped: 1)),
        '22 days read: 12 new, 10 updated · 1 skipped.',
      );
      expect(
        gpsUploadSummary(const GpsUploadResult(rows: 1, created: 0, updated: 0, unchanged: 1, skipped: 0)),
        '1 day read: 1 already saved.',
      );
    });
  });
}
