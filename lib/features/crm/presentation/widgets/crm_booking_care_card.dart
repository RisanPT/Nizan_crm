import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/crm/data/crm_weekly_models.dart';
import 'package:nizan_crm/features/crm/services/crm_weekly_service.dart';

final _dayFmt = DateFormat('EEE d MMM');
String crmDayLabel(String day) {
  final d = DateTime.tryParse(day);
  return d == null ? day : _dayFmt.format(d);
}

String _todayKey() => DateFormat('yyyy-MM-dd').format(DateTime.now());

/// Reloads what shows a booking's care: the card, the to-do lists and the weekly report.
void refreshCrmCare(WidgetRef ref) {
  ref.invalidate(crmCareProvider);
  ref.invalidate(crmCareListProvider);
  ref.invalidate(crmWeeklyProvider);
}

/// On a booking (CRM team and management): each work day verified with the client and its photos collected, the client's medical
/// conditions, and medical emergencies. Leadership sees it without the buttons.
class CrmBookingCareCard extends ConsumerWidget {
  const CrmBookingCareCard({super.key, required this.bookingId, this.today});
  final String bookingId;

  /// What "today" is ('yyyy-MM-dd') — for tests.
  final String? today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crm = context.crmColors;
    final async = ref.watch(crmCareProvider(bookingId));
    return Container(
      key: const Key('crmCareCard'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: crm.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: crm.border)),
      child: async.when(
        loading: () => const SizedBox(height: 60, child: Center(child: CircularProgressIndicator())),
        error: (e, _) => Text(friendlyErrorMessage(e), style: TextStyle(color: crm.textSecondary)),
        data: (c) => _body(context, ref, crm, c),
      ),
    );
  }

  Widget _body(BuildContext context, WidgetRef ref, CrmTheme crm, CrmCare c) {
    final today = this.today ?? _todayKey();
    final svc = ref.read(crmWeeklyServiceProvider);
    Future<void> run(Future<Object?> Function() f) async {
      try {
        await f();
        refreshCrmCare(ref);
      } catch (e) {
        if (context.mounted) showErrorSnackBar(context, e);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(Icons.support_agent_outlined, size: 18, color: crm.primary),
          const SizedBox(width: 8),
          Text('CRM care', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: crm.textPrimary)),
        ]),
        const SizedBox(height: 4),
        Text('Verify each work day with the client, tick the photos once collected, and keep the client\'s health notes here — the artists on the work see them.',
            style: TextStyle(fontSize: 12, color: crm.textSecondary)),
        const SizedBox(height: 12),
        if (c.days.isEmpty) Text('This booking has no work days yet.', style: TextStyle(color: crm.textSecondary)),
        for (final day in c.days)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(width: 110, child: Text(crmDayLabel(day), style: TextStyle(fontWeight: FontWeight.w700, color: crm.textPrimary))),
                _tickChip(
                  key: Key('crmVerify_$day'),
                  crm: crm,
                  label: 'Verified with client',
                  mark: c.verifiedOn(day),
                  enabled: c.canWrite,
                  onChanged: (v) => run(() => svc.verify(bookingId, day, done: v)),
                ),
                _tickChip(
                  key: Key('crmPhotos_$day'),
                  crm: crm,
                  label: 'Photos collected',
                  mark: c.photosOn(day),
                  enabled: c.canWrite && day.compareTo(today) <= 0,
                  disabledReason: day.compareTo(today) > 0 ? 'after the work' : null,
                  onChanged: (v) => run(() => svc.photos(bookingId, day, done: v)),
                ),
              ],
            ),
          ),
        const Divider(height: 24),
        Row(
          children: [
            Icon(Icons.medical_information_outlined, size: 18, color: c.hasMedical ? crm.destructive : crm.textSecondary),
            const SizedBox(width: 8),
            Expanded(child: Text('Client health', style: TextStyle(fontWeight: FontWeight.w800, color: crm.textPrimary))),
            if (c.canWrite)
              TextButton(
                key: const Key('crmEditMedical'),
                onPressed: () async {
                  final r = await showDialog<(List<String>, String)>(context: context, builder: (_) => _MedicalDialog(conditions: c.conditions, note: c.medicalNote));
                  if (r != null) await run(() => svc.setMedical(bookingId, r.$1, r.$2));
                },
                child: Text(c.hasMedical || c.medicalNote.isNotEmpty ? 'Edit' : 'Add'),
              ),
          ],
        ),
        CrmHealthLine(care: c, emptyText: 'Nothing noted.'),
        const SizedBox(height: 12),
        Row(
          children: [
            Text('Emergencies', style: TextStyle(fontWeight: FontWeight.w800, color: crm.textPrimary)),
            const Spacer(),
            if (c.canWrite && c.days.any((d) => d.compareTo(today) <= 0))
              TextButton.icon(
                key: const Key('crmLogEmergency'),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Log one'),
                onPressed: () async {
                  final r = await showDialog<(String, String, String)>(
                    context: context,
                    builder: (_) => _EmergencyDialog(days: c.days.where((d) => d.compareTo(today) <= 0).toList()),
                  );
                  if (r != null) await run(() => svc.addEmergency(bookingId, day: r.$1, what: r.$2, action: r.$3));
                },
              ),
          ],
        ),
        if (c.emergencies.isEmpty) Text('None.', style: TextStyle(color: crm.textSecondary)),
        for (final e in c.emergencies)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.warning_amber_rounded, size: 18, color: crm.destructive),
              const SizedBox(width: 8),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${crmDayLabel(e.day)} — ${e.what}', style: TextStyle(fontWeight: FontWeight.w600, color: crm.textPrimary)),
                  if (e.action.isNotEmpty) Text('Done: ${e.action}', style: TextStyle(fontSize: 12.5, color: crm.textPrimary)),
                  Text('Logged by ${e.byName.isEmpty ? 'the CRM' : e.byName}', style: TextStyle(fontSize: 11.5, color: crm.textSecondary)),
                ]),
              ),
            ]),
          ),
      ],
    );
  }

  Widget _tickChip({required Key key, required CrmTheme crm, required String label, required CrmDayMark? mark, required bool enabled, String? disabledReason, required ValueChanged<bool> onChanged}) {
    final done = mark != null;
    return Tooltip(
      message: done ? '$label by ${mark.byName.isEmpty ? 'the CRM' : mark.byName}${mark.at == null ? '' : ', ${DateFormat('d MMM, h:mm a').format(mark.at!)}'}${mark.note.isEmpty ? '' : ' — ${mark.note}'}' : (disabledReason == null ? '' : 'Only $disabledReason'),
      child: FilterChip(
        key: key,
        label: Text(done && mark.byName.isNotEmpty ? '$label · ${mark.byName}' : label),
        selected: done,
        showCheckmark: true,
        selectedColor: crm.success.withValues(alpha: 0.15),
        onSelected: enabled ? onChanged : null,
      ),
    );
  }
}

/// The client's conditions and note, in red — or [emptyText].
class CrmHealthLine extends StatelessWidget {
  const CrmHealthLine({super.key, required this.care, this.emptyText});
  final CrmCare care;
  final String? emptyText;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    if (!care.hasMedical && care.medicalNote.isEmpty) {
      return emptyText == null ? const SizedBox.shrink() : Text(emptyText!, style: TextStyle(color: crm.textSecondary));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final c in care.conditions)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: crm.destructive.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(20)),
              child: Text(crmMedicalLabel(c), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: crm.destructive)),
            ),
        ]),
        if (care.medicalNote.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text(care.medicalNote, style: TextStyle(color: crm.textPrimary))),
      ],
    );
  }
}

/// On an artist's work: the client's health notes (shown only when there are some — the server lets the artists on the work read them).
class CrmClientHealthNote extends ConsumerWidget {
  const CrmClientHealthNote({super.key, required this.bookingId});
  final String bookingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crm = context.crmColors;
    final c = ref.watch(crmCareProvider(bookingId)).value;
    if (c == null || (!c.hasMedical && c.medicalNote.isEmpty)) return const SizedBox.shrink();
    return Container(
      key: Key('crmHealthNote_$bookingId'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: crm.destructive.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: crm.destructive.withValues(alpha: 0.3)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.medical_information_outlined, size: 20, color: crm.destructive),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Client health — read before you start', style: TextStyle(fontWeight: FontWeight.w800, color: crm.destructive)),
            const SizedBox(height: 6),
            CrmHealthLine(care: c),
          ]),
        ),
      ]),
    );
  }
}

class _MedicalDialog extends StatefulWidget {
  const _MedicalDialog({required this.conditions, required this.note});
  final List<String> conditions;
  final String note;
  @override
  State<_MedicalDialog> createState() => _MedicalDialogState();
}

class _MedicalDialogState extends State<_MedicalDialog> {
  late final Set<String> _picked = {...widget.conditions};
  late final _note = TextEditingController(text: widget.note);
  String? _error;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Client health'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final c in crmMedicalConditions)
                FilterChip(
                  key: Key('crmCondition_$c'),
                  label: Text(crmMedicalLabel(c)),
                  selected: _picked.contains(c),
                  onSelected: (v) => setState(() => v ? _picked.add(c) : _picked.remove(c)),
                ),
            ]),
            const SizedBox(height: 10),
            TextField(
              key: const Key('crmMedicalNote'),
              controller: _note,
              minLines: 2,
              maxLines: 4,
              decoration: InputDecoration(labelText: 'Note for the artists (what to avoid, what to use)', errorText: _error),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          key: const Key('crmMedicalSave'),
          onPressed: () {
            if (_picked.contains('other') && _note.text.trim().length < 3) {
              setState(() => _error = 'Say what the other condition is.');
              return;
            }
            Navigator.pop(context, ([for (final c in crmMedicalConditions) if (_picked.contains(c)) c], _note.text.trim()));
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _EmergencyDialog extends StatefulWidget {
  const _EmergencyDialog({required this.days});
  final List<String> days;
  @override
  State<_EmergencyDialog> createState() => _EmergencyDialogState();
}

class _EmergencyDialogState extends State<_EmergencyDialog> {
  late String _day = widget.days.last;
  final _what = TextEditingController();
  final _action = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _what.dispose();
    _action.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Log a medical emergency'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _day,
              decoration: const InputDecoration(labelText: 'Work day'),
              items: [for (final d in widget.days) DropdownMenuItem(value: d, child: Text(crmDayLabel(d)))],
              onChanged: (v) => setState(() => _day = v ?? _day),
            ),
            TextField(key: const Key('crmEmergencyWhat'), controller: _what, minLines: 2, maxLines: 4, decoration: InputDecoration(labelText: 'What happened', errorText: _error)),
            TextField(controller: _action, minLines: 1, maxLines: 3, decoration: const InputDecoration(labelText: 'What was done')),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          key: const Key('crmEmergencySave'),
          onPressed: () {
            if (_what.text.trim().length < 3) {
              setState(() => _error = 'Say what happened.');
              return;
            }
            Navigator.pop(context, (_day, _what.text.trim(), _action.text.trim()));
          },
          child: const Text('Log it'),
        ),
      ],
    );
  }
}
