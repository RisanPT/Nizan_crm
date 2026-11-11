import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:nizan_crm/core/models/auth_session.dart';
import 'package:nizan_crm/core/models/employee.dart';
import 'package:nizan_crm/core/providers/auth_provider.dart';
import 'package:nizan_crm/core/theme/app_theme.dart';
import 'package:nizan_crm/features/it/domain/models/monthly_objective.dart';
import 'package:nizan_crm/features/it/domain/models/monthly_trend.dart';
import 'package:nizan_crm/features/it/domain/models/okr_model.dart';
import 'package:nizan_crm/features/it/presentation/screens/company_projects_screen.dart';
import 'package:nizan_crm/features/it/presentation/screens/widgets/monthly_objective_dialogs.dart';
import 'package:nizan_crm/features/it/presentation/screens/widgets/monthly_objectives_view.dart';
import 'package:nizan_crm/features/it/services/it_service.dart';
import 'package:nizan_crm/features/it/services/monthly_objective_service.dart';
import 'package:nizan_crm/features/it/services/okr_service.dart';
import 'package:nizan_crm/features/org/services/department_service.dart';
import 'package:nizan_crm/services/employee_service.dart';

// Monthly objectives per department (Company Projects → Monthly): every department's month, each objective with key results,
// who may do what, reporting progress, and the month-end close-out with carry-over.

final _now = DateTime.now();
final MonthKey _thisMonth = (year: _now.year, month: _now.month);
String get _monthName => kMonthNames[_now.month - 1];
String get _nextMonthName => monthTitle(nextMonthOf(_thisMonth)); // "December 2026" — what the dialogs print

Map<String, dynamic> _kr(String id, String title, num target, num current, {String unit = '', bool done = false, String? kind, String? doneAt, String? doneBy}) => {
      'id': id,
      'title': title,
      'targetValue': target,
      'currentValue': current,
      'unit': unit,
      'completed': done,
      'checkIns': <Map<String, dynamic>>[],
      'kind': ?kind,
      'completedAt': ?doneAt,
      'completedByName': ?doneBy,
    };

Map<String, dynamic> _obj(
  String id,
  String title, {
  String dept = 'd1',
  String deptName = 'IT',
  int progress = 0,
  String? result,
  String note = '',
  String owner = '',
  List<Map<String, dynamic>> krs = const [],
  bool canManage = false,
  bool canCheckIn = false,
  bool carriedFrom = false,
  bool carriedTo = false,
  String priority = 'medium',
  Map<String, dynamic>? span,
  String? suggested, // the server's word; left out, the app works it out from the progress
  bool noSuggestion = false, // the server said "nothing measures this"
  bool overridden = false,
  int? progressAtClose,
  bool planLocked = false,
  bool assignedToMe = false,
  bool readyToClose = false,
  List<Map<String, dynamic>> changes = const [],
}) =>
    {
      'id': id,
      'departmentId': dept,
      'departmentName': deptName,
      'year': _now.year,
      'month': _now.month,
      'objective': title,
      'description': '',
      'priority': priority,
      'ownerId': owner.isEmpty ? null : 'e-$owner',
      'ownerName': owner,
      'keyResults': krs,
      'progress': progress,
      'span': span,
      if (suggested != null || noSuggestion) 'suggestedResult': suggested,
      'overridden': overridden,
      'progressAtClose': progressAtClose,
      'planLocked': planLocked,
      'assignedToMe': assignedToMe,
      'readyToClose': readyToClose,
      'changes': changes,
      'result': result,
      'resultNote': note,
      'closedAt': result == null ? null : '2026-11-30T10:00:00.000Z',
      'carriedFrom': carriedFrom,
      'carriedTo': carriedTo,
      'updatedAt': '2026-11-02T10:00:00.000Z',
      'access': {'canManage': canManage, 'canCheckIn': canCheckIn},
    };

Map<String, dynamic> _summary({
  int count = 0,
  int avg = 0,
  int open = 0,
  int closed = 0,
  int achieved = 0,
  int partly = 0,
  int missed = 0,
  int continued = 0,
  int cancelled = 0,
  int deferred = 0,
}) => {
      'count': count,
      'avgProgress': avg,
      'open': open,
      'closed': closed,
      'achieved': achieved,
      'partly': partly,
      'missed': missed,
      'continued': continued,
      'cancelled': cancelled,
      'deferred': deferred,
    };

Map<String, dynamic> _dept(String id, String name, {String? head, bool canManage = false, bool member = false, List<Map<String, dynamic>> objectives = const [], Map<String, dynamic>? summary, Map<String, dynamic>? last}) => {
      'member': member,
      'departmentId': id,
      'name': name,
      'key': name.toLowerCase(),
      'division': 'administrative',
      'head': head == null ? null : {'id': 'h-$id', 'name': head},
      'canManage': canManage,
      'objectives': objectives,
      'summary': summary ?? _summary(count: objectives.length),
      'lastMonth': last ?? _summary(),
    };

/// IT: the viewer's own (manages it); HR: someone else's (view only); Artist: nothing set yet.
MonthlyObjectivesPage _page({List<Map<String, dynamic>>? departments, MonthKey? month, List<Map<String, dynamic>> assigned = const []}) {
  final m = month ?? _thisMonth;
  final depts = departments ??
      [
        _dept('d1', 'IT', head: 'Ishaan', canManage: true, summary: _summary(count: 2, avg: 60, open: 1, closed: 1, achieved: 1), last: _summary(count: 3, achieved: 1, partly: 1, open: 1), objectives: [
          _obj('o1', 'Ship the booking app', progress: 50, owner: 'Irfan', canManage: true, canCheckIn: true, krs: [_kr('k1', 'Screens done', 40, 20, unit: 'screens'), _kr('k2', 'Bugs closed', 10, 10, done: true)]),
          _obj('o2', 'Migrate the old server', progress: 100, result: 'achieved', note: 'Done on the 28th', canManage: true, carriedFrom: true, krs: [_kr('k3', 'Services moved', 5, 5, done: true)]),
        ]),
        _dept('d2', 'HR', head: 'Hana', objectives: [_obj('o3', 'Hire two trainers', dept: 'd2', deptName: 'HR', progress: 25, krs: [_kr('k4', 'Offers made', 2, 0)])], summary: _summary(count: 1, avg: 25, open: 1)),
        _dept('d3', 'Artist', canManage: true),
      ];
  final ds = depts.map(MonthlyDepartment.fromJson).toList();
  return MonthlyObjectivesPage(
    year: m.year,
    month: m.month,
    isCurrent: m == _thisMonth,
    departments: ds,
    assigned: assigned.map(MonthlyObjective.fromJson).toList(),
    departmentCount: ds.length,
    withObjectives: ds.where((d) => !d.isEmpty).length,
    objectiveCount: ds.fold(0, (s, d) => s + d.objectives.length),
    avgProgress: 45,
    closed: 1,
  );
}

/// Six months ending [end]: IT had objectives in the last two (45%, then 60%), HR in the last one (25%), Artist never.
MonthlyTrend _trend(MonthKey end) {
  final keys = <MonthKey>[];
  var m = end;
  for (var i = 0; i < 6; i++) {
    keys.insert(0, m);
    m = prevMonthOf(m);
  }
  Map<String, dynamic> dept(String id, String name, int count, int avg) => {'departmentId': id, 'name': name, 'count': count, 'avgProgress': avg, 'closed': 0};
  return MonthlyTrend.fromJson({
    'end': {'year': end.year, 'month': end.month},
    'months': [
      for (var i = 0; i < keys.length; i++)
        {
          'year': keys[i].year,
          'month': keys[i].month,
          'count': i == 4 ? 2 : (i == 5 ? 3 : 0),
          'avgProgress': i == 4 ? 45 : (i == 5 ? 50 : 0),
          'closed': 0,
          'achieved': 0,
          'departments': [
            dept('d1', 'IT', i == 4 ? 2 : (i == 5 ? 2 : 0), i == 4 ? 45 : (i == 5 ? 60 : 0)),
            dept('d2', 'HR', i == 5 ? 1 : 0, i == 5 ? 25 : 0),
            dept('d3', 'Artist', 0, 0),
          ],
        },
    ],
  });
}

MonthlyObjective _o({String id = 'o1', String title = 'Ship the booking app', String dept = 'd1', int progress = 0, String? result, List<Map<String, dynamic>> krs = const []}) =>
    MonthlyObjective.fromJson(_obj(id, title, dept: dept, progress: progress, result: result, krs: krs, canManage: true, canCheckIn: true));

class _Call {
  _Call(this.name, this.args);
  final String name;
  final Map<String, Object?> args;
  @override
  String toString() => '$name$args';
}

/// "id|title|target|unit" — and "|kind" when it is not an ordinary number, so older expectations read as they always did.
String _kr2s(KeyResultInput k) => '${k.id ?? '-'}|${k.title}|${k.targetValue}|${k.unit}${k.kind == 'number' ? '' : '|${k.kind}'}';

class _Service implements MonthlyObjectiveService {
  final calls = <_Call>[];
  Object? failWith;
  int failAfter = 1; // once failWith is set, the Nth write fails (1-based) and every one after it — a half-finished close-out is reported
  var _writes = 0;
  final requested = <MonthKey>[];

  void _write(String name, Map<String, Object?> args) {
    calls.add(_Call(name, args));
    _writes++;
    if (failWith != null && _writes >= failAfter) throw failWith!;
  }

  @override
  Future<MonthlyObjectivesPage> getMonth(MonthKey m) async => _page(month: m);

  @override
  Future<MonthlyObjective> create({required String departmentId, required MonthKey month, required String objective, String description = '', String priority = 'medium', String? ownerId, int spanMonths = 1, List<KeyResultInput> keyResults = const []}) async {
    _write('create', {'departmentId': departmentId, 'month': month, 'objective': objective, 'priority': priority, 'ownerId': ownerId, 'spanMonths': spanMonths, 'krs': [for (final k in keyResults) _kr2s(k)]});
    return _o(title: objective);
  }

  @override
  Future<MonthlyObjective> update(MonthlyObjective o, {required String objective, String description = '', String priority = 'medium', String? ownerId, int spanMonths = 1, String changeReason = '', List<KeyResultInput> keyResults = const []}) async {
    _write('update', {'id': o.id, 'expectedUpdatedAt': o.updatedAt, 'objective': objective, 'priority': priority, 'spanMonths': spanMonths, 'changeReason': changeReason, 'krs': [for (final k in keyResults) _kr2s(k)]});
    return _o(title: objective);
  }

  @override
  Future<MonthlyObjective> checkIn(String objectiveId, String keyResultId, {double? value, bool? completed}) async {
    _write('checkIn', {'objective': objectiveId, 'kr': keyResultId, 'value': value, 'completed': completed});
    return _o();
  }

  @override
  Future<MonthlyObjective> close(String id, ObjectiveResult result, {String note = ''}) async {
    _write('close', {'id': id, 'result': result.slug, 'note': note});
    return _o(id: id, result: result.slug);
  }

  @override
  Future<MonthlyObjective> reopen(String id) async {
    _write('reopen', {'id': id});
    return _o(id: id);
  }

  @override
  Future<void> delete(String id) async => _write('delete', {'id': id});

  @override
  Future<({List<MonthlyObjective> created, int skipped})> carryOver({required String departmentId, required MonthKey month, List<String>? ids}) async {
    _write('carryOver', {'departmentId': departmentId, 'month': month, 'ids': ids});
    return (created: [for (final _ in ids ?? const <String>[]) _o()], skipped: 0);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError('${invocation.memberName}');
}

Employee _emp(String id, String name, String dept) => Employee.fromJson({'_id': id, 'name': name, 'department': dept, 'status': 'active'});

Future<_Service> _pump(
  WidgetTester tester, {
  MonthlyObjectivesPage Function(MonthKey)? pageFor,
  Object? loadError,
  Size size = const Size(1400, 1800),
  _Service? service,
  Widget? screen,
  MonthlyTrend Function(MonthKey)? trendFor,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final s = service ?? _Service();
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpWidget(ProviderScope(
    overrides: <Override>[
      monthlyObjectiveServiceProvider.overrideWithValue(s),
      monthlyObjectivesProvider.overrideWith((ref, m) async {
        s.requested.add(m);
        if (loadError != null) throw loadError;
        return (pageFor ?? (k) => _page(month: k))(m);
      }),
      monthlyTrendProvider.overrideWith((ref, m) async => (trendFor ?? _trend)(m)),
      employeesProvider.overrideWith((ref) async => [_emp('e-Irfan', 'Irfan', 'IT'), _emp('e-Imran', 'Imran', 'IT'), _emp('e-Hana', 'Hana', 'HR')]),
      authSessionProvider.overrideWithValue(AuthSession(token: 't', userId: 'u', name: 'U', email: 'u@x', role: 'artist', employeeId: 'e1')),
      companyProjectsProvider.overrideWith((ref, d) async => const []),
      planningOkrsProvider.overrideWith((ref) async => <OKRModel>[]),
      departmentsProvider.overrideWith((ref) async => const []),
    ],
    child: MaterialApp(theme: AppTheme.lightTheme, home: Scaffold(body: screen ?? const MonthlyObjectivesView())),
  ));
  await tester.pumpAndSettle();
  return s;
}

Finder _k(String key) => find.byKey(Key(key));
Future<void> _tap(WidgetTester t, Finder f) async {
  await t.ensureVisible(f);
  await t.pumpAndSettle();
  await t.tap(f);
  await t.pumpAndSettle();
}

Future<void> _open(WidgetTester t, String id) => _tap(t, _k('mo_toggle_$id'));

/// "Set Objective" — and, when this person runs several departments, the one it is for.
Future<void> _startAdd(WidgetTester t, String dept) async {
  await _tap(t, _k('mo_set'));
  if (_k('mo_pick_$dept').evaluate().isNotEmpty) await _tap(t, _k('mo_pick_$dept'));
}

/// The page menu's "Close out the month…" — and the department, when there is a choice.
Future<void> _startCloseOut(WidgetTester t, String dept) async {
  await _tap(t, _k('mo_header_menu'));
  await t.tap(_k('mo_closeout'));
  await t.pumpAndSettle();
  if (_k('mo_pick_$dept').evaluate().isNotEmpty) await _tap(t, _k('mo_pick_$dept'));
}

void main() {

  group('the month', () {
    testWidgets('opens on this month, and says so', (tester) async {
      await _pump(tester);
      expect(find.text('$_monthName ${_now.year}'), findsOneWidget);
      expect(_k('mo_this_month'), findsOneWidget);
      expect(_k('mo_go_now'), findsNothing);
    });

    testWidgets('◀ ▶ step through the months and ask for each; "This month" brings you back', (tester) async {
      final s = await _pump(tester);
      await _tap(tester, _k('mo_next'));
      expect(find.text(_nextMonthName), findsOneWidget);
      expect(s.requested.last, nextMonthOf(_thisMonth));
      expect(_k('mo_this_month'), findsNothing);
      expect(_k('mo_go_now'), findsOneWidget);

      await _tap(tester, _k('mo_prev'));
      await _tap(tester, _k('mo_prev'));
      expect(s.requested.last, prevMonthOf(_thisMonth));

      await _tap(tester, _k('mo_go_now'));
      expect(find.text('$_monthName ${_now.year}'), findsOneWidget);
      expect(_k('mo_this_month'), findsOneWidget);
    });

    testWidgets('over a year end', (tester) async {
      final s = await _pump(tester, pageFor: (k) => _page(month: k));
      // 12 forward from now is always the same month next year: stepping lands exactly there
      for (var i = 0; i < 12; i++) {
        await tester.tap(_k('mo_next'));
        await tester.pumpAndSettle();
      }
      expect(s.requested.last, (year: _now.year + 1, month: _now.month));
    });
  });

  group('the whole company at a glance', () {
    testWidgets('the five headline numbers — total, completed, in progress, not started, overall — and who has set nothing, named', (tester) async {
      await _pump(tester);
      final prev = kMonthNames[prevMonthOf(_thisMonth).month - 1].substring(0, 3);
      expect(_text(tester, 'mo_kpi_total_value'), '3');
      expect(_text(tester, 'mo_kpi_total_chip'), 'same as $prev (3)'); // last month had 3 as well
      expect(_text(tester, 'mo_kpi_completed_value'), '1');
      expect(_text(tester, 'mo_kpi_completed_caption'), '33% of total');
      expect(_text(tester, 'mo_kpi_progress_value'), '2');
      expect(_text(tester, 'mo_kpi_progress_caption'), '67% of total');
      expect(_text(tester, 'mo_kpi_notstarted_value'), '0');
      expect(_text(tester, 'mo_kpi_overall_value'), '58%'); // (50 + 100 + 25) / 3
      expect(_text(tester, 'mo_kpi_overall_caption'), '1 of 3 completed');
      expect(find.descendant(of: _k('mo_takeaways_card'), matching: find.text('No objectives set yet: Artist')), findsOneWidget);
    });

    testWidgets('every department is listed — one with nothing set says so, instead of being left out', (tester) async {
      await _pump(tester);
      for (final d in ['d1', 'd2', 'd3']) {
        expect(_k('mo_dept_$d'), findsOneWidget, reason: d);
      }
      expect(find.text('No objectives set for $_monthName'), findsOneWidget);
    });

    testWidgets('all set: nobody is named as "not set yet"', (tester) async {
      await _pump(tester, pageFor: (k) => _page(departments: [_dept('d1', 'IT', objectives: [_obj('o1', 'x')])]));
      expect(find.textContaining('No objectives set yet'), findsNothing);
    });

    testWidgets('a department card: head, progress, and the results so far', (tester) async {
      await _pump(tester);
      expect(find.text('Head: Ishaan'), findsOneWidget);
      expect(find.text('No head set'), findsOneWidget); // Artist
      expect(_text(tester, 'mo_dept_progress_d1'), '75%'); // (50 + 100) / 2
      expect(find.text('2 objectives · 1 done'), findsOneWidget);
      expect(_text(tester, 'mo_dept_progress_d2'), '25%');
      expect(find.text('1 objective'), findsOneWidget);
    });

    testWidgets('last month is on the card — and is picked out when some of it was never closed', (tester) async {
      await _pump(tester);
      final t = tester.widget<Text>(_k('mo_dept_last_d1'));
      expect(t.data, 'Last month: 1 achieved · 1 partly · 0 missed · 1 not closed');
      expect(t.style!.color, kObjectiveAmber);
      expect(_k('mo_dept_last_d2'), findsNothing); // HR had nothing last month
    });

    testWidgets('someone who belongs to no department is told, not shown a blank', (tester) async {
      await _pump(tester, pageFor: (k) => _page(departments: const []));
      expect(_k('mo_no_departments'), findsOneWidget);
    });

    testWidgets('a month that fails to load says so, with Try again', (tester) async {
      await _pump(tester, loadError: Exception('server down'));
      expect(find.text('Try again'), findsOneWidget);
      expect(_k('mo_summary'), findsNothing);
    });
  });

  group('an objective', () {
    testWidgets('shows its title, owner, how many key results are done and its progress', (tester) async {
      await _pump(tester);
      expect(find.text('Ship the booking app'), findsOneWidget);
      expect(find.text('Irfan'), findsOneWidget);
      expect(find.text('1 of 2 key results done'), findsOneWidget);
      expect(_text(tester, 'mo_progress_o1'), '50%');
    });

    testWidgets('opened, it shows each key result with what it has reached', (tester) async {
      await _pump(tester);
      expect(find.text('Screens done'), findsNothing); // folded
      await _open(tester, 'o1');
      expect(find.text('Screens done'), findsOneWidget);
      expect(_text(tester, 'mo_kr_text_k1'), '20 / 40 screens');
      expect(_text(tester, 'mo_kr_text_k2'), '10 / 10');
    });

    testWidgets('a closed one carries its result and note; a carried-over one says so', (tester) async {
      await _pump(tester);
      expect(find.descendant(of: _k('mo_status_o2'), matching: find.text('Completed')), findsOneWidget);
      expect(find.text('carried over'), findsOneWidget);
      await _open(tester, 'o2');
      expect(find.descendant(of: _k('mo_result_o2'), matching: find.text('Achieved')), findsOneWidget);
      expect(find.text('“Done on the 28th”'), findsOneWidget);
    });

    testWidgets('an objective with no key results says so (and how to add them)', (tester) async {
      await _pump(tester, pageFor: (k) => _page(departments: [_dept('d1', 'IT', canManage: true, objectives: [_obj('o1', 'Hire a trainer', canManage: true)])]));
      await _open(tester, 'o1');
      expect(find.textContaining('No key results yet'), findsOneWidget);
      expect(find.textContaining('Edit the objective to add'), findsOneWidget);
    });
  });

  group('who may do what (the server decides; the app only shows or hides)', () {
    testWidgets('the department\'s head sees Set Objective, Close out the month, and the menu on every objective — for the departments they run', (tester) async {
      await _pump(tester);
      expect(_k('mo_set'), findsOneWidget);
      expect(_k('mo_menu_o1'), findsOneWidget);
      await _tap(tester, _k('mo_header_menu'));
      expect(_k('mo_closeout'), findsOneWidget);
      await tester.tapAt(const Offset(5, 5)); // close the menu
      await tester.pumpAndSettle();
      // IT and the (empty) Artist department are theirs: they choose between those two
      await _tap(tester, _k('mo_set'));
      expect(_k('mo_pick_d1'), findsOneWidget);
      expect(_k('mo_pick_d3'), findsOneWidget);
    });

    testWidgets('someone who only views another department cannot set, close out or edit anything in it', (tester) async {
      await _pump(tester);
      await _tap(tester, _k('mo_set'));
      expect(_k('mo_pick_d2'), findsNothing); // HR is not theirs
      expect(_k('mo_menu_o3'), findsNothing);
    });

    testWidgets('someone who runs no department has no Set Objective and no Close out', (tester) async {
      await _pump(tester, pageFor: (k) => _page(departments: [_dept('d2', 'HR', head: 'Hana', objectives: [_obj('o3', 'Hire two trainers', dept: 'd2', deptName: 'HR')])]));
      expect(_k('mo_set'), findsNothing);
      await _tap(tester, _k('mo_header_menu'));
      expect(_k('mo_refresh'), findsOneWidget);
      expect(_k('mo_closeout'), findsNothing);
    });

    testWidgets('with only one department to run, "Set Objective" goes straight to it', (tester) async {
      await _pump(tester, pageFor: (k) => _page(departments: [_dept('d1', 'IT', head: 'Ishaan', canManage: true, objectives: [_obj('o1', 'x', canManage: true)]), _dept('d2', 'HR', head: 'Hana')]));
      await _tap(tester, _k('mo_set'));
      expect(_k('mo_pick_dialog'), findsNothing);
      expect(_k('mo_form_title'), findsOneWidget);
    });

    testWidgets('the CEO\'s view: every department, no buttons at all', (tester) async {
      await _pump(tester, pageFor: (k) => _page(departments: [
            _dept('d1', 'IT', head: 'Ishaan', objectives: [_obj('o1', 'Ship it', krs: [_kr('k1', 'Screens', 40, 20)])]),
            _dept('d3', 'Artist'),
          ]));
      expect(_k('mo_set'), findsNothing);
      expect(_k('mo_menu_o1'), findsNothing);
      await _tap(tester, _k('mo_header_menu'));
      expect(_k('mo_closeout'), findsNothing);
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      await _open(tester, 'o1');
      expect(_k('mo_kr_checkin_o1_k1'), findsNothing);
      expect(find.text('No objectives set for $_monthName'), findsOneWidget);
    });

    testWidgets('the owner of an objective may report progress on it, but not rewrite it', (tester) async {
      await _pump(tester, pageFor: (k) => _page(departments: [
            _dept('d1', 'IT', objectives: [_obj('o1', 'Ship it', canCheckIn: true, krs: [_kr('k1', 'Screens', 40, 20)])]),
          ]));
      await _open(tester, 'o1');
      expect(_k('mo_kr_checkin_o1_k1'), findsOneWidget);
      expect(_k('mo_menu_o1'), findsNothing);
    });

    testWidgets('a closed objective is not reported on — even by someone who could have while it was open', (tester) async {
      await _pump(tester, pageFor: (k) => _page(departments: [
            _dept('d1', 'IT', objectives: [_obj('c1', 'Closed with work left', progress: 40, result: 'partly', canCheckIn: true, krs: [_kr('kc', 'Screens', 40, 16)])]),
          ]));
      await _open(tester, 'c1');
      expect(find.text('Screens'), findsOneWidget); // opened…
      expect(_k('mo_kr_checkin_c1_kc'), findsNothing); // …but no "Update"
    });
  });

  group('adding an objective', () {
    Future<void> openForm(WidgetTester t, {String dept = 'd1'}) async {
      await _startAdd(t, dept);
    }

    testWidgets('the form says whose month it is; the title is required', (tester) async {
      await _pump(tester);
      await openForm(tester);
      expect(find.text('New objective'), findsOneWidget);
      expect(find.text('IT · $_monthName ${_now.year}'), findsOneWidget);
      await _tap(tester, _k('mo_form_save'));
      expect(find.text('Give the objective a title.'), findsOneWidget);
      expect(find.text('New objective'), findsOneWidget); // still open
    });

    testWidgets('a key result needs a name and a target above zero', (tester) async {
      final s = await _pump(tester);
      await openForm(tester);
      await tester.enterText(_k('mo_form_title'), 'Win more brides');
      await _tap(tester, _k('mo_form_add_kr'));
      await _tap(tester, _k('mo_form_save'));
      expect(find.text('Name key result 1.'), findsOneWidget);
      expect(find.text('Target above 0'), findsOneWidget);
      await tester.enterText(_k('mo_form_kr_title_0'), 'Bookings');
      await tester.enterText(_k('mo_form_kr_target_0'), '0');
      await _tap(tester, _k('mo_form_save'));
      expect(find.text('Target above 0'), findsOneWidget);
      expect(s.calls, isEmpty);
    });

    testWidgets('saving sends the department, the month, the title and every key result — then closes with a toast', (tester) async {
      final s = await _pump(tester);
      await openForm(tester);
      await tester.enterText(_k('mo_form_title'), '  Win more brides ');
      await _tap(tester, _k('mo_form_add_kr'));
      await tester.enterText(_k('mo_form_kr_title_0'), 'Bookings');
      await tester.enterText(_k('mo_form_kr_target_0'), '40');
      await tester.enterText(_k('mo_form_kr_unit_0'), 'bookings');
      await _tap(tester, _k('mo_form_add_kr'));
      await tester.enterText(_k('mo_form_kr_title_1'), 'Reviews');
      await tester.enterText(_k('mo_form_kr_target_1'), '12.5');
      await _tap(tester, _k('mo_form_save'));

      expect(s.calls, hasLength(1));
      final c = s.calls.single;
      expect(c.name, 'create');
      expect(c.args['departmentId'], 'd1');
      expect(c.args['month'], _thisMonth);
      expect(c.args['objective'], 'Win more brides');
      expect(c.args['krs'], ['-|Bookings|40.0|bookings', '-|Reviews|12.5|']);
      expect(find.text('New objective'), findsNothing); // closed
      expect(find.text('Objective added'), findsOneWidget);
    });

    testWidgets('after saving, the month is read again (so the new objective appears)', (tester) async {
      final s = await _pump(tester);
      final before = s.requested.length;
      await openForm(tester);
      await tester.enterText(_k('mo_form_title'), 'Another');
      await _tap(tester, _k('mo_form_save'));
      expect(s.requested.length, greaterThan(before));
    });

    testWidgets('key results can be taken out, and there are at most eight', (tester) async {
      await _pump(tester);
      await openForm(tester);
      for (var i = 0; i < 8; i++) {
        await _tap(tester, _k('mo_form_add_kr'));
      }
      expect(find.text('8 of 8'), findsOneWidget);
      expect(tester.widget<TextButton>(_k('mo_form_add_kr')).onPressed, isNull);
      await _tap(tester, _k('mo_form_kr_remove_3'));
      expect(find.text('7 of 8'), findsOneWidget);
      expect(tester.widget<TextButton>(_k('mo_form_add_kr')).onPressed, isNotNull);
    });

    testWidgets('a refusal from the server is shown in the form, which stays open with what was typed', (tester) async {
      final s = _Service()..failWith = Exception('boom');
      await _pump(tester, service: s);
      await openForm(tester);
      await tester.enterText(_k('mo_form_title'), 'Keep me');
      await _tap(tester, _k('mo_form_save'));
      expect(_k('mo_form_error'), findsOneWidget);
      expect(find.text('Keep me'), findsOneWidget);
      expect(find.text('New objective'), findsOneWidget);
    });

    testWidgets('the owner list is the department\'s own staff', (tester) async {
      await _pump(tester);
      await openForm(tester);
      await _tap(tester, _k('mo_form_owner'));
      expect(tester.takeException(), isNull);
      expect(find.text('Irfan'), findsWidgets);
      expect(find.text('Imran'), findsWidgets);
      expect(find.text('Hana'), findsNothing); // HR
    });
  });

  group('editing', () {
    testWidgets('the form opens with what is there; saving keeps each key result\'s id and sends the version it was edited from', (tester) async {
      final s = await _pump(tester);
      await _tap(tester, _k('mo_menu_o1'));
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      expect(find.text('Edit objective'), findsOneWidget);
      expect(find.text('Ship the booking app'), findsWidgets);
      await tester.enterText(_k('mo_form_title'), 'Ship the booking app v2');
      await tester.enterText(_k('mo_form_kr_target_0'), '50');
      await _tap(tester, _k('mo_form_save'));
      final c = s.calls.single;
      expect(c.name, 'update');
      expect(c.args['id'], 'o1');
      expect(c.args['expectedUpdatedAt'], '2026-11-02T10:00:00.000Z'); // so a stale edit is refused, not overwritten
      expect(c.args['objective'], 'Ship the booking app v2');
      expect(c.args['krs'], ['k1|Screens done|50.0|screens', 'k2|Bugs closed|10.0|']);
      expect(find.text('Objective saved'), findsOneWidget);
    });

    testWidgets('a closed objective cannot be edited or deleted — only reopened', (tester) async {
      await _pump(tester);
      await _tap(tester, _k('mo_menu_o2'));
      expect(find.text('Edit'), findsNothing);
      expect(find.text('Delete'), findsNothing);
      expect(find.text('Reopen'), findsOneWidget);
    });

    testWidgets('Reopen reopens it', (tester) async {
      final s = await _pump(tester);
      await _tap(tester, _k('mo_menu_o2'));
      await tester.tap(find.text('Reopen'));
      await tester.pumpAndSettle();
      expect(s.calls.single.name, 'reopen');
      expect(s.calls.single.args['id'], 'o2');
      expect(find.text('Objective reopened'), findsOneWidget);
    });
  });

  group('deleting', () {
    testWidgets('asks first; Cancel deletes nothing', (tester) async {
      final s = await _pump(tester);
      await _tap(tester, _k('mo_menu_o1'));
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(find.text('Delete this objective?'), findsOneWidget);
      await tester.tap(_k('mo_delete_cancel'));
      await tester.pumpAndSettle();
      expect(s.calls, isEmpty);
    });

    testWidgets('confirming deletes it', (tester) async {
      final s = await _pump(tester);
      await _tap(tester, _k('mo_menu_o1'));
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(_k('mo_delete_confirm'));
      await tester.pumpAndSettle();
      expect(s.calls.single.name, 'delete');
      expect(s.calls.single.args['id'], 'o1');
      expect(find.text('Objective deleted'), findsOneWidget);
    });

    testWidgets('a refusal is shown, not swallowed', (tester) async {
      final s = _Service()..failWith = Exception('no');
      await _pump(tester, service: s);
      await _tap(tester, _k('mo_menu_o1'));
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(_k('mo_delete_confirm'));
      await tester.pumpAndSettle();
      expect(find.text('Objective deleted'), findsNothing);
      expect(find.byType(SnackBar), findsOneWidget);
    });
  });

  group('reporting progress', () {
    Future<void> openReport(WidgetTester t) async {
      await _open(t, 'o1');
      await _tap(t, _k('mo_kr_checkin_o1_k1'));
    }

    testWidgets('opens with what it has reached; saving sends the new number (and not "done", which reaching the target does by itself)', (tester) async {
      final s = await _pump(tester);
      await openReport(tester);
      expect(find.text('Screens done'), findsWidgets);
      expect(find.textContaining('Target 40 screens'), findsOneWidget);
      expect(tester.widget<TextField>(_k('mo_ci_value')).controller!.text, '20');
      await tester.enterText(_k('mo_ci_value'), '31');
      await _tap(tester, _k('mo_ci_save'));
      final c = s.calls.single;
      expect(c.name, 'checkIn');
      expect(c.args, {'objective': 'o1', 'kr': 'k1', 'value': 31.0, 'completed': null});
      expect(find.text('Progress saved'), findsOneWidget);
    });

    testWidgets('"Mark as done" is sent when it is ticked', (tester) async {
      final s = await _pump(tester);
      await openReport(tester);
      await _tap(tester, _k('mo_ci_done'));
      await _tap(tester, _k('mo_ci_save'));
      expect(s.calls.single.args['completed'], true);
    });

    testWidgets('a blank or negative number is refused before anything is sent', (tester) async {
      final s = await _pump(tester);
      await openReport(tester);
      await tester.enterText(_k('mo_ci_value'), '');
      await _tap(tester, _k('mo_ci_save'));
      expect(_k('mo_ci_error'), findsOneWidget);
      await tester.enterText(_k('mo_ci_value'), '-3');
      await _tap(tester, _k('mo_ci_save'));
      expect(_k('mo_ci_error'), findsOneWidget);
      expect(s.calls, isEmpty);
    });

    testWidgets('a refusal from the server stays in the dialog', (tester) async {
      final s = _Service()..failWith = Exception('closed');
      await _pump(tester, service: s);
      await openReport(tester);
      await _tap(tester, _k('mo_ci_save'));
      expect(_k('mo_ci_error'), findsOneWidget);
      expect(find.textContaining('Target 40 screens'), findsOneWidget);
    });
  });

  group('closing the month out', () {
    // IT: o1 open at 60% (Partly), o2 open 100% (Achieved), o3 open 10% (Missed), o4 already closed Partly and not yet carried
    final it = MonthlyDepartment.fromJson(_dept('d1', 'IT', head: 'Ishaan', canManage: true, objectives: [
      _obj('a', 'Sixty percent', progress: 60, canManage: true, krs: [_kr('ka', 'K', 10, 6)]),
      _obj('b', 'All done', progress: 100, canManage: true, krs: [_kr('kb', 'K', 10, 10, done: true)]),
      _obj('c', 'Barely started', progress: 10, canManage: true, krs: [_kr('kc', 'K', 10, 1)]),
      _obj('d', 'Closed earlier', progress: 40, result: 'partly', canManage: true, krs: [_kr('kd', 'K', 10, 4)]),
    ]));

    Future<_Service> openCloseOut(WidgetTester t, {_Service? service}) async {
      final s = await _pump(t, service: service, pageFor: (k) => _page(departments: [_dept('d1', 'IT', head: 'Ishaan', canManage: true, objectives: [
            _obj('a', 'Sixty percent', progress: 60, canManage: true, krs: [_kr('ka', 'K', 10, 6)]),
            _obj('b', 'All done', progress: 100, canManage: true, krs: [_kr('kb', 'K', 10, 10, done: true)]),
            _obj('c', 'Barely started', progress: 10, canManage: true, krs: [_kr('kc', 'K', 10, 1)]),
            _obj('d', 'Closed earlier', progress: 40, result: 'partly', canManage: true, krs: [_kr('kd', 'K', 10, 4)]),
          ])]));
      await _startCloseOut(t, 'd1');
      return s;
    }

    ObjectiveResult selected(WidgetTester t, String id) => t.widget<SegmentedButton<ObjectiveResult>>(_k('mo_co_result_$id')).selected.single;
    bool? carry(WidgetTester t, String id) => find.byKey(Key('mo_co_carry_$id')).evaluate().isEmpty ? null : t.widget<CheckboxListTile>(_k('mo_co_carry_$id')).value;

    test('what each objective starts as: done is Achieved, half way Partly, less Missed', () {
      expect(it.objectives[0].suggestedResult, ObjectiveResult.partly);
      expect(it.objectives[1].suggestedResult, ObjectiveResult.achieved);
      expect(it.objectives[2].suggestedResult, ObjectiveResult.missed);
      MonthlyObjective at(int p) => _o(progress: p, krs: [_kr('k', 'K', 100, p)]);
      expect(at(49).suggestedResult, ObjectiveResult.missed);
      expect(at(50).suggestedResult, ObjectiveResult.partly);
      expect(at(99).suggestedResult, ObjectiveResult.partly);
      expect(_o(progress: 0).suggestedResult, isNull); // no key results: nothing measures it, so nothing is suggested
    });

    testWidgets('opens with a row for each objective, the result already guessed from its progress', (tester) async {
      await openCloseOut(tester);
      expect(find.text('Close out $_monthName ${_now.year}'), findsOneWidget);
      expect(selected(tester, 'a'), ObjectiveResult.partly);
      expect(selected(tester, 'b'), ObjectiveResult.achieved);
      expect(selected(tester, 'c'), ObjectiveResult.missed);
      expect(_k('mo_co_result_d'), findsNothing); // closed already: no choice to make
      expect(find.text('Closed already'), findsOneWidget);
    });

    testWidgets('what is unfinished is offered for carrying over, ticked; an achieved one is not offered', (tester) async {
      await openCloseOut(tester);
      expect(carry(tester, 'a'), true);
      expect(carry(tester, 'c'), true);
      expect(carry(tester, 'b'), isNull); // achieved: nothing to carry
      expect(carry(tester, 'd'), true); // closed earlier but never carried
      expect(find.text('3 will be carried into $_nextMonthName'), findsOneWidget);
    });

    testWidgets('choosing Achieved takes the carry-over away; choosing something else offers it again', (tester) async {
      await openCloseOut(tester);
      await tester.tap(find.descendant(of: _k('mo_co_result_a'), matching: find.text('Achieved')));
      await tester.pumpAndSettle();
      expect(carry(tester, 'a'), isNull);
      expect(find.text('2 will be carried into $_nextMonthName'), findsOneWidget);
      await tester.tap(find.descendant(of: _k('mo_co_result_a'), matching: find.text('Missed')));
      await tester.pumpAndSettle();
      expect(carry(tester, 'a'), true);
    });

    testWidgets('confirming closes each open one with its result and note, then carries over what is ticked — and says what it did', (tester) async {
      final s = await openCloseOut(tester);
      await tester.enterText(_k('mo_co_note_a'), 'Half way there');
      await tester.tap(find.descendant(of: _k('mo_co_result_c'), matching: find.text('Partly'))); // changed from Missed (10%) — so it says why
      await tester.pumpAndSettle();
      await tester.enterText(_k('mo_co_note_c'), 'Nearly there');
      await _tap(tester, _k('mo_co_carry_c')); // …and left behind
      await _tap(tester, _k('mo_co_confirm'));

      expect([for (final c in s.calls) c.name], ['close', 'close', 'close', 'carryOver']);
      expect(s.calls[0].args, {'id': 'a', 'result': 'partly', 'note': 'Half way there'});
      expect(s.calls[1].args, {'id': 'b', 'result': 'achieved', 'note': ''});
      expect(s.calls[2].args, {'id': 'c', 'result': 'partly', 'note': 'Nearly there'});
      expect(s.calls[3].args['departmentId'], 'd1');
      expect(s.calls[3].args['month'], _thisMonth);
      expect(s.calls[3].args['ids'], ['a', 'd']); // c was unticked, b is achieved
      expect(find.text('Close out $_monthName ${_now.year}'), findsNothing);
      expect(find.text('Closed 3 objectives · carried 2 into $_nextMonthName'), findsOneWidget);
    });

    testWidgets('changing a result starts the carry-over choice afresh: unticked, then re-offered ticked when it is not Achieved', (tester) async {
      await openCloseOut(tester);
      await _tap(tester, _k('mo_co_carry_c')); // leave it behind…
      expect(carry(tester, 'c'), false);
      await tester.tap(find.descendant(of: _k('mo_co_result_c'), matching: find.text('Partly'))); // …then change its result
      await tester.pumpAndSettle();
      expect(carry(tester, 'c'), true);
    });

    testWidgets('an objective closed earlier is never closed again', (tester) async {
      final s = await openCloseOut(tester);
      await _tap(tester, _k('mo_co_confirm'));
      expect(s.calls.where((c) => c.name == 'close').map((c) => c.args['id']), isNot(contains('d')));
    });

    testWidgets('nothing ticked to carry: it only closes', (tester) async {
      final s = await openCloseOut(tester);
      for (final id in ['a', 'c', 'd']) {
        await _tap(tester, _k('mo_co_carry_$id'));
      }
      await _tap(tester, _k('mo_co_confirm'));
      expect(s.calls.every((c) => c.name == 'close'), isTrue);
      expect(find.text('Closed 3 objectives'), findsOneWidget);
    });

    testWidgets('if it stops part-way, it says how far it got', (tester) async {
      final s = _Service()..failWith = Exception('lost connection')..failAfter = 2;
      await openCloseOut(tester, service: s);
      await _tap(tester, _k('mo_co_confirm'));
      expect(find.textContaining('Closed 1, then it stopped'), findsOneWidget);
      expect(find.text('Close out $_monthName ${_now.year}'), findsOneWidget); // still open, to try again
    });

    testWidgets('a month already closed out only offers the carry-over, and has nothing to do once that is done', (tester) async {
      await _pump(tester, pageFor: (k) => _page(departments: [_dept('d1', 'IT', canManage: true, objectives: [
            _obj('x', 'Closed, left unfinished', progress: 40, result: 'partly', canManage: true, krs: [_kr('kx', 'K', 10, 4)]),
            _obj('y', 'Closed and carried', progress: 40, result: 'partly', canManage: true, carriedTo: true, krs: [_kr('ky', 'K', 10, 4)]),
          ])]));
      await _startCloseOut(tester, 'd1');
      expect(find.descendant(of: _k('mo_co_confirm'), matching: find.text('Carry over')), findsOneWidget);
      expect(carry(tester, 'x'), true);
      expect(carry(tester, 'y'), isNull); // already carried
      expect(find.textContaining('Already carried into'), findsOneWidget);
      await _tap(tester, _k('mo_co_carry_x'));
      expect(tester.widget<FilledButton>(_k('mo_co_confirm')).onPressed, isNull); // nothing left to do
    });
  });

  group('layout', () {
    testWidgets('a phone (360): one column, nothing overflows', (tester) async {
      await _pump(tester, size: const Size(360, 2600));
      expect(tester.takeException(), isNull);
      final a = tester.getRect(_k('mo_dept_d1'));
      final b = tester.getRect(_k('mo_dept_d2'));
      expect(a.left, b.left);
      expect(b.top, greaterThan(a.bottom - 1)); // stacked
      expect(a.width, greaterThan(360 - 40));
    });

    testWidgets('a laptop (1400): departments sit three by three, and the trend, target and takeaways side by side', (tester) async {
      await _pump(tester);
      expect(tester.takeException(), isNull);
      final a = tester.getRect(_k('mo_dept_d1'));
      final b = tester.getRect(_k('mo_dept_d2'));
      final c = tester.getRect(_k('mo_dept_d3'));
      expect(b.left, greaterThan(a.right));
      expect(c.left, greaterThan(b.right));
      expect((a.top - b.top).abs(), lessThan(2));
      expect((b.top - c.top).abs(), lessThan(2));
      // IT has a "last month" line the others do not — the three cards are still the same height
      expect(a.height, closeTo(b.height, 0.5));
      expect(b.height, closeTo(c.height, 0.5));
      final trend = tester.getRect(find.ancestor(of: _k('mo_trend_chart'), matching: find.byType(Container)).first);
      final target = tester.getRect(_k('mo_target_card'));
      final takeaways = tester.getRect(_k('mo_takeaways_card'));
      expect(target.left, greaterThan(trend.left));
      expect(takeaways.left, greaterThan(target.left));
      expect((target.top - takeaways.top).abs(), lessThan(2));
    });

    testWidgets('a laptop (1400): "This Month" sits beside the month, the department filter at the far side', (tester) async {
      await _pump(tester);
      final title = tester.getRect(_k('mo_title'));
      final pill = tester.getRect(_k('mo_this_month'));
      final filter = tester.getRect(_k('mo_dept_filter'));
      expect(pill.left, greaterThan(title.right));
      expect(pill.left, lessThan(title.right + 400)); // right next to it (the test font is wide), not floating in the middle
      expect(filter.right, greaterThan(1300));
      expect((filter.top - pill.top).abs(), lessThan(30)); // one line
    });

    testWidgets('a phone (360): the filter wraps under the month rather than squeezing it', (tester) async {
      await _pump(tester, size: const Size(360, 3200));
      expect(tester.getRect(_k('mo_dept_filter')).top, greaterThan(tester.getRect(_k('mo_title')).bottom - 1));
      expect(tester.takeException(), isNull);
    });

    testWidgets('a tablet (800): two departments across, the trend above target and takeaways', (tester) async {
      await _pump(tester, size: const Size(800, 2200));
      expect(tester.takeException(), isNull);
      final a = tester.getRect(_k('mo_dept_d1'));
      final b = tester.getRect(_k('mo_dept_d2'));
      expect(b.left, greaterThan(a.right));
      expect((a.top - b.top).abs(), lessThan(2));
      final target = tester.getRect(_k('mo_target_card'));
      final takeaways = tester.getRect(_k('mo_takeaways_card'));
      expect(takeaways.left, greaterThan(target.left));
      expect((target.top - takeaways.top).abs(), lessThan(2));
    });

    testWidgets('a phone (360): the headline numbers sit two across, and every card is one column', (tester) async {
      await _pump(tester, size: const Size(360, 3200));
      expect(tester.takeException(), isNull);
      final total = tester.getRect(_k('mo_kpi_total'));
      final done = tester.getRect(_k('mo_kpi_completed'));
      expect(done.left, greaterThan(total.right - 1));
      expect((total.top - done.top).abs(), lessThan(2));
      expect(tester.getRect(_k('mo_target_card')).left, tester.getRect(_k('mo_takeaways_card')).left);
    });

    testWidgets('the form with everything switched on still fits a phone: all three key-result kinds, several months, and the reason', (tester) async {
      await _pump(tester, size: const Size(360, 900), pageFor: (k) => _page(departments: [
            _dept('d1', 'IT', head: 'Ishaan', canManage: true, objectives: [
              _obj('o1', 'Marketing Automation', canManage: true, planLocked: true, span: {'number': 2, 'total': 3, 'final': false, 'overran': false}, krs: [
                _kr('a', 'Leads', 40, 12, unit: 'leads'),
                _kr('b', 'Automation built', 100, 60, kind: 'percent'),
                _kr('c', 'Launched', 1, 0, kind: 'yesno'),
              ]),
            ]),
          ]));
      await _tap(tester, _k('mo_menu_o1'));
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      await tester.enterText(_k('mo_form_title'), 'Marketing Automation v2'); // so the reason shows its problem too
      await tester.ensureVisible(_k('mo_form_save'));
      await tester.pumpAndSettle();
      await tester.tap(_k('mo_form_save'));
      await tester.pumpAndSettle();
      expect(find.text('Say why the plan is changing.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the assigned section and the close-out dialog fit a phone', (tester) async {
      await _pump(tester, size: const Size(360, 900), pageFor: (k) => _page(
            departments: [_dept('d1', 'IT', head: 'Ishaan', canManage: true, member: true, objectives: [_obj('o1', 'Marketing Automation', canManage: true, span: {'number': 1, 'total': 3, 'final': false, 'overran': false}, krs: [_kr('a', 'Leads', 40, 12)])])],
            assigned: [_obj('g1', 'Fleet audit for IT with a long title to wrap', dept: 'd9', deptName: 'Fleet', canCheckIn: true, assignedToMe: true, krs: [_kr('a', 'Vehicles checked this month', 10, 4, unit: 'vehicles'), _kr('b', 'Report filed', 1, 0, kind: 'yesno')])],
          ));
      expect(tester.takeException(), isNull);
      await _startCloseOut(tester, 'd1');
      expect(tester.takeException(), isNull);
    });

    testWidgets('the form fits a phone', (tester) async {
      await _pump(tester, size: const Size(360, 800));
      await _startAdd(tester, 'd1');
      await _tap(tester, _k('mo_form_add_kr'));
      expect(tester.takeException(), isNull);
    });
  });

  group('in Company Projects', () {
    testWidgets('Monthly is a mode of its own beside Objectives & OKRs — open it from the pills', (tester) async {
      await _pump(tester, screen: const CompanyProjectsScreen());
      expect(_k('mode_monthly'), findsOneWidget);
      expect(find.text('Objectives & OKRs'), findsOneWidget);
      expect(_k('mo_summary'), findsNothing); // not until chosen
      await _tap(tester, _k('mode_monthly'));
      expect(_k('mo_summary'), findsOneWidget);
    });

    testWidgets('a link with ?mode=monthly (the reminder notification) opens straight into it', (tester) async {
      await _pump(tester, screen: const CompanyProjectsScreen(initialMode: 'monthly'));
      expect(_k('mo_summary'), findsOneWidget);
    });

    testWidgets('on a phone the Monthly pill is reachable when linked to', (tester) async {
      await _pump(tester, size: const Size(360, 800), screen: const CompanyProjectsScreen(initialMode: 'monthly'));
      expect(tester.takeException(), isNull);
      expect(tester.getRect(_k('mode_monthly')).right, lessThanOrEqualTo(360 + 1)); // scrolled into view
    });

    testWidgets('an unknown mode falls back to the usual one', (tester) async {
      await _pump(tester, screen: const CompanyProjectsScreen(initialMode: 'nonsense'));
      expect(_k('mo_summary'), findsNothing);
    });
  });

  // ── when the objective is not just "a number, then a result" ──────────────────
  MonthlyObjectivesPage Function(MonthKey) pageOf(List<Map<String, dynamic>> objectives) =>
      (k) => _page(departments: [_dept('d1', 'IT', head: 'Ishaan', canManage: true, objectives: objectives)]);

  group('a key result that is not a number', () {
    Future<_Service> startNew(WidgetTester t) async {
      final s = await _pump(t);
      await _startAdd(t, 'd1');
      await t.enterText(_k('mo_form_title'), 'Marketing Automation');
      await _tap(t, _k('mo_form_add_kr'));
      return s;
    }

    testWidgets('a new key result is a number, as before — target and unit are asked for — with the other two kinds on offer', (tester) async {
      await startNew(tester);
      expect(_k('mo_form_kr_target_0'), findsOneWidget);
      expect(_k('mo_form_kr_unit_0'), findsOneWidget);
      expect(tester.widget<ChoiceChip>(_k('mo_form_kr_kind_0_number')).selected, isTrue);
      expect(_k('mo_form_kr_kind_0_percent'), findsOneWidget);
      expect(_k('mo_form_kr_kind_0_yesno'), findsOneWidget);
    });

    testWidgets('a percentage needs no target — only its name — and is sent as a percentage', (tester) async {
      final s = await startNew(tester);
      await _tap(tester, _k('mo_form_kr_kind_0_percent'));
      expect(_k('mo_form_kr_target_0'), findsNothing);
      expect(_k('mo_form_kr_unit_0'), findsNothing);
      expect(find.textContaining('Out of 100%'), findsOneWidget);
      await tester.enterText(_k('mo_form_kr_title_0'), 'Automation built');
      await _tap(tester, _k('mo_form_save'));
      expect(s.calls.single.args['krs'], ['-|Automation built|100.0||percent']);
    });

    testWidgets('a yes / no needs no target either, and is sent as done-or-not', (tester) async {
      final s = await startNew(tester);
      await _tap(tester, _k('mo_form_kr_kind_0_yesno'));
      expect(_k('mo_form_kr_target_0'), findsNothing);
      expect(find.textContaining('Done or not done'), findsOneWidget);
      await tester.enterText(_k('mo_form_kr_title_0'), 'Campaign launched');
      await _tap(tester, _k('mo_form_save'));
      expect(s.calls.single.args['krs'], ['-|Campaign launched|1.0||yesno']);
    });

    testWidgets('a mixed objective: a number, a percentage and a yes/no together', (tester) async {
      final s = await startNew(tester);
      await tester.enterText(_k('mo_form_kr_title_0'), 'Leads');
      await tester.enterText(_k('mo_form_kr_target_0'), '50');
      await _tap(tester, _k('mo_form_add_kr'));
      await _tap(tester, _k('mo_form_kr_kind_1_percent'));
      await tester.enterText(_k('mo_form_kr_title_1'), 'Automation built');
      await _tap(tester, _k('mo_form_add_kr'));
      await _tap(tester, _k('mo_form_kr_kind_2_yesno'));
      await tester.enterText(_k('mo_form_kr_title_2'), 'Launched');
      await _tap(tester, _k('mo_form_save'));
      expect(s.calls.single.args['krs'], ['-|Leads|50.0|', '-|Automation built|100.0||percent', '-|Launched|1.0||yesno']);
    });

    testWidgets('going back to a number asks for its target again — and a number still needs one', (tester) async {
      final s = await startNew(tester);
      await _tap(tester, _k('mo_form_kr_kind_0_yesno'));
      await _tap(tester, _k('mo_form_kr_kind_0_number'));
      expect(_k('mo_form_kr_target_0'), findsOneWidget);
      await tester.enterText(_k('mo_form_kr_title_0'), 'Leads');
      await _tap(tester, _k('mo_form_save'));
      expect(find.text('Target above 0'), findsOneWidget);
      expect(s.calls, isEmpty);
    });

    testWidgets('taking out the key result above never leaves the next one showing the wrong kind', (tester) async {
      await startNew(tester);
      await _tap(tester, _k('mo_form_add_kr'));
      await _tap(tester, _k('mo_form_kr_kind_1_yesno'));
      await _tap(tester, _k('mo_form_kr_remove_0'));
      expect(tester.widget<ChoiceChip>(_k('mo_form_kr_kind_0_yesno')).selected, isTrue);
      expect(_k('mo_form_kr_target_0'), findsNothing);
    });

    testWidgets('editing keeps each key result\'s kind (and its id) as it was', (tester) async {
      final s = await _pump(tester, pageFor: pageOf([
        _obj('o1', 'Marketing Automation', canManage: true, krs: [_kr('k1', 'Automation built', 100, 60, unit: '%', kind: 'percent'), _kr('k2', 'Launched', 1, 0, kind: 'yesno')]),
      ]));
      await _tap(tester, _k('mo_menu_o1'));
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      expect(tester.widget<ChoiceChip>(_k('mo_form_kr_kind_0_percent')).selected, isTrue);
      expect(tester.widget<ChoiceChip>(_k('mo_form_kr_kind_1_yesno')).selected, isTrue);
      await _tap(tester, _k('mo_form_save'));
      expect(s.calls.single.args['krs'], ['k1|Automation built|100.0||percent', 'k2|Launched|1.0||yesno']);
    });

    testWidgets('each reads as it should in the objective: "60%", "Done", "Not yet", "20 / 40 screens"', (tester) async {
      await _pump(tester, pageFor: pageOf([
        _obj('o1', 'Marketing Automation', krs: [_kr('p', 'Built', 100, 60, kind: 'percent'), _kr('y', 'Launched', 1, 1, kind: 'yesno', done: true), _kr('n', 'Not launched', 1, 0, kind: 'yesno'), _kr('c', 'Leads', 40, 20, unit: 'screens')]),
      ]));
      await _open(tester, 'o1');
      expect(_text(tester, 'mo_kr_text_p'), '60%');
      expect(_text(tester, 'mo_kr_text_y'), 'Done');
      expect(_text(tester, 'mo_kr_text_n'), 'Not yet');
      expect(_text(tester, 'mo_kr_text_c'), '20 / 40 screens');
    });
  });

  group('reporting on a key result that is not a number', () {
    Future<_Service> open(WidgetTester t, String krId, {_Service? service}) async {
      final s = await _pump(t, service: service, pageFor: pageOf([
        _obj('o1', 'Marketing Automation', canManage: true, canCheckIn: true, krs: [_kr('p', 'Automation built', 100, 60, kind: 'percent'), _kr('y', 'Launched', 1, 0, kind: 'yesno'), _kr('d', 'Done already', 1, 1, kind: 'yesno', done: true)]),
      ]));
      await _open(t, 'o1');
      await _tap(t, _k('mo_kr_checkin_o1_$krId'));
      return s;
    }

    testWidgets('a yes / no has no number to give — it is ticked, and that is sent', (tester) async {
      final s = await open(tester, 'y');
      expect(_k('mo_ci_value'), findsNothing);
      expect(find.text('Not done yet'), findsOneWidget);
      await _tap(tester, _k('mo_ci_done'));
      await _tap(tester, _k('mo_ci_save'));
      expect(s.calls.single.args, {'objective': 'o1', 'kr': 'y', 'value': null, 'completed': true});
    });

    testWidgets('a yes / no that was done can be put back', (tester) async {
      final s = await open(tester, 'd');
      await _tap(tester, _k('mo_ci_done'));
      await _tap(tester, _k('mo_ci_save'));
      expect(s.calls.single.args['completed'], false);
    });

    testWidgets('a percentage is a number out of 100: 65 is sent, 130 is refused before anything is sent', (tester) async {
      final s = await open(tester, 'p');
      expect(find.text('So far 60% of 100%'), findsOneWidget);
      await tester.enterText(_k('mo_ci_value'), '130');
      await _tap(tester, _k('mo_ci_save'));
      expect(find.text('A percentage is out of 100.'), findsOneWidget);
      expect(s.calls, isEmpty);
      await tester.enterText(_k('mo_ci_value'), '65');
      await _tap(tester, _k('mo_ci_save'));
      expect(s.calls.single.args, {'objective': 'o1', 'kr': 'p', 'value': 65.0, 'completed': null});
    });
  });

  group('an objective that takes several months', () {
    Future<void> startNew(WidgetTester t) async {
      await _startAdd(t, 'd1');
      await t.enterText(_k('mo_form_title'), 'Marketing Automation');
    }

    testWidgets('an ordinary objective is one month, and the length is not asked until it is switched on', (tester) async {
      final s = await _pump(tester);
      await startNew(tester);
      expect(tester.widget<SwitchListTile>(_k('mo_form_span_switch')).value, isFalse);
      expect(_k('mo_form_span_months'), findsNothing);
      await _tap(tester, _k('mo_form_save'));
      expect(s.calls.single.args['spanMonths'], 1);
    });

    testWidgets('switched on, it asks how long (three months to begin with) and sends that', (tester) async {
      final s = await _pump(tester);
      await startNew(tester);
      await _tap(tester, _k('mo_form_span_switch'));
      expect(find.text('3 months'), findsOneWidget);
      await _tap(tester, _k('mo_form_save'));
      expect(s.calls.single.args['spanMonths'], 3);
    });

    testWidgets('and any length from 2 to 12 can be chosen', (tester) async {
      final s = await _pump(tester);
      await startNew(tester);
      await _tap(tester, _k('mo_form_span_switch'));
      await _tap(tester, _k('mo_form_span_months'));
      await tester.tap(find.text('6 months').last);
      await tester.pumpAndSettle();
      await _tap(tester, _k('mo_form_save'));
      expect(s.calls.single.args['spanMonths'], 6);
    });

    testWidgets('one that already runs shows its length; switching it off sends one month', (tester) async {
      final s = await _pump(tester, pageFor: pageOf([
        _obj('o1', 'Marketing Automation', canManage: true, span: {'number': 2, 'total': 4, 'final': false, 'overran': false}, krs: [_kr('k', 'Leads', 40, 12)]),
      ]));
      await _tap(tester, _k('mo_menu_o1'));
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      expect(tester.widget<SwitchListTile>(_k('mo_form_span_switch')).value, isTrue);
      expect(find.text('4 months'), findsOneWidget);
      await _tap(tester, _k('mo_form_span_switch'));
      await _tap(tester, _k('mo_form_save'));
      expect(s.calls.single.args['spanMonths'], 1);
    });

    testWidgets('where it is in its run shows on the objective: "Month 2 of 3"; past the plan, it says so', (tester) async {
      await _pump(tester, pageFor: pageOf([
        _obj('a', 'In the middle', span: {'number': 2, 'total': 3, 'final': false, 'overran': false}),
        _obj('b', 'Overran', span: {'number': 4, 'total': 3, 'final': true, 'overran': true}),
        _obj('c', 'One month only'),
      ]));
      expect(_text(tester, 'mo_span_a'), 'Month 2 of 3');
      expect(_text(tester, 'mo_span_b'), 'Month 4 of 3 · over plan');
      expect(_k('mo_span_c'), findsNothing);
    });
  });

  group('changing the plan after the month has started', () {
    Future<_Service> edit(WidgetTester t, {bool locked = true, _Service? service}) async {
      final s = await _pump(t, service: service, pageFor: pageOf([
        _obj('o1', 'Ship the booking app', canManage: true, planLocked: locked, krs: [_kr('k1', 'Screens', 40, 20), _kr('k2', 'Bugs', 10, 2)]),
      ]));
      await _tap(t, _k('mo_menu_o1'));
      await t.tap(find.text('Edit'));
      await t.pumpAndSettle();
      return s;
    }

    testWidgets('a new objective, or one still being planned, is never asked for a reason', (tester) async {
      await edit(tester, locked: false);
      expect(_k('mo_form_reason'), findsNothing);
    });

    testWidgets('once it is locked the form asks why — and says what for', (tester) async {
      await edit(tester);
      expect(_k('mo_form_reason'), findsOneWidget);
      expect(find.textContaining('already started'), findsOneWidget);
    });

    testWidgets('changing the title needs the reason; with it, it is sent along', (tester) async {
      final s = await edit(tester);
      await tester.enterText(_k('mo_form_title'), 'Ship the booking app v2');
      await _tap(tester, _k('mo_form_save'));
      expect(find.text('Say why the plan is changing.'), findsOneWidget);
      expect(s.calls, isEmpty);
      await tester.enterText(_k('mo_form_reason'), 'Scope grew');
      await _tap(tester, _k('mo_form_save'));
      expect(s.calls.single.args['changeReason'], 'Scope grew');
    });

    testWidgets('so does lowering a target, adding a key result, taking one out, or changing its kind', (tester) async {
      Future<void> tryChange(Future<void> Function(WidgetTester) change) async {
        final s = await edit(tester);
        await change(tester);
        await _tap(tester, _k('mo_form_save'));
        expect(find.text('Say why the plan is changing.'), findsOneWidget);
        expect(s.calls, isEmpty);
      }

      await tryChange((t) => t.enterText(_k('mo_form_kr_target_0'), '30'));
      await tryChange((t) async {
        await _tap(t, _k('mo_form_add_kr'));
        await t.enterText(_k('mo_form_kr_title_2'), 'Extra');
        await t.enterText(_k('mo_form_kr_target_2'), '5');
      });
      await tryChange((t) => _tap(t, _k('mo_form_kr_remove_1')));
      await tryChange((t) => _tap(t, _k('mo_form_kr_kind_0_yesno')));
    });

    testWidgets('but the details are not the plan: a new description or priority saves without a reason', (tester) async {
      final s = await edit(tester);
      await tester.enterText(_k('mo_form_desc'), 'More detail');
      await _tap(tester, _k('mo_form_save'));
      expect(s.calls.single.name, 'update');
      expect(s.calls.single.args['changeReason'], '');
    });

    testWidgets('a reason of a letter is not a reason', (tester) async {
      final s = await edit(tester);
      await tester.enterText(_k('mo_form_title'), 'Something else');
      await tester.enterText(_k('mo_form_reason'), 'x');
      await _tap(tester, _k('mo_form_save'));
      expect(find.text('Say why the plan is changing.'), findsOneWidget);
      expect(s.calls, isEmpty);
    });

    testWidgets('each change is on the objective afterwards: when, by whom, why, and what', (tester) async {
      await _pump(tester, pageFor: pageOf([
        _obj('o1', 'Win brides', changes: [
          {'at': '2026-11-04T10:00:00.000Z', 'byName': 'Ishaan', 'reason': 'Two artists left', 'summary': ['“Bookings” target 40 → 30']},
          {'at': '2026-11-06T10:00:00.000Z', 'byName': 'Ishaan', 'reason': 'Focus on referrals', 'summary': ['Added key result “Referrals”', 'Removed key result “Reviews”']},
        ]),
      ]));
      await _open(tester, 'o1');
      expect(find.text('Plan changed 2 times'), findsOneWidget);
      expect(find.textContaining('“Two artists left” — Ishaan'), findsOneWidget);
      expect(find.text('• “Bookings” target 40 → 30'), findsOneWidget);
      expect(find.text('• Removed key result “Reviews”'), findsOneWidget);
    });

    testWidgets('an objective that never changed shows no history', (tester) async {
      await _pump(tester);
      await _open(tester, 'o1');
      expect(_k('mo_changes_o1'), findsNothing);
    });
  });

  group('ending a month differently from what the progress says', () {
    Future<_Service> closeOut(WidgetTester t, List<Map<String, dynamic>> objectives, {_Service? service}) async {
      final s = await _pump(t, service: service, pageFor: pageOf(objectives));
      await _startCloseOut(t, 'd1');
      return s;
    }

    Finder pick(String id, String label) => find.descendant(of: _k('mo_co_result_$id'), matching: find.text(label));
    Set<ObjectiveResult> chosen(WidgetTester t, String id) => t.widget<SegmentedButton<ObjectiveResult>>(_k('mo_co_result_$id')).selected;

    testWidgets('100% but called Missed (it was late): it says why, and cannot be sent without a note', (tester) async {
      final s = await closeOut(tester, [_obj('a', 'Hire two', progress: 100, canManage: true, krs: [_kr('k', 'Offers', 10, 10, done: true)])]);
      await tester.tap(pick('a', 'Missed'));
      await tester.pumpAndSettle();
      expect(find.text('Progress is 100%, which points to Achieved. Say why it ended as Missed.'), findsOneWidget);
      await _tap(tester, _k('mo_co_confirm'));
      expect(find.textContaining('Add a note for “Hire two”'), findsOneWidget);
      expect(s.calls, isEmpty);
      await tester.enterText(_k('mo_co_note_a'), 'Joined after the deadline');
      await _tap(tester, _k('mo_co_confirm'));
      expect(s.calls.single.args, {'id': 'a', 'result': 'missed', 'note': 'Joined after the deadline'});
    });

    testWidgets('…and the other way: 40% called Achieved because the scope was cut', (tester) async {
      final s = await closeOut(tester, [_obj('a', 'Train staff', progress: 40, canManage: true, krs: [_kr('k', 'Sessions', 10, 4)])]);
      expect(chosen(tester, 'a'), {ObjectiveResult.missed}); // what 40% points to
      await tester.tap(pick('a', 'Achieved'));
      await tester.pumpAndSettle();
      expect(_k('mo_co_why_a'), findsOneWidget);
      await tester.enterText(_k('mo_co_note_a'), 'Two venues were enough');
      await _tap(tester, _k('mo_co_confirm'));
      expect(s.calls.single.args, {'id': 'a', 'result': 'achieved', 'note': 'Two venues were enough'});
    });

    testWidgets('a note of a letter is not a reason', (tester) async {
      final s = await closeOut(tester, [_obj('a', 'Train staff', progress: 40, canManage: true, krs: [_kr('k', 'Sessions', 10, 4)])]);
      await tester.tap(pick('a', 'Achieved'));
      await tester.pumpAndSettle();
      await tester.enterText(_k('mo_co_note_a'), 'x');
      await _tap(tester, _k('mo_co_confirm'));
      expect(find.textContaining('Add a note for'), findsOneWidget);
      expect(s.calls, isEmpty);
    });

    testWidgets('the result its progress points to needs no note and is not asked for one', (tester) async {
      final s = await closeOut(tester, [_obj('a', 'Open a desk', progress: 60, canManage: true, krs: [_kr('k', 'Visits', 10, 6)])]);
      expect(_k('mo_co_why_a'), findsNothing);
      await _tap(tester, _k('mo_co_confirm'));
      expect(s.calls.first.args, {'id': 'a', 'result': 'partly', 'note': ''});
    });

    testWidgets('choosing the suggested one again takes the question away', (tester) async {
      await closeOut(tester, [_obj('a', 'Open a desk', progress: 60, canManage: true, krs: [_kr('k', 'Visits', 10, 6)])]);
      await tester.tap(pick('a', 'Missed'));
      await tester.pumpAndSettle();
      expect(_k('mo_co_why_a'), findsOneWidget);
      await tester.tap(pick('a', 'Partly'));
      await tester.pumpAndSettle();
      expect(_k('mo_co_why_a'), findsNothing);
    });

    testWidgets('an objective with no key results has nothing to measure it by: no suggestion, the choice starts empty, any result is fine', (tester) async {
      final s = await closeOut(tester, [_obj('a', 'Culture', canManage: true)]);
      expect(chosen(tester, 'a'), isEmpty);
      await _tap(tester, _k('mo_co_confirm'));
      expect(find.text('Choose how “Culture” ended.'), findsOneWidget);
      expect(s.calls, isEmpty);
      await tester.tap(pick('a', 'Achieved'));
      await tester.pumpAndSettle();
      expect(_k('mo_co_why_a'), findsNothing);
      await _tap(tester, _k('mo_co_confirm'));
      expect(s.calls.first.args, {'id': 'a', 'result': 'achieved', 'note': ''});
    });

    testWidgets('an objective that was ended with a different result shows what the progress had been', (tester) async {
      await _pump(tester, pageFor: pageOf([
        _obj('a', 'Train staff', progress: 40, result: 'achieved', overridden: true, progressAtClose: 40, note: 'Two venues were enough', canManage: true, krs: [_kr('k', 'Sessions', 10, 4)]),
        _obj('b', 'Open a desk', progress: 60, result: 'partly', progressAtClose: 60, krs: [_kr('k', 'Visits', 10, 6)]),
      ]));
      await _open(tester, 'a');
      await _open(tester, 'b');
      expect(find.text('Progress was 40% — it ended achieved.'), findsOneWidget);
      expect(_k('mo_overridden_b'), findsNothing);
    });
  });

  group('a plan that changes: continues, postponed, cancelled', () {
    final running = {'number': 1, 'total': 3, 'final': false, 'overran': false};
    final last = {'number': 3, 'total': 3, 'final': true, 'overran': false};

    Future<_Service> closeOut(WidgetTester t, List<Map<String, dynamic>> objectives, {_Service? service}) async {
      final s = await _pump(t, service: service, pageFor: pageOf(objectives));
      await _startCloseOut(t, 'd1');
      return s;
    }

    Finder pick(String id, String label) => find.descendant(of: _k('mo_co_result_$id'), matching: find.text(label));
    Set<ObjectiveResult> chosen(WidgetTester t, String id) => t.widget<SegmentedButton<ObjectiveResult>>(_k('mo_co_result_$id')).selected;

    testWidgets('a month that is not the last of a run simply continues: nothing to score, no note, and its total is carried on', (tester) async {
      final s = await closeOut(tester, [_obj('r', 'Marketing automation', progress: 30, span: running, canManage: true, krs: [_kr('k', 'Leads', 40, 12)])]);
      expect(chosen(tester, 'r'), {ObjectiveResult.continued});
      expect(pick('r', 'Partly'), findsNothing); // continues / achieved (done early) / missed (given up)
      expect(pick('r', 'Continues'), findsOneWidget);
      expect(_k('mo_co_why_r'), findsNothing);
      expect(find.text('Continue into ${monthTitle(nextMonthOf(_thisMonth))} — keeps what has been done'), findsOneWidget);
      await _tap(tester, _k('mo_co_confirm'));
      expect([for (final c in s.calls) c.name], ['close', 'carryOver']);
      expect(s.calls[0].args, {'id': 'r', 'result': 'continued', 'note': ''});
      expect(s.calls[1].args['ids'], ['r']);
    });

    testWidgets('giving up on a run part-way (Missed, at 30%) is ending it differently from what continuing says: it asks why', (tester) async {
      await closeOut(tester, [_obj('r', 'Marketing automation', progress: 30, span: running, canManage: true, krs: [_kr('k', 'Leads', 40, 12)])]);
      await tester.tap(pick('r', 'Missed'));
      await tester.pumpAndSettle();
      expect(_k('mo_co_why_r'), findsOneWidget);
    });

    testWidgets('the last month of a run is scored like any other: Partly is there, Continues is not', (tester) async {
      await closeOut(tester, [_obj('f', 'Marketing automation', progress: 70, span: last, canManage: true, krs: [_kr('k', 'Leads', 40, 28)])]);
      expect(pick('f', 'Continues'), findsNothing);
      expect(pick('f', 'Partly'), findsOneWidget);
      expect(chosen(tester, 'f'), {ObjectiveResult.partly});
    });

    testWidgets('closed already: cancelled is not carried; postponed is offered if it has not been moved yet', (tester) async {
      final next = monthTitle(nextMonthOf(_thisMonth));
      await closeOut(tester, [
        _obj('x', 'Dropped', progress: 10, result: 'cancelled', note: 'No budget', canManage: true, krs: [_kr('k', 'K', 10, 1)]),
        _obj('y', 'Later', progress: 0, result: 'deferred', note: 'New office', canManage: true, krs: [_kr('k', 'K', 10, 0)]),
        _obj('z', 'Moved already', progress: 0, result: 'deferred', carriedTo: true, canManage: true, krs: [_kr('k', 'K', 10, 0)]),
      ]);
      expect(find.text('Cancelled — not carried'), findsOneWidget);
      expect(_k('mo_co_carry_x'), findsNothing);
      expect(find.text('Postponed — not moved into $next yet'), findsOneWidget);
      expect(_k('mo_co_carry_y'), findsOneWidget);
      expect(find.text('Postponed — already in $next'), findsOneWidget);
      expect(_k('mo_co_carry_z'), findsNothing);
    });
  });

  group('cancelling and postponing from the objective', () {
    Future<void> menu(WidgetTester t, String id, String item) async {
      await _tap(t, _k('mo_menu_$id'));
      await t.tap(find.text(item));
      await t.pumpAndSettle();
    }

    testWidgets('an open objective can be postponed or cancelled; a closed one can only be reopened', (tester) async {
      await _pump(tester);
      await _tap(tester, _k('mo_menu_o1'));
      expect(find.text('Postpone to next month'), findsOneWidget);
      expect(find.text('Cancel objective'), findsOneWidget);
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      await _tap(tester, _k('mo_menu_o2'));
      expect(find.text('Postpone to next month'), findsNothing);
      expect(find.text('Cancel objective'), findsNothing);
      expect(find.text('Reopen'), findsOneWidget);
    });

    testWidgets('cancelling asks why; the button waits for a reason, and "Not now" does nothing', (tester) async {
      final s = await _pump(tester);
      await menu(tester, 'o1', 'Cancel objective');
      expect(find.text('Cancel “Ship the booking app”?'), findsOneWidget);
      expect(tester.widget<FilledButton>(_k('mo_reason_confirm')).onPressed, isNull);
      await tester.enterText(_k('mo_reason_text'), 'no');
      await tester.pump();
      expect(tester.widget<FilledButton>(_k('mo_reason_confirm')).onPressed, isNull);
      await _tap(tester, _k('mo_reason_cancel'));
      expect(s.calls, isEmpty);
    });

    testWidgets('cancelling with a reason closes it as cancelled, and says so', (tester) async {
      final s = await _pump(tester);
      await menu(tester, 'o1', 'Cancel objective');
      await tester.enterText(_k('mo_reason_text'), 'The supplier pulled out');
      await tester.pump();
      await _tap(tester, _k('mo_reason_confirm'));
      expect(s.calls.single.name, 'close');
      expect(s.calls.single.args, {'id': 'o1', 'result': 'cancelled', 'note': 'The supplier pulled out'});
      expect(find.text('Objective cancelled'), findsOneWidget);
    });

    testWidgets('postponing closes it as postponed and moves it into next month, with the reason', (tester) async {
      final s = await _pump(tester);
      await menu(tester, 'o1', 'Postpone to next month');
      expect(find.textContaining(monthTitle(nextMonthOf(_thisMonth))), findsWidgets);
      await tester.enterText(_k('mo_reason_text'), 'Waiting on the new office');
      await tester.pump();
      await _tap(tester, _k('mo_reason_confirm'));
      expect([for (final c in s.calls) c.name], ['close', 'carryOver']);
      expect(s.calls[0].args, {'id': 'o1', 'result': 'deferred', 'note': 'Waiting on the new office'});
      expect(s.calls[1].args['ids'], ['o1']);
      expect(s.calls[1].args['month'], _thisMonth);
      expect(find.text('Postponed to ${monthTitle(nextMonthOf(_thisMonth))}'), findsOneWidget);
    });

    testWidgets('if it is postponed but cannot be moved, it says so and where to finish the job', (tester) async {
      final s = _Service()..failWith = Exception('lost connection')..failAfter = 2;
      await _pump(tester, service: s);
      await menu(tester, 'o1', 'Postpone to next month');
      await tester.enterText(_k('mo_reason_text'), 'Waiting on the new office');
      await tester.pump();
      await _tap(tester, _k('mo_reason_confirm'));
      expect(find.textContaining('Postponed, but not moved into'), findsOneWidget);
      expect(find.textContaining('Close out month'), findsWidgets);
    });

    testWidgets('if it cannot even be closed, nothing is moved', (tester) async {
      final s = _Service()..failWith = Exception('no');
      await _pump(tester, service: s);
      await menu(tester, 'o1', 'Postpone to next month');
      await tester.enterText(_k('mo_reason_text'), 'Waiting on the new office');
      await tester.pump();
      await _tap(tester, _k('mo_reason_confirm'));
      expect([for (final c in s.calls) c.name], ['close']);
      expect(find.text('Postponed to ${monthTitle(nextMonthOf(_thisMonth))}'), findsNothing);
    });
  });

  group('how the month reads with them in it', () {
    testWidgets('what continues, was postponed, cancelled or ended short is told on the objective itself, and in the headline', (tester) async {
      await _pump(tester, pageFor: pageOf([
            _obj('a', 'A', result: 'continued'),
            _obj('b', 'B', result: 'deferred'),
            _obj('c', 'C', result: 'cancelled'),
            _obj('d', 'D', progress: 50, result: 'partly'),
          ]));
      expect(find.descendant(of: _k('mo_status_a'), matching: find.text('In progress')), findsOneWidget);
      expect(find.descendant(of: _k('mo_status_b'), matching: find.text('Postponed')), findsOneWidget);
      expect(find.descendant(of: _k('mo_status_c'), matching: find.text('Cancelled')), findsOneWidget);
      expect(find.descendant(of: _k('mo_status_d'), matching: find.text('Partly done')), findsOneWidget);
      expect(_text(tester, 'mo_kpi_other'), 'Also this month: 1 ended short · 2 cancelled or postponed');
      // cancelled and postponed stay out of the average: (0 + 50) / 2
      expect(_text(tester, 'mo_kpi_overall_value'), '25%');
    });

    testWidgets('last month\'s line includes them too — and reads as it always did when there are none', (tester) async {
      await _pump(tester, pageFor: (k) => _page(departments: [
            _dept('d1', 'IT', head: 'I', objectives: [_obj('o1', 'x')], last: _summary(count: 6, achieved: 1, partly: 1, missed: 1, continued: 1, deferred: 1, cancelled: 1)),
          ]));
      expect(_text(tester, 'mo_dept_last_d1'), 'Last month: 1 achieved · 1 partly · 1 missed · 1 continuing · 1 postponed · 1 cancelled');
    });

    testWidgets('a closed objective wears its result: Continues, Postponed, Cancelled', (tester) async {
      await _pump(tester, pageFor: pageOf([_obj('a', 'A', result: 'continued'), _obj('b', 'B', result: 'deferred'), _obj('c', 'C', result: 'cancelled')]));
      for (final id in ['a', 'b', 'c']) {
        await _open(tester, id);
      }
      expect(find.descendant(of: _k('mo_result_a'), matching: find.text('Continues')), findsOneWidget);
      expect(find.descendant(of: _k('mo_result_b'), matching: find.text('Postponed')), findsOneWidget);
      expect(find.descendant(of: _k('mo_result_c'), matching: find.text('Cancelled')), findsOneWidget);
    });
  });

  // ── the team sees its own month, and what is assigned to them ─────────────────
  group('your department, and what is assigned to you', () {
    final given = _obj('g1', 'Fleet audit for IT', dept: 'd9', deptName: 'Fleet', progress: 40, canCheckIn: true, assignedToMe: true, krs: [_kr('a', 'Vehicles checked', 10, 4, unit: 'vehicles'), _kr('b', 'Report filed', 1, 0, kind: 'yesno')]);

    testWidgets('with nothing assigned, there is no such section', (tester) async {
      await _pump(tester);
      expect(_k('mo_assigned'), findsNothing);
    });

    testWidgets('what is assigned comes first — from any department, even one that is not on the page — with its key results', (tester) async {
      await _pump(tester, pageFor: (k) => _page(assigned: [given]));
      expect(_k('mo_assigned'), findsOneWidget);
      expect(find.text('Assigned to you'), findsOneWidget);
      expect(_text(tester, 'mo_assigned_count'), '1');
      final row = find.descendant(of: _k('mo_assigned_g1'), matching: find.byType(Text));
      final texts = [for (final w in tester.widgetList<Text>(row)) w.data ?? w.textSpan?.toPlainText() ?? ''];
      expect(texts, containsAll(['Fleet', 'Fleet audit for IT', '40%']));
      expect(texts.any((t) => t.contains('Vehicles checked') && t.contains('4 / 10 vehicles')), isTrue);
      expect(texts.any((t) => t.contains('Report filed') && t.contains('Not yet')), isTrue);
      // …and above the departments
      expect(tester.getRect(_k('mo_assigned')).bottom, lessThan(tester.getRect(_k('mo_summary')).top));
    });

    testWidgets('each open key result can be reported on from there', (tester) async {
      final s = await _pump(tester, pageFor: (k) => _page(assigned: [given]));
      await _tap(tester, _k('mo_assigned_checkin_g1_a'));
      await tester.enterText(_k('mo_ci_value'), '7');
      await _tap(tester, _k('mo_ci_save'));
      expect(s.calls.single.args, {'objective': 'g1', 'kr': 'a', 'value': 7.0, 'completed': null});
      expect(find.text('Progress saved'), findsOneWidget);
    });

    testWidgets('a yes / no is ticked from there too', (tester) async {
      final s = await _pump(tester, pageFor: (k) => _page(assigned: [given]));
      await _tap(tester, _k('mo_assigned_checkin_g1_b'));
      expect(_k('mo_ci_value'), findsNothing);
      await _tap(tester, _k('mo_ci_done'));
      await _tap(tester, _k('mo_ci_save'));
      expect(s.calls.single.args, {'objective': 'g1', 'kr': 'b', 'value': null, 'completed': true});
    });

    testWidgets('a closed one shows how it ended and cannot be reported on', (tester) async {
      await _pump(tester, pageFor: (k) => _page(assigned: [
            _obj('g2', 'Finished', dept: 'd9', deptName: 'Fleet', progress: 100, result: 'achieved', canCheckIn: true, assignedToMe: true, krs: [_kr('a', 'Done', 1, 1, done: true)]),
          ]));
      expect(find.descendant(of: _k('mo_assigned_g2'), matching: find.text('Achieved')), findsOneWidget);
      expect(find.byWidgetPredicate((w) => w.key.toString().contains('mo_assigned_checkin_g2')), findsNothing);
    });

    testWidgets('a view-only login that has something assigned sees it but cannot report on it', (tester) async {
      await _pump(tester, pageFor: (k) => _page(assigned: [
            _obj('g4', 'Board pack', dept: 'd9', deptName: 'Fleet', assignedToMe: true, krs: [_kr('a', 'Pages', 10, 2)]), // canCheckIn: false
          ]));
      expect(find.descendant(of: _k('mo_assigned_g4'), matching: find.text('Board pack')), findsOneWidget);
      expect(_k('mo_assigned_checkin_g4_a'), findsNothing);
    });

    testWidgets('someone who only has things assigned (no department to see) gets them, not a "nothing to show" message', (tester) async {
      await _pump(tester, pageFor: (k) => _page(departments: const [], assigned: [given]));
      expect(_k('mo_assigned'), findsOneWidget);
      expect(_k('mo_no_departments'), findsNothing);
      expect(_k('mo_summary'), findsNothing); // no departments, no company summary
    });

    testWidgets('someone with neither is still told there is nothing to show', (tester) async {
      await _pump(tester, pageFor: (k) => _page(departments: const []));
      expect(_k('mo_no_departments'), findsOneWidget);
      expect(_k('mo_assigned'), findsNothing);
    });

    testWidgets('an objective with no key results says so', (tester) async {
      await _pump(tester, pageFor: (k) => _page(assigned: [_obj('g3', 'Culture', dept: 'd9', deptName: 'Fleet', assignedToMe: true, canCheckIn: true)]));
      expect(find.descendant(of: _k('mo_assigned_g3'), matching: find.text('No key results yet.')), findsOneWidget);
    });

    testWidgets('your own department is tagged; the others are not', (tester) async {
      await _pump(tester, pageFor: (k) => _page(departments: [
            _dept('d1', 'IT', head: 'Ishaan', member: true, objectives: [_obj('o1', 'x')]),
            _dept('d2', 'HR', head: 'Hana', objectives: [_obj('o2', 'y', dept: 'd2', deptName: 'HR')]),
          ]));
      expect(find.descendant(of: _k('mo_dept_d1'), matching: find.text('Your department')), findsOneWidget);
      expect(_k('mo_mine_d1'), findsOneWidget);
      expect(_k('mo_mine_d2'), findsNothing);
    });

    testWidgets('in your department an objective given to you says "You"; one given to a colleague names them', (tester) async {
      await _pump(tester, pageFor: (k) => _page(departments: [
            _dept('d1', 'IT', head: 'Ishaan', member: true, objectives: [
              _obj('o1', 'Mine', owner: 'Irfan', assignedToMe: true, canCheckIn: true),
              _obj('o2', 'Theirs', owner: 'Imran'),
            ]),
          ]));
      expect(find.descendant(of: _k('mo_obj_o1'), matching: find.text('You')), findsOneWidget);
      expect(find.text('Irfan'), findsNothing); // you do not see your own name
      expect(find.text('Imran'), findsOneWidget);
      expect(find.descendant(of: _k('mo_obj_o2'), matching: find.text('You')), findsNothing);
    });
  });

  // ── when the key results are done ─────────────────────────────────────────────
  group('when every key result is done', () {
    final allDone = [_kr('k', 'Screens', 40, 40, done: true), _kr('k2', 'Bugs', 10, 10)];

    testWidgets('the objective says so, and its head can close it as achieved with one tap — from the list, no need to open it', (tester) async {
      final s = await _pump(tester, pageFor: pageOf([_obj('o1', 'Ship the app', progress: 100, readyToClose: true, canManage: true, krs: allDone)]));
      expect(_text(tester, 'mo_ready_o1'), 'Every key result is done');
      await _tap(tester, _k('mo_close_achieved_o1'));
      expect(s.calls.single.name, 'close');
      expect(s.calls.single.args, {'id': 'o1', 'result': 'achieved', 'note': ''});
      expect(find.text('Closed as achieved'), findsOneWidget);
    });

    testWidgets('someone who may not close it sees that it is finished, but is not offered the button', (tester) async {
      await _pump(tester, pageFor: pageOf([_obj('o1', 'Ship the app', progress: 100, readyToClose: true, canCheckIn: true, krs: allDone)]));
      expect(_k('mo_ready_o1'), findsOneWidget);
      expect(_k('mo_close_achieved_o1'), findsNothing);
    });

    testWidgets('an objective that is not ready (key results open, already closed, or a run with months to go) shows nothing of the kind', (tester) async {
      await _pump(tester, pageFor: pageOf([
        _obj('a', 'Still open', progress: 50, canManage: true, krs: [_kr('k', 'K', 10, 5)]),
        _obj('b', 'Already closed', progress: 100, result: 'achieved', canManage: true, krs: [_kr('k', 'K', 10, 10, done: true)]),
        _obj('c', 'A long one', progress: 100, canManage: true, span: {'number': 1, 'total': 3, 'final': false, 'overran': false}, krs: [_kr('k', 'K', 10, 10, done: true)]),
      ]));
      for (final id in ['a', 'b', 'c']) {
        expect(_k('mo_ready_$id'), findsNothing, reason: id);
        expect(_k('mo_close_achieved_$id'), findsNothing, reason: id);
      }
    });

    testWidgets('if it cannot be closed, it says so and nothing else changes', (tester) async {
      final s = _Service()..failWith = Exception('closed by someone else');
      await _pump(tester, service: s, pageFor: pageOf([_obj('o1', 'Ship the app', progress: 100, readyToClose: true, canManage: true, krs: allDone)]));
      await _tap(tester, _k('mo_close_achieved_o1'));
      expect(find.text('Closed as achieved'), findsNothing);
      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('on a phone the line and the button fit', (tester) async {
      await _pump(tester, size: const Size(360, 900), pageFor: pageOf([_obj('o1', 'Ship the booking app for the whole team', progress: 100, readyToClose: true, canManage: true, krs: allDone)]));
      expect(tester.takeException(), isNull);
      expect(_k('mo_close_achieved_o1'), findsOneWidget);
    });

    testWidgets('a key result that is done says who finished it and when; an open one, or one that reached its target by itself, says nothing', (tester) async {
      await _pump(tester, pageFor: pageOf([
        _obj('o1', 'Ship the app', krs: [
          _kr('a', 'Screens', 40, 40, done: true, doneAt: '2026-11-04T10:00:00.000Z', doneBy: 'Irfan'),
          _kr('b', 'Bugs', 10, 3),
          _kr('c', 'Reviews', 5, 5, done: true), // no stamp
          _kr('d', 'Anonymous', 5, 5, done: true, doneAt: '2026-11-05T10:00:00.000Z'),
        ]),
      ]));
      await _open(tester, 'o1');
      expect(_text(tester, 'mo_kr_done_a'), 'Done 4 Nov · Irfan');
      expect(_k('mo_kr_done_b'), findsNothing);
      expect(_k('mo_kr_done_c'), findsNothing);
      expect(_text(tester, 'mo_kr_done_d'), 'Done 5 Nov');
    });
  });

  // ── the page as redesigned: header, month bar, tabs, cards, table ─────────────
  group('the page', () {
    final prevName = kMonthNames[prevMonthOf(_thisMonth).month - 1];
    int y(WidgetTester t, String key) => t.getTopLeft(_k(key)).dy.round();

    group('the month bar', () {
      testWidgets('the page has a title, and the month says which days it covers', (tester) async {
        await _pump(tester);
        expect(find.text('Monthly Objectives'), findsOneWidget);
        expect(_text(tester, 'mo_range'), '01 ${_monthName.substring(0, 3)} ${_now.year} – ${DateTime(_now.year, _now.month + 1, 0).day} ${_monthName.substring(0, 3)} ${_now.year} (${DateTime(_now.year, _now.month + 1, 0).day} days)');
      });

      testWidgets('stepping to another month changes the days, too', (tester) async {
        await _pump(tester);
        final before = _text(tester, 'mo_range');
        await _tap(tester, _k('mo_next'));
        expect(_text(tester, 'mo_range'), isNot(before));
        expect(_text(tester, 'mo_range'), contains(kMonthNames[nextMonthOf(_thisMonth).month - 1].substring(0, 3)));
      });

      testWidgets('the department filter lists every department, and "All Departments" is what it starts as', (tester) async {
        await _pump(tester);
        expect(_text(tester, 'mo_dept_filter_label'), 'All Departments');
        await _tap(tester, _k('mo_dept_filter'));
        for (final k in ['mo_dept_filter_all', 'mo_dept_filter_d1', 'mo_dept_filter_d2', 'mo_dept_filter_d3']) {
          expect(_k(k), findsOneWidget, reason: k);
        }
      });

      testWidgets('with a single department there is nothing to filter, so no filter', (tester) async {
        await _pump(tester, pageFor: (k) => _page(departments: [_dept('d1', 'IT', member: true, objectives: [_obj('o1', 'x')])]));
        expect(_k('mo_dept_filter'), findsNothing);
      });

      testWidgets('choosing a department narrows the headline, the cards, the table and the trend to it; "All Departments" brings the rest back', (tester) async {
        await _pump(tester);
        await _tap(tester, _k('mo_dept_filter'));
        await _tap(tester, _k('mo_dept_filter_d1'));
        expect(_text(tester, 'mo_dept_filter_label'), 'IT');
        expect(_text(tester, 'mo_kpi_total_value'), '2'); // IT's two
        expect(_text(tester, 'mo_kpi_overall_value'), '75%');
        expect(_k('mo_obj_o1'), findsOneWidget);
        expect(_k('mo_obj_o3'), findsNothing); // HR's
        expect(find.descendant(of: _k('mo_dept_d1'), matching: find.byType(Container)), findsWidgets);
        expect(find.text('IT'), findsWidgets);
        await _tap(tester, _k('mo_dept_filter'));
        await _tap(tester, _k('mo_dept_filter_all'));
        expect(_text(tester, 'mo_kpi_total_value'), '3');
        expect(_k('mo_obj_o3'), findsOneWidget);
      });

      testWidgets('tapping a department\'s card narrows the page to it; tapping it again shows everyone', (tester) async {
        await _pump(tester);
        await _tap(tester, _k('mo_dept_open_d2'));
        expect(_text(tester, 'mo_kpi_total_value'), '1');
        expect(_text(tester, 'mo_dept_filter_label'), 'HR');
        expect(_k('mo_obj_o3'), findsOneWidget);
        expect(_k('mo_obj_o1'), findsNothing);
        await _tap(tester, _k('mo_dept_open_d2'));
        expect(_text(tester, 'mo_kpi_total_value'), '3');
        expect(_text(tester, 'mo_dept_filter_label'), 'All Departments');
      });

      testWidgets('when the page is narrowed to a department they run, "Set Objective" is for that one — no question asked', (tester) async {
        await _pump(tester); // they run IT and Artist
        await _tap(tester, _k('mo_dept_filter'));
        await _tap(tester, _k('mo_dept_filter_d1'));
        await _tap(tester, _k('mo_set'));
        expect(_k('mo_pick_dialog'), findsNothing);
        expect(_k('mo_form_title'), findsOneWidget);
      });

      testWidgets('a department that is not in the month asked for is forgotten, not an empty page', (tester) async {
        await _pump(tester, pageFor: (k) => k == _thisMonth ? _page() : _page(departments: [_dept('d1', 'IT', objectives: [_obj('o1', 'x')])]));
        await _tap(tester, _k('mo_dept_open_d2'));
        expect(_text(tester, 'mo_kpi_total_value'), '1');
        await _tap(tester, _k('mo_next'));
        expect(_text(tester, 'mo_kpi_total_value'), '1'); // everything there is: IT's one
        expect(_k('mo_obj_o1'), findsOneWidget);
      });
    });

    group('the headline numbers', () {
      testWidgets('more objectives than last month, or fewer, or the same', (tester) async {
        final prev = prevName.substring(0, 3);
        await _pump(tester, pageFor: (k) => _page(departments: [_dept('d1', 'IT', objectives: [_obj('a', 'A'), _obj('b', 'B'), _obj('c', 'C')], last: _summary(count: 2))]));
        expect(_text(tester, 'mo_kpi_total_chip'), '+1 vs $prev (2)');
        await _pump(tester, pageFor: (k) => _page(departments: [_dept('d1', 'IT', objectives: [_obj('a', 'A')], last: _summary(count: 4))]));
        expect(_text(tester, 'mo_kpi_total_chip'), '-3 vs $prev (4)');
      });

      testWidgets('a month with nothing set is zeros — and no division by zero', (tester) async {
        await _pump(tester, pageFor: (k) => _page(departments: [_dept('d1', 'IT', canManage: true)]));
        expect(tester.takeException(), isNull);
        expect(_text(tester, 'mo_kpi_total_value'), '0');
        expect(_text(tester, 'mo_kpi_completed_caption'), '0% of total');
        expect(_text(tester, 'mo_kpi_overall_value'), '0%');
        expect(_k('mo_kpi_other'), findsNothing);
      });

      testWidgets('not started counts what has no progress yet', (tester) async {
        await _pump(tester, pageFor: pageOf([_obj('a', 'A'), _obj('b', 'B', progress: 10), _obj('c', 'C', progress: 100)]));
        expect(_text(tester, 'mo_kpi_notstarted_value'), '1');
        expect(_text(tester, 'mo_kpi_progress_value'), '1');
        expect(_text(tester, 'mo_kpi_completed_value'), '1');
      });
    });

    group('the tabs', () {
      testWidgets('four of them, opening on the department overview', (tester) async {
        await _pump(tester);
        for (final t in ['Department Overview', 'Objective List', 'Progress Matrix', 'Key Results']) {
          expect(find.text(t), findsOneWidget, reason: t);
        }
        expect(_k('mo_dept_d1'), findsOneWidget);
        expect(_k('mo_trend_chart'), findsOneWidget);
        expect(_k('mo_table'), findsOneWidget);
      });

      testWidgets('the overview has the cards, the charts and the table in that order', (tester) async {
        await _pump(tester);
        expect(y(tester, 'mo_dept_d1'), lessThan(y(tester, 'mo_target_card')));
        expect(y(tester, 'mo_target_card'), lessThan(y(tester, 'mo_table')));
      });

      testWidgets('the objective list is the table alone', (tester) async {
        await _pump(tester);
        await _tap(tester, _k('mo_tab_list'));
        expect(_k('mo_table'), findsOneWidget);
        expect(_k('mo_dept_d1'), findsNothing);
        expect(_k('mo_trend_chart'), findsNothing);
        expect(_k('mo_matrix'), findsNothing);
      });

      testWidgets('the progress matrix and the key results each have a tab of their own, and "Department Overview" brings the first back', (tester) async {
        await _pump(tester);
        await _tap(tester, _k('mo_tab_matrix'));
        expect(_k('mo_matrix'), findsOneWidget);
        expect(_k('mo_table'), findsNothing);
        await _tap(tester, _k('mo_tab_krs'));
        expect(_k('mo_kr_panel'), findsOneWidget);
        expect(_k('mo_matrix'), findsNothing);
        await _tap(tester, _k('mo_tab_overview'));
        expect(_k('mo_dept_d1'), findsOneWidget);
        expect(_k('mo_kr_panel'), findsNothing);
      });

      testWidgets('the headline stays above whichever tab is open', (tester) async {
        await _pump(tester);
        for (final t in ['mo_tab_list', 'mo_tab_matrix', 'mo_tab_krs']) {
          await _tap(tester, _k(t));
          expect(_k('mo_summary'), findsOneWidget, reason: t);
        }
      });
    });

    group('the table', () {
      testWidgets('a row: title, department, owner, priority, progress, status', (tester) async {
        await _pump(tester);
        for (final h in ['Objective', 'Department', 'Owner', 'Priority', 'Progress', 'Status']) {
          expect(find.text(h), findsWidgets, reason: h);
        }
        final row = _k('mo_obj_o1');
        expect(find.descendant(of: row, matching: find.text('Ship the booking app')), findsOneWidget);
        expect(find.descendant(of: row, matching: find.text('IT')), findsOneWidget);
        expect(find.descendant(of: row, matching: find.text('Irfan')), findsOneWidget);
        expect(find.descendant(of: row, matching: find.text('IR')), findsOneWidget); // initials
        expect(find.descendant(of: row, matching: find.text('Medium')), findsOneWidget);
        expect(_text(tester, 'mo_progress_o1'), '50%');
        expect(find.descendant(of: _k('mo_status_o1'), matching: find.text('In progress')), findsOneWidget);
      });

      testWidgets('the priorities read as Critical / High / Medium / Low', (tester) async {
        await _pump(tester, pageFor: pageOf([_obj('a', 'A', priority: 'critical'), _obj('b', 'B', priority: 'high'), _obj('c', 'C'), _obj('d', 'D', priority: 'low')]));
        for (final p in ['Critical', 'High', 'Medium', 'Low']) {
          expect(find.text(p), findsOneWidget, reason: p);
        }
      });

      testWidgets('an objective with no owner says so with a dash', (tester) async {
        await _pump(tester, pageFor: pageOf([_obj('a', 'A')]));
        expect(find.descendant(of: _k('mo_obj_a'), matching: find.text('—')), findsOneWidget);
      });

      testWidgets('the title says which month, and a month with nothing in it says so — and how to set one, for those who may', (tester) async {
        await _pump(tester, pageFor: (k) => _page(departments: [_dept('d1', 'IT', head: 'I', canManage: true)]));
        expect(_text(tester, 'mo_table_title'), 'Objectives – ${monthTitle(_thisMonth)}');
        expect(find.text('No objectives set for $_monthName.'), findsOneWidget);
        expect(find.textContaining('Use “Set Objective”'), findsOneWidget);
      });

      testWidgets('…and for someone who may not, who sets them', (tester) async {
        await _pump(tester, pageFor: (k) => _page(departments: [_dept('d1', 'IT', head: 'I', member: true)]));
        expect(find.textContaining('Its department\'s head sets them'), findsOneWidget);
      });

      testWidgets('searching finds an objective by its title, its owner or its department — and says when nothing matches', (tester) async {
        await _pump(tester);
        await tester.enterText(_k('mo_search'), 'booking');
        await tester.pumpAndSettle();
        expect(_k('mo_obj_o1'), findsOneWidget);
        expect(_k('mo_obj_o2'), findsNothing);
        expect(_k('mo_obj_o3'), findsNothing);
        await tester.enterText(_k('mo_search'), 'hana'); // not an owner here, and not a title
        await tester.pumpAndSettle();
        expect(_k('mo_table_empty'), findsOneWidget);
        expect(find.text('No objectives match.'), findsOneWidget);
        await tester.enterText(_k('mo_search'), 'HR');
        await tester.pumpAndSettle();
        expect(_k('mo_obj_o3'), findsOneWidget);
      });

      testWidgets('"Clear search and filters" brings everything back', (tester) async {
        await _pump(tester);
        await tester.enterText(_k('mo_search'), 'zzz');
        await tester.pumpAndSettle();
        await _tap(tester, _k('mo_clear_filters'));
        expect(_k('mo_obj_o1'), findsOneWidget);
        expect(_k('mo_obj_o3'), findsOneWidget);
      });

      testWidgets('"Clear search and filters" keeps the page on the department it was narrowed to', (tester) async {
        await _pump(tester);
        await _tap(tester, _k('mo_dept_open_d2')); // HR
        await tester.enterText(_k('mo_search'), 'zzz');
        await tester.pumpAndSettle();
        await _tap(tester, _k('mo_clear_filters'));
        expect(_k('mo_obj_o3'), findsOneWidget);
        expect(_k('mo_obj_o1'), findsNothing);
        expect(_text(tester, 'mo_dept_filter_label'), 'HR');
      });

      testWidgets('Reset in the filters clears "only what is given to me" as well', (tester) async {
        await _pump(tester, pageFor: pageOf([_obj('a', 'A'), _obj('d', 'D', assignedToMe: true)]));
        await _tap(tester, _k('mo_filters'));
        await _tap(tester, _k('mo_f_mine'));
        await _tap(tester, _k('mo_f_apply'));
        expect(_k('mo_obj_a'), findsNothing);
        await _tap(tester, _k('mo_filters'));
        await _tap(tester, _k('mo_f_reset'));
        await _tap(tester, _k('mo_f_apply'));
        expect(_k('mo_obj_a'), findsOneWidget);
        expect(_text(tester, 'mo_filters_label'), 'Filters');
      });

      testWidgets('the Filters button narrows by status, by priority, or to what is given to you — and counts what is on', (tester) async {
        await _pump(tester, pageFor: pageOf([_obj('a', 'A'), _obj('b', 'B', progress: 40), _obj('c', 'C', progress: 100, priority: 'high'), _obj('d', 'D', progress: 10, assignedToMe: true)]));
        expect(_text(tester, 'mo_filters_label'), 'Filters');
        await _tap(tester, _k('mo_filters'));
        await _tap(tester, _k('mo_f_status_completed'));
        await _tap(tester, _k('mo_f_apply'));
        expect(_k('mo_obj_c'), findsOneWidget);
        expect(_k('mo_obj_a'), findsNothing);
        expect(_text(tester, 'mo_filters_label'), 'Filters · 1');

        await _tap(tester, _k('mo_filters'));
        await _tap(tester, _k('mo_f_reset'));
        await _tap(tester, _k('mo_f_prio_high'));
        await _tap(tester, _k('mo_f_apply'));
        expect([_k('mo_obj_c').evaluate().length, _k('mo_obj_a').evaluate().length], [1, 0]);

        await _tap(tester, _k('mo_filters'));
        await _tap(tester, _k('mo_f_reset'));
        await _tap(tester, _k('mo_f_mine'));
        await _tap(tester, _k('mo_f_apply'));
        expect([_k('mo_obj_d').evaluate().length, _k('mo_obj_a').evaluate().length], [1, 0]);
      });

      testWidgets('cancelling the filters changes nothing', (tester) async {
        await _pump(tester);
        await _tap(tester, _k('mo_filters'));
        await _tap(tester, _k('mo_f_status_completed'));
        await _tap(tester, find.text('Cancel'));
        expect(_text(tester, 'mo_filters_label'), 'Filters');
        expect(_k('mo_obj_o1'), findsOneWidget);
      });

      testWidgets('the search narrows the table, not the month\'s headline', (tester) async {
        await _pump(tester);
        await tester.enterText(_k('mo_search'), 'booking');
        await tester.pumpAndSettle();
        expect(_text(tester, 'mo_kpi_total_value'), '3');
      });

      testWidgets('a phone gets cards instead of a table: the same things, one under the other', (tester) async {
        await _pump(tester, size: const Size(360, 3400));
        expect(tester.takeException(), isNull);
        final row = _k('mo_obj_o1');
        expect(find.descendant(of: row, matching: find.text('Ship the booking app')), findsOneWidget);
        expect(find.descendant(of: row, matching: find.text('IT')), findsOneWidget);
        expect(find.descendant(of: row, matching: find.text('Medium')), findsOneWidget);
        expect(find.descendant(of: _k('mo_status_o1'), matching: find.text('In progress')), findsOneWidget);
        expect(find.text('Department'), findsNothing); // no column heads
      });
    });

    group('the trend', () {
      testWidgets('is drawn once two months have objectives', (tester) async {
        await _pump(tester);
        expect(find.text('Monthly Progress Trend'), findsOneWidget);
        expect(find.text('All departments · average progress'), findsOneWidget);
        expect(_k('mo_trend_chart'), findsOneWidget);
      });

      testWidgets('with less history than that, says so instead of drawing a line', (tester) async {
        await _pump(tester, trendFor: (m) => MonthlyTrend.fromJson({'months': <dynamic>[]}));
        expect(_k('mo_trend_chart'), findsNothing);
        expect(find.textContaining('Not enough history yet'), findsOneWidget);
      });

      testWidgets('narrowed to a department it is that department\'s line — and one with only a month of history has none', (tester) async {
        await _pump(tester);
        await _tap(tester, _k('mo_dept_open_d1'));
        expect(find.text('IT'), findsWidgets);
        expect(_k('mo_trend_chart'), findsOneWidget); // IT has two months
        await _tap(tester, _k('mo_dept_open_d1')); // everyone again
        await _tap(tester, _k('mo_dept_open_d2')); // HR: one month
        expect(_k('mo_trend_chart'), findsNothing);
        expect(find.textContaining('Not enough history yet'), findsOneWidget);
      });

      testWidgets('if it cannot be loaded the card says so with Retry — and the rest of the page still works', (tester) async {
        var fail = true;
        await _pump(tester, trendFor: (m) {
          if (fail) throw Exception('no trend');
          return _trend(m);
        });
        expect(find.text('Could not load this.'), findsWidgets);
        expect(_k('mo_table'), findsOneWidget);
        expect(_text(tester, 'mo_kpi_total_value'), '3');
        fail = false;
        await _tap(tester, find.text('Retry').first);
        expect(_k('mo_trend_chart'), findsOneWidget);
      });
    });

    group('target against achievement', () {
      testWidgets('planned, completed, in progress and not started — each with its share', (tester) async {
        await _pump(tester);
        expect(find.text('Target vs Achievement'), findsOneWidget);
        expect(_text(tester, 'mo_target_planned_value'), '3');
        expect(_text(tester, 'mo_target_completed_value'), '1 (33%)');
        expect(_text(tester, 'mo_target_progress_value'), '2 (67%)');
        expect(_text(tester, 'mo_target_notstarted_value'), '0 (0%)');
        expect(_k('mo_target_other_value'), findsNothing);
      });

      testWidgets('what ended short or was dropped has a line of its own, only when there is some', (tester) async {
        await _pump(tester, pageFor: pageOf([_obj('a', 'A', progress: 100), _obj('b', 'B', result: 'missed', progress: 10), _obj('c', 'C', result: 'cancelled')]));
        expect(_text(tester, 'mo_target_other_value'), '2 (67%)');
      });

      testWidgets('a month with nothing planned says so', (tester) async {
        await _pump(tester, pageFor: (k) => _page(departments: [_dept('d1', 'IT')]));
        expect(find.text('Nothing is planned for $_monthName yet.'), findsOneWidget);
      });
    });

    group('what stands out', () {
      testWidgets('who has finished, who is moving, who has set nothing, what was never closed, and how much is left', (tester) async {
        await _pump(tester);
        final card = _k('mo_takeaways_card');
        expect(find.descendant(of: card, matching: find.text('1 objective completed (IT)')), findsOneWidget);
        expect(find.descendant(of: card, matching: find.text('2 objectives in progress (IT, HR)')), findsOneWidget);
        expect(find.descendant(of: card, matching: find.text('No objectives set yet: Artist')), findsOneWidget);
        expect(find.descendant(of: card, matching: find.text('1 objective from $prevName was never closed out')), findsOneWidget);
        expect(find.descendant(of: card, matching: find.textContaining('still to finish by')), findsOneWidget);
      });

      testWidgets('narrowed to a department it is about that department', (tester) async {
        await _pump(tester);
        await _tap(tester, _k('mo_dept_open_d2'));
        final card = _k('mo_takeaways_card');
        expect(find.descendant(of: card, matching: find.text('1 objective in progress (HR)')), findsOneWidget);
        expect(find.descendant(of: card, matching: find.textContaining('IT')), findsNothing);
      });

      testWidgets('a month with nothing in it points at who has to set it', (tester) async {
        await _pump(tester, pageFor: (k) => _page(departments: [_dept('d1', 'IT', canManage: true), _dept('d2', 'HR')]));
        expect(find.text('No objectives set yet: IT, HR'), findsOneWidget);
      });
    });

    group('the progress matrix', () {
      testWidgets('a row for each department, a column for each of the last six months, and the average progress in each', (tester) async {
        await _pump(tester);
        await _tap(tester, _k('mo_tab_matrix'));
        for (final n in ['IT', 'HR', 'Artist']) {
          expect(find.descendant(of: _k('mo_matrix'), matching: find.text(n)), findsOneWidget, reason: n);
        }
        expect(find.descendant(of: _k('mo_cell_d1_4'), matching: find.text('45%')), findsOneWidget);
        expect(find.descendant(of: _k('mo_cell_d1_5'), matching: find.text('60%')), findsOneWidget);
        expect(find.descendant(of: _k('mo_cell_d2_5'), matching: find.text('25%')), findsOneWidget);
        expect(find.descendant(of: _k('mo_cell_d2_4'), matching: find.text('—')), findsOneWidget); // HR set nothing then
        expect(find.descendant(of: _k('mo_cell_d3_5'), matching: find.text('—')), findsOneWidget); // Artist never
        for (var i = 0; i < 6; i++) {
          expect(_k('mo_cell_d1_$i'), findsOneWidget, reason: 'column $i');
        }
        expect(find.text('No objectives'), findsOneWidget); // the legend
        expect(find.text('Under 40%'), findsOneWidget);
      });

      testWidgets('under the departments, a row for the whole company', (tester) async {
        await _pump(tester);
        await _tap(tester, _k('mo_tab_matrix'));
        expect(find.text('Whole company'), findsOneWidget);
        expect(find.descendant(of: _k('mo_cell_all_4'), matching: find.text('45%')), findsOneWidget);
        expect(find.descendant(of: _k('mo_cell_all_5'), matching: find.text('50%')), findsOneWidget);
        expect(find.descendant(of: _k('mo_cell_all_0'), matching: find.text('—')), findsOneWidget);
      });

      testWidgets('…but not when the page is narrowed to one department (its row is the company)', (tester) async {
        await _pump(tester);
        await _tap(tester, _k('mo_dept_open_d1'));
        await _tap(tester, _k('mo_tab_matrix'));
        expect(find.text('Whole company'), findsNothing);
        expect(_k('mo_cell_all_5'), findsNothing);
      });

      testWidgets('on a wide screen the months share the card; on a phone they keep their width and scroll', (tester) async {
        await _pump(tester);
        await _tap(tester, _k('mo_tab_matrix'));
        final wide = tester.getRect(_k('mo_cell_d1_0')).width;
        expect(wide, greaterThan(100));
        await _pump(tester, size: const Size(360, 1800));
        await _tap(tester, _k('mo_tab_matrix'));
        expect(tester.getRect(_k('mo_cell_d1_0')).width, closeTo(58, 0.5)); // not squeezed to fit
      });

      testWidgets('the months are named along the top, ending with this one', (tester) async {
        await _pump(tester);
        await _tap(tester, _k('mo_tab_matrix'));
        expect(find.descendant(of: _k('mo_matrix'), matching: find.text(_monthName.substring(0, 3))), findsOneWidget);
      });

      testWidgets('narrowed to a department, only its row', (tester) async {
        await _pump(tester);
        await _tap(tester, _k('mo_dept_open_d2'));
        await _tap(tester, _k('mo_tab_matrix'));
        expect(find.descendant(of: _k('mo_matrix'), matching: find.text('HR')), findsOneWidget);
        expect(find.descendant(of: _k('mo_matrix'), matching: find.text('IT')), findsNothing);
      });

      testWidgets('with no objectives in any of the months, says so', (tester) async {
        await _pump(tester, trendFor: (m) => MonthlyTrend.fromJson({'months': <dynamic>[]}));
        await _tap(tester, _k('mo_tab_matrix'));
        expect(find.text('No objectives were set in these months yet.'), findsOneWidget);
      });

      testWidgets('it fits a phone (it scrolls sideways rather than overflowing)', (tester) async {
        await _pump(tester, size: const Size(360, 1800));
        await _tap(tester, _k('mo_tab_matrix'));
        expect(tester.takeException(), isNull);
      });
    });

    group('key results across the month', () {
      testWidgets('every key result with its objective and department — the unfinished ones first', (tester) async {
        await _pump(tester);
        await _tap(tester, _k('mo_tab_krs'));
        expect(find.textContaining('of 4 done'), findsOneWidget);
        for (final k in ['k1', 'k2', 'k3', 'k4']) {
          expect(_k('mo_kr_row_$k'), findsOneWidget, reason: k);
        }
        expect(y(tester, 'mo_kr_row_k1'), lessThan(y(tester, 'mo_kr_row_k2')));
        expect(y(tester, 'mo_kr_row_k4'), lessThan(y(tester, 'mo_kr_row_k2')));
        expect(_text(tester, 'mo_kr_row_text_k1'), '20 / 40 screens');
      });

      testWidgets('open and done narrow the list', (tester) async {
        await _pump(tester);
        await _tap(tester, _k('mo_tab_krs'));
        await _tap(tester, _k('mo_kr_filter_1')); // Open
        expect(_k('mo_kr_row_k1'), findsOneWidget);
        expect(_k('mo_kr_row_k2'), findsNothing);
        await _tap(tester, _k('mo_kr_filter_2')); // Done
        expect(_k('mo_kr_row_k2'), findsOneWidget);
        expect(_k('mo_kr_row_k1'), findsNothing);
        await _tap(tester, _k('mo_kr_filter_0')); // All
        expect(_k('mo_kr_row_k1'), findsOneWidget);
      });

      testWidgets('the department narrows it', (tester) async {
        await _pump(tester);
        await _tap(tester, _k('mo_dept_open_d2'));
        await _tap(tester, _k('mo_tab_krs'));
        expect(_k('mo_kr_row_k4'), findsOneWidget);
        expect(_k('mo_kr_row_k1'), findsNothing);
      });

      testWidgets('someone who may report can do it from here — and it is saved as from the objective', (tester) async {
        final s = await _pump(tester);
        await _tap(tester, _k('mo_tab_krs'));
        await _tap(tester, _k('mo_kr_checkin_o1_k1'));
        await tester.enterText(_k('mo_ci_value'), '30');
        await _tap(tester, _k('mo_ci_save'));
        expect(s.calls.single.args, {'objective': 'o1', 'kr': 'k1', 'value': 30.0, 'completed': null});
        expect(find.text('Progress saved'), findsOneWidget);
      });

      testWidgets('no Update on a key result of a closed objective, or for someone who may not report', (tester) async {
        await _pump(tester);
        await _tap(tester, _k('mo_tab_krs'));
        expect(_k('mo_kr_checkin_o2_k3'), findsNothing); // o2 is closed
        expect(_k('mo_kr_checkin_o3_k4'), findsNothing); // HR's, not theirs
      });

      testWidgets('a cancelled objective\'s key results are no longer the plan, so they are not listed', (tester) async {
        await _pump(tester, pageFor: pageOf([_obj('a', 'A', result: 'cancelled', krs: [_kr('x', 'Gone', 10, 0)]), _obj('b', 'B', krs: [_kr('y', 'Kept', 10, 0)])]));
        await _tap(tester, _k('mo_tab_krs'));
        expect(_k('mo_kr_row_x'), findsNothing);
        expect(_k('mo_kr_row_y'), findsOneWidget);
      });

      testWidgets('with none yet it says so', (tester) async {
        await _pump(tester, pageFor: pageOf([_obj('a', 'A')]));
        await _tap(tester, _k('mo_tab_krs'));
        expect(find.textContaining('No key results yet'), findsOneWidget);
      });
    });
  });

  group('the model', () {
    test('a key result\'s attainment: done is 100, else current over target, never above 100', () {
      MonthlyKeyResult k(num t, num c, {bool done = false}) => MonthlyKeyResult(id: 'k', title: 'k', targetValue: t.toDouble(), currentValue: c.toDouble(), completed: done);
      expect(k(40, 20).attainment, 50);
      expect(k(10, 30).attainment, 100);
      expect(k(10, 0, done: true).attainment, 100);
      expect(k(0, 5).attainment, 0);
    });

    test('work left: not if achieved; with key results only if one is unfinished', () {
      expect(_o(krs: [_kr('a', 'x', 10, 5)]).hasWorkLeft, isTrue);
      expect(_o(krs: [_kr('a', 'x', 10, 10)]).hasWorkLeft, isFalse);
      expect(_o().hasWorkLeft, isTrue); // no key results: nothing says it is done
      expect(_o(result: 'achieved', krs: [_kr('a', 'x', 10, 5)]).hasWorkLeft, isFalse);
      expect(_o(result: 'missed', krs: [_kr('a', 'x', 10, 5)]).hasWorkLeft, isTrue);
    });

    test('the month before and after, over a year end', () {
      expect(prevMonthOf((year: 2027, month: 1)), (year: 2026, month: 12));
      expect(nextMonthOf((year: 2026, month: 12)), (year: 2027, month: 1));
      expect(monthTitle((year: 2026, month: 11)), 'November 2026');
    });

    test('results are read from the server\'s words; anything else is "not closed"', () {
      expect(ObjectiveResult.parse('achieved'), ObjectiveResult.achieved);
      expect(ObjectiveResult.parse('partly'), ObjectiveResult.partly);
      expect(ObjectiveResult.parse('missed'), ObjectiveResult.missed);
      expect(ObjectiveResult.parse(null), isNull);
      expect(ObjectiveResult.parse('whatever'), isNull);
    });

    test('what is assigned, and which department is yours, are read from the page', () {
      final page = MonthlyObjectivesPage.fromJson({
        'year': 2026,
        'month': 11,
        'isCurrent': true,
        'departments': [_dept('d1', 'IT', member: true), _dept('d2', 'HR')],
        'assigned': [_obj('g1', 'Given', assignedToMe: true)],
        'totals': <String, dynamic>{},
      });
      expect(page.departments.map((d) => d.isMine), [true, false]);
      expect(page.assigned.single.assignedToMe, isTrue);
      expect(MonthlyObjectivesPage.fromJson({'year': 2026, 'month': 11, 'departments': <dynamic>[]}).assigned, isEmpty); // an older server says nothing
    });

    test('the six results, as the server words them', () {
      expect(ObjectiveResult.values.map((r) => r.slug), ['achieved', 'partly', 'missed', 'continued', 'cancelled', 'deferred']);
      expect(ObjectiveResult.parse('continued'), ObjectiveResult.continued);
      expect(ObjectiveResult.parse('cancelled'), ObjectiveResult.cancelled);
      expect(ObjectiveResult.parse('deferred'), ObjectiveResult.deferred);
      expect(ObjectiveResult.deferred.label, 'Postponed');
      expect(ObjectiveResult.continued.tally, 'continuing');
      expect(ObjectiveResult.scored, [ObjectiveResult.achieved, ObjectiveResult.partly, ObjectiveResult.missed]);
    });

    test('a key result that says nothing about its kind is a number (older ones)', () {
      expect(KeyResultKind.parse(null), KeyResultKind.number);
      expect(KeyResultKind.parse('percent'), KeyResultKind.percent);
      expect(KeyResultKind.parse('yesno'), KeyResultKind.yesno);
      expect(KeyResultKind.parse('whatever'), KeyResultKind.number);
      expect(MonthlyKeyResult.fromJson(_kr('k', 'x', 10, 5)).kind, KeyResultKind.number);
    });

    test('what the progress points to: the server\'s word when it gives one, else worked out — and a run with months to go continues', () {
      final run = {'number': 1, 'total': 3, 'final': false, 'overran': false};
      MonthlyObjective with_(Map<String, dynamic> extra, {int p = 30}) => MonthlyObjective.fromJson({..._obj('o', 't', progress: p, krs: [_kr('k', 'K', 100, p)]), ...extra});
      expect(with_({'suggestedResult': 'achieved'}).suggestedResult, ObjectiveResult.achieved); // the server's word wins
      expect(with_({'suggestedResult': null}, p: 90).suggestedResult, isNull); // …even "nothing"
      expect(with_({'span': run}).suggestedResult, ObjectiveResult.continued);
      expect(with_({'span': run}, p: 100).suggestedResult, ObjectiveResult.achieved); // finished early
      expect(with_({'span': {...run, 'number': 3, 'final': true}}, p: 70).suggestedResult, ObjectiveResult.partly);
    });

    test('a cancelled objective has no work left; a postponed or continuing one does', () {
      final krs = [_kr('k', 'K', 10, 2)];
      MonthlyObjective ended(String r) => MonthlyObjective.fromJson(_obj('o', 't', result: r, krs: krs));
      expect(ended('cancelled').hasWorkLeft, isFalse);
      expect(ended('deferred').hasWorkLeft, isTrue);
      expect(ended('continued').hasWorkLeft, isTrue);
    });

    test('ready to close and who finished a key result are read from the server', () {
      final o = MonthlyObjective.fromJson(_obj('o', 't', readyToClose: true, krs: [_kr('k', 'K', 1, 1, done: true, doneAt: '2026-11-04T10:00:00.000Z', doneBy: 'Irfan')]));
      expect(o.readyToClose, isTrue);
      expect(o.keyResults.single.completedByName, 'Irfan');
      expect(o.keyResults.single.completedAt, isNotNull);
      expect(MonthlyObjective.fromJson(_obj('o', 't')).readyToClose, isFalse);
      expect(MonthlyKeyResult.fromJson(_kr('k', 'K', 1, 0)).completedAt, isNull);
    });

    test('progress text for each kind', () {
      expect(progressText(MonthlyKeyResult.fromJson(_kr('k', 'x', 100, 60, kind: 'percent'))), '60%');
      expect(progressText(MonthlyKeyResult.fromJson(_kr('k', 'x', 1, 1, kind: 'yesno', done: true))), 'Done');
      expect(progressText(MonthlyKeyResult.fromJson(_kr('k', 'x', 1, 0, kind: 'yesno'))), 'Not yet');
    });

    test('progress text', () {
      expect(progressText(MonthlyKeyResult.fromJson(_kr('k', 'x', 40, 20, unit: 'screens'))), '20 / 40 screens');
      expect(progressText(MonthlyKeyResult.fromJson(_kr('k', 'x', 12.5, 3.25))), '3.25 / 12.5');
    });
  });
}

String _text(WidgetTester t, String key) => t.widget<Text>(find.byKey(Key(key))).data!;
