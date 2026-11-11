import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:nizan_crm/core/theme/app_theme.dart';
import 'package:nizan_crm/features/consultations/controllers/consultation_provider.dart';
import 'package:nizan_crm/features/consultations/data/consultation.dart';
import 'package:nizan_crm/features/consultations/data/stylist_client.dart';
import 'package:nizan_crm/features/consultations/presentation/screens/stylist_client_form_screen.dart';
import 'package:nizan_crm/features/consultations/presentation/screens/stylist_client_screen.dart';
import 'package:nizan_crm/features/consultations/presentation/screens/stylist_clients_screen.dart';
import 'package:nizan_crm/features/consultations/presentation/widgets/consultation_ui.dart';
import 'package:nizan_crm/features/consultations/presentation/widgets/reference_images.dart';
import 'package:nizan_crm/features/consultations/presentation/widgets/stylist_client_ui.dart';

String _iso(DateTime d) => d.toUtc().toIso8601String();
final _now = DateTime.now();
String _day(int fromToday) => dayKey(DateTime(_now.year, _now.month, _now.day).add(Duration(days: fromToday)));

Map<String, dynamic> _clientJson({
  String id = 'c1',
  String name = 'Anjali Menon',
  String company = 'Team N',
  int done = 1,
  int booked = 1,
  bool withCalls = false,
}) =>
    {
      '_id': id,
      'clientNo': 'SC-261105-4821',
      'company': company,
      'leadId': company == 'Team N' ? 'l1' : null,
      'syncedAt': company == 'Team N' ? _iso(_now) : null,
      'name': name,
      'phone': '9876543210',
      'eventType': 'Wedding',
      'eventDates': [_day(10), _day(11)],
      'eventSlot': 'Morning',
      'venue': 'Le Méridien, Kochi',
      'culture': 'Hindu',
      'packageName': 'Bridal premium',
      'bookingNumber': company == 'Team N' ? 'NB-1234' : '',
      'artistNames': ['Asha', 'Bina'],
      'outfitDetails': 'Red Kanjivaram, temple jewellery',
      'notes': 'Prefers evening calls',
      'stylistId': {'_id': 's1', 'name': 'Priya'},
      'status': 'Active',
      'requiredCalls': 4,
      'progress': {
        'done': done,
        'required': 4,
        'booked': booked,
        'nextCallAt': booked > 0 ? _iso(_now.add(const Duration(days: 2))) : null,
        'nextCallId': booked > 0 ? 'k2' : null,
      },
      if (withCalls) ...{
        'calls': [
          _call('k1', 1, 'Completed', _now.subtract(const Duration(days: 5))),
          _call('k2', 2, 'Scheduled', _now.add(const Duration(days: 2))),
          _call('kx', null, 'Cancelled', _now.subtract(const Duration(days: 3))),
        ],
        'images': [
          {'_id': 'i1', 'url': 'https://res.cloudinary.com/demo/image/upload/v1/a.jpg', 'caption': 'Saree', 'callNumber': 1},
          {'_id': 'i2', 'url': 'https://res.cloudinary.com/demo/image/upload/v1/b.jpg', 'callNumber': 1},
        ],
      },
    };

Map<String, dynamic> _call(String id, int? n, String status, DateTime at) => {
      '_id': id,
      'consultationNo': 'CN-$id',
      'clientId': {'_id': 'c1', 'name': 'Anjali Menon', 'company': 'Team N', 'requiredCalls': 4},
      'callNumber': n,
      'stylistId': {'_id': 's1', 'name': 'Priya'},
      'scheduledAt': _iso(at),
      'endsAt': _iso(at.add(const Duration(minutes: 45))),
      'durationMins': 45,
      'status': status,
      'mode': 'Video',
    };

Future<void> _pump(WidgetTester tester, Widget screen, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        stylistClientsProvider.overrideWith(
          (ref, q) async => [
            StylistClient.fromJson(_clientJson()),
            StylistClient.fromJson(_clientJson(id: 'c2', name: 'Riya Joseph', company: 'Nizan', done: 0, booked: 0)),
          ],
        ),
        stylistClientProvider.overrideWith((ref, id) async => StylistClient.fromJson(_clientJson(withCalls: true))),
        consultationStylistsProvider.overrideWith(
          (ref) async => const [ConsultationStylist(id: 's1', name: 'Priya', role: 'stylist')],
        ),
      ],
      child: MaterialApp(theme: AppTheme.lightTheme, home: screen),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final entry in {'desktop': const Size(1440, 2000), 'phone': const Size(390, 2400)}.entries) {
    final desktop = entry.key == 'desktop';
    group('on ${entry.key}', () {
      testWidgets('My clients lists both companies with their call progress', (tester) async {
        await _pump(tester, const StylistClientsScreen(), entry.value);
        expect(tester.takeException(), isNull);
        expect(find.text('My clients'), findsOneWidget);
        expect(find.text('2 active'), findsOneWidget);
        expect(find.text('Anjali Menon'), findsOneWidget);
        expect(find.text('Riya Joseph'), findsOneWidget);
        expect(find.widgetWithText(CompanyTag, 'Team N'), findsOneWidget);
        expect(find.widgetWithText(CompanyTag, 'Nizan'), findsOneWidget);
        expect(find.text('1/4'), findsOneWidget);
        expect(find.text('0/4'), findsOneWidget);
        // Riya has nothing booked; Anjali's next call is shown.
        expect(find.text(desktop ? 'No call booked' : 'No call'), findsOneWidget);
        final next = _now.add(const Duration(days: 2));
        expect(
          find.text(desktop ? DateFormat('EEE d MMM, h:mm a').format(next) : 'Next ${fmtShortDay(next)}'),
          findsOneWidget,
        );
        expect(find.textContaining('in 10 days', findRichText: true), findsNWidgets(2));
        expect(find.text('New client'), findsOneWidget);
        expect(find.text('Active'), findsOneWidget); // status switch
      });

      if (desktop) {
        testWidgets('desktop shows one filter bar over a table', (tester) async {
          await _pump(tester, const StylistClientsScreen(), entry.value);
          for (final h in ['Client', 'Event', 'Calls', 'Next call']) {
            expect(find.text(h), findsOneWidget, reason: h);
          }
          expect(find.text('Stylist'), findsNothing); // a stylist sees only their own
          expect(find.text('Both'), findsOneWidget);
          expect(find.text('Sort: Event soonest'), findsOneWidget);
          expect(find.text('Cancelled'), findsOneWidget);
        });
      } else {
        testWidgets('phone keeps company and sort behind Filters', (tester) async {
          await _pump(tester, const StylistClientsScreen(), entry.value);
          expect(find.text('Sort: Event soonest'), findsNothing);
          expect(find.text('Done'), findsOneWidget); // short label for Completed
          await tester.tap(find.byTooltip('Filters'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.text('Company'), findsOneWidget);
          expect(find.text('Event soonest'), findsOneWidget);
          await tester.tap(find.widgetWithText(ChoiceChip, 'Nizan'));
          await tester.pumpAndSettle();
          await tester.tap(find.widgetWithText(FilledButton, 'Done'));
          await tester.pumpAndSettle();
          expect(find.text('Company'), findsNothing);
        });
      }

      testWidgets('client page shows labelled actions, the call slots and details', (tester) async {
        await _pump(tester, const StylistClientScreen(clientId: 'c1'), entry.value);
        expect(tester.takeException(), isNull);
        expect(find.text('Anjali Menon'), findsWidgets);
        expect(find.text('Client no. SC-261105-4821'), findsOneWidget);
        expect(find.widgetWithText(CompanyTag, 'Team N'), findsOneWidget);
        expect(find.textContaining('Wedding in 10 days'), findsOneWidget);
        // Calls 1 and 2 are booked, so the main button books call 3.
        expect(find.widgetWithText(FilledButton, 'Schedule call 3'), findsOneWidget);
        expect(find.text(desktop ? 'Report PDF' : 'Report'), findsOneWidget);
        if (desktop) {
          expect(find.text('Call'), findsOneWidget);
          expect(find.text('WhatsApp'), findsOneWidget);
        } else {
          expect(find.byTooltip('Call'), findsOneWidget);
          expect(find.byTooltip('WhatsApp'), findsOneWidget);
        }

        // Call series.
        expect(find.text('1 of 4 done'), findsOneWidget);
        for (final n in [1, 2, 3, 4]) {
          expect(find.textContaining('Call $n', findRichText: true), findsWidgets, reason: 'Call $n');
        }
        expect(find.textContaining('Not booked', findRichText: true), findsNWidgets(2));
        expect(find.textContaining('Not counted: 1 cancelled or no-show'), findsOneWidget);
        await tester.tap(find.textContaining('Not counted'));
        await tester.pumpAndSettle();
        expect(find.textContaining('Cancelled  ·', findRichText: true), findsOneWidget);

        // Details and images: open on desktop, closed on a phone.
        expect(find.textContaining('From booking'), findsOneWidget);
        if (!desktop) {
          expect(find.text('Bridal premium'), findsNothing);
          expect(find.byType(ReferenceImageGrid), findsNothing);
          await tester.ensureVisible(find.text('Details'));
          await tester.tap(find.text('Details'));
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.text('Reference images · 2'));
          await tester.tap(find.text('Reference images · 2'));
          await tester.pumpAndSettle();
        }
        expect(tester.takeException(), isNull);
        expect(find.text('CONTACT'), findsOneWidget);
        expect(find.text('Bridal premium'), findsOneWidget);
        expect(find.text('Asha, Bina'), findsOneWidget);
        expect(find.text('Red Kanjivaram, temple jewellery'), findsOneWidget);
        expect(find.byType(ReferenceImageGrid), findsOneWidget);
      });

      testWidgets('client page keeps edit, refresh and status in More', (tester) async {
        await _pump(tester, const StylistClientScreen(clientId: 'c1'), entry.value);
        expect(find.text('Edit details'), findsNothing);
        await tester.tap(find.text('More'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('Edit details'), findsOneWidget);
        expect(find.text('Refresh from booking'), findsOneWidget);
        expect(find.text('Mark client completed'), findsOneWidget);
        expect(find.text('Cancel client'), findsOneWidget);
        expect(find.text('Reopen client'), findsNothing); // already active
      });

      testWidgets('new client: Team N searches, Nizan asks for the details', (tester) async {
        await _pump(tester, const StylistClientFormScreen(), entry.value);
        expect(tester.takeException(), isNull);
        expect(find.text('Find the Team N client'), findsOneWidget);
        expect(find.text('Name, phone or booking number'), findsOneWidget);
        expect(find.text('Required calls'), findsOneWidget);
        expect(find.text('4'), findsOneWidget);

        await tester.tap(find.text('Nizan'));
        await tester.pumpAndSettle();
        expect(find.text('Name *'), findsOneWidget);
        expect(find.text('Phone *'), findsOneWidget);
        expect(find.text('Event dates'), findsOneWidget);
        expect(find.text('Outfit details'), findsOneWidget);

        // Saving with nothing typed shows what's missing and sends nothing.
        await tester.tap(find.text('Add client'));
        await tester.pumpAndSettle();
        expect(find.text('Enter the name'), findsOneWidget);
        expect(find.text('Enter the phone'), findsOneWidget);
      });

      testWidgets('editing a Team N client explains the booking refresh', (tester) async {
        await _pump(tester, const StylistClientFormScreen(clientId: 'c1'), entry.value);
        expect(tester.takeException(), isNull);
        expect(find.text('Edit Anjali Menon'), findsOneWidget);
        expect(find.textContaining('came from the Team N booking'), findsOneWidget);
        expect(find.text('Anjali Menon'), findsOneWidget); // prefilled name field
        expect(find.text('Save'), findsOneWidget);
      });
    });
  }

  group('client model and formatting', () {
    test('a client file parses with progress, calls and images', () {
      final c = StylistClient.fromJson(_clientJson(withCalls: true));
      expect(c.isTeamN, isTrue);
      expect(c.stylistName, 'Priya');
      expect(c.eventDays.length, 2);
      expect(c.daysToEvent, 10);
      expect(c.progress.done, 1);
      expect(c.calls.length, 3);
      expect(c.calls.first.callLabel, 'Call 1 of 4');
      expect(c.calls.last.callLabel, ''); // cancelled: not numbered
      expect(c.images.first.callNumber, 1);
      expect(c.toEditJson()['eventDates'], c.eventDates);
    });

    test('a call beyond the required ones is an extra call', () {
      final call = Consultation.fromJson(_call('k5', 5, 'Scheduled', _now));
      expect(call.callLabel, 'Extra call 5');
      expect(call.clientName, 'Anjali Menon');
    });

    test('event days read naturally', () {
      expect(fmtEventDays([DateTime(2026, 12, 14)]), '14 Dec 2026');
      expect(fmtEventDays([DateTime(2026, 12, 14), DateTime(2026, 12, 15)]), '14–15 Dec 2026');
      expect(fmtEventDays([DateTime(2026, 12, 31), DateTime(2027, 1, 1)]), '31 Dec 2026 – 1 Jan 2027');
      expect(fmtEventDays([DateTime(2026, 12, 14), DateTime(2026, 12, 16), DateTime(2026, 12, 20)]),
          '14, 16 and 20 Dec 2026');
      expect(fmtDaysToEvent(0), 'Today');
      expect(fmtDaysToEvent(1), 'Tomorrow');
      expect(fmtDaysToEvent(21), 'In 3 weeks');
    });
  });
}
