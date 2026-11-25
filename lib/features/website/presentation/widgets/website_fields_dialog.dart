import 'package:flutter/material.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/website/data/website_models.dart';
import 'package:nizan_crm/features/website/presentation/widgets/field_editor.dart';

/// A dialog that edits a set of registry fields (e.g. a package's website text)
/// and saves them with [onSave]. Server validation messages are shown inline.
class WebsiteFieldsDialog extends StatefulWidget {
  final String title;
  final String? subtitle;
  final Map<String, FieldDef> fields;
  final Map<String, dynamic> initial;
  final String uploadSection;
  final Future<void> Function(Map<String, dynamic> data) onSave;
  final List<Widget> headerChildren;

  const WebsiteFieldsDialog({
    super.key,
    required this.title,
    required this.fields,
    required this.initial,
    required this.uploadSection,
    required this.onSave,
    this.subtitle,
    this.headerChildren = const [],
  });

  @override
  State<WebsiteFieldsDialog> createState() => _WebsiteFieldsDialogState();
}

class _WebsiteFieldsDialogState extends State<WebsiteFieldsDialog> {
  late final Map<String, dynamic> _data = {
    for (final k in widget.fields.keys) k: deepCopyJson(widget.initial[k]),
  };
  bool _busy = false;
  List<String> _errors = const [];

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _errors = const [];
    });
    try {
      await widget.onSave(_data);
      if (mounted) Navigator.pop(context, true);
    } on WebsiteValidationException catch (e) {
      if (mounted) {
        setState(() => _errors = e.errors.isEmpty ? [e.message] : e.errors);
      }
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 620,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.subtitle != null)
                Text(
                  widget.subtitle!,
                  style: TextStyle(color: crm.textSecondary, fontSize: 12),
                ),
              ...widget.headerChildren,
              if (_errors.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _errors.map((e) => '• $e').join('\n'),
                    style: TextStyle(color: crm.destructive),
                  ),
                ),
              const SizedBox(height: 12),
              for (final def in widget.fields.values)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: FieldEditor(
                    def: def,
                    value: _data[def.name],
                    uploadSection: widget.uploadSection,
                    onChanged: (v) => setState(() => _data[def.name] = v),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: _busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}
