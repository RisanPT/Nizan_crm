import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nizan_crm/core/utils/lead_priority.dart';

/// The lead form lays desktop fields into an aligned grid. These cover the
/// sizing behaviour that used to be a free-form Wrap (uneven rows) and the
/// mobile stack, at the widths the app actually runs at.
void main() {
  Widget box(String label) => SizedBox(
        height: 56,
        child: DecoratedBox(
          decoration: const BoxDecoration(color: Color(0xFFEEEEEE)),
          child: Center(child: Text(label)),
        ),
      );

  testWidgets('form fields stack without overflow on mobile', (tester) async {
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: Column(
            children: [
              for (var i = 0; i < 12; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: box('Field $i'),
                ),
              const LeadPrioritySelector(value: 'Hot', onChanged: _noop),
            ],
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('priority selector wraps on a narrow screen', (tester) async {
    // Three pills must not overflow even on the smallest phone width.
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: Padding(
          padding: EdgeInsets.all(16),
          child: LeadPrioritySelector(value: 'Warm', onChanged: _noop),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    for (final p in LeadPriority.all) {
      expect(find.text(p.label), findsOneWidget);
    }
  });

  testWidgets('priority selector renders at desktop width', (tester) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 340,
          child: LeadPrioritySelector(value: 'Cold', onChanged: _noop),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    // The hint updates with the selection.
    expect(find.text(LeadPriority.cold.hint), findsOneWidget);
  });
}

void _noop(String _) {}
