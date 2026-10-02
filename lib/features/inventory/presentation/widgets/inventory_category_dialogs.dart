import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/inventory/controllers/inventory_controller.dart';
import 'package:nizan_crm/features/inventory/data/inventory_category.dart';
import 'inventory_widgets.dart';

// Category add / rename / delete for the Stock List.
//
// Built-in categories and any category already used by products are locked
// (the server refuses to change them too), so these actions only ever affect
// custom categories that no product uses — existing products are untouched.

List<InventoryCategory> _current(WidgetRef ref) =>
    ref.read(inventoryCategoriesProvider).value ?? InventoryCategory.builtins();

void _toast(BuildContext context, String msg) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
}

/// Name prompt shared by Add and Rename. Returns the trimmed name, or null.
Future<String?> _nameDialog(
  BuildContext context,
  WidgetRef ref, {
  required String title,
  required String action,
  String initial = '',
  String? excludeName,
}) {
  final ctrl = TextEditingController(text: initial);
  final formKey = GlobalKey<FormState>();
  final taken = {
    for (final c in _current(ref))
      if (c.name.toLowerCase() != excludeName?.toLowerCase())
        c.name.toLowerCase(),
  };
  return showDialog<String>(
    context: context,
    builder: (ctx) {
      void submit() {
        if (formKey.currentState?.validate() ?? false) {
          Navigator.pop(ctx, ctrl.text.replaceAll(RegExp(r'\s+'), ' ').trim());
        }
      }

      return AlertDialog(
        title: Text(title),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: ctrl,
            autofocus: true,
            maxLength: 40,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Category name',
              hintText: 'e.g. Nails',
              prefixIcon: Icon(Icons.sell_outlined),
            ),
            validator: (v) {
              final name = (v ?? '').replaceAll(RegExp(r'\s+'), ' ').trim();
              if (name.isEmpty) return 'Enter a name';
              if (taken.contains(name.toLowerCase())) {
                return '"$name" already exists';
              }
              return null;
            },
            onFieldSubmitted: (_) => submit(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(onPressed: submit, child: Text(action)),
        ],
      );
    },
  );
}

Future<void> showAddCategoryDialog(BuildContext context, WidgetRef ref) async {
  final name = await _nameDialog(
    context,
    ref,
    title: 'New category',
    action: 'Add',
  );
  if (name == null || !context.mounted) return;
  try {
    await ref.read(inventoryServiceProvider).createCategory(name);
    ref.invalidate(inventoryCategoriesProvider);
    if (context.mounted) _toast(context, 'Category "$name" added');
  } catch (e) {
    if (context.mounted) showErrorSnackBar(context, e);
  }
}

/// Returns the new name when renamed, else null.
Future<String?> showRenameCategoryDialog(
  BuildContext context,
  WidgetRef ref,
  InventoryCategory category,
) async {
  if (!category.canEdit) {
    _toast(
      context,
      '${category.name}: ${category.lockReason} — can\'t be renamed',
    );
    return null;
  }
  final name = await _nameDialog(
    context,
    ref,
    title: 'Rename category',
    action: 'Save',
    initial: category.name,
    excludeName: category.name,
  );
  if (name == null || name == category.name || !context.mounted) return null;
  try {
    await ref.read(inventoryServiceProvider).renameCategory(category.id!, name);
    ref.invalidate(inventoryCategoriesProvider);
    if (context.mounted) _toast(context, 'Renamed to "$name"');
    return name;
  } catch (e) {
    if (context.mounted) showErrorSnackBar(context, e);
    return null;
  }
}

/// Returns true when deleted.
Future<bool> confirmDeleteCategory(
  BuildContext context,
  WidgetRef ref,
  InventoryCategory category,
) async {
  if (!category.canEdit) {
    _toast(
      context,
      '${category.name}: ${category.lockReason} — can\'t be deleted',
    );
    return false;
  }
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Delete category?'),
      content: Text(
        '"${category.name}" will be removed from the list. '
        'No products use it, so nothing else changes.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: ctx.crmColors.destructive,
          ),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  if (ok != true || !context.mounted) return false;
  try {
    await ref.read(inventoryServiceProvider).deleteCategory(category.id!);
    ref.invalidate(inventoryCategoriesProvider);
    if (context.mounted) _toast(context, 'Category "${category.name}" deleted');
    return true;
  } catch (e) {
    if (context.mounted) showErrorSnackBar(context, e);
    return false;
  }
}

/// Long-press / right-click menu on a category pill.
Future<void> showCategoryActions(
  BuildContext context,
  WidgetRef ref,
  InventoryCategory category, {
  required Offset position,
  void Function(String? renamedTo, bool deleted)? onChanged,
}) async {
  final crm = context.crmColors;
  final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
  final choice = await showMenu<String>(
    context: context,
    position: RelativeRect.fromRect(
      position & const Size(1, 1),
      Offset.zero & overlay.size,
    ),
    items: [
      PopupMenuItem<String>(
        enabled: false,
        child: Row(
          children: [
            Icon(
              category.canEdit ? Icons.sell_outlined : Icons.lock_outline,
              size: 16,
              color: crm.textSecondary,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                category.canEdit
                    ? category.name
                    : '${category.name} · ${category.lockReason}',
                style: TextStyle(fontSize: 12.5, color: crm.textSecondary),
              ),
            ),
          ],
        ),
      ),
      const PopupMenuDivider(),
      PopupMenuItem<String>(
        value: 'rename',
        enabled: category.canEdit,
        child: const ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.edit_outlined, size: 20),
          title: Text('Rename'),
        ),
      ),
      PopupMenuItem<String>(
        value: 'delete',
        enabled: category.canEdit,
        child: ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.delete_outline, size: 20, color: crm.destructive),
          title: Text('Delete', style: TextStyle(color: crm.destructive)),
        ),
      ),
    ],
  );
  if (!context.mounted) return;
  if (choice == 'rename') {
    final to = await showRenameCategoryDialog(context, ref, category);
    if (to != null) onChanged?.call(to, false);
  } else if (choice == 'delete') {
    if (await confirmDeleteCategory(context, ref, category)) {
      onChanged?.call(null, true);
    }
  }
}

/// Full list of categories with product counts, lock state and actions.
Future<void> showManageCategoriesSheet(
  BuildContext context,
  WidgetRef ref, {
  void Function(String oldName, String? renamedTo, bool deleted)? onChanged,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => Consumer(
      builder: (context, ref, _) {
        final crm = context.crmColors;
        final async = ref.watch(inventoryCategoriesProvider);
        final cats = async.value ?? const <InventoryCategory>[];
        final custom = cats.where((c) => c.isCustom).length;
        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
            maxWidth: 560,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Categories',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${cats.length} total · $custom custom',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: crm.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: () => showAddCategoryDialog(context, ref),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Add'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: crm.input,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.lock_outline,
                        size: 16,
                        color: crm.textSecondary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Built-in categories and ones already used by products '
                          'are locked, so existing products never change.',
                          style: TextStyle(
                            fontSize: 12,
                            color: crm.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                if (async.isLoading && cats.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: cats.length,
                      separatorBuilder: (_, _) =>
                          Divider(height: 1, color: crm.border),
                      itemBuilder: (context, i) {
                        final c = cats[i];
                        final color = categoryColor(c.name);
                        final sub = [
                          if (c.isBuiltin) 'Built-in',
                          if (c.isCustom) 'Custom',
                          if (!c.isBuiltin && !c.isCustom) 'From products',
                          if (c.productCount > 0)
                            '${c.productCount} product${c.productCount == 1 ? '' : 's'}'
                          else
                            'No products',
                        ].join(' · ');
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            radius: 16,
                            backgroundColor: color.withValues(alpha: 0.14),
                            child: Icon(
                              productIcon(c.name),
                              size: 16,
                              color: color,
                            ),
                          ),
                          title: Text(
                            c.name,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            sub,
                            style: TextStyle(
                              fontSize: 12,
                              color: crm.textSecondary,
                            ),
                          ),
                          trailing: c.canEdit
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      tooltip: 'Rename',
                                      icon: const Icon(
                                        Icons.edit_outlined,
                                        size: 20,
                                      ),
                                      onPressed: () async {
                                        final to =
                                            await showRenameCategoryDialog(
                                              context,
                                              ref,
                                              c,
                                            );
                                        if (to != null) {
                                          onChanged?.call(c.name, to, false);
                                        }
                                      },
                                    ),
                                    IconButton(
                                      tooltip: 'Delete',
                                      icon: Icon(
                                        Icons.delete_outline,
                                        size: 20,
                                        color: crm.destructive,
                                      ),
                                      onPressed: () async {
                                        if (await confirmDeleteCategory(
                                          context,
                                          ref,
                                          c,
                                        )) {
                                          onChanged?.call(c.name, null, true);
                                        }
                                      },
                                    ),
                                  ],
                                )
                              : Tooltip(
                                  message: c.lockReason,
                                  child: Icon(
                                    Icons.lock_outline,
                                    size: 18,
                                    color: crm.textSecondary,
                                  ),
                                ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
