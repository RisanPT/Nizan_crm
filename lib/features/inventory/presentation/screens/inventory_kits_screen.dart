import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nizan_crm/core/auth/app_role.dart';
import 'package:nizan_crm/core/extensions/space_extension.dart';
import 'package:nizan_crm/core/models/crm_user.dart';
import 'package:nizan_crm/features/inventory/data/inventory_product.dart';
import 'package:nizan_crm/features/inventory/data/staff_kit.dart';
import 'package:nizan_crm/core/providers/auth_provider.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/core/utils/responsive_builder.dart';
import 'package:nizan_crm/features/inventory/controllers/inventory_controller.dart';
import 'package:nizan_crm/services/user_service.dart';
import 'package:nizan_crm/features/inventory/presentation/widgets/inventory_widgets.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/state/data_refresh.dart';

// ── Local helpers ───────────────────────────────────────────────────────────

/// Gold used for the per-kit verification checklist.
const _kGold = Color(0xFFC9A227);
const _kGoldDeep = Color(0xFF8A6E10);

const _avatarPalette = [
  Color(0xFF800020),
  Color(0xFF9E2B43),
  Color(0xFF6E1423),
  Color(0xFFB76E79),
  Color(0xFF5C1120),
  Color(0xFFAD3A53),
];

String _kitItemName(KitItem it) =>
    it.shade.isNotEmpty && it.shade != '—' ? '${it.name} · ${it.shade}' : it.name;

String _initials(String s) {
  final parts =
      s.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first[0].toUpperCase();
  return (parts[0][0] + parts[1][0]).toUpperCase();
}

String _roleLabel(String role) {
  final r = role.trim().replaceAll('_', ' ');
  if (r.isEmpty) return '';
  return r[0].toUpperCase() + r.substring(1);
}

Color _itemColor(CrmTheme crm, KitItem it) => it.isOut
    ? crm.destructive
    : (it.isTubeLow ? kLowStockColor : crm.success);

/// Derived numbers for one kit.
class _KitStats {
  final int items;
  final int units;
  final int low;
  final int empty;
  final double value;
  const _KitStats(this.items, this.units, this.low, this.empty, this.value);

  int get healthy => items - low - empty;
  int get alerts => low + empty;
  bool get needsAttention => alerts > 0;

  factory _KitStats.of(StaffKit k, Map<String, InventoryProduct> byId) {
    var units = 0, low = 0, empty = 0;
    var value = 0.0;
    for (final it in k.items) {
      units += it.quantity;
      if (it.isOut) {
        empty++;
      } else if (it.isTubeLow) {
        low++;
      }
      final p = byId[it.productId];
      if (p != null && it.quantity > 0) value += it.quantity * p.price;
    }
    return _KitStats(k.items.length, units, low, empty, value);
  }
}

class InventoryKitsScreen extends ConsumerStatefulWidget {
  const InventoryKitsScreen({super.key});

  @override
  ConsumerState<InventoryKitsScreen> createState() =>
      _InventoryKitsScreenState();
}

class _InventoryKitsScreenState extends ConsumerState<InventoryKitsScreen> {
  // Per-kit checklist verification state (local session only).
  final Map<String, Set<int>> _checks = {};

  final _searchCtrl = TextEditingController();
  String _query = '';
  bool _attentionOnly = false;

  /// Kit shown in the side detail panel (wide layouts only).
  String? _selectedId;

  /// Employee id → CRM user (managers only), refreshed every build.
  Map<String, CrmUser> _staff = const {};
  bool _isArtist = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _toggleCheck(String kitId, int i) {
    if (!mounted) return;
    setState(() {
      final set = _checks.putIfAbsent(kitId, () => {});
      if (set.contains(i)) {
        set.remove(i);
      } else {
        set.add(i);
      }
    });
  }

  int _verifiedCount(StaffKit k) =>
      (_checks[k.id] ?? const <int>{}).where((i) => i < k.items.length).length;

  String _assigneeLine(StaffKit k) {
    final staff = _staff[k.employeeId];
    if (staff == null) {
      if (_isArtist) return 'My allocation';
      return k.employeeId.isEmpty ? 'Unassigned' : 'Assigned staff';
    }
    final parts = <String>[
      if (staff.name.isNotEmpty &&
          staff.name.toLowerCase() != k.name.toLowerCase())
        staff.name,
      if (_roleLabel(staff.role).isNotEmpty) _roleLabel(staff.role),
    ];
    return parts.isEmpty ? 'Assigned staff' : parts.join(' · ');
  }

  String _avatarLabel(StaffKit k) {
    final staff = _staff[k.employeeId];
    return (staff != null && staff.name.isNotEmpty) ? staff.name : k.name;
  }

  // ── Detail: side panel (wide) or bottom sheet (narrow) ──

  void _openKit(StaffKit kit, bool wide) {
    if (wide) {
      setState(() => _selectedId = kit.id);
    } else {
      _openKitSheet(kit);
    }
  }

  void _openKitSheet(StaffKit kit) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.8,
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
              builder: (sheetCtx, setSheet) => Container(
                decoration: BoxDecoration(
                  color: Theme.of(sheetCtx).scaffoldBackgroundColor,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: _kitDetail(
                  ctx: sheetCtx,
                  kit: live,
                  products: products,
                  controller: controller,
                  showHandle: true,
                  onToggle: (i) {
                    _toggleCheck(live.id, i);
                    setSheet(() {});
                  },
                  onClose: () => Navigator.pop(ctx),
                  onDeleted: () {
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _kitDetail({
    required BuildContext ctx,
    required StaffKit kit,
    required List<InventoryProduct> products,
    required ValueChanged<int> onToggle,
    required VoidCallback onClose,
    required VoidCallback onDeleted,
    ScrollController? controller,
    bool showHandle = false,
  }) {
    final crm = ctx.crmColors;
    final byId = {for (final p in products) p.id: p};
    final s = _KitStats.of(kit, byId);
    final checked = _checks[kit.id] ?? const <int>{};
    final verified = _verifiedCount(kit);
    final frac = kit.items.isEmpty ? 0.0 : verified / kit.items.length;

    return Column(
      children: [
        if (showHandle)
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 4),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: crm.border, borderRadius: BorderRadius.circular(2)),
          ),
        Padding(
          padding: EdgeInsets.fromLTRB(18, showHandle ? 8 : 16, 8, 12),
          child: Row(
            children: [
              _StaffAvatar(label: _avatarLabel(kit), radius: 22),
              12.w,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(kit.name.isEmpty ? 'Untitled kit' : kit.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: crm.textPrimary)),
                    2.h,
                    Text(_assigneeLine(kit),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12.5, color: crm.textSecondary)),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Close',
                icon: const Icon(Icons.close),
                onPressed: onClose,
              ),
            ],
          ),
        ),
        Divider(height: 1, color: crm.border),
        Expanded(
          child: ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              Row(
                children: [
                  Expanded(
                      child: _MiniStat(
                          icon: Icons.inventory_2_outlined,
                          label: 'Items',
                          value: '${s.items}')),
                  8.w,
                  Expanded(
                      child: _MiniStat(
                          icon: Icons.layers_outlined,
                          label: 'Units',
                          value: '${s.units}')),
                  8.w,
                  Expanded(
                      child: _MiniStat(
                          icon: Icons.currency_rupee_rounded,
                          label: 'Value',
                          value: fmtINR(s.value))),
                ],
              ),
              14.h,
              InvCard(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text('Kit health',
                              style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: crm.textPrimary)),
                        ),
                        _healthBadge(crm, s),
                      ],
                    ),
                    10.h,
                    _HealthBar(stats: s, height: 8),
                    8.h,
                    _HealthLegend(stats: s),
                    14.h,
                    Row(
                      children: [
                        const Icon(Icons.fact_check_outlined,
                            size: 15, color: _kGold),
                        6.w,
                        Expanded(
                          child: Text(
                              '$verified / ${kit.items.length} verified',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 12, color: crm.textSecondary)),
                        ),
                        Text('${(frac * 100).round()}%',
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: _kGoldDeep)),
                      ],
                    ),
                    6.h,
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: frac,
                        minHeight: 6,
                        backgroundColor: crm.input,
                        valueColor: const AlwaysStoppedAnimation(_kGold),
                      ),
                    ),
                  ],
                ),
              ),
              14.h,
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _editKit(kit),
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('Edit kit'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _quickAddItem(kit),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add item'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () async {
                      if (await _confirmDeleteKit(kit)) onDeleted();
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: crm.destructive,
                      side: BorderSide(
                          color: crm.destructive.withValues(alpha: 0.4)),
                    ),
                    icon: const Icon(Icons.delete_outline, size: 16),
                    label: const Text('Delete'),
                  ),
                ],
              ),
              20.h,
              InvSectionHeader(
                title: 'Items',
                count: kit.items.length,
                subtitle: 'Tick to verify · tap Update to record usage',
              ),
              12.h,
              if (kit.items.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Column(
                    children: [
                      Icon(Icons.inventory_2_outlined,
                          size: 40,
                          color: crm.textSecondary.withValues(alpha: 0.4)),
                      8.h,
                      Text('No items in this kit yet',
                          style: TextStyle(
                              fontSize: 13, color: crm.textSecondary)),
                      8.h,
                      FilledButton.tonalIcon(
                        onPressed: () => _quickAddItem(kit),
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Add item'),
                      ),
                    ],
                  ),
                )
              else
                for (var i = 0; i < kit.items.length; i++)
                  _KitItemTile(
                    item: kit.items[i],
                    category: byId[kit.items[i].productId]?.category,
                    checked: checked.contains(i),
                    onToggle: () => onToggle(i),
                    onUpdate: () => _adjustKitItem(kit.id, i, kit.items[i],
                        _usageFor(products, kit.items[i])),
                  ),
            ],
          ),
        ),
      ],
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
              ref.refreshData.inventory();
              if (sheetCtx.mounted) Navigator.pop(sheetCtx);
              messenger.showSnackBar(
                  const SnackBar(content: Text('Allocation updated')));
            } catch (e) {
              setSheet(() => busy = false);
              messenger.showSnackBar(
                  SnackBar(content: Text(friendlyErrorMessage(e))));
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
                Text(_kitItemName(it),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
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
                    Expanded(
                      child: Text('Tubes assigned',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: crm.textPrimary)),
                    ),
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

  /// Quick "add item" straight from a kit card / detail panel. Uses the same
  /// item picker as the kit editor and saves the kit with the item appended.
  Future<void> _quickAddItem(StaffKit kit) async {
    final messenger = ScaffoldMessenger.of(context);
    final it = await _showKitItemDialog(context, ref);
    if (it == null) return;
    try {
      await ref.read(inventoryServiceProvider).saveKit(
            id: kit.id,
            name: kit.name,
            employeeId: kit.employeeId,
            items: [...kit.items, it],
            notes: kit.notes,
          );
      ref.refreshData.inventory();
      messenger.showSnackBar(
          SnackBar(content: Text('Added ${it.name} to ${kit.name}')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
    }
  }

  /// Returns true when the kit was deleted.
  Future<bool> _confirmDeleteKit(StaffKit kit) async {
    final crm = context.crmColors;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete kit?'),
        content: Text(
            'Remove "${kit.name}" and its ${kit.items.length} '
            'item${kit.items.length == 1 ? '' : 's'}? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: crm.destructive),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return false;
    try {
      await ref.read(inventoryServiceProvider).deleteKit(kit.id);
      ref.refreshData.inventory();
      if (mounted) {
        setState(() {
          _checks.remove(kit.id);
          if (_selectedId == kit.id) _selectedId = null;
        });
      }
      return true;
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, e);
      }
      return false;
    }
  }

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveBuilder.isMobile(context);
    // Keep stock loaded so the kit-item picker has products available.
    final products = ref.watch(inventoryProductsProvider).value ??
        const <InventoryProduct>[];
    final role = AppRole.fromString(ref.watch(authSessionProvider)?.role);
    _isArtist = role == AppRole.artist;
    final canManage = role.canManageInventory;
    // Resolve Employee id → staff member to show the assignee on each card.
    var staff = const <String, CrmUser>{};
    if (canManage) {
      final users = ref.watch(crmUsersProvider).value;
      if (users != null) {
        staff = {
          for (final u in users)
            if (u.employeeId.isNotEmpty) u.employeeId: u,
        };
      }
    }
    _staff = staff;
    final async = ref.watch(staffKitsProvider);

    return InvBody(
      isMobile: isMobile,
      child: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => AppErrorView(
            error: e, onRetry: () => ref.invalidate(staffKitsProvider)),
        data: (kits) => LayoutBuilder(builder: (context, box) {
          final wide = !isMobile && box.maxWidth >= 1080;
          final byId = {for (final p in products) p.id: p};
          final stats = {for (final k in kits) k.id: _KitStats.of(k, byId)};
          final selected = (wide && _selectedId != null)
              ? kits.where((k) => k.id == _selectedId).firstOrNull
              : null;

          final list = _kitList(kits, stats, isMobile, wide, selected?.id);
          if (selected == null) return list;

          final crm = context.crmColors;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: list),
              16.w,
              SizedBox(
                width: box.maxWidth >= 1400 ? 440 : 390,
                child: Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: crm.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: crm.border),
                  ),
                  child: _kitDetail(
                    ctx: context,
                    kit: selected,
                    products: products,
                    onToggle: (i) => _toggleCheck(selected.id, i),
                    onClose: () => setState(() => _selectedId = null),
                    onDeleted: () {},
                  ),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _kitList(List<StaffKit> kits, Map<String, _KitStats> stats,
      bool isMobile, bool wide, String? selectedId) {
    return LayoutBuilder(builder: (context, box) {
      final crm = context.crmColors;
      final w = box.maxWidth;

      // ── Aggregate metrics ──
      final all = stats.values;
      final totalItems = all.fold<int>(0, (a, s) => a + s.items);
      final totalUnits = all.fold<int>(0, (a, s) => a + s.units);
      final totalValue = all.fold<double>(0, (a, s) => a + s.value);
      final lowItems = all.fold<int>(0, (a, s) => a + s.low);
      final emptyItems = all.fold<int>(0, (a, s) => a + s.empty);
      final healthyItems = totalItems - lowItems - emptyItems;
      final attentionKits = all.where((s) => s.needsAttention).length;
      final staffIds = kits
          .map((k) => k.employeeId)
          .where((e) => e.isNotEmpty)
          .toSet();
      final unassigned = kits.where((k) => k.employeeId.isEmpty).length;
      final healthyPct =
          totalItems == 0 ? 0 : (healthyItems / totalItems * 100).round();

      // ── Search + filter ──
      final q = _query.trim().toLowerCase();
      final visible = kits.where((k) {
        if (_attentionOnly && !(stats[k.id]?.needsAttention ?? false)) {
          return false;
        }
        if (q.isEmpty) return true;
        final st = _staff[k.employeeId];
        return k.name.toLowerCase().contains(q) ||
            (st != null &&
                (st.name.toLowerCase().contains(q) ||
                    st.role.toLowerCase().contains(q))) ||
            k.items.any((it) => it.name.toLowerCase().contains(q));
      }).toList();

      final cols = w < 680 ? 1 : (w < 1040 ? 2 : 3);
      final cards = [
        for (final k in visible)
          _KitCard(
            kit: k,
            stats: stats[k.id]!,
            avatarLabel: _avatarLabel(k),
            assigneeLine: _assigneeLine(k),
            verified: _verifiedCount(k),
            selected: k.id == selectedId,
            fill: cols > 1,
            onOpen: () => _openKit(k, wide),
            onEdit: () => _editKit(k),
            onAddItem: () => _quickAddItem(k),
            onDelete: () => _confirmDeleteKit(k),
          ),
      ];

      return RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(staffKitsProvider);
          ref.invalidate(inventoryProductsProvider);
          try {
            await ref.read(staffKitsProvider.future);
          } catch (_) {
            // Failure is shown by the screen's error state; don't throw from pull-to-refresh.
          }
        },
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            InvHeader(
              title: _isArtist ? 'My Kits' : 'Staff Kits',
              subtitle: _isArtist
                  ? '${kits.length} kit${kits.length == 1 ? '' : 's'} · your allocated products'
                  : '${kits.length} kit${kits.length == 1 ? '' : 's'} · '
                      '${staffIds.length} staff equipped',
              actionLabel: isMobile ? 'New' : 'New Kit',
              onAction: () => _editKit(),
              trailing: IconButton(
                tooltip: 'Refresh',
                icon: Icon(Icons.refresh_rounded, color: crm.textSecondary),
                onPressed: () {
                  ref.invalidate(staffKitsProvider);
                  ref.invalidate(inventoryProductsProvider);
                },
              ),
            ),
            16.h,
            InvKpiGrid(width: w, stats: [
              InvKpi(
                  '${kits.length}',
                  'Total Kits',
                  attentionKits > 0
                      ? '$attentionKits need attention'
                      : 'all kits healthy',
                  Icons.work_outline,
                  crm.primary),
              InvKpi(
                  '${staffIds.length}',
                  'Staff Equipped',
                  unassigned > 0
                      ? '$unassigned kit${unassigned == 1 ? '' : 's'} unassigned'
                      : 'with an assigned kit',
                  Icons.people_outline_rounded,
                  crm.accent),
              InvKpi('$totalItems', 'Items Allocated', 'products across kits',
                  Icons.inventory_2_outlined, const Color(0xFF9E2B43)),
              InvKpi('$totalUnits', 'Units Allocated', 'tubes / units in kits',
                  Icons.layers_outlined, const Color(0xFF800020)),
              InvKpi(fmtINR(totalValue), 'Kit Value', 'qty × unit price',
                  Icons.currency_rupee_rounded, const Color(0xFF6E1423)),
              InvKpi('$healthyItems', 'Healthy Items',
                  '$healthyPct% of kit items',
                  Icons.check_circle_outline_rounded, crm.success),
              InvKpi('$lowItems', 'Running Low', 'open tube ≤ 20%',
                  Icons.trending_down_rounded, kLowStockColor),
              InvKpi('$emptyItems', 'Empty', 'no tubes left',
                  Icons.remove_circle_outline_rounded, crm.destructive),
            ]),
            16.h,
            if (kits.isEmpty)
              InvCard(
                child: SizedBox(
                  height: 280,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Flexible(
                        child: InvEmpty(
                            icon: Icons.work_outline,
                            title: 'No kits yet',
                            subtitle: 'Create a kit for each artist.'),
                      ),
                      12.h,
                      FilledButton.icon(
                        onPressed: () => _editKit(),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('New Kit'),
                      ),
                    ],
                  ),
                ),
              )
            else ...[
              _toolbar(crm, w, kits.length, attentionKits),
              14.h,
              if (visible.isEmpty)
                InvCard(
                  child: SizedBox(
                    height: 220,
                    child: InvEmpty(
                      icon: _attentionOnly && q.isEmpty
                          ? Icons.check_circle_outline_rounded
                          : Icons.search_off_rounded,
                      title: _attentionOnly && q.isEmpty
                          ? 'Every kit is healthy'
                          : 'No kits match',
                      subtitle: _attentionOnly && q.isEmpty
                          ? 'No items are running low or empty.'
                          : 'Try another staff or kit name, or clear the filter.',
                    ),
                  ),
                )
              else
                _grid(cards, cols),
            ],
          ],
        ),
      );
    });
  }

  Widget _toolbar(CrmTheme crm, double w, int total, int attention) {
    final search = TextField(
      controller: _searchCtrl,
      onChanged: (v) => setState(() => _query = v),
      decoration: InputDecoration(
        hintText: 'Search staff or kit…',
        prefixIcon: const Icon(Icons.search, size: 20),
        suffixIcon: _query.isEmpty
            ? null
            : IconButton(
                tooltip: 'Clear',
                icon: const Icon(Icons.close, size: 18),
                onPressed: () {
                  _searchCtrl.clear();
                  setState(() => _query = '');
                },
              ),
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(vertical: 11, horizontal: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
    final filters = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ChoiceChip(
          label: Text('All ($total)'),
          selected: !_attentionOnly,
          onSelected: (_) => setState(() => _attentionOnly = false),
        ),
        ChoiceChip(
          avatar: Icon(Icons.warning_amber_rounded,
              size: 16,
              color: _attentionOnly ? null : kLowStockColor),
          label: Text('Needs attention ($attention)'),
          selected: _attentionOnly,
          onSelected: (_) => setState(() => _attentionOnly = true),
        ),
      ],
    );
    if (w < 640) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [search, 10.h, filters],
      );
    }
    return Row(
      children: [
        Expanded(child: search),
        12.w,
        filters,
      ],
    );
  }

  /// Rows of equal-height cards (1 column → plain stacked list).
  Widget _grid(List<Widget> cards, int cols) {
    if (cols <= 1) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < cards.length; i++) ...[
            if (i > 0) 12.h,
            cards[i],
          ],
        ],
      );
    }
    final rows = <Widget>[];
    for (var i = 0; i < cards.length; i += cols) {
      final row = <Widget>[];
      for (var j = 0; j < cols; j++) {
        if (j > 0) row.add(12.w);
        final idx = i + j;
        row.add(Expanded(
            child: idx < cards.length ? cards[idx] : const SizedBox.shrink()));
      }
      if (rows.isNotEmpty) rows.add(12.h);
      rows.add(IntrinsicHeight(
        child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch, children: row),
      ));
    }
    return Column(children: rows);
  }
}

Widget _healthBadge(CrmTheme crm, _KitStats s) {
  if (s.items == 0) return invBadge('No items', crm.textSecondary);
  if (s.empty > 0) {
    return invBadge(
        '${s.alerts} need${s.alerts == 1 ? 's' : ''} attention', crm.destructive);
  }
  if (s.low > 0) {
    return invBadge(
        '${s.alerts} need${s.alerts == 1 ? 's' : ''} attention', kLowStockColor);
  }
  return invBadge('All good', crm.success);
}

// ── Kit card ────────────────────────────────────────────────────────────────

class _KitCard extends StatelessWidget {
  final StaffKit kit;
  final _KitStats stats;
  final String avatarLabel;
  final String assigneeLine;
  final int verified;
  final bool selected;

  /// True when the card is stretched to a grid row's height.
  final bool fill;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onAddItem;
  final VoidCallback onDelete;

  const _KitCard({
    required this.kit,
    required this.stats,
    required this.avatarLabel,
    required this.assigneeLine,
    required this.verified,
    required this.selected,
    required this.fill,
    required this.onOpen,
    required this.onEdit,
    required this.onAddItem,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final s = stats;
    // Worst items first for the preview.
    int rank(KitItem it) => it.isOut ? 0 : (it.isTubeLow ? 1 : 2);
    final preview = [...kit.items]..sort((a, b) {
        final r = rank(a).compareTo(rank(b));
        return r != 0 ? r : a.fillLevel.compareTo(b.fillLevel);
      });
    const maxPreview = 3;
    final more = kit.items.length - maxPreview;
    final vFrac = kit.items.isEmpty ? 0.0 : verified / kit.items.length;

    return Material(
      color: crm.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
            color: selected ? crm.primary : crm.border,
            width: selected ? 1.6 : 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
          child: Column(
            mainAxisSize: fill ? MainAxisSize.max : MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──
              Row(
                children: [
                  _StaffAvatar(label: avatarLabel, radius: 20),
                  12.w,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(kit.name.isEmpty ? 'Untitled kit' : kit.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: crm.textPrimary)),
                        2.h,
                        Row(
                          children: [
                            Icon(Icons.person_outline,
                                size: 13, color: crm.textSecondary),
                            3.w,
                            Flexible(
                              child: Text(assigneeLine,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: 11.5,
                                      color: crm.textSecondary)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Kit actions',
                    icon: Icon(Icons.more_vert,
                        size: 18, color: crm.textSecondary),
                    onSelected: (v) {
                      if (v == 'open') onOpen();
                      if (v == 'edit') onEdit();
                      if (v == 'add') onAddItem();
                      if (v == 'delete') onDelete();
                    },
                    itemBuilder: (_) => [
                      _menuItem('open', Icons.visibility_outlined, 'View kit'),
                      _menuItem('edit', Icons.edit_outlined, 'Edit'),
                      _menuItem('add', Icons.add, 'Add item'),
                      _menuItem('delete', Icons.delete_outline, 'Delete',
                          color: crm.destructive),
                    ],
                  ),
                ],
              ),
              12.h,
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Numbers ──
                    Row(
                      children: [
                        Expanded(
                            child: _MiniStat(
                                icon: Icons.inventory_2_outlined,
                                label: 'Items',
                                value: '${s.items}')),
                        8.w,
                        Expanded(
                            child: _MiniStat(
                                icon: Icons.layers_outlined,
                                label: 'Units',
                                value: '${s.units}')),
                        8.w,
                        Expanded(
                            child: _MiniStat(
                                icon: Icons.currency_rupee_rounded,
                                label: 'Value',
                                value: fmtINR(s.value))),
                      ],
                    ),
                    12.h,
                    // ── Health ──
                    Row(
                      children: [
                        Expanded(
                          child: Text('Kit health',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: crm.textSecondary)),
                        ),
                        _healthBadge(crm, s),
                      ],
                    ),
                    8.h,
                    _HealthBar(stats: s, height: 6),
                    6.h,
                    _HealthLegend(stats: s),
                    12.h,
                    // ── Item preview ──
                    if (kit.items.isEmpty)
                      Text('No items yet — add products to this kit.',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 12, color: crm.textSecondary))
                    else ...[
                      for (final it in preview.take(maxPreview))
                        _PreviewRow(item: it),
                      if (more > 0)
                        Text('+ $more more item${more == 1 ? '' : 's'}',
                            style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: crm.primary)),
                    ],
                    10.h,
                    // ── Verification ──
                    Row(
                      children: [
                        const Icon(Icons.fact_check_outlined,
                            size: 13, color: _kGold),
                        4.w,
                        Expanded(
                          child: Text(
                              '$verified / ${kit.items.length} verified',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 11, color: crm.textSecondary)),
                        ),
                        SizedBox(
                          width: 70,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: vFrac,
                              minHeight: 5,
                              backgroundColor: crm.input,
                              valueColor:
                                  const AlwaysStoppedAnimation(_kGold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (fill) const Spacer() else 6.h,
              Divider(height: 14, color: crm.border),
              // ── Actions ──
              Row(
                children: [
                  TextButton.icon(
                    onPressed: onOpen,
                    style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact),
                    icon: const Icon(Icons.open_in_new_rounded, size: 16),
                    label: const Text('Open'),
                  ),
                  TextButton.icon(
                    onPressed: onAddItem,
                    style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add item'),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Edit kit',
                    visualDensity: VisualDensity.compact,
                    icon: Icon(Icons.edit_outlined,
                        size: 18, color: crm.textSecondary),
                    onPressed: onEdit,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  PopupMenuItem<String> _menuItem(String value, IconData icon, String label,
          {Color? color}) =>
      PopupMenuItem(
        value: value,
        child: Row(children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(label, style: color == null ? null : TextStyle(color: color)),
        ]),
      );
}

class _PreviewRow extends StatelessWidget {
  final KitItem item;
  const _PreviewRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final color = _itemColor(crm, item);
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          8.w,
          Expanded(
            child: Text(_kitItemName(item),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: crm.textPrimary)),
          ),
          8.w,
          SizedBox(
            width: 64,
            child: TubeGauge(
                quantity: item.quantity,
                fillLevel: item.fillLevel,
                height: 6,
                showLabel: false),
          ),
          6.w,
          SizedBox(
            width: 40,
            child: Text(item.isOut ? 'Empty' : '${item.fillLevel}%',
                textAlign: TextAlign.right,
                maxLines: 1,
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w700, color: color)),
          ),
        ],
      ),
    );
  }
}

// ── Detail item tile ────────────────────────────────────────────────────────

class _KitItemTile extends StatelessWidget {
  final KitItem item;
  final String? category;
  final bool checked;
  final VoidCallback onToggle;
  final VoidCallback onUpdate;
  const _KitItemTile({
    required this.item,
    required this.category,
    required this.checked,
    required this.onToggle,
    required this.onUpdate,
  });

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final it = item;
    final color = _itemColor(crm, it);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
      decoration: BoxDecoration(
        color: checked ? _kGold.withValues(alpha: 0.08) : crm.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: checked ? _kGold : crm.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Tooltip(
                message: checked ? 'Verified' : 'Mark as verified',
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onToggle,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: checked ? _kGold : crm.surface,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: checked ? _kGold : crm.border),
                    ),
                    child: checked
                        ? const Icon(Icons.check, size: 16, color: Colors.white)
                        : null,
                  ),
                ),
              ),
              10.w,
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10)),
                child: Icon(
                    category == null
                        ? Icons.inventory_2_outlined
                        : productIcon(category!),
                    size: 17,
                    color: color),
              ),
              10.w,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_kitItemName(it),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: crm.textPrimary)),
                    2.h,
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                              it.brand.isEmpty ? 'My allocation' : it.brand,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 11.5, color: crm.textSecondary)),
                        ),
                        if (it.isOut || it.isTubeLow) ...[
                          6.w,
                          invBadge(it.isOut ? 'Empty' : 'Low', color),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              6.w,
              FilledButton.tonalIcon(
                onPressed: onUpdate,
                icon: const Icon(Icons.tune, size: 16),
                label: const Text('Update'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 34),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
          10.h,
          TubeGauge(quantity: it.quantity, fillLevel: it.fillLevel),
        ],
      ),
    );
  }
}

// ── Small building blocks ───────────────────────────────────────────────────

class _StaffAvatar extends StatelessWidget {
  final String label;
  final double radius;
  const _StaffAvatar({required this.label, this.radius = 20});

  @override
  Widget build(BuildContext context) {
    final key = label.trim().toLowerCase();
    var h = 0;
    for (final c in key.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    final color = _avatarPalette[h % _avatarPalette.length];
    return CircleAvatar(
      radius: radius,
      backgroundColor: color.withValues(alpha: 0.12),
      child: Text(_initials(label),
          style: TextStyle(
              color: color,
              fontSize: radius * 0.72,
              fontWeight: FontWeight.w800)),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _MiniStat(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: crm.input,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: crm.textSecondary),
              4.w,
              Flexible(
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: crm.textSecondary)),
              ),
            ],
          ),
          3.h,
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value,
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: crm.textPrimary)),
          ),
        ],
      ),
    );
  }
}

/// Segmented healthy / low / empty bar for a kit.
class _HealthBar extends StatelessWidget {
  final _KitStats stats;
  final double height;
  const _HealthBar({required this.stats, this.height = 6});

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final segs = [
      (stats.healthy, crm.success),
      (stats.low, kLowStockColor),
      (stats.empty, crm.destructive),
    ].where((e) => e.$1 > 0).toList();
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: SizedBox(
        height: height,
        child: segs.isEmpty
            ? ColoredBox(color: crm.input, child: const SizedBox.expand())
            : Row(
                children: [
                  for (var i = 0; i < segs.length; i++) ...[
                    if (i > 0) const SizedBox(width: 2),
                    Expanded(
                      flex: segs[i].$1,
                      child: ColoredBox(
                          color: segs[i].$2,
                          child: const SizedBox.expand()),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}

class _HealthLegend extends StatelessWidget {
  final _KitStats stats;
  const _HealthLegend({required this.stats});

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    Widget dot(Color c, String t) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
            4.w,
            Text(t, style: TextStyle(fontSize: 11, color: crm.textSecondary)),
          ],
        );
    return Wrap(
      spacing: 12,
      runSpacing: 4,
      children: [
        dot(crm.success, '${stats.healthy} healthy'),
        dot(kLowStockColor, '${stats.low} low'),
        dot(crm.destructive, '${stats.empty} empty'),
      ],
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
    } catch (e) {
      artists = const [];
      // The editor still opens, but tell the manager why the list is empty.
      if (context.mounted) {
        showWarningSnackBar(
            context,
            friendlyErrorMessage(e,
                fallback: "Couldn't load the artist list. Please try again."));
      }
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
                        ref.refreshData.inventory();
                        if (dialogContext.mounted) {
                          Navigator.of(dialogContext).pop();
                        }
                      } catch (e) {
                        setState(() => saving = false);
                        if (dialogContext.mounted) {
                          showErrorSnackBar(dialogContext, e);
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
  // Show all studio products sorted alphabetically.
  final allProducts = [...products]
    ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  InventoryProduct? selected;
  var custom = allProducts.isEmpty; // no products at all → custom entry
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
          contentPadding: const EdgeInsets.fromLTRB(0, 16, 0, 0),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!custom) ...[
                  // ── Searchable product picker ──────────────────────────
                  _ProductPickerField(
                    products: allProducts,
                    selected: selected,
                    label: label,
                    onSelected: (p) => setState(() => selected = p),
                  ),
                  if (allProducts.isEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                      child: Text('No products in the studio inventory yet.',
                          style: TextStyle(
                              fontSize: 12, color: crm.textSecondary)),
                    ),
                ] else ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
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
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: SizedBox(
                    width: 110,
                    child: TextField(
                        controller: qtyCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Quantity')),
                  ),
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: TextButton.icon(
                    onPressed: () => setState(() => custom = !custom),
                    icon: Icon(custom ? Icons.inventory_2_outlined : Icons.edit,
                        size: 15),
                    label: Text(custom
                        ? 'Pick from stock instead'
                        : 'Add a custom item'),
                  ),
                ),
                const SizedBox(height: 8),
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

/// Inline search-and-filter widget for picking a product from inventory.
/// Shows a search TextField + in-stock toggle + scrollable filtered list.
class _ProductPickerField extends StatefulWidget {
  final List<InventoryProduct> products;
  final InventoryProduct? selected;
  final String Function(InventoryProduct) label;
  final ValueChanged<InventoryProduct?> onSelected;

  const _ProductPickerField({
    required this.products,
    required this.selected,
    required this.label,
    required this.onSelected,
  });

  @override
  State<_ProductPickerField> createState() => _ProductPickerFieldState();
}

class _ProductPickerFieldState extends State<_ProductPickerField> {
  final _searchCtrl = TextEditingController();
  bool _inStockOnly = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() => setState(() => _query = _searchCtrl.text));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;

    final filtered = widget.products.where((p) {
      if (_inStockOnly && p.quantity <= 0) return false;
      if (_query.isEmpty) return true;
      final q = _query.toLowerCase();
      return p.name.toLowerCase().contains(q) ||
          p.brand.toLowerCase().contains(q) ||
          p.shade.toLowerCase().contains(q);
    }).toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Search bar + filter chip ───────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Search products…',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _query.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _query = '');
                            },
                          )
                        : null,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        vertical: 10, horizontal: 12),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: const Text('In stock'),
                selected: _inStockOnly,
                onSelected: (v) => setState(() => _inStockOnly = v),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),

        // ── Selected item banner ───────────────────────────────────────
        if (widget.selected != null)
          Container(
            margin: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: crm.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: crm.primary.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle_outline, size: 16, color: crm.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.label(widget.selected!),
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: crm.primary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, size: 16, color: crm.textSecondary),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => widget.onSelected(null),
                ),
              ],
            ),
          ),

        // ── Results list ───────────────────────────────────────────────
        SizedBox(
          height: 240,
          child: filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.search_off,
                          size: 36,
                          color: crm.textSecondary.withValues(alpha: 0.4)),
                      const SizedBox(height: 8),
                      Text('No products match',
                          style: TextStyle(color: crm.textSecondary)),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, i) {
                    final p = filtered[i];
                    final isSelected = widget.selected?.id == p.id;
                    final outOfStock = p.quantity <= 0;
                    return InkWell(
                      onTap: outOfStock
                          ? null
                          : () => widget.onSelected(isSelected ? null : p),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                        color: isSelected
                            ? crm.primary.withValues(alpha: 0.06)
                            : Colors.transparent,
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    () {
                                      final shade = p.shade.isNotEmpty &&
                                              p.shade != '—'
                                          ? ' · ${p.shade}'
                                          : '';
                                      return '${p.name}$shade';
                                    }(),
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w600,
                                      color: outOfStock
                                          ? crm.textSecondary
                                          : crm.textPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (p.brand.isNotEmpty)
                                    Text(
                                      p.brand,
                                      style: TextStyle(
                                          fontSize: 11.5,
                                          color: crm.textSecondary),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: outOfStock
                                    ? crm.textSecondary.withValues(alpha: 0.08)
                                    : crm.success.withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                outOfStock
                                    ? 'Out of stock'
                                    : '${p.quantity} in stock',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  color: outOfStock
                                      ? crm.textSecondary
                                      : crm.success,
                                ),
                              ),
                            ),
                            if (isSelected) ...[
                              const SizedBox(width: 8),
                              Icon(Icons.check_circle,
                                  size: 18, color: crm.primary),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        Divider(height: 1, color: crm.border),
      ],
    );
  }
}
