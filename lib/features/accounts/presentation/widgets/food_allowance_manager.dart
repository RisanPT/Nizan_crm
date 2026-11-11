import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/core/utils/responsive_builder.dart';
import 'package:nizan_crm/core/state/data_refresh.dart';
import 'package:nizan_crm/features/accounts/controllers/food_allowance_controller.dart';
import 'package:nizan_crm/features/accounts/data/artist_expense.dart' show kMeals, mealLabel;
import 'package:nizan_crm/features/accounts/data/food_allowance.dart';
import 'package:nizan_crm/features/accounts/presentation/widgets/list_common.dart' show rupeesWhole;

String _day(String iso) => iso.isEmpty ? '' : DateFormat('d MMM yyyy').format(DateTime.parse(iso));

/// "All dates" / "From 1 Oct 2026" / "Until 30 Sep 2026" / "1 Oct 2026 – 31 Dec 2026".
String allowanceDatesText(FoodAllowanceRule r) {
  if (r.effectiveFrom.isEmpty && r.effectiveTo.isEmpty) return 'All dates';
  if (r.effectiveTo.isEmpty) return 'From ${_day(r.effectiveFrom)}';
  if (r.effectiveFrom.isEmpty) return 'Until ${_day(r.effectiveTo)}';
  return '${_day(r.effectiveFrom)} – ${_day(r.effectiveTo)}';
}

/// Opens the food-allowance manager: a dialog on wide screens, a bottom sheet on a phone.
Future<void> showFoodAllowanceManager(BuildContext context) {
  if (ResponsiveBuilder.isMobile(context)) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => const FoodAllowanceManager(),
    );
  }
  return showDialog<void>(
    context: context,
    builder: (_) => Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 620, maxHeight: 740), child: const FoodAllowanceManager()),
    ),
  );
}

/// ACCOUNTS: how much may be spent on each meal PER HEAD. Add, edit, switch off and delete the
/// rules; a work's food is checked against heads × the amount (over is flagged, never cut).
class FoodAllowanceManager extends ConsumerWidget {
  const FoodAllowanceManager({super.key});

  Future<void> _openForm(BuildContext context, {FoodAllowanceRule? existing}) async {
    await showDialog<bool>(context: context, builder: (_) => FoodAllowanceForm(existing: existing));
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, FoodAllowanceRule r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this allowance?'),
        content: Text('The ${mealLabel(r.meal).toLowerCase()} allowance of ${rupeesWhole(r.amountPerHead)} per head (${allowanceDatesText(r).toLowerCase()}) '
            'will be removed. Works are no longer checked against it.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(key: const Key('allowanceConfirmDelete'), onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await ref.read(foodAllowanceServiceProvider).delete(r.id);
      ref.refreshData.expenses();
    } catch (e) {
      if (context.mounted) showErrorSnackBar(context, e);
    }
  }

  Future<void> _toggle(BuildContext context, WidgetRef ref, FoodAllowanceRule r, bool on) async {
    try {
      await ref.read(foodAllowanceServiceProvider).setActive(r.id, on);
      ref.refreshData.expenses();
    } catch (e) {
      // e.g. switching it on would clash with another active rule for the same meal and dates
      if (context.mounted) showErrorSnackBar(context, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crm = context.crmColors;
    final async = ref.watch(foodAllowanceRulesProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
          child: Row(
            children: [
              Expanded(child: Text('Food allowance per head', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: crm.textPrimary))),
              IconButton(onPressed: () => Navigator.of(context).maybePop(), icon: const Icon(Icons.close)),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Text(
            "How much may be spent on each meal per person. A work's food is checked against its heads × this amount. "
            'Going over is flagged for Accounts — the full amount still counts as the work\'s cost.',
            style: TextStyle(fontSize: 12.5, color: crm.textSecondary),
          ),
        ),
        Flexible(
          child: async.when(
            loading: () => const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator())),
            error: (e, _) => Padding(padding: const EdgeInsets.all(16), child: AppErrorView(error: e, onRetry: () => ref.invalidate(foodAllowanceRulesProvider))),
            data: (rules) => rules.isEmpty
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                    child: Column(children: [
                      Icon(Icons.restaurant_menu_outlined, size: 40, color: crm.textSecondary.withValues(alpha: 0.5)),
                      const SizedBox(height: 10),
                      Text('No allowance set yet', key: const Key('allowanceEmpty'), style: TextStyle(color: crm.textSecondary, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text('Add an amount per head for each meal.', style: TextStyle(fontSize: 12.5, color: crm.textSecondary)),
                    ]),
                  )
                : ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                    children: [for (final r in rules) _row(context, ref, crm, r)],
                  ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              key: const Key('allowanceAdd'),
              onPressed: () => _openForm(context),
              icon: const Icon(Icons.add),
              label: const Text('Add allowance'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _row(BuildContext context, WidgetRef ref, CrmTheme crm, FoodAllowanceRule r) {
    final icon = kMeals.where((m) => m.$1 == r.meal).map((m) => m.$3).firstOrNull ?? Icons.restaurant_outlined;
    final dim = !r.active;
    return Container(
      key: Key('allowanceRow_${r.id}'),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: crm.border),
      ),
      child: Opacity(
        opacity: dim ? 0.55 : 1,
        child: Row(
          children: [
            Icon(icon, size: 22, color: crm.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(mealLabel(r.meal), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                  Text('${rupeesWhole(r.amountPerHead)} per head', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: crm.primary)),
                  const SizedBox(height: 2),
                  Text(
                    [allowanceDatesText(r), if (dim) 'Switched off', if (r.note.isNotEmpty) r.note].join('  ·  '),
                    style: TextStyle(fontSize: 11.5, color: crm.textSecondary),
                  ),
                ],
              ),
            ),
            Switch(
              key: Key('allowanceSwitch_${r.id}'),
              value: r.active,
              onChanged: (on) => _toggle(context, ref, r, on),
            ),
            IconButton(key: Key('allowanceEdit_${r.id}'), tooltip: 'Edit', onPressed: () => _openForm(context, existing: r), icon: const Icon(Icons.edit_outlined, size: 20)),
            IconButton(key: Key('allowanceDelete_${r.id}'), tooltip: 'Delete', onPressed: () => _delete(context, ref, r), icon: Icon(Icons.delete_outline, size: 20, color: crm.destructive)),
          ],
        ),
      ),
    );
  }
}

/// Add or edit one allowance rule.
class FoodAllowanceForm extends ConsumerStatefulWidget {
  final FoodAllowanceRule? existing;
  const FoodAllowanceForm({super.key, this.existing});

  @override
  ConsumerState<FoodAllowanceForm> createState() => _FoodAllowanceFormState();
}

class _FoodAllowanceFormState extends ConsumerState<FoodAllowanceForm> {
  late String _meal = widget.existing?.meal ?? 'lunch';
  late final _amount = TextEditingController(text: widget.existing == null ? '' : _plain(widget.existing!.amountPerHead));
  late final _note = TextEditingController(text: widget.existing?.note ?? '');
  late String _from = widget.existing?.effectiveFrom ?? '';
  late String _to = widget.existing?.effectiveTo ?? '';
  late bool _active = widget.existing?.active ?? true;
  String? _error;
  bool _busy = false;

  static String _plain(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : '$v';
  static String _iso(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pick({required bool from}) async {
    final current = from ? _from : _to;
    final picked = await showDatePicker(
      context: context,
      initialDate: current.isEmpty ? DateTime.now() : DateTime.parse(current),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => from ? _from = _iso(picked) : _to = _iso(picked));
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amount.text.trim().replaceAll(',', ''));
    if (amount == null || amount < 0) {
      setState(() => _error = 'Enter the amount allowed per head (0 or more).');
      return;
    }
    if (_from.isNotEmpty && _to.isNotEmpty && _from.compareTo(_to) > 0) {
      setState(() => _error = 'The "from" date is after the "to" date.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final rule = FoodAllowanceRule(
      id: widget.existing?.id ?? '',
      meal: _meal,
      amountPerHead: amount,
      effectiveFrom: _from,
      effectiveTo: _to,
      active: _active,
      note: _note.text.trim(),
    );
    try {
      final service = ref.read(foodAllowanceServiceProvider);
      if (widget.existing == null) {
        await service.create(rule);
      } else {
        await service.update(widget.existing!.id, rule);
      }
      ref.refreshData.expenses();
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      // the server's own words — e.g. there is already an active lunch allowance for those dates
      if (mounted) {
        setState(() {
          _busy = false;
          _error = friendlyErrorMessage(e);
        });
      }
    }
  }

  Widget _dateField({required Key key, required String label, required String value, required VoidCallback onTap, required VoidCallback onClear}) => InkWell(
        key: key,
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            isDense: true,
            suffixIcon: value.isEmpty ? const Icon(Icons.calendar_today_outlined, size: 18) : IconButton(icon: const Icon(Icons.close, size: 18), onPressed: onClear),
          ),
          child: Text(value.isEmpty ? 'No limit' : _day(value)),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return AlertDialog(
      key: const Key('allowanceForm'),
      title: Text(widget.existing == null ? 'Add allowance' : 'Edit allowance'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<String>(
                key: const Key('allowanceMeal'),
                initialValue: _meal,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Meal', border: OutlineInputBorder(), isDense: true),
                items: [for (final m in kMeals) DropdownMenuItem(value: m.$1, child: Text(m.$2))],
                onChanged: (v) => setState(() => _meal = v ?? _meal),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('allowanceAmount'),
                controller: _amount,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Allowed per head (₹)', prefixIcon: Icon(Icons.currency_rupee, size: 18), border: OutlineInputBorder(), isDense: true),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _dateField(key: const Key('allowanceFrom'), label: 'From', value: _from, onTap: () => _pick(from: true), onClear: () => setState(() => _from = ''))),
                const SizedBox(width: 10),
                Expanded(child: _dateField(key: const Key('allowanceTo'), label: 'To', value: _to, onTap: () => _pick(from: false), onClear: () => setState(() => _to = ''))),
              ]),
              const SizedBox(height: 12),
              TextField(
                key: const Key('allowanceNote'),
                controller: _note,
                maxLength: 200,
                decoration: const InputDecoration(labelText: 'Note (optional)', border: OutlineInputBorder(), isDense: true, counterText: ''),
              ),
              SwitchListTile(
                key: const Key('allowanceActive'),
                contentPadding: EdgeInsets.zero,
                title: const Text('In use'),
                subtitle: const Text('Switch off to keep the rule but stop checking against it.'),
                value: _active,
                onChanged: (v) => setState(() => _active = v),
              ),
              if (_error != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(_error!, key: const Key('allowanceError'), style: TextStyle(color: crm.destructive, fontSize: 12.5))),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.of(context).pop(false), child: const Text('Cancel')),
        FilledButton(key: const Key('allowanceSave'), onPressed: _busy ? null : _save, child: Text(_busy ? 'Saving…' : 'Save')),
      ],
    );
  }
}
