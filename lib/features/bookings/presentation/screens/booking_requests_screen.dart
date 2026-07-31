import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nizan_crm/core/extensions/space_extension.dart';
import 'package:nizan_crm/features/bookings/data/booking.dart';
import 'package:nizan_crm/features/bookings/controllers/booking_provider.dart';
import 'package:nizan_crm/features/bookings/presentation/widgets/add_booking_mode_sheet.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/core/utils/responsive_builder.dart';

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
    await ref
        .read(bookingProvider.notifier)
        .updateBooking(booking.copyWith(status: status));
  }

  // Accept a single request straight from its card (no dialog needed).
  Future<void> _acceptSingle(Booking booking) async {
    try {
      await _updateStatus(booking, 'confirmed');
      if (mounted) {
        setState(() => _selectedIds.remove(booking.id));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Booking confirmed and moved to calendar.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to confirm booking: $error')),
        );
      }
    }
  }

  // Reject a single request (with a confirmation, since it's destructive).
  Future<void> _rejectSingle(Booking booking) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject booking request?'),
        content: Text(
            "This rejects ${booking.customerName}'s booking request."),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFB91C1C)),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _updateStatus(booking, 'rejected');
      if (mounted) {
        setState(() => _selectedIds.remove(booking.id));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Booking rejected.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to reject booking: $error')),
        );
      }
    }
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
          SnackBar(content: Text('${toUpdate.length} booking(s) confirmed.')),
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

    return SelectionArea(
      child: asyncBookings.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) =>
          Center(child: Text('Failed to load booking requests: $error')),
      data: (bookings) {
        final pendingBookings =
            bookings
                .where((booking) => booking.status.toLowerCase() == 'pending')
                .toList()
              ..sort((a, b) => a.serviceStart.compareTo(b.serviceStart));
        final pendingEntries = pendingBookings
            .expand(
              (booking) => booking.displayEntries.map(
                (entry) => _BookingRequestEntry(
                  id: entry.id,
                  booking: booking,
                  service: entry.service,
                  eventSlot: entry.eventSlot,
                  selectedDates: entry.selectedDates,
                  totalPrice: entry.totalPrice,
                  advanceAmount: entry.advanceAmount,
                  serviceStart: entry.serviceStart,
                  serviceEnd: entry.serviceEnd,
                ),
              ),
            )
            .toList()
          ..sort((a, b) => a.serviceStart.compareTo(b.serviceStart));

        final activeBooking = pendingEntries.cast<_BookingRequestEntry?>().firstWhere(
          (booking) => booking?.id == _activeBookingId,
          orElse: () =>
              pendingEntries.isNotEmpty ? pendingEntries.first : null,
        );

        if (pendingEntries.isNotEmpty && _activeBookingId == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() => _activeBookingId = pendingEntries.first.id);
            }
          });
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Mobile: the app bar already shows "Booking Requests", so skip the
            // duplicate heading — give the description full width and a proper
            // full-width action button instead of cramming it beside the text.
            if (isMobile) ...[
              Text(
                'Review new bookings, accept or reject individually, and bulk confirm orders from one place.',
                style: TextStyle(color: crmColors.textSecondary, fontSize: 13),
              ),
              12.h,
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => showAddBookingModeChooser(context),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('New Booking'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ] else
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Booking Requests',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        8.h,
                        Text(
                          'Review new bookings, accept or reject individually, and bulk confirm orders from one place.',
                          style: TextStyle(color: crmColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  // Create a booking from here too — the Booking section grants
                  // 'bookings' access, but until now a new booking could only be
                  // started from the Calendar (which needs a separate permission).
                  OutlinedButton.icon(
                    onPressed: () => showAddBookingModeChooser(context),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('New Booking'),
                  ),
                  12.w,
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
            isMobile ? 16.h : 24.h,
            if (isMobile && pendingEntries.isNotEmpty)
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
            if (pendingEntries.isEmpty)
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
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
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
                  itemCount: pendingEntries.length,
                  separatorBuilder: (context, index) => 12.h,
                  itemBuilder: (context, index) {
                    final booking = pendingEntries[index];
                    return _MobileBookingRequestCard(
                      booking: booking,
                      selected: _selectedIds.contains(booking.booking.id),
                      onSelected: (selected) {
                        setState(() {
                          if (selected == true) {
                            _selectedIds.add(booking.booking.id);
                          } else {
                            _selectedIds.remove(booking.booking.id);
                          }
                        });
                      },
                      onAccept: () => _acceptSingle(booking.booking),
                      onReject: () => _rejectSingle(booking.booking),
                      onReview: () async {
                        await showDialog<void>(
                          context: context,
                          builder: (_) =>
                              _BookingApprovalDialog(booking: booking),
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
                            itemCount: pendingEntries.length,
                            separatorBuilder: (context, index) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final booking = pendingEntries[index];
                              final isSelected = _selectedIds.contains(
                                booking.booking.id,
                              );
                              final isActive = booking.id == activeBooking?.id;

                              return InkWell(
                                onTap: () => setState(
                                  () => _activeBookingId = booking.id,
                                ),
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isActive
                                        ? crmColors.secondary.withValues(
                                            alpha: 0.35,
                                          )
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
                                              _selectedIds.add(booking.booking.id);
                                            } else {
                                              _selectedIds.remove(booking.booking.id);
                                            }
                                          });
                                        },
                                      ),
                                      CircleAvatar(
                                        backgroundColor: crmColors.secondary,
                                        child: Text(
                                          booking.booking.initials,
                                          style: TextStyle(
                                            color: crmColors.primary,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      14.w,
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              booking.booking.customerName,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            4.h,
                                            Text(
                                              booking.summaryLabel,
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
                                          _formatBookingDateSummary(booking),
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
                                final scaffoldMessenger = ScaffoldMessenger.of(
                                  context,
                                );
                                await _updateStatus(
                                  activeBooking.booking,
                                  'confirmed',
                                );
                                if (mounted) {
                                  scaffoldMessenger.showSnackBar(
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
                                final scaffoldMessenger = ScaffoldMessenger.of(
                                  context,
                                );
                                await _updateStatus(
                                  activeBooking.booking,
                                  'rejected',
                                );
                                if (mounted) {
                                  scaffoldMessenger.showSnackBar(
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
      ),
    );
  }
}

class _AdminReviewSlide extends StatelessWidget {
  final _BookingRequestEntry? booking;
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
                    style: TextStyle(
                      color: crmColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  24.h,
                  _ApprovalRow(
                    label: 'Client',
                    value: booking!.booking.customerName,
                  ),
                  if (booking!.eventSlot.trim().isNotEmpty)
                    _ApprovalRow(label: 'Slot', value: booking!.eventSlot),
                  _ApprovalRow(
                    label: 'Phone',
                    value: booking!.booking.phone,
                  ),
                  _ApprovalRow(
                    label: 'Email',
                    value: booking!.booking.email.isEmpty
                        ? 'Missing email'
                        : booking!.booking.email,
                  ),
                  _ApprovalRow(label: 'Package', value: booking!.service),
                  _ApprovalRow(
                    label: 'Region',
                    value: booking!.booking.region.isEmpty
                        ? 'Default'
                        : booking!.booking.region,
                  ),
                  _ApprovalRow(
                    label: 'Dates',
                    value: _formatSelectedDatesLabel(booking!),
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
                          onPressed: onReject == null
                              ? null
                              : () => onReject!.call(),
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
                          onPressed: onAccept == null
                              ? null
                              : () => onAccept!.call(),
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
  final _BookingRequestEntry booking;
  final bool selected;
  final ValueChanged<bool?> onSelected;
  final VoidCallback onReview;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  static const _pending = Color(0xFFB45309);
  static const _accept = Color(0xFF15803D);
  static const _reject = Color(0xFFB91C1C);

  const _MobileBookingRequestCard({
    required this.booking,
    required this.selected,
    required this.onSelected,
    required this.onReview,
    required this.onAccept,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final crmColors = context.crmColors;
    final b = booking.booking;

    return Container(
      decoration: BoxDecoration(
        color: crmColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selected ? crmColors.primary : crmColors.border,
          width: selected ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onReview,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header: avatar · name + Pending pill + summary · select ──
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: _pending.withValues(alpha: 0.12),
                      child: Text(
                        b.initials,
                        style: const TextStyle(
                            color: _pending, fontWeight: FontWeight.bold),
                      ),
                    ),
                    12.w,
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  b.customerName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15),
                                ),
                              ),
                              8.w,
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _pending.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Text(
                                  'Pending',
                                  style: TextStyle(
                                      color: _pending,
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700),
                                ),
                              ),
                            ],
                          ),
                          2.h,
                          Text(
                            booking.summaryLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: crmColors.textSecondary, fontSize: 12.5),
                          ),
                        ],
                      ),
                    ),
                    // Bulk-select checkbox.
                    Checkbox(
                      value: selected,
                      onChanged: onSelected,
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ],
                ),
                8.h,
                // ── Event date row ──
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Row(
                    children: [
                      Icon(Icons.event_outlined,
                          size: 15, color: crmColors.textSecondary),
                      6.w,
                      Expanded(
                        child: Text(
                          _formatBookingDateSummary(booking),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: crmColors.textSecondary, fontSize: 12.5),
                        ),
                      ),
                      Text(
                        'Details',
                        style: TextStyle(
                            color: crmColors.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700),
                      ),
                      Icon(Icons.chevron_right,
                          size: 16, color: crmColors.primary),
                    ],
                  ),
                ),
                12.h,
                // ── Inline triage actions ──
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: onReject,
                          icon: const Icon(Icons.close, size: 18),
                          label: const Text('Reject'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _reject,
                            side: const BorderSide(color: _reject),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                      10.w,
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: onAccept,
                          icon: const Icon(Icons.check, size: 18),
                          label: const Text('Accept'),
                          style: FilledButton.styleFrom(
                            backgroundColor: _accept,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BookingApprovalDialog extends ConsumerStatefulWidget {
  final _BookingRequestEntry booking;

  const _BookingApprovalDialog({required this.booking});

  @override
  ConsumerState<_BookingApprovalDialog> createState() =>
      _BookingApprovalDialogState();
}

class _BookingApprovalDialogState
    extends ConsumerState<_BookingApprovalDialog> {
  bool _saving = false;

  Future<void> _changeStatus(String status) async {
    setState(() => _saving = true);
    try {
      await ref
          .read(bookingProvider.notifier)
          .updateBooking(widget.booking.booking.copyWith(status: status));
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

String _formatDateShort(DateTime date) {
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

  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

String _formatSelectedDatesLabel(_BookingRequestEntry booking) {
  final dates = _bookingRequestDates(booking);
  return dates.map(_formatDateShort).join(', ');
}

String _formatBookingDateSummary(_BookingRequestEntry booking) {
  final dates = _bookingRequestDates(booking);
  if (dates.isEmpty) return '-';
  if (dates.length == 1) return _formatDateShort(dates.first);
  return '${_formatDateShort(dates.first)} +${dates.length - 1} more';
}

List<DateTime> _bookingRequestDates(_BookingRequestEntry booking) {
  if (booking.selectedDates.isNotEmpty) {
    return [...booking.selectedDates]..sort((a, b) => a.compareTo(b));
  }

  return [booking.serviceStart];
}

class _BookingRequestEntry {
  final String id;
  final Booking booking;
  final String service;
  final String eventSlot;
  final List<DateTime> selectedDates;
  final double totalPrice;
  final double advanceAmount;
  final DateTime serviceStart;
  final DateTime serviceEnd;

  const _BookingRequestEntry({
    required this.id,
    required this.booking,
    required this.service,
    required this.eventSlot,
    required this.selectedDates,
    required this.totalPrice,
    required this.advanceAmount,
    required this.serviceStart,
    required this.serviceEnd,
  });

  String get summaryLabel =>
      eventSlot.trim().isEmpty ? service : '$service • ${eventSlot.trim()}';
}
