import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/it/domain/models/it_task_model.dart';
import 'package:nizan_crm/features/it/domain/task_extension.dart';

// Extending a task's due date, in the app: under the due date — how late the task is, how many times its time was extended, and the
// button to extend it; in the task's log — the whole history; and the dialogs that ask for the new day and the reason. The rules are the
// server's (backend utils/taskExtension.js); what is shown here is advice — the server decides.

const _late = Color(0xFFB91C1C);
const _extended = Color(0xFFB45309);

Widget _pill(
  String text,
  Color color, {
  Key? key,
  IconData? icon,
  VoidCallback? onTap,
}) {
  final body = Container(
    key: key,
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
        ],
        Flexible(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
      ],
    ),
  );
  return onTap == null
      ? body
      : InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: body,
        );
}

/// Under the due date: "Overdue by 5 days", "Extended 3 times · +17 days" (tap for the history) and the button to extend.
class DueDateStatus extends StatelessWidget {
  const DueDateStatus({
    super.key,
    required this.task,
    required this.now,
    required this.canExtend,
    required this.onExtend,
    this.onHistory,
  });

  /// The task as it stands (its due date is the one saved, not one being picked).
  final ITTaskModel task;
  final DateTime now;

  /// This person plans the task (the server checks again).
  final bool canExtend;
  final VoidCallback onExtend;
  final VoidCallback? onHistory;

  @override
  Widget build(BuildContext context) {
    final late = task.overdueDays(now);
    final summary = task.extensionSummary;
    final mayExtend = canExtend && task.dueDate != null && !task.isCompleted;
    if (late == 0 && summary.isEmpty && !mayExtend) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Wrap(
        key: const Key('task_due_status'),
        spacing: 8,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (late > 0)
            _pill(
              'Overdue by ${daysText(late)}',
              _late,
              key: const Key('task_overdue_chip'),
              icon: Icons.warning_amber_rounded,
            ),
          if (!summary.isEmpty)
            _pill(
              extensionHeadline(summary),
              _extended,
              key: const Key('task_extension_count'),
              icon: Icons.update_rounded,
              onTap: onHistory,
            ),
          if (mayExtend)
            OutlinedButton.icon(
              key: const Key('task_extend_open'),
              style: OutlinedButton.styleFrom(
                visualDensity: VisualDensity.compact,
                foregroundColor: late > 0 ? _late : null,
                side: late > 0 ? const BorderSide(color: _late) : null,
              ),
              onPressed: onExtend,
              icon: const Icon(Icons.event_repeat_outlined, size: 16),
              label: Text(late > 0 ? 'Extend due date' : 'Extend'),
            ),
        ],
      ),
    );
  }
}

/// The task's extensions, newest first, with the count and what they add up to — in the task's log.
class ExtensionHistory extends StatelessWidget {
  const ExtensionHistory({super.key, required this.task});
  final ITTaskModel task;

  static final _when = DateFormat('d MMM yyyy, h:mm a');

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final list = [...task.extensions]..sort((a, b) => a.at.compareTo(b.at));
    final summary = task.extensionSummary;
    if (list.isEmpty) return const SizedBox.shrink();
    return Container(
      key: const Key('task_extensions_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _extended.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _extended.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.update_rounded, size: 18, color: _extended),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  extensionHeadline(summary),
                  key: const Key('ext_summary'),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: crm.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            [
              if (summary.originalDeadline != null)
                'First due ${longDay(summary.originalDeadline!)}',
              if (task.dueDate != null) 'now ${longDay(task.dueDate!)}',
              if (summary.whileOverdue > 0)
                '${summary.whileOverdue} of ${summary.count} done while it was already late',
            ].join(' · '),
            key: const Key('ext_summary_detail'),
            style: TextStyle(fontSize: 12, color: crm.textSecondary),
          ),
          const SizedBox(height: 10),
          // newest first; the number is the order they happened in
          for (var i = list.length - 1; i >= 0; i--)
            _entry(crm, list[i], i + 1),
        ],
      ),
    );
  }

  Widget _entry(CrmTheme crm, ITExtension e, int n) => Padding(
    key: Key('ext_entry_$n'),
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _extended.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Text(
            '$n',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: _extended,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${dayRange(e.from, e.to)}  (+${daysText(e.days)})',
                key: Key('ext_range_$n'),
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: crm.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${e.byName.isEmpty ? 'Someone' : e.byName} · ${_when.format(e.at)}',
                key: Key('ext_by_$n'),
                style: TextStyle(fontSize: 11.5, color: crm.textSecondary),
              ),
              if (e.overdueDays > 0 || e.viaEdit) ...[
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    if (e.overdueDays > 0)
                      _pill(
                        'was ${daysText(e.overdueDays)} overdue',
                        _late,
                        key: Key('ext_late_$n'),
                      ),
                    if (e.viaEdit)
                      _pill(
                        'date edited',
                        crm.textSecondary,
                        key: Key('ext_edit_$n'),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 4),
              e.reason.isEmpty
                  ? Text(
                      'No reason given',
                      key: Key('ext_reason_$n'),
                      style: TextStyle(
                        fontSize: 12.5,
                        fontStyle: FontStyle.italic,
                        color: crm.textSecondary,
                      ),
                    )
                  : Text(
                      e.reason,
                      key: Key('ext_reason_$n'),
                      style: TextStyle(fontSize: 13, color: crm.textPrimary),
                    ),
            ],
          ),
        ),
      ],
    ),
  );
}

/// What a person gives to extend a due date.
typedef ExtendRequest = ({DateTime newDeadline, String reason});

/// Picks a day (injectable, so a test need not drive the calendar).
typedef DayPicker =
    Future<DateTime?> Function(
      BuildContext context,
      DateTime initial,
      DateTime first,
      DateTime last,
    );

Future<DateTime?> _calendar(
  BuildContext context,
  DateTime initial,
  DateTime first,
  DateTime last,
) => showDatePicker(
  context: context,
  initialDate: initial,
  firstDate: first,
  lastDate: last,
);

/// Asks for the new due date and the reason. The new day has to be after the current one; the reason is required. Warns, without stopping
/// anyone, when the new day is after the project's end date. Returns null when the person backs out.
Future<ExtendRequest?> showExtendDeadlineDialog(
  BuildContext context, {
  required ITTaskModel task,
  DateTime? projectEnd,
  DateTime? now,
  DayPicker? picker,
}) {
  final today = now ?? DateTime.now();
  final due = task.dueDate!;
  final first = due.add(const Duration(days: 1));
  // a sensible start: a week past the later of the due day and today
  var picked = (daysBetween(today, due) > 0 ? today : due).add(
    const Duration(days: 7),
  );
  final reason = TextEditingController();
  String? error;

  return showDialog<ExtendRequest>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        final late = task.overdueDays(today);
        final gap = daysBetween(picked, due);
        final pastEnd =
            projectEnd != null && daysBetween(picked, projectEnd) > 0;
        return AlertDialog(
          key: const Key('extend_dialog'),
          title: const Text('Extend the due date'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Now due ${longDay(due)}${late > 0 ? ' — overdue by ${daysText(late)}' : ''}.',
                  key: const Key('extend_current'),
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: late > 0 ? _late : null,
                  ),
                ),
                if (task.extensionCount > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'Already ${extensionHeadline(task.extensionSummary).toLowerCase()}.',
                      key: const Key('extend_before'),
                      style: const TextStyle(fontSize: 12.5, color: _extended),
                    ),
                  ),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  key: const Key('extend_date'),
                  onPressed: () async {
                    final d = await (picker ?? _calendar)(
                      ctx,
                      picked.isBefore(first) ? first : picked,
                      first,
                      DateTime(2035),
                    );
                    if (d != null) setState(() => picked = d);
                  },
                  icon: const Icon(Icons.calendar_today_outlined, size: 16),
                  label: Text('New due date: ${longDay(picked)}'),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 2),
                  child: Text(
                    gap > 0
                        ? '+${daysText(gap)} from the current due date'
                        : 'It has to be after ${longDay(due)}',
                    key: const Key('extend_days'),
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                if (pastEnd)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'This is after the project\'s end date (${longDay(projectEnd)}). The project itself is not changed.',
                      key: const Key('extend_after_project_end'),
                      style: const TextStyle(
                        fontSize: 12,
                        color: _extended,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('extend_reason'),
                  controller: reason,
                  minLines: 2,
                  maxLines: 4,
                  maxLength: 300,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Why is more time needed?',
                    alignLabelWithHint: true,
                  ),
                ),
                if (error != null)
                  Text(
                    error!,
                    key: const Key('extend_error'),
                    style: const TextStyle(color: _late, fontSize: 12.5),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              key: const Key('extend_cancel'),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: const Key('extend_send'),
              onPressed: () {
                if (daysBetween(picked, due) <= 0) {
                  setState(
                    () => error =
                        'The new due date has to be after ${longDay(due)}.',
                  );
                } else if (reason.text.trim().length < 3) {
                  setState(() => error = 'Say why more time is needed.');
                } else {
                  Navigator.pop(ctx, (
                    newDeadline: picked,
                    reason: reason.text.trim(),
                  ));
                }
              },
              child: const Text('Extend'),
            ),
          ],
        );
      },
    ),
  );
}

/// Asked when the due date of an OVERDUE task is moved later in an ordinary edit: the server writes that down as an extension too, so
/// say why. Returns the reason, or null when the person backs out (nothing is saved).
Future<String?> askExtensionReason(
  BuildContext context, {
  required DateTime from,
  required DateTime to,
  required int overdueDays,
}) {
  final reason = TextEditingController();
  String? error;
  return showDialog<String>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        key: const Key('ext_reason_dialog'),
        title: const Text('Why is the due date moving?'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'It is ${daysText(overdueDays)} overdue, and the due date moves ${dayRange(from, to)}. This is kept in its history as an extension.',
                key: const Key('ext_reason_note'),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('ext_reason_field'),
                controller: reason,
                autofocus: true,
                minLines: 2,
                maxLines: 4,
                maxLength: 300,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Reason',
                  alignLabelWithHint: true,
                ),
              ),
              if (error != null)
                Text(
                  error!,
                  key: const Key('ext_reason_error'),
                  style: const TextStyle(color: _late, fontSize: 12.5),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            key: const Key('ext_reason_cancel'),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('ext_reason_ok'),
            onPressed: () {
              if (reason.text.trim().length < 3) {
                setState(() => error = 'Say why more time is needed.');
              } else {
                Navigator.pop(ctx, reason.text.trim());
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );
}
