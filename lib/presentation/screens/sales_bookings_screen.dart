import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/extensions/space_extension.dart';
import '../../core/models/booking.dart';
import '../../core/providers/booking_provider.dart';
import '../../core/theme/crm_theme.dart';
import '../../core/utils/responsive_builder.dart';

class SalesBookingsScreen extends HookConsumerWidget {
  const SalesBookingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crmColors = context.crmColors;
    final theme = Theme.of(context);
    final asyncBookings = ref.watch(bookingProvider);
    final isMobile = ResponsiveBuilder.isMobile(context);
    final selectedIds = useState<Set<String>>(<String>{});

    Future<void> deleteBookings(List<String> bookingIds) async {
      if (bookingIds.isEmpty) return;

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(
            bookingIds.length == 1 ? 'Delete Booking' : 'Delete Bookings',
          ),
          content: Text(
            bookingIds.length == 1
                ? 'This booking will be deleted permanently.'
                : '${bookingIds.length} bookings will be deleted permanently.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete'),
            ),
          ],
        ),
      );

      if (confirmed != true || !context.mounted) return;

      final notifier = ref.read(bookingProvider.notifier);
      for (final bookingId in bookingIds) {
        await notifier.removeBooking(bookingId);
      }

      selectedIds.value = {
        for (final existingId in selectedIds.value)
          if (!bookingIds.contains(existingId)) existingId,
      };
    }

    return asyncBookings.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Text(
          'Failed to load bookings: $error',
          style: TextStyle(color: crmColors.textSecondary),
        ),
      ),
      data: (bookings) {
        final sortedBookings = [...bookings]
          ..sort((a, b) => b.bookingDate.compareTo(a.bookingDate));

        final totalSales = sortedBookings.fold<double>(
          0,
          (sum, booking) => sum + booking.totalPrice,
        );
        final totalAdvance = sortedBookings.fold<double>(
          0,
          (sum, booking) => sum + booking.advanceAmount,
        );
        final completedCount = sortedBookings
            .where((booking) => booking.status.toLowerCase() == 'completed')
            .length;
        final cancelledCount = sortedBookings
            .where((booking) => booking.status.toLowerCase() == 'cancelled')
            .length;
        final allSelected =
            sortedBookings.isNotEmpty &&
            sortedBookings.every((booking) => selectedIds.value.contains(booking.id));

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sales & Invoices',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              8.h,
              Text(
                'All bookings with financial status, advance tracking, and invoice-ready totals.',
                style: TextStyle(
                  color: crmColors.textSecondary,
                  fontSize: 15,
                ),
              ),
              20.h,
              Row(
                children: [
                  if (!isMobile) ...[
                    Checkbox(
                      value: allSelected,
                      onChanged: sortedBookings.isEmpty
                          ? null
                          : (value) {
                              selectedIds.value = value == true
                                  ? {
                                      for (final booking in sortedBookings)
                                        booking.id,
                                    }
                                  : <String>{};
                            },
                    ),
                    Text(
                      'Select all',
                      style: TextStyle(color: crmColors.textSecondary),
                    ),
                  ],
                  const Spacer(),
                  if (selectedIds.value.isNotEmpty)
                    ElevatedButton.icon(
                      onPressed: () =>
                          deleteBookings(selectedIds.value.toList(growable: false)),
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: Text('Delete Selected (${selectedIds.value.length})'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: crmColors.destructive,
                        foregroundColor: Colors.white,
                      ),
                    ),
                ],
              ),
              24.h,
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  _MetricCard(
                    label: 'Total Bookings',
                    value: '${sortedBookings.length}',
                  ),
                  _MetricCard(
                    label: 'Sales Value',
                    value: '₹${_money(totalSales)}',
                  ),
                  _MetricCard(
                    label: 'Advance Collected',
                    value: '₹${_money(totalAdvance)}',
                  ),
                  _MetricCard(
                    label: 'Completed',
                    value: '$completedCount',
                  ),
                  _MetricCard(
                    label: 'Cancelled',
                    value: '$cancelledCount',
                  ),
                ],
              ),
              24.h,
              Container(
                decoration: BoxDecoration(
                  color: crmColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: crmColors.border),
                ),
                child: isMobile
                    ? Column(
                        children: sortedBookings
                            .map(
                              (booking) => _MobileBookingCard(
                                booking: booking,
                                isSelected: selectedIds.value.contains(booking.id),
                                onSelectChanged: (value) {
                                  final next = {...selectedIds.value};
                                  if (value == true) {
                                    next.add(booking.id);
                                  } else {
                                    next.remove(booking.id);
                                  }
                                  selectedIds.value = next;
                                },
                                onDelete: () => deleteBookings([booking.id]),
                              ),
                            )
                            .toList(),
                      )
                    : Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 16,
                            ),
                            child: Row(
                              children: const [
                                SizedBox(width: 44),
                                Expanded(flex: 2, child: _HeaderText('Booking')),
                                Expanded(flex: 2, child: _HeaderText('Client')),
                                Expanded(flex: 2, child: _HeaderText('Package')),
                                Expanded(child: _HeaderText('Status')),
                                Expanded(child: _HeaderText('Advance')),
                                Expanded(child: _HeaderText('Total')),
                                Expanded(child: _HeaderText('Balance')),
                                SizedBox(width: 132),
                              ],
                            ),
                          ),
                          const Divider(height: 1),
                          ...sortedBookings.map(
                            (booking) => _DesktopBookingRow(
                              booking: booking,
                              isSelected: selectedIds.value.contains(booking.id),
                              onSelectChanged: (value) {
                                final next = {...selectedIds.value};
                                if (value == true) {
                                  next.add(booking.id);
                                } else {
                                  next.remove(booking.id);
                                }
                                selectedIds.value = next;
                              },
                              onDelete: () => deleteBookings([booking.id]),
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;

  const _MetricCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final crmColors = context.crmColors;
    return Container(
      width: 220,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: crmColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: crmColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: crmColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
          10.h,
          Text(
            value,
            style: TextStyle(
              color: crmColors.textPrimary,
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderText extends StatelessWidget {
  final String text;

  const _HeaderText(this.text);

  @override
  Widget build(BuildContext context) {
    final crmColors = context.crmColors;
    return Text(
      text,
      style: TextStyle(
        color: crmColors.textSecondary,
        fontWeight: FontWeight.w700,
        fontSize: 12,
        letterSpacing: 1,
      ),
    );
  }
}

class _DesktopBookingRow extends StatelessWidget {
  final Booking booking;
  final bool isSelected;
  final ValueChanged<bool?> onSelectChanged;
  final VoidCallback onDelete;

  const _DesktopBookingRow({
    required this.booking,
    required this.isSelected,
    required this.onSelectChanged,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final crmColors = context.crmColors;
    final balance = ((booking.totalPrice -
                booking.advanceAmount -
                booking.discountAmount)
            .clamp(0, double.infinity))
        .toDouble();

    return InkWell(
      onTap: () => context.go('/booking/manage/${booking.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            SizedBox(
              width: 44,
              child: Checkbox(
                value: isSelected,
                onChanged: onSelectChanged,
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                '#${booking.displayBookingNumber}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            Expanded(flex: 2, child: Text(booking.customerName)),
            Expanded(flex: 2, child: Text(booking.service)),
            Expanded(child: _StatusChip(status: booking.status)),
            Expanded(child: Text('₹${_money(booking.advanceAmount)}')),
            Expanded(child: Text('₹${_money(booking.totalPrice)}')),
            Expanded(child: Text('₹${_money(balance)}')),
            SizedBox(
              width: 132,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Expanded(
                    child: Text(
                      _formatDate(booking.bookingDate),
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: crmColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: onDelete,
                    tooltip: 'Delete booking',
                    icon: Icon(
                      Icons.delete_outline,
                      color: crmColors.destructive,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MobileBookingCard extends StatelessWidget {
  final Booking booking;
  final bool isSelected;
  final ValueChanged<bool?> onSelectChanged;
  final VoidCallback onDelete;

  const _MobileBookingCard({
    required this.booking,
    required this.isSelected,
    required this.onSelectChanged,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final crmColors = context.crmColors;
    final balance = ((booking.totalPrice -
                booking.advanceAmount -
                booking.discountAmount)
            .clamp(0, double.infinity))
        .toDouble();

    return InkWell(
      onTap: () => context.go('/booking/manage/${booking.id}'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: crmColors.border)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Checkbox(
                  value: isSelected,
                  onChanged: onSelectChanged,
                ),
                Expanded(
                  child: Text(
                    booking.customerName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                _StatusChip(status: booking.status),
              ],
            ),
            8.h,
            Text(
              '#${booking.displayBookingNumber} • ${booking.service}',
              style: TextStyle(
                color: crmColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            10.h,
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                _MiniFinance(
                  label: 'Advance',
                  value: '₹${_money(booking.advanceAmount)}',
                ),
                _MiniFinance(
                  label: 'Total',
                  value: '₹${_money(booking.totalPrice)}',
                ),
                _MiniFinance(
                  label: 'Balance',
                  value: '₹${_money(balance)}',
                ),
                _MiniFinance(
                  label: 'Date',
                  value: _formatDate(booking.bookingDate),
                ),
              ],
            ),
            8.h,
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onDelete,
                icon: Icon(Icons.delete_outline, color: crmColors.destructive),
                label: Text(
                  'Delete',
                  style: TextStyle(color: crmColors.destructive),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniFinance extends StatelessWidget {
  final String label;
  final String value;

  const _MiniFinance({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final crmColors = context.crmColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: crmColors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: crmColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          4.h,
          Text(
            value,
            style: TextStyle(
              color: crmColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    switch (status.toLowerCase()) {
      case 'completed':
        bg = Colors.green.withValues(alpha: 0.12);
        fg = Colors.green.shade700;
        break;
      case 'cancelled':
        bg = Colors.red.withValues(alpha: 0.12);
        fg = Colors.red.shade700;
        break;
      case 'confirmed':
        bg = Colors.blue.withValues(alpha: 0.12);
        fg = Colors.blue.shade700;
        break;
      default:
        bg = Colors.amber.withValues(alpha: 0.14);
        fg = Colors.amber.shade800;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: fg,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

String _money(double value) {
  return value.toStringAsFixed(0);
}

String _formatDate(DateTime value) {
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  return '$day/$month/${value.year}';
}
