import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/state/data_refresh.dart';

import '../../controllers/consultation_provider.dart';
import '../../data/consultation.dart';
import '../../services/consultation_service.dart';
import 'consultation_ui.dart';

// Each dialog returns true when it changed the consultation. They refresh the
// shared consultation providers themselves, so callers only need to react.

Future<bool> showRescheduleDialog(
  BuildContext context,
  Consultation consultation, {
  required bool isLead,
}) async {
  final changed = await showDialog<bool>(
    context: context,
    builder: (_) => _RescheduleDialog(consultation: consultation, isLead: isLead),
  );
  return changed ?? false;
}

Future<bool> showCancelDialog(BuildContext context, Consultation consultation) async {
  final changed = await showDialog<bool>(
    context: context,
    builder: (_) => _CancelDialog(consultation: consultation),
  );
  return changed ?? false;
}

Future<bool> showEditMeetingDialog(BuildContext context, Consultation consultation) async {
  final changed = await showDialog<bool>(
    context: context,
    builder: (_) => _EditMeetingDialog(consultation: consultation),
  );
  return changed ?? false;
}

// ── Reschedule ───────────────────────────────────────────────────────────────
class _RescheduleDialog extends ConsumerStatefulWidget {
  const _RescheduleDialog({required this.consultation, required this.isLead});

  final Consultation consultation;
  final bool isLead;

  @override
  ConsumerState<_RescheduleDialog> createState() => _RescheduleDialogState();
}

class _RescheduleDialogState extends ConsumerState<_RescheduleDialog> {
  late DateTime _when = widget.consultation.scheduledAt;
  late int _duration = widget.consultation.durationMins;
  late String _stylistId = widget.consultation.stylistId;
  final _reason = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _save({bool force = false}) async {
    setState(() => _saving = true);
    try {
      await ref.read(consultationServiceProvider).reschedule(
            widget.consultation.id,
            scheduledAt: _when,
            durationMins: _duration,
            stylistId: _stylistId == widget.consultation.stylistId ? null : _stylistId,
            reason: _reason.text.trim(),
            force: force,
          );
      ref.refreshData.consultations();
      if (!mounted) return;
      showSuccessSnackBar(context, 'Consultation rescheduled');
      Navigator.pop(context, true);
    } on ScheduleConflictException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      final bookAnyway = await showConflictDialog(context, e, canOverride: widget.isLead);
      if (bookAnyway && mounted) await _save(force: true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showErrorSnackBar(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final stylists = widget.isLead ? ref.watch(consultationStylistsProvider).value : null;
    return AlertDialog(
      title: const Text('Reschedule consultation'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SchedulePickerFields(
                value: _when,
                durationMins: _duration,
                onChanged: (d) => setState(() => _when = d),
                onDurationChanged: (d) => setState(() => _duration = d),
              ),
              if (stylists != null && stylists.isNotEmpty) ...[
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: stylists.any((s) => s.id == _stylistId) ? _stylistId : null,
                  decoration: const InputDecoration(
                    labelText: 'Stylist',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: [
                    for (final s in stylists) DropdownMenuItem(value: s.id, child: Text(s.name)),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _stylistId = v);
                  },
                ),
              ],
              const SizedBox(height: 16),
              TextField(
                controller: _reason,
                decoration: const InputDecoration(
                  labelText: 'Reason (optional)',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Reschedule'),
        ),
      ],
    );
  }
}

// ── Cancel ───────────────────────────────────────────────────────────────────
class _CancelDialog extends ConsumerStatefulWidget {
  const _CancelDialog({required this.consultation});

  final Consultation consultation;

  @override
  ConsumerState<_CancelDialog> createState() => _CancelDialogState();
}

class _CancelDialogState extends ConsumerState<_CancelDialog> {
  final _reason = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref
          .read(consultationServiceProvider)
          .cancel(widget.consultation.id, reason: _reason.text.trim());
      ref.refreshData.consultations();
      if (!mounted) return;
      showSuccessSnackBar(context, 'Consultation cancelled');
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showErrorSnackBar(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Cancel consultation?'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.consultation.clientName} · ${fmtDateTime(widget.consultation.scheduledAt)}\n'
              'The time slot is freed. This cannot be undone.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _reason,
              decoration: const InputDecoration(
                labelText: 'Reason (optional)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('Keep it'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Cancel consultation'),
        ),
      ],
    );
  }
}

// ── Edit meeting details ─────────────────────────────────────────────────────
class _EditMeetingDialog extends ConsumerStatefulWidget {
  const _EditMeetingDialog({required this.consultation});

  final Consultation consultation;

  @override
  ConsumerState<_EditMeetingDialog> createState() => _EditMeetingDialogState();
}

class _EditMeetingDialogState extends ConsumerState<_EditMeetingDialog> {
  late String _mode = widget.consultation.mode;
  late final _link = TextEditingController(text: widget.consultation.meetingLink);
  late final _location = TextEditingController(text: widget.consultation.location);
  bool _saving = false;

  @override
  void dispose() {
    _link.dispose();
    _location.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(consultationServiceProvider).update(widget.consultation.id, {
        'mode': _mode,
        'meetingLink': _link.text.trim(),
        'location': _location.text.trim(),
      });
      ref.refreshData.consultations();
      if (!mounted) return;
      showSuccessSnackBar(context, 'Meeting details saved');
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showErrorSnackBar(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Meeting details'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SegmentedButton<String>(
                segments: [
                  for (final m in kConsultationModes) ButtonSegment(value: m, label: Text(m)),
                ],
                selected: {_mode},
                onSelectionChanged: (s) => setState(() => _mode = s.first),
              ),
              const SizedBox(height: 16),
              if (_mode == 'Video')
                TextField(
                  controller: _link,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: 'Meet / Zoom link',
                    hintText: 'Paste the meeting link',
                    border: OutlineInputBorder(),
                  ),
                )
              else
                TextField(
                  controller: _location,
                  decoration: const InputDecoration(
                    labelText: 'Location',
                    border: OutlineInputBorder(),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Save'),
        ),
      ],
    );
  }
}
