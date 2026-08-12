import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:nizan_crm/core/extensions/space_extension.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/finance/data/aging_report.dart';
import 'package:nizan_crm/features/finance/controllers/accounting_provider.dart';
import 'package:nizan_crm/features/finance/presentation/widgets/party_statement_sheet.dart';
import 'package:nizan_crm/features/finance/utils/csv_export.dart';

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

  bool get _isReceivable => _kind == 'receivables';

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final async = ref.watch(agingProvider(_kind));
    final accent = _isReceivable ? const Color(0xFF0D9488) : const Color(0xFFB44A2C);

    return Scaffold(
      backgroundColor: crm.background,
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(agingProvider(_kind)),
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(children: [
            _toggle(crm, accent),
            Padding(padding: const EdgeInsets.all(40), child: Center(child: Text('$e', style: TextStyle(color: crm.destructive)))),
          ]),
          data: (r) => ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
            children: [
              _toggle(crm, accent),
              16.h,
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
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 6),
                  child: Row(children: [
                    Text('${_isReceivable ? 'CLIENTS' : 'VENDORS'} · ${r.parties.length}',
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
                for (final p in r.parties) _partyRow(crm, p),
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
          onTap: () => setState(() => _kind = kind),
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

  Widget _totalBanner(CrmTheme crm, AgingReport r, Color accent) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        Icon(_isReceivable ? Icons.account_balance_wallet_outlined : Icons.request_quote_outlined, color: accent, size: 26),
        14.w,
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_isReceivable ? 'Total owed to us' : 'Total we owe',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: crm.textSecondary)),
          2.h,
          Text(_money(r.totalOutstanding),
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: accent)),
        ]),
        const Spacer(),
        if (r.days90 > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: crm.destructive.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
            child: Text('${_money(r.days90)} · 90+ overdue',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: crm.destructive)),
          ),
      ]),
    );
  }

  Widget _bucketRow(CrmTheme crm, AgingReport r) {
    final items = [
      ('Current', r.current, crm.success),
      ('31–60', r.days30, const Color(0xFFB45309)),
      ('61–90', r.days60, const Color(0xFFC2410C)),
      ('90+', r.days90, crm.destructive),
    ];
    return Row(children: [
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
    ]);
  }

  Widget _partyRow(CrmTheme crm, AgingParty p) {
    final overdue = p.oldestDays > 90;
    final ageColor = p.oldestDays > 90
        ? crm.destructive
        : p.oldestDays > 60
            ? const Color(0xFFC2410C)
            : p.oldestDays > 30
                ? const Color(0xFFB45309)
                : crm.success;
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
                child: Text('${p.oldestDays}d', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: ageColor)),
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
    final rows = <List<Object?>>[
      ['$label Aging'],
      [partyLabel, 'Phone', 'Current', '31-60', '61-90', '90+', 'Outstanding', 'Oldest (days)'],
      for (final p in r.parties)
        [p.name, p.phone, csvNum(p.current), csvNum(p.days30), csvNum(p.days60), csvNum(p.days90), csvNum(p.outstanding), p.oldestDays],
      ['TOTAL', '', csvNum(r.current), csvNum(r.days30), csvNum(r.days60), csvNum(r.days90), csvNum(r.totalOutstanding), ''],
    ];
    try {
      await downloadCsv('${_kind}_aging.csv', rows);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$label aging exported')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    }
  }
}
