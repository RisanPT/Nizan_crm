import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nizan_crm/core/auth/access_control.dart';
import 'package:nizan_crm/core/models/auth_session.dart';
import 'package:nizan_crm/core/routing/app_router.dart';
import 'package:nizan_crm/core/theme/app_theme.dart';
import 'package:nizan_crm/features/crm/data/crm_models.dart';
import 'package:nizan_crm/features/crm/data/crm_weekly_models.dart';
import 'package:nizan_crm/features/crm/presentation/screens/crm_weekly_report_screen.dart';
import 'package:nizan_crm/features/crm/presentation/widgets/crm_booking_care_card.dart';
import 'package:nizan_crm/features/crm/presentation/widgets/crm_care_todo.dart';
import 'package:nizan_crm/features/crm/services/crm_service.dart';
import 'package:nizan_crm/features/crm/services/crm_weekly_service.dart';

// The CRM weekly report and a booking's CRM care: the eight items in the team's order, "—" for what was not recorded, what the Head
// types is what is saved, a report is handed in only after its week (and then cannot be edited, only reopened), the per-day ticks, the
// client's health notes (and the artists see them), and the to-do lists.

final _now = DateTime(2026, 11, 18, 12);

Map<String, dynamic> _figures({bool photosTracked = true}) => {
  'nextWeek': {'from': '2026-11-16', 'to': '2026-11-22', 'label': '16 Nov – 22 Nov 2026'},
  'trials': {'held': 5, 'completed': 4, 'cancelled': 1, 'postponed': 0, 'converted': 2, 'maturing': 1, 'prevHeld': 3},
  'photosReviews': {
    'worksDone': 12,
    'photos': photosTracked ? 9 : null,
    'photosPct': photosTracked ? 75 : null,
    'clientsDone': 10,
    'reviews': 6,
    'reviewsPct': 60,
    'missingPhotos': [
      {'bookingId': 'b1', 'client': 'Diya', 'day': '2026-11-12', 'bookingNumber': 'BN-1', 'phone': '98950'},
    ],
    'missingReviews': [],
  },
  'support': {'clients': 31, 'prevClients': 28, 'monthToDate': 64, 'monthTarget': 100, 'monthFrom': '2026-11-01', 'monthTo': '2026-11-15', 'byMember': [{'name': 'Asha', 'clients': 18}, {'name': 'Bina', 'clients': 13}]},
  'verification': {
    'thisWeek': {'from': '2026-11-09', 'to': '2026-11-15', 'works': 12, 'verified': 11, 'pct': 91.7, 'unverified': []},
    'nextWeek': {'from': '2026-11-16', 'to': '2026-11-22', 'works': 8, 'verified': 6, 'pct': 75, 'unverified': [{'bookingId': 'b7', 'client': 'Liya', 'day': '2026-11-20'}]},
  },
  'medical': {
    'withConditions': [{'bookingId': 'b2', 'client': 'Sneha', 'days': ['2026-11-17'], 'conditions': ['Allergy'], 'note': 'Latex'}],
    'emergencies': [{'client': 'Diya', 'day': '2026-11-12', 'what': 'Rash after primer', 'action': 'Cold compress'}],
  },
  'workload': {
    'thisWeek': {'booked': 14, 'capacity': 42, 'days': []},
    'nextWeek': {
      'from': '2026-11-16', 'to': '2026-11-22', 'booked': 25, 'capacity': 42, 'overDays': 1,
      'days': [
        for (var d = 16; d <= 22; d++) {'day': '2026-11-$d', 'booked': d == 21 ? 8 : 2, 'capacity': 6, 'spare': d == 21 ? 0 : 4, 'over': d == 21, 'blocked': false},
      ],
    },
  },
  'outsource': {
    'total': 2,
    'lines': [
      {'bride': 'Anu', 'outsource': 'Rani', 'work': 'Bridal · Lead artist', 'phone': '9000011111', 'day': '2026-11-11'},
      {'bride': 'Diya', 'outsource': 'Rani', 'work': 'Party', 'phone': '9000011111', 'day': '2026-11-12'},
    ],
    'byPerson': [{'name': 'Rani', 'phone': '9000011111', 'works': 2}],
  },
};

// the figures that can be typed by hand (backend utils/crmWeekly.js OVERRIDE_FIELDS)
const _fields = [
  {'key': 'trialsHeld', 'section': 'trials', 'label': 'Trials held'},
  {'key': 'trialsCompleted', 'section': 'trials', 'label': 'Trials completed'},
  {'key': 'trialsConverted', 'section': 'trials', 'label': 'Trials that became bookings'},
  {'key': 'worksDone', 'section': 'photos', 'label': 'Makeover works done'},
  {'key': 'photos', 'section': 'photos', 'label': 'Photos collected'},
  {'key': 'clientsDone', 'section': 'photos', 'label': 'Clients done'},
  {'key': 'reviews', 'section': 'photos', 'label': 'Reviews collected'},
  {'key': 'supportClients', 'section': 'support', 'label': 'Clients handled this week'},
  {'key': 'monthToDate', 'section': 'support', 'label': 'Clients handled this month'},
  {'key': 'verifyWorks', 'section': 'verification', 'label': "Coming week's works"},
  {'key': 'verified', 'section': 'verification', 'label': "Coming week's works verified"},
  {'key': 'medicalConditions', 'section': 'medical', 'label': 'Clients with a medical condition'},
  {'key': 'medicalEmergencies', 'section': 'medical', 'label': 'Medical emergencies'},
  {'key': 'workloadBooked', 'section': 'workload', 'label': 'Coming week: bookings'},
  {'key': 'workloadCapacity', 'section': 'workload', 'label': 'Coming week: slots'},
];
const _records = {'worksDone': 12, 'photos': 9, 'clientsDone': 10, 'reviews': 6, 'trialsHeld': 5, 'verified': 6, 'verifyWorks': 8};

CrmWeeklyReport _report({
  String status = 'draft',
  String from = '2026-11-09',
  String to = '2026-11-15',
  Map<String, dynamic> typed = const {},
  bool photosTracked = true,
  Map<String, dynamic> records = _records,
  Map<String, dynamic>? figures,
}) =>
    CrmWeeklyReport.fromJson({
      'week': {'from': from, 'to': to, 'label': 'Week of $from'},
      'status': status,
      'live': status != 'submitted',
      'typed': typed,
      'figures': figures ?? _figures(photosTracked: photosTracked),
      'records': records,
      'fields': _fields,
      'submittedByName': status == 'submitted' ? 'Meera' : '',
      'submittedAt': status == 'submitted' ? '2026-11-17T05:00:00.000Z' : null,
    });

class _Fake extends CrmWeeklyService {
  _Fake(this.report, {this.careValue}) : super(Dio());
  CrmWeeklyReport report;
  CrmCare? careValue;
  final saved = <Map<String, dynamic>>[];
  final submitted = <String>[];
  final verified = <(String, String, bool)>[];
  final photosTicked = <(String, String, bool)>[];
  final medical = <(List<String>, String)>[];

  @override
  Future<CrmWeeklyReport> save(String week, Map<String, dynamic> typed) async {
    saved.add(typed);
    return report;
  }

  @override
  Future<CrmWeeklyReport> submit(String week) async {
    submitted.add(week);
    return report;
  }

  @override
  Future<CrmCare> verify(String bookingId, String day, {bool done = true, String note = ''}) async {
    verified.add((bookingId, day, done));
    return careValue!;
  }

  @override
  Future<CrmCare> photos(String bookingId, String day, {bool done = true}) async {
    photosTicked.add((bookingId, day, done));
    return careValue!;
  }

  @override
  Future<CrmCare> setMedical(String bookingId, List<String> conditions, String note) async {
    medical.add((conditions, note));
    return careValue!;
  }
}

CrmMe _me(String viewer) => CrmMe(viewer: viewer, userId: 'u', canAssign: viewer == 'head', seesTeam: true, canWrite: viewer != 'leadership');

Future<void> _pump(WidgetTester t, Widget child, {required _Fake svc, CrmMe? me, double width = 1300}) async {
  t.view.physicalSize = Size(width, 2400);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final router = GoRouter(routes: [
    GoRoute(path: '/', builder: (_, _) => Scaffold(body: child)),
    GoRoute(path: '/booking/manage/:id', builder: (_, s) => Scaffold(body: Text('BOOKING ${s.pathParameters['id']}'))),
  ]);
  await t.pumpWidget(ProviderScope(
    overrides: [
      crmWeeklyServiceProvider.overrideWithValue(svc),
      crmMeProvider.overrideWith((ref) async => me ?? _me('head')),
      crmWeeklyProvider.overrideWith((ref, w) async => svc.report),
      crmWeeksProvider.overrideWith((ref) async => const []),
      if (svc.careValue != null) crmCareProvider.overrideWith((ref, id) async => svc.careValue!),
      crmCareListProvider.overrideWith((ref, kind) async => CrmCareList.fromJson({
            'kind': kind, 'works': 2, 'done': 1,
            'items': [
              {'bookingId': 'b7', 'client': 'Liya', 'day': '2026-11-20', 'done': false, 'medical': true},
              {'bookingId': 'b8', 'client': 'Neha', 'day': '2026-11-21', 'done': true, 'byName': 'Asha'},
            ],
          })),
    ],
    child: MaterialApp.router(theme: AppTheme.lightTheme, routerConfig: router),
  ));
  await t.pumpAndSettle();
}

String _text(WidgetTester t, String key) => t.widget<Text>(find.byKey(Key(key))).data ?? '';

void main() {
  group('who opens the weekly report', () {
    AuthSession s(String role) => AuthSession(token: 't', userId: 'u', name: role, email: '$role@x', role: role, permissions: const ['clients', 'bookings']);
    test('the CRM Head and leadership — not a member, not sales', () {
      expect(isRouteAllowed('/crm/weekly', Access.of(s('crm_manager'))), isTrue);
      expect(isRouteAllowed('/crm/weekly', Access.of(s('ceo'))), isTrue);
      expect(isRouteAllowed('/crm/weekly', Access.of(s('crm'))), isFalse);
      expect(isRouteAllowed('/crm/weekly', Access.of(s('sales'))), isFalse);
    });
  });

  group('the weekly report', () {
    testWidgets('the eight items in the team\'s order, with the figures', (t) async {
      await _pump(t, CrmWeeklyReportScreen(now: _now), svc: _Fake(_report()));
      final order = ['trials', 'photos', 'support', 'messages', 'verification', 'medical', 'workload', 'outsource'];
      final ys = [for (final k in order) t.getTopLeft(find.byKey(Key('crmWeekly_$k'))).dy];
      for (var i = 2; i < ys.length; i += 2) {
        expect(ys[i], greaterThan(ys[i - 2]), reason: '${order[i]} comes after ${order[i - 2]}');
      }
      expect(_text(t, 'crmWeeklyValue_trialsHeld'), '5');
      expect(_text(t, 'crmWeeklyValue_photos'), '9');
      expect(_text(t, 'crmWeeklyValue_reviews'), '6');
      expect(_text(t, 'crmWeeklyValue_support'), '31');
      expect(_text(t, 'crmWeeklyValue_verified'), '6 / 8');
      expect(_text(t, 'crmWeeklyValue_workload'), '25 / 42');
      expect(find.text('Sneha · Allergy'), findsOneWidget);
      expect(find.text('Rani · 2'), findsOneWidget);
      expect(find.text('9000011111'), findsNWidgets(2));
      expect(t.takeException(), isNull);
    });

    testWidgets('photos not ticked yet in that week read "—", not 0', (t) async {
      await _pump(t, CrmWeeklyReportScreen(now: _now), svc: _Fake(_report(photosTracked: false)));
      expect(_text(t, 'crmWeeklyValue_photos'), '—');
    });

    testWidgets('the Head types the counts and the manpower answers; handing in saves them first', (t) async {
      final svc = _Fake(_report());
      await _pump(t, CrmWeeklyReportScreen(now: _now), svc: svc);
      await t.enterText(find.byKey(const Key('crmWeekly_nizan')), '14');
      await t.enterText(find.byKey(const Key('crmWeekly_teamN')), '9');
      await t.pump();
      expect(_text(t, 'crmWeeklyMsgTotal'), 'Total 23');
      await t.enterText(find.byKey(const Key('crmWeekly_plan')), 'Two freelancers for Saturday');
      await t.tap(find.byKey(const Key('crmWeekly_enough_yes')));
      await t.pump();
      await t.tap(find.byKey(const Key('crmWeeklySubmit')));
      await t.pumpAndSettle();
      expect(svc.saved.single, containsPair('startingMessagesNizan', '14'));
      expect(svc.saved.single, containsPair('enoughWork', 'yes'));
      expect(svc.saved.single, containsPair('manpowerPlan', 'Two freelancers for Saturday'));
      expect(svc.submitted, ['2026-11-09']);
    });

    testWidgets('a week still going on cannot be handed in', (t) async {
      final svc = _Fake(_report(status: 'new', from: '2026-11-16', to: '2026-11-22'));
      await _pump(t, CrmWeeklyReportScreen(now: _now), svc: svc);
      expect(t.widget<FilledButton>(find.byKey(const Key('crmWeeklySubmit'))).onPressed, isNull);
      expect(find.byKey(const Key('crmWeekNext')), findsOneWidget);
      expect(t.widget<IconButton>(find.byKey(const Key('crmWeekNext'))).onPressed, isNull, reason: 'no week after the current one');
    });

    testWidgets('a handed-in report: nothing to type, the Head can reopen it; leadership only reads', (t) async {
      await _pump(t, CrmWeeklyReportScreen(now: _now), svc: _Fake(_report(status: 'submitted', typed: {'startingMessagesNizan': 14})));
      expect(t.widget<TextField>(find.byKey(const Key('crmWeekly_nizan'))).enabled, isFalse);
      expect(find.byKey(const Key('crmWeeklySave')), findsNothing);
      expect(find.byKey(const Key('crmWeeklyReopen')), findsOneWidget);
      expect(find.textContaining('Handed in by Meera'), findsOneWidget);
    });

    testWidgets('leadership: no buttons at all', (t) async {
      await _pump(t, CrmWeeklyReportScreen(now: _now), svc: _Fake(_report()), me: _me('leadership'));
      expect(find.byKey(const Key('crmWeeklySave')), findsNothing);
      expect(find.byKey(const Key('crmWeeklyReopen')), findsNothing);
      expect(t.widget<TextField>(find.byKey(const Key('crmWeekly_plan'))).enabled, isFalse);
      expect(find.byKey(const Key('crmWeeklyEnter_photos')), findsNothing, reason: 'leadership does not enter figures');
    });

    testWidgets('a figure typed by hand: the dialog shows the records\' figure; empty goes back to it; the rest of the page is saved too', (t) async {
      final svc = _Fake(_report());
      await _pump(t, CrmWeeklyReportScreen(now: _now), svc: svc, width: 390);
      await t.enterText(find.byKey(const Key('crmWeekly_nizan')), '14'); // typed on the page, not saved yet
      await t.tap(find.byKey(const Key('crmWeeklyEnter_photos')));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('crmByHandDialog')), findsOneWidget);
      expect(t.takeException(), isNull, reason: 'the dialog fits a phone');
      expect(find.text('Records: 12'), findsOneWidget, reason: 'works done, from the records');
      expect(find.text('Records: 9'), findsOneWidget);
      await t.enterText(find.byKey(const Key('crmByHand_worksDone')), '13');
      await t.enterText(find.byKey(const Key('crmByHand_photos')), '11');
      await t.enterText(find.byKey(const Key('crmByHand_note')), 'Two works kept on paper');
      await t.tap(find.byKey(const Key('crmByHandSave')));
      await t.pumpAndSettle();
      final sent = svc.saved.single;
      expect(sent['overrides'], {'worksDone': 13, 'photos': 11, 'clientsDone': null, 'reviews': null});
      expect(sent['sectionNotes'], {'photos': 'Two works kept on paper'});
      expect(sent, containsPair('startingMessagesNizan', '14'), reason: 'what was typed on the page is not lost');
    });

    testWidgets('"Use the records\' figures" empties the boxes', (t) async {
      final svc = _Fake(_report(typed: {'overrides': {'trialsHeld': 7}}));
      await _pump(t, CrmWeeklyReportScreen(now: _now), svc: svc);
      await t.tap(find.byKey(const Key('crmWeeklyEnter_trials')));
      await t.pumpAndSettle();
      expect(t.widget<TextField>(find.byKey(const Key('crmByHand_trialsHeld'))).controller!.text, '7');
      await t.tap(find.byKey(const Key('crmByHandClear')));
      await t.tap(find.byKey(const Key('crmByHandSave')));
      await t.pumpAndSettle();
      expect(svc.saved.single['overrides'], {'trialsHeld': null, 'trialsCompleted': null, 'trialsConverted': null});
    });

    testWidgets('a typed figure is marked, with the records\' figure under it; the item\'s note shows', (t) async {
      final f = _figures();
      (f['outsource'] as Map)['lines'] = [
        ...((f['outsource'] as Map)['lines'] as List),
        {'bride': 'Paper Bride', 'outsource': 'Lini', 'work': 'Party', 'phone': '9000033333', 'day': '', 'byHand': true},
      ];
      final svc = _Fake(_report(
        typed: {
          'overrides': {'photos': 9},
          'sectionNotes': {'photos': 'Two works kept on paper'},
          'outsourceLines': [{'bride': 'Paper Bride', 'outsource': 'Lini', 'work': 'Party', 'phone': '9000033333', 'day': ''}],
        },
        records: {..._records, 'photos': 7},
        figures: f,
      ));
      await _pump(t, CrmWeeklyReportScreen(now: _now), svc: svc);
      expect(_text(t, 'crmWeeklyValue_photos'), '9');
      expect(_text(t, 'crmWeeklyRecords_photos'), 'typed by hand · records 7');
      expect(find.byKey(const Key('crmWeeklyRecords_worksDone')), findsNothing, reason: 'not typed: no mark');
      expect(find.descendant(of: find.byKey(const Key('crmWeeklyByHand_photos')), matching: find.textContaining('Note: Two works kept on paper')), findsOneWidget);
      expect(find.byKey(const Key('crmWeeklyByHand_trials')), findsNothing);
      expect(find.byKey(const Key('crmWeeklyByHand_outsource')), findsOneWidget);
      expect(find.textContaining('typed by hand', findRichText: true), findsWidgets);
      expect(find.text('Party · typed by hand'), findsOneWidget);
    });

    testWidgets('outsource works typed in: a half-filled one says what is missing; one can be removed', (t) async {
      final svc = _Fake(_report(typed: {'outsourceLines': [{'bride': 'Old Bride', 'outsource': 'Mini'}]}));
      await _pump(t, CrmWeeklyReportScreen(now: _now), svc: svc);
      await t.tap(find.byKey(const Key('crmWeeklyEnter_outsource')));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('crmByHandLine_0')), findsOneWidget);
      await t.tap(find.byKey(const Key('crmByHandRemove_0')));
      await t.pump();
      expect(find.byKey(const Key('crmByHandLine_0')), findsNothing);
      await t.enterText(find.byKey(const Key('crmByHand_bride')), 'Paper Bride');
      await t.tap(find.byKey(const Key('crmByHandSave')));
      await t.pump();
      expect(find.byKey(const Key('crmByHandError')), findsOneWidget, reason: 'no artist yet');
      expect(svc.saved, isEmpty);
      await t.enterText(find.byKey(const Key('crmByHand_artist')), 'Lini');
      await t.enterText(find.byKey(const Key('crmByHand_work')), 'Party');
      await t.enterText(find.byKey(const Key('crmByHand_phone')), '9000033333');
      await t.tap(find.byKey(const Key('crmByHandSave')));
      await t.pumpAndSettle();
      expect(svc.saved.single['outsourceLines'], [
        {'bride': 'Paper Bride', 'outsource': 'Lini', 'work': 'Party', 'phone': '9000033333', 'day': ''},
      ]);
    });

    testWidgets('handed in, or leadership: nothing to enter by hand', (t) async {
      await _pump(t, CrmWeeklyReportScreen(now: _now), svc: _Fake(_report(status: 'submitted')));
      expect(find.byKey(const Key('crmWeeklyEnter_photos')), findsNothing);
      expect(find.byKey(const Key('crmWeeklyEnter_outsource')), findsNothing);
    });

    testWidgets('a phone-width report does not overflow', (t) async {
      await _pump(t, CrmWeeklyReportScreen(now: _now), svc: _Fake(_report()), width: 390);
      expect(t.takeException(), isNull);
      // down to the last item (the list builds what is on screen)
      await t.scrollUntilVisible(find.byKey(const Key('crmWeekly_outsource')), 400, scrollable: find.byType(Scrollable).first);
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(find.byKey(const Key('crmWeekly_outsource')), findsOneWidget);
    });
  });

  group('a booking\'s care', () {
    CrmCare care({List<String> conditions = const [], bool full = true, bool canWrite = true}) => CrmCare.fromJson({
      'bookingId': 'b1',
      'days': ['2026-11-17', '2026-11-25'],
      'medical': {'conditions': conditions, 'note': conditions.isEmpty ? '' : 'Latex allergy'},
      'emergencies': [],
      if (full) 'verifications': [{'day': '2026-11-17', 'byName': 'Asha'}],
      if (full) 'photos': [],
      'canWrite': canWrite,
    });

    testWidgets('a tick per work day; photos only for a day that has happened', (t) async {
      final svc = _Fake(_report(), careValue: care());
      await _pump(t, const CrmBookingCareCard(bookingId: 'b1', today: '2026-11-18'), svc: svc);
      expect(t.widget<FilterChip>(find.byKey(const Key('crmVerify_2026-11-17'))).selected, isTrue);
      expect(t.widget<FilterChip>(find.byKey(const Key('crmPhotos_2026-11-25'))).onSelected, isNull, reason: 'the 25th has not happened');
      await t.tap(find.byKey(const Key('crmVerify_2026-11-25')));
      await t.tap(find.byKey(const Key('crmPhotos_2026-11-17')));
      await t.pumpAndSettle();
      expect(svc.verified, [('b1', '2026-11-25', true)]);
      expect(svc.photosTicked, [('b1', '2026-11-17', true)]);
    });

    testWidgets('health notes: "Other" needs a note; the conditions are saved in their order', (t) async {
      final svc = _Fake(_report(), careValue: care());
      await _pump(t, const CrmBookingCareCard(bookingId: 'b1', today: '2026-11-18'), svc: svc);
      await t.tap(find.byKey(const Key('crmEditMedical')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('crmCondition_other')));
      await t.tap(find.byKey(const Key('crmCondition_allergy')));
      await t.pump();
      await t.tap(find.byKey(const Key('crmMedicalSave')));
      await t.pumpAndSettle();
      expect(svc.medical, isEmpty);
      expect(find.text('Say what the other condition is.'), findsOneWidget);
      await t.enterText(find.byKey(const Key('crmMedicalNote')), 'Asthma — no spray products');
      await t.tap(find.byKey(const Key('crmMedicalSave')));
      await t.pumpAndSettle();
      expect(svc.medical.single.$1, ['allergy', 'other']);
      expect(svc.medical.single.$2, 'Asthma — no spray products');
    });

    testWidgets('read only: no buttons', (t) async {
      await _pump(t, const CrmBookingCareCard(bookingId: 'b1', today: '2026-11-18'), svc: _Fake(_report(), careValue: care(canWrite: false)));
      expect(t.widget<FilterChip>(find.byKey(const Key('crmVerify_2026-11-25'))).onSelected, isNull);
      expect(find.byKey(const Key('crmEditMedical')), findsNothing);
    });

    testWidgets('the artist sees the client\'s health notes on the work — and nothing when there are none', (t) async {
      await _pump(t, const CrmClientHealthNote(bookingId: 'b1'), svc: _Fake(_report(), careValue: care(conditions: ['allergy', 'pregnancy'], full: false)));
      expect(find.text('Client health — read before you start'), findsOneWidget);
      expect(find.text('Allergy'), findsOneWidget);
      expect(find.text('Pregnancy'), findsOneWidget);
      expect(find.text('Latex allergy'), findsOneWidget);
    });

    testWidgets('no health notes: nothing shown', (t) async {
      await _pump(t, const CrmClientHealthNote(bookingId: 'b1'), svc: _Fake(_report(), careValue: care(full: false)));
      expect(find.byKey(const Key('crmHealthNote_b1')), findsNothing);
    });
  });

  group('the to-do lists', () {
    testWidgets('only what is not done, with its button', (t) async {
      final svc = _Fake(_report(), careValue: CrmCare.fromJson(const {'bookingId': 'b7'}));
      await _pump(t, const SingleChildScrollView(child: CrmCareToDo(kind: 'verify')), svc: svc);
      expect(find.text('1 of 2 done'), findsOneWidget);
      expect(find.text('Liya'), findsOneWidget);
      expect(find.text('Neha'), findsNothing, reason: 'done');
      await t.tap(find.byKey(const Key('crmToDoDone_verify_b7_2026-11-20')));
      await t.pumpAndSettle();
      expect(svc.verified, [('b7', '2026-11-20', true)]);
    });
  });
}
