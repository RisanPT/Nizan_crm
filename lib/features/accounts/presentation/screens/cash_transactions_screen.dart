import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/state/data_refresh.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/core/utils/responsive_builder.dart';
import 'package:nizan_crm/features/accounts/data/cash_transaction.dart';
import 'package:nizan_crm/features/accounts/services/cash_transaction_service.dart';
import 'package:nizan_crm/features/finance/controllers/accounting_provider.dart' show accountTypesProvider;
import 'package:nizan_crm/features/finance/data/bank_account.dart';
import 'package:nizan_crm/features/finance/data/chart_account.dart';
import 'package:nizan_crm/features/finance/services/bank_account_service.dart';
import 'package:nizan_crm/features/org/services/department_service.dart';

final _inr = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
final _iso = DateFormat('yyyy-MM-dd');
final _day = DateFormat('d MMM yyyy');

const _typeLabels = {'in': 'Cash In', 'out': 'Cash Out', 'transfer': 'Transfer'};

const _payModes = <({String value, String label})>[
  (value: 'cash', label: 'Cash'),
  (value: 'upi', label: 'UPI'),
  (value: 'bank_transfer', label: 'Bank transfer'),
  (value: 'card', label: 'Card'),
  (value: 'cheque', label: 'Cheque'),
  (value: 'other', label: 'Other'),
];

enum _Period { thisMonth, lastMonth, thisFy, custom }

/// Accounts → Cash In / Out. Money the Accounts team keys in directly
/// (Zoho-Books style): received into / paid from a bank or cash account against
/// an Account Type → Account Name, or moved between accounts. Each entry posts
/// to the ledger immediately, so Bank & Cash balances move with it.
class CashTransactionsScreen extends ConsumerStatefulWidget {
  const CashTransactionsScreen({super.key});

  @override
  ConsumerState<CashTransactionsScreen> createState() => _CashTransactionsScreenState();
}

class _CashTransactionsScreenState extends ConsumerState<CashTransactionsScreen> {
  _Period _period = _Period.thisMonth;
  DateTimeRange? _custom;
  String _type = 'all';
  String _search = '';

  DateTimeRange get _range {
    final now = DateTime.now();
    switch (_period) {
      case _Period.thisMonth:
        return DateTimeRange(start: DateTime(now.year, now.month, 1), end: DateTime(now.year, now.month + 1, 0));
      case _Period.lastMonth:
        return DateTimeRange(start: DateTime(now.year, now.month - 1, 1), end: DateTime(now.year, now.month, 0));
      case _Period.thisFy:
        final y = now.month >= 4 ? now.year : now.year - 1;
        return DateTimeRange(start: DateTime(y, 4, 1), end: now);
      case _Period.custom:
        return _custom ?? DateTimeRange(start: DateTime(now.year, now.month, 1), end: now);
    }
  }

  CashTxnFilter get _filter =>
      (from: _iso.format(_range.start), to: _iso.format(_range.end), type: _type, search: _search);

  Future<void> _pickCustom() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: _custom ?? _range,
    );
    if (picked == null) return;
    setState(() {
      _custom = picked;
      _period = _Period.custom;
    });
  }

  void _refresh() {
    ref.invalidate(cashTransactionsProvider);
    ref.refreshData.bankAccounts();
  }

  Future<void> _openForm({String type = 'out', CashTransaction? existing}) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _CashTxnDialog(initialType: type, existing: existing),
    );
    if (saved == true) _refresh();
  }

  Future<void> _delete(CashTransaction t) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete entry?'),
        content: Text('${_typeLabels[t.type]} of ${_inr.format(t.total)} on ${_day.format(t.date)} '
            'will be removed and its ledger voucher reversed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: ctx.crmColors.destructive),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(cashTransactionServiceProvider).delete(t.id);
      _refresh();
      messenger.showSnackBar(const SnackBar(content: Text('Entry deleted')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final isMobile = ResponsiveBuilder.isMobile(context);
    final filter = _filter;
    final async = ref.watch(cashTransactionsProvider(filter));

    Widget chip(String label, bool selected, VoidCallback onTap) =>
        ChoiceChip(label: Text(label), selected: selected, onSelected: (_) => onTap());

    return Scaffold(
      backgroundColor: crm.background,
      floatingActionButton: PopupMenuButton<String>(
        tooltip: 'New entry',
        onSelected: (t) => _openForm(type: t),
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'in', child: ListTile(leading: Icon(Icons.south_west_rounded), title: Text('Cash In'))),
          PopupMenuItem(value: 'out', child: ListTile(leading: Icon(Icons.north_east_rounded), title: Text('Cash Out'))),
          PopupMenuItem(value: 'transfer', child: ListTile(leading: Icon(Icons.swap_horiz_rounded), title: Text('Transfer'))),
        ],
        child: FloatingActionButton.extended(
          onPressed: null,
          backgroundColor: crm.primary,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add),
          label: const Text('New entry'),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async => _refresh(),
        child: ListView(
          padding: EdgeInsets.fromLTRB(isMobile ? 16 : 24, 16, isMobile ? 16 : 24, 96),
          children: [
            Text('Cash In / Out',
                style: TextStyle(fontSize: isMobile ? 22 : 28, fontWeight: FontWeight.w800, color: crm.textPrimary)),
            const SizedBox(height: 4),
            Text('Money received and paid by Accounts. Every entry posts to the books and moves Bank & Cash balances.',
                style: TextStyle(fontSize: 13, color: crm.textSecondary)),
            const SizedBox(height: 16),
            Wrap(spacing: 8, runSpacing: 8, children: [
              chip('This month', _period == _Period.thisMonth, () => setState(() => _period = _Period.thisMonth)),
              chip('Last month', _period == _Period.lastMonth, () => setState(() => _period = _Period.lastMonth)),
              chip('This FY', _period == _Period.thisFy, () => setState(() => _period = _Period.thisFy)),
              chip(_period == _Period.custom ? '${_day.format(_range.start)} – ${_day.format(_range.end)}' : 'Custom…',
                  _period == _Period.custom, _pickCustom),
            ]),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final t in const ['all', 'in', 'out', 'transfer'])
                chip(t == 'all' ? 'All' : _typeLabels[t]!, _type == t, () => setState(() => _type = t)),
            ]),
            const SizedBox(height: 10),
            TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search party, notes, reference…',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onSubmitted: (v) => setState(() => _search = v),
            ),
            const SizedBox(height: 16),
            async.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 60),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => AppErrorView(error: e, onRetry: () => ref.invalidate(cashTransactionsProvider(filter))),
              data: (page) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GridView.count(
                    crossAxisCount: isMobile ? 2 : 4,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: isMobile ? 2.1 : 2.8,
                    children: [
                      _Tile('Money In', page.totals.moneyIn, crm.success),
                      _Tile('Money Out', page.totals.moneyOut, crm.destructive),
                      _Tile('Net', page.totals.net, page.totals.net >= 0 ? crm.success : crm.destructive),
                      _Tile('Transfers', page.totals.transfer, crm.textSecondary),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (page.rows.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 48),
                      child: Column(children: [
                        Icon(Icons.receipt_long_outlined, size: 48, color: crm.textSecondary),
                        const SizedBox(height: 8),
                        Text('No entries for this period.', style: TextStyle(color: crm.textSecondary)),
                      ]),
                    )
                  else
                    for (final t in page.rows) _row(crm, t),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(CrmTheme crm, CashTransaction t) {
    final isIn = t.type == 'in';
    final isOut = t.type == 'out';
    final color = isIn ? crm.success : (isOut ? crm.destructive : crm.textSecondary);
    final icon = isIn ? Icons.south_west_rounded : (isOut ? Icons.north_east_rounded : Icons.swap_horiz_rounded);
    final title = t.type == 'transfer'
        ? '${t.moneyAccount?.name ?? '—'} → ${t.toMoneyAccount?.name ?? '—'}'
        : (t.account?.name ?? '—');
    final sub = [
      _day.format(t.date),
      if (t.department.isNotEmpty) t.department,
      if (t.type != 'transfer' && t.moneyAccount != null) '${isIn ? 'to' : 'from'} ${t.moneyAccount!.name}',
      if (t.party.isNotEmpty) t.party,
      if (t.reference.isNotEmpty) '#${t.reference}',
    ].join(' · ');
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: crm.border),
      ),
      child: Material(
        color: Colors.transparent,
        child: ListTile(
        onTap: () => _openForm(type: t.type, existing: t),
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.12),
          child: Icon(icon, color: color, size: 18),
        ),
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(
          [sub, if (t.notes.isNotEmpty) t.notes].join('\n'),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 12, color: crm.textSecondary),
        ),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${isIn ? '+' : (isOut ? '−' : '')}${_inr.format(t.total)}',
                style: TextStyle(fontWeight: FontWeight.w800, color: color),
              ),
              if (t.gstType == 'gst' && t.gstAmount > 0)
                Text('incl. GST ${_inr.format(t.gstAmount)}', style: TextStyle(fontSize: 10.5, color: crm.textSecondary)),
            ],
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'edit') _openForm(type: t.type, existing: t);
              if (v == 'delete') _delete(t);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('Edit')),
              PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ]),
      ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  const _Tile(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: crm.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: crm.textSecondary)),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(_inr.format(value), style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
          ),
        ],
      ),
    );
  }
}

// ── Entry form ───────────────────────────────────────────────────────────────

class _CashTxnDialog extends ConsumerStatefulWidget {
  const _CashTxnDialog({required this.initialType, this.existing});
  final String initialType;
  final CashTransaction? existing;

  @override
  ConsumerState<_CashTxnDialog> createState() => _CashTxnDialogState();
}

class _CashTxnDialogState extends ConsumerState<_CashTxnDialog> {
  final _formKey = GlobalKey<FormState>();
  late String _type;
  late DateTime _date;
  String? _department;
  String? _accountType;
  String? _accountId;
  String? _moneyId;
  String? _toMoneyId;
  String _mode = 'bank_transfer';
  String _gstType = 'none';
  final _amount = TextEditingController();
  final _gst = TextEditingController();
  final _party = TextEditingController();
  final _reference = TextEditingController();
  final _payRef = TextEditingController();
  final _notes = TextEditingController();
  bool _saving = false;

  CashTransaction? get _e => widget.existing;

  @override
  void initState() {
    super.initState();
    final e = _e;
    _type = e?.type ?? widget.initialType;
    _date = e?.date ?? DateTime.now();
    _department = (e?.department.isNotEmpty ?? false) ? e!.department : null;
    _accountType = (e?.account?.accountType.isNotEmpty ?? false) ? e!.account!.accountType : null;
    _accountId = e?.account?.id;
    _moneyId = e?.moneyAccount?.id;
    _toMoneyId = e?.toMoneyAccount?.id;
    _mode = (e?.paymentMode.isNotEmpty ?? false) ? e!.paymentMode : 'bank_transfer';
    _gstType = e?.gstType ?? 'none';
    if (e != null) {
      _amount.text = e.amount == e.amount.roundToDouble() ? e.amount.toStringAsFixed(0) : e.amount.toString();
      if (e.gstAmount > 0) _gst.text = e.gstAmount.toStringAsFixed(2);
      _party.text = e.party;
      _reference.text = e.reference;
      _payRef.text = e.paymentRef;
      _notes.text = e.notes;
    }
  }

  @override
  void dispose() {
    for (final c in [_amount, _gst, _party, _reference, _payRef, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  // Natures shown first for each entry type (all non-cash/bank types allowed).
  List<String> get _natureOrder => _type == 'in'
      ? const ['income', 'liability', 'equity', 'asset', 'expense']
      : const ['expense', 'asset', 'liability', 'equity', 'income'];

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await ref.read(cashTransactionServiceProvider).save({
        'type': _type,
        // Noon IST keeps the chosen calendar day whatever the server's zone.
        'date': '${_iso.format(_date)}T12:00:00+05:30',
        'department': _department ?? '',
        'amount': double.tryParse(_amount.text.trim()) ?? 0,
        'moneyAccountId': _moneyId,
        'paymentMode': _mode,
        'paymentRef': _payRef.text.trim(),
        'party': _party.text.trim(),
        'reference': _reference.text.trim(),
        'notes': _notes.text.trim(),
        if (_type == 'transfer') 'toMoneyAccountId': _toMoneyId,
        if (_type != 'transfer') 'accountId': _accountId,
        if (_type == 'out') 'gstType': _gstType,
        if (_type == 'out') 'gstAmount': _gstType == 'none' ? 0 : (double.tryParse(_gst.text.trim()) ?? 0),
      }, id: _e?.id);
      navigator.pop(true);
      messenger.showSnackBar(SnackBar(content: Text(_e == null ? 'Entry saved and posted' : 'Entry updated')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e)), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  InputDecoration _dec(String label, {String? hint}) =>
      InputDecoration(labelText: label, hintText: hint, border: const OutlineInputBorder(), isDense: true);

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final accounts = ref.watch(cashTxnAccountsProvider);
    final types = ref.watch(accountTypesProvider).value ?? const <AccountTypeOption>[];
    final banks = ref.watch(bankAccountsProvider).value?.accounts.where((a) => a.active && a.isLinked).toList() ??
        const <BankAccount>[];
    final departments = ref.watch(departmentsProvider).value?.where((d) => d.active).map((d) => d.name).toList() ??
        const <String>[];
    final deptItems = {...departments, ?_department}.toList()..sort();

    final allAccounts = accounts.value ?? const [];
    // Account Types that have at least one account, ordered for this entry type.
    final typeOrder = {for (var i = 0; i < types.length; i++) types[i].key: i};
    final usableTypes = types.where((t) => allAccounts.any((a) => a.accountType == t.key)).toList()
      ..sort((x, y) {
        final n = _natureOrder.indexOf(x.nature).compareTo(_natureOrder.indexOf(y.nature));
        return n != 0 ? n : (typeOrder[x.key] ?? 0).compareTo(typeOrder[y.key] ?? 0);
      });
    final accountsOfType = allAccounts.where((a) => a.accountType == _accountType).toList();
    final selectedType = types.where((t) => t.key == _accountType).firstOrNull;

    final moneyItems = <DropdownMenuItem<String>>[
      for (final b in banks)
        DropdownMenuItem(
          value: b.id,
          child: Row(children: [
            Icon(b.isCash ? Icons.payments_outlined : Icons.account_balance, size: 16, color: crm.textSecondary),
            const SizedBox(width: 8),
            Expanded(child: Text(b.name, maxLines: 1, overflow: TextOverflow.ellipsis)),
          ]),
        ),
    ];

    return Dialog(
      backgroundColor: crm.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(_e == null ? 'New entry' : 'Edit entry',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: crm.textPrimary)),
                const SizedBox(height: 14),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'in', icon: Icon(Icons.south_west_rounded, size: 16), label: Text('Cash In')),
                    ButtonSegment(value: 'out', icon: Icon(Icons.north_east_rounded, size: 16), label: Text('Cash Out')),
                    ButtonSegment(value: 'transfer', icon: Icon(Icons.swap_horiz_rounded, size: 16), label: Text('Transfer')),
                  ],
                  selected: {_type},
                  onSelectionChanged: (s) => setState(() {
                    _type = s.first;
                    _accountType = null;
                    _accountId = null;
                  }),
                ),
                const SizedBox(height: 14),
                if (banks.isEmpty)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: crm.warning.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'No bank or cash account is linked to a ledger yet. Link one on Finance → Bank & Cash Balance first.',
                      style: TextStyle(fontSize: 12, color: crm.textPrimary),
                    ),
                  ),
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final d = await showDatePicker(
                            context: context, initialDate: _date, firstDate: DateTime(2020), lastDate: DateTime(2035));
                        if (d != null) setState(() => _date = d);
                      },
                      icon: const Icon(Icons.calendar_today, size: 16),
                      label: Text(_day.format(_date)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _department,
                      isExpanded: true,
                      decoration: _dec('Department'),
                      items: [for (final d in deptItems) DropdownMenuItem(value: d, child: Text(d))],
                      onChanged: (v) => setState(() => _department = v),
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                if (_type == 'transfer') ...[
                  DropdownButtonFormField<String>(
                    initialValue: _moneyId,
                    isExpanded: true,
                    decoration: _dec('From account *'),
                    items: moneyItems,
                    validator: (v) => v == null ? 'Required' : null,
                    onChanged: (v) => setState(() => _moneyId = v),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _toMoneyId,
                    isExpanded: true,
                    decoration: _dec('To account *'),
                    items: moneyItems,
                    validator: (v) => v == null ? 'Required' : (v == _moneyId ? 'Choose a different account' : null),
                    onChanged: (v) => setState(() => _toMoneyId = v),
                  ),
                ] else ...[
                  if (accounts.isLoading && allAccounts.isEmpty)
                    const LinearProgressIndicator()
                  else if (accounts.hasError)
                    AppErrorView(error: accounts.error!, compact: true, onRetry: () => ref.invalidate(cashTxnAccountsProvider))
                  else ...[
                    DropdownButtonFormField<String>(
                      key: ValueKey('type-$_type'),
                      initialValue: _accountType,
                      isExpanded: true,
                      decoration: _dec('Account type *').copyWith(
                        helperText: selectedType == null ? null : natureLabel(selectedType.nature),
                      ),
                      items: [for (final t in usableTypes) DropdownMenuItem(value: t.key, child: Text(t.label))],
                      validator: (v) => v == null ? 'Required' : null,
                      onChanged: (v) => setState(() {
                        _accountType = v;
                        _accountId = null;
                      }),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      key: ValueKey('acc-$_type-$_accountType'),
                      initialValue: accountsOfType.any((a) => a.id == _accountId) ? _accountId : null,
                      isExpanded: true,
                      decoration: _dec('Account name *').copyWith(
                        helperText: 'Missing one? Add it in Finance → Chart of Accounts.',
                      ),
                      items: [
                        for (final a in accountsOfType)
                          DropdownMenuItem(value: a.id, child: Text(a.label, maxLines: 1, overflow: TextOverflow.ellipsis)),
                      ],
                      validator: (v) => v == null ? 'Required' : null,
                      onChanged: (v) => setState(() => _accountId = v),
                    ),
                  ],
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: banks.any((b) => b.id == _moneyId) ? _moneyId : null,
                    isExpanded: true,
                    decoration: _dec(_type == 'in' ? 'Deposit to *' : 'Paid through *'),
                    items: moneyItems,
                    validator: (v) => v == null ? 'Required' : null,
                    onChanged: (v) => setState(() {
                      _moneyId = v;
                      final b = banks.where((x) => x.id == v).firstOrNull;
                      if (b != null && b.isCash) _mode = 'cash';
                      if (b != null && !b.isCash && _mode == 'cash') _mode = 'bank_transfer';
                    }),
                  ),
                ],
                const SizedBox(height: 12),
                TextFormField(
                  controller: _amount,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                  decoration: _dec(_type == 'out' ? 'Amount (before GST) *' : 'Amount *').copyWith(prefixText: '₹ '),
                  validator: (v) => (double.tryParse(v?.trim() ?? '') ?? 0) > 0 ? null : 'Enter an amount',
                ),
                if (_type == 'out') ...[
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _gstType,
                        decoration: _dec('Tax'),
                        items: const [
                          DropdownMenuItem(value: 'none', child: Text('No GST')),
                          DropdownMenuItem(value: 'gst', child: Text('GST (input credit)')),
                          DropdownMenuItem(value: 'rcm', child: Text('Reverse charge (RCM)')),
                        ],
                        onChanged: (v) => setState(() => _gstType = v ?? 'none'),
                      ),
                    ),
                    if (_gstType != 'none') ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _gst,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                          decoration: _dec('GST amount').copyWith(prefixText: '₹ '),
                        ),
                      ),
                    ],
                  ]),
                ],
                const SizedBox(height: 12),
                Text('Payment mode', style: TextStyle(fontSize: 12, color: crm.textSecondary)),
                const SizedBox(height: 6),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final m in _payModes)
                    ChoiceChip(label: Text(m.label), selected: _mode == m.value, onSelected: (_) => setState(() => _mode = m.value)),
                ]),
                if (_mode != 'cash') ...[
                  const SizedBox(height: 12),
                  TextFormField(controller: _payRef, decoration: _dec('Payment ref (UTR / UPI ref / cheque no.)')),
                ],
                if (_type != 'transfer') ...[
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                      child: TextFormField(
                        controller: _party,
                        decoration: _dec(_type == 'in' ? 'Received from' : 'Paid to / vendor'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: TextFormField(controller: _reference, decoration: _dec('Bill / invoice no.'))),
                  ]),
                ],
                const SizedBox(height: 12),
                TextFormField(controller: _notes, maxLines: 2, decoration: _dec('Notes')),
                const SizedBox(height: 18),
                Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: const Text('Cancel')),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _saving || banks.isEmpty ? null : _submit,
                    child: Text(_saving ? 'Saving…' : 'Save & post'),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
