import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nizan_crm/core/theme/app_theme.dart';
import 'package:nizan_crm/features/consultations/controllers/consultation_provider.dart';
import 'package:nizan_crm/features/consultations/data/consultation_summary.dart';
import 'package:nizan_crm/features/consultations/data/stylist_client.dart';
import 'package:nizan_crm/features/consultations/presentation/screens/consultations_dashboard_screen.dart';

Map<String, dynamic> _consultation(String id, String client, String status, DateTime start) => {
      '_id': id,
      'consultationNo': 'CN-$id',
      'leadId': {'_id': 'l$id', 'name': client, 'phone': '9876543210'},
      'stylistId': {'_id': 's1', 'name': 'Asha'},
      'scheduledAt': start.toUtc().toIso8601String(),
      'endsAt': start.add(const Duration(minutes: 45)).toUtc().toIso8601String(),
      'durationMins': 45,
      'status': status,
      'mode': 'Video',
    };

ConsultationSummary _summary({required String scope}) {
  final now = DateTime.now();
  return ConsultationSummary.fromJson({
    'range': {'from': '2026-11-01', 'to': '2026-11-30'},
    'scope': scope,
    'activeClients': 2,
    'statusCounts': {'total': 6, 'Scheduled': 2, 'Completed': 3, 'Cancelled': 0, 'No-show': 1},
    'perStylist': [
      {
        'stylistId': 's1',
        'name': 'Asha',
        'total': 4,
        'scheduled': 1,
        'completed': 2,
        'cancelled': 0,
        'noShow': 1,
        'attendedRate': 0.67,
      },
    ],
    'enquiryStatus': {
      'New': 4,
      'Contacted': 2,
      'Consultation Scheduled': 2,
      'Follow-up Required': 1,
      'Appointment Confirmed': 3,
      'Cancelled': 0,
    },
    'today': [_consultation('1', 'Anjali Menon', 'Scheduled', now)],
    'upcoming': [_consultation('2', 'Divya Nair', 'Scheduled', now.add(const Duration(days: 3)))],
    'needsOutcome': [_consultation('3', 'Meera Das', 'Scheduled', now.subtract(const Duration(days: 1)))],
    'followUps': {
      'count': 1,
      'items': [
        {
          'leadId': 'l9',
          'name': 'Kavya Pillai',
          'phone': '9000000001',
          'followUpDate': now.subtract(const Duration(hours: 2)).toUtc().toIso8601String(),
          'overdue': true,
        },
      ],
    },
  });
}

final _clients = [
  StylistClient.fromJson(const {
    '_id': 'c1',
    'company': 'Team N',
    'name': 'Anjali Menon',
    'eventType': 'Wedding',
    'requiredCalls': 4,
    'progress': {'done': 2, 'required': 4, 'booked': 1, 'nextCallAt': '2030-01-01T05:30:00.000Z'},
  }),
  StylistClient.fromJson(const {
    '_id': 'c2',
    'company': 'Nizan',
    'name': 'Riya Joseph',
    'eventType': 'Reception',
    'requiredCalls': 4,
    'progress': {'done': 1, 'required': 4, 'booked': 0},
  }),
];

Future<void> _pump(
  WidgetTester tester,
  ConsultationSummary summary, {
  Size size = const Size(1200, 2000),
  List<StylistClient>? clients,
}) async {
  final shownClients = clients ?? _clients;
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        consultationSummaryProvider.overrideWith((ref, q) async => summary),
        stylistClientsProvider.overrideWith((ref, q) async => shownClients),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: const ConsultationsDashboardScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

const _desktop = Size(1440, 2200);
const _phone = Size(390, 3200);

Future<void> _openReport(WidgetTester tester) async {
  await tester.tap(find.textContaining('Month report'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('stylist lead sees one urgent list, side cards and a closed month report', (tester) async {
    await _pump(tester, _summary(scope: 'all'), size: _desktop);

    expect(tester.takeException(), isNull);
    expect(find.textContaining('Whole team'), findsOneWidget);
    // Header button on desktop, no floating button.
    expect(find.widgetWithText(FilledButton, 'Schedule call'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);

    // Filter chips replace the old summary tiles.
    expect(find.widgetWithText(ChoiceChip, 'All 4'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, '1 to record'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, '1 call today'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, '1 needs a call'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, '1 follow-up'), findsOneWidget);
    expect(find.text('Calls today'), findsNothing);

    // Needs you now, most urgent first.
    expect(find.text('Needs you now'), findsOneWidget);
    expect(find.text('Meera Das'), findsOneWidget);
    expect(find.text('Ended'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Record outcome'), findsOneWidget);
    // A video call with no link yet asks for the link before anything else.
    expect(find.text('Add link'), findsOneWidget);
    expect(find.textContaining('Link missing'), findsOneWidget);
    expect(find.text('No call'), findsOneWidget); // Riya: no call booked
    expect(find.widgetWithText(OutlinedButton, 'Schedule'), findsOneWidget);
    expect(find.text('Kavya Pillai'), findsOneWidget);
    expect(find.text('Overdue'), findsOneWidget);
    final order = ['Meera Das', 'Anjali Menon', 'Riya Joseph', 'Kavya Pillai']
        .map((n) => tester.getTopLeft(find.text(n).first).dy)
        .toList();
    expect(order, [...order]..sort());

    // Side cards.
    expect(find.text('This week'), findsOneWidget);
    expect(find.textContaining('Divya Nair'), findsOneWidget);
    expect(find.text('Client progress'), findsOneWidget);
    expect(find.text('2 active'), findsOneWidget);
    expect(find.textContaining('Next call'), findsOneWidget); // Anjali

    // Month report starts closed, with a one-line summary.
    expect(find.textContaining('Month report'), findsOneWidget);
    expect(find.textContaining('75% attended'), findsOneWidget); // 3 completed of 4 ended
    expect(find.text('By stylist'), findsNothing);

    await _openReport(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('75%'), findsOneWidget);
    expect(find.text('Enquiries by status'), findsOneWidget);
    expect(find.text('Appointment Confirmed'), findsOneWidget);
    expect(find.text('By stylist'), findsOneWidget);
    expect(find.text('67%'), findsOneWidget);
  });

  testWidgets('a filter chip narrows the list and tapping it again clears it', (tester) async {
    await _pump(tester, _summary(scope: 'all'), size: _desktop);

    await tester.tap(find.widgetWithText(ChoiceChip, '1 to record'));
    await tester.pumpAndSettle();
    expect(find.text('Meera Das'), findsOneWidget);
    expect(find.text('Add link'), findsNothing);
    expect(find.text('Kavya Pillai'), findsNothing);

    await tester.tap(find.widgetWithText(ChoiceChip, '1 to record'));
    await tester.pumpAndSettle();
    expect(find.text('Add link'), findsOneWidget);
    expect(find.text('Kavya Pillai'), findsOneWidget);
  });

  testWidgets('a stylist sees their own calls and no team table', (tester) async {
    await _pump(tester, _summary(scope: 'own'), size: _desktop);

    expect(tester.takeException(), isNull);
    expect(find.textContaining('Your calls'), findsOneWidget);
    await _openReport(tester);
    expect(find.text('By stylist'), findsNothing);
    expect(find.text('Anjali Menon'), findsWidgets); // today's call + client progress
  });

  testWidgets('the whole page fits a phone with data, report open', (tester) async {
    await _pump(tester, _summary(scope: 'all'), size: _phone);

    expect(tester.takeException(), isNull);
    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(find.text('Schedule call'), findsOneWidget); // the floating button only
    // Short button label on a phone.
    expect(find.widgetWithText(FilledButton, 'Record'), findsOneWidget);
    expect(find.text('Needs you now'), findsOneWidget);

    await _openReport(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('By stylist'), findsOneWidget);
  });

  testWidgets('empty sections show friendly text and nothing overflows on a phone', (tester) async {
    await _pump(
      tester,
      ConsultationSummary.fromJson({'scope': 'own'}),
      size: _phone,
      clients: const [],
    );

    expect(tester.takeException(), isNull);
    expect(find.text("You're all caught up. Nothing needs you right now."), findsOneWidget);
    expect(find.byType(ChoiceChip), findsNothing); // no chips when there is nothing to filter
    expect(find.text('No active clients yet.'), findsOneWidget);
    expect(find.text('Nothing booked in the next 7 days.'), findsOneWidget);
    expect(find.text('Ended'), findsNothing);

    await _openReport(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('No enquiries in this period.'), findsOneWidget);
  });
}
