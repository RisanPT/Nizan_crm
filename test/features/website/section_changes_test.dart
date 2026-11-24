import 'package:flutter_test/flutter_test.dart';
import 'package:nizan_crm/features/website/data/section_changes.dart';
import 'package:nizan_crm/features/website/data/website_models.dart';

void main() {
  const fields = {
    'title': FieldDef(name: 'title', type: 'text', label: 'Title'),
    'subtitle': FieldDef(name: 'subtitle', type: 'textarea', label: 'Subtitle'),
    'stats': FieldDef(name: 'stats', type: 'list', label: 'Counters'),
  };

  test('lists the fields that differ from what visitors see', () {
    final changed = changedFieldLabels(
      fields,
      {'title': 'New', 'subtitle': 'Same', 'stats': [{'value': 1}]},
      {'title': 'Old', 'subtitle': 'Same', 'stats': [{'value': 2}]},
    );
    expect(changed, ['Title', 'Counters']);
  });

  test('an empty field is not a change (the website keeps its own text)', () {
    expect(changedFieldLabels(fields, {'title': '', 'stats': []}, {'title': 'Old'}), isEmpty);
  });
}
