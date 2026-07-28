import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nizan_crm/features/fleet/controllers/fleet_controller.dart';
import 'package:nizan_crm/features/fleet/data/fleet_models.dart';
import 'package:nizan_crm/features/fleet/presentation/screens/driver/driver_add_expense_screen.dart';

FleetJob _job({
  required String id,
  required String customer,
  dynamic vehicle,
  List<Map<String, dynamic>> staff = const [],
}) => FleetJob(
  id: id,
  bookingNumber: 'BK-$id',
  vehicleId: vehicle,
  customerName: customer,
  service: 'Bridal',
  serviceStart: DateTime(2026, 7, 24, 9),
  serviceEnd: DateTime(2026, 7, 24, 17),
  assignedStaff: staff,
);

Widget _app(List<FleetJob> jobs, {String? jobId}) => ProviderScope(
  overrides: [driverJobsProvider.overrideWith((ref) async => jobs)],
  child: MaterialApp(home: DriverAddExpenseScreen(jobId: jobId)),
);

final _tripPicker = find.byKey(const Key('tripPicker'));
final _categoryPicker = find.byKey(const Key('categoryPicker'));

void main() {
  testWidgets('standalone entry lets the driver pick which trip', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app([
        _job(id: 'a', customer: 'Asha', vehicle: 'v1'),
        _job(id: 'b', customer: 'Meera', vehicle: {'_id': 'v2'}),
      ]),
    );
    await tester.pumpAndSettle();

    expect(_tripPicker, findsOneWidget);
    await tester.tap(_tripPicker);
    await tester.pumpAndSettle();
    // The customer name is NOT used — booking number falls back when no artist.
    expect(find.textContaining('BK-a'), findsWidgets);
    expect(find.textContaining('Asha'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('trip is labelled by the main (lead) artist, not the bride', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app([
        _job(
          id: 'a',
          customer: 'Asha The Bride',
          vehicle: 'v1',
          staff: [
            {'artistName': 'Priya', 'roleType': 'lead'},
            {'artistName': 'Neha', 'roleType': 'assistant'},
          ],
        ),
      ]),
    );
    await tester.pumpAndSettle();

    await tester.tap(_tripPicker);
    await tester.pumpAndSettle();
    expect(find.textContaining('Priya'), findsWidgets);
    expect(find.textContaining('Asha The Bride'), findsNothing);
  });

  testWidgets('category dropdown defaults to Fuel', (tester) async {
    await tester.pumpWidget(
      _app([_job(id: 'a', customer: 'Asha', vehicle: 'v1')]),
    );
    await tester.pumpAndSettle();

    expect(_categoryPicker, findsOneWidget);
    final dd = tester.widget<DropdownButtonFormField<String>>(_categoryPicker);
    expect(dd.initialValue, 'fuel');
  });

  testWidgets('a lone trip is pre-selected', (tester) async {
    await tester.pumpWidget(
      _app([_job(id: 'a', customer: 'Asha', vehicle: 'v1')]),
    );
    await tester.pumpAndSettle();

    final dd = tester.widget<DropdownButtonFormField<String>>(_tripPicker);
    expect(dd.initialValue, 'a');
  });

  testWidgets('trips with no vehicle are excluded and submit is blocked', (
    tester,
  ) async {
    await tester.pumpWidget(_app([_job(id: 'a', customer: 'Asha')]));
    await tester.pumpAndSettle();

    expect(_tripPicker, findsNothing);
    expect(find.textContaining('No trips assigned to you yet'), findsOneWidget);
    final btn = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(btn.onPressed, isNull);
  });

  testWidgets('opened from an active job, no trip picker is shown', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app([_job(id: 'a', customer: 'Asha', vehicle: 'v1')], jobId: 'a'),
    );
    await tester.pumpAndSettle();

    expect(_tripPicker, findsNothing);
    // Category picker is always present.
    expect(_categoryPicker, findsOneWidget);
    expect(find.text('Submit Expense'), findsOneWidget);
  });
}
