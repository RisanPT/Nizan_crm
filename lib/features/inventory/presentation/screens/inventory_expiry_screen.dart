import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/extensions/space_extension.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/core/utils/responsive_builder.dart';
import 'package:nizan_crm/features/inventory/controllers/inventory_controller.dart';
import 'package:nizan_crm/features/inventory/data/inventory_product.dart';
import 'package:nizan_crm/features/inventory/presentation/widgets/inventory_dialogs.dart';
import 'package:nizan_crm/features/inventory/presentation/widgets/inventory_widgets.dart';

// ── Buckets ─────────────────────────────────────────────────────────────────

enum _Bucket { expired, thisMonth, next30, d60, d90, later }

const _bucketLabels = {
  _Bucket.expired: 'Expired',
  _Bucket.thisMonth: 'This month',
  _Bucket.next30: 'Next 30 days',
  _Bucket.d60: '31–60 days',
  _Bucket.d90: '61–90 days',
  _Bucket.later: 'Later',
};

const _bucketSubtitles = {
  _Bucket.expired: 'Past their expiry date — remove or replace',
  _Bucket.thisMonth: 'Expiring before the end of this month',
  _Bucket.next30: 'Expiring within the next 30 days',
  _Bucket.d60: 'Expiring in 31 to 60 days',
  _Bucket.d90: 'Expiring in 61 to 90 days',
  _Bucket.later: 'More than 90 days away',
};

_Bucket _bucketOf(InventoryProduct p, DateTime now) {
  final d = daysLeft(p.expiry) ?? 9999;
  final e = p.expiry!;
  if (d < 0) return _Bucket.expired;
  if (e.year == now.year && e.month == now.month) return _Bucket.thisMonth;
  if (d <= 30) return _Bucket.next30;
  if (d <= 60) return _Bucket.d60;
  if (d <= 90) return _Bucket.d90;
  return _Bucket.later;
}

Color _bucketColor(CrmTheme crm, _Bucket b) {
  switch (b) {
    case _Bucket.expired:
      return crm.destructive;
    case _Bucket.thisMonth:
    case _Bucket.next30:
      return crm.warning;
    case _Bucket.d60:
      return kLowStockColor;
    case _Bucket.d90:
      return const Color(0xFF9E2B43);
    case _Bucket.later:
      return crm.success;
  }
}

String _daysText(int d) {
  if (d < 0) {
    final n = -d;
    return 'Expired $n day${n == 1 ? '' : 's'} ago';
  }
  if (d == 0) return 'Expires today';
  return '$d day${d == 1 ? '' : 's'} left';
}

// ── Screen ──────────────────────────────────────────────────────────────────

class InventoryExpiryScreen extends ConsumerStatefulWidget {
  const InventoryExpiryScreen({super.key});

  @override
  ConsumerState<InventoryExpiryScreen> createState() =>
      _InventoryExpiryScreenState();
}

class _InventoryExpiryScreenState extends ConsumerState<InventoryExpiryScreen> {
  final _searchCtrl = TextEditingController();
  _Bucket? _filter; // null = all

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
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
          final now = DateTime.now();
          final tracked = products.where((p) => p.expiry != null).toList()
            ..sort((a, b) => a.expiry!.compareTo(b.expiry!));
          final noExpiry = products.length - tracked.length;
          final byBucket = {for (final b in _Bucket.values) b: <InventoryProduct>[]};
          for (final p in tracked) {
            byBucket[_bucketOf(p, now)]!.add(p);
          }
          int dl(InventoryProduct p) => daysLeft(p.expiry) ?? 9999;
          final expired = byBucket[_Bucket.expired]!.length;
          final within30 =
              tracked.where((p) => dl(p) >= 0 && dl(p) <= 30).length;
          final within60 = byBucket[_Bucket.d60]!.length;
          final within90 = byBucket[_Bucket.d90]!.length;
          final atRisk = tracked
              .where((p) => dl(p) <= 90)
              .fold<double>(0, (a, p) => a + p.quantity * p.price);

          final q = _searchCtrl.text.trim().toLowerCase();
          bool match(InventoryProduct p) =>
              q.isEmpty ||
              p.name.toLowerCase().contains(q) ||
              p.brand.toLowerCase().contains(q) ||
              p.shade.toLowerCase().contains(q) ||
              p.category.toLowerCase().contains(q);
          final visibleBuckets = _filter == null ? _Bucket.values : [_filter!];
          final sections = [
            for (final b in visibleBuckets)
              (b, byBucket[b]!.where(match).toList()),
          ].where((s) => s.$2.isNotEmpty).toList();

          void edit(InventoryProduct p) =>
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
                  title: 'Expiry Tracker',
                  subtitle:
                      'Shelf life across the studio · ${DateFormat('EEE, d MMM yyyy').format(now)}',
                  trailing: IconButton(
                    tooltip: 'Refresh',
                    icon: Icon(Icons.refresh_rounded, color: crm.textSecondary),
                    onPressed: _refresh,
                  ),
                ),
                16.h,
                InvKpiGrid(width: box.maxWidth, stats: [
                  InvKpi('$expired', 'Expired', 'past expiry date',
                      Icons.event_busy_outlined, crm.destructive),
                  InvKpi('$within30', 'Within 30 Days', 'use these first',
                      Icons.hourglass_bottom_rounded, crm.warning),
                  InvKpi('$within60', '31–60 Days', 'plan usage',
                      Icons.hourglass_top_rounded, kLowStockColor),
                  InvKpi('$within90', '61–90 Days', 'keep an eye on',
                      Icons.schedule_rounded, const Color(0xFF9E2B43)),
                  InvKpi(fmtINR(atRisk), 'Value at Risk',
                      'qty × price, expiring ≤ 90d',
                      Icons.currency_rupee_rounded, const Color(0xFF6E1423)),
                  InvKpi('${tracked.length}', 'Tracked',
                      noExpiry > 0 ? '$noExpiry without expiry date' : 'all products dated',
                      Icons.event_available_outlined, crm.primary),
                ]),
                16.h,
                if (tracked.isEmpty)
                  InvCard(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 36),
                      child: InvEmpty(
                        icon: Icons.event_available_outlined,
                        title: 'No expiry data yet',
                        subtitle: products.isEmpty
                            ? 'Add products to start tracking expiry.'
                            : 'Add expiry dates to your $noExpiry products to track them here.',
                      ),
                    ),
                  )
                else ...[
                  _ExpiryTimelineCard(products: tracked),
                  16.h,
                  _toolbar(crm, box.maxWidth < 700, byBucket, tracked.length),
                  if (noExpiry > 0) ...[
                    10.h,
                    Row(
                      children: [
                        Icon(Icons.info_outline_rounded,
                            size: 14, color: crm.textSecondary),
                        6.w,
                        Expanded(
                          child: Text(
                              '$noExpiry product${noExpiry == 1 ? ' has' : 's have'} no expiry date and ${noExpiry == 1 ? 'is' : 'are'} not tracked.',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 11.5, color: crm.textSecondary)),
                        ),
                      ],
                    ),
                  ],
                  14.h,
                  if (sections.isEmpty)
                    InvCard(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 28),
                        child: InvEmpty(
                          icon: q.isEmpty
                              ? Icons.event_available_outlined
                              : Icons.search_off_rounded,
                          title: q.isEmpty
                              ? 'Nothing in this range'
                              : 'No matching products',
                          subtitle: q.isEmpty
                              ? 'No products expire in the selected window.'
                              : 'Try a different search or filter.',
                        ),
                      ),
                    )
                  else
                    for (final s in sections) ...[
                      InvSectionHeader(
                        title: _bucketLabels[s.$1]!,
                        subtitle:
                            '${_bucketSubtitles[s.$1]!} · ${fmtINR(s.$2.fold<double>(0, (a, p) => a + p.quantity * p.price))} in stock',
                        count: s.$2.length,
                        badgeColor: _bucketColor(crm, s.$1),
                      ),
                      10.h,
                      _ExpiryGrid(
                        items: s.$2,
                        color: _bucketColor(crm, s.$1),
                        width: box.maxWidth,
                        onEdit: edit,
                      ),
                      20.h,
                    ],
                ],
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _toolbar(CrmTheme crm, bool compact,
      Map<_Bucket, List<InventoryProduct>> byBucket, int total) {
    final chips = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _BucketChip(
          label: 'All',
          count: total,
          color: crm.primary,
          selected: _filter == null,
          onTap: () => setState(() => _filter = null),
        ),
        for (final b in _Bucket.values)
          _BucketChip(
            label: _bucketLabels[b]!,
            count: byBucket[b]!.length,
            color: _bucketColor(crm, b),
            selected: _filter == b,
            onTap: () => setState(() => _filter = b),
          ),
      ],
    );
    final search = SizedBox(
      height: 40,
      width: compact ? double.infinity : 280,
      child: TextField(
        controller: _searchCtrl,
        onChanged: (_) => setState(() {}),
        style: TextStyle(fontSize: 13, color: crm.textPrimary),
        decoration: InputDecoration(
          isDense: true,
          hintText: 'Search products…',
          hintStyle: TextStyle(fontSize: 13, color: crm.textSecondary),
          prefixIcon:
              Icon(Icons.search_rounded, size: 18, color: crm.textSecondary),
          suffixIcon: _searchCtrl.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Clear',
                  icon: Icon(Icons.close_rounded,
                      size: 16, color: crm.textSecondary),
                  onPressed: () => setState(_searchCtrl.clear),
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
    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [search, 10.h, chips],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [Expanded(child: chips), 12.w, search],
    );
  }
}

class _BucketChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  const _BucketChip({
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

// ── Timeline chart (expired + next 12 months) ───────────────────────────────

class _ExpiryTimelineCard extends StatelessWidget {
  final List<InventoryProduct> products; // all have an expiry
  const _ExpiryTimelineCard({required this.products});

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final now = DateTime.now();
    final months = List.generate(12, (i) => DateTime(now.year, now.month + i));
    // Index 0 = expired, 1..12 = months starting with the current one.
    final counts = List<int>.filled(13, 0);
    final values = List<double>.filled(13, 0);
    var beyond = 0;
    for (final p in products) {
      final e = p.expiry!;
      int slot;
      if ((daysLeft(e) ?? 0) < 0) {
        slot = 0;
      } else {
        final diff = (e.year - now.year) * 12 + e.month - now.month;
        if (diff < 0) {
          slot = 0;
        } else if (diff >= 12) {
          beyond++;
          continue;
        } else {
          slot = diff + 1;
        }
      }
      counts[slot]++;
      values[slot] += p.quantity * p.price;
    }
    final maxC = counts.fold<int>(0, (a, v) => v > a ? v : a);
    final maxY = maxC <= 0 ? 4.0 : (maxC * 1.25).ceilToDouble();

    Color barColor(int i) {
      if (i == 0) return crm.destructive;
      if (i <= 1) return crm.warning;
      if (i <= 3) return kLowStockColor;
      return crm.primary.withValues(alpha: 0.55);
    }

    String label(int i) =>
        i == 0 ? 'Exp.' : DateFormat('MMM').format(months[i - 1]);

    return InvCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InvSectionHeader(
            title: 'Expiry Timeline',
            subtitle:
                'Products by month of expiry · next 12 months${beyond > 0 ? ' · $beyond later' : ''}',
          ),
          18.h,
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                maxY: maxY,
                alignment: BarChartAlignment.spaceAround,
                borderData: FlBorderData(show: false),
                gridData: FlGridData(
                  drawVerticalLine: false,
                  horizontalInterval: maxY / 4,
                  getDrawingHorizontalLine: (_) => FlLine(
                      color: crm.border.faded(0.5), strokeWidth: 1),
                ),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => Colors.black87,
                    getTooltipItem: (group, _, rod, _) {
                      final i = group.x;
                      return BarTooltipItem(
                        '${i == 0 ? 'Already expired' : DateFormat('MMMM yyyy').format(months[i - 1])}\n',
                        const TextStyle(color: Colors.white70, fontSize: 10.5),
                        children: [
                          TextSpan(
                            text:
                                '${counts[i]} product${counts[i] == 1 ? '' : 's'} · ${fmtINR(values[i])}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: maxY / 4,
                      getTitlesWidget: (v, meta) {
                        if (v == meta.max) return const SizedBox.shrink();
                        return Text(v.round().toString(),
                            style: TextStyle(
                                fontSize: 10, color: crm.textSecondary));
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 26,
                      getTitlesWidget: (v, meta) {
                        final i = v.toInt();
                        if (i < 0 || i > 12) return const SizedBox.shrink();
                        return SideTitleWidget(
                          meta: meta,
                          space: 6,
                          child: Text(label(i),
                              style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight:
                                      i <= 1 ? FontWeight.w700 : FontWeight.w500,
                                  color: i == 0
                                      ? crm.destructive
                                      : (i == 1
                                          ? crm.textPrimary
                                          : crm.textSecondary))),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: [
                  for (var i = 0; i < 13; i++)
                    BarChartGroupData(x: i, barRods: [
                      BarChartRodData(
                        toY: counts[i].toDouble(),
                        width: 14,
                        color: barColor(i),
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(5)),
                        backDrawRodData: BackgroundBarChartRodData(
                          show: true,
                          toY: maxY,
                          color: crm.input.withValues(alpha: 0.5),
                        ),
                      ),
                    ]),
                ],
              ),
            ),
          ),
          12.h,
          Wrap(
            spacing: 16,
            runSpacing: 6,
            children: [
              _legend(crm, crm.destructive, 'Expired'),
              _legend(crm, crm.warning, 'This month'),
              _legend(crm, kLowStockColor, 'Next 2 months'),
              _legend(crm, crm.primary.withValues(alpha: 0.55), 'Later'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legend(CrmTheme crm, Color c, String text) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                  color: c, borderRadius: BorderRadius.circular(3))),
          6.w,
          Text(text, style: TextStyle(fontSize: 11.5, color: crm.textSecondary)),
        ],
      );
}

// ── Item cards ──────────────────────────────────────────────────────────────

class _ExpiryGrid extends StatelessWidget {
  final List<InventoryProduct> items;
  final Color color;
  final double width;
  final void Function(InventoryProduct) onEdit;
  const _ExpiryGrid({
    required this.items,
    required this.color,
    required this.width,
    required this.onEdit,
  });

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
            child: _ExpiryCard(
                product: p, color: color, onEdit: () => onEdit(p)),
          ),
      ],
    );
  }
}

class _ExpiryCard extends StatelessWidget {
  final InventoryProduct product;
  final Color color;
  final VoidCallback onEdit;
  const _ExpiryCard(
      {required this.product, required this.color, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final p = product;
    final d = daysLeft(p.expiry) ?? 0;
    final expired = d < 0;
    final value = p.quantity * p.price;

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
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Icon(productIcon(p.category),
                          size: 19, color: color),
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
                                  fontSize: 13.5,
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
                  ],
                ),
                12.h,
                Row(
                  children: [
                    Icon(
                        expired
                            ? Icons.event_busy_outlined
                            : Icons.event_outlined,
                        size: 15,
                        color: color),
                    6.w,
                    Flexible(
                      child: Text(
                          DateFormat('d MMM yyyy').format(p.expiry!),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: crm.textPrimary)),
                    ),
                    8.w,
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: expired ? color : color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(_daysText(d),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: expired ? Colors.white : color)),
                      ),
                    ),
                  ],
                ),
                12.h,
                Row(
                  children: [
                    Expanded(
                      child: _MiniStat(
                          label: 'In stock',
                          value:
                              '${p.quantity} unit${p.quantity == 1 ? '' : 's'}'),
                    ),
                    Expanded(
                      child: _MiniStat(
                          label: 'Value at risk',
                          value: fmtINR(value),
                          color: value > 0 ? color : null),
                    ),
                    TextButton.icon(
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_outlined, size: 15),
                      label: const Text('Edit',
                          style: TextStyle(
                              fontSize: 12.5, fontWeight: FontWeight.w600)),
                      style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 10)),
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
  final Color? color;
  const _MiniStat({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 10.5, color: crm.textSecondary)),
        2.h,
        Text(value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: color ?? crm.textPrimary)),
      ],
    );
  }
}
