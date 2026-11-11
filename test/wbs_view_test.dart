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
import 'package:nizan_crm/features/it/presentation/screens/widgets/it_wbs_view.dart';
import 'package:nizan_crm/features/it/services/it_service.dart';

// The WBS tab: the strip (ring, counts, project status), Tree / Table, search, filter, export, and the rows.

Project _project({String department = 'Management', bool canManage = true}) => Project.fromJson({
      '_id': 'p1',
      'name': 'Lifestyle brand at 2030',
      'status': 'planning',
      'priority': 'medium',
      'targetDepartment': department,
      'managerId': {'_id': 'm1', 'name': 'Amna'},
      'editMode': 'managed',
      'departments': [
        {'name': department, 'role': 'owner', 'status': 'accepted'}
      ],
      'access': {
        'role': canManage ? 'manager' : 'viewer',
        'canManage': canManage,
        'editMode': 'managed',
        'canCreateTasks': canManage,
        'canEditAllTasks': canManage,
        'leadDepartments': <String>[],
        'pendingInvitations': <String>[],
        'canDecide': false,
      },
    });

ITTask _t(
  String id,
  String title, {
  String? parent,
  int order = 0,
  int pct = 0,
  String owner = '',
  String ownerName = '',
  ITTaskStatus status = ITTaskStatus.todo,
  DateTime? start,
  DateTime? due,
}) =>
    ITTask(
      id: id,
      projectId: 'p1',
      title: title,
      parentTaskId: parent,
      order: order,
      percentComplete: pct,
      assigneeId: owner,
      assigneeName: ownerName,
      status: status,
      startDate: start,
      dueDate: due,
    );

List<ITTask> _plan() => [
      _t('p1', 'Discovery & Planning', order: 1, start: DateTime(2026, 11, 5), due: DateTime(2026, 11, 8)),
      _t('t11', 'Requirements & Scope Approval', parent: 'p1', order: 1, owner: 'e1', ownerName: 'Adithya', pct: 100, status: ITTaskStatus.closed, start: DateTime(2026, 11, 5), due: DateTime(2026, 11, 8)),
      _t('t12', 'Stakeholder Alignment', parent: 'p1', order: 2, owner: 'e2', ownerName: 'Amna Rahman', pct: 50, status: ITTaskStatus.inProgress, start: DateTime(2026, 11, 5), due: DateTime(2026, 11, 8)),
      _t('p2', 'Sourcing & Procurement', order: 2),
      _t('t21', 'Vendor Contracts & Orders', parent: 'p2', order: 1, owner: 'e1', ownerName: 'Adithya'),
      _t('p3', 'Launch & Handoff', order: 3),
    ];

class _Repo implements IITTaskRepository {
  _Repo(this.tasks);
  final List<ITTask> tasks;
  final deleted = <String>[];
  final updates = <String, Map<String, dynamic>>{};
  @override
  Future<ITTask> updateTask(String id, Map<String, dynamic> data) async {
    updates[id] = data;
    final t = tasks.firstWhere((x) => x.id == id);
    return t.copyWith(order: (data['order'] as num?)?.toInt());
  }

  @override
  Future<List<ITTask>> getTasks({String? projectId, String? status, String? assignedTo, String? ticketType, String? severity, String? subTeam, String? search, bool mine = false}) async => tasks;
  @override
  Future<void> deleteTask(String id) async => deleted.add(id);
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError('${invocation.memberName}');
}

class _Export {
  final calls = <({String kind, String file, String title, List<String> headers, List<List<dynamic>> rows})>[];
  Future<void> call(String kind, String file, String title, List<String> headers, List<List<dynamic>> rows) async {
    calls.add((kind: kind, file: file, title: title, headers: headers, rows: rows));
  }
}

_Repo? _lastRepo; // the repository of the page just pumped

/// The real screen keeps the project's tasks loaded in their notifier; this page only shows the list it is given, so load them.
Future<void> _loaded(WidgetTester tester) async {
  final container = ProviderScope.containerOf(tester.element(find.byType(ITWbsView)));
  await container.read(itProjectTasksControllerProvider('p1').future);
}

Future<_Export> _pump(
  WidgetTester tester, {
  List<ITTask>? tasks,
  Project? project,
  Size size = const Size(1500, 1100),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final list = tasks ?? _plan();
  final export = _Export();
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpWidget(ProviderScope(
    overrides: <Override>[
      authSessionProvider.overrideWithValue(AuthSession(token: 't', userId: 'u', name: 'U', email: 'u@x', role: 'crm', employeeId: 'e1')),
      projectsProvider.overrideWith((ref) async => [project ?? _project()]),
      projectEmployeesProvider('p1').overrideWith((ref) => const <Employee>[]),
      itTaskRepositoryProvider.overrideWithValue(_lastRepo = _Repo(list)),
    ],
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(body: ITWbsView(projectId: 'p1', tasks: list, exporter: export.call)),
    ),
  ));
  await tester.pumpAndSettle();
  return export;
}

Finder _row(String id) => find.byKey(Key('wbs_row_$id'));
Finder _in(String key, String text) => find.descendant(of: find.byKey(Key(key)), matching: find.text(text));
List<String> _listed(WidgetTester tester) {
  final rows = <String>[];
  for (final id in ['p1', 't11', 't12', 'p2', 't21', 'p3']) {
    if (_row(id).evaluate().isNotEmpty) rows.add(id);
  }
  return rows;
}

void main() {
  group('the strip', () {
    testWidgets('overall progress: the ring, "x of y items completed", and the counts', (tester) async {
      await _pump(tester);
      // leaves: 100, 50, 0, 0 → 38%
      expect(_in('wbs_ring', '38%'), findsOneWidget);
      expect(find.text('Overall Progress'), findsOneWidget);
      expect(find.text('1 of 6 items completed'), findsOneWidget);
      expect(_in('wbs_stat_phases', '3'), findsOneWidget);
      expect(_in('wbs_stat_tasks', '3'), findsOneWidget);
      expect(_in('wbs_stat_total', '6'), findsOneWidget);
      expect(_in('wbs_stat_completed', '1'), findsOneWidget);
      expect(_in('wbs_stat_remaining', '5'), findsOneWidget);
      for (final label in ['Phases', 'Tasks', 'Total Items', 'Completed', 'Remaining']) {
        expect(find.descendant(of: find.byKey(const Key('wbs_summary')), matching: find.text(label)), findsOneWidget, reason: label);
      }
    });

    testWidgets('the project\'s status and priority sit at its end', (tester) async {
      await _pump(tester);
      expect(_in('wbs_status_pill', 'Planning'), findsOneWidget);
      expect(_in('wbs_priority_pill', 'Medium'), findsOneWidget);
    });

    testWidgets('a project with no work yet: zeros', (tester) async {
      await _pump(tester, tasks: const []);
      expect(_in('wbs_ring', '0%'), findsOneWidget);
      expect(find.text('0 of 0 items completed'), findsOneWidget);
      expect(find.text('No tasks yet'), findsOneWidget);
    });
  });

  group('the toolbar', () {
    testWidgets('title, subtitle, and the controls', (tester) async {
      await _pump(tester);
      expect(find.text('Work Breakdown Structure (WBS)'), findsOneWidget);
      expect(find.text('Hierarchical breakdown of project phases, tasks and deliverables.'), findsOneWidget);
      expect(find.text('View:'), findsOneWidget);
      for (final k in ['wbs_view_tree', 'wbs_view_table', 'wbs_search', 'wbs_filter', 'wbs_export', 'wbs_add_phase']) {
        expect(find.byKey(Key(k)), findsOneWidget, reason: k);
      }
      expect(find.text('Search tasks...'), findsOneWidget);
    });

    testWidgets('someone who may not add work has no Add Phase and no row menus, but can still look, search and export', (tester) async {
      await _pump(tester, project: _project(canManage: false));
      expect(find.byKey(const Key('wbs_add_phase')), findsNothing);
      expect(find.byKey(const Key('wbs_menu_p1')), findsNothing);
      for (final k in ['wbs_search', 'wbs_filter', 'wbs_export']) {
        expect(find.byKey(Key(k)), findsOneWidget, reason: k);
      }
    });
  });

  group('the table', () {
    testWidgets('columns, and every phase with its tasks in order', (tester) async {
      await _pump(tester);
      for (final h in ['#', 'Task / Phase', 'Owner', 'Start Date', 'Due Date', 'Duration', 'Progress', 'Status']) {
        expect(find.descendant(of: find.byKey(const Key('wbs_table')), matching: find.text(h)), findsOneWidget, reason: h);
      }
      expect(_listed(tester), ['p1', 't11', 't12', 'p2', 't21', 'p3']);
      final ys = [for (final id in _listed(tester)) tester.getTopLeft(_row(id)).dy];
      expect(ys, [...ys]..sort());
    });

    testWidgets('a phase is numbered; its tasks are numbered under it', (tester) async {
      await _pump(tester);
      expect(_in('wbs_row_p1', '1'), findsOneWidget);
      expect(_in('wbs_row_t11', '1.1'), findsOneWidget);
      expect(_in('wbs_row_t12', '1.2'), findsOneWidget);
      expect(_in('wbs_row_p2', '2'), findsOneWidget);
      expect(_in('wbs_row_t21', '2.1'), findsOneWidget);
    });

    testWidgets('a task row: owner with initials, dates, duration, progress, status', (tester) async {
      await _pump(tester);
      expect(_in('wbs_row_t12', 'Stakeholder Alignment'), findsOneWidget);
      expect(_in('wbs_row_t12', 'Amna Rahman'), findsOneWidget);
      expect(_in('wbs_row_t12', 'AR'), findsOneWidget); // the avatar
      expect(_in('wbs_row_t12', '5/11/26'), findsOneWidget);
      expect(_in('wbs_row_t12', '8/11/26'), findsOneWidget);
      expect(_in('wbs_row_t12', '3 days'), findsOneWidget);
      expect(_in('wbs_row_t12', '50%'), findsOneWidget);
      expect(_in('wbs_row_t12', 'In Progress'), findsOneWidget);
      expect(_in('wbs_row_t11', 'Done'), findsOneWidget); // a company project's word for closed
    });

    testWidgets('a phase\'s own % is its tasks\' average; with nobody on it the owner reads "—"', (tester) async {
      await _pump(tester);
      expect(_in('wbs_row_p1', '75%'), findsOneWidget);
      expect(_in('wbs_row_p2', '—'), findsWidgets);
      expect(_in('wbs_row_p3', '0%'), findsOneWidget);
    });

    testWidgets('an IT project uses the IT words for status', (tester) async {
      await _pump(tester, tasks: [_t('p1', 'Build', order: 1), _t('t1', 'Review it', parent: 'p1', status: ITTaskStatus.codeReview)], project: _project(department: 'IT'));
      expect(_in('wbs_row_t1', 'Code Review'), findsOneWidget);
    });

    testWidgets('tapping a phase folds its tasks away; tapping again brings them back', (tester) async {
      await _pump(tester);
      await tester.tap(_row('p1'));
      await tester.pumpAndSettle();
      expect(_listed(tester), ['p1', 'p2', 't21', 'p3']);
      await tester.tap(_row('p1'));
      await tester.pumpAndSettle();
      expect(_listed(tester), ['p1', 't11', 't12', 'p2', 't21', 'p3']);
    });
  });

  group('Tree and Table', () {
    testWidgets('Table lists everything flat, ignores what was folded, and a phase opens its details instead of folding', (tester) async {
      await _pump(tester);
      await tester.tap(_row('p1')); // fold in Tree
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('wbs_view_table')));
      await tester.pumpAndSettle();
      expect(_listed(tester), ['p1', 't11', 't12', 'p2', 't21', 'p3']);

      await tester.tap(_row('p2'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('task_title')), findsOneWidget); // the details dialog
      expect(tester.widget<TextField>(find.byKey(const Key('task_title'))).controller!.text, 'Sourcing & Procurement');
    });

    testWidgets('going back to Tree keeps the folds', (tester) async {
      await _pump(tester);
      await tester.tap(_row('p1'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('wbs_view_table')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('wbs_view_tree')));
      await tester.pumpAndSettle();
      expect(_listed(tester), ['p1', 'p2', 't21', 'p3']);
    });
  });

  group('search', () {
    testWidgets('narrows to what matches (with its phase), and the ✕ puts everything back', (tester) async {
      await _pump(tester);
      await tester.enterText(find.byKey(const Key('wbs_search')), 'stakeholder');
      await tester.pumpAndSettle();
      expect(_listed(tester), ['p1', 't12']);

      await tester.tap(find.byKey(const Key('wbs_search_clear')));
      await tester.pumpAndSettle();
      expect(_listed(tester), ['p1', 't11', 't12', 'p2', 't21', 'p3']);
      expect(tester.widget<TextField>(find.byKey(const Key('wbs_search'))).controller!.text, isEmpty);
    });

    testWidgets('finds by owner and by number too', (tester) async {
      await _pump(tester);
      await tester.enterText(find.byKey(const Key('wbs_search')), 'adithya');
      await tester.pumpAndSettle();
      expect(_listed(tester), ['p1', 't11', 'p2', 't21']);
      await tester.enterText(find.byKey(const Key('wbs_search')), '2.1');
      await tester.pumpAndSettle();
      expect(_listed(tester), ['p2', 't21']);
    });

    testWidgets('nothing matches: says so, with a way back', (tester) async {
      await _pump(tester);
      await tester.enterText(find.byKey(const Key('wbs_search')), 'zzz');
      await tester.pumpAndSettle();
      expect(find.text('No item matches'), findsOneWidget);
      expect(_listed(tester), isEmpty);
      await tester.tap(find.byKey(const Key('wbs_clear_filters')));
      await tester.pumpAndSettle();
      expect(_listed(tester), hasLength(6));
    });
  });

  group('filter', () {
    testWidgets('by status: only those statuses are listed, and the button counts what is narrowed', (tester) async {
      await _pump(tester);
      await tester.tap(find.byKey(const Key('wbs_filter')));
      await tester.pumpAndSettle();
      // only statuses that are in use are offered
      expect(find.byKey(const Key('wbs_filter_status_in-progress')), findsOneWidget);
      expect(find.byKey(const Key('wbs_filter_status_todo')), findsOneWidget);
      expect(find.byKey(const Key('wbs_filter_status_closed')), findsOneWidget);
      expect(find.byKey(const Key('wbs_filter_status_backlog')), findsNothing);

      await tester.tap(find.byKey(const Key('wbs_filter_status_in-progress')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('wbs_filter_apply')));
      await tester.pumpAndSettle();
      expect(_listed(tester), ['p1', 't12']);
      expect(find.text('Filter (1)'), findsOneWidget);
    });

    testWidgets('by owner, and Reset clears it', (tester) async {
      await _pump(tester);
      await tester.tap(find.byKey(const Key('wbs_filter')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('wbs_filter_owner')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Amna Rahman').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('wbs_filter_apply')));
      await tester.pumpAndSettle();
      expect(_listed(tester), ['p1', 't12']);

      await tester.tap(find.byKey(const Key('wbs_filter')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('wbs_filter_reset')));
      await tester.pumpAndSettle();
      expect(_listed(tester), hasLength(6));
      expect(find.text('Filter'), findsOneWidget);
    });

    testWidgets('Cancel leaves the table as it was', (tester) async {
      await _pump(tester);
      await tester.tap(find.byKey(const Key('wbs_filter')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('wbs_filter_status_closed')));
      await tester.pump();
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(_listed(tester), hasLength(6));
    });
  });

  group('export', () {
    testWidgets('CSV: every item with the work-breakdown numbers, named for the project and the day', (tester) async {
      final export = await _pump(tester);
      await tester.tap(find.byKey(const Key('wbs_export')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Export as CSV'));
      await tester.pumpAndSettle();

      final c = export.calls.single;
      expect(c.kind, 'csv');
      expect(c.file, startsWith('wbs_lifestyle_brand_at_2030_'));
      expect(c.title, 'Work Breakdown Structure — Lifestyle brand at 2030');
      expect(c.headers, ['#', 'Task / Phase', 'Owner', 'Start Date', 'Due Date', 'Duration (days)', 'Progress %', 'Status']);
      expect(c.rows.map((r) => r[0]), ['1', '1.1', '1.2', '2', '2.1', '3']);
      expect(c.rows[2], ['1.2', 'Stakeholder Alignment', 'Amna Rahman', '5/11/26', '8/11/26', 3, 50, 'In Progress']);
    });

    testWidgets('PDF goes the same way; what is exported follows the search (folded phases included)', (tester) async {
      final export = await _pump(tester);
      await tester.tap(_row('p1')); // fold it: the export still lists its tasks
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('wbs_export')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Export as PDF'));
      await tester.pumpAndSettle();
      expect(export.calls.single.kind, 'pdf');
      expect(export.calls.single.rows.map((r) => r[0]), ['1', '1.1', '1.2', '2', '2.1', '3']);

      await tester.enterText(find.byKey(const Key('wbs_search')), 'vendor');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('wbs_export')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Export as CSV'));
      await tester.pumpAndSettle();
      expect(export.calls.last.rows.map((r) => r[0]), ['2', '2.1']);
    });

    testWidgets('nothing to export: says so instead of saving an empty file', (tester) async {
      final export = await _pump(tester);
      await tester.enterText(find.byKey(const Key('wbs_search')), 'zzz');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('wbs_export')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Export as CSV'));
      await tester.pumpAndSettle();
      expect(export.calls, isEmpty);
      expect(find.textContaining('Nothing to export'), findsOneWidget);
    });
  });

  group('rows keep their menu', () {
    testWidgets('Add sub-task / Add sibling / Edit / Delete, for someone who manages the project', (tester) async {
      await _pump(tester);
      await tester.tap(find.byKey(const Key('wbs_menu_p1')));
      await tester.pumpAndSettle();
      for (final item in ['Add sub-task', 'Add sibling', 'Edit', 'Delete']) {
        expect(find.text(item), findsOneWidget, reason: item);
      }
    });

    testWidgets('Move up / Move down: the first phase cannot go up, the last cannot go down', (tester) async {
      await _pump(tester);
      await tester.tap(find.byKey(const Key('wbs_menu_p1')));
      await tester.pumpAndSettle();
      expect(tester.widget<PopupMenuItem<String>>(find.byKey(const Key('wbs_menu_up_p1'))).enabled, isFalse);
      expect(tester.widget<PopupMenuItem<String>>(find.byKey(const Key('wbs_menu_down_p1'))).enabled, isTrue);
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('wbs_menu_p3')));
      await tester.pumpAndSettle();
      expect(tester.widget<PopupMenuItem<String>>(find.byKey(const Key('wbs_menu_down_p3'))).enabled, isFalse);
    });

    testWidgets('Move up writes the new order: the phase and the one above it trade places, nothing else is touched', (tester) async {
      await _pump(tester);
      await _loaded(tester);
      await tester.tap(find.byKey(const Key('wbs_menu_p2')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Move up'));
      await tester.pumpAndSettle();
      expect(_lastRepo!.updates, {'p2': {'order': 1}, 'p1': {'order': 2}});
    });

    testWidgets('a task moves only among the tasks of its own phase', (tester) async {
      await _pump(tester);
      await _loaded(tester);
      await tester.tap(find.byKey(const Key('wbs_menu_t12')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Move up'));
      await tester.pumpAndSettle();
      expect(_lastRepo!.updates, {'t12': {'order': 1}, 't11': {'order': 2}}); // never a task of another phase
    });

    testWidgets('someone who may not plan sees no Move', (tester) async {
      await _pump(tester, project: _project(canManage: false));
      expect(find.byKey(const Key('wbs_menu_p1')), findsNothing); // nothing to open at all
    });

    testWidgets('deleting a phase asks first and says how much goes with it; "Cancel" deletes nothing', (tester) async {
      await _pump(tester);
      await tester.tap(find.byKey(const Key('wbs_menu_p1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(find.text('Delete phase?'), findsOneWidget);
      expect(find.textContaining('2 item(s) under it'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(_listed(tester), hasLength(6));
    });
  });

  group('layout', () {
    testWidgets('narrow: the strip stacks, the toolbar wraps, the table scrolls sideways, nothing overflows', (tester) async {
      await _pump(tester, size: const Size(760, 1200));
      expect(tester.takeException(), isNull);
      final ring = tester.getRect(find.byKey(const Key('wbs_ring')));
      final stat = tester.getRect(find.byKey(const Key('wbs_stat_phases')));
      expect(stat.top, greaterThan(ring.bottom - 1)); // stacked below the ring, not beside it
      expect(find.byKey(const Key('wbs_search')), findsOneWidget);
      // the table is wider than the screen and scrolls
      expect(tester.getRect(find.byKey(const Key('wbs_table'))).width, lessThan(760));
      expect(find.byType(SingleChildScrollView), findsWidgets);
    });

    testWidgets('wide: the strip is one row and the toolbar sits beside the title', (tester) async {
      await _pump(tester, size: const Size(1500, 1100));
      expect(tester.takeException(), isNull);
      final ring = tester.getRect(find.byKey(const Key('wbs_ring')));
      final stat = tester.getRect(find.byKey(const Key('wbs_stat_total')));
      expect(stat.left, greaterThan(ring.right));
      expect((stat.center.dy - ring.center.dy).abs(), lessThan(30));
      final title = tester.getRect(find.text('Work Breakdown Structure (WBS)'));
      final add = tester.getRect(find.byKey(const Key('wbs_add_phase')));
      expect(add.left, greaterThan(title.right));
    });

    testWidgets('a laptop-sized page (sidebar taken off a 1440 screen) does not overflow', (tester) async {
      await _pump(tester, size: const Size(1150, 900));
      expect(tester.takeException(), isNull);
    });
  });
}
