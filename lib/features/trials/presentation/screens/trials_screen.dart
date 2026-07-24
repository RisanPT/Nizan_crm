import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nizan_crm/core/extensions/space_extension.dart';
import 'package:nizan_crm/core/models/trial.dart';
import 'package:nizan_crm/core/providers/trial_provider.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';

// ── Status helpers ─────────────────────────────────────────────────────────
extension TrialStatusX on String {
  Color get statusColor {
    switch (this) {
      case 'completed':
        return const Color(0xFF10B981);
      case 'postponed':
        return const Color(0xFFF59E0B);
      case 'cancelled':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF6366F1);
    }
  }

  String get statusLabel {
    switch (this) {
      case 'completed':
        return 'Completed';
      case 'postponed':
        return 'Postponed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return 'Scheduled';
    }
  }

  IconData get statusIcon {
    switch (this) {
      case 'completed':
        return Icons.check_circle_outline;
      case 'postponed':
        return Icons.schedule_outlined;
      case 'cancelled':
        return Icons.cancel_outlined;
      default:
        return Icons.event_available_outlined;
    }
  }
}

// ── Screen ─────────────────────────────────────────────────────────────────
class TrialsScreen extends ConsumerStatefulWidget {
  const TrialsScreen({super.key});

  @override
  ConsumerState<TrialsScreen> createState() => _TrialsScreenState();
}

class _TrialsScreenState extends ConsumerState<TrialsScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  static const List<String> _weekDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const List<String> _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  String _monthKey(DateTime d) {
    final m = d.month.toString().padLeft(2, '0');
    return '${d.year}-$m';
  }

  void _previousMonth() {
    setState(() {
      _focusedDay = DateTime(_focusedDay.year, _focusedDay.month - 1, 1);
      _selectedDay = null;
    });
    ref.read(trialsMonthProvider.notifier).state = _monthKey(_focusedDay);
  }

  void _nextMonth() {
    setState(() {
      _focusedDay = DateTime(_focusedDay.year, _focusedDay.month + 1, 1);
      _selectedDay = null;
    });
    ref.read(trialsMonthProvider.notifier).state = _monthKey(_focusedDay);
  }

  List<Trial> _trialsOnDay(List<Trial> trials, DateTime day) {
    return trials.where((t) {
      return t.trialDate.year == day.year &&
          t.trialDate.month == day.month &&
          t.trialDate.day == day.day;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final crmColors = context.crmColors;
    final trialsAsync = ref.watch(trialsProvider);

    return Scaffold(
      backgroundColor: crmColors.background,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context, crmColors),
          Expanded(
            child: trialsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Text('Error: $e',
                    style: TextStyle(color: crmColors.textSecondary)),
              ),
              data: (trials) => _buildContent(context, crmColors, trials),
            ),
          ),
        ],
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────
  Widget _buildHeader(BuildContext context, CrmTheme crmColors) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      decoration: BoxDecoration(
        color: crmColors.surface,
        border: Border(
          bottom: BorderSide(color: crmColors.border, width: 1),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.event_available_outlined,
                color: Color(0xFF8B5CF6), size: 22),
          ),
          12.w,
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Studio Trials',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: crmColors.textPrimary,
                ),
              ),
              Text(
                'Bridal studio appointment management',
                style: TextStyle(
                  fontSize: 12,
                  color: crmColors.textSecondary,
                ),
              ),
            ],
          ),
          const Spacer(),
          FilledButton.icon(
            onPressed: () => context.push('/trials/new'),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add Trial'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF8B5CF6),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Content ─────────────────────────────────────────────────────────────
  Widget _buildContent(
      BuildContext context, CrmTheme crmColors, List<Trial> trials) {
    final trialsByDay = <String, List<Trial>>{};
    for (final t in trials) {
      final key =
          '${t.trialDate.year}-${t.trialDate.month}-${t.trialDate.day}';
      trialsByDay.putIfAbsent(key, () => []).add(t);
    }

    final displayTrials = _selectedDay != null
        ? _trialsOnDay(trials, _selectedDay!)
        : trials;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCalendar(crmColors, trialsByDay),
          24.h,
          _buildListSection(context, crmColors, displayTrials),
        ],
      ),
    );
  }

  // ── Calendar ─────────────────────────────────────────────────────────────
  Widget _buildCalendar(CrmTheme crmColors, Map<String, List<Trial>> byDay) {
    final firstDay = DateTime(_focusedDay.year, _focusedDay.month, 1);
    final daysInMonth =
        DateTime(_focusedDay.year, _focusedDay.month + 1, 0).day;
    // weekday: Mon=1 … Sun=7
    final startOffset = (firstDay.weekday - 1) % 7;

    return Container(
      decoration: BoxDecoration(
        color: crmColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: crmColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Column(
        children: [
          // Month navigator
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                IconButton(
                  onPressed: _previousMonth,
                  icon: Icon(Icons.chevron_left,
                      color: crmColors.textPrimary),
                ),
                Expanded(
                  child: Text(
                    '${_monthNames[_focusedDay.month - 1]} ${_focusedDay.year}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: crmColors.textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _nextMonth,
                  icon: Icon(Icons.chevron_right,
                      color: crmColors.textPrimary),
                ),
              ],
            ),
          ),
          // Weekday row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: _weekDays
                  .map((d) => Expanded(
                        child: Center(
                          child: Text(
                            d,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: crmColors.textSecondary,
                            ),
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ),
          8.h,
          // Day grid
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                childAspectRatio: 1.1,
              ),
              itemCount: startOffset + daysInMonth,
              itemBuilder: (context, index) {
                if (index < startOffset) return const SizedBox();
                final day = index - startOffset + 1;
                final date =
                    DateTime(_focusedDay.year, _focusedDay.month, day);
                final key = '${date.year}-${date.month}-${date.day}';
                final dayTrials = byDay[key] ?? [];
                final isSelected = _selectedDay?.year == date.year &&
                    _selectedDay?.month == date.month &&
                    _selectedDay?.day == date.day;
                final isToday = DateTime.now().year == date.year &&
                    DateTime.now().month == date.month &&
                    DateTime.now().day == date.day;

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedDay =
                          isSelected ? null : date;
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF8B5CF6)
                          : isToday
                              ? const Color(0xFF8B5CF6).withValues(alpha: 0.1)
                              : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$day',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isToday || isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isSelected
                                ? Colors.white
                                : isToday
                                    ? const Color(0xFF8B5CF6)
                                    : crmColors.textPrimary,
                          ),
                        ),
                        if (dayTrials.isNotEmpty) ...[
                          2.h,
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: dayTrials
                                .take(3)
                                .map((t) => Container(
                                      width: 5,
                                      height: 5,
                                      margin: const EdgeInsets.symmetric(
                                          horizontal: 1),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? Colors.white
                                            : t.status.statusColor,
                                        shape: BoxShape.circle,
                                      ),
                                    ))
                                .toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── Trial List ────────────────────────────────────────────────────────────
  Widget _buildListSection(
      BuildContext context, CrmTheme crmColors, List<Trial> trials) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              _selectedDay != null
                  ? 'Trials on ${_selectedDay!.day} ${_monthNames[_selectedDay!.month - 1]}'
                  : 'All Trials — ${_monthNames[_focusedDay.month - 1]} ${_focusedDay.year}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: crmColors.textPrimary,
              ),
            ),
            8.w,
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${trials.length}',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF8B5CF6)),
              ),
            ),
          ],
        ),
        12.h,
        if (trials.isEmpty)
          _buildEmptyState(crmColors)
        else
          ...trials.map((t) => _TrialCard(
                trial: t,
                onTap: () => context.push('/trials/${t.id}'),
              )),
      ],
    );
  }

  Widget _buildEmptyState(CrmTheme crmColors) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(48),
      decoration: BoxDecoration(
        color: crmColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: crmColors.border),
      ),
      child: Column(
        children: [
          Icon(Icons.event_available_outlined,
              size: 48, color: crmColors.textSecondary),
          16.h,
          Text(
            'No trials scheduled',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: crmColors.textSecondary),
          ),
          8.h,
          Text(
            'Add a new trial appointment using the "+ Add Trial" button',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: crmColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

// ── Trial Card ──────────────────────────────────────────────────────────────
class _TrialCard extends StatelessWidget {
  final Trial trial;
  final VoidCallback onTap;

  const _TrialCard({required this.trial, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final crmColors = context.crmColors;
    final statusColor = trial.status.statusColor;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: crmColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: crmColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: IntrinsicHeight(
            child: Row(
              children: [
                // Status bar
                Container(
                  width: 5,
                  color: statusColor,
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Avatar
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: const Color(0xFF8B5CF6)
                                    .withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  trial.clientName.isNotEmpty
                                      ? trial.clientName[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF8B5CF6),
                                  ),
                                ),
                              ),
                            ),
                            12.w,
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    trial.clientName,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: crmColors.textPrimary,
                                    ),
                                  ),
                                  4.h,
                                  Row(
                                    children: [
                                      Icon(Icons.phone_outlined,
                                          size: 12,
                                          color: crmColors.textSecondary),
                                      4.w,
                                      Text(
                                        trial.phone,
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: crmColors.textSecondary),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            // Status badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color:
                                    statusColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(trial.status.statusIcon,
                                      size: 11, color: statusColor),
                                  4.w,
                                  Text(
                                    trial.status.statusLabel,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: statusColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        12.h,
                        Row(
                          children: [
                            _InfoChip(
                              icon: Icons.calendar_today_outlined,
                              label: _formatDate(trial.trialDate),
                            ),
                            8.w,
                            if (trial.startTime.isNotEmpty)
                              _InfoChip(
                                icon: Icons.access_time_outlined,
                                label: trial.endTime.isNotEmpty
                                    ? '${trial.startTime} – ${trial.endTime}'
                                    : trial.startTime,
                              ),
                            8.w,
                            if (trial.trialItems.isNotEmpty)
                              _InfoChip(
                                icon: Icons.checkroom_outlined,
                                label:
                                    '${trial.trialItems.length} package${trial.trialItems.length > 1 ? 's' : ''}',
                                accent: true,
                              ),
                          ],
                        ),
                        if (trial.trialNumber.isNotEmpty) ...[
                          8.h,
                          Text(
                            trial.trialNumber,
                            style: TextStyle(
                              fontSize: 11,
                              color: crmColors.textSecondary,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Icon(Icons.chevron_right,
                      color: crmColors.textSecondary, size: 20),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool accent;

  const _InfoChip({
    required this.icon,
    required this.label,
    this.accent = false,
  });

  @override
  Widget build(BuildContext context) {
    final crmColors = context.crmColors;
    final color =
        accent ? const Color(0xFF8B5CF6) : crmColors.textSecondary;
    final bg = accent
        ? const Color(0xFF8B5CF6).withValues(alpha: 0.1)
        : crmColors.border.withValues(alpha: 0.5);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          4.w,
          Text(label,
              style: TextStyle(
                  fontSize: 11, color: color, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
