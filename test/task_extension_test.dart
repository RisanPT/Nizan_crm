import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/models/auth_session.dart';
import 'package:nizan_crm/core/models/employee.dart';
import 'package:nizan_crm/core/providers/auth_provider.dart';
import 'package:nizan_crm/core/theme/app_theme.dart';
import 'package:nizan_crm/features/it/data/it_task.dart';
import 'package:nizan_crm/features/it/data/project.dart';
import 'package:nizan_crm/features/it/domain/repositories/it_task_repository.dart';
import 'package:nizan_crm/features/it/domain/task_cost.dart';
import 'package:nizan_crm/features/it/domain/task_extension.dart';
import 'package:nizan_crm/features/it/presentation/controllers/it_tasks_notifier.dart';
import 'package:nizan_crm/features/it/presentation/screens/widgets/it_task_detail_sheet.dart';
import 'package:nizan_crm/features/it/presentation/screens/widgets/it_task_editor.dart';
import 'package:nizan_crm/features/it/presentation/screens/widgets/it_wbs_view.dart';
import 'package:nizan_crm/features/it/presentation/screens/widgets/task_extension_widgets.dart';
import 'package:nizan_crm/features/it/services/it_service.dart';

// Extending a task's due date, in the app: how late a task is, the "extend" option for whoever plans it, the number of extensions and the
// whole history in the task's log, a reason asked for when the date of a late task is moved in an ordinary edit, and the badge in the WBS.
// The rules are the server's (backend utils/taskExtension.js); these tests check what the app reads, shows and sends.

// ── days: relative to today, so the tests are true on any day ───────────────
final _now = DateTime.now();
DateTime _d(int offset) =>
    DateTime(_now.year, _now.month, _now.day).add(Duration(days: offset));

/// A day in the middle of last month: late by two weeks or more, and a later day (the 15th) is on the same calendar page.
DateTime get _lastMonth10 => DateTime(_now.year, _now.month - 1, 10);

/// A day in the middle of next month: not late.
DateTime get _nextMonth10 => DateTime(_now.year, _now.month + 1, 10);

ITExtension _ext(
  int n, {
  required DateTime from,
  required DateTime to,
  String by = 'mira',
  String reason = '',
  int late = 0,
  bool viaEdit = false,
}) => ITExtension(
  at: DateTime(2026, 11, 1, 9).add(Duration(hours: n * 5)),
  from: from,
  to: to,
  byName: by,
  days: daysBetween(to, from),
  reason: reason,
  overdueDays: late,
  viaEdit: viaEdit,
);

ITTask _task({
  String id = 't1',
  DateTime? due,
  bool done = false,
  List<ITExtension> ext = const [],
  List<ITActivityLog> logs = const [],
  String assignee = '',
}) => ITTask(
  id: id,
  projectId: 'p1',
  title: 'Print banners',
  dueDate: due,
  startDate: due?.subtract(const Duration(days: 10)),
  status: done ? ITTaskStatus.closed : ITTaskStatus.inProgress,
  percentComplete: done ? 100 : 20,
  extensions: ext,
  activityLogs: logs,
  assigneeId: assignee,
);

Project _project({bool plan = true, DateTime? end}) => Project.fromJson({
  '_id': 'p1',
  'name': 'Website redesign',
  'status': 'active',
  'targetDepartment': 'Marketing',
  'managerId': {'_id': 'm1', 'name': 'Mira'},
  'editMode': 'managed',
  'endDate': end?.toIso8601String(),
  'departments': [
    {'name': 'Marketing', 'role': 'owner', 'status': 'accepted'},
  ],
  'access': {
    'role': plan ? 'manager' : 'member',
    'canManage': plan,
    'editMode': 'managed',
    'canCreateTasks': plan,
    'canEditAllTasks': plan,
    'leadDepartments': <String>[],
    'pendingInvitations': <String>[],
    'canDecide': false,
    'canSeeCost': plan,
    'canEditCost': plan,
  },
});

AuthSession _session() => AuthSession(
  token: 't',
  userId: 'u',
  name: 'U',
  email: 'u@x',
  role: 'crm',
  employeeId: 'e1',
);
Finder _k(String key) => find.byKey(Key(key));

Future<void> _tap(WidgetTester t, Finder f) async {
  await t.ensureVisible(f);
  await t.pumpAndSettle();
  await t.tap(f);
  await t.pumpAndSettle();
}

Future<void> _type(WidgetTester t, Finder f, String text) async {
  await t.ensureVisible(f);
  await t.enterText(f, text);
  await t.pump();
}

/// In the calendar the date picker opened: choose the [day] of the month it is showing, and confirm.
Future<void> _pickDay(WidgetTester t, int day) async {
  await t.tap(find.text('$day').last);
  await t.pumpAndSettle();
  await t.tap(find.text('OK'));
  await t.pumpAndSettle();
}

Future<void> _show(
  WidgetTester t,
  Widget child, {
  Size size = const Size(900, 1400),
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
  await t.pumpAndSettle();
}

// ── fakes ───────────────────────────────────────────────────────────────────
class _Repo implements IITTaskRepository {
  _Repo(List<ITTask> tasks) : tasks = [...tasks];
  List<ITTask> tasks;
  final updates = <Map<String, dynamic>>[];

  @override
  Future<List<ITTask>> getTasks({
    String? projectId,
    String? status,
    String? assignedTo,
    String? ticketType,
    String? severity,
    String? subTeam,
    String? search,
    bool mine = false,
  }) async => tasks;

  @override
  Future<ITTask> updateTask(String id, Map<String, dynamic> data) async {
    updates.add(data);
    return tasks.firstWhere((x) => x.id == id);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _Capture implements HttpClientAdapter {
  _Capture({this.status = 200, this.body});
  final int status;
  final Map<String, dynamic>? body;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final data =
        body ??
        {
          '_id': 't1',
          'projectId': 'p1',
          'title': 'Print banners',
          'deadline': '2026-01-05T00:00:00.000Z',
          'extensions': [
            {
              'from': '2025-12-28T00:00:00.000Z',
              'to': '2026-01-05T00:00:00.000Z',
              'days': 8,
              'byName': 'mira',
              'reason': 'Client sent the files late',
            },
          ],
        };
    return ResponseBody.fromString(
      jsonEncode(data),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _Svc extends ITTaskService {
  _Svc(this.repo) : super(Dio());
  final _Repo repo;
  final extended = <({String id, DateTime to, String reason})>[];
  final created = <Map<String, dynamic>>[];
  final updated = <Map<String, dynamic>>[];
  Object? fail;

  @override
  Future<ITTask> extendTask(
    String id, {
    required DateTime newDeadline,
    required String reason,
  }) async {
    if (fail != null) throw fail!;
    extended.add((id: id, to: newDeadline, reason: reason));
    final t = repo.tasks.firstWhere((x) => x.id == id);
    final e = ITExtension(
      at: DateTime.now(),
      from: t.dueDate!,
      to: newDeadline,
      byName: 'mira',
      days: daysBetween(newDeadline, t.dueDate!),
      reason: reason,
      overdueDays: t.overdueDays(DateTime.now()),
    );
    final next = t.copyWith(
      dueDate: newDeadline,
      extensions: [...t.extensions, e],
    );
    repo.tasks = [for (final x in repo.tasks) x.id == id ? next : x];
    return next;
  }

  @override
  Future<TaskSaveResult> createTask(Map<String, dynamic> body) async {
    created.add(body);
    return const TaskSaveResult();
  }

  @override
  Future<TaskSaveResult> updateTask(
    String id,
    Map<String, dynamic> body,
  ) async {
    updated.add(body);
    return const TaskSaveResult();
  }
}

void main() {
  // ── what the app reads ────────────────────────────────────────────────────
  group('reading extensions', () {
    test(
      'an entry reads who, when, from, to, how many days, how late it was and why',
      () {
        final e = ITExtension.tryParse({
          'at': '2026-11-17T04:30:00.000Z',
          'byName': 'mira',
          'from': '2026-11-12T00:00:00.000Z',
          'to': '2026-11-20T00:00:00.000Z',
          'days': 8,
          'reason': 'Client sent the files late',
          'overdueDays': 5,
          'viaEdit': true,
        })!;
        expect(
          (e.byName, e.days, e.reason, e.overdueDays, e.viaEdit),
          ('mira', 8, 'Client sent the files late', 5, true),
        );
        expect(e.to.isAfter(e.from), isTrue);
      },
    );

    test(
      'an entry with no usable dates is left out; the days are worked out when missing',
      () {
        expect(ITExtension.tryParse({'byName': 'x'}), isNull);
        expect(
          ITExtension.tryParse({'from': '2026-11-12T00:00:00.000Z'}),
          isNull,
        );
        final e = ITExtension.tryParse({
          'from': '2026-11-12T00:00:00.000Z',
          'to': '2026-11-15T00:00:00.000Z',
        })!;
        expect(
          (e.days, e.reason, e.overdueDays, e.viaEdit, e.byName),
          (3, '', 0, false, ''),
        );
      },
    );

    test('the history adds up, whatever order it arrives in', () {
      final list = [
        _ext(2, from: _d(5), to: _d(10), late: 0),
        _ext(1, from: _d(-5), to: _d(5), late: 5),
        _ext(3, from: _d(10), to: _d(12), late: 2),
      ];
      final s = summarizeExtensions(list);
      expect((s.count, s.totalDays, s.whileOverdue), (3, 17, 2));
      expect(
        s.originalDeadline,
        _d(-5),
        reason: 'the due date before the first extension',
      );
      expect(s.last!.to, _d(12));
      expect(summarizeExtensions(const []).isEmpty, isTrue);
      expect(summarizeExtensions(const []).count, 0);
      expect(list.first.days, 5, reason: 'the list is not reordered');
    });

    test('calendar days: how far apart, and how late a task is', () {
      expect(
        daysBetween(
          DateTime(2026, 11, 17, 23, 59),
          DateTime(2026, 11, 12, 0, 1),
        ),
        5,
      );
      expect(daysBetween(DateTime(2026, 11, 12), DateTime(2026, 11, 17)), -5);
      expect(
        daysBetween(DateTime(2026, 12, 1), DateTime(2026, 11, 30)),
        1,
        reason: 'across a month end',
      );
      final now = DateTime(2026, 11, 17, 10);
      expect(
        taskOverdueDays(due: DateTime(2026, 11, 17), done: false, now: now),
        0,
        reason: 'due today is not late',
      );
      expect(
        taskOverdueDays(due: DateTime(2026, 11, 16), done: false, now: now),
        1,
      );
      expect(
        taskOverdueDays(due: DateTime(2026, 11, 12), done: false, now: now),
        5,
      );
      expect(
        taskOverdueDays(due: DateTime(2026, 11, 30), done: false, now: now),
        0,
      );
      expect(taskOverdueDays(due: null, done: false, now: now), 0);
      expect(
        taskOverdueDays(due: DateTime(2026, 11, 1), done: true, now: now),
        0,
        reason: 'a finished task is never late',
      );
    });

    test('words: days, ranges, the count', () {
      expect(isoDay(DateTime(2026, 1, 5)), '2026-01-05');
      expect(daysText(1), '1 day');
      expect(daysText(8), '8 days');
      expect(longDay(DateTime(2026, 11, 12)), '12 Nov 2026');
      expect(
        dayRange(DateTime(2026, 11, 12), DateTime(2026, 11, 20)),
        '12 Nov → 20 Nov 2026',
      );
      expect(
        dayRange(DateTime(2026, 12, 28), DateTime(2027, 1, 4)),
        '28 Dec 2026 → 4 Jan 2027',
      );
      expect(extensionHeadline(const ExtensionSummary()), 'Never extended');
      expect(
        extensionHeadline(const ExtensionSummary(count: 1, totalDays: 1)),
        'Extended 1 time · +1 day',
      );
      expect(
        extensionHeadline(const ExtensionSummary(count: 3, totalDays: 17)),
        'Extended 3 times · +17 days',
      );
    });

    test(
      'a task reads its extensions (junk skipped) and how late it is; copying keeps them; the whole task sent back carries none',
      () {
        final t = ITTask.fromJson({
          '_id': 't1',
          'projectId': 'p1',
          'title': 'Print',
          'status': 'in-progress',
          'deadline': _d(-5).toUtc().toIso8601String(),
          'extensions': [
            {
              'from': _d(-9).toUtc().toIso8601String(),
              'to': _d(-5).toUtc().toIso8601String(),
              'byName': 'mira',
              'days': 4,
            },
            {'byName': 'broken'},
            'junk',
          ],
        });
        expect(t.extensionCount, 1);
        expect(t.extensionSummary.totalDays, 4);
        expect(t.isOverdue(_now), isTrue);
        expect(t.overdueDays(_now), 5);
        expect(t.copyWith(title: 'Renamed').extensionCount, 1);
        expect(
          t.toJson().containsKey('extensions'),
          isFalse,
          reason: 'the history is the server\'s alone',
        );
        expect(
          ITTask.fromJson({
            '_id': 'a',
            'projectId': 'p1',
            'title': 'Old',
          }).extensions,
          isEmpty,
        );
        expect(_task(due: _d(-5), done: true).isOverdue(_now), isFalse);
        expect(_task().isOverdue(_now), isFalse, reason: 'no due date');
      },
    );
  });

  group('the request to the server', () {
    test(
      'goes to the task\'s extend route with the day (no time, no zone) and the reason, and reads the task that comes back',
      () async {
        final cap = _Capture();
        final svc = ITTaskService(
          Dio(BaseOptions(baseUrl: 'http://x/api'))..httpClientAdapter = cap,
        );
        final task = await svc.extendTask(
          't1',
          newDeadline: DateTime(2026, 1, 5, 23, 59),
          reason: 'Client sent the files late',
        );
        final r = cap.requests.single;
        expect((r.method, r.path), ('POST', '/it-tasks/t1/extend'));
        expect(r.data, {
          'newDeadline': '2026-01-05',
          'reason': 'Client sent the files late',
        });
        expect(task.extensionCount, 1);
        expect(task.extensions.single.reason, 'Client sent the files late');
        expect(task.extensions.single.days, 8);
      },
    );

    test('a refusal comes out as an ordinary, readable error', () async {
      final cap = _Capture(
        status: 400,
        body: {
          'code': 'REASON_REQUIRED',
          'message': 'Say why the time is being extended.',
        },
      );
      final svc = ITTaskService(
        Dio(BaseOptions(baseUrl: 'http://x/api'))..httpClientAdapter = cap,
      );
      await expectLater(
        svc.extendTask('t1', newDeadline: DateTime(2026, 1, 5), reason: ''),
        throwsA(
          isA<AppException>().having(
            (e) => e.message,
            'message',
            contains('Say why the time is being extended'),
          ),
        ),
      );
    });
  });

  // ── under the due date ────────────────────────────────────────────────────
  group('under the due date', () {
    Future<void> status(
      WidgetTester t,
      ITTask task, {
      bool canExtend = true,
      VoidCallback? onExtend,
      VoidCallback? onHistory,
    }) => _show(
      t,
      DueDateStatus(
        task: task,
        now: _now,
        canExtend: canExtend,
        onExtend: onExtend ?? () {},
        onHistory: onHistory,
      ),
    );

    testWidgets('a late task says how late, and offers to extend it', (
      t,
    ) async {
      await status(t, _task(due: _d(-5)));
      expect(
        t
            .widget<Text>(
              find.descendant(
                of: _k('task_overdue_chip'),
                matching: find.byType(Text),
              ),
            )
            .data,
        'Overdue by 5 days',
      );
      expect(find.text('Extend due date'), findsOneWidget);
      expect(_k('task_extension_count'), findsNothing);
    });

    testWidgets(
      'one day late is "1 day", and a task not late has no warning but can still be extended',
      (t) async {
        await status(t, _task(due: _d(-1)));
        expect(find.text('Overdue by 1 day'), findsOneWidget);
        await status(t, _task(due: _d(3)));
        expect(_k('task_overdue_chip'), findsNothing);
        expect(find.text('Extend'), findsOneWidget);
      },
    );

    testWidgets(
      'says how many times the due date was extended, and tapping it opens the history',
      (t) async {
        var opened = 0;
        final ext = [
          _ext(1, from: _d(-9), to: _d(-4)),
          _ext(2, from: _d(-4), to: _d(2)),
        ];
        await status(
          t,
          _task(due: _d(2), ext: ext),
          onHistory: () => opened++,
        );
        expect(find.text('Extended 2 times · +11 days'), findsOneWidget);
        await _tap(t, _k('task_extension_count'));
        expect(opened, 1);
      },
    );

    testWidgets('the button asks to extend', (t) async {
      var asked = 0;
      await status(t, _task(due: _d(-5)), onExtend: () => asked++);
      await _tap(t, _k('task_extend_open'));
      expect(asked, 1);
    });

    testWidgets(
      'someone who does not plan the task sees how late it is and how often it was extended, but no button',
      (t) async {
        await status(
          t,
          _task(
            due: _d(-5),
            ext: [_ext(1, from: _d(-9), to: _d(-5))],
          ),
          canExtend: false,
        );
        expect(_k('task_overdue_chip'), findsOneWidget);
        expect(_k('task_extension_count'), findsOneWidget);
        expect(_k('task_extend_open'), findsNothing);
      },
    );

    testWidgets('fits a phone: the chips wrap', (t) async {
      await _show(
        t,
        DueDateStatus(
          task: _task(
            due: _d(-5),
            ext: [
              _ext(1, from: _d(-9), to: _d(-5)),
              _ext(2, from: _d(-14), to: _d(-9)),
            ],
          ),
          now: _now,
          canExtend: true,
          onExtend: () {},
        ),
        size: const Size(300, 800),
      );
      expect(t.takeException(), isNull);
      expect(_k('task_overdue_chip'), findsOneWidget);
      expect(_k('task_extend_open'), findsOneWidget);
    });

    testWidgets(
      'a finished task, or one with no due date, has no button; with nothing to say there is nothing at all',
      (t) async {
        await status(t, _task(due: _d(-5), done: true));
        expect(_k('task_extend_open'), findsNothing);
        expect(_k('task_overdue_chip'), findsNothing);
        await status(t, _task());
        expect(_k('task_extend_open'), findsNothing);
        expect(_k('task_due_status'), findsNothing);
        await status(t, _task(due: _d(3)), canExtend: false);
        expect(_k('task_due_status'), findsNothing);
      },
    );
  });

  // ── the history ───────────────────────────────────────────────────────────
  group('the history in the task\'s log', () {
    final three = [
      _ext(
        1,
        from: DateTime(2026, 11, 5),
        to: DateTime(2026, 11, 12),
        reason: 'Client sent the files late',
        late: 3,
      ),
      _ext(
        2,
        from: DateTime(2026, 11, 12),
        to: DateTime(2026, 11, 20),
        reason: 'Printer is booked',
      ),
      _ext(
        3,
        from: DateTime(2026, 11, 20),
        to: DateTime(2026, 11, 22),
        by: 'boss',
        viaEdit: true,
      ),
    ];

    testWidgets(
      'says how many times, how many days in all, the first due date and the present one',
      (t) async {
        await _show(
          t,
          ExtensionHistory(
            task: _task(due: DateTime(2026, 11, 22), ext: three),
          ),
        );
        expect(
          t.widget<Text>(_k('ext_summary')).data,
          'Extended 3 times · +17 days',
        );
        expect(
          t.widget<Text>(_k('ext_summary_detail')).data,
          'First due 5 Nov 2026 · now 22 Nov 2026 · 1 of 3 done while it was already late',
        );
      },
    );

    testWidgets(
      'lists every one, newest first, numbered in the order they happened, with who and when',
      (t) async {
        await _show(
          t,
          ExtensionHistory(
            task: _task(due: DateTime(2026, 11, 22), ext: three),
          ),
        );
        for (final n in [1, 2, 3]) {
          expect(_k('ext_entry_$n'), findsOneWidget, reason: '#$n');
        }
        final y = [
          for (final n in [3, 2, 1]) t.getTopLeft(_k('ext_entry_$n')).dy,
        ];
        expect(
          y[0] < y[1] && y[1] < y[2],
          isTrue,
          reason: 'newest at the top: $y',
        );
        expect(
          t.widget<Text>(_k('ext_range_1')).data,
          '5 Nov → 12 Nov 2026  (+7 days)',
        );
        expect(
          t.widget<Text>(_k('ext_range_3')).data,
          '20 Nov → 22 Nov 2026  (+2 days)',
        );
        expect(t.widget<Text>(_k('ext_by_1')).data, startsWith('mira · '));
        expect(t.widget<Text>(_k('ext_by_3')).data, startsWith('boss · '));
      },
    );

    testWidgets(
      'gives each reason; says plainly when none was given; marks the ones made late and the ones made by editing the date',
      (t) async {
        await _show(
          t,
          ExtensionHistory(
            task: _task(due: DateTime(2026, 11, 22), ext: three),
          ),
        );
        expect(
          t.widget<Text>(_k('ext_reason_1')).data,
          'Client sent the files late',
        );
        expect(t.widget<Text>(_k('ext_reason_2')).data, 'Printer is booked');
        expect(t.widget<Text>(_k('ext_reason_3')).data, 'No reason given');
        expect(find.text('was 3 days overdue'), findsOneWidget);
        expect(_k('ext_late_2'), findsNothing);
        expect(_k('ext_edit_3'), findsOneWidget);
        expect(_k('ext_edit_1'), findsNothing);
      },
    );

    testWidgets('a task never extended has no card', (t) async {
      await _show(t, ExtensionHistory(task: _task(due: _d(3))));
      expect(_k('task_extensions_card'), findsNothing);
    });

    testWidgets('fits a phone, with a long reason', (t) async {
      final long = [
        _ext(
          1,
          from: DateTime(2026, 11, 5),
          to: DateTime(2026, 11, 12),
          reason:
              'The client sent the print files late and then asked for another round of changes to the banner copy' *
              2,
          late: 3,
        ),
      ];
      await _show(
        t,
        ExtensionHistory(
          task: _task(due: DateTime(2026, 11, 12), ext: long),
        ),
        size: const Size(360, 1400),
      );
      expect(t.takeException(), isNull);
    });
  });

  // ── the dialog ────────────────────────────────────────────────────────────
  group('the extend dialog', () {
    ExtendRequest? result;
    bool closed = false;

    Future<void> open(
      WidgetTester t,
      ITTask task, {
      DateTime? projectEnd,
      DayPicker? picker,
    }) async {
      result = null;
      closed = false;
      t.view.physicalSize = const Size(900, 1400);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  result = await showExtendDeadlineDialog(
                    context,
                    task: task,
                    projectEnd: projectEnd,
                    picker: picker,
                    now: _now,
                  );
                  closed = true;
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await t.tap(find.text('open'));
      await t.pumpAndSettle();
    }

    DayPicker picks(DateTime d) =>
        (context, initial, first, last) async => d;

    testWidgets(
      'shows how late the task is, and how often it was extended before',
      (t) async {
        await open(
          t,
          _task(
            due: _d(-5),
            ext: [
              _ext(1, from: _d(-9), to: _d(-5)),
              _ext(2, from: _d(-14), to: _d(-9)),
            ],
          ),
        );
        expect(
          t.widget<Text>(_k('extend_current')).data,
          'Now due ${longDay(_d(-5))} — overdue by 5 days.',
        );
        expect(
          t.widget<Text>(_k('extend_before')).data,
          'Already extended 2 times · +9 days.',
        );
      },
    );

    testWidgets(
      'starts a week past today for a late task, a week past the due date for one that is not late yet',
      (t) async {
        await open(t, _task(due: _d(-5)));
        expect(find.text('New due date: ${longDay(_d(7))}'), findsOneWidget);
        expect(
          t.widget<Text>(_k('extend_days')).data,
          '+12 days from the current due date',
        );
        await t.tap(_k('extend_cancel'));
        await t.pumpAndSettle();
        await open(t, _task(due: _d(4)));
        expect(find.text('New due date: ${longDay(_d(11))}'), findsOneWidget);
        expect(
          t.widget<Text>(_k('extend_days')).data,
          '+7 days from the current due date',
        );
      },
    );

    testWidgets('a reason is needed; then it goes back with the day, trimmed', (
      t,
    ) async {
      await open(t, _task(due: _d(-5)));
      await _tap(t, _k('extend_send'));
      expect(
        t.widget<Text>(_k('extend_error')).data,
        'Say why more time is needed.',
      );
      expect(result, isNull);
      await _type(t, _k('extend_reason'), '  ab ');
      await _tap(t, _k('extend_send'));
      expect(_k('extend_error'), findsOneWidget);
      await _type(t, _k('extend_reason'), '  Client sent the files late  ');
      await _tap(t, _k('extend_send'));
      expect(closed, isTrue);
      expect(result!.reason, 'Client sent the files late');
      expect(isoDay(result!.newDeadline), isoDay(_d(7)));
    });

    testWidgets(
      'the day is chosen with the picker, which starts after the current due date',
      (t) async {
        DateTime? firstAllowed;
        await open(
          t,
          _task(due: _d(-5)),
          picker: (context, initial, first, last) async {
            firstAllowed = first;
            return _d(20);
          },
        );
        await _tap(t, _k('extend_date'));
        expect(
          isoDay(firstAllowed!),
          isoDay(_d(-4)),
          reason: 'the day after the current due date',
        );
        expect(find.text('New due date: ${longDay(_d(20))}'), findsOneWidget);
        expect(
          t.widget<Text>(_k('extend_days')).data,
          '+25 days from the current due date',
        );
        await _type(t, _k('extend_reason'), 'Scope grew');
        await _tap(t, _k('extend_send'));
        expect(isoDay(result!.newDeadline), isoDay(_d(20)));
      },
    );

    testWidgets(
      'a day that is not after the current one is refused before anything is sent',
      (t) async {
        await open(t, _task(due: _d(-5)), picker: picks(_d(-5)));
        await _tap(t, _k('extend_date'));
        expect(
          t.widget<Text>(_k('extend_days')).data,
          'It has to be after ${longDay(_d(-5))}',
        );
        await _type(t, _k('extend_reason'), 'A reason');
        await _tap(t, _k('extend_send'));
        expect(
          t.widget<Text>(_k('extend_error')).data,
          'The new due date has to be after ${longDay(_d(-5))}.',
        );
        expect(result, isNull);
        expect(closed, isFalse);
      },
    );

    testWidgets(
      'a day after the project\'s end date is warned about, and still allowed',
      (t) async {
        await open(
          t,
          _task(due: _d(-5)),
          projectEnd: _d(10),
          picker: picks(_d(20)),
        );
        expect(
          _k('extend_after_project_end'),
          findsNothing,
          reason: 'the first day offered is inside the project',
        );
        await _tap(t, _k('extend_date'));
        expect(
          t.widget<Text>(_k('extend_after_project_end')).data,
          contains('after the project\'s end date (${longDay(_d(10))})'),
        );
        await _type(t, _k('extend_reason'), 'Scope grew');
        await _tap(t, _k('extend_send'));
        expect(result, isNotNull);
      },
    );

    testWidgets('backing out sends nothing', (t) async {
      await open(t, _task(due: _d(-5)));
      await _type(t, _k('extend_reason'), 'A reason');
      await _tap(t, _k('extend_cancel'));
      expect(closed, isTrue);
      expect(result, isNull);
    });
  });

  group('the reason asked for when a late task\'s date is edited', () {
    String? reason;
    bool closed = false;

    Future<void> open(WidgetTester t) async {
      reason = null;
      closed = false;
      t.view.physicalSize = const Size(900, 1400);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  reason = await askExtensionReason(
                    context,
                    from: DateTime(2026, 11, 12),
                    to: DateTime(2026, 11, 20),
                    overdueDays: 5,
                  );
                  closed = true;
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await t.tap(find.text('open'));
      await t.pumpAndSettle();
    }

    testWidgets('says what is moving and that it is kept; a reason is needed', (
      t,
    ) async {
      await open(t);
      expect(
        t.widget<Text>(_k('ext_reason_note')).data,
        'It is 5 days overdue, and the due date moves 12 Nov → 20 Nov 2026. This is kept in its history as an extension.',
      );
      await _tap(t, _k('ext_reason_ok'));
      expect(
        t.widget<Text>(_k('ext_reason_error')).data,
        'Say why more time is needed.',
      );
      expect(closed, isFalse);
      await _type(t, _k('ext_reason_field'), ' Printer is booked ');
      await _tap(t, _k('ext_reason_ok'));
      expect(reason, 'Printer is booked');
    });

    testWidgets('backing out gives nothing', (t) async {
      await open(t);
      await _tap(t, _k('ext_reason_cancel'));
      expect(closed, isTrue);
      expect(reason, isNull);
    });
  });

  // ── the task dialog ───────────────────────────────────────────────────────
  group('the task dialog', () {
    late _Repo repo;
    late _Svc svc;

    Future<void> openSheet(
      WidgetTester t,
      ITTask task, {
      Project? project,
      Size size = const Size(1300, 1100),
    }) async {
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(const SizedBox.shrink());
      repo = _Repo([task]);
      svc = _Svc(repo);
      final p = project ?? _project();
      await t.pumpWidget(
        ProviderScope(
          retry: (_, _) => null,
          overrides: <Override>[
            authSessionProvider.overrideWithValue(_session()),
            projectsProvider.overrideWith((ref) async => [p]),
            projectEmployeesProvider(
              'p1',
            ).overrideWith((ref) => const <Employee>[]),
            itTaskRepositoryProvider.overrideWithValue(repo),
            itTaskServiceProvider.overrideWithValue(svc),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: Consumer(
              builder: (context, ref, _) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    key: const Key('open'),
                    onPressed: () => showITTaskDetailSheet(
                      context,
                      ref,
                      task: task,
                      allTasks: [task],
                    ),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      await t.tap(_k('open'));
      await t.pumpAndSettle();
    }

    testWidgets(
      'a late task says so under its due date, with the option to extend it',
      (t) async {
        await openSheet(t, _task(due: _d(-5)));
        expect(find.text('Overdue by 5 days'), findsOneWidget);
        expect(_k('task_extend_open'), findsOneWidget);
      },
    );

    testWidgets(
      'extending: the day and the reason go to the server; the task now shows the new day and one extension',
      (t) async {
        await openSheet(t, _task(due: _d(-5)));
        await _tap(t, _k('task_extend_open'));
        expect(_k('extend_dialog'), findsOneWidget);
        await _type(t, _k('extend_reason'), 'Client sent the files late');
        await _tap(t, _k('extend_send'));
        expect(svc.extended, hasLength(1));
        expect(isoDay(svc.extended.single.to), isoDay(_d(7)));
        expect(svc.extended.single.reason, 'Client sent the files late');
        expect(
          find.text('Due date extended to ${longDay(_d(7))}.'),
          findsWidgets,
        );
        expect(
          find.text('Overdue by 5 days'),
          findsNothing,
          reason: 'it is not late any more',
        );
        expect(find.text('Extended 1 time · +12 days'), findsOneWidget);
        expect(
          t
              .widget<Text>(
                find.descendant(
                  of: _k('task_due'),
                  matching: find.byType(Text),
                ),
              )
              .data,
          DateFormatter.dayMonthYear(_d(7)),
        );
      },
    );

    testWidgets(
      'then Save does not send the extension again, and does not ask why',
      (t) async {
        await openSheet(t, _task(due: _d(-5)));
        await _tap(t, _k('task_extend_open'));
        await _type(t, _k('extend_reason'), 'Client sent the files late');
        await _tap(t, _k('extend_send'));
        // the "extended" message goes away, off the Save button
        await t.pump(const Duration(seconds: 6));
        await t.pumpAndSettle();
        await _tap(t, _k('task_save'));
        expect(_k('ext_reason_dialog'), findsNothing);
        expect(repo.updates, hasLength(1));
        expect(repo.updates.single.containsKey('extensionReason'), isFalse);
        expect(svc.extended, hasLength(1));
      },
    );

    testWidgets('backing out of the dialog changes nothing', (t) async {
      await openSheet(t, _task(due: _d(-5)));
      await _tap(t, _k('task_extend_open'));
      await _tap(t, _k('extend_cancel'));
      expect(svc.extended, isEmpty);
      expect(find.text('Overdue by 5 days'), findsOneWidget);
    });

    testWidgets('a refusal from the server is shown, and the due date stays', (
      t,
    ) async {
      await openSheet(t, _task(due: _d(-5)));
      svc.fail = AppException(
        DioException(
          requestOptions: RequestOptions(path: '/it-tasks/t1/extend'),
          type: DioExceptionType.badResponse,
          response: Response(
            requestOptions: RequestOptions(path: '/it-tasks/t1/extend'),
            statusCode: 409,
            data: {
              'code': 'DEADLINE_CHANGED',
              'message':
                  'Someone changed this task\'s due date a moment ago. Open it again to see where it stands.',
            },
          ),
        ),
        action: 'extend the due date',
      );
      await _tap(t, _k('task_extend_open'));
      await _type(t, _k('extend_reason'), 'A reason');
      await _tap(t, _k('extend_send'));
      expect(find.textContaining('Someone changed this task'), findsWidgets);
      expect(find.text('Overdue by 5 days'), findsOneWidget);
    });

    testWidgets(
      'the person it is given to sees how late it is, but cannot extend it',
      (t) async {
        await openSheet(
          t,
          _task(due: _d(-5), assignee: 'e1'),
          project: _project(plan: false),
        );
        expect(find.text('Overdue by 5 days'), findsOneWidget);
        expect(_k('task_extend_open'), findsNothing);
      },
    );

    testWidgets(
      'the log opens with the whole history; the extension lines are not repeated among the comments',
      (t) async {
        final ext = [
          _ext(
            1,
            from: _d(-9),
            to: _d(-4),
            reason: 'Printer is booked',
            late: 5,
          ),
          _ext(
            2,
            from: _d(-4),
            to: _d(2),
            by: 'boss',
            reason: 'Waiting for sign-off',
          ),
        ];
        final logs = [
          ITActivityLog(
            id: '1',
            message: 'Started the layout',
            authorName: 'Adithya',
            timestamp: DateTime(2026, 11, 3),
          ),
          ITActivityLog(
            id: '2',
            message: 'Due date extended by 5 days: 8 Nov → 13 Nov 2026',
            authorName: 'mira',
            type: 'extension',
            timestamp: DateTime(2026, 11, 4),
          ),
        ];
        await openSheet(t, _task(due: _d(2), ext: ext, logs: logs));
        await _tap(t, _k('task_tab_activity'));
        expect(
          t.widget<Text>(_k('ext_summary')).data,
          'Extended 2 times · +11 days',
        );
        expect(t.widget<Text>(_k('ext_reason_2')).data, 'Waiting for sign-off');
        expect(find.text('Started the layout'), findsOneWidget);
        expect(
          find.textContaining('Due date extended by 5 days'),
          findsNothing,
          reason: 'it is in the history above, not repeated',
        );
      },
    );

    testWidgets('tapping "Extended N times" goes to the log', (t) async {
      await openSheet(
        t,
        _task(
          due: _d(2),
          ext: [_ext(1, from: _d(-9), to: _d(2), reason: 'Printer is booked')],
        ),
      );
      await _tap(t, _k('task_extension_count'));
      expect(_k('task_extensions_card'), findsOneWidget);
    });

    testWidgets('a task never extended and with no comments says so', (
      t,
    ) async {
      await openSheet(t, _task(due: _d(2)));
      await _tap(t, _k('task_tab_activity'));
      expect(find.text('No activity or comments yet.'), findsOneWidget);
      expect(_k('task_extensions_card'), findsNothing);
    });

    testWidgets(
      'moving a LATE task\'s due date later in the form asks why, and sends the reason with the save',
      (t) async {
        await openSheet(t, _task(due: _lastMonth10));
        await _tap(t, _k('task_due'));
        await _pickDay(t, 15);
        await _tap(t, _k('task_save'));
        expect(_k('ext_reason_dialog'), findsOneWidget);
        await _type(t, _k('ext_reason_field'), 'Waiting for the client');
        await _tap(t, _k('ext_reason_ok'));
        expect(repo.updates, hasLength(1));
        expect(
          repo.updates.single['extensionReason'],
          'Waiting for the client',
        );
        expect(repo.updates.single['deadline'], contains('-15T'));
      },
    );

    testWidgets('backing out of that question saves nothing at all', (t) async {
      await openSheet(t, _task(due: _lastMonth10));
      await _tap(t, _k('task_due'));
      await _pickDay(t, 15);
      await _tap(t, _k('task_save'));
      await _tap(t, _k('ext_reason_cancel'));
      expect(repo.updates, isEmpty);
      expect(
        _k('task_save'),
        findsOneWidget,
        reason: 'the dialog is still open',
      );
    });

    testWidgets('a task that is not late yet is not asked', (t) async {
      await openSheet(t, _task(due: _nextMonth10));
      await _tap(t, _k('task_due'));
      await _pickDay(t, 15);
      await _tap(t, _k('task_save'));
      expect(_k('ext_reason_dialog'), findsNothing);
      expect(repo.updates.single.containsKey('extensionReason'), isFalse);
    });

    testWidgets(
      'and neither is a late task whose date did not move, or moved earlier',
      (t) async {
        await openSheet(t, _task(due: _lastMonth10));
        await _tap(t, _k('task_save'));
        expect(_k('ext_reason_dialog'), findsNothing);
        expect(repo.updates.single.containsKey('extensionReason'), isFalse);
        await openSheet(t, _task(due: _lastMonth10));
        await _tap(t, _k('task_due'));
        await _pickDay(t, 5);
        await _tap(t, _k('task_save'));
        expect(_k('ext_reason_dialog'), findsNothing);
      },
    );
  });

  // ── the task form (editor) ────────────────────────────────────────────────
  group('the task form', () {
    late _Svc svc;

    Future<void> openForm(WidgetTester t, ITTask existing) async {
      t.view.physicalSize = const Size(900, 2200);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      svc = _Svc(_Repo([existing]));
      await t.pumpWidget(
        ProviderScope(
          retry: (_, _) => null,
          overrides: <Override>[
            authSessionProvider.overrideWithValue(_session()),
            projectByIdProvider('p1').overrideWithValue(_project()),
            projectEmployeesProvider(
              'p1',
            ).overrideWithValue(const <Employee>[]),
            itTaskServiceProvider.overrideWithValue(svc),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) => TextButton(
                  onPressed: () => showTaskEditor(
                    context,
                    ref,
                    'p1',
                    existing: existing,
                    allTasks: [existing],
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await t.tap(find.text('open'));
      await t.pumpAndSettle();
    }

    Finder save() => find.textContaining(RegExp(r'^Save (ticket|task)$'));
    Finder dueButton(ITTask task) => find.textContaining('Due: ');

    testWidgets(
      'moving a LATE task\'s due date later asks why, and sends the reason',
      (t) async {
        final task = _task(due: _lastMonth10);
        await openForm(t, task);
        await _tap(t, dueButton(task));
        await _pickDay(t, 15);
        await _tap(t, save());
        expect(_k('ext_reason_dialog'), findsOneWidget);
        await _type(t, _k('ext_reason_field'), 'Printer is booked');
        await _tap(t, _k('ext_reason_ok'));
        expect(svc.updated, hasLength(1));
        expect(svc.updated.single['extensionReason'], 'Printer is booked');
      },
    );

    testWidgets('backing out saves nothing', (t) async {
      final task = _task(due: _lastMonth10);
      await openForm(t, task);
      await _tap(t, dueButton(task));
      await _pickDay(t, 15);
      await _tap(t, save());
      await _tap(t, _k('ext_reason_cancel'));
      expect(svc.updated, isEmpty);
    });

    testWidgets(
      'a task that is not late, or whose date is not moved later, is not asked',
      (t) async {
        final soon = _task(due: _nextMonth10);
        await openForm(t, soon);
        await _tap(t, dueButton(soon));
        await _pickDay(t, 15);
        await _tap(t, save());
        expect(_k('ext_reason_dialog'), findsNothing);
        expect(svc.updated.single.containsKey('extensionReason'), isFalse);

        final late = _task(due: _lastMonth10);
        await openForm(t, late);
        await _tap(t, save());
        expect(_k('ext_reason_dialog'), findsNothing);
        expect(svc.updated.single.containsKey('extensionReason'), isFalse);
      },
    );
  });

  // ── the WBS ───────────────────────────────────────────────────────────────
  group('the WBS due date', () {
    Future<void> showWbs(WidgetTester t, List<ITTask> list) async {
      t.view.physicalSize = const Size(1700, 1100);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(const SizedBox.shrink());
      await t.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            authSessionProvider.overrideWithValue(_session()),
            projectsProvider.overrideWith((ref) async => [_project()]),
            projectEmployeesProvider(
              'p1',
            ).overrideWith((ref) => const <Employee>[]),
            itTaskRepositoryProvider.overrideWithValue(_Repo(list)),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: ITWbsView(projectId: 'p1', tasks: list),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
    }

    Color? colorOf(WidgetTester t, String key) =>
        t.widget<Text>(_k(key)).style?.color;

    testWidgets(
      'a task extended before carries how many times, with the whole summary on hover',
      (t) async {
        final extended = _task(
          id: 'a',
          due: _d(3),
          ext: [
            _ext(1, from: _d(-9), to: _d(-4)),
            _ext(2, from: _d(-4), to: _d(3)),
          ],
        );
        await showWbs(t, [extended, _task(id: 'b', due: _d(4))]);
        expect(
          t
              .widget<Text>(
                find.descendant(
                  of: _k('wbs_ext_a'),
                  matching: find.byType(Text),
                ),
              )
              .data,
          '×2',
        );
        expect(find.byTooltip('Extended 2 times · +12 days'), findsOneWidget);
        expect(_k('wbs_ext_b'), findsNothing);
      },
    );

    testWidgets(
      'the due date of a late task is red; one that is not late, or is finished, is not',
      (t) async {
        await showWbs(t, [
          _task(id: 'late', due: _d(-5)),
          _task(id: 'ok', due: _d(5)),
          _task(id: 'done', due: _d(-5), done: true),
        ]);
        expect(colorOf(t, 'wbs_due_late'), const Color(0xFFB91C1C));
        expect(colorOf(t, 'wbs_due_ok'), isNot(const Color(0xFFB91C1C)));
        expect(colorOf(t, 'wbs_due_done'), isNot(const Color(0xFFB91C1C)));
      },
    );
  });
}

/// The day as the task dialog's date field writes it ("dd MMM yyyy").
abstract final class DateFormatter {
  static String dayMonthYear(DateTime d) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${d.day.toString().padLeft(2, '0')} ${months[d.month - 1]} ${d.year}';
  }
}
