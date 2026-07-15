import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/extensions/space_extension.dart';
import '../../core/models/trial.dart';
import '../../core/providers/trial_provider.dart';
import '../../services/trial_service.dart';
import '../../core/theme/crm_theme.dart';
import '../../core/utils/responsive_builder.dart';

/// Trials calendar — mirrors the booking calendar's UI/UX (Month / Week / Day)
/// but bound to studio trials. Isolated from the booking calendar.
class TrialsCalendarScreen extends HookConsumerWidget {
  const TrialsCalendarScreen({super.key});

  static const _wd = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
  static const _wdFull = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
  ];
  static const _mo = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  static const _moFull = [
    'January', 'February', 'March', 'April', 'May', 'June', 'July',
    'August', 'September', 'October', 'November', 'December'
  ];

  // Soft status palette — identical to the booking calendar.
  static Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return const Color(0xFF5AA06E);
      case 'cancelled':
        return const Color(0xFFD07A7A);
      case 'postponed':
        return const Color(0xFFDDA05F);
      case 'scheduled':
      case 'confirmed':
        return const Color(0xFF6699CC);
      default:
        return const Color(0xFF7C8E9A);
    }
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  // Sort key from a free-text start time like "10:00 AM".
  static int _startMinutes(Trial t) {
    var s = t.startTime.trim().toUpperCase();
    if (s.isEmpty) return 9 * 60;
    final isPm = s.contains('PM');
    final isAm = s.contains('AM');
    final digits = s.replaceAll(RegExp(r'[^0-9:]'), '');
    final parts = digits.split(':');
    var h = int.tryParse(parts.isNotEmpty ? parts[0] : '') ?? 9;
    final m = int.tryParse(parts.length > 1 ? parts[1] : '') ?? 0;
    if (isPm && h < 12) h += 12;
    if (isAm && h == 12) h = 0;
    return h * 60 + m;
  }

  static String _timeLabel(Trial t) {
    final s = t.startTime.trim();
    final e = t.endTime.trim();
    if (s.isNotEmpty && e.isNotEmpty) return '$s – $e';
    return s;
  }

  static String _subtitle(Trial t) {
    if (t.trialItems.isEmpty) return 'Trial';
    final first = t.trialItems.first;
    final label = first.lookLabel.trim().isNotEmpty
        ? first.lookLabel.trim()
        : first.packageName.trim();
    final extra = t.trialItems.length > 1 ? ' +${t.trialItems.length - 1}' : '';
    return '${label.isEmpty ? 'Trial' : label}$extra';
  }

  List<Trial> _trialsOnDay(List<Trial> trials, DateTime day) {
    final list =
        trials.where((t) => _sameDay(t.trialDate, day)).toList()
          ..sort((a, b) => _startMinutes(a).compareTo(_startMinutes(b)));
    return list;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crm = context.crmColors;
    final theme = Theme.of(context);
    final isMobile = ResponsiveBuilder.isMobile(context);
    final now = DateTime.now();

    final viewMode = useState<String>('Month');
    final monthFocus = useState<DateTime>(DateTime(now.year, now.month, 1));
    final currentWeekMonday = useMemoized(() => DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1)));
    final weekStart = useState<DateTime>(currentWeekMonday);
    final statusFilter = useState<String>('all');

    final weekDays =
        List.generate(7, (i) => weekStart.value.add(Duration(days: i)));

    int dayIndexFor(DateTime target) {
      for (var i = 0; i < weekDays.length; i++) {
        if (_sameDay(weekDays[i], target)) return i;
      }
      return 0;
    }

    final selectedDayIndex = useState(dayIndexFor(now));
    final selectedDay = weekDays[selectedDayIndex.value];

    final async = ref.watch(allTrialsProvider);
    final allTrials = async.value ?? const <Trial>[];
    final trials = statusFilter.value == 'all'
        ? allTrials
        : allTrials
            .where((t) => t.status.toLowerCase() == statusFilter.value)
            .toList();

    void goToDay(DateTime day) {
      final aligned = DateTime(day.year, day.month, day.day)
          .subtract(Duration(days: day.weekday - 1));
      weekStart.value = aligned;
      selectedDayIndex.value = day.weekday - 1;
    }

    void openDayView(DateTime day) {
      goToDay(day);
      viewMode.value = 'Day';
    }

    void goPrev() {
      if (viewMode.value == 'Month') {
        monthFocus.value =
            DateTime(monthFocus.value.year, monthFocus.value.month - 1, 1);
      } else if (viewMode.value == 'Day') {
        goToDay(selectedDay.subtract(const Duration(days: 1)));
      } else {
        weekStart.value = weekStart.value.subtract(const Duration(days: 7));
        selectedDayIndex.value = 0;
      }
    }

    void goNext() {
      if (viewMode.value == 'Month') {
        monthFocus.value =
            DateTime(monthFocus.value.year, monthFocus.value.month + 1, 1);
      } else if (viewMode.value == 'Day') {
        goToDay(selectedDay.add(const Duration(days: 1)));
      } else {
        weekStart.value = weekStart.value.add(const Duration(days: 7));
        selectedDayIndex.value = 0;
      }
    }

    void goToday() {
      monthFocus.value = DateTime(now.year, now.month, 1);
      weekStart.value = currentWeekMonday;
      selectedDayIndex.value = dayIndexFor(now);
    }

    String centerTitle() {
      if (viewMode.value == 'Month') {
        return '${_moFull[monthFocus.value.month - 1]} ${monthFocus.value.year}';
      }
      if (viewMode.value == 'Day') {
        return '${_wdFull[selectedDay.weekday - 1]}, ${selectedDay.day} ${_mo[selectedDay.month - 1]}';
      }
      final end = weekDays.last;
      return '${weekDays.first.day} ${_mo[weekDays.first.month - 1]} – ${end.day} ${_mo[end.month - 1]}';
    }

    return PopScope(
      canPop: viewMode.value != 'Day',
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && viewMode.value == 'Day') viewMode.value = 'Month';
      },
      child: Scaffold(
        backgroundColor: crm.background,
        floatingActionButton: isMobile
            ? FloatingActionButton(
                onPressed: () => context.push('/trials/new'),
                backgroundColor: crm.primary,
                foregroundColor: Colors.white,
                child: const Icon(Icons.add),
              )
            : null,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _topBar(context, crm, isMobile),
            _controls(context, crm, theme, isMobile, viewMode, statusFilter,
                goToday, goPrev, goNext, centerTitle()),
            Expanded(
              child: async.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : async.hasError
                      ? Center(
                          child: Text('Failed to load trials',
                              style: TextStyle(color: crm.textSecondary)))
                      : SingleChildScrollView(
                          padding: EdgeInsets.all(isMobile ? 12 : 16),
                          child: viewMode.value == 'Month'
                              ? _monthView(context, crm, isMobile, trials,
                                  monthFocus.value, now, openDayView)
                              : viewMode.value == 'Week'
                                  ? _weekView(context, ref, crm, trials,
                                      weekDays, openDayView)
                                  : _dayView(context, ref, crm, isMobile,
                                      trials, selectedDay, goToDay),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────
  Widget _topBar(BuildContext context, CrmTheme crm, bool isMobile) {
    return Container(
      padding: EdgeInsets.fromLTRB(isMobile ? 16 : 24, 18, isMobile ? 16 : 24, 14),
      decoration: BoxDecoration(
        color: crm.surface,
        border: Border(bottom: BorderSide(color: crm.border)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: crm.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.event_available_outlined,
                color: crm.primary, size: 22),
          ),
          12.w,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Trials Calendar',
                    style: TextStyle(
                        fontSize: isMobile ? 18 : 22,
                        fontWeight: FontWeight.w800,
                        color: crm.textPrimary)),
                Text('Studio trial appointments',
                    style: TextStyle(fontSize: 12, color: crm.textSecondary)),
              ],
            ),
          ),
          if (!isMobile)
            FilledButton.icon(
              onPressed: () => context.push('/trials/new'),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('New Trial'),
            ),
        ],
      ),
    );
  }

  Widget _controls(
    BuildContext context,
    CrmTheme crm,
    ThemeData theme,
    bool isMobile,
    ValueNotifier<String> viewMode,
    ValueNotifier<String> statusFilter,
    VoidCallback goToday,
    VoidCallback goPrev,
    VoidCallback goNext,
    String title,
  ) {
    final segmented = SegmentedButton<String>(
      segments: const [
        ButtonSegment(value: 'Day', label: Text('Day')),
        ButtonSegment(value: 'Week', label: Text('Week')),
        ButtonSegment(value: 'Month', label: Text('Month')),
      ],
      selected: {viewMode.value},
      onSelectionChanged: (s) => viewMode.value = s.first,
      showSelectedIcon: false,
      style: SegmentedButton.styleFrom(
        backgroundColor: crm.input,
        selectedBackgroundColor: crm.surface,
        selectedForegroundColor: crm.textPrimary,
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),
    );

    final nav = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        OutlinedButton(onPressed: goToday, child: const Text('Today')),
        8.w,
        IconButton(onPressed: goPrev, icon: const Icon(Icons.chevron_left)),
        IconButton(onPressed: goNext, icon: const Icon(Icons.chevron_right)),
        8.w,
        Flexible(
          child: Text(title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
        ),
      ],
    );

    return Container(
      padding: EdgeInsets.fromLTRB(isMobile ? 12 : 24, 12, isMobile ? 12 : 24, 4),
      child: isMobile
          ? Column(
              children: [
                nav,
                10.h,
                Row(children: [
                  Expanded(child: _statusFilter(crm, statusFilter)),
                  12.w,
                  segmented,
                ]),
              ],
            )
          : Row(
              children: [
                nav,
                const Spacer(),
                _statusFilter(crm, statusFilter),
                16.w,
                segmented,
              ],
            ),
    );
  }

  Widget _statusFilter(CrmTheme crm, ValueNotifier<String> statusFilter) {
    const opts = {
      'all': 'All trials',
      'scheduled': 'Scheduled',
      'completed': 'Completed',
      'postponed': 'Postponed',
      'cancelled': 'Cancelled',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: crm.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: statusFilter.value,
          isDense: true,
          icon: const Icon(Icons.keyboard_arrow_down, size: 18),
          items: [
            for (final e in opts.entries)
              DropdownMenuItem(value: e.key, child: Text(e.value)),
          ],
          onChanged: (v) => statusFilter.value = v ?? 'all',
        ),
      ),
    );
  }

  // ── Month view ────────────────────────────────────────────────────────
  Widget _monthView(BuildContext context, CrmTheme crm, bool isMobile,
      List<Trial> trials, DateTime month, DateTime now,
      void Function(DateTime) onOpenDay) {
    final first = DateTime(month.year, month.month, 1);
    final gridStart = first.subtract(Duration(days: first.weekday - 1));
    final days = List.generate(42, (i) => gridStart.add(Duration(days: i)));
    final maxPills = isMobile ? 0 : 3;

    return Container(
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: crm.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Row(
            children: _wd
                .map((d) => Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        alignment: Alignment.center,
                        child: Text(d,
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: crm.textSecondary)),
                      ),
                    ))
                .toList(),
          ),
          Divider(height: 1, color: crm.border),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: isMobile ? 0.72 : 1.05,
            ),
            itemCount: 42,
            itemBuilder: (context, i) {
              final day = days[i];
              final inMonth = day.month == month.month;
              final isToday = _sameDay(day, now);
              final dayTrials = inMonth ? _trialsOnDay(trials, day) : const <Trial>[];
              return Container(
                decoration: BoxDecoration(
                  border: Border(
                    right: BorderSide(color: crm.border),
                    bottom: BorderSide(color: crm.border),
                  ),
                  color: inMonth
                      ? crm.surface
                      : crm.background.withValues(alpha: 0.5),
                ),
                padding: EdgeInsets.all(isMobile ? 2 : 4),
                child: !inMonth
                    ? const SizedBox.shrink()
                    : Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => onOpenDay(day),
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
                                    width: isMobile ? 26 : 36,
                                    height: isMobile ? 26 : 36,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isToday
                                          ? crm.primary
                                          : Colors.transparent,
                                    ),
                                    child: Text('${day.day}',
                                        style: TextStyle(
                                            fontSize: isMobile ? 12 : 15,
                                            fontWeight: FontWeight.w700,
                                            color: isToday
                                                ? Colors.white
                                                : crm.textPrimary)),
                                  ),
                                ),
                                if (isMobile) ...[
                                  if (dayTrials.isNotEmpty) ...[
                                    4.h,
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: dayTrials.take(3).map((t) {
                                        return Container(
                                          width: 5,
                                          height: 5,
                                          margin: const EdgeInsets.symmetric(
                                              horizontal: 1),
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: _statusColor(t.status),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ],
                                ] else ...[
                                  6.h,
                                  ...dayTrials.take(maxPills).map((t) => Padding(
                                        padding: const EdgeInsets.only(bottom: 4),
                                        child: _monthPill(crm, t),
                                      )),
                                  if (dayTrials.length > maxPills)
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: crm.secondary
                                            .withValues(alpha: 0.35),
                                        borderRadius: BorderRadius.circular(999),
                                      ),
                                      child: Text(
                                          'View all (${dayTrials.length})',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                              color: crm.textSecondary,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700)),
                                    ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _monthPill(CrmTheme crm, Trial t) {
    final color = _statusColor(t.status);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      child: Text(t.clientName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700, color: crm.textPrimary)),
    );
  }

  // ── Week view ───────────────────────────────────────────────────────────
  Widget _weekView(BuildContext context, WidgetRef ref, CrmTheme crm,
      List<Trial> trials, List<DateTime> weekDays,
      void Function(DateTime) onOpenDay) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final day in weekDays)
            Expanded(child: _dayColumn(context, ref, crm, trials, day,
                selected: false, onSelectDay: onOpenDay)),
        ],
      ),
    );
  }

  // ── Day view (3 columns: prev · selected · next) ──────────────────────────
  Widget _dayView(BuildContext context, WidgetRef ref, CrmTheme crm,
      bool isMobile, List<Trial> trials, DateTime selectedDay,
      void Function(DateTime) onSelectDay) {
    final prev = selectedDay.subtract(const Duration(days: 1));
    final next = selectedDay.add(const Duration(days: 1));
    if (isMobile) {
      return _dayColumn(context, ref, crm, trials, selectedDay,
          selected: true, onSelectDay: onSelectDay);
    }
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _dayColumn(context, ref, crm, trials, prev,
              selected: false, onSelectDay: onSelectDay)),
          Expanded(child: _dayColumn(context, ref, crm, trials, selectedDay,
              selected: true, onSelectDay: onSelectDay)),
          Expanded(child: _dayColumn(context, ref, crm, trials, next,
              selected: false, onSelectDay: onSelectDay)),
        ],
      ),
    );
  }

  Widget _dayColumn(BuildContext context, WidgetRef ref, CrmTheme crm,
      List<Trial> trials, DateTime day,
      {required bool selected, required void Function(DateTime) onSelectDay}) {
    final items = _trialsOnDay(trials, day);
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
                    ? LinearGradient(begin: Alignment.topLeft,
                        end: Alignment.bottomRight, colors: [
                        crm.primary,
                        Color.lerp(crm.primary, Colors.black, 0.28)!,
                      ])
                    : null,
                color: selected ? null : crm.background,
              ),
              child: Column(
                children: [
                  Text(_wd[day.weekday - 1],
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                          color: selected ? Colors.white70 : crm.textSecondary)),
                  const SizedBox(height: 3),
                  Text('${day.day} ${_mo[day.month - 1]}',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: selected ? Colors.white : crm.textPrimary)),
                  const SizedBox(height: 2),
                  Text('${items.length} trial${items.length == 1 ? '' : 's'}',
                      style: TextStyle(
                          fontSize: 10.5,
                          color: selected ? Colors.white70 : crm.textSecondary)),
                ],
              ),
            ),
          ),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 12),
              child: Center(
                  child: Text('No trials',
                      style: TextStyle(color: crm.textSecondary, fontSize: 12))),
            )
          else
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                children: [
                  for (final t in items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: _trialChip(context, ref, crm, t),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _trialChip(
      BuildContext context, WidgetRef ref, CrmTheme crm, Trial t) {
    final bg = _statusColor(t.status);
    final time = _timeLabel(t);
    final sub = [
      if (time.isNotEmpty) time,
      _subtitle(t),
    ].join(' · ');
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showTrialPopup(context, ref, crm, t),
        onLongPress: () => context.push('/trials/${t.id}'),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration:
              BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t.clientName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5)),
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

  // ── Trial detail popup ────────────────────────────────────────────────
  void _showTrialPopup(
      BuildContext context, WidgetRef ref, CrmTheme crm, Trial t) {
    var status = t.status;
    var saving = false;
    const statuses = ['scheduled', 'completed', 'postponed', 'cancelled'];

    Widget row(IconData icon, String label, String value) {
      if (value.trim().isEmpty) return const SizedBox.shrink();
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

    showDialog<void>(
      context: context,
      builder: (dctx) => StatefulBuilder(
        builder: (dctx, setLocal) {
          final head = _statusColor(status);
          Future<void> saveStatus(String s) async {
            setLocal(() {
              status = s;
              saving = true;
            });
            final messenger = ScaffoldMessenger.of(dctx);
            try {
              await ref
                  .read(trialServiceProvider)
                  .updateTrial(t.copyWith(status: s));
              ref.read(trialsRefreshTriggerProvider.notifier).state++;
              setLocal(() => saving = false);
              messenger.showSnackBar(
                  const SnackBar(content: Text('Trial updated')));
            } catch (e) {
              setLocal(() => saving = false);
              messenger.showSnackBar(SnackBar(content: Text('Update failed: $e')));
            }
          }

          final looks = t.trialItems
              .map((i) => i.lookLabel.trim().isNotEmpty
                  ? i.lookLabel.trim()
                  : i.packageName.trim())
              .where((s) => s.isNotEmpty)
              .join(', ');

          return Dialog(
            insetPadding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460, maxHeight: 620),
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
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(t.clientName,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800)),
                              4.h,
                              Text(
                                  '${_wdFull[t.trialDate.weekday - 1]}, ${t.trialDate.day} ${_moFull[t.trialDate.month - 1]} ${t.trialDate.year}',
                                  style: const TextStyle(
                                      color: Colors.white70, fontSize: 12.5)),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => Navigator.pop(dctx),
                        ),
                      ],
                    ),
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (t.trialNumber.isNotEmpty)
                            row(Icons.tag, 'Trial no', t.trialNumber),
                          row(Icons.call_outlined, 'Phone', t.phone),
                          row(Icons.mail_outline, 'Email', t.email),
                          row(Icons.schedule, 'Time', _timeLabel(t)),
                          row(Icons.brush_outlined, 'Looks', looks),
                          row(Icons.notes_outlined, 'Notes', t.notes),
                          14.h,
                          DropdownButtonFormField<String>(
                            initialValue: statuses.contains(status.toLowerCase())
                                ? status.toLowerCase()
                                : 'scheduled',
                            decoration: const InputDecoration(
                                labelText: 'Status',
                                isDense: true,
                                border: OutlineInputBorder()),
                            items: [
                              for (final s in statuses)
                                DropdownMenuItem(
                                    value: s,
                                    child:
                                        Text(s[0].toUpperCase() + s.substring(1)))
                            ],
                            onChanged: saving
                                ? null
                                : (v) {
                                    if (v != null) saveStatus(v);
                                  },
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
                    child: Row(children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () {
                            Navigator.pop(dctx);
                            context.push('/trials/${t.id}');
                          },
                          icon: const Icon(Icons.open_in_new, size: 18),
                          label: const Text('Open trial'),
                        ),
                      ),
                    ]),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
