import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/state/data_refresh.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/core/utils/responsive_builder.dart';
import 'package:nizan_crm/features/fleet/controllers/fuel_price_controller.dart';
import 'package:nizan_crm/features/fleet/data/fuel_price.dart';

String _day(String iso) =>
    iso.isEmpty ? '' : DateFormat('d MMM yyyy').format(DateTime.parse(iso));
String _iso(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

/// Who may change the fuel prices (the server enforces the same list).
bool canEditFuelPrices(String? role) =>
    const {'accounts', 'finance_head', 'fleet_manager', 'admin'}.contains(role);

/// Opens the fuel-price manager: a dialog on wide screens, a bottom sheet on a phone.
Future<void> showFuelPriceManager(BuildContext context) {
  if (ResponsiveBuilder.isMobile(context)) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => const FuelPriceManager(),
    );
  }
  return showDialog<void>(
    context: context,
    builder: (_) => Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 740),
        child: const FuelPriceManager(),
      ),
    ),
  );
}

/// What a litre of petrol or diesel (a kg of CNG, a kWh) costs, and from which day. Kept by hand: there
/// is no dependable free price feed for Kerala. A price change is a NEW row, so an older bill is still
/// held against the price of ITS day. Used to fill in the amount on a fuel entry and to check bills.
class FuelPriceManager extends ConsumerWidget {
  const FuelPriceManager({super.key});

  Future<void> _openForm(
    BuildContext context, {
    FuelPriceRow? existing,
    String? fuelType,
  }) async {
    await showDialog<bool>(
      context: context,
      builder: (_) => FuelPriceForm(existing: existing, fuelType: fuelType),
    );
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    FuelPriceRow r,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this price?'),
        content: Text(
          'The ${fuelLabel(r.fuelType).toLowerCase()} price of ₹${priceText(r.pricePerUnit)} per ${r.unit} (from ${_day(r.effectiveFrom)}) will be removed. '
          'Bills from those days are then held against the price before it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('fuelPriceConfirmDelete'),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await ref.read(fuelPriceServiceProvider).delete(r.id);
      ref.refreshData.fuelExpenses();
    } catch (e) {
      if (context.mounted) showErrorSnackBar(context, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crm = context.crmColors;
    final async = ref.watch(fuelPricesProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Fuel prices',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: crm.textPrimary,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Text(
            "Keep today's price up to date. A driver's fuel entry then fills in the amount from the litres, and a bill whose rate is "
            'far from the price of its day is flagged for review — never refused.',
            style: TextStyle(fontSize: 12.5, color: crm.textSecondary),
          ),
        ),
        Flexible(
          child: async.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(16),
              child: AppErrorView(
                error: e,
                onRetry: () => ref.invalidate(fuelPricesProvider),
              ),
            ),
            data: (prices) => prices.isEmpty
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                    child: Column(
                      children: [
                        Icon(
                          Icons.local_gas_station_outlined,
                          size: 40,
                          color: crm.textSecondary.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'No fuel price set yet',
                          key: const Key('fuelPriceEmpty'),
                          style: TextStyle(
                            color: crm.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Add the price per litre of petrol and diesel.',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: crm.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                    children: [
                      for (final f in kFuelPriceTypes)
                        ..._section(context, ref, crm, prices, f),
                      Padding(
                        padding: const EdgeInsets.only(top: 4, bottom: 4),
                        child: Text(
                          'A bill is flagged when its rate is more than ${priceText(prices.tolerancePct)}% above or below the price of its day.',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: crm.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              key: const Key('fuelPriceAdd'),
              onPressed: () => _openForm(context),
              icon: const Icon(Icons.add),
              label: const Text('Add price'),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _section(
    BuildContext context,
    WidgetRef ref,
    CrmTheme crm,
    FuelPrices prices,
    (String, String, String, IconData) f,
  ) {
    final rows = prices.items.where((p) => p.fuelType == f.$1).toList();
    if (rows.isEmpty) return const [];
    final current = prices.current[f.$1];
    return [
      Padding(
        padding: const EdgeInsets.only(top: 6, bottom: 6),
        child: Row(
          children: [
            Icon(f.$4, size: 18, color: crm.primary),
            const SizedBox(width: 8),
            Text(
              f.$2,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
            ),
            Text(
              '  ·  per ${f.$3}',
              style: TextStyle(fontSize: 12, color: crm.textSecondary),
            ),
          ],
        ),
      ),
      for (final r in rows)
        _row(context, ref, crm, prices, r, isCurrent: current?.id == r.id),
    ];
  }

  Widget _row(
    BuildContext context,
    WidgetRef ref,
    CrmTheme crm,
    FuelPrices prices,
    FuelPriceRow r, {
    required bool isCurrent,
  }) {
    final upcoming = r.effectiveFrom.compareTo(prices.today) > 0;
    final (label, color) = isCurrent
        ? ('In force today', crm.success)
        : (upcoming
              ? ('Upcoming', crm.primary)
              : ('Earlier', crm.textSecondary));
    return Container(
      key: Key('fuelPriceRow_${r.id}'),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCurrent ? crm.success.withValues(alpha: 0.5) : crm.border,
        ),
      ),
      child: Opacity(
        opacity: isCurrent || upcoming ? 1 : 0.7,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '₹${priceText(r.pricePerUnit)} per ${r.unit}',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: crm.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      'From ${_day(r.effectiveFrom)}',
                      if (r.note.isNotEmpty) r.note,
                    ].join('  ·  '),
                    style: TextStyle(fontSize: 11.5, color: crm.textSecondary),
                  ),
                ],
              ),
            ),
            Container(
              key: Key('fuelPriceStatus_${r.id}'),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
            IconButton(
              key: Key('fuelPriceEdit_${r.id}'),
              tooltip: 'Edit',
              onPressed: () => _openForm(context, existing: r),
              icon: const Icon(Icons.edit_outlined, size: 20),
            ),
            IconButton(
              key: Key('fuelPriceDelete_${r.id}'),
              tooltip: 'Delete',
              onPressed: () => _delete(context, ref, r),
              icon: Icon(
                Icons.delete_outline,
                size: 20,
                color: crm.destructive,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Add or edit one price.
class FuelPriceForm extends ConsumerStatefulWidget {
  final FuelPriceRow? existing;

  /// A fuel to start on when adding (otherwise petrol).
  final String? fuelType;
  const FuelPriceForm({super.key, this.existing, this.fuelType});

  @override
  ConsumerState<FuelPriceForm> createState() => _FuelPriceFormState();
}

class _FuelPriceFormState extends ConsumerState<FuelPriceForm> {
  late String _fuel = widget.existing?.fuelType ?? widget.fuelType ?? 'petrol';
  late final _price = TextEditingController(
    text: widget.existing == null
        ? ''
        : priceText(widget.existing!.pricePerUnit),
  );
  late final _note = TextEditingController(text: widget.existing?.note ?? '');
  late String _from = widget.existing?.effectiveFrom ?? _iso(DateTime.now());
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _price.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(_from) ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _from = _iso(picked));
  }

  Future<void> _save() async {
    final price = double.tryParse(_price.text.trim().replaceAll(',', ''));
    if (price == null || price <= 0) {
      setState(
        () => _error = 'Enter the price per ${fuelUnit(_fuel)} (more than 0).',
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final row = FuelPriceRow(
      id: widget.existing?.id ?? '',
      fuelType: _fuel,
      pricePerUnit: price,
      effectiveFrom: _from,
      note: _note.text.trim(),
    );
    try {
      final service = ref.read(fuelPriceServiceProvider);
      if (widget.existing == null) {
        await service.create(row);
      } else {
        await service.update(widget.existing!.id, row);
      }
      ref.refreshData.fuelExpenses();
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      // the server's own words — e.g. there is already a petrol price from that date
      if (mounted) {
        setState(() {
          _busy = false;
          _error = friendlyErrorMessage(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return AlertDialog(
      key: const Key('fuelPriceForm'),
      title: Text(
        widget.existing == null ? 'Add fuel price' : 'Edit fuel price',
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<String>(
                key: const Key('fuelPriceFuel'),
                initialValue: _fuel,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Fuel',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: [
                  for (final f in kFuelPriceTypes)
                    DropdownMenuItem(
                      value: f.$1,
                      child: Text('${f.$2}  (per ${f.$3})'),
                    ),
                ],
                onChanged: (v) => setState(() => _fuel = v ?? _fuel),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('fuelPriceAmount'),
                controller: _price,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Price per ${fuelUnit(_fuel)} (₹)',
                  prefixIcon: const Icon(Icons.currency_rupee, size: 18),
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              InkWell(
                key: const Key('fuelPriceFrom'),
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(8),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Starts from',
                    border: OutlineInputBorder(),
                    isDense: true,
                    suffixIcon: Icon(Icons.calendar_today_outlined, size: 18),
                  ),
                  child: Text(_day(_from)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('fuelPriceNote'),
                controller: _note,
                maxLength: 200,
                decoration: const InputDecoration(
                  labelText: 'Note (optional)',
                  border: OutlineInputBorder(),
                  isDense: true,
                  counterText: '',
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _error!,
                    key: const Key('fuelPriceError'),
                    style: TextStyle(color: crm.destructive, fontSize: 12.5),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('fuelPriceSave'),
          onPressed: _busy ? null : _save,
          child: Text(_busy ? 'Saving…' : 'Save'),
        ),
      ],
    );
  }
}
