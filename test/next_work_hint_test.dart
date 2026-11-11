import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/models/auth_session.dart';
import 'package:nizan_crm/core/models/trial.dart';
import 'package:nizan_crm/core/providers/auth_provider.dart';
import 'package:nizan_crm/core/providers/trial_provider.dart';
import 'package:nizan_crm/core/theme/app_theme.dart';
import 'package:nizan_crm/features/bookings/controllers/booking_provider.dart';
import 'package:nizan_crm/features/bookings/controllers/next_work_provider.dart';
import 'package:nizan_crm/features/bookings/data/booking.dart';
import 'package:nizan_crm/features/bookings/data/next_work_hint.dart';
import 'package:nizan_crm/features/bookings/presentation/widgets/next_work_strip.dart';
import 'package:nizan_crm/features/bookings/services/booking_service.dart';
import 'package:nizan_crm/presentation/screens/artist_works_screen.dart';

// An artist with several works in a day goes from one venue straight to the next, so
// each of their work cards says which work is next and how far it is.

Map<String, dynamic> _next({Object? km = 20, int minutes = 40, bool approximate = false, String mapUrl = '11.2, 75.8', String place = 'Mavoor Rd, Calicut'}) => {
      'bookingId': 'b2',
      'bookingNumber': 'BK-2',
      'customerName': 'Beena',
      'service': 'Bridal',
      'serviceStart': '2026-10-30T07:30:00.000Z', // 1:00 PM IST
      'serviceEnd': '2026-10-30T10:30:00.000Z', // 4:00 PM IST
      'place': place,
      'mapUrl': mapUrl,
      'km': km,
      'durationMin': minutes,
      'approximate': approximate,
    };

NextWorkHint _hint({int position = 1, int total = 3, Map<String, dynamic>? next, bool last = false}) => NextWorkHint.fromJson({
      'dayKey': '2026-10-30',
      'position': position,
      'total': total,
      'next': last ? null : (next ?? _next()),
    });

class _Capture implements HttpClientAdapter {
  RequestOptions? last;
  int calls = 0;
  final Object body;
  final int status;
  _Capture(this.body, {this.status = 200});

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    last = options;
    calls++;
    return ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

Widget _strip(NextWorkHint hint, {bool ready = true, ValueChanged<String>? onMap, String day = 'today'}) => MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(body: Padding(padding: const EdgeInsets.all(16), child: NextWorkStrip(hint: hint, distanceReady: ready, dayLabel: day, onOpenMap: onMap))),
    );

void main() {
  group('parsing', () {
    test('a full hint', () {
      final h = _hint(position: 2, total: 3);
      expect((h.dayKey, h.position, h.total, h.isMultiWorkDay, h.isLast), ('2026-10-30', 2, 3, true, false));
      final n = h.next!;
      expect((n.bookingId, n.customerName, n.km, n.durationMin, n.approximate), ('b2', 'Beena', 20.0, 40, false));
      expect(n.serviceStart, isNotNull);
      expect(n.mapUrl, '11.2, 75.8');
    });

    test('the last work of a day has no next; a single work is not a multi-work day', () {
      expect(_hint(position: 3, total: 3, last: true).isLast, isTrue);
      final solo = NextWorkHint.fromJson({'dayKey': 'd', 'position': 1, 'total': 1, 'next': null});
      expect((solo.isMultiWorkDay, solo.isLast), (false, false));
    });

    test('a distance that could not be measured is null, and ints are fine', () {
      expect(NextWork.fromJson(_next(km: null)).km, isNull);
      expect(NextWork.fromJson(_next(km: 12)).km, 12.0);
    });

    test('a sparse payload never throws', () {
      final n = NextWork.fromJson({});
      expect((n.customerName, n.km, n.durationMin, n.mapUrl, n.serviceStart), ('', null, 0, '', null));
      final h = NextWorkHint.fromJson({});
      expect((h.position, h.total, h.next), (1, 1, null));
    });

    test('the whole response; distance "not ready" is only false when the server says so', () {
      final r = NextWorkHints.fromJson({
        'distanceReady': false,
        'hints': {'b1': {'dayKey': 'd', 'position': 1, 'total': 2, 'next': _next()}},
      });
      expect(r.distanceReady, isFalse);
      expect(r.byBooking.keys.toList(), ['b1']);
      expect(NextWorkHints.fromJson({}).distanceReady, isTrue);
      expect(NextWorkHints.fromJson({}).byBooking, isEmpty);
    });
  });

  group('service + provider', () {
    test('GET /bookings/next-work with the ids, parsed into hints', () async {
      final cap = _Capture({'distanceReady': true, 'hints': {'b1': {'dayKey': 'd', 'position': 1, 'total': 2, 'next': _next()}}});
      final r = await BookingService(Dio()..httpClientAdapter = cap).getNextWorkHints(['b1', 'b2']);
      expect(cap.last!.path, '/bookings/next-work');
      expect(cap.last!.queryParameters, {'ids': 'b1,b2'});
      expect(r.byBooking['b1']!.next!.customerName, 'Beena');
    });

    test('no ids: no request at all', () async {
      final cap = _Capture({});
      final r = await BookingService(Dio()..httpClientAdapter = cap).getNextWorkHints([]);
      expect(cap.calls, 0);
      expect(r.byBooking, isEmpty);
    });

    test('a failed request is a friendly AppException', () async {
      final cap = _Capture({'message': 'boom'}, status: 500);
      await expectLater(BookingService(Dio()..httpClientAdapter = cap).getNextWorkHints(['b1']), throwsA(isA<AppException>()));
    });

    test('the family key is the same for the same works in any order, and ignores repeats', () {
      expect(nextWorkKey(['b2', 'b1', 'b2']), 'b1,b2');
      expect(nextWorkKey(['b1', 'b2']), nextWorkKey(['b2', 'b1']));
      expect(nextWorkKey([]), '');
    });

    test('the provider asks for exactly the ids in its key', () async {
      final cap = _Capture({'distanceReady': true, 'hints': <String, dynamic>{}});
      final container = ProviderContainer(overrides: [bookingServiceProvider.overrideWithValue(BookingService(Dio()..httpClientAdapter = cap))]);
      addTearDown(container.dispose);
      await container.read(nextWorkHintsProvider('a,b').future);
      expect(cap.last!.queryParameters, {'ids': 'a,b'});
    });
  });

  group('the strip', () {
    testWidgets('first of three: the position, the next work with its times, the distance and time', (t) async {
      await t.pumpWidget(_strip(_hint(position: 1, total: 3)));
      expect(find.text('WORK 1 OF 3 TODAY'), findsOneWidget);
      expect(find.textContaining('Beena'), findsOneWidget);
      expect(find.textContaining('1:00 PM – 4:00 PM'), findsOneWidget);
      expect(find.text('20 km · 40 min'), findsOneWidget);
    });

    testWidgets('the day is named when it is not today', (t) async {
      await t.pumpWidget(_strip(_hint(), day: 'on 30 Oct 2026'));
      expect(find.text('WORK 1 OF 3 ON 30 OCT 2026'), findsOneWidget);
    });

    testWidgets('a decimal distance and an hour-plus drive read naturally', (t) async {
      await t.pumpWidget(_strip(_hint(next: _next(km: 3.4, minutes: 75))));
      expect(find.text('3.4 km · 1 h 15 min'), findsOneWidget);
    });

    testWidgets('a distance to a pincode-only venue is called approximate', (t) async {
      await t.pumpWidget(_strip(_hint(next: _next(km: 18.2, minutes: 35, approximate: true))));
      expect(find.text('About 18.2 km · about 35 min'), findsOneWidget);
    });

    testWidgets('same place: 0 km is shown, not hidden', (t) async {
      await t.pumpWidget(_strip(_hint(next: _next(km: 0, minutes: 0))));
      expect(find.text('0 km'), findsOneWidget);
    });

    testWidgets('a distance that could not be measured says why, but still names the next work', (t) async {
      await t.pumpWidget(_strip(_hint(next: _next(km: null))));
      expect(find.textContaining('Beena'), findsOneWidget);
      expect(find.text('Distance not available — the venue location is missing'), findsOneWidget);
    });

    testWidgets('no distance service on the server: the next work, and no distance line at all', (t) async {
      await t.pumpWidget(_strip(_hint(next: _next(km: null)), ready: false));
      expect(find.textContaining('Beena'), findsOneWidget);
      expect(find.byKey(const Key('nextWorkDistance')), findsNothing);
    });

    testWidgets('the last work of the day has no next and no distance', (t) async {
      await t.pumpWidget(_strip(_hint(position: 3, total: 3, last: true)));
      expect(find.text('WORK 3 OF 3 TODAY'), findsOneWidget);
      expect(find.text('Last work of the day'), findsOneWidget);
      expect(find.byKey(const Key('nextWorkDistance')), findsNothing);
      expect(find.byKey(const Key('nextWorkMap')), findsNothing);
    });

    testWidgets('a day with one work shows nothing', (t) async {
      await t.pumpWidget(_strip(NextWorkHint.fromJson({'dayKey': 'd', 'position': 1, 'total': 1, 'next': null})));
      expect(find.byKey(const Key('nextWorkStrip')), findsNothing);
    });

    testWidgets('the Map button opens the next work\'s saved map link (coordinates become a map search)', (t) async {
      final opened = <String>[];
      await t.pumpWidget(_strip(_hint(), onMap: opened.add));
      await t.tap(find.byKey(const Key('nextWorkMap')));
      expect(opened.single, 'https://www.google.com/maps/search/?api=1&query=11.2%2C75.8');
    });

    testWidgets('a full link is opened as it is; with no map link the address is searched; with neither there is no button', (t) async {
      final opened = <String>[];
      await t.pumpWidget(_strip(_hint(next: _next(mapUrl: 'https://maps.app.goo.gl/abc')), onMap: opened.add));
      await t.tap(find.byKey(const Key('nextWorkMap')));
      expect(opened.last, 'https://maps.app.goo.gl/abc');

      await t.pumpWidget(_strip(_hint(next: _next(mapUrl: '', place: 'Mavoor Rd, Calicut')), onMap: opened.add));
      await t.pump();
      await t.tap(find.byKey(const Key('nextWorkMap')));
      expect(opened.last, 'https://www.google.com/maps/search/?api=1&query=Mavoor+Rd%2C+Calicut');

      await t.pumpWidget(_strip(_hint(next: _next(mapUrl: '', place: '')), onMap: opened.add));
      await t.pump();
      expect(find.byKey(const Key('nextWorkMap')), findsNothing);
    });

    testWidgets('it fits a phone (320px) with a long client name and a long address', (t) async {
      t.view.physicalSize = const Size(320, 800);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final n = _next();
      n['customerName'] = 'Mohammed Abdul Rahman Kunhimon Haji Thekkepurayil';
      await t.pumpWidget(_strip(_hint(next: n), onMap: (_) {}));
      expect(t.takeException(), isNull);
    });
  });

  group('on the artist\'s works screen', () {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    Booking booking(String id, String client, DateTime day, int hour) => Booking(
          id: id,
          customerName: client,
          phone: '9895499872',
          service: 'Bridal',
          bookingDate: DateTime(day.year, day.month, day.day, hour),
          serviceStart: DateTime(day.year, day.month, day.day, hour),
          serviceEnd: DateTime(day.year, day.month, day.day, hour + 3),
          totalPrice: 24500,
          advanceAmount: 3000,
          createdAt: now,
        );

    PaginatedBookingsResponse page(List<Booking> items) => PaginatedBookingsResponse(
          items: items,
          page: 1,
          limit: 10,
          totalItems: items.length,
          totalPages: 1,
          summary: const BookingPageSummary(),
        );

    final asked = <String>[];

    Future<void> open(
      WidgetTester t, {
      required List<Booking> upcoming,
      required Future<NextWorkHints> Function(String key) hints,
    }) async {
      asked.clear();
      t.view.physicalSize = const Size(800, 3000);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(ProviderScope(
        overrides: [
          authSessionProvider.overrideWithValue(const AuthSession(token: 't', userId: 'u', name: 'Anu', email: 'a@x', role: 'artist', employeeId: 'e1')),
          paginatedBookingsProvider.overrideWith((ref, params) async => page(params.status == 'upcoming' ? upcoming : const <Booking>[])),
          artistTrialsProvider.overrideWith((ref) async => <Trial>[]),
          nextWorkHintsProvider.overrideWith((ref, key) {
            asked.add(key);
            return hints(key);
          }),
        ],
        child: MaterialApp(theme: AppTheme.lightTheme, home: const ArtistWorksScreen()),
      ));
      await t.pumpAndSettle();
    }

    testWidgets('each card on a multi-work day names the next work and how far it is; the last one says it is last', (t) async {
      await open(
        t,
        upcoming: [booking('b1', 'Asha', today, 8), booking('b2', 'Beena', today, 13), booking('b3', 'Chitra', today, 18)],
        hints: (key) async => NextWorkHints.fromJson({
          'distanceReady': true,
          'hints': {
            'b1': {'dayKey': 'd', 'position': 1, 'total': 3, 'next': _next()},
            'b2': {'dayKey': 'd', 'position': 2, 'total': 3, 'next': {..._next(km: 30, minutes: 60), 'customerName': 'Chitra'}},
            'b3': {'dayKey': 'd', 'position': 3, 'total': 3, 'next': null},
          },
        }),
      );
      expect(asked, ['b1,b2,b3'], reason: 'one request for the whole screen, the ids in a stable order');
      expect(find.text('WORK 1 OF 3 TODAY'), findsOneWidget);
      expect(find.text('WORK 2 OF 3 TODAY'), findsOneWidget);
      expect(find.text('20 km · 40 min'), findsOneWidget);
      expect(find.text('30 km · 1 h'), findsOneWidget);
      expect(find.text('Last work of the day'), findsOneWidget);
      expect(find.text('Asha'), findsOneWidget, reason: 'the works themselves are still all there');
      expect(find.text('Chitra'), findsOneWidget);
    });

    testWidgets('a work that is alone that day gets no strip', (t) async {
      await open(
        t,
        upcoming: [booking('b1', 'Asha', today, 8)],
        hints: (key) async => NextWorkHints.fromJson({
          'distanceReady': true,
          'hints': {'b1': {'dayKey': 'd', 'position': 1, 'total': 1, 'next': null}},
        }),
      );
      expect(find.text('Asha'), findsOneWidget);
      expect(find.byKey(const Key('nextWorkStrip')), findsNothing);
    });

    testWidgets('upcoming days are counted per day, and named', (t) async {
      final later = today.add(const Duration(days: 3));
      await open(
        t,
        upcoming: [booking('b1', 'Asha', later, 8), booking('b2', 'Beena', later, 13)],
        hints: (key) async => NextWorkHints.fromJson({
          'distanceReady': true,
          'hints': {
            'b1': {'dayKey': 'd', 'position': 1, 'total': 2, 'next': _next()},
            'b2': {'dayKey': 'd', 'position': 2, 'total': 2, 'next': null},
          },
        }),
      );
      expect(find.textContaining('WORK 1 OF 2 ON '), findsOneWidget);
      expect(find.text('20 km · 40 min'), findsOneWidget);
    });

    testWidgets('if the hints cannot be loaded the works list is exactly as before', (t) async {
      await open(
        t,
        upcoming: [booking('b1', 'Asha', today, 8), booking('b2', 'Beena', today, 13)],
        hints: (key) async => throw Exception('map service down'),
      );
      expect(find.text('Asha'), findsOneWidget);
      expect(find.text('Beena'), findsOneWidget);
      expect(find.byKey(const Key('nextWorkStrip')), findsNothing);
      expect(find.text('Try again'), findsNothing, reason: 'a missing hint is not an error the artist needs to see');
    });
  });
}
