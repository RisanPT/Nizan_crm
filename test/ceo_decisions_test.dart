import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nizan_crm/core/theme/app_theme.dart';
import 'package:nizan_crm/features/finance/data/month_end.dart';
import 'package:nizan_crm/features/finance/presentation/screens/ceo_decisions_screen.dart';
import 'package:nizan_crm/features/finance/services/month_end_service.dart';

void main() {
  final now = DateTime.now();
  final sampleOpenDecision = CeoDecision(
    id: 'd1',
    month: 10,
    year: 2026,
    type: 'action_item',
    title: 'Approve new marketing budget',
    description: 'Q4 marketing campaign approval',
    amount: 50000,
    status: 'pending',
    owner: 'Risan',
  );

  final sampleCurrentMonthDecision = CeoDecision(
    id: 'd2',
    month: now.month,
    year: now.year,
    type: 'strategic_decision',
    title: 'Finalize HR expansion',
    description: 'Hiring plan for South expansion',
    amount: 120000,
    status: 'approved',
    owner: 'HR Head',
  );

  testWidgets('CeoDecisionsScreen loads open decisions by default when initialOpenOnly is true', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          openDecisionsProvider.overrideWith((ref) async => [sampleOpenDecision]),
          decisionsProvider.overrideWith((ref, period) async => [sampleCurrentMonthDecision]),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const CeoDecisionsScreen(initialOpenOnly: true),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Open Decisions header and card are displayed
    expect(find.text('All open decisions'), findsOneWidget);
    expect(find.text('Approve new marketing budget'), findsOneWidget);
    expect(find.text('Risan'), findsOneWidget);
  });

  testWidgets('CeoDecisionsScreen switches between open decisions and month-based decisions', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          openDecisionsProvider.overrideWith((ref) async => [sampleOpenDecision]),
          decisionsProvider.overrideWith((ref, period) async => [sampleCurrentMonthDecision]),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const CeoDecisionsScreen(initialOpenOnly: false),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // In month-based mode, sampleCurrentMonthDecision is shown
    expect(find.text('Finalize HR expansion'), findsOneWidget);

    // Toggle Open only
    await tester.tap(find.text('Open only'));
    await tester.pumpAndSettle();

    // Now open decisions list is shown
    expect(find.text('All open decisions'), findsOneWidget);
    expect(find.text('Approve new marketing budget'), findsOneWidget);
  });
}
