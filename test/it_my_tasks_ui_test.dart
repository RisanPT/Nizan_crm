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
  });
}
