import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/extensions/space_extension.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/core/utils/responsive_builder.dart';
import 'package:nizan_crm/features/inventory/controllers/inventory_controller.dart';
import 'package:nizan_crm/features/inventory/data/purchase.dart';
import 'package:nizan_crm/features/inventory/presentation/widgets/inventory_widgets.dart';
import 'inventory_purchase_screen.dart';
import 'package:nizan_crm/core/state/data_refresh.dart';

// ── Helpers ─────────────────────────────────────────────────────────────────

enum _StatusFilter { all, paid, partial, unpaid, overdue }

extension on _StatusFilter {
  String get label => switch (this) {
        _StatusFilter.all => 'All',
        _StatusFilter.paid => 'Paid',
        _StatusFilter.partial => 'Partial',
        _StatusFilter.unpaid => 'Unpaid',
        _StatusFilter.overdue => 'Overdue',
      };

  bool matches(Purchase p) => switch (this) {
        _StatusFilter.all => true,
        _StatusFilter.paid => p.status == 'paid',
        _StatusFilter.partial => p.status == 'partial',
        _StatusFilter.unpaid => p.status == 'unpaid',
        _StatusFilter.overdue => p.isOverdue,
      };
}

String _vendorName(Purchase p) =>
    p.supplier.trim().isEmpty ? 'No supplier' : p.supplier.trim();

String _initials(String name) {
  final parts =
      name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) {
    return parts.first.substring(0, parts.first.length >= 2 ? 2 : 1).toUpperCase();
  }
  return (parts[0][0] + parts[1][0]).toUpperCase();
}

const _avatarPalette = [
  Color(0xFF800020),
  Color(0xFF9E2B43),
  Color(0xFF6E1423),
  Color(0xFFBC4E64),
  Color(0xFF5C1120),
  Color(0xFFAD3A53),
  Color(0xFF8F1D33),
  Color(0xFFC96578),
];

Color _vendorColor(String name) {
  var h = 0;
  for (final c in name.toLowerCase().codeUnits) {
    h = (h * 31 + c) & 0x7fffffff;
  }
  return _avatarPalette[h % _avatarPalette.length];
}

String _compact(double v) {
  if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
  if (v >= 1000) return '${(v / 1000).toStringAsFixed(v >= 10000 ? 0 : 1)}k';
  return v.toStringAsFixed(0);
}

String _fmtDate(DateTime d) => DateFormat('d MMM yyyy').format(d);

Color _statusColor(CrmTheme crm, Purchase p) {
  if (p.isFullyPaid) return crm.success;
  if (p.isOverdue) return crm.destructive;
  if (p.isPartiallyPaid) return crm.accent;
  return crm.warning;
}

String _statusLabel(Purchase p) {
  if (p.isFullyPaid) return 'PAID';
  if (p.isOverdue) return 'OVERDUE';
  if (p.isPartiallyPaid) return 'PARTIAL';
  return 'UNPAID';
}

class _VendorAvatar extends StatelessWidget {
  final String name;
  final double size;
  const _VendorAvatar({required this.name, this.size = 42});

  @override
  Widget build(BuildContext context) {
    final c = _vendorColor(name);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(size * 0.3),
        border: Border.all(color: c.withValues(alpha: 0.25)),
      ),
      child: Text(_initials(name),
          style: TextStyle(
              fontSize: size * 0.34, fontWeight: FontWeight.w800, color: c)),
    );
  }
}

// ── Screen ──────────────────────────────────────────────────────────────────

/// Purchases — vendor bills with spend analytics, payment status and quick
/// actions (record payment, mark paid, edit billing / GST, delete).
class InventoryPurchasesScreen extends ConsumerStatefulWidget {
  const InventoryPurchasesScreen({super.key});

  @override
  ConsumerState<InventoryPurchasesScreen> createState() =>
      _InventoryPurchasesScreenState();
}

class _InventoryPurchasesScreenState
    extends ConsumerState<InventoryPurchasesScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  _StatusFilter _filter = _StatusFilter.all;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _newPurchase() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const InventoryPurchaseScreen()),
    );
  }

  bool _matchesQuery(Purchase p) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return true;
    if (p.supplier.toLowerCase().contains(q)) return true;
    if (p.invoiceNo.toLowerCase().contains(q)) return true;
    return p.items.any((i) =>
        i.name.toLowerCase().contains(q) || i.brand.toLowerCase().contains(q));
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final isMobile = ResponsiveBuilder.isMobile(context);
    final async = ref.watch(purchasesProvider);

    return InvBody(
      isMobile: isMobile,
      child: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => AppErrorView(
            error: e, onRetry: () => ref.invalidate(purchasesProvider)),
        data: (purchases) => LayoutBuilder(builder: (context, box) {
          final width = box.maxWidth;
          final stacked = width < 860;
          final now = DateTime.now();
          final monthStart = DateTime(now.year, now.month);
          final lastMonthStart = DateTime(now.year, now.month - 1);

          // ── Derived metrics ──
          bool inMonth(DateTime d, DateTime m) =>
              d.year == m.year && d.month == m.month;
          final thisMonth =
              purchases.where((p) => inMonth(p.date, monthStart)).toList();
          final lastMonth =
              purchases.where((p) => inMonth(p.date, lastMonthStart)).toList();
          final monthSpend =
              thisMonth.fold<double>(0, (a, p) => a + p.grandTotal);
          final lastMonthSpend =
              lastMonth.fold<double>(0, (a, p) => a + p.grandTotal);
          final allSpend =
              purchases.fold<double>(0, (a, p) => a + p.grandTotal);
          final paidTotal =
              purchases.fold<double>(0, (a, p) => a + p.paidAmount);
          final outstanding =
              purchases.fold<double>(0, (a, p) => a + p.balance);
          final openBills = purchases.where((p) => p.balance > 0.01).length;
          final overdue = purchases.where((p) => p.isOverdue).toList();
          final overdueAmt = overdue.fold<double>(0, (a, p) => a + p.balance);
          final gstMonth = thisMonth.fold<double>(0, (a, p) => a + p.gstAmount);
          final gstAll = purchases.fold<double>(0, (a, p) => a + p.gstAmount);
          final units = purchases.fold<int>(0, (a, p) => a + p.unitCount);
          final vendorCount =
              purchases.map((p) => _vendorName(p).toLowerCase()).toSet().length;

          String trend() {
            if (lastMonthSpend <= 0) {
              return '${thisMonth.length} bill${thisMonth.length == 1 ? '' : 's'} this month';
            }
            final pct = ((monthSpend - lastMonthSpend) / lastMonthSpend * 100)
                .round();
            return '${pct >= 0 ? '+' : ''}$pct% vs last month';
          }

          final counts = {
            for (final f in _StatusFilter.values)
              f: purchases.where(f.matches).length,
          };
          final filtered = purchases
              .where((p) => _filter.matches(p) && _matchesQuery(p))
              .toList();
          final filteredTotal =
              filtered.fold<double>(0, (a, p) => a + p.grandTotal);

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(purchasesProvider);
              try {
                await ref.read(purchasesProvider.future);
              } catch (_) {
                // Failure is shown by the screen's error state; don't throw from pull-to-refresh.
              }
            },
            child: ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                InvHeader(
                  title: 'Purchases',
                  subtitle:
                      'Vendor bills, spend & payables · ${purchases.length} bill${purchases.length == 1 ? '' : 's'}',
                  actionLabel: isMobile ? 'New' : 'New Purchase',
                  actionIcon: Icons.add_shopping_cart_outlined,
                  onAction: _newPurchase,
                  trailing: IconButton(
                    tooltip: 'Refresh',
                    icon: Icon(Icons.refresh_rounded, color: crm.textSecondary),
                    onPressed: () => ref.invalidate(purchasesProvider),
                  ),
                ),
                16.h,
                InvKpiGrid(width: width, stats: [
                  InvKpi(fmtINR(monthSpend), 'Spend This Month', trend(),
                      Icons.calendar_month_outlined, crm.primary),
                  InvKpi(fmtINR(allSpend), 'All-time Spend',
                      'incl. GST · ${purchases.length} bills',
                      Icons.summarize_outlined, const Color(0xFF6E1423)),
                  InvKpi(fmtINR(outstanding), 'Outstanding',
                      '$openBills bill${openBills == 1 ? '' : 's'} to settle',
                      Icons.pending_actions_outlined, crm.warning),
                  InvKpi(
                      '${overdue.length}',
                      'Overdue Bills',
                      overdue.isEmpty
                          ? 'nothing past due'
                          : '${fmtINR(overdueAmt)} past due',
                      Icons.warning_amber_rounded,
                      crm.destructive),
                  InvKpi(fmtINR(paidTotal), 'Paid to Vendors',
                      allSpend <= 0
                          ? 'no bills yet'
                          : '${(paidTotal / allSpend * 100).round()}% of spend settled',
                      Icons.check_circle_outline_rounded, crm.success),
                  InvKpi('${purchases.length}', 'Bills Recorded',
                      '$units units purchased', Icons.receipt_long_outlined,
                      crm.accent),
                  InvKpi(fmtINR(gstMonth), 'GST Input This Month',
                      '${fmtINR(gstAll)} all-time', Icons.account_balance_outlined,
                      const Color(0xFF9E2B43)),
                  InvKpi('$vendorCount', 'Vendors', 'suppliers billed',
                      Icons.storefront_outlined, kLowStockColor),
                ]),
                16.h,
                invPair(
                  stacked,
                  _SpendChartCard(purchases: purchases),
                  _TopVendorsCard(purchases: purchases),
                  flexA: 3,
                  flexB: 2,
                ),
                16.h,
                InvCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      InvSectionHeader(
                        title: 'Bills',
                        count: filtered.length,
                        subtitle: filtered.isEmpty
                            ? 'No bills match'
                            : '${fmtINR(filteredTotal)} across ${filtered.length} bill${filtered.length == 1 ? '' : 's'}',
                      ),
                      14.h,
                      _filtersBar(crm, counts, stacked),
                      16.h,
                      if (purchases.isEmpty)
                        const SizedBox(
                          height: 260,
                          child: InvEmpty(
                              icon: Icons.receipt_long_outlined,
                              title: 'No purchases yet',
                              subtitle:
                                  'Record a purchase to start your buying ledger.'),
                        )
                      else if (filtered.isEmpty)
                        const SizedBox(
                          height: 200,
                          child: InvEmpty(
                              icon: Icons.search_off_rounded,
                              title: 'No matching bills',
                              subtitle:
                                  'Try another status or search term.'),
                        )
                      else
                        _billsGrid(crm, filtered, width - 32),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  // ── Filters ───────────────────────────────────────────────────────────────

  Widget _filtersBar(
      CrmTheme crm, Map<_StatusFilter, int> counts, bool stacked) {
    final chips = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final f in _StatusFilter.values)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _filterChip(crm, f, counts[f] ?? 0),
            ),
        ],
      ),
    );
    final search = SizedBox(
      height: 42,
      child: TextField(
        controller: _searchCtrl,
        onChanged: (v) => setState(() => _query = v),
        style: const TextStyle(fontSize: 13.5),
        decoration: InputDecoration(
          isDense: true,
          hintText: 'Search vendor, invoice or item',
          prefixIcon: const Icon(Icons.search_rounded, size: 20),
          suffixIcon: _query.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: () => setState(() {
                    _searchCtrl.clear();
                    _query = '';
                  }),
                ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
    if (stacked) {
      return Column(children: [search, 12.h, chips]);
    }
    return Row(
      children: [
        Expanded(child: chips),
        16.w,
        SizedBox(width: 300, child: search),
      ],
    );
  }

  Widget _filterChip(CrmTheme crm, _StatusFilter f, int count) {
    final selected = _filter == f;
    final color = switch (f) {
      _StatusFilter.all => crm.primary,
      _StatusFilter.paid => crm.success,
      _StatusFilter.partial => crm.accent,
      _StatusFilter.unpaid => crm.warning,
      _StatusFilter.overdue => crm.destructive,
    };
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => setState(() => _filter = f),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.12) : crm.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? color.withValues(alpha: 0.6) : crm.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (f != _StatusFilter.all) ...[
              Container(
                  width: 8,
                  height: 8,
                  decoration:
                      BoxDecoration(color: color, shape: BoxShape.circle)),
              6.w,
            ],
            Text(f.label,
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: selected ? color : crm.textPrimary)),
            6.w,
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: selected
                    ? color.withValues(alpha: 0.18)
                    : crm.input.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('$count',
                  style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: selected ? color : crm.textSecondary)),
            ),
          ],
        ),
      ),
    );
  }

  // ── Bills ─────────────────────────────────────────────────────────────────

  Widget _billsGrid(CrmTheme crm, List<Purchase> bills, double width) {
    final cols = width >= 1100 ? 3 : (width >= 640 ? 2 : 1);
    const gap = 12.0;
    final w = (width - gap * (cols - 1)) / cols;
    if (cols == 1) {
      return Column(
        children: [
          for (final b in bills)
            Padding(
              padding: const EdgeInsets.only(bottom: gap),
              child: _billCard(crm, b),
            ),
        ],
      );
    }
    return Wrap(
      spacing: gap,
      runSpacing: gap,
      children: [
        for (final b in bills) SizedBox(width: w, child: _billCard(crm, b)),
      ],
    );
  }

  Widget _billCard(CrmTheme crm, Purchase p) {
    final vendor = _vendorName(p);
    final color = _statusColor(crm, p);
    final frac = p.grandTotal <= 0
        ? (p.isFullyPaid ? 1.0 : 0.0)
        : (p.paidAmount / p.grandTotal).clamp(0.0, 1.0);
    final expenseLines = p.items.where((i) => !i.stockIn).length;
    final due = p.dueDate;

    return Material(
      color: crm.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _showDetails(crm, p),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 8, 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: p.isOverdue
                    ? crm.destructive.withValues(alpha: 0.4)
                    : crm.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Vendor row ──
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Row(
                  children: [
                    _VendorAvatar(name: vendor),
                    12.w,
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(vendor,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: crm.textPrimary)),
                          2.h,
                          Text(
                              '${p.invoiceNo.isEmpty ? 'No invoice #' : '#${p.invoiceNo}'} · ${_fmtDate(p.date)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 11.5, color: crm.textSecondary)),
                        ],
                      ),
                    ),
                    8.w,
                    invBadge(_statusLabel(p), color),
                  ],
                ),
              ),
              12.h,
              // ── Meta chips ──
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _metaChip(crm, Icons.inventory_2_outlined,
                        '${p.items.length} item${p.items.length == 1 ? '' : 's'} · ${p.unitCount} unit${p.unitCount == 1 ? '' : 's'}'),
                    if (p.gstEnabled)
                      _metaChip(crm, Icons.percent_rounded,
                          'GST ${p.gstRate.toStringAsFixed(p.gstRate % 1 == 0 ? 0 : 1)}% · ${p.interState ? 'IGST' : 'CGST+SGST'}'),
                    if (expenseLines > 0)
                      _metaChip(crm, Icons.receipt_outlined,
                          '$expenseLines expense'),
                    if (p.billImage.isNotEmpty)
                      _metaChip(crm, Icons.attach_file_rounded, 'Bill'),
                  ],
                ),
              ),
              14.h,
              // ── Amounts ──
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Grand total',
                              style: TextStyle(
                                  fontSize: 11, color: crm.textSecondary)),
                          2.h,
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(fmtINR(p.grandTotal),
                                style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: crm.textPrimary,
                                    height: 1.1)),
                          ),
                        ],
                      ),
                    ),
                    8.w,
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Balance',
                            style: TextStyle(
                                fontSize: 11, color: crm.textSecondary)),
                        2.h,
                        Text(fmtINR(p.balance),
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: p.balance > 0.01
                                    ? (p.isOverdue
                                        ? crm.destructive
                                        : crm.warning)
                                    : crm.success)),
                      ],
                    ),
                  ],
                ),
              ),
              10.h,
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Stack(
                    children: [
                      Container(height: 7, color: crm.input),
                      FractionallySizedBox(
                        widthFactor: frac,
                        child: Container(
                          height: 7,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [
                              crm.success.withValues(alpha: 0.7),
                              crm.success,
                            ]),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              6.h,
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                          'Paid ${fmtINR(p.paidAmount)} · ${(frac * 100).round()}%',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 11, color: crm.textSecondary)),
                    ),
                    Icon(Icons.event_outlined,
                        size: 13,
                        color: p.isOverdue
                            ? crm.destructive
                            : crm.textSecondary),
                    4.w,
                    Text(
                        due == null
                            ? 'No due date'
                            : (p.isOverdue
                                ? 'Overdue · ${DateFormat('d MMM').format(due)}'
                                : 'Due ${DateFormat('d MMM').format(due)}'),
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight:
                                p.isOverdue ? FontWeight.w700 : FontWeight.w500,
                            color: p.isOverdue
                                ? crm.destructive
                                : crm.textSecondary)),
                  ],
                ),
              ),
              6.h,
              Divider(height: 1, color: crm.border),
              4.h,
              // ── Quick actions ──
              Row(
                children: [
                  if (!p.isFullyPaid) ...[
                    Flexible(
                      child: TextButton.icon(
                        onPressed: () => _recordPayment(crm, p),
                        style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding:
                                const EdgeInsets.symmetric(horizontal: 8)),
                        icon: const Icon(Icons.payments_outlined, size: 16),
                        label: const Text('Pay',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12.5)),
                      ),
                    ),
                    Flexible(
                      child: TextButton.icon(
                        onPressed: () => _setPaid(p, true),
                        style: TextButton.styleFrom(
                            foregroundColor: crm.success,
                            visualDensity: VisualDensity.compact,
                            padding:
                                const EdgeInsets.symmetric(horizontal: 8)),
                        icon: const Icon(Icons.done_all_rounded, size: 16),
                        label: const Text('Mark paid',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12.5)),
                      ),
                    ),
                  ] else
                    Flexible(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.verified_outlined,
                                size: 15, color: crm.success),
                            6.w,
                            Flexible(
                              child: Text('Settled',
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                      color: crm.success)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const Spacer(),
                  if (p.billImage.isNotEmpty)
                    IconButton(
                      icon: Icon(Icons.receipt_long, size: 18,
                          color: crm.primary),
                      tooltip: 'View bill',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _viewBill(crm, p.billImage),
                    ),
                  _menu(crm, p),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metaChip(CrmTheme crm, IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: crm.input.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: crm.textSecondary),
          4.w,
          Text(text,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: crm.textSecondary)),
        ],
      ),
    );
  }

  Widget _menu(CrmTheme crm, Purchase p) {
    Widget item(IconData icon, String text, {Color? color}) => Row(children: [
          Icon(icon, size: 16, color: color ?? crm.textSecondary),
          const SizedBox(width: 8),
          Text(text, style: TextStyle(color: color)),
        ]);
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert, size: 18, color: crm.textSecondary),
      tooltip: 'More',
      onSelected: (v) {
        switch (v) {
          case 'details':
            _showDetails(crm, p);
          case 'pay':
            _recordPayment(crm, p);
          case 'paid':
            _setPaid(p, true);
          case 'unpaid':
            _setPaid(p, false);
          case 'edit':
            _editBilling(crm, p);
          case 'bill':
            _viewBill(crm, p.billImage);
          case 'delete':
            _confirmDeletePurchase(crm, p);
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(
            value: 'details', child: item(Icons.visibility_outlined, 'View details')),
        if (!p.isFullyPaid) ...[
          PopupMenuItem(
              value: 'pay', child: item(Icons.payments_outlined, 'Record payment')),
          PopupMenuItem(
              value: 'paid', child: item(Icons.done_all_rounded, 'Mark paid')),
        ] else
          PopupMenuItem(value: 'unpaid', child: item(Icons.undo, 'Mark unpaid')),
        PopupMenuItem(
            value: 'edit', child: item(Icons.edit_outlined, 'Edit billing / GST')),
        if (p.billImage.isNotEmpty)
          PopupMenuItem(
              value: 'bill', child: item(Icons.receipt_long, 'View bill')),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'delete',
          child: item(Icons.delete_outline, 'Delete purchase',
              color: crm.destructive),
        ),
      ],
    );
  }

  // ── Details sheet ─────────────────────────────────────────────────────────

  void _showDetails(CrmTheme crm, Purchase p) {
    final vendor = _vendorName(p);
    Widget row(String label, String value,
            {Color? color, bool bold = false}) =>
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            children: [
              Expanded(
                child: Text(label,
                    style: TextStyle(fontSize: 13, color: crm.textSecondary)),
              ),
              Text(value,
                  style: TextStyle(
                      fontSize: bold ? 15 : 13,
                      fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                      color: color ?? crm.textPrimary)),
            ],
          ),
        );

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 680),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        builder: (ctx, scroll) => ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: [
            Row(
              children: [
                _VendorAvatar(name: vendor, size: 46),
                12.w,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(vendor,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: crm.textPrimary)),
                      2.h,
                      Text(
                          '${p.invoiceNo.isEmpty ? 'No invoice #' : '#${p.invoiceNo}'} · ${_fmtDate(p.date)}',
                          style: TextStyle(
                              fontSize: 12, color: crm.textSecondary)),
                    ],
                  ),
                ),
                invBadge(_statusLabel(p), _statusColor(crm, p)),
              ],
            ),
            16.h,
            Text('LINE ITEMS',
                style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 0.6,
                    fontWeight: FontWeight.w800,
                    color: crm.textSecondary)),
            8.h,
            for (final it in p.items)
              Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: crm.input.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                          color:
                              categoryColor(it.category).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(9)),
                      child: Icon(productIcon(it.category),
                          size: 16, color: categoryColor(it.category)),
                    ),
                    10.w,
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              it.shade.isNotEmpty && it.shade != '—'
                                  ? '${it.name} · ${it.shade}'
                                  : it.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w600)),
                          Text(
                              '${it.category}${it.stockIn ? '' : ' · expense'} · ${it.quantity} × ${fmtINR(it.unitCost)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 11, color: crm.textSecondary)),
                        ],
                      ),
                    ),
                    8.w,
                    Text(fmtINR(it.subtotal),
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
            12.h,
            row('Taxable value', fmtINR(p.total)),
            if (p.gstEnabled || p.gstAmount > 0) ...[
              if (p.interState)
                row('IGST @ ${p.gstRate.toStringAsFixed(p.gstRate % 1 == 0 ? 0 : 1)}%',
                    fmtINR(p.igst))
              else ...[
                row('CGST', fmtINR(p.cgst)),
                row('SGST', fmtINR(p.sgst)),
              ],
              if (p.gstin.isNotEmpty) row('Vendor GSTIN', p.gstin),
            ],
            Divider(color: crm.border),
            row('Grand total', fmtINR(p.grandTotal), bold: true),
            row('Paid', fmtINR(p.paidAmount), color: crm.success),
            row('Balance', fmtINR(p.balance),
                color: p.balance > 0.01 ? crm.warning : crm.success,
                bold: true),
            if (p.dueDate != null)
              row('Due date', _fmtDate(p.dueDate!),
                  color: p.isOverdue ? crm.destructive : null),
            if (p.payments.isNotEmpty) ...[
              14.h,
              Text('PAYMENTS',
                  style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 0.6,
                      fontWeight: FontWeight.w800,
                      color: crm.textSecondary)),
              6.h,
              for (final pay in p.payments)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle_outline,
                          size: 16, color: crm.success),
                      8.w,
                      Expanded(
                        child: Text(
                            '${_fmtDate(pay.date)} · ${pay.mode.replaceAll('_', ' ')}${pay.note.isEmpty ? '' : ' · ${pay.note}'}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 12.5, color: crm.textSecondary)),
                      ),
                      Text(fmtINR(pay.amount),
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
            ],
            if (p.notes.isNotEmpty) ...[
              14.h,
              Text('NOTES',
                  style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 0.6,
                      fontWeight: FontWeight.w800,
                      color: crm.textSecondary)),
              6.h,
              Text(p.notes, style: const TextStyle(fontSize: 13)),
            ],
            18.h,
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                if (p.billImage.isNotEmpty)
                  OutlinedButton.icon(
                    onPressed: () => _viewBill(crm, p.billImage),
                    icon: const Icon(Icons.receipt_long, size: 18),
                    label: const Text('View bill'),
                  ),
                if (!p.isFullyPaid)
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _recordPayment(crm, p);
                    },
                    icon: const Icon(Icons.payments_outlined, size: 18),
                    label: const Text('Record payment'),
                  ),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _editBilling(crm, p);
                  },
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Edit billing / GST'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> _setPaid(Purchase p, bool paid) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(inventoryServiceProvider).setPurchasePaid(p.id, paid);
      ref.refreshData.purchases();
      messenger.showSnackBar(
          SnackBar(content: Text(paid ? 'Marked paid' : 'Marked unpaid')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
    }
  }

  Future<void> _recordPayment(CrmTheme crm, Purchase b) async {
    final amountCtrl =
        TextEditingController(text: b.balance.toStringAsFixed(0));
    final noteCtrl = TextEditingController();
    var mode = 'cash';
    var payDate = DateTime.now();
    var saving = false;

    await showDialog<void>(
      context: context,
      builder: (dctx) => StatefulBuilder(
        builder: (dctx, setLocal) {
          Future<void> submit() async {
            final amount = double.tryParse(amountCtrl.text.trim()) ?? 0;
            if (amount <= 0) return;
            setLocal(() => saving = true);
            final messenger = ScaffoldMessenger.of(context);
            try {
              await ref.read(inventoryServiceProvider).recordPurchasePayment(
                    b.id,
                    amount: amount,
                    date: payDate,
                    mode: mode,
                    note: noteCtrl.text.trim(),
                  );
              ref.refreshData.purchases();
              if (dctx.mounted) Navigator.pop(dctx);
              messenger.showSnackBar(
                  const SnackBar(content: Text('Payment recorded')));
            } catch (e) {
              setLocal(() => saving = false);
              messenger.showSnackBar(
                  SnackBar(content: Text(friendlyErrorMessage(e))));
            }
          }

          return AlertDialog(
            title: const Text('Record payment'),
            content: SizedBox(
              width: 380,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: crm.warning.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: crm.warning.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(_vendorName(b),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 13, color: crm.textSecondary)),
                          ),
                          Text('Balance ${fmtINR(b.balance)}',
                              style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: crm.warning)),
                        ],
                      ),
                    ),
                    12.h,
                    TextField(
                      controller: amountCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                          labelText: 'Amount',
                          prefixText: '₹ ',
                          isDense: true,
                          border: OutlineInputBorder()),
                    ),
                    12.h,
                    DropdownButtonFormField<String>(
                      initialValue: mode,
                      decoration: const InputDecoration(
                          labelText: 'Payment mode',
                          isDense: true,
                          border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: 'cash', child: Text('Cash')),
                        DropdownMenuItem(value: 'upi', child: Text('UPI')),
                        DropdownMenuItem(
                            value: 'bank_transfer',
                            child: Text('Bank transfer')),
                        DropdownMenuItem(
                            value: 'cheque', child: Text('Cheque')),
                        DropdownMenuItem(value: 'card', child: Text('Card')),
                        DropdownMenuItem(value: 'other', child: Text('Other')),
                      ],
                      onChanged: (v) => setLocal(() => mode = v ?? 'cash'),
                    ),
                    12.h,
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: dctx,
                          initialDate: payDate,
                          firstDate: DateTime(2020),
                          lastDate:
                              DateTime.now().add(const Duration(days: 1)),
                        );
                        if (picked != null) setLocal(() => payDate = picked);
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                            labelText: 'Payment date',
                            isDense: true,
                            border: OutlineInputBorder()),
                        child: Text(_fmtDate(payDate)),
                      ),
                    ),
                    12.h,
                    TextField(
                      controller: noteCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Note (optional)',
                          isDense: true,
                          border: OutlineInputBorder()),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                  onPressed: saving ? null : () => Navigator.pop(dctx),
                  child: const Text('Cancel')),
              FilledButton(
                onPressed: saving ? null : submit,
                child: saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Save payment'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _editBilling(CrmTheme crm, Purchase b) async {
    final invoiceCtrl = TextEditingController(text: b.invoiceNo);
    final gstinCtrl = TextEditingController(text: b.gstin);
    var gstEnabled = b.gstEnabled;
    var interState = b.interState;
    var gstRate = b.gstRate;
    DateTime? dueDate = b.dueDate;
    var saving = false;

    double gstAmountFor(double rate) => b.total * rate / 100;

    await showDialog<void>(
      context: context,
      builder: (dctx) => StatefulBuilder(
        builder: (dctx, setLocal) {
          final gstAmount = gstEnabled ? gstAmountFor(gstRate) : 0.0;
          Future<void> submit() async {
            setLocal(() => saving = true);
            final messenger = ScaffoldMessenger.of(context);
            try {
              await ref.read(inventoryServiceProvider).updatePurchaseBilling(
                    b.id,
                    invoiceNo: invoiceCtrl.text.trim(),
                    dueDate: dueDate,
                    gstEnabled: gstEnabled,
                    gstin: gstinCtrl.text.trim(),
                    gstRate: gstEnabled ? gstRate : 0,
                    gstAmount: gstEnabled ? gstAmountFor(gstRate) : 0,
                    interState: interState,
                  );
              ref.refreshData.purchases();
              if (dctx.mounted) Navigator.pop(dctx);
              messenger
                  .showSnackBar(const SnackBar(content: Text('Bill updated')));
            } catch (e) {
              setLocal(() => saving = false);
              messenger.showSnackBar(
                  SnackBar(content: Text(friendlyErrorMessage(e))));
            }
          }

          return AlertDialog(
            title: const Text('Edit billing / GST'),
            content: SizedBox(
              width: 400,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Taxable value: ${fmtINR(b.total)}',
                        style: TextStyle(color: crm.textSecondary)),
                    12.h,
                    TextField(
                      controller: invoiceCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Invoice no',
                          isDense: true,
                          border: OutlineInputBorder()),
                    ),
                    12.h,
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: dctx,
                          initialDate: dueDate ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) setLocal(() => dueDate = picked);
                      },
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Due date',
                          isDense: true,
                          border: const OutlineInputBorder(),
                          suffixIcon: dueDate == null
                              ? null
                              : IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () =>
                                      setLocal(() => dueDate = null),
                                ),
                        ),
                        child: Text(
                            dueDate == null ? 'Not set' : _fmtDate(dueDate!)),
                      ),
                    ),
                    8.h,
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: const Text('This is a GST bill'),
                      value: gstEnabled,
                      onChanged: (v) => setLocal(() => gstEnabled = v),
                    ),
                    if (gstEnabled) ...[
                      TextField(
                        controller: gstinCtrl,
                        decoration: const InputDecoration(
                            labelText: 'Vendor GSTIN',
                            isDense: true,
                            border: OutlineInputBorder()),
                      ),
                      12.h,
                      DropdownButtonFormField<double>(
                        initialValue:
                            const [0.0, 5, 12, 18, 28].contains(gstRate)
                                ? gstRate
                                : 18.0,
                        decoration: const InputDecoration(
                            labelText: 'GST rate',
                            isDense: true,
                            border: OutlineInputBorder()),
                        items: const [
                          DropdownMenuItem(value: 0.0, child: Text('0%')),
                          DropdownMenuItem(value: 5.0, child: Text('5%')),
                          DropdownMenuItem(value: 12.0, child: Text('12%')),
                          DropdownMenuItem(value: 18.0, child: Text('18%')),
                          DropdownMenuItem(value: 28.0, child: Text('28%')),
                        ],
                        onChanged: (v) =>
                            setLocal(() => gstRate = v ?? gstRate),
                      ),
                      8.h,
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: const Text('Inter-state (IGST)'),
                        subtitle: Text(interState
                            ? 'IGST applied'
                            : 'CGST + SGST applied'),
                        value: interState,
                        onChanged: (v) => setLocal(() => interState = v),
                      ),
                      8.h,
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: crm.input,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('GST ${fmtINR(gstAmount)}',
                                style: TextStyle(
                                    color: crm.textSecondary, fontSize: 13)),
                            Text('Total ${fmtINR(b.total + gstAmount)}',
                                style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: crm.textPrimary)),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                  onPressed: saving ? null : () => Navigator.pop(dctx),
                  child: const Text('Cancel')),
              FilledButton(
                onPressed: saving ? null : submit,
                child: saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _confirmDeletePurchase(CrmTheme crm, Purchase p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete purchase?'),
        content: Text(
            'Remove this purchase${p.supplier.isNotEmpty ? ' from ${p.supplier}' : ''} '
            '(${p.items.length} item${p.items.length == 1 ? '' : 's'} · ${fmtINR(p.total)})?\n\n'
            'Stock already added is not reversed.'),
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
    if (ok != true) return;
    try {
      await ref.read(inventoryServiceProvider).deletePurchase(p.id);
      ref.refreshData.purchases();
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, e);
      }
    }
  }

  void _viewBill(CrmTheme crm, String url) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
              child: Row(
                children: [
                  Icon(Icons.receipt_long, color: crm.primary),
                  8.w,
                  const Expanded(
                      child: Text('Supplier Bill',
                          style: TextStyle(fontWeight: FontWeight.bold))),
                  IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx)),
                ],
              ),
            ),
            Flexible(
              child: InteractiveViewer(
                child: Image.network(url,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => Padding(
                          padding: const EdgeInsets.all(40),
                          child: Text('Could not load bill image',
                              style: TextStyle(color: crm.textSecondary)),
                        )),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 6-month spend chart ─────────────────────────────────────────────────────

class _SpendChartCard extends StatelessWidget {
  final List<Purchase> purchases;
  const _SpendChartCard({required this.purchases});

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final now = DateTime.now();
    final months =
        List.generate(6, (i) => DateTime(now.year, now.month - 5 + i));
    int idx(DateTime d) =>
        months.indexWhere((m) => m.year == d.year && m.month == d.month);

    final values = List<double>.filled(6, 0);
    final paid = List<double>.filled(6, 0);
    for (final p in purchases) {
      final i = idx(p.date);
      if (i >= 0) {
        values[i] += p.grandTotal;
        paid[i] += p.paidAmount.clamp(0, p.grandTotal).toDouble();
      }
    }
    final maxV = values.fold<double>(0, (a, v) => v > a ? v : a);
    final maxY = maxV <= 0 ? 4.0 : maxV * 1.25;
    final total = values.fold<double>(0, (a, v) => a + v);
    final avg = total / 6;
    final color = crm.accent;

    Widget legend(Color c, String t) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                    color: c, borderRadius: BorderRadius.circular(3))),
            6.w,
            Text(t, style: TextStyle(fontSize: 11.5, color: crm.textSecondary)),
          ],
        );

    return InvCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InvSectionHeader(
            title: 'Purchase Spend',
            subtitle:
                'Last 6 months · ${fmtINR(total)} total · ${fmtINR(avg)}/mo avg',
          ),
          10.h,
          Wrap(spacing: 16, runSpacing: 6, children: [
            legend(crm.success, 'Paid'),
            legend(color.withValues(alpha: 0.55), 'Outstanding'),
          ]),
          14.h,
          SizedBox(
            height: 210,
            child: BarChart(
              BarChartData(
                maxY: maxY,
                alignment: BarChartAlignment.spaceAround,
                borderData: FlBorderData(show: false),
                gridData: FlGridData(
                  drawVerticalLine: false,
                  horizontalInterval: maxY / 4,
                  getDrawingHorizontalLine: (_) => FlLine(
                      color: crm.border.faded(0.5),
                      strokeWidth: 1),
                ),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => Colors.black87,
                    getTooltipItem: (group, _, rod, _) => BarTooltipItem(
                      '${DateFormat('MMM yyyy').format(months[group.x])}\n',
                      const TextStyle(color: Colors.white70, fontSize: 10.5),
                      children: [
                        TextSpan(
                          text: fmtINR(rod.toY),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold),
                        ),
                        TextSpan(
                          text: '\npaid ${fmtINR(paid[group.x])}',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 10.5),
                        ),
                      ],
                    ),
                  ),
                ),
                titlesData: FlTitlesData(
                  topTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 38,
                      interval: maxY / 4,
                      getTitlesWidget: (v, meta) {
                        if (v == meta.max) return const SizedBox.shrink();
                        return Text(_compact(v),
                            style: TextStyle(
                                fontSize: 10, color: crm.textSecondary));
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 26,
                      getTitlesWidget: (v, _) {
                        final i = v.toInt();
                        if (i < 0 || i >= months.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(DateFormat('MMM').format(months[i]),
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: i == 5
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: i == 5
                                      ? crm.textPrimary
                                      : crm.textSecondary)),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: [
                  for (var i = 0; i < 6; i++)
                    BarChartGroupData(x: i, barRods: [
                      BarChartRodData(
                        toY: values[i],
                        width: 22,
                        color: i == 5 ? color : color.withValues(alpha: 0.55),
                        rodStackItems: [
                          if (paid[i] > 0)
                            BarChartRodStackItem(
                                0,
                                paid[i],
                                i == 5
                                    ? crm.success
                                    : crm.success.withValues(alpha: 0.75)),
                        ],
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(6)),
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
        ],
      ),
    );
  }
}

// ── Top vendors ─────────────────────────────────────────────────────────────

class _TopVendorsCard extends StatelessWidget {
  final List<Purchase> purchases;
  const _TopVendorsCard({required this.purchases});

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final spend = <String, double>{};
    final bills = <String, int>{};
    final owed = <String, double>{};
    for (final p in purchases) {
      final n = _vendorName(p);
      spend[n] = (spend[n] ?? 0) + p.grandTotal;
      bills[n] = (bills[n] ?? 0) + 1;
      owed[n] = (owed[n] ?? 0) + p.balance;
    }
    final entries = spend.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = entries.take(6).toList();
    final maxV = top.isEmpty ? 1.0 : (top.first.value <= 0 ? 1.0 : top.first.value);

    return InvCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InvSectionHeader(
            title: 'Top Vendors',
            subtitle: 'By total spend (incl. GST)',
            count: entries.length,
          ),
          16.h,
          if (top.isEmpty)
            const SizedBox(
                height: 200,
                child: InvEmpty(
                    icon: Icons.storefront_outlined,
                    title: 'No vendors yet',
                    subtitle: 'Vendor spend appears once bills are recorded.'))
          else
            for (final e in top)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    _VendorAvatar(name: e.key, size: 34),
                    10.w,
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(e.key,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                        color: crm.textPrimary)),
                              ),
                              8.w,
                              Text(fmtINR(e.value),
                                  style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w800,
                                      color: crm.textPrimary)),
                            ],
                          ),
                          5.h,
                          ClipRRect(
                            borderRadius: BorderRadius.circular(5),
                            child: Stack(
                              children: [
                                Container(height: 6, color: crm.input),
                                FractionallySizedBox(
                                  widthFactor:
                                      (e.value / maxV).clamp(0.02, 1.0),
                                  child: Container(
                                      height: 6,
                                      color: _vendorColor(e.key)),
                                ),
                              ],
                            ),
                          ),
                          4.h,
                          Text(
                              '${bills[e.key]} bill${bills[e.key] == 1 ? '' : 's'}'
                              '${(owed[e.key] ?? 0) > 0.01 ? ' · ${fmtINR(owed[e.key]!)} due' : ' · settled'}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 10.5,
                                  color: (owed[e.key] ?? 0) > 0.01
                                      ? crm.warning
                                      : crm.textSecondary)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}
