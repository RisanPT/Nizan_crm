import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nizan_crm/core/models/addon_service.dart';
import 'package:nizan_crm/core/models/service_package.dart';
import 'package:nizan_crm/features/bookings/presentation/screens/add_booking_screen.dart';
import 'package:nizan_crm/services/addon_service_service.dart';
import 'package:nizan_crm/services/package_service.dart';
import 'package:nizan_crm/core/auth/access_control.dart';
import 'package:nizan_crm/core/auth/app_role.dart';
import 'package:nizan_crm/core/auth/workspace.dart';
import 'package:nizan_crm/core/models/auth_session.dart';
import 'package:nizan_crm/core/models/employee.dart';
import 'package:nizan_crm/core/models/trial.dart';
import 'package:nizan_crm/core/models/zone.dart';
import 'package:nizan_crm/core/providers/auth_provider.dart';
import 'package:nizan_crm/core/providers/trial_provider.dart';
import 'package:nizan_crm/core/theme/app_theme.dart';
import 'package:nizan_crm/features/bookings/controllers/booking_provider.dart';
import 'package:nizan_crm/features/bookings/data/assignment_rules.dart';
import 'package:nizan_crm/features/bookings/data/booking.dart';
import 'package:nizan_crm/features/bookings/presentation/screens/calendar_screen.dart';
import 'package:nizan_crm/features/bookings/presentation/widgets/calendar_extras.dart';
import 'package:nizan_crm/features/bookings/presentation/widgets/month_kpi_strip.dart';
import 'package:nizan_crm/services/district_service.dart';
import 'package:nizan_crm/services/employee_service.dart';
import 'package:nizan_crm/services/region_service.dart';
import 'package:nizan_crm/services/state_service.dart';
import 'package:nizan_crm/services/zone_service.dart';

// Trials on the main Calendar Scheduler, and influencer works in their own colour:
// - "Show: Works only / Works + trials / Trials only" (only for people who can see trials; an artist sees just their own trials). Trials
//   follow the staff filter; they have no place, so a place filter hides them and the key says so.
// - Trials are teal with a brush, in every view (Month pills / phone dots, Week, Day columns, the phone list); a tap opens the trial.
// - An influencer work (ticked on the booking, or "influencer" in its name / remarks for works from before the tick) is violet with a
//   star, as its own pill even next to the same artist's other works; cancelled / postponed keep their red / amber but still show the star.

Map<String, dynamic> _a(String id, String name, [String roleType = 'lead']) => {
      'employeeId': id,
      'artistName': name,
      'role': roleType == 'lead' ? 'Lead Artist' : 'Assistant',
      'roleType': roleType,
      'type': 'in-house',
    };

final _anu = _a('a1', 'Anu');
final _chitra = _a('a2', 'Chitra');

Booking _b(String id, String customer, String day,
        {String service = 'Bridal',
        List<Map<String, dynamic>> staff = const [],
        String status = 'confirmed',
        bool influencer = false,
        String remarks = '',
        List<Map<String, dynamic>> items = const []}) =>
    Booking.fromJson({
      '_id': id,
      'bookingNumber': 'BK-$id',
      'customerName': customer,
      'phone': '9895499872',
      'status': status,
      'service': service,
      'totalPrice': 10000,
      'advanceAmount': 1000,
      'selectedDates': [day],
      'bookingDate': '${day}T04:00:00.000Z',
      'serviceStart': '${day}T04:00:00.000Z',
      'serviceEnd': '${day}T08:00:00.000Z',
      'assignedStaff': staff,
      'influencerWork': influencer,
      'internalRemarks': remarks,
      'bookingItems': items,
    });

Trial _t(String id, String client, String day, {String start = '', String end = '', String status = 'scheduled', List<Map<String, dynamic>> staff = const []}) =>
    Trial.fromJson({
      '_id': id,
      'trialNumber': 'TR-$id',
      'clientName': client,
      'phone': '9000000000',
      'trialDate': day,
      'startTime': start,
      'endTime': end,
      'status': status,
      'assignedStaff': staff,
      'trialItems': [
        {'packageName': 'Bridal Classic', 'lookLabel': 'Bridal Look', 'price': 2500},
      ],
    });

// 18 Nov: Anu has an influencer work (Party) and an ordinary one (Bridal), and a trial. 20 Nov: an old influencer work typed into the
// client name (no tick) and Chitra's trial. 22 Nov: a cancelled influencer work. 24 Nov: a cancelled trial nobody is on.
final _collab = _b('1', 'Ayesha Collab', '2026-11-18', service: 'Party', staff: [_anu], influencer: true);
final _meera = _b('2', 'Meera', '2026-11-18', staff: [_anu]);
final _legacy = _b('3', 'INFLUENCER WORK - Riya', '2026-11-20', service: 'Party', staff: [_chitra]);
final _offCollab = _b('4', 'Called Collab', '2026-11-22', service: 'Party', staff: [_anu], status: 'cancelled', influencer: true);
final _bookings = [_collab, _meera, _legacy, _offCollab];

final _t1 = _t('t1', 'Trial Bride', '2026-11-18', start: '10:00 AM', end: '12:00 PM', staff: [_anu]);
final _t2 = _t('t2', 'Chitra Trial', '2026-11-20', start: '2:30 PM', staff: [_chitra]);
final _t3 = _t('t3', 'Called Off', '2026-11-24', status: 'cancelled');
final _trials = [_t1, _t2, _t3];

Employee _e(String id, String name) => Employee.fromJson({'_id': id, 'name': name, 'artistRole': 'artist', 'type': 'in-house', 'status': 'active', 'phone': '90000$id'});

class _Bookings extends BookingNotifier {
  _Bookings(this.list);
  final List<Booking> list;
  @override
  FutureOr<List<Booking>> build() => list;
}

// The calendar's own palettes (status colours of the Day chips, and the Month pills' service / status colours) — the two new colours
// must be none of them.
const _existingColours = [
  Color(0xFF5AA06E), Color(0xFFD07A7A), Color(0xFFDDA05F), Color(0xFF6699CC), Color(0xFF7C8E9A), //
  Color(0xFF601A29), Color(0xFFC9A66B), Color(0xFF0B5B37), Color(0xFFEF4444), Color(0xFFEAB308), Color(0xFF22C55E),
];

void main() {
  group('which works are influencer works', () {
    test('ticked on the booking; or "influencer" in the client name / service / remarks / a package (works from before the tick)', () {
      expect(_collab.isInfluencerWork, isTrue);
      expect(_legacy.isInfluencerWork, isTrue, reason: 'the old calendar titled them "INFLUENCER WORK"');
      expect(_b('5', 'Sara', '2026-11-26', remarks: 'Influencer collab — reel').isInfluencerWork, isTrue);
      expect(_b('6', 'Sana', '2026-11-26', items: [{'service': 'Influencer Shoot', 'selectedDates': ['2026-11-26']}]).isInfluencerWork, isTrue);
      expect(_meera.isInfluencerWork, isFalse);
      expect(_meera.influencerWork, isFalse);
    });

    test('the tick is read from and sent to the server, and copyWith keeps or changes it', () {
      expect(_collab.toJson()['influencerWork'], isTrue);
      expect(_meera.toJson()['influencerWork'], isFalse);
      expect(_collab.copyWith(customerName: 'X').influencerWork, isTrue);
      expect(_collab.copyWith(influencerWork: false).influencerWork, isFalse);
      expect(Booking.fromJson({..._meera.toJson(), '_id': '2', 'influencerWork': true}).influencerWork, isTrue);
    });
  });

  group('trials on the calendar: the rules', () {
    test('a trial\'s start time is read from free text (9:00 when none)', () {
      int m(String s) => trialStartMinutes(_t('x', 'X', '2026-11-18', start: s));
      expect([m('10:00 AM'), m('2:30 PM'), m('14:15'), m('12:00 AM'), m('12:30 PM'), m('')], [600, 870, 855, 0, 750, 540]);
    });

    test('a day\'s trials: only that day, earliest first', () {
      final late = _t('t9', 'Late', '2026-11-18', start: '5:00 PM');
      final early = _t('t8', 'Early', '2026-11-18', start: '8:00 AM');
      expect(trialsOnDay([late, _t1, _t2, early], DateTime(2026, 11, 18)).map((t) => t.clientName), ['Early', 'Trial Bride', 'Late']);
      expect(trialsOnDay(_trials, DateTime(2026, 11, 19)), isEmpty);
    });

    test('the staff filter works for trials as for works', () {
      List<String> under(String f, [Set<String> assoc = const {}]) =>
          _trials.where((t) => trialMatchesStaffFilter(t, f, assoc)).map((t) => t.id).toList();
      expect(under('all'), ['t1', 't2', 't3']);
      expect(under('unassigned'), ['t3']);
      expect(under('a1'), ['t1']);
      expect(under('a2'), ['t2']);
      expect(under(kAssociatesFilter, {'a2'}), ['t2']);
      expect(under(kAssociatesFilter), isEmpty, reason: 'no associates registered → nothing, never everything');
    });

    test('trials and influencer works each have their own colour — none of the calendar\'s other colours', () {
      expect(kTrialColor, isNot(kInfluencerColor));
      expect(_existingColours, isNot(contains(kTrialColor)));
      expect(_existingColours, isNot(contains(kInfluencerColor)));
      expect(trialColors(_t1), (bg: kTrialColor, fg: Colors.white));
      expect(trialColors(_t3).fg, kTrialColor, reason: 'a cancelled trial is pale teal');
      expect(trialColors(_t3).bg, isNot(kTrialColor));
    });
  });

  group('the Calendar Scheduler', () {
    Future<void> open(
      WidgetTester t, {
      String role = 'admin',
      String? employeeId,
      String? artistId,
      Size size = const Size(1400, 1100),
      List<Trial>? artistTrials,
      List<ZoneModel> zones = const [],
      Access? access,
      CalendarShow? remembered,
    }) async {
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final original = FlutterError.onError;
      FlutterError.onError = (d) {
        if (!d.toString().contains('overflowed')) original?.call(d); // the test font is wider than the real one
      };
      addTearDown(() => FlutterError.onError = original);
      await t.pumpWidget(ProviderScope(
        overrides: <Override>[
          bookingProvider.overrideWith(() => _Bookings(_bookings)),
          employeesProvider.overrideWith((ref) async => [_e('a1', 'Anu'), _e('a2', 'Chitra')]),
          zonesProvider.overrideWith((ref) async => zones),
          statesProvider.overrideWith((ref) async => const []),
          regionsProvider.overrideWith((ref) async => const []),
          districtsProvider.overrideWith((ref) async => const []),
          allTrialsProvider.overrideWith((ref) async {
            if (artistTrials != null) throw StateError('an artist must not load everyone\'s trials');
            return _trials;
          }),
          artistTrialsProvider.overrideWith((ref) async => artistTrials ?? const <Trial>[]),
          authSessionProvider.overrideWithValue(AuthSession(token: 't', userId: 'u', name: 'U', email: 'u@x', role: role, employeeId: employeeId ?? '')),
          if (access != null) effectiveAccessProvider.overrideWithValue(access),
          if (remembered != null) calendarShowProvider.overrideWith((ref) => remembered),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(body: CalendarScreen(initialFocusDate: DateTime(2026, 11, 16), initialArtistId: artistId)),
        ),
      ));
      await t.pumpAndSettle();
    }

    Future<void> showChoice(WidgetTester t, CalendarShow v) async {
      await t.tap(find.byKey(const Key('cal_show')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(Key('cal_show_${v.name}')));
      await t.pumpAndSettle();
    }

    // The colour of the coloured box a pill / chip text sits in.
    Color? boxColour(WidgetTester t, Finder inside) {
      for (final c in t.widgetList<Container>(find.ancestor(of: inside, matching: find.byType(Container)))) {
        final d = c.decoration;
        if (d is BoxDecoration && d.color != null && d.color != Colors.transparent) return d.color;
      }
      return null;
    }

    Finder trial(String id) => find.byKey(ValueKey('cal_trial_$id'));
    Finder mark = find.byKey(const Key('cal_influencer_mark'));

    testWidgets('as before, Works only: no trials; the key names the influencer colour', (t) async {
      await open(t);
      expect(find.text('Works only'), findsOneWidget, reason: 'the Show button');
      expect([trial('t1'), trial('t2'), trial('t3')].map((f) => f.evaluate().length), [0, 0, 0]);
      expect(find.descendant(of: find.byKey(const Key('cal_color_key')), matching: find.text('Influencer work')), findsOneWidget);
      expect(find.text('Trial'), findsNothing);
      expect(find.byType(MonthKpiStrip), findsOneWidget);
    });

    testWidgets('an influencer work is its own violet pill with a star, even next to the same artist\'s ordinary work', (t) async {
      await open(t);
      expect(find.text('ANU • PARTY'), findsOneWidget, reason: 'not merged into "ANU (2)"');
      expect(find.text('ANU • BRIDAL'), findsOneWidget);
      expect(boxColour(t, find.text('ANU • PARTY')), kInfluencerColor);
      expect(boxColour(t, find.text('ANU • BRIDAL')), isNot(kInfluencerColor));
      expect(find.descendant(of: find.ancestor(of: find.text('ANU • PARTY'), matching: find.byType(InkWell)).first, matching: mark), findsOneWidget);
      // the old one typed into the client name
      expect(boxColour(t, find.text('CHITRA • PARTY')), kInfluencerColor);
      // a cancelled influencer work stays red (it is not happening) but keeps its star
      final cancelled = find.text('CALLED COLLAB • PARTY');
      expect(cancelled, findsOneWidget);
      expect(boxColour(t, cancelled), const Color(0xFFEF4444));
      expect(find.descendant(of: find.ancestor(of: cancelled, matching: find.byType(InkWell)).first, matching: mark), findsOneWidget);
      expect(mark, findsNWidgets(3));
    });

    testWidgets('Works + trials: teal trial pills next to the works; the key adds Trial; a tap opens the trial', (t) async {
      await open(t);
      await showChoice(t, CalendarShow.both);
      expect([trial('t1'), trial('t2'), trial('t3')].map((f) => f.evaluate().length), [1, 1, 1]);
      expect(find.text('TRIAL • TRIAL BRIDE'), findsOneWidget);
      expect(boxColour(t, find.text('TRIAL • TRIAL BRIDE')), kTrialColor);
      expect(find.text('TRIAL • CALLED OFF • CANCELLED'), findsOneWidget);
      expect(boxColour(t, find.text('TRIAL • CALLED OFF • CANCELLED')), trialColors(_t3).bg, reason: 'pale once cancelled');
      expect(find.text('ANU • BRIDAL'), findsOneWidget, reason: 'the works stay');
      expect(find.descendant(of: find.byKey(const Key('cal_color_key')), matching: find.text('Trial')), findsOneWidget);
      expect(find.text('Works + trials'), findsOneWidget);
      await t.tap(trial('t1'));
      await t.pumpAndSettle();
      expect(find.text('Open trial'), findsOneWidget);
      expect(find.text('Trial Bride'), findsOneWidget);
      expect(boxColour(t, find.text('Trial Bride')), kTrialColor, reason: 'the popup is headed in the trial colour');
      expect(find.text('10:00 AM – 12:00 PM'), findsOneWidget);
    });

    testWidgets('Trials only: the works and their figures step aside', (t) async {
      await open(t);
      await showChoice(t, CalendarShow.trials);
      expect(find.text('ANU • BRIDAL'), findsNothing);
      expect(find.text('ANU • PARTY'), findsNothing);
      expect(find.byType(MonthKpiStrip), findsNothing);
      expect([trial('t1'), trial('t2'), trial('t3')].map((f) => f.evaluate().length), [1, 1, 1]);
      expect(find.text('Trials only'), findsOneWidget);
    });

    testWidgets('trials follow the staff filter', (t) async {
      await open(t, artistId: 'a2');
      await showChoice(t, CalendarShow.both);
      expect([trial('t1'), trial('t2'), trial('t3')].map((f) => f.evaluate().length), [0, 1, 0]);
    });

    testWidgets('a place filter hides trials (they have no place), and the key and the Show menu say so', (t) async {
      await open(t, zones: const [ZoneModel(id: 'z1', name: 'North', status: 'active')]);
      await showChoice(t, CalendarShow.both);
      expect(trial('t1'), findsOneWidget);
      await t.tap(find.text('Location'));
      await t.pumpAndSettle();
      await t.tap(find.text('All Zones').last);
      await t.pumpAndSettle();
      await t.tap(find.text('North').last);
      await t.pumpAndSettle();
      await t.tap(find.text('Done'));
      await t.pumpAndSettle();
      expect(trial('t1'), findsNothing);
      expect(find.text('Trial (hidden by the place filter)'), findsOneWidget);
      await t.tap(find.byKey(const Key('cal_show')));
      await t.pumpAndSettle();
      expect(find.textContaining('hidden while a place filter is on'), findsOneWidget);
    });

    testWidgets('a Month day with only a trial opens its Day view', (t) async {
      await open(t);
      await showChoice(t, CalendarShow.both);
      await t.tap(find.text('24').first);
      await t.pumpAndSettle();
      expect(find.text('1 trial'), findsOneWidget, reason: '24 Nov has only the cancelled trial');
      expect(find.byType(TrialCalendarChip), findsOneWidget);
    });

    testWidgets('Day view: trial chips sit among the works and the column counts both', (t) async {
      await open(t);
      await showChoice(t, CalendarShow.both);
      await t.tap(find.text('18').first);
      await t.pumpAndSettle();
      expect(find.byType(TrialCalendarChip), findsOneWidget);
      expect(find.text('2 works · 1 trial'), findsOneWidget);
      expect(find.text('1 work'), findsNothing);
      expect(boxColour(t, find.descendant(of: find.byType(TrialCalendarChip), matching: find.text('Trial Bride'))), kTrialColor);
      // Anu: two chips that day — the influencer one is violet with its star
      final inTrial = find.descendant(of: find.byType(TrialCalendarChip), matching: find.text('Anu')).evaluate().toSet();
      final anuChips = find.text('Anu').evaluate().where((e) => !inTrial.contains(e)).toList();
      expect(anuChips.length, 2, reason: 'the trial chip names Anu too — not counted');
      final colours = [for (final e in anuChips) boxColour(t, find.byWidget(e.widget))];
      expect(colours.where((c) => c == kInfluencerColor).length, 1);
      // its popup says it is an influencer work, headed in the influencer colour
      await t.tap(find.byWidget(anuChips[colours.indexOf(kInfluencerColor)].widget));
      await t.pumpAndSettle();
      final sub = find.textContaining('★ Influencer work');
      expect(sub, findsOneWidget);
      expect(boxColour(t, sub), kInfluencerColor);
      await t.tap(find.byIcon(Icons.close).last);
      await t.pumpAndSettle();
      // a day with only a trial is not "No works"
      await t.tap(find.byIcon(Icons.chevron_right).first);
      await t.pumpAndSettle();
      await t.tap(find.byIcon(Icons.chevron_right).first);
      await t.pumpAndSettle();
      expect(find.text('1 work · 1 trial'), findsOneWidget, reason: '20 Nov: the old influencer work + Chitra\'s trial');
    });

    testWidgets('on a phone: a teal dot on Month days with a trial, and trial cards in the Week list', (t) async {
      await open(t, size: const Size(390, 900));
      await showChoice(t, CalendarShow.both);
      final tealDots = t.widgetList<Container>(find.byType(Container)).where((c) {
        final d = c.decoration;
        return d is BoxDecoration && d.shape == BoxShape.circle && d.color == kTrialColor;
      });
      expect(tealDots.length, 3, reason: '18, 20 and 24 Nov');
      final violetDots = t.widgetList<Container>(find.byType(Container)).where((c) {
        final d = c.decoration;
        return d is BoxDecoration && d.shape == BoxShape.circle && d.color == kInfluencerColor;
      });
      expect(violetDots.length, 3, reason: 'the three influencer works');
      await t.tap(find.text('Week'));
      await t.pumpAndSettle();
      await t.tap(find.text('18').first);
      await t.pumpAndSettle();
      expect(find.byType(TrialCalendarCard), findsOneWidget);
      expect(find.text('INFLUENCER · PARTY'), findsOneWidget);
      expect(find.text('BRIDAL'), findsOneWidget);
    });

    testWidgets('an artist cannot see trials (as on the Trials screen); one whose role is given trials sees just their own', (t) async {
      await open(t, role: 'artist', employeeId: 'a1', artistTrials: [_t1]);
      expect(find.byKey(const Key('cal_show')), findsNothing);
      await t.pumpWidget(const SizedBox()); // a fresh ProviderScope for the second login
      await open(t, role: 'artist', employeeId: 'a1', artistTrials: [_t1], access: const Access(AppRole.artist, {'calendar', 'trials'}));
      await showChoice(t, CalendarShow.both);
      expect([trial('t1'), trial('t2'), trial('t3')].map((f) => f.evaluate().length), [1, 0, 0]);
      expect(t.takeException(), isNull);
    });

    testWidgets('someone who cannot see trials gets no Show button and no trials — even if "Works + trials" was left picked', (t) async {
      await open(t, role: 'sales', access: const Access(AppRole.sales, {'bookings'}), remembered: CalendarShow.both);
      expect(find.byKey(const Key('cal_show')), findsNothing);
      expect(trial('t1'), findsNothing);
      expect(find.text('Influencer work'), findsOneWidget, reason: 'the influencer colour is still explained');
    });
  });

  group('the Add Booking form', () {
    testWidgets('has an "Influencer work" tick, off to begin with', (t) async {
      t.view.physicalSize = const Size(1200, 2600);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final router = GoRouter(routes: [GoRoute(path: '/', builder: (_, _) => const Scaffold(body: AddBookingScreen()))]);
      await t.pumpWidget(ProviderScope(
        overrides: <Override>[
          packagesProvider.overrideWith((ref) async => <ServicePackage>[]),
          districtsProvider.overrideWith((ref) async => const []),
          addonServicesProvider.overrideWith((ref) async => <AddonService>[]),
        ],
        child: MaterialApp.router(theme: AppTheme.lightTheme, routerConfig: router),
      ));
      await t.pumpAndSettle();
      final tick = find.byKey(const Key('ab_influencer_work'));
      await t.ensureVisible(tick);
      expect(t.widget<CheckboxListTile>(tick).value, isFalse);
      expect(find.text('Influencer work'), findsOneWidget);
      await t.tap(tick);
      await t.pump();
      expect(t.widget<CheckboxListTile>(tick).value, isTrue);
    });
  });
}
