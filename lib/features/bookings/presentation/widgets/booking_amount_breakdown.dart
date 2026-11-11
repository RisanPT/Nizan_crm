import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/bookings/data/booking.dart';

/// One line of the amount breakdown (a package or an add-on).
class BreakdownLine {
  const BreakdownLine({
    required this.label,
    this.detail = '',
    required this.amount,
    this.persons = 1,
    this.packageName = '',
  });
  final String label;
  final String detail;
  final double amount;

  /// Add-ons only: number of persons, and the package it belongs to (set on
  /// multi-package bookings).
  final int persons;
  final String packageName;

  /// Invoice line text, e.g. "Extra look × 2 (Wedding)".
  String get invoiceLabel =>
      '$label${persons > 1 ? ' × $persons' : ''}${packageName.isNotEmpty ? ' ($packageName)' : ''}';
}

/// Pure numbers behind [BookingAmountBreakdown], kept separate so they can be
/// unit-tested and reused (PDF, CSV) without a widget.
class BookingAmounts {
  BookingAmounts._({
    required this.packages,
    required this.addons,
    required this.otherCharges,
    required this.orderValue,
    required this.discount,
    required this.netPayable,
    required this.advance,
    required this.collected,
    required this.balance,
  });

  final List<BreakdownLine> packages;
  final List<BreakdownLine> addons;

  /// Part of the order value not explained by packages + add-ons (e.g. the
  /// extra-date charge on a single-package booking). 0 when everything adds up.
  final double otherCharges;

  /// Complete order value = package(s) + add-ons (the booking's totalPrice).
  final double orderValue;
  final double discount;

  /// What the client pays: order value − discount.
  final double netPayable;
  final double advance;

  /// Verified collections after the event.
  final double collected;

  /// Still to collect on record: net payable − advance − collected (never < 0).
  final double balance;

  double get addonsTotal => addons.fold(0.0, (s, a) => s + a.amount);
  double get received => advance + collected;

  static final DateFormat _day = DateFormat('d MMM yyyy');

  static String _addonDetail(BookingAddon a) =>
      '₹${a.amount.toStringAsFixed(0)} × ${a.persons} ${a.persons == 1 ? 'person' : 'people'}';

  static double _addonAmount(BookingAddon a) => a.amount * (a.persons < 1 ? 1 : a.persons);

  factory BookingAmounts.of(Booking b) {
    final multi = b.bookingItems.length > 1;

    // Add-ons: a multi-package booking carries them per package (labelled
    // with the package); booking-level add-ons always count. Mirrors the
    // server's total rule in bookingController (create + update).
    final addons = <BreakdownLine>[
      if (multi)
        for (final item in b.bookingItems)
          for (final a in item.addons)
            BreakdownLine(
              label: a.service.isEmpty ? 'Add-on' : a.service,
              detail: '${_addonDetail(a)} · ${item.service.isEmpty ? 'Package' : item.service}',
              amount: _addonAmount(a),
              persons: a.persons,
              packageName: item.service.isEmpty ? 'Package' : item.service,
            ),
      for (final a in b.addons)
        BreakdownLine(
          label: a.service.isEmpty ? 'Add-on' : a.service,
          detail: _addonDetail(a),
          amount: _addonAmount(a),
          persons: a.persons,
        ),
    ];
    final addonsTotal = addons.fold(0.0, (s, a) => s + a.amount);

    String dates(List<DateTime> d) => d.map(_day.format).join(', ');
    String detailOf(String slot, List<DateTime> d) =>
        [if (slot.isNotEmpty) slot, if (d.isNotEmpty) dates(d)].join(' · ');

    final List<BreakdownLine> packages;
    if (b.bookingItems.isNotEmpty) {
      packages = [
        for (final i in b.bookingItems)
          BreakdownLine(
            label: i.service.isEmpty ? 'Package' : i.service,
            detail: detailOf(i.eventSlot, i.selectedDates),
            amount: i.totalPrice,
          ),
      ];
    } else {
      // Single legacy booking: totalPrice already includes the add-ons.
      final pkg = b.totalPrice - addonsTotal;
      packages = [
        BreakdownLine(
          label: b.service.isEmpty ? 'Package' : b.service,
          detail: detailOf(b.eventSlot, b.selectedDates),
          amount: pkg < 0 ? 0 : pkg,
        ),
      ];
    }

    final packagesTotal = packages.fold(0.0, (s, p) => s + p.amount);
    final orderValue = b.totalPrice < 0 ? 0.0 : b.totalPrice;
    final other = orderValue - packagesTotal - addonsTotal;
    final discount = b.discountAmount < 0 ? 0.0 : b.discountAmount;
    final net = (orderValue - discount) < 0 ? 0.0 : orderValue - discount;
    final balance = net - b.advanceAmount - b.collectedAmount;

    return BookingAmounts._(
      packages: packages,
      addons: addons,
      // Ignore rounding noise.
      otherCharges: other.abs() < 1 ? 0 : other,
      orderValue: orderValue,
      discount: discount,
      netPayable: net,
      advance: b.advanceAmount,
      collected: b.collectedAmount,
      balance: balance < 0 ? 0 : balance,
    );
  }
}

/// Full money picture of a booking: packages, add-ons, order value, discount,
/// advance, collections and balance. Used by Invoices & Bookings quick view
/// and the Accounts invoice detail.
class BookingAmountBreakdown extends StatelessWidget {
  const BookingAmountBreakdown({super.key, required this.booking});
  final Booking booking;

  static final NumberFormat _inr =
      NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final b = booking;
    final a = BookingAmounts.of(b);

    Widget section(String title) => Padding(
          padding: const EdgeInsets.only(top: 14, bottom: 6),
          child: Text(title.toUpperCase(),
              style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 0.6,
                  fontWeight: FontWeight.w800,
                  color: crm.textSecondary)),
        );

    Widget line(String label, double amount,
            {String detail = '', bool bold = false, Color? color, String prefix = ''}) =>
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: TextStyle(
                            fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                            fontSize: bold ? 14.5 : 13.5,
                            color: color ?? crm.textPrimary)),
                    if (detail.isNotEmpty)
                      Text(detail, style: TextStyle(fontSize: 11.5, color: crm.textSecondary)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text('$prefix${_inr.format(amount)}',
                  style: TextStyle(
                      fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
                      fontSize: bold ? 15 : 13.5,
                      color: color ?? crm.textPrimary)),
            ],
          ),
        );

    Widget note(String text, {Color? color}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Text(text, style: TextStyle(fontSize: 12, color: color ?? crm.textSecondary)),
        );

    final discountDetail = [
      if (b.discountType == 'percent' && b.discountValue > 0)
        '${b.discountValue.toStringAsFixed(b.discountValue % 1 == 0 ? 0 : 1)}%',
      if (b.discountReason.trim().isNotEmpty) b.discountReason.trim(),
    ].join(' · ');

    final workDone = !b.hasPendingWork;
    final status = b.status.toLowerCase();

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: crm.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          section(a.packages.length > 1 ? 'Packages (${a.packages.length})' : 'Package'),
          for (final p in a.packages) line(p.label, p.amount, detail: p.detail),

          section('Add-ons'),
          if (a.addons.isEmpty)
            note('No add-ons taken')
          else ...[
            for (final x in a.addons) line(x.label, x.amount, detail: x.detail),
            if (a.addons.length > 1) line('Add-ons total', a.addonsTotal, color: crm.textSecondary),
          ],
          if (a.otherCharges != 0)
            line(a.otherCharges > 0 ? 'Other charges' : 'Adjustment', a.otherCharges,
                detail: 'Extra dates / manual price change'),

          const Divider(height: 20),
          line('Total order value', a.orderValue,
              detail: 'Package + add-ons', bold: true, color: crm.primary),

          section('Discount'),
          if (a.discount <= 0)
            note('No discount given')
          else
            line('Discount', a.discount,
                detail: discountDetail, prefix: '− ', color: crm.destructive),
          if (a.discount > 0) line('Net payable', a.netPayable, bold: true),

          section('Payments'),
          line('Advance taken', a.advance,
              detail: [
                if (b.paymentMode.isNotEmpty) b.paymentMode,
                if (a.advance <= 0) 'No advance recorded',
              ].join(' · '),
              color: a.advance > 0 ? crm.success : crm.textSecondary),
          line('Collected after event', a.collected,
              detail: 'Verified collections',
              color: a.collected > 0 ? crm.success : crm.textSecondary),
          line('Total received', a.received, bold: true),

          const Divider(height: 20),
          line('Balance due', a.balance,
              bold: true, color: a.balance > 0 ? crm.warning : crm.success),
          if (a.balance <= 0)
            note('Fully paid', color: crm.success)
          else if (workDone && status != 'cancelled' && status != 'rejected')
            note('Work is complete but this balance is not yet recorded as collected.',
                color: crm.warning),
        ],
      ),
    );
  }
}
