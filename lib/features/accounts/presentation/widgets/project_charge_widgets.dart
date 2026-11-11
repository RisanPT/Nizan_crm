import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/core/utils/rupees.dart';
import 'package:nizan_crm/features/it/data/project_spend.dart';
import 'package:nizan_crm/features/it/services/it_service.dart';

// Charging an expense to a project: the picker on the expense form, and what is said when the expense would take the
// project past the budget its finance head approved.

/// "Charge to a project (optional)": the projects an expense can go to (their cost is approved), what is left of each when the
/// person may know it, and a warning when it is nearly used or over. [amount] is what is being filed, to say what it would do.
class ProjectChargeField extends ConsumerWidget {
  const ProjectChargeField({super.key, required this.selectedId, required this.onChanged, this.amount = 0, this.keepName});

  final String? selectedId;
  final ValueChanged<String?> onChanged;
  final double amount;

  /// The project the expense is already on, when it is no longer in the list (finished, cancelled): kept selectable by name.
  final ({String id, String name})? keepName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crm = context.crmColors;
    final async = ref.watch(chargeableProjectsProvider);
    return async.when(
      loading: () => const SizedBox(height: 56, child: Center(child: LinearProgressIndicator())),
      // no list, no picker: an expense can still be filed without a project
      error: (_, _) => Row(children: [
        Icon(Icons.hub_outlined, size: 16, color: crm.textSecondary),
        const SizedBox(width: 8),
        Expanded(child: Text('The projects could not be loaded, so this cannot be charged to one.', style: TextStyle(fontSize: 12, color: crm.textSecondary))),
        TextButton(onPressed: () => ref.invalidate(chargeableProjectsProvider), child: const Text('Retry')),
      ]),
      data: (projects) {
        final items = [...projects];
        if (keepName != null && !items.any((p) => p.id == keepName!.id)) items.add(ChargeableProject(id: keepName!.id, name: keepName!.name));
        final chosen = items.where((p) => p.id == selectedId).firstOrNull;
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          DropdownButtonFormField<String?>(
            key: Key('charge_project_${selectedId ?? 'none'}'),
            initialValue: chosen?.id,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Charge to a project (optional)', helperText: 'Only projects whose cost the finance head has approved'),
            items: [
              const DropdownMenuItem<String?>(value: null, child: Text('No project')),
              for (final p in items)
                DropdownMenuItem<String?>(value: p.id, child: Text(p.department.isEmpty ? p.name : '${p.name} · ${p.department}', overflow: TextOverflow.ellipsis)),
            ],
            onChanged: onChanged,
          ),
          if (chosen != null) _note(crm, chosen),
        ]);
      },
    );
  }

  Widget _note(CrmTheme crm, ChargeableProject p) {
    final available = p.available;
    final after = available == null ? null : available - amount;
    final over = after != null && after < 0;
    final warn = !over && (p.level == 'warn' || (p.limit != null && p.used != null && p.limit! > 0 && (p.used! + amount) * 100 >= p.limit! * 80));
    final color = over || p.level == 'over' ? const Color(0xFFB91C1C) : (warn ? const Color(0xFFB45309) : crm.textSecondary);
    final text = available == null
        ? (p.level == 'over' ? 'This project is already over its approved budget.' : (p.level == 'warn' ? 'This project has used most of its approved budget.' : ''))
        : over
            ? 'This takes the project ${rupees(-after)} over its approved budget (${rupees(available.clamp(0, double.infinity))} left). Only the finance head can approve it.'
            : '${rupees(available)} left of the approved ${rupees(p.limit ?? 0)}${amount > 0 ? ' — ${rupees(after!)} after this' : ''}.';
    if (text.isEmpty) return const SizedBox.shrink();
    return Padding(
      key: const Key('charge_project_note'),
      padding: const EdgeInsets.only(top: 6),
      child: Text(text, style: TextStyle(fontSize: 12, color: color, fontWeight: over || warn ? FontWeight.w600 : FontWeight.w400)),
    );
  }
}

/// An expense would take its project past the approved budget. For the finance head (or an administrator) this asks for the
/// reason and returns it; for anyone else it only says that the finance head has to approve it, and returns null.
Future<String?> showOverBudgetDialog(BuildContext context, OverBudgetRefusal refusal) {
  final reason = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (ctx) {
      var tooShort = false;
      return StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          key: const Key('over_budget_dialog'),
          title: const Text('Over the project\'s budget'),
          content: SizedBox(
            width: 420,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(refusal.message, style: const TextStyle(fontSize: 13.5)),
              if (refusal.needsReason) ...[
                const SizedBox(height: 12),
                TextField(
                  key: const Key('over_reason'),
                  controller: reason,
                  maxLines: 2,
                  decoration: InputDecoration(labelText: 'Why is it approved over the budget? *', errorText: tooShort ? 'Say why' : null),
                ),
              ],
            ]),
          ),
          actions: [
            TextButton(key: const Key('over_cancel'), onPressed: () => Navigator.pop(ctx), child: Text(refusal.needsReason ? 'Cancel' : 'OK')),
            if (refusal.needsReason)
              FilledButton(
                key: const Key('over_confirm'),
                onPressed: () {
                  if (reason.text.trim().length < 3) {
                    setD(() => tooShort = true);
                    return;
                  }
                  Navigator.pop(ctx, reason.text.trim());
                },
                child: const Text('Approve over the budget'),
              ),
          ],
        ),
      );
    },
  );
}
