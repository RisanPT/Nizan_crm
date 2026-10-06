import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/models/service_package.dart';
import 'package:nizan_crm/core/state/data_refresh.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/services/package_service.dart';

/// Services → Packages → "Arrange order". Drag (or use the arrows) to set the
/// order packages appear in everywhere — quotes, the booking form, pickers.
/// Saved on the server, so every user sees the same order.
Future<void> showPackageOrderDialog(BuildContext context, WidgetRef ref) {
  return showDialog<void>(
    context: context,
    builder: (_) => const _PackageOrderDialog(),
  );
}

class _PackageOrderDialog extends ConsumerStatefulWidget {
  const _PackageOrderDialog();

  @override
  ConsumerState<_PackageOrderDialog> createState() => _PackageOrderDialogState();
}

class _PackageOrderDialogState extends ConsumerState<_PackageOrderDialog> {
  List<ServicePackage>? _order;
  bool _saving = false;

  void _move(int from, int to) {
    final list = [..._order!];
    final item = list.removeAt(from);
    list.insert(to, item);
    setState(() => _order = list);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(packageServiceProvider).reorderPackages([for (final p in _order!) p.id]);
      ref.refreshData.packages();
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Package order saved')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showErrorSnackBar(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final async = ref.watch(packagesProvider);
    // Seed the editable order once, from the server's current order.
    if (_order == null && async.hasValue) _order = [...async.value!];
    final order = _order;

    return AlertDialog(
      title: const Text('Arrange package order'),
      contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      content: SizedBox(
        width: 460,
        height: 460,
        child: order == null
            ? async.hasError
                ? AppErrorView(error: async.error!, compact: true, onRetry: () => ref.invalidate(packagesProvider))
                : const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Drag ⠿ or use the arrows. This is the order packages appear in quotes, '
                    'the booking form and every package list. New packages are added at the end.',
                    style: TextStyle(fontSize: 12.5, color: crm.textSecondary),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: ReorderableListView.builder(
                      buildDefaultDragHandles: false,
                      itemCount: order.length,
                      onReorderItem: _move,
                      itemBuilder: (context, i) {
                        final p = order[i];
                        return Container(
                          key: ValueKey(p.id),
                          margin: const EdgeInsets.only(bottom: 6),
                          decoration: BoxDecoration(
                            color: crm.surface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: crm.border),
                          ),
                          child: ListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.only(left: 4, right: 4),
                            leading: ReorderableDragStartListener(
                              index: i,
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                Icon(Icons.drag_indicator_rounded, color: crm.textSecondary),
                                const SizedBox(width: 6),
                                CircleAvatar(
                                  radius: 12,
                                  backgroundColor: crm.primary.withValues(alpha: 0.1),
                                  child: Text('${i + 1}',
                                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: crm.primary)),
                                ),
                              ]),
                            ),
                            title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text('₹${p.price.toStringAsFixed(0)}'),
                            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                              IconButton(
                                tooltip: 'Move up',
                                visualDensity: VisualDensity.compact,
                                onPressed: i == 0 ? null : () => _move(i, i - 1),
                                icon: const Icon(Icons.arrow_upward_rounded, size: 18),
                              ),
                              IconButton(
                                tooltip: 'Move down',
                                visualDensity: VisualDensity.compact,
                                onPressed: i == order.length - 1 ? null : () => _move(i, i + 1),
                                icon: const Icon(Icons.arrow_downward_rounded, size: 18),
                              ),
                            ]),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _saving || order == null || order.length < 2 ? null : _save,
          icon: _saving
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.check_rounded, size: 18),
          label: const Text('Save order'),
        ),
      ],
    );
  }
}
