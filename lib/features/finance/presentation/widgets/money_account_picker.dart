import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/finance/data/bank_account.dart';
import 'package:nizan_crm/features/finance/services/bank_account_service.dart';

/// What Accounts picked in the approval popup: how the money moved and which
/// Bank & Cash account it went through. Sent with the approve / verify call.
class MoneyChoice {
  final String moneyAccountId;
  final String paymentMode;
  final String paymentRef;
  final DateTime? verifiedAt;

  /// Only when the popup let Accounts change the amount (an artist expense): what they approved,
  /// which may be less than what was logged. Only this is paid out of the account.
  final double? approvedAmount;

  /// Why it was approved for less (optional).
  final String approvalNote;
  const MoneyChoice({
    required this.moneyAccountId,
    required this.paymentMode,
    this.paymentRef = '',
    this.verifiedAt,
    this.approvedAmount,
    this.approvalNote = '',
  });

  Map<String, dynamic> toJson() => {
        'moneyAccountId': moneyAccountId,
        'paymentMode': paymentMode,
        'paymentRef': paymentRef,
        if (verifiedAt != null) 'verifiedAt': verifiedAt!.toIso8601String(),
        if (approvedAmount != null) 'approvedAmount': approvedAmount,
        if (approvalNote.isNotEmpty) 'approvalNote': approvalNote,
      };
}

/// A payment mode offered in the popup: the record's own stored value + label.
typedef PayModeOption = ({String value, String label});

const kCollectionPayModes = <PayModeOption>[
  (value: 'cash', label: 'Cash'),
  (value: 'upi', label: 'UPI'),
  (value: 'bank_transfer', label: 'Bank transfer'),
  (value: 'other', label: 'Other'),
];

const kAdminPayModes = <PayModeOption>[
  (value: 'cash', label: 'Cash'),
  (value: 'petty_cash', label: 'Petty cash'),
  (value: 'upi', label: 'UPI'),
  (value: 'bank_transfer', label: 'Bank transfer'),
  (value: 'debit_card', label: 'Debit card'),
  (value: 'credit_card', label: 'Corporate card'),
  (value: 'other', label: 'Other'),
];

const kFleetPayModes = <PayModeOption>[
  (value: 'cash', label: 'Cash'),
  (value: 'upi', label: 'UPI'),
  (value: 'card', label: 'Card'),
  (value: 'other', label: 'Other'),
];

/// Salary / HRA / refund payments.
const kPayrollPayModes = <PayModeOption>[
  (value: 'bank_transfer', label: 'Bank transfer'),
  (value: 'upi', label: 'UPI'),
  (value: 'cash', label: 'Cash'),
  (value: 'cheque', label: 'Cheque'),
  (value: 'other', label: 'Other'),
];

const kPurchasePayModes = <PayModeOption>[
  (value: 'cash', label: 'Cash'),
  (value: 'upi', label: 'UPI'),
  (value: 'bank_transfer', label: 'Bank transfer'),
  (value: 'cheque', label: 'Cheque'),
  (value: 'card', label: 'Card'),
  (value: 'other', label: 'Other'),
];

bool _isCashMode(String m) => m == 'cash' || m == 'petty_cash';

String _rupees(double v) => NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: v % 1 == 0 ? 0 : 2).format(v);

/// What was typed in the "Approved amount" box, checked against what was logged.
/// [value] is the amount when it is acceptable, [error] says what is wrong otherwise.
({double? value, String? error}) checkApprovedAmount(String typed, double logged) {
  final n = double.tryParse(typed.trim().replaceAll(',', ''));
  if (n == null) return (value: null, error: 'Enter the amount you are approving');
  final v = (n * 100).round() / 100;
  if (v <= 0) return (value: null, error: 'Must be more than ₹0 — reject the expense to pay nothing');
  if (v > logged) return (value: null, error: "Can't be more than the ${_rupees(logged)} that was logged");
  return (value: v, error: null);
}

/// The approval popup: choose mode + Bank/Cash account before approving.
/// [moneyIn] = true for income (collections), false for spending.
/// [adjustableAmount]: [amount] is what was LOGGED, and the popup asks for the approved amount too
/// (up to what was logged) — only that is paid out of the account. Used for artist expenses.
/// Returns null when cancelled. When no account is linked to a ledger yet,
/// returns a choice with an empty [MoneyChoice.moneyAccountId] if the user
/// approves anyway (the server then keeps its old cash/bank rule).
Future<MoneyChoice?> showMoneyAccountPicker(
  BuildContext context, {
  required String title,
  required double amount,
  required bool moneyIn,
  required List<PayModeOption> modes,
  String initialMode = '',
  DateTime? initialDate,
  String approveLabel = 'Approve',
  bool adjustableAmount = false,
}) {
  return showDialog<MoneyChoice>(
    context: context,
    builder: (_) => _MoneyAccountDialog(
      title: title,
      amount: amount,
      moneyIn: moneyIn,
      modes: modes,
      initialMode: initialMode,
      initialDate: initialDate,
      approveLabel: approveLabel,
      adjustableAmount: adjustableAmount,
    ),
  );
}

class _MoneyAccountDialog extends ConsumerStatefulWidget {
  const _MoneyAccountDialog({
    required this.title,
    required this.amount,
    required this.moneyIn,
    required this.modes,
    required this.initialMode,
    this.initialDate,
    required this.approveLabel,
    this.adjustableAmount = false,
  });

  final bool adjustableAmount;
  final String title;
  final double amount;
  final bool moneyIn;
  final List<PayModeOption> modes;
  final String initialMode;
  final DateTime? initialDate;
  final String approveLabel;

  @override
  ConsumerState<_MoneyAccountDialog> createState() => _MoneyAccountDialogState();
}

class _MoneyAccountDialogState extends ConsumerState<_MoneyAccountDialog> {
  late String _mode;
  late DateTime _approvedDate;
  String? _accountId;
  final _ref = TextEditingController();
  late final _approved = TextEditingController(text: widget.amount % 1 == 0 ? widget.amount.toStringAsFixed(0) : widget.amount.toStringAsFixed(2));
  final _note = TextEditingController();

  ({double? value, String? error}) get _check => checkApprovedAmount(_approved.text, widget.amount);

  /// What will be paid: the approved amount when it can be set and is acceptable, else what was logged.
  double get _payable => widget.adjustableAmount ? (_check.value ?? widget.amount) : widget.amount;

  @override
  void initState() {
    super.initState();
    _mode = widget.modes.any((m) => m.value == widget.initialMode)
        ? widget.initialMode
        : widget.modes.first.value;
    _approvedDate = widget.initialDate ?? DateTime.now();
  }

  @override
  void dispose() {
    _ref.dispose();
    _approved.dispose();
    _note.dispose();
    super.dispose();
  }

  // Cash modes list cash accounts first; everything else lists banks first.
  List<BankAccount> _ordered(List<BankAccount> all) {
    final usable = all.where((a) => a.active && a.isLinked).toList();
    final wantCash = _isCashMode(_mode);
    usable.sort((x, y) => (x.isCash == wantCash ? 0 : 1).compareTo(y.isCash == wantCash ? 0 : 1));
    return usable;
  }

  void _pickDefault(List<BankAccount> ordered) {
    final stillThere = ordered.any((a) => a.id == _accountId);
    final wantCash = _isCashMode(_mode);
    final current = ordered.where((a) => a.id == _accountId).firstOrNull;
    // Re-pick when nothing is chosen or the choice doesn't fit the mode.
    if (!stillThere || (current != null && current.isCash != wantCash)) {
      _accountId = ordered.where((a) => a.isCash == wantCash).firstOrNull?.id ??
          (ordered.isEmpty ? null : ordered.first.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final async = ref.watch(bankAccountsProvider);
    final money = _rupees(_payable);
    final check = _check;
    final reduced = widget.adjustableAmount && check.value != null && check.value! < widget.amount;

    return AlertDialog(
      backgroundColor: crm.surface,
      title: Text(widget.title),
      content: SizedBox(
        width: 420,
        child: async.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: LinearProgressIndicator(),
          ),
          error: (e, _) => AppErrorView(error: e, compact: true, onRetry: () => ref.invalidate(bankAccountsProvider)),
          data: (result) {
            final ordered = _ordered(result.accounts);
            _pickDefault(ordered);
            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.moneyIn ? '$money received — where did it land?' : '$money paid — which account paid it?',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: crm.textPrimary),
                  ),
                  if (widget.adjustableAmount) ...[
                    const SizedBox(height: 14),
                    _amountBlock(crm, check, reduced),
                  ],
                  const SizedBox(height: 14),
                  Text('Approved date', style: TextStyle(fontSize: 12, color: crm.textSecondary)),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _approvedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setState(() => _approvedDate = picked);
                      }
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.calendar_today_outlined, size: 16),
                        border: OutlineInputBorder(),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      child: Text(
                        DateFormat('dd MMM yyyy').format(_approvedDate),
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: crm.textPrimary),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text('Payment mode', style: TextStyle(fontSize: 12, color: crm.textSecondary)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final m in widget.modes)
                        ChoiceChip(
                          label: Text(m.label),
                          selected: _mode == m.value,
                          onSelected: (_) => setState(() {
                            _mode = m.value;
                            _accountId = null; // re-default for the new mode
                          }),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (ordered.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: crm.warning.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'No bank or cash account is linked to a ledger yet. Link one on '
                        'Finance → Bank & Cash Balance to track where money goes. '
                        'You can still approve; it will post the old way.',
                        style: TextStyle(fontSize: 12, color: crm.textPrimary),
                      ),
                    )
                  else ...[
                    DropdownButtonFormField<String>(
                      // Rebuilt per mode so the re-defaulted account shows.
                      key: ValueKey(_mode),
                      initialValue: _accountId,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: widget.moneyIn ? 'Deposited to *' : 'Paid from *',
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: [
                        for (final a in ordered)
                          DropdownMenuItem(
                            value: a.id,
                            child: Row(children: [
                              Icon(a.isCash ? Icons.payments_outlined : Icons.account_balance,
                                  size: 16, color: crm.textSecondary),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  [a.name, if (a.accountNumber.isNotEmpty) a.maskedAccount].join(' · '),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ]),
                          ),
                      ],
                      onChanged: (v) => setState(() => _accountId = v),
                    ),
                    if (!_isCashMode(_mode)) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: _ref,
                        decoration: const InputDecoration(
                          labelText: 'Reference (UTR / UPI ref / cheque no.)',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: crm.success),
          onPressed: async.isLoading || (widget.adjustableAmount && check.value == null)
              ? null
              : () {
                  final hasAccounts = _ordered(async.value?.accounts ?? const []).isNotEmpty;
                  if (hasAccounts && _accountId == null) return;
                  Navigator.pop(
                    context,
                    MoneyChoice(
                      moneyAccountId: hasAccounts ? _accountId! : '',
                      paymentMode: _mode,
                      paymentRef: _ref.text.trim(),
                      verifiedAt: _approvedDate,
                      approvedAmount: widget.adjustableAmount ? check.value : null,
                      approvalNote: reduced ? _note.text.trim() : '',
                    ),
                  );
                },
          child: Text(widget.approveLabel),
        ),
      ],
    );
  }

  /// "Logged ₹1,517" and the box for the amount being approved, with what that means for the account.
  Widget _amountBlock(CrmTheme crm, ({double? value, String? error}) check, bool reduced) {
    final less = reduced ? widget.amount - check.value! : 0.0;
    return Container(
      key: const Key('approveAmountBlock'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: crm.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: crm.primary.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Logged by the artist', style: TextStyle(fontSize: 12, color: crm.textSecondary))),
              Text(
                _rupees(widget.amount),
                key: const Key('approveLoggedAmount'),
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: crm.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            key: const Key('approvedAmountField'),
            controller: _approved,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Approved amount *',
              prefixText: '₹ ',
              border: const OutlineInputBorder(),
              isDense: true,
              errorText: check.error,
              errorMaxLines: 2,
            ),
          ),
          const SizedBox(height: 8),
          if (check.error == null)
            Text(
              reduced
                  ? '${_rupees(less)} less than logged — only ${_rupees(check.value!)} comes out of the account.'
                  : 'Approved in full — ${_rupees(widget.amount)} comes out of the account.',
              key: const Key('approveAmountHint'),
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: reduced ? crm.warning : crm.success),
            ),
          if (reduced) ...[
            const SizedBox(height: 10),
            TextField(
              key: const Key('approvalNoteField'),
              controller: _note,
              maxLength: 300,
              maxLines: 2,
              minLines: 1,
              decoration: const InputDecoration(
                labelText: 'Reason (optional — the artist can see it)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
