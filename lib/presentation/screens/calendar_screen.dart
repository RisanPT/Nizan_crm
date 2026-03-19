import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/extensions/space_extension.dart';
import '../../core/models/booking.dart';
import '../../core/providers/booking_provider.dart';
import '../../core/theme/crm_theme.dart';
import '../../core/utils/responsive_builder.dart';
import '../../services/blocked_date_service.dart';

class CalendarScreen extends HookConsumerWidget {
  const CalendarScreen({super.key});

  // Maps service names to colors for the calendar blocks
  static const _serviceColors = {
    'hair': Color(0xFF0B1B3B),
    'makeup': Color(0xFFC9A66B),
    'spa': Color(0xFF0B5B37),
    'bridal': Color(0xFFC9A66B),
    'grooming': Color(0xFF0B1B3B),
    'facial': Color(0xFF0B5B37),
    'default': Color(0xFF0B1B3B),
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
    if (s.contains('makeup') || s.contains('bridal')) {
      return const Color(0xFFF2EDE4);
    }
    if (s.contains('spa') || s.contains('facial')) {
      return const Color(0xFFE6F6EE);
    }
    return const Color(0xFFF6F7F9);
  }

  static String _artistLabelForBooking(Booking booking) {
    final artistAssignment = booking.assignedStaff.cast<BookingAssignment?>().firstWhere(
          (assignment) =>
              assignment != null &&
              assignment.artistName.trim().isNotEmpty &&
              assignment.roleType.toLowerCase() == 'artist',
          orElse: () => null,
        );

    if (artistAssignment != null) {
      return artistAssignment.artistName.trim();
    }

    final fallbackAssignment = booking.assignedStaff.cast<BookingAssignment?>().firstWhere(
          (assignment) =>
              assignment != null && assignment.artistName.trim().isNotEmpty,
          orElse: () => null,
        );

    return fallbackAssignment?.artistName.trim() ?? 'Not Assigned';
  }

  static List<_ArtistDayGroup> _groupBookingsByArtist(List<Booking> bookings) {
    final grouped = <String, List<Booking>>{};

    for (final booking in bookings) {
      final label = _artistLabelForBooking(booking);
      grouped.putIfAbsent(label, () => <Booking>[]).add(booking);
    }

    final groups = grouped.entries
        .map(
          (entry) => _ArtistDayGroup(
            artistLabel: entry.key,
            bookings: entry.value..sort((a, b) => a.serviceStart.compareTo(b.serviceStart)),
          ),
        )
        .toList()
      ..sort((a, b) {
        if (a.artistLabel == 'Not Assigned' && b.artistLabel != 'Not Assigned') {
          return 1;
        }
        if (b.artistLabel == 'Not Assigned' && a.artistLabel != 'Not Assigned') {
          return -1;
        }
        return a.artistLabel.compareTo(b.artistLabel);
      });

    return groups;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final crmColors = context.crmColors;
    final isMobile = ResponsiveBuilder.isMobile(context);

    // All bookings from provider
    final asyncBookings = ref.watch(bookingProvider);
    final allBookings = asyncBookings.value ?? [];
    final confirmedBookings = allBookings
        .where((booking) => booking.status.toLowerCase() == 'confirmed')
        .toList();
    final asyncBlockedDates = ref.watch(blockedDatesProvider);
    final blockedDates = asyncBlockedDates.value ?? [];

    final now = DateTime.now();
    final currentWeekMonday = useMemoized(
      () => DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: now.weekday - 1)),
    );
    final weekStart = useState<DateTime>(currentWeekMonday);
    final monthFocus = useState<DateTime>(DateTime(now.year, now.month, 1));
    final viewMode = useState<String>('Month');

    final weekDays = List.generate(
      7,
      (i) => weekStart.value.add(Duration(days: i)),
    );

    int dayIndexFor(DateTime target) {
      for (int i = 0; i < weekDays.length; i++) {
        final d = weekDays[i];
        if (d.year == target.year &&
            d.month == target.month &&
            d.day == target.day) {
          return i;
        }
      }
      return 0;
    }

    final selectedDayIndex = useState(dayIndexFor(now));
    final selectedDay = weekDays[selectedDayIndex.value];

    String weekRangeTitle() {
      const months = [
        'January',
        'February',
        'March',
        'April',
        'May',
        'June',
        'July',
        'August',
        'September',
        'October',
        'November',
        'December',
      ];
      final start = weekDays.first;
      final end = weekDays.last;
      if (start.month == end.month) {
        return '${months[start.month - 1]} ${start.day} – ${end.day}, ${start.year}';
      }
      return '${months[start.month - 1]} ${start.day} – ${months[end.month - 1]} ${end.day}, ${start.year}';
    }

    String monthTitle(DateTime date) {
      const months = [
        'January',
        'February',
        'March',
        'April',
        'May',
        'June',
        'July',
        'August',
        'September',
        'October',
        'November',
        'December',
      ];
      return '${months[date.month - 1]} ${date.year}';
    }

    void goToToday() {
      weekStart.value = currentWeekMonday;
      selectedDayIndex.value = dayIndexFor(now);
      monthFocus.value = DateTime(now.year, now.month, 1);
    }

    void goToPreviousWeek() {
      if (viewMode.value == 'Month') {
        monthFocus.value = DateTime(
          monthFocus.value.year,
          monthFocus.value.month - 1,
          1,
        );
      } else {
        weekStart.value = weekStart.value.subtract(const Duration(days: 7));
        selectedDayIndex.value = 0;
      }
    }

    void goToNextWeek() {
      if (viewMode.value == 'Month') {
        monthFocus.value = DateTime(
          monthFocus.value.year,
          monthFocus.value.month + 1,
          1,
        );
      } else {
        weekStart.value = weekStart.value.add(const Duration(days: 7));
        selectedDayIndex.value = 0;
      }
    }

    Future<void> manageBlockedDates() async {
      final reasonCtrl = TextEditingController();
      DateTime? pickedDate;

      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setState) {
              Future<void> pickBlockedDate() async {
                final selected = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (selected != null) {
                  setState(() {
                    pickedDate = DateTime(
                      selected.year,
                      selected.month,
                      selected.day,
                    );
                  });
                }
              }

              Future<void> saveBlockedDate() async {
                if (pickedDate == null) return;

                try {
                  await ref.read(blockedDateServiceProvider).saveBlockedDate(
                        date: pickedDate!,
                        reason: reasonCtrl.text.trim(),
                      );
                  ref.invalidate(blockedDatesProvider);
                  if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                } catch (error) {
                  if (dialogContext.mounted) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      SnackBar(content: Text('Failed to save blocked date: $error')),
                    );
                  }
                }
              }

              return AlertDialog(
                title: const Text('Manage Blocked Dates'),
                content: SizedBox(
                  width: 520,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          OutlinedButton.icon(
                            onPressed: pickBlockedDate,
                            icon: const Icon(Icons.calendar_month_outlined),
                            label: Text(
                              pickedDate == null
                                  ? 'Choose date'
                                  : '${pickedDate!.year}-${pickedDate!.month.toString().padLeft(2, '0')}-${pickedDate!.day.toString().padLeft(2, '0')}',
                            ),
                          ),
                          SizedBox(
                            width: 260,
                            child: TextField(
                              controller: reasonCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Reason (optional)',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      18.h,
                      const Text(
                        'Blocked dates',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      12.h,
                      if (asyncBlockedDates.isLoading)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: CircularProgressIndicator(),
                        )
                      else if (blockedDates.isEmpty)
                        const Text('No blocked dates yet.')
                      else
                        SizedBox(
                          height: 220,
                          child: ListView.separated(
                            shrinkWrap: true,
                            itemCount: blockedDates.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final item = blockedDates[index];
                              final formatted =
                                  '${item.date.year}-${item.date.month.toString().padLeft(2, '0')}-${item.date.day.toString().padLeft(2, '0')}';
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(formatted),
                                subtitle: item.reason.isEmpty
                                    ? null
                                    : Text(item.reason),
                                trailing: IconButton(
                                  onPressed: () async {
                                    try {
                                      await ref
                                          .read(blockedDateServiceProvider)
                                          .deleteBlockedDate(item.id);
                                      ref.invalidate(blockedDatesProvider);
                                    } catch (error) {
                                      if (dialogContext.mounted) {
                                        ScaffoldMessenger.of(dialogContext)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Failed to remove blocked date: $error',
                                            ),
                                          ),
                                        );
                                      }
                                    }
                                  },
                                  icon: const Icon(Icons.delete_outline),
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text('Close'),
                  ),
                  ElevatedButton(
                    onPressed: pickedDate == null ? null : saveBlockedDate,
                    child: const Text('Save Blocked Date'),
                  ),
                ],
              );
            },
          );
        },
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
                  Text(
                    'Calendar Scheduler',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Manage staff bookings and services.',
                    style: TextStyle(color: crmColors.textSecondary),
                  ),
                ],
              ),
            ),
            if (!isMobile) ...[
              OutlinedButton.icon(
                onPressed: manageBlockedDates,
                icon: const Icon(Icons.calendar_month_outlined, size: 18),
                label: const Text('Blocked Dates'),
                style: OutlinedButton.styleFrom(
                  backgroundColor: crmColors.surface,
                ),
              ),
              16.w,
              OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.filter_list, size: 18),
                label: const Text('Filter'),
                style: OutlinedButton.styleFrom(
                  backgroundColor: crmColors.surface,
                ),
              ),
              16.w,
              ElevatedButton.icon(
                onPressed: () => context.push('/booking/add'),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('New Booking'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: crmColors.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ],
        ),
        if (isMobile) ...[
          16.h,
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: manageBlockedDates,
                  icon:  Icon(Icons.calendar_month, size: 18),
                  label: const Text('Blocked'),
                ),
              ),
              16.w,
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
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
        24.h,
        // ── Calendar card ─────────────────────────────────────────────--
        Expanded(
          child: Card(
            color: crmColors.surface,
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
                            onPressed: goToToday,
                            child: const Text('Today'),
                          ),
                          8.w,
                          IconButton(
                            onPressed: goToPreviousWeek,
                            icon: const Icon(Icons.chevron_left),
                          ),
                          IconButton(
                            onPressed: goToNextWeek,
                            icon: const Icon(Icons.chevron_right),
                          ),
                          16.w,
                          if (!isMobile)
                            Text(
                              viewMode.value == 'Month'
                                  ? monthTitle(monthFocus.value)
                                  : weekRangeTitle(),
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                        ],
                      ),
                      if (isMobile)
                        Text(
                          viewMode.value == 'Month'
                              ? monthTitle(monthFocus.value)
                              : weekRangeTitle(),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () {},
                            icon: const CircleAvatar(
                              radius: 4,
                              backgroundColor: Colors.blue,
                            ),
                            label: const Text('All Staff'),
                          ),
                          16.w,
                          SegmentedButton<String>(
                            segments: const [
                              ButtonSegment(value: 'Day', label: Text('Day')),
                              ButtonSegment(value: 'Week', label: Text('Week')),
                              ButtonSegment(
                                value: 'Month',
                                label: Text('Month'),
                              ),
                            ],
                            selected: {viewMode.value},
                            onSelectionChanged: (selection) {
                              final selected = selection.first;
                              viewMode.value = selected == 'Day'
                                  ? 'Week'
                                  : selected;
                            },
                            style: SegmentedButton.styleFrom(
                              backgroundColor: crmColors.input,
                              selectedBackgroundColor: crmColors.surface,
                              selectedForegroundColor: crmColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    child: viewMode.value == 'Month'
                        ? _monthView(
                            context,
                            crmColors,
                            confirmedBookings,
                            monthFocus.value,
                            now,
                          )
                        : viewMode.value == 'Day'
                        ? _dayView(
                            context,
                            crmColors,
                            confirmedBookings,
                            selectedDay,
                            now,
                          )
                        : !isMobile
                        ? _weekView(
                            context,
                            crmColors,
                            confirmedBookings,
                            weekDays,
                            now,
                          )
                        : isMobile
                        ? _mobileDay(
                            context,
                            crmColors,
                            [
                              ...confirmedBookings.where(
                                (b) => b.isOnDate(selectedDay),
                              ),
                            ]..sort(
                              (a, b) =>
                                  a.serviceStart.compareTo(b.serviceStart),
                            ),
                            selectedDay,
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Wrap(
                    spacing: 24,
                    runSpacing: 12,
                    children: [
                      _buildLegendItem(
                        context,
                        'Hair Services',
                        _serviceColors['hair']!,
                      ),
                      _buildLegendItem(
                        context,
                        'Makeup & Bridal',
                        _serviceColors['makeup']!,
                      ),
                      _buildLegendItem(
                        context,
                        'Spa & Massage',
                        _serviceColors['spa']!,
                      ),
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
              Icon(Icons.event_available, size: 48, color: crmColors.border),
              16.h,
              Text(
                'No bookings for this day',
                style: TextStyle(color: crmColors.textSecondary),
              ),
              8.h,
              ElevatedButton.icon(
                onPressed: () => context.push('/booking/add'),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('New Booking'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: crmColors.primary,
                  foregroundColor: Colors.white,
                ),
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
      separatorBuilder: (context, index) => 12.h,
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
                left: BorderSide(color: _colorForService(b.service), width: 4),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        b.service,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      4.h,
                      Text(
                        '${_fmt(b.serviceStart)} – ${_fmt(b.serviceEnd)}',
                        style: TextStyle(
                          color: crmColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      4.h,
                      Text(
                        _artistLabelForBooking(b),
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: _artistLabelForBooking(b) == 'Not Assigned'
                              ? crmColors.textSecondary
                              : crmColors.textPrimary,
                        ),
                      ),
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

  Widget _monthView(
    BuildContext context,
    CrmTheme crmColors,
    List<Booking> bookings,
    DateTime month,
    DateTime now,
  ) {
    final days = _buildMonthCells(month);
    const weekdayLabels = ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'];

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
          color: crmColors.surface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: crmColors.border),
        ),
        child: Column(
          children: [
            Row(
              children: weekdayLabels
                  .map(
                    (label) => Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        child: Text(
                          label,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: crmColors.textSecondary,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const Divider(height: 1),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: days.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                childAspectRatio: 1.02,
              ),
              itemBuilder: (context, index) {
                final day = days[index];
                final dayBookings = bookings
                    .where((booking) => booking.isOnDate(day))
                    .toList()
                  ..sort((a, b) => a.serviceStart.compareTo(b.serviceStart));
                final artistGroups = _groupBookingsByArtist(dayBookings);
                final isCurrentMonth = day.month == month.month;
                final isToday =
                    day.year == now.year &&
                    day.month == now.month &&
                    day.day == now.day;

                return Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    border: Border(
                      right: BorderSide(color: crmColors.border),
                      bottom: BorderSide(color: crmColors.border),
                    ),
                    color: isCurrentMonth
                        ? crmColors.surface
                        : crmColors.background.withValues(alpha: 0.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Align(
                        alignment: Alignment.topCenter,
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isToday ? crmColors.primary : Colors.transparent,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '${day.day}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: isToday
                                  ? Colors.white
                                  : isCurrentMonth
                                  ? crmColors.textPrimary
                                  : crmColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                      8.h,
                      ...artistGroups.take(4).map(
                        (group) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: _buildMonthBookingPill(context, group),
                        ),
                      ),
                      if (artistGroups.length > 4)
                        Padding(
                          padding: const EdgeInsets.only(top: 2, left: 6),
                          child: Text(
                            '${artistGroups.length - 4} more',
                            style: TextStyle(
                              color: crmColors.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _weekView(
    BuildContext context,
    CrmTheme crmColors,
    List<Booking> bookings,
    List<DateTime> weekDays,
    DateTime now,
  ) {
    const timelineHours = [
      '1 AM',
      '2 AM',
      '3 AM',
      '4 AM',
      '5 AM',
      '6 AM',
      '7 AM',
      '8 AM',
      '9 AM',
    ];
    const topLaneHeight = 92.0;
    const hourRowHeight = 64.0;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
          color: crmColors.surface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: crmColors.border),
        ),
        child: Column(
          children: [
            Row(
              children: [
                const SizedBox(width: 84),
                ...weekDays.map(
                  (day) => Expanded(
                    child: _buildTopDayHeader(
                      context,
                      day: day,
                      now: now,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 1),
            SizedBox(
              height: topLaneHeight + (timelineHours.length * hourRowHeight),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 84,
                    child: Column(
                      children: [
                        Container(
                          height: topLaneHeight,
                          alignment: Alignment.topCenter,
                          padding: const EdgeInsets.only(top: 12),
                          decoration: BoxDecoration(
                            border: Border(
                              right: BorderSide(color: crmColors.border),
                            ),
                          ),
                          child: Text(
                            'GMT+04',
                            style: TextStyle(
                              color: crmColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        ...timelineHours.map(
                          (label) => Container(
                            height: hourRowHeight,
                            alignment: Alignment.topRight,
                            padding: const EdgeInsets.only(top: 8, right: 12),
                            decoration: BoxDecoration(
                              border: Border(
                                right: BorderSide(color: crmColors.border),
                                bottom: BorderSide(
                                  color: crmColors.border.withValues(alpha: 0.7),
                                ),
                              ),
                            ),
                            child: Text(
                              label,
                              style: TextStyle(
                                color: crmColors.textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ...weekDays.map((day) {
                    final dayBookings = bookings
                        .where((booking) => booking.isOnDate(day))
                        .toList()
                      ..sort((a, b) => a.serviceStart.compareTo(b.serviceStart));
                    final artistGroups = _groupBookingsByArtist(dayBookings);

                    return Expanded(
                      child: Column(
                        children: [
                          Container(
                            height: topLaneHeight,
                            padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
                            decoration: BoxDecoration(
                              border: Border(
                                right: BorderSide(color: crmColors.border),
                                bottom: BorderSide(color: crmColors.border),
                              ),
                            ),
                            child: Column(
                              children: [
                                ...artistGroups.take(3).map(
                                  (group) => Padding(
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: _buildReferencePill(
                                      context,
                                      group,
                                      compact: true,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ...timelineHours.map(
                            (_) => Container(
                              height: hourRowHeight,
                              decoration: BoxDecoration(
                                border: Border(
                                  right: BorderSide(color: crmColors.border),
                                  bottom: BorderSide(
                                    color: crmColors.border.withValues(alpha: 0.7),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dayView(
    BuildContext context,
    CrmTheme crmColors,
    List<Booking> bookings,
    DateTime day,
    DateTime now,
  ) {
    const timelineHours = [
      '1 AM',
      '2 AM',
      '3 AM',
      '4 AM',
      '5 AM',
      '6 AM',
      '7 AM',
      '8 AM',
      '9 AM',
    ];
    const topLaneHeight = 96.0;
    const hourRowHeight = 64.0;

    final dayBookings = bookings
        .where((booking) => booking.isOnDate(day))
        .toList()
      ..sort((a, b) => a.serviceStart.compareTo(b.serviceStart));
    final artistGroups = _groupBookingsByArtist(dayBookings);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
          color: crmColors.surface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: crmColors.border),
        ),
        child: Column(
          children: [
            Row(
              children: [
                const SizedBox(width: 84),
                Expanded(
                  child: _buildTopDayHeader(
                    context,
                    day: day,
                    now: now,
                  ),
                ),
              ],
            ),
            const Divider(height: 1),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 84,
                  child: Column(
                    children: [
                      Container(
                        height: topLaneHeight,
                        alignment: Alignment.topCenter,
                        padding: const EdgeInsets.only(top: 12),
                        decoration: BoxDecoration(
                          border: Border(
                            right: BorderSide(color: crmColors.border),
                          ),
                        ),
                        child: Text(
                          'GMT+04',
                          style: TextStyle(
                            color: crmColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      ...timelineHours.map(
                        (label) => Container(
                          height: hourRowHeight,
                          alignment: Alignment.topRight,
                          padding: const EdgeInsets.only(top: 8, right: 12),
                          decoration: BoxDecoration(
                            border: Border(
                              right: BorderSide(color: crmColors.border),
                              bottom: BorderSide(
                                color: crmColors.border.withValues(alpha: 0.7),
                              ),
                            ),
                          ),
                          child: Text(
                            label,
                            style: TextStyle(
                              color: crmColors.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Container(
                        height: topLaneHeight,
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: crmColors.border),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ...artistGroups.map(
                              (group) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: _buildReferencePill(context, group),
                              ),
                            ),
                            if (artistGroups.isEmpty)
                              Text(
                                'No confirmed bookings',
                                style: TextStyle(
                                  color: crmColors.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                          ],
                        ),
                      ),
                      ...timelineHours.map(
                        (_) => Container(
                          height: hourRowHeight,
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: crmColors.border.withValues(alpha: 0.7),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(BuildContext context, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        8.w,
        Text(
          label,
          style: TextStyle(
            color: context.crmColors.textSecondary,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _buildMonthBookingPill(
    BuildContext context,
    _ArtistDayGroup group,
  ) {
    return _buildReferencePill(context, group);
  }

  Widget _buildReferencePill(
    BuildContext context,
    _ArtistDayGroup group, {
    bool compact = false,
  }) {
    final booking = group.bookings.first;
    final accent = _colorForService(booking.service);
    final label = group.count > 1
        ? '${group.artistLabel.toUpperCase()} (${group.count})'
        : group.artistLabel.toUpperCase();

    return InkWell(
      onTap: () => context.push('/booking/manage/${booking.id}'),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 10,
          vertical: compact ? 5 : 6,
        ),
        decoration: BoxDecoration(
          color: accent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white,
            fontSize: compact ? 11 : 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildTopDayHeader(
    BuildContext context, {
    required DateTime day,
    required DateTime now,
  }) {
    final crmColors = context.crmColors;
    final isToday =
        day.year == now.year && day.month == now.month && day.day == now.day;
    const names = ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'];
    final dayName = names[day.weekday % 7];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(color: crmColors.border),
        ),
      ),
      child: Column(
        children: [
          Text(
            dayName,
            style: TextStyle(
              color: isToday ? crmColors.primary : crmColors.textSecondary,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          10.h,
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isToday ? crmColors.primary : Colors.transparent,
            ),
            alignment: Alignment.center,
            child: Text(
              '${day.day}',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w500,
                color: isToday ? Colors.white : crmColors.textPrimary,
              ),
            ),
          ),
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

  static List<DateTime> _buildMonthCells(DateTime month) {
    final monthStart = DateTime(month.year, month.month, 1);
    final gridStart = monthStart.subtract(Duration(days: monthStart.weekday % 7));
    return List.generate(
      42,
      (index) => DateTime(
        gridStart.year,
        gridStart.month,
        gridStart.day + index,
      ),
    );
  }
}

class _ArtistDayGroup {
  final String artistLabel;
  final List<Booking> bookings;

  const _ArtistDayGroup({
    required this.artistLabel,
    required this.bookings,
  });

  int get count => bookings.length;
}
