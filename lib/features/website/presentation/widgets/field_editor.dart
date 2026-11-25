import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/website/data/website_models.dart';
import 'package:nizan_crm/features/website/services/website_service.dart';
import 'package:nizan_crm/features/website/presentation/widgets/website_image_field.dart';

/// Editor for one field, chosen by its type from the backend registry.
/// [uploadSection] is where images for this field are uploaded ('hero', 'package', …).
/// List items are edited in place and handed back through [onChanged].
class FieldEditor extends StatelessWidget {
  final FieldDef def;
  final dynamic value;
  final ValueChanged<dynamic> onChanged;
  final String uploadSection;

  const FieldEditor({
    super.key,
    required this.def,
    required this.value,
    required this.onChanged,
    required this.uploadSection,
  });

  String get _label => '${def.label}${def.required ? ' *' : ''}';

  @override
  Widget build(BuildContext context) {
    switch (def.type) {
      case 'image':
        final rule = def.upload;
        if (rule == null) return Text('${def.label}: no upload rule');
        return WebsiteImageField(
          label: def.label,
          required: def.required,
          rule: rule,
          section: uploadSection,
          field: def.name,
          value: value,
          onChanged: onChanged,
        );
      case 'boolean':
        return SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(def.label),
          value: value == true,
          onChanged: onChanged,
        );
      case 'list':
        return _ListFieldEditor(
          def: def,
          value: value,
          onChanged: onChanged,
          uploadSection: uploadSection,
        );
      case 'textList':
        return _TextListEditor(def: def, value: value, onChanged: onChanged);
      case 'keyedText':
        return _KeyedTextEditor(def: def, value: value, onChanged: onChanged);
      case 'number':
        return TextFormField(
          initialValue: value == null ? '' : '$value',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
          ],
          decoration: InputDecoration(labelText: _label, isDense: true),
          onChanged: (v) =>
              onChanged(v.trim().isEmpty ? null : num.tryParse(v.trim())),
        );
      default: // text, textarea, url, email, phone
        final multi = def.type == 'textarea';
        return TextFormField(
          initialValue: value?.toString() ?? '',
          maxLength: def.maxLength,
          minLines: multi ? 2 : 1,
          maxLines: multi ? 6 : 1,
          keyboardType: switch (def.type) {
            'email' => TextInputType.emailAddress,
            'phone' => TextInputType.phone,
            'url' => TextInputType.url,
            _ => multi ? TextInputType.multiline : TextInputType.text,
          },
          decoration: InputDecoration(
            labelText: _label,
            isDense: true,
            helperText: def.type == 'url'
                ? 'https:// link, or a site page like /book'
                : null,
          ),
          onChanged: onChanged,
        );
    }
  }
}

/// A repeating group (FAQ items, steps, counters…). Items can be added,
/// moved and removed, up to the field's limit.
class _ListFieldEditor extends StatelessWidget {
  final FieldDef def;
  final dynamic value;
  final ValueChanged<dynamic> onChanged;
  final String uploadSection;

  const _ListFieldEditor({
    required this.def,
    required this.value,
    required this.onChanged,
    required this.uploadSection,
  });

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    // Keep the SAME item map objects between builds (ObjectKey relies on it), so
    // a text field keeps focus while typing. The editor's working copy is built
    // by deepCopyJson, which already yields Map<String, dynamic> items.
    final items = value is List
        ? (value as List)
              .map(
                (e) => e is Map<String, dynamic>
                    ? e
                    : (e is Map
                          ? Map<String, dynamic>.from(e)
                          : <String, dynamic>{}),
              )
              .toList()
        : <Map<String, dynamic>>[];
    final max = def.maxItems;
    final full = max != null && items.length >= max;

    void move(int from, int to) {
      final next = [...items];
      final item = next.removeAt(from);
      next.insert(to, item);
      onChanged(next);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${def.label}${max != null ? '  (${items.length}/$max)' : ''}',
          style: TextStyle(fontWeight: FontWeight.w600, color: crm.textPrimary),
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < items.length; i++)
          Card(
            key: ObjectKey(items[i]),
            margin: const EdgeInsets.only(bottom: 10),
            elevation: 0,
            color: crm.surface,
            shape: RoundedRectangleBorder(
              side: BorderSide(color: crm.border),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 4, 12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Text(
                        '#${i + 1}',
                        style: TextStyle(
                          color: crm.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: 'Move up',
                        icon: const Icon(Icons.arrow_upward, size: 18),
                        onPressed: i == 0 ? null : () => move(i, i - 1),
                      ),
                      IconButton(
                        tooltip: 'Move down',
                        icon: const Icon(Icons.arrow_downward, size: 18),
                        onPressed: i == items.length - 1
                            ? null
                            : () => move(i, i + 1),
                      ),
                      IconButton(
                        tooltip: 'Remove',
                        icon: Icon(
                          Icons.delete_outline,
                          size: 18,
                          color: crm.destructive,
                        ),
                        onPressed: () => onChanged([...items]..removeAt(i)),
                      ),
                    ],
                  ),
                  for (final sub in def.fields.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 8, bottom: 8),
                      child: FieldEditor(
                        def: sub,
                        value: items[i][sub.name],
                        uploadSection: uploadSection,
                        onChanged: (v) {
                          items[i][sub.name] =
                              v; // edited in place: the list keeps the same item objects
                          onChanged(items);
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        OutlinedButton.icon(
          onPressed: full
              ? null
              : () => onChanged([...items, <String, dynamic>{}]),
          icon: const Icon(Icons.add),
          label: Text(full ? 'Limit reached' : 'Add'),
        ),
      ],
    );
  }
}

/// A short list of plain strings (e.g. "What's included" on a package).
class _TextListEditor extends StatelessWidget {
  final FieldDef def;
  final dynamic value;
  final ValueChanged<dynamic> onChanged;

  const _TextListEditor({
    required this.def,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final items = value is List
        ? (value as List).map((e) => e.toString()).toList()
        : <String>[];
    final max = def.maxItems;
    final full = max != null && items.length >= max;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${def.label}${max != null ? '  (${items.length}/$max)' : ''}',
          style: TextStyle(fontWeight: FontWeight.w600, color: crm.textPrimary),
        ),
        for (var i = 0; i < items.length; i++)
          Row(
            key: ValueKey('${def.name}-$i-${items.length}'),
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: items[i],
                  maxLength: def.maxLength,
                  decoration: InputDecoration(
                    isDense: true,
                    counterText: '',
                    hintText: 'Item ${i + 1}',
                  ),
                  onChanged: (v) {
                    items[i] = v;
                    onChanged(items);
                  },
                ),
              ),
              IconButton(
                tooltip: 'Remove',
                icon: Icon(Icons.close, size: 18, color: crm.destructive),
                onPressed: () => onChanged([...items]..removeAt(i)),
              ),
            ],
          ),
        TextButton.icon(
          onPressed: full ? null : () => onChanged([...items, '']),
          icon: const Icon(Icons.add),
          label: Text(full ? 'Limit reached' : 'Add item'),
        ),
      ],
    );
  }
}

/// One short text per CRM package (the comparison table cells).
class _KeyedTextEditor extends ConsumerWidget {
  final FieldDef def;
  final dynamic value;
  final ValueChanged<dynamic> onChanged;

  const _KeyedTextEditor({
    required this.def,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crm = context.crmColors;
    final map = value is Map
        ? (value as Map).cast<String, dynamic>()
        : <String, dynamic>{};
    final async = ref.watch(websitePackagesProvider);

    return async.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text(
        'Could not load packages for this table.',
        style: TextStyle(color: crm.destructive),
      ),
      data: (data) {
        final shown = data.packages.where((p) => p.show).toList();
        if (shown.isEmpty) {
          return Text(
            'Switch on at least one package in "Packages" to fill this row.',
            style: TextStyle(color: crm.textSecondary, fontSize: 12),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              def.label,
              style: TextStyle(fontSize: 12, color: crm.textSecondary),
            ),
            for (final p in shown)
              TextFormField(
                key: ValueKey('${def.name}-${p.id}'),
                initialValue: map[p.id]?.toString() ?? '',
                maxLength: def.maxLength,
                decoration: InputDecoration(
                  labelText: p.name,
                  isDense: true,
                  counterText: '',
                ),
                onChanged: (v) {
                  map[p.id] = v;
                  onChanged(map);
                },
              ),
          ],
        );
      },
    );
  }
}
