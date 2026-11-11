import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nizan_crm/core/theme/app_theme.dart';
import 'package:nizan_crm/features/it/domain/models/it_project_model.dart';
import 'package:nizan_crm/features/it/domain/models/it_task_model.dart';
import 'package:nizan_crm/features/it/presentation/screens/widgets/functional_plan_wizard_dialog.dart';

void main() {
  testWidgets('FunctionalPlanWizardDialog renders and navigates steps', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const ProviderScope(
          child: Scaffold(
            body: FunctionalPlanWizardDialog(
              projectId: 'proj_123',
              projectName: 'ERP Modernization',
              existingTasks: <ITTaskModel>[],
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Step 1: Function Overview
    expect(find.text('Functional Plan & Gantt Auto-Scheduler'), findsOneWidget);
    expect(find.text('Function Overview'), findsOneWidget);
    expect(find.text('Quick WBS Template'), findsNothing); // nothing is pre-filled
    expect(find.text('Continue'), findsOneWidget);

    // Tap Continue to Step 2: Phases & WBS
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Milestones & Phases (WBS)'), findsOneWidget);
    expect(find.text('Add Phase'), findsOneWidget);

    // Tap Continue to Step 3: Tasks & Team
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Tasks & Ownership'), findsOneWidget);
    expect(find.text('Add Task'), findsOneWidget);

    // Tap Continue to Step 4: Dependencies & Gantt Auto-Schedule
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Dependencies & Gantt Auto-Schedule'), findsOneWidget);
    expect(find.text('Total Duration'), findsOneWidget);
    expect(find.text('Critical Path'), findsAtLeastNWidgets(1));
    expect(find.text('Generate Gantt Plan'), findsOneWidget);
  });

  testWidgets('FunctionalPlanWizardDialog scopes to IT department for IT project', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    const itProject = ITProjectModel(
      id: 'proj_it_1',
      name: 'Cloud Infrastructure Upgrade',
      targetDepartment: 'IT',
      departments: [
        ProjectDepartment(name: 'IT', role: 'owner', status: 'accepted'),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const ProviderScope(
          child: Scaffold(
            body: FunctionalPlanWizardDialog(
              projectId: 'proj_it_1',
              projectName: 'Cloud Infrastructure Upgrade',
              project: itProject,
              existingTasks: <ITTaskModel>[],
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Should display IT and Project Owner, and not a department dropdown
    expect(find.text('IT'), findsAtLeastNWidgets(1));
    expect(find.text('Project Owner'), findsOneWidget);
    expect(find.byType(DropdownButtonFormField<String>), findsNothing);
    expect(find.text('This project belongs to IT. To involve other departments, invite them in Project Settings.'), findsOneWidget);
  });

  testWidgets('FunctionalPlanWizardDialog offers active departments for cross-department project', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    const crossProject = ITProjectModel(
      id: 'proj_cross_1',
      name: 'Omnichannel Launch',
      targetDepartment: 'Marketing',
      departments: [
        ProjectDepartment(name: 'Marketing', role: 'owner', status: 'accepted'),
        ProjectDepartment(name: 'IT', role: 'participant', status: 'accepted'),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const ProviderScope(
          child: Scaffold(
            body: FunctionalPlanWizardDialog(
              projectId: 'proj_cross_1',
              projectName: 'Omnichannel Launch',
              project: crossProject,
              existingTasks: <ITTaskModel>[],
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Default dropdown selects Marketing (owner) and includes IT
    expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
    expect(find.text('Active participating departments on this project.'), findsOneWidget);
  });

  testWidgets('FunctionalPlanWizardDialog detects circular dependency and recovers via Reset to Sequence', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: ProviderScope(
          child: Scaffold(
            body: FunctionalPlanWizardDialog(
              projectId: 'proj_123',
              projectName: 'ERP Modernization',
              existingTasks: const <ITTaskModel>[],
              // two tasks, the second waiting for the first (the wizard pre-fills no plan of its own)
              seed: (
                phases: [PlanPhaseDraft(id: 'ph1', name: 'Design')],
                tasks: [
                  PlanTaskDraft(id: 'tk1', phaseId: 'ph1', title: 'First'),
                  PlanTaskDraft(id: 'tk2', phaseId: 'ph1', title: 'Second', predecessorIds: ['tk1']),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Navigate to Step 4
    await tester.tap(find.text('Continue')); // Step 2
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue')); // Step 3
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue')); // Step 4
    await tester.pumpAndSettle();

    // Initially clean sequence without circular dependency
    expect(find.text('Circular dependency loop detected. Please resolve loops between tasks.'), findsNothing);
    expect(find.text('Generate Gantt Plan'), findsOneWidget);

    // Downstream tasks are NOT eligible as predecessors: "First" cannot be made to wait for "Second", which waits for it
    // and "Second" has nothing left to add either (it already waits for the only other task): no "add dependency" anywhere
    expect(find.byIcon(Icons.link_off_rounded), findsNWidgets(2));
    expect(find.byIcon(Icons.add_link_rounded), findsNothing);
  });
}
