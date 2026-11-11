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
import 'package:nizan_crm/features/it/domain/repositories/it_task_repository.dart';
import 'package:nizan_crm/features/it/presentation/controllers/it_tasks_notifier.dart';
import 'package:nizan_crm/features/it/presentation/screens/widgets/it_interactive_gantt.dart';
import 'package:nizan_crm/features/it/services/it_service.dart';

// The timeline's bars: a bar says WHICH task it is. The title goes inside the bar when it fits, otherwise beside
// it (never a cut-off "IT-A2…"); the ticket key lives in the left list and the tooltip.

final _today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
DateTime _d(int offset) => _today.add(Duration(days: offset));

ITTask _task(String id, String title, {required int from, required int days, String assignee = '', List<String> after = const []}) => ITTask(
      id: id,
      projectId: 'p1',
      title: title,
      startDate: _d(from),
      dueDate: _d(from + days - 1),
      assigneeName: assignee,
      predecessorIds: after,
    );

class _Repo implements IITTaskRepository {
  _Repo(this.tasks);
  final List<ITTask> tasks;
  @override
  Future<List<ITTask>> getTasks({String? projectId, String? status, String? assignedTo, String? ticketType, String? severity, String? subTeam, String? search, bool mine = false}) async => tasks;
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError('${invocation.memberName}');
}

Future<void> _pump(WidgetTester tester, List<ITTask> tasks, {GanttZoomScale zoom = GanttZoomScale.week}) async {
  tester.view.physicalSize = const Size(1500, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
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
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpWidget(ProviderScope(
    overrides: <Override>[
      authSessionProvider.overrideWithValue(AuthSession(token: 't', userId: 'u', name: 'U', email: 'u@x', role: 'crm', employeeId: 'e1')),
      projectsProvider.overrideWith((ref) async => [project]),
      projectEmployeesProvider('p1').overrideWith((ref) => const <Employee>[]),
      itTaskRepositoryProvider.overrideWithValue(_Repo(tasks)),
    ],
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(body: ITInteractiveGantt(tasks: tasks, allTasks: tasks, projectId: 'p1', zoomScale: zoom)),
    ),
  ));
  await tester.pumpAndSettle();
}

Finder _bar(String id) => find.byKey(Key('gantt_bar_$id'));
Finder _inside(String id) => find.byKey(Key('gantt_bar_text_$id'));
Finder _label(String id) => find.byKey(Key('gantt_label_$id'));
String _text(WidgetTester tester, Finder f) => tester.widget<Text>(find.descendant(of: f, matching: find.byType(Text)).first).data!;

void main() {
  // week zoom: 110px a week, about 15.7px a day
  testWidgets('a bar too short for its title shows nothing inside; the title is written beside it, level with it', (tester) async {
    await _pump(tester, [_task('a', 'Discovery & Planning', from: 3, days: 3)]); // ~47px
    expect(_inside('a'), findsNothing);
    expect(_label('a'), findsOneWidget);
    expect(_text(tester, _label('a')), 'Discovery & Planning');

    final bar = tester.getRect(_bar('a'));
    final label = tester.getRect(_label('a'));
    expect(label.left, greaterThanOrEqualTo(bar.right + 6));
    expect(label.top, bar.top);
    expect(label.height, bar.height);
  });

  testWidgets('a bar that can hold the title shows it inside, and no label beside it', (tester) async {
    await _pump(tester, [_task('a', 'Launch', from: 3, days: 30)]); // ~470px
    expect(_label('a'), findsNothing);
    expect(_inside('a'), findsOneWidget);
    expect(tester.widget<Text>(_inside('a')).data, 'Launch');
    final bar = tester.getRect(_bar('a'));
    final text = tester.getRect(_inside('a'));
    expect(text.left, greaterThanOrEqualTo(bar.left));
    expect(text.right, lessThanOrEqualTo(bar.right));
    expect((text.center.dy - bar.center.dy).abs(), lessThan(1.5), reason: 'the title is centred in the bar, not stuck to its top');
  });

  testWidgets('the ticket key is not in the bar any more (it is in the left list and the tooltip)', (tester) async {
    await _pump(tester, [_task('abcd1234', 'Launch', from: 3, days: 30), _task('wxyz9876', 'Discovery & Planning', from: 3, days: 3)]);
    for (final id in ['abcd1234', 'wxyz9876']) {
      expect(find.descendant(of: _bar(id), matching: find.textContaining('IT-')), findsNothing, reason: id);
    }
    expect(find.descendant(of: _label('wxyz9876'), matching: find.textContaining('IT-')), findsNothing);

    final tip = tester.widget<Tooltip>(find.descendant(of: _bar('wxyz9876'), matching: find.byType(Tooltip))).message!;
    expect(tip, contains('IT-9876'));
    expect(tip, contains('Discovery & Planning'));
    expect(tip, contains('Click to view details / drag to reschedule'));
    // the label beside it says the same on hover
    expect(tester.widget<Tooltip>(find.descendant(of: _label('wxyz9876'), matching: find.byType(Tooltip))).message, tip);
  });

  testWidgets('a long title in a middling bar goes beside it, not cut short inside it', (tester) async {
    await _pump(tester, [_task('a', 'Requirements & Scope Approval', from: 3, days: 8)]); // ~126px; the title needs ~190
    expect(_inside('a'), findsNothing);
    expect(_text(tester, _label('a')), 'Requirements & Scope Approval');
  });

  testWidgets('a bar with room for the title and the assignee shows both; with room for the title only, just the title', (tester) async {
    await _pump(tester, [
      _task('wide', 'Launch', from: 3, days: 30, assignee: 'Meera Nair'),
      _task('snug', 'Build', from: 40, days: 6, assignee: 'Bartholomew Stone'), // ~94px: the title fits, the long name does not
    ]);
    expect(find.descendant(of: _bar('wide'), matching: find.text('Meera')), findsOneWidget);
    expect(_inside('snug'), findsOneWidget);
    expect(_label('snug'), findsNothing);
    expect(find.descendant(of: _bar('snug'), matching: find.text('Bartholomew')), findsNothing);
  });

  testWidgets('a one-day bar (kept at its minimum width) is labelled beside it', (tester) async {
    await _pump(tester, [_task('a', 'Sign-off', from: 5, days: 1)]);
    expect(tester.getRect(_bar('a')).width, 34);
    expect(_inside('a'), findsNothing);
    expect(_text(tester, _label('a')), 'Sign-off');
  });

  testWidgets('a bar near the end of the timeline puts its label on the LEFT when it would not fit on the right', (tester) async {
    await _pump(tester, [
      _task('first', 'Kick-off', from: 0, days: 3),
      _task('last', 'Final brand guidelines review, sign-off and handover', from: 60, days: 2),
    ]);
    final bar = tester.getRect(_bar('last'));
    final label = tester.getRect(_label('last'));
    expect(label.right, lessThanOrEqualTo(bar.left - 6));
    expect(tester.widget<Text>(find.descendant(of: _label('last'), matching: find.byType(Text)).first).textAlign, TextAlign.right);
    // an early bar is unaffected: label on its right
    expect(tester.getRect(_label('first')).left, greaterThan(tester.getRect(_bar('first')).right));
  });

  testWidgets('zooming in widens the bars, and a label that was beside its bar moves inside', (tester) async {
    final tasks = [_task('a', 'Planning', from: 3, days: 4)];
    await _pump(tester, tasks); // ~63px at week zoom
    expect(_inside('a'), findsNothing);
    expect(_label('a'), findsOneWidget);

    await _pump(tester, tasks, zoom: GanttZoomScale.day); // 44px a day → 176px
    expect(_label('a'), findsNothing);
    expect(tester.widget<Text>(_inside('a')).data, 'Planning');
  });

  testWidgets('a blocked task keeps its lock on the bar while its title is beside it', (tester) async {
    await _pump(tester, [
      _task('pre', 'Research', from: 0, days: 3),
      _task('a', 'Discovery & Planning', from: 5, days: 3, after: ['pre']),
    ]);
    expect(find.descendant(of: _bar('a'), matching: find.byIcon(Icons.lock_clock)), findsOneWidget);
    expect(_inside('a'), findsNothing);
    expect(_label('a'), findsOneWidget);
    expect(find.descendant(of: _bar('pre'), matching: find.byIcon(Icons.lock_clock)), findsNothing);
  });

  testWidgets('clicking the label opens the task, same as clicking the bar', (tester) async {
    await _pump(tester, [_task('a', 'Discovery & Planning', from: 3, days: 3)]);
    await tester.ensureVisible(_label('a'));
    await tester.tap(_label('a'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('task_title')), findsOneWidget);
    expect(tester.widget<TextField>(find.byKey(const Key('task_title'))).controller!.text, 'Discovery & Planning');

    await tester.tap(find.byKey(const Key('task_close')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(_bar('a'));
    await tester.tap(_bar('a'));
    // the bar also listens for a double-click, so a single click is held back for a moment
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('task_title')), findsOneWidget);
  });

  testWidgets('a task with no dates still shows its "Set Schedule" prompt and no label', (tester) async {
    await _pump(tester, [ITTask(id: 'u', projectId: 'p1', title: 'Undated')]);
    expect(find.textContaining('Set Schedule for'), findsOneWidget);
    expect(_bar('u'), findsNothing);
    expect(_label('u'), findsNothing);
  });
}
