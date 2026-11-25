import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:nizan_crm/core/error/error_message.dart';
import 'package:nizan_crm/core/error/error_snackbar.dart';
import 'package:nizan_crm/core/providers/auth_provider.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/bookings/controllers/booking_provider.dart';
import 'package:nizan_crm/features/bookings/data/booking.dart';
import 'package:nizan_crm/features/bookings/presentation/widgets/booking_amount_breakdown.dart';

/// Roles allowed to correct a booking's advance. Must match
/// ADVANCE_EDIT_ROLES in the backend's bookingAdvanceController.
const kAdvanceEditRoles = {'admin', 'accounts', 'finance_head', 'manager'};

bool canEditAdvance(WidgetRef ref) =>
    kAdvanceEditRoles.contains(ref.watch(authSessionProvider)?.role.trim().toLowerCase() ?? '');

final NumberFormat _inr = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

/// Opens "Edit advance" for [booking]. Returns the saved booking, or null when
/// cancelled.
Future<Booking?> showEditAdvanceDialog(BuildContext context, Booking booking) {
  return showDialog<Booking>(
    context: context,
    builder: (_) => _EditAdvanceDialog(booking: booking),
  );
}

class _EditAdvanceDialog extends ConsumerStatefulWidget {
  const _EditAdvanceDialog({required this.booking});
  final Booking booking;

  @override
  ConsumerState<_EditAdvanceDialog> createState() => _EditAdvanceDialogState();
}

class _EditAdvanceDialogState extends ConsumerState<_EditAdvanceDialog> {
  late final List<TextEditingController> _amounts;
  final _reason = TextEditingController();
  bool _saving = false;
  String? _error;

  Booking get b => widget.booking;

  /// One field per package on a multi-package booking, else a single field.
  bool get _perPackage => b.bookingItems.length > 1;

  @override
  void initState() {
    super.initState();
    String fmt(double v) => v.toStringAsFixed(v % 1 == 0 ? 0 : 2);
    _amounts = _perPackage
        ? [for (final i in b.bookingItems) TextEditingController(text: fmt(i.advanceAmount))]
        : [TextEditingController(text: fmt(b.advanceAmount))];
    for (final c in _amounts) {
      c.addListener(() => setState(() => _error = null));
    }
  }

  @override
  void dispose() {
    for (final c in _amounts) {
      c.dispose();
    }
    _reason.dispose();
    super.dispose();
  }

  double? _parse(TextEditingController c) {
    final v = double.tryParse(c.text.trim().isEmpty ? '0' : c.text.trim());
    return v == null || v < 0 ? null : v;
  }

  double get _newTotal => _amounts.fold(0.0, (s, c) => s + (_parse(c) ?? 0));

  Future<void> _save() async {
    final values = [for (final c in _amounts) _parse(c)];
    if (values.any((v) => v == null)) {
      setState(() => _error = 'Enter a valid amount (0 or more).');
      return;
    }
    final net = BookingAmounts.of(b).netPayable;
    if (_newTotal + b.collectedAmount > net + 0.009) {
      setState(() => _error =
          'Advance plus collected (${_inr.format(_newTotal + b.collectedAmount)}) is more than the bill (${_inr.format(net)}).');
      return;
    }
    final unchanged = _perPackage
        ? [for (var i = 0; i < values.length; i++) values[i] == b.bookingItems[i].advanceAmount]
            .every((same) => same)
        : values.first == b.advanceAmount;
    if (unchanged) {
      setState(() => _error = 'The advance is unchanged.');
      return;
    }
    if (_reason.text.trim().isEmpty) {
      setState(() => _error = 'Give a reason for the change.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final saved = await ref.read(bookingProvider.notifier).updateAdvance(
            b.id,
            amount: _perPackage ? null : values.first,
            itemAmounts: _perPackage ? {for (var i = 0; i < values.length; i++) i: values[i]!} : null,
            reason: _reason.text.trim(),
          );
      if (!mounted) return;
      final reverify = b.advanceStatus == 'verified' && saved.advanceStatus == 'pending';
      showSuccessSnackBar(
        context,
        reverify
            ? 'Advance updated to ${_inr.format(saved.advanceAmount)} — sent to Accounts to verify again'
            : 'Advance updated to ${_inr.format(saved.advanceAmount)}',
      );
      Navigator.of(context).pop(saved);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = friendlyErrorMessage(e);
      });
    }
  }

  Widget _amountField(TextEditingController c, String label) => TextField(
        controller: c,
        enabled: !_saving,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
        decoration: InputDecoration(labelText: label, prefixText: '₹ ', isDense: true),
      );

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final a = BookingAmounts.of(b);
    final balanceAfter = (a.netPayable - _newTotal - b.collectedAmount).clamp(0, double.infinity);

    return AlertDialog(
      title: const Text('Edit advance'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${b.customerName}${b.bookingNumber.isNotEmpty ? ' · ${b.bookingNumber}' : ''}',
                style: TextStyle(color: crm.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 4),
              Text('Advance the client actually paid. Enter 0 if nothing was paid.',
                  style: TextStyle(color: crm.textSecondary, fontSize: 12)),
              const SizedBox(height: 14),
              if (_perPackage)
                for (var i = 0; i < _amounts.length; i++) ...[
                  _amountField(
                    _amounts[i],
                    b.bookingItems[i].service.isEmpty ? 'Package ${i + 1}' : b.bookingItems[i].service,
                  ),
                  const SizedBox(height: 10),
                ]
              else ...[
                _amountField(_amounts.first, 'Advance paid'),
                const SizedBox(height: 10),
              ],
              TextField(
                controller: _reason,
                enabled: !_saving,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Reason for the change',
                  hintText: 'e.g. Client paid ₹5000, not ₹3000',
                  isDense: true,
                ),
              ),
              const SizedBox(height: 14),
              _Figure('Net payable', _inr.format(a.netPayable)),
              _Figure('Advance', '${_inr.format(b.advanceAmount)} → ${_inr.format(_newTotal)}'),
              if (b.collectedAmount > 0) _Figure('Collected after event', _inr.format(b.collectedAmount)),
              _Figure('Balance due after', _inr.format(balanceAfter), bold: true),
              if (b.advanceStatus == 'verified') ...[
                const SizedBox(height: 10),
                Text(
                  'Accounts already verified this advance. Changing the amount sends it back to them to verify again.',
                  style: TextStyle(color: crm.warning, fontSize: 12),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: TextStyle(color: crm.destructive, fontSize: 12.5)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Save'),
        ),
      ],
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure(this.label, this.value, {this.bold = false});
  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: 13,
      fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
      color: context.crmColors.textPrimary,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(children: [Expanded(child: Text(label, style: style)), Text(value, style: style)]),
    );
  }
}

/// [BookingAmountBreakdown] with the "Edit advance" pencil for the roles
/// allowed to use it. Keeps the latest saved copy so the panel updates at once.
class EditableBookingAmountBreakdown extends ConsumerStatefulWidget {
  const EditableBookingAmountBreakdown({super.key, required this.booking, this.onChanged});
  final Booking booking;

  /// Called with the saved booking after an advance edit.
  final ValueChanged<Booking>? onChanged;

  @override
  ConsumerState<EditableBookingAmountBreakdown> createState() => _EditableBookingAmountBreakdownState();
}

class _EditableBookingAmountBreakdownState extends ConsumerState<EditableBookingAmountBreakdown> {
  late Booking _booking = widget.booking;

  @override
  void didUpdateWidget(covariant EditableBookingAmountBreakdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.booking, widget.booking)) _booking = widget.booking;
  }

  @override
  Widget build(BuildContext context) {
    return BookingAmountBreakdown(
      booking: _booking,
      onEditAdvance: canEditAdvance(ref)
          ? () async {
              final saved = await showEditAdvanceDialog(context, _booking);
              if (saved == null || !mounted) return;
              setState(() => _booking = saved);
              widget.onChanged?.call(saved);
            }
          : null,
    );
  }
}
