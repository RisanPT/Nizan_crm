import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nizan_crm/core/models/auth_session.dart';
import 'package:nizan_crm/core/providers/auth_provider.dart';
import 'package:nizan_crm/core/theme/app_theme.dart';
import 'package:nizan_crm/features/it/data/it_task.dart';
import 'package:nizan_crm/features/it/services/it_service.dart';
import 'package:nizan_crm/features/it/presentation/screens/it_my_tasks_screen.dart';

void main() {
  Widget buildApp(List<ITTask> tasks) {
    return ProviderScope(
      overrides: [
        myTasksProvider.overrideWith((ref) => Future.value(tasks)),
        authSessionProvider.overrideWith((ref) => const AuthSession(
              token: 'token',
              userId: 'u1',
              employeeId: 'EMP-001',
              name: 'Muhammed Risan',
              email: 'risan@teamn.com',
              role: 'admin',
              departmentName: 'IT',
            )),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: const ITMyTasksScreen(),
      ),
    );
  }

  testWidgets('ITMyTasksScreen displays 5 KPI cards and Overview analytics', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final tasks = [
      ITTask(
        id: 't1',
        title: 'Bug in Hr management',
        projectId: 'p1',
        projectName: 'ERP',
        description: 'Fix the reported issue in HR module',
        status: ITTaskStatus.closed,
        severity: ITSeverity.p1,
        percentComplete: 100,
        dueDate: DateTime(2026, 9, 14),
        assigneeId: 'EMP-001',
        assigneeName: 'Muhammed Risan',
      ),
      ITTask(
        id: 't2',
        title: 'Car owners Meeting',
        projectId: 'p2',
        projectName: 'South Expansion',
        description: 'Objective: Soft Launch In Delhi',
        status: ITTaskStatus.todo,
        severity: ITSeverity.p2,
        percentComplete: 0,
        dueDate: DateTime(2026, 11, 13),
        assigneeId: 'EMP-001',
        assigneeName: 'Muhammed Risan',
      ),
    ];

    await tester.pumpWidget(buildApp(tasks));
    await tester.pumpAndSettle();

    // Verify 5 KPI cards
    expect(find.text('Total Tasks'), findsWidgets);
    expect(find.text('In Progress'), findsWidgets);
    expect(find.text('Completed'), findsWidgets);
    expect(find.text('Pending / Overdue'), findsWidgets);
    expect(find.text('On-Time Delivery'), findsWidgets);

    // Verify Overview Analytics cards
    expect(find.text('Task Progress Trend'), findsOneWidget);
    expect(find.text('Tasks by Status'), findsOneWidget);
    expect(find.text('My Tasks – Timeframe View'), findsOneWidget);

    // Verify Export button
    expect(find.text('Export'), findsOneWidget);

    // Verify completed task styling (green text, no strikethrough)
    final completedTextWidget = tester.widget<Text>(find.text('Bug in Hr management'));
    expect(completedTextWidget.style?.color, const Color(0xFF059669));
    expect(completedTextWidget.style?.decoration, isNull);

    // Verify non-completed task styling (not green, no strikethrough)
    final pendingTextWidget = tester.widget<Text>(find.text('Car owners Meeting'));
    expect(pendingTextWidget.style?.color, isNot(const Color(0xFF059669)));
    expect(pendingTextWidget.style?.decoration, isNull);

    // Verify Assignee column in header and rows
    expect(find.text('Assignee'), findsWidgets);
    expect(find.text('Muhammed Risan'), findsWidgets);
  });

  testWidgets('ITMyTasksScreen tabs filter correctly and empty state handles unassigned user', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final tasks = [
      ITTask(
        id: 't1',
        title: 'Task for other developer',
        projectId: 'p1',
        projectName: 'ERP',
        description: 'Backend API fix',
        status: ITTaskStatus.inProgress,
        severity: ITSeverity.p2,
        percentComplete: 50,
        dueDate: DateTime(2026, 11, 20),
        assigneeId: 'EMP-OTHER',
        assigneeName: 'Jane Doe',
      ),
      ITTask(
        id: 't2',
        title: 'Task for Muhammed Risan',
        projectId: 'p2',
        projectName: 'South Expansion',
        description: 'Delhi Launch',
        status: ITTaskStatus.todo,
        severity: ITSeverity.p1,
        percentComplete: 0,
        dueDate: DateTime(2026, 11, 25),
        assigneeId: 'EMP-001',
        assigneeName: 'Muhammed Risan',
      ),
    ];

    await tester.pumpWidget(buildApp(tasks));
    await tester.pumpAndSettle();

    // Default tab is Assigned to Me: should show only t2, not t1
    expect(find.text('Task for Muhammed Risan'), findsOneWidget);
    expect(find.text('Task for other developer'), findsNothing);

    // Tap "All Tasks" tab in the bottom tab bar
    await tester.tap(find.text('All Tasks').last);
    await tester.pumpAndSettle();

    // Now both tasks should be visible
    expect(find.text('Task for Muhammed Risan'), findsOneWidget);
    expect(find.text('Task for other developer'), findsOneWidget);
  });

  testWidgets('ITMyTasksScreen shows helpful empty state when user has no assigned tasks', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final tasks = [
      ITTask(
        id: 't1',
        title: 'Unassigned Backlog Item',
        projectId: 'p1',
        projectName: 'ERP',
        description: 'General task',
        status: ITTaskStatus.todo,
        severity: ITSeverity.p3,
        percentComplete: 0,
        assigneeId: '',
        assigneeName: '',
      ),
    ];

    await tester.pumpWidget(buildApp(tasks));
    await tester.pumpAndSettle();

    // On Assigned to Me tab, should show empty state with helper
    expect(find.text('No tasks assigned to you'), findsOneWidget);
    expect(find.text('View All Tasks'), findsOneWidget);

    // Tap "View All Tasks"
    await tester.tap(find.text('View All Tasks'));
    await tester.pumpAndSettle();

    // Now should be on All Tasks and display the backlog item
    expect(find.text('Unassigned Backlog Item'), findsOneWidget);
  });
}
