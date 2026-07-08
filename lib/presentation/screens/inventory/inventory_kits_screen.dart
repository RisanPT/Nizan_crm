import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/app_role.dart';
import '../../../core/extensions/space_extension.dart';
import '../../../core/models/crm_user.dart';
import '../../../core/models/inventory_product.dart';
import '../../../core/models/staff_kit.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/crm_theme.dart';
import '../../../core/utils/responsive_builder.dart';
import '../../../services/inventory_service.dart';
import '../../../services/user_service.dart';
import 'inventory_widgets.dart';

class InventoryKitsScreen extends ConsumerStatefulWidget {
  const InventoryKitsScreen({super.key});

  @override
  ConsumerState<InventoryKitsScreen> createState() =>
      _InventoryKitsScreenState();
}

class _InventoryKitsScreenState extends ConsumerState<InventoryKitsScreen> {
  // Per-kit checklist verification state (local session only).
  final Map<String, Set<int>> _checks = {};

  void _openKit(StaffKit kit) {
    final crm = context.crmColors;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.72,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        expand: false,
        builder: (c, controller) => Consumer(
          builder: (c, sheetRef, _) {
            // Re-read live so tube edits reflect immediately in this sheet.
            final kits =
                sheetRef.watch(staffKitsProvider).value ?? const <StaffKit>[];
            final live =
                kits.firstWhere((k) => k.id == kit.id, orElse: () => kit);
            final products = sheetRef.watch(inventoryProductsProvider).value ??
                const <InventoryProduct>[];
            return StatefulBuilder(
              builder: (ctx, setSheet) {
                final checked = _checks[live.id] ?? <int>{};
                return Container(
                  decoration: BoxDecoration(
                    color: Theme.of(ctx).scaffoldBackgroundColor,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: Column(
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 12, bottom: 4),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                            color: crm.border,
                            borderRadius: BorderRadius.circular(2)),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 12, 8),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor:
                                  crm.primary.withValues(alpha: 0.1),
                              child: Text(
                                  live.name.isNotEmpty
                                      ? live.name[0].toUpperCase()
                                      : '?',
                                  style: TextStyle(
                                      color: crm.primary,
                                      fontWeight: FontWeight.bold)),
                            ),
                            12.w,
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(live.name,
                                      style: const TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.bold)),
                                  Text('Tap the tube to update usage',
                                      style: TextStyle(
                                          fontSize: 12.5,
                                          color: crm.textSecondary)),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () => Navigator.pop(ctx),
                            ),
                          ],
                        ),
                      ),
                      Divider(height: 1, color: crm.border),
                      Expanded(
                        child: ListView.builder(
                          controller: controller,
                          padding: const EdgeInsets.all(16),
                          itemCount: live.items.length,
                          itemBuilder: (context, i) {
                            final it = live.items[i];
                            final on = checked.contains(i);
                            final usage = _usageFor(products, it);
                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: on
                                    ? const Color(0xFFFBF6EA)
                                    : crm.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: on
                                        ? const Color(0xFFC9A227)
                                        : crm.border),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      GestureDetector(
                                        behavior: HitTestBehavior.opaque,
                                        onTap: () => setSheet(() {
                                          final set = _checks.putIfAbsent(
                                              live.id, () => {});
                                          on ? set.remove(i) : set.add(i);
                                        }),
                                        child: Container(
                                          width: 24,
                                          height: 24,
                                          decoration: BoxDecoration(
                                            color: on
                                                ? const Color(0xFFC9A227)
                                                : crm.surface,
                                            borderRadius:
                                                BorderRadius.circular(6),
                                            border: Border.all(
                                                color: on
                                                    ? const Color(0xFFC9A227)
                                                    : crm.border),
                                          ),
                                          child: on
                                              ? const Icon(Icons.check,
                                                  size: 16, color: Colors.white)
                                              : null,
                                        ),
                                      ),
                                      12.w,
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                                it.shade.isNotEmpty &&
                                                        it.shade != '—'
                                                    ? '${it.name} · ${it.shade}'
                                                    : it.name,
                                                style: const TextStyle(
                                                    fontSize: 14,
                                                    fontWeight:
                                                        FontWeight.w600)),
                                            Text(
                                                it.brand.isEmpty
                                                    ? 'My allocation'
                                                    : it.brand,
                                                style: TextStyle(
                                                    fontSize: 12,
                                                    color: crm.textSecondary)),
                                          ],
                                        ),
                                      ),
                                      FilledButton.tonalIcon(
                                        onPressed: () =>
                                            _adjustKitItem(live.id, i, it, usage),
                                        icon: const Icon(Icons.tune, size: 16),
                                        label: const Text('Update'),
                                        style: FilledButton.styleFrom(
                                          minimumSize: const Size(0, 34),
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 12),
                                          visualDensity: VisualDensity.compact,
                                        ),
                                      ),
                                    ],
                                  ),
                                  10.h,
                                  TubeGauge(
                                      quantity: it.quantity,
                                      fillLevel: it.fillLevel),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  /// usagePerWork of the linked studio product (default 10%).
  int _usageFor(List<InventoryProduct> products, KitItem it) {
    if (it.productId.isEmpty) return 10;
    for (final p in products) {
      if (p.id == it.productId) return p.usagePerWork;
    }
    return 10;
  }

  /// Adjust a single kit item's PER-ARTIST allocation (tube count + fill).
  /// Writes only to this artist's kit — never the shared studio stock.
  Future<void> _adjustKitItem(
      String kitId, int index, KitItem it, int usage) async {
    final crm = context.crmColors;
    final messenger = ScaffoldMessenger.of(context);
    var level = it.fillLevel.toDouble();
    var qty = it.quantity;
    var busy = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setSheet) {
          Future<void> commit() async {
            setSheet(() => busy = true);
            try {
              await ref.read(inventoryServiceProvider).updateKitItem(
                    kitId,
                    index,
                    fillLevel: level.round().clamp(0, 100),
                    quantity: qty,
                  );
              ref.invalidate(staffKitsProvider);
              if (sheetCtx.mounted) Navigator.pop(sheetCtx);
              messenger.showSnackBar(
                  const SnackBar(content: Text('Allocation updated')));
            } catch (e) {
              setSheet(() => busy = false);
              messenger.showSnackBar(SnackBar(content: Text('$e')));
            }
          }

          Widget stepBtn(IconData icon, VoidCallback? onTap) => InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                      color: crm.input,
                      borderRadius: BorderRadius.circular(10)),
                  child: Icon(icon,
                      size: 20,
                      color: onTap == null
                          ? crm.textSecondary.withValues(alpha: 0.4)
                          : crm.textPrimary),
                ),
              );

          return Padding(
            padding: EdgeInsets.fromLTRB(
                20, 14, 20, 20 + MediaQuery.of(sheetCtx).viewInsets.bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: crm.border,
                        borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                14.h,
                Text(
                    it.shade.isNotEmpty && it.shade != '—'
                        ? '${it.name} · ${it.shade}'
                        : it.name,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.bold)),
                4.h,
                Text('My allocation · update as you use it',
                    style: TextStyle(fontSize: 12.5, color: crm.textSecondary)),
                20.h,
                Row(
                  children: [
                    Icon(Icons.inventory_2_outlined,
                        size: 18, color: crm.textSecondary),
                    8.w,
                    Text('Tubes assigned',
                        style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: crm.textPrimary)),
                    const Spacer(),
                    stepBtn(Icons.remove,
                        (busy || qty <= 0) ? null : () => setSheet(() => qty--)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text('$qty',
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w800)),
                    ),
                    stepBtn(
                        Icons.add,
                        busy
                            ? null
                            : () => setSheet(() {
                                  if (qty <= 0 && level <= 0) level = 100;
                                  qty++;
                                })),
                  ],
                ),
                18.h,
                Divider(height: 1, color: crm.border),
                18.h,
                Row(
                  children: [
                    Text('${level.round()}%',
                        style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: crm.primary)),
                    12.w,
                    Expanded(
                      child: Slider(
                        value: level.clamp(0, 100),
                        min: 0,
                        max: 100,
                        divisions: 20,
                        label: '${level.round()}%',
                        onChanged:
                            busy ? null : (v) => setSheet(() => level = v),
                      ),
                    ),
                  ],
                ),
                8.h,
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final preset in const [100, 75, 50, 25, 0])
                      ActionChip(
                        label: Text('$preset%'),
                        onPressed: busy
                            ? null
                            : () => setSheet(() => level = preset.toDouble()),
                      ),
                    ActionChip(
                      avatar: const Icon(Icons.remove, size: 16),
                      label: Text('Use (−$usage%)'),
                      onPressed: busy
                          ? null
                          : () => setSheet(
                              () => level = (level - usage).clamp(0, 100)),
                    ),
                  ],
                ),
                20.h,
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: busy ? null : commit,
                    style:
                        FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                    child: busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Save allocation'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _editKit([StaffKit? kit]) async {
    await showKitEditor(context, ref, kit: kit);
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final isMobile = ResponsiveBuilder.isMobile(context);
    // Keep stock loaded so the kit-item picker has products available.
    ref.watch(inventoryProductsProvider);
    final role = AppRole.fromString(ref.watch(authSessionProvider)?.role);
    final isArtist = role == AppRole.artist;
    final canManage = role.canManageInventory;
    // Resolve Employee id → artist name to show the assignee on each card.
    var artistNames = const <String, String>{};
    if (canManage) {
      final users = ref.watch(crmUsersProvider).value;
      if (users != null) {
        artistNames = {
          for (final u in users)
            if (u.employeeId.isNotEmpty) u.employeeId: u.name,
        };
      }
    }
    final async = ref.watch(staffKitsProvider);

    return InvBody(
      isMobile: isMobile,
      child: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
            child: Text('Failed to load kits: $e',
                style: TextStyle(color: crm.textSecondary))),
        data: (kits) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InvHeader(
              title: isArtist ? 'My Kits' : 'Staff Kits',
              subtitle: '${kits.length} kits',
              actionLabel: 'New Kit',
              onAction: () => _editKit(),
            ),
            16.h,
            Expanded(
              child: kits.isEmpty
                  ? const InvEmpty(
                      icon: Icons.work_outline,
                      title: 'No kits yet',
                      subtitle: 'Create a kit for each artist.')
                  : isMobile
                      ? ListView.separated(
                          padding: const EdgeInsets.only(bottom: 24),
                          itemCount: kits.length,
                          separatorBuilder: (_, _) => 12.h,
                          itemBuilder: (context, i) =>
                              _kitCard(crm, kits[i], artistNames[kits[i].employeeId]),
                        )
                      : GridView.count(
                          crossAxisCount: 3,
                          childAspectRatio: 1.9,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          children: [
                            for (final k in kits)
                              _kitCard(crm, k, artistNames[k.employeeId]),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kitCard(CrmTheme crm, StaffKit k, [String? assignee]) {
    final checked = (_checks[k.id] ?? const {}).length;
    final pct = k.items.isEmpty ? 0 : (checked / k.items.length * 100).round();
    final units = k.items.fold<int>(0, (a, i) => a + i.quantity);
    // Show the assignee when it adds information beyond the kit name.
    final showAssignee = assignee != null &&
        assignee.isNotEmpty &&
        assignee.toLowerCase() != k.name.toLowerCase();
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _openKit(k),
      child: InvCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: crm.primary.withValues(alpha: 0.1),
                  child: Text(k.name.isNotEmpty ? k.name[0].toUpperCase() : '?',
                      style: TextStyle(
                          color: crm.primary, fontWeight: FontWeight.bold)),
                ),
                10.w,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(k.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.bold)),
                      2.h,
                      Text('${k.items.length} products · $units units',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 12, color: crm.textSecondary)),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.edit_outlined,
                      size: 18, color: crm.textSecondary),
                  onPressed: () => _editKit(k),
                  visualDensity: VisualDensity.compact,
                ),
                Icon(Icons.chevron_right, size: 18, color: crm.textSecondary),
              ],
            ),
            if (showAssignee) ...[
              8.h,
              Row(
                children: [
                  Icon(Icons.person_outline, size: 13, color: crm.primary),
                  4.w,
                  Expanded(
                    child: Text('Assigned to $assignee',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: crm.primary)),
                  ),
                ],
              ),
            ],
            10.h,
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: k.items.isEmpty ? 0 : checked / k.items.length,
                      minHeight: 7,
                      backgroundColor: crm.input,
                      valueColor:
                          AlwaysStoppedAnimation(const Color(0xFFC9A227)),
                    ),
                  ),
                ),
                10.w,
                Text('$pct%',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF8A6E10))),
              ],
            ),
            4.h,
            Text('$checked / ${k.items.length} verified',
                style: TextStyle(fontSize: 11, color: crm.textSecondary)),
          ],
        ),
      ),
    );
  }
}

// ── Kit editor dialog ─────────────────────────────────────────────────────

Future<void> showKitEditor(BuildContext context, WidgetRef ref,
    {StaffKit? kit}) async {
  // Managers assign a kit to an artist; artists' own kits auto-bind to them.
  final role = AppRole.fromString(ref.read(authSessionProvider)?.role);
  final canManage = role.canManageInventory;

  // Load the artist roster for the assignee picker (managers only).
  var artists = const <CrmUser>[];
  if (canManage) {
    try {
      final users = await ref.read(crmUsersProvider.future);
      // Only artists granted "Access to Inventory" can be assigned a kit.
      artists = users
          .where((u) =>
              u.role == 'artist' && u.inventoryAccess && u.employeeId.isNotEmpty)
          .toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    } catch (_) {
      artists = const [];
    }
  }
  if (!context.mounted) return;

  final crm = context.crmColors;
  final nameCtrl = TextEditingController(text: kit?.name ?? '');
  final items = <KitItem>[...(kit?.items ?? const [])];
  // Preselect the currently-assigned artist (by Employee id) if it's in range.
  var assigneeEmpId = kit != null &&
          kit.employeeId.isNotEmpty &&
          artists.any((a) => a.employeeId == kit.employeeId)
      ? kit.employeeId
      : null;
  var saving = false;

  await showDialog(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) {
        Future<void> addItem() async {
          final it = await _showKitItemDialog(context, ref);
          if (it != null) setState(() => items.add(it));
        }

        return AlertDialog(
          title: Text(kit == null ? 'New Kit' : 'Edit Kit'),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (canManage) ...[
                    DropdownButtonFormField<String>(
                      initialValue: assigneeEmpId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Assign to artist',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      hint: Text(artists.isEmpty
                          ? 'No inventory-access artists'
                          : 'Select an artist'),
                      items: [
                        for (final a in artists)
                          DropdownMenuItem(
                            value: a.employeeId,
                            child: Text(a.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ),
                      ],
                      onChanged: artists.isEmpty
                          ? null
                          : (v) => setState(() {
                                assigneeEmpId = v;
                                // Default the kit name to the artist's name.
                                final picked =
                                    artists.where((a) => a.employeeId == v);
                                if (picked.isNotEmpty &&
                                    nameCtrl.text.trim().isEmpty) {
                                  nameCtrl.text = picked.first.name;
                                }
                              }),
                    ),
                    if (artists.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                            'Enable "Access to Inventory" for an artist in '
                            'Settings to assign kits.',
                            style: TextStyle(
                                fontSize: 11.5, color: crm.textSecondary)),
                      ),
                    10.h,
                  ],
                  TextField(
                    controller: nameCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Kit / Artist name *'),
                  ),
                  14.h,
                  Row(
                    children: [
                      Text('Items (${items.length})',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: addItem,
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Add item'),
                      ),
                    ],
                  ),
                  if (items.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text('No items yet.',
                          style: TextStyle(color: crm.textSecondary)),
                    )
                  else
                    for (var i = 0; i < items.length; i++)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: Text(
                            items[i].shade.isNotEmpty && items[i].shade != '—'
                                ? '${items[i].name} · ${items[i].shade}'
                                : items[i].name),
                        subtitle: Text(
                            '${items[i].brand}  ×${items[i].quantity}'),
                        trailing: IconButton(
                          icon: Icon(Icons.close,
                              size: 18, color: crm.destructive),
                          onPressed: () => setState(() => items.removeAt(i)),
                        ),
                      ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed:
                  saving ? null : () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (nameCtrl.text.trim().isEmpty) return;
                      setState(() => saving = true);
                      try {
                        await ref.read(inventoryServiceProvider).saveKit(
                              id: kit?.id,
                              name: nameCtrl.text.trim(),
                              employeeId: canManage
                                  ? (assigneeEmpId ?? '')
                                  : (kit?.employeeId ?? ''),
                              items: items,
                            );
                        ref.invalidate(staffKitsProvider);
                        if (dialogContext.mounted) {
                          Navigator.of(dialogContext).pop();
                        }
                      } catch (e) {
                        setState(() => saving = false);
                        if (dialogContext.mounted) {
                          ScaffoldMessenger.of(dialogContext)
                              .showSnackBar(SnackBar(content: Text('$e')));
                        }
                      }
                    },
              child: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Save'),
            ),
          ],
        );
      },
    ),
  );
}

/// Add a kit item by picking from existing stock (products with quantity > 0),
/// with a manual fallback for anything not yet stocked.
Future<KitItem?> _showKitItemDialog(BuildContext context, WidgetRef ref) {
  final products = ref.read(inventoryProductsProvider).value ??
      const <InventoryProduct>[];
  // Show all studio products (including out-of-stock) so any can be allocated.
  final inStock = [...products]
    ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  InventoryProduct? selected;
  var custom = inStock.isEmpty; // no products at all → custom entry
  final qtyCtrl = TextEditingController(text: '1');
  final nameCtrl = TextEditingController();
  final brandCtrl = TextEditingController();
  final shadeCtrl = TextEditingController();

  String label(InventoryProduct p) {
    final shade = p.shade.isNotEmpty && p.shade != '—' ? ' · ${p.shade}' : '';
    final brand = p.brand.isNotEmpty ? ' — ${p.brand}' : '';
    final stock = p.quantity > 0 ? '${p.quantity} in stock' : 'out of stock';
    return '${p.name}$shade$brand  ($stock)';
  }

  return showDialog<KitItem>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        final crm = ctx.crmColors;
        return AlertDialog(
          title: const Text('Add Kit Item'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!custom) ...[
                  DropdownButtonFormField<InventoryProduct>(
                    initialValue: selected,
                    isExpanded: true,
                    decoration:
                        const InputDecoration(labelText: 'Pick from stock *'),
                    items: [
                      for (final p in inStock)
                        DropdownMenuItem(
                          value: p,
                          child: Text(label(p),
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: (v) => setState(() => selected = v),
                  ),
                  if (inStock.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text('No products in the studio inventory yet.',
                          style: TextStyle(
                              fontSize: 12, color: crm.textSecondary)),
                    ),
                ] else ...[
                  TextField(
                      controller: nameCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Product *')),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                        child: TextField(
                            controller: brandCtrl,
                            decoration:
                                const InputDecoration(labelText: 'Brand'))),
                    const SizedBox(width: 12),
                    Expanded(
                        child: TextField(
                            controller: shadeCtrl,
                            decoration:
                                const InputDecoration(labelText: 'Shade'))),
                  ]),
                ],
                const SizedBox(height: 12),
                SizedBox(
                  width: 110,
                  child: TextField(
                      controller: qtyCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Quantity')),
                ),
                const SizedBox(height: 4),
                TextButton.icon(
                  onPressed: () => setState(() => custom = !custom),
                  icon: Icon(custom ? Icons.inventory_2_outlined : Icons.edit,
                      size: 15),
                  label: Text(custom
                      ? 'Pick from stock instead'
                      : 'Add a custom item'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                final qty = int.tryParse(qtyCtrl.text.trim()) ?? 1;
                if (custom) {
                  if (nameCtrl.text.trim().isEmpty) return;
                  Navigator.pop(
                    ctx,
                    KitItem(
                      name: nameCtrl.text.trim(),
                      brand: brandCtrl.text.trim(),
                      shade: shadeCtrl.text.trim(),
                      quantity: qty,
                    ),
                  );
                } else {
                  final p = selected;
                  if (p == null) return;
                  Navigator.pop(
                    ctx,
                    KitItem(
                      productId: p.id,
                      name: p.name,
                      brand: p.brand,
                      shade: p.shade,
                      quantity: qty,
                    ),
                  );
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    ),
  );
}
