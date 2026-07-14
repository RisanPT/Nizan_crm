import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/extensions/space_extension.dart';
import '../../../core/models/purchase.dart';
import '../../../core/models/vendor.dart';
import '../../../core/theme/crm_theme.dart';
import '../../../core/utils/responsive_builder.dart';
import '../../../services/inventory_service.dart';
import '../inventory/inventory_widgets.dart';

/// Accounts → Bills / Payables. Vendor bills (from inventory purchases) with
/// paid/unpaid + GST tracking, bill viewing, and payment recording — Zoho-style.
class AccountsBillsScreen extends ConsumerStatefulWidget {
  const AccountsBillsScreen({super.key});

  @override
  ConsumerState<AccountsBillsScreen> createState() =>
      _AccountsBillsScreenState();
}

class _AccountsBillsScreenState extends ConsumerState<AccountsBillsScreen> {
  String _status = 'all'; // all | unpaid | partial | overdue | paid
  String _vendor = 'all'; // vendor id
  bool _gstOnly = false;
  String _query = '';

  static String _money(double v) =>
      NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0)
          .format(v);
  static String _date(DateTime d) => DateFormat('d MMM yyyy').format(d);

  Color _statusColor(CrmTheme crm, String status) {
    switch (status) {
      case 'paid':
        return crm.success;
      case 'partial':
        return crm.accent;
      case 'overdue':
        return crm.destructive;
      default:
        return crm.warning;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'paid':
        return 'Paid';
      case 'partial':
        return 'Partially paid';
      case 'overdue':
        return 'Overdue';
      default:
        return 'Unpaid';
    }
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final isMobile = ResponsiveBuilder.isMobile(context);
    final purchasesAsync = ref.watch(purchasesProvider);
    final vendors = ref.watch(vendorsProvider).value ?? const <Vendor>[];
    final vendorById = {for (final v in vendors) v.id: v};

    return purchasesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Failed to load bills:\n$e',
              textAlign: TextAlign.center,
              style: TextStyle(color: crm.textSecondary)),
        ),
      ),
      data: (all) {
        // Bills = studio vendor purchases (exclude artist-owned, handled server-side).
        final bills = [...all]..sort((a, b) => b.date.compareTo(a.date));

        // Summary across all bills.
        double outstanding = 0, paid = 0, overdue = 0, gstPaid = 0, gstInput = 0;
        for (final b in bills) {
          outstanding += b.balance;
          paid += b.paidAmount;
          if (b.isOverdue) overdue += b.balance;
          gstInput += b.gstAmount;
          if (b.isFullyPaid) gstPaid += b.gstAmount;
        }

        // Apply filters for the list.
        final filtered = bills.where((b) {
          if (_status != 'all' && b.status != _status) return false;
          if (_vendor != 'all' && b.vendorId != _vendor) return false;
          if (_gstOnly && !b.gstEnabled) return false;
          if (_query.isNotEmpty) {
            final q = _query.toLowerCase();
            final name =
                (vendorById[b.vendorId]?.name ?? b.supplier).toLowerCase();
            if (!name.contains(q) &&
                !b.invoiceNo.toLowerCase().contains(q) &&
                !b.gstin.toLowerCase().contains(q)) {
              return false;
            }
          }
          return true;
        }).toList();

        final stats = [
          InvStat(_money(outstanding), 'Outstanding',
              Icons.account_balance_wallet_outlined, crm.primary),
          InvStat(_money(overdue), 'Overdue', Icons.warning_amber_rounded,
              crm.destructive),
          InvStat(_money(paid), 'Paid', Icons.check_circle_outline,
              crm.success),
          InvStat(_money(gstPaid), 'GST paid (input)',
              Icons.receipt_long_outlined, crm.accent),
        ];

        return ListView(
          padding: EdgeInsets.fromLTRB(
              isMobile ? 16 : 24, 16, isMobile ? 16 : 24, 24),
          children: [
            _header(crm, isMobile, gstInput),
            16.h,
            InvStatGrid(stats: stats, isMobile: isMobile),
            18.h,
            _filters(crm, isMobile, vendors),
            14.h,
            if (filtered.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 48),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.receipt_long_outlined,
                          size: 42, color: crm.textSecondary),
                      10.h,
                      Text('No bills match these filters',
                          style: TextStyle(color: crm.textSecondary)),
                    ],
                  ),
                ),
              )
            else
              ...filtered.map((b) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _billCard(crm, b, vendorById[b.vendorId]),
                  )),
          ],
        );
      },
    );
  }

  Widget _header(CrmTheme crm, bool isMobile, double gstInput) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Bills & Payables',
            style: TextStyle(
                fontSize: isMobile ? 22 : 28,
                fontWeight: FontWeight.w800,
                color: crm.textPrimary)),
        4.h,
        Text(
            'Vendor bills from inventory purchases · GST input this period: ${_money(gstInput)}',
            style: TextStyle(fontSize: 13, color: crm.textSecondary)),
      ],
    );
  }

  Widget _filters(CrmTheme crm, bool isMobile, List<Vendor> vendors) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: isMobile ? double.infinity : 260,
          child: TextField(
            onChanged: (v) => setState(() => _query = v.trim()),
            decoration: InputDecoration(
              hintText: 'Search vendor, invoice, GSTIN',
              prefixIcon: const Icon(Icons.search, size: 20),
              isDense: true,
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
        _statusChoice(crm),
        _vendorChoice(crm, vendors),
        FilterChip(
          selected: _gstOnly,
          label: const Text('GST bills'),
          avatar: Icon(Icons.percent,
              size: 16, color: _gstOnly ? crm.primary : crm.textSecondary),
          onSelected: (v) => setState(() => _gstOnly = v),
        ),
      ],
    );
  }

  Widget _statusChoice(CrmTheme crm) {
    const opts = {
      'all': 'All',
      'unpaid': 'Unpaid',
      'partial': 'Partial',
      'overdue': 'Overdue',
      'paid': 'Paid',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: crm.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _status,
          isDense: true,
          items: [
            for (final e in opts.entries)
              DropdownMenuItem(value: e.key, child: Text(e.value)),
          ],
          onChanged: (v) => setState(() => _status = v ?? 'all'),
        ),
      ),
    );
  }

  Widget _vendorChoice(CrmTheme crm, List<Vendor> vendors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: crm.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _vendor,
          isDense: true,
          items: [
            const DropdownMenuItem(value: 'all', child: Text('All vendors')),
            for (final v in vendors)
              DropdownMenuItem(value: v.id, child: Text(v.name)),
          ],
          onChanged: (v) => setState(() => _vendor = v ?? 'all'),
        ),
      ),
    );
  }

  Widget _billCard(CrmTheme crm, Purchase b, Vendor? vendor) {
    final name =
        (vendor?.name ?? b.supplier).trim().isEmpty
            ? 'Unnamed vendor'
            : (vendor?.name ?? b.supplier);
    final color = _statusColor(crm, b.status);
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => _openBillDetails(b, vendor),
      child: Container(
        decoration: BoxDecoration(
          color: crm.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: crm.border),
        ),
        child: Column(
          children: [
            Container(
              height: 4,
              decoration: BoxDecoration(
                color: color,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(14)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                                color: crm.textPrimary)),
                      ),
                      _chip(color, _statusLabel(b.status)),
                    ],
                  ),
                  4.h,
                  Text(
                    [
                      if (b.invoiceNo.isNotEmpty) 'Inv ${b.invoiceNo}',
                      _date(b.date),
                      if (b.dueDate != null) 'Due ${_date(b.dueDate!)}',
                      if (b.gstEnabled) 'GST ${b.gstRate.toStringAsFixed(0)}%',
                    ].join('  ·  '),
                    style: TextStyle(fontSize: 12, color: crm.textSecondary),
                  ),
                  10.h,
                  Row(
                    children: [
                      _amountBit(crm, 'Total', _money(b.grandTotal),
                          crm.textPrimary),
                      _amountBit(crm, 'Paid', _money(b.paidAmount), crm.success),
                      _amountBit(
                          crm,
                          'Balance',
                          _money(b.balance),
                          b.balance > 0 ? crm.destructive : crm.success),
                    ],
                  ),
                  10.h,
                  Row(
                    children: [
                      if (b.billImage.isNotEmpty)
                        OutlinedButton.icon(
                          onPressed: () => _viewBill(crm, b.billImage),
                          icon: const Icon(Icons.receipt_long, size: 16),
                          label: const Text('Bill'),
                          style: OutlinedButton.styleFrom(
                              visualDensity: VisualDensity.compact),
                        ),
                      8.w,
                      if (b.balance > 0.01)
                        FilledButton.icon(
                          onPressed: () => _recordPayment(b),
                          icon: const Icon(Icons.payments_outlined, size: 16),
                          label: const Text('Record payment'),
                          style: FilledButton.styleFrom(
                              visualDensity: VisualDensity.compact),
                        ),
                      const Spacer(),
                      IconButton(
                        tooltip: 'Edit billing / GST',
                        icon: Icon(Icons.edit_outlined,
                            size: 18, color: crm.textSecondary),
                        onPressed: () => _editBilling(b, vendor),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _amountBit(CrmTheme crm, String label, String value, Color color) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(),
              style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                  color: crm.textSecondary)),
          2.h,
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }

  Widget _chip(Color color, String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(text,
            style: TextStyle(
                color: color, fontSize: 11, fontWeight: FontWeight.w700)),
      );

  // ── Bill details bottom sheet ──────────────────────────────────────────
  void _openBillDetails(Purchase b, Vendor? vendor) {
    final crm = context.crmColors;
    final name = (vendor?.name ?? b.supplier).trim().isEmpty
        ? 'Unnamed vendor'
        : (vendor?.name ?? b.supplier);
    final gstin = b.gstin.isNotEmpty ? b.gstin : (vendor?.gstNumber ?? '');
    final color = _statusColor(crm, b.status);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: crm.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        Widget kv(String k, String v, {Color? vc}) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                      width: 140,
                      child: Text(k,
                          style: TextStyle(
                              color: crm.textSecondary, fontSize: 12.5))),
                  Expanded(
                      child: Text(v,
                          style: TextStyle(
                              color: vc ?? crm.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600))),
                ],
              ),
            );

        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          builder: (ctx, scroll) => ListView(
            controller: scroll,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(name,
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: crm.textPrimary)),
                  ),
                  _chip(color, _statusLabel(b.status)),
                ],
              ),
              12.h,
              kv('Invoice no', b.invoiceNo.isEmpty ? '—' : b.invoiceNo),
              kv('Bill date', _date(b.date)),
              if (b.dueDate != null)
                kv('Due date', _date(b.dueDate!),
                    vc: b.isOverdue ? crm.destructive : null),
              if (gstin.isNotEmpty) kv('GSTIN', gstin),
              const Divider(height: 24),
              kv('Taxable value', _money(b.total)),
              if (b.gstEnabled) ...[
                if (b.interState)
                  kv('IGST (${b.gstRate.toStringAsFixed(0)}%)', _money(b.igst))
                else ...[
                  kv('CGST (${(b.gstRate / 2).toStringAsFixed(1)}%)',
                      _money(b.cgst)),
                  kv('SGST (${(b.gstRate / 2).toStringAsFixed(1)}%)',
                      _money(b.sgst)),
                ],
              ],
              kv('Grand total', _money(b.grandTotal), vc: crm.textPrimary),
              kv('Paid', _money(b.paidAmount), vc: crm.success),
              kv('Balance', _money(b.balance),
                  vc: b.balance > 0 ? crm.destructive : crm.success),
              if (b.payments.isNotEmpty) ...[
                const Divider(height: 24),
                Text('Payments made',
                    style: TextStyle(
                        fontWeight: FontWeight.w800, color: crm.textPrimary)),
                6.h,
                ...b.payments.map((p) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle,
                              size: 15, color: crm.success),
                          8.w,
                          Expanded(
                            child: Text(
                                '${_money(p.amount)} · ${_pmLabel(p.mode)} · ${_date(p.date)}'
                                '${p.note.isNotEmpty ? ' · ${p.note}' : ''}',
                                style: TextStyle(
                                    fontSize: 12.5, color: crm.textSecondary)),
                          ),
                        ],
                      ),
                    )),
              ],
              18.h,
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  if (b.billImage.isNotEmpty)
                    OutlinedButton.icon(
                      onPressed: () => _viewBill(crm, b.billImage),
                      icon: const Icon(Icons.receipt_long, size: 18),
                      label: const Text('View bill'),
                    ),
                  if (b.balance > 0.01)
                    FilledButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _recordPayment(b);
                      },
                      icon: const Icon(Icons.payments_outlined, size: 18),
                      label: const Text('Record payment'),
                    ),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _editBilling(b, vendor);
                    },
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Edit billing / GST'),
                  ),
                  if (b.isFullyPaid)
                    TextButton.icon(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await _setPaid(b, false);
                      },
                      icon: const Icon(Icons.undo, size: 18),
                      label: const Text('Mark unpaid'),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Record payment ─────────────────────────────────────────────────────
  Future<void> _recordPayment(Purchase b) async {
    final crm = context.crmColors;
    final amountCtrl =
        TextEditingController(text: b.balance.toStringAsFixed(0));
    final noteCtrl = TextEditingController();
    var mode = 'cash';
    var payDate = DateTime.now();
    var saving = false;

    await showDialog<void>(
      context: context,
      builder: (dctx) => StatefulBuilder(
        builder: (dctx, setLocal) {
          Future<void> submit() async {
            final amount = double.tryParse(amountCtrl.text.trim()) ?? 0;
            if (amount <= 0) return;
            setLocal(() => saving = true);
            final messenger = ScaffoldMessenger.of(context);
            try {
              await ref.read(inventoryServiceProvider).recordPurchasePayment(
                    b.id,
                    amount: amount,
                    date: payDate,
                    mode: mode,
                    note: noteCtrl.text.trim(),
                  );
              ref.invalidate(purchasesProvider);
              if (dctx.mounted) Navigator.pop(dctx);
              messenger.showSnackBar(
                  const SnackBar(content: Text('Payment recorded')));
            } catch (e) {
              setLocal(() => saving = false);
              messenger.showSnackBar(SnackBar(content: Text('$e')));
            }
          }

          return AlertDialog(
            title: const Text('Record payment'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Balance due: ${_money(b.balance)}',
                      style: TextStyle(color: crm.textSecondary)),
                  12.h,
                  TextField(
                    controller: amountCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                        labelText: 'Amount', prefixText: '₹ ', isDense: true,
                        border: OutlineInputBorder()),
                  ),
                  12.h,
                  DropdownButtonFormField<String>(
                    initialValue: mode,
                    decoration: const InputDecoration(
                        labelText: 'Payment mode',
                        isDense: true,
                        border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: 'cash', child: Text('Cash')),
                      DropdownMenuItem(value: 'upi', child: Text('UPI')),
                      DropdownMenuItem(
                          value: 'bank_transfer',
                          child: Text('Bank transfer')),
                      DropdownMenuItem(value: 'cheque', child: Text('Cheque')),
                      DropdownMenuItem(value: 'card', child: Text('Card')),
                      DropdownMenuItem(value: 'other', child: Text('Other')),
                    ],
                    onChanged: (v) => setLocal(() => mode = v ?? 'cash'),
                  ),
                  12.h,
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: dctx,
                        initialDate: payDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now().add(const Duration(days: 1)),
                      );
                      if (picked != null) setLocal(() => payDate = picked);
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                          labelText: 'Payment date',
                          isDense: true,
                          border: OutlineInputBorder()),
                      child: Text(_date(payDate)),
                    ),
                  ),
                  12.h,
                  TextField(
                    controller: noteCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Note (optional)',
                        isDense: true,
                        border: OutlineInputBorder()),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: saving ? null : () => Navigator.pop(dctx),
                  child: const Text('Cancel')),
              FilledButton(
                onPressed: saving ? null : submit,
                child: saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Save payment'),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── Edit billing / GST ─────────────────────────────────────────────────
  Future<void> _editBilling(Purchase b, Vendor? vendor) async {
    final crm = context.crmColors;
    final invoiceCtrl = TextEditingController(text: b.invoiceNo);
    final gstinCtrl = TextEditingController(
        text: b.gstin.isNotEmpty ? b.gstin : (vendor?.gstNumber ?? ''));
    var gstEnabled = b.gstEnabled;
    var interState = b.interState;
    var gstRate = b.gstRate;
    DateTime? dueDate = b.dueDate;
    var saving = false;

    double gstAmountFor(double rate) => b.total * rate / 100;

    await showDialog<void>(
      context: context,
      builder: (dctx) => StatefulBuilder(
        builder: (dctx, setLocal) {
          final gstAmount = gstEnabled ? gstAmountFor(gstRate) : 0.0;
          Future<void> submit() async {
            setLocal(() => saving = true);
            final messenger = ScaffoldMessenger.of(context);
            try {
              await ref.read(inventoryServiceProvider).updatePurchaseBilling(
                    b.id,
                    invoiceNo: invoiceCtrl.text.trim(),
                    dueDate: dueDate,
                    gstEnabled: gstEnabled,
                    gstin: gstinCtrl.text.trim(),
                    gstRate: gstEnabled ? gstRate : 0,
                    gstAmount: gstEnabled ? gstAmountFor(gstRate) : 0,
                    interState: interState,
                  );
              ref.invalidate(purchasesProvider);
              if (dctx.mounted) Navigator.pop(dctx);
              messenger
                  .showSnackBar(const SnackBar(content: Text('Bill updated')));
            } catch (e) {
              setLocal(() => saving = false);
              messenger.showSnackBar(SnackBar(content: Text('$e')));
            }
          }

          return AlertDialog(
            title: const Text('Edit billing / GST'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Taxable value: ${_money(b.total)}',
                      style: TextStyle(color: crm.textSecondary)),
                  12.h,
                  TextField(
                    controller: invoiceCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Invoice no',
                        isDense: true,
                        border: OutlineInputBorder()),
                  ),
                  12.h,
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: dctx,
                        initialDate: dueDate ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) setLocal(() => dueDate = picked);
                    },
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Due date',
                        isDense: true,
                        border: const OutlineInputBorder(),
                        suffixIcon: dueDate == null
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () =>
                                    setLocal(() => dueDate = null),
                              ),
                      ),
                      child: Text(dueDate == null ? 'Not set' : _date(dueDate!)),
                    ),
                  ),
                  8.h,
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text('This is a GST bill'),
                    value: gstEnabled,
                    onChanged: (v) => setLocal(() => gstEnabled = v),
                  ),
                  if (gstEnabled) ...[
                    TextField(
                      controller: gstinCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Vendor GSTIN',
                          isDense: true,
                          border: OutlineInputBorder()),
                    ),
                    12.h,
                    DropdownButtonFormField<double>(
                      initialValue:
                          const [0.0, 5, 12, 18, 28].contains(gstRate)
                              ? gstRate
                              : 18.0,
                      decoration: const InputDecoration(
                          labelText: 'GST rate',
                          isDense: true,
                          border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: 0.0, child: Text('0%')),
                        DropdownMenuItem(value: 5.0, child: Text('5%')),
                        DropdownMenuItem(value: 12.0, child: Text('12%')),
                        DropdownMenuItem(value: 18.0, child: Text('18%')),
                        DropdownMenuItem(value: 28.0, child: Text('28%')),
                      ],
                      onChanged: (v) => setLocal(() => gstRate = v ?? gstRate),
                    ),
                    8.h,
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: const Text('Inter-state (IGST)'),
                      subtitle: Text(interState
                          ? 'IGST applied'
                          : 'CGST + SGST applied'),
                      value: interState,
                      onChanged: (v) => setLocal(() => interState = v),
                    ),
                    8.h,
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: crm.input,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('GST ${_money(gstAmount)}',
                              style: TextStyle(
                                  color: crm.textSecondary, fontSize: 13)),
                          Text('Total ${_money(b.total + gstAmount)}',
                              style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: crm.textPrimary)),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: saving ? null : () => Navigator.pop(dctx),
                  child: const Text('Cancel')),
              FilledButton(
                onPressed: saving ? null : submit,
                child: saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _setPaid(Purchase b, bool paid) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(inventoryServiceProvider).setPurchasePaid(b.id, paid);
      ref.invalidate(purchasesProvider);
      messenger.showSnackBar(
          SnackBar(content: Text(paid ? 'Marked paid' : 'Marked unpaid')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  // ── Bill viewer (image) ────────────────────────────────────────────────
  void _viewBill(CrmTheme crm, String url) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
              child: Row(
                children: [
                  Icon(Icons.receipt_long, color: crm.primary),
                  8.w,
                  const Expanded(
                      child: Text('Supplier Bill',
                          style: TextStyle(fontWeight: FontWeight.bold))),
                  IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx)),
                ],
              ),
            ),
            Flexible(
              child: InteractiveViewer(
                child: Image.network(url,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => Padding(
                          padding: const EdgeInsets.all(40),
                          child: Text('Could not load bill image',
                              style: TextStyle(color: crm.textSecondary)),
                        )),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _pmLabel(String mode) {
    switch (mode) {
      case 'bank_transfer':
        return 'Bank transfer';
      case 'upi':
        return 'UPI';
      case 'cheque':
        return 'Cheque';
      case 'card':
        return 'Card';
      case 'cash':
        return 'Cash';
      default:
        return 'Other';
    }
  }
}
