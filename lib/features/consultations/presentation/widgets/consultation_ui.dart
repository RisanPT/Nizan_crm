import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/consultation.dart';
import '../../services/consultation_service.dart';

// ── After-call details ───────────────────────────────────────────────────────
/// One section of the after-call form. [key] is the server field name and
/// [maxLength] matches the server's limit (consultationRules TEXT_LIMITS).
class AfterCallField {
  const AfterCallField(this.key, this.label, this.hint, this.icon, {this.maxLength = 1000, this.lines = 2});

  final String key;
  final String label;
  final String hint;
  final IconData icon;
  final int maxLength;
  final int lines;
}

/// The after-call sections, in the order the form and the call page show them.
const kAfterCallFields = [
  AfterCallField('preferences', "Client's requirements", 'What the client asked for',
      Icons.favorite_border, maxLength: 2000, lines: 3),
  AfterCallField('conveyed', 'What we conveyed', 'What we suggested and told the client',
      Icons.campaign_outlined, maxLength: 3000, lines: 3),
  AfterCallField('lookMakeup', 'Makeup look', 'Style, finish, colours', Icons.brush_outlined),
  AfterCallField('lookHair', 'Hairstyle', 'Bun, waves, accessories…', Icons.content_cut),
  AfterCallField('lookOutfit', 'Outfit and jewellery', 'Outfit colours, jewellery, draping',
      Icons.checkroom_outlined),
  AfterCallField('skinNotes', 'Skin and allergy notes', 'Sensitivities, products to avoid',
      Icons.health_and_safety_outlined),
  AfterCallField('nextSteps', 'Next steps', 'What happens before the next call',
      Icons.flag_outlined, maxLength: 2000),
  AfterCallField('notes', 'Other notes', 'Anything else', Icons.notes_outlined,
      maxLength: 5000, lines: 3),
];

/// A readable name for a field key in the history ("lookHair" → "Hairstyle").
String afterCallFieldLabel(String key) {
  if (key == 'referenceImages') return 'Reference images';
  for (final f in kAfterCallFields) {
    if (f.key == key) return f.label;
  }
  return key;
}

// ── Status styling ───────────────────────────────────────────────────────────
Color consultationStatusColor(String status) {
  switch (status) {
    case 'Completed':
      return const Color(0xFF10B981);
    case 'Cancelled':
      return const Color(0xFFEF4444);
    case 'No-show':
      return const Color(0xFFF59E0B);
    default:
      return const Color(0xFF6366F1); // Scheduled
  }
}

IconData consultationStatusIcon(String status) {
  switch (status) {
    case 'Completed':
      return Icons.check_circle_outline;
    case 'Cancelled':
      return Icons.cancel_outlined;
    case 'No-show':
      return Icons.person_off_outlined;
    default:
      return Icons.event_available_outlined;
  }
}

/// Colour for the SRS client status derived from lead + consultations.
Color clientStatusColor(String status) {
  switch (status) {
    case 'Consultation Scheduled':
      return const Color(0xFF6366F1);
    case 'Appointment Confirmed':
      return const Color(0xFF10B981);
    case 'Follow-up Required':
      return const Color(0xFFF97316);
    case 'Cancelled':
      return const Color(0xFFEF4444);
    case 'Contacted':
      return const Color(0xFF3B82F6);
    default:
      return const Color(0xFF6B7280); // New
  }
}

// ── Formatting ───────────────────────────────────────────────────────────────
String fmtDay(DateTime d) => DateFormat('EEE, d MMM yyyy').format(d);
String fmtShortDay(DateTime d) => DateFormat('d MMM').format(d);
String fmtTime(DateTime d) => DateFormat('h:mm a').format(d);
String fmtDateTime(DateTime d) => DateFormat('d MMM yyyy, h:mm a').format(d);
String fmtRange(Consultation c) => '${fmtTime(c.scheduledAt)} – ${fmtTime(c.endsAt)}';

bool sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

// ── Small widgets ────────────────────────────────────────────────────────────
class ConsultationStatusChip extends StatelessWidget {
  const ConsultationStatusChip(this.status, {super.key, this.color});

  final String status;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? consultationStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(color: c, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// Date, time and duration pickers, shared by the booking form and the
/// reschedule dialog.
class SchedulePickerFields extends StatelessWidget {
  const SchedulePickerFields({
    super.key,
    required this.value,
    required this.durationMins,
    required this.onChanged,
    required this.onDurationChanged,
  });

  final DateTime value;
  final int durationMins;
  final ValueChanged<DateTime> onChanged;
  final ValueChanged<int> onDurationChanged;

  Future<void> _pickDate(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: value,
      firstDate: now.subtract(const Duration(days: 60)),
      lastDate: now.add(const Duration(days: 365 * 2)),
    );
    if (picked == null) return;
    onChanged(DateTime(picked.year, picked.month, picked.day, value.hour, value.minute));
  }

  Future<void> _pickTime(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(value),
    );
    if (picked == null) return;
    onChanged(DateTime(value.year, value.month, value.day, picked.hour, picked.minute));
  }

  @override
  Widget build(BuildContext context) {
    final durations = {...kConsultationDurations, durationMins}.toList()..sort();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            OutlinedButton.icon(
              onPressed: () => _pickDate(context),
              icon: const Icon(Icons.calendar_today_outlined, size: 18),
              label: Text(fmtDay(value)),
            ),
            OutlinedButton.icon(
              onPressed: () => _pickTime(context),
              icon: const Icon(Icons.access_time, size: 18),
              label: Text(fmtTime(value)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<int>(
          initialValue: durationMins,
          decoration: const InputDecoration(
            labelText: 'Duration',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          items: [
            for (final d in durations)
              DropdownMenuItem(value: d, child: Text('$d minutes')),
          ],
          onChanged: (d) {
            if (d != null) onDurationChanged(d);
          },
        ),
        const SizedBox(height: 6),
        Text(
          'Ends at ${fmtTime(value.add(Duration(minutes: durationMins)))}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

// ── Conflicts ────────────────────────────────────────────────────────────────
/// Lists the clashing consultations. Returns true when the user chooses to book
/// over them (only offered to a stylist lead).
Future<bool> showConflictDialog(
  BuildContext context,
  ScheduleConflictException error, {
  required bool canOverride,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B)),
          SizedBox(width: 8),
          Expanded(child: Text('Schedule clash')),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(error.message),
            const SizedBox(height: 12),
            for (final c in error.conflicts)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '• ${c.scheduledAt == null ? '' : '${fmtDay(c.scheduledAt!)}, ${fmtTime(c.scheduledAt!)}'}'
                  '${c.endsAt == null ? '' : ' – ${fmtTime(c.endsAt!)}'}'
                  '${c.clientName.isEmpty ? '' : '  ·  ${c.clientName}'}',
                ),
              ),
            if (!canOverride) ...[
              const SizedBox(height: 4),
              const Text('Pick a different time, or ask a stylist lead to book over it.'),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(canOverride ? 'Change time' : 'OK'),
        ),
        if (canOverride)
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Book anyway'),
          ),
      ],
    ),
  );
  return result ?? false;
}

// ── WhatsApp invitation (click-to-chat) ──────────────────────────────────────
/// The number wa.me needs: digits only, with the India country code added to a
/// plain 10-digit mobile number.
String whatsAppNumber(String phone) {
  var digits = phone.replaceAll(RegExp(r'\D'), '');
  if (digits.length == 11 && digits.startsWith('0')) digits = digits.substring(1);
  if (digits.length == 10) digits = '91$digits';
  return digits;
}

String buildInviteMessage(Consultation c) {
  final first = c.clientName.trim().split(RegExp(r'\s+')).first;
  final buf = StringBuffer()
    ..write('Hello${first.isEmpty ? '' : ' $first'}, this is Team N Makeovers. ')
    ..write('Your bridal consultation is booked for ${fmtDay(c.scheduledAt)} at ${fmtTime(c.scheduledAt)} ')
    ..write('(${c.durationMins} minutes)');
  if (c.stylistName.isNotEmpty) buf.write(' with ${c.stylistName}');
  buf.write('.');
  if (c.isVideo && c.meetingLink.isNotEmpty) {
    buf.write('\n\nJoin the video call here: ${c.meetingLink}');
  } else if (!c.isVideo && c.location.isNotEmpty) {
    buf.write('\n\nLocation: ${c.location}');
  }
  return buf.toString();
}

/// Opens WhatsApp with the invitation prefilled. Returns true when it opened.
Future<bool> openWhatsAppInvite(Consultation c) async {
  final number = whatsAppNumber(c.clientPhone);
  if (number.isEmpty) return false;
  final uri = Uri.https('wa.me', '/$number', {'text': buildInviteMessage(c)});
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}

/// Month / Week / List switch shared by the calendar and the list of calls,
/// so the two read as one Calendar page. Values: 'month', 'week', 'list'.
class CallsViewSwitch extends StatelessWidget {
  const CallsViewSwitch({super.key, required this.selected, required this.onChanged});

  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<String>(
      showSelectedIcon: false,
      segments: const [
        ButtonSegment(value: 'month', label: Text('Month')),
        ButtonSegment(value: 'week', label: Text('Week')),
        ButtonSegment(value: 'list', label: Text('List')),
      ],
      selected: {selected},
      onSelectionChanged: (s) => onChanged(s.first),
    );
  }
}
