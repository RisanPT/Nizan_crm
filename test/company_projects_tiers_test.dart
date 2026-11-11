import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nizan_crm/core/models/auth_session.dart';
import 'package:nizan_crm/core/models/employee.dart';
import 'package:nizan_crm/core/providers/auth_provider.dart';
import 'package:nizan_crm/core/theme/app_theme.dart';
import 'package:nizan_crm/features/it/data/project.dart';
import 'package:nizan_crm/features/it/domain/models/strategic_vision_model.dart';
import 'package:nizan_crm/features/it/presentation/screens/company_projects_screen.dart';
import 'package:nizan_crm/features/it/services/strategic_vision_service.dart';
import 'package:nizan_crm/features/it/services/it_service.dart';
import 'package:nizan_crm/features/org/data/department.dart';
import 'package:nizan_crm/features/org/services/department_service.dart';

// Company Projects → Portfolio: projects are Mini (7 days – 1 month), Moderate (1 – 3 months) or Main (3 months and
// more), worked out from their dates. The Mini tab holds the minis; "Moderate & Main" holds the rest in sections.
// The project form asks for the dates and says what kind of project they make.

final _now = DateTime.now();
String _iso(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
DateTime _in(int days) => DateTime(_now.year, _now.month, _now.day + days);

Project _p(
  String id,
  String name, {
  DateTime? start,
  DateTime? end,
  int? targetYear,
  String status = 'active',
  bool canManage = true,
  Map<String, dynamic> extra = const {},
}) =>
    Project.fromJson({
      '_id': id,
      'name': name,
      'status': status,
      'priority': 'medium',
      'targetDepartment': 'Marketing',
      'managerId': {'_id': 'm1', 'name': 'Mira Nair'},
      'startDate': _iso(start ?? _in(-3)),
      if (end != null) 'endDate': _iso(end),
      if (targetYear != null) 'targetYear': targetYear,
      'departments': [
        {'name': 'Marketing', 'role': 'owner', 'status': 'accepted'},
      ],
      'access': {'role': 'manager', 'canManage': canManage},
      ...extra,
    });

class _FakeProjects extends ProjectService {
  _FakeProjects(this.projects) : super(Dio());
  final List<Project> projects;
  final saved = <Map<String, dynamic>>[];
  final departmentCalls = <String?>[];

  @override
  Future<List<Project>> getProjects({String? status, String? priority, String? search, String? department, bool ownerOnly = false}) async {
    departmentCalls.add(department);
    return projects;
  }

  @override
  Future<Project> saveProject(Map<String, dynamic> body, {String? id}) async {
    saved.add({...body, if (id != null) '_id': id});
    return _p('new', body['name'] as String? ?? 'x');
  }
}

Future<_FakeProjects> _open(
  WidgetTester tester,
  List<Project> projects, {
  Size size = const Size(1300, 1500),
  String role = 'artist',
}) async {
  final fake = _FakeProjects(projects);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authSessionProvider.overrideWithValue(AuthSession(token: 't', userId: 'u', name: 'U', email: 'u@x', role: role, employeeId: 'e1', permissions: const ['calendar'])),
        projectServiceProvider.overrideWithValue(fake),
        departmentsProvider.overrideWith((ref) async => const [Department(id: 'd1', name: 'Marketing'), Department(id: 'd2', name: 'Finance')]),
        departmentEmployeesProvider.overrideWith((ref, dept) => const <Employee>[]),
        strategicVisionProvider.overrideWith((ref) => Completer<StrategicVisionModel>().future),
      ],
      child: MaterialApp(theme: AppTheme.lightTheme, home: const CompanyProjectsScreen()),
    ),
  );
  await tester.pumpAndSettle();
  return fake;
}

// A mix: two minis, a moderate, a main, a main by target year, and one nobody has dated.
List<Project> _mix() => [
      _p('a', 'Diwali reel shoot', start: _in(-2), end: _in(12)), // 15 days → mini
      _p('b', 'Packaging refresh', start: _in(-1), end: _in(25)), // 27 days → mini
      _p('c', 'Website revamp', start: _in(-5), end: _in(70)), // ~2.5 months → moderate
      _p('d', 'Pan Indian expansion', start: _in(-10), end: _in(500)), // main
      _p('e', 'Lifestyle brand 2030', start: _in(-1), targetYear: 2030), // main (by target year)
      _p('f', 'Vendor audit'), // no end date, no year
    ];

Finder _tab(String id) => find.byKey(Key('tier_tab_$id'));
String _tabText(WidgetTester t, String id) => t.widgetList<Text>(find.descendant(of: _tab(id), matching: find.byType(Text))).map((x) => x.data).join('|');

void main() {
  testWidgets('two tabs with how many projects are in each; the one with the big projects opens first', (tester) async {
    await _open(tester, _mix());
    expect(_tab('mini'), findsOneWidget);
    expect(_tab('long'), findsOneWidget);
    expect(_tabText(tester, 'mini'), 'Mini projects|7 days to 1 month|2');
    expect(_tabText(tester, 'long'), 'Moderate & Main|1 month and above|4', reason: 'moderate + two main + the one with no timeline');
    // the first look is the Moderate & Main tab: its projects are there, the minis are not
    expect(find.text('Website revamp'), findsOneWidget);
    expect(find.text('Pan Indian expansion'), findsOneWidget);
    expect(find.text('Diwali reel shoot'), findsNothing);
  });

  testWidgets('the Mini tab shows only the minis, soonest end first', (tester) async {
    await _open(tester, _mix());
    await tester.tap(_tab('mini'));
    await tester.pumpAndSettle();
    expect(find.text('Diwali reel shoot'), findsOneWidget);
    expect(find.text('Packaging refresh'), findsOneWidget);
    expect(find.text('Website revamp'), findsNothing);
    expect(find.text('Pan Indian expansion'), findsNothing);
    // (the cards sit side by side: the earlier end comes first, to the left)
    final first = tester.getTopLeft(find.text('Diwali reel shoot'));
    final second = tester.getTopLeft(find.text('Packaging refresh'));
    expect(first.dy < second.dy || (first.dy == second.dy && first.dx < second.dx), isTrue, reason: 'ends on day 12, the other on day 25');
    expect(find.byKey(const Key('tier_section_mini')), findsOneWidget);
  });

  testWidgets('Moderate & Main: Main first, then Moderate, then the projects with no timeline yet', (tester) async {
    await _open(tester, _mix());
    final main = find.byKey(const Key('tier_section_main'));
    final moderate = find.byKey(const Key('tier_section_moderate'));
    final none = find.byKey(const Key('tier_section_unscheduled'));
    expect([main, moderate, none].map((f) => f.evaluate().length), [1, 1, 1]);
    final y = [main, moderate, none].map((f) => tester.getTopLeft(f).dy).toList();
    expect(y[0] < y[1] && y[1] < y[2], isTrue, reason: 'Main, Moderate, No timeline from top to bottom');
    expect(find.text('Main projects'), findsOneWidget);
    expect(find.text('Moderate projects'), findsOneWidget);
    expect(find.text('Projects with no timeline'), findsOneWidget);
    // a project dated only by its target year is Main, and says so
    expect(tester.getTopLeft(find.text('Lifestyle brand 2030')).dy, lessThan(tester.getTopLeft(find.text('Website revamp')).dy));
  });

  testWidgets('a card shows its kind, its dates, how long it runs and how long is left', (tester) async {
    await _open(tester, _mix());
    await tester.tap(_tab('mini'));
    await tester.pumpAndSettle();
    final line = find.byKey(const Key('timeline_a'));
    expect(line, findsOneWidget);
    final text = tester.widgetList<Text>(find.descendant(of: line, matching: find.byType(Text))).map((t) => t.data).join('|');
    expect(text, contains('15 days'));
    expect(text, contains('days left'), reason: 'ends in 12 days');
    expect(find.text('Mini'), findsWidgets, reason: 'the kind chip on each card');
    expect(find.textContaining('H1 ·'), findsNothing, reason: 'a strategic wave means little for a mini');
  });

  testWidgets('a Moderate / Main card keeps its strategic wave', (tester) async {
    await _open(tester, _mix());
    expect(find.textContaining('H1 ·'), findsWidgets);
    expect(find.text('Main'), findsWidgets);
    expect(find.text('Moderate'), findsWidgets);
  });

  testWidgets('a project with no end date says so and offers to set one', (tester) async {
    final fake = await _open(tester, _mix());
    expect(find.byKey(const Key('timeline_none_f')), findsOneWidget);
    expect(find.text('No end date yet'), findsOneWidget);
    await tester.tap(find.byKey(const Key('set_timeline_f')));
    await tester.pumpAndSettle();
    expect(find.text('Edit project'), findsOneWidget, reason: 'the edit form opens, on the Timeline');
    expect(find.byKey(const Key('timeline_start')), findsOneWidget);
    expect(fake.saved, isEmpty);
  });

  testWidgets('someone who cannot edit the project is not offered "Set timeline"', (tester) async {
    await _open(tester, [_p('g', 'Read-only', canManage: false)]);
    expect(find.text('No end date yet'), findsOneWidget);
    expect(find.byKey(const Key('set_timeline_g')), findsNothing);
  });

  testWidgets('the counts follow the search; an empty tab points to the other one', (tester) async {
    await _open(tester, _mix());
    await tester.enterText(find.byType(TextField).first, 'diwali');
    await tester.pumpAndSettle();
    expect(_tabText(tester, 'mini'), 'Mini projects|7 days to 1 month|1');
    expect(_tabText(tester, 'long'), 'Moderate & Main|1 month and above|0');
    // the open tab (Moderate & Main) has nothing for "diwali": it says where the match is
    expect(find.text('No moderate or main projects match your filters.'), findsOneWidget);
    expect(find.text('1 mini project is in the Mini tab.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('empty_switch_tab')));
    await tester.pumpAndSettle();
    expect(find.text('Diwali reel shoot'), findsOneWidget);
    expect(find.byKey(const Key('portfolio_empty')), findsNothing);
  });

  testWidgets('no minis yet: the Mini tab explains itself and offers to start one', (tester) async {
    await _open(tester, [_p('c', 'Website revamp', start: _in(-5), end: _in(70))]);
    await tester.tap(_tab('mini'));
    await tester.pumpAndSettle();
    expect(find.text('No mini projects yet.'), findsOneWidget);
    expect(find.text('Short pieces of work, from 7 days to 1 month, live here.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('empty_create')));
    await tester.pumpAndSettle();
    // the form opens ready for a mini: two weeks long
    expect(find.byKey(const Key('timeline_kind')), findsOneWidget);
    expect(find.textContaining('Mini project · 14 days'), findsOneWidget);
  });

  testWidgets('only minis: the Mini tab opens first', (tester) async {
    await _open(tester, [_p('a', 'Diwali reel shoot', start: _in(-2), end: _in(12))]);
    expect(find.text('Diwali reel shoot'), findsOneWidget);
    expect(find.byKey(const Key('tier_section_mini')), findsOneWidget);
  });

  testWidgets('the table view has a KIND and a TIMELINE column', (tester) async {
    await _open(tester, _mix());
    await tester.tap(find.byTooltip('Table List View'));
    await tester.pumpAndSettle();
    expect(find.text('KIND'), findsWidgets);
    expect(find.text('TIMELINE'), findsWidgets);
    expect(find.text('No end date'), findsOneWidget);
  });

  testWidgets('on a phone the two tabs sit side by side without overflow', (tester) async {
    await _open(tester, _mix(), size: const Size(390, 1500));
    expect(tester.takeException(), isNull);
    expect(_tab('mini'), findsOneWidget);
    expect(tester.getSize(_tab('mini')).width, closeTo(tester.getSize(_tab('long')).width, 1));
  });

  group('the filters', () {
    testWidgets('Department and Status are two compact menus, not a row of chips for every one', (tester) async {
      await _open(tester, _mix());
      expect(find.byKey(const Key('filter_dept')), findsOneWidget);
      expect(find.byKey(const Key('filter_status')), findsOneWidget);
      expect(find.text('Department'), findsOneWidget);
      expect(find.text('Status'), findsOneWidget);
      for (final gone in ['All Departments', 'Any status', 'Proposed', 'Planning', 'On hold', 'Cancelled', 'Finance']) {
        expect(find.text(gone), findsNothing, reason: '"$gone" is inside a menu now, not on the screen');
      }
    });

    testWidgets('the Department menu lists the departments; choosing one asks for it and the button says so', (tester) async {
      final fake = await _open(tester, _mix());
      await tester.tap(find.byKey(const Key('filter_dept')));
      await tester.pumpAndSettle();
      expect(find.text('All departments'), findsOneWidget);
      expect(find.text('Finance'), findsOneWidget);
      await tester.tap(find.text('Finance'));
      await tester.pumpAndSettle();
      expect(fake.departmentCalls.last, 'Finance');
      expect(find.descendant(of: find.byKey(const Key('filter_dept')), matching: find.text('Finance')), findsOneWidget, reason: 'the button now names the choice');
      expect(find.text('Department'), findsNothing);
      // and choosing "All departments" again puts it back
      await tester.tap(find.byKey(const Key('filter_dept')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('All departments'));
      await tester.pumpAndSettle();
      expect(find.text('Department'), findsOneWidget, reason: 'back to no department chosen');
    });

    testWidgets('the Status menu filters the list, the count says how many are left, Reset clears it', (tester) async {
      await _open(tester, [..._mix(), _p('h', 'Closed audit', start: _in(-40), end: _in(-5), status: 'completed')]);
      expect(find.byKey(const Key('filter_count')), findsNothing, reason: 'nothing filtered: no count, no Reset');
      expect(find.byKey(const Key('filter_reset')), findsNothing);
      await tester.tap(find.byKey(const Key('filter_status')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(PopupMenuItem<String>, 'Completed'));
      await tester.pumpAndSettle();
      expect(find.text('1 of 7'), findsOneWidget);
      expect(find.text('Closed audit'), findsOneWidget);
      expect(find.text('Website revamp'), findsNothing);
      expect(find.descendant(of: find.byKey(const Key('filter_status')), matching: find.text('Completed')), findsOneWidget);
      await tester.tap(find.byKey(const Key('filter_reset')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('filter_count')), findsNothing);
      expect(find.text('Website revamp'), findsOneWidget);
      expect(find.text('Status'), findsOneWidget);
    });

    testWidgets('Reset clears the department, the status and the search together', (tester) async {
      await _open(tester, _mix());
      await tester.tap(find.byKey(const Key('filter_dept')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(PopupMenuItem<String>, 'Finance'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('filter_status')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(PopupMenuItem<String>, 'Active'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'revamp');
      await tester.pumpAndSettle();
      expect(find.text('Department'), findsNothing);
      expect(find.text('Status'), findsNothing);
      await tester.tap(find.byKey(const Key('filter_reset')));
      await tester.pumpAndSettle();
      expect(find.text('Department'), findsOneWidget);
      expect(find.text('Status'), findsOneWidget);
      expect(tester.widget<TextField>(find.byType(TextField).first).controller!.text, isEmpty);
    });

    testWidgets('on a phone the two filters share a line under the search, without overflow', (tester) async {
      await _open(tester, _mix(), size: const Size(390, 1500));
      final search = tester.getTopLeft(find.byType(TextField).first);
      final dept = tester.getTopLeft(find.byKey(const Key('filter_dept')));
      final status = tester.getTopLeft(find.byKey(const Key('filter_status')));
      expect(dept.dy, greaterThan(search.dy), reason: 'under the search');
      expect(status.dy, dept.dy, reason: 'side by side');
      expect(status.dx, greaterThan(dept.dx));
      await tester.tap(find.byKey(const Key('filter_status')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(PopupMenuItem<String>, 'Active'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('6 of 6 projects'), findsOneWidget);
    });
  });

  group('the project form', () {
    Future<_FakeProjects> openForm(WidgetTester tester, {List<Project>? projects}) async {
      final fake = await _open(tester, projects ?? _mix());
      await tester.tap(find.widgetWithText(FilledButton, 'Propose Project').first);
      await tester.pumpAndSettle();
      return fake;
    }

    testWidgets('asks for a start and an end date and shows the three kinds', (tester) async {
      await openForm(tester);
      expect(find.text('Timeline'), findsOneWidget);
      expect(find.text('Start date *'), findsOneWidget);
      expect(find.text('End date *'), findsOneWidget);
      expect(find.textContaining('Mini 7 days to 1 month · Moderate 1 to 3 months · Main 3 months and above'), findsOneWidget);
      expect(find.text('Pick an end date to see what kind of project this is.'), findsOneWidget);
    });

    testWidgets('a ready-made length sets the end date and says what kind of project it is', (tester) async {
      await openForm(tester);
      final kind = find.byKey(const Key('timeline_kind'));
      Future<String> pick(String preset) async {
        await tester.ensureVisible(find.byKey(Key('preset_$preset')));
        await tester.tap(find.byKey(Key('preset_$preset')));
        await tester.pumpAndSettle();
        return tester.widgetList<Text>(find.descendant(of: kind, matching: find.byType(Text))).map((t) => t.data).join('|');
      }

      expect(await pick('2 weeks'), contains('Mini project · 14 days'));
      expect(await pick('1 month'), contains('Mini project · 1 month'));
      expect(await pick('2 months'), contains('Moderate project · 2 months'));
      expect(await pick('6 months'), contains('Main project · 6 months'));
    });

    testWidgets('the strategic wave and pillar are asked for a Moderate / Main project, not for a Mini', (tester) async {
      await openForm(tester);
      await tester.ensureVisible(find.byKey(const Key('preset_2 weeks')));
      await tester.tap(find.byKey(const Key('preset_2 weeks')));
      await tester.pumpAndSettle();
      expect(find.text('Strategic Roadmap Alignment'), findsNothing);
      await tester.tap(find.byKey(const Key('preset_6 months')));
      await tester.pumpAndSettle();
      expect(find.text('Strategic Roadmap Alignment'), findsOneWidget);
    });

    testWidgets('an end date is needed: without one nothing is saved', (tester) async {
      final fake = await openForm(tester);
      await tester.enterText(find.widgetWithText(TextField, 'Project name *'), 'Winter shoot');
      await tester.ensureVisible(find.text('Send proposal'));
      await tester.tap(find.text('Send proposal'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Pick the end date'), findsOneWidget);
      expect(fake.saved, isEmpty);
    });

    testWidgets('saving a mini sends both dates and leaves the strategic fields out', (tester) async {
      final fake = await openForm(tester);
      await tester.enterText(find.widgetWithText(TextField, 'Project name *'), 'Winter shoot');
      await tester.enterText(find.byKey(const Key('cost_total')), '25000'); // every new project says what it will cost
      await tester.ensureVisible(find.byKey(const Key('preset_2 weeks')));
      await tester.tap(find.byKey(const Key('preset_2 weeks')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Send proposal'));
      await tester.tap(find.text('Send proposal'));
      await tester.pumpAndSettle();
      expect(fake.saved, hasLength(1));
      final body = fake.saved.single;
      expect(body['startDate'], _iso(_in(0)));
      expect(body['endDate'], _iso(_in(13)), reason: 'two weeks: 14 days counting both ends');
      expect(body.containsKey('horizonNumber'), isFalse);
      expect(body.containsKey('strategicPillar'), isFalse);
    });

    testWidgets('saving a main project sends the dates and the strategic wave', (tester) async {
      final fake = await openForm(tester);
      await tester.enterText(find.widgetWithText(TextField, 'Project name *'), 'Dubai studio');
      await tester.enterText(find.byKey(const Key('cost_total')), '25000');
      await tester.ensureVisible(find.byKey(const Key('preset_1 year')));
      await tester.tap(find.byKey(const Key('preset_1 year')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Send proposal'));
      await tester.tap(find.text('Send proposal'));
      await tester.pumpAndSettle();
      final body = fake.saved.single;
      expect(body.containsKey('endDate'), isTrue);
      expect(body['horizonNumber'], 1);
      expect(body.containsKey('strategicPillar'), isTrue);
    });

    // ── the estimated cost: asked for when a project is added, approved by the finance head before it starts ──

    testWidgets('a new project asks for its estimated cost, and nothing is saved without one', (tester) async {
      final fake = await openForm(tester);
      expect(find.byKey(const Key('cost_total')), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextField, 'Project name *'), 'Winter shoot');
      await tester.ensureVisible(find.byKey(const Key('preset_2 weeks')));
      await tester.tap(find.byKey(const Key('preset_2 weeks')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Send proposal'));
      await tester.tap(find.text('Send proposal'));
      await tester.pumpAndSettle();
      expect(find.text('Enter the estimated cost of the project'), findsOneWidget); // the message
      expect(find.text('Enter the estimated cost of this project'), findsOneWidget); // under the field
      expect(fake.saved, isEmpty);
    });

    testWidgets('a zero cost is no cost', (tester) async {
      final fake = await openForm(tester);
      await tester.enterText(find.widgetWithText(TextField, 'Project name *'), 'Winter shoot');
      await tester.enterText(find.byKey(const Key('cost_total')), '0');
      await tester.ensureVisible(find.byKey(const Key('preset_2 weeks')));
      await tester.tap(find.byKey(const Key('preset_2 weeks')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Send proposal'));
      await tester.tap(find.text('Send proposal'));
      await tester.pumpAndSettle();
      expect(fake.saved, isEmpty);
    });

    testWidgets('the cost is sent with the project', (tester) async {
      final fake = await openForm(tester);
      await tester.enterText(find.widgetWithText(TextField, 'Project name *'), 'Winter shoot');
      await tester.enterText(find.byKey(const Key('cost_total')), '1,25,000');
      await tester.ensureVisible(find.byKey(const Key('preset_2 weeks')));
      await tester.tap(find.byKey(const Key('preset_2 weeks')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Send proposal'));
      await tester.tap(find.text('Send proposal'));
      await tester.pumpAndSettle();
      expect(fake.saved.single['budget'], 125000.0);
      expect(fake.saved.single.containsKey('costPlan'), isFalse);
    });

    testWidgets('a breakdown is sent instead, and its total is the cost', (tester) async {
      final fake = await openForm(tester);
      await tester.enterText(find.widgetWithText(TextField, 'Project name *'), 'Winter shoot');
      await tester.ensureVisible(find.byKey(const Key('cost_breakdown_toggle')));
      await tester.tap(find.byKey(const Key('cost_breakdown_toggle')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('cost_line_amount_0')), '60000');
      await tester.ensureVisible(find.byKey(const Key('cost_add_line')));
      await tester.tap(find.byKey(const Key('cost_add_line')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('cost_line_amount_1')), '15500');
      expect(tester.widget<TextField>(find.byKey(const Key('cost_total'))).controller!.text, '75500');
      expect(tester.widget<TextField>(find.byKey(const Key('cost_total'))).readOnly, isTrue);
      await tester.ensureVisible(find.byKey(const Key('preset_2 weeks')));
      await tester.tap(find.byKey(const Key('preset_2 weeks')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Send proposal'));
      await tester.tap(find.text('Send proposal'));
      await tester.pumpAndSettle();
      final body = fake.saved.single;
      expect(body.containsKey('budget'), isFalse);
      final plan = (body['costPlan'] as List).cast<Map<String, dynamic>>();
      expect(plan.map((l) => l['category']), ['manpower', 'other']);
      expect(plan.map((l) => l['amount']), [60000.0, 15500.0]);
    });

    testWidgets('an administrator\'s new project cannot be started: "Active" is not offered until Finance approves the cost', (tester) async {
      await _open(tester, _mix(), role: 'admin');
      await tester.tap(find.widgetWithText(FilledButton, 'New Project').first);
      await tester.pumpAndSettle();
      final status = find.widgetWithText(DropdownButtonFormField<String>, 'Status');
      await tester.ensureVisible(status);
      await tester.tap(status);
      await tester.pumpAndSettle();
      expect(find.text('Planning'), findsWidgets);
      expect(find.text('On hold'), findsWidgets);
      expect(find.text('Cancelled'), findsWidgets);
      expect(find.text('Active'), findsNothing);
    });

    testWidgets('editing a project does not ask for the cost again: it says where it stands', (tester) async {
      await _open(tester, [
        _p('a', 'Diwali reel shoot', start: _in(-2), end: _in(12), status: 'planning', extra: {
          'costStatus': 'pending',
          'cost': {'budget': 125000, 'approvedBudget': 0, 'plan': <dynamic>[], 'changes': <dynamic>[]},
        }),
      ]);
      await tester.tap(find.byIcon(Icons.more_vert).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit Settings'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('cost_total')), findsNothing);
      expect(find.byKey(const Key('form_cost_note')), findsOneWidget);
      expect(find.textContaining('₹1,25,000 · Awaiting finance approval'), findsOneWidget);
    });

    Future<List<String>> statusChoices(WidgetTester tester, Project p) async {
      await tester.pumpWidget(const SizedBox.shrink()); // a fresh start, so a form left open by the last look is gone
      await _open(tester, [p], role: 'admin');
      await tester.tap(find.text('Portfolio')); // an administrator opens on the dashboard
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.more_vert).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit Settings'));
      await tester.pumpAndSettle();
      final status = find.widgetWithText(DropdownButtonFormField<String>, 'Status');
      await tester.ensureVisible(status);
      await tester.tap(status);
      await tester.pumpAndSettle();
      return [for (final label in ['Planning', 'Active', 'On hold', 'Completed', 'Cancelled']) if (find.text(label).evaluate().isNotEmpty) label];
    }

    testWidgets('a project whose cost Finance has not approved (or sent back) cannot be set to Active', (tester) async {
      expect(await statusChoices(tester, _p('a', 'Shoot', start: _in(-2), end: _in(12), status: 'planning', extra: {'costStatus': 'pending'})), isNot(contains('Active')));
      expect(await statusChoices(tester, _p('b', 'Shoot', start: _in(-2), end: _in(12), status: 'planning', extra: {'costStatus': 'returned'})), isNot(contains('Active')));
    });

    testWidgets('once approved it can; so can a project from before costs existed', (tester) async {
      expect(await statusChoices(tester, _p('a', 'Shoot', start: _in(-2), end: _in(12), status: 'planning', extra: {'costStatus': 'approved'})), contains('Active'));
      expect(await statusChoices(tester, _p('b', 'Shoot', start: _in(-2), end: _in(12), status: 'planning')), contains('Active'));
    });

    testWidgets('a project already running keeps "Active" while a change to its cost waits', (tester) async {
      expect(await statusChoices(tester, _p('a', 'Shoot', start: _in(-2), end: _in(12), status: 'active', extra: {'costStatus': 'pending'})), contains('Active'));
    });

    testWidgets('a portfolio card says its cost is waiting for Finance, or was sent back', (tester) async {
      await _open(tester, [
        _p('a', 'Diwali reel shoot', start: _in(-2), end: _in(12), status: 'planning', extra: {'costStatus': 'pending'}),
        _p('b', 'Packaging refresh', start: _in(-1), end: _in(25), status: 'planning', extra: {'costStatus': 'returned'}),
        _p('c', 'Website revamp', start: _in(-5), end: _in(70), extra: {'costStatus': 'approved'}),
      ]);
      await tester.tap(find.byKey(const Key('tier_tab_mini')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('card_cost_a')), findsOneWidget);
      expect(find.text('Awaiting finance approval'), findsOneWidget);
      expect(find.byKey(const Key('card_cost_b')), findsOneWidget);
      expect(find.text('Sent back by Finance'), findsOneWidget);
      await tester.tap(find.byKey(const Key('tier_tab_long')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('card_cost_c')), findsNothing, reason: 'approved: nothing to flag');
    });

    testWidgets('editing a project: its dates are filled in, and changing them says the kind moves', (tester) async {
      final fake = await _open(tester, [_p('a', 'Diwali reel shoot', start: _in(-2), end: _in(12))]);
      await tester.tap(find.byIcon(Icons.more_vert).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit Settings'));
      await tester.pumpAndSettle();
      expect(find.text('Edit project'), findsOneWidget);
      expect(find.textContaining('Mini project · 15 days'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('preset_6 months')));
      await tester.tap(find.byKey(const Key('preset_6 months')));
      await tester.pumpAndSettle();
      expect(find.text('This moves the project from Mini to Main.'), findsOneWidget);
      expect(fake.saved, isEmpty);
    });

    testWidgets('editing a project that has no end date can still be saved without one', (tester) async {
      final fake = await _open(tester, [_p('f', 'Vendor audit')]);
      await tester.tap(find.byKey(const Key('set_timeline_f')));
      await tester.pumpAndSettle();
      expect(find.text('End date'), findsOneWidget, reason: 'not marked required for a project that never had one');
      await tester.ensureVisible(find.text('Save changes'));
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();
      expect(fake.saved, hasLength(1));
      expect(fake.saved.single.containsKey('endDate'), isFalse);
      expect(fake.saved.single['_id'], 'f');
    });
  });
}
