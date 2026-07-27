import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nizan_crm/features/fleet/controllers/fleet_controller.dart';
import 'package:nizan_crm/features/fleet/data/fleet_models.dart';
import 'package:nizan_crm/features/fleet/presentation/screens/driver/driver_add_expense_screen.dart';

FleetJob _job({required String id, required String customer, dynamic vehicle}) =>
    FleetJob(
      id: id,
      bookingNumber: 'BK-$id',
      vehicleId: vehicle,
      customerName: customer,
      service: 'Bridal',
      serviceStart: DateTime(2026, 7, 24, 9),
      serviceEnd: DateTime(2026, 7, 24, 17),
    );

Widget _app(List<FleetJob> jobs, {String? jobId}) => ProviderScope(
      overrides: [
        driverJobsProvider.overrideWith((ref) async => jobs),
      ],
      child: MaterialApp(home: DriverAddExpenseScreen(jobId: jobId)),
    );

void main() {
  testWidgets('standalone entry lets the driver pick which trip', (tester) async {
    await tester.pumpWidget(_app([
      _job(id: 'a', customer: 'Asha', vehicle: 'v1'),
      _job(id: 'b', customer: 'Meera', vehicle: {'_id': 'v2'}),
    ]));
    await tester.pumpAndSettle();

    expect(find.text('Trip *'), findsOneWidget);
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    expect(find.textContaining('Asha'), findsWidgets);
    expect(find.textContaining('Meera'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a lone trip is pre-selected', (tester) async {
    await tester.pumpWidget(_app([_job(id: 'a', customer: 'Asha', vehicle: 'v1')]));
    await tester.pumpAndSettle();

    final dd = tester.widget<DropdownButtonFormField<String>>(
        find.byType(DropdownButtonFormField<String>));
    expect(dd.initialValue, 'a');
  });

  testWidgets('trips with no vehicle are excluded and submit is blocked',
      (tester) async {
    await tester.pumpWidget(_app([_job(id: 'a', customer: 'Asha')]));
    await tester.pumpAndSettle();

    expect(find.byType(DropdownButtonFormField<String>), findsNothing);
    expect(find.textContaining('No trips assigned to you yet'), findsOneWidget);
    final btn = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(btn.onPressed, isNull);
  });

  testWidgets('opened from an active job, no picker is shown', (tester) async {
    await tester.pumpWidget(
        _app([_job(id: 'a', customer: 'Asha', vehicle: 'v1')], jobId: 'a'));
    await tester.pumpAndSettle();

    expect(find.byType(DropdownButtonFormField<String>), findsNothing);
    expect(find.text('Submit Expense'), findsOneWidget);
  });
}
