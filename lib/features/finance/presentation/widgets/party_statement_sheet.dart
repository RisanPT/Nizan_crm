import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:nizan_crm/core/extensions/space_extension.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/finance/data/aging_report.dart';
import 'package:nizan_crm/features/finance/controllers/accounting_provider.dart';

String _money(num v) =>
    NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0).format(v);
String _date(DateTime? d) => d == null ? '—' : DateFormat('d MMM yy').format(d);

/// Open a party's statement of account (their bookings or bills with a running
/// balance) as a scrollable bottom sheet.
Future<void> showPartyStatement(
  BuildContext context, {
  required String kind,
  required String name,
  String phone = '',
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _PartyStatementSheet(kind: kind, name: name, phone: phone),
  );
}

class _PartyStatementSheet extends ConsumerWidget {
  const _PartyStatementSheet({required this.kind, required this.name, required this.phone});
  final String kind;
  final String name;
  final String phone;

  bool get _isReceivable => kind == 'receivables';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crm = context.crmColors;
    final accent = _isReceivable ? const Color(0xFF0D9488) : const Color(0xFFB44A2C);
    final async = ref.watch(partyStatementProvider((kind: kind, name: name, phone: phone)));

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: crm.background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(children: [
          8.h,
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(color: crm.border, borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
            child: Row(children: [
              Icon(_isReceivable ? Icons.call_received_rounded : Icons.call_made_rounded, color: accent, size: 20),
              10.w,
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(name, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: crm.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text('Statement of account${phone.isNotEmpty ? ' · $phone' : ''}',
                      style: TextStyle(fontSize: 12, color: crm.textSecondary)),
                ]),
              ),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, size: 20)),
            ]),
          ),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('$e', style: TextStyle(color: crm.destructive)))),
              data: (s) => _body(crm, accent, s, scrollController),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _body(CrmTheme crm, Color accent, PartyStatement s, ScrollController controller) {
    return ListView(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        // Summary
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: accent.withValues(alpha: 0.3)),
          ),
          child: Row(children: [
            _sumCol(crm, _isReceivable ? 'Invoiced' : 'Billed', s.invoicedTotal, crm.textPrimary),
            _sumCol(crm, _isReceivable ? 'Received' : 'Paid', s.receivedTotal, const Color(0xFF0D9488)),
            _sumCol(crm, 'Outstanding', s.outstanding, accent),
          ]),
        ),
        14.h,
        if (s.rows.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 30),
            child: Center(child: Text('No transactions found', style: TextStyle(color: crm.textSecondary))),
          )
        else
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
                  Expanded(flex: 5, child: Text('PARTICULARS', style: _hdr(crm))),
                  Expanded(flex: 3, child: Text(_isReceivable ? 'INVOICED' : 'BILLED', textAlign: TextAlign.right, style: _hdr(crm))),
                  Expanded(flex: 3, child: Text(_isReceivable ? 'RECEIVED' : 'PAID', textAlign: TextAlign.right, style: _hdr(crm))),
                  Expanded(flex: 3, child: Text('BALANCE', textAlign: TextAlign.right, style: _hdr(crm))),
                ]),
              ),
              for (final r in s.rows)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(border: Border(top: BorderSide(color: crm.border.withValues(alpha: 0.4)))),
                  child: Row(children: [
                    Expanded(
                      flex: 5,
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(r.description, style: TextStyle(fontSize: 12.5, color: crm.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
                        Text(_date(r.date), style: TextStyle(fontSize: 10.5, color: crm.textSecondary)),
                      ]),
                    ),
                    Expanded(flex: 3, child: Text(r.invoiced > 0 ? _money(r.invoiced) : '—', textAlign: TextAlign.right, style: TextStyle(fontSize: 12, color: crm.textPrimary))),
                    Expanded(flex: 3, child: Text(r.received > 0 ? _money(r.received) : '—', textAlign: TextAlign.right, style: const TextStyle(fontSize: 12, color: Color(0xFF0D9488)))),
                    Expanded(flex: 3, child: Text(_money(r.runningBalance), textAlign: TextAlign.right, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: crm.textPrimary))),
                  ]),
                ),
            ]),
          ),
      ],
    );
  }

  Widget _sumCol(CrmTheme crm, String label, double v, Color color) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.3, color: crm.textSecondary)),
          3.h,
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(_money(v), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: color)),
          ),
        ]),
      );

  TextStyle _hdr(CrmTheme crm) => TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.4, color: crm.textSecondary);
}
