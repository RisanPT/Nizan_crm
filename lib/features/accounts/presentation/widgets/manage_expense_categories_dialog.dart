import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/state/data_refresh.dart';
import 'package:nizan_crm/core/extensions/space_extension.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/accounts/data/expense_category.dart';
import 'package:nizan_crm/features/accounts/services/expense_category_service.dart';

// Departments an approver can manage categories for (mirrors the record form).
const _kManageDepartments = [
  'CRM',
  'Finance',
  'Accounts',
  'IT',
  'Sales',
  'Marketing',
  'HR',
  'Artist',
  'Fleet',
  'Operations',
  'General',
];

/// Add / rename / remove the expense categories for a department.
///
/// A department head manages only their own department ([canPickDepartment] =
/// false, [department] locked). Accounts/Admin may switch departments.
class ManageExpenseCategoriesDialog extends ConsumerStatefulWidget {
  final String department;
  final bool canPickDepartment;

  const ManageExpenseCategoriesDialog({
    super.key,
    required this.department,
    required this.canPickDepartment,
  });

  @override
  ConsumerState<ManageExpenseCategoriesDialog> createState() =>
      _ManageExpenseCategoriesDialogState();
}

class _ManageExpenseCategoriesDialogState
    extends ConsumerState<ManageExpenseCategoriesDialog> {
  late String _dept;
  final _addCtrl = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _dept = widget.department.isNotEmpty
        ? widget.department
        : (widget.canPickDepartment ? 'General' : widget.department);
  }

  @override
  void dispose() {
    _addCtrl.dispose();
    super.dispose();
  }

  void _refresh() => ref.refreshData.expenseCategories();

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      _refresh();
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _add() async {
    final name = _addCtrl.text.trim();
    if (name.isEmpty) return;
    await _run(() async {
      await ref
          .read(expenseCategoryServiceProvider)
          .create(name: name, department: _dept);
      _addCtrl.clear();
    });
  }

  Future<void> _rename(ExpenseCategory cat) async {
    final ctrl = TextEditingController(text: cat.label);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename category'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Category name'),
          onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (newName == null || newName.isEmpty || newName == cat.name) return;
    await _run(() async {
      await ref
          .read(expenseCategoryServiceProvider)
          .update(cat.id, name: newName);
    });
  }

  Future<void> _delete(ExpenseCategory cat) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove category'),
        content: Text(
          'Remove "${cat.label}" from $_dept? Existing expenses keep their label.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _run(() async {
      await ref.read(expenseCategoryServiceProvider).delete(cat.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final categoriesAsync = ref.watch(expenseCategoriesProvider(_dept));

    return Dialog(
      backgroundColor: crm.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 480,
        constraints: const BoxConstraints(maxHeight: 620),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Manage Expense Categories',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: crm.textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            8.h,
            if (widget.canPickDepartment)
              DropdownButtonFormField<String>(
                initialValue:
                    _kManageDepartments.contains(_dept) ? _dept : null,
                decoration: const InputDecoration(labelText: 'Department'),
                items: _kManageDepartments
                    .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                    .toList(),
                onChanged: _busy
                    ? null
                    : (v) {
                        if (v != null) setState(() => _dept = v);
                      },
              )
            else
              Text(
                _dept,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: crm.primary,
                ),
              ),
            12.h,
            // ── Add row ──
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _addCtrl,
                    decoration: const InputDecoration(
                      labelText: 'New category',
                      hintText: 'e.g. Client Gifts',
                      isDense: true,
                    ),
                    onSubmitted: (_) => _add(),
                  ),
                ),
                8.w,
                FilledButton.icon(
                  onPressed: _busy ? null : _add,
                  style: FilledButton.styleFrom(backgroundColor: crm.primary),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add'),
                ),
              ],
            ),
            16.h,
            Divider(color: crm.border, height: 1),
            8.h,
            Flexible(
              child: categoriesAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => AppErrorView(
                  error: e,
                  onRetry: _refresh,
                ),
                data: (cats) {
                  if (cats.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(
                        child: Text(
                          'No categories yet — add one above.',
                          style: TextStyle(color: crm.textSecondary),
                        ),
                      ),
                    );
                  }
                  return ListView.separated(
                    shrinkWrap: true,
                    itemCount: cats.length,
                    separatorBuilder: (_, _) =>
                        Divider(color: crm.border, height: 1),
                    itemBuilder: (context, i) {
                      final c = cats[i];
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          c.label,
                          style: TextStyle(
                            color: crm.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              tooltip: 'Rename',
                              onPressed: _busy ? null : () => _rename(c),
                            ),
                            IconButton(
                              icon: Icon(Icons.delete_outline,
                                  size: 18, color: Colors.red.shade400),
                              tooltip: 'Remove',
                              onPressed: _busy ? null : () => _delete(c),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
