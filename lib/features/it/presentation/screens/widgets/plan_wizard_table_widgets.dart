import 'package:flutter/material.dart';

import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/it/domain/plan_import.dart';

// The pieces of the plan wizard's task table that have no state of their own: a person's initials in a coloured circle, the dashed
// "add a task" row, and the dialog that turns a pasted list into tasks.

const _avatarColors = [
  Color(0xFF7B1E3B),
  Color(0xFFB45309),
  Color(0xFF0F766E),
  Color(0xFF4338CA),
  Color(0xFF9D174D),
  Color(0xFF1D4ED8),
  Color(0xFF15803D),
];

/// "Amna Rahman" → "AR"; one word → its first two letters; nothing → "?".
String initialsOf(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) {
    final w = parts.first;
    return (w.length >= 2 ? w.substring(0, 2) : w).toUpperCase();
  }
  return (parts.first[0] + parts.last[0]).toUpperCase();
}

/// A person as a circle with their initials; the colour stays the same for the same name.
class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar({super.key, required this.name, this.size = 28});
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color =
        _avatarColors[name.codeUnits.fold<int>(0, (a, c) => a + c) %
            _avatarColors.length];
    return Tooltip(
      message: name,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 1.5),
        ),
        child: Text(
          initialsOf(name),
          style: TextStyle(
            fontSize: size * 0.38,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ),
    );
  }
}

/// A full-width row with a dashed border and a "+ label" in the middle: the way to add one more.
class DashedAddRow extends StatelessWidget {
  const DashedAddRow({super.key, required this.label, required this.onTap});
  final String label;

  /// Null greys the row out.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final color = onTap == null
        ? crm.textSecondary.withValues(alpha: 0.5)
        : crm.primary;
    return CustomPaint(
      painter: _DashedBorder(color: color.withValues(alpha: 0.45), radius: 10),
      child: Material(
        color: onTap == null
            ? Colors.transparent
            : crm.primary.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: SizedBox(
            height: 48,
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_rounded, size: 18, color: color),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedBorder extends CustomPainter {
  const _DashedBorder({required this.color, required this.radius});
  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)),
      );
    for (final metric in path.computeMetrics()) {
      var at = 0.0;
      while (at < metric.length) {
        canvas.drawPath(metric.extractPath(at, at + 6), paint);
        at += 10;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorder old) =>
      old.color != color || old.radius != radius;
}

/// What the import dialog gives back: the tasks, and the phase they go under.
typedef ImportChoice = ({String phaseId, List<ImportedTask> tasks});

/// Asks for a pasted list of tasks (one per line, an optional number of days at the end) and the phase they go under.
Future<ImportChoice?> showImportTasksDialog(
  BuildContext context, {
  required List<({String id, String label})> phases,
  String? initialPhaseId,
}) {
  final text = TextEditingController();
  var phaseId = phases.any((p) => p.id == initialPhaseId)
      ? initialPhaseId!
      : phases.first.id;
  return showDialog<ImportChoice>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        final found = parseTaskLines(text.text);
        final crm = ctx.crmColors;
        return AlertDialog(
          key: const Key('wizard_import_dialog'),
          title: const Text('Import tasks'),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Paste a list, one task per line. End a line with the days it takes — "Wireframes, 3" — or leave them off and each task gets 3. '
                    'Bullets and numbers at the start of a line are dropped, and a column copied from a spreadsheet works too.',
                    style: TextStyle(fontSize: 12.5, color: crm.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    key: const Key('wizard_import_text'),
                    controller: text,
                    autofocus: true,
                    minLines: 6,
                    maxLines: 10,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      hintText: 'Wireframes, 3\nMockups, 4\nDeveloper handoff',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    key: const Key('wizard_import_phase'),
                    initialValue: phaseId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Add them under',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (final p in phases)
                        DropdownMenuItem(
                          value: p.id,
                          child: Text(p.label, overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: (v) => setState(() => phaseId = v ?? phaseId),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    found.isEmpty
                        ? 'Nothing to add yet.'
                        : '${found.length} task${found.length == 1 ? '' : 's'} will be added${found.length >= maxImportedTasks ? ' (the most one paste may add)' : ''}.',
                    key: const Key('wizard_import_count'),
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: found.isEmpty
                          ? crm.textSecondary
                          : crm.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              key: const Key('wizard_import_cancel'),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: const Key('wizard_import_ok'),
              onPressed: found.isEmpty
                  ? null
                  : () => Navigator.pop(ctx, (phaseId: phaseId, tasks: found)),
              child: Text(
                found.isEmpty
                    ? 'Add tasks'
                    : 'Add ${found.length} task${found.length == 1 ? '' : 's'}',
              ),
            ),
          ],
        );
      },
    ),
  );
}
