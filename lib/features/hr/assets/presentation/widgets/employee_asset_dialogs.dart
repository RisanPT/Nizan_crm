import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/hr/assets/data/employee_asset_models.dart';
import 'package:nizan_crm/features/hr/assets/service/employee_asset_service.dart';
import 'package:nizan_crm/features/hr/shared/hr_person_picker.dart';

const kAssetMaroon = Color(0xFF601A29);

String fmtAssetDate(DateTime? d) {
  if (d == null) return '—';
  const m = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${d.day.toString().padLeft(2, '0')} ${m[d.month]} ${d.year}';
}

Color employeeAssetStatusColor(String s) {
  switch (s) {
    case 'issued':
      return const Color(0xFFD97706);
    case 'returned':
      return const Color(0xFF0D9488);
    case 'lost':
      return const Color(0xFFDC2626);
    default:
      return Colors.grey;
  }
}

void _snack(BuildContext context, String msg) {
  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
}

/// Issue (or edit, when [existing] is given) an asset. When [employeeId] is
/// fixed the employee picker is hidden; otherwise [people] feeds the picker.
/// Returns true when something was saved.
Future<bool> showIssueEmployeeAssetDialog(
  BuildContext context,
  WidgetRef ref, {
  String? employeeId,
  List<PickerItem> people = const [],
  EmployeeAsset? existing,
}) async {
  String? selected = existing?.employeeId ?? employeeId;
  String category = existing?.category ?? 'laptop';
  DateTime issuedOn = existing?.issuedOn ?? DateTime.now();
  final itemCtrl = TextEditingController(text: existing?.item ?? '');
  final serialCtrl = TextEditingController(text: existing?.serialNo ?? '');
  final condCtrl = TextEditingController(text: existing?.condition ?? '');
  final notesCtrl = TextEditingController(text: existing?.notes ?? '');
  final fixedEmployee = existing != null || (employeeId != null && employeeId.isNotEmpty);

  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDlg) => AlertDialog(
        title: Text(existing == null ? 'Issue asset' : 'Edit asset',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800)),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!fixedEmployee) ...[
                  PersonPickerField(
                    label: 'Employee *',
                    icon: Icons.person_outline,
                    selectedId: selected,
                    items: people,
                    onChanged: (v) => setDlg(() => selected = v),
                  ),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: itemCtrl,
                  decoration: const InputDecoration(labelText: 'Item * (e.g. Dell Latitude 5420)'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: category,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: kEmployeeAssetCategories
                      .map((c) => DropdownMenuItem(value: c, child: Text(employeeAssetCategoryLabel(c))))
                      .toList(),
                  onChanged: (v) => setDlg(() => category = v ?? 'other'),
                ),
                const SizedBox(height: 12),
                TextField(controller: serialCtrl, decoration: const InputDecoration(labelText: 'Serial / tag no.')),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    final now = DateTime.now();
                    final d = await showDatePicker(
                      context: ctx,
                      initialDate: issuedOn,
                      firstDate: DateTime(now.year - 10),
                      lastDate: DateTime(now.year + 1),
                    );
                    if (d != null) setDlg(() => issuedOn = d);
                  },
                  icon: const Icon(Icons.event_outlined, size: 18),
                  label: Text('Issued on: ${fmtAssetDate(issuedOn)}'),
                ),
                const SizedBox(height: 12),
                TextField(controller: condCtrl, decoration: const InputDecoration(labelText: 'Condition when issued')),
                const SizedBox(height: 12),
                TextField(
                  controller: notesCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Notes', border: OutlineInputBorder()),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kAssetMaroon, foregroundColor: const Color(0xFFF5F3EF)),
            onPressed: () {
              if ((selected ?? '').isEmpty || itemCtrl.text.trim().isEmpty) return;
              Navigator.of(ctx).pop(true);
            },
            child: Text(existing == null ? 'Issue' : 'Save'),
          ),
        ],
      ),
    ),
  );
  if (ok != true || (selected ?? '').isEmpty) return false;
  if (!context.mounted) return false;
  try {
    final svc = ref.read(employeeAssetServiceProvider);
    if (existing == null) {
      await svc.issue(
        employeeId: selected!,
        item: itemCtrl.text.trim(),
        category: category,
        serialNo: serialCtrl.text.trim(),
        issuedOn: issuedOn,
        condition: condCtrl.text.trim(),
        notes: notesCtrl.text.trim(),
      );
    } else {
      await svc.update(existing.id, {
        'item': itemCtrl.text.trim(),
        'category': category,
        'serialNo': serialCtrl.text.trim(),
        'issuedOn': issuedOn.toIso8601String(),
        'condition': condCtrl.text.trim(),
        'notes': notesCtrl.text.trim(),
      });
    }
    invalidateEmployeeAssets(ref, selected);
    if (context.mounted) _snack(context, existing == null ? 'Asset issued' : 'Asset updated');
    return true;
  } catch (e) {
    if (context.mounted) _snack(context, friendlyErrorMessage(e));
    return false;
  }
}

/// Mark an issued asset returned (asks for date + condition).
Future<bool> showReturnEmployeeAssetDialog(BuildContext context, WidgetRef ref, EmployeeAsset a) async {
  DateTime returnedOn = DateTime.now();
  final condCtrl = TextEditingController();
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDlg) => AlertDialog(
        title: Text('Mark returned', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800)),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${a.item}${a.serialNo.isNotEmpty ? ' (${a.serialNo})' : ''} — ${a.employeeName}'),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () async {
                  final now = DateTime.now();
                  final d = await showDatePicker(
                    context: ctx,
                    initialDate: returnedOn,
                    firstDate: DateTime(now.year - 10),
                    lastDate: DateTime(now.year + 1),
                  );
                  if (d != null) setDlg(() => returnedOn = d);
                },
                icon: const Icon(Icons.event_outlined, size: 18),
                label: Text('Returned on: ${fmtAssetDate(returnedOn)}'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: condCtrl,
                decoration: const InputDecoration(labelText: 'Condition on return (e.g. good, screen scratched)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0D9488)),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Mark returned'),
          ),
        ],
      ),
    ),
  );
  if (ok != true || !context.mounted) return false;
  try {
    await ref.read(employeeAssetServiceProvider).markReturned(a.id, returnedOn: returnedOn, returnCondition: condCtrl.text.trim());
    invalidateEmployeeAssets(ref, a.employeeId);
    if (context.mounted) _snack(context, 'Marked returned');
    return true;
  } catch (e) {
    if (context.mounted) _snack(context, friendlyErrorMessage(e));
    return false;
  }
}

/// Mark an issued asset lost (asks for a note).
Future<bool> showLostEmployeeAssetDialog(BuildContext context, WidgetRef ref, EmployeeAsset a) async {
  final notesCtrl = TextEditingController();
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Mark as lost'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${a.item} issued to ${a.employeeName} will be recorded as lost.'),
            const SizedBox(height: 12),
            TextField(controller: notesCtrl, decoration: const InputDecoration(labelText: 'What happened? (optional)')),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Mark lost'),
        ),
      ],
    ),
  );
  if (ok != true || !context.mounted) return false;
  try {
    await ref.read(employeeAssetServiceProvider).markLost(a.id, notes: notesCtrl.text.trim());
    invalidateEmployeeAssets(ref, a.employeeId);
    if (context.mounted) _snack(context, 'Marked lost');
    return true;
  } catch (e) {
    if (context.mounted) _snack(context, friendlyErrorMessage(e));
    return false;
  }
}

/// Delete an asset record (backend allows HR-wide users only).
Future<bool> confirmDeleteEmployeeAsset(BuildContext context, WidgetRef ref, EmployeeAsset a) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Delete asset record?'),
      content: Text('Remove "${a.item}" for ${a.employeeName}? Use "Mark returned" or "Mark lost" to close a record normally.'),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  if (ok != true || !context.mounted) return false;
  try {
    await ref.read(employeeAssetServiceProvider).remove(a.id);
    invalidateEmployeeAssets(ref, a.employeeId);
    if (context.mounted) _snack(context, 'Asset record deleted');
    return true;
  } catch (e) {
    if (context.mounted) _snack(context, friendlyErrorMessage(e));
    return false;
  }
}
