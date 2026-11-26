import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/allocation/data/allocation_models.dart';
import 'package:nizan_crm/features/allocation/services/allocation_service.dart';

/// The allocation's rules: on / trial / off (admins and managers), the clash check, the evening cut-off, the 30 minutes, the ready buffer,
/// a job's default length, the extras a day. → true when saved.
Future<bool?> showAllocationSettingsDialog(BuildContext context, AllocationSettings s) => showDialog<bool>(context: context, builder: (_) => _SettingsDialog(s: s));

class _SettingsDialog extends ConsumerStatefulWidget {
  const _SettingsDialog({required this.s});
  final AllocationSettings s;
  @override
  ConsumerState<_SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends ConsumerState<_SettingsDialog> {
  late String _mode = widget.s.mode;
  late bool _guard = widget.s.guard == 'on';
  late bool _auto = widget.s.autoAllocate == 'on';
  late String _extraWhen = widget.s.extraWhen;
  late final _cutoff = TextEditingController(text: widget.s.eveningCutoff);
  late final _travel = TextEditingController(text: '${widget.s.travelLimitMin}');
  late final _ready = TextEditingController(text: '${widget.s.readyBufferMin}');
  late final _job = TextEditingController(text: '${widget.s.defaultJobMin}');
  late final _extras = TextEditingController(text: '${widget.s.extrasPerDay}');
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_cutoff, _travel, _ready, _job, _extras]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(allocationServiceProvider).saveSettings({
        if (widget.s.canChangeMode) 'mode': _mode,
        if (widget.s.canChangeMode) 'guard': _guard ? 'on' : 'off',
        if (widget.s.canChangeMode) 'autoAllocate': _auto ? 'on' : 'off',
        'eveningCutoff': _cutoff.text.trim(),
        'travelLimitMin': int.tryParse(_travel.text.trim()) ?? -1,
        'readyBufferMin': int.tryParse(_ready.text.trim()) ?? -1,
        'defaultJobMin': int.tryParse(_job.text.trim()) ?? -1,
        'extrasPerDay': int.tryParse(_extras.text.trim()) ?? -1,
        'extraWhen': _extraWhen,
      });
      refreshAllocation(ref);
      if (mounted) Navigator.pop(context, true);
    } on AllocationRefusal catch (r) {
      if (mounted) setState(() => _error = r.message);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyErrorMessage(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _num(String label, TextEditingController c, String keyName, {String? hint}) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextField(key: Key(keyName), controller: c, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: label, hintText: hint, border: const OutlineInputBorder(), isDense: true)),
      );

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return AlertDialog(
      key: const Key('alloc_settings'),
      title: const Text('Allocation rules'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (widget.s.canChangeMode) ...[
              Text('The allocation is', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: crm.textSecondary)),
              const SizedBox(height: 6),
              SegmentedButton<String>(
                key: const Key('alloc_mode'),
                segments: const [ButtonSegment(value: 'off', label: Text('Off')), ButtonSegment(value: 'shadow', label: Text('On trial')), ButtonSegment(value: 'suggest', label: Text('On'))],
                selected: {_mode},
                onSelectionChanged: (v) => setState(() => _mode = v.first),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 6, bottom: 4),
                child: Text(
                  switch (_mode) {
                    'shadow' => 'On trial: the ERP quietly notes what it would suggest for new bookings — coordinators see nothing new yet.',
                    'suggest' => 'On: coordinators get the ranked teams when they confirm a new booking. Bookings from before stay as they are.',
                    _ => 'Off: nothing changes for anyone.',
                  },
                  style: TextStyle(fontSize: 12, color: crm.textSecondary),
                ),
              ),
              SwitchListTile(
                key: const Key('alloc_auto'),
                contentPadding: EdgeInsets.zero,
                value: _auto,
                onChanged: _mode == 'suggest' ? (v) => setState(() => _auto = v) : null,
                title: const Text('Assign automatically'),
                subtitle: const Text('A new booking gets its team the moment it is confirmed — only when it is on her route or her preferred location. The rest wait for CRM.'),
              ),
              SwitchListTile(
                key: const Key('alloc_guard'),
                contentPadding: EdgeInsets.zero,
                value: _guard,
                onChanged: _mode == 'suggest' ? (v) => setState(() => _guard = v) : null,
                title: const Text('Clash check on Manage Booking'),
                subtitle: const Text('Ask "assign anyway?" when an artist put on a new booking is busy, on leave or out of slots.'),
              ),
              const Divider(),
            ],
            _num('Evening starts at (HH:MM)', _cutoff, 'alloc_cutoff', hint: '14:00'),
            _num('"Same area" — drive minutes at most', _travel, 'alloc_travel'),
            _num('Ready time at the next venue (minutes)', _ready, 'alloc_ready'),
            _num('A job with no end time lasts (minutes)', _job, 'alloc_job'),
            _num('EXTRA slots a day (company-wide)', _extras, 'alloc_extras'),
            DropdownButtonFormField<String>(
              key: const Key('alloc_extra_when'),
              initialValue: _extraWhen,
              isExpanded: true, // long choices shrink to the dialog's width (a phone) instead of overflowing
              decoration: const InputDecoration(labelText: 'Offer an extra slot once', border: OutlineInputBorder(), isDense: true),
              items: const [
                DropdownMenuItem(value: 'half_full', child: Text('that half (morning / evening) is full', overflow: TextOverflow.ellipsis)),
                DropdownMenuItem(value: 'day_full', child: Text('the whole day is full', overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (v) => setState(() => _extraWhen = v ?? 'half_full'),
            ),
            if (_error != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(_error!, key: const Key('alloc_settings_error'), style: TextStyle(color: crm.destructive, fontWeight: FontWeight.w600))),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(key: const Key('alloc_settings_save'), style: FilledButton.styleFrom(backgroundColor: crm.primary), onPressed: _saving ? null : _save, child: const Text('Save')),
      ],
    );
  }
}
