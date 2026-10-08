import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/core/widgets/date_pickers.dart';
import 'package:nizan_crm/features/dashboard/data/dashboard_analytics.dart' show kPackageFamilies;
import 'package:nizan_crm/features/sales/data/sales_target.dart';
import 'package:nizan_crm/features/sales/presentation/widgets/my_target_card.dart';
import 'package:nizan_crm/features/sales/services/sales_target_service.dart';

String _ymd(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String _rangeText(CombinedTarget t) {
  final f = DateFormat('d MMM');
  final s = t.start, e = t.end;
  if (s == e) return DateFormat('d MMM yyyy').format(s);
  return '${f.format(s)} – ${DateFormat('d MMM yyyy').format(e)}';
}

/// Combined (pool) targets for a month: shared goals every salesperson's
/// sales count toward. Managers can add / edit / delete; everyone sees the
/// team's progress (salespeople also see their own share).
class CombinedTargetsSection extends ConsumerWidget {
  final TargetPeriod period;
  final bool editable;

  /// Hide the whole section when there's nothing to show (for dashboards).
  final bool hideWhenEmpty;

  const CombinedTargetsSection({
    super.key,
    required this.period,
    this.editable = false,
    this.hideWhenEmpty = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crm = context.crmColors;
    final async = ref.watch(combinedTargetsProvider(period));
    final list = async.value ?? const <CombinedTarget>[];
    if (hideWhenEmpty && list.isEmpty) return const SizedBox.shrink();

    final title = Row(children: [
      Icon(Icons.groups_rounded, size: 20, color: crm.primary),
      const SizedBox(width: 8),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Combined targets',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: crm.textPrimary)),
          Text('Shared goals — every salesperson’s sales count toward them.',
              style: TextStyle(fontSize: 12, color: crm.textSecondary)),
        ]),
      ),
    ]);
    final add = FilledButton.tonalIcon(
      onPressed: () => showCombinedTargetDialog(context, ref, period: period),
      icon: const Icon(Icons.add_rounded, size: 18),
      label: const Text('Add combined target'),
    );

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (!editable)
        title
      else
        // The button drops under the title on phones.
        LayoutBuilder(
          builder: (context, c) => c.maxWidth < 560
              ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  title,
                  const SizedBox(height: 8),
                  add,
                ])
              : Row(children: [Expanded(child: title), add]),
        ),
      const SizedBox(height: 12),
      async.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => AppErrorView(
          error: e,
          compact: true,
          onRetry: () => ref.invalidate(combinedTargetsProvider(period)),
        ),
        data: (targets) => targets.isEmpty
            ? Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: crm.input, borderRadius: BorderRadius.circular(12)),
                child: Text(
                  editable
                      ? 'No combined targets this month. Add one for a team goal like “₹10L in Diwali week” or “20 Airbrush bookings”.'
                      : 'No combined targets this month.',
                  style: TextStyle(fontSize: 13, color: crm.textSecondary),
                ),
              )
            : LayoutBuilder(builder: (context, c) {
                final per = c.maxWidth >= 900 ? 2 : 1;
                final w = (c.maxWidth - 12 * (per - 1)) / per;
                return Wrap(spacing: 12, runSpacing: 12, children: [
                  for (final t in targets)
                    SizedBox(
                      width: w,
                      child: _CombinedCard(t: t, period: period, editable: editable),
                    ),
                ]);
              }),
      ),
    ]);
  }
}

class _CombinedCard extends ConsumerWidget {
  final CombinedTarget t;
  final TargetPeriod period;
  final bool editable;
  const _CombinedCard({required this.t, required this.period, required this.editable});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crm = context.crmColors;
    final pct = t.pct;
    final color = t.status == 'upcoming' ? crm.textSecondary : targetStatusColor(pct, expectedPct: t.elapsed);
    final valuePct = t.salesTarget > 0 ? t.achieved.salesValue / t.salesTarget : null;
    final countPct = t.bookingsTarget > 0 ? t.achieved.bookings / t.bookingsTarget : null;

    Widget bar(String label, String done, String goal, double p) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Flexible(
                child: Text(label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: crm.textSecondary)),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(text: done, style: TextStyle(fontWeight: FontWeight.w800, color: crm.textPrimary)),
                    TextSpan(text: ' / $goal', style: TextStyle(fontSize: 12, color: crm.textSecondary)),
                  ]),
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ]),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: p.clamp(0, 1).toDouble(),
                minHeight: 8,
                backgroundColor: color.withValues(alpha: 0.12),
                color: color,
              ),
            ),
          ],
        );

    final statusText = switch (t.status) {
      'upcoming' => 'Starts ${DateFormat('d MMM').format(t.start)}',
      'ended' => pct >= 1 ? 'Achieved 🎉' : 'Ended at ${(pct * 100).toStringAsFixed(0)}%',
      _ => pct >= 1 ? 'Achieved 🎉' : '${t.daysLeft} day${t.daysLeft == 1 ? '' : 's'} left',
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: crm.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t.title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: crm.textPrimary)),
              const SizedBox(height: 4),
              Wrap(spacing: 6, runSpacing: 4, children: [
                _chip(crm, Icons.date_range_rounded, _rangeText(t)),
                _chip(crm, Icons.inventory_2_outlined, t.service.isEmpty ? 'All packages' : t.service),
                _chip(crm, Icons.schedule_rounded, statusText, color: color),
              ]),
            ]),
          ),
          Text('${(pct * 100).toStringAsFixed(0)}%',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: color)),
          if (editable)
            PopupMenuButton<String>(
              tooltip: 'More',
              onSelected: (v) async {
                if (v == 'edit') {
                  await showCombinedTargetDialog(context, ref, period: period, existing: t);
                } else if (v == 'delete') {
                  await _delete(context, ref);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
        ]),
        const SizedBox(height: 12),
        if (valuePct != null) ...[
          bar('Sales value', targetRupees(t.achieved.salesValue), targetRupees(t.salesTarget), valuePct),
          const SizedBox(height: 10),
        ],
        if (countPct != null) ...[
          bar('Bookings', '${t.achieved.bookings}', '${t.bookingsTarget}', countPct),
          const SizedBox(height: 10),
        ],
        if (editable) ...[
          Text('${t.contributors} contributor${t.contributors == 1 ? '' : 's'}',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: crm.textSecondary)),
          const SizedBox(height: 4),
          if (t.contributions.isEmpty)
            Text('No sales yet.', style: TextStyle(fontSize: 12, color: crm.textSecondary))
          else
            for (final c in t.contributions.take(5)) _contribution(crm, c),
          if (t.contributions.length > 5)
            Text('+ ${t.contributions.length - 5} more', style: TextStyle(fontSize: 11.5, color: crm.textSecondary)),
        ] else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(color: crm.input, borderRadius: BorderRadius.circular(10)),
            child: Text(
              'Your share: ${targetRupees(t.mine.salesValue)} · ${t.mine.bookings} booking${t.mine.bookings == 1 ? '' : 's'}'
              '${t.achieved.salesValue > 0 && t.salesTarget > 0 ? ' (${(t.mine.salesValue / t.achieved.salesValue * 100).toStringAsFixed(0)}% of the team’s)' : ''}',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: crm.textPrimary),
            ),
          ),
        if (t.note.isNotEmpty || t.setByName.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            [if (t.note.isNotEmpty) '“${t.note}”', if (t.setByName.isNotEmpty) 'Set by ${t.setByName}'].join(' — '),
            style: TextStyle(fontSize: 11.5, fontStyle: FontStyle.italic, color: crm.textSecondary),
          ),
        ],
      ]),
    );
  }

  Widget _contribution(CrmTheme crm, CombinedContribution c) {
    final share = t.salesTarget > 0
        ? (t.achieved.salesValue == 0 ? 0.0 : c.salesValue / t.achieved.salesValue)
        : (t.achieved.bookings == 0 ? 0.0 : c.bookings / t.achieved.bookings);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        SizedBox(
          width: 110,
          child: Text(c.name, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: crm.textPrimary)),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: share.clamp(0, 1).toDouble(),
              minHeight: 5,
              backgroundColor: crm.input,
              color: crm.primary,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          t.salesTarget > 0 ? targetRupeesShort(c.salesValue) : '${c.bookings}',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: crm.textPrimary),
        ),
      ]),
    );
  }

  Widget _chip(CrmTheme crm, IconData icon, String text, {Color? color}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: (color ?? crm.textSecondary).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 12, color: color ?? crm.textSecondary),
          const SizedBox(width: 4),
          Flexible(
            child: Text(text,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: color ?? crm.textSecondary)),
          ),
        ]),
      );

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete combined target?'),
        content: Text('“${t.title}” will be removed for everyone. Bookings are not affected.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(salesTargetServiceProvider).deleteCombined(t.id);
      ref.invalidate(combinedTargetsProvider);
    } catch (e) {
      if (context.mounted) showErrorSnackBar(context, e);
    }
  }
}

/// Create (or edit [existing]) a combined target. Defaults to the whole of
/// [period]'s month.
Future<void> showCombinedTargetDialog(
  BuildContext context,
  WidgetRef ref, {
  required TargetPeriod period,
  CombinedTarget? existing,
}) =>
    showDialog<void>(
      context: context,
      builder: (_) => _CombinedTargetDialog(period: period, existing: existing),
    );

class _CombinedTargetDialog extends ConsumerStatefulWidget {
  final TargetPeriod period;
  final CombinedTarget? existing;
  const _CombinedTargetDialog({required this.period, this.existing});

  @override
  ConsumerState<_CombinedTargetDialog> createState() => _CombinedTargetDialogState();
}

class _CombinedTargetDialogState extends ConsumerState<_CombinedTargetDialog> {
  late final _title = TextEditingController(text: widget.existing?.title ?? '');
  late final _value = TextEditingController(
      text: (widget.existing?.salesTarget ?? 0) > 0 ? widget.existing!.salesTarget.round().toString() : '');
  late final _count = TextEditingController(
      text: (widget.existing?.bookingsTarget ?? 0) > 0 ? '${widget.existing!.bookingsTarget}' : '');
  late final _note = TextEditingController(text: widget.existing?.note ?? '');
  late DateTimeRange _range = widget.existing != null
      ? DateTimeRange(start: widget.existing!.start, end: widget.existing!.end)
      : DateTimeRange(
          start: DateTime(widget.period.year, widget.period.month, 1),
          end: DateTime(widget.period.year, widget.period.month + 1, 0),
        );
  late String _service = widget.existing?.service ?? '';
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _value.dispose();
    _count.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickRange() async {
    final picked = await showBrandedDateRangePicker(
      context,
      initialDateRange: _range,
      firstDate: DateTime(2024),
      lastDate: DateTime(DateTime.now().year + 2, 12, 31),
      helpText: 'Target window',
    );
    if (picked != null) setState(() => _range = picked);
  }

  Future<void> _save() async {
    final value = double.tryParse(_value.text.trim()) ?? 0;
    final count = int.tryParse(_count.text.trim()) ?? 0;
    if (_title.text.trim().isEmpty) {
      setState(() => _error = 'Give the target a name.');
      return;
    }
    if (value <= 0 && count <= 0) {
      setState(() => _error = 'Set a sales value, a number of bookings, or both.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(salesTargetServiceProvider).saveCombined(
            CombinedTargetInput(
              title: _title.text.trim(),
              startDay: _ymd(_range.start),
              endDay: _ymd(_range.end),
              salesTarget: value,
              bookingsTarget: count,
              service: _service,
              note: _note.text.trim(),
            ),
            id: widget.existing?.id,
          );
      ref.invalidate(combinedTargetsProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _error = friendlyErrorMessage(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final f = DateFormat('d MMM yyyy');
    return AlertDialog(
      title: Text(widget.existing == null ? 'Add combined target' : 'Edit combined target'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('A shared goal for the whole sales team — everyone’s bookings in the window count.',
                style: TextStyle(fontSize: 12.5, color: crm.textSecondary)),
            const SizedBox(height: 14),
            TextField(
              controller: _title,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Name', hintText: 'e.g. Diwali week push'),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: _pickRange,
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Dates', suffixIcon: Icon(Icons.date_range_rounded)),
                child: Text('${f.format(_range.start)} – ${f.format(_range.end)}'),
              ),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _value,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(labelText: 'Sales value', prefixText: '₹ ', hintText: 'optional'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _count,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(labelText: 'Bookings', hintText: 'optional'),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _service,
              decoration: const InputDecoration(labelText: 'Package'),
              items: [
                const DropdownMenuItem(value: '', child: Text('All packages')),
                for (final p in {...kPackageFamilies, if (_service.isNotEmpty) _service})
                  DropdownMenuItem(value: p, child: Text(p)),
              ],
              onChanged: (v) => setState(() => _service = v ?? ''),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _note,
              decoration: const InputDecoration(labelText: 'Note (optional)', hintText: 'e.g. bonus for the team if hit'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: crm.destructive, fontSize: 12.5)),
            ],
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(widget.existing == null ? 'Add target' : 'Save'),
        ),
      ],
    );
  }
}
