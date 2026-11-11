import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:nizan_crm/core/models/auth_session.dart';
import 'package:nizan_crm/core/models/employee.dart';
import 'package:nizan_crm/core/providers/auth_provider.dart';
import 'package:nizan_crm/core/theme/app_theme.dart';
import 'package:nizan_crm/features/it/data/it_task.dart';
import 'package:nizan_crm/features/it/data/project.dart';
import 'package:nizan_crm/features/it/domain/gantt_weeks.dart';
import 'package:nizan_crm/features/it/domain/repositories/it_task_repository.dart';
import 'package:nizan_crm/features/it/presentation/controllers/it_tasks_notifier.dart';
import 'package:nizan_crm/features/it/presentation/screens/widgets/it_interactive_gantt.dart';
import 'package:nizan_crm/features/it/services/it_service.dart';

// The Timeline week by week: a toolbar to step ◀ ▶ one week, jump to Today and change the scale; a "1 Week" view that
// fits seven days on the screen; the week in focus; a click on a week header opens that week.

final _today = dateOnly(DateTime.now());
final _thisMonday = mondayOf(_today);
DateTime _d(int offset) => DateTime(_today.year, _today.month, _today.day + offset);
String _iso(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

ITTask _task(String id, String title, {required int from, required int days}) =>
    ITTask(id: id, projectId: 'p1', title: title, startDate: _d(from), dueDate: _d(from + days - 1));

/// A plan that runs from two weeks ago to five months ahead: today is inside it.
List<ITTask> _running() => [
      _task('a', 'Research', from: -14, days: 5),
      _task('b', 'Design', from: 0, days: 3),
      _task('c', 'Build', from: 10, days: 21),
      _task('d', 'Launch', from: 55, days: 3),
      _task('e', 'Review', from: 150, days: 3), // a long plan: the chart is wide enough to scroll to any week
    ];

class _Repo implements IITTaskRepository {
  _Repo(this.tasks);
  final List<ITTask> tasks;
  @override
  Future<List<ITTask>> getTasks({String? projectId, String? status, String? assignedTo, String? ticketType, String? severity, String? subTeam, String? search, bool mine = false}) async => tasks;
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError('${invocation.memberName}');
}

Widget _app(Widget gantt, List<ITTask> tasks) {
  final project = Project.fromJson({
    '_id': 'p1',
    'name': 'Lifestyle brand at 2030',
    'targetDepartment': 'Management',
    'managerId': {'_id': 'm1', 'name': 'Amna'},
    'editMode': 'managed',
    'departments': [
      {'name': 'Management', 'role': 'owner', 'status': 'accepted'}
    ],
    'access': {'role': 'manager', 'canManage': true, 'editMode': 'managed', 'canCreateTasks': true, 'canEditAllTasks': true, 'leadDepartments': <String>[], 'pendingInvitations': <String>[], 'canDecide': false},
  });
  return ProviderScope(
    overrides: <Override>[
      authSessionProvider.overrideWithValue(AuthSession(token: 't', userId: 'u', name: 'U', email: 'u@x', role: 'crm', employeeId: 'e1')),
      projectsProvider.overrideWith((ref) async => [project]),
      projectEmployeesProvider('p1').overrideWith((ref) => const <Employee>[]),
      itTaskRepositoryProvider.overrideWithValue(_Repo(tasks)),
    ],
    child: MaterialApp(theme: AppTheme.lightTheme, home: Scaffold(body: gantt)),
  );
}

Future<void> _pump(
  WidgetTester tester,
  List<ITTask> tasks, {
  bool toolbar = true,
  GanttZoomScale zoom = GanttZoomScale.week,
  Size size = const Size(1500, 900),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpWidget(_app(ITInteractiveGantt(tasks: tasks, allTasks: tasks, projectId: 'p1', zoomScale: zoom, showToolbar: toolbar), tasks));
  await tester.pumpAndSettle();
}

Finder _k(String key) => find.byKey(Key(key));
String _label(WidgetTester t) => t.widget<Text>(_k('gantt_week_label')).data!;
Rect _band(WidgetTester t) => t.getRect(_k('gantt_focus_band'));
Rect _bar(WidgetTester t, String id) => t.getRect(_k('gantt_bar_$id'));
bool _enabled(WidgetTester t, String key) => t.widget<IconButton>(_k(key)).onPressed != null;

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.tap(f);
  await tester.pumpAndSettle();
}

void main() {
  const sidebar = 270.0;

  group('the toolbar', () {
    testWidgets('names the week in focus (this week at first), with Today and the four scales', (tester) async {
      await _pump(tester, _running());
      expect(_label(tester), weekLabel(_thisMonday));
      expect(_k('gantt_this_week'), findsOneWidget);
      expect(_k('gantt_today'), findsOneWidget);
      for (final (key, text) in [('gantt_scale_fit', '1 Week'), ('gantt_scale_day', 'Days'), ('gantt_scale_week', 'Weeks'), ('gantt_scale_month', 'Months')]) {
        expect(find.descendant(of: _k(key), matching: find.text(text)), findsOneWidget, reason: key);
      }
      expect(_enabled(tester, 'gantt_prev_week'), isTrue);
      expect(_enabled(tester, 'gantt_next_week'), isTrue);
    });

    testWidgets('the Roadmap, which has its own scale control, gets none of it', (tester) async {
      await _pump(tester, _running(), toolbar: false);
      for (final k in ['gantt_week_label', 'gantt_today', 'gantt_prev_week', 'gantt_next_week', 'gantt_scale_fit', 'gantt_focus_band']) {
        expect(_k(k), findsNothing, reason: k);
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('week headers carry the week number', (tester) async {
      await _pump(tester, _running());
      expect(find.textContaining('W${isoWeekNumber(_thisMonday)} · '), findsWidgets);
    });
  });

  group('stepping week by week', () {
    testWidgets('▶ moves one week on, ◀ one back, and the shaded week moves with it', (tester) async {
      await _pump(tester, _running());
      final first = _band(tester);
      expect(first.width, greaterThan(0));
      final week = first.width; // 7 days wide

      await _tap(tester, _k('gantt_next_week'));
      expect(_label(tester), weekLabel(addWeeks(_thisMonday, 1)));
      expect(_k('gantt_this_week'), findsNothing);
      expect(_band(tester).width, week);

      await _tap(tester, _k('gantt_prev_week'));
      await _tap(tester, _k('gantt_prev_week'));
      expect(_label(tester), weekLabel(addWeeks(_thisMonday, -1)));
    });

    testWidgets('the week stepped to is brought into view: its first day sits just in from the left edge', (tester) async {
      await _pump(tester, _running());
      await _tap(tester, _k('gantt_next_week'));
      expect(_band(tester).left, closeTo(sidebar + 24, 1.5));
      await _tap(tester, _k('gantt_next_week'));
      expect(_band(tester).left, closeTo(sidebar + 24, 1.5));
    });

    testWidgets('Today comes back to the current week from anywhere', (tester) async {
      await _pump(tester, _running());
      for (var i = 0; i < 3; i++) {
        await _tap(tester, _k('gantt_next_week'));
      }
      expect(_label(tester), weekLabel(addWeeks(_thisMonday, 3)));
      await _tap(tester, _k('gantt_today'));
      expect(_label(tester), weekLabel(_thisMonday));
      expect(_k('gantt_this_week'), findsOneWidget);
      expect(_band(tester).left, closeTo(sidebar + 24, 1.5));
    });

    testWidgets('the buttons stop at the ends of the timeline instead of going off it', (tester) async {
      await _pump(tester, _running());
      var steps = 0;
      while (_enabled(tester, 'gantt_prev_week') && steps < 60) {
        await _tap(tester, _k('gantt_prev_week'));
        steps++;
      }
      expect(steps, inInclusiveRange(3, 59));
      final earliest = _label(tester);
      expect(_enabled(tester, 'gantt_next_week'), isTrue);

      var forward = 0;
      while (_enabled(tester, 'gantt_next_week') && forward < 120) {
        await _tap(tester, _k('gantt_next_week'));
        forward++;
      }
      expect(forward, greaterThan(steps));
      expect(_label(tester), isNot(earliest));
      expect(_enabled(tester, 'gantt_prev_week'), isTrue);
      expect(tester.takeException(), isNull);
    });
  });

  group('the 1 Week view', () {
    testWidgets('seven days fill the screen: a 3-day bar is three sevenths of it, with its title inside', (tester) async {
      await _pump(tester, _running());
      await _tap(tester, _k('gantt_scale_fit'));
      final day = (1500 - sidebar) / 7;
      expect(_bar(tester, 'b').width, closeTo(3 * day, 1));
      expect(_k('gantt_bar_text_b'), findsOneWidget);
      expect(_k('gantt_label_b'), findsNothing);
      expect(tester.widget<Text>(_k('gantt_bar_text_b')).data, 'Design');
    });

    testWidgets('it stays on the week that was in focus, with its first day at the left edge', (tester) async {
      await _pump(tester, _running());
      await _tap(tester, _k('gantt_next_week'));
      final before = _label(tester);
      await _tap(tester, _k('gantt_scale_fit'));
      expect(_label(tester), before);
      expect(_band(tester).left, closeTo(sidebar, 1.5));
      expect(_band(tester).width, closeTo(1500 - sidebar, 1.5));
    });

    testWidgets('▶ turns the page: the next week fills the screen the same way', (tester) async {
      await _pump(tester, _running());
      await _tap(tester, _k('gantt_scale_fit'));
      await _tap(tester, _k('gantt_next_week'));
      expect(_label(tester), weekLabel(addWeeks(_thisMonday, 1)));
      expect(_band(tester).left, closeTo(sidebar, 1.5));
      await _tap(tester, _k('gantt_prev_week'));
      expect(_label(tester), weekLabel(_thisMonday));
      expect(_band(tester).left, closeTo(sidebar, 1.5));
    });

    testWidgets('the days have names and dates, and Mondays start a week', (tester) async {
      await _pump(tester, _running());
      await _tap(tester, _k('gantt_scale_fit'));
      expect(find.text('Mon'), findsWidgets);
      expect(find.text('Sun'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });

  group('the other scales', () {
    testWidgets('switching Days / Weeks / Months keeps the same week in focus', (tester) async {
      await _pump(tester, _running());
      await _tap(tester, _k('gantt_next_week'));
      final label = _label(tester);
      for (final key in ['gantt_scale_day', 'gantt_scale_month', 'gantt_scale_week', 'gantt_scale_fit', 'gantt_scale_day']) {
        await _tap(tester, _k(key));
        expect(_label(tester), label, reason: key);
        expect(tester.takeException(), isNull, reason: key);
      }
    });

    testWidgets('Days: a 44px column a day (a 3-day bar is 132px); Weeks: about 16px a day', (tester) async {
      await _pump(tester, _running());
      await _tap(tester, _k('gantt_scale_day'));
      expect(_bar(tester, 'b').width, closeTo(3 * 44, 1));
      await _tap(tester, _k('gantt_scale_week'));
      expect(_bar(tester, 'b').width, closeTo(3 * 110 / 7, 1));
    });

    testWidgets('the chosen scale is shown as chosen', (tester) async {
      await _pump(tester, _running());
      Color? bg(String key) => (tester.widget<Container>(find.descendant(of: _k(key), matching: find.byType(Container)).first).decoration as BoxDecoration?)?.color;
      final on = bg('gantt_scale_week');
      expect(on, isNot(Colors.transparent));
      expect(bg('gantt_scale_fit'), Colors.transparent);
      await _tap(tester, _k('gantt_scale_fit'));
      expect(bg('gantt_scale_fit'), on);
      expect(bg('gantt_scale_week'), Colors.transparent);
    });
  });

  group('clicking a week', () {
    testWidgets('a week header opens that week in the 1 Week view', (tester) async {
      await _pump(tester, _running());
      final target = addWeeks(_thisMonday, 2);
      final header = _k('gantt_open_week_${_iso(target)}');
      await tester.ensureVisible(header);
      await tester.pumpAndSettle();
      await _tap(tester, header);
      expect(_label(tester), weekLabel(target));
      expect(_band(tester).left, closeTo(sidebar, 1.5));
      expect(_bar(tester, 'b').width, closeTo(3 * (1500 - sidebar) / 7, 1)); // the 1 Week view
    });

    testWidgets('in the Days scale, a day opens its week', (tester) async {
      await _pump(tester, _running());
      await _tap(tester, _k('gantt_scale_day'));
      final day = addWeeks(_thisMonday, 1).add(const Duration(days: 3)); // a Thursday next week
      final header = _k('gantt_open_day_${_iso(day)}');
      await tester.ensureVisible(header);
      await tester.pumpAndSettle();
      await _tap(tester, header);
      expect(_label(tester), weekLabel(addWeeks(_thisMonday, 1)));
      expect(_bar(tester, 'b').width, closeTo(3 * (1500 - sidebar) / 7, 1));
    });

    testWidgets('inside the 1 Week view the days are not buttons (the week is already open)', (tester) async {
      await _pump(tester, _running());
      await _tap(tester, _k('gantt_scale_fit'));
      expect(find.byKey(Key('gantt_open_day_${_iso(_today)}')), findsNothing);
    });
  });

  group('which week opens first', () {
    testWidgets('a plan that has not started opens on its first week', (tester) async {
      final tasks = [_task('x', 'Kick-off', from: 70, days: 3), _task('y', 'Build', from: 80, days: 10)];
      await _pump(tester, tasks);
      expect(_label(tester), weekLabel(mondayOf(_d(70))));
      expect(_k('gantt_this_week'), findsNothing);
    });

    testWidgets('a plan that is over opens on its last week', (tester) async {
      final tasks = [_task('x', 'Kick-off', from: -120, days: 3), _task('y', 'Wrap-up', from: -80, days: 5)];
      await _pump(tester, tasks);
      expect(_label(tester), weekLabel(mondayOf(_d(-80 + 4))));
    });

    testWidgets('tasks with no dates at all: this week', (tester) async {
      await _pump(tester, [ITTask(id: 'u', projectId: 'p1', title: 'Undated')]);
      expect(_label(tester), weekLabel(_thisMonday));
    });
  });

  group('layout', () {
    testWidgets('a narrow screen wraps the toolbar and nothing overflows', (tester) async {
      await _pump(tester, _running(), size: const Size(760, 900));
      expect(tester.takeException(), isNull);
      expect(_k('gantt_week_label'), findsOneWidget);
      expect(_k('gantt_scale_fit'), findsOneWidget);
      await _tap(tester, _k('gantt_scale_fit'));
      expect(tester.takeException(), isNull);
    });

    testWidgets('on a wide screen the scale switch sits at the right, the stepper at the left', (tester) async {
      await _pump(tester, _running());
      expect(tester.getRect(_k('gantt_week_label')).left, lessThan(tester.getRect(_k('gantt_scale_fit')).left));
      expect(tester.getRect(_k('gantt_scale_month')).right, greaterThan(1300));
    });

    testWidgets('a parent that owns the scale can still change it (toolbar off)', (tester) async {
      final scale = ValueNotifier(GanttZoomScale.week);
      addTearDown(scale.dispose);
      final tasks = _running();
      tester.view.physicalSize = const Size(1500, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(_app(
        ValueListenableBuilder<GanttZoomScale>(
          valueListenable: scale,
          builder: (_, s, _) => ITInteractiveGantt(tasks: tasks, allTasks: tasks, projectId: 'p1', zoomScale: s),
        ),
        tasks,
      ));
      await tester.pumpAndSettle();
      expect(_bar(tester, 'b').width, closeTo(3 * 110 / 7, 1));
      scale.value = GanttZoomScale.day;
      await tester.pumpAndSettle();
      expect(_bar(tester, 'b').width, closeTo(3 * 44, 1));
    });
  });
}
