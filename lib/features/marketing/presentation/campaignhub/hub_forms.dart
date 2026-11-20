import 'package:flutter/material.dart';

import 'package:nizan_crm/features/marketing/presentation/kit/mkt_kit.dart';

// What every Campaigns form (campaign, ad, a day's figures, the Meta import) is built from: a dialog on a laptop, a bottom sheet on a phone,
// a refusal shown inside the form, and a footer whose Save is disabled while it saves.

/// Open [form] as a dialog (≥ 700px wide) or a bottom sheet.
Future<T?> showHubForm<T>(BuildContext context, Widget form, {double maxWidth = 640}) {
  if (MediaQuery.sizeOf(context).width >= 700) {
    return showDialog<T>(context: context, builder: (_) => Dialog(child: ConstrainedBox(constraints: BoxConstraints(maxWidth: maxWidth), child: form)));
  }
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (ctx) => Padding(padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom), child: form),
  );
}

InputDecoration hubDec(String label, {String? hint, String? helper}) => InputDecoration(labelText: label, hintText: hint, helperText: helper, helperMaxLines: 2, isDense: true, border: const OutlineInputBorder());

/// A scrolling body with a pinned footer: the refusal (if any) above Cancel / Save.
class HubFormFrame extends StatelessWidget {
  const HubFormFrame({super.key, required this.title, required this.children, required this.keyPrefix, required this.saving, required this.error, required this.onSave, required this.saveLabel, this.onCancel, this.leading});
  final String title, keyPrefix, saveLabel;
  final List<Widget> children;
  final bool saving;
  final String? error;
  final VoidCallback? onSave;
  final VoidCallback? onCancel;
  final Widget? leading;

  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, children: [
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(title, style: mktText(19, weight: FontWeight.w800)),
              const SizedBox(height: 12),
              ...children,
            ]),
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: Mkt.border))),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (error != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(error!, key: Key('${keyPrefix}_error'), style: mktText(12.5, weight: FontWeight.w600, color: Mkt.bad))),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (leading != null) Flexible(child: leading!),
              // the buttons wrap under each other on a narrow screen instead of running off its edge
              Expanded(
                child: Wrap(alignment: WrapAlignment.end, spacing: 10, runSpacing: 6, children: [
                  OutlinedButton(key: Key('${keyPrefix}_cancel'), onPressed: saving ? null : (onCancel ?? () => Navigator.pop(context)), child: const Text('Cancel')),
                  FilledButton(key: Key('${keyPrefix}_save'), style: FilledButton.styleFrom(backgroundColor: Mkt.maroon), onPressed: saving ? null : onSave, child: saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : Text(saveLabel)),
                ]),
              ),
            ]),
          ]),
        ),
      ]);
}

/// A number typed in a form: "12,500", "1250.5" → the value; blank → [blank]; anything else → null (the form says so).
double? parseHubNumber(String text, {double? blank = 0}) {
  final t = text.replaceAll(',', '').replaceAll('₹', '').trim();
  if (t.isEmpty) return blank;
  return double.tryParse(t);
}
