import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/models/employee.dart';
import 'package:nizan_crm/core/state/data_refresh.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/core/utils/responsive_builder.dart';
import 'package:nizan_crm/features/fleet/controllers/fleet_controller.dart'
    show FleetDateRange;
import 'package:nizan_crm/features/fleet/controllers/fuel_expense_controller.dart';
import 'package:nizan_crm/features/fleet/controllers/fuel_price_controller.dart';
import 'package:nizan_crm/features/fleet/data/fuel_price.dart';
import 'package:nizan_crm/features/fleet/presentation/widgets/fuel_price_manager.dart';
import 'package:nizan_crm/features/fleet/presentation/widgets/fuel_rate_widgets.dart';
import 'package:nizan_crm/core/providers/auth_provider.dart';
import 'package:nizan_crm/features/fleet/controllers/vehicle_controller.dart';
import 'package:nizan_crm/features/fleet/data/fuel_expense.dart';
import 'package:nizan_crm/features/fleet/data/vehicle.dart';
import 'package:nizan_crm/features/fleet/presentation/widgets/bill_attachment_field.dart';
import 'package:nizan_crm/features/fleet/presentation/widgets/fleet_report_widgets.dart';
import 'package:nizan_crm/presentation/common_widgets/export_report_dialog.dart';
import 'package:nizan_crm/services/employee_service.dart';

// ── Categories ──────────────────────────────────────────────────────────────

class _Cat {
  final String key;
  final String label;
  final IconData icon;
  final Color color;
  const _Cat(this.key, this.label, this.icon, this.color);
}

const _cats = <_Cat>[
  _Cat('fuel', 'Fuel', Icons.local_gas_station_rounded, Color(0xFF800020)),
  _Cat('food', 'Food', Icons.restaurant_rounded, Color(0xFFE08E0B)),
  _Cat('toll', 'Toll', Icons.toll_rounded, Color(0xFF3B6FB6)),
  _Cat('parking', 'Parking', Icons.local_parking_rounded, Color(0xFF5B8DEF)),
  _Cat('service', 'Service', Icons.build_rounded, Color(0xFF2E7D32)),
  _Cat('outsource_salary', 'Driver Salary', Icons.badge_rounded, Color(0xFF8E44AD)),
  _Cat('other', 'Other', Icons.receipt_long_rounded, Color(0xFF6B7280)),
];

_Cat _cat(String key) =>
    _cats.firstWhere((c) => c.key == key, orElse: () => _cats.last);

/// Categories that aren't tied to a vehicle. Everything else requires one.
const _vehiclelessCategories = {'outsource_salary'};

const _paymentModes = [
  ('cash', 'Cash'),
  ('upi', 'UPI'),
  ('card', 'Card'),
  ('credit', 'Credit'),
  ('other', 'Other'),
];

String _paymentLabel(String key) =>
    _paymentModes.firstWhere((m) => m.$1 == key, orElse: () => (key, key)).$2;

const _statusLabels = {
  'pending': 'Pending',
  'approved': 'Approved',
  'rejected': 'Rejected',
};

Color _statusColor(String s, CrmTheme crm) => switch (s) {
      'approved' => crm.success,
      'rejected' => crm.destructive,
      _ => crm.warning,
    };

/// What a row leads with: the vehicle, or — for an outsourced salary, which
/// has no vehicle — the driver who was paid.
String _subject(FuelExpense e) {
  if (e.category == 'outsource_salary') {
    final name = e.driver?.name.trim() ?? '';
    return name.isEmpty ? 'Driver salary' : name;
  }
  final v = e.vehicle;
  if (v == null) return 'No vehicle';
  return v.registrationNumber.isEmpty ? v.name : '${v.name} · ${v.registrationNumber}';
}

final _rowDate = DateFormat('d MMM yyyy');

// ── Screen ──────────────────────────────────────────────────────────────────

class FuelExpensesScreen extends ConsumerStatefulWidget {
  const FuelExpensesScreen({super.key});

  @override
  ConsumerState<FuelExpensesScreen> createState() => _FuelExpensesScreenState();
}

class _FuelExpensesScreenState extends ConsumerState<FuelExpensesScreen> {
  static const _pageSize = 25;

  var _preset = FleetRangePreset.thisMonth;
  FleetDateRange _range = fleetRangeFor(FleetRangePreset.thisMonth);
  String? _category; // null = all
  String? _vehicleId; // null = all
  String? _status; // null = all
  String _query = '';
  int _page = 0;
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _resetPage() => _page = 0;

  bool _inRange(FuelExpense e) {
    final d = DateTime(e.date.year, e.date.month, e.date.day);
    return !d.isBefore(_range.from) && !d.isAfter(_range.to);
  }

  bool _matchesSearch(FuelExpense e) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return [
      e.vehicle?.name,
      e.vehicle?.registrationNumber,
      e.driver?.name,
      e.station,
      e.notes,
      _cat(e.category).label,
    ].any((s) => (s ?? '').toLowerCase().contains(q));
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final isMobile = ResponsiveBuilder.isMobile(context);
    final async = ref.watch(fuelExpensesProvider);
    // Keep the form's vehicle / driver pickers loaded before it opens.
    ref.watch(vehiclesProvider);
    ref.watch(employeesProvider);

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => AppErrorView(
          error: e, onRetry: () => ref.invalidate(fuelExpensesProvider)),
      data: (all) {
        // Date + search + vehicle + status narrow everything; the category
        // chips then filter the list but the chips themselves show the
        // totals of every category so they stay comparable.
        final scoped = all
            .where(_inRange)
            .where(_matchesSearch)
            .where((e) => _vehicleId == null || e.vehicle?.id == _vehicleId)
            .where((e) => _status == null || e.status == _status)
            .toList();
        final shown = _category == null
            ? scoped
            : scoped.where((e) => e.category == _category).toList();

        final pages = shown.isEmpty ? 1 : (shown.length / _pageSize).ceil();
        final page = _page.clamp(0, pages - 1);
        final pageItems =
            shown.skip(page * _pageSize).take(_pageSize).toList();

        final vehicles = {
          for (final e in all)
            if (e.vehicle != null) e.vehicle!.id: e.vehicle!,
        }.values.toList()
          ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(fuelExpensesProvider);
            try {
              await ref.read(fuelExpensesProvider.future);
            } catch (_) {
              // The error state shows the failure.
            }
          },
          child: ListView(
            padding: EdgeInsets.fromLTRB(
                isMobile ? 16 : 0, 12, isMobile ? 16 : 0, 24),
            children: [
              _header(crm, isMobile, shown),
              const SizedBox(height: 14),
              FleetDateRangeBar(
                preset: _preset,
                range: _range,
                onChanged: (p, r) => setState(() {
                  _preset = p;
                  _range = r;
                  _resetPage();
                }),
              ),
              const SizedBox(height: 14),
              _Kpis(items: shown),
              const SizedBox(height: 14),
              _filters(crm, isMobile, scoped, vehicles),
              const SizedBox(height: 14),
              if (shown.isNotEmpty) ...[
                _Breakdown(items: shown, wide: !isMobile),
                const SizedBox(height: 14),
              ],
              _list(crm, isMobile, shown, pageItems, page, pages),
            ],
          ),
        );
      },
    );
  }

  // ── Header ──

  Widget _header(CrmTheme crm, bool isMobile, List<FuelExpense> shown) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Fleet Expenses',
                  style: TextStyle(
                      fontSize: isMobile ? 20 : 24,
                      fontWeight: FontWeight.w800,
                      color: crm.textPrimary)),
              if (!isMobile)
                Text('Fuel, tolls, parking, service and driver costs',
                    style: TextStyle(fontSize: 13, color: crm.textSecondary)),
            ],
          ),
        ),
        // The fuel prices bills are checked against, and fill-ins use.
        if (canEditFuelPrices(ref.read(authSessionProvider)?.role)) ...[
          IconButton(
            key: const Key('fuelPricesButton'),
            tooltip: 'Fuel prices',
            onPressed: () => showFuelPriceManager(context),
            icon: const Icon(Icons.local_gas_station_outlined),
            style: IconButton.styleFrom(
              foregroundColor: crm.accent,
              backgroundColor: crm.accent.withValues(alpha: 0.10),
            ),
          ),
          const SizedBox(width: 8),
        ],
        IconButton(
          tooltip: 'Export shown expenses',
          onPressed: shown.isEmpty ? null : () => _export(shown),
          icon: const Icon(Icons.download_rounded),
          style: IconButton.styleFrom(
            foregroundColor: crm.accent,
            backgroundColor: crm.accent.withValues(alpha: 0.10),
          ),
        ),
        const SizedBox(width: 8),
        FilledButton.icon(
          onPressed: () => _openForm(),
          icon: const Icon(Icons.add_rounded, size: 18),
          label: Text(isMobile ? 'Add' : 'Add Expense'),
        ),
      ],
    );
  }

  void _export(List<FuelExpense> items) {
    showDialog(
      context: context,
      builder: (_) => ExportReportDialog<FuelExpense>(
        title: 'Fleet Expenses ${fleetDay(_range.from)} - ${fleetDay(_range.to)}',
        items: items,
        getVehicleName: (e) => e.vehicle?.name,
        getDriverName: (e) => e.driver?.name,
        headers: const [
          'Date',
          'Category',
          'Vehicle',
          'Driver',
          'Amount',
          'Liters',
          'Odometer',
          'Payment',
          'Status',
          'Station / Vendor',
          'Notes',
        ],
        buildRow: (e) => [
          DateFormat('yyyy-MM-dd').format(e.date),
          _cat(e.category).label,
          e.vehicle?.name ?? '',
          e.driver?.name ?? '',
          e.totalAmount.toStringAsFixed(2),
          e.liters > 0 ? e.liters.toStringAsFixed(2) : '',
          e.odometerKm > 0 ? e.odometerKm.toStringAsFixed(0) : '',
          _paymentLabel(e.paymentMode),
          _statusLabels[e.status] ?? e.status,
          e.station,
          e.notes,
        ],
      ),
    );
  }

  // ── Filters ──

  Widget _filters(CrmTheme crm, bool isMobile, List<FuelExpense> scoped,
      List<Vehicle> vehicles) {
    double sumOf(String? cat) => scoped
        .where((e) => cat == null || e.category == cat)
        .fold(0.0, (a, e) => a + e.totalAmount);

    final search = TextField(
      controller: _searchCtrl,
      onChanged: (v) => setState(() {
        _query = v;
        _resetPage();
      }),
      decoration: InputDecoration(
        hintText: 'Search vehicle, driver, station, notes…',
        prefixIcon: const Icon(Icons.search_rounded, size: 20),
        suffixIcon: _query.isEmpty
            ? null
            : IconButton(
                tooltip: 'Clear',
                icon: const Icon(Icons.close_rounded, size: 18),
                onPressed: () => setState(() {
                  _searchCtrl.clear();
                  _query = '';
                  _resetPage();
                }),
              ),
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );

    Widget dropdown<T>({
      required String hint,
      required T? value,
      required List<DropdownMenuItem<T?>> items,
      required ValueChanged<T?> onChanged,
    }) =>
        DropdownButtonFormField<T?>(
          initialValue: value,
          isExpanded: true,
          isDense: true,
          decoration: InputDecoration(
            labelText: hint,
            isDense: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          items: items,
          onChanged: onChanged,
        );

    final vehicleFilter = dropdown<String>(
      hint: 'Vehicle',
      value: _vehicleId,
      items: [
        const DropdownMenuItem(value: null, child: Text('All vehicles')),
        for (final v in vehicles)
          DropdownMenuItem(
            value: v.id,
            child: Text(
                v.registrationNumber.isEmpty
                    ? v.name
                    : '${v.name} · ${v.registrationNumber}',
                overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: (v) => setState(() {
        _vehicleId = v;
        _resetPage();
      }),
    );
    final statusFilter = dropdown<String>(
      hint: 'Status',
      value: _status,
      items: [
        const DropdownMenuItem(value: null, child: Text('Any status')),
        for (final s in _statusLabels.entries)
          DropdownMenuItem(value: s.key, child: Text(s.value)),
      ],
      onChanged: (v) => setState(() {
        _status = v;
        _resetPage();
      }),
    );

    Widget chip(String? key, String label, IconData icon, Color color) {
      final selected = _category == key;
      final total = sumOf(key);
      return ChoiceChip(
        selected: selected,
        showCheckmark: false,
        avatar: Icon(icon, size: 16, color: selected ? Colors.white : color),
        label: Text('$label · ${fleetInrCompact(total)}'),
        labelStyle: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : crm.textPrimary),
        selectedColor: color,
        backgroundColor: color.withValues(alpha: 0.08),
        side: BorderSide(color: color.withValues(alpha: selected ? 1 : 0.25)),
        onSelected: (_) => setState(() {
          _category = key;
          _resetPage();
        }),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isMobile) ...[
          search,
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: vehicleFilter),
            const SizedBox(width: 10),
            Expanded(child: statusFilter),
          ]),
        ] else
          Row(children: [
            Expanded(flex: 3, child: search),
            const SizedBox(width: 10),
            Expanded(flex: 2, child: vehicleFilter),
            const SizedBox(width: 10),
            Expanded(flex: 1, child: statusFilter),
          ]),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              chip(null, 'All', Icons.apps_rounded, crm.primary),
              for (final c in _cats)
                if (scoped.any((e) => e.category == c.key)) ...[
                  const SizedBox(width: 6),
                  chip(c.key, c.label, c.icon, c.color),
                ],
            ],
          ),
        ),
      ],
    );
  }

  // ── List ──

  Widget _list(CrmTheme crm, bool isMobile, List<FuelExpense> shown,
      List<FuelExpense> pageItems, int page, int pages) {
    final filtered = _category != null ||
        _vehicleId != null ||
        _status != null ||
        _query.trim().isNotEmpty;
    return FleetSection(
      title: 'Expenses',
      subtitle:
          '${shown.length} entr${shown.length == 1 ? 'y' : 'ies'} · ${fleetInr(shown.fold(0.0, (a, e) => a + e.totalAmount))}',
      icon: Icons.receipt_long_rounded,
      trailing: filtered
          ? TextButton(
              onPressed: () => setState(() {
                _category = null;
                _vehicleId = null;
                _status = null;
                _query = '';
                _searchCtrl.clear();
                _resetPage();
              }),
              child: const Text('Clear filters'),
            )
          : null,
      child: shown.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 36),
              child: Column(
                children: [
                  Icon(Icons.receipt_long_outlined,
                      size: 44, color: crm.textSecondary.withValues(alpha: 0.4)),
                  const SizedBox(height: 10),
                  Text('No expenses in this range',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: crm.textSecondary)),
                  const SizedBox(height: 4),
                  Text(
                      filtered
                          ? 'Try clearing the filters or picking other dates.'
                          : 'Pick other dates, or add an expense.',
                      style: TextStyle(fontSize: 12, color: crm.textSecondary)),
                ],
              ),
            )
          : Column(
              children: [
                if (!isMobile) const _TableHeader(),
                for (final e in pageItems)
                  isMobile
                      ? _ExpenseCard(
                          e: e,
                          onEdit: () => _openForm(e),
                          onDelete: () => _delete(e),
                          onBill: () => _showBill(e))
                      : _ExpenseRow(
                          e: e,
                          onEdit: () => _openForm(e),
                          onDelete: () => _delete(e),
                          onBill: () => _showBill(e)),
                if (pages > 1) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                          '${page * _pageSize + 1}–${page * _pageSize + pageItems.length} of ${shown.length}',
                          style: TextStyle(
                              fontSize: 12, color: crm.textSecondary)),
                      IconButton(
                        tooltip: 'Previous',
                        onPressed: page > 0
                            ? () => setState(() => _page = page - 1)
                            : null,
                        icon: const Icon(Icons.chevron_left_rounded),
                      ),
                      IconButton(
                        tooltip: 'Next',
                        onPressed: page < pages - 1
                            ? () => setState(() => _page = page + 1)
                            : null,
                        icon: const Icon(Icons.chevron_right_rounded),
                      ),
                    ],
                  ),
                ],
              ],
            ),
    );
  }

  // ── Actions ──

  void _showBill(FuelExpense e) {
    if (e.billImage.isEmpty) return;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text('Bill · ${fleetInr(e.totalAmount)}'),
              subtitle: Text('${_cat(e.category).label} · ${_rowDate.format(e.date)}'),
              trailing: IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
            Flexible(
              child: InteractiveViewer(
                maxScale: 5,
                child: Image.network(
                  e.billImage,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const Padding(
                    padding: EdgeInsets.all(32),
                    child: Text("Couldn't load the bill image."),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _delete(FuelExpense e) async {
    final crm = context.crmColors;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete expense?'),
        content: Text(
            '${_cat(e.category).label} · ${fleetInr(e.totalAmount)} on ${_rowDate.format(e.date)} will be removed.'),
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
      await ref.read(fuelExpenseServiceProvider).deleteFuelExpense(e.id);
      ref.refreshData.fuelExpenses();
    } catch (err) {
      if (mounted) showErrorSnackBar(context, err);
    }
  }

  Future<void> _openForm([FuelExpense? expense]) async {
    final vehicles = ref.read(vehiclesProvider).value ?? const <Vehicle>[];
    final employees = ref.read(employeesProvider).value ?? const <Employee>[];
    await showDialog(
      context: context,
      builder: (_) => _ExpenseForm(
        expense: expense,
        vehicles: vehicles,
        drivers: employees
            .where((e) =>
                e.isDriver && (e.isActive || e.id == expense?.driver?.id))
            .toList(),
      ),
    );
  }
}

// ── KPIs ────────────────────────────────────────────────────────────────────

class _Kpis extends StatelessWidget {
  final List<FuelExpense> items;
  const _Kpis({required this.items});

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final total = items.fold(0.0, (a, e) => a + e.totalAmount);
    final fuel = items.where((e) => e.category == 'fuel');
    final fuelSpend = fuel.fold(0.0, (a, e) => a + e.totalAmount);
    final liters = fuel.fold(0.0, (a, e) => a + e.liters);
    final pending = items.where((e) => e.status == 'pending');
    final pendingSpend = pending.fold(0.0, (a, e) => a + e.totalAmount);
    final byVehicle = <String, double>{};
    for (final e in items) {
      if (e.vehicle == null) continue;
      byVehicle[e.vehicle!.name] = (byVehicle[e.vehicle!.name] ?? 0) + e.totalAmount;
    }
    final top = byVehicle.entries.isEmpty
        ? null
        : byVehicle.entries.reduce((a, b) => b.value > a.value ? b : a);
    return FleetKpiGrid(kpis: [
      FleetKpi(fleetInr(total), 'Total spend',
          '${items.length} entr${items.length == 1 ? 'y' : 'ies'}',
          Icons.account_balance_wallet_rounded, crm.primary),
      FleetKpi(fleetInr(fuelSpend), 'Fuel',
          liters > 0 ? '${liters.toStringAsFixed(1)} L filled' : 'no fuel entries',
          Icons.local_gas_station_rounded, const Color(0xFF800020)),
      FleetKpi('${pending.length}', 'Pending approval',
          pending.isEmpty ? 'all reviewed' : fleetInr(pendingSpend),
          Icons.hourglass_top_rounded, crm.warning),
      FleetKpi(top?.key ?? '—', 'Highest-spend vehicle',
          top == null ? 'no vehicle costs' : fleetInr(top.value),
          Icons.directions_car_rounded, crm.accent),
    ]);
  }
}

// ── Breakdown ───────────────────────────────────────────────────────────────

class _Breakdown extends StatelessWidget {
  final List<FuelExpense> items;
  final bool wide;
  const _Breakdown({required this.items, required this.wide});

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final total = items.fold(0.0, (a, e) => a + e.totalAmount);

    final byCat = <String, double>{};
    for (final e in items) {
      byCat[e.category] = (byCat[e.category] ?? 0) + e.totalAmount;
    }
    final cats = byCat.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    final byVehicle = <String, double>{};
    for (final e in items) {
      byVehicle[_subject(e)] = (byVehicle[_subject(e)] ?? 0) + e.totalAmount;
    }
    final vehicles = byVehicle.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final category = FleetSection(
      title: 'By category',
      icon: Icons.donut_large_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Stacked share bar.
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 12,
              child: Row(
                children: [
                  for (var i = 0; i < cats.length; i++) ...[
                    if (i > 0) const SizedBox(width: 2),
                    Expanded(
                      flex: total <= 0 ? 1 : (cats[i].value / total * 1000).round().clamp(1, 1000),
                      child: ColoredBox(color: _cat(cats[i].key).color),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          for (final c in cats)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                        color: _cat(c.key).color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_cat(c.key).label,
                        style: TextStyle(fontSize: 13, color: crm.textPrimary)),
                  ),
                  Text(
                      total <= 0 ? '' : '${(c.value / total * 100).round()}%',
                      style: TextStyle(fontSize: 12, color: crm.textSecondary)),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 96,
                    child: Text(fleetInr(c.value),
                        textAlign: TextAlign.right,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: crm.textPrimary)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );

    final topVehicles = vehicles.take(5).toList();
    final vehicle = FleetSection(
      title: 'Top spend',
      subtitle: 'By vehicle (salaries by driver)',
      icon: Icons.leaderboard_rounded,
      child: Column(
        children: [
          for (final v in topVehicles)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(v.key,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 13, color: crm.textPrimary)),
                      ),
                      Text(fleetInr(v.value),
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: crm.textPrimary)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: topVehicles.first.value <= 0
                          ? 0
                          : v.value / topVehicles.first.value,
                      minHeight: 6,
                      backgroundColor: crm.input,
                      valueColor: AlwaysStoppedAnimation(crm.accent),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );

    if (!wide) {
      return Column(children: [category, const SizedBox(height: 14), vehicle]);
    }
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: category),
          const SizedBox(width: 14),
          Expanded(child: vehicle),
        ],
      ),
    );
  }
}

// ── Rows ────────────────────────────────────────────────────────────────────

class _CatBadge extends StatelessWidget {
  final String category;
  final double size;
  const _CatBadge({required this.category, this.size = 38});

  @override
  Widget build(BuildContext context) {
    final c = _cat(category);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
          color: c.color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10)),
      child: Icon(c.icon, size: size * 0.5, color: c.color),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String status;
  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status, context.crmColors);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(_statusLabels[status] ?? status,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

String _details(FuelExpense e) => [
      if (e.liters > 0) '${e.liters.toStringAsFixed(1)} L',
      if (e.odometerKm > 0) '${e.odometerKm.toStringAsFixed(0)} km',
      if (e.station.isNotEmpty) e.station,
      if (e.category != 'outsource_salary' && (e.driver?.name ?? '').isNotEmpty)
        e.driver!.name,
      // The work the driver tied it to (none = a whole-day expense).
      if (e.workLabel.isNotEmpty) 'Work ${e.workLabel}',
    ].join(' · ');

class _RowMenu extends StatelessWidget {
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _RowMenu({required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return PopupMenuButton<String>(
      tooltip: 'Actions',
      icon: Icon(Icons.more_vert_rounded, size: 20, color: crm.textSecondary),
      onSelected: (v) => v == 'edit' ? onEdit() : onDelete(),
      itemBuilder: (_) => [
        const PopupMenuItem(
          value: 'edit',
          child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.edit_outlined, size: 18),
              title: Text('Edit')),
        ),
        PopupMenuItem(
          value: 'delete',
          child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.delete_outline, size: 18, color: crm.destructive),
              title: Text('Delete', style: TextStyle(color: crm.destructive))),
        ),
      ],
    );
  }
}

class _TableHeader extends StatelessWidget {
  const _TableHeader();

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    TextStyle s() => TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.4,
        color: crm.textSecondary);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 4, 8),
      child: Row(
        children: [
          SizedBox(width: 96, child: Text('DATE', style: s())),
          Expanded(flex: 4, child: Text('EXPENSE', style: s())),
          SizedBox(width: 90, child: Text('PAYMENT', style: s())),
          SizedBox(width: 96, child: Text('STATUS', style: s())),
          SizedBox(width: 40, child: Text('BILL', style: s())),
          SizedBox(
              width: 110,
              child: Text('AMOUNT', textAlign: TextAlign.right, style: s())),
          const SizedBox(width: 44),
        ],
      ),
    );
  }
}

class _BillButton extends StatelessWidget {
  final FuelExpense e;
  final VoidCallback onBill;
  const _BillButton({required this.e, required this.onBill});

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final has = e.billImage.isNotEmpty;
    return IconButton(
      tooltip: has ? 'View bill' : 'No bill attached',
      visualDensity: VisualDensity.compact,
      onPressed: has ? onBill : null,
      icon: Icon(has ? Icons.receipt_rounded : Icons.receipt_outlined,
          size: 19, color: has ? crm.accent : crm.border),
    );
  }
}

class _ExpenseRow extends StatelessWidget {
  final FuelExpense e;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onBill;
  const _ExpenseRow({
    required this.e,
    required this.onEdit,
    required this.onDelete,
    required this.onBill,
  });

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final details = _details(e);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: crm.border)),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 96,
                child: Text(_rowDate.format(e.date),
                    style: TextStyle(fontSize: 12.5, color: crm.textSecondary)),
              ),
              Expanded(
                flex: 4,
                child: Row(
                  children: [
                    _CatBadge(category: e.category, size: 34),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${_cat(e.category).label} · ${_subject(e)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: crm.textPrimary)),
                          if (details.isNotEmpty || e.notes.isNotEmpty)
                            Text(
                                [details, if (e.notes.isNotEmpty) '“${e.notes}”']
                                    .where((s) => s.isNotEmpty)
                                    .join(' · '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 11.5, color: crm.textSecondary)),
                          RateCheckLine(check: e.rateCheck, flaggedOnly: true),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 90,
                child: Text(_paymentLabel(e.paymentMode),
                    style: TextStyle(fontSize: 12.5, color: crm.textSecondary)),
              ),
              SizedBox(
                width: 96,
                child: Align(
                    alignment: Alignment.centerLeft,
                    child: _StatusPill(status: e.status)),
              ),
              SizedBox(width: 40, child: _BillButton(e: e, onBill: onBill)),
              SizedBox(
                width: 110,
                child: Text(fleetInr(e.totalAmount),
                    textAlign: TextAlign.right,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: crm.textPrimary)),
              ),
              SizedBox(
                  width: 44,
                  child: _RowMenu(onEdit: onEdit, onDelete: onDelete)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExpenseCard extends StatelessWidget {
  final FuelExpense e;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onBill;
  const _ExpenseCard({
    required this.e,
    required this.onEdit,
    required this.onDelete,
    required this.onBill,
  });

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final details = _details(e);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: crm.border),
      ),
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CatBadge(category: e.category),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(fleetInr(e.totalAmount),
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: crm.textPrimary)),
                        ),
                        _StatusPill(status: e.status),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text('${_cat(e.category).label} · ${_subject(e)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: crm.textPrimary)),
                    Text(
                        [
                          _rowDate.format(e.date),
                          _paymentLabel(e.paymentMode),
                          if (details.isNotEmpty) details,
                        ].join(' · '),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11.5, color: crm.textSecondary)),
                    if (e.notes.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text('“${e.notes}”',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 11.5,
                                fontStyle: FontStyle.italic,
                                color: crm.textSecondary)),
                      ),
                    RateCheckLine(check: e.rateCheck, flaggedOnly: true),
                  ],
                ),
              ),
              Column(
                children: [
                  _RowMenu(onEdit: onEdit, onDelete: onDelete),
                  _BillButton(e: e, onBill: onBill),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Add / edit form ─────────────────────────────────────────────────────────

class _ExpenseForm extends ConsumerStatefulWidget {
  final FuelExpense? expense;
  final List<Vehicle> vehicles;
  final List<Employee> drivers;
  const _ExpenseForm({
    required this.expense,
    required this.vehicles,
    required this.drivers,
  });

  @override
  ConsumerState<_ExpenseForm> createState() => _ExpenseFormState();
}

class _ExpenseFormState extends ConsumerState<_ExpenseForm> {
  late final e = widget.expense;
  late final _odometer = TextEditingController(
      text: e != null && e!.odometerKm > 0 ? e!.odometerKm.toStringAsFixed(0) : '');
  late final _liters = TextEditingController(
      text: e != null && e!.liters > 0 ? e!.liters.toStringAsFixed(2) : '');
  late final _amount =
      TextEditingController(text: e != null ? e!.totalAmount.toStringAsFixed(0) : '');
  late final _station = TextEditingController(text: e?.station ?? '');
  late final _notes = TextEditingController(text: e?.notes ?? '');
  late String _category = e?.category ?? 'fuel';
  late String _vehicleId = e?.vehicle?.id ?? '';
  late String _driverId = e?.driver?.id ?? '';
  late String _payment = e?.paymentMode ?? 'cash';
  late DateTime _date = e?.date ?? DateTime.now();
  // Bill / screenshot proof — mandatory before an expense can be saved.
  late String? _bill = (e?.billImage.isNotEmpty ?? false) ? e!.billImage : null;
  bool _billMissing = false;
  bool _vehicleMissing = false;
  bool _amountMissing = false;
  bool _saving = false;

  bool get _isSalary => _vehiclelessCategories.contains(_category);

  // The amount is filled in from litres × the price of the day, until someone types their own.
  final _amountFill = AmountFillIn();

  /// The vehicle chosen (null = none yet).
  Vehicle? get _vehicle => widget.vehicles.where((v) => v.id == _vehicleId).firstOrNull;
  String get _priceDay => DateFormat('yyyy-MM-dd').format(_date);

  void _fillAmount() {
    final fuel = fuelPriceTypeOf(_vehicle?.fuelType);
    final prices = ref.read(fuelPricesProvider).value;
    final litres = double.tryParse(_liters.text.trim()) ?? 0;
    final suggested = (_category == 'fuel' && fuel != null && prices != null) ? prices.suggestAmount(fuel, _priceDay, litres) : null;
    _amountFill.apply(_amount, suggested);
  }

  @override
  void initState() {
    super.initState();
    _liters.addListener(_fillAmount);
  }

  @override
  void dispose() {
    for (final c in [_odometer, _liters, _amount, _station, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amount.text.replaceAll(',', '').trim()) ?? 0;
    setState(() {
      _billMissing = _bill == null || _bill!.isEmpty;
      _vehicleMissing = !_isSalary && _vehicleId.isEmpty;
      _amountMissing = amount <= 0;
    });
    if (_billMissing || _vehicleMissing || _amountMissing) return;
    setState(() => _saving = true);
    try {
      await ref.read(fuelExpenseServiceProvider).saveFuelExpense(
            id: e?.id,
            vehicleId: _isSalary ? '' : _vehicleId,
            driverId: _driverId,
            category: _category,
            date: _date,
            odometerKm: _category == 'fuel'
                ? double.tryParse(_odometer.text.trim()) ?? 0
                : 0,
            liters: _category == 'fuel'
                ? double.tryParse(_liters.text.trim()) ?? 0
                : 0,
            totalAmount: amount,
            paymentMode: _payment,
            station: _station.text.trim(),
            notes: _notes.text.trim(),
            billImage: _bill ?? '',
          );
      ref.refreshData.fuelExpenses();
      if (mounted) Navigator.of(context).pop();
    } catch (err) {
      // Keep the form open so the user can retry.
      if (mounted) {
        setState(() => _saving = false);
        showErrorSnackBar(context, err);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final isMobile = ResponsiveBuilder.isMobile(context);
    final hasVehicle = widget.vehicles.any((v) => v.id == _vehicleId);
    final hasDriver = widget.drivers.any((d) => d.id == _driverId);
    // The prices may arrive after the litres were typed: fill in then too.
    ref.listen(fuelPricesProvider, (_, _) => _fillAmount());

    Widget label(String t) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(t,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: crm.textSecondary)),
        );

    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(24, 20, 12, 0),
      title: Row(
        children: [
          _CatBadge(category: _category, size: 34),
          const SizedBox(width: 10),
          Expanded(child: Text(e == null ? 'Add expense' : 'Edit expense')),
          if (e != null) _StatusPill(status: e!.status),
        ],
      ),
      content: SizedBox(
        width: isMobile ? double.maxFinite : 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              label('CATEGORY'),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final c in _cats)
                    ChoiceChip(
                      selected: _category == c.key,
                      showCheckmark: false,
                      avatar: Icon(c.icon,
                          size: 16,
                          color: _category == c.key ? Colors.white : c.color),
                      label: Text(c.label),
                      labelStyle: TextStyle(
                          color: _category == c.key ? Colors.white : null,
                          fontWeight: FontWeight.w600),
                      selectedColor: c.color,
                      onSelected: (_) {
                        setState(() => _category = c.key);
                        _fillAmount();
                      },
                    ),
                ],
              ),
              const SizedBox(height: 18),
              label('AMOUNT & DATE'),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _amount,
                      autofocus: e == null,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) {
                        if (_amountMissing) setState(() => _amountMissing = false);
                      },
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w800),
                      decoration: InputDecoration(
                        prefixText: '₹ ',
                        labelText: 'Total amount',
                        errorText: _amountMissing ? 'Enter the amount' : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _date,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now().add(const Duration(days: 1)),
                        );
                        if (picked != null) {
                          setState(() => _date = picked);
                          _fillAmount();
                        }
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Date',
                          suffixIcon: Icon(Icons.calendar_today_outlined, size: 18),
                        ),
                        child: Text(_rowDate.format(_date)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                children: [
                  for (final m in _paymentModes)
                    ChoiceChip(
                      label: Text(m.$2),
                      selected: _payment == m.$1,
                      visualDensity: VisualDensity.compact,
                      onSelected: (_) => setState(() => _payment = m.$1),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              label(_isSalary ? 'PAID TO' : 'VEHICLE & DRIVER'),
              // A salary isn't tied to a vehicle, so the picker is hidden for
              // it; every other category needs one.
              if (!_isSalary) ...[
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: hasVehicle ? _vehicleId : null,
                  items: [
                    for (final v in widget.vehicles)
                      DropdownMenuItem(
                        value: v.id,
                        child: Text(
                            v.registrationNumber.isEmpty
                                ? v.name
                                : '${v.name} · ${v.registrationNumber}',
                            overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (v) {
                    setState(() {
                      _vehicleId = v ?? '';
                      _vehicleMissing = false;
                    });
                    _fillAmount();
                  },
                  decoration: InputDecoration(
                    labelText: 'Vehicle',
                    prefixIcon: const Icon(Icons.directions_car_outlined),
                    errorText: _vehicleMissing ? 'Please select a vehicle' : null,
                  ),
                ),
                const SizedBox(height: 12),
              ],
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: hasDriver ? _driverId : '',
                items: [
                  const DropdownMenuItem(value: '', child: Text('Not specified')),
                  for (final d in widget.drivers)
                    DropdownMenuItem(value: d.id, child: Text(d.name)),
                ],
                onChanged: (v) => setState(() => _driverId = v ?? ''),
                decoration: InputDecoration(
                  labelText: _isSalary ? 'Outsourced driver' : 'Driver',
                  prefixIcon: const Icon(Icons.person_outline),
                ),
              ),
              if (_category == 'fuel') ...[
                const SizedBox(height: 18),
                label('FUEL DETAILS'),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _liters,
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                            labelText: 'Liters', suffixText: 'L'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _odometer,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                            labelText: 'Odometer', suffixText: 'km'),
                      ),
                    ),
                  ],
                ),
                FuelRateHint(
                  vehicleFuelType: _vehicle?.fuelType,
                  day: _priceDay,
                  liters: _liters,
                  amount: _amount,
                  fillsIn: true,
                ),
              ],
              const SizedBox(height: 18),
              label('DETAILS'),
              TextField(
                controller: _station,
                decoration: InputDecoration(
                  labelText:
                      _category == 'fuel' ? 'Fuel station' : 'Vendor / place',
                  prefixIcon: const Icon(Icons.storefront_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _notes,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Notes',
                  prefixIcon: Icon(Icons.notes_rounded),
                ),
              ),
              const SizedBox(height: 18),
              BillAttachmentField(
                value: _bill,
                isMissing: _billMissing,
                onChanged: (url) => setState(() {
                  _bill = url;
                  if (url != null) _billMissing = false;
                }),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Text(e == null ? 'Add expense' : 'Save changes'),
        ),
      ],
    );
  }
}
