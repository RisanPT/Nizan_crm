import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nizan_crm/features/fleet/presentation/widgets/bill_attachment_field.dart';

Widget _wrap(Widget child) => ProviderScope(
      child: MaterialApp(home: Scaffold(body: child)),
    );

void main() {
  testWidgets('prompts as required when nothing is attached', (tester) async {
    await tester.pumpWidget(_wrap(
      BillAttachmentField(value: null, onChanged: (_) {}),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('Attach bill / screenshot'), findsOneWidget);
    expect(find.textContaining('Required'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows the error state after a failed submit', (tester) async {
    await tester.pumpWidget(_wrap(
      BillAttachmentField(value: null, onChanged: (_) {}, isMissing: true),
    ));
    await tester.pumpAndSettle();

    expect(
      find.text('A bill / screenshot is required for this expense.'),
      findsOneWidget,
    );
  });

  testWidgets('confirms attachment and allows removal', (tester) async {
    String? current = 'https://example.com/bill.jpg';
    await tester.pumpWidget(_wrap(
      StatefulBuilder(
        builder: (context, setState) => BillAttachmentField(
          value: current,
          onChanged: (v) => setState(() => current = v),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Bill attached — tap to change'), findsOneWidget);
    // The required hint disappears once a bill is attached.
    expect(find.textContaining('Required'), findsNothing);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(current, isNull);
    expect(tester.takeException(), isNull);
  });
}
