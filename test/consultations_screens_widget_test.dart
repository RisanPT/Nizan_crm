import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nizan_crm/core/theme/app_theme.dart';
import 'package:nizan_crm/features/consultations/controllers/consultation_provider.dart';
import 'package:nizan_crm/features/consultations/data/consultation.dart';
import 'package:nizan_crm/features/consultations/data/stylist_client.dart';
import 'package:nizan_crm/features/consultations/presentation/screens/after_call_form_screen.dart';
import 'package:nizan_crm/features/consultations/presentation/screens/consultation_detail_screen.dart';
import 'package:nizan_crm/features/consultations/presentation/widgets/consultation_ui.dart';
import 'package:nizan_crm/features/consultations/presentation/widgets/reference_images.dart';
import 'package:nizan_crm/features/consultations/presentation/screens/consultation_form_screen.dart';
import 'package:nizan_crm/features/consultations/presentation/screens/consultations_calendar_screen.dart';
import 'package:nizan_crm/features/consultations/presentation/screens/consultations_list_screen.dart';

Map<String, dynamic> _json(String id, String client, String status, DateTime start,
    {bool notes = false, String link = 'https://meet.google.com/abc-defg-hij', String company = 'Team N'}) {
  return {
    '_id': id,
    'clientId': {'_id': 'c$id', 'name': client, 'company': company, 'requiredCalls': 4},
    'callNumber': status == 'Cancelled' ? null : 1,
    'consultationNo': 'CN-261102-$id',
    'leadId': {
      '_id': 'l$id',
      'name': client,
      'phone': '9876543210',
      'eventType': 'Wedding',
      'eventDate': '2026-12-12T00:00:00.000Z',
      'location': 'Kochi',
    },
    'stylistId': {'_id': 's1', 'name': 'Asha'},
    'scheduledAt': start.toUtc().toIso8601String(),
    'endsAt': start.add(const Duration(minutes: 45)).toUtc().toIso8601String(),
    'durationMins': 45,
    'status': status,
    'mode': 'Video',
    'meetingProvider': 'Google Meet',
    'meetingLink': link,
    if (notes) ...{
      'notes': 'Likes soft glam',
      'preferences': 'Dewy base',
      'nextSteps': 'Trial next week',
      'conveyed': 'Suggested a nude palette',
      'lookHair': 'Low bun with jasmine',
      'referenceImages': [
        {'_id': 'i1', 'url': 'https://res.cloudinary.com/demo/image/upload/v1/a.jpg', 'caption': 'Saree colour'},
        {'_id': 'i2', 'url': 'https://res.cloudinary.com/demo/image/upload/v1/b.jpg'},
      ],
    },
    'history': [
      {'action': 'Scheduled', 'status': 'Scheduled', 'at': start.toUtc().toIso8601String(), 'byName': 'Asha'},
      {
        'action': 'Rescheduled',
        'status': 'Scheduled',
        'at': start.toUtc().toIso8601String(),
        'byName': 'Meera',
        'fromAt': start.toUtc().toIso8601String(),
        'toAt': start.add(const Duration(days: 1)).toUtc().toIso8601String(),
        'reason': 'Bride travelling',
      },
    ],
  };
}

final _now = DateTime.now();
final _today = DateTime(_now.year, _now.month, _now.day, 11);

List<Consultation> _items() => [
      Consultation.fromJson(_json('1', 'Anjali Menon', 'Scheduled', _today)),
      Consultation.fromJson(_json('2', 'Divya Nair', 'Completed', _today.add(const Duration(hours: 3)), company: 'Nizan')),
      Consultation.fromJson(_json('3', 'Meera Das', 'Cancelled', _today.add(const Duration(days: 1)))),
    ];

Future<void> _pump(WidgetTester tester, Widget screen, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        consultationsProvider.overrideWith((ref, q) async => _items()),
        consultationStylistsProvider.overrideWith(
          (ref) async => const [
            ConsultationStylist(id: 's1', name: 'Asha', role: 'stylist'),
            ConsultationStylist(id: 's2', name: 'Bina', role: 'stylist'),
          ],
        ),
        consultationProvider.overrideWith(
          (ref, id) async => Consultation.fromJson(
              _json(id, 'Anjali Menon', 'Scheduled', _today.add(const Duration(days: 1)), notes: true)),
        ),
        stylistClientsProvider.overrideWith(
          (ref, q) async => [
            StylistClient.fromJson(const {
              '_id': 'c9',
              'company': 'Nizan',
              'name': 'Riya Joseph',
              'phone': '9876543210',
              'eventType': 'Reception',
              'requiredCalls': 4,
              'progress': {'done': 1, 'required': 4, 'booked': 0},
            }),
          ],
        ),
        stylistClientProvider.overrideWith(
          (ref, id) async => StylistClient.fromJson({
            '_id': id,
            'company': 'Team N',
            'name': 'Anjali Menon',
            'phone': '9876543210',
            'eventType': 'Wedding',
            'requiredCalls': 4,
            'progress': {'done': 1, 'required': 4, 'booked': 0},
            'calls': [
              {
                '_id': 'k1',
                'callNumber': 1,
                'status': 'Completed',
                'scheduledAt': _today.subtract(const Duration(days: 3)).toUtc().toIso8601String(),
              },
            ],
          }),
        ),
        leadConsultationsProvider.overrideWith(
          (ref, id) async => LeadConsultations(
            lead: const ConsultationLead(id: 'l1', name: 'Anjali Menon', phone: '9876543210', eventType: 'Wedding'),
            derivedStatus: 'Consultation Scheduled',
            consultations: _items(),
          ),
        ),
      ],
      child: MaterialApp(theme: AppTheme.lightTheme, home: screen),
    ),
  );
  await tester.pumpAndSettle();
}

const _desktop = Size(1440, 2000);
const _phone = Size(390, 2200);

/// The call page alone, for one consultation's JSON.
Future<void> _pumpDetail(WidgetTester tester, Map<String, dynamic> json, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [consultationProvider.overrideWith((ref, id) async => Consultation.fromJson(json))],
      child: MaterialApp(theme: AppTheme.lightTheme, home: const ConsultationDetailScreen(consultationId: '1')),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final entry in {'desktop': _desktop, 'phone': _phone}.entries) {
    group('on ${entry.key}', () {
      testWidgets('calendar shows the month, the day agenda and hides cancelled', (tester) async {
        await _pump(tester, const ConsultationsCalendarScreen(), entry.value);
        expect(tester.takeException(), isNull);
        expect(find.text('Calendar'), findsOneWidget);
        // Today's agenda: both of today's calls, with their call number.
        expect(find.text('Anjali Menon'), findsOneWidget);
        expect(find.text('Divya Nair'), findsOneWidget);
        expect(find.textContaining('Call 1 of 4'), findsWidgets);
        expect(find.text('Meera Das'), findsNothing); // cancelled + different day
        expect(find.byTooltip('Schedule on this day'), findsOneWidget);
      });

      testWidgets('calendar filters by company', (tester) async {
        await _pump(tester, const ConsultationsCalendarScreen(), entry.value);
        if (entry.key == 'desktop') {
          // Desktop: the company switch sits in the filter line.
          await tester.tap(find.descendant(of: find.byType(SegmentedButton<String>), matching: find.text('Nizan')));
          await tester.pumpAndSettle();
        } else {
          // Phone: company lives behind the Filters button.
          await tester.tap(find.byTooltip('Filters'));
          await tester.pumpAndSettle();
          expect(find.text('Company'), findsOneWidget);
          await tester.tap(find.widgetWithText(ChoiceChip, 'Nizan'));
          await tester.pumpAndSettle();
          await tester.tap(find.widgetWithText(FilledButton, 'Done'));
          await tester.pumpAndSettle();
          expect(find.text('1'), findsWidgets); // one filter active on the badge
        }
        expect(tester.takeException(), isNull);
        expect(find.text('Divya Nair'), findsOneWidget);
        expect(find.text('Anjali Menon'), findsNothing);
      });

      testWidgets('calendar week view lists seven days', (tester) async {
        await _pump(tester, const ConsultationsCalendarScreen(), entry.value);
        await tester.tap(find.text('Week'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('Free'), findsWidgets);
        expect(find.text('Anjali Menon'), findsOneWidget);
      });

      testWidgets('calendar can open straight on the week', (tester) async {
        await _pump(tester, const ConsultationsCalendarScreen(initialView: 'week'), entry.value);
        expect(tester.takeException(), isNull);
        expect(find.text('Free'), findsWidgets);
        expect(find.text('List'), findsOneWidget); // Month / Week / List switch
      });

      testWidgets('the List switch stays on the Calendar page and groups calls by day', (tester) async {
        await _pump(tester, const ConsultationsCalendarScreen(), entry.value);
        expect(find.text('Client name or phone'), findsNothing);
        await tester.tap(find.text('List'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('Calendar'), findsOneWidget);
        expect(find.text('Client name or phone'), findsOneWidget); // search appears in List
        expect(find.textContaining('Today'), findsWidgets); // today's day heading (and the Today button)
        expect(find.text('Anjali Menon'), findsOneWidget);
        expect(find.text('Divya Nair'), findsOneWidget);
        expect(find.text('Meera Das'), findsNothing); // cancelled, hidden by default
        if (entry.key == 'desktop') {
          expect(find.text('Status: Any'), findsOneWidget);
          expect(find.textContaining('calls this month'), findsOneWidget);
        }
      });

      testWidgets('list screen shows consultations and filters by search', (tester) async {
        await _pump(tester, const ConsultationsListScreen(), entry.value);
        expect(tester.takeException(), isNull);
        // The list is a view of the Calendar page.
        expect(find.text('Calendar'), findsOneWidget);
        expect(find.text('Month'), findsOneWidget);
        expect(find.text('List'), findsOneWidget);
        expect(find.text('Anjali Menon'), findsOneWidget);
        expect(find.text('Divya Nair'), findsOneWidget);

        await tester.enterText(find.byType(TextField).first, 'divya');
        await tester.pumpAndSettle();
        expect(find.text('Anjali Menon'), findsNothing);
        expect(find.text('Divya Nair'), findsOneWidget);
      });

      testWidgets('detail shows client, meeting, notes and history', (tester) async {
        await _pump(tester, const ConsultationDetailScreen(consultationId: '1'), entry.value);
        expect(tester.takeException(), isNull);
        expect(find.text('Anjali Menon'), findsOneWidget); // the page title
        expect(find.textContaining('Call 1 of 4'), findsOneWidget); // title line
        // Link added, invite not sent: Share invite is the one main button.
        expect(find.widgetWithText(FilledButton, 'Share invite'), findsOneWidget);
        expect(find.text('This call ended. Record what was discussed, or mark a no-show.'), findsNothing);
        // Join sits beside it on desktop and in More on a phone.
        expect(find.text('Join call'), entry.key == 'desktop' ? findsOneWidget : findsNothing);
        expect(find.text('Reschedule'), findsNothing); // tucked into More
        expect(find.text('https://meet.google.com/abc-defg-hij'), findsOneWidget);
        expect(find.text('Call details'), findsOneWidget);
        expect(find.text('Likes soft glam'), findsOneWidget);
        expect(find.text('What we conveyed'), findsOneWidget);
        expect(find.text('Suggested a nude palette'), findsOneWidget);
        expect(find.text('Hairstyle'), findsOneWidget);
        // Empty sections are not shown on the call page.
        expect(find.text('Skin and allergy notes'), findsNothing);
        expect(find.text('Reference images (2)'), findsOneWidget);
        expect(find.byType(ReferenceImageGrid), findsOneWidget);
        // History starts closed.
        expect(find.text('History'), findsOneWidget);
        expect(find.text('2 changes'), findsOneWidget);
        expect(find.text('Rescheduled'), findsNothing);
        await tester.ensureVisible(find.text('History'));
        await tester.tap(find.text('History'));
        await tester.pumpAndSettle();
        expect(find.text('Rescheduled'), findsOneWidget);

        // More holds the rarer actions, Cancel last.
        await tester.tap(find.text('More'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('Reschedule'), findsOneWidget);
        expect(find.text('Mark no-show'), findsOneWidget);
        expect(find.text('Cancel call'), findsOneWidget);
        expect(find.text('Join call'), findsOneWidget);
        final cancelY = tester.getTopLeft(find.text('Cancel call')).dy;
        expect(tester.getTopLeft(find.text('Reschedule')).dy, lessThan(cancelY));
      });

      testWidgets('an ended call asks for the outcome first', (tester) async {
        await _pumpDetail(tester, _json('1', 'Anjali Menon', 'Scheduled', _today.subtract(const Duration(days: 1)),
            notes: true), entry.value);
        expect(tester.takeException(), isNull);
        expect(find.text('This call ended. Record what was discussed, or mark a no-show.'), findsOneWidget);
        expect(find.widgetWithText(FilledButton, 'Record outcome'), findsOneWidget);
        expect(find.text('Share invite'), findsNothing);
        if (entry.key == 'desktop') {
          expect(find.text('Mark no-show'), findsOneWidget);
        } else {
          await tester.tap(find.text('More'));
          await tester.pumpAndSettle();
          expect(find.text('Mark no-show'), findsOneWidget);
        }
      });

      testWidgets('a completed call offers only to edit its details', (tester) async {
        await _pumpDetail(tester, _json('1', 'Anjali Menon', 'Completed', _today.subtract(const Duration(days: 1)),
            notes: true), entry.value);
        expect(tester.takeException(), isNull);
        expect(find.widgetWithText(FilledButton, 'Edit call details'), findsOneWidget);
        expect(find.text('More'), findsNothing);
        expect(find.textContaining('This call ended'), findsNothing);
      });

      testWidgets('a cancelled call shows the reason and no actions', (tester) async {
        await _pumpDetail(
          tester,
          {..._json('1', 'Anjali Menon', 'Cancelled', _today), 'cancelReason': 'Bride postponed'},
          entry.value,
        );
        expect(tester.takeException(), isNull);
        expect(find.text('Cancelled: Bride postponed'), findsOneWidget);
        expect(find.byType(FilledButton), findsNothing);
        expect(find.text('More'), findsNothing);
      });

      testWidgets('tapping a reference image opens the viewer and swipes to the next', (tester) async {
        await _pump(tester, const ConsultationDetailScreen(consultationId: '1'), entry.value);
        await tester.tap(find.byTooltip('Saree colour'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(tester.takeException(), isNull);
        expect(find.text('1 of 2'), findsOneWidget);
        expect(find.text('Saree colour'), findsWidgets);

        await tester.tap(find.byTooltip('Next'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.text('2 of 2'), findsOneWidget);

        await tester.tap(find.byTooltip('Close'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.text('2 of 2'), findsNothing);
      });

      testWidgets('after-call form (complete) shows every section and both actions', (tester) async {
        await _pump(
          tester,
          const AfterCallFormScreen(consultationId: '1', complete: true),
          entry.value,
        );
        expect(tester.takeException(), isNull);
        expect(find.text('Complete call'), findsWidgets); // title + button
        for (final f in kAfterCallFields) {
          expect(find.text(f.label), findsOneWidget, reason: f.label);
        }
        expect(find.text('Suggested a nude palette'), findsOneWidget); // prefilled
        expect(find.text('Reference images'), findsOneWidget);
        expect(find.text('2 / 15'), findsOneWidget);
        expect(find.text('Add images'), findsOneWidget);
        expect(find.text("Client didn't join"), findsOneWidget);
      });

      testWidgets('after-call form (edit) saves without completing', (tester) async {
        await _pump(tester, const AfterCallFormScreen(consultationId: '1'), entry.value);
        expect(tester.takeException(), isNull);
        expect(find.text('Call details'), findsOneWidget);
        expect(find.text('Save'), findsOneWidget);
        expect(find.text("Client didn't join"), findsNothing);
      });

      testWidgets('detail hides the notes card when the server withheld notes', (tester) async {
        tester.view.physicalSize = entry.value;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              consultationProvider.overrideWith(
                (ref, id) async => Consultation.fromJson(_json(id, 'Anjali Menon', 'Scheduled', _today)),
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: const ConsultationDetailScreen(consultationId: '1'),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('Call details'), findsNothing);
        expect(find.byType(ReferenceImageGrid), findsNothing);
      });

      testWidgets('booking form from an enquiry renders every section', (tester) async {
        await _pump(tester, const ConsultationFormScreen(leadId: 'l1'), entry.value);
        expect(tester.takeException(), isNull);
        expect(find.text('Schedule call'), findsWidgets); // title + button
        expect(find.text('Anjali Menon'), findsWidgets);
        expect(find.textContaining('created from this enquiry'), findsOneWidget);
        for (final s in ['Client', 'When', 'Meeting', 'Day', 'Start time', 'Length']) {
          expect(find.text(s), findsWidgets, reason: s);
        }
        expect(find.text('Tomorrow'), findsOneWidget);
        expect(find.text('45 min'), findsOneWidget);
      });

      testWidgets('booking form from a client page shows which call it will be', (tester) async {
        await _pump(tester, const ConsultationFormScreen(clientId: 'c1'), entry.value);
        expect(tester.takeException(), isNull);
        expect(find.text('Call 2 of 4'), findsWidgets);
        expect(find.text('Change'), findsNothing); // fixed from the client page
        // The stylist's other calls that day are listed for clashes.
        expect(find.textContaining('Other calls on'), findsOneWidget);
      });

      testWidgets('booking form without a client lists your clients', (tester) async {
        await _pump(tester, const ConsultationFormScreen(), entry.value);
        expect(tester.takeException(), isNull);
        expect(find.text('Search your clients by name, phone or booking'), findsOneWidget);
        expect(find.text('Riya Joseph'), findsOneWidget);
        expect(find.text('New client'), findsOneWidget);

        await tester.tap(find.text('Riya Joseph'));
        await tester.pumpAndSettle();
        expect(find.text('Change'), findsOneWidget);
        expect(find.text('Call 2 of 4'), findsWidgets);
      });
    });
  }
}
