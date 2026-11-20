import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/finance/data/bank_account.dart';
import 'package:nizan_crm/features/finance/presentation/widgets/bank_account_dialogs.dart';
import 'package:nizan_crm/features/finance/presentation/widgets/bank_transactions_view.dart';
import 'package:nizan_crm/features/finance/services/bank_account_service.dart';

/// Where an account's full list of transactions opens.
String bankTransactionsPath(String accountId) => '/company-finance/bank-balance/$accountId/transactions';

/// Finance → Bank & Cash Balance.
///
/// The totals (against the end of last month), the accounts on the left, and — beside them on a wide
/// window — the chosen account's latest transactions, each saying what it was for. The whole list of an
/// account's transactions is its own screen ([bankTransactionsPath]); on a phone, tapping an account
/// goes straight there.
///
/// Each account is linked to a Cash / Bank ledger: its live balance is the last balance entered by hand
/// plus the ledger's receipts and payments since that day.
class BankBalanceScreen extends ConsumerStatefulWidget {
  const BankBalanceScreen({super.key});

  @override
  ConsumerState<BankBalanceScreen> createState() => _BankBalanceScreenState();
}

class _BankBalanceScreenState extends ConsumerState<BankBalanceScreen> {
  String? _selectedId;
  BankPeriod _period = BankPeriod.sinceBalance;

  /// What the transactions panel is showing — so Export downloads exactly that.
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
        data: (result) => LayoutBuilder(
          builder: (context, c) {
            final wide = c.maxWidth >= 1000;
            final accounts = result.accounts;
            // the account on show: the one picked, else the first
            final selected = accounts.where((a) => a.id == _selectedId).firstOrNull ?? accounts.firstOrNull;
            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(bankAccountsProvider);
                ref.invalidate(bankStatementProvider);
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.all(wide ? 24 : 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _header(crm, wide, selected),
                    const SizedBox(height: 18),
                    _KpiRow(result: result),
                    const SizedBox(height: 18),
                    if (accounts.isEmpty)
                      _emptyState(crm)
                    else if (wide)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(width: 340, child: _accountsPanel(crm, accounts, selected, wide)),
                          const SizedBox(width: 18),
                          Expanded(child: _transactionsPanel(crm, selected!)),
                        ],
                      )
                    else
                      _accountsPanel(crm, accounts, null, wide),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ── header ─────────────────────────────────────────────────────────────────

  Widget _header(CrmTheme crm, bool wide, BankAccount? selected) {
    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Bank & Cash Balance', style: TextStyle(fontSize: wide ? 26 : 21, fontWeight: FontWeight.w800, color: crm.textPrimary, letterSpacing: -0.3)),
        const SizedBox(height: 2),
        Text('Manage bank accounts and cash balances', style: TextStyle(fontSize: 13, color: crm.textSecondary)),
      ],
    );
    if (!wide) return title; // on a phone the period and Export live on the account's own screen
    return Row(
      children: [
        Expanded(child: title),
        const SizedBox(width: 16),
        BankPeriodButton(period: _period, onChanged: (p) => setState(() => _period = p)),
        const SizedBox(width: 12),
        BankExportButton(account: selected, query: selected == null || _query?.accountId != selected.id ? null : _query),
      ],
    );
  }

  Widget _emptyState(CrmTheme crm) => Container(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        decoration: BoxDecoration(color: crm.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: crm.border)),
        child: Column(
          children: [
            Icon(Icons.account_balance_outlined, size: 48, color: crm.textSecondary),
            const SizedBox(height: 10),
            Text('No accounts yet.', key: const Key('bankNoAccounts'), style: TextStyle(fontWeight: FontWeight.w700, color: crm.textPrimary)),
            const SizedBox(height: 2),
            Text('Add your bank accounts and cash in hand.', style: TextStyle(color: crm.textSecondary, fontSize: 12.5)),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: () => openBankAccountForm(context, ref),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Account'),
            ),
          ],
        ),
      );

  // ── accounts ───────────────────────────────────────────────────────────────

  Widget _accountsPanel(CrmTheme crm, List<BankAccount> accounts, BankAccount? selected, bool wide) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: crm.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: crm.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text('Accounts', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: crm.textPrimary))),
              OutlinedButton.icon(
                key: const Key('bankAddAccount'),
                onPressed: () => openBankAccountForm(context, ref),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Account'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: crm.primary,
                  side: BorderSide(color: crm.primary),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          for (final a in accounts)
            _AccountTile(
              account: a,
              selected: selected?.id == a.id,
              // wide: show it beside the list; narrow: its transactions are a screen of their own
              onTap: wide ? () => setState(() => _selectedId = a.id) : () => context.go(bankTransactionsPath(a.id)),
              trailing: wide ? null : BankAccountMenuButton(account: a),
            ),
        ],
      ),
    );
  }

  // ── the chosen account's transactions ──────────────────────────────────────

  Widget _transactionsPanel(CrmTheme crm, BankAccount a) {
    final since = _period.isSinceBalance ? 'Since the ${bankDate(a.asOf)} balance' : _period.label;
    return Container(
      key: const Key('bankTransactionsPanel'),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: crm.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: crm.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _IconDisc(icon: a.isCash ? Icons.payments_outlined : Icons.account_balance, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${a.name} — Transactions', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: crm.textPrimary)),
                    Text(
                      [since, if (a.isLinked) 'Ledger ${a.ledger!.label}'].join('  •  '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12.5, color: crm.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              if (a.isLinked) ...[
                OutlinedButton.icon(
                  key: const Key('bankViewLedger'),
                  onPressed: () => context.go('/company-finance/ledger?account=${a.ledger!.id}'),
                  icon: const Icon(Icons.menu_book_outlined, size: 17),
                  label: const Text('View Ledger'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: crm.textPrimary,
                    side: BorderSide(color: crm.border),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              BankAccountMenuButton(account: a, onDeleted: () => setState(() => _selectedId = null)),
            ],
          ),
          const SizedBox(height: 16),
          if (!a.isLinked)
            _NotLinkedNotice(account: a)
          else
            BankTransactionsView(
              account: a,
              period: _period,
              pageSize: 8,
              onViewAll: () => context.go(bankTransactionsPath(a.id)),
              onQueryChanged: (q) => setState(() => _query = q),
            ),
        ],
      ),
    );
  }
}

/// An icon in a soft round disc.
class _IconDisc extends StatelessWidget {
  final IconData icon;
  final double size;
  const _IconDisc({required this.icon, this.size = 48});

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: crm.primary.withValues(alpha: 0.08), shape: BoxShape.circle),
      child: Icon(icon, color: crm.primary, size: size * 0.46),
    );
  }
}

/// An account that is not linked to a ledger: its balance is only what was typed.
class _NotLinkedNotice extends ConsumerWidget {
  final BankAccount account;
  const _NotLinkedNotice({required this.account});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crm = context.crmColors;
    return Container(
      key: const Key('bankNotLinked'),
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      decoration: BoxDecoration(color: crm.warning.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Icon(Icons.link_off, size: 18, color: crm.warning),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Not linked to a ledger — this balance (${bankInr(account.balance)} as of ${bankDate(account.asOf)}) does not move with transactions, and there is nothing to list.',
              style: TextStyle(fontSize: 12.5, color: crm.textPrimary),
            ),
          ),
          TextButton(onPressed: () => linkBankLedger(context, ref, account), child: const Text('Link')),
        ],
      ),
    );
  }
}

/// One account in the list: what it is, its number, its live balance.
class _AccountTile extends StatelessWidget {
  final BankAccount account;
  final bool selected;
  final VoidCallback onTap;
  final Widget? trailing;
  const _AccountTile({required this.account, required this.selected, required this.onTap, this.trailing});

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final a = account;
    final sub = [
      if (a.bankName.isNotEmpty) a.bankName,
      if (a.accountNumber.isNotEmpty) a.maskedAccount,
      if (a.isCash && a.isLinked) a.ledger!.code,
      if (a.isCash && !a.isLinked) 'Cash in hand',
    ].join('  ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: selected ? crm.primary.withValues(alpha: 0.06) : crm.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: selected ? crm.primary : crm.border, width: selected ? 1.5 : 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: Key('bankAccount_${a.id}'),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
            child: Row(
              children: [
                _IconDisc(icon: a.isCash ? Icons.payments_outlined : Icons.account_balance, size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(a.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: crm.textPrimary, height: 1.2)),
                      if (sub.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, color: crm.textSecondary)),
                      ],
                      const SizedBox(height: 4),
                      Text(bankInr(a.currentBalance), key: Key('bankAccountBalance_${a.id}'), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: crm.textPrimary)),
                      if (!a.isLinked)
                        Text('Not linked to a ledger', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: crm.warning)),
                    ],
                  ),
                ),
                trailing ?? Icon(Icons.chevron_right, color: crm.textSecondary),
                if (trailing != null) Icon(Icons.chevron_right, color: crm.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The totals across the top: everything, the banks, and the cash boxes — each against what it held at
/// the end of last month.
class _KpiRow extends StatelessWidget {
  final BankAccountsResult result;
  const _KpiRow({required this.result});

  @override
  Widget build(BuildContext context) {
    final active = result.accounts.where((a) => a.active).toList();
    final banks = active.where((a) => !a.isCash).toList();
    final cash = active.where((a) => a.isCash).toList();
    final prev = result.previous;
    final cards = <_KpiCard>[
      _KpiCard(
        keyName: 'total',
        icon: Icons.account_balance,
        label: 'Total Balance',
        value: result.totalBalance,
        change: percentChange(result.totalBalance, prev.total),
        changeSuffix: 'vs last month',
        highlight: true,
      ),
      if (banks.isNotEmpty)
        _KpiCard(keyName: 'bank', icon: Icons.credit_card, label: 'Bank Balance', value: result.bankTotal, change: percentChange(result.bankTotal, prev.bank)),
      // up to two cash boxes each get a card of their own; more than that share one
      if (cash.length <= 2)
        for (final a in cash)
          _KpiCard(keyName: 'cash_${a.id}', icon: Icons.payments_outlined, label: a.name, value: a.currentBalance, change: percentChange(a.currentBalance, a.previousBalance))
      else
        _KpiCard(keyName: 'cash', icon: Icons.payments_outlined, label: 'Cash in Hand (${cash.length})', value: result.cashTotal, change: percentChange(result.cashTotal, prev.cash)),
    ];
    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth >= 900) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < cards.length; i++) ...[
                if (i > 0) const SizedBox(width: 14),
                Expanded(child: cards[i]),
              ],
            ],
          );
        }
        // two to a row, smaller, on a narrow window (one to a row only when it is very narrow)
        final w = c.maxWidth >= 340 ? (c.maxWidth - 12) / 2 : c.maxWidth;
        return Wrap(spacing: 12, runSpacing: 12, children: [for (final card in cards) SizedBox(width: w, child: card.compact())]);
      },
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String keyName;
  final IconData icon;
  final String label;
  final double value;

  /// Percent against the end of last month; null = nothing to compare with.
  final double? change;
  final String changeSuffix;
  final bool highlight;

  /// Smaller, for two to a row on a phone.
  final bool small;
  const _KpiCard({required this.keyName, required this.icon, required this.label, required this.value, this.change, this.changeSuffix = '', this.highlight = false, this.small = false});

  _KpiCard compact() => _KpiCard(keyName: keyName, icon: icon, label: label, value: value, change: change, changeSuffix: changeSuffix, highlight: highlight, small: true);

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final up = (change ?? 0) >= 0;
    final flat = change != null && change!.abs() < 0.05;
    final tone = flat ? crm.textSecondary : (up ? crm.success : crm.destructive);
    return Container(
      key: Key('bankKpi_$keyName'),
      padding: EdgeInsets.all(small ? 12 : 18),
      decoration: BoxDecoration(
        color: highlight ? crm.primary.withValues(alpha: 0.06) : crm.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: highlight ? crm.primary.withValues(alpha: 0.18) : crm.border),
      ),
      child: Row(
        children: [
          _IconDisc(icon: icon, size: small ? 36 : 52),
          SizedBox(width: small ? 10 : 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: small ? 12 : 13, color: crm.textSecondary)),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(bankInr(value), style: TextStyle(fontSize: small ? 19 : 24, fontWeight: FontWeight.w800, color: crm.textPrimary, letterSpacing: -0.3)),
                ),
                const SizedBox(height: 4),
                // only said when there is a figure for the end of last month to compare with
                if (change != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!flat) Icon(up ? Icons.arrow_drop_up : Icons.arrow_drop_down, size: 20, color: tone),
                      Flexible(
                        child: Text.rich(
                          TextSpan(children: [
                            TextSpan(text: flat ? '0.0%' : '${up ? '+' : '−'}${change!.abs().toStringAsFixed(1)}%', style: TextStyle(fontWeight: FontWeight.w800, color: tone)),
                            if (changeSuffix.isNotEmpty) TextSpan(text: ' $changeSuffix', style: TextStyle(color: crm.textSecondary)),
                          ]),
                          key: Key('bankKpiChange_$keyName'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12.5),
                        ),
                      ),
                    ],
                  )
                else
                  Text('—', key: Key('bankKpiChange_$keyName'), style: TextStyle(fontSize: 12.5, color: crm.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
