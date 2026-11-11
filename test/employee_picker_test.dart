import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nizan_crm/core/models/employee.dart';
import 'package:nizan_crm/core/theme/app_theme.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/core/widgets/employee_picker.dart';

Employee _emp(String id, String name, String dept) =>
    Employee.fromJson({'_id': id, 'name': name, 'department': dept, 'status': 'active'});

final _staff = [_emp('e1', 'Irfan', 'IT'), _emp('e2', 'Imran', 'IT'), _emp('e3', 'Hana', 'HR')];

Future<void> _openPicker(WidgetTester tester, {String? selectedId, ValueChanged<Employee?>? onChanged}) async {
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.lightTheme,
    home: Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: EmployeePickerField(
          employees: _staff,
          selectedId: selectedId,
          label: 'Owner',
          onChanged: onChanged ?? (_) {},
        ),
      ),
    ),
  ));
  await tester.tap(find.byType(EmployeePickerField));
  await tester.pumpAndSettle();
}

void main() {
  group('EmployeePicker sheet', () {
    testWidgets('opens with a selection without the framework reporting a ListTile-on-DecoratedBox problem', (tester) async {
      await _openPicker(tester, selectedId: 'e2');

      // The sheet used to put its ListTiles under an opaque coloured DecoratedBox, which trips a debug
      // assertion ("ListTile background color or ink splashes may be invisible") every time it opened.
      expect(tester.takeException(), isNull);

      for (final n in ['Irfan', 'Imran', 'Hana']) {
        expect(find.widgetWithText(ListTile, n), findsOneWidget);
      }
      final selected = tester.widgetList<ListTile>(find.byType(ListTile)).where((t) => t.selected).toList();
      expect(selected, hasLength(1));
      expect((selected.single.title as Text).data, 'Imran');
      expect(find.descendant(of: find.widgetWithText(ListTile, 'Imran'), matching: find.byIcon(Icons.check_circle)), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsOneWidget); // only the selected row carries it
    });

    testWidgets('the rows sit on a Material, so the selected tint and tap ink have somewhere to paint', (tester) async {
      await _openPicker(tester, selectedId: 'e1');
      expect(tester.takeException(), isNull);

      final material = tester.widget<Material>(
        find.ancestor(of: find.byType(ListTile).first, matching: find.byType(Material)).first,
      );
      expect(material.color, AppTheme.lightTheme.extension<CrmTheme>()!.surface);
      expect(material.clipBehavior, Clip.antiAlias);
      expect(material.shape, isA<RoundedRectangleBorder>());
      expect((material.shape! as RoundedRectangleBorder).borderRadius,
          const BorderRadius.vertical(top: Radius.circular(18)));
    });

    testWidgets('tapping a row picks that employee', (tester) async {
      Employee? picked;
      await _openPicker(tester, selectedId: 'e1', onChanged: (e) => picked = e);

      await tester.tap(find.widgetWithText(ListTile, 'Hana'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(picked?.id, 'e3');
      expect(find.byType(ListTile), findsNothing); // sheet closed
    });
  });
}
