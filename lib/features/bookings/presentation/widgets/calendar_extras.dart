import 'package:flutter/material.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:nizan_crm/core/models/trial.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/bookings/data/assignment_rules.dart';
import 'package:nizan_crm/features/trials/presentation/screens/trials_calendar_screen.dart';

// ── Influencer works and studio trials on the Calendar Scheduler ────────────────────────────────────────────────────────────────────
// Each gets its own colour, so neither reads as an ordinary booking: influencer works are violet (with a star), trials are teal (with a
// brush). A cancelled or postponed influencer work keeps the red / amber the calendar uses for those, and still shows its star.

/// Influencer works (booking ticked "Influencer work").
const kInfluencerColor = Color(0xFF8A5CD0);

/// Studio trials.
const kTrialColor = Color(0xFF13878F);

const kInfluencerIcon = Icons.star_rounded;
const kTrialIcon = Icons.brush_outlined;

/// What the Calendar shows. Works only is how it always was.
enum CalendarShow { works, both, trials }

extension CalendarShowText on CalendarShow {
  String get label => switch (this) {
        CalendarShow.works => 'Works only',
        CalendarShow.both => 'Works + trials',
        CalendarShow.trials => 'Trials only',
      };

  bool get showsWorks => this != CalendarShow.trials;
  bool get showsTrials => this != CalendarShow.works;
}

/// The Calendar's Show choice — kept while the app is open, so leaving the calendar and coming back keeps it.
final calendarShowProvider = StateProvider<CalendarShow>((ref) => CalendarShow.works);

// ── Trial helpers ──────────────────────────────────────────────────────────────────────────────────────────────────────────────────

/// Minutes after midnight a trial starts, from its free-text start time ("10:00 AM", "14:30"); 9:00 when none is set.
int trialStartMinutes(Trial t) {
  final s = t.startTime.trim().toUpperCase();
  if (s.isEmpty) return 9 * 60;
  final isPm = s.contains('PM');
  final isAm = s.contains('AM');
  final parts = s.replaceAll(RegExp(r'[^0-9:]'), '').split(':');
  var h = int.tryParse(parts.isNotEmpty ? parts[0] : '') ?? 9;
  final m = int.tryParse(parts.length > 1 ? parts[1] : '') ?? 0;
  if (isPm && h < 12) h += 12;
  if (isAm && h == 12) h = 0;
  return h * 60 + m;
}

String trialTimeLabel(Trial t) {
  final s = t.startTime.trim();
  final e = t.endTime.trim();
  if (s.isNotEmpty && e.isNotEmpty) return '$s – $e';
  return s;
}

/// The first look (or package) of a trial, "+N" for the rest.
String trialLooksLabel(Trial t) {
  if (t.trialItems.isEmpty) return '';
  final first = t.trialItems.first;
  final label = first.lookLabel.trim().isNotEmpty ? first.lookLabel.trim() : first.packageName.trim();
  final extra = t.trialItems.length > 1 ? ' +${t.trialItems.length - 1}' : '';
  return '$label$extra'.trim();
}

String trialArtists(Trial t) =>
    t.assignedStaff.map((a) => a.artistName.trim()).where((n) => n.isNotEmpty).join(', ');

/// A trial's day's trials, earliest first.
List<Trial> trialsOnDay(Iterable<Trial> trials, DateTime day) => trials
    .where((t) => t.trialDate.year == day.year && t.trialDate.month == day.month && t.trialDate.day == day.day)
    .toList()
  ..sort((a, b) => trialStartMinutes(a).compareTo(trialStartMinutes(b)));

/// The Calendar's staff filter, for a trial — the same choices as for works ([bookingMatchesStaffFilter]).
bool trialMatchesStaffFilter(Trial t, String filter, Set<String> associateIds) {
  if (filter == 'all') return true;
  final named = t.assignedStaff.where((a) => a.artistName.trim().isNotEmpty || a.employeeId.trim().isNotEmpty);
  if (filter == 'unassigned') return named.isEmpty;
  if (filter == kAssociatesFilter) return associateIds.isNotEmpty && named.any((a) => associateIds.contains(a.employeeId));
  return named.any((a) => a.employeeId == filter);
}

bool trialIsOff(Trial t) {
  final s = t.status.toLowerCase();
  return s == 'cancelled' || s == 'postponed';
}

/// A trial's chip colours: solid teal while it is on (scheduled or done), pale teal once cancelled or postponed.
({Color bg, Color fg}) trialColors(Trial t) => trialIsOff(t)
    ? (bg: Color.lerp(kTrialColor, Colors.white, 0.8)!, fg: kTrialColor)
    : (bg: kTrialColor, fg: Colors.white);

/// A small word for a trial's status when it is not simply scheduled.
String trialStatusWord(Trial t) => switch (t.status.toLowerCase()) {
      'completed' => 'Done',
      'cancelled' => 'Cancelled',
      'postponed' => 'Postponed',
      _ => '',
    };

/// The trial's popup (the Trials calendar's own), headed in the trial colour.
void openTrialDetails(BuildContext context, WidgetRef ref, Trial t) =>
    TrialsCalendarScreen.showTrialPopup(context, ref, context.crmColors, t, headColor: kTrialColor);

// ── Trial pill (Month and Week views) ──────────────────────────────────────────────────────────────────────────────────────────────

class TrialCalendarPill extends ConsumerWidget {
  const TrialCalendarPill({super.key, required this.trial});

  final Trial trial;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = trialColors(trial);
    final status = trialStatusWord(trial);
    final label = ['TRIAL', trial.clientName.trim().toUpperCase(), if (status.isNotEmpty) status.toUpperCase()]
        .where((s) => s.isNotEmpty)
        .join(' • ');
    return Tooltip(
      message: [
        'Trial · ${trial.clientName}',
        if (trialTimeLabel(trial).isNotEmpty) trialTimeLabel(trial),
        if (trialArtists(trial).isNotEmpty) trialArtists(trial),
      ].join('\n'),
      child: InkWell(
        key: ValueKey('cal_trial_${trial.id}'),
        onTap: () => openTrialDetails(context, ref, trial),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(color: c.bg, borderRadius: BorderRadius.circular(8)),
          child: Row(
            children: [
              Icon(kTrialIcon, size: 12, color: c.fg),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: c.fg,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    decoration: trial.status.toLowerCase() == 'cancelled' ? TextDecoration.lineThrough : null,
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

// ── Trial chip (Day view columns) ──────────────────────────────────────────────────────────────────────────────────────────────────

class TrialCalendarChip extends ConsumerWidget {
  const TrialCalendarChip({super.key, required this.trial});

  final Trial trial;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = trialColors(trial);
    final soft = c.fg.withValues(alpha: 0.78);
    final status = trialStatusWord(trial);
    final sub = [
      'Trial',
      if (trialLooksLabel(trial).isNotEmpty) trialLooksLabel(trial),
      if (status.isNotEmpty) status,
    ].join(' · ');
    final time = trialTimeLabel(trial);
    final artists = trialArtists(trial);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: ValueKey('cal_trial_${trial.id}'),
        onTap: () => openTrialDetails(context, ref, trial),
        onLongPress: () => context.push('/trials/${trial.id}'),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(color: c.bg, borderRadius: BorderRadius.circular(8)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(kTrialIcon, size: 13, color: c.fg),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      trial.clientName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: c.fg,
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
                        decoration: trial.status.toLowerCase() == 'cancelled' ? TextDecoration.lineThrough : null,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: soft, fontSize: 10)),
              if (time.isNotEmpty || artists.isNotEmpty) ...[
                const SizedBox(height: 3),
                Wrap(
                  spacing: 8,
                  runSpacing: 2,
                  children: [
                    if (time.isNotEmpty)
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.schedule, size: 11, color: soft),
                        const SizedBox(width: 3),
                        Text(time, style: TextStyle(color: c.fg, fontSize: 10, fontWeight: FontWeight.w600)),
                      ]),
                    if (artists.isNotEmpty)
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.person_outline, size: 11, color: soft),
                        const SizedBox(width: 2),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 130),
                          child: Text(artists,
                              maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: soft, fontSize: 10)),
                        ),
                      ]),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Trial card (phone Week view list) ──────────────────────────────────────────────────────────────────────────────────────────────

class TrialCalendarCard extends ConsumerWidget {
  const TrialCalendarCard({super.key, required this.trial});

  final Trial trial;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crm = context.crmColors;
    final status = trialStatusWord(trial);
    final time = trialTimeLabel(trial);
    final artists = trialArtists(trial);
    final looks = trialLooksLabel(trial);
    return GestureDetector(
      key: ValueKey('cal_trial_${trial.id}'),
      onTap: () => openTrialDetails(context, ref, trial),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: crm.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kTrialColor.withValues(alpha: 0.35)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 4,
              height: 40,
              decoration: BoxDecoration(
                color: trialIsOff(trial) ? kTrialColor.withValues(alpha: 0.35) : kTrialColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    trial.clientName,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      decoration: trial.status.toLowerCase() == 'cancelled' ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  if (time.isNotEmpty || looks.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      [if (time.isNotEmpty) time, if (looks.isNotEmpty) looks].join(' · '),
                      style: TextStyle(color: crm.textSecondary, fontSize: 12),
                    ),
                  ],
                  if (artists.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(children: [
                      const Icon(Icons.person_outline, size: 14, color: kTrialColor),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(artists,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: kTrialColor, fontSize: 12, fontWeight: FontWeight.w600)),
                      ),
                    ]),
                  ],
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: kTrialColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(kTrialIcon, size: 12, color: kTrialColor),
                const SizedBox(width: 4),
                Text(
                  status.isEmpty ? 'TRIAL' : 'TRIAL · ${status.toUpperCase()}',
                  style: const TextStyle(color: kTrialColor, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

// ── The star on an influencer work ─────────────────────────────────────────────────────────────────────────────────────────────────

class InfluencerMark extends StatelessWidget {
  const InfluencerMark({super.key, this.color = Colors.white, this.size = 12});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: 'Influencer work',
        child: Padding(
          padding: const EdgeInsets.only(right: 3),
          child: Icon(kInfluencerIcon, key: const Key('cal_influencer_mark'), size: size, color: color),
        ),
      );
}

// ── Show button + key ──────────────────────────────────────────────────────────────────────────────────────────────────────────────

/// "Show: Works only / Works + trials / Trials only". [placeFilterOn]: trials have no place, so a place filter hides them — the menu
/// says so.
class CalendarShowButton extends ConsumerWidget {
  const CalendarShowButton({super.key, this.placeFilterOn = false});

  final bool placeFilterOn;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crm = context.crmColors;
    final show = ref.watch(calendarShowProvider);
    final on = show.showsTrials;
    final fg = on ? kTrialColor : crm.textPrimary;
    return PopupMenuButton<CalendarShow>(
      key: const Key('cal_show'),
      tooltip: 'Show works, trials or both',
      initialValue: show,
      onSelected: (v) => ref.read(calendarShowProvider.notifier).state = v,
      itemBuilder: (_) => [
        for (final v in CalendarShow.values)
          CheckedPopupMenuItem<CalendarShow>(
            key: Key('cal_show_${v.name}'),
            value: v,
            checked: v == show,
            child: Text(v.label),
          ),
        if (placeFilterOn)
          PopupMenuItem<CalendarShow>(
            enabled: false,
            child: Text(
              'Trials have no place, so they are hidden while a place filter is on.',
              style: TextStyle(fontSize: 12, color: crm.textSecondary),
            ),
          ),
      ],
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: on ? kTrialColor.withValues(alpha: 0.08) : crm.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: on ? kTrialColor.withValues(alpha: 0.45) : crm.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(on ? kTrialIcon : Icons.layers_outlined, size: 18, color: fg),
            const SizedBox(width: 6),
            Text(show.label, style: TextStyle(color: fg, fontWeight: FontWeight.w600, fontSize: 13)),
            Icon(Icons.arrow_drop_down, size: 18, color: fg),
          ],
        ),
      ),
    );
  }
}

/// The colour key under the toolbar: influencer works always, trials when they are shown.
class CalendarColorKey extends StatelessWidget {
  const CalendarColorKey({super.key, required this.showsTrials, this.trialsHidden = false});

  final bool showsTrials;

  /// Trials are switched on but a place filter hides them.
  final bool trialsHidden;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    Widget item(IconData icon, Color color, String text) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 18,
              height: 18,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(5)),
              child: Icon(icon, size: 12, color: Colors.white),
            ),
            const SizedBox(width: 6),
            Text(text, style: TextStyle(fontSize: 12, color: crm.textSecondary, fontWeight: FontWeight.w600)),
          ],
        );
    return Wrap(
      key: const Key('cal_color_key'),
      spacing: 16,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        item(kInfluencerIcon, kInfluencerColor, 'Influencer work'),
        if (showsTrials) item(kTrialIcon, kTrialColor, trialsHidden ? 'Trial (hidden by the place filter)' : 'Trial'),
      ],
    );
  }
}
