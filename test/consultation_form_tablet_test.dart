import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nizan_crm/core/theme/app_theme.dart';
import 'package:nizan_crm/features/consultations/controllers/consultation_provider.dart';
import 'package:nizan_crm/features/consultations/data/consultation.dart';
import 'package:nizan_crm/features/consultations/data/stylist_client.dart';
import 'package:nizan_crm/features/consultations/presentation/screens/consultation_form_screen.dart';

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

Future<void> _pump(WidgetTester tester, Widget screen, Size size, {bool shell = true}) async {
  _shell = shell;
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
      child: MaterialApp(theme: AppTheme.lightTheme, home: _shell ? _framed(screen, size) : screen),
    ),
  );
  await tester.pumpAndSettle();
}


var _shell = true;

/// The screen as the app shows it from a tablet up (main_layout.dart): the sidebar — 80 px collapsed on a tablet under 840 px,
/// 250 px otherwise — then the page with 24 px of padding. A phone (< 600 px) gets the screen alone.
Widget _framed(Widget screen, Size size) {
  if (size.width < 600) return screen;
  final sidebar = size.width < 840 ? 80.0 : 250.0;
  return Scaffold(
    body: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SizedBox(width: sidebar, child: const ColoredBox(color: Color(0xFFEEEEEE))),
      Expanded(child: Padding(padding: const EdgeInsets.all(24), child: screen)),
    ]),
  );
}

// Every iPad, both ways round, plus a phone and a desktop.
const _sizes = {
  'phone 390': Size(390, 844),
  'iPad mini portrait 744': Size(744, 1133),
  'iPad portrait 820': Size(820, 1180),
  'iPad Pro 11 portrait 834': Size(834, 1194),
  'iPad Pro 12.9 portrait 1024': Size(1024, 1366),
  'iPad 10.2 landscape 1080': Size(1080, 810),
  'iPad mini landscape 1133': Size(1133, 744),
  'iPad Air landscape 1180': Size(1180, 820),
  'iPad Pro 11 landscape 1194': Size(1194, 834),
  'iPad Pro 12.9 landscape 1366': Size(1366, 1024),
  'desktop 1440': Size(1440, 900),
};

void main() {
  for (final e in _sizes.entries) {
    testWidgets('Schedule call at ${e.key}: the Schedule button is always there to press, nothing overflows', (tester) async {
      await _pump(tester, const ConsultationFormScreen(clientId: 'c1'), e.value);
      expect(tester.takeException(), isNull);
      final button = find.widgetWithText(FilledButton, 'Schedule call');
      expect(button, findsOneWidget, reason: 'one Schedule button — beside the form or in the bar under it');
      expect(button.hitTestable(), findsOneWidget, reason: 'on screen, not hidden or covered');
      // what will be booked is in sight next to it
      expect(find.text('Call 2 of 4').hitTestable(), findsWidgets);
    });
  }
}
