import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/core/utils/responsive_builder.dart';
import 'package:nizan_crm/core/providers/auth_provider.dart';
import 'package:nizan_crm/core/models/employee.dart';
import 'package:nizan_crm/services/employee_service.dart';
import 'package:nizan_crm/features/bookings/controllers/booking_provider.dart';
import 'package:nizan_crm/features/bookings/data/booking.dart';
import 'package:nizan_crm/features/accounts/data/artist_payout.dart';
import 'package:nizan_crm/features/accounts/services/artist_payout_service.dart';

/// Artist Payouts — the freelancer (outsource artist) compensation ledger.
/// Accounts creates a per-booking payout, approves it, and pays it (posting a
/// COGS expense to the books). Freelancers are NOT on monthly payroll.
class ArtistPayoutsScreen extends ConsumerWidget {
  const ArtistPayoutsScreen({super.key});

  static const _modes = ['cash', 'upi', 'bank_transfer', 'other'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crm = context.crmColors;
    final isMobile = ResponsiveBuilder.isMobile(context);
    final role = ref.watch(authSessionProvider)?.role ?? '';
    final canManage = role == 'admin' || role == 'accounts';

    final filter = ref.watch(payoutFilterProvider);
    final async = ref.watch(artistPayoutsProvider);

    return Scaffold(
      backgroundColor: crm.background,
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              onPressed: () => _openEditor(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('New Payout'),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(artistPayoutsProvider),
        child: ListView(
          padding: EdgeInsets.fromLTRB(
              isMobile ? 14 : 24, 18, isMobile ? 14 : 24, 90),
          children: [
            Text('Artist Payouts',
                style: TextStyle(
                    fontSize: isMobile ? 22 : 26,
                    fontWeight: FontWeight.w800,
                    color: crm.textPrimary)),
            Text('Per-booking fees paid to freelance (outsource) artists',
                style: TextStyle(fontSize: 12.5, color: crm.textSecondary)),
            16.hg,

            // Status filters
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final s in const ['all', 'pending', 'approved', 'paid'])
                  _chip(crm, _statusLabel(s), filter.status == s, () {
                    ref.read(payoutFilterProvider.notifier).state =
                        filter.copyWith(status: s);
                  }),
              ],
            ),
            16.hg,

            async.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Text(e.toString().replaceFirst('Exception: ', ''),
                      style: TextStyle(color: crm.textSecondary)),
                ),
              ),
              data: (list) {
                final pending = list
                    .where((p) => p.status == 'pending' || p.status == 'approved')
                    .fold<double>(0, (s, p) => s + p.amount);
                final paid = list
                    .where((p) => p.status == 'paid')
                    .fold<double>(0, (s, p) => s + p.amount);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _summary(crm, 'Outstanding', '₹${_money(pending)}',
                            const Color(0xFFEA580C)),
                        10.wg,
                        _summary(crm, 'Paid', '₹${_money(paid)}',
                            const Color(0xFF16A34A)),
                        10.wg,
                        _summary(crm, 'Records', '${list.length}',
                            const Color(0xFF6D5DF6)),
                      ],
                    ),
                    18.hg,
                    if (list.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 30),
                        child: Center(
                          child: Text('No payouts yet.',
                              style: TextStyle(color: crm.textSecondary)),
                        ),
                      )
                    else
                      for (final p in list)
                        _payoutCard(context, ref, crm, p, canManage),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ── payout row ──
  Widget _payoutCard(BuildContext context, WidgetRef ref, CrmTheme crm,
      ArtistPayout p, bool canManage) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: crm.border),
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
                    Text(p.artistName.isEmpty ? 'Artist' : p.artistName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: crm.textPrimary)),
                    2.hg,
                    Text(
                        [
                          if (p.bookingNumber.isNotEmpty ||
                              p.booking != null)
                            '#${p.booking?.bookingNumber ?? p.bookingNumber}'
                                '${p.booking?.customerName.isNotEmpty == true ? ' · ${p.booking!.customerName}' : ''}',
                          _date(p.date),
                          _modeLabel(p.paymentMode),
                        ].where((s) => s.trim().isNotEmpty).join('  •  '),
                        style: TextStyle(
                            fontSize: 11.5, color: crm.textSecondary)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('₹${_money(p.amount)}',
                      style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          color: crm.textPrimary)),
                  4.hg,
                  _pill(_statusLabel(p.status), _statusColor(p.status)),
                ],
              ),
            ],
          ),
          if (p.notes.isNotEmpty) ...[
            8.hg,
            Text(p.notes,
                style: TextStyle(fontSize: 12, color: crm.textSecondary)),
          ],
          if (canManage) ...[
            10.hg,
            Divider(height: 1, color: crm.border),
            6.hg,
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 6,
              children: [
                if (p.status == 'pending')
                  TextButton.icon(
                    onPressed: () => _run(context, ref,
                        () => ref.read(artistPayoutServiceProvider).approvePayout(p.id),
                        'Approved'),
                    icon: const Icon(Icons.done, size: 16),
                    label: const Text('Approve'),
                  ),
                if (p.status != 'paid') ...[
                  TextButton.icon(
                    onPressed: () => _openEditor(context, ref, existing: p),
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('Edit'),
                  ),
                  FilledButton.icon(
                    onPressed: () => _confirmPay(context, ref, p),
                    icon: const Icon(Icons.payments_outlined, size: 16),
                    label: const Text('Pay'),
                  ),
                ],
                TextButton.icon(
                  onPressed: () => _confirmDelete(context, ref, p),
                  icon: const Icon(Icons.delete_outline, size: 16),
                  label: const Text('Delete'),
                  style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFFDC2626)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ── create / edit editor ──
  void _openEditor(BuildContext context, WidgetRef ref, {ArtistPayout? existing}) {
    final employees = ref.read(employeesProvider).value ?? const <Employee>[];
    final bookings = ref.read(bookingProvider).value ?? const <Booking>[];
    final artists = employees.where((e) => e.isArtist && e.isActive).toList()
      ..sort((a, b) {
        // Freelancers first (this screen is for them), then by name.
        final ao = a.type == 'outsource' ? 0 : 1;
        final bo = b.type == 'outsource' ? 0 : 1;
        if (ao != bo) return ao - bo;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

    String? empId = existing?.employee?.id;
    String? bookingId = existing?.booking?.id;
    final amountCtrl = TextEditingController(
        text: existing != null ? existing.amount.toStringAsFixed(0) : '');
    final notesCtrl = TextEditingController(text: existing?.notes ?? '');
    String mode = existing?.paymentMode ?? 'bank_transfer';
    DateTime date = existing?.date ?? DateTime.now();
    bool saving = false;

    showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setLocal) {
          // Bookings the chosen artist is assigned to (works → finance link).
          final artistBookings = empId == null
              ? <Booking>[]
              : (bookings.where((b) => _onBooking(b, empId!)).toList()
                ..sort((a, b) => b.serviceStart.compareTo(a.serviceStart)));

          return AlertDialog(
            title: Text(existing == null ? 'New Payout' : 'Edit Payout'),
            content: SizedBox(
              width: 420,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Artist
                    DropdownButtonFormField<String>(
                      initialValue: empId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                          labelText: 'Artist', border: OutlineInputBorder()),
                      items: [
                        for (final a in artists)
                          DropdownMenuItem(
                            value: a.id,
                            child: Text(
                                '${a.name}${a.type == 'outsource' ? '  · Freelance' : ''}',
                                overflow: TextOverflow.ellipsis),
                          ),
                      ],
                      onChanged: (v) => setLocal(() {
                        empId = v;
                        bookingId = null;
                      }),
                    ),
                    12.hg,
                    // Booking (for the selected artist)
                    DropdownButtonFormField<String>(
                      initialValue: bookingId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                          labelText: 'Booking (optional)',
                          border: OutlineInputBorder()),
                      items: [
                        const DropdownMenuItem(
                            value: null, child: Text('— No specific booking —')),
                        for (final b in artistBookings)
                          DropdownMenuItem(
                            value: b.id,
                            child: Text(
                                '#${b.displayBookingNumber} · ${b.customerName.isEmpty ? b.service : b.customerName}',
                                overflow: TextOverflow.ellipsis),
                          ),
                      ],
                      onChanged: (v) => setLocal(() => bookingId = v),
                    ),
                    12.hg,
                    TextField(
                      controller: amountCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                          labelText: 'Amount (₹)',
                          hintText: 'Fee agreed for this job',
                          border: OutlineInputBorder()),
                    ),
                    12.hg,
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: mode,
                            decoration: const InputDecoration(
                                labelText: 'Mode',
                                border: OutlineInputBorder()),
                            items: [
                              for (final m in _modes)
                                DropdownMenuItem(
                                    value: m, child: Text(_modeLabel(m))),
                            ],
                            onChanged: (v) => setLocal(() => mode = v ?? mode),
                          ),
                        ),
                        10.wg,
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: ctx,
                                initialDate: date,
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2100),
                              );
                              if (picked != null) setLocal(() => date = picked);
                            },
                            child: Text(_date(date)),
                          ),
                        ),
                      ],
                    ),
                    12.hg,
                    TextField(
                      controller: notesCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Notes (optional)',
                          border: OutlineInputBorder()),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                  onPressed: saving ? null : () => Navigator.pop(ctx),
                  child: const Text('Cancel')),
              FilledButton(
                onPressed: saving
                    ? null
                    : () async {
                        final amount = double.tryParse(amountCtrl.text.trim()) ?? 0;
                        if (empId == null) {
                          _snack(ctx, 'Select an artist', isError: true);
                          return;
                        }
                        if (amount <= 0) {
                          _snack(ctx, 'Enter a valid amount', isError: true);
                          return;
                        }
                        setLocal(() => saving = true);
                        try {
                          final svc = ref.read(artistPayoutServiceProvider);
                          if (existing == null) {
                            await svc.createPayout(
                              employeeId: empId!,
                              bookingId: bookingId,
                              amount: amount,
                              date: date,
                              paymentMode: mode,
                              notes: notesCtrl.text.trim(),
                            );
                          } else {
                            await svc.updatePayout(
                              id: existing.id,
                              amount: amount,
                              date: date,
                              paymentMode: mode,
                              notes: notesCtrl.text.trim(),
                              bookingId: bookingId ?? '',
                            );
                          }
                          ref.invalidate(artistPayoutsProvider);
                          ref.invalidate(artistPayoutsForEmployeeProvider);
                          if (ctx.mounted) Navigator.pop(ctx);
                        } catch (e) {
                          setLocal(() => saving = false);
                          if (ctx.mounted) {
                            _snack(ctx, e.toString().replaceFirst('Exception: ', ''),
                                isError: true);
                          }
                        }
                      },
                child: Text(saving ? 'Saving…' : 'Save'),
              ),
            ],
          );
        });
      },
    );
  }

  Future<void> _confirmPay(BuildContext context, WidgetRef ref, ArtistPayout p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mark as paid?'),
        content: Text(
            'Pay ₹${_money(p.amount)} to ${p.artistName}. This posts the amount '
            'to the books as an artist payout expense and locks the record.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Pay')),
        ],
      ),
    );
    if (ok != true) return;
    if (!context.mounted) return;
    await _run(context, ref,
        () => ref.read(artistPayoutServiceProvider).payPayout(p.id), 'Marked paid');
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, ArtistPayout p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete payout?'),
        content: Text(
            'Remove the ₹${_money(p.amount)} payout for ${p.artistName}?'
            '${p.status == 'paid' ? ' Its ledger entry will also be reversed.' : ''}'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFDC2626)),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    if (!context.mounted) return;
    await _run(context, ref, () async {
      await ref.read(artistPayoutServiceProvider).deletePayout(p.id);
    }, 'Payout removed');
  }

  Future<void> _run(BuildContext context, WidgetRef ref,
      Future<void> Function() action, String successMsg) async {
    try {
      await action();
      ref.invalidate(artistPayoutsProvider);
      ref.invalidate(artistPayoutsForEmployeeProvider);
      if (context.mounted) _snack(context, successMsg);
    } catch (e) {
      if (context.mounted) {
        _snack(context, e.toString().replaceFirst('Exception: ', ''), isError: true);
      }
    }
  }

  // ── small helpers ──
  void _snack(BuildContext context, String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
    ));
  }

  Widget _summary(CrmTheme crm, String label, String value, Color color) =>
      Expanded(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: crm.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: crm.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: color)),
              Text(label,
                  style: TextStyle(fontSize: 11, color: crm.textSecondary)),
            ],
          ),
        ),
      );

  Widget _chip(CrmTheme crm, String label, bool sel, VoidCallback onTap) =>
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(100),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: sel ? crm.primary : crm.surface,
            borderRadius: BorderRadius.circular(100),
            border: Border.all(color: sel ? crm.primary : crm.border),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: sel ? Colors.white : crm.textSecondary)),
        ),
      );

  Widget _pill(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(100)),
        child: Text(text,
            style: TextStyle(
                fontSize: 10.5, fontWeight: FontWeight.w700, color: color)),
      );

  static bool _onBooking(Booking b, String id) {
    if (id.isEmpty) return false;
    if (b.assignedStaff.any((s) => s.employeeId == id)) return true;
    for (final item in b.bookingItems) {
      if (item.assignedStaff.any((s) => s.employeeId == id)) return true;
    }
    return false;
  }

  static String _statusLabel(String s) {
    switch (s) {
      case 'all':
        return 'All';
      case 'pending':
        return 'Pending';
      case 'approved':
        return 'Approved';
      case 'paid':
        return 'Paid';
      case 'cancelled':
        return 'Cancelled';
      default:
        return s;
    }
  }

  static Color _statusColor(String s) {
    switch (s) {
      case 'paid':
        return const Color(0xFF16A34A);
      case 'approved':
        return const Color(0xFF2563EB);
      case 'cancelled':
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFFEA580C); // pending
    }
  }

  static String _modeLabel(String m) {
    switch (m) {
      case 'cash':
        return 'Cash';
      case 'upi':
        return 'UPI';
      case 'bank_transfer':
        return 'Bank';
      default:
        return 'Other';
    }
  }

  static const _mon = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul',
      'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  static String _date(DateTime d) => '${d.day} ${_mon[d.month]} ${d.year}';

  static String _money(double v) {
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}k';
    return v.toStringAsFixed(0);
  }
}

extension _Gap on num {
  Widget get hg => SizedBox(height: toDouble());
  Widget get wg => SizedBox(width: toDouble());
}
