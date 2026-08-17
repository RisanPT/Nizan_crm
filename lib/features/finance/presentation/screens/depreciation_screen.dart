import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:nizan_crm/core/extensions/space_extension.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/finance/data/asset.dart';
import 'package:nizan_crm/features/finance/data/depreciation.dart';
import 'package:nizan_crm/features/finance/controllers/asset_provider.dart';
import 'package:nizan_crm/core/error/errors.dart';

String _money(num v) =>
    NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0).format(v);
String _date(DateTime? d) => d == null ? '—' : DateFormat('d MMM yyyy').format(d);

/// Finance → Depreciation. Shows what each depreciable asset is worth now and
/// posts the monthly depreciation charge to the ledger.
class DepreciationScreen extends ConsumerStatefulWidget {
  const DepreciationScreen({super.key});

  @override
  ConsumerState<DepreciationScreen> createState() => _DepreciationScreenState();
}

class _DepreciationScreenState extends ConsumerState<DepreciationScreen> {
  DateTime _asOf = DateTime.now();
  bool _busy = false;

  String get _asOfIso => DateTime(_asOf.year, _asOf.month, _asOf.day).toIso8601String();

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final async = ref.watch(depreciationScheduleProvider(_asOfIso));

    return Scaffold(
      backgroundColor: crm.background,
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(depreciationScheduleProvider(_asOfIso));
          ref.invalidate(depreciationRunsProvider);
        },
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(children: [
            Padding(padding: const EdgeInsets.all(40), child: Center(child: Text(friendlyErrorMessage(e), style: TextStyle(color: crm.destructive)))),
          ]),
          data: (s) => ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
            children: [
              _asOfBar(crm),
              12.h,
              _summaryCard(crm, s.totals),
              14.h,
              if (s.rows.isEmpty)
                _emptyHint(crm)
              else
                _scheduleTable(crm, s.rows),
              16.h,
              _runHistory(crm),
            ],
          ),
        ),
      ),
    );
  }

  Widget _asOfBar(CrmTheme crm) {
    return Row(children: [
      Expanded(
        child: InkWell(
          onTap: _busy ? null : _pickDate,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: crm.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: crm.border.withValues(alpha: 0.8)),
            ),
            child: Row(children: [
              Icon(Icons.event_outlined, size: 18, color: crm.textSecondary),
              10.w,
              Text('As of ${_date(_asOf)}',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: crm.textPrimary)),
              const Spacer(),
              Icon(Icons.edit_calendar_outlined, size: 16, color: crm.textSecondary),
            ]),
          ),
        ),
      ),
      10.w,
      FilledButton.icon(
        onPressed: _busy ? null : _run,
        icon: _busy
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.play_arrow_rounded, size: 20),
        label: const Text('Run'),
      ),
    ]);
  }

  Widget _summaryCard(CrmTheme crm, DepreciationTotals t) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: crm.border.withValues(alpha: 0.8)),
      ),
      child: Column(children: [
        Row(children: [
          _metric(crm, 'Cost', _money(t.totalCost), crm.textPrimary),
          _metric(crm, 'Depreciated', _money(t.totalAccumulated), const Color(0xFFB44A2C)),
          _metric(crm, 'Book value', _money(t.totalBookValue), const Color(0xFF0D9488)),
        ]),
        const Divider(height: 24),
        Row(children: [
          Icon(Icons.pending_actions_outlined, size: 18, color: crm.textSecondary),
          10.w,
          Expanded(
            child: Text('To post for this date',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: crm.textPrimary)),
          ),
          Text(_money(t.totalPeriodDepreciation),
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: t.totalPeriodDepreciation > 0 ? crm.textPrimary : crm.textSecondary)),
        ]),
      ]),
    );
  }

  Widget _metric(CrmTheme crm, String label, String value, Color color) {
    return Expanded(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label.toUpperCase(),
            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 0.4, color: crm.textSecondary)),
        4.h,
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: color)),
      ]),
    );
  }

  Widget _emptyHint(CrmTheme crm) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: crm.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: crm.border.withValues(alpha: 0.8)),
        ),
        child: Column(children: [
          Icon(Icons.trending_down_outlined, size: 40, color: crm.border),
          10.h,
          Text('No depreciable assets yet',
              style: TextStyle(fontWeight: FontWeight.w800, color: crm.textPrimary)),
          6.h,
          Text('Open an asset in Finance → Assets, turn on “Depreciate this asset”, '
              'and set a method, rate or useful life. It will then appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: crm.textSecondary)),
        ]),
      );

  Widget _scheduleTable(CrmTheme crm, List<DepreciationRow> rows) {
    return Container(
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: crm.border.withValues(alpha: 0.8)),
      ),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(color: crm.background.withValues(alpha: 0.4), borderRadius: const BorderRadius.vertical(top: Radius.circular(14))),
          child: Row(children: [
            Expanded(flex: 5, child: Text('ASSET', style: _hdr(crm))),
            Expanded(flex: 3, child: Text('COST', textAlign: TextAlign.right, style: _hdr(crm))),
            Expanded(flex: 3, child: Text('THIS RUN', textAlign: TextAlign.right, style: _hdr(crm))),
            Expanded(flex: 3, child: Text('BOOK', textAlign: TextAlign.right, style: _hdr(crm))),
          ]),
        ),
        for (final r in rows) _row(crm, r),
      ]),
    );
  }

  Widget _row(CrmTheme crm, DepreciationRow r) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(border: Border(top: BorderSide(color: crm.border.withValues(alpha: 0.4)))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            flex: 5,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(r.name, style: TextStyle(fontSize: 13, color: crm.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(
                  '${depreciationMethodLabel(r.method)}'
                  '${r.method == 'wdv' || r.usefulLifeYears == 0 ? ' · ${r.rate.toStringAsFixed(0)}%/yr' : ' · ${r.usefulLifeYears.toStringAsFixed(0)} yrs'}'
                  '${r.fullyDepreciated ? ' · fully depreciated' : ''}',
                  style: TextStyle(fontSize: 10.5, color: crm.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
            ]),
          ),
          Expanded(flex: 3, child: Text(_money(r.cost), textAlign: TextAlign.right, style: TextStyle(fontSize: 12.5, color: crm.textPrimary))),
          Expanded(
              flex: 3,
              child: Text(r.periodDepreciation > 0 ? _money(r.periodDepreciation) : '—',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: r.periodDepreciation > 0 ? const Color(0xFFB44A2C) : crm.textSecondary))),
          Expanded(
              flex: 3,
              child: Text(_money(r.bookValue),
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: const Color(0xFF0D9488)))),
        ]),
      );

  Widget _runHistory(CrmTheme crm) {
    final async = ref.watch(depreciationRunsProvider);
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (runs) {
        if (runs.isEmpty) return const SizedBox.shrink();
        return Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: crm.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: crm.border.withValues(alpha: 0.8)),
          ),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              initiallyExpanded: false,
              title: Text('Run history (${runs.length})',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: crm.textPrimary)),
              children: [
                for (final run in runs)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(children: [
                      Icon(Icons.check_circle_outline, size: 15, color: crm.success),
                      10.w,
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(_date(run.periodEnd),
                              style: TextStyle(fontSize: 12.5, color: crm.textPrimary)),
                          Text('${run.assetsAffected} asset${run.assetsAffected == 1 ? '' : 's'}${run.voucherNo.isEmpty ? '' : ' · ${run.voucherNo}'}',
                              style: TextStyle(fontSize: 10.5, color: crm.textSecondary)),
                        ]),
                      ),
                      Text(_money(run.totalAmount),
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: crm.textPrimary)),
                    ]),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  TextStyle _hdr(CrmTheme crm) => TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.4, color: crm.textSecondary);

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _asOf,
      firstDate: DateTime(2015),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _asOf = picked);
  }

  Future<void> _run() async {
    final messenger = ScaffoldMessenger.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Run depreciation?'),
        content: Text('This posts a depreciation voucher (Dr Depreciation, Cr Accumulated Depreciation) '
            'for all depreciable assets as of ${_date(_asOf)} and updates each asset’s book value.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Run')),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _busy = true);
    try {
      final res = await ref.read(assetServiceProvider).runDepreciation(asOf: _asOf);
      ref.invalidate(depreciationScheduleProvider(_asOfIso));
      ref.invalidate(depreciationRunsProvider);
      ref.invalidate(assetsProvider);
      ref.invalidate(assetStatsProvider);
      if (mounted) {
        messenger.showSnackBar(SnackBar(
          content: Text(res.posted
              ? 'Posted ${_money(res.total)} across ${res.assetsAffected} asset${res.assetsAffected == 1 ? '' : 's'} (${res.voucherNo})'
              : (res.message.isEmpty ? 'Nothing to post' : res.message)),
        ));
      }
    } catch (e) {
      if (mounted) messenger.showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
