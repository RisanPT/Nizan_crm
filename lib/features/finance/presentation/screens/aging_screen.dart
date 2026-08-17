import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:nizan_crm/core/extensions/space_extension.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/finance/data/aging_report.dart';
import 'package:nizan_crm/features/finance/controllers/accounting_provider.dart';
import 'package:nizan_crm/features/finance/presentation/widgets/date_filter_chip.dart';
import 'package:nizan_crm/features/finance/presentation/widgets/party_statement_sheet.dart';
import 'package:nizan_crm/features/finance/presentation/widgets/report_search_field.dart';
import 'package:nizan_crm/features/finance/presentation/widgets/show_more_button.dart';
import 'package:nizan_crm/features/finance/utils/csv_export.dart';
import 'package:nizan_crm/core/error/errors.dart';

String _money(num v) =>
    NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0).format(v);

/// Finance → Receivables & Payables aging. Who owes us / whom we owe, aged into
/// 0–30 / 31–60 / 61–90 / 90+ buckets.
class AgingScreen extends ConsumerStatefulWidget {
  const AgingScreen({super.key});

  @override
  ConsumerState<AgingScreen> createState() => _AgingScreenState();
}

class _AgingScreenState extends ConsumerState<AgingScreen> {
  String _kind = 'receivables';
  String _search = '';
  int _visible = kFinancePageSize;
  DateTime? _asOf; // null = today

  bool get _isReceivable => _kind == 'receivables';

  String get _asOfIso => _asOf == null ? '' : DateFormat('yyyy-MM-dd').format(_asOf!);

  ({String kind, String asOf}) get _key => (kind: _kind, asOf: _asOfIso);

  List<AgingParty> _filteredParties(AgingReport r) {
    final q = _search.trim().toLowerCase();
    if (q.isEmpty) return r.parties;
    return r.parties.where((p) => '${p.name} ${p.phone}'.toLowerCase().contains(q)).toList();
  }

  Future<void> _pickAsOf() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _asOf ?? now,
      firstDate: DateTime(2015),
      lastDate: DateTime(now.year + 2, 12, 31),
    );
    if (picked != null) {
      setState(() {
        _asOf = picked;
        _visible = kFinancePageSize;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final async = ref.watch(agingProvider(_key));
    final accent = _isReceivable ? const Color(0xFF0D9488) : const Color(0xFFB44A2C);

    return Scaffold(
      backgroundColor: crm.background,
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(agingProvider(_key)),
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(children: [
            _toggle(crm, accent),
            Padding(padding: const EdgeInsets.all(40), child: Center(child: Text(friendlyErrorMessage(e), style: TextStyle(color: crm.destructive)))),
          ]),
          data: (r) => ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
            children: [
              _toggle(crm, accent),
              12.h,
              _asOfRow(crm),
              14.h,
              _totalBanner(crm, r, accent),
              14.h,
              _bucketRow(crm, r),
              16.h,
              if (r.parties.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 40),
                  child: Center(
                    child: Column(children: [
                      Icon(_isReceivable ? Icons.check_circle_outline : Icons.inbox_outlined, size: 52, color: crm.border),
                      12.h,
                      Text(_isReceivable ? 'Nothing outstanding — all collected' : 'No unpaid bills',
                          style: TextStyle(color: crm.textSecondary)),
                    ]),
                  ),
                )
              else ...[
                ReportSearchField(
                  hint: _isReceivable ? 'Search a client…' : 'Search a vendor…',
                  onChanged: (v) => setState(() {
                    _search = v;
                    _visible = kFinancePageSize;
                  }),
                ),
                10.h,
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 6),
                  child: Row(children: [
                    Text('${_isReceivable ? 'CLIENTS' : 'VENDORS'} · ${_filteredParties(r).length}',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.6, color: crm.textSecondary)),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () => _exportCsv(r),
                      icon: const Icon(Icons.download_outlined, size: 17),
                      label: const Text('Export CSV'),
                      style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8), visualDensity: VisualDensity.compact),
                    ),
                  ]),
                ),
                for (final p in _filteredParties(r).take(_visible)) _partyRow(crm, p),
                ShowMoreButton(
                  remaining: _filteredParties(r).length - _visible,
                  onPressed: () => setState(() => _visible += kFinancePageSize),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _toggle(CrmTheme crm, Color accent) {
    Widget seg(String kind, String label, IconData icon) {
      final on = _kind == kind;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() {
            _kind = kind;
            _visible = kFinancePageSize;
          }),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 11),
            decoration: BoxDecoration(
              color: on ? crm.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(icon, size: 16, color: on ? Colors.white : crm.textSecondary),
              8.w,
              Text(label, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: on ? Colors.white : crm.textSecondary)),
            ]),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: crm.border.withValues(alpha: 0.7)),
      ),
      child: Row(children: [
        seg('receivables', 'Receivables', Icons.call_received_rounded),
        seg('payables', 'Payables', Icons.call_made_rounded),
      ]),
    );
  }

  Widget _asOfRow(CrmTheme crm) {
    return Row(children: [
      Text('Aged as on', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: crm.textSecondary)),
      8.w,
      DateFilterChip(
        label: 'As on',
        date: _asOf,
        onTap: _pickAsOf,
        onClear: _asOf == null ? null : () => setState(() {
          _asOf = null;
          _visible = kFinancePageSize;
        }),
      ),
      const Spacer(),
      if (_asOf == null)
        Text('Today', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: crm.textSecondary)),
    ]);
  }

  Widget _totalBanner(CrmTheme crm, AgingReport r, Color accent) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(_isReceivable ? Icons.account_balance_wallet_outlined : Icons.request_quote_outlined, color: accent, size: 26),
          14.w,
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_isReceivable ? 'Total owed to us' : 'Total we owe',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: crm.textSecondary)),
            2.h,
            Text(_money(r.totalOutstanding),
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: accent)),
          ]),
        ]),
        14.h,
        Row(children: [
          Expanded(child: _totalChip(crm, 'Overdue', r.totalOverdue, crm.destructive, emphasize: true)),
          10.w,
          Expanded(child: _totalChip(crm, 'Not yet due', r.totalNotYetDue, crm.textSecondary)),
        ]),
      ]),
    );
  }

  Widget _totalChip(CrmTheme crm, String label, double value, Color color, {bool emphasize = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: emphasize ? color.withValues(alpha: 0.12) : crm.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: emphasize ? color.withValues(alpha: 0.35) : crm.border.withValues(alpha: 0.6)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
        4.h,
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(_money(value),
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: emphasize ? color : crm.textPrimary)),
        ),
      ]),
    );
  }

  Widget _bucketRow(CrmTheme crm, AgingReport r) {
    final items = [
      ('0–30', r.current, crm.success),
      ('31–60', r.days30, const Color(0xFFB45309)),
      ('61–90', r.days60, const Color(0xFFC2410C)),
      ('90+', r.days90, crm.destructive),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 6),
        child: Text('OVERDUE — DAYS PAST DUE',
            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 0.6, color: crm.textSecondary)),
      ),
      Row(children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) 10.w,
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: crm.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: crm.border.withValues(alpha: 0.6)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(items[i].$1, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: items[i].$3)),
                6.h,
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(_money(items[i].$2),
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: crm.textPrimary)),
                ),
              ]),
            ),
          ),
        ],
      ]),
    ]);
  }

  Widget _partyRow(CrmTheme crm, AgingParty p) {
    final overdue = p.oldestDays > 90;
    final notDue = p.overdue <= 0.5; // nothing past due — balance is still upcoming
    final ageColor = notDue
        ? crm.textSecondary
        : p.oldestDays > 90
            ? crm.destructive
            : p.oldestDays > 60
                ? const Color(0xFFC2410C)
                : p.oldestDays > 30
                    ? const Color(0xFFB45309)
                    : crm.success;
    final ageLabel = notDue ? 'Not due' : '${p.oldestDays}d';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: crm.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => showPartyStatement(context, kind: _kind, name: p.name, phone: p.phone),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: overdue ? crm.destructive.withValues(alpha: 0.35) : crm.border.withValues(alpha: 0.7)),
            ),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(p.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                  2.h,
                  Text('${p.count} ${_isReceivable ? 'booking' : 'bill'}${p.count == 1 ? '' : 's'}'
                      '${p.phone.isNotEmpty ? ' · ${p.phone}' : ''}',
                      style: TextStyle(fontSize: 12, color: crm.textSecondary)),
                ]),
              ),
              8.w,
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: ageColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
                child: Text(ageLabel, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: ageColor)),
              ),
              10.w,
              Text(_money(p.outstanding), style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: crm.textPrimary)),
              4.w,
              Icon(Icons.chevron_right, size: 18, color: crm.textSecondary),
            ]),
          ),
        ),
      ),
    );
  }

  Future<void> _exportCsv(AgingReport r) async {
    final label = _isReceivable ? 'Receivables' : 'Payables';
    final partyLabel = _isReceivable ? 'Client' : 'Vendor';
    final asOn = DateFormat('d MMM yyyy').format(r.asOf ?? _asOf ?? DateTime.now());
    final rows = <List<Object?>>[
      ['$label Aging'],
      ['As on', asOn],
      [partyLabel, 'Phone', 'Not yet due', '0-30', '31-60', '61-90', '90+', 'Overdue', 'Outstanding', 'Oldest overdue (days)'],
      for (final p in r.parties)
        [p.name, p.phone, csvNum(p.notYetDue), csvNum(p.current), csvNum(p.days30), csvNum(p.days60), csvNum(p.days90), csvNum(p.overdue), csvNum(p.outstanding), p.oldestDays],
      ['TOTAL', '', csvNum(r.totalNotYetDue), csvNum(r.current), csvNum(r.days30), csvNum(r.days60), csvNum(r.days90), csvNum(r.totalOverdue), csvNum(r.totalOutstanding), ''],
    ];
    try {
      await downloadCsv('${_kind}_aging.csv', rows);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$label aging exported')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
      }
    }
  }
}
