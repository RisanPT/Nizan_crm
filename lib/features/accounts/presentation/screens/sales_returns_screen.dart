import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:nizan_crm/core/extensions/space_extension.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/accounts/data/sales_return.dart';
import 'package:nizan_crm/features/accounts/controllers/sales_return_provider.dart';
import 'package:nizan_crm/features/bookings/controllers/booking_provider.dart';
import 'package:nizan_crm/features/bookings/data/booking.dart';

String _money(num v) =>
    NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0).format(v);
String _fmtDate(DateTime d) => DateFormat('d MMM yyyy').format(d);

/// Accounts → Sales Returns (Credit Notes, SRT-01). A credit note reduces
/// revenue rather than adding to expenses; bride name + reason are mandatory.
class SalesReturnsScreen extends ConsumerWidget {
  const SalesReturnsScreen({super.key});

  Color _statusColor(String status, CrmTheme crm) {
    switch (status) {
      case 'processed':
        return crm.success;
      case 'approved':
        return crm.accent;
      case 'cancelled':
        return crm.textSecondary;
      default:
        return crm.warning; // draft
    }
  }

  void _refresh(WidgetRef ref) {
    ref.invalidate(salesReturnsProvider);
    ref.invalidate(salesReturnStatsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crm = context.crmColors;
    final returnsAsync = ref.watch(salesReturnsProvider);
    final statsAsync = ref.watch(salesReturnStatsProvider);

    return Scaffold(
      backgroundColor: crm.background,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: crm.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('New Credit Note', style: TextStyle(color: Colors.white)),
        onPressed: () => _openForm(context, ref),
      ),
      body: RefreshIndicator(
        onRefresh: () async => _refresh(ref),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            Text('Sales Returns · Credit Notes',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: crm.textPrimary)),
            4.h,
            Text('Refunds to brides. Approved / processed notes reduce revenue in reports.',
                style: TextStyle(fontSize: 12.5, color: crm.textSecondary)),
            14.h,
            statsAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
              data: (s) => _StatsRow(stats: s, crm: crm),
            ),
            16.h,
            returnsAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.only(top: 60),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.only(top: 40),
                child: Center(child: Text('Error: $e', style: TextStyle(color: crm.destructive))),
              ),
              data: (returns) {
                if (returns.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 60),
                    child: Center(
                      child: Column(children: [
                        Icon(Icons.assignment_return_outlined, size: 56, color: crm.border),
                        12.h,
                        Text('No credit notes yet', style: TextStyle(color: crm.textSecondary)),
                      ]),
                    ),
                  );
                }
                return Column(
                  children: returns
                      .map((r) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _ReturnCard(
                              r: r,
                              crm: crm,
                              statusColor: _statusColor(r.status, crm),
                              onEdit: () => _openForm(context, ref, existing: r),
                              onDelete: () => _delete(context, ref, r),
                              onStatus: (s) => _setStatus(context, ref, r, s),
                            ),
                          ))
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _setStatus(BuildContext context, WidgetRef ref, SalesReturn r, String status) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(salesReturnServiceProvider).updateStatus(r.id, status);
      _refresh(ref);
      messenger.showSnackBar(SnackBar(content: Text('Credit note $status')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, SalesReturn r) async {
    final crm = context.crmColors;
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: crm.surface,
        title: const Text('Delete credit note?'),
        content: Text('Delete ${r.creditNoteNumber} for ${r.brideName}?', style: TextStyle(color: crm.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Delete', style: TextStyle(color: crm.destructive))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(salesReturnServiceProvider).delete(r.id);
      _refresh(ref);
      messenger.showSnackBar(const SnackBar(content: Text('Credit note deleted')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  void _openForm(BuildContext context, WidgetRef ref, {SalesReturn? existing}) {
    showDialog(
      context: context,
      builder: (_) => _CreditNoteDialog(existing: existing, onSaved: () => _refresh(ref)),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.stats, required this.crm});
  final SalesReturnStats stats;
  final CrmTheme crm;
  @override
  Widget build(BuildContext context) {
    final tiles = <Widget>[
      _tile('This Month', _money(stats.thisMonthAmount), Icons.calendar_month_rounded, crm.destructive),
      _tile('Processed', _money(stats.processedAmount), Icons.check_circle_outline, crm.success),
      _tile('Pending', '${stats.pendingCount}', Icons.hourglass_bottom_rounded, crm.warning),
      _tile('Total Notes', '${stats.totalCount}', Icons.receipt_long_outlined, crm.accent),
    ];
    return LayoutBuilder(builder: (ctx, c) {
      final perRow = c.maxWidth >= 720 ? 4 : 2;
      const gap = 10.0;
      final w = (c.maxWidth - gap * (perRow - 1)) / perRow;
      return Wrap(spacing: gap, runSpacing: gap, children: tiles.map((t) => SizedBox(width: w, child: t)).toList());
    });
  }

  Widget _tile(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: crm.border.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          8.h,
          FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(value, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: crm.textPrimary))),
          2.h,
          Text(label, style: TextStyle(fontSize: 11, color: crm.textSecondary, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _ReturnCard extends StatelessWidget {
  const _ReturnCard({
    required this.r,
    required this.crm,
    required this.statusColor,
    required this.onEdit,
    required this.onDelete,
    required this.onStatus,
  });
  final SalesReturn r;
  final CrmTheme crm;
  final Color statusColor;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<String> onStatus;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: crm.border.withValues(alpha: 0.8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.brideName.isEmpty ? 'Unknown' : r.brideName,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    2.h,
                    Text('${r.creditNoteNumber} · ${_fmtDate(r.date)}',
                        style: TextStyle(fontSize: 12, color: crm.textSecondary)),
                  ],
                ),
              ),
              8.w,
              Text('- ${_money(r.amount)}',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: crm.destructive)),
              8.w,
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: crm.textSecondary),
                onSelected: (v) {
                  switch (v) {
                    case 'edit': onEdit(); break;
                    case 'delete': onDelete(); break;
                    default: onStatus(v);
                  }
                },
                itemBuilder: (_) => [
                  if (r.isDraft) const PopupMenuItem(value: 'approved', child: Text('Approve')),
                  if (r.isApproved) const PopupMenuItem(value: 'processed', child: Text('Mark Processed')),
                  if (!r.isCancelled && !r.isProcessed)
                    const PopupMenuItem(value: 'cancelled', child: Text('Cancel note')),
                  const PopupMenuItem(value: 'edit', child: Text('Edit')),
                  const PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ],
          ),
          10.h,
          Wrap(spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
              child: Text(r.statusLabel, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: statusColor)),
            ),
            if (r.reducesRevenue)
              Text('reduces revenue', style: TextStyle(fontSize: 11, color: crm.destructive, fontStyle: FontStyle.italic)),
            if (r.originalInvoiceRef.isNotEmpty)
              Text('Inv: ${r.originalInvoiceRef}', style: TextStyle(fontSize: 11.5, color: crm.textSecondary)),
            Text('· ${r.paymentModeLabel}', style: TextStyle(fontSize: 11.5, color: crm.textSecondary)),
          ]),
          if (r.reason.isNotEmpty) ...[
            8.h,
            Text(r.reason, style: TextStyle(fontSize: 12.5, color: crm.textSecondary, height: 1.3), maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
        ],
      ),
    );
  }
}

class _CreditNoteDialog extends ConsumerStatefulWidget {
  const _CreditNoteDialog({this.existing, required this.onSaved});
  final SalesReturn? existing;
  final VoidCallback onSaved;
  @override
  ConsumerState<_CreditNoteDialog> createState() => _CreditNoteDialogState();
}

class _CreditNoteDialogState extends ConsumerState<_CreditNoteDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _cnCtrl;
  late TextEditingController _brideCtrl;
  late TextEditingController _amountCtrl;
  late TextEditingController _invoiceCtrl;
  late TextEditingController _reasonCtrl;
  late TextEditingController _notesCtrl;
  late DateTime _date;
  String _paymentMode = 'bank_transfer';
  bool _saving = false;
  // Booking-client picker: optional event-date filter + the chosen booking.
  DateTime? _eventDate;
  String? _selectedBookingId;

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// The date shown for a booking in the picker (first event day).
  static DateTime _eventDateOf(Booking b) =>
      b.selectedDates.isNotEmpty ? b.selectedDates.first : b.serviceStart;

  /// Whether a booking's event falls on [d] — matches any selected date or the
  /// service span (serviceStart..serviceEnd), inclusive by calendar day.
  static bool _bookingOnDate(Booking b, DateTime d) {
    if (b.selectedDates.any((x) => _sameDay(x, d))) return true;
    final day = DateTime(d.year, d.month, d.day);
    final start =
        DateTime(b.serviceStart.year, b.serviceStart.month, b.serviceStart.day);
    final end = DateTime(b.serviceEnd.year, b.serviceEnd.month, b.serviceEnd.day);
    return !day.isBefore(start) && !day.isAfter(end);
  }

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    final now = DateTime.now();
    _cnCtrl = TextEditingController(
      text: e?.creditNoteNumber ?? 'CN-${now.year}-${now.millisecondsSinceEpoch % 100000}',
    );
    _brideCtrl = TextEditingController(text: e?.brideName ?? '');
    _amountCtrl = TextEditingController(text: e != null ? e.amount.toStringAsFixed(0) : '');
    _invoiceCtrl = TextEditingController(text: e?.originalInvoiceRef ?? '');
    _reasonCtrl = TextEditingController(text: e?.reason ?? '');
    _notesCtrl = TextEditingController(text: e?.notes ?? '');
    _date = e?.date ?? now;
    _paymentMode = e?.paymentMode ?? 'bank_transfer';
  }

  @override
  void dispose() {
    _cnCtrl.dispose();
    _brideCtrl.dispose();
    _amountCtrl.dispose();
    _invoiceCtrl.dispose();
    _reasonCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      final payload = {
        'creditNoteNumber': _cnCtrl.text.trim(),
        'brideName': _brideCtrl.text.trim(),
        'amount': double.tryParse(_amountCtrl.text.trim()) ?? 0,
        'date': _date.toIso8601String(),
        'originalInvoiceRef': _invoiceCtrl.text.trim(),
        'reason': _reasonCtrl.text.trim(),
        'paymentMode': _paymentMode,
        'notes': _notesCtrl.text.trim(),
      };
      final svc = ref.read(salesReturnServiceProvider);
      if (widget.existing == null) {
        await svc.create(payload);
      } else {
        await svc.update(widget.existing!.id, payload);
      }
      widget.onSaved();
      navigator.pop();
      messenger.showSnackBar(const SnackBar(content: Text('Credit note saved')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;

    // Bookings for the client picker, filtered by the optional event-date filter
    // and sorted most-recent event first.
    final bookingsAsync = ref.watch(bookingProvider);
    final allBookings = bookingsAsync.asData?.value ?? const <Booking>[];
    final bookingChoices = [
      for (final b in allBookings)
        if (b.customerName.trim().isNotEmpty &&
            (_eventDate == null || _bookingOnDate(b, _eventDate!)))
          b,
    ]..sort((a, b) => _eventDateOf(b).compareTo(_eventDateOf(a)));
    final validSelectedId =
        bookingChoices.any((b) => b.id == _selectedBookingId)
            ? _selectedBookingId
            : null;

    return Dialog(
      backgroundColor: crm.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 520,
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.existing == null ? 'New Credit Note' : 'Edit Credit Note',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: crm.textPrimary)),
                16.h,
                Row(children: [
                  Expanded(
                    child: TextFormField(
                      controller: _cnCtrl,
                      decoration: const InputDecoration(labelText: 'Credit Note No. *'),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                  ),
                  12.w,
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _date,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) setState(() => _date = picked);
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(labelText: 'Date *', suffixIcon: Icon(Icons.calendar_today, size: 18)),
                        child: Text(_fmtDate(_date)),
                      ),
                    ),
                  ),
                ]),
                12.h,
                // ── Pick the bride/client from existing bookings ──────────────
                Row(children: [
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _eventDate ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) {
                          setState(() {
                            _eventDate = picked;
                            _selectedBookingId = null;
                          });
                        }
                      },
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Filter bookings by event date',
                          suffixIcon: _eventDate == null
                              ? const Icon(Icons.calendar_today, size: 18)
                              : IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  tooltip: 'Clear date filter',
                                  onPressed: () => setState(() {
                                    _eventDate = null;
                                    _selectedBookingId = null;
                                  }),
                                ),
                        ),
                        child: Text(_eventDate == null ? 'All dates' : _fmtDate(_eventDate!)),
                      ),
                    ),
                  ),
                ]),
                12.h,
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: validSelectedId,
                  decoration: InputDecoration(
                    labelText: 'Booking Client',
                    hintText: bookingsAsync.isLoading
                        ? 'Loading bookings…'
                        : (bookingChoices.isEmpty
                            ? 'No bookings for this date'
                            : 'Select from bookings'),
                    prefixIcon: const Icon(Icons.event_note_outlined, size: 18),
                  ),
                  items: [
                    for (final b in bookingChoices)
                      DropdownMenuItem(
                        value: b.id,
                        child: Text(
                          '${b.customerName}'
                          '${b.bookingNumber.isNotEmpty ? ' · ${b.bookingNumber}' : ''}'
                          ' · ${_fmtDate(_eventDateOf(b))}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: bookingChoices.isEmpty
                      ? null
                      : (id) {
                          Booking? picked;
                          for (final b in bookingChoices) {
                            if (b.id == id) {
                              picked = b;
                              break;
                            }
                          }
                          setState(() {
                            _selectedBookingId = id;
                            if (picked != null) {
                              _brideCtrl.text = picked.customerName;
                              if (picked.bookingNumber.isNotEmpty) {
                                _invoiceCtrl.text = picked.bookingNumber;
                              }
                            }
                          });
                        },
                ),
                12.h,
                TextFormField(
                  controller: _brideCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Bride Name *',
                    hintText: 'Pick a booking above, or type the customer name',
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Bride name is mandatory' : null,
                ),
                12.h,
                Row(children: [
                  Expanded(
                    child: TextFormField(
                      controller: _amountCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Refund Amount (₹) *', prefixText: '₹ '),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Enter amount';
                        if (double.tryParse(v.trim()) == null) return 'Invalid';
                        return null;
                      },
                    ),
                  ),
                  12.w,
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _paymentMode,
                      decoration: const InputDecoration(labelText: 'Refund Mode'),
                      items: const [
                        DropdownMenuItem(value: 'bank_transfer', child: Text('Bank Transfer')),
                        DropdownMenuItem(value: 'upi', child: Text('UPI')),
                        DropdownMenuItem(value: 'cash', child: Text('Cash')),
                        DropdownMenuItem(value: 'cheque', child: Text('Cheque')),
                        DropdownMenuItem(value: 'other', child: Text('Other')),
                      ],
                      onChanged: (v) => setState(() => _paymentMode = v ?? 'bank_transfer'),
                    ),
                  ),
                ]),
                12.h,
                TextFormField(
                  controller: _invoiceCtrl,
                  decoration: const InputDecoration(labelText: 'Original Invoice Ref', hintText: 'Booking / invoice number'),
                ),
                12.h,
                TextFormField(
                  controller: _reasonCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Reason / Narration *', hintText: 'Why the refund was issued'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Reason is mandatory' : null,
                ),
                12.h,
                TextFormField(
                  controller: _notesCtrl,
                  decoration: const InputDecoration(labelText: 'Notes'),
                ),
                20.h,
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: const Text('Cancel')),
                    8.w,
                    ElevatedButton(
                      onPressed: _saving ? null : _submit,
                      style: ElevatedButton.styleFrom(backgroundColor: crm.primary),
                      child: _saving
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Save', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
