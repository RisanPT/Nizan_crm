import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nizan_crm/core/auth/access_control.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/models/auth_session.dart';
import 'package:nizan_crm/core/providers/auth_provider.dart';
import 'package:nizan_crm/core/routing/app_router.dart';
import 'package:nizan_crm/core/theme/app_theme.dart';
import 'package:nizan_crm/features/allocation/data/allocation_models.dart';
import 'package:nizan_crm/features/allocation/presentation/screens/allocation_board_screen.dart';
import 'package:nizan_crm/features/allocation/presentation/screens/artist_management_screen.dart';
import 'package:nizan_crm/features/allocation/presentation/widgets/allocation_preview_line.dart';
import 'package:nizan_crm/features/allocation/presentation/widgets/allocation_settings_dialog.dart';
import 'package:nizan_crm/features/allocation/presentation/widgets/allocation_sheet.dart';
import 'package:nizan_crm/features/allocation/presentation/widgets/booking_allocation_result.dart';
import 'package:nizan_crm/features/allocation/presentation/widgets/suggest_team_button.dart';
import 'package:nizan_crm/features/allocation/services/allocation_service.dart';
import 'dart:async';

import 'package:nizan_crm/features/bookings/controllers/booking_provider.dart';
import 'package:nizan_crm/features/bookings/data/booking.dart';
import 'package:nizan_crm/features/bookings/presentation/screens/booking_requests_screen.dart' show confirmBookingRequest;

// The smart booking allocation in the app: the "who takes this work" sheet (ranked teams with reasons, the suggestion chosen first, a
// reason asked for anything else, "assign anyway" on a clash, a slot just taken), the Allocation Board (slots, the queue and its
// filters, extras to OK), Artist Management (the rotation; read-only for a CRM member), and who may open what.

Finder _k(String key) => find.byKey(Key(key));

/// A bookings store that records each save's status.
class _Bookings extends BookingNotifier {
  final saved = <String>[];
  @override
  FutureOr<List<Booking>> build() => const [];
  @override
  Future<Booking> updateBooking(Booking booking, {bool confirmFleetConflict = false, bool confirmArtistConflict = false, Map<String, dynamic>? extraBody}) async {
    saved.add(booking.status);
    return booking;
  }
}

Booking _request() => Booking.fromJson({'_id': 'b1', 'bookingNumber': 'BK-1001', 'customerName': 'Amina K', 'status': 'pending', 'service': 'Bridal', 'totalPrice': 10000, 'selectedDates': ['2026-12-12'], 'bookingDate': '2026-12-12T03:30:00.000Z', 'serviceStart': '2026-12-12T03:30:00.000Z', 'serviceEnd': '2026-12-12T05:30:00.000Z'});

/// Booking Requests' Accept, as a button.
class _Accept extends ConsumerStatefulWidget {
  const _Accept();
  @override
  ConsumerState<_Accept> createState() => _AcceptState();
}

class _AcceptState extends ConsumerState<_Accept> {
  String result = '';
  @override
  Widget build(BuildContext context) => Column(children: [
        ElevatedButton(key: const Key('accept'), onPressed: () async {
          final ok = await confirmBookingRequest(context, ref, _request());
          setState(() => result = '$ok');
        }, child: const Text('accept')),
        Text(result, key: const Key('accept_result')),
      ]);
}

AuthSession _who(String role, {bool artistHead = false, bool head = false}) => AuthSession(token: 't', userId: 'u', name: 'U', email: 'u@x', role: role, artistHead: artistHead, isDepartmentHead: head);

Map<String, dynamic> _cand(String id, String name, String tier, {bool rec = false, int rank = 1, String reason = '', List<String> warnings = const [], bool approval = false}) => {
      'teamId': id,
      'teamName': name,
      'lead': {'id': 'L$id', 'name': name.replaceFirst('Team ', '')},
      'assistants': [
        {'id': 'A$id', 'name': '${name.replaceFirst('Team ', '')}\'s assistant'},
      ],
      'tier': tier,
      'rank': rank,
      'recommended': rec,
      'reason': reason,
      'warnings': warnings,
      'slots': [
        {'day': '2026-12-12', 'half': 'morning', 'used': 1, 'of': 2},
      ],
      'needsApproval': approval,
    };

Map<String, dynamic> _alloc({bool eligible = true, String mode = 'suggest', bool timeSet = true}) => {
      'mode': mode,
      'eligible': eligible,
      'canConfirm': true,
      'bookingId': 'b1',
      'bookingNumber': 'BK-1001',
      'customerName': 'Amina K',
      'updatedAt': '2026-11-20T05:00:00.000Z',
      'message': eligible ? '' : 'This booking was made before the allocation went live — its artists are assigned as before.',
      'units': eligible
          ? [
              {
                'unitKey': 'b',
                'label': 'Bridal Makeup',
                'days': [
                  {'day': '2026-12-12', 'start': '12:00', 'end': '14:00', 'half': 'morning', 'timeSet': timeSet, 'place': {'label': 'Calicut', 'precision': 'pincode'}},
                ],
                'candidates': [
                  _cand('t1', 'Team Nihala', 'continue', rec: true, rank: 1, reason: 'Same area as her 9:00 AM Calicut job — 12 min (7 km) away'),
                  _cand('t2', 'Team Irfana', 'new_route', rank: 2, reason: 'Starts a new route — next in rotation', warnings: ['Irfana\'s assistant is on #2612 at 9:00 AM — change assistant']),
                  _cand('t3', 'Team Sandra', 'blocked', rank: 3, reason: 'Both morning slots taken'),
                ],
              },
            ]
          : [],
    };

DioException _refusal(int status, Map<String, dynamic> body) => DioException(requestOptions: RequestOptions(path: '/x'), response: Response(requestOptions: RequestOptions(path: '/x'), statusCode: status, data: body), type: DioExceptionType.badResponse);

class _FakeAlloc extends AllocationService {
  _FakeAlloc() : super(Dio());
  Map<String, dynamic> booking = _alloc();
  AllocationSettings s = AllocationSettings.fromJson({'mode': 'suggest', 'canAllocate': true, 'canEdit': true, 'canChangeMode': true});
  final confirms = <({List<Map<String, dynamic>> picks, bool conflicts, String? updatedAt, String source})>[];
  Object? Function(int call)? confirmScript;
  Map<String, dynamic> board = {};
  Map<String, dynamic> teamsPage = {};
  final approved = <String>[];
  final many = <List<Map<String, dynamic>>>[];
  final orders = <List<String>>[];
  Map<String, dynamic> status = {};
  final savedSettings = <Map<String, dynamic>>[];

  @override
  Future<AllocationSettings> settings() async => s;
  @override
  Future<AllocationSettings> saveSettings(Map<String, dynamic> body) async {
    savedSettings.add(body);
    return s;
  }

  Map<String, dynamic> Function(Map<String, dynamic> draft)? previewScript;
  final previews = <Map<String, dynamic>>[];
  @override
  Future<AllocationPreview> preview(Map<String, dynamic> draft) async {
    previews.add(draft);
    return AllocationPreview.fromJson(previewScript?.call(draft) ?? {'on': false});
  }

  @override
  Future<BookingAllocationStatus> bookingStatus(String bookingId) async => BookingAllocationStatus.fromJson({'bookingId': bookingId, ...status});
  @override
  Future<BookingAllocation> forBooking(String bookingId) async => BookingAllocation.fromJson(booking);
  @override
  Future<Map<String, dynamic>> confirm({required String bookingId, String? updatedAt, required List<Map<String, dynamic>> picks, String source = 'requests', bool confirmConflicts = false}) async {
    confirms.add((picks: picks, conflicts: confirmConflicts, updatedAt: updatedAt, source: source));
    final err = confirmScript?.call(confirms.length);
    if (err != null) throw AllocationRefusal.of(AppException(err)) ?? err;
    return {
      'results': [
        {'unitKey': 'b', 'teamName': 'Team Nihala', 'pending': false},
      ],
    };
  }

  @override
  Future<DayBoard> day(String dayIso) async => DayBoard.fromJson(board);
  @override
  Future<void> approveExtra(String allocationId) async => approved.add(allocationId);
  @override
  Future<List<Map<String, dynamic>>> confirmMany(List<Map<String, dynamic>> items) async {
    many.add(items);
    return [for (final _ in items) {'ok': true}];
  }

  @override
  Future<TeamsPage> teams({String? day, bool inactive = false}) async => TeamsPage.fromJson(teamsPage);
  @override
  Future<void> reorderTeams(List<String> ids) async => orders.add(ids);
}

Future<_FakeAlloc> _pump(WidgetTester t, Widget child, {_FakeAlloc? f, AuthSession? who, Size size = const Size(1200, 1600)}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final fake = f ?? _FakeAlloc();
  await t.pumpWidget(ProviderScope(
    overrides: [
      allocationServiceProvider.overrideWithValue(fake),
      authSessionProvider.overrideWithValue(who ?? _who('crm')),
    ],
    child: MaterialApp(theme: AppTheme.lightTheme, home: Scaffold(body: child)),
  ));
  await t.pumpAndSettle();
  return fake;
}

/// A button that opens the sheet (as Booking Requests / the Board do) and shows what it returned.
class _Opener extends StatefulWidget {
  const _Opener({this.pick = false});
  final bool pick;
  @override
  State<_Opener> createState() => _OpenerState();
}

class _OpenerState extends State<_Opener> {
  String result = '';
  @override
  Widget build(BuildContext context) => Column(children: [
        ElevatedButton(
          key: const Key('open'),
          onPressed: () async {
            if (widget.pick) {
              final p = await pickTeamFor(context, bookingId: 'b1', unitKey: 'b');
              setState(() => result = p == null ? 'none' : '${p.teamName}|${p.chosenRank}|${p.overrideReason}|${p.assistants.length}');
            } else {
              final r = await showAllocationSheet(context, bookingId: 'b1', primaryLabel: 'Confirm & allocate', secondaryLabel: 'Confirm without artist', onSecondary: () async {});
              setState(() => result = '$r');
            }
          },
          child: const Text('open'),
        ),
        Text(result, key: const Key('result')),
      ]);
}

Map<String, dynamic> _assigned() => {
      'bookingNumber': 'BK-2630',
      'mode': 'suggest',
      'auto': true,
      'eligible': true,
      'status': 'confirmed',
      'units': [
        {
          'unitKey': 'b',
          'label': 'Bridal Makeup',
          'days': [
            {'day': '2026-12-12', 'start': '10:30', 'half': 'morning', 'place': 'Kozhikode'},
          ],
          'status': 'assigned',
          'teamName': 'Team Nihala',
          'lead': 'Nihala',
          'assistants': ['Ameena'],
          'how': 'auto',
          'reason': 'Starts a new route — prefers Kozhikode',
        },
      ],
    };
Map<String, dynamic> _waiting() => {
      ..._assigned(),
      'units': [
        {
          'unitKey': 'b',
          'label': 'Party makeup',
          'days': [
            {'day': '2026-12-12', 'start': '18:00', 'half': 'evening', 'place': 'Kollam'},
          ],
          'status': 'waiting',
          'reason': 'Waiting for CRM — No free artist has Kollam as a preferred location',
        },
      ],
    };

/// Add Booking's step after the save, as a button: the result of the automatic allocation (→ whether it was shown).
class _AfterSave extends ConsumerStatefulWidget {
  const _AfterSave();
  @override
  ConsumerState<_AfterSave> createState() => _AfterSaveState();
}

class _AfterSaveState extends ConsumerState<_AfterSave> {
  String result = '';
  @override
  Widget build(BuildContext context) => Column(children: [
        ElevatedButton(key: const Key('saved'), onPressed: () async {
          final shown = await showBookingAllocationResult(context, ref, bookingId: 'b9');
          setState(() => result = '$shown');
        }, child: const Text('saved')),
        Text(result, key: const Key('saved_result')),
      ]);
}

/// Add Booking's venue row, as far as the preview cares: the pincode field and the packages.
class _Form extends StatefulWidget {
  const _Form({this.items = const []});
  final List<Map<String, dynamic>> items;
  @override
  State<_Form> createState() => _FormState();
}

class _FormState extends State<_Form> {
  final pin = TextEditingController();
  @override
  void dispose() {
    pin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(children: [
        TextField(key: const Key('pin'), controller: pin),
        AllocationPreviewLine(pincodeCtrl: pin, items: widget.items, debounce: Duration.zero),
      ]);
}

Map<String, dynamic> _previewArea({List<Map<String, dynamic>> preferred = const [], int teams = 1}) => {
      'on': true,
      'auto': true,
      'area': {'pincode': '679576', 'districtName': 'Malappuram', 'preferredTeams': preferred, 'teams': teams},
      'units': [],
    };
const _fayiza = {'teamName': 'Team Fayiza Irfana Bl', 'lead': 'Fayiza Irfana Bl', 'assistants': ['Anjali TK'], 'match': 'district'};

class _Rules extends StatelessWidget {
  const _Rules(this.s);
  final AllocationSettings s;
  @override
  Widget build(BuildContext context) => ElevatedButton(key: const Key('rules'), onPressed: () => showAllocationSettingsDialog(context, s), child: const Text('rules'));
}

void main() {
  test('what the server sends reads into the models; a refusal is read in its own words', () {
    final a = BookingAllocation.fromJson(_alloc());
    expect(a.units.single.recommended!.teamName, 'Team Nihala');
    expect(a.units.single.candidates[2].blocked, isTrue);
    final r = AllocationRefusal.of(AppException(_refusal(409, {'code': 'ARTIST_CONFLICT', 'message': 'Team Sandra: Already on #2611', 'problems': [{'team': 'Team Sandra', 'reason': 'Already on #2611 9:00 AM–11:00 AM'}], 'warnings': []})));
    expect([r!.code, r.isConflict, r.problems.single], ['ARTIST_CONFLICT', true, 'Team Sandra: Already on #2611 9:00 AM–11:00 AM']);
    expect(AllocationRefusal.of(AppException(_refusal(500, {'message': 'x'}))), isNull);
    expect(fmtHHMM('14:30'), '2:30 PM');
  });

  group('who takes this work — the sheet', () {
    testWidgets('the teams ranked with their reasons; the suggestion is chosen first; confirming sends it', (t) async {
      final f = await _pump(t, const _Opener());
      await t.tap(_k('open'));
      await t.pumpAndSettle();
      expect(_k('alloc_sheet'), findsOneWidget);
      expect(find.textContaining('Who takes #BK-1001 · Amina K?'), findsOneWidget);
      expect(find.text('Same area as her 9:00 AM Calicut job — 12 min (7 km) away'), findsOneWidget);
      expect(_k('alloc_suggested_t1'), findsOneWidget);
      expect(find.text('Both morning slots taken'), findsNothing, reason: 'the teams that are not free are folded away');
      await t.tap(_k('alloc_show_all_b'));
      await t.pumpAndSettle();
      expect(find.text('Both morning slots taken'), findsOneWidget);
      await t.tap(_k('alloc_confirm'));
      await t.pumpAndSettle();
      expect(f.confirms.single.picks.single, {'unitKey': 'b', 'teamId': 't1', 'assistantIds': ['At1']});
      expect(f.confirms.single.updatedAt, '2026-11-20T05:00:00.000Z', reason: 'a stale screen is caught by the server');
      expect(t.widget<Text>(_k('result')).data, 'true');
    });

    testWidgets('choosing another team asks why; an assistant can be taken off; a blocked team can\'t be chosen', (t) async {
      final f = await _pump(t, const _Opener());
      await t.tap(_k('open'));
      await t.pumpAndSettle();
      await t.tap(_k('alloc_cand_b_t2'));
      await t.pumpAndSettle();
      expect(find.text('Irfana\'s assistant is on #2612 at 9:00 AM — change assistant'), findsOneWidget);
      await t.tap(_k('alloc_confirm'));
      await t.pumpAndSettle();
      expect(f.confirms, isEmpty);
      expect(find.textContaining('pick a reason'), findsOneWidget);
      await t.tap(_k('alloc_reason_1'));
      await t.tap(_k('alloc_asst_At2'));
      await t.pumpAndSettle();
      await t.tap(_k('alloc_show_all_b'));
      await t.pumpAndSettle();
      await t.tap(_k('alloc_cand_b_t3'));
      await t.pumpAndSettle();
      await t.ensureVisible(_k('alloc_confirm'));
      await t.tap(_k('alloc_confirm'));
      await t.pumpAndSettle();
      expect(f.confirms.single.picks.single, {'unitKey': 'b', 'teamId': 't2', 'assistantIds': <String>[], 'overrideReason': 'Better route'});
    });

    testWidgets('a clash: "assign anyway?" — yes repeats with the confirmation', (t) async {
      final f = _FakeAlloc()..confirmScript = (n) => n == 1 ? _refusal(409, {'code': 'ARTIST_CONFLICT', 'message': 'Team Nihala: Already on #2611', 'problems': [{'team': 'Team Nihala', 'reason': 'Already on #2611 9:00 AM–11:00 AM'}]}) : null;
      await _pump(t, const _Opener(), f: f);
      await t.tap(_k('open'));
      await t.pumpAndSettle();
      await t.tap(_k('alloc_confirm'));
      await t.pumpAndSettle();
      expect(find.text('Team Nihala: Already on #2611 9:00 AM–11:00 AM'), findsOneWidget);
      await t.tap(_k('artist_conflict_confirm'));
      await t.pumpAndSettle();
      expect(f.confirms.map((c) => c.conflicts), [false, true]);
      expect(t.widget<Text>(_k('result')).data, 'true');
    });

    testWidgets('a slot just taken: said in words, the suggestions read again, nothing closes', (t) async {
      final f = _FakeAlloc()..confirmScript = (_) => _refusal(409, {'code': 'SLOT_TAKEN', 'message': 'That slot was just taken by another booking — the suggestions have been refreshed.'});
      await _pump(t, const _Opener(), f: f);
      await t.tap(_k('open'));
      await t.pumpAndSettle();
      await t.tap(_k('alloc_confirm'));
      await t.pumpAndSettle();
      expect(t.widget<Text>(_k('alloc_error')).data, contains('just taken'));
      expect(_k('alloc_sheet'), findsOneWidget);
    });

    testWidgets('a booking from before go-live: no suggestions — the other way out still works', (t) async {
      final f = _FakeAlloc()..booking = _alloc(eligible: false);
      await _pump(t, const _Opener(), f: f);
      await t.tap(_k('open'));
      await t.pumpAndSettle();
      expect(find.textContaining('made before the allocation went live'), findsOneWidget);
      expect(_k('alloc_confirm'), findsNothing);
      await t.tap(_k('alloc_secondary'));
      await t.pumpAndSettle();
      expect(t.widget<Text>(_k('result')).data, 'false');
    });

    testWidgets('time not set: the sheet says so', (t) async {
      await _pump(t, const _Opener(), f: _FakeAlloc()..booking = _alloc(timeSet: false));
      await t.tap(_k('open'));
      await t.pumpAndSettle();
      expect(_k('alloc_time_not_set_b'), findsOneWidget);
    });

    testWidgets('pick mode (Manage Booking): the team comes back for the form, nothing is sent', (t) async {
      final f = await _pump(t, const _Opener(pick: true));
      await t.tap(_k('open'));
      await t.pumpAndSettle();
      await t.tap(_k('alloc_confirm'));
      await t.pumpAndSettle();
      expect(t.widget<Text>(_k('result')).data, 'Team Nihala|1||1');
      expect(f.confirms, isEmpty);
    });

    testWidgets('a phone (390 wide): the sheet fits', (t) async {
      await _pump(t, const _Opener(), size: const Size(390, 844));
      await t.tap(_k('open'));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(_k('alloc_confirm'), findsOneWidget);
    });
  });

  group('Booking Requests: Accept', () {
    Future<_Bookings> pumpAccept(WidgetTester t, _FakeAlloc f, AuthSession who) async {
      final store = _Bookings();
      t.view.physicalSize = const Size(1200, 1600);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(ProviderScope(
        overrides: [allocationServiceProvider.overrideWithValue(f), authSessionProvider.overrideWithValue(who), bookingProvider.overrideWith(() => store)],
        child: MaterialApp(theme: AppTheme.lightTheme, home: const Scaffold(body: _Accept())),
      ));
      await t.pumpAndSettle();
      return store;
    }

    testWidgets('suggestions on: Accept opens "who takes it" — Confirm & allocate confirms the request, then the team', (t) async {
      final f = _FakeAlloc();
      final store = await pumpAccept(t, f, _who('crm'));
      await t.tap(_k('accept'));
      await t.pumpAndSettle();
      expect(_k('alloc_sheet'), findsOneWidget);
      expect(store.saved, isEmpty, reason: 'nothing confirmed until a choice is made');
      await t.tap(_k('alloc_confirm'));
      await t.pumpAndSettle();
      expect(store.saved, ['confirmed']);
      expect(f.confirms.single.updatedAt, isNull, reason: 'the status save changed the booking: no stale-screen check after it');
      expect(t.widget<Text>(_k('accept_result')).data, 'true');
    });

    testWidgets('"Confirm without artist" confirms only the request; closing the sheet confirms nothing', (t) async {
      final f = _FakeAlloc();
      final store = await pumpAccept(t, f, _who('crm'));
      await t.tap(_k('accept'));
      await t.pumpAndSettle();
      await t.tap(_k('alloc_secondary'));
      await t.pumpAndSettle();
      expect([store.saved, f.confirms.length], [['confirmed'], 0]);
      await t.tap(_k('accept'));
      await t.pumpAndSettle();
      await t.tap(_k('alloc_close'));
      await t.pumpAndSettle();
      expect(store.saved, ['confirmed'], reason: 'closed: not confirmed again');
      expect(t.widget<Text>(_k('accept_result')).data, 'false');
    });

    testWidgets('suggestions off: Accept confirms at once, as before', (t) async {
      final off = _FakeAlloc()..s = AllocationSettings.fromJson({'mode': 'off'});
      final store = await pumpAccept(t, off, _who('crm'));
      await t.tap(_k('accept'));
      await t.pumpAndSettle();
      expect([_k('alloc_sheet').evaluate().isEmpty, store.saved], [true, ['confirmed']]);
    });

    testWidgets('someone who can\'t allocate (sales): Accept confirms at once, as before', (t) async {
      final sales = await pumpAccept(t, _FakeAlloc(), _who('sales'));
      await t.tap(_k('accept'));
      await t.pumpAndSettle();
      expect([_k('alloc_sheet').evaluate().isEmpty, sales.saved], [true, ['confirmed']]);
    });
  });

  test('the picked team fills the form: lead + assistants replace the old ones; the driver stays', () {
    final current = [
      const BookingAssignment(employeeId: 'old', artistName: 'Old', role: 'Lead Artist', type: '', roleType: 'lead'),
      const BookingAssignment(employeeId: 'drv', artistName: 'Driver', role: 'Driver', type: '', roleType: 'driver'),
    ];
    final out = withPickedTeam(current, const AllocationPick(unitKey: 'b', teamId: 't1', teamName: 'Team Nihala', lead: TeamPerson(id: 'n', name: 'Nihala'), assistants: [TeamPerson(id: 'a', name: 'Ameena')]), const []);
    expect(out.map((a) => '${a.employeeId}:${a.roleType}'), ['n:lead', 'a:assistant', 'drv:driver']);
    expect(const AllocationPick(unitKey: 'i:0', teamId: 't2', teamName: 'x', lead: TeamPerson(id: 'l', name: 'L'), chosenRank: 2, topTeamId: 't1', overrideReason: 'Better route').toIntent(), {'unitKey': 'i:0', 'teamId': 't2', 'chosenRank': 2, 'topTeamId': 't1', 'tier': '', 'overrideReason': 'Better route'});
  });

  group('the Allocation Board', () {
    Map<String, dynamic> board() => {
          'day': '2026-12-12',
          'mode': 'suggest',
          'canAllocate': true,
          'canApproveExtra': true,
          'settings': {'travelLimitMin': 30, 'extrasPerDay': 2},
          'summary': {'planned': 18, 'booked': 3, 'extrasUsed': 1, 'extrasPending': 1, 'unallocated': 2},
          'teams': [
            {
              'id': 't1', 'name': 'Team Nihala', 'status': 'has_room', 'used': 2, 'of': 3, 'lead': {'id': 'L1', 'name': 'Nihala'}, 'assistants': [{'id': 'A1', 'name': 'Ameena'}], 'freeFromText': 'free from 2:00 PM, after the Calicut job',
              'jobs': [{'bookingId': 'b1', 'bookingNumber': 'B1', 'customerName': 'Amina K', 'start': '09:00', 'end': '11:00', 'half': 'morning', 'place': {'label': 'Calicut'}}],
              'slots': [
                {'key': 'M1', 'half': 'morning', 'job': {'bookingId': 'b1', 'bookingNumber': 'B1', 'customerName': 'Amina K', 'start': '09:00', 'end': '11:00', 'label': 'Calicut'}},
                {'key': 'M2', 'half': 'morning', 'job': null},
                {'key': 'E1', 'half': 'evening', 'job': null},
              ],
            },
            {'id': 't2', 'name': 'Team Irfana', 'status': 'on_leave', 'used': 0, 'of': 3, 'leave': {'halfDay': 'none'}, 'slots': [{'key': 'E1', 'half': 'evening', 'job': null}]},
          ],
          'queue': [
            {'bookingId': 'q1', 'unitKey': 'b', 'bookingNumber': 'Q1', 'customerName': 'Diya', 'label': 'Reception', 'start': '17:00', 'end': '19:00', 'half': 'evening', 'place': {'label': 'Calicut'}, 'top': {'teamId': 't1', 'teamName': 'Team Nihala', 'tier': 'continue', 'reason': 'Same area as her 9:00 AM Calicut job'}, 'nearTeams': [{'teamId': 't1', 'minutes': 12}]},
            {'bookingId': 'q2', 'unitKey': 'b', 'bookingNumber': 'Q2', 'customerName': 'Neha', 'label': 'Party', 'start': '10:00', 'end': '11:00', 'half': 'morning', 'place': {'label': 'Kollam'}, 'top': null, 'nearTeams': []},
          ],
          'pendingExtras': [
            {'id': 'x1', 'bookingNumber': 'X1', 'customerName': 'Fathima', 'day': '2026-12-12', 'start': '12:00', 'teamName': 'Team Sandra', 'askedBy': 'Sana'},
          ],
          'week': [
            for (final (i, d) in ['2026-12-07', '2026-12-08', '2026-12-09', '2026-12-10', '2026-12-11', '2026-12-12', '2026-12-13'].indexed) {'day': d, 'booked': i == 5 ? 3 : i, 'extras': i == 5 ? 1 : 0, 'toAllocate': i == 5 ? 2 : 1, 'pending': i == 5 ? 1 : 0},
          ],
        };

    testWidgets('each team\'s slots, the extras to OK, the queue with the suggestion; the filters narrow it', (t) async {
      final f = _FakeAlloc()..board = board();
      await _pump(t, const AllocationBoardScreen(initialDay: '2026-12-12'), f: f, who: _who('artist_head'));
      expect(find.text('3/18'), findsOneWidget);
      expect(_k('board_team_t1'), findsOneWidget);
      expect(t.widget<Text>(_k('board_status_t2')).data, 'On leave');
      expect(_k('board_slot_away_E1'), findsOneWidget, reason: 'her empty slot says "on leave", not "free"');
      expect(find.text('Free from 2:00 PM, after the Calicut job'), findsOneWidget);
      expect(_k('board_slot_M1_B1'), findsOneWidget);
      expect(_k('board_queue_q1_b'), findsOneWidget);
      expect(_k('board_queue_q2_b'), findsOneWidget);
      expect(find.textContaining('Suggested: Team Nihala'), findsOneWidget);
      await t.tap(_k('board_filter_half_evening'));
      await t.pumpAndSettle();
      expect(_k('board_queue_q2_b'), findsNothing, reason: 'a morning work is filtered out');
      expect(_k('board_queue_q1_b'), findsOneWidget);
      await t.tap(_k('board_approve_x1'));
      await t.pumpAndSettle();
      expect(f.approved, ['x1']);
      await t.tap(_k('board_allocate_all'));
      await t.pumpAndSettle();
      await t.tap(_k('board_allocate_all_ok'));
      await t.pumpAndSettle();
      expect(f.many.single, [
        {'bookingId': 'q1', 'picks': [{'unitKey': 'b', 'teamId': 't1'}]},
      ]);
    });

    testWidgets('a slot card names its CLIENT, time and place; the row shows the day, first job and place; the day in full lists each job', (t) async {
      final f = _FakeAlloc()..board = board();
      await _pump(t, const AllocationBoardScreen(initialDay: '2026-12-12'), f: f, who: _who('crm'));
      expect(t.widget<Text>(_k('board_slot_client_M1')).data, 'Amina K');
      expect(find.descendant(of: _k('board_slot_M1_B1'), matching: find.text('9:00 AM')), findsOneWidget);
      expect(find.descendant(of: _k('board_slot_M1_B1'), matching: find.text('Calicut')), findsOneWidget);
      expect(find.text('Sat, 12 Dec 2026 • 9:00 AM'), findsOneWidget);
      expect(find.text('Sat, 12 Dec 2026 • on leave'), findsOneWidget, reason: 'Irfana is on leave');
      // the four cards: booked, extras, to allocate, extras waiting
      expect(find.descendant(of: _k('board_booked'), matching: find.text('3/18')), findsOneWidget);
      expect(find.descendant(of: _k('board_extras'), matching: find.text('1/2')), findsOneWidget);
      expect(find.descendant(of: _k('board_unallocated'), matching: find.text('2')), findsOneWidget);
      expect(find.descendant(of: _k('board_pending'), matching: find.text('1')), findsOneWidget);
      expect(_k('board_day_t1'), findsNothing);
      await t.tap(_k('board_expand_t1'));
      await t.pumpAndSettle();
      expect(find.descendant(of: _k('board_day_t1'), matching: find.text('9:00 AM–11:00 AM')), findsOneWidget);
      expect(find.descendant(of: _k('board_day_t1'), matching: find.text('Amina K · #B1 · Calicut')), findsOneWidget);
    });

    testWidgets('"New Allocation": choose the work, its allocation opens; "Learn more" explains the rule', (t) async {
      final f = _FakeAlloc()..board = board();
      await _pump(t, const AllocationBoardScreen(initialDay: '2026-12-12'), f: f, who: _who('crm'));
      await t.tap(_k('board_new_allocation'));
      await t.pumpAndSettle();
      expect(_k('board_pick_q1_b'), findsOneWidget);
      await t.tap(_k('board_pick_q1_b'));
      await t.pumpAndSettle();
      expect(_k('alloc_sheet'), findsOneWidget);
      await t.tap(_k('alloc_close'));
      await t.pumpAndSettle();
      await t.tap(_k('board_learn_more'));
      await t.pumpAndSettle();
      expect(find.textContaining('within 30 min of her job'), findsOneWidget);
    });

    testWidgets('nothing left to allocate: "No more allocations"; the queue says every work has its artist', (t) async {
      final f = _FakeAlloc()..board = {...board(), 'queue': <Map<String, dynamic>>[], 'summary': {'planned': 18, 'booked': 3, 'unallocated': 0}};
      await _pump(t, const AllocationBoardScreen(initialDay: '2026-12-12'), f: f, who: _who('crm'));
      expect(_k('board_all_done'), findsOneWidget);
      expect(find.text('No more allocations'), findsOneWidget);
      expect(t.widget<Text>(_k('board_queue_empty')).data, 'Every new work of the day has its artist.');
    });

    testWidgets('a phone: Teams | To allocate tabs, and it fits', (t) async {
      await _pump(t, const AllocationBoardScreen(initialDay: '2026-12-12'), f: _FakeAlloc()..board = board(), size: const Size(390, 844));
      expect(t.takeException(), isNull);
      expect(_k('board_tab_queue'), findsOneWidget);
      await t.tap(_k('board_tab_queue'));
      await t.pumpAndSettle();
      expect(_k('board_queue_q1_b'), findsOneWidget);
    });
  });

  group('Artist Management', () {
    Map<String, dynamic> page({bool canManage = true}) => {
          'day': '2026-12-12',
          'canManage': canManage,
          'teams': [
            {'id': 't1', 'name': 'Team Nihala', 'rotationOrder': 1, 'active': true, 'lead': {'id': 'L1', 'name': 'Nihala'}, 'assistants': [{'id': 'A1', 'name': 'Ameena'}], 'slots': {'morning': 2, 'evening': 1}, 'preferredDistricts': [{'id': 'd1', 'name': 'Calicut'}], 'load': {'status': 'has_room', 'used': 1, 'of': 3, 'jobs': [{'bookingNumber': 'B1', 'start': '09:00', 'label': 'Calicut'}], 'freeFromText': 'free from 11:00 AM, after the Calicut job'}},
            {'id': 't2', 'name': 'Team Irfana', 'rotationOrder': 2, 'active': true, 'lead': {'id': 'L2', 'name': 'Irfana'}, 'slots': {'morning': 2, 'evening': 1}, 'warnings': ['Ameena is also on Team Nihala']},
            {'id': 't3', 'name': 'Team Old', 'rotationOrder': 3, 'active': false, 'lead': {'id': 'L3', 'name': 'Old'}, 'slots': {'morning': 2, 'evening': 1}},
          ],
        };

    testWidgets('the teams in rotation order with their people, places, slots and the day\'s load; editors see Add and Edit', (t) async {
      await _pump(t, const ArtistManagementScreen(), f: _FakeAlloc()..teamsPage = page(), who: _who('crm_manager'));
      expect(find.text('Team Nihala'), findsOneWidget);
      expect(find.text('Calicut'), findsOneWidget);
      expect(find.text('2 morning + 1 evening'), findsNWidgets(3));
      expect(t.widget<Text>(_k('am_load_t1')).data, startsWith('1/3 booked · 9:00 AM Calicut'));
      expect(find.text('Ameena is also on Team Nihala'), findsOneWidget);
      expect(find.text('Not in the rotation'), findsOneWidget);
      expect(_k('am_add'), findsOneWidget);
      expect(_k('am_edit_t1'), findsOneWidget);
      expect(find.text('Suggestions: On'), findsOneWidget);
    });

    testWidgets('a CRM member reads it: no Add, no Edit, no drag', (t) async {
      final f = _FakeAlloc()
        ..teamsPage = page(canManage: false)
        ..s = AllocationSettings.fromJson({'mode': 'suggest'});
      await _pump(t, const ArtistManagementScreen(), f: f, who: _who('crm'));
      expect(_k('am_add'), findsNothing);
      expect(_k('am_edit_t1'), findsNothing);
      expect(_k('am_settings'), findsNothing);
      expect(_k('am_rotation'), findsNothing);
    });
  });

  test('who may open and do what (the server decides the same way)', () {
    Access a(String role, {bool artistHead = false, bool head = false}) => Access.of(_who(role, artistHead: artistHead, head: head));
    // the whole CRM team keeps the teams (main artist, assistants, preferred locations)
    expect([a('crm').canSeeAllocation, a('crm').canAllocateArtists, a('crm').canApproveExtraSlots, a('crm').canManageArtistTeams], [true, true, false, true]);
    // a salesperson reads their booking's artist (or why it waits) — not the board
    expect([a('sales').canSeeBookingAllocation, a('sales').canSeeAllocation, a('crm').canSeeBookingAllocation, a('artist').canSeeBookingAllocation], [true, false, true, false]);
    expect([a('crm_manager').canManageArtistTeams, a('crm_manager').canApproveExtraSlots], [true, false]);
    expect([a('artist_head').canAllocateArtists, a('artist_head').canApproveExtraSlots, a('artist_head').canManageArtistTeams], [true, true, true]);
    expect([a('regional_artist_head').canSeeAllocation, a('regional_artist_head').canAllocateArtists], [true, false]);
    expect([a('artist', artistHead: true).canApproveExtraSlots, a('artist').canSeeAllocation], [true, false]);
    expect([a('sales').canSeeAllocation, a('ceo').canSeeAllocation, a('ceo').canAllocateArtists], [false, true, false]);
    expect(isRouteAllowed('/booking/allocation', a('crm')), isTrue);
    expect(isRouteAllowed('/artist-management', a('crm')), isTrue);
    expect(isRouteAllowed('/booking/allocation', a('sales')), isFalse, reason: 'checked before the generic /booking rule');
    expect(isRouteAllowed('/artist-management', a('ceo')), isTrue);
  });

  group('automatic allocation', () {
    testWidgets('a salesperson saves a booking: "Artist assigned — Team Nihala, Nihala with Ameena, automatically"; nothing to change', (t) async {
      final f = _FakeAlloc()..status = _assigned();
      await _pump(t, const _AfterSave(), f: f, who: _who('sales'));
      await t.tap(_k('saved'));
      await t.pumpAndSettle();
      expect(_k('alloc_result'), findsOneWidget);
      expect(find.text('Artist assigned'), findsOneWidget);
      expect(find.text('Team Nihala'), findsOneWidget);
      expect(find.text('Nihala, with Ameena · assigned automatically'), findsOneWidget);
      expect(find.text('Bridal Makeup · Sat 12 Dec, 10:30 AM · Kozhikode'), findsOneWidget);
      expect(t.widget<Text>(_k('alloc_reason_b')).data, 'Starts a new route — prefers Kozhikode');
      expect(_k('alloc_result_allocate'), findsNothing, reason: 'sales can not change the team');
      await t.tap(_k('alloc_result_ok'));
      await t.pumpAndSettle();
      expect(t.widget<Text>(_k('saved_result')).data, 'true');
    });

    testWidgets('it waits for CRM: the salesperson sees why, and that a notification will come', (t) async {
      final f = _FakeAlloc()..status = _waiting();
      await _pump(t, const _AfterSave(), f: f, who: _who('sales'));
      await t.tap(_k('saved'));
      await t.pumpAndSettle();
      expect(find.text('Sent to CRM for the artist'), findsOneWidget);
      expect(find.text('Waiting for CRM to assign the artist'), findsOneWidget);
      expect(t.widget<Text>(_k('alloc_reason_b')).data, 'No free artist has Kollam as a preferred location');
      expect(_k('alloc_result_wait_note'), findsOneWidget);
    });

    testWidgets('automatic allocation off (or a booking from before): nothing shown — Add Booking goes on as before', (t) async {
      final f = _FakeAlloc()..status = {..._assigned(), 'auto': false};
      await _pump(t, const _AfterSave(), f: f, who: _who('sales'));
      await t.tap(_k('saved'));
      await t.pumpAndSettle();
      expect([_k('alloc_result').evaluate().isEmpty, t.widget<Text>(_k('saved_result')).data], [true, 'false']);
    });

    testWidgets('CRM accepts a request with automatic allocation on: confirmed, the result shown, no sheet first; "Change team" opens it', (t) async {
      final f = _FakeAlloc()
        ..s = AllocationSettings.fromJson({'mode': 'suggest', 'canAllocate': true, 'autoAllocate': 'on', 'autoOn': true})
        ..status = _assigned();
      final store = _Bookings();
      t.view.physicalSize = const Size(1200, 1600);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(ProviderScope(
        overrides: [allocationServiceProvider.overrideWithValue(f), authSessionProvider.overrideWithValue(_who('crm')), bookingProvider.overrideWith(() => store)],
        child: MaterialApp(theme: AppTheme.lightTheme, home: const Scaffold(body: _Accept())),
      ));
      await t.pumpAndSettle();
      await t.tap(_k('accept'));
      await t.pumpAndSettle();
      expect(store.saved, ['confirmed'], reason: 'the status is saved at once — the server allocates as it confirms');
      expect(_k('alloc_sheet'), findsNothing);
      expect(_k('alloc_result'), findsOneWidget);
      expect(find.text('Change team'), findsOneWidget);
      await t.tap(_k('alloc_result_allocate'));
      await t.pumpAndSettle();
      expect(_k('alloc_sheet'), findsOneWidget);
    });

    testWidgets('CRM, when it waits: "Allocate now"', (t) async {
      final f = _FakeAlloc()..status = _waiting();
      await _pump(t, const _AfterSave(), f: f, who: _who('crm'));
      await t.tap(_k('saved'));
      await t.pumpAndSettle();
      expect(find.text('Allocate now'), findsOneWidget);
      expect(_k('alloc_result_wait_note'), findsNothing);
    });

    testWidgets('Manage Booking shows the booking\'s artist to a salesperson; nothing for a booking it does not apply to', (t) async {
      final f = _FakeAlloc()..status = _assigned();
      await _pump(t, const BookingAllocationCard(bookingId: 'b9'), f: f, who: _who('sales'));
      expect(_k('booking_alloc_card'), findsOneWidget);
      expect(find.text('Team Nihala'), findsOneWidget);
      expect(_k('booking_alloc_allocate'), findsNothing);
      final old = _FakeAlloc()..status = {..._assigned(), 'eligible': false};
      await _pump(t, const BookingAllocationCard(bookingId: 'b8'), f: old, who: _who('sales'));
      expect(_k('booking_alloc_card'), findsNothing);
    });

    testWidgets('the rules: an admin switches "Assign automatically" on (only with the allocation On)', (t) async {
      final f = _FakeAlloc();
      await _pump(t, _Rules(f.s), f: f, who: _who('admin'));
      await t.tap(_k('rules'));
      await t.pumpAndSettle();
      expect(t.widget<SwitchListTile>(_k('alloc_auto')).value, isFalse);
      await t.tap(_k('alloc_auto'));
      await t.pumpAndSettle();
      await t.tap(_k('alloc_settings_save'));
      await t.pumpAndSettle();
      expect(f.savedSettings.single['autoAllocate'], 'on');
      final trial = _FakeAlloc()..s = AllocationSettings.fromJson({'mode': 'shadow', 'canEdit': true, 'canChangeMode': true});
      await _pump(t, _Rules(trial.s), f: trial, who: _who('admin'));
      await t.tap(_k('rules'));
      await t.pumpAndSettle();
      expect(t.widget<SwitchListTile>(_k('alloc_auto')).onChanged, isNull, reason: 'automatic needs the allocation On');
    });
  });

  group('Add Booking: the artist before saving', () {
    testWidgets('the pincode typed: "Preferred artist for Malappuram: Team Fayiza Irfana Bl — Fayiza with Anjali TK" (a salesperson sees it)', (t) async {
      final f = _FakeAlloc()..previewScript = (d) => d['pincode'] == '679576' ? _previewArea(preferred: [_fayiza]) : {'on': true, 'area': {'pincode': '', 'districtName': ''}, 'units': []};
      await _pump(t, const _Form(), f: f, who: _who('sales'));
      expect(_k('alloc_preview_hint'), findsOneWidget, reason: 'no pincode yet: a hint');
      await t.enterText(_k('pin'), '67');
      await t.pumpAndSettle();
      expect(_k('alloc_preview_hint'), findsOneWidget, reason: 'half a pincode: still the hint');
      await t.enterText(_k('pin'), '679576');
      await t.pumpAndSettle();
      expect(find.text('Preferred artist for Malappuram: Team Fayiza Irfana Bl'), findsOneWidget);
      expect(find.text('Fayiza Irfana Bl, with Anjali TK'), findsOneWidget);
      expect(find.text('Add the event day and time to check she is free.'), findsOneWidget);
      expect(f.previews.last['pincode'], '679576');
    });

    testWidgets('with the event day: "Likely artist", the reason, and that it is assigned automatically on save', (t) async {
      final items = [
        {'service': 'Bridal Makeup', 'eventSlot': '', 'selectedDates': ['2026-12-12'], 'startTime': '10:00', 'endTime': '12:00', 'districtId': ''},
      ];
      final f = _FakeAlloc()
        ..previewScript = (d) => {
              ..._previewArea(preferred: [_fayiza]),
              'units': [
                {'unitKey': 'i:0', 'label': 'Bridal Makeup', 'days': [{'day': '2026-12-12', 'start': '10:00', 'place': 'Malappuram'}], 'ok': true, 'reason': 'Starts a new route — prefers Malappuram', 'top': {'teamName': 'Team Fayiza Irfana Bl', 'lead': 'Fayiza Irfana Bl', 'assistants': ['Anjali TK'], 'tier': 'new_route'}},
              ],
            };
      await _pump(t, _Form(items: items), f: f, who: _who('sales'));
      await t.enterText(_k('pin'), '679576');
      await t.pumpAndSettle();
      expect(find.text('Likely artist: Team Fayiza Irfana Bl'), findsOneWidget);
      expect(find.text('Starts a new route — prefers Malappuram'), findsOneWidget);
      expect(t.widget<Text>(_k('alloc_preview_footer')).data, 'Assigned automatically when you save.');
      expect((f.previews.last['bookingItems'] as List).single['startTime'], '10:00', reason: 'the packages go as the booking sends them');
      expect(f.previews.last['selectedDates'], ['2026-12-12']);
    });

    testWidgets('doubtful: "CRM assigns the artist after you save" with the reason; nobody prefers the place: said so', (t) async {
      final f = _FakeAlloc()
        ..previewScript = (d) => (d['bookingItems'] as List).isEmpty
            ? _previewArea()
            : {
                ..._previewArea(),
                'units': [
                  {'unitKey': 'i:0', 'label': 'Bridal Makeup', 'days': [], 'ok': false, 'reason': 'No team is free for it — Fayiza Irfana Bl is on leave on 12 Dec', 'top': null},
                ],
              };
      await _pump(t, const _Form(), f: f, who: _who('sales'));
      await t.enterText(_k('pin'), '679576');
      await t.pumpAndSettle();
      expect(find.text('No artist team has Malappuram as a preferred location — CRM assigns the artist after you save.'), findsOneWidget);
      await _pump(t, const _Form(items: [{'service': 'Bridal Makeup', 'selectedDates': ['2026-12-12'], 'startTime': '10:00', 'endTime': '12:00'}]), f: f, who: _who('sales'));
      await t.enterText(_k('pin'), '679576');
      await t.pumpAndSettle();
      expect(find.text('CRM assigns the artist after you save'), findsOneWidget);
      expect(find.text('No team is free for it — Fayiza Irfana Bl is on leave on 12 Dec'), findsOneWidget);
      expect(_k('alloc_preview_footer'), findsNothing);
    });

    testWidgets('the allocation Off: nothing on the form; an artist is never asked', (t) async {
      final off = _FakeAlloc()..previewScript = (_) => {'on': false};
      await _pump(t, const _Form(), f: off, who: _who('sales'));
      await t.enterText(_k('pin'), '679576');
      await t.pumpAndSettle();
      expect(_k('alloc_preview'), findsNothing);
      final f = _FakeAlloc()..previewScript = (_) => _previewArea(preferred: [_fayiza]);
      await _pump(t, const _Form(), f: f, who: _who('artist'));
      await t.enterText(_k('pin'), '679576');
      await t.pumpAndSettle();
      expect([_k('alloc_preview').evaluate().isEmpty, f.previews.length], [true, 0]);
    });
  });

  group('Add Booking: a fully booked date', () {
    Map<String, dynamic> full({Map<String, dynamic>? fit, List<Map<String, dynamic>> options = const [], int left = 2, String message = ''}) => {
          ..._previewArea(preferred: [_fayiza]),
          'day': {
            'full': true, 'blocked': false, 'day': '2026-12-12', 'booked': 18, 'capacity': 18, 'left': left, 'message': message,
            'units': [
              {'unitKey': 'i:0', 'label': 'Bridal Makeup', 'start': '14:30', 'end': '16:00', 'place': 'Kozhikode', 'fit': fit, 'options': options},
            ],
          },
        };
    const items = [
      {'service': 'Bridal Makeup', 'selectedDates': ['2026-12-12'], 'startTime': '14:30', 'endTime': '16:00'},
    ];
    final nihala = {'teamName': 'Team Nihala', 'lead': 'Nihala', 'assistants': ['Ameena'], 'tier': 'extra', 'needsOk': true, 'reason': "EXTRA 2nd slot — every evening slot is full; her 12:00 PM Kozhikode job — 22 min (11 km) away by pincode. Needs the Artist Head's OK"};
    final nihalaGap = {'teamName': 'Team Nihala', 'lead': 'Nihala', 'windows': [{'from': '14:22', 'to': '16:25', 'reason': '22 min from her 12:00 PM Kozhikode job'}]};

    testWidgets('a 4th work fits: who, why — and sales are told to contact CRM', (t) async {
      final f = _FakeAlloc()..previewScript = (_) => full(fit: nihala, options: [nihalaGap]);
      await _pump(t, const _Form(items: items), f: f, who: _who('sales'));
      await t.enterText(_k('pin'), '673001');
      await t.pumpAndSettle();
      expect(find.text('Sat 12 Dec is fully booked (18/18)'), findsOneWidget);
      expect(find.text('4th work possible: Team Nihala'), findsOneWidget);
      expect(find.text('Nihala, with Ameena'), findsOneWidget);
      expect(find.text('2:30 PM–4:00 PM fits her day — her 12:00 PM Kozhikode job — 22 min (11 km) away by pincode'), findsOneWidget);
      expect(t.widget<Text>(_k('alloc_full_footer')).data, 'Contact CRM to book this 4th work.');
      expect(_k('alloc_preview_area'), findsNothing, reason: 'the full date says it all');
    });

    testWidgets('CRM may save it: "it goes to her as a 4th work; the Artist Head OKs it"', (t) async {
      final f = _FakeAlloc()..previewScript = (_) => {...full(fit: nihala), 'day': {...(full(fit: nihala)['day'] as Map), 'canBook': true}};
      await _pump(t, const _Form(items: items), f: f, who: _who('crm'));
      await t.enterText(_k('pin'), '673001');
      await t.pumpAndSettle();
      expect(t.widget<Text>(_k('alloc_full_footer')).data, "You can save it — it goes to her as a 4th work; the Artist Head OKs it.");
    });

    testWidgets('not at the asked time: the times it fits; nobody at all: "choose another date"', (t) async {
      final f = _FakeAlloc()..previewScript = (_) => full(options: [nihalaGap]);
      await _pump(t, const _Form(items: items), f: f, who: _who('sales'));
      await t.enterText(_k('pin'), '673001');
      await t.pumpAndSettle();
      expect(find.text('Not at 2:30 PM — a 4th work fits at:'), findsOneWidget);
      expect(find.text('Team Nihala · 2:22 PM–4:25 PM (22 min from her 12:00 PM Kozhikode job)'), findsOneWidget);
      expect(t.widget<Text>(_k('alloc_full_footer')).data, 'Contact CRM to book this 4th work at one of these times.');
      final none = _FakeAlloc()..previewScript = (_) => full(message: 'That date is fully booked (18/18). No artist has time for another work near Kozhikode that day. Please choose another date.');
      await _pump(t, const _Form(items: items), f: none, who: _who('sales'));
      await t.enterText(_k('pin'), '673002'); // (the same form stays: a new pincode asks again)
      await t.pumpAndSettle();
      expect(t.widget<Text>(_k('alloc_full_none')).data, 'No artist has time for another work near Kozhikode that day. Please choose another date.');
      expect(_k('alloc_full_footer'), findsNothing);
    });
  });
}
