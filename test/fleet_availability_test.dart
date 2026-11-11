import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/models/employee.dart';
import 'package:nizan_crm/core/theme/app_theme.dart';
import 'package:nizan_crm/features/bookings/controllers/booking_provider.dart';
import 'package:nizan_crm/features/bookings/data/booking.dart';
import 'package:nizan_crm/features/fleet/controllers/fleet_availability_controller.dart';
import 'package:nizan_crm/features/fleet/controllers/vehicle_controller.dart';
import 'package:nizan_crm/features/fleet/data/fleet_availability.dart';
import 'package:nizan_crm/features/fleet/data/vehicle.dart';
import 'package:nizan_crm/features/fleet/presentation/screens/fleet_assignments_screen.dart';
import 'package:nizan_crm/features/fleet/presentation/widgets/fleet_availability_widgets.dart';
import 'package:nizan_crm/features/fleet/presentation/widgets/fleet_board.dart';
import 'package:nizan_crm/features/fleet/services/fleet_availability_service.dart';
import 'package:nizan_crm/services/employee_service.dart';

// Fleet availability: who is free for a work, marked on the driver / vehicle pickers; the "assign
// anyway?" question when the server refuses a clash; and the "who is free" board for a day.

const _start1 = '2026-10-30T03:30:00.000Z'; // 9:00 AM IST
const _end1 = '2026-10-30T07:30:00.000Z'; // 1:00 PM IST

String _t(String iso) =>
    DateFormat('h:mm a').format(DateTime.parse(iso).toLocal());

Map<String, dynamic> _overlap({
  String resource = '',
  String name = 'Ravi',
  String number = 'BK-12',
  String customer = 'Beena',
}) => {
  'resource': resource,
  'id': 'x',
  'name': name,
  'kind': 'overlap',
  'day': '2026-10-30',
  'start': _start1,
  'end': _end1,
  'with': {
    'bookingId': 'b12',
    'bookingNumber': number,
    'customerName': customer,
  },
};

Map<String, dynamic> _tight({bool estimated = false}) => {
  'kind': 'tight',
  'day': '2026-10-30',
  'start': _start1,
  'end': _end1,
  'with': {
    'bookingId': 'b12',
    'bookingNumber': 'BK-12',
    'customerName': 'Beena',
  },
  'gapMinutes': 30,
  'neededMinutes': 90,
  'estimated': estimated,
};

Map<String, dynamic> _unavailable(String reason) => {
  'kind': 'unavailable',
  'reason': reason,
  'day': '2026-10-30',
};
Map<String, dynamic> _warning(String reason) => {
  'kind': 'warning',
  'reason': reason,
};

Map<String, dynamic> _res(
  String id,
  String name,
  String status, {
  List<Map<String, dynamic>> conflicts = const [],
  List<Map<String, dynamic>> warnings = const [],
  String reg = '',
}) => {
  'id': id,
  'name': name,
  'registrationNumber': reg,
  'status': status,
  'conflicts': conflicts,
  'warnings': warnings,
};

BookingAvailability _availability() => BookingAvailability.fromJson({
  'bookingId': 'b1',
  'days': ['2026-10-30'],
  'drivers': [
    _res('d1', 'Ravi', 'busy', conflicts: [_overlap(name: 'Ravi')]),
    _res(
      'd2',
      'Suresh',
      'unavailable',
      conflicts: [_unavailable('Suresh is on leave on 2026-10-30')],
    ),
    _res('d3', 'Mani', 'free'),
  ],
  'vehicles': [
    _res(
      'v1',
      'Innova',
      'tight',
      conflicts: [_tight()],
      warnings: [_warning('Insurance was due on 2026-10-12')],
      reg: 'KL 11 AB 1234',
    ),
    _res('v2', 'Tempo', 'free', reg: 'KL 11 CD 5678'),
  ],
});

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

AppException _conflictError({
  List<Map<String, dynamic>>? problems,
  int status = 409,
  String code = 'FLEET_CONFLICT',
}) {
  final ro = RequestOptions(path: '/bookings/b1');
  return AppException(
    DioException(
      requestOptions: ro,
      type: DioExceptionType.badResponse,
      response: Response(
        requestOptions: ro,
        statusCode: status,
        data: {
          'code': code,
          'message':
              'Ravi is already on BK-12 (9:00 AM–1:00 PM) on 2026-10-30. Confirm to assign anyway.',
          'problems': problems ?? [_overlap(resource: 'driver')],
          'warnings': [_warning('Insurance was due on 2026-10-12')],
        },
      ),
    ),
    action: 'update booking',
  );
}

/// A bookings store that records every save and fails them as scripted.
class _FakeBookings extends BookingNotifier {
  _FakeBookings(this.list, {this.script});
  final List<Booking> list;
  final calls = <({String driverId, String vehicleId, bool confirm})>[];

  /// Called with `confirm`; return an error to fail that save, or null to let it through.
  final Object? Function(bool confirm)? script;

  @override
  FutureOr<List<Booking>> build() => list;

  @override
  Future<Booking> updateBooking(
    Booking booking, {
    bool confirmFleetConflict = false,
  }) async {
    calls.add((
      driverId: booking.driverId,
      vehicleId: booking.vehicleId,
      confirm: confirmFleetConflict,
    ));
    final err = script?.call(confirmFleetConflict);
    if (err != null) throw err;
    return booking;
  }
}

Booking _booking({String driverId = '', String vehicleId = ''}) =>
    Booking.fromJson({
      '_id': 'b1',
      'bookingNumber': 'BK-1',
      'customerName': 'Asha',
      'phone': '9895499872',
      'status': 'confirmed',
      'service': 'Bridal',
      'totalPrice': 10000,
      'advanceAmount': 1000,
      'address': 'Beach Road',
      'selectedDates': ['2026-10-30'],
      'bookingDate': _start1,
      'serviceStart': _start1,
      'serviceEnd': _end1,
      'driverId': driverId,
      'vehicleId': vehicleId,
      'assignedStaff': [
        {
          'employeeId': 'a1',
          'artistName': 'Anu',
          'role': 'Lead',
          'roleType': 'lead',
        },
      ],
    });

void _size(WidgetTester t, {double w = 1400, double h = 2400}) {
  t.view.physicalSize = Size(w, h);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
}

void main() {
  group('what a clash says', () {
    test('overlap: the other work and its times', () {
      final p = AvailabilityProblem.fromJson(_overlap());
      expect(
        (p.isOverlap, p.isBlocking, p.otherWork),
        (true, true, 'BK-12 · Beena'),
      );
      expect(p.text, 'Already on BK-12 · Beena, ${_t(_start1)}–${_t(_end1)}');
    });

    test(
      'tight: how long there is and how long it takes — "about" when the drive was only estimated',
      () {
        expect(
          AvailabilityProblem.fromJson(_tight()).text,
          'Only 30 min from BK-12 · Beena — 1 h 30 min needed to get there',
        );
        expect(
          AvailabilityProblem.fromJson(_tight(estimated: true)).text,
          'Only 30 min from BK-12 · Beena — about 1 h 30 min needed to get there',
        );
        expect(
          AvailabilityProblem.fromJson(_tight()).isBlocking,
          isFalse,
          reason: 'a tight gap is advice',
        );
      },
    );

    test('unavailable and warning say the server\'s reason', () {
      final u = AvailabilityProblem.fromJson(
        _unavailable('Dzire is under service'),
      );
      expect(
        (u.text, u.isUnavailable, u.isBlocking),
        ('Dzire is under service', true, true),
      );
      final w = AvailabilityProblem.fromJson(
        _warning('Insurance was due on 2026-10-12'),
      );
      expect(
        (w.text, w.isWarning, w.isBlocking),
        ('Insurance was due on 2026-10-12', true, false),
      );
    });

    test('durations read plainly', () {
      expect(AvailabilityProblem.duration(0), '0 min');
      expect(AvailabilityProblem.duration(45), '45 min');
      expect(AvailabilityProblem.duration(60), '1 h');
      expect(AvailabilityProblem.duration(125), '2 h 5 min');
    });

    test('a thin answer never throws', () {
      final p = AvailabilityProblem.fromJson({'kind': 'overlap'});
      expect(p.text, 'Already on another work', reason: 'no times to give');
      expect(AvailabilityProblem.fromJson({}).text, '');
    });
  });

  group('for one booking', () {
    test(
      'finds a driver or vehicle by id, with the worst problem as its summary',
      () {
        final a = _availability();
        expect(a.driver('d1')!.status, 'busy');
        expect(a.driver('d1')!.isBlocked, isTrue);
        expect(a.driver('d3')!.isFree, isTrue);
        expect(a.driver('d3')!.summary, '');
        expect(
          a.vehicle('v1')!.summary,
          startsWith('Only 30 min'),
          reason: 'the conflict, not the warning',
        );
        expect(a.vehicle('v2')!.isBlocked, isFalse);
        expect(
          (a.driver('nobody'), a.driver(null), a.vehicle('')),
          (null, null, null),
        );
      },
    );

    test('a warning alone is the summary when there is no conflict', () {
      final r = ResourceAvailability.fromJson(
        _res(
          'v9',
          'Dzire',
          'free',
          warnings: [_warning('Tax was due on 2026-09-01')],
        ),
      );
      expect((r.isFree, r.summary), (true, 'Tax was due on 2026-09-01'));
    });
  });

  group('the server refusing an assignment', () {
    test('reads a 409 FLEET_CONFLICT, wrapped or not', () {
      final c = FleetConflict.of(_conflictError())!;
      expect(c.problems, hasLength(1));
      expect(c.problems.single.resource, 'driver');
      expect(c.warnings.single.text, 'Insurance was due on 2026-10-12');
      expect(c.message, contains('Confirm to assign anyway'));
      expect(
        FleetConflict.of((_conflictError()).cause),
        isNotNull,
        reason: 'the raw DioException too',
      );
    });

    test('anything else is not a fleet conflict', () {
      expect(FleetConflict.of(_conflictError(status: 400)), isNull);
      expect(FleetConflict.of(_conflictError(code: 'DUPLICATE')), isNull);
      expect(FleetConflict.of(Exception('boom')), isNull);
      expect(FleetConflict.of(null), isNull);
      expect(FleetConflict.of(AppException(Exception('offline'))), isNull);
    });
  });

  group('service', () {
    FleetAvailabilityService svc(_Capture c) =>
        FleetAvailabilityService(Dio()..httpClientAdapter = c);

    test('one booking: GET /fleet/availability/booking/<id>', () async {
      final cap = _Capture({
        'bookingId': 'b1',
        'days': ['2026-10-30'],
        'drivers': [_res('d1', 'Ravi', 'free')],
        'vehicles': [],
      });
      final a = await svc(cap).forBooking('b1');
      expect(
        (cap.last!.method, cap.last!.path),
        ('GET', '/fleet/availability/booking/b1'),
      );
      expect(a.drivers.single.name, 'Ravi');
    });

    test('one day: GET /fleet/availability/day?date=', () async {
      final cap = _Capture({
        'day': '2026-10-30',
        'vehicles': [],
        'drivers': [],
        'needing': [],
      });
      await svc(cap).forDay('2026-10-30');
      expect(cap.last!.path, '/fleet/availability/day');
      expect(cap.last!.queryParameters['date'], '2026-10-30');
    });

    test('a refusal is a friendly AppException', () async {
      final cap = _Capture({'message': 'Not authorized'}, status: 403);
      await expectLater(
        svc(cap).forBooking('b1'),
        throwsA(isA<AppException>()),
      );
      await expectLater(
        svc(cap).forDay('2026-10-30'),
        throwsA(isA<AppException>()),
      );
    });
  });

  group('the marks', () {
    Widget host(Widget child) => MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: Padding(padding: const EdgeInsets.all(16), child: child),
      ),
    );

    testWidgets('a pill for each state', (t) async {
      await t.pumpWidget(
        host(
          Column(
            children: [
              for (final s in ['free', 'tight', 'busy', 'unavailable'])
                AvailabilityPill(status: s),
            ],
          ),
        ),
      );
      expect(find.text('Free'), findsOneWidget);
      expect(find.text('Tight'), findsOneWidget);
      expect(find.text('Busy'), findsOneWidget);
      expect(find.text('Unavailable'), findsOneWidget);
    });

    testWidgets('the note lists what is wrong, and the warnings quietly', (
      t,
    ) async {
      await t.pumpWidget(
        host(AvailabilityNote(resource: _availability().vehicle('v1'))),
      );
      expect(find.byKey(const Key('availabilityNote_v1')), findsOneWidget);
      expect(find.textContaining('Only 30 min from BK-12'), findsOneWidget);
      expect(
        find.textContaining('Insurance was due on 2026-10-12'),
        findsOneWidget,
      );
    });

    testWidgets('a free one with nothing to say has no note at all', (t) async {
      await t.pumpWidget(
        host(AvailabilityNote(resource: _availability().driver('d3'))),
      );
      expect(find.byType(Container), findsNothing);
      await t.pumpWidget(host(const AvailabilityNote(resource: null)));
      expect(find.byType(Text), findsNothing);
    });
  });

  group('assign anyway?', () {
    Widget app(
      _FakeBookings store,
      void Function(Object?) onDone, {
      Booking? booking,
    }) => ProviderScope(
      overrides: <Override>[bookingProvider.overrideWith(() => store)],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: Consumer(
            builder: (ctx, ref, _) => ElevatedButton(
              onPressed: () async {
                try {
                  onDone(
                    await updateBookingConfirmingFleet(
                      ctx,
                      ref,
                      booking ?? _booking(driverId: 'd1'),
                    ),
                  );
                } catch (e) {
                  onDone(e);
                }
              },
              child: const Text('save'),
            ),
          ),
        ),
      ),
    );

    testWidgets('no clash: saved at once, no question', (t) async {
      final store = _FakeBookings([_booking()]);
      Object? result;
      await t.pumpWidget(app(store, (r) => result = r));
      await t.tap(find.text('save'));
      await t.pumpAndSettle();
      expect(result, isA<Booking>());
      expect(find.byKey(const Key('fleetConflictDialog')), findsNothing);
      expect(store.calls.map((c) => c.confirm), [false]);
    });

    testWidgets(
      'a clash: the question names who and when; "Assign anyway" saves again WITH confirmation',
      (t) async {
        final store = _FakeBookings([
          _booking(),
        ], script: (confirm) => confirm ? null : _conflictError());
        Object? result;
        await t.pumpWidget(app(store, (r) => result = r));
        await t.tap(find.text('save'));
        await t.pumpAndSettle();
        expect(find.byKey(const Key('fleetConflictDialog')), findsOneWidget);
        expect(find.text('Already committed'), findsOneWidget);
        expect(find.text('Ravi\n', findRichText: true), findsNothing);
        expect(find.textContaining('Already on BK-12 · Beena'), findsOneWidget);
        expect(
          find.textContaining('Insurance was due'),
          findsOneWidget,
          reason: 'warnings are shown too',
        );
        expect(
          store.calls,
          hasLength(1),
          reason: 'nothing is repeated until the person says yes',
        );
        await t.tap(find.byKey(const Key('fleetConflictAssign')));
        await t.pumpAndSettle();
        expect(store.calls.map((c) => c.confirm), [false, true]);
        expect(result, isA<Booking>());
      },
    );

    testWidgets(
      '"Choose another": nothing more is sent, and the answer is null (not an error)',
      (t) async {
        final store = _FakeBookings([
          _booking(),
        ], script: (confirm) => confirm ? null : _conflictError());
        Object? result = 'unset';
        await t.pumpWidget(app(store, (r) => result = r));
        await t.tap(find.text('save'));
        await t.pumpAndSettle();
        await t.tap(find.byKey(const Key('fleetConflictCancel')));
        await t.pumpAndSettle();
        expect(result, isNull);
        expect(store.calls, hasLength(1));
      },
    );

    testWidgets(
      'any other failure is thrown for the screen to show, with no question',
      (t) async {
        final store = _FakeBookings([
          _booking(),
        ], script: (_) => _conflictError(status: 500));
        Object? result;
        await t.pumpWidget(app(store, (r) => result = r));
        await t.tap(find.text('save'));
        await t.pumpAndSettle();
        expect(result, isA<AppException>());
        expect(find.byKey(const Key('fleetConflictDialog')), findsNothing);
      },
    );

    testWidgets('if the confirmed save fails too, that failure is thrown', (
      t,
    ) async {
      final store = _FakeBookings(
        [_booking()],
        script: (confirm) =>
            confirm ? _conflictError(status: 500) : _conflictError(),
      );
      Object? result;
      await t.pumpWidget(app(store, (r) => result = r));
      await t.tap(find.text('save'));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('fleetConflictAssign')));
      await t.pumpAndSettle();
      expect(result, isA<AppException>());
    });
  });

  group('the fleet board', () {
    FleetBoard board(String day) => FleetBoard.fromJson({
      'day': day,
      'vehicles': [
        {
          'id': 'v1',
          'name': 'Innova',
          'registrationNumber': 'KL 11 AB 1234',
          'category': 'mpv',
          'seats': 7,
          'status': 'busy',
          'works': [
            {
              'bookingId': 'b1',
              'bookingNumber': 'BK-1',
              'customerName': 'Asha',
              'start': _start1,
              'end': _end1,
            },
          ],
          'clashes': [],
          'conflicts': [],
          'warnings': [_warning('Insurance was due on 2026-10-12')],
        },
        {
          'id': 'v2',
          'name': 'Tempo',
          'registrationNumber': 'KL 11 CD 5678',
          'status': 'free',
          'works': [],
          'clashes': [],
          'conflicts': [],
          'warnings': [],
        },
        {
          'id': 'v3',
          'name': 'Dzire',
          'registrationNumber': 'KL 11 EF 9',
          'status': 'unavailable',
          'works': [],
          'clashes': [],
          'conflicts': [_unavailable('Dzire is under service')],
          'warnings': [],
        },
      ],
      'drivers': [
        {
          'id': 'd1',
          'name': 'Ravi',
          'status': 'busy',
          'works': [
            {
              'bookingId': 'b1',
              'bookingNumber': 'BK-1',
              'customerName': 'Asha',
              'start': _start1,
              'end': _end1,
            },
            {
              'bookingId': 'b2',
              'bookingNumber': 'BK-2',
              'customerName': 'Beena',
              'start': _start1,
              'end': _end1,
            },
          ],
          'clashes': [
            {
              'kind': 'overlap',
              'between': ['BK-1', 'BK-2'],
            },
          ],
          'conflicts': [],
          'warnings': [],
        },
        {
          'id': 'd2',
          'name': 'Mani',
          'status': 'free',
          'works': [],
          'clashes': [],
          'conflicts': [],
          'warnings': [],
        },
      ],
      'needing': [
        {
          'bookingId': 'b8',
          'bookingNumber': 'BK-8',
          'customerName': 'Chitra',
          'start': _start1,
          'end': _end1,
          'needsDriver': true,
          'needsVehicle': true,
        },
        {
          'bookingId': 'b9',
          'bookingNumber': 'BK-9',
          'customerName': 'Dev',
          'start': _start1,
          'end': _end1,
          'needsDriver': false,
          'needsVehicle': true,
        },
      ],
    });

    Widget app(List<String> asked, {bool fail = false}) => ProviderScope(
      overrides: <Override>[
        fleetBoardProvider.overrideWith((ref, day) async {
          asked.add(day);
          if (fail) throw Exception('server down');
          return board(day);
        }),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: FleetBoardView(initialDay: DateTime(2026, 10, 30)),
        ),
      ),
    );

    testWidgets(
      'names the day and summarises who is free and what still needs someone',
      (t) async {
        final asked = <String>[];
        _size(t);
        await t.pumpWidget(app(asked));
        await t.pumpAndSettle();
        expect(asked, ['2026-10-30']);
        expect(find.text('Fri, 30 Oct 2026'), findsOneWidget);
        expect(
          t.widget<Text>(find.byKey(const Key('boardSummary'))).data,
          '1 of 3 vehicles and 1 of 2 drivers free · 2 works need a driver or vehicle',
        );
      },
    );

    testWidgets(
      'works that still need a driver or vehicle are listed first, saying which',
      (t) async {
        _size(t);
        await t.pumpWidget(app([]));
        await t.pumpAndSettle();
        expect(find.textContaining('BK-8  Chitra'), findsOneWidget);
        expect(
          find.textContaining('needs a driver and vehicle'),
          findsOneWidget,
        );
        expect(find.textContaining('needs a vehicle'), findsOneWidget);
      },
    );

    testWidgets(
      'each vehicle and driver: its state, its works with times, and what is wrong',
      (t) async {
        _size(t);
        await t.pumpWidget(app([]));
        await t.pumpAndSettle();
        expect(find.byKey(const Key('vehicle_v1')), findsOneWidget);
        expect(
          find.textContaining('Innova  ·  KL 11 AB 1234  ·  7 seats'),
          findsOneWidget,
        );
        expect(
          find.text('${_t(_start1)}–${_t(_end1)}   BK-1  Asha'),
          findsNWidgets(2),
          reason: 'on Innova and on Ravi',
        );
        expect(
          find.text('Free all day'),
          findsNWidgets(2),
          reason: 'Tempo and Mani',
        );
        expect(find.text('Dzire is under service'), findsOneWidget);
        expect(find.text('BK-1 and BK-2 are at the same time'), findsOneWidget);
        expect(find.text('Insurance was due on 2026-10-12'), findsOneWidget);
        expect(find.byKey(const Key('availability_busy')), findsNWidgets(2));
        expect(
          find.byKey(const Key('availability_unavailable')),
          findsOneWidget,
        );
      },
    );

    testWidgets('the next / previous day ask the server for that day', (
      t,
    ) async {
      final asked = <String>[];
      _size(t);
      await t.pumpWidget(app(asked));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('boardNext')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('boardPrev')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('boardPrev')));
      await t.pumpAndSettle();
      expect(asked, ['2026-10-30', '2026-10-31', '2026-10-30', '2026-10-29']);
      expect(find.text('Thu, 29 Oct 2026'), findsOneWidget);
    });

    testWidgets(
      'a server failure shows a plain error with a retry, not a blank board',
      (t) async {
        _size(t);
        await t.pumpWidget(app([], fail: true));
        await t.pumpAndSettle();
        expect(find.byKey(const Key('boardSummary')), findsNothing);
        expect(find.byType(AppErrorView), findsOneWidget);
      },
    );

    testWidgets('on a phone it fits', (t) async {
      final errors = <String>[];
      final previous = FlutterError.onError;
      FlutterError.onError = (d) =>
          errors.add(d.toDiagnosticsNode().toStringDeep());
      try {
        _size(t, w: 360, h: 1800);
        await t.pumpWidget(app([]));
        await t.pumpAndSettle();
      } finally {
        FlutterError.onError = previous;
      }
      expect(find.byKey(const Key('boardSummary')), findsOneWidget);
      expect(errors.where((e) => e.contains('fleet_board.dart')), isEmpty);
    });
  });

  group('the assignments screen', () {
    final drivers = [
      for (final (id, name) in [
        ('d1', 'Ravi'),
        ('d2', 'Suresh'),
        ('d3', 'Mani'),
      ])
        Employee.fromJson({
          '_id': id,
          'name': name,
          'artistRole': 'driver',
          'status': 'active',
        }),
    ];
    final vehicles = [
      Vehicle.fromJson({
        '_id': 'v1',
        'name': 'Innova',
        'registrationNumber': 'KL 11 AB 1234',
        'fuelType': 'petrol',
        'status': 'running',
      }),
      Vehicle.fromJson({
        '_id': 'v2',
        'name': 'Tempo',
        'registrationNumber': 'KL 11 CD 5678',
        'fuelType': 'diesel',
        'status': 'running',
      }),
    ];

    Widget screen(_FakeBookings store, {bool availabilityFails = false}) =>
        ProviderScope(
          overrides: <Override>[
            bookingProvider.overrideWith(() => store),
            employeesProvider.overrideWith((ref) async => drivers),
            vehiclesProvider.overrideWith((ref) async => vehicles),
            bookingAvailabilityProvider.overrideWith((ref, id) async {
              if (availabilityFails) throw Exception('server down');
              return _availability();
            }),
            fleetBoardProvider.overrideWith(
              (ref, day) async => FleetBoard(day: day),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const Scaffold(body: FleetAssignmentsScreen()),
          ),
        );

    Future<void> pick(WidgetTester t, String label, String itemText) async {
      await t.tap(find.widgetWithText(DropdownButtonFormField<String>, label));
      await t.pumpAndSettle();
      await t.tap(find.textContaining(itemText).last);
      await t.pumpAndSettle();
    }

    Future<void> open(
      WidgetTester t,
      _FakeBookings store, {
      bool availabilityFails = false,
    }) async {
      _size(t, h: 3200);
      await t.pumpWidget(screen(store, availabilityFails: availabilityFails));
      await t.pumpAndSettle();
    }

    testWidgets(
      'the driver picker marks each driver: busy, unavailable, free',
      (t) async {
        await open(t, _FakeBookings([_booking()]));
        await t.tap(
          find.widgetWithText(DropdownButtonFormField<String>, 'Driver'),
        );
        await t.pumpAndSettle();
        expect(find.byKey(const Key('availability_busy')), findsOneWidget);
        expect(
          find.byKey(const Key('availability_unavailable')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('availability_free')), findsOneWidget);
      },
    );

    testWidgets('choosing a busy driver says why, right under the picker', (
      t,
    ) async {
      await open(t, _FakeBookings([_booking()]));
      await pick(t, 'Driver', 'Ravi');
      expect(find.byKey(const Key('availabilityNote_d1')), findsOneWidget);
      expect(find.textContaining('Already on BK-12 · Beena'), findsOneWidget);
    });

    testWidgets(
      'the vehicle picker is marked too, with a tight gap and an overdue paper',
      (t) async {
        await open(t, _FakeBookings([_booking()]));
        await pick(t, 'Vehicle', 'Innova');
        expect(find.byKey(const Key('availabilityNote_v1')), findsOneWidget);
        expect(find.textContaining('Only 30 min from BK-12'), findsOneWidget);
        expect(find.textContaining('Insurance was due'), findsOneWidget);
      },
    );

    testWidgets(
      'if the check cannot be loaded, the pickers simply have no marks',
      (t) async {
        await open(t, _FakeBookings([_booking()]), availabilityFails: true);
        await pick(t, 'Driver', 'Ravi');
        expect(find.byKey(const Key('availabilityNote_d1')), findsNothing);
        expect(find.byType(AvailabilityPill), findsNothing);
      },
    );

    testWidgets('a free driver saves with no question', (t) async {
      final store = _FakeBookings([_booking()]);
      await open(t, store);
      await pick(t, 'Driver', 'Mani');
      await t.tap(find.text('Save Transport Allocation'));
      await t.pumpAndSettle();
      expect(store.calls.map((c) => (c.driverId, c.confirm)), [('d3', false)]);
      expect(find.byKey(const Key('fleetConflictDialog')), findsNothing);
      expect(
        find.text('Transport assignment updated successfully.'),
        findsOneWidget,
      );
    });

    testWidgets(
      'a clash: the question appears; "Assign anyway" saves with confirmation and the usual success note',
      (t) async {
        final store = _FakeBookings([
          _booking(),
        ], script: (confirm) => confirm ? null : _conflictError());
        await open(t, store);
        await pick(t, 'Driver', 'Ravi');
        await t.tap(find.text('Save Transport Allocation'));
        await t.pump();
        // the Save button spins behind the dialog, so the frame never goes quiet
        await t.pump(const Duration(milliseconds: 300));
        expect(find.byKey(const Key('fleetConflictDialog')), findsOneWidget);
        await t.tap(find.byKey(const Key('fleetConflictAssign')));
        await t.pumpAndSettle();
        expect(store.calls.map((c) => (c.driverId, c.confirm)), [
          ('d1', false),
          ('d1', true),
        ]);
        expect(
          find.text('Transport assignment updated successfully.'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'declining leaves nothing assigned: no success note, no error, and the button is usable again',
      (t) async {
        final store = _FakeBookings([
          _booking(),
        ], script: (confirm) => confirm ? null : _conflictError());
        await open(t, store);
        await pick(t, 'Driver', 'Ravi');
        await t.tap(find.text('Save Transport Allocation'));
        await t.pump();
        await t.pump(const Duration(milliseconds: 300));
        await t.tap(find.byKey(const Key('fleetConflictCancel')));
        await t.pumpAndSettle();
        expect(store.calls, hasLength(1));
        expect(
          find.text('Transport assignment updated successfully.'),
          findsNothing,
        );
        expect(
          find.byType(CircularProgressIndicator),
          findsNothing,
          reason: 'not stuck saving',
        );
        await t.tap(find.text('Save Transport Allocation'));
        await t.pump();
        await t.pump(const Duration(milliseconds: 300));
        expect(store.calls, hasLength(2), reason: 'it can be tried again');
        expect(
          find.byKey(const Key('fleetConflictDialog')),
          findsOneWidget,
          reason: 'and asks again',
        );
        await t.tap(find.byKey(const Key('fleetConflictCancel')));
        await t.pumpAndSettle();
      },
    );

    testWidgets('a different failure shows its own message, with no question', (
      t,
    ) async {
      final store = _FakeBookings([
        _booking(),
      ], script: (_) => _conflictError(status: 500));
      await open(t, store);
      await pick(t, 'Driver', 'Mani');
      await t.tap(find.text('Save Transport Allocation'));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('fleetConflictDialog')), findsNothing);
      expect(
        find.text('Transport assignment updated successfully.'),
        findsNothing,
      );
    });

    testWidgets('"Who is free" opens the board for that booking\'s day', (
      t,
    ) async {
      await open(t, _FakeBookings([_booking()]));
      await t.tap(find.byKey(const Key('whoIsFreeButton')));
      await t.pumpAndSettle();
      expect(find.text('Who is free'), findsWidgets);
      expect(find.byKey(const Key('boardDay')), findsOneWidget);
      expect(find.text('Fri, 30 Oct 2026'), findsOneWidget);
    });
  });
}
