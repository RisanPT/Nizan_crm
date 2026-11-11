import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/it/domain/models/okr_model.dart';
import 'package:nizan_crm/features/it/domain/okr_pace.dart';
import 'package:nizan_crm/features/it/presentation/controllers/okr_notifier.dart';

/// A check-in on ONE key result: where it stands now, and whether it is done. It is its own
/// request, so it never undoes someone else's, and the server remembers each report (the timeline
/// plots them). Shows the last few reports. Returns true when something was saved.
Future<bool> showKeyResultCheckIn(
  BuildContext context,
  WidgetRef ref, {
  required String? projectId,
  required OKRModel okr,
  required KeyResultItem kr,
}) async {
  final crm = context.crmColors;
  final value = TextEditingController(text: okrNumber(kr.currentValue));
  var done = kr.completed;
  final recent = kr.checkIns.reversed.take(4).toList();
  final day = DateFormat('d MMM');

  final saved = await showDialog<({double value, bool done})>(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, setDialog) => AlertDialog(
        title: Text(kr.title, maxLines: 2, overflow: TextOverflow.ellipsis),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                okr.objective,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: crm.textSecondary),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: value,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Where it stands now',
                  helperText: 'Target: ${okrNumber(kr.targetValue)} ${kr.unit}',
                  suffixText: kr.unit,
                ),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: done,
                onChanged: (v) => setDialog(() => done = v ?? false),
                title: const Text('Mark as done'),
              ),
              if (recent.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  'Recent reports',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: crm.textSecondary),
                ),
                const SizedBox(height: 4),
                for (final c in recent)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 1.5),
                    child: Text(
                      '${day.format(c.at)}  ·  ${okrNumber(c.value)} ${kr.unit}${c.completed ? '  ·  done' : ''}${c.by.isEmpty ? '' : '  ·  ${c.by}'}',
                      style: TextStyle(fontSize: 12, color: crm.textSecondary),
                    ),
                  ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final n = double.tryParse(value.text.trim());
              if (n == null) return;
              Navigator.pop(c, (value: n, done: done));
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );
  if (saved == null) return false;
  if (!context.mounted) return false;

  try {
    await ref.read(projectOKRsNotifierProvider(projectId).notifier).updateKeyResult(okr.id, kr.id, {
      'currentValue': saved.value,
      'completed': saved.done,
    });
    return true;
  } catch (e) {
    if (context.mounted) showErrorSnackBar(context, e);
    return false;
  }
}
