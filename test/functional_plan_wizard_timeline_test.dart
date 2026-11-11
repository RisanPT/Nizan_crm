import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:nizan_crm/core/models/employee.dart';
import 'package:nizan_crm/core/theme/app_theme.dart';
import 'package:nizan_crm/features/it/data/it_task.dart';
import 'package:nizan_crm/features/it/data/project.dart';
import 'package:nizan_crm/features/it/domain/plan_drafts.dart';
import 'package:nizan_crm/features/it/domain/repositories/it_task_repository.dart';
import 'package:nizan_crm/features/it/presentation/controllers/it_tasks_notifier.dart';
import 'package:nizan_crm/features/it/presentation/screens/widgets/functional_plan_wizard_dialog.dart';
import 'package:nizan_crm/features/it/services/it_service.dart';

// The Gantt Plan Wizard, "Tasks & Ownership": each task can be fixed on the timeline — a start day, an end day and a time of
// day for each. Pick a start and an end and the length follows (and the other way round); a fixed start is "not before", so an
// earlier task can still push it later and the row says so; the first sub-task takes over what was fixed on its task;
// and what is saved carries the dates, and the clock times as exact moments.

class _Repo implements IITTaskRepository {
  final created = <Map<String, dynamic>>[];
  var _n = 0;
  @override
  Future<ITTask> createTask(Map<String, dynamic> data) async {
    created.add(data);
    return ITTask(id: 'c${++_n}', projectId: 'p1', title: (data['title'] ?? '').toString());
  }

  @override
  Future<ITTask> updateTask(String id, Map<String, dynamic> data) async => ITTask(id: id, projectId: 'p1', title: '');

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError('${invocation.memberName}');
}

final _project = Project.fromJson({
  '_id': 'p1',
  'name': 'Lifestyle brand at 2030',
  'targetDepartment': 'IT',
  'managerId': {'_id': 'm1', 'name': 'Amna'},
  'editMode': 'managed',
  'departments': [
    {'name': 'IT', 'role': 'owner', 'status': 'accepted'},
  ],
  'access': {
    'role': 'manager',
    'canManage': true,
    'editMode': 'managed',
    'canCreateTasks': true,
    'canEditAllTasks': true,
    'leadDepartments': <String>[],
    'pendingInvitations': <String>[],
    'canDecide': false,
  },
});

typedef _Seed = ({List<PlanPhaseDraft> phases, List<PlanTaskDraft> tasks});
_Seed _plan(List<PlanTaskDraft> tasks) => (phases: [PlanPhaseDraft(id: 'ph1', name: 'Design')], tasks: tasks);

PlanTaskDraft _task(
  String id, {
  int days = 2,
  String? parent,
  List<String> after = const [],
  DateTime? start,
  DateTime? end,
  TimeOfDay? from,
  TimeOfDay? to,
  bool milestone = false,
}) => PlanTaskDraft(
  id: id,
  phaseId: 'ph1',
  parentId: parent,
  title: 'Task $id',
  durationDays: days,
  predecessorIds: after,
  startDate: start,
  endDate: end,
  startTime: from,
  endTime: to,
  isMilestone: milestone,
);

Future<_Repo> _open(WidgetTester tester, _Seed seed) async {
  tester.view.physicalSize = const Size(1500, 1100);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final repo = _Repo();
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        projectEmployeesProvider('p1').overrideWith((ref) => const <Employee>[]),
        itTaskRepositoryProvider.overrideWithValue(repo),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () => showDialog<void>(
                context: context,
                barrierDismissible: false,
                builder: (_) => FunctionalPlanWizardDialog(
                  projectId: 'p1',
                  projectName: 'Lifestyle brand at 2030',
                  existingTasks: const [],
                  project: _project,
                  seed: seed,
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return repo;
}

Future<void> _continue(WidgetTester tester, [int times = 1]) async {
  for (var i = 0; i < times; i++) {
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
  }
}

Future<void> _toTasks(WidgetTester tester) => _continue(tester, 2);

Future<void> _generate(WidgetTester tester) async {
  await _continue(tester); // to the last step
  await tester.tap(find.text('Generate Gantt Plan'));
  await tester.pumpAndSettle();
}

Finder _k(String key) => find.byKey(Key(key));
Finder _in(String key, Finder what) => find.descendant(of: _k(key), matching: what);
final _fmt = DateFormat('MMM dd, yyyy');
String _day(DateTime d) => _fmt.format(d);
DateTime _from(int offset) {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day + offset);
}

String _time(WidgetTester t, TimeOfDay v) => v.format(t.element(find.byType(FunctionalPlanWizardDialog)));

/// The text of a date chip.
String _chip(WidgetTester t, String key) => t.widget<Text>(find.descendant(of: _k(key), matching: find.byType(Text)).first).data!;

/// Opens the date picker of [chip], goes to the next month and picks its [day] — whatever today is, that day is later than it.
Future<DateTime> _pickNextMonth(WidgetTester tester, String chip, int day) async {
  await tester.tap(_k(chip));
  await tester.pumpAndSettle();
  final shown = _from(0);
  await tester.tap(find.byTooltip('Next month'));
  await tester.pumpAndSettle();
  await tester.tap(find.descendant(of: find.byType(DatePickerDialog), matching: find.text('$day')).first);
  await tester.pumpAndSettle();
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
  return DateTime(shown.year, shown.month + 1, day);
}

DateTime _at(int y, int m, int d, [int h = 0, int min = 0]) => DateTime(y, m, d, h, min);
String _utc(DateTime d) => d.toUtc().toIso8601String();

void main() {
  group('the timeline strip on each task', () {
    testWidgets('shows start, end and both times — the plan chooses the days until you fix them', (tester) async {
      await _open(tester, _plan([_task('tk1')]));
      await _toTasks(tester);
      expect(_chip(tester, 'wizard_start_date_tk1'), _day(_from(0)));
      expect(_chip(tester, 'wizard_end_date_tk1'), _day(_from(2)));
      expect(_in('wizard_start_time_tk1', find.text('Add time')), findsOneWidget);
      expect(_in('wizard_end_time_tk1', find.text('Add time')), findsOneWidget);
      expect(find.text('auto'), findsNWidgets(2)); // both days are the plan's
      expect(_k('wizard_clear_dates_tk1'), findsNothing); // nothing to hand back yet
    });

    testWidgets('a task that waits for another starts after it', (tester) async {
      await _open(
        tester,
        _plan([
          _task('tk1', days: 3),
          _task('tk2', after: ['tk1']),
        ]),
      );
      await _toTasks(tester);
      expect(_chip(tester, 'wizard_start_date_tk2'), _day(_from(3)));
      expect(_chip(tester, 'wizard_end_date_tk2'), _day(_from(5)));
    });
  });

  group('picking the days', () {
    testWidgets('a start day fixes it, and the end follows by the length', (tester) async {
      await _open(tester, _plan([_task('tk1', days: 3)]));
      await _toTasks(tester);
      final start = await _pickNextMonth(tester, 'wizard_start_date_tk1', 15);
      expect(_chip(tester, 'wizard_start_date_tk1'), _day(start));
      expect(_chip(tester, 'wizard_end_date_tk1'), _day(DateTime(start.year, start.month, start.day + 3)));
      expect(_k('wizard_clear_dates_tk1'), findsOneWidget);
      expect(_in('wizard_start_date_tk1', find.text('auto')), findsNothing); // fixed now
      expect(_in('wizard_end_date_tk1', find.text('auto')), findsOneWidget); // the end is still the plan's
    });

    testWidgets('an end day fixes both and makes the length the days between them', (tester) async {
      await _open(tester, _plan([_task('tk1', days: 2)]));
      await _toTasks(tester);
      final end = await _pickNextMonth(tester, 'wizard_end_date_tk1', 20);
      expect(_chip(tester, 'wizard_end_date_tk1'), _day(end));
      expect(_chip(tester, 'wizard_start_date_tk1'), _day(_from(0))); // fixed where it stood
      final days = daysBetweenPicked(_from(0), end);
      expect(tester.widget<TextFormField>(_k('wizard_dur_tk1_1')).initialValue, '$days'); // the Dur box shows it
      expect(_in('wizard_end_date_tk1', find.text('auto')), findsNothing);
      expect(_k('wizard_clear_dates_tk1'), findsOneWidget);
    });

    testWidgets('moving the start moves the end with it and keeps the length', (tester) async {
      await _open(tester, _plan([_task('tk1', days: 3, start: _at(2027, 3, 1), end: _at(2027, 3, 4))]));
      await _toTasks(tester);
      expect(_chip(tester, 'wizard_start_date_tk1'), 'Mar 01, 2027');
      await tester.tap(_k('wizard_start_date_tk1'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Next month'));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: find.byType(DatePickerDialog), matching: find.text('10')).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(_chip(tester, 'wizard_start_date_tk1'), 'Apr 10, 2027');
      expect(_chip(tester, 'wizard_end_date_tk1'), 'Apr 13, 2027');
    });

    testWidgets('moving the start onto the day the end used to be does not make it a same-day job', (tester) async {
      await _open(tester, _plan([_task('tk1', days: 3, start: _at(2027, 3, 1), end: _at(2027, 3, 4))]));
      await _toTasks(tester);
      await tester.tap(_k('wizard_start_date_tk1'));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: find.byType(DatePickerDialog), matching: find.text('4')).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(_chip(tester, 'wizard_start_date_tk1'), 'Mar 04, 2027');
      expect(_chip(tester, 'wizard_end_date_tk1'), 'Mar 07, 2027'); // still three days long
    });

    testWidgets('a same-day job that is given a length is no longer a same-day job', (tester) async {
      await _open(tester, _plan([_task('tk1', days: 1, start: _at(2027, 3, 1), end: _at(2027, 3, 1))]));
      await _toTasks(tester);
      expect(_chip(tester, 'wizard_end_date_tk1'), 'Mar 01, 2027');
      await tester.enterText(_k('wizard_dur_tk1_0'), '3');
      await tester.pumpAndSettle();
      expect(_chip(tester, 'wizard_end_date_tk1'), 'Mar 04, 2027');
      await _continue(tester);
      expect(tester.widget<Text>(_k('wizard_range_tk1')).data, 'Mar 01, 2027 → Mar 04, 2027 (3d)');
    });

    testWidgets('moving a same-day job keeps it a same-day job', (tester) async {
      await _open(tester, _plan([_task('tk1', days: 1, start: _at(2027, 3, 1), end: _at(2027, 3, 1))]));
      await _toTasks(tester);
      await tester.tap(_k('wizard_start_date_tk1'));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: find.byType(DatePickerDialog), matching: find.text('9')).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(_chip(tester, 'wizard_start_date_tk1'), 'Mar 09, 2027');
      expect(_chip(tester, 'wizard_end_date_tk1'), 'Mar 09, 2027');
    });

    testWidgets('closing the picker changes nothing', (tester) async {
      await _open(tester, _plan([_task('tk1')]));
      await _toTasks(tester);
      await tester.tap(_k('wizard_start_date_tk1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel').last);
      await tester.pumpAndSettle();
      expect(_k('wizard_clear_dates_tk1'), findsNothing);
      expect(find.text('auto'), findsNWidgets(2));
    });

    testWidgets('a longer length moves a fixed end', (tester) async {
      await _open(tester, _plan([_task('tk1', days: 3, start: _at(2027, 3, 1), end: _at(2027, 3, 4))]));
      await _toTasks(tester);
      await tester.enterText(_k('wizard_dur_tk1_0'), '5');
      await tester.pumpAndSettle();
      expect(_chip(tester, 'wizard_end_date_tk1'), 'Mar 06, 2027');
      expect(_chip(tester, 'wizard_start_date_tk1'), 'Mar 01, 2027');
    });

    testWidgets('a longer length moves the plan\'s own end too, even with no day fixed', (tester) async {
      await _open(tester, _plan([_task('tk1', days: 2)]));
      await _toTasks(tester);
      await tester.enterText(_k('wizard_dur_tk1_0'), '6');
      await tester.pumpAndSettle();
      expect(_chip(tester, 'wizard_end_date_tk1'), _day(_from(6)));
    });

    testWidgets('"Auto dates" hands the days back to the plan', (tester) async {
      await _open(tester, _plan([_task('tk1', days: 3, start: _at(2027, 3, 1), end: _at(2027, 3, 4))]));
      await _toTasks(tester);
      await tester.tap(_k('wizard_clear_dates_tk1'));
      await tester.pumpAndSettle();
      expect(_chip(tester, 'wizard_start_date_tk1'), _day(_from(0)));
      expect(_chip(tester, 'wizard_end_date_tk1'), _day(_from(3)));
      expect(_k('wizard_clear_dates_tk1'), findsNothing);
      expect(find.text('auto'), findsNWidgets(2));
    });
  });

  group('a fixed start is "not before"', () {
    testWidgets('an earlier task that is not done by then pushes it later, and the row says so', (tester) async {
      await _open(
        tester,
        _plan([
          _task('tk1', days: 6),
          _task('tk2', days: 2, after: ['tk1'], start: _from(1), end: _from(3)),
        ]),
      );
      await _toTasks(tester);
      expect(_chip(tester, 'wizard_start_date_tk2'), _day(_from(6))); // not the day that was picked
      expect(_chip(tester, 'wizard_end_date_tk2'), _day(_from(8)));
      final note = tester.widget<Text>(find.descendant(of: _k('wizard_pushed_tk2'), matching: find.byType(Text)));
      expect(note.data, contains(_day(_from(6))));
      expect(note.data, contains(_day(_from(1))));
      expect(_in('wizard_end_date_tk2', find.text('auto')), findsOneWidget); // the picked end no longer holds
    });

    testWidgets('a day after what it waits for is kept, with no note', (tester) async {
      await _open(
        tester,
        _plan([
          _task('tk1', days: 2),
          _task('tk2', days: 2, after: ['tk1'], start: _from(5), end: _from(7)),
        ]),
      );
      await _toTasks(tester);
      expect(_chip(tester, 'wizard_start_date_tk2'), _day(_from(5)));
      expect(_chip(tester, 'wizard_end_date_tk2'), _day(_from(7)));
      expect(_k('wizard_pushed_tk2'), findsNothing);
      expect(_in('wizard_end_date_tk2', find.text('auto')), findsNothing);
    });
  });

  group('time of day', () {
    testWidgets('a time is picked, shown and taken away again', (tester) async {
      await _open(tester, _plan([_task('tk1')]));
      await _toTasks(tester);
      await tester.tap(_k('wizard_start_time_tk1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(_in('wizard_start_time_tk1', find.text(_time(tester, const TimeOfDay(hour: 9, minute: 0)))), findsOneWidget); // starts at 9 unless told
      await tester.tap(_k('wizard_end_time_tk1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(_in('wizard_end_time_tk1', find.text(_time(tester, const TimeOfDay(hour: 17, minute: 0)))), findsOneWidget); // and ends at 5
      await tester.tap(_k('wizard_start_time_clear_tk1'));
      await tester.pumpAndSettle();
      expect(_in('wizard_start_time_tk1', find.text('Add time')), findsOneWidget);
      expect(_k('wizard_start_time_clear_tk1'), findsNothing);
    });

    testWidgets('a time does not fix the day: the plan still chooses it', (tester) async {
      await _open(tester, _plan([_task('tk1', from: const TimeOfDay(hour: 10, minute: 0))]));
      await _toTasks(tester);
      expect(_k('wizard_clear_dates_tk1'), findsNothing);
      expect(find.text('auto'), findsNWidgets(2));
    });

    testWidgets('the last step shows the times beside the days, and "same day" for a short job', (tester) async {
      await _open(
        tester,
        _plan([
          _task(
            'tk1',
            days: 1,
            start: _at(2027, 3, 1),
            end: _at(2027, 3, 1),
            from: const TimeOfDay(hour: 10, minute: 0),
            to: const TimeOfDay(hour: 13, minute: 0),
          ),
        ]),
      );
      await _toTasks(tester);
      expect(_chip(tester, 'wizard_start_date_tk1'), 'Mar 01, 2027');
      expect(_chip(tester, 'wizard_end_date_tk1'), 'Mar 01, 2027'); // ends where it starts
      await _continue(tester);
      final ten = _time(tester, const TimeOfDay(hour: 10, minute: 0));
      final one = _time(tester, const TimeOfDay(hour: 13, minute: 0));
      expect(tester.widget<Text>(_k('wizard_range_tk1')).data, 'Mar 01, 2027, $ten → Mar 01, 2027, $one (same day)');
    });

    testWidgets('without times the last step reads as it always did', (tester) async {
      await _open(tester, _plan([_task('tk1', days: 3, start: _at(2027, 3, 1), end: _at(2027, 3, 4))]));
      await _toTasks(tester);
      await _continue(tester);
      expect(tester.widget<Text>(_k('wizard_range_tk1')).data, 'Mar 01, 2027 → Mar 04, 2027 (3d)');
    });

    testWidgets('a job that ends before it starts cannot be made: it goes back to the task to fix', (tester) async {
      final repo = await _open(
        tester,
        _plan([
          _task(
            'tk1',
            days: 1,
            start: _at(2027, 3, 1),
            end: _at(2027, 3, 1),
            from: const TimeOfDay(hour: 13, minute: 0),
            to: const TimeOfDay(hour: 10, minute: 0),
          ),
        ]),
      );
      await _toTasks(tester);
      await _generate(tester);
      expect(find.textContaining('ends before it starts'), findsOneWidget);
      expect(repo.created, isEmpty);
      expect(find.text('Tasks & Ownership'), findsOneWidget); // back on the step that has it
    });

    testWidgets('over several days, an end time earlier in the day than the start time is fine', (tester) async {
      final repo = await _open(
        tester,
        _plan([
          _task(
            'tk1',
            days: 3,
            start: _at(2027, 3, 1),
            end: _at(2027, 3, 4),
            from: const TimeOfDay(hour: 15, minute: 0),
            to: const TimeOfDay(hour: 11, minute: 0),
          ),
        ]),
      );
      await _toTasks(tester);
      await _generate(tester);
      expect(repo.created, hasLength(2)); // the phase and the task
    });
  });

  group('milestones, summaries and sub-tasks', () {
    testWidgets('a milestone is at one moment: a day and a time, no end', (tester) async {
      await _open(tester, _plan([_task('tk1', days: 1, milestone: true, start: _at(2027, 3, 1))]));
      await _toTasks(tester);
      expect(find.text('ON'), findsOneWidget);
      expect(_k('wizard_start_date_tk1'), findsOneWidget);
      expect(_k('wizard_end_date_tk1'), findsNothing);
      expect(_k('wizard_end_time_tk1'), findsNothing);
    });

    testWidgets('making a task a milestone drops its end', (tester) async {
      await _open(tester, _plan([_task('tk1', days: 3, start: _at(2027, 3, 1), end: _at(2027, 3, 4), to: const TimeOfDay(hour: 17, minute: 0))]));
      await _toTasks(tester);
      await tester.tap(find.byIcon(Icons.outlined_flag_rounded));
      await tester.pumpAndSettle();
      expect(_k('wizard_end_date_tk1'), findsNothing);
      await tester.tap(find.byIcon(Icons.flag_rounded));
      await tester.pumpAndSettle();
      expect(_in('wizard_end_time_tk1', find.text('Add time')), findsOneWidget); // the end time went with it
      expect(_in('wizard_end_date_tk1', find.text('auto')), findsOneWidget);
    });

    testWidgets('a task with sub-tasks has no days of its own: it shows the span of its sub-tasks', (tester) async {
      await _open(
        tester,
        _plan([
          _task('g', days: 1),
          _task('a', parent: 'g', days: 2),
          _task('b', parent: 'g', days: 3, after: ['a']),
        ]),
      );
      await _toTasks(tester);
      expect(_k('wizard_start_date_g'), findsNothing);
      expect(tester.widget<Text>(find.descendant(of: _k('wizard_group_range_g'), matching: find.byType(Text))).data, contains('from its sub-tasks'));
      expect(
        tester.widget<Text>(find.descendant(of: _k('wizard_group_range_g'), matching: find.byType(Text))).data,
        contains('${_day(_from(0))} → ${_day(_from(5))}'),
      );
    });

    testWidgets('the first sub-task takes over what was fixed on its task, and the task becomes a summary', (tester) async {
      await _open(
        tester,
        _plan([
          _task(
            'tk1',
            days: 3,
            start: _at(2027, 3, 1),
            end: _at(2027, 3, 4),
            from: const TimeOfDay(hour: 9, minute: 0),
            to: const TimeOfDay(hour: 17, minute: 0),
          ),
        ]),
      );
      await _toTasks(tester);
      await tester.tap(_k('wizard_add_sub_tk1'));
      await tester.pumpAndSettle();
      expect(_k('wizard_group_range_tk1'), findsOneWidget); // the task spans its sub-tasks now
      expect(_k('wizard_start_date_tk1'), findsNothing);
      expect(_chip(tester, 'wizard_start_date_tsk_1'), 'Mar 01, 2027');
      expect(_chip(tester, 'wizard_end_date_tsk_1'), 'Mar 04, 2027');
      expect(_in('wizard_start_time_tsk_1', find.text(_time(tester, const TimeOfDay(hour: 9, minute: 0)))), findsOneWidget);
      expect(_in('wizard_end_time_tsk_1', find.text(_time(tester, const TimeOfDay(hour: 17, minute: 0)))), findsOneWidget);
    });

    testWidgets('a second sub-task starts with nothing fixed', (tester) async {
      await _open(tester, _plan([_task('tk1', days: 3, start: _at(2027, 3, 1), end: _at(2027, 3, 4))]));
      await _toTasks(tester);
      await tester.tap(_k('wizard_add_sub_tk1'));
      await tester.pumpAndSettle();
      await tester.tap(_k('wizard_add_sub_tk1'));
      await tester.pumpAndSettle();
      expect(_k('wizard_clear_dates_tsk_2'), findsNothing);
      expect(_in('wizard_start_date_tsk_2', find.text('auto')), findsOneWidget);
    });
  });

  group('what is saved', () {
    DateTime dateOf(Map<String, dynamic> b, String k) => DateTime.parse(b[k] as String);

    testWidgets('fixed days with no times go as they always did — a day, not a moment', (tester) async {
      final repo = await _open(tester, _plan([_task('tk1', days: 3, start: _at(2027, 3, 1), end: _at(2027, 3, 4))]));
      await _toTasks(tester);
      await _generate(tester);
      final made = repo.created.firstWhere((b) => b['title'] == 'Task tk1');
      expect(made['startDate'], _at(2027, 3, 1).toIso8601String());
      expect(made['dueDate'], _at(2027, 3, 4).toIso8601String());
      expect(made['deadline'], made['dueDate']);
      expect(made['startDate'], isNot(endsWith('Z')));
    });

    testWidgets('clock times go as exact moments, so 10:00 here comes back as 10:00 here', (tester) async {
      final repo = await _open(
        tester,
        _plan([
          _task(
            'tk1',
            days: 1,
            start: _at(2027, 3, 1),
            end: _at(2027, 3, 1),
            from: const TimeOfDay(hour: 10, minute: 0),
            to: const TimeOfDay(hour: 13, minute: 30),
          ),
        ]),
      );
      await _toTasks(tester);
      await _generate(tester);
      final made = repo.created.firstWhere((b) => b['title'] == 'Task tk1');
      expect(made['startDate'], _utc(_at(2027, 3, 1, 10, 0)));
      expect(made['dueDate'], _utc(_at(2027, 3, 1, 13, 30)));
      expect(made['deadline'], made['dueDate']);
      expect(made['startDate'], endsWith('Z'));
      expect(dateOf(made, 'startDate').toLocal(), _at(2027, 3, 1, 10, 0));
    });

    testWidgets('a time on only one end: that end is a moment, the other a day', (tester) async {
      final repo = await _open(
        tester,
        _plan([_task('tk1', days: 2, start: _at(2027, 3, 1), end: _at(2027, 3, 3), to: const TimeOfDay(hour: 17, minute: 0))]),
      );
      await _toTasks(tester);
      await _generate(tester);
      final made = repo.created.firstWhere((b) => b['title'] == 'Task tk1');
      expect(made['startDate'], _at(2027, 3, 1).toIso8601String());
      expect(made['dueDate'], _utc(_at(2027, 3, 3, 17, 0)));
    });

    testWidgets('a milestone is saved at its moment', (tester) async {
      final repo = await _open(
        tester,
        _plan([_task('tk1', days: 1, milestone: true, start: _at(2027, 3, 1), from: const TimeOfDay(hour: 11, minute: 0))]),
      );
      await _toTasks(tester);
      await _generate(tester);
      final made = repo.created.firstWhere((b) => b['title'] == 'Task tk1');
      expect(made['startDate'], _utc(_at(2027, 3, 1, 11, 0)));
      expect(made['dueDate'], _utc(_at(2027, 3, 1, 11, 0)));
    });

    testWidgets('a summary spans its sub-tasks, times included, and so does its phase', (tester) async {
      final repo = await _open(
        tester,
        _plan([
          _task('g', days: 1),
          _task('s1', parent: 'g', days: 1, start: _at(2027, 3, 1), from: const TimeOfDay(hour: 9, minute: 0)),
          _task('s2', parent: 'g', days: 2, after: ['s1'], to: const TimeOfDay(hour: 18, minute: 0)),
        ]),
      );
      await _toTasks(tester);
      await _generate(tester);
      final phase = repo.created.first;
      final summary = repo.created.firstWhere((b) => b['title'] == 'Task g');
      final first = repo.created.firstWhere((b) => b['title'] == 'Task s1');
      final last = repo.created.firstWhere((b) => b['title'] == 'Task s2');
      expect(first['startDate'], _utc(_at(2027, 3, 1, 9, 0)));
      expect(last['dueDate'], _utc(_at(2027, 3, 4, 18, 0))); // s2 follows s1 (1 → 2 Mar) and takes 2 days
      expect(summary['startDate'], first['startDate']);
      expect(summary['dueDate'], last['dueDate']);
      expect(phase['startDate'], first['startDate']);
      expect(phase['dueDate'], last['dueDate']);
    });

    testWidgets('a plan with no fixed days or times is saved exactly as before: days from the plan start, no moments', (tester) async {
      final repo = await _open(
        tester,
        _plan([
          _task('tk1', days: 3),
          _task('tk2', days: 2, after: ['tk1']),
        ]),
      );
      await _toTasks(tester);
      await _generate(tester);
      final one = repo.created.firstWhere((b) => b['title'] == 'Task tk1');
      final two = repo.created.firstWhere((b) => b['title'] == 'Task tk2');
      expect(dateOf(one, 'startDate'), _from(0));
      expect(dateOf(one, 'dueDate'), _from(3));
      expect(dateOf(two, 'startDate'), _from(3));
      expect(dateOf(two, 'dueDate'), _from(5));
      for (final b in repo.created) {
        expect(b['startDate'], isNot(endsWith('Z')));
        expect(b['dueDate'], isNot(endsWith('Z')));
      }
    });

    testWidgets('a pushed task is saved on the day it really starts, not the one that was picked', (tester) async {
      final repo = await _open(
        tester,
        _plan([
          _task('tk1', days: 6),
          _task('tk2', days: 2, after: ['tk1'], start: _from(1), end: _from(3)),
        ]),
      );
      await _toTasks(tester);
      await _generate(tester);
      final two = repo.created.firstWhere((b) => b['title'] == 'Task tk2');
      expect(dateOf(two, 'startDate'), _from(6));
      expect(dateOf(two, 'dueDate'), _from(8));
    });
  });
}
