import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
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
import 'package:nizan_crm/features/it/presentation/screens/widgets/it_task_detail_sheet.dart';
import 'package:nizan_crm/features/it/services/it_service.dart';

// The task dialog: header, the four tabs, Basic Information beside the overview and blockers, the description's
// formatting buttons, subtasks, dependencies, comments — and what each kind of person may change and send.

Project _project({
  String department = 'Marketing',
  bool canManage = true,
  List<String> lead = const [],
}) =>
    Project.fromJson({
      '_id': 'p1',
      'name': 'Lifestyle brand at 2030',
      'status': 'planning',
      'phase': 'discovery',
      'targetDepartment': department,
      'managerId': {'_id': 'm1', 'name': 'Amna'},
      'editMode': 'managed',
      'departments': [
        {'name': department, 'role': 'owner', 'status': 'accepted'},
      ],
      'access': {
        'role': canManage ? 'manager' : 'member',
        'canManage': canManage,
        'editMode': 'managed',
        'canCreateTasks': canManage,
        'canEditAllTasks': canManage,
        'leadDepartments': lead,
        'pendingInvitations': const <String>[],
        'canDecide': false,
      },
    });

ITTask _task(
  String id,
  String title, {
  String description = '',
  int order = 0,
  DateTime? start,
  DateTime? due,
  DateTime? created,
  List<String> predecessors = const [],
  String assignee = '',
  ITTaskStatus status = ITTaskStatus.todo,
  List<ITSubtask> subtasks = const [],
}) =>
    ITTask(
      id: id,
      projectId: 'p1',
      title: title,
      description: description,
      order: order,
      startDate: start,
      dueDate: due,
      createdAt: created,
      predecessorIds: predecessors,
      assigneeId: assignee,
      status: status,
      subtasks: subtasks,
    );

ITTask _discovery({List<String> predecessors = const [], String assignee = '', List<ITSubtask> subtasks = const [], String? description}) => _task(
      'a',
      'Discovery & Planning',
      description: description ?? 'Define goals, scope, and detailed plan for the project discovery phase.\n\nMore detail below.',
      order: 1,
      start: DateTime(2026, 11, 5),
      due: DateTime(2026, 11, 8),
      created: DateTime(2026, 11, 3, 10, 24),
      predecessors: predecessors,
      assignee: assignee,
      subtasks: subtasks,
    );

class _Repo implements IITTaskRepository {
  _Repo(List<ITTask> tasks) : tasks = [...tasks];
  List<ITTask> tasks;
  final updates = <Map<String, dynamic>>[];
  final deleted = <String>[];

  @override
  Future<List<ITTask>> getTasks({String? projectId, String? status, String? assignedTo, String? ticketType, String? severity, String? subTeam, String? search, bool mine = false}) async => tasks;

  @override
  Future<ITTask> updateTask(String id, Map<String, dynamic> data) async {
    updates.add(data);
    var t = tasks.firstWhere((x) => x.id == id);
    if (data['subtasks'] is List) {
      t = t.copyWith(subtasks: [for (final s in data['subtasks'] as List) ITSubtask.fromJson((s as Map).cast<String, dynamic>())]);
    }
    if (data['activityLogs'] is List) {
      t = t.copyWith(activityLogs: [for (final l in data['activityLogs'] as List) ITActivityLog.fromJson((l as Map).cast<String, dynamic>())]);
    }
    if (data['percentComplete'] is num) t = t.copyWith(percentComplete: (data['percentComplete'] as num).toInt());
    tasks = [for (final x in tasks) x.id == id ? t : x];
    return t;
  }

  @override
  Future<void> deleteTask(String id) async => deleted.add(id);

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError('${invocation.memberName}');
}

class _Launcher extends ConsumerWidget {
  const _Launcher({required this.task, required this.all, required this.onResult});
  final ITTask task;
  final List<ITTask> all;
  final ValueChanged<bool?> onResult;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
        body: Center(
          child: ElevatedButton(
            key: const Key('open'),
            onPressed: () async => onResult(await showITTaskDetailSheet(context, ref, task: task, allTasks: all)),
            child: const Text('open'),
          ),
        ),
      );
}

class _Opened {
  _Opened(this.repo);
  final _Repo repo;
  bool? result;
  bool closed = false;
}

/// Opens the dialog (a bottom sheet on a phone) for [task], with [all] as its project's tasks.
Future<_Opened> _open(
  WidgetTester tester, {
  ITTask? task,
  List<ITTask>? all,
  Project? project,
  Size size = const Size(1300, 1000),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  // a fresh tree: a second open in one test would otherwise leave the first dialog underneath
  await tester.pumpWidget(const SizedBox.shrink());
  final t = task ?? _discovery();
  final list = all ?? [t];
  final repo = _Repo(list);
  final out = _Opened(repo);
  final p = project ?? _project();
  await tester.pumpWidget(ProviderScope(
    overrides: <Override>[
      authSessionProvider.overrideWithValue(AuthSession(token: 't', userId: 'u', name: 'U', email: 'u@x', role: 'crm', employeeId: 'e1')),
      projectsProvider.overrideWith((ref) async => [p]),
      projectEmployeesProvider('p1').overrideWith((ref) => const <Employee>[]),
      itTaskRepositoryProvider.overrideWithValue(repo),
    ],
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      home: _Launcher(task: t, all: list, onResult: (r) {
        out.result = r;
        out.closed = true;
      }),
    ),
  ));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('open')));
  await tester.pumpAndSettle();
  return out;
}

Future<void> _tab(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(Key('task_tab_$key')));
  await tester.pumpAndSettle();
}

Finder _in(String key, String text) => find.descendant(of: find.byKey(Key(key)), matching: find.text(text));

void main() {
  group('the header', () {
    testWidgets('key and priority chips, the work-breakdown number, the title and what the task is for', (tester) async {
      await _open(tester);
      expect(_in('task_key_chip', 'IT-a'), findsOneWidget);
      expect(_in('task_priority_chip', 'P2 · Medium'), findsOneWidget);
      expect(find.byKey(const Key('task_wbs_number')), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const Key('task_wbs_number'))).data, '1.');
      expect(tester.widget<TextField>(find.byKey(const Key('task_title'))).controller!.text, 'Discovery & Planning');
      expect(tester.widget<Text>(find.byKey(const Key('task_subtitle'))).data, 'Define goals, scope, and detailed plan for the project discovery phase.');
    });

    testWidgets('the number is the task\'s place in the plan, and absent when it is not in the list it was opened from', (tester) async {
      final design = _task('b', 'Design', order: 2);
      await _open(tester, task: design, all: [_discovery(), design]);
      expect(tester.widget<Text>(find.byKey(const Key('task_wbs_number'))).data, '2.');
      await _open(tester, task: design, all: [design]);
      expect(tester.widget<Text>(find.byKey(const Key('task_wbs_number'))).data, '1.'); // alone in its own list
      await _open(tester, task: design, all: const []);
      expect(find.byKey(const Key('task_wbs_number')), findsNothing);
    });

    testWidgets('the line under the title is plain words (no Markdown marks), and follows the description as it is edited', (tester) async {
      await _open(tester, task: _discovery(description: '## **Goal:** ship the brand book\nmore'));
      expect(tester.widget<Text>(find.byKey(const Key('task_subtitle'))).data, 'Goal: ship the brand book');

      await tester.enterText(find.byKey(const Key('task_description')), '- first item\n- second');
      await tester.pump();
      expect(tester.widget<Text>(find.byKey(const Key('task_subtitle'))).data, 'first item');

      await tester.enterText(find.byKey(const Key('task_description')), '');
      await tester.pump();
      expect(find.byKey(const Key('task_subtitle')), findsNothing);
    });

    testWidgets('the priority chip follows the priority picked', (tester) async {
      await _open(tester);
      await tester.tap(find.byKey(const Key('task_priority')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Critical').last);
      await tester.pumpAndSettle();
      expect(_in('task_priority_chip', 'P0 · Critical'), findsOneWidget);
    });

    testWidgets('the ✕ closes it without saving', (tester) async {
      final o = await _open(tester);
      await tester.tap(find.byKey(const Key('task_close')));
      await tester.pumpAndSettle();
      expect(o.closed, isTrue);
      expect(o.result, isNull);
      expect(o.repo.updates, isEmpty);
    });
  });

  group('the tabs', () {
    testWidgets('Details, Subtasks, Dependencies, Activity & Comments — with their counts', (tester) async {
      final blocker = _task('p', 'Brand audit', due: DateTime(2026, 11, 2));
      await _open(tester,
          task: _discovery(predecessors: ['p'], subtasks: const [ITSubtask(id: 's1', title: 'One'), ITSubtask(id: 's2', title: 'Two', isCompleted: true)]),
          all: [blocker]);
      expect(_in('task_tab_details', 'Details'), findsOneWidget);
      expect(_in('task_tab_subtasks', 'Subtasks (2)'), findsOneWidget);
      expect(_in('task_tab_dependencies', 'Dependencies (1)'), findsOneWidget);
      expect(_in('task_tab_activity', 'Activity & Comments'), findsOneWidget);
    });

    testWidgets('a new task has none: Subtasks (0), Dependencies (0)', (tester) async {
      await _open(tester);
      expect(_in('task_tab_subtasks', 'Subtasks (0)'), findsOneWidget);
      expect(_in('task_tab_dependencies', 'Dependencies (0)'), findsOneWidget);
    });
  });

  group('details', () {
    testWidgets('Basic Information: status, priority, assignee, dates, hours, progress, description', (tester) async {
      await _open(tester);
      final card = find.byKey(const Key('task_basic_info'));
      for (final t in ['Basic Information', 'Status', 'Priority', 'Start Date', 'Due Date', 'Estimated Hours', 'Actual Hours Spent', 'Progress', 'Description & Acceptance Criteria']) {
        expect(find.descendant(of: card, matching: find.text(t)), findsOneWidget, reason: t);
      }
      expect(find.descendant(of: card, matching: find.text('To Do')), findsOneWidget);
      expect(find.descendant(of: card, matching: find.text('Medium')), findsOneWidget);
      expect(find.descendant(of: card, matching: find.text('Unassigned')), findsOneWidget);
      expect(find.descendant(of: card, matching: find.text('05 Nov 2026')), findsOneWidget);
      expect(find.descendant(of: card, matching: find.text('08 Nov 2026')), findsOneWidget);
      expect(find.text('e.g. 40'), findsOneWidget);
      expect(find.text('e.g. 0'), findsOneWidget);
      expect(find.descendant(of: card, matching: find.text('0%')), findsOneWidget);
    });

    testWidgets('a task without dates says "Select date"', (tester) async {
      await _open(tester, task: _task('a', 'Bare', order: 1));
      expect(find.text('Select date'), findsNWidgets(2));
    });

    testWidgets('Task Overview: phase, project, manager, created, and the completion', (tester) async {
      await _open(tester);
      final card = find.byKey(const Key('task_overview'));
      for (final t in ['Task Overview', 'Phase', 'Discovery', 'Project', 'Lifestyle brand at 2030', 'Manager', 'Amna', 'Created', '03 Nov 2026, 10:24 AM']) {
        expect(find.descendant(of: card, matching: find.text(t)), findsOneWidget, reason: t);
      }
      expect(_in('task_completion', 'Completion'), findsOneWidget);
      expect(_in('task_completion', '0%'), findsOneWidget);
    });

    testWidgets('moving the progress (or choosing Completed) moves the completion with it', (tester) async {
      await _open(tester);
      await tester.drag(find.byKey(const Key('task_progress')), const Offset(200, 0));
      await tester.pump();
      final pct = tester.widget<Text>(find.byKey(const Key('task_progress_text'))).data!;
      expect(pct, isNot('0%'));
      expect(_in('task_completion', pct), findsOneWidget);

      await tester.tap(find.byKey(const Key('task_status')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Completed / Done').last);
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(find.byKey(const Key('task_progress_text'))).data, '100%');
      expect(_in('task_completion', '100%'), findsOneWidget);
    });

    testWidgets('a task created without a date reads "—"; a task that is in no project yet falls back gracefully', (tester) async {
      await _open(tester, task: _task('a', 'Bare', order: 1));
      expect(find.descendant(of: find.byKey(const Key('task_overview')), matching: find.text('—')), findsOneWidget);
    });

    testWidgets('Predecessor Dependencies card: says what it is for, and adds a dependency', (tester) async {
      final other = _task('b', 'Design', order: 2, due: DateTime(2026, 11, 20));
      await _open(tester, all: [_discovery(), other]);
      final card = find.byKey(const Key('task_dependencies_card'));
      expect(find.descendant(of: card, matching: find.text('Predecessor Dependencies (Blockers)')), findsOneWidget);
      expect(find.descendant(of: card, matching: find.text('Tasks that must be completed before this one can start.')), findsOneWidget);

      await tester.tap(find.byKey(const Key('add_dependency')));
      await tester.pumpAndSettle();
      expect(find.text('Select Predecessor Task'), findsOneWidget);
      expect(find.byKey(const Key('dependency_option_a')), findsNothing); // not itself
      await tester.tap(find.byKey(const Key('dependency_option_b')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('blocker_chip_b')), findsOneWidget);
      expect(_in('task_tab_dependencies', 'Dependencies (1)'), findsOneWidget);

      await tester.ensureVisible(find.byKey(const Key('blocker_chip_b')));
      await tester.tap(find.descendant(of: find.byKey(const Key('blocker_chip_b')), matching: find.byTooltip('Delete')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('blocker_chip_b')), findsNothing);
      expect(_in('task_tab_dependencies', 'Dependencies (0)'), findsOneWidget);
    });
  });

  group('the description\'s formatting buttons', () {
    TextEditingController desc(WidgetTester tester) => tester.widget<TextField>(find.byKey(const Key('task_description'))).controller!;

    testWidgets('Bold and Italic wrap the selection; pressing again takes it off', (tester) async {
      await _open(tester, task: _discovery(description: 'hello world'));
      final c = desc(tester);
      c.selection = const TextSelection(baseOffset: 0, extentOffset: 5);
      await tester.tap(find.byKey(const Key('md_bold')));
      await tester.pump();
      expect(c.text, '**hello** world');
      await tester.tap(find.byKey(const Key('md_bold')));
      await tester.pump();
      expect(c.text, 'hello world');
      await tester.tap(find.byKey(const Key('md_italic')));
      await tester.pump();
      expect(c.text, '*hello* world');
    });

    testWidgets('bullets, numbers and a link', (tester) async {
      await _open(tester, task: _discovery(description: 'alpha\nbeta'));
      final c = desc(tester);
      c.selection = const TextSelection(baseOffset: 0, extentOffset: 10);
      await tester.tap(find.byKey(const Key('md_bullets')));
      await tester.pump();
      expect(c.text, '- alpha\n- beta');
      await tester.tap(find.byKey(const Key('md_numbered')));
      await tester.pump();
      expect(c.text, '1. alpha\n2. beta');

      c.selection = const TextSelection(baseOffset: 3, extentOffset: 8);
      await tester.tap(find.byKey(const Key('md_link')));
      await tester.pump();
      expect(c.text, contains('[alpha](https://)'));
    });

    testWidgets('Preview shows the text as formatted; the buttons rest while previewing; Edit comes back', (tester) async {
      await _open(tester, task: _discovery(description: 'a **bold** word'));
      await tester.tap(find.byKey(const Key('md_preview')));
      await tester.pumpAndSettle();
      expect(find.byType(MarkdownBody), findsOneWidget);
      expect(find.byKey(const Key('task_description')), findsNothing);
      expect(tester.widget<IconButton>(find.byKey(const Key('md_bold'))).onPressed, isNull);
      expect(find.text('Edit'), findsOneWidget);

      await tester.tap(find.byKey(const Key('md_preview')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('task_description')), findsOneWidget);
      expect(desc(tester).text, 'a **bold** word');
    });

    testWidgets('an empty description previews as "No description yet."', (tester) async {
      await _open(tester, task: _discovery(description: ''));
      await tester.tap(find.byKey(const Key('md_preview')));
      await tester.pumpAndSettle();
      expect(find.text('No description yet.'), findsOneWidget);
    });
  });

  group('saving', () {
    testWidgets('sends what was changed and closes, telling the caller it saved', (tester) async {
      final o = await _open(tester);
      await tester.enterText(find.byKey(const Key('task_title')), 'Discovery and plan');
      await tester.enterText(find.byKey(const Key('task_description')), 'New scope');
      await tester.enterText(find.byKey(const Key('task_est_hours')), '12.5');
      await tester.ensureVisible(find.byKey(const Key('task_priority'))); // typing scrolled the page
      await tester.tap(find.byKey(const Key('task_priority')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('High').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('task_save')));
      await tester.pumpAndSettle();

      expect(o.result, isTrue);
      final sent = o.repo.updates.single;
      expect(sent['title'], 'Discovery and plan');
      expect(sent['description'], 'New scope');
      expect(sent['severity'], 'p1');
      expect(sent['estimatedHours'], 12.5);
      expect(sent['actualHours'], 0);
      expect(sent['status'], 'todo');
      expect(sent['percentComplete'], 0);
      expect(sent['assignedTo'], isNull);
      expect(DateTime.parse(sent['startDate'] as String), DateTime(2026, 11, 5));
      expect(DateTime.parse(sent['dueDate'] as String), DateTime(2026, 11, 8));
      expect(sent['predecessorIds'], isEmpty);
    });

    testWidgets('Cancel closes without sending anything', (tester) async {
      final o = await _open(tester);
      await tester.enterText(find.byKey(const Key('task_title')), 'Changed my mind');
      await tester.tap(find.byKey(const Key('task_cancel')));
      await tester.pumpAndSettle();
      expect(o.closed, isTrue);
      expect(o.result, isNull);
      expect(o.repo.updates, isEmpty);
    });

    testWidgets('a dependency added in the dialog is part of what is saved', (tester) async {
      final other = _task('b', 'Design', order: 2);
      final o = await _open(tester, all: [_discovery(), other]);
      await tester.tap(find.byKey(const Key('add_dependency')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('dependency_option_b')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('task_save')));
      await tester.pumpAndSettle();
      expect(o.repo.updates.single['predecessorIds'], ['b']);
    });
  });

  group('who may change what', () {
    testWidgets('someone who only reports progress: the plan is locked, status / hours / progress are not, and only those are sent', (tester) async {
      final o = await _open(tester, task: _discovery(assignee: 'e1'), project: _project(canManage: false));
      expect(find.textContaining('The project manager plans this task'), findsOneWidget);
      bool locked(String key) => find.ancestor(of: find.byKey(Key(key)), matching: find.byWidgetPredicate((w) => w is IgnorePointer && w.ignoring)).evaluate().isNotEmpty;
      for (final k in ['task_title', 'task_priority', 'task_start', 'task_due', 'task_est_hours', 'task_description', 'add_dependency']) {
        expect(locked(k), isTrue, reason: '$k is locked');
      }
      for (final k in ['task_status', 'task_actual_hours', 'task_progress']) {
        expect(locked(k), isFalse, reason: '$k is open');
      }
      await tester.enterText(find.byKey(const Key('task_actual_hours')), '3');
      await tester.tap(find.byKey(const Key('task_save')));
      await tester.pumpAndSettle();
      expect(o.repo.updates.single.keys.toSet(), {'status', 'actualHours', 'percentComplete'});
      expect(o.repo.updates.single['actualHours'], 3);
    });

    testWidgets('someone not on the task: view only, no Save, no Delete', (tester) async {
      await _open(tester, task: _discovery(assignee: 'someone-else'), project: _project(canManage: false));
      expect(find.textContaining('View only'), findsOneWidget);
      expect(find.byKey(const Key('task_save')), findsNothing);
      expect(find.byKey(const Key('task_delete')), findsNothing);
      expect(find.byKey(const Key('task_cancel')), findsOneWidget);
    });

    testWidgets('a manager can delete: asks first, then removes it and closes', (tester) async {
      final o = await _open(tester);
      await tester.tap(find.byKey(const Key('task_delete')));
      await tester.pumpAndSettle();
      expect(find.text('Delete Task?'), findsOneWidget);
      // saying no leaves everything as it was
      await tester.tap(find.widgetWithText(TextButton, 'Cancel').last);
      await tester.pumpAndSettle();
      expect(o.repo.deleted, isEmpty);
      expect(o.closed, isFalse);

      await tester.tap(find.byKey(const Key('task_delete')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();
      expect(o.repo.deleted, ['a']);
      expect(o.result, isTrue);
    });
  });

  group('IT projects', () {
    testWidgets('keep Severity, Sub-Team and Ticket Type; a company project has Priority and none of those', (tester) async {
      await _open(tester, project: _project(department: 'IT'));
      expect(find.text('Severity'), findsOneWidget);
      expect(find.byKey(const Key('task_subteam')), findsOneWidget);
      expect(find.byKey(const Key('task_type')), findsOneWidget);
      expect(_in('task_key_chip', 'IT-a • Feature'), findsOneWidget);

      await _open(tester);
      expect(find.text('Priority'), findsOneWidget);
      expect(find.text('Severity'), findsNothing);
      expect(find.byKey(const Key('task_subteam')), findsNothing);
      expect(find.byKey(const Key('task_type')), findsNothing);
    });
  });

  group('dependencies', () {
    final blocker = _task('p', 'Brand audit', due: DateTime(2026, 11, 10), start: DateTime(2026, 11, 1));
    final finished = _task('f', 'Market study', due: DateTime(2026, 11, 12), status: ITTaskStatus.closed);
    final waiter = _task('b', 'Design', order: 2, predecessors: ['a']);

    testWidgets('a predecessor that ends after this task starts is a blocker: the banner says so, the list marks its due date', (tester) async {
      await _open(tester, task: _discovery(predecessors: ['p']), all: [_discovery(predecessors: ['p']), blocker]);
      expect(find.byKey(const Key('task_blocker_banner')), findsOneWidget);
      expect(find.textContaining('Blocked by: IT-p (Brand audit) due Nov 10'), findsOneWidget);

      await _tab(tester, 'dependencies');
      expect(find.byKey(const Key('dep_row_p')), findsOneWidget);
      expect(_in('dep_row_p', 'Due 10 Nov 2026'), findsOneWidget);
      expect(tester.widget<Text>(find.descendant(of: find.byKey(const Key('dep_row_p')), matching: find.text('Due 10 Nov 2026'))).style!.color, Colors.red.shade700);
    });

    testWidgets('a finished predecessor is not blocking: no banner, due date not flagged', (tester) async {
      await _open(tester, task: _discovery(predecessors: ['f']), all: [_discovery(predecessors: ['f']), finished]);
      expect(find.byKey(const Key('task_blocker_banner')), findsNothing);
      await _tab(tester, 'dependencies');
      expect(tester.widget<Text>(find.descendant(of: find.byKey(const Key('dep_row_f')), matching: find.text('Due 12 Nov 2026'))).style!.color, isNot(Colors.red.shade700));
    });

    testWidgets('removing a blocker clears the banner and the count', (tester) async {
      await _open(tester, task: _discovery(predecessors: ['p']), all: [_discovery(predecessors: ['p']), blocker]);
      await _tab(tester, 'dependencies');
      await tester.tap(find.byKey(const Key('dep_remove_p')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('dep_row_p')), findsNothing);
      expect(find.text('No blockers. This task can start any time.'), findsOneWidget);
      expect(find.byKey(const Key('task_blocker_banner')), findsNothing);
      expect(_in('task_tab_dependencies', 'Dependencies (0)'), findsOneWidget);
    });

    testWidgets('"Waiting on this task" lists what has this one as a predecessor; empty says so', (tester) async {
      await _open(tester, all: [_discovery(), waiter]);
      await _tab(tester, 'dependencies');
      expect(find.descendant(of: find.byKey(const Key('dependencies_waiting')), matching: find.byKey(const Key('dep_row_b'))), findsOneWidget);
      expect(_in('dependencies_waiting', 'Design'), findsOneWidget);

      await _open(tester);
      await _tab(tester, 'dependencies');
      expect(find.text('Nothing is waiting on this task.'), findsOneWidget);
    });

    testWidgets('a predecessor that was deleted from the project can still be removed', (tester) async {
      await _open(tester, task: _discovery(predecessors: ['gone']), all: [_discovery(predecessors: ['gone'])]);
      await _tab(tester, 'dependencies');
      expect(find.text('A task that is no longer in this project'), findsOneWidget);
      await tester.tap(find.descendant(of: find.byKey(const Key('dep_row_gone')), matching: find.byIcon(Icons.close)));
      await tester.pumpAndSettle();
      expect(_in('task_tab_dependencies', 'Dependencies (0)'), findsOneWidget);
    });

    testWidgets('the Add Dependency button on this tab works like the one on Details', (tester) async {
      await _open(tester, all: [_discovery(), waiter]);
      await _tab(tester, 'dependencies');
      await tester.tap(find.byKey(const Key('add_dependency')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('dependency_option_b')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('dep_row_b')), findsWidgets);
      expect(_in('task_tab_dependencies', 'Dependencies (1)'), findsOneWidget);
    });
  });

  group('subtasks and comments', () {
    testWidgets('a subtask is added, shown, ticked (which moves the progress), and counted', (tester) async {
      final o = await _open(tester);
      await _tab(tester, 'subtasks');
      expect(find.text('No subtasks or checklist items yet.'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('subtask_input')), 'Unit tests pass');
      await tester.tap(find.byKey(const Key('subtask_add')));
      await tester.pumpAndSettle();
      expect(find.text('Unit tests pass'), findsOneWidget);
      expect(_in('task_tab_subtasks', 'Subtasks (1)'), findsOneWidget);
      expect(tester.widget<TextField>(find.byKey(const Key('subtask_input'))).controller!.text, isEmpty);
      expect(find.text('0 of 1 done'), findsOneWidget);

      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();
      expect(find.text('1 of 1 done'), findsOneWidget);
      expect(o.repo.updates.last['percentComplete'], 100);

      await tester.tap(find.byTooltip('Remove'));
      await tester.pumpAndSettle();
      expect(find.text('Unit tests pass'), findsNothing);
      expect(_in('task_tab_subtasks', 'Subtasks (0)'), findsOneWidget);
    });

    testWidgets('a blank subtask is not added', (tester) async {
      final o = await _open(tester);
      await _tab(tester, 'subtasks');
      await tester.enterText(find.byKey(const Key('subtask_input')), '   ');
      await tester.tap(find.byKey(const Key('subtask_add')));
      await tester.pumpAndSettle();
      expect(o.repo.updates, isEmpty);
    });

    testWidgets('a comment is posted and shown, with the box cleared', (tester) async {
      await _open(tester);
      await _tab(tester, 'activity');
      expect(find.text('No activity or comments yet.'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('comment_input')), 'Waiting on the client');
      await tester.tap(find.byKey(const Key('comment_post')));
      await tester.pumpAndSettle();
      expect(find.text('Waiting on the client'), findsOneWidget);
      expect(find.text('Current User'), findsOneWidget);
      expect(tester.widget<TextField>(find.byKey(const Key('comment_input'))).controller!.text, isEmpty);
    });
  });

  group('layout', () {
    testWidgets('wide: Basic Information on the left, overview over blockers on the right', (tester) async {
      await _open(tester);
      final basic = tester.getRect(find.byKey(const Key('task_basic_info')));
      final overview = tester.getRect(find.byKey(const Key('task_overview')));
      final deps = tester.getRect(find.byKey(const Key('task_dependencies_card')));
      expect(overview.top, basic.top);
      expect(overview.left, greaterThan(basic.right - 1));
      expect(deps.top, greaterThan(overview.bottom - 1));
      expect(deps.left, overview.left);
      expect(basic.width, greaterThan(overview.width));
      expect(tester.takeException(), isNull);
    });

    testWidgets('a phone gets a sheet: one column, the tabs scroll, nothing overflows', (tester) async {
      await _open(tester, size: const Size(390, 844));
      final basic = tester.getRect(find.byKey(const Key('task_basic_info')));
      expect(basic.left, greaterThanOrEqualTo(0));
      expect(basic.right, lessThanOrEqualTo(390));
      expect(tester.widget<TabBar>(find.byType(TabBar)).isScrollable, isTrue);
      await tester.ensureVisible(find.byKey(const Key('task_overview')));
      await tester.pump();
      final overview = tester.getRect(find.byKey(const Key('task_overview')));
      final basicNow = tester.getRect(find.byKey(const Key('task_basic_info'))); // the page has scrolled
      expect(overview.top, greaterThan(basicNow.bottom - 1)); // below, not beside
      expect(overview.left, basicNow.left);
      expect(find.byKey(const Key('task_save')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
