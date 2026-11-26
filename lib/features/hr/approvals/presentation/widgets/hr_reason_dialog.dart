import 'package:flutter/material.dart';

/// Asks for a decision note. Returns the trimmed text, or null when dismissed.
/// With [required] (rejections) an empty reason is refused in the dialog. The
/// dialog owns its controller, so it is disposed only after the dialog is gone.
Future<String?> askHrReason(
  BuildContext context, {
  required String title,
  required String label,
  required String confirmLabel,
  bool required = true,
  String? hint,
  String cancelLabel = 'Cancel',
  Widget? header,
  Color? confirmColor,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _HrReasonDialog(
      title: title,
      label: label,
      confirmLabel: confirmLabel,
      required: required,
      hint: hint,
      cancelLabel: cancelLabel,
      header: header,
      confirmColor: confirmColor,
    ),
  );
}

class _HrReasonDialog extends StatefulWidget {
  const _HrReasonDialog({
    required this.title,
    required this.label,
    required this.confirmLabel,
    required this.required,
    required this.cancelLabel,
    this.hint,
    this.header,
    this.confirmColor,
  });

  final String title;
  final String label;
  final String confirmLabel;
  final bool required;
  final String cancelLabel;
  final String? hint;
  final Widget? header;
  final Color? confirmColor;

  @override
  State<_HrReasonDialog> createState() => _HrReasonDialogState();
}

class _HrReasonDialogState extends State<_HrReasonDialog> {
  final _ctrl = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _confirm() {
    final text = _ctrl.text.trim();
    if (widget.required && text.isEmpty) {
      setState(() => _error = 'Please give a reason');
      return;
    }
    Navigator.of(context).pop(text);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.header != null) ...[widget.header!, const SizedBox(height: 12)],
            TextField(
              controller: _ctrl,
              autofocus: true,
              minLines: 2,
              maxLines: 3,
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
              decoration: InputDecoration(
                labelText: widget.label,
                hintText: widget.hint,
                errorText: _error,
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(widget.cancelLabel)),
        FilledButton(
          style: widget.confirmColor == null ? null : FilledButton.styleFrom(backgroundColor: widget.confirmColor),
          onPressed: _confirm,
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
