import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/finance/data/bank_account.dart';
import 'package:nizan_crm/features/finance/presentation/widgets/bank_account_dialogs.dart';
import 'package:nizan_crm/features/finance/presentation/widgets/bank_transactions_view.dart';
import 'package:nizan_crm/features/finance/services/bank_account_service.dart';

const _bankBalancePath = '/company-finance/bank-balance';

/// Finance → Bank & Cash Balance → one account's TRANSACTIONS, all of them: the period, what came in
/// and went out, the balance it opened and closed with, and the full list — filtered, paged, exported —
/// with a tap on any row for what it was for.
class BankTransactionsScreen extends ConsumerStatefulWidget {
  final String accountId;
  const BankTransactionsScreen({super.key, required this.accountId});

  @override
  ConsumerState<BankTransactionsScreen> createState() => _BankTransactionsScreenState();
}

class _BankTransactionsScreenState extends ConsumerState<BankTransactionsScreen> {
  BankPeriod _period = BankPeriod.sinceBalance;
  BankTxnQuery? _query;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final async = ref.watch(bankAccountsProvider);
    return Scaffold(
      backgroundColor: crm.background,
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => AppErrorView(error: e, onRetry: () => ref.invalidate(bankAccountsProvider)),
        data: (result) {
          final a = result.accounts.where((x) => x.id == widget.accountId).firstOrNull;
          if (a == null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.account_balance_outlined, size: 44, color: crm.textSecondary),
                  const SizedBox(height: 10),
                  Text('That account is not here any more.', key: const Key('bankAccountGone'), style: TextStyle(color: crm.textSecondary)),
                  const SizedBox(height: 10),
                  FilledButton(onPressed: () => context.go(_bankBalancePath), child: const Text('Back to Bank & Cash Balance')),
                ],
              ),
            );
          }
          return LayoutBuilder(
            builder: (context, c) {
              final wide = c.maxWidth >= 900;
              return SingleChildScrollView(
                padding: EdgeInsets.all(wide ? 24 : 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _header(crm, a, wide),
                    const SizedBox(height: 16),
                    if (a.isLinked) ...[
                      _summary(crm, a),
                      const SizedBox(height: 16),
                    ],
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(color: crm.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: crm.border)),
                      child: a.isLinked
                          ? BankTransactionsView(account: a, period: _period, pageSize: 25, showOpening: false, onQueryChanged: (q) => setState(() => _query = q))
                          : Text(
                              'This account is not linked to a ledger, so there are no transactions to list. Link it from the ⋯ menu.',
                              key: const Key('bankNotLinked'),
                              style: TextStyle(fontSize: 13, color: crm.textSecondary),
                            ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _header(CrmTheme crm, BankAccount a, bool wide) {
    final sub = [
      a.isCash ? 'Cash' : 'Bank',
      if (a.bankName.isNotEmpty) a.bankName,
      if (a.accountNumber.isNotEmpty) a.maskedAccount,
      if (a.isLinked) 'Ledger ${a.ledger!.label}',
    ].join('  •  ');
    final title = Row(
      children: [
        IconButton(
          key: const Key('bankTxnBack'),
          tooltip: 'Back to Bank & Cash Balance',
          onPressed: () => context.go(_bankBalancePath),
          icon: const Icon(Icons.arrow_back),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${a.name} — Transactions', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: wide ? 24 : 19, fontWeight: FontWeight.w800, color: crm.textPrimary, letterSpacing: -0.3)),
              Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: crm.textSecondary)),
            ],
          ),
        ),
      ],
    );
    final actions = [
      BankPeriodButton(period: _period, onChanged: (p) => setState(() => _period = p)),
      BankExportButton(account: a, query: _query?.accountId == a.id ? _query : null),
      BankAccountMenuButton(account: a, onDeleted: () => context.go(_bankBalancePath)),
    ];
    if (wide) {
      return Row(
        children: [
          Expanded(child: title),
          const SizedBox(width: 12),
          for (final w in actions) Padding(padding: const EdgeInsets.only(left: 10), child: w),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        title,
        const SizedBox(height: 12),
        Wrap(spacing: 10, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: actions),
      ],
    );
  }

  /// Opening balance · money in · money out · closing balance, for the period on screen (not the
  /// filters: those narrow the list, the account's totals stay whole).
  Widget _summary(CrmTheme crm, BankAccount a) {
    final q = _query?.accountId == a.id ? _query : null;
    final data = q == null ? null : ref.watch(bankStatementProvider(q)).value;
    String money(double? v) => data == null ? '…' : (v == null ? '—' : bankInr(v));
    final tiles = [
      _SummaryTile(keyName: 'opening', label: _period.isSinceBalance ? 'Balance entered' : 'Opening balance', value: money(data?.opening), color: crm.textPrimary),
      _SummaryTile(keyName: 'in', label: 'Money in', value: data == null ? '…' : '+${bankInr(data.allTotals.moneyIn)}', color: crm.success),
      _SummaryTile(keyName: 'out', label: 'Money out', value: data == null ? '…' : '−${bankInr(data.allTotals.moneyOut)}', color: crm.destructive),
      _SummaryTile(keyName: 'closing', label: _period.isSinceBalance ? 'Current balance' : 'Closing balance', value: money(data?.closing), color: crm.textPrimary, strong: true),
    ];
    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth >= 760) {
          return Row(
            children: [
              for (var i = 0; i < tiles.length; i++) ...[
                if (i > 0) const SizedBox(width: 12),
                Expanded(child: tiles[i]),
              ],
            ],
          );
        }
        final w = (c.maxWidth - 12) / 2;
        return Wrap(spacing: 12, runSpacing: 12, children: [for (final t in tiles) SizedBox(width: w, child: t)]);
      },
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final String keyName;
  final String label;
  final String value;
  final Color color;
  final bool strong;
  const _SummaryTile({required this.keyName, required this.label, required this.value, required this.color, this.strong = false});

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return Container(
      key: Key('bankSummary_$keyName'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: strong ? crm.primary.withValues(alpha: 0.06) : crm.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: strong ? crm.primary.withValues(alpha: 0.18) : crm.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12.5, color: crm.textSecondary)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color, letterSpacing: -0.2)),
          ),
        ],
      ),
    );
  }
}
