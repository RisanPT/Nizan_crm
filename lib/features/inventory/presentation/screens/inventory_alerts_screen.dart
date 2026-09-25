import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/extensions/space_extension.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/core/utils/responsive_builder.dart';
import 'package:nizan_crm/features/inventory/controllers/inventory_controller.dart';
import 'package:nizan_crm/features/inventory/data/inventory_product.dart';
import 'package:nizan_crm/features/inventory/presentation/widgets/inventory_dialogs.dart';
import 'package:nizan_crm/features/inventory/presentation/widgets/inventory_widgets.dart';

// ── Alert model helpers ─────────────────────────────────────────────────────

enum _Filter { all, out, low, tube }

enum _Sort { urgent, name, category, cost, recent }

const _sortLabels = {
  _Sort.urgent: 'Most urgent',
  _Sort.name: 'Name (A–Z)',
  _Sort.category: 'Category',
  _Sort.cost: 'Restock cost',
  _Sort.recent: 'Recently added',
};

bool _flagged(InventoryProduct p) => p.isOut || p.isLow || p.isTubeLow;

/// 0 = out of stock, 1 = low stock, 2 = only the open tube is nearly empty.
int _severity(InventoryProduct p) => p.isOut ? 0 : (p.isLow ? 1 : 2);

/// Units to buy to get back above the reorder level (at least one).
int _suggestedQty(InventoryProduct p) {
  final n = p.lowStockThreshold + 1 - p.quantity;
  return n < 1 ? 1 : n;
}

double _restockCost(InventoryProduct p) => _suggestedQty(p) * p.price;

int _urgencyCompare(InventoryProduct a, InventoryProduct b) {
  final s = _severity(a).compareTo(_severity(b));
  if (s != 0) return s;
  double ratio(InventoryProduct p) =>
      p.quantity / (p.lowStockThreshold <= 0 ? 1 : p.lowStockThreshold);
  final r = ratio(a).compareTo(ratio(b));
  if (r != 0) return r;
  final f = a.fillLevel.compareTo(b.fillLevel);
  if (f != 0) return f;
  return a.name.toLowerCase().compareTo(b.name.toLowerCase());
}

Color _severityColor(CrmTheme crm, InventoryProduct p) => p.isOut
    ? crm.destructive
    : (p.isLow ? kLowStockColor : crm.warning);

String _severityLabel(InventoryProduct p) =>
    p.isOut ? 'OUT OF STOCK' : (p.isLow ? 'LOW STOCK' : 'TUBE LOW');

// ── Screen ──────────────────────────────────────────────────────────────────

class InventoryAlertsScreen extends ConsumerStatefulWidget {
  const InventoryAlertsScreen({super.key});

  @override
  ConsumerState<InventoryAlertsScreen> createState() =>
      _InventoryAlertsScreenState();
}

class _InventoryAlertsScreenState extends ConsumerState<InventoryAlertsScreen> {
  final _searchCtrl = TextEditingController();
  _Filter _filter = _Filter.all;
  _Sort _sort = _Sort.urgent;
  bool _grouped = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  bool _matchesFilter(InventoryProduct p, _Filter f) {
    switch (f) {
      case _Filter.all:
        return true;
      case _Filter.out:
        return p.isOut;
      case _Filter.low:
        return p.isLow;
      case _Filter.tube:
        return p.isTubeLow;
    }
  }

  void _refresh() => ref.invalidate(inventoryProductsProvider);

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final isMobile = ResponsiveBuilder.isMobile(context);
    final async = ref.watch(inventoryProductsProvider);

    return InvBody(
      isMobile: isMobile,
      child: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => AppErrorView(error: e, onRetry: _refresh),
        data: (products) => LayoutBuilder(builder: (context, box) {
          final flagged = products.where(_flagged).toList();
          final out = flagged.where((p) => p.isOut).length;
          final low = flagged.where((p) => p.isLow).length;
          final tube = flagged.where((p) => p.isTubeLow).length;
          final cost = flagged.fold<double>(0, (a, p) => a + _restockCost(p));
          final cats = flagged.map((p) => p.category).toSet();
          final allCats = products.map((p) => p.category).toSet();
          final counts = {
            _Filter.all: flagged.length,
            _Filter.out: out,
            _Filter.low: low,
            _Filter.tube: tube,
          };

          // ── Filter / search / sort ──
          final q = _searchCtrl.text.trim().toLowerCase();
          final shown = flagged
              .where((p) => _matchesFilter(p, _filter))
              .where((p) =>
                  q.isEmpty ||
                  p.name.toLowerCase().contains(q) ||
                  p.brand.toLowerCase().contains(q) ||
                  p.shade.toLowerCase().contains(q) ||
                  p.category.toLowerCase().contains(q))
              .toList();
          switch (_sort) {
            case _Sort.urgent:
              shown.sort(_urgencyCompare);
            case _Sort.name:
              shown.sort((a, b) =>
                  a.name.toLowerCase().compareTo(b.name.toLowerCase()));
            case _Sort.category:
              shown.sort((a, b) {
                final c = a.category.compareTo(b.category);
                return c != 0 ? c : _urgencyCompare(a, b);
              });
            case _Sort.cost:
              shown.sort((a, b) => _restockCost(b).compareTo(_restockCost(a)));
            case _Sort.recent:
              shown.sort((a, b) {
                final x = a.createdAt, y = b.createdAt;
                if (x == null && y == null) return 0;
                if (x == null) return 1;
                if (y == null) return -1;
                return y.compareTo(x);
              });
          }

          void restock(InventoryProduct p) =>
              showProductDialog(context, ref, product: p);

          return RefreshIndicator(
            onRefresh: () async {
              _refresh();
              try {
                await ref.read(inventoryProductsProvider.future);
              } catch (_) {
                // Failure is shown by the screen's error state; don't throw from pull-to-refresh.
              }
            },
            child: ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                InvHeader(
                  title: 'Restock Alerts',
                  subtitle: flagged.isEmpty
                      ? 'Everything is above its reorder level'
                      : '${flagged.length} product${flagged.length == 1 ? '' : 's'} need attention',
                  trailing: IconButton(
                    tooltip: 'Refresh',
                    icon: Icon(Icons.refresh_rounded, color: crm.textSecondary),
                    onPressed: _refresh,
                  ),
                ),
                16.h,
                InvKpiGrid(width: box.maxWidth, stats: [
                  InvKpi('$out', 'Out of Stock', 'zero units left',
                      Icons.remove_shopping_cart_outlined, crm.destructive),
                  InvKpi('$low', 'Low Stock', 'at or below reorder level',
                      Icons.trending_down_rounded, kLowStockColor),
                  InvKpi('$tube', 'Tube Nearly Empty', 'open tube ≤ 20% left',
                      Icons.water_drop_outlined, crm.warning),
                  InvKpi(fmtINR(cost), 'Est. Restock Cost',
                      'suggested qty × unit price',
                      Icons.currency_rupee_rounded, const Color(0xFF6E1423)),
                  InvKpi('${cats.length}', 'Categories Affected',
                      'of ${allCats.length} categories',
                      Icons.category_outlined, crm.primary),
                ]),
                16.h,
                if (flagged.isEmpty)
                  _AllStockedUp(productCount: products.length)
                else ...[
                  _Toolbar(
                    compact: box.maxWidth < 700,
                    filter: _filter,
                    counts: counts,
                    searchCtrl: _searchCtrl,
                    sort: _sort,
                    grouped: _grouped,
                    onFilter: (f) => setState(() => _filter = f),
                    onSearch: () => setState(() {}),
                    onSort: (s) => setState(() => _sort = s),
                    onGrouped: (g) => setState(() => _grouped = g),
                  ),
                  14.h,
                  if (shown.isEmpty)
                    InvCard(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 28),
                        child: InvEmpty(
                          icon: Icons.search_off_rounded,
                          title: 'No matching alerts',
                          subtitle: q.isEmpty
                              ? 'Nothing in this filter right now.'
                              : 'Try a different search or filter.',
                        ),
                      ),
                    )
                  else if (_grouped)
                    ..._groupedSections(shown, box.maxWidth, restock)
                  else
                    _AlertGrid(
                        items: shown, width: box.maxWidth, onRestock: restock),
                ],
              ],
            ),
          );
        }),
      ),
    );
  }

  List<Widget> _groupedSections(List<InventoryProduct> items, double width,
      void Function(InventoryProduct) onRestock) {
    final groups = <String, List<InventoryProduct>>{};
    for (final p in items) {
      groups.putIfAbsent(p.category, () => []).add(p);
    }
    // Most urgent category first (by its worst item), then by size.
    final keys = groups.keys.toList()
      ..sort((a, b) {
        final s = _severity(groups[a]!.reduce(
                (x, y) => _urgencyCompare(x, y) <= 0 ? x : y))
            .compareTo(_severity(groups[b]!
                .reduce((x, y) => _urgencyCompare(x, y) <= 0 ? x : y)));
        return s != 0 ? s : groups[b]!.length.compareTo(groups[a]!.length);
      });
    return [
      for (final k in keys) ...[
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 4, 2, 10),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                    color: categoryColor(k).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8)),
                child: Icon(productIcon(k), size: 15, color: categoryColor(k)),
              ),
              10.w,
              Expanded(
                child: InvSectionHeader(
                  title: k,
                  count: groups[k]!.length,
                  badgeColor: categoryColor(k),
                  subtitle:
                      'Est. ${fmtINR(groups[k]!.fold<double>(0, (a, p) => a + _restockCost(p)))} to restock',
                ),
              ),
            ],
          ),
        ),
        _AlertGrid(items: groups[k]!, width: width, onRestock: onRestock),
        18.h,
      ],
    ];
  }
}

// ── Toolbar: filter chips, search, sort, grouping ───────────────────────────

class _Toolbar extends StatelessWidget {
  final bool compact;
  final _Filter filter;
  final Map<_Filter, int> counts;
  final TextEditingController searchCtrl;
  final _Sort sort;
  final bool grouped;
  final ValueChanged<_Filter> onFilter;
  final VoidCallback onSearch;
  final ValueChanged<_Sort> onSort;
  final ValueChanged<bool> onGrouped;
  const _Toolbar({
    required this.compact,
    required this.filter,
    required this.counts,
    required this.searchCtrl,
    required this.sort,
    required this.grouped,
    required this.onFilter,
    required this.onSearch,
    required this.onSort,
    required this.onGrouped,
  });

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final labels = {
      _Filter.all: ('All', crm.primary),
      _Filter.out: ('Out', crm.destructive),
      _Filter.low: ('Low', kLowStockColor),
      _Filter.tube: ('Tube low', crm.warning),
    };

    final chips = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final f in _Filter.values)
          _FilterChip(
            label: labels[f]!.$1,
            count: counts[f] ?? 0,
            color: labels[f]!.$2,
            selected: filter == f,
            onTap: () => onFilter(f),
          ),
      ],
    );

    final search = SizedBox(
      height: 40,
      child: TextField(
        controller: searchCtrl,
        onChanged: (_) => onSearch(),
        style: TextStyle(fontSize: 13, color: crm.textPrimary),
        decoration: InputDecoration(
          isDense: true,
          hintText: 'Search name, brand, shade…',
          hintStyle: TextStyle(fontSize: 13, color: crm.textSecondary),
          prefixIcon:
              Icon(Icons.search_rounded, size: 18, color: crm.textSecondary),
          suffixIcon: searchCtrl.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Clear',
                  icon: Icon(Icons.close_rounded,
                      size: 16, color: crm.textSecondary),
                  onPressed: () {
                    searchCtrl.clear();
                    onSearch();
                  },
                ),
          filled: true,
          fillColor: crm.surface,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: crm.border)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: crm.border)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: crm.primary)),
        ),
      ),
    );

    final sortBtn = PopupMenuButton<_Sort>(
      tooltip: 'Sort',
      initialValue: sort,
      onSelected: onSort,
      itemBuilder: (_) => [
        for (final s in _Sort.values)
          PopupMenuItem(value: s, child: Text(_sortLabels[s]!)),
      ],
      child: _OutlinedPill(
        icon: Icons.sort_rounded,
        label: compact ? 'Sort' : _sortLabels[sort]!,
      ),
    );

    final groupBtn = Tooltip(
      message: grouped ? 'Show as one list' : 'Group by category',
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => onGrouped(!grouped),
        child: _OutlinedPill(
          icon: grouped ? Icons.view_agenda_outlined : Icons.workspaces_outline,
          label: compact ? 'Group' : (grouped ? 'Grouped' : 'Group'),
          active: grouped,
        ),
      ),
    );

    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          chips,
          10.h,
          Row(children: [
            Expanded(child: search),
            8.w,
            sortBtn,
            8.w,
            groupBtn,
          ]),
        ],
      );
    }
    return Row(
      children: [
        chips,
        16.w,
        Expanded(child: search),
        8.w,
        sortBtn,
        8.w,
        groupBtn,
      ],
    );
  }
}

class _OutlinedPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  const _OutlinedPill(
      {required this.icon, required this.label, this.active = false});

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: active ? crm.primary.withValues(alpha: 0.1) : crm.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: active ? crm.primary.withValues(alpha: 0.4) : crm.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: 16, color: active ? crm.primary : crm.textSecondary),
          6.w,
          Text(label,
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: active ? crm.primary : crm.textPrimary)),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({
    required this.label,
    required this.count,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.fromLTRB(12, 7, 7, 7),
        decoration: BoxDecoration(
          color: selected ? color : crm.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? color : crm.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: selected ? Colors.white : crm.textPrimary)),
            6.w,
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
              decoration: BoxDecoration(
                color: selected
                    ? Colors.white.withValues(alpha: 0.25)
                    : color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('$count',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: selected ? Colors.white : color)),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Alert cards ─────────────────────────────────────────────────────────────

class _AlertGrid extends StatelessWidget {
  final List<InventoryProduct> items;
  final double width;
  final void Function(InventoryProduct) onRestock;
  const _AlertGrid(
      {required this.items, required this.width, required this.onRestock});

  @override
  Widget build(BuildContext context) {
    final cols = width < 640 ? 1 : (width < 1150 ? 2 : 3);
    const gap = 12.0;
    final w = (width - gap * (cols - 1)) / cols;
    return Wrap(
      spacing: gap,
      runSpacing: gap,
      children: [
        for (final p in items)
          SizedBox(
              width: w,
              child: _AlertCard(product: p, onRestock: () => onRestock(p))),
      ],
    );
  }
}

class _AlertCard extends StatelessWidget {
  final InventoryProduct product;
  final VoidCallback onRestock;
  const _AlertCard({required this.product, required this.onRestock});

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final p = product;
    final color = _severityColor(crm, p);
    final thr = p.lowStockThreshold;
    // Bar shows stock against a comfortable level of twice the reorder point.
    final target = thr <= 0 ? 2 : thr * 2;
    final frac = (p.quantity / target).clamp(0.0, 1.0);
    final suggest = _suggestedQty(p);

    return Container(
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(height: 4, color: color),
          Container(
            color: color.withValues(alpha: 0.04),
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Title row ──
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: p.isOut ? color : color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Icon(productIcon(p.category),
                          size: 20, color: p.isOut ? Colors.white : color),
                    ),
                    12.w,
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(invDisplayName(p),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: crm.textPrimary)),
                          3.h,
                          Text(
                              '${p.brand.isEmpty ? '—' : p.brand} · ${p.category}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 11.5, color: crm.textSecondary)),
                        ],
                      ),
                    ),
                    8.w,
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: p.isOut ? color : color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(_severityLabel(p),
                          style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.3,
                              color: p.isOut ? Colors.white : color)),
                    ),
                  ],
                ),
                14.h,

                // ── Stock vs reorder level ──
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${p.quantity}',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            height: 1.0,
                            color: color)),
                    4.w,
                    Text('in stock',
                        style: TextStyle(
                            fontSize: 11.5, color: crm.textSecondary)),
                    const Spacer(),
                    Flexible(
                      child: Text('reorder at ≤ $thr',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: crm.textSecondary)),
                    ),
                  ],
                ),
                6.h,
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: frac,
                    minHeight: 6,
                    backgroundColor: crm.input,
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                ),
                12.h,
                TubeGauge(quantity: p.quantity, fillLevel: p.fillLevel),
                14.h,

                // ── Reorder suggestion ──
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: crm.background,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: crm.border),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _MiniStat(
                            label: 'Suggested order',
                            value: '$suggest unit${suggest == 1 ? '' : 's'}'),
                      ),
                      Expanded(
                        child: _MiniStat(
                            label: 'Unit price', value: fmtINR(p.price)),
                      ),
                      Expanded(
                        child: _MiniStat(
                            label: 'Est. cost',
                            value: fmtINR(_restockCost(p)),
                            emphasis: true),
                      ),
                    ],
                  ),
                ),
                12.h,

                // ── Footer ──
                Row(
                  children: [
                    Icon(Icons.schedule_rounded,
                        size: 12, color: crm.textSecondary),
                    4.w,
                    Expanded(
                      child: Text('Added ${fmtAdded(p.createdAt)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 11, color: crm.textSecondary)),
                    ),
                    8.w,
                    FilledButton.icon(
                      onPressed: onRestock,
                      icon: const Icon(Icons.add_shopping_cart_rounded,
                          size: 16),
                      label: const Text('Restock',
                          style: TextStyle(
                              fontSize: 12.5, fontWeight: FontWeight.w700)),
                      style: FilledButton.styleFrom(
                        backgroundColor: p.isOut ? color : null,
                        minimumSize: const Size(0, 36),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final bool emphasis;
  const _MiniStat(
      {required this.label, required this.value, this.emphasis = false});

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 10, color: crm.textSecondary)),
        2.h,
        Text(value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 12.5,
                fontWeight: emphasis ? FontWeight.w800 : FontWeight.w700,
                color: emphasis ? crm.primary : crm.textPrimary)),
      ],
    );
  }
}

// ── Empty state ─────────────────────────────────────────────────────────────

class _AllStockedUp extends StatelessWidget {
  final int productCount;
  const _AllStockedUp({required this.productCount});

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return InvCard(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 44),
      child: Column(
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  crm.success.withValues(alpha: 0.22),
                  crm.success.withValues(alpha: 0.06),
                ],
              ),
            ),
            child: Icon(Icons.verified_rounded, size: 42, color: crm.success),
          ),
          18.h,
          Text('All stocked up',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: crm.textPrimary)),
          6.h,
          Text(
              productCount == 0
                  ? 'Add products to start tracking reorder levels.'
                  : 'All $productCount products are above their reorder level and no open tube is running dry.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: crm.textSecondary)),
          16.h,
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              invBadge('0 out of stock', crm.success),
              invBadge('0 low stock', crm.success),
              invBadge('0 tubes nearly empty', crm.success),
            ],
          ),
        ],
      ),
    );
  }
}
