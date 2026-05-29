import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/extensions/space_extension.dart';
import '../../core/providers/booking_provider.dart';
import '../../core/theme/crm_theme.dart';
import '../../core/models/booking.dart';
import '../../core/utils/booking_print_service.dart';
import '../../services/booking_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Colour helpers
// ─────────────────────────────────────────────────────────────────────────────
Color _statusColor(String status) {
  switch (status.toLowerCase()) {
    case 'confirmed':
      return const Color(0xFF3B82F6);
    case 'completed':
      return const Color(0xFF22C55E);
    case 'pending':
      return const Color(0xFFF97316);
    case 'cancelled':
      return const Color(0xFFEF4444);
    default:
      return const Color(0xFF8B5CF6);
  }
}

IconData _statusIcon(String status) {
  switch (status.toLowerCase()) {
    case 'confirmed':
      return Icons.check_circle_rounded;
    case 'completed':
      return Icons.task_alt_rounded;
    case 'pending':
      return Icons.hourglass_top_rounded;
    case 'cancelled':
      return Icons.cancel_rounded;
    default:
      return Icons.info_rounded;
  }
}

String _fmt(DateTime d) {
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
  return '${d.day.toString().padLeft(2, '0')} ${months[d.month - 1]} ${d.year}';
}

String _fmtTime(DateTime d) {
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final m = d.minute.toString().padLeft(2, '0');
  final ap = d.hour >= 12 ? 'PM' : 'AM';
  return '$h:$m $ap';
}

// ─────────────────────────────────────────────────────────────────────────────
//  Main Screen
// ─────────────────────────────────────────────────────────────────────────────
class ArtistWorksScreen extends HookConsumerWidget {
  const ArtistWorksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pageState = useState(1);
    final asyncWorks = ref.watch(artistAssignedWorksProvider(pageState.value));

    return Scaffold(
      backgroundColor: context.crmColors.background,
      body: asyncWorks.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorView(
          error: error.toString(),
          onRetry: () => ref.invalidate(artistAssignedWorksProvider),
        ),
        data: (response) {
          final bookings = response.items;
          if (bookings.isEmpty) return const _EmptyState();

          // Sort: upcoming first, then by date
          final now = DateTime.now();
          final sorted = [...bookings]
            ..sort((a, b) {
              final aFuture = a.serviceStart.isAfter(now);
              final bFuture = b.serviceStart.isAfter(now);
              if (aFuture && !bFuture) return -1;
              if (!aFuture && bFuture) return 1;
              return a.serviceStart.compareTo(b.serviceStart);
            });

          return _BookingCardStack(
            bookings: sorted,
            summary: response.summary,
            page: response.page,
            totalPages: response.totalPages,
            totalItems: response.totalItems,
            onPrev: response.page > 1 ? () => pageState.value-- : null,
            onNext: response.page < response.totalPages
                ? () => pageState.value++
                : null,
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Card Stack View
// ─────────────────────────────────────────────────────────────────────────────
class _BookingCardStack extends HookWidget {
  final List<Booking> bookings;
  final BookingPageSummary summary;
  final int page;
  final int totalPages;
  final int totalItems;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  const _BookingCardStack({
    required this.bookings,
    required this.summary,
    required this.page,
    required this.totalPages,
    required this.totalItems,
    required this.onPrev,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final expandedIndex = useState<int?>(null);
    final now = DateTime.now();

    // Separate today, upcoming and past
    final todayBookings = bookings
        .where(
          (b) =>
              b.serviceStart.year == now.year &&
              b.serviceStart.month == now.month &&
              b.serviceStart.day == now.day,
        )
        .toList();

    final upcomingBookings = bookings
        .where(
          (b) =>
              b.serviceStart.isAfter(now) &&
              !(b.serviceStart.year == now.year &&
                  b.serviceStart.month == now.month &&
                  b.serviceStart.day == now.day),
        )
        .toList();

    final pastBookings = bookings
        .where(
          (b) =>
              b.serviceStart.isBefore(DateTime(now.year, now.month, now.day)),
        )
        .toList();

    return Column(
      children: [
        // ── Summary strip ────────────────────────────────
        _SummaryStrip(summary: summary, total: totalItems),

        // ── Card list ────────────────────────────────────
        Expanded(
          child: ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              // TODAY
              if (todayBookings.isNotEmpty) ...[
                _SectionLabel(
                  label: "Today's Work",
                  icon: Icons.wb_sunny_rounded,
                  color: Colors.orange,
                ),
                8.h,
                ...todayBookings.asMap().entries.map(
                  (e) => _AnimatedWorkCard(
                    booking: e.value,
                    index: e.key,
                    isExpanded: expandedIndex.value == e.value.id.hashCode,
                    onTap: () {
                      expandedIndex.value =
                          expandedIndex.value == e.value.id.hashCode
                          ? null
                          : e.value.id.hashCode;
                    },
                    isToday: true,
                  ),
                ),
                20.h,
              ],

              // UPCOMING
              if (upcomingBookings.isNotEmpty) ...[
                _SectionLabel(
                  label: 'Upcoming',
                  icon: Icons.upcoming_rounded,
                  color: const Color(0xFF3B82F6),
                ),
                8.h,
                ...upcomingBookings.asMap().entries.map(
                  (e) => _AnimatedWorkCard(
                    booking: e.value,
                    index: e.key,
                    isExpanded: expandedIndex.value == e.value.id.hashCode,
                    onTap: () {
                      expandedIndex.value =
                          expandedIndex.value == e.value.id.hashCode
                          ? null
                          : e.value.id.hashCode;
                    },
                    isToday: false,
                  ),
                ),
                20.h,
              ],

              // PAST
              if (pastBookings.isNotEmpty) ...[
                _SectionLabel(
                  label: 'Past Works',
                  icon: Icons.history_rounded,
                  color: crm.textSecondary,
                ),
                8.h,
                ...pastBookings.asMap().entries.map(
                  (e) => _AnimatedWorkCard(
                    booking: e.value,
                    index: e.key,
                    isExpanded: expandedIndex.value == e.value.id.hashCode,
                    onTap: () {
                      expandedIndex.value =
                          expandedIndex.value == e.value.id.hashCode
                          ? null
                          : e.value.id.hashCode;
                    },
                    isToday: false,
                    isPast: true,
                  ),
                ),
              ],

              // ── Pagination ─────────────────────────────
              if (totalPages > 1) ...[
                20.h,
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _PaginationButton(
                      icon: Icons.chevron_left_rounded,
                      enabled: onPrev != null,
                      onTap: onPrev,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'Page $page of $totalPages',
                        style: TextStyle(
                          color: crm.textSecondary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    _PaginationButton(
                      icon: Icons.chevron_right_rounded,
                      enabled: onNext != null,
                      onTap: onNext,
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Summary Strip
// ─────────────────────────────────────────────────────────────────────────────
class _SummaryStrip extends StatelessWidget {
  final BookingPageSummary summary;
  final int total;

  const _SummaryStrip({required this.summary, required this.total});

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return Container(
      color: crm.surface,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          _StripStat(
            label: 'Total',
            value: '$total',
            color: crm.primary,
            icon: Icons.assignment_rounded,
          ),
          const _Divider(),
          _StripStat(
            label: 'Done',
            value: '${summary.completedCount}',
            color: const Color(0xFF22C55E),
            icon: Icons.task_alt_rounded,
          ),
          const _Divider(),
          _StripStat(
            label: 'Earnings',
            value: '₹${summary.totalSales.toStringAsFixed(0)}',
            color: const Color(0xFF8B5CF6),
            icon: Icons.account_balance_wallet_rounded,
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(height: 28, width: 1, color: context.crmColors.border),
  );
}

class _StripStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _StripStat({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) => Expanded(
    flex: 3,
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 16, color: color),
        6.w,
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: context.crmColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  Section Label
// ─────────────────────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;

  const _SectionLabel({
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 14, color: color),
      ),
      10.w,
      Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w800,
          color: color,
          letterSpacing: 0.3,
        ),
      ),
    ],
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  Animated Work Card  (boarding-pass / stacked style)
// ─────────────────────────────────────────────────────────────────────────────
class _AnimatedWorkCard extends HookWidget {
  final Booking booking;
  final int index;
  final bool isExpanded;
  final VoidCallback onTap;
  final bool isToday;
  final bool isPast;

  const _AnimatedWorkCard({
    required this.booking,
    required this.index,
    required this.isExpanded,
    required this.onTap,
    required this.isToday,
    this.isPast = false,
  });

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final statusColor = _statusColor(booking.status);
    final balance =
        (booking.totalPrice - booking.advanceAmount - booking.discountAmount)
            .clamp(0, double.infinity)
            .toDouble();

    // My assigned works for this booking
    final myWorks = booking.assignedStaff
        .where((s) => s.works.isNotEmpty)
        .expand((s) => s.works)
        .toSet()
        .toList();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isPast ? crm.surface.withValues(alpha: 0.7) : crm.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: crm.border),
          boxShadow: isToday
              ? [
                  BoxShadow(
                    color: statusColor.withValues(alpha: 0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
        ),
        child: Column(
          children: [
            // ── Card Header ─────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                children: [
                  Row(
                    children: [
                      // Avatar
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              statusColor.withValues(alpha: 0.9),
                              statusColor,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          booking.initials,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      14.w,

                      // Name + service
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              booking.customerName,
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                                color: isPast
                                    ? crm.textSecondary
                                    : crm.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            4.h,
                            Text(
                              booking.service,
                              style: TextStyle(
                                fontSize: 12,
                                color: crm.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      12.w,

                      // Status + expand arrow
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _StatusChip(status: booking.status),
                          8.h,
                          Icon(
                            isExpanded
                                ? Icons.keyboard_arrow_up_rounded
                                : Icons.keyboard_arrow_down_rounded,
                            size: 18,
                            color: crm.textSecondary,
                          ),
                        ],
                      ),
                    ],
                  ),

                  14.h,
                  // ── Date / Time Row ──────────────────────
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isToday
                          ? statusColor.withValues(alpha: 0.06)
                          : crm.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isToday
                            ? statusColor.withValues(alpha: 0.2)
                            : crm.border,
                      ),
                    ),
                    child: Row(
                      children: [
                        // Date block
                        _IconInfo(
                          icon: Icons.calendar_today_rounded,
                          text: _fmt(booking.serviceStart),
                          color: isToday ? statusColor : crm.textSecondary,
                        ),
                        const Spacer(),
                        Container(width: 1, height: 28, color: crm.border),
                        const Spacer(),
                        // Time block
                        _IconInfo(
                          icon: Icons.access_time_rounded,
                          text:
                              '${_fmtTime(booking.serviceStart)} – ${_fmtTime(booking.serviceEnd)}',
                          color: isToday ? statusColor : crm.textSecondary,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Expanded Details ─────────────────────────
            if (isExpanded)
              _ExpandedDetails(
                booking: booking,
                balance: balance,
                myWorks: myWorks,
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Expanded Details (shown when card is tapped)
// ─────────────────────────────────────────────────────────────────────────────
class _ExpandedDetails extends StatelessWidget {
  final Booking booking;
  final double balance;
  final List<String> myWorks;

  const _ExpandedDetails({
    required this.booking,
    required this.balance,
    required this.myWorks,
  });

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Dashed separator (like a boarding pass tear line) ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final dashCount = (constraints.constrainWidth() / 8).floor();
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(
                  dashCount,
                  (_) => Container(width: 4, height: 1, color: crm.border),
                ),
              );
            },
          ),
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              WorkTimerWidget(booking: booking),
              12.h,
              // My assigned tasks
              if (myWorks.isNotEmpty) ...[
                _DetailLabel('My Assigned Tasks'),
                8.h,
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: myWorks.map((w) => _WorkTag(text: w)).toList(),
                ),
                16.h,
              ],

              // Location
              if (booking.region.isNotEmpty || booking.district.isNotEmpty) ...[
                _DetailLabel('Location'),
                6.h,
                _IconInfo(
                  icon: Icons.location_on_rounded,
                  text: [
                    booking.district,
                    booking.region,
                  ].where((s) => s.isNotEmpty).join(', '),
                  color: crm.textSecondary,
                  fontSize: 13,
                ),
                14.h,
              ],

              // Travel info
              if (booking.travelMode.isNotEmpty) ...[
                _DetailLabel('Travel'),
                6.h,
                _IconInfo(
                  icon: Icons.directions_car_rounded,
                  text:
                      '${booking.travelMode}'
                      '${booking.travelTime.isNotEmpty ? ' • ${booking.travelTime}' : ''}'
                      '${booking.travelDistanceKm > 0 ? ' • ${booking.travelDistanceKm.toStringAsFixed(1)} km' : ''}',
                  color: Colors.black,
                  fontSize: 13,
                ),
                14.h,
              ],

              // Staff instructions
              if (booking.staffInstructions.isNotEmpty) ...[
                _DetailLabel('Instructions'),
                6.h,
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFFF97316).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        size: 16,
                        color: Color(0xFFF97316),
                      ),
                      8.w,
                      Expanded(
                        child: Text(
                          booking.staffInstructions,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF92400E),
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                14.h,
              ],

              // Payment breakdown
              _DetailLabel('Payment'),
              12.h,
              Row(
                children: [
                  _PayCard(
                    label: 'Total',
                    value: '₹${booking.totalPrice.toStringAsFixed(0)}',
                    color: crm.primary,
                    icon: Icons.receipt_rounded,
                  ),
                  8.w,
                  _PayCard(
                    label: 'Advance',
                    value: '₹${booking.advanceAmount.toStringAsFixed(0)}',
                    color: const Color(0xFF22C55E),
                    icon: Icons.check_circle_rounded,
                  ),
                  8.w,
                  _PayCard(
                    label: 'Balance',
                    value: '₹${balance.toStringAsFixed(0)}',
                    color: balance > 0
                        ? const Color(0xFFEF4444)
                        : const Color(0xFF22C55E),
                    icon: balance > 0
                        ? Icons.pending_rounded
                        : Icons.done_all_rounded,
                  ),
                ],
              ),

              // PDF client details download option
              14.h,
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    try {
                      await printBookingDetails(
                        booking,
                        variant: BookingPrintVariant.client,
                      );
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error downloading PDF: $e')),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
                  label: const Text('Download Client Details (PDF)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: crm.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),

              // Map link
              if (booking.mapUrl.isNotEmpty) ...[
                14.h,
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      // mapUrl can be launched from here
                    },
                    icon: const Icon(Icons.map_rounded, size: 16),
                    label: const Text('View on Map'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF3B82F6),
                      side: const BorderSide(color: Color(0xFF3B82F6)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Small Reusable Widgets
// ─────────────────────────────────────────────────────────────────────────────
class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_statusIcon(status), size: 11, color: color),
          4.w,
          Text(
            status.toUpperCase(),
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _IconInfo extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  final double fontSize;

  const _IconInfo({
    required this.icon,
    required this.text,
    required this.color,
    this.fontSize = 12,
  });

  @override
  Widget build(BuildContext context) => Text.rich(
    TextSpan(
      children: [
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Padding(
            padding: const EdgeInsets.only(right: 5),
            child: Icon(icon, size: 14, color: color),
          ),
        ),
        TextSpan(
          text: text,
          style: TextStyle(
            fontSize: fontSize,
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
    overflow: TextOverflow.ellipsis,
  );
}

class _DetailLabel extends StatelessWidget {
  final String text;
  const _DetailLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      color: context.crmColors.textSecondary,
      letterSpacing: 0.8,
    ),
  );
}

class _WorkTag extends StatelessWidget {
  final String text;
  const _WorkTag({required this.text});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.3)),
    ),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: Color(0xFF8B5CF6),
      ),
    ),
  );
}

class _PayCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _PayCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 16, color: color),
            6.h,
            Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
            3.h,
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: crm.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaginationButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback? onTap;

  const _PaginationButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: enabled ? crm.primary.withValues(alpha: 0.1) : crm.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: enabled ? crm.primary.withValues(alpha: 0.3) : crm.border,
          ),
        ),
        child: Icon(
          icon,
          size: 20,
          color: enabled ? crm.primary : crm.textSecondary,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Empty State
// ─────────────────────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: crm.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.celebration_rounded,
                size: 48,
                color: crm.primary.withValues(alpha: 0.5),
              ),
            ),
            24.h,
            Text(
              'All Clear! 🎉',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
                color: crm.textPrimary,
              ),
            ),
            12.h,
            Text(
              'You have no assigned works right now.\nEnjoy your free time!',
              style: TextStyle(
                color: crm.textSecondary,
                fontSize: 14,
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Error State
// ─────────────────────────────────────────────────────────────────────────────
class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 56,
              color: crm.destructive.withValues(alpha: 0.6),
            ),
            20.h,
            Text(
              'Could not load works',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            10.h,
            Text(
              error,
              style: TextStyle(color: crm.textSecondary, fontSize: 12),
              textAlign: TextAlign.center,
              maxLines: 3,
            ),
            20.h,
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Work Timer Widget
// ─────────────────────────────────────────────────────────────────────────────
class WorkTimerWidget extends ConsumerStatefulWidget {
  final Booking booking;

  const WorkTimerWidget({
    super.key,
    required this.booking,
  });

  @override
  ConsumerState<WorkTimerWidget> createState() => _WorkTimerWidgetState();
}

class _WorkTimerWidgetState extends ConsumerState<WorkTimerWidget> {
  static const int _threeHoursSeconds = 3 * 3600; // 10800 seconds
  
  String get _stateKey => 'work_timer_state_${widget.booking.id}';
  String get _dataKey => 'work_timer_data_${widget.booking.id}';

  String _timerState = 'idle'; // 'idle', 'running', 'paused', 'completed'
  int _remainingSeconds = _threeHoursSeconds;
  DateTime? _startTime;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _loadTimerState();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadTimerState() async {
    final prefs = await SharedPreferences.getInstance();
    final savedState = prefs.getString(_stateKey) ?? 'idle';
    
    // If the booking is already completed in backend, make sure we reflect that
    if (widget.booking.status.toLowerCase() == 'completed') {
      if (mounted) {
        setState(() {
          _timerState = 'completed';
        });
      }
      return;
    }

    if (savedState == 'running') {
      final savedStartStr = prefs.getString(_dataKey);
      if (savedStartStr != null) {
        final savedStart = DateTime.tryParse(savedStartStr);
        if (savedStart != null) {
          final elapsed = DateTime.now().difference(savedStart).inSeconds;
          final remaining = _threeHoursSeconds - elapsed;
          if (remaining > 0) {
            _timerState = 'running';
            _startTime = savedStart;
            _remainingSeconds = remaining;
            _startTicker();
          } else {
            // Timer expired while app was closed/minimized
            _timerState = 'running';
            _startTime = savedStart;
            _remainingSeconds = 0;
            _startTicker();
          }
        }
      }
    } else if (savedState == 'paused') {
      final savedRemaining = prefs.getInt(_dataKey) ?? _threeHoursSeconds;
      _timerState = 'paused';
      _remainingSeconds = savedRemaining;
    } else if (savedState == 'completed') {
      _timerState = 'completed';
    }

    if (mounted) {
      setState(() {});
    }
  }

  void _startTicker() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_startTime == null) return;
      final elapsed = DateTime.now().difference(_startTime!).inSeconds;
      final remaining = _threeHoursSeconds - elapsed;
      if (remaining <= 0) {
        if (mounted) {
          setState(() {
            _remainingSeconds = 0;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _remainingSeconds = remaining;
          });
        }
      }
    });
  }

  Future<void> _startTimer() async {
    final now = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_stateKey, 'running');
    await prefs.setString(_dataKey, now.toIso8601String());

    if (mounted) {
      setState(() {
        _timerState = 'running';
        _startTime = now;
        _remainingSeconds = _threeHoursSeconds;
      });
      _startTicker();
    }
  }

  Future<void> _pauseTimer() async {
    _timer?.cancel();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_stateKey, 'paused');
    await prefs.setInt(_dataKey, _remainingSeconds);

    if (mounted) {
      setState(() {
        _timerState = 'paused';
      });
    }
  }

  Future<void> _resumeTimer() async {
    final elapsed = _threeHoursSeconds - _remainingSeconds;
    final effectiveStart = DateTime.now().subtract(Duration(seconds: elapsed));

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_stateKey, 'running');
    await prefs.setString(_dataKey, effectiveStart.toIso8601String());

    if (mounted) {
      setState(() {
        _timerState = 'running';
        _startTime = effectiveStart;
      });
      _startTicker();
    }
  }

  Future<void> _completeTimer() async {
    _timer?.cancel();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_stateKey, 'completed');

    if (mounted) {
      setState(() {
        _timerState = 'completed';
      });
    }

    try {
      await ref.read(bookingServiceProvider).updateBooking(
        widget.booking.copyWith(status: 'completed'),
      );
      ref.invalidate(artistAssignedWorksProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✓ Work Marked as Completed')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating status: $e')),
        );
      }
    }
  }

  String _formatDuration(int totalSeconds) {
    final h = totalSeconds ~/ 3600;
    final m = (totalSeconds % 3600) ~/ 60;
    final s = totalSeconds % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    
    if (widget.booking.status.toLowerCase() == 'cancelled') {
      return const SizedBox.shrink();
    }

    if (_timerState == 'idle') {
      return Container(
        margin: const EdgeInsets.only(top: 8, bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: crm.primary.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: crm.primary.withValues(alpha: 0.15)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.timer_outlined, color: crm.primary, size: 20),
                8.w,
                Expanded(
                  child: Text(
                    'Standard duration: 3 Hours',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: crm.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            12.h,
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _startTimer,
                icon: const Icon(Icons.play_arrow_rounded, size: 18),
                label: const Text('START WORK'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_timerState == 'completed' || widget.booking.status.toLowerCase() == 'completed') {
      return Container(
        margin: const EdgeInsets.only(top: 8, bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.green.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            const Icon(Icons.task_alt_rounded, color: Colors.green, size: 22),
            10.w,
            const Text(
              'Work Completed Successfully',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
          ],
        ),
      );
    }

    final progress = (_threeHoursSeconds - _remainingSeconds) / _threeHoursSeconds;
    final isRunning = _timerState == 'running';

    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isRunning 
            ? crm.primary.withValues(alpha: 0.05)
            : Colors.orange.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isRunning 
              ? crm.primary.withValues(alpha: 0.2)
              : Colors.orange.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  _PulsingDot(color: isRunning ? Colors.green : Colors.orange),
                  8.w,
                  Text(
                    isRunning ? 'WORK IN PROGRESS' : 'WORK PAUSED',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: isRunning ? Colors.green : Colors.orange,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              Text(
                _remainingSeconds > 0 ? 'Remaining' : 'Time Over limit',
                style: TextStyle(
                  fontSize: 11,
                  color: crm.textSecondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          10.h,
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                _formatDuration(_remainingSeconds),
                style: TextStyle(
                  fontSize: 26,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w900,
                  color: isRunning ? crm.textPrimary : Colors.orange,
                ),
              ),
              Text(
                'Goal: 03:00:00',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: crm.textSecondary,
                ),
              ),
            ],
          ),
          12.h,
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: crm.border,
              valueColor: AlwaysStoppedAnimation<Color>(
                _remainingSeconds > 0 
                    ? (isRunning ? crm.primary : Colors.orange) 
                    : Colors.red,
              ),
            ),
          ),
          16.h,
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: isRunning ? _pauseTimer : _resumeTimer,
                  icon: Icon(
                    isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    size: 16,
                  ),
                  label: Text(isRunning ? 'PAUSE' : 'RESUME'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isRunning ? Colors.orange : Colors.green,
                    side: BorderSide(
                      color: isRunning ? Colors.orange : Colors.green,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              12.w,
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _completeTimer,
                  icon: const Icon(Icons.check_rounded, size: 16),
                  label: const Text('FINISH WORK'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Pulsing Dot Component
// ─────────────────────────────────────────────────────────────────────────────
class _PulsingDot extends HookWidget {
  final Color color;

  const _PulsingDot({required this.color});

  @override
  Widget build(BuildContext context) {
    final controller = useAnimationController(
      duration: const Duration(milliseconds: 1000),
    );

    useEffect(() {
      controller.repeat(reverse: true);
      return null;
    }, []);

    final animation = useAnimation(
      ColorTween(
        begin: color.withValues(alpha: 0.3),
        end: color,
      ).animate(controller),
    );

    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: animation,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.4),
            blurRadius: 4,
            spreadRadius: 1,
          ),
        ],
      ),
    );
  }
}
