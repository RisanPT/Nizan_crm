import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/extensions/space_extension.dart';
import '../common_widgets/add_booking_mode_sheet.dart';
import '../common_widgets/reference_images.dart';
import '../../core/models/booking.dart';
import '../../core/models/employee.dart';
import '../../core/models/zone.dart';
import '../../core/models/geographic_state.dart';
import '../../core/models/service_region.dart';
import '../../core/models/district.dart';
import '../../core/providers/booking_provider.dart';
import '../../core/theme/crm_theme.dart';
import '../../core/utils/booking_print_service.dart';
import '../../core/utils/responsive_builder.dart';
import '../../services/blocked_date_service.dart';
import '../../services/employee_service.dart';
import '../../services/zone_service.dart';
import '../../services/state_service.dart';
import '../../services/region_service.dart';
import '../../services/district_service.dart';
import '../../core/auth/app_role.dart';
import '../../core/providers/auth_provider.dart';

class CalendarScreen extends HookConsumerWidget {
  const CalendarScreen({super.key, this.initialFocusDate});

  final DateTime? initialFocusDate;

  // Maps service names to colors for the calendar blocks
  static const _serviceColors = {
    'hair': Color(0xFF601A29),
    'makeup': Color(0xFFC9A66B),
    'spa': Color(0xFF0B5B37),
    'bridal': Color(0xFFC9A66B),
    'grooming': Color(0xFF601A29),
    'facial': Color(0xFF0B5B37),
    'default': Color(0xFF601A29),
  };

  static Color _colorForService(String service) {
    final s = service.toLowerCase();
    for (final key in _serviceColors.keys) {
      if (s.contains(key)) return _serviceColors[key]!;
    }
    return _serviceColors['default']!;
  }

  // ignore: unused_element
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

  static String _artistLabelForEntry(BookingDisplayEntry entry) {
    final artistAssignment = _primaryArtistAssignment(entry);

    if (artistAssignment != null) {
      return artistAssignment.artistName.trim();
    }

    final fallbackAssignment = entry.assignedStaff
        .cast<BookingAssignment?>()
        .firstWhere(
          (assignment) =>
              assignment != null && assignment.artistName.trim().isNotEmpty,
          orElse: () => null,
        );

    final customerName = entry.booking.customerName.trim();
    return fallbackAssignment?.artistName.trim() ??
        (customerName.isNotEmpty ? customerName : 'Not Assigned');
  }

  static BookingAssignment? _primaryArtistAssignment(BookingDisplayEntry entry) {
    return entry.assignedStaff.cast<BookingAssignment?>().firstWhere(
      (assignment) =>
          assignment != null &&
          assignment.artistName.trim().isNotEmpty &&
          (assignment.roleType.toLowerCase() == 'artist' ||
              assignment.roleType.toLowerCase() == 'lead'),
      orElse: () => null,
    );
  }

  // Colour by booking status. Softer, lower-contrast tones (still readable with
  // white text). Completed shows GREEN (per requirement); the rest stay distinct.
  static Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return const Color(0xFF5AA06E); // soft green
      case 'cancelled':
        return const Color(0xFFD07A7A); // soft red
      case 'postponed':
        return const Color(0xFFDDA05F); // soft amber
      case 'confirmed':
        return const Color(0xFF6699CC); // soft blue
      default:
        return const Color(0xFF7C8E9A); // soft slate (pending / other)
    }
  }

  // Stable identity for the assigned artist of a work, so we can count how many
  // works one artist has in a day. Null when no artist is assigned.
  static String? _artistKeyForEntry(BookingDisplayEntry entry) {
    final assignment = _primaryArtistAssignment(entry) ??
        entry.assignedStaff.cast<BookingAssignment?>().firstWhere(
              (a) => a != null && a.artistName.trim().isNotEmpty,
              orElse: () => null,
            );
    if (assignment == null) return null;
    return assignment.employeeId.trim().isNotEmpty
        ? 'id:${assignment.employeeId.trim()}'
        : 'name:${assignment.artistName.trim().toLowerCase()}';
  }

  static List<BookingDisplayEntry> _entriesForDay(
    List<Booking> bookings,
    DateTime day,
  ) {
    final entries = bookings
        .expand((booking) => booking.displayEntries)
        .where((entry) => entry.isOnDate(day))
        .toList()
      ..sort((a, b) {
        final startComparison = a.serviceStart.compareTo(b.serviceStart);
        if (startComparison != 0) return startComparison;
        return a.summaryLabel.compareTo(b.summaryLabel);
      });

    return entries;
  }

  static List<_ArtistDayGroup> _groupBookingsByArtist(
    List<BookingDisplayEntry> bookings,
  ) {
    final grouped = <String, List<BookingDisplayEntry>>{};
    final groupLabels = <String, String>{};
    final groupTypes = <String, bool>{};
    for (final entry in bookings) {
      final isCancelled = entry.booking.status.toLowerCase() == 'cancelled';
      final isPostponed = entry.booking.status.toLowerCase() == 'postponed';
      final isCompleted = entry.booking.status.toLowerCase() == 'completed';

      if (isCancelled || isPostponed) {
        // Cancelled and postponed bookings are treated individually to show distinct color with client name
        final key = isCancelled ? 'cancelled:${entry.id}' : 'postponed:${entry.id}';
        grouped.putIfAbsent(key, () => <BookingDisplayEntry>[]).add(entry);
        groupLabels[key] = entry.booking.customerName.trim();
        groupTypes[key] = false;
      } else {
        final assignedArtist = _primaryArtistAssignment(entry);
        String label = _artistLabelForEntry(entry);
        
        if (isCompleted) {
          // If completed, ensure the label is the artist name if assigned, or fallback
          final fallbackAssignment = entry.assignedStaff
              .cast<BookingAssignment?>()
              .firstWhere(
                (assignment) =>
                    assignment != null && assignment.artistName.trim().isNotEmpty,
                orElse: () => null,
              );
          label = fallbackAssignment?.artistName.trim() ?? 'Not Assigned';
        }

        final key = assignedArtist != null
            ? 'artist:${assignedArtist.employeeId.isNotEmpty ? assignedArtist.employeeId : assignedArtist.artistName.trim().toLowerCase()}'
            : 'entry:${entry.id}';
        grouped.putIfAbsent(key, () => <BookingDisplayEntry>[]).add(entry);
        groupLabels[key] = label;
        groupTypes[key] = assignedArtist != null;
      }
    }

    final groups = grouped.entries
        .map(
          (entry) => _ArtistDayGroup(
            artistLabel: groupLabels[entry.key] ?? 'Not Assigned',
            hasAssignedArtistGroup: groupTypes[entry.key] ?? false,
            bookings: entry.value..sort((a, b) => a.serviceStart.compareTo(b.serviceStart)),
          ),
        )
        .toList()
      ..sort((a, b) {
        if (a.artistLabel == 'Not Assigned' &&
            b.artistLabel != 'Not Assigned') {
          return 1;
        }
        if (b.artistLabel == 'Not Assigned' &&
            a.artistLabel != 'Not Assigned') {
          return -1;
        }
        final timeComparison = a.bookings.first.serviceStart.compareTo(
          b.bookings.first.serviceStart,
        );
        if (timeComparison != 0) return timeComparison;
        return a.artistLabel.compareTo(b.artistLabel);
      });

    return groups;
  }

  // ── Day view = 3 columns: previous · selected · next ──────────────────────

  Widget _threeDayView(
    BuildContext context,
    WidgetRef ref,
    CrmTheme crm,
    List<Booking> bookings,
    DateTime selectedDay,
    void Function(DateTime) onSelectDay,
  ) {
    final sel = DateTime(selectedDay.year, selectedDay.month, selectedDay.day);
    final days = [
      sel.subtract(const Duration(days: 1)),
      sel,
      sel.add(const Duration(days: 1)),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final d in days)
              Expanded(
                child: _dayWorksColumn(
                  context,
                  ref,
                  crm,
                  bookings,
                  d,
                  selected: d == sel,
                  onSelectDay: onSelectDay,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _dayWorksColumn(
    BuildContext context,
    WidgetRef ref,
    CrmTheme crm,
    List<Booking> bookings,
    DateTime day, {
    required bool selected,
    required void Function(DateTime) onSelectDay,
  }) {
    const wd = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    const mo = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final entries = _entriesForDay(bookings, day);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: selected ? crm.primary : crm.border,
            width: selected ? 2 : 1),
        boxShadow: selected
            ? [
                BoxShadow(
                    color: crm.primary.withValues(alpha: 0.18),
                    blurRadius: 18,
                    offset: const Offset(0, 8))
              ]
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GestureDetector(
            onTap: selected ? null : () => onSelectDay(day),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                gradient: selected
                    ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          crm.primary,
                          Color.lerp(crm.primary, Colors.black, 0.28)!,
                        ])
                    : null,
                color: selected ? null : crm.background,
              ),
              child: Column(
                children: [
                  Text(wd[day.weekday - 1],
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                          color:
                              selected ? Colors.white70 : crm.textSecondary)),
                  const SizedBox(height: 3),
                  Text('${day.day} ${mo[day.month - 1]}',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: selected ? Colors.white : crm.textPrimary)),
                  const SizedBox(height: 2),
                  Text(
                      '${entries.length} work${entries.length == 1 ? '' : 's'}',
                      style: TextStyle(
                          fontSize: 10.5,
                          color:
                              selected ? Colors.white70 : crm.textSecondary)),
                ],
              ),
            ),
          ),
          if (entries.isEmpty)
            Padding(
              padding:
                  const EdgeInsets.symmetric(vertical: 28, horizontal: 12),
              child: Center(
                  child: Text('No works',
                      style: TextStyle(
                          color: crm.textSecondary, fontSize: 12))),
            )
          else
            Builder(builder: (context) {
              // Collapse an artist's multiple works into ONE chip; unassigned
              // works stay individual. Groups keep their first-work time order.
              final groups = _groupEntriesForChips(entries);
              return Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  children: [
                    for (final g in groups)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: _workChip(context, ref, crm, g),
                      ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  // Group a day's entries into chips: assigned-artist works merge into one
  // chip; unassigned works each get their own. Input is already time-sorted.
  static List<_DayChipGroup> _groupEntriesForChips(
      List<BookingDisplayEntry> entries) {
    final groups = <_DayChipGroup>[];
    final byArtist = <String, _DayChipGroup>{};
    for (final e in entries) {
      final key = _artistKeyForEntry(e);
      if (key == null) {
        groups.add(_DayChipGroup(label: _artistLabelForEntry(e), entries: [e]));
      } else {
        final existing = byArtist[key];
        if (existing == null) {
          final g =
              _DayChipGroup(label: _artistLabelForEntry(e), entries: [e]);
          byArtist[key] = g;
          groups.add(g);
        } else {
          existing.entries.add(e);
        }
      }
    }
    return groups;
  }

  // Representative colour for a chip: the shared status if all works agree,
  // else slate (mixed). Completed shows green via _statusColor.
  static Color _groupColor(List<BookingDisplayEntry> entries) {
    final statuses =
        entries.map((e) => e.booking.status.toLowerCase()).toSet();
    if (statuses.length == 1) return _statusColor(statuses.first);
    return const Color(0xFF7C8E9A); // soft slate (mixed)
  }

  // One chip per artist (or per unassigned work). When the artist has several
  // works they merge into this single chip with a count; tap lists them in
  // order. A single work taps straight into its details.
  Widget _workChip(
      BuildContext context, WidgetRef ref, CrmTheme crm, _DayChipGroup group) {
    final entries = group.entries;
    final first = entries.first;
    final booking = first.booking;
    final label = group.label;
    final count = entries.length;
    final multi = count > 1;
    final bg = _groupColor(entries);

    String subFor(BookingDisplayEntry e) {
      final slot = e.eventSlot.trim();
      return [
        if (slot.isNotEmpty) slot,
        if (e.service.trim().isNotEmpty) e.service.trim(),
      ].join(' · ');
    }

    // Subtitle: single → slot·service; multiple → "N works" + distinct services.
    final String sub;
    if (multi) {
      final services = entries
          .map((e) => e.service.trim())
          .where((s) => s.isNotEmpty)
          .toSet()
          .join(', ');
      sub = services.isEmpty ? '$count works' : '$count works · $services';
    } else {
      sub = subFor(first);
    }

    void handleTap() =>
        _openWorkDialog(context, ref, crm, label, entries);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: handleTap,
        onLongPress: multi
            ? handleTap
            : () => context.push(
                '/booking/manage/${booking.id}?entry=${Uri.encodeComponent(first.id)}'),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration:
              BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 12.5)),
                  ),
                  if (multi) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.55),
                            width: 0.8),
                      ),
                      child: Text('×$count',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 10,
                              height: 1.1)),
                    ),
                  ],
                ],
              ),
              if (sub.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(sub,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70, fontSize: 10)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static String _fmtTime(DateTime d) {
    final h = d.hour == 0 ? 12 : (d.hour > 12 ? d.hour - 12 : d.hour);
    final m = d.minute.toString().padLeft(2, '0');
    return '$h:$m ${d.hour >= 12 ? 'PM' : 'AM'}';
  }

  static String _fmtFullDate(DateTime d) {
    const wd = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday',
      'Sunday'
    ];
    const mo = [
      'January', 'February', 'March', 'April', 'May', 'June', 'July',
      'August', 'September', 'October', 'November', 'December'
    ];
    return '${wd[d.weekday - 1]}, ${mo[d.month - 1]} ${d.day}, ${d.year}';
  }

  // One popup for a chip: shows every work of that artist (or the single work)
  // in order, each expandable and editable — no chained dialogs.
  void _openWorkDialog(BuildContext context, WidgetRef ref, CrmTheme crm,
      String title, List<BookingDisplayEntry> entries) {
    final ordered = [...entries]
      ..sort((a, b) => a.serviceStart.compareTo(b.serviceStart));
    showDialog<void>(
      context: context,
      builder: (_) =>
          _WorkDetailsDialog(crm: crm, title: title, entries: ordered),
    );
  }

  Widget _buildCompactPaymentInfo({
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final crmColors = context.crmColors;
    final isMobile = ResponsiveBuilder.isMobile(context);

    final session = ref.watch(authSessionProvider);
    final role = session != null
        ? AppRole.fromString(session.role)
        : AppRole.artist;
    final isArtist = role == AppRole.artist;
    final artistEmployeeId = session?.employeeId;

    // All bookings from provider
    final asyncBookings = ref.watch(bookingProvider);
    final allBookings = asyncBookings.value ?? [];
    final calendarBookings = allBookings
        .where((booking) => booking.status.toLowerCase() != 'rejected')
        .toList();
    final asyncEmployees = ref.watch(employeesProvider);
    final activeArtists = (asyncEmployees.value ?? const [])
        .where(
          (employee) =>
              employee.status.toLowerCase() == 'active' &&
              employee.artistRole.toLowerCase() == 'artist',
        )
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    final asyncBlockedDates = ref.watch(blockedDatesProvider);
    final blockedDates = asyncBlockedDates.value ?? [];

    final now = initialFocusDate ?? DateTime.now();
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
    final selectedArtistFilter = useState<String>(isArtist ? (artistEmployeeId ?? 'all') : 'all');

    // Geographic filters (zone → state → region → district).
    final zoneFilter = useState<String>('all');
    final stateFilter = useState<String>('all');
    final regionFilter = useState<String>('all');
    final districtFilter = useState<String>('all');
    final zones = ref.watch(zonesProvider).value ?? const [];
    final states = ref.watch(statesProvider).value ?? const [];
    final regions = ref.watch(regionsProvider).value ?? const [];
    final districts = ref.watch(districtsProvider).value ?? const [];
    // Resolve a booking's region/state/zone up the hierarchy.
    final districtToRegion = {for (final d in districts) d.id: d.regionId};
    final regionToState = {for (final r in regions) r.id: r.stateId};
    final stateToZone = {for (final s in states) s.id: s.zoneId};
    final activeGeoCount = [
      zoneFilter.value,
      stateFilter.value,
      regionFilter.value,
      districtFilter.value,
    ].where((v) => v != 'all').length;

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

    // Move the Day view to a specific date (used by month-cell taps and the
    // day-by-day arrows). Aligns the underlying week and selects the day.
    void goToDay(DateTime day) {
      final d = DateTime(day.year, day.month, day.day);
      weekStart.value = d.subtract(Duration(days: d.weekday - 1));
      selectedDayIndex.value = d.weekday - 1;
    }

    // Open the Day-view "inner page" for a clicked date (from the Month view).
    void openDayView(DateTime day) {
      goToDay(day);
      viewMode.value = 'Day';
    }

    void goToPreviousWeek() {
      if (viewMode.value == 'Month') {
        monthFocus.value = DateTime(
          monthFocus.value.year,
          monthFocus.value.month - 1,
          1,
        );
      } else if (viewMode.value == 'Day') {
        goToDay(weekDays[selectedDayIndex.value]
            .subtract(const Duration(days: 1)));
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
      } else if (viewMode.value == 'Day') {
        goToDay(
            weekDays[selectedDayIndex.value].add(const Duration(days: 1)));
      } else {
        weekStart.value = weekStart.value.add(const Duration(days: 7));
        selectedDayIndex.value = 0;
      }
    }

    final filteredCalendarBookings = calendarBookings.where((booking) {
      // Geographic filters. Resolve the booking's state/zone from its region.
      if (activeGeoCount > 0) {
        final bDistrictId = booking.districtId;
        // Prefer the booking's own regionId; fall back to its district's region.
        final bRegionId = booking.regionId.isNotEmpty
            ? booking.regionId
            : (districtToRegion[bDistrictId] ?? '');
        final bStateId = regionToState[bRegionId] ?? '';
        final bZoneId = stateToZone[bStateId] ?? '';
        if (zoneFilter.value != 'all' && bZoneId != zoneFilter.value) {
          return false;
        }
        if (stateFilter.value != 'all' && bStateId != stateFilter.value) {
          return false;
        }
        if (regionFilter.value != 'all' && bRegionId != regionFilter.value) {
          return false;
        }
        if (districtFilter.value != 'all' &&
            bDistrictId != districtFilter.value) {
          return false;
        }
      }

      final filter = selectedArtistFilter.value;
      if (filter == 'all') return true;
      if (filter == 'unassigned') {
        return !booking.assignedStaff.any(
          (assignment) => assignment.artistName.trim().isNotEmpty,
        );
      }
      return booking.assignedStaff.any(
        (assignment) =>
            (assignment.roleType.toLowerCase() == 'artist' ||
                assignment.roleType.toLowerCase() == 'lead') &&
            assignment.employeeId == filter,
      );
    }).toList();

    void openGeoFilters() => _openGeoFilters(
          context,
          crmColors,
          zones: zones,
          states: states,
          regions: regions,
          districts: districts,
          zoneFilter: zoneFilter,
          stateFilter: stateFilter,
          regionFilter: regionFilter,
          districtFilter: districtFilter,
        );

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
                  await ref
                      .read(blockedDateServiceProvider)
                      .saveBlockedDate(
                        date: pickedDate!,
                        reason: reasonCtrl.text.trim(),
                      );
                  ref.invalidate(blockedDatesProvider);
                  if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                } catch (error) {
                  if (dialogContext.mounted) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      SnackBar(
                        content: Text('Failed to save blocked date: $error'),
                      ),
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
                            separatorBuilder: (_, _) =>
                                const Divider(height: 1),
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
                                        ScaffoldMessenger.of(
                                          dialogContext,
                                        ).showSnackBar(
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


    Future<void> openMonthPicker() async {
      final pickedMonth = await showDialog<DateTime>(
        context: context,
        builder: (dialogContext) {
          var selectedYear = monthFocus.value.year;
          const monthLabels = [
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

          return StatefulBuilder(
            builder: (context, setState) {
              return Dialog(
                insetPadding: const EdgeInsets.all(20),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Jump To Month',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        16.h,
                        Row(
                          children: [
                            IconButton(
                              onPressed: () =>
                                  setState(() => selectedYear -= 1),
                              icon: const Icon(Icons.chevron_left),
                            ),
                            Expanded(
                              child: Center(
                                child: Text(
                                  '$selectedYear',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () =>
                                  setState(() => selectedYear += 1),
                              icon: const Icon(Icons.chevron_right),
                            ),
                          ],
                        ),
                        16.h,
                        GridView.builder(
                          shrinkWrap: true,
                          itemCount: monthLabels.length,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 2.2,
                          ),
                          itemBuilder: (context, index) {
                            final monthNumber = index + 1;
                            final isActive =
                                selectedYear == monthFocus.value.year &&
                                monthNumber == monthFocus.value.month;
                            return InkWell(
                              onTap: () => Navigator.of(dialogContext).pop(
                                DateTime(selectedYear, monthNumber, 1),
                              ),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: isActive
                                      ? crmColors.primary
                                      : crmColors.surface,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: crmColors.border),
                                ),
                                child: Text(
                                  monthLabels[index],
                                  style: TextStyle(
                                    color: isActive
                                        ? Colors.white
                                        : crmColors.textPrimary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      );

      if (pickedMonth != null) {
        monthFocus.value = pickedMonth;
      }
    }

    return PopScope(
      // In the Day "inner page", back returns to the Month view instead of
      // leaving the calendar screen.
      canPop: viewMode.value != 'Day',
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && viewMode.value == 'Day') {
          viewMode.value = 'Month';
        }
      },
      child: Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: (isMobile && !isArtist)
          ? FloatingActionButton(
              onPressed: () => showAddBookingModeChooser(context),
              backgroundColor: crmColors.primary,
              foregroundColor: Colors.white,
              child: const Icon(Icons.add),
            )
          : null,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Page header ──────────────────────────────────────────────────
          if (!isMobile) ...[
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
                if (!isArtist) ...[
                  OutlinedButton.icon(
                    onPressed: manageBlockedDates,
                    icon: const Icon(Icons.calendar_month_outlined, size: 18),
                    label: const Text('Blocked Dates'),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: crmColors.surface,
                    ),
                  ),
                  16.w,
                  ElevatedButton.icon(
                    onPressed: () => showAddBookingModeChooser(context),
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
            24.h,
          ] else if (!isArtist) ...[
            Row(
              children: [
                const Spacer(),
                IconButton(
                  onPressed: manageBlockedDates,
                  icon: Icon(Icons.calendar_today_outlined, color: crmColors.textPrimary),
                  tooltip: 'Blocked Dates',
                  style: IconButton.styleFrom(
                    backgroundColor: crmColors.surface,
                    side: BorderSide(color: crmColors.border),
                  ),
                ),
              ],
            ),
            12.h,
          ],
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
                    child: isMobile
                        ? Column(
                            children: [
                              Row(
                                children: [
                                  IconButton(
                                    onPressed: goToPreviousWeek,
                                    icon: const Icon(Icons.chevron_left),
                                  ),
                                  Expanded(
                                    child: Center(
                                      child: InkWell(
                                        onTap: viewMode.value == 'Month' ? openMonthPicker : null,
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              viewMode.value == 'Month'
                                                  ? monthTitle(monthFocus.value)
                                                  : weekRangeTitle(),
                                              style: theme.textTheme.titleMedium?.copyWith(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            if (viewMode.value == 'Month') ...[
                                              4.w,
                                              const Icon(Icons.arrow_drop_down, size: 18),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: goToNextWeek,
                                    icon: const Icon(Icons.chevron_right),
                                  ),
                                  OutlinedButton(
                                    onPressed: goToToday,
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    ),
                                    child: const Text('Today'),
                                  ),
                                ],
                              ),
                              12.h,
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildArtistFilter(
                                      context,
                                      crmColors,
                                      activeArtists,
                                      selectedArtistFilter,
                                      isArtist,
                                    ),
                                  ),
                                  if (!isArtist) ...[
                                    8.w,
                                    _geoFilterButton(
                                      context,
                                      crmColors,
                                      activeCount: activeGeoCount,
                                      compact: true,
                                      onTap: openGeoFilters,
                                    ),
                                  ],
                                  12.w,
                                  SegmentedButton<String>(
                                    segments: const [
                                      ButtonSegment(value: 'Day', label: Text('Day')),
                                      ButtonSegment(value: 'Week', label: Text('Week')),
                                      ButtonSegment(value: 'Month', label: Text('Month')),
                                    ],
                                    selected: {viewMode.value},
                                    onSelectionChanged: (selection) {
                                      viewMode.value = selection.first;
                                    },
                                    showSelectedIcon: false,
                                    style: SegmentedButton.styleFrom(
                                      backgroundColor: crmColors.input,
                                      selectedBackgroundColor: crmColors.surface,
                                      selectedForegroundColor: crmColors.textPrimary,
                                      visualDensity: VisualDensity.compact,
                                      padding: const EdgeInsets.symmetric(horizontal: 8),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          )
                        : Wrap(
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
                                  if (viewMode.value == 'Month')
                                    OutlinedButton.icon(
                                      onPressed: openMonthPicker,
                                      icon: const Icon(Icons.calendar_month_outlined),
                                      label: Text(monthTitle(monthFocus.value)),
                                    )
                                  else
                                    Text(
                                      weekRangeTitle(),
                                      style: theme.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                ],
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _buildArtistFilter(
                                    context,
                                    crmColors,
                                    activeArtists,
                                    selectedArtistFilter,
                                    isArtist,
                                  ),
                                  if (!isArtist) ...[
                                    12.w,
                                    _geoFilterButton(
                                      context,
                                      crmColors,
                                      activeCount: activeGeoCount,
                                      compact: false,
                                      onTap: openGeoFilters,
                                    ),
                                  ],
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
                                      viewMode.value = selection.first;
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
                              filteredCalendarBookings,
                              monthFocus.value,
                              now,
                              onOpenDay: (day, _) async => openDayView(day),
                            )
                          : viewMode.value == 'Day'
                          ? (isMobile
                              ? Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    _buildWeeklyStrip(
                                      context,
                                      crmColors,
                                      weekDays,
                                      selectedDayIndex.value,
                                      selectedDayIndex,
                                      filteredCalendarBookings,
                                    ),
                                    _dayWorksColumn(
                                      context,
                                      ref,
                                      crmColors,
                                      filteredCalendarBookings,
                                      selectedDay,
                                      selected: true,
                                      onSelectDay: goToDay,
                                    ),
                                  ],
                                )
                              : _threeDayView(
                                  context,
                                  ref,
                                  crmColors,
                                  filteredCalendarBookings,
                                  selectedDay,
                                  goToDay,
                                ))
                          : !isMobile
                          ? _weekView(
                              context,
                              crmColors,
                              filteredCalendarBookings,
                              weekDays,
                              now,
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildWeeklyStrip(
                                  context,
                                  crmColors,
                                  weekDays,
                                  selectedDayIndex.value,
                                  selectedDayIndex,
                                  filteredCalendarBookings,
                                ),
                                _mobileDay(
                                  context,
                                  crmColors,
                                  isArtist,
                                  [
                                    ...filteredCalendarBookings.where(
                                      (b) => b.isOnDate(selectedDay),
                                    ),
                                  ]..sort(
                                      (a, b) =>
                                          a.serviceStart.compareTo(b.serviceStart),
                                    ),
                                  selectedDay,
                                ),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }

  // ── Mobile: show bookings for selected day as a list ─────────────────────
  Widget _mobileDay(
    BuildContext context,
    CrmTheme crmColors,
    bool isArtist,
    List<Booking> bookings,
    DateTime day,
  ) {
    final entries = _entriesForDay(bookings, day);

    if (entries.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 64, horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.event_available, size: 48, color: crmColors.border),
              16.h,
              Text(
                'No bookings for this day',
                style: TextStyle(color: crmColors.textSecondary, fontSize: 14),
              ),
              if (!isArtist) ...[
                12.h,
                ElevatedButton.icon(
                  onPressed: () => showAddBookingModeChooser(context),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('New Booking'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: crmColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: entries.length,
      separatorBuilder: (context, index) => 12.h,
      itemBuilder: (ctx, i) {
        final entry = entries[i];
        final b = entry.booking;
        final isAssigned = entry.assignedStaff
            .cast<BookingAssignment?>()
            .any((assignment) =>
                assignment != null && assignment.artistName.trim().isNotEmpty);
        final serviceColor = _colorForService(entry.service);
        final borderColor = isAssigned
            ? serviceColor
            : Color.lerp(serviceColor, Colors.white, 0.55)!;
        // Show THIS entry's amounts (per package/day), not the whole booking's,
        // so every day of a multi-day / multi-package booking reads correctly.
        // Discount is spread evenly across the booking's entries.
        final entryCount = b.displayEntries.isEmpty ? 1 : b.displayEntries.length;
        final entryTotal = entry.totalPrice;
        final entryAdvance = entry.advanceAmount;
        final balance = entryTotal - entryAdvance - (b.discountAmount / entryCount);

        return GestureDetector(
          onTap: () => context.push(
            '/booking/manage/${b.id}?entry=${Uri.encodeComponent(entry.id)}',
          ),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: crmColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: crmColors.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 4,
                      height: 40,
                      decoration: BoxDecoration(
                        color: borderColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    12.w,
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.summaryLabel,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          4.h,
                          Text(
                            '${_fmt(entry.serviceStart)} – ${_fmt(entry.serviceEnd)}',
                            style: TextStyle(
                              color: crmColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                          if (isAssigned) ...[
                            4.h,
                            Row(
                              children: [
                                Icon(
                                  Icons.person_outline,
                                  size: 14,
                                  color: crmColors.primary,
                                ),
                                4.w,
                                Text(
                                  _artistLabelForEntry(entry),
                                  style: TextStyle(
                                    color: crmColors.primary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: borderColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        entry.service.toUpperCase(),
                        style: TextStyle(
                          color: borderColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                16.h,
                const Divider(height: 1),
                12.h,
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildCompactPaymentInfo(
                      label: 'Total',
                      value: '₹${entryTotal.toStringAsFixed(0)}',
                      color: crmColors.textPrimary,
                    ),
                    _buildCompactPaymentInfo(
                      label: 'Advance',
                      value: '₹${entryAdvance.toStringAsFixed(0)}',
                      color: crmColors.success,
                    ),
                    _buildCompactPaymentInfo(
                      label: 'Balance',
                      value: '₹${balance.toStringAsFixed(0)}',
                      color: balance > 0 ? crmColors.destructive : crmColors.success,
                    ),
                  ],
                ),
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
    {
    required Future<void> Function(
      DateTime day,
      List<BookingDisplayEntry> entries,
    )
    onOpenDay,
  }
  ) {
    final days = _buildMonthCells(month);
    const weekdayLabels = ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'];
    final isMobile = ResponsiveBuilder.isMobile(context);

    return Padding(
      padding: EdgeInsets.all(isMobile ? 8 : 16),
      child: Container(
        decoration: BoxDecoration(
          color: crmColors.surface,
          borderRadius: BorderRadius.circular(isMobile ? 16 : 28),
          border: Border.all(color: crmColors.border),
        ),
        child: Column(
          children: [
            Row(
              children: weekdayLabels
                  .map(
                    (label) => Expanded(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          vertical: isMobile ? 10 : 18,
                        ),
                        child: Text(
                          label,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: crmColors.textSecondary,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                            fontSize: isMobile ? 12 : 14,
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const Divider(height: 1),
            LayoutBuilder(
              builder: (context, constraints) {
                final monthWidth = constraints.maxWidth;
                final maxVisibleGroups = monthWidth < 900
                    ? 1
                    : monthWidth < 1200
                    ? 2
                    : 3;
                final childAspectRatio = isMobile
                    ? 0.8
                    : monthWidth < 900
                    ? 0.9
                    : monthWidth < 1200
                    ? 0.98
                    : 1.08;

                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: days.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    childAspectRatio: childAspectRatio,
                  ),
                  itemBuilder: (context, index) {
                    final day = days[index];
                    final isCurrentMonth = day.month == month.month;
                    final isToday =
                        day.year == now.year &&
                        day.month == now.month &&
                        day.day == now.day;
                    final dayBookings = isCurrentMonth
                        ? _entriesForDay(bookings, day)
                        : <BookingDisplayEntry>[];
                    final artistGroups = _groupBookingsByArtist(dayBookings);

                    return Container(
                      padding: EdgeInsets.all(isMobile ? 2 : 4),
                      decoration: BoxDecoration(
                        border: Border(
                          right: BorderSide(color: crmColors.border),
                          bottom: BorderSide(color: crmColors.border),
                        ),
                        color: isCurrentMonth
                            ? crmColors.surface
                            : crmColors.background.withValues(alpha: 0.5),
                      ),
                      child: !isCurrentMonth
                          ? const SizedBox.shrink()
                          : Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: dayBookings.isEmpty
                                    ? null
                                    : () => onOpenDay(day, dayBookings),
                                borderRadius: BorderRadius.circular(isMobile ? 8 : 12),
                                child: Padding(
                                  padding: const EdgeInsets.all(2),
                                  child: Column(
                                    crossAxisAlignment: isMobile
                                        ? CrossAxisAlignment.center
                                        : CrossAxisAlignment.start,
                                    children: [
                                      Align(
                                        alignment: Alignment.topCenter,
                                        child: Container(
                                          width: isMobile ? 28 : 38,
                                          height: isMobile ? 28 : 38,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: isToday
                                                ? crmColors.primary
                                                : Colors.transparent,
                                          ),
                                          alignment: Alignment.center,
                                          child: Text(
                                            '${day.day}',
                                            style: TextStyle(
                                              fontSize: isMobile ? 13 : 16,
                                              fontWeight: FontWeight.w700,
                                              color: isToday
                                                  ? Colors.white
                                                  : crmColors.textPrimary,
                                            ),
                                          ),
                                        ),
                                      ),
                                      if (isMobile) ...[
                                        if (dayBookings.isNotEmpty) ...[
                                          4.h,
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: dayBookings
                                                .take(3)
                                                .map((entry) {
                                              final color =
                                                  _colorForService(entry.service);
                                              return Container(
                                                width: 5,
                                                height: 5,
                                                margin: const EdgeInsets.symmetric(
                                                  horizontal: 1,
                                                ),
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color: color,
                                                ),
                                              );
                                            }).toList(),
                                          ),
                                        ],
                                      ] else ...[
                                        6.h,
                                        ...artistGroups
                                            .take(maxVisibleGroups)
                                            .map(
                                              (group) => Padding(
                                                padding:
                                                    const EdgeInsets.only(
                                                  bottom: 4,
                                                ),
                                                child: _buildMonthBookingPill(
                                                  context,
                                                  group,
                                                ),
                                              ),
                                            ),
                                        if (artistGroups.length >
                                            maxVisibleGroups)
                                          Container(
                                            width: double.infinity,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 5,
                                            ),
                                            decoration: BoxDecoration(
                                              color: crmColors.secondary
                                                  .withValues(alpha: 0.35),
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                            ),
                                            child: Text(
                                              'View all (${artistGroups.length})',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color:
                                                    crmColors.textSecondary,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklyStrip(
    BuildContext context,
    CrmTheme crmColors,
    List<DateTime> weekDays,
    int selectedIndex,
    ValueNotifier<int> selectedDayIndex,
    List<Booking> bookings,
  ) {
    const dayNames = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: crmColors.surface,
        border: Border(
          bottom: BorderSide(color: crmColors.border),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(7, (index) {
          final day = weekDays[index];
          final isSelected = index == selectedIndex;
          final isToday = DateTime.now().year == day.year &&
              DateTime.now().month == day.month &&
              DateTime.now().day == day.day;
          
          final dayName = dayNames[day.weekday % 7];
          final dayBookings = _entriesForDay(bookings, day);

          return InkWell(
            onTap: () {
              selectedDayIndex.value = index;
            },
            borderRadius: BorderRadius.circular(16),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 44,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? crmColors.primary
                    : isToday
                        ? crmColors.primary.withValues(alpha: 0.1)
                        : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                border: isToday && !isSelected
                    ? Border.all(color: crmColors.primary.withValues(alpha: 0.3))
                    : null,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    dayName,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? Colors.white70
                          : isToday
                              ? crmColors.primary
                              : crmColors.textSecondary,
                    ),
                  ),
                  4.h,
                  Text(
                    '${day.day}',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? Colors.white
                          : crmColors.textPrimary,
                    ),
                  ),
                  if (dayBookings.isNotEmpty) ...[
                    4.h,
                    Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected ? Colors.white : crmColors.primary,
                      ),
                    ),
                  ] else ...[
                    4.h,
                    const SizedBox(width: 4, height: 4),
                  ],
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildArtistFilter(
    BuildContext context,
    CrmTheme crmColors,
    List<Employee> activeArtists,
    ValueNotifier<String> selectedArtistFilter,
    bool isArtist,
  ) {
    if (isArtist) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: crmColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: crmColors.primary.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_pin_outlined, size: 18, color: crmColors.primary),
            8.w,
            Text(
              'My Works',
              style: TextStyle(
                color: crmColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }
    return PopupMenuButton<String>(
      tooltip: 'Filter by artist',
      onSelected: (value) => selectedArtistFilter.value = value,
      itemBuilder: (context) => [
        const PopupMenuItem<String>(
          value: 'all',
          child: Text('All Staff'),
        ),
        const PopupMenuItem<String>(
          value: 'unassigned',
          child: Text('Not Assigned'),
        ),
        ...activeArtists.map(
          (artist) => PopupMenuItem<String>(
            value: artist.id,
            child: Text(artist.name),
          ),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: crmColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: crmColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.filter_list, size: 18),
            8.w,
            Flexible(
              child: Text(
                _filterLabelForValue(selectedArtistFilter.value, activeArtists),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: crmColors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            4.w,
            Icon(
              Icons.keyboard_arrow_down,
              size: 18,
              color: crmColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  String _filterLabelForValue(String value, List<Employee> activeArtists) {
    if (value == 'all') return 'All Staff';
    if (value == 'unassigned') return 'Not Assigned';
    for (final artist in activeArtists) {
      if (artist.id == value) return artist.name;
    }
    return 'All Staff';
  }

  // Location-filter trigger button (icon + count badge). Opens the geo sheet.
  Widget _geoFilterButton(
    BuildContext context,
    CrmTheme crm, {
    required int activeCount,
    required bool compact,
    required VoidCallback onTap,
  }) {
    final active = activeCount > 0;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: EdgeInsets.symmetric(
              horizontal: compact ? 12 : 14, vertical: 10),
          decoration: BoxDecoration(
            color: active ? crm.primary.withValues(alpha: 0.10) : crm.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: active
                    ? crm.primary.withValues(alpha: 0.5)
                    : crm.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.public,
                  size: 18, color: active ? crm.primary : crm.textPrimary),
              if (!compact) ...[
                8.w,
                Text('Location',
                    style: TextStyle(
                        color: active ? crm.primary : crm.textPrimary,
                        fontWeight: FontWeight.w500)),
              ],
              if (active) ...[
                6.w,
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                      color: crm.primary,
                      borderRadius: BorderRadius.circular(10)),
                  child: Text('$activeCount',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // Cascading Zone → State → Region → District filter sheet. Selections write
  // straight to the notifiers so the calendar updates live.
  void _openGeoFilters(
    BuildContext context,
    CrmTheme crm, {
    required List<ZoneModel> zones,
    required List<GeographicState> states,
    required List<ServiceRegion> regions,
    required List<District> districts,
    required ValueNotifier<String> zoneFilter,
    required ValueNotifier<String> stateFilter,
    required ValueNotifier<String> regionFilter,
    required ValueNotifier<String> districtFilter,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: crm.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (sheetCtx, setSheet) {
            // Child options depend on the selected parent (cascading).
            final visibleStates = zoneFilter.value == 'all'
                ? states
                : states.where((s) => s.zoneId == zoneFilter.value).toList();
            final visibleRegions = stateFilter.value != 'all'
                ? regions
                    .where((r) => r.stateId == stateFilter.value)
                    .toList()
                : (zoneFilter.value == 'all'
                    ? regions
                    : regions
                        .where((r) =>
                            visibleStates.any((s) => s.id == r.stateId))
                        .toList());
            final visibleDistricts = regionFilter.value != 'all'
                ? districts
                    .where((d) => d.regionId == regionFilter.value)
                    .toList()
                : ((stateFilter.value == 'all' && zoneFilter.value == 'all')
                    ? districts
                    : districts
                        .where((d) =>
                            visibleRegions.any((r) => r.id == d.regionId))
                        .toList());

            Widget dd(String label, String value, List<(String, String)> opts,
                ValueChanged<String> onChanged) {
              final ids = {'all', ...opts.map((o) => o.$1)};
              final v = ids.contains(value) ? value : 'all';
              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: DropdownButtonFormField<String>(
                  initialValue: v,
                  isExpanded: true,
                  decoration: InputDecoration(
                      labelText: label,
                      isDense: true,
                      border: const OutlineInputBorder()),
                  items: [
                    DropdownMenuItem(value: 'all', child: Text('All ${label}s')),
                    for (final o in opts)
                      DropdownMenuItem(value: o.$1, child: Text(o.$2)),
                  ],
                  onChanged: (val) => onChanged(val ?? 'all'),
                ),
              );
            }

            return Padding(
              padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 16,
                  bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.public, color: crm.primary),
                      8.w,
                      Text('Filter by location',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: crm.textPrimary)),
                      const Spacer(),
                      TextButton(
                        onPressed: () {
                          zoneFilter.value = 'all';
                          stateFilter.value = 'all';
                          regionFilter.value = 'all';
                          districtFilter.value = 'all';
                          setSheet(() {});
                        },
                        child: const Text('Clear all'),
                      ),
                    ],
                  ),
                  12.h,
                  dd('Zone', zoneFilter.value,
                      [for (final z in zones) (z.id, z.name)], (v) {
                    zoneFilter.value = v;
                    stateFilter.value = 'all';
                    regionFilter.value = 'all';
                    districtFilter.value = 'all';
                    setSheet(() {});
                  }),
                  dd('State', stateFilter.value,
                      [for (final s in visibleStates) (s.id, s.name)], (v) {
                    stateFilter.value = v;
                    regionFilter.value = 'all';
                    districtFilter.value = 'all';
                    setSheet(() {});
                  }),
                  dd('Region', regionFilter.value,
                      [for (final r in visibleRegions) (r.id, r.name)], (v) {
                    regionFilter.value = v;
                    districtFilter.value = 'all';
                    setSheet(() {});
                  }),
                  dd('District', districtFilter.value,
                      [for (final d in visibleDistricts) (d.id, d.name)], (v) {
                    districtFilter.value = v;
                    setSheet(() {});
                  }),
                  4.h,
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(sheetCtx),
                      child: const Text('Done'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
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
                    child: _buildTopDayHeader(context, day: day, now: now),
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
                                  color: crmColors.border.withValues(
                                    alpha: 0.7,
                                  ),
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
                    final dayBookings = _entriesForDay(bookings, day);
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
                            // Only two pills fit in topLaneHeight; a third
                            // overflowed by 25px. Show the rest as a count,
                            // and clip as a belt-and-braces guard.
                            child: ClipRect(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ...artistGroups
                                      .take(2)
                                      .map(
                                        (group) => Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 6,
                                          ),
                                          child: _buildReferencePill(
                                            context,
                                            group,
                                            compact: true,
                                          ),
                                        ),
                                      ),
                                  if (artistGroups.length > 2)
                                    Text(
                                      '+${artistGroups.length - 2} more',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: crmColors.textSecondary,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          ...timelineHours.map(
                            (_) => Container(
                              height: hourRowHeight,
                              decoration: BoxDecoration(
                                border: Border(
                                  right: BorderSide(color: crmColors.border),
                                  bottom: BorderSide(
                                    color: crmColors.border.withValues(
                                      alpha: 0.7,
                                    ),
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

  Widget _buildMonthBookingPill(BuildContext context, _ArtistDayGroup group) {
    return _buildReferencePill(context, group, compact: true);
  }

  Widget _buildReferencePill(
    BuildContext context,
    _ArtistDayGroup group, {
    bool compact = false,
  }) {
    final bookingEntry = group.bookings.first;
    final booking = bookingEntry.booking;
    
    final isCancelled = booking.status.toLowerCase() == 'cancelled';
    final isPostponed = booking.status.toLowerCase() == 'postponed';
    final isCompleted = booking.status.toLowerCase() == 'completed';

    Color pillBg;
    Color pillTextColor;

    if (isCancelled) {
      pillBg = const Color(0xFFEF4444); // Red
      pillTextColor = Colors.white;
    } else if (isPostponed) {
      pillBg = const Color(0xFFEAB308); // Yellow
      pillTextColor = Colors.white;
    } else if (isCompleted) {
      pillBg = const Color(0xFF22C55E); // Green
      pillTextColor = Colors.white;
    } else {
      final isAssigned = bookingEntry.assignedStaff
          .cast<BookingAssignment?>()
          .any((assignment) => assignment != null && assignment.artistName.trim().isNotEmpty);

      final serviceColor = _colorForService(bookingEntry.service);
      pillBg = isAssigned 
          ? serviceColor 
          : Color.lerp(serviceColor, Colors.white, 0.82)!;

      pillTextColor = isAssigned
          ? Colors.white
          : serviceColor;
    }

    final detailLabel = bookingEntry.eventSlot.trim().isNotEmpty
        ? bookingEntry.eventSlot.trim()
        : bookingEntry.service.trim();
    final label = group.hasAssignedArtistGroup && group.count > 1
        ? '${group.artistLabel.toUpperCase()} (${group.count})'
        : (detailLabel.isEmpty
              ? group.artistLabel.toUpperCase()
              : '${group.artistLabel.toUpperCase()} • ${detailLabel.toUpperCase()}');

    return InkWell(
      onTap: () => context.push(
        '/booking/manage/${booking.id}?entry=${Uri.encodeComponent(bookingEntry.id)}',
      ),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 10,
          vertical: compact ? 5 : 6,
        ),
        decoration: BoxDecoration(
          color: pillBg,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: pillTextColor,
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
        border: Border(right: BorderSide(color: crmColors.border)),
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
    final gridStart = monthStart.subtract(
      Duration(days: monthStart.weekday % 7),
    );
    return List.generate(
      42,
      (index) =>
          DateTime(gridStart.year, gridStart.month, gridStart.day + index),
    );
  }
}

class _ArtistDayGroup {
  final String artistLabel;
  final bool hasAssignedArtistGroup;
  final List<BookingDisplayEntry> bookings;

  const _ArtistDayGroup({
    required this.artistLabel,
    required this.hasAssignedArtistGroup,
    required this.bookings,
  });

  int get count => bookings.length;
}

// One chip in a day column: an assigned artist (possibly several works merged)
// or a single unassigned work. Works are kept in time order.
class _DayChipGroup {
  _DayChipGroup({required this.label, required this.entries});
  final String label;
  final List<BookingDisplayEntry> entries;
}

// One detail line inside the work popup.
Widget _workDetailRow(CrmTheme crm, IconData icon, String label, String value) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 17, color: crm.primary),
        10.w,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label.toUpperCase(),
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                      color: crm.textSecondary)),
              2.h,
              Text(value,
                  style: TextStyle(
                      fontSize: 13.5, color: crm.textPrimary, height: 1.3)),
            ],
          ),
        ),
      ],
    ),
  );
}

// Per-work editable state held by the popup (controllers + view/edit flags).
class _WorkForm {
  _WorkForm(this.entry)
      : status = entry.booking.status,
        customer = TextEditingController(text: entry.booking.customerName),
        phone = TextEditingController(text: entry.booking.phone),
        phone2 = TextEditingController(text: entry.booking.secondaryContact),
        email = TextEditingController(text: entry.booking.email),
        service = TextEditingController(text: entry.booking.service),
        eventSlot = TextEditingController(text: entry.booking.eventSlot),
        address = TextEditingController(text: entry.booking.address),
        mapUrl = TextEditingController(text: entry.booking.mapUrl),
        outfit = TextEditingController(text: entry.booking.outfitDetails),
        room = TextEditingController(text: entry.booking.requiredRoomDetail),
        travelMode = TextEditingController(text: entry.booking.travelMode),
        travelTime = TextEditingController(text: entry.booking.travelTime),
        driverName = TextEditingController(text: entry.booking.driverName),
        pocName = TextEditingController(text: entry.booking.pocName),
        pocPhone = TextEditingController(text: entry.booking.pocPhone),
        capture =
            TextEditingController(text: entry.booking.captureStaffDetails),
        tempStaff =
            TextEditingController(text: entry.booking.temporaryStaffDetails),
        staffInstructions =
            TextEditingController(text: entry.booking.staffInstructions),
        remarks = TextEditingController(text: entry.booking.internalRemarks);

  final BookingDisplayEntry entry;
  String status;
  bool editing = false;
  bool saving = false;
  bool expanded = false;

  final TextEditingController customer;
  final TextEditingController phone;
  final TextEditingController phone2;
  final TextEditingController email;
  final TextEditingController service;
  final TextEditingController eventSlot;
  final TextEditingController address;
  final TextEditingController mapUrl;
  final TextEditingController outfit;
  final TextEditingController room;
  final TextEditingController travelMode;
  final TextEditingController travelTime;
  final TextEditingController driverName;
  final TextEditingController pocName;
  final TextEditingController pocPhone;
  final TextEditingController capture;
  final TextEditingController tempStaff;
  final TextEditingController staffInstructions;
  final TextEditingController remarks;

  void dispose() {
    for (final c in [
      customer, phone, phone2, email, service, eventSlot, address, mapUrl,
      outfit, room, travelMode, travelTime, driverName, pocName, pocPhone,
      capture, tempStaff, staffInstructions, remarks
    ]) {
      c.dispose();
    }
  }
}

// The single popup that shows all of an artist's works (or one work) in order,
// each expandable + editable. Saving persists via updateBooking.
class _WorkDetailsDialog extends ConsumerStatefulWidget {
  const _WorkDetailsDialog({
    required this.crm,
    required this.title,
    required this.entries,
  });

  final CrmTheme crm;
  final String title;
  final List<BookingDisplayEntry> entries;

  @override
  ConsumerState<_WorkDetailsDialog> createState() =>
      _WorkDetailsDialogState();
}

class _WorkDetailsDialogState extends ConsumerState<_WorkDetailsDialog> {
  late final List<_WorkForm> forms;
  bool get single => forms.length == 1;
  bool _pdfBusy = false;

  static const _statuses = [
    'pending', 'confirmed', 'completed', 'cancelled', 'postponed'
  ];

  @override
  void initState() {
    super.initState();
    forms = widget.entries.map(_WorkForm.new).toList();
    if (forms.isNotEmpty) forms.first.expanded = true;
  }

  // Download the artist's full work sheet for the day as a PDF (reuses the
  // existing artist print variant). Optional [only] limits it to one work.
  Future<void> _downloadPdf({BookingDisplayEntry? only}) async {
    final entries = only != null ? [only] : widget.entries;
    if (entries.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    final bookingsById = <String, Booking>{};
    for (final e in entries) {
      bookingsById[e.booking.id] = e.booking;
    }
    setState(() => _pdfBusy = true);
    try {
      await printBookingDetails(
        entries.first.booking,
        variant: BookingPrintVariant.artist,
        relatedArtistBookings: bookingsById.values.toList(),
        relatedArtistEntries: entries,
        selectedArtistEntry: entries.first,
        artistName: widget.title,
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('PDF error: $e')));
    } finally {
      if (mounted) setState(() => _pdfBusy = false);
    }
  }

  @override
  void dispose() {
    for (final f in forms) {
      f.dispose();
    }
    super.dispose();
  }

  Future<void> _save(_WorkForm f) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => f.saving = true);
    try {
      await ref.read(bookingProvider.notifier).updateBooking(
            f.entry.booking.copyWith(
              status: f.status,
              customerName: f.customer.text.trim(),
              phone: f.phone.text.trim(),
              secondaryContact: f.phone2.text.trim(),
              email: f.email.text.trim(),
              service: f.service.text.trim(),
              eventSlot: f.eventSlot.text.trim(),
              address: f.address.text.trim(),
              mapUrl: f.mapUrl.text.trim(),
              outfitDetails: f.outfit.text.trim(),
              requiredRoomDetail: f.room.text.trim(),
              travelMode: f.travelMode.text.trim(),
              travelTime: f.travelTime.text.trim(),
              driverName: f.driverName.text.trim(),
              pocName: f.pocName.text.trim(),
              pocPhone: f.pocPhone.text.trim(),
              captureStaffDetails: f.capture.text.trim(),
              temporaryStaffDetails: f.tempStaff.text.trim(),
              staffInstructions: f.staffInstructions.text.trim(),
              internalRemarks: f.remarks.text.trim(),
            ),
          );
      ref.invalidate(bookingProvider);
      if (!mounted) return;
      setState(() {
        f.saving = false;
        f.editing = false;
      });
      messenger
          .showSnackBar(const SnackBar(content: Text('Booking updated')));
    } catch (e) {
      if (!mounted) return;
      setState(() => f.saving = false);
      messenger.showSnackBar(SnackBar(content: Text('Update failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final crm = widget.crm;
    final head = single
        ? CalendarScreen._statusColor(forms.first.entry.booking.status)
        : crm.primary;
    final headerTitle = single ? forms.first.entry.summaryLabel : widget.title;
    final headerSub = single
        ? CalendarScreen._fmtFullDate(forms.first.entry.serviceStart)
        : '${forms.length} works · ${CalendarScreen._fmtFullDate(forms.first.entry.serviceStart)}';

    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 660),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 16),
              decoration: BoxDecoration(
                color: head,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: InkWell(
                      // Tap the artist name to download their full work sheet.
                      onTap: _pdfBusy ? null : () => _downloadPdf(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(headerTitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800)),
                              ),
                              6.w,
                              const Icon(Icons.picture_as_pdf,
                                  size: 15, color: Colors.white70),
                            ],
                          ),
                          4.h,
                          Text(headerSub,
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 12.5)),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Download PDF',
                    icon: _pdfBusy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.download_rounded,
                            color: Colors.white),
                    onPressed: _pdfBusy ? null : () => _downloadPdf(),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Flexible(
              child: single
                  ? SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
                      child: _formBody(forms.first),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.all(12),
                      itemCount: forms.length,
                      separatorBuilder: (_, _) => 10.h,
                      itemBuilder: (context, i) => _workCard(i, forms[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // Collapsed/expanded card for one work in the multi-work list.
  Widget _workCard(int index, _WorkForm f) {
    final crm = widget.crm;
    final e = f.entry;
    final c = CalendarScreen._statusColor(e.booking.status);
    final slot = e.eventSlot.trim();
    final sub = [
      '${CalendarScreen._fmtTime(e.serviceStart)} – ${CalendarScreen._fmtTime(e.serviceEnd)}',
      if (slot.isNotEmpty) slot,
      if (e.service.trim().isNotEmpty) e.service.trim(),
    ].join('  ·  ');

    return Container(
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: crm.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => f.expanded = !f.expanded),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: c.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                      border: Border.all(color: c, width: 1.3),
                    ),
                    child: Text('${index + 1}',
                        style: TextStyle(
                            color: c,
                            fontWeight: FontWeight.w800,
                            fontSize: 12.5)),
                  ),
                  10.w,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(e.summaryLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13.5,
                                color: crm.textPrimary)),
                        2.h,
                        Text(sub,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 11, color: crm.textSecondary)),
                      ],
                    ),
                  ),
                  6.w,
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: c.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                        e.booking.status.isEmpty
                            ? 'pending'
                            : e.booking.status,
                        style: TextStyle(
                            color: c,
                            fontSize: 10,
                            fontWeight: FontWeight.w700)),
                  ),
                  Icon(f.expanded ? Icons.expand_less : Icons.expand_more,
                      color: crm.textSecondary),
                ],
              ),
            ),
          ),
          if (f.expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 2, 14, 12),
              child: _formBody(f),
            ),
        ],
      ),
    );
  }

  // The view/edit content + action buttons for one work.
  Widget _formBody(_WorkForm f) {
    final crm = widget.crm;
    final b = f.entry.booking;
    String dot(String a, String c) =>
        [a, c].where((e) => e.trim().isNotEmpty).join(' · ');

    if (f.editing) {
      Widget editField(String label, TextEditingController c,
              {int maxLines = 1, TextInputType? keyboard}) =>
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: TextField(
              controller: c,
              maxLines: maxLines,
              keyboardType: keyboard,
              decoration: InputDecoration(
                  labelText: label,
                  isDense: true,
                  border: const OutlineInputBorder()),
            ),
          );
      Widget section(String t) => Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 8),
            child: Text(t.toUpperCase(),
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: crm.primary)),
          );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _statuses.contains(f.status.toLowerCase())
                ? f.status.toLowerCase()
                : 'pending',
            decoration: const InputDecoration(
                labelText: 'Status',
                isDense: true,
                border: OutlineInputBorder()),
            items: [
              for (final s in _statuses)
                DropdownMenuItem(
                    value: s,
                    child: Text(s[0].toUpperCase() + s.substring(1)))
            ],
            onChanged: (v) => setState(() => f.status = v ?? f.status),
          ),
          12.h,
          section('Customer'),
          editField('Customer name', f.customer),
          Row(children: [
            Expanded(
                child: editField('Phone', f.phone,
                    keyboard: TextInputType.phone)),
            10.w,
            Expanded(
                child: editField('Secondary phone', f.phone2,
                    keyboard: TextInputType.phone)),
          ]),
          editField('Email', f.email, keyboard: TextInputType.emailAddress),
          section('Service'),
          editField('Package / service', f.service),
          editField('Event slot', f.eventSlot),
          section('Location & travel'),
          editField('Address', f.address, maxLines: 2),
          editField('Map link (URL)', f.mapUrl, keyboard: TextInputType.url),
          Row(children: [
            Expanded(child: editField('Travel mode', f.travelMode)),
            10.w,
            Expanded(child: editField('Travel time', f.travelTime)),
          ]),
          editField('Driver', f.driverName),
          section('Requirements'),
          editField('Outfit', f.outfit),
          editField('Required room', f.room),
          editField('Capture', f.capture),
          editField('Temporary staff / needs', f.tempStaff, maxLines: 2),
          editField('Staff instructions', f.staffInstructions, maxLines: 2),
          section('Point of contact'),
          Row(children: [
            Expanded(child: editField('POC name', f.pocName)),
            10.w,
            Expanded(child: editField('POC phone', f.pocPhone)),
          ]),
          editField('Remarks', f.remarks, maxLines: 3),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: f.saving
                    ? null
                    : () => setState(() => f.editing = false),
                child: const Text('Cancel'),
              ),
            ),
            10.w,
            Expanded(
              child: FilledButton(
                onPressed: f.saving ? null : () => _save(f),
                child: f.saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Save'),
              ),
            ),
          ]),
        ],
      );
    }

    final artists = b.assignedStaff
        .where((a) => a.artistName.trim().isNotEmpty)
        .map((a) => a.artistName.trim())
        .toSet()
        .join(', ');
    final addons = b.addons
        .map((a) => a.service.trim())
        .where((s) => s.isNotEmpty)
        .join(', ');
    final rows = <(IconData, String, String)>[
      (Icons.person_outline, 'Customer', f.customer.text),
      (Icons.call_outlined, 'Phone', dot(f.phone.text, f.phone2.text)),
      (Icons.brush_outlined, 'Artists / needs', artists),
      (Icons.workspace_premium_outlined, 'Package', b.service),
      (Icons.add_circle_outline, 'Add-ons', addons),
      (Icons.schedule, 'Time',
          '${CalendarScreen._fmtTime(b.serviceStart)} – ${CalendarScreen._fmtTime(b.serviceEnd)}'),
      (Icons.event_seat_outlined, 'Slot', b.eventSlot),
      (Icons.checkroom_outlined, 'Outfit', f.outfit.text),
      (Icons.meeting_room_outlined, 'Required room', f.room.text),
      (Icons.directions_car_outlined, 'Travel',
          dot(f.travelMode.text, f.travelTime.text)),
      (Icons.support_agent_outlined, 'POC',
          dot(f.pocName.text, f.pocPhone.text)),
      (Icons.local_taxi_outlined, 'Driver', b.driverName),
      (Icons.videocam_outlined, 'Capture', f.capture.text),
      (Icons.place_outlined, 'Location',
          b.address.trim().isNotEmpty ? b.address : b.district),
      (Icons.notes_outlined, 'Remarks', f.remarks.text),
    ].where((r) => r.$3.trim().isNotEmpty).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final r in rows) _workDetailRow(crm, r.$1, r.$2, r.$3),
        // Reference looks uploaded by CRM — read-only for the artist.
        if (b.referenceImages.isNotEmpty) ...[
          10.h,
          ReferenceImagesPanel(
            images: b.referenceImages,
            title: 'Reference Looks',
          ),
        ],
        6.h,
        Row(children: [
          if (b.mapUrl.trim().isNotEmpty) ...[
            IconButton(
              tooltip: 'Map',
              onPressed: () async {
                final uri = Uri.tryParse(b.mapUrl.trim());
                if (uri != null && await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              icon: const Icon(Icons.map_outlined),
            ),
          ],
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => setState(() => f.editing = true),
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Edit'),
            ),
          ),
          10.w,
          Expanded(
            child: FilledButton.icon(
              onPressed: () {
                Navigator.pop(context);
                context.push(
                    '/booking/manage/${b.id}?entry=${Uri.encodeComponent(f.entry.id)}');
              },
              icon: const Icon(Icons.open_in_new, size: 18),
              label: const Text('Open booking'),
            ),
          ),
        ]),
      ],
    );
  }
}
