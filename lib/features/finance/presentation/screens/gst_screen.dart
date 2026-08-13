import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:nizan_crm/core/extensions/space_extension.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/core/utils/file_saver.dart';
import 'package:nizan_crm/features/finance/data/gst_models.dart';
import 'package:nizan_crm/features/finance/controllers/accounting_provider.dart';
import 'package:nizan_crm/features/finance/presentation/widgets/date_filter_chip.dart';
import 'package:nizan_crm/features/finance/presentation/widgets/report_search_field.dart';
import 'package:nizan_crm/features/finance/presentation/widgets/show_more_button.dart';

String _money(num v) =>
    NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0).format(v);
String _n2(num v) => NumberFormat('#,##0.00', 'en_IN').format(v);
String _date(DateTime? d) => d == null ? '' : DateFormat('d MMM yy').format(d);

/// Finance → GST. Output − input = net payable, the GSTR-1 outward register,
/// and the studio's GST configuration.
class GstScreen extends ConsumerStatefulWidget {
  const GstScreen({super.key});

  @override
  ConsumerState<GstScreen> createState() => _GstScreenState();
}

class _GstScreenState extends ConsumerState<GstScreen> {
  DateTime? _from;
  DateTime? _to;
  String _search = '';
  int _visible = kFinancePageSize;

  String _iso(DateTime? d) => d == null ? '' : DateTime(d.year, d.month, d.day).toIso8601String();
  ({String from, String to}) get _range => (from: _iso(_from), to: _iso(_to));

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final summary = ref.watch(gstSummaryProvider(_range));
    final gstr1 = ref.watch(gstr1Provider(_range));

    return Scaffold(
      backgroundColor: crm.background,
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(gstSummaryProvider);
          ref.invalidate(gstr1Provider);
          ref.invalidate(gstSettingsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
          children: [
            Row(children: [
              Text('GST', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: crm.textPrimary)),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: () => showDialog(context: context, builder: (_) => const _GstSettingsDialog()),
                icon: const Icon(Icons.settings_outlined, size: 16),
                label: const Text('Settings'),
              ),
            ]),
            12.h,
            _periodBar(crm),
            12.h,
            summary.when(
              loading: () => const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
              error: (e, _) => Text('$e', style: TextStyle(color: crm.destructive)),
              data: (s) => _summaryCard(crm, s),
            ),
            18.h,
            gstr1.when(
              loading: () => const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
              error: (e, _) => Text('$e', style: TextStyle(color: crm.destructive)),
              data: (r) => _gstr1Section(context, crm, r),
            ),
          ],
        ),
      ),
    );
  }

  Widget _periodBar(CrmTheme crm) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        DateFilterChip(label: 'From', date: _from, onTap: () => _pick(true), onClear: () => setState(() => _from = null)),
        8.w,
        DateFilterChip(label: 'To', date: _to, onTap: () => _pick(false), onClear: () => setState(() => _to = null)),
      ]),
      8.h,
      Wrap(spacing: 8, runSpacing: 4, children: [
        _preset('This month', () => _setMonth(0)),
        _preset('Last month', () => _setMonth(-1)),
        _preset('This FY', _setFy),
        _preset('All time', () => setState(() {
              _from = null;
              _to = null;
            })),
      ]),
    ]);
  }

  Widget _preset(String label, VoidCallback onTap) => OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            textStyle: const TextStyle(fontSize: 12)),
        child: Text(label),
      );

  void _setMonth(int offset) {
    final now = DateTime.now();
    final first = DateTime(now.year, now.month + offset, 1);
    final last = DateTime(first.year, first.month + 1, 0); // last day of that month
    setState(() {
      _from = first;
      _to = last;
    });
  }

  void _setFy() {
    final now = DateTime.now();
    final startYear = now.month >= 4 ? now.year : now.year - 1; // Indian FY starts April
    setState(() {
      _from = DateTime(startYear, 4, 1);
      _to = DateTime(now.year, now.month, now.day);
    });
  }

  Future<void> _pick(bool from) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: (from ? _from : _to) ?? now,
      firstDate: DateTime(2015),
      lastDate: DateTime(now.year + 1),
    );
    if (picked != null) setState(() => from ? _from = picked : _to = picked);
  }

  Widget _summaryCard(CrmTheme crm, GstSummary s) {
    final payable = s.netPayable >= 0;
    final color = payable ? crm.destructive : crm.success;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: crm.border.withValues(alpha: 0.8)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(payable ? 'NET GST PAYABLE' : 'NET GST CREDIT (refundable)',
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: 0.5, color: crm.textSecondary)),
        4.h,
        Text(_money(s.netPayable.abs()), style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: color)),
        14.h,
        Divider(height: 1, color: crm.border.withValues(alpha: 0.6)),
        12.h,
        _row(crm, 'Output CGST', s.outputCgst),
        _row(crm, 'Output SGST', s.outputSgst),
        if (s.outputIgst != 0) _row(crm, 'Output IGST', s.outputIgst),
        _row(crm, 'Total output tax', s.totalOutput, bold: true),
        8.h,
        _row(crm, 'Input tax credit (ITC)', -s.inputCredit),
      ]),
    );
  }

  Widget _row(CrmTheme crm, String label, double v, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Expanded(child: Text(label, style: TextStyle(fontSize: 13, fontWeight: bold ? FontWeight.w800 : FontWeight.w500, color: crm.textPrimary))),
        Text(_money(v), style: TextStyle(fontSize: 13.5, fontWeight: bold ? FontWeight.w800 : FontWeight.w600, color: crm.textPrimary)),
      ]),
    );
  }

  Widget _gstr1Section(BuildContext context, CrmTheme crm, Gstr1Report r) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text('GSTR-1 · Outward supplies',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: crm.textPrimary)),
        8.w,
        if (r.rate > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(color: crm.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
            child: Text('${r.rate.toStringAsFixed(r.rate % 1 == 0 ? 0 : 1)}% · ${r.interState ? 'IGST' : 'CGST+SGST'}',
                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: crm.primary)),
          ),
        const Spacer(),
        if (r.rows.isNotEmpty)
          TextButton.icon(
            onPressed: () => _exportCsv(context, r),
            icon: const Icon(Icons.download_rounded, size: 16),
            label: const Text('CSV'),
          ),
      ]),
      8.h,
      // Totals card
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: crm.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: crm.border.withValues(alpha: 0.8)),
        ),
        child: Row(children: [
          _tot(crm, '${r.count}', 'Invoices', crm.primary),
          _tot(crm, _money(r.taxable), 'Taxable', crm.textPrimary),
          if (r.interState) _tot(crm, _money(r.igst), 'IGST', const Color(0xFF0D9488))
          else ...[
            _tot(crm, _money(r.cgst), 'CGST', const Color(0xFF0D9488)),
            _tot(crm, _money(r.sgst), 'SGST', const Color(0xFF0D9488)),
          ],
        ]),
      ),
      12.h,
      if (r.rows.isEmpty)
        Padding(padding: const EdgeInsets.all(16), child: Text('No outward supplies in this period.', style: TextStyle(color: crm.textSecondary)))
      else ...[
        ReportSearchField(
          hint: 'Search customer or invoice…',
          onChanged: (v) => setState(() {
            _search = v;
            _visible = kFinancePageSize;
          }),
        ),
        12.h,
        Builder(builder: (context) {
          final q = _search.trim().toLowerCase();
          final filtered = q.isEmpty
              ? r.rows
              : r.rows.where((row) => '${row.customer} ${row.invoiceNo}'.toLowerCase().contains(q)).toList();
          return Column(children: [
            Container(
              decoration: BoxDecoration(
                color: crm.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: crm.border.withValues(alpha: 0.8)),
              ),
              child: Column(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(color: crm.background.withValues(alpha: 0.4), borderRadius: const BorderRadius.vertical(top: Radius.circular(12))),
                  child: Row(children: [
                    Expanded(flex: 3, child: Text('INVOICE', style: _hdr(crm))),
                    Expanded(flex: 2, child: Text('TAXABLE', textAlign: TextAlign.right, style: _hdr(crm))),
                    Expanded(flex: 2, child: Text('TAX', textAlign: TextAlign.right, style: _hdr(crm))),
                  ]),
                ),
                for (final row in filtered.take(_visible))
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    decoration: BoxDecoration(border: Border(top: BorderSide(color: crm.border.withValues(alpha: 0.4)))),
                    child: Row(children: [
                      Expanded(
                        flex: 3,
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(row.customer.isEmpty ? (row.invoiceNo.isEmpty ? 'Booking' : row.invoiceNo) : row.customer,
                              style: TextStyle(fontSize: 12.5, color: crm.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
                          Text('${row.invoiceNo}${row.date != null ? ' · ${_date(row.date)}' : ''}',
                              style: TextStyle(fontSize: 10.5, color: crm.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ]),
                      ),
                      Expanded(flex: 2, child: Text(_money(row.taxable), textAlign: TextAlign.right, style: TextStyle(fontSize: 12.5, color: crm.textPrimary))),
                      Expanded(flex: 2, child: Text(_money(row.cgst + row.sgst + row.igst), textAlign: TextAlign.right, style: TextStyle(fontSize: 12.5, color: const Color(0xFF0D9488), fontWeight: FontWeight.w600))),
                    ]),
                  ),
              ]),
            ),
            ShowMoreButton(
              remaining: filtered.length - _visible,
              onPressed: () => setState(() => _visible += kFinancePageSize),
            ),
          ]);
        }),
      ],
    ]);
  }

  Widget _tot(CrmTheme crm, String value, String label, Color color) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: color))),
          2.h,
          Text(label, style: TextStyle(fontSize: 10.5, color: crm.textSecondary)),
        ]),
      );

  TextStyle _hdr(CrmTheme crm) => TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.4, color: crm.textSecondary);

  Future<void> _exportCsv(BuildContext context, Gstr1Report r) async {
    final messenger = ScaffoldMessenger.of(context);
    final b = StringBuffer('Invoice No,Customer,Date,Rate %,Taxable,CGST,SGST,IGST,Total\n');
    String esc(String s) => '"${s.replaceAll('"', '""')}"';
    for (final row in r.rows) {
      b.writeln([
        esc(row.invoiceNo),
        esc(row.customer),
        _date(row.date),
        row.rate.toString(),
        _n2(row.taxable),
        _n2(row.cgst),
        _n2(row.sgst),
        _n2(row.igst),
        _n2(row.total),
      ].join(','));
    }
    try {
      await saveFileBytes('gstr1.csv', Uint8List.fromList(utf8.encode(b.toString())), mime: 'text/csv');
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }
}

class _GstSettingsDialog extends ConsumerStatefulWidget {
  const _GstSettingsDialog();
  @override
  ConsumerState<_GstSettingsDialog> createState() => _GstSettingsDialogState();
}

class _GstSettingsDialogState extends ConsumerState<_GstSettingsDialog> {
  GstSettings? _s;
  final _rate = TextEditingController();
  final _gstin = TextEditingController();
  final _state = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _rate.dispose();
    _gstin.dispose();
    _state.dispose();
    super.dispose();
  }

  void _seed(GstSettings s) {
    if (_s != null) return;
    _s = s;
    _rate.text = s.rate.toStringAsFixed(s.rate % 1 == 0 ? 0 : 2);
    _gstin.text = s.gstin;
    _state.text = s.homeStateCode;
  }

  Future<void> _save() async {
    final s = _s!;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await ref.read(accountingServiceProvider).updateGstSettings(s.copyWith(
            rate: double.tryParse(_rate.text.trim()) ?? s.rate,
            gstin: _gstin.text.trim(),
            homeStateCode: _state.text.trim(),
          ));
      ref.invalidate(gstSettingsProvider);
      ref.invalidate(gstSummaryProvider);
      ref.invalidate(gstr1Provider);
      navigator.pop();
      messenger.showSnackBar(const SnackBar(content: Text('GST settings saved — re-sync the ledger to re-split existing sales.')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final async = ref.watch(gstSettingsProvider);
    return Dialog(
      backgroundColor: crm.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 440,
        padding: const EdgeInsets.all(22),
        child: async.when(
          loading: () => const SizedBox(height: 120, child: Center(child: CircularProgressIndicator())),
          error: (e, _) => Text('$e', style: TextStyle(color: crm.destructive)),
          data: (loaded) {
            _seed(loaded);
            final s = _s!;
            return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('GST Settings', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: crm.textPrimary)),
              16.h,
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: s.enabled,
                onChanged: (v) => setState(() => _s = s.copyWith(enabled: v)),
                title: const Text('Charge GST on sales', style: TextStyle(fontSize: 14)),
                subtitle: Text('Off = post revenue gross', style: TextStyle(fontSize: 11.5, color: crm.textSecondary)),
              ),
              8.h,
              TextField(
                controller: _rate,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'GST rate (%)', isDense: true),
              ),
              12.h,
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: s.pricesIncludeTax,
                onChanged: (v) => setState(() => _s = s.copyWith(pricesIncludeTax: v)),
                title: const Text('Prices include GST', style: TextStyle(fontSize: 14)),
                subtitle: Text(s.pricesIncludeTax ? 'Tax is backed out of the booking price' : 'Tax is added on top of the price',
                    style: TextStyle(fontSize: 11.5, color: crm.textSecondary)),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: s.interState,
                onChanged: (v) => setState(() => _s = s.copyWith(interState: v)),
                title: const Text('Inter-state (IGST)', style: TextStyle(fontSize: 14)),
                subtitle: Text(s.interState ? 'One IGST line' : 'Split into CGST + SGST', style: TextStyle(fontSize: 11.5, color: crm.textSecondary)),
              ),
              12.h,
              Row(children: [
                Expanded(child: TextField(controller: _gstin, decoration: const InputDecoration(labelText: 'GSTIN', isDense: true))),
                12.w,
                SizedBox(width: 110, child: TextField(controller: _state, decoration: const InputDecoration(labelText: 'State code', isDense: true))),
              ]),
              18.h,
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: const Text('Cancel')),
                8.w,
                ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(backgroundColor: crm.primary),
                  child: _saving
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Save', style: TextStyle(color: Colors.white)),
                ),
              ]),
            ]);
          },
        ),
      ),
    );
  }
}
