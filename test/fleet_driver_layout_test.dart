// Driver-app layout checks at small Android (360), phone (390) and desktop
// (1440) widths with long, realistic text. A RenderFlex overflow surfaces as
// an exception, so each step asserts `tester.takeException()` is null.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nizan_crm/core/models/auth_session.dart';
import 'package:nizan_crm/core/providers/auth_provider.dart';
import 'package:nizan_crm/core/theme/app_theme.dart';
import 'package:nizan_crm/features/fleet/controllers/fleet_controller.dart';
import 'package:nizan_crm/features/fleet/data/fleet_models.dart';
import 'package:nizan_crm/features/fleet/presentation/screens/driver/active_job_screen.dart';
import 'package:nizan_crm/features/fleet/presentation/screens/driver/driver_dashboard.dart';
import 'package:nizan_crm/features/fleet/presentation/screens/driver/driver_day.dart';
import 'package:nizan_crm/features/fleet/presentation/screens/driver/pre_trip_inspection_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _sizes = [
  ('small android 360', Size(360, 1400)),
  ('phone 390', Size(390, 1400)),
  ('desktop 1440', Size(1440, 1400)),
];

const _address = "Near St. Mary's Church, MG Road, Ernakulam North, Kochi 682018";

Future<void> _setSize(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

String _today(int hour) {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day, hour, 30).toIso8601String();
}

FleetJob _job(
  String id, {
  required String status,
  required int hour,
  String customer = 'Anjali Krishnakumar Menon Thekkedath',
  bool staff = true,
  bool otpVerified = false,
  bool started = false,
  double? startKm,
  double? endKm,
}) =>
    FleetJob.fromJson({
      '_id': id,
      'bookingNumber': 'NZ-2026-11-000$id',
      'tripStatus': status,
      'customerName': customer,
      'address': _address,
      'service': 'Bridal Makeup + Hairstyling + Saree Draping (Premium)',
      'eventSlot': 'Muhurtham 10:30 AM – Reception 7:00 PM',
      'serviceStart': _today(hour),
      'serviceEnd': _today(hour + 2),
      'pocName': 'Thomas Kuruvilla Kunnumpurathu',
      'pocPhone': '+91 98765 43210',
      'vehicleId': {
        '_id': 'v1',
        'type': 'Toyota Innova Crysta 2.8 ZX AT',
        'registrationNumber': 'KL-07-CX-1234',
        'currentKm': 45230.5,
      },
      'assignedStaff': staff
          ? [
              {'name': 'Fathima Liya Muhammed', 'role': 'artist'},
            ]
          : <Map<String, dynamic>>[],
      'startKm': ?startKm,
      'endKm': ?endKm,
      if (started) 'tripStartedAt': _today(hour),
      if (endKm != null) 'tripCompletedAt': _today(hour + 1),
      if (otpVerified) 'artistOtpVerifiedAt': _today(hour),
    });

List<FleetJob> _jobs({bool otpVerified = false}) => [
      _job('1',
          status: 'completed',
          hour: 6,
          started: true,
          startKm: 45230.5,
          endKm: 45311.2,
          otpVerified: true),
      _job('2',
          status: 'in_progress',
          hour: 9,
          started: true,
          startKm: 45311.2,
          otpVerified: otpVerified),
      _job('3', status: 'assigned', hour: 14, customer: 'Riya Joseph Kuruvilla Thomas Kunnumpurathu'),
    ];

Widget _app(List<FleetJob> jobs, Widget home) => ProviderScope(
      overrides: [
        driverJobsProvider.overrideWith((ref) async => jobs),
        authSessionProvider.overrideWith(
          (ref) => const AuthSession(
              token: 't',
              userId: 'u0',
              name: 'Muhammed Shihabudheen Kunjumon',
              email: 'driver@example.com',
              role: 'driver',
              employeeId: 'e1'),
        ),
      ],
      child: MaterialApp(theme: AppTheme.lightTheme, home: home),
    );

Future<void> _pump(WidgetTester tester, Size size, List<FleetJob> jobs, Widget home) async {
  SharedPreferences.setMockInitialValues({});
  await _setSize(tester, size);
  await tester.pumpWidget(_app(jobs, home));
  await tester.pumpAndSettle();
}

void main() {
  for (final (label, size) in _sizes) {
    group(label, () {
      testWidgets('driver dashboard: header, stats and trip cards', (tester) async {
        await _pump(tester, size, _jobs(), const DriverDashboard());
        expect(find.text('Driver Dashboard'), findsOneWidget);
        expect(tester.takeException(), isNull, reason: 'dashboard');
      });

      testWidgets('active job: OTP pending card + complete dialog', (tester) async {
        await _pump(tester, size, _jobs(), const ActiveJobScreen(jobId: '2'));
        expect(find.text('Artist Trip OTP'), findsOneWidget);
        expect(tester.takeException(), isNull, reason: 'active job, OTP pending');

        // Wrong-length OTP shows the inline error under the field.
        await tester.enterText(find.byType(TextField).first, '12');
        await tester.tap(find.text('Verify'));
        await tester.pumpAndSettle();
        expect(find.text('Enter all 4 digits'), findsOneWidget);
        expect(tester.takeException(), isNull, reason: 'OTP error state');

        await tester.ensureVisible(find.text('Complete Job'));
        await tester.tap(find.text('Complete Job'));
        await tester.pumpAndSettle();
        expect(find.text('Complete trip'), findsOneWidget);
        expect(tester.takeException(), isNull, reason: 'complete dialog');
      });

      testWidgets('active job: OTP verified', (tester) async {
        await _pump(tester, size, _jobs(otpVerified: true), const ActiveJobScreen(jobId: '2'));
        expect(find.textContaining('Artist OTP verified'), findsOneWidget);
        expect(tester.takeException(), isNull, reason: 'OTP verified');
      });

      testWidgets('active job: completed trip view', (tester) async {
        await _pump(tester, size, _jobs(), const ActiveJobScreen(jobId: '1'));
        expect(find.text('Trip completed'), findsOneWidget);
        expect(tester.takeException(), isNull, reason: 'completed trip');
      });

      testWidgets('pre-trip inspection with artist OTP card', (tester) async {
        // The screen reads (not watches) driverJobsProvider, which the app has
        // already loaded via the dashboard — mirror that here.
        await _pump(
          tester,
          size,
          _jobs(),
          Consumer(
            builder: (context, ref, _) => ref.watch(driverJobsProvider).hasValue
                ? const PreTripInspectionScreen(jobId: '3')
                : const SizedBox.shrink(),
          ),
        );
        expect(find.text('Artist Trip OTP'), findsOneWidget);
        expect(tester.takeException(), isNull, reason: 'inspection');
        await tester.enterText(find.byType(TextField).last, '12');
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'inspection partial OTP');
      });

      testWidgets('driver day: quick-start sheet + next trip card', (tester) async {
        final jobs = _jobs();
        await _pump(
          tester,
          size,
          jobs,
          Consumer(
            builder: (context, ref, _) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => showQuickStartSheet(context, ref, jobs[2], suggestedKm: 45311.2),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        expect(find.text('Start next trip'), findsOneWidget);
        expect(tester.takeException(), isNull, reason: 'quick-start sheet');
      });
    });
  }
}
