import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/extensions/space_extension.dart';
import '../../core/models/booking.dart';
import '../../core/providers/booking_provider.dart';
import '../../core/theme/crm_theme.dart';
import '../../core/utils/responsive_builder.dart';

class CalendarScreen extends HookConsumerWidget {
  const CalendarScreen({super.key});

  // Maps service names to colors for the calendar blocks
  static const _serviceColors = {
    'hair': Color(0xFF1E3A5F),
    'makeup': Color(0xFFD97706),
    'spa': Color(0xFF10B981),
    'bridal': Color(0xFFD97706),
    'grooming': Color(0xFF1E3A5F),
    'facial': Color(0xFF10B981),
    'default': Color(0xFF1E3A5F),
  };

  static Color _colorForService(String service) {
    final s = service.toLowerCase();
    for (final key in _serviceColors.keys) {
      if (s.contains(key)) return _serviceColors[key]!;
    }
    return _serviceColors['default']!;
  }

  static Color _bgForService(String service) {
    final s = service.toLowerCase();
    if (s.contains('makeup') || s.contains('bridal')) return const Color(0xFFFEF3C7);
    if (s.contains('spa') || s.contains('facial')) return const Color(0xFFD1FAE5);
    return const Color(0xFFE2E8F0);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final crmColors = context.crmColors;
    final isMobile = ResponsiveBuilder.isMobile(context);

    // All bookings from provider
    final allBookings = ref.watch(bookingProvider);

    // Current week anchor: Monday of the current week
    final now = DateTime.now();
    final monday = useMemoized(
      () => now.subtract(Duration(days: now.weekday - 1)),
    );

    // 6-day week (Mon–Sat)
    final weekDays = useMemoized(
      () => List.generate(6, (i) => monday.add(Duration(days: i))),
      [monday],
    );

    // Selected day index — default to today within the week
    final todayIndex = useMemoized(() {
      for (int i = 0; i < weekDays.length; i++) {
        final d = weekDays[i];
        if (d.year == now.year && d.month == now.month && d.day == now.day) {
          return i;
        }
      }
      return 0;
    }, [weekDays]);
    final selectedDayIndex = useState(todayIndex);
    final selectedDay = weekDays[selectedDayIndex.value];

    // Hours shown on the grid (08:00 – 20:00)
    const hours = [
      '08:00', '09:00', '10:00', '11:00', '12:00',
      '13:00', '14:00', '15:00', '16:00', '17:00',
      '18:00', '19:00', '20:00',
    ];
    const rowHeight = 80.0;
    const startHour = 8;

    // Format a day header: "MON\n13"
    String dayLabel(DateTime d) {
      const names = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
      return '${names[d.weekday - 1]}\n${d.day}';
    }

    String monthRangeTitle() {
      const months = [
        'January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December'
      ];
      final start = weekDays.first;
      final end = weekDays.last;
      if (start.month == end.month) {
        return '${months[start.month - 1]} ${start.day} – ${end.day}, ${start.year}';
      }
      return '${months[start.month - 1]} ${start.day} – ${months[end.month - 1]} ${end.day}, ${start.year}';
    }

    /// Translate a booking into a Positioned widget for the grid column.
    Widget? positionedBooking(BuildContext ctx, Booking b) {
      final startH = b.serviceStart.hour + b.serviceStart.minute / 60.0;
      final endH = b.serviceEnd.hour + b.serviceEnd.minute / 60.0;
      final topOffset = (startH - startHour) * rowHeight;
      final rawBlockHeight = (endH - startH) * rowHeight;

      // Skip inverted or out-of-range bookings
      if (topOffset < 0 || topOffset >= hours.length * rowHeight) return null;
      if (rawBlockHeight <= 0) return null; // end before/same as start

      final blockHeight = rawBlockHeight.clamp(50.0, double.infinity);

      return Positioned(
        top: topOffset,
        left: 4,
        right: 4,
        height: blockHeight,
        child: GestureDetector(
          onTap: () => context.push('/booking/manage/${b.id}'),
          child: ClipRect(
            child: _buildEventBlock(
              ctx,
              title: b.service,
              time: '${_fmt(b.serviceStart)} – ${_fmt(b.serviceEnd)}',
              patient: b.customerName,
              bgColor: _bgForService(b.service),
              indicatorColor: _colorForService(b.service),
              blockHeight: blockHeight,
            ),
          ),
        ),
      );
    }


    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Page header ──────────────────────────────────────────────────
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Calendar Scheduler',
                      style: theme.textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  Text('Manage staff bookings and services.',
                      style: TextStyle(color: crmColors.textSecondary)),
                ],
              ),
            ),
            if (!isMobile) ...[
              OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.filter_list, size: 18),
                label: const Text('Filter'),
                style: OutlinedButton.styleFrom(backgroundColor: Colors.white),
              ),
              16.w,
              ElevatedButton.icon(
                onPressed: () => context.push('/booking/add'),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('New Booking'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: crmColors.primary,
                    foregroundColor: Colors.white),
              ),
            ]
          ],
        ),
        if (isMobile) ...[
          16.h,
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.filter_list, size: 18),
                label: const Text('Filter'),
              ),
            ),
            16.w,
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => context.push('/booking/add'),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('New Booking'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: crmColors.primary,
                    foregroundColor: Colors.white),
              ),
            ),
          ]),
        ],
        24.h,
        // ── Calendar card ─────────────────────────────────────────────--
        Expanded(
          child: Card(
            color: Colors.white,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: crmColors.border),
            ),
            child: Column(
              children: [
                // Toolbar
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          OutlinedButton(
                              onPressed: () {},
                              child: const Text('Today')),
                          8.w,
                          IconButton(
                              onPressed: () {},
                              icon: const Icon(Icons.chevron_left)),
                          IconButton(
                              onPressed: () {},
                              icon: const Icon(Icons.chevron_right)),
                          16.w,
                          if (!isMobile)
                            Text(monthRangeTitle(),
                                style: theme.textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      if (isMobile)
                        Text(monthRangeTitle(),
                            style: theme.textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold)),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () {},
                            icon: const CircleAvatar(
                                radius: 4, backgroundColor: Colors.blue),
                            label: const Text('All Staff'),
                          ),
                          16.w,
                          SegmentedButton<String>(
                            segments: const [
                              ButtonSegment(value: 'Day', label: Text('Day')),
                              ButtonSegment(value: 'Week', label: Text('Week')),
                              ButtonSegment(
                                  value: 'Month', label: Text('Month')),
                            ],
                            selected: const {'Week'},
                            onSelectionChanged: (_) {},
                            style: SegmentedButton.styleFrom(
                              backgroundColor: const Color(0xFFF1F5F9),
                              selectedBackgroundColor: Colors.white,
                              selectedForegroundColor: crmColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                // ── Column headers (desktop) / tabs (mobile) ────────────
                if (!isMobile)
                  Container(
                    color: const Color(0xFFF8FAFC),
                    child: Row(
                      children: [
                        const SizedBox(width: 60),
                        ...weekDays.asMap().entries.map((entry) {
                          final i = entry.key;
                          final d = entry.value;
                          final label = dayLabel(d);
                          final isSelected = i == selectedDayIndex.value;
                          final isToday = d.year == now.year &&
                              d.month == now.month &&
                              d.day == now.day;
                          // Count bookings on this day
                          final count = allBookings
                              .where((b) => b.isOnDate(d))
                              .length;
                          return Expanded(
                            child: InkWell(
                              onTap: () => selectedDayIndex.value = i,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 10),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? crmColors.primary.withValues(alpha: 0.07)
                                      : null,
                                  border: Border(
                                    left: BorderSide(color: crmColors.border),
                                    bottom: BorderSide(color: crmColors.border),
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Column(
                                  children: [
                                    Text(
                                      label,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontWeight: isToday || isSelected
                                            ? FontWeight.bold
                                            : FontWeight.w500,
                                        color: isToday || isSelected
                                            ? crmColors.primary
                                            : crmColors.textSecondary,
                                        fontSize: 13,
                                      ),
                                    ),
                                    if (count > 0) ...[
                                      4.h,
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: crmColors.primary,
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          '$count',
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                if (isMobile)
                  TabBar(
                    isScrollable: true,
                    onTap: (i) => selectedDayIndex.value = i,
                    tabs: weekDays
                        .map((d) => Tab(text: dayLabel(d).replaceAll('\n', ' ')))
                        .toList(),
                  ),
                // ── Grid body ────────────────────────────────────────────
                Expanded(
                  child: SingleChildScrollView(
                    child: isMobile
                        ? _mobileDay(
                            context,
                            crmColors,
                            allBookings
                                .where((b) => b.isOnDate(selectedDay))
                                .toList(),
                            selectedDay,
                          )
                        : Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Time column
                              SizedBox(
                                width: 60,
                                child: Column(
                                  children: hours
                                      .map((h) => Container(
                                            height: rowHeight,
                                            alignment: Alignment.topCenter,
                                            padding: const EdgeInsets.only(
                                                top: 8),
                                            decoration: BoxDecoration(
                                              border: Border(
                                                right: BorderSide(
                                                    color: crmColors.border),
                                              ),
                                            ),
                                            child: Text(h,
                                                style: TextStyle(
                                                    fontSize: 12,
                                                    color: crmColors
                                                        .textSecondary)),
                                          ))
                                      .toList(),
                                ),
                              ),
                              // Day columns
                              ...weekDays.asMap().entries.map((entry) {
                                final i = entry.key;
                                final day = entry.value;
                                final dayBookings = allBookings
                                    .where((b) => b.isOnDate(day))
                                    .toList();
                                final isSelected =
                                    i == selectedDayIndex.value;

                                return Expanded(
                                  child: GestureDetector(
                                    onTap: () =>
                                        selectedDayIndex.value = i,
                                    child: Container(
                                      color: isSelected
                                          ? crmColors.primary
                                              .withValues(alpha: 0.03)
                                          : null,
                                      child: Stack(
                                        children: [
                                          // Hour grid lines
                                          Column(
                                            children: hours
                                                .map((_) => Container(
                                                      height: rowHeight,
                                                      decoration:
                                                          BoxDecoration(
                                                        border: Border(
                                                          right: BorderSide(
                                                              color: crmColors
                                                                  .border),
                                                          bottom: BorderSide(
                                                              color: crmColors
                                                                  .border
                                                                  .withValues(
                                                                      alpha:
                                                                          0.5)),
                                                        ),
                                                      ),
                                                    ))
                                                .toList(),
                                          ),
                                          // Booking blocks
                                          ...dayBookings
                                              .map((b) =>
                                                  positionedBooking(
                                                      context, b))
                                              .whereType<Widget>(),
                                          // Empty state tap hint
                                          if (dayBookings.isEmpty)
                                            Positioned(
                                              top: 8,
                                              left: 0,
                                              right: 0,
                                              child: Center(
                                                child: Icon(
                                                  Icons.add_circle_outline,
                                                  size: 20,
                                                  color: crmColors.border,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ],
                          ),
                  ),
                ),
                const Divider(height: 1),
                // Legend
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      _buildLegendItem(context, 'Hair Services',
                          _serviceColors['hair']!),
                      24.w,
                      _buildLegendItem(context, 'Makeup & Bridal',
                          _serviceColors['makeup']!),
                      24.w,
                      _buildLegendItem(context, 'Spa & Massage',
                          _serviceColors['spa']!),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Mobile: show bookings for selected day as a list ─────────────────────
  Widget _mobileDay(
    BuildContext context,
    CrmTheme crmColors,
    List<Booking> bookings,
    DateTime day,
  ) {
    if (bookings.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.event_available,
                  size: 48, color: crmColors.border),
              16.h,
              Text('No bookings for this day',
                  style: TextStyle(color: crmColors.textSecondary)),
              8.h,
              ElevatedButton.icon(
                onPressed: () => context.push('/booking/add'),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('New Booking'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: crmColors.primary,
                    foregroundColor: Colors.white),
              ),
            ],
          ),
        ),
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: bookings.length,
      separatorBuilder: (_, __) => 12.h,
      itemBuilder: (ctx, i) {
        final b = bookings[i];
        return GestureDetector(
          onTap: () => context.push('/booking/manage/${b.id}'),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _bgForService(b.service),
              borderRadius: BorderRadius.circular(8),
              border: Border(
                left: BorderSide(
                    color: _colorForService(b.service), width: 4),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(b.service,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14)),
                      4.h,
                      Text(
                          '${_fmt(b.serviceStart)} – ${_fmt(b.serviceEnd)}',
                          style: TextStyle(
                              color: crmColors.textSecondary,
                              fontSize: 12)),
                      if (b.customerName.isNotEmpty) ...[
                        4.h,
                        Text(b.customerName,
                            style:
                                const TextStyle(fontWeight: FontWeight.w500)),
                      ],
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: crmColors.textSecondary),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLegendItem(
      BuildContext context, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
              color: color, borderRadius: BorderRadius.circular(2)),
        ),
        8.w,
        Text(label,
            style: TextStyle(
                color: context.crmColors.textSecondary, fontSize: 13)),
      ],
    );
  }

  Widget _buildEventBlock(
    BuildContext context, {
    required String title,
    required String time,
    required String patient,
    required Color bgColor,
    required Color indicatorColor,
    String? extraDesc,
    double blockHeight = 80,
  }) {
    final crmColors = context.crmColors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
        border: Border(left: BorderSide(color: indicatorColor, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            overflow: TextOverflow.ellipsis,
            maxLines: blockHeight > 70 ? 2 : 1,
          ),
          if (blockHeight >= 55) ...[
            2.h,
            Text(
              time,
              style: TextStyle(fontSize: 10, color: crmColors.textSecondary),
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (patient.isNotEmpty && blockHeight >= 70) ...[
            4.h,
            Row(
              children: [
                CircleAvatar(
                  radius: 8,
                  backgroundColor: crmColors.primary.withValues(alpha: 0.15),
                  child: Text(
                    patient[0],
                    style: TextStyle(fontSize: 8, color: crmColors.primary),
                  ),
                ),
                4.w,
                Expanded(
                  child: Text(
                    patient,
                    style: TextStyle(
                      fontSize: 10,
                      color: crmColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static String _fmt(DateTime dt) {
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour < 12 ? 'AM' : 'PM';
    return '$h:$m $ampm';
  }
}
