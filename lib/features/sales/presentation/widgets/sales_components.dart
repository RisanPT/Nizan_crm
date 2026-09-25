part of '../screens/sales_invoices_screen.dart';
// Sales — leaf presentation widgets (stat cards, booking rows/cards, chips,
// pagination). Part of the SalesBookingsScreen library.

class _StatCardWithIcon extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color color;
  final double width;

  /// Exact figure behind an abbreviated [value] (e.g. '₹2,51,18,500' for
  /// '₹2.51Cr'). Shown on hover/long-press so nothing is lost by abbreviating.
  final String? exactValue;

  const _StatCardWithIcon({
    required this.title,
    required this.value,
    this.subtitle,
    required this.icon,
    required this.color,
    required this.width,
    this.exactValue,
  });

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: child,
          ),
        );
      },
      child: Container(
        width: width,
        decoration: BoxDecoration(
          color: crm.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: crm.border.faded(0.5)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Subtler colored accent strip along the top.
          Container(height: 4, color: color.withValues(alpha: 0.8)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: color, size: 20),
                    ),
                    12.w,
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: crm.textSecondary,
                            fontSize: 13,
                            letterSpacing: 0.3,
                            height: 1.2,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                16.h,
                Tooltip(
                  // No tooltip when the figure is already shown in full.
                  message: exactValue ?? '',
                  waitDuration: const Duration(milliseconds: 400),
                  child: Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: crm.textPrimary,
                        fontSize: 28,
                        height: 1.1,
                        letterSpacing: -0.5,
                        fontWeight: FontWeight.w800),
                  ),
                ),
                if (subtitle != null) ...[
                  6.h,
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: crm.textSecondary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500),
                  ),
                ],
              ],
            ),
          ),
          ],
        ),
      ),
    );
  }
}

class _PaginationBar extends StatelessWidget {
  final int page;
  final int limit;
  final int totalPages;
  final int totalItems;
  final int currentItemCount;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  const _PaginationBar({
    required this.page,
    required this.limit,
    required this.totalPages,
    required this.totalItems,
    required this.currentItemCount,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final crmColors = context.crmColors;
    final startItem = totalItems == 0 ? 0 : ((page - 1) * limit) + 1;
    final endItem = totalItems == 0 ? 0 : startItem + currentItemCount - 1;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: crmColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: crmColors.border),
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          // Full labelled controls need room; below this, use compact icon
          // buttons with the page info centred so nothing overflows on a phone.
          final compact = c.maxWidth < 520;

          final prevIcon = IconButton(
            onPressed: onPrevious,
            icon: const Icon(Icons.chevron_left),
            tooltip: 'Previous',
            visualDensity: VisualDensity.compact,
            style: IconButton.styleFrom(
              backgroundColor: crmColors.input,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
          final nextIcon = IconButton(
            onPressed: onNext,
            icon: const Icon(Icons.chevron_right),
            tooltip: 'Next',
            visualDensity: VisualDensity.compact,
            style: IconButton.styleFrom(
              backgroundColor: crmColors.primary.withValues(alpha: 0.12),
              foregroundColor: crmColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );

          if (compact) {
            return Row(
              children: [
                prevIcon,
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Page $page of $totalPages',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: crmColors.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      if (totalItems > 0)
                        Text(
                          '$startItem–$endItem of $totalItems',
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: crmColors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                    ],
                  ),
                ),
                nextIcon,
              ],
            );
          }

          return Row(
            children: [
              Expanded(
                child: Text(
                  'Showing $startItem-$endItem of $totalItems bookings',
                  style: TextStyle(
                    color: crmColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                'Page $page of $totalPages',
                style: TextStyle(
                  color: crmColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              12.w,
              OutlinedButton.icon(
                onPressed: onPrevious,
                icon: const Icon(Icons.chevron_left),
                label: const Text('Previous'),
              ),
              8.w,
              ElevatedButton.icon(
                onPressed: onNext,
                icon: const Icon(Icons.chevron_right),
                label: const Text('Next'),
              ),
            ],
          );
        },
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
  final VoidCallback? onRowTap;

  const _DesktopBookingRow({
    required this.booking,
    required this.isSelected,
    required this.onSelectChanged,
    required this.onDelete,
    this.onRowTap,
  });

  @override
  Widget build(BuildContext context) {
    final crmColors = context.crmColors;
    final balance =
        ((booking.totalPrice - booking.advanceAmount - booking.discountAmount)
                .clamp(0, double.infinity))
            .toDouble();

    return InkWell(
      onTap: onRowTap ?? () => context.go('/booking/manage/${booking.id}'),
      hoverColor: crmColors.primary.withValues(alpha: 0.03),
      child: Container(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: crmColors.border.faded(0.3))),
          color: isSelected ? crmColors.primary.withValues(alpha: 0.05) : null,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
        child: Row(
          children: [
            SizedBox(
              width: 44,
              child: Checkbox(
                value: isSelected, 
                onChanged: onSelectChanged,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                '#${booking.displayBookingNumber}',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                _formatDate(booking.createdAt ?? booking.bookingDate),
                style: TextStyle(
                  color: crmColors.textSecondary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                _formatDate(booking.serviceStart),
                style: TextStyle(
                  color: crmColors.textSecondary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
            Expanded(
              flex: 2, 
              child: Text(
                booking.customerName,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
              ),
            ),
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    booking.service,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  if (booking.duplicateCount > 1)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: _DuplicateBadge(count: booking.duplicateCount),
                    ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Align(
                alignment: Alignment.centerLeft,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: _StatusChip(status: booking.status),
                ),
              ),
            ),
            Expanded(
              child: Text('₹${_money(booking.advanceAmount)}',
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
            Expanded(
              child: Text('₹${_money(booking.totalPrice)}',
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
            Expanded(
              child: Text('₹${_money(balance)}',
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
            SizedBox(
              width: 60,
              child: Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  onPressed: onDelete,
                  tooltip: 'Delete booking',
                  icon: Icon(
                    Icons.delete_outline,
                    color: crmColors.destructive,
                    size: 20,
                  ),
                ),
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
  final VoidCallback? onRowTap;

  const _MobileBookingCard({
    required this.booking,
    required this.isSelected,
    required this.onSelectChanged,
    required this.onDelete,
    this.onRowTap,
  });

  @override
  Widget build(BuildContext context) {
    final crmColors = context.crmColors;
    final balance =
        ((booking.totalPrice - booking.advanceAmount - booking.discountAmount)
                .clamp(0, double.infinity))
            .toDouble();

    final accent = _statusColorFor(booking.status);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: crmColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: isSelected ? accent : crmColors.border.faded(0.5),
            width: isSelected ? 2 : 1),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 16,
              offset: const Offset(0, 4)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onRowTap ?? () => context.go('/booking/manage/${booking.id}'),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 5, color: accent),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          SizedBox(
                            width: 24,
                            height: 24,
                            child: Checkbox(
                                value: isSelected,
                                onChanged: onSelectChanged,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                visualDensity: VisualDensity.compact),
                          ),
                          10.w,
                          Expanded(
                            child: Text(
                              booking.customerName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w800),
                            ),
                          ),
                          _StatusChip(status: booking.status),
                        ],
                      ),
                      10.h,
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '#${booking.displayBookingNumber}  ·  ${booking.service}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: crmColors.textSecondary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                          if (booking.duplicateCount > 1) ...[
                            8.w,
                            _DuplicateBadge(count: booking.duplicateCount),
                          ],
                        ],
                      ),
                      16.h,
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _MiniFinance(
                              label: 'Advance',
                              value: '₹${_money(booking.advanceAmount)}'),
                          _MiniFinance(
                              label: 'Total',
                              value: '₹${_money(booking.totalPrice)}'),
                          _MiniFinance(
                              label: 'Balance', value: '₹${_money(balance)}'),
                          _MiniFinance(
                              label: 'Date',
                              value: _formatDate(booking.bookingDate)),
                        ],
                      ),
                      8.h,
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: onDelete,
                          style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              foregroundColor: crmColors.destructive),
                          icon: const Icon(Icons.delete_outline, size: 18),
                          label: const Text('Delete', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Shared status → accent color for sales cards/rows.
Color _statusColorFor(String status) {
  switch (status.toLowerCase()) {
    case 'completed':
      return const Color(0xFF2E7D32);
    case 'cancelled':
      return const Color(0xFFD32F2F);
    case 'postponed':
      return const Color(0xFFE65100);
    case 'confirmed':
      return const Color(0xFF1565C0);
    default:
      return const Color(0xFFB8860B);
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
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: crmColors.input,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: crmColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: crmColors.textSecondary,
              fontSize: 9.5,
              letterSpacing: 0.3,
              fontWeight: FontWeight.w700,
            ),
          ),
          3.h,
          Text(
            value,
            style: TextStyle(
              color: crmColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _DuplicateBadge extends StatelessWidget {
  final int count;

  const _DuplicateBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'Possible duplicate ($count)',
        style: TextStyle(
          color: Colors.red.shade700,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
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
      case 'postponed':
        bg = Colors.orange.withValues(alpha: 0.12);
        fg = Colors.orange.shade800;
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: fg.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
          ),
          6.w,
          Text(
            status.toUpperCase(),
            style:
                TextStyle(color: fg, fontSize: 10.5, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

/// Indian digit grouping (2,51,18,500 — not 25,118,500), matching
/// monthly_bookings_screen and the Accounts module. The rupee symbol is NOT
/// included: every call site writes its own '₹' prefix.
final _inrGrouped = NumberFormat.decimalPattern('en_IN');

String _money(double value) {
  if (value.isNaN || value.isInfinite) return '0';
  return _inrGrouped.format(value.round());
}

/// Money as ONE story instead of three unrelated tiles: what was booked, what
/// has come in, and what is still owed. The sales team's daily question is
/// "how much is left to collect", and a bar answers it at a glance where three
/// separate numbers made them do the subtraction themselves.
class _CollectionSummaryCard extends StatelessWidget {
  final double booked;
  final double collected;
  final double outstanding;
  final double pct; // 0..1
  final String scopeLabel;

  const _CollectionSummaryCard({
    required this.booked,
    required this.collected,
    required this.outstanding,
    required this.pct,
    required this.scopeLabel,
  });

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: crm.border.faded(0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: crm.textSecondary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.payments_outlined, size: 18, color: crm.textSecondary),
              ),
              12.w,
              Expanded(
                child: Text('COLLECTION  ·  $scopeLabel',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 11.5,
                        letterSpacing: 0.5,
                        fontWeight: FontWeight.w700,
                        color: crm.textSecondary)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: crm.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('${(pct * 100).round()}% collected',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: crm.success)),
              ),
            ],
          ),
          20.h,
          Tooltip(
            message: '₹${_money(booked)}',
            waitDuration: const Duration(milliseconds: 400),
            child: Text('₹${_moneyCompact(booked)} booked',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 32, height: 1.1, letterSpacing: -0.5, fontWeight: FontWeight.w800, color: crm.textPrimary)),
          ),
          20.h,
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 12,
              backgroundColor: crm.warning.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation<Color>(crm.success),
            ),
          ),
          16.h,
          Row(
            children: [
              Expanded(
                child: _CollectionLeg(
                  dot: crm.success,
                  label: 'Collected',
                  value: '₹${_moneyCompact(collected)}',
                  exact: '₹${_money(collected)}',
                ),
              ),
              Expanded(
                child: _CollectionLeg(
                  dot: crm.warning,
                  label: 'Still to collect',
                  value: '₹${_moneyCompact(outstanding)}',
                  exact: '₹${_money(outstanding)}',
                  alignEnd: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CollectionLeg extends StatelessWidget {
  final Color dot;
  final String label;
  final String value;
  final String exact;
  final bool alignEnd;

  const _CollectionLeg({
    required this.dot,
    required this.label,
    required this.value,
    required this.exact,
    this.alignEnd = false,
  });

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return Column(
      crossAxisAlignment: alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: alignEnd ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
            6.w,
            Flexible(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: crm.textSecondary)),
            ),
          ],
        ),
        4.h,
        Tooltip(
          message: exact,
          waitDuration: const Duration(milliseconds: 400),
          child: Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: crm.textPrimary)),
        ),
      ],
    );
  }
}

/// Status as slices of one whole rather than four separate tiles, so it is
/// obvious the parts add up to the stated total. Segments are drawn in
/// proportion, and any status outside the four named ones is kept as "Other"
/// so nothing silently goes missing.
class _StatusBreakdownCard extends StatelessWidget {
  final int total;
  final int confirmed;
  final int pending;
  final int completed;
  final int cancelled;
  final int other;
  final String scopeLabel;

  const _StatusBreakdownCard({
    required this.total,
    required this.confirmed,
    required this.pending,
    required this.completed,
    required this.cancelled,
    required this.other,
    required this.scopeLabel,
  });

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final segs = <(String, int, Color)>[
      ('Confirmed', confirmed, crm.primary),
      ('Pending', pending, crm.warning),
      ('Completed', completed, crm.success),
      ('Cancelled', cancelled, crm.destructive),
      if (other > 0) ('Other', other, crm.textSecondary),
    ];

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: crm.border.faded(0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: crm.textSecondary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.donut_small_outlined, size: 18, color: crm.textSecondary),
              ),
              12.w,
              Expanded(
                child: Text('WORKS BY STATUS  ·  $scopeLabel',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 11.5,
                        letterSpacing: 0.5,
                        fontWeight: FontWeight.w700,
                        color: crm.textSecondary)),
              ),
            ],
          ),
          20.h,
          Text('$total works',
              style: TextStyle(
                  fontSize: 32, height: 1.1, letterSpacing: -0.5, fontWeight: FontWeight.w800, color: crm.textPrimary)),
          20.h,
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 12,
              child: total <= 0
                  ? Container(color: crm.border)
                  : Row(
                      children: [
                        for (final s in segs)
                          if (s.$2 > 0) Expanded(flex: s.$2, child: Container(color: s.$3)),
                      ],
                    ),
            ),
          ),
          16.h,
          Wrap(
            spacing: 20,
            runSpacing: 12,
            children: [
              for (final s in segs)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 8, height: 8, decoration: BoxDecoration(color: s.$3, shape: BoxShape.circle)),
                    8.w,
                    Text('${s.$1} ${s.$2}',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700, color: crm.textPrimary)),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Compact form for headline tiles — 2.51Cr / 29.92L — so a crore-scale figure
/// stays scannable at a glance instead of running to eleven digits. Mirrors
/// sales_dashboard_screen and accounts_dashboard_screen. Below ₹1 lakh it falls
/// back to full grouping, and the exact figure is always kept in the tooltip.
String _moneyCompact(double value) {
  if (value.isNaN || value.isInfinite) return '0';
  final v = value.abs();
  final sign = value < 0 ? '-' : '';
  if (v >= 10000000) return '$sign${(v / 10000000).toStringAsFixed(2)}Cr';
  if (v >= 100000) return '$sign${(v / 100000).toStringAsFixed(2)}L';
  return _money(value);
}

// Left 70% panel: Today vs Yesterday sales with a trend chip.
class _TodayYesterdayPanel extends StatelessWidget {
  final double todaySales;
  final double yesterdaySales;
  final int todayWorks;
  final int yesterdayWorks;
  final double? trend; // % change today vs yesterday

  const _TodayYesterdayPanel({
    required this.todaySales,
    required this.yesterdaySales,
    required this.todayWorks,
    required this.yesterdayWorks,
    required this.trend,
  });

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    Widget dayBlock(String label, double amount, int works, Color accent) =>
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(width: 8, height: 8,
                    decoration:
                        BoxDecoration(color: accent, shape: BoxShape.circle)),
                6.w,
                Text(label.toUpperCase(),
                    style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 0.4,
                        fontWeight: FontWeight.w700,
                        color: crm.textSecondary)),
              ]),
              8.h,
              Text('₹${_money(amount)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: crm.textPrimary)),
              4.h,
              Text('$works work${works == 1 ? '' : 's'}',
                  style: TextStyle(fontSize: 12, color: crm.textSecondary)),
            ],
          ),
        );

    final up = (trend ?? 0) >= 0;
    final trendColor = up ? const Color(0xFF2E7D32) : const Color(0xFFD32F2F);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: crm.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.today_outlined, size: 18, color: crm.primary),
              8.w,
              Text("Today's Sales",
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: crm.textPrimary)),
              const Spacer(),
              if (trend != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: trendColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(up ? Icons.arrow_upward : Icons.arrow_downward,
                        size: 13, color: trendColor),
                    2.w,
                    Text('${trend!.abs().toStringAsFixed(0)}% vs yest.',
                        style: TextStyle(
                            color: trendColor,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800)),
                  ]),
                ),
            ],
          ),
          18.h,
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                dayBlock('Today', todaySales, todayWorks, crm.primary),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: VerticalDivider(width: 1, color: crm.border),
                ),
                dayBlock('Yesterday', yesterdaySales, yesterdayWorks,
                    crm.textSecondary),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Right 30% panel: Total revenue + Q1–Q4 works mini-bars for the selected FY.
// Tap opens the full quarterly performance inner page.
class _RevenueQuarterPanel extends StatelessWidget {
  final double totalRevenue;
  final List<int> quarterWorks; // length 4
  final String fyLabel;
  final VoidCallback? onTap;

  const _RevenueQuarterPanel({
    required this.totalRevenue,
    required this.quarterWorks,
    required this.fyLabel,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final maxQ = quarterWorks.fold<int>(1, (m, v) => v > m ? v : m);
    const labels = ['Q1', 'Q2', 'Q3', 'Q4'];

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: crm.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: crm.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('TOTAL REVENUE',
                  style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 0.4,
                      fontWeight: FontWeight.w700,
                      color: crm.textSecondary)),
              6.h,
              Tooltip(
                message: '₹${_money(totalRevenue)}',
                waitDuration: const Duration(milliseconds: 400),
                child: Text('₹${_moneyCompact(totalRevenue)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: crm.primary)),
              ),
              2.h,
              Text('FY $fyLabel',
                  style: TextStyle(fontSize: 12, color: crm.textSecondary)),
              16.h,
              Divider(height: 1, color: crm.border),
              14.h,
              Row(
                children: [
                  Text('WORKS BY QUARTER',
                      style: TextStyle(
                          fontSize: 11,
                          letterSpacing: 0.4,
                          fontWeight: FontWeight.w700,
                          color: crm.textSecondary)),
                  const Spacer(),
                  if (onTap != null)
                    Icon(Icons.chevron_right, size: 18, color: crm.primary),
                ],
              ),
              12.h,
              // Flex bars — the bar fills a fraction of the flexible area so it
              // can never overflow, regardless of the counts.
              SizedBox(
                height: 92,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (var i = 0; i < 4; i++)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Column(
                            children: [
                              Text('${quarterWorks[i]}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: crm.textPrimary)),
                              4.h,
                              Expanded(
                                child: FractionallySizedBox(
                                  alignment: Alignment.bottomCenter,
                                  heightFactor: quarterWorks[i] == 0
                                      ? 0.05
                                      : (quarterWorks[i] / maxQ)
                                          .clamp(0.08, 1.0)
                                          .toDouble(),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: crm.primary.withValues(
                                          alpha:
                                              quarterWorks[i] == 0 ? 0.15 : 0.85),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                  ),
                                ),
                              ),
                              4.h,
                              Text(labels[i],
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: crm.textSecondary)),
                            ],
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
    );
  }
}

String _formatDate(DateTime value) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final day = value.day.toString().padLeft(2, '0');
  final month = months[value.month - 1];
  return '$day-$month-${value.year}';
}
