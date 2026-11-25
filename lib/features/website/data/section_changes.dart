import 'dart:convert';

import 'package:nizan_crm/features/website/data/website_models.dart';

bool _isEmpty(dynamic v) =>
    v == null || v == '' || (v is List && v.isEmpty) || (v is Map && v.isEmpty);

String _norm(dynamic v) => _isEmpty(v) ? '' : jsonEncode(v);

/// Labels of the fields whose value on screen differs from [baseline]
/// (what the website shows now: the live section, or its built-in text).
/// An empty field counts as "unchanged" — the website keeps its own text there.
List<String> changedFieldLabels(
  Map<String, FieldDef> fields,
  Map<String, dynamic> current,
  Map<String, dynamic> baseline,
) {
  final out = <String>[];
  for (final def in fields.values) {
    final now = current[def.name];
    if (_isEmpty(now)) continue;
    if (_norm(now) != _norm(baseline[def.name])) out.add(def.label);
  }
  return out;
}
