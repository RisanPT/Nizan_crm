import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/providers/dio_provider.dart';

final _inr = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
final _iso = DateFormat('yyyy-MM-dd');
double _d(dynamic v) => (v as num?)?.toDouble() ?? 0;

class CashFlowItem {
  final String code, name;
  final double moneyIn, moneyOut, net;
  CashFlowItem(Map<String, dynamic> j)
      : code = j['code']?.toString() ?? '',
        name = j['name']?.toString() ?? '',
        moneyIn = _d(j['in']),
        moneyOut = _d(j['out']),
        net = _d(j['net']);
}

class CashFlowSection {
  final String label;
  final double inflow, outflow, net;
  final List<CashFlowItem> items;
  CashFlowSection(Map<String, dynamic> j)
      : label = j['label']?.toString() ?? '',
        inflow = _d(j['inflow']),
        outflow = _d(j['outflow']),
        net = _d(j['net']),
        items = ((j['items'] as List?) ?? const []).map((e) => CashFlowItem((e as Map).cast<String, dynamic>())).toList();
}

class CashFlowAccount {
  final String code, name;
  final double opening, moneyIn, moneyOut, closing;
  CashFlowAccount(Map<String, dynamic> j)
      : code = j['code']?.toString() ?? '',
        name = j['name']?.toString() ?? '',
        opening = _d(j['opening']),
        moneyIn = _d(j['in']),
        moneyOut = _d(j['out']),
        closing = _d(j['closing']);
}

class LedgerCashFlow {
  final double opening, inflow, outflow, net, closing, transfers;
  final List<CashFlowSection> sections;
  final List<CashFlowAccount> accounts;
  LedgerCashFlow(Map<String, dynamic> j)
      : opening = _d(j['opening']),
        inflow = _d(j['inflow']),
        outflow = _d(j['outflow']),
        net = _d(j['net']),
        closing = _d(j['closing']),
        transfers = _d(j['transfers']),
        sections = ((j['sections'] as List?) ?? const []).map((e) => CashFlowSection((e as Map).cast<String, dynamic>())).toList(),
        accounts = ((j['accounts'] as List?) ?? const []).map((e) => CashFlowAccount((e as Map).cast<String, dynamic>())).toList();
}

final ledgerCashFlowProvider =
    FutureProvider.autoDispose.family<LedgerCashFlow, ({String from, String to})>((ref, r) async {
  try {
    final res = await ref.watch(dioProvider).get('/accounting/cash-flow', queryParameters: {
      if (r.from.isNotEmpty) 'from': r.from,
      if (r.to.isNotEmpty) 'to': r.to,
    });
    return LedgerCashFlow((res.data as Map).cast<String, dynamic>());
  } catch (e) {
    throw AppException(e, action: 'load the cash flow');
  }
});

/// Cash flow straight from the books: opening cash & bank, money in / out by
/// operating / investing / financing (direct method over the ledger), and
/// closing balance per Cash / Bank ledger. Matches the Trial Balance and the
/// ledgers, unlike the operational view.
class LedgerCashFlowView extends ConsumerWidget {
  const LedgerCashFlowView({super.key, this.from, this.to, required this.header});

  final DateTime? from;
  final DateTime? to;

  /// Widgets shown above the statement (title, view toggle).
  final List<Widget> header;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crm = context.crmColors;
    final key = (from: from == null ? '' : _iso.format(from!), to: to == null ? '' : _iso.format(to!));
    final async = ref.watch(ledgerCashFlowProvider(key));

    Widget line(String label, double v, {bool bold = false, Color? color}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            Expanded(
              child: Text(label,
                  style: TextStyle(fontSize: 13.5, fontWeight: bold ? FontWeight.w800 : FontWeight.w500, color: crm.textPrimary)),
            ),
            Text(_inr.format(v),
                style: TextStyle(fontSize: 13.5, fontWeight: bold ? FontWeight.w800 : FontWeight.w600, color: color ?? crm.textPrimary)),
          ]),
        );

    Widget card(List<Widget> children) => Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: crm.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: crm.border),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
        );

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(ledgerCashFlowProvider(key)),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          ...header,
          async.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 60),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => AppErrorView(error: e, onRetry: () => ref.invalidate(ledgerCashFlowProvider(key))),
            data: (cf) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              card([
                line('Opening cash & bank', cf.opening),
                line('+ Money in', cf.inflow, color: crm.success),
                line('− Money out', cf.outflow, color: crm.destructive),
                Divider(color: crm.border),
                line('Closing cash & bank', cf.closing, bold: true),
                const SizedBox(height: 4),
                Text(
                  'Net cash flow ${_inr.format(cf.net)}'
                  '${cf.transfers > 0 ? ' · ${_inr.format(cf.transfers)} moved between own accounts (not counted)' : ''}',
                  style: TextStyle(fontSize: 12, color: crm.textSecondary),
                ),
              ]),
              for (final s in cf.sections)
                card([
                  Row(children: [
                    Expanded(
                      child: Text(s.label,
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: crm.textPrimary)),
                    ),
                    Text(_inr.format(s.net),
                        style: TextStyle(
                            fontWeight: FontWeight.w800, color: s.net >= 0 ? crm.success : crm.destructive)),
                  ]),
                  const SizedBox(height: 8),
                  if (s.items.isEmpty)
                    Text('No movement.', style: TextStyle(fontSize: 12, color: crm.textSecondary))
                  else
                    for (final i in s.items)
                      line('${i.code} · ${i.name}', i.net, color: i.net >= 0 ? crm.success : crm.destructive),
                  Divider(color: crm.border),
                  Row(children: [
                    Text('In ${_inr.format(s.inflow)}', style: TextStyle(fontSize: 12, color: crm.textSecondary)),
                    const Spacer(),
                    Text('Out ${_inr.format(s.outflow)}', style: TextStyle(fontSize: 12, color: crm.textSecondary)),
                  ]),
                ]),
              card([
                Text('By account', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: crm.textPrimary)),
                const SizedBox(height: 8),
                for (final a in cf.accounts) ...[
                  Text('${a.code} · ${a.name}', style: TextStyle(fontWeight: FontWeight.w700, color: crm.textPrimary)),
                  Text(
                    'Opening ${_inr.format(a.opening)}  + ${_inr.format(a.moneyIn)}  − ${_inr.format(a.moneyOut)}'
                    '  = ${_inr.format(a.closing)}',
                    style: TextStyle(fontSize: 12, color: crm.textSecondary),
                  ),
                  const SizedBox(height: 8),
                ],
                Text(
                  'Ledger balances count only what is posted to the books. The Bank & Cash Balance screen starts '
                  'from the balance you entered, so its figures can differ.',
                  style: TextStyle(fontSize: 11.5, color: crm.textSecondary),
                ),
              ]),
            ]),
          ),
        ],
      ),
    );
  }
}
