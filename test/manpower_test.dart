import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nizan_crm/core/auth/access_control.dart';
import 'package:nizan_crm/core/auth/app_role.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/routing/app_router.dart';
import 'package:nizan_crm/core/theme/app_theme.dart';
import 'package:nizan_crm/features/it/data/manpower.dart';
import 'package:nizan_crm/features/it/data/project.dart';
import 'package:nizan_crm/features/it/presentation/screens/manpower_screen.dart';
import 'package:nizan_crm/features/it/presentation/screens/widgets/manpower_widgets.dart';
import 'package:nizan_crm/features/it/services/manpower_service.dart';

// Manpower: a project asks HR for people; HR covers the seats (someone on staff, a new hire, a contractor), places a hire who
// has joined, or declines; a department head lets one of theirs go or says no; the asker can take a request back. The rules
// are the server's (backend utils/manpower.js) — these tests check what the app asks for, shows and sends.

// ── a fake server ────────────────────────────────────────────────────────────

AppException _refusal(String code, {String message = 'Refused.', Map<String, dynamic> extra = const {}}) {
  final opts = RequestOptions(path: '/manpower');
  return AppException(
    DioException(requestOptions: opts, response: Response(requestOptions: opts, statusCode: 409, data: {'code': code, 'message': message, ...extra}), type: DioExceptionType.badResponse),
    action: 'cover the seats',
  );
}

class _Fake extends ManpowerService {
  _Fake() : super(Dio());

  List<ManpowerRequest> requests = [];
  List<TeamMember> members = [];
  List<AvailablePerson> people = [];
  Object? listFails;
  final failures = <Object>[]; // thrown by the next handle / allocate calls, one each
  Object? raiseFails;
  Object? declineFails;
  Object? releaseFails;

  final raised = <Map<String, dynamic>>[];
  final handled = <({String id, List<Map<String, dynamic>> lines, bool anyway})>[];
  final allocated = <({String id, String line, String employee, bool anyway})>[];
  final released = <({String id, String line, bool approve, String note})>[];
  final declined = <({String id, String note})>[];
  final cancelled = <String>[];
  final queries = <AvailabilityQuery>[];
  ManpowerRequest? raiseAnswer;

  ManpowerRequest _find(String id) => requests.firstWhere((r) => r.id == id);

  @override
  Future<List<ManpowerRequest>> list({String? projectId, String scope = 'all'}) async {
    if (listFails != null) throw listFails!;
    return projectId == null ? requests : [for (final r in requests) if (r.projectId == projectId) r];
  }

  @override
  Future<List<TeamMember>> team(String projectId) async => members;

  @override
  Future<List<AvailablePerson>> availability(AvailabilityQuery q) async {
    queries.add(q);
    final s = q.search.trim().toLowerCase();
    return [for (final p in people) if (s.isEmpty || p.name.toLowerCase().contains(s)) p];
  }

  @override
  Future<ManpowerRequest> raise(
    String projectId, {
    required String roleTitle,
    required int headcount,
    required DateTime startDate,
    required DateTime endDate,
    required int allocationPercent,
    required String reason,
    String skills = '',
    bool urgent = false,
    double? estimatedCost,
  }) async {
    if (raiseFails != null) throw raiseFails!;
    raised.add({
      'projectId': projectId,
      'roleTitle': roleTitle,
      'headcount': headcount,
      'start': '${startDate.year}-${startDate.month}-${startDate.day}',
      'end': '${endDate.year}-${endDate.month}-${endDate.day}',
      'percent': allocationPercent,
      'reason': reason,
      'skills': skills,
      'urgent': urgent,
      'cost': estimatedCost,
    });
    return raiseAnswer ?? _r(id: 'new', headcount: headcount, roleTitle: roleTitle);
  }

  @override
  Future<ManpowerRequest> handle(String id, List<ManpowerChoice> choices, {bool assignAnyway = false}) async {
    handled.add((id: id, lines: [for (final c in choices) c.toJson()], anyway: assignAnyway));
    if (failures.isNotEmpty) throw failures.removeAt(0);
    return _find(id);
  }

  @override
  Future<ManpowerRequest> allocateHire(String id, String lineId, String employeeId, {int? percent, bool assignAnyway = false}) async {
    allocated.add((id: id, line: lineId, employee: employeeId, anyway: assignAnyway));
    if (failures.isNotEmpty) throw failures.removeAt(0);
    return _find(id);
  }

  @override
  Future<ManpowerRequest> release(String id, String lineId, {required bool approve, String note = ''}) async {
    released.add((id: id, line: lineId, approve: approve, note: note));
    if (releaseFails != null) throw releaseFails!;
    return _find(id);
  }

  @override
  Future<ManpowerRequest> decline(String id, String note) async {
    declined.add((id: id, note: note));
    if (declineFails != null) throw declineFails!;
    return _find(id);
  }

  @override
  Future<ManpowerRequest> cancel(String id, {String note = ''}) async {
    cancelled.add(id);
    return _find(id);
  }
}

Map<String, dynamic> _line({
  String id = 'l1',
  String type = 'internal',
  String state = 'assigned',
  int seats = 1,
  int filled = 0,
  String employeeName = 'Dev One',
  String employeeDept = 'IT',
  int percent = 50,
  String vendor = '',
  double cost = 0,
  String releaseNote = '',
}) => {
  'id': id,
  'type': type,
  'state': state,
  'seats': seats,
  'filled': filled,
  'employeeId': type == 'internal' ? 'e_$id' : '',
  'employeeName': type == 'internal' ? employeeName : '',
  'employeeDept': type == 'internal' ? employeeDept : '',
  'percent': percent,
  'from': '2026-12-01T00:00:00.000Z',
  'to': '2027-02-28T00:00:00.000Z',
  'vendorName': vendor,
  'cost': cost,
  'releaseNote': releaseNote,
};

ManpowerRequest _r({
  String id = 'r1',
  String projectId = 'p1',
  String projectName = 'Website redesign',
  String roleTitle = 'UI designer',
  int headcount = 2,
  int? seatsLeft,
  String status = 'submitted',
  bool urgent = false,
  List<Map<String, dynamic>> lines = const [],
  bool canHandle = false,
  bool canCancel = false,
  List<String> releasable = const [],
  String decisionNote = '',
  double estimatedCost = 0,
  String skills = '',
}) => ManpowerRequest.fromJson({
  'id': id,
  'projectId': projectId,
  'projectName': projectName,
  'department': 'Marketing',
  'requestedByName': 'Mira',
  'requestedAt': '2026-11-10T08:00:00.000Z',
  'roleTitle': roleTitle,
  'skills': skills,
  'headcount': headcount,
  'startDate': '2026-12-01T00:00:00.000Z',
  'endDate': '2027-02-28T00:00:00.000Z',
  'allocationPercent': 50,
  'urgency': urgent ? 'urgent' : 'normal',
  'reason': 'Scope grew',
  'estimatedCost': estimatedCost,
  'status': status,
  'seatsLeft': seatsLeft ?? headcount,
  'lines': lines,
  'hrOwnerName': '',
  'decisionNote': decisionNote,
  'access': {'canHandle': canHandle, 'canCancel': canCancel, 'releasable': releasable},
});

AvailablePerson _person(String id, String name, {String level = 'free', int load = 0, bool onLeave = false, String dept = 'IT', String role = 'Designer', int tasks = 0}) =>
    AvailablePerson(id: id, name: name, department: dept, role: role, load: load, onLeave: onLeave, openTasks: tasks, level: level);

TeamMember _member(String id, String name, {String state = 'active', int percent = 50, String role = 'UI designer'}) => TeamMember(
  id: id,
  employeeId: 'e_$id',
  employeeName: name,
  role: role,
  percent: percent,
  from: DateTime.utc(2026, 12, 1),
  to: DateTime.utc(2027, 2, 28),
  state: state,
);

Project _project({String status = 'active', Map<String, dynamic> access = const {'role': 'manager', 'canManage': true}}) => Project.fromJson({
  '_id': 'p1',
  'name': 'Website redesign',
  'status': status,
  'targetDepartment': 'Marketing',
  'managerId': {'_id': 'm1', 'name': 'Mira'},
  // a date with no zone reads as the same day wherever the test runs (the project model turns stamps into local time)
  'startDate': '2026-12-01T12:00:00',
  'endDate': '2027-02-28T12:00:00',
  'costStatus': 'approved',
  'access': access,
});

Future<_Fake> _pump(WidgetTester tester, Widget child, {_Fake? fake, Size size = const Size(900, 1600)}) async {
  final f = fake ?? _Fake();
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: <Override>[manpowerServiceProvider.overrideWithValue(f)],
      child: MaterialApp(theme: AppTheme.lightTheme, home: child),
    ),
  );
  await tester.pumpAndSettle();
  return f;
}

Finder _k(String key) => find.byKey(Key(key));
String _txt(WidgetTester t, String key) => t.widget<Text>(_k(key)).data!;
Future<void> _tap(WidgetTester t, Finder f) async {
  await t.ensureVisible(f);
  await t.pumpAndSettle();
  await t.tap(f);
  await t.pumpAndSettle();
}

Future<void> _type(WidgetTester t, String key, String text) async {
  await t.ensureVisible(_k(key));
  await t.enterText(_k(key), text);
  await t.pump();
}

/// Types in the staff search and waits out its pause.
Future<void> _search(WidgetTester t, String text) async {
  await t.enterText(_k('mp_search'), text);
  await t.pump(const Duration(milliseconds: 400));
  await t.pumpAndSettle();
}

void main() {
  // ── the data and its words ────────────────────────────────────────────────

  group('a request as the server sends it', () {
    test('is read field by field', () {
      final r = _r(
        status: 'in_progress',
        urgent: true,
        seatsLeft: 1,
        estimatedCost: 60000,
        skills: 'Figma',
        lines: [_line(id: 'a', state: 'awaiting_release'), _line(id: 'b', type: 'hire', state: 'hiring', seats: 2, filled: 1, cost: 40000)],
        canHandle: true,
        releasable: ['a'],
      );
      expect(r.id, 'r1');
      expect(r.projectName, 'Website redesign');
      expect(r.department, 'Marketing');
      expect(r.what, '2 UI designers');
      expect(r.isUrgent, isTrue);
      expect(r.isOpen, isTrue);
      expect(r.seatsLeft, 1);
      expect(r.allocationPercent, 50);
      expect(r.estimatedCost, 60000);
      expect(r.skills, 'Figma');
      expect(r.lines.length, 2);
      expect(r.lines[1].cost, 40000);
      expect(r.access.canHandle, isTrue);
      expect(r.access.canCancel, isFalse);
      expect(r.toRelease.map((l) => l.id), ['a']);
    });

    test('one person is "1 UI designer", not "1 UI designers"', () {
      expect(_r(headcount: 1).what, '1 UI designer');
    });

    test('only submitted and in-progress requests are open', () {
      for (final s in ['submitted', 'in_progress']) {
        expect(_r(status: s).isOpen, isTrue, reason: s);
      }
      for (final s in ['fulfilled', 'declined', 'cancelled']) {
        expect(_r(status: s).isOpen, isFalse, reason: s);
      }
    });

    test('a line to release is only one this person is asked about, and only while it waits', () {
      final r = _r(lines: [_line(id: 'a', state: 'awaiting_release'), _line(id: 'b', state: 'awaiting_release'), _line(id: 'c', state: 'assigned')], releasable: ['a', 'c']);
      expect(r.toRelease.map((l) => l.id), ['a']);
    });

    test('a missing access block means nothing may be done', () {
      final r = ManpowerRequest.fromJson({'id': 'x'});
      expect(r.access.canHandle, isFalse);
      expect(r.access.canCancel, isFalse);
      expect(r.access.releasable, isEmpty);
      expect(r.status, 'submitted');
      expect(r.budget, isNull);
    });

    test('the budget note comes with a new request', () {
      final r = ManpowerRequest.fromJson({'id': 'x', 'budget': {'short': true, 'shortfall': 50000, 'available': 100000}});
      expect(r.budget!.short, isTrue);
      expect(r.budget!.shortfall, 50000);
      expect(r.budget!.available, 100000);
    });

    test('the status words', () {
      expect(manpowerStatusLabel('submitted'), 'Waiting for HR');
      expect(manpowerStatusLabel('in_progress'), 'HR is on it');
      expect(manpowerStatusLabel('fulfilled'), 'Covered');
      expect(manpowerStatusLabel('declined'), 'Declined');
      expect(manpowerStatusLabel('cancelled'), 'Withdrawn');
    });

    test('each kind of line says what it is, and where it stands', () {
      ManpowerLine l(Map<String, dynamic> j) => ManpowerLine.fromJson(j);
      expect(l(_line(employeeName: 'Dev One')).title, 'Dev One');
      expect(manpowerLineLabel(l(_line())), 'On the project');
      expect(manpowerLineLabel(l(_line(state: 'awaiting_release', employeeDept: 'Sales'))), 'Waiting for Sales\'s head');
      expect(manpowerLineLabel(l(_line(state: 'refused'))), 'Not released');
      expect(l(_line(type: 'hire')).title, 'A new hire');
      expect(l(_line(type: 'hire', seats: 3)).title, '3 new hires');
      expect(manpowerLineLabel(l(_line(type: 'hire', state: 'hiring', seats: 2))), 'Hiring');
      expect(manpowerLineLabel(l(_line(type: 'hire', state: 'hiring', seats: 2, filled: 1))), 'Hiring · 1 of 2 joined');
      expect(l(_line(type: 'contract', vendor: 'Lens & Co')).title, 'Contractor · Lens & Co');
      expect(manpowerLineLabel(l(_line(type: 'contract', vendor: 'x'))), 'Contractor');
    });

    test('a stored day reads as the day it names, wherever the reader is', () {
      expect(manpowerDay(DateTime.utc(2026, 12, 1)), '1 Dec 2026');
      expect(manpowerDay(DateTime.utc(2027, 2, 28, 23, 30)), '28 Feb 2027');
      expect(manpowerDay(null), '');
      expect(manpowerSpan(DateTime.utc(2026, 12, 1), DateTime.utc(2027, 2, 28)), '1 Dec 2026 → 28 Feb 2027');
      expect(manpowerSpan(null, DateTime.utc(2027, 2, 28)), '');
    });
  });

  group('people to choose from', () {
    test('a person is read, and busy ones are known', () {
      final p = AvailablePerson.fromJson({'id': 'a', 'name': 'Sam', 'department': 'Sales', 'role': 'Rep', 'load': 70, 'onLeave': false, 'openTasks': 3, 'level': 'tight'});
      expect(p.name, 'Sam');
      expect(p.load, 70);
      expect(p.openTasks, 3);
      expect(p.isBusy, isFalse);
      expect(p.loadLabel, '70% booked');
      expect(_person('b', 'B', level: 'busy').isBusy, isTrue);
    });

    test('on leave and free read plainly', () {
      expect(_person('a', 'A', onLeave: true, level: 'busy').loadLabel, 'On leave');
      expect(_person('a', 'A').loadLabel, 'Nothing booked');
    });

    test('two searches are the same only when every part is', () {
      final a = AvailabilityQuery(from: DateTime(2026, 12, 1), to: DateTime(2027, 2, 28), percent: 50, search: 'x');
      expect(a, AvailabilityQuery(from: DateTime(2026, 12, 1), to: DateTime(2027, 2, 28), percent: 50, search: 'x'));
      expect(a == AvailabilityQuery(from: DateTime(2026, 12, 2), to: DateTime(2027, 2, 28), percent: 50, search: 'x'), isFalse);
      expect(a == AvailabilityQuery(from: DateTime(2026, 12, 1), to: DateTime(2027, 2, 27), percent: 50, search: 'x'), isFalse);
      expect(a == AvailabilityQuery(from: DateTime(2026, 12, 1), to: DateTime(2027, 2, 28), percent: 60, search: 'x'), isFalse);
      expect(a == AvailabilityQuery(from: DateTime(2026, 12, 1), to: DateTime(2027, 2, 28), percent: 50, search: 'y'), isFalse);
    });
  });

  group('what is sent when seats are covered', () {
    test('a person on staff: who, and how much of their time only when changed', () {
      expect(const ManpowerChoice.person('e1').toJson(), {'type': 'internal', 'employeeId': 'e1'});
      expect(const ManpowerChoice.person('e1', percent: 30, note: ' for the launch ').toJson(), {'type': 'internal', 'employeeId': 'e1', 'percent': 30, 'note': 'for the launch'});
    });

    test('a new hire: seats and what it costs', () {
      expect(const ManpowerChoice.hire(seats: 2, cost: 60000).toJson(), {'type': 'hire', 'seats': 2, 'cost': 60000.0});
      expect(const ManpowerChoice.hire().toJson(), {'type': 'hire', 'seats': 1});
    });

    test('a contractor: who, seats and cost', () {
      expect(const ManpowerChoice.contractor(vendorName: 'Lens & Co', cost: 25000).toJson(), {'type': 'contract', 'seats': 1, 'cost': 25000.0, 'vendorName': 'Lens & Co'});
    });
  });

  group('what the server asks back', () {
    test('a busy person: who, how much, or on leave', () {
      final r = ManpowerRefusal.of(_refusal('MANPOWER_CONFLICT', message: 'Dev is busy.', extra: {'employeeName': 'Dev', 'load': 70, 'onLeave': false}))!;
      expect(r.isConflict, isTrue);
      expect(r.needsBudget, isFalse);
      expect(r.message, 'Dev is busy.');
      expect(r.employeeName, 'Dev');
      expect(r.load, 70);
      expect(r.onLeave, isFalse);
      expect(ManpowerRefusal.of(_refusal('MANPOWER_CONFLICT', extra: {'onLeave': true}))!.onLeave, isTrue);
    });

    test('a cost that does not fit: by how much, and what is left', () {
      final r = ManpowerRefusal.of(_refusal('NEEDS_BUDGET', extra: {'shortfall': 50000, 'available': 100000}))!;
      expect(r.needsBudget, isTrue);
      expect(r.isConflict, isFalse);
      expect(r.shortfall, 50000);
      expect(r.available, 100000);
    });

    test('works on the bare Dio error as well as the wrapped one', () {
      final wrapped = _refusal('NEEDS_BUDGET');
      expect(ManpowerRefusal.of(wrapped.cause), isNotNull);
    });

    test('other failures are not refusals', () {
      expect(ManpowerRefusal.of(_refusal('NO_SEATS_LEFT')), isNull);
      expect(ManpowerRefusal.of(Exception('boom')), isNull);
      expect(ManpowerRefusal.of(null), isNull);
      final opts = RequestOptions(path: '/x');
      final notConflict = DioException(requestOptions: opts, response: Response(requestOptions: opts, statusCode: 500, data: {'code': 'NEEDS_BUDGET'}));
      expect(ManpowerRefusal.of(notConflict), isNull, reason: 'only a 409 is a question');
      final noBody = DioException(requestOptions: opts, response: Response(requestOptions: opts, statusCode: 409, data: 'plain'));
      expect(ManpowerRefusal.of(noBody), isNull);
    });

    test('after a request is sent: it says it is with HR, and whether the cost fits', () {
      expect(manpowerSentMessage(_r(headcount: 2)), 'Sent to HR: 2 UI designers');
      final fits = ManpowerRequest.fromJson({'id': 'x', 'roleTitle': 'QA', 'headcount': 1, 'budget': {'short': false, 'shortfall': 0, 'available': 100000}});
      expect(manpowerSentMessage(fits), 'Sent to HR: 1 QA');
      final short = ManpowerRequest.fromJson({'id': 'x', 'roleTitle': 'QA', 'headcount': 1, 'budget': {'short': true, 'shortfall': 50000, 'available': 100000}});
      final msg = manpowerSentMessage(short);
      expect(msg, contains('₹50,000 more than the project has left'));
      expect(msg, contains('₹1,00,000'));
      expect(msg, contains('raise the project\'s cost'));
    });
  });

  group('who sees the manpower screen', () {
    test('it is open to everyone signed in — the list itself is scoped by the server', () {
      for (final role in [AppRole.admin, AppRole.unknown]) {
        expect(isRouteAllowed('/manpower', Access(role, const {})), isTrue, reason: '$role');
      }
    });
  });

  // ── asking ────────────────────────────────────────────────────────────────

  group('asking HR for people', () {
    Future<(_Fake, List<ManpowerRequest?>)> open(WidgetTester t, {DateTime? start, DateTime? end, _Fake? fake}) async {
      final results = <ManpowerRequest?>[];
      final f = await _pump(
        t,
        Scaffold(
          body: Consumer(
            builder: (context, ref, _) => Center(
              child: ElevatedButton(
                key: const Key('open'),
                onPressed: () async => results.add(
                  await showManpowerRequestDialog(context, ref, projectId: 'p1', projectName: 'Website redesign', department: 'Marketing', suggestedStart: start, suggestedEnd: end),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
        fake: fake,
      );
      await _tap(t, _k('open'));
      return (f, results);
    }

    testWidgets('asks for the role, the dates, the reason — and says whose project it is', (t) async {
      await open(t);
      expect(find.text('Ask HR for people'), findsOneWidget);
      expect(find.text('Website redesign · Marketing'), findsOneWidget);
      for (final k in ['mp_role', 'mp_skills', 'mp_reason', 'mp_cost', 'mp_start', 'mp_end', 'mp_percent', 'mp_urgent', 'mp_submit']) {
        expect(_k(k), findsOneWidget, reason: k);
      }
      expect(_txt(t, 'mp_headcount'), '1');
    });

    testWidgets('a good request goes out as typed', (t) async {
      final (f, results) = await open(t, start: DateTime(2026, 12, 1), end: DateTime(2027, 2, 28));
      await _type(t, 'mp_role', '  UI designer ');
      await _tap(t, _k('mp_more'));
      await _tap(t, _k('mp_more'));
      expect(_txt(t, 'mp_headcount'), '3');
      await _tap(t, _k('mp_percent'));
      await _tap(t, find.text('50%').last);
      await _type(t, 'mp_skills', 'Figma');
      await _type(t, 'mp_reason', 'Scope grew');
      await _type(t, 'mp_cost', '1,20,000');
      await _tap(t, _k('mp_urgent'));
      await _tap(t, _k('mp_submit'));
      expect(f.raised.length, 1);
      final sent = f.raised.single;
      expect(sent['projectId'], 'p1');
      expect(sent['roleTitle'], '  UI designer ', reason: 'the service tidies it');
      expect(sent['headcount'], 3);
      expect(sent['start'], '2026-12-1');
      expect(sent['end'], '2027-2-28');
      expect(sent['percent'], 50);
      expect(sent['skills'], 'Figma');
      expect(sent['reason'], 'Scope grew');
      expect(sent['urgent'], isTrue);
      expect(sent['cost'], 120000);
      expect(results.single, isNotNull, reason: 'the dialog returns what the server filed');
      expect(find.text('Ask HR for people'), findsNothing);
    });

    testWidgets('it asks for all of a person\'s time unless told otherwise, and is not urgent', (t) async {
      final (f, _) = await open(t, start: DateTime(2026, 12, 1), end: DateTime(2026, 12, 31));
      await _type(t, 'mp_role', 'Editor');
      await _type(t, 'mp_reason', 'A shoot');
      await _tap(t, _k('mp_submit'));
      expect(f.raised.single['percent'], 100);
      expect(f.raised.single['urgent'], isFalse);
      expect(f.raised.single['cost'], isNull);
      expect(f.raised.single['headcount'], 1);
    });

    testWidgets('the project\'s own dates are suggested; nothing is suggested when it has none', (t) async {
      await open(t, start: DateTime(2026, 12, 1), end: DateTime(2027, 2, 28));
      expect(find.descendant(of: _k('mp_start'), matching: find.text('1 Dec 2026')), findsOneWidget);
      expect(find.descendant(of: _k('mp_end'), matching: find.text('28 Feb 2027')), findsOneWidget);
    });

    testWidgets('dates can be picked', (t) async {
      final (f, _) = await open(t);
      expect(find.descendant(of: _k('mp_start'), matching: find.text('Needed from *')), findsOneWidget);
      await _tap(t, _k('mp_start'));
      await _tap(t, find.text('OK'));
      await _tap(t, _k('mp_end'));
      await _tap(t, find.text('OK'));
      expect(find.descendant(of: _k('mp_start'), matching: find.text('Needed from *')), findsNothing);
      await _type(t, 'mp_role', 'QA');
      await _type(t, 'mp_reason', 'Testing');
      await _tap(t, _k('mp_submit'));
      expect(f.raised.length, 1);
      expect(f.raised.single['start'], f.raised.single['end'], reason: 'both are today');
    });

    testWidgets('each missing thing is named and nothing is sent', (t) async {
      final (f, _) = await open(t);
      await _tap(t, _k('mp_submit'));
      expect(_txt(t, 'mp_error'), 'Say what role is needed.');
      await _type(t, 'mp_role', 'QA');
      await _tap(t, _k('mp_submit'));
      expect(_txt(t, 'mp_error'), 'Give the dates the people are needed from and to.');
      expect(f.raised, isEmpty);
    });

    testWidgets('an end before the start is refused', (t) async {
      final (f, _) = await open(t, start: DateTime(2026, 12, 10), end: DateTime(2026, 12, 1));
      await _type(t, 'mp_role', 'QA');
      await _type(t, 'mp_reason', 'Testing');
      await _tap(t, _k('mp_submit'));
      expect(_txt(t, 'mp_error'), 'The end date is before the start date.');
      expect(f.raised, isEmpty);
    });

    testWidgets('no reason is refused; so is a cost that is not a number', (t) async {
      final (f, _) = await open(t, start: DateTime(2026, 12, 1), end: DateTime(2026, 12, 31));
      await _type(t, 'mp_role', 'QA');
      await _tap(t, _k('mp_submit'));
      expect(_txt(t, 'mp_error'), 'Say why more people are needed.');
      await _type(t, 'mp_reason', 'Testing');
      await _type(t, 'mp_cost', '1.2.3');
      await _tap(t, _k('mp_submit'));
      expect(_txt(t, 'mp_error'), 'The estimated cost must be a number.');
      expect(f.raised, isEmpty);
    });

    testWidgets('the number of people stays between 1 and 20', (t) async {
      await open(t);
      expect(t.widget<IconButton>(_k('mp_less')).onPressed, isNull);
      for (var i = 0; i < 25; i++) {
        final more = t.widget<IconButton>(_k('mp_more'));
        if (more.onPressed == null) break;
        await t.tap(_k('mp_more'));
        await t.pump();
      }
      expect(_txt(t, 'mp_headcount'), '20');
      expect(t.widget<IconButton>(_k('mp_more')).onPressed, isNull);
      await _tap(t, _k('mp_less'));
      expect(_txt(t, 'mp_headcount'), '19');
    });

    testWidgets('when the server refuses, it says why, stays open, and may be sent again', (t) async {
      final fake = _Fake()..raiseFails = AppException(Exception('boom'), action: 'ask for more people');
      final (f, results) = await open(t, start: DateTime(2026, 12, 1), end: DateTime(2026, 12, 31), fake: fake);
      await _type(t, 'mp_role', 'QA');
      await _type(t, 'mp_reason', 'Testing');
      await _tap(t, _k('mp_submit'));
      expect(_k('mp_error'), findsOneWidget);
      expect(find.text('Ask HR for people'), findsOneWidget);
      expect(results, isEmpty);
      expect(t.widget<FilledButton>(_k('mp_submit')).onPressed, isNotNull);
      f.raiseFails = null;
      await _tap(t, _k('mp_submit'));
      expect(f.raised.length, 1);
      expect(results.single, isNotNull);
    });

    testWidgets('cancelling sends nothing and returns nothing', (t) async {
      final (f, results) = await open(t);
      await _type(t, 'mp_role', 'QA');
      await _tap(t, _k('mp_cancel'));
      expect(f.raised, isEmpty);
      expect(results, [null]);
    });
  });

  // ── the project's team ────────────────────────────────────────────────────

  group('the project team card', () {
    Future<_Fake> card(WidgetTester t, Project p, {_Fake? fake}) => _pump(t, Scaffold(body: SingleChildScrollView(child: ProjectTeamCard(project: p))), fake: fake);

    testWidgets('someone with no part in it, and nothing to show, sees nothing', (t) async {
      await card(t, _project(access: const {'role': 'viewer'}));
      expect(_k('project_team_card'), findsNothing);
    });

    testWidgets('a manager with no team yet sees that, and may ask for people', (t) async {
      await card(t, _project());
      expect(_k('project_team_card'), findsOneWidget);
      expect(_k('team_empty'), findsOneWidget);
      expect(_k('team_request'), findsOneWidget);
      expect(find.text('Ask HR for people'), findsOneWidget);
    });

    testWidgets('who is on the team: how much of their time and when; an upcoming start is marked', (t) async {
      final fake = _Fake()
        ..members = [_member('a', 'Dev One'), _member('b', 'Dev Two', state: 'upcoming', percent: 25, role: 'QA'), _member('c', 'Gone', state: 'ended')];
      await card(t, _project(access: const {'role': 'member'}), fake: fake);
      expect(find.text('Dev One'), findsOneWidget);
      expect(find.text('UI designer · 50% of their time · 1 Dec 2026 → 28 Feb 2027'), findsOneWidget);
      expect(find.text('QA · 25% of their time · 1 Dec 2026 → 28 Feb 2027'), findsOneWidget);
      expect(find.text('Starts soon'), findsOneWidget);
      expect(find.text('Gone'), findsNothing, reason: 'someone whose time is over is not on the team');
      expect(_txt(t, 'team_earlier'), '1 earlier member not shown');
      expect(_k('team_request'), findsNothing, reason: 'a member cannot ask');
      expect(_k('team_empty'), findsNothing);
    });

    testWidgets('a member who is not running the project sees the team but cannot ask', (t) async {
      final fake = _Fake()..members = [_member('a', 'Dev One')];
      await card(t, _project(access: const {'role': 'member'}), fake: fake);
      expect(_k('project_team_card'), findsOneWidget);
      expect(_k('team_request'), findsNothing);
    });

    testWidgets('where the open requests stand — closed ones are left out', (t) async {
      final fake = _Fake()
        ..requests = [
          _r(id: 'a', status: 'submitted', headcount: 2, urgent: true),
          _r(id: 'b', status: 'in_progress', headcount: 1, seatsLeft: 1, roleTitle: 'QA'),
          _r(id: 'c', status: 'fulfilled'),
          _r(id: 'd', status: 'declined'),
        ];
      await card(t, _project(), fake: fake);
      expect(find.text('2 UI designers · urgent · 2 seats open'), findsOneWidget);
      expect(find.text('1 QA · 1 seat open'), findsOneWidget);
      expect(find.text('Waiting for HR'), findsOneWidget);
      expect(find.text('HR is on it'), findsOneWidget);
      expect(_k('team_request_c'), findsNothing);
      expect(_k('team_request_d'), findsNothing);
      expect(_k('team_all_requests'), findsOneWidget);
    });

    testWidgets('the lead of a department on the project may ask too', (t) async {
      await card(t, _project(access: const {'role': 'dept_lead', 'leadDepartments': ['IT']}));
      expect(_k('team_request'), findsOneWidget);
    });

    testWidgets('a proposal or a cancelled project takes no requests', (t) async {
      expect(ProjectTeamCard.canRequest(_project(status: 'proposed')), isFalse);
      expect(ProjectTeamCard.canRequest(_project(status: 'cancelled')), isFalse);
      expect(ProjectTeamCard.canRequest(_project(status: 'planning')), isTrue);
      expect(ProjectTeamCard.canRequest(_project(access: const {'role': 'viewer'})), isFalse);
      await card(t, _project(status: 'cancelled'));
      expect(_k('team_request'), findsNothing);
    });

    testWidgets('asking from the card: the dialog opens with the project\'s dates, and the sent request is announced', (t) async {
      final fake = _Fake();
      await card(t, _project(), fake: fake);
      await _tap(t, _k('team_request'));
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.descendant(of: _k('mp_start'), matching: find.text('1 Dec 2026')), findsOneWidget);
      await _type(t, 'mp_role', 'QA');
      await _type(t, 'mp_reason', 'Testing');
      fake.raiseAnswer = ManpowerRequest.fromJson({'id': 'n', 'roleTitle': 'QA', 'headcount': 1, 'budget': {'short': true, 'shortfall': 50000, 'available': 100000}});
      expect(_k('team_request_n'), findsNothing);
      fake.requests = [_r(id: 'n', roleTitle: 'QA', headcount: 1)]; // what the server will now have
      await _tap(t, _k('mp_submit'));
      expect(fake.raised.single['projectId'], 'p1');
      expect(_k('team_request_n'), findsOneWidget, reason: 'the card reloads its requests');
      expect(find.textContaining('Sent to HR: 1 QA'), findsOneWidget);
      expect(find.textContaining('₹50,000 more than the project has left'), findsOneWidget);
    });

    testWidgets('"All requests" goes to the manpower screen', (t) async {
      final fake = _Fake()..requests = [_r()];
      t.view.physicalSize = const Size(900, 1600);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final router = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, _) => Scaffold(body: SingleChildScrollView(child: ProjectTeamCard(project: _project())))),
          GoRoute(path: '/manpower', builder: (_, _) => const Scaffold(body: Text('the manpower page'))),
        ],
      );
      await t.pumpWidget(
        ProviderScope(
          retry: (_, _) => null,
          overrides: <Override>[manpowerServiceProvider.overrideWithValue(fake)],
          child: MaterialApp.router(theme: AppTheme.lightTheme, routerConfig: router),
        ),
      );
      await t.pumpAndSettle();
      await _tap(t, _k('team_all_requests'));
      expect(find.text('the manpower page'), findsOneWidget);
    });
  });

  // ── HR's screen ───────────────────────────────────────────────────────────

  group('the manpower screen', () {
    Future<_Fake> screen(WidgetTester t, {_Fake? fake}) => _pump(t, const ManpowerScreen(), fake: fake);

    testWidgets('open and done requests are counted and kept apart', (t) async {
      final fake = _Fake()
        ..requests = [_r(id: 'a', status: 'submitted'), _r(id: 'b', status: 'in_progress'), _r(id: 'c', status: 'fulfilled'), _r(id: 'd', status: 'declined'), _r(id: 'e', status: 'cancelled')];
      await screen(t, fake: fake);
      expect(_txt(t, 'mp_tab_open'), 'Open (2)');
      expect(_txt(t, 'mp_tab_done'), 'Done (3)');
      expect(_k('mp_card_a'), findsOneWidget);
      expect(_k('mp_card_b'), findsOneWidget);
      expect(_k('mp_card_c'), findsNothing);
      await _tap(t, _k('mp_tab_done'));
      expect(_k('mp_card_a'), findsNothing);
      for (final id in ['c', 'd', 'e']) {
        expect(_k('mp_card_$id'), findsOneWidget, reason: id);
      }
    });

    testWidgets('nothing waiting, nothing closed: it says so', (t) async {
      await screen(t);
      expect(find.text('No requests are waiting.'), findsOneWidget);
      await _tap(t, _k('mp_tab_done'));
      expect(find.text('Nothing has been closed yet.'), findsOneWidget);
    });

    testWidgets('a failed load shows the error with a way to retry', (t) async {
      final fake = _Fake()..listFails = AppException(Exception('boom'), action: 'load the manpower requests');
      await screen(t, fake: fake);
      expect(find.byType(AppErrorView), findsOneWidget);
      fake
        ..listFails = null
        ..requests = [_r()];
      await _tap(t, find.text('Try again'));
      expect(_k('mp_card_r1'), findsOneWidget);
    });

    testWidgets('a request shows the project, what is asked, when, how much of their time, and why', (t) async {
      final fake = _Fake()..requests = [_r(urgent: true, skills: 'Figma', estimatedCost: 60000)];
      await screen(t, fake: fake);
      expect(find.text('Website redesign'), findsOneWidget);
      expect(_txt(t, 'mp_what_r1'), '2 UI designers');
      expect(find.textContaining('Marketing · asked by Mira'), findsOneWidget);
      expect(find.text('1 Dec 2026 → 28 Feb 2027 · 50% of their time · about ₹60,000'), findsOneWidget);
      expect(find.text('Skills: Figma'), findsOneWidget);
      expect(find.text('Scope grew'), findsOneWidget);
      expect(find.text('Waiting for HR'), findsOneWidget);
      expect(_k('mp_urgent_r1'), findsOneWidget);
      expect(_txt(t, 'mp_left_r1'), '2 seats still to cover');
    });

    testWidgets('urgent is only flagged while the request is open', (t) async {
      final fake = _Fake()..requests = [_r(id: 'a', urgent: true), _r(id: 'b', urgent: true, status: 'fulfilled')];
      await screen(t, fake: fake);
      expect(_k('mp_urgent_a'), findsOneWidget);
      await _tap(t, _k('mp_tab_done'));
      expect(_k('mp_urgent_b'), findsNothing);
    });

    testWidgets('each seat shows who covers it and where that stands', (t) async {
      final fake = _Fake()
        ..requests = [
          _r(
            status: 'in_progress',
            headcount: 4,
            seatsLeft: 0,
            lines: [
              _line(id: 'a', state: 'assigned', employeeName: 'Dev One'),
              _line(id: 'b', state: 'awaiting_release', employeeName: 'Sam', employeeDept: 'Sales'),
              _line(id: 'c', type: 'hire', state: 'hiring', seats: 2, filled: 1, cost: 40000),
              _line(id: 'd', type: 'contract', state: 'assigned', vendor: 'Lens & Co', cost: 25000),
            ],
          ),
        ];
      await screen(t, fake: fake);
      expect(find.text('Dev One'), findsOneWidget);
      expect(_txt(t, 'mp_line_state_a'), 'On the project');
      expect(find.text('Sam'), findsOneWidget);
      expect(_txt(t, 'mp_line_state_b'), 'Waiting for Sales\'s head');
      expect(find.text('2 new hires'), findsOneWidget);
      expect(_txt(t, 'mp_line_state_c'), 'Hiring · 1 of 2 joined');
      expect(find.text('Contractor · Lens & Co'), findsOneWidget);
      expect(find.text('2 seats · ₹40,000'), findsOneWidget);
      expect(_txt(t, 'mp_left_r1'), 'Every seat is covered');
    });

    testWidgets('a head\'s reason for saying no is kept on the line', (t) async {
      final fake = _Fake()..requests = [_r(status: 'in_progress', lines: [_line(state: 'refused', releaseNote: 'Needed for the festive season')])];
      await screen(t, fake: fake);
      expect(find.text('“Needed for the festive season”'), findsOneWidget);
      expect(_txt(t, 'mp_line_state_l1'), 'Not released');
    });

    testWidgets('a declined request shows why', (t) async {
      final fake = _Fake()..requests = [_r(status: 'declined', decisionNote: 'Nobody is free until March')];
      await screen(t, fake: fake);
      await _tap(t, _k('mp_tab_done'));
      expect(find.text('Nobody is free until March'), findsOneWidget);
    });

    group('who gets which buttons', () {
      testWidgets('HR may cover seats and decline; not take it back', (t) async {
        final fake = _Fake()..requests = [_r(canHandle: true)];
        await screen(t, fake: fake);
        expect(_k('mp_cover_r1'), findsOneWidget);
        expect(_k('mp_decline_r1'), findsOneWidget);
        expect(_k('mp_cancel_r1'), findsNothing);
      });

      testWidgets('whoever asked may only take it back', (t) async {
        final fake = _Fake()..requests = [_r(canCancel: true)];
        await screen(t, fake: fake);
        expect(_k('mp_cancel_r1'), findsOneWidget);
        expect(_k('mp_cover_r1'), findsNothing);
        expect(_k('mp_decline_r1'), findsNothing);
      });

      testWidgets('once seats are covered it cannot be declined as a whole; once every seat is covered there is nothing to cover', (t) async {
        final fake = _Fake()
          ..requests = [
            _r(id: 'a', status: 'in_progress', canHandle: true, seatsLeft: 1, lines: [_line()]),
            _r(id: 'b', status: 'in_progress', canHandle: true, seatsLeft: 0, lines: [_line(), _line(id: 'l2')]),
          ];
        await screen(t, fake: fake);
        expect(_k('mp_cover_a'), findsOneWidget);
        expect(_k('mp_decline_a'), findsNothing);
        expect(_k('mp_cover_b'), findsNothing);
        expect(_k('mp_decline_b'), findsNothing);
      });

      testWidgets('a refused line leaves the request free to decline', (t) async {
        final fake = _Fake()..requests = [_r(status: 'in_progress', canHandle: true, lines: [_line(state: 'refused')])];
        await screen(t, fake: fake);
        expect(_k('mp_decline_r1'), findsOneWidget);
      });

      testWidgets('a closed request has no buttons at all', (t) async {
        final fake = _Fake()..requests = [_r(status: 'fulfilled', canHandle: true, canCancel: true)];
        await screen(t, fake: fake);
        await _tap(t, _k('mp_tab_done'));
        for (final k in ['mp_cover_r1', 'mp_decline_r1', 'mp_cancel_r1']) {
          expect(_k(k), findsNothing, reason: k);
        }
      });

      testWidgets('nobody with no say sees any button', (t) async {
        final fake = _Fake()..requests = [_r()];
        await screen(t, fake: fake);
        for (final k in ['mp_cover_r1', 'mp_decline_r1', 'mp_cancel_r1']) {
          expect(_k(k), findsNothing, reason: k);
        }
      });

      testWidgets('a head sees the answer buttons only on the lines asked of them', (t) async {
        final fake = _Fake()
          ..requests = [
            _r(
              status: 'in_progress',
              lines: [_line(id: 'a', state: 'awaiting_release'), _line(id: 'b', state: 'awaiting_release'), _line(id: 'c', state: 'assigned')],
              releasable: ['a'],
            ),
          ];
        await screen(t, fake: fake);
        expect(_k('mp_release_yes_a'), findsOneWidget);
        expect(_k('mp_release_no_a'), findsOneWidget);
        expect(_k('mp_release_yes_b'), findsNothing);
        expect(_k('mp_release_yes_c'), findsNothing);
      });

      testWidgets('a line that is not waiting has no answer buttons even if it is listed', (t) async {
        final fake = _Fake()..requests = [_r(status: 'in_progress', lines: [_line(id: 'c', state: 'assigned'), _line(id: 'd', state: 'refused')], releasable: ['c', 'd'])];
        await screen(t, fake: fake);
        for (final id in ['c', 'd']) {
          expect(_k('mp_release_yes_$id'), findsNothing, reason: id);
          expect(_k('mp_release_no_$id'), findsNothing, reason: id);
        }
      });

      testWidgets('"Someone joined" is for HR, on a hire that is still being filled', (t) async {
        final fake = _Fake()
          ..requests = [
            _r(id: 'a', status: 'in_progress', canHandle: true, seatsLeft: 0, lines: [_line(id: 'h', type: 'hire', state: 'hiring', seats: 2)]),
            _r(id: 'b', status: 'in_progress', canHandle: false, seatsLeft: 0, lines: [_line(id: 'g', type: 'hire', state: 'hiring', seats: 2)]),
            _r(id: 'c', status: 'in_progress', canHandle: true, seatsLeft: 0, lines: [_line(id: 'i', type: 'hire', state: 'assigned', seats: 1)]),
          ];
        await screen(t, fake: fake);
        expect(_k('mp_joined_h'), findsOneWidget);
        expect(_k('mp_joined_g'), findsNothing);
        expect(_k('mp_joined_i'), findsNothing);
      });
    });

    group('declining', () {
      testWidgets('needs a reason; sends it; the list is loaded again', (t) async {
        final fake = _Fake()..requests = [_r(canHandle: true)];
        await screen(t, fake: fake);
        await _tap(t, _k('mp_decline_r1'));
        await _tap(t, _k('mp_decline_confirm'));
        expect(find.text('Say why'), findsOneWidget);
        expect(fake.declined, isEmpty);
        await t.enterText(_k('mp_decline_reason'), '  Nobody is free until March ');
        fake.requests = [_r(status: 'declined', decisionNote: 'Nobody is free until March')];
        await _tap(t, _k('mp_decline_confirm'));
        expect(fake.declined.single.id, 'r1');
        expect(fake.declined.single.note, 'Nobody is free until March');
        expect(find.text('Request declined'), findsOneWidget);
        expect(_txt(t, 'mp_tab_open'), 'Open (0)');
        expect(_txt(t, 'mp_tab_done'), 'Done (1)');
      });

      testWidgets('cancelling the question declines nothing', (t) async {
        final fake = _Fake()..requests = [_r(canHandle: true)];
        await screen(t, fake: fake);
        await _tap(t, _k('mp_decline_r1'));
        await _tap(t, find.text('Cancel'));
        expect(fake.declined, isEmpty);
        expect(_k('mp_card_r1'), findsOneWidget);
      });

      testWidgets('when the server refuses, it is said and the request stays', (t) async {
        final fake = _Fake()
          ..requests = [_r(canHandle: true)]
          ..declineFails = AppException(Exception('boom'), action: 'decline the request');
        await screen(t, fake: fake);
        await _tap(t, _k('mp_decline_r1'));
        await t.enterText(_k('mp_decline_reason'), 'No one is free');
        await _tap(t, _k('mp_decline_confirm'));
        expect(find.byType(SnackBar), findsOneWidget);
        expect(_txt(t, 'mp_tab_open'), 'Open (1)');
      });
    });

    group('taking a request back', () {
      testWidgets('asks first; "Keep it" leaves it alone', (t) async {
        final fake = _Fake()..requests = [_r(canCancel: true)];
        await screen(t, fake: fake);
        await _tap(t, _k('mp_cancel_r1'));
        expect(_k('mp_cancel_dialog'), findsOneWidget);
        expect(find.textContaining('2 UI designers for Website redesign'), findsOneWidget);
        await _tap(t, _k('mp_cancel_keep'));
        expect(fake.cancelled, isEmpty);
      });

      testWidgets('confirming takes it back', (t) async {
        final fake = _Fake()..requests = [_r(canCancel: true)];
        await screen(t, fake: fake);
        await _tap(t, _k('mp_cancel_r1'));
        fake.requests = [_r(status: 'cancelled')];
        await _tap(t, _k('mp_cancel_confirm'));
        expect(fake.cancelled, ['r1']);
        expect(find.text('Request taken back'), findsOneWidget);
        expect(_txt(t, 'mp_tab_open'), 'Open (0)');
      });
    });

    group('a department head answers', () {
      testWidgets('"Let them go" says yes at once', (t) async {
        final fake = _Fake()..requests = [_r(status: 'in_progress', lines: [_line(id: 'a', state: 'awaiting_release', employeeName: 'Sam')], releasable: ['a'])];
        await screen(t, fake: fake);
        await _tap(t, _k('mp_release_yes_a'));
        expect(fake.released.single, (id: 'r1', line: 'a', approve: true, note: ''));
        expect(find.text('Sam can join Website redesign'), findsOneWidget);
      });

      testWidgets('"Not now" needs a reason, and sends it', (t) async {
        final fake = _Fake()..requests = [_r(status: 'in_progress', lines: [_line(id: 'a', state: 'awaiting_release', employeeName: 'Sam')], releasable: ['a'])];
        await screen(t, fake: fake);
        await _tap(t, _k('mp_release_no_a'));
        expect(find.text('Why can Sam not go?'), findsOneWidget);
        await _tap(t, _k('mp_release_confirm'));
        expect(find.text('Say why'), findsOneWidget);
        expect(fake.released, isEmpty);
        await t.enterText(_k('mp_release_reason'), 'Needed for the festive season');
        await _tap(t, _k('mp_release_confirm'));
        expect(fake.released.single, (id: 'r1', line: 'a', approve: false, note: 'Needed for the festive season'));
        expect(find.text('HR has been told — the seat is open again'), findsOneWidget);
      });

      testWidgets('if the server refuses, that is said instead of "told"', (t) async {
        final fake = _Fake()
          ..requests = [_r(status: 'in_progress', lines: [_line(id: 'a', state: 'awaiting_release')], releasable: ['a'])]
          ..releaseFails = AppException(Exception('boom'), action: 'let them go');
        await screen(t, fake: fake);
        await _tap(t, _k('mp_release_yes_a'));
        expect(find.textContaining('can join'), findsNothing);
        expect(find.byType(SnackBar), findsOneWidget);
      });
    });

    // ── covering seats ──

    group('covering seats', () {
      _Fake hrFake({int headcount = 2, int? seatsLeft}) => _Fake()
        ..requests = [_r(canHandle: true, headcount: headcount, seatsLeft: seatsLeft)]
        ..people = [
          _person('e1', 'Anu', level: 'free', load: 0),
          _person('e2', 'Ben', level: 'tight', load: 40, tasks: 4),
          _person('e3', 'Cleo', level: 'busy', load: 80),
          _person('e4', 'Dev', level: 'busy', onLeave: true),
        ];

      testWidgets('the sheet lists the staff for the request\'s days and share of time, with Free / Tight / Busy', (t) async {
        final fake = hrFake();
        await screen(t, fake: fake);
        await _tap(t, _k('mp_cover_r1'));
        expect(find.text('Cover 2 UI designers'), findsOneWidget);
        expect(find.text('Website redesign · 2 seats to cover'), findsOneWidget);
        final q = fake.queries.last;
        expect(q.percent, 50);
        expect(q.from, DateTime(2026, 12, 1));
        expect(q.to, DateTime(2027, 2, 28));
        expect(find.text('Shown for 1 Dec 2026 → 28 Feb 2027 at 50% of their time'), findsOneWidget);
        for (final n in ['Anu', 'Ben', 'Cleo', 'Dev']) {
          expect(find.text(n), findsOneWidget, reason: n);
        }
        expect(find.text('Free'), findsOneWidget);
        expect(find.text('Tight'), findsOneWidget);
        expect(find.text('Busy'), findsNWidgets(2));
        expect(find.textContaining('40% booked · 4 open tasks'), findsOneWidget);
        expect(find.textContaining('On leave'), findsOneWidget);
      });

      testWidgets('the staff can be searched by name', (t) async {
        final fake = hrFake();
        await screen(t, fake: fake);
        await _tap(t, _k('mp_cover_r1'));
        await _search(t, 'cle');
        expect(find.text('Cleo'), findsOneWidget);
        expect(find.text('Anu'), findsNothing);
        await _search(t, 'zzz');
        expect(_k('mp_nobody'), findsOneWidget);
      });

      testWidgets('nothing chosen: it asks to choose, and sends nothing', (t) async {
        final fake = hrFake();
        await screen(t, fake: fake);
        await _tap(t, _k('mp_cover_r1'));
        await _tap(t, _k('mp_cover_submit'));
        expect(_txt(t, 'mp_cover_error'), 'Choose who to put on the project.');
        expect(fake.handled, isEmpty);
      });

      testWidgets('a person is chosen and sent; the list is loaded again', (t) async {
        final fake = hrFake();
        await screen(t, fake: fake);
        await _tap(t, _k('mp_cover_r1'));
        await _tap(t, _k('mp_person_e1'));
        fake.requests = [_r(status: 'in_progress', seatsLeft: 1, lines: [_line()], canHandle: true)];
        await _tap(t, _k('mp_cover_submit'));
        expect(fake.handled.single.id, 'r1');
        expect(fake.handled.single.lines, [
          {'type': 'internal', 'employeeId': 'e1'},
        ]);
        expect(fake.handled.single.anyway, isFalse);
        expect(find.text('Cover 2 UI designers'), findsNothing, reason: 'the sheet closes');
        expect(_txt(t, 'mp_left_r1'), '1 seat still to cover');
      });

      testWidgets('as many people as seats, and no more', (t) async {
        final fake = hrFake(headcount: 2);
        await screen(t, fake: fake);
        await _tap(t, _k('mp_cover_r1'));
        for (final id in ['e1', 'e2', 'e3']) {
          await _tap(t, _k('mp_person_$id'));
        }
        await _tap(t, _k('mp_cover_submit'));
        expect(fake.handled.single.lines.map((l) => l['employeeId']).toSet(), {'e1', 'e2'}, reason: 'the third is ignored');
      });

      testWidgets('with one seat left, choosing another replaces the first', (t) async {
        final fake = hrFake(headcount: 2, seatsLeft: 1);
        await screen(t, fake: fake);
        await _tap(t, _k('mp_cover_r1'));
        await _tap(t, _k('mp_person_e1'));
        await _tap(t, _k('mp_person_e2'));
        await _tap(t, _k('mp_cover_submit'));
        expect(fake.handled.single.lines.single['employeeId'], 'e2');
      });

      testWidgets('someone chosen can be un-chosen', (t) async {
        final fake = hrFake();
        await screen(t, fake: fake);
        await _tap(t, _k('mp_cover_r1'));
        await _tap(t, _k('mp_person_e1'));
        await _tap(t, _k('mp_person_e1'));
        await _tap(t, _k('mp_cover_submit'));
        expect(_k('mp_cover_error'), findsOneWidget);
        expect(fake.handled, isEmpty);
      });

      testWidgets('a person who is busy then: HR is asked, and "Assign anyway" sends it again with that said', (t) async {
        final fake = hrFake();
        fake.failures.add(_refusal('MANPOWER_CONFLICT', message: 'Cleo already has 80% of their time on other projects then. Assign anyway?', extra: {'employeeName': 'Cleo', 'load': 80}));
        await screen(t, fake: fake);
        await _tap(t, _k('mp_cover_r1'));
        await _tap(t, _k('mp_person_e3'));
        await _tap(t, _k('mp_cover_submit'));
        expect(_k('mp_conflict_dialog'), findsOneWidget);
        expect(find.text('Already busy then'), findsOneWidget);
        expect(find.textContaining('Cleo already has 80%'), findsOneWidget);
        await _tap(t, _k('mp_conflict_yes'));
        expect(fake.handled.length, 2);
        expect(fake.handled[0].anyway, isFalse);
        expect(fake.handled[1].anyway, isTrue);
        expect(fake.handled[1].lines.single['employeeId'], 'e3');
        expect(find.text('Cover 2 UI designers'), findsNothing);
      });

      testWidgets('someone on leave is said to be on leave', (t) async {
        final fake = hrFake();
        fake.failures.add(_refusal('MANPOWER_CONFLICT', message: 'Dev is on leave then. Assign anyway?', extra: {'onLeave': true}));
        await screen(t, fake: fake);
        await _tap(t, _k('mp_cover_r1'));
        await _tap(t, _k('mp_person_e4'));
        await _tap(t, _k('mp_cover_submit'));
        expect(find.text('On leave then'), findsOneWidget);
      });

      testWidgets('"Choose someone else" sends nothing more and keeps the sheet open', (t) async {
        final fake = hrFake();
        fake.failures.add(_refusal('MANPOWER_CONFLICT', message: 'busy', extra: {'load': 80}));
        await screen(t, fake: fake);
        await _tap(t, _k('mp_cover_r1'));
        await _tap(t, _k('mp_person_e3'));
        await _tap(t, _k('mp_cover_submit'));
        await _tap(t, _k('mp_conflict_no'));
        expect(fake.handled.length, 1);
        expect(find.text('Cover 2 UI designers'), findsOneWidget);
        expect(t.widget<FilledButton>(_k('mp_cover_submit')).onPressed, isNotNull, reason: 'it can be tried again');
      });

      testWidgets('a cost that does not fit the budget is told plainly, with no "anyway"', (t) async {
        final fake = hrFake();
        fake.failures.add(_refusal('NEEDS_BUDGET', message: 'The project has ₹1,00,000 of its approved budget left, and this costs ₹1,50,000.', extra: {'shortfall': 50000, 'available': 100000}));
        await screen(t, fake: fake);
        await _tap(t, _k('mp_cover_r1'));
        await _tap(t, find.text('Contractor'));
        await _type(t, 'mp_vendor', 'Big Agency');
        await _type(t, 'mp_cover_cost', '1,50,000');
        await _tap(t, _k('mp_cover_submit'));
        expect(_k('mp_budget_dialog'), findsOneWidget);
        expect(find.textContaining('₹1,50,000'), findsOneWidget);
        expect(_k('mp_conflict_yes'), findsNothing);
        await _tap(t, _k('mp_budget_ok'));
        expect(fake.handled.length, 1, reason: 'nothing is resent');
        expect(find.text('Cover 2 UI designers'), findsOneWidget);
      });

      testWidgets('any other failure is shown on the sheet', (t) async {
        final fake = hrFake();
        fake.failures.add(AppException(Exception('boom'), action: 'cover the seats'));
        await screen(t, fake: fake);
        await _tap(t, _k('mp_cover_r1'));
        await _tap(t, _k('mp_person_e1'));
        await _tap(t, _k('mp_cover_submit'));
        expect(_k('mp_cover_error'), findsOneWidget);
        expect(_k('mp_conflict_dialog'), findsNothing);
      });

      testWidgets('a new hire: seats (no more than are left) and what it costs', (t) async {
        final fake = hrFake(headcount: 3);
        await screen(t, fake: fake);
        await _tap(t, _k('mp_cover_r1'));
        await _tap(t, find.text('New hire'));
        expect(find.textContaining('A hiring plan is raised for Marketing'), findsOneWidget);
        expect(_k('mp_person_e1'), findsNothing, reason: 'no staff list for a hire');
        for (var i = 0; i < 5; i++) {
          if (t.widget<IconButton>(_k('mp_seats_more')).onPressed == null) break;
          await t.tap(_k('mp_seats_more'));
          await t.pump();
        }
        expect(_txt(t, 'mp_seats'), '3');
        expect(t.widget<IconButton>(_k('mp_seats_more')).onPressed, isNull);
        await _tap(t, _k('mp_seats_less'));
        await _type(t, 'mp_cover_cost', '60,000');
        await _tap(t, _k('mp_cover_submit'));
        expect(fake.handled.single.lines, [
          {'type': 'hire', 'seats': 2, 'cost': 60000.0},
        ]);
      });

      testWidgets('a hire needs no cost named', (t) async {
        final fake = hrFake();
        await screen(t, fake: fake);
        await _tap(t, _k('mp_cover_r1'));
        await _tap(t, find.text('New hire'));
        await _tap(t, _k('mp_cover_submit'));
        expect(fake.handled.single.lines, [
          {'type': 'hire', 'seats': 1},
        ]);
      });

      testWidgets('a contractor needs a name; the cost must be a number', (t) async {
        final fake = hrFake();
        await screen(t, fake: fake);
        await _tap(t, _k('mp_cover_r1'));
        await _tap(t, find.text('Contractor'));
        await _tap(t, _k('mp_cover_submit'));
        expect(_txt(t, 'mp_cover_error'), 'Say who the contractor is.');
        await _type(t, 'mp_vendor', 'Lens & Co');
        await _type(t, 'mp_cover_cost', '1.2.3');
        await _tap(t, _k('mp_cover_submit'));
        expect(_txt(t, 'mp_cover_error'), 'The cost must be a number.');
        expect(fake.handled, isEmpty);
        await _type(t, 'mp_cover_cost', '25,000');
        await _tap(t, _k('mp_cover_submit'));
        expect(fake.handled.single.lines, [
          {'type': 'contract', 'seats': 1, 'cost': 25000.0, 'vendorName': 'Lens & Co'},
        ]);
      });

      testWidgets('switching the kind clears an old complaint', (t) async {
        final fake = hrFake();
        await screen(t, fake: fake);
        await _tap(t, _k('mp_cover_r1'));
        await _tap(t, _k('mp_cover_submit'));
        expect(_k('mp_cover_error'), findsOneWidget);
        await _tap(t, find.text('New hire'));
        expect(_k('mp_cover_error'), findsNothing);
      });

      testWidgets('cancelling the sheet changes nothing', (t) async {
        final fake = hrFake();
        await screen(t, fake: fake);
        await _tap(t, _k('mp_cover_r1'));
        await _tap(t, _k('mp_cover_cancel'));
        expect(fake.handled, isEmpty);
        expect(find.text('Cover 2 UI designers'), findsNothing);
      });
    });

    // ── a hire who has joined ──

    group('placing a new hire who has joined', () {
      _Fake hireFake() => _Fake()
        ..requests = [_r(status: 'in_progress', canHandle: true, seatsLeft: 0, headcount: 2, lines: [_line(id: 'h', type: 'hire', state: 'hiring', seats: 2, filled: 1)])]
        ..people = [_person('e1', 'Anu'), _person('e2', 'Ben', level: 'busy', load: 90)];

      testWidgets('says how many are still to join; one person is chosen at a time', (t) async {
        final fake = hireFake();
        await screen(t, fake: fake);
        await _tap(t, _k('mp_joined_h'));
        expect(find.text('Who joined?'), findsOneWidget);
        expect(find.text('UI designer for Website redesign · 1 still to join'), findsOneWidget);
        await _tap(t, _k('mp_person_e1'));
        await _tap(t, _k('mp_person_e2'));
        await _tap(t, _k('mp_allocate_submit'));
        expect(fake.allocated.single, (id: 'r1', line: 'h', employee: 'e2', anyway: false));
      });

      testWidgets('choosing nobody is refused', (t) async {
        final fake = hireFake();
        await screen(t, fake: fake);
        await _tap(t, _k('mp_joined_h'));
        await _tap(t, _k('mp_allocate_submit'));
        expect(_txt(t, 'mp_allocate_error'), 'Choose who joined.');
        expect(fake.allocated, isEmpty);
      });

      testWidgets('a busy person is asked about, then sent anyway when HR says so', (t) async {
        final fake = hireFake();
        fake.failures.add(_refusal('MANPOWER_CONFLICT', message: 'Ben already has 90% of their time on other projects then. Assign anyway?', extra: {'load': 90}));
        await screen(t, fake: fake);
        await _tap(t, _k('mp_joined_h'));
        await _tap(t, _k('mp_person_e2'));
        await _tap(t, _k('mp_allocate_submit'));
        expect(_k('mp_conflict_dialog'), findsOneWidget);
        await _tap(t, _k('mp_conflict_yes'));
        expect(fake.allocated.length, 2);
        expect(fake.allocated[1].anyway, isTrue);
        expect(find.text('Who joined?'), findsNothing);
      });

      testWidgets('another failure is shown on the sheet', (t) async {
        final fake = hireFake();
        fake.failures.add(AppException(Exception('boom'), action: 'place the new hire'));
        await screen(t, fake: fake);
        await _tap(t, _k('mp_joined_h'));
        await _tap(t, _k('mp_person_e1'));
        await _tap(t, _k('mp_allocate_submit'));
        expect(_k('mp_allocate_error'), findsOneWidget);
        expect(find.text('Who joined?'), findsOneWidget);
      });

      testWidgets('cancelling places nobody', (t) async {
        final fake = hireFake();
        await screen(t, fake: fake);
        await _tap(t, _k('mp_joined_h'));
        await _tap(t, _k('mp_allocate_cancel'));
        expect(fake.allocated, isEmpty);
      });
    });

    testWidgets('fits a phone', (t) async {
      final fake = _Fake()
        ..requests = [
          _r(urgent: true, canHandle: true, status: 'in_progress', lines: [_line(state: 'awaiting_release', employeeDept: 'Sales'), _line(id: 'h', type: 'hire', state: 'hiring', seats: 2)], seatsLeft: 0),
        ];
      await _pump(t, const ManpowerScreen(), fake: fake, size: const Size(360, 800));
      expect(_k('mp_card_r1'), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  });
}
