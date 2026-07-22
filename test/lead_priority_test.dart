import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nizan_crm/core/models/lead.dart';
import 'package:nizan_crm/core/utils/lead_priority.dart';

void main() {
  group('LeadPriority.of', () {
    test('resolves the three levels case-insensitively', () {
      expect(LeadPriority.of('Hot').value, 'Hot');
      expect(LeadPriority.of('hot').value, 'Hot');
      expect(LeadPriority.of('COLD').value, 'Cold');
      expect(LeadPriority.of('Warm').value, 'Warm');
    });

    test('defaults to Warm for unknown, empty or null', () {
      expect(LeadPriority.of(null).value, 'Warm');
      expect(LeadPriority.of('').value, 'Warm');
      expect(LeadPriority.of('banana').value, 'Warm');
    });

    test('each level has a distinct colour', () {
      final colours = LeadPriority.all.map((p) => p.color).toSet();
      expect(colours.length, 3);
    });
  });

  group('Lead priority round-trip', () {
    test('parses priority from json and defaults when absent', () {
      final base = {
        'name': 'Aisha',
        'phone': '9876543210',
        'status': 'Follow-up',
        'createdAt': '2026-07-01T00:00:00.000Z',
      };
      expect(Lead.fromJson({...base, 'priority': 'Hot'}).priority, 'Hot');
      // Leads created before the field existed fall back to Warm.
      expect(Lead.fromJson(base).priority, 'Warm');
    });

    test('priority is independent of pipeline status', () {
      final lead = Lead.fromJson({
        'name': 'Aisha',
        'phone': '9876543210',
        'status': 'Follow-up',
        'priority': 'Hot',
        'createdAt': '2026-07-01T00:00:00.000Z',
      });
      // The whole point of a separate field: both survive together.
      expect(lead.status, 'Follow-up');
      expect(lead.priority, 'Hot');
      expect(lead.toJson()['priority'], 'Hot');
      expect(lead.toJson()['status'], 'Follow-up');
    });

    test('copyWith changes priority without touching status', () {
      final lead = Lead.fromJson({
        'name': 'A',
        'phone': '1',
        'status': 'Qualified',
        'priority': 'Cold',
        'createdAt': '2026-07-01T00:00:00.000Z',
      });
      final updated = lead.copyWith(priority: 'Hot');
      expect(updated.priority, 'Hot');
      expect(updated.status, 'Qualified');
    });
  });

  testWidgets('selector reports the tapped priority', (tester) async {
    String? picked;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: LeadPrioritySelector(
          value: 'Warm',
          onChanged: (v) => picked = v,
        ),
      ),
    ));

    await tester.tap(find.text('Hot'));
    await tester.pumpAndSettle();
    expect(picked, 'Hot');
    expect(tester.takeException(), isNull);
  });

  testWidgets('chip renders the label for each level', (tester) async {
    for (final p in LeadPriority.all) {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: LeadPriorityChip(p.value)),
      ));
      await tester.pumpAndSettle();
      expect(find.text(p.label), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
}
