import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/extensions/space_extension.dart';
import '../../core/models/booking.dart';
import '../../core/providers/booking_provider.dart';
import '../../core/theme/crm_theme.dart';
import '../../core/utils/responsive_builder.dart';

class BookingRequestsScreen extends ConsumerStatefulWidget {
  const BookingRequestsScreen({super.key});

  @override
  ConsumerState<BookingRequestsScreen> createState() =>
      _BookingRequestsScreenState();
}

class _BookingRequestsScreenState extends ConsumerState<BookingRequestsScreen> {
  final Set<String> _selectedIds = <String>{};
  bool _bulkSaving = false;
  String? _activeBookingId;

  Future<void> _updateStatus(Booking booking, String status) async {
    await ref.read(bookingProvider.notifier).updateBooking(
          booking.copyWith(status: status),
        );
  }

  Future<void> _bulkConfirm(List<Booking> pendingBookings) async {
    if (_selectedIds.isEmpty) return;

    setState(() => _bulkSaving = true);
    try {
      final toUpdate = pendingBookings
          .where((booking) => _selectedIds.contains(booking.id))
          .toList();

      for (final booking in toUpdate) {
        await _updateStatus(booking, 'confirmed');
      }

      if (mounted) {
        setState(() {
          _selectedIds.clear();
          _activeBookingId = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${toUpdate.length} booking(s) confirmed.'),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to confirm bookings: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _bulkSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final crmColors = context.crmColors;
    final isMobile = ResponsiveBuilder.isMobile(context);
    final asyncBookings = ref.watch(bookingProvider);

    return asyncBookings.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Text('Failed to load booking requests: $error'),
      ),
      data: (bookings) {
        final pendingBookings = bookings
            .where((booking) => booking.status.toLowerCase() == 'pending')
            .toList()
          ..sort((a, b) => a.serviceStart.compareTo(b.serviceStart));

        final activeBooking = pendingBookings.cast<Booking?>().firstWhere(
              (booking) => booking?.id == _activeBookingId,
              orElse: () => pendingBookings.isNotEmpty ? pendingBookings.first : null,
            );

        if (pendingBookings.isNotEmpty && _activeBookingId == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() => _activeBookingId = pendingBookings.first.id);
            }
          });
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Booking Requests',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      8.h,
                      Text(
                        'Review new bookings, accept or reject individually, and bulk confirm orders from one place.',
                        style: TextStyle(color: crmColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                if (!isMobile)
                  FilledButton.icon(
                    onPressed: _bulkSaving || _selectedIds.isEmpty
                        ? null
                        : () => _bulkConfirm(pendingBookings),
                    icon: _bulkSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.done_all),
                    label: Text('Bulk Accept (${_selectedIds.length})'),
                  ),
              ],
            ),
            24.h,
            if (isMobile && pendingBookings.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _bulkSaving || _selectedIds.isEmpty
                        ? null
                        : () => _bulkConfirm(pendingBookings),
                    icon: _bulkSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.done_all),
                    label: Text('Bulk Accept (${_selectedIds.length})'),
                  ),
                ),
              ),
            if (pendingBookings.isEmpty)
              Expanded(
                child: Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 420),
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: crmColors.surface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: crmColors.border),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.mark_email_read_outlined,
                          size: 48,
                          color: crmColors.textSecondary,
                        ),
                        14.h,
                        Text(
                          'No pending booking requests.',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        8.h,
                        Text(
                          'New client bookings will appear here for admin approval.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: crmColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else if (isMobile)
              Expanded(
                child: ListView.separated(
                  itemCount: pendingBookings.length,
                  separatorBuilder: (_, __) => 12.h,
                  itemBuilder: (context, index) {
                    final booking = pendingBookings[index];
                    return _MobileBookingRequestCard(
                      booking: booking,
                      selected: _selectedIds.contains(booking.id),
                      onSelected: (selected) {
                        setState(() {
                          if (selected == true) {
                            _selectedIds.add(booking.id);
                          } else {
                            _selectedIds.remove(booking.id);
                          }
                        });
                      },
                      onReview: () async {
                        await showDialog<void>(
                          context: context,
                          builder: (_) => _BookingApprovalDialog(booking: booking),
                        );
                      },
                    );
                  },
                ),
              )
            else
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 5,
                      child: Card(
                        child: Padding(
                          padding: 20.p,
                          child: ListView.separated(
                            itemCount: pendingBookings.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final booking = pendingBookings[index];
                              final isSelected = _selectedIds.contains(booking.id);
                              final isActive = booking.id == activeBooking?.id;

                              return InkWell(
                                onTap: () => setState(() => _activeBookingId = booking.id),
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isActive
                                        ? crmColors.secondary.withValues(alpha: 0.35)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Row(
                                    children: [
                                      Checkbox(
                                        value: isSelected,
                                        onChanged: (selected) {
                                          setState(() {
                                            if (selected == true) {
                                              _selectedIds.add(booking.id);
                                            } else {
                                              _selectedIds.remove(booking.id);
                                            }
                                          });
                                        },
                                      ),
                                      CircleAvatar(
                                        backgroundColor: crmColors.secondary,
                                        child: Text(
                                          booking.initials,
                                          style: TextStyle(
                                            color: crmColors.primary,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      14.w,
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              booking.customerName,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            4.h,
                                            Text(
                                              booking.service,
                                              style: TextStyle(
                                                color: crmColors.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      SizedBox(
                                        width: 150,
                                        child: Text(
                                          _formatBookingDateTime(booking),
                                          style: TextStyle(
                                            color: crmColors.textSecondary,
                                          ),
                                        ),
                                      ),
                                      14.w,
                                      OutlinedButton(
                                        onPressed: () => setState(
                                          () => _activeBookingId = booking.id,
                                        ),
                                        child: const Text('Open'),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                    24.w,
                    Expanded(
                      flex: 4,
                      child: _AdminReviewSlide(
                        booking: activeBooking,
                        onAccept: activeBooking == null
                            ? null
                            : () async {
                                await _updateStatus(activeBooking, 'confirmed');
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Booking confirmed and moved to calendar.',
                                      ),
                                    ),
                                  );
                                }
                              },
                        onReject: activeBooking == null
                            ? null
                            : () async {
                                await _updateStatus(activeBooking, 'rejected');
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Booking rejected.'),
                                    ),
                                  );
                                }
                              },
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _AdminReviewSlide extends StatelessWidget {
  final Booking? booking;
  final Future<void> Function()? onAccept;
  final Future<void> Function()? onReject;

  const _AdminReviewSlide({
    required this.booking,
    required this.onAccept,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final crmColors = context.crmColors;

    return Card(
      child: Padding(
        padding: 24.p,
        child: booking == null
            ? Center(
                child: Text(
                  'Select a booking request to review.',
                  style: TextStyle(color: crmColors.textSecondary),
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: crmColors.secondary,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'NEW BOOKING SLIDE',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                        color: crmColors.primary,
                      ),
                    ),
                  ),
                  18.h,
                  Text(
                    'Accept Or Reject Booking',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  10.h,
                  Text(
                    'Confirm this booking to move it into the CRM calendar, or reject it to stop the request.',
                    style: TextStyle(color: crmColors.textSecondary, height: 1.5),
                  ),
                  24.h,
                  _ApprovalRow(label: 'Client', value: booking!.customerName),
                  _ApprovalRow(label: 'Phone', value: booking!.phone),
                  _ApprovalRow(label: 'Package', value: booking!.service),
                  _ApprovalRow(
                    label: 'Region',
                    value: booking!.region.isEmpty ? 'Default' : booking!.region,
                  ),
                  _ApprovalRow(
                    label: 'Date',
                    value: _formatBookingDateTime(booking!, dateOnly: true),
                  ),
                  _ApprovalRow(
                    label: 'Time',
                    value: _formatBookingDateTime(booking!, timeOnly: true),
                  ),
                  _ApprovalRow(
                    label: 'Advance',
                    value: '₹ ${booking!.advanceAmount.toStringAsFixed(0)}',
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: onReject == null ? null : () => onReject!.call(),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: crmColors.destructive,
                            side: BorderSide(color: crmColors.destructive),
                            padding: const EdgeInsets.symmetric(vertical: 18),
                          ),
                          child: const Text('Reject'),
                        ),
                      ),
                      14.w,
                      Expanded(
                        child: ElevatedButton(
                          onPressed: onAccept == null ? null : () => onAccept!.call(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: crmColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                          ),
                          child: const Text('Accept & Confirm'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}

class _MobileBookingRequestCard extends StatelessWidget {
  final Booking booking;
  final bool selected;
  final ValueChanged<bool?> onSelected;
  final VoidCallback onReview;

  const _MobileBookingRequestCard({
    required this.booking,
    required this.selected,
    required this.onSelected,
    required this.onReview,
  });

  @override
  Widget build(BuildContext context) {
    final crmColors = context.crmColors;

    return Card(
      child: Padding(
        padding: 16.p,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Checkbox(value: selected, onChanged: onSelected),
                Expanded(
                  child: Text(
                    booking.customerName,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            Text(
              booking.service,
              style: TextStyle(color: crmColors.textSecondary),
            ),
            8.h,
            Text(
              _formatBookingDateTime(booking),
              style: TextStyle(color: crmColors.textSecondary),
            ),
            14.h,
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonal(
                onPressed: onReview,
                child: const Text('Review Booking'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BookingApprovalDialog extends ConsumerStatefulWidget {
  final Booking booking;

  const _BookingApprovalDialog({required this.booking});

  @override
  ConsumerState<_BookingApprovalDialog> createState() =>
      _BookingApprovalDialogState();
}

class _BookingApprovalDialogState extends ConsumerState<_BookingApprovalDialog> {
  bool _saving = false;

  Future<void> _changeStatus(String status) async {
    setState(() => _saving = true);
    try {
      await ref.read(bookingProvider.notifier).updateBooking(
            widget.booking.copyWith(status: status),
          );
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              status == 'confirmed'
                  ? 'Booking confirmed and moved to calendar.'
                  : 'Booking rejected.',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update booking: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: _AdminReviewSlide(
          booking: widget.booking,
          onAccept: _saving ? null : () => _changeStatus('confirmed'),
          onReject: _saving ? null : () => _changeStatus('rejected'),
        ),
      ),
    );
  }
}

class _ApprovalRow extends StatelessWidget {
  final String label;
  final String value;

  const _ApprovalRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final crmColors = context.crmColors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
                color: crmColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: crmColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatBookingDateTime(
  Booking booking, {
  bool dateOnly = false,
  bool timeOnly = false,
}) {
  final date = booking.serviceStart;
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  final datePart = '${date.day} ${months[date.month - 1]} ${date.year}';
  final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
  final minute = date.minute.toString().padLeft(2, '0');
  final period = date.hour >= 12 ? 'PM' : 'AM';
  final timePart = '$hour:$minute $period';

  if (dateOnly) return datePart;
  if (timeOnly) return timePart;
  return '$datePart • $timePart';
}
