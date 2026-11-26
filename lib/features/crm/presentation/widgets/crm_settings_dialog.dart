import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/crm/data/crm_models.dart';
import 'package:nizan_crm/features/crm/services/crm_service.dart';

/// The CRM team's time limits and thresholds (the CRM Head and management change them; PUT /api/crm/settings).
Future<void> showCrmSettingsDialog(BuildContext context, WidgetRef ref) async {
  CrmSettings s;
  try {
    s = await ref.read(crmServiceProvider).settings();
  } catch (e) {
    if (context.mounted) showErrorSnackBar(context, e);
    return;
  }
  if (!context.mounted) return;
  await showDialog<void>(context: context, builder: (_) => _SettingsDialog(initial: s));
}

class _SettingsDialog extends ConsumerStatefulWidget {
  const _SettingsDialog({required this.initial});
  final CrmSettings initial;

  @override
  ConsumerState<_SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends ConsumerState<_SettingsDialog> {
  late final Map<String, TextEditingController> _c = {
    'requestSlaHours': TextEditingController(text: '${widget.initial.requestSlaHours}'),
    'chatResponseSlaMins': TextEditingController(text: '${widget.initial.chatResponseSlaMins}'),
    'chatUnansweredHours': TextEditingController(text: '${widget.initial.chatUnansweredHours}'),
    for (final k in crmCaseKinds) 'case.$k': TextEditingController(text: '${widget.initial.caseSlaHours[k] ?? ''}'),
    'lowNps': TextEditingController(text: '${widget.initial.lowNps}'),
    'trialConversionDays': TextEditingController(text: '${widget.initial.trialConversionDays}'),
    'reEngagementWinDays': TextEditingController(text: '${widget.initial.reEngagementWinDays}'),
    'monthlyCustomerTarget': TextEditingController(text: '${widget.initial.monthlyCustomerTarget}'),
  };
  bool _saving = false;

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  Widget _field(String key, String label, String unit) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        SizedBox(
          width: 110,
          child: TextField(
            key: Key('crmSetting_$key'),
            controller: _c[key],
            textAlign: TextAlign.end,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(isDense: true, suffixText: unit, border: const OutlineInputBorder()),
          ),
        ),
      ],
    ),
  );

  Future<void> _save() async {
    int? v(String k) => int.tryParse(_c[k]!.text.trim());
    final body = <String, dynamic>{
      for (final k in ['requestSlaHours', 'chatResponseSlaMins', 'chatUnansweredHours', 'lowNps', 'trialConversionDays', 'reEngagementWinDays', 'monthlyCustomerTarget'])
        if (v(k) != null) k: v(k),
      'caseSlaHours': {for (final k in crmCaseKinds) if (v('case.$k') != null) k: v('case.$k')},
    };
    setState(() => _saving = true);
    try {
      await ref.read(crmServiceProvider).saveSettings(body);
      refreshCrm(ref);
      ref.invalidate(crmMeProvider);
      if (mounted) {
        Navigator.pop(context);
        showSuccessSnackBar(context, 'CRM settings saved');
      }
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final who = widget.initial.updatedByName;
    return AlertDialog(
      title: const Text('CRM time limits'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _field('requestSlaHours', 'Decide a booking request within', 'h'),
              _field('chatResponseSlaMins', 'Answer a client in chat within', 'min'),
              _field('chatUnansweredHours', 'A chat counts as left unanswered after', 'h'),
              const Divider(height: 24),
              for (final k in crmCaseKinds) _field('case.$k', 'Resolve a ${crmCaseKindLabel(k).toLowerCase()} within', 'h'),
              const Divider(height: 24),
              _field('lowNps', 'A review with NPS at or under this opens a complaint', ''),
              _field('trialConversionDays', 'A trial counts as booked if the client books within', 'days'),
              _field('reEngagementWinDays', 'A re-engagement call is won if the client books within', 'days'),
              const Divider(height: 24),
              _field('monthlyCustomerTarget', 'Weekly report: clients to handle in a month', ''),
              if (who.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 10), child: Text('Last changed by $who', style: const TextStyle(fontSize: 12))),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(key: const Key('crmSettingsSave'), onPressed: _saving ? null : _save, child: const Text('Save')),
      ],
    );
  }
}
