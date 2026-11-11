import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/accounts/data/artist_expense.dart'
    show mealLabel, mealsLabel, orderMeals, periodLabel, travelDistanceText;
import 'package:nizan_crm/features/accounts/data/food_allowance.dart';
import 'package:nizan_crm/features/accounts/controllers/expense_controller.dart';
import 'package:nizan_crm/features/accounts/data/work_cost.dart';

String _rupees(double v) =>
    '₹${v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2)}';

String _clock(DateTime? t) => t == null ? '' : DateFormat('h:mm a').format(t);

String workWindow(DayWorkBrief w) => [
  _clock(w.serviceStart),
  _clock(w.serviceEnd),
].where((x) => x.isNotEmpty).join(' – ');

/// "Afternoon · 1:00 PM – 4:00 PM" — when in the day the work is, then its hours.
String workWhen(DayWorkBrief w) => [
  periodLabel(w.period),
  workWindow(w),
].where((x) => x.isNotEmpty).join(' · ');

/// "Breakfast, lunch and dinner" — for the sentence that explains a combined bill.
String _mealsInWords(List<String> meals) {
  final names = meals.map((m) => mealLabel(m).toLowerCase()).where((n) => n.isNotEmpty).toList();
  if (names.length < 2) return names.join();
  return '${names.sublist(0, names.length - 1).join(', ')} and ${names.last}';
}

/// While adding a meal: which of the artist's works that day it will be counted under, and
/// why — with a way to choose a different one. (The rule is the server's: the nearest work in
/// time; see utils/mealAllocation.js.) A failure to check never blocks saving the expense;
/// Accounts can still place it.
class MealPlacementCard extends ConsumerWidget {
  /// When the meal was.
  final DateTime at;

  /// The meals this bill covers, in the order they are eaten (one, or several when the artist
  /// filed one bill for more than one meal).
  final List<String> meals;

  /// Accounts, adding on an artist's behalf, names the artist; an artist leaves it null.
  final String? employeeId;

  /// The work the artist has chosen (null = let the app pick by time).
  final String? pinnedBookingId;
  final ValueChanged<String?> onPin;

  /// What is being typed in the amount field (null / 0 = nothing yet). The team's limit is checked
  /// against it as it is typed — no request per keystroke: the server says what the team has already
  /// logged, and the sum is done here.
  final double? amount;

  /// An expense being edited: left out of what the team has already logged.
  final String? excludeExpenseId;

  /// The amount the team's meal works out to (heads × the allowance per head, less what the team has
  /// already logged), told whenever the work, the meal or the team changes; null when there is none.
  /// The form fills the field with it unless the artist has typed their own. Null = no auto-fill.
  final ValueChanged<double?>? onAutoAmount;

  /// The artist picked one of the quick amounts (whole team / just me / what's left).
  final ValueChanged<double>? onUseAmount;

  /// [meal] is for one meal; [meals] for one or several (it wins when both are given).
  MealPlacementCard({
    super.key,
    required this.at,
    String meal = '',
    List<String> meals = const [],
    required this.employeeId,
    required this.pinnedBookingId,
    required this.onPin,
    this.amount,
    this.excludeExpenseId,
    this.onAutoAmount,
    this.onUseAmount,
  }) : meals = orderMeals(meals.isNotEmpty ? meals : [if (meal.isNotEmpty) meal]);

  /// Several meals on one bill.
  bool get isCombined => meals.length > 1;

  Future<void> _choose(BuildContext context, MealPreview preview) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                'Count this meal under…',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
            ),
            for (final w in preview.works)
              ListTile(
                key: Key('mealWorkOption_${w.bookingId}'),
                leading: Icon(
                  w.bookingId ==
                          (pinnedBookingId ?? preview.suggestion.bookingId)
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                ),
                title: Text(
                  w.customerName.isEmpty ? 'Work' : w.customerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  [
                    workWhen(w),
                    w.service,
                    travelDistanceText(w.travelDistanceKm),
                  ].where((x) => x.isNotEmpty).join(' · '),
                ),
                onTap: () => Navigator.pop(ctx, w.bookingId),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (picked != null) onPin(picked);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crm = context.crmColors;
    final key = (
      at: at.toUtc().toIso8601String(),
      // one meal, or several joined with commas ("breakfast,lunch,dinner")
      meal: meals.join(','),
      employeeId: employeeId ?? '',
      bookingId: pinnedBookingId ?? '',
      excludeId: excludeExpenseId ?? '',
    );
    final async = ref.watch(mealPreviewProvider(key));

    Widget box(Widget child, {Color? color}) => Container(
      key: const Key('mealPlacement'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(
        color: (color ?? crm.primary).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (color ?? crm.primary).withValues(alpha: 0.22),
        ),
      ),
      child: child,
    );

    return async.when(
      loading: () => box(
        Row(
          children: [
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Checking which work this meal is for…',
                style: TextStyle(fontSize: 12.5, color: crm.textSecondary),
              ),
            ),
          ],
        ),
      ),
      error: (e, _) => box(
        Text(
          "Couldn't check which work this is for (${friendlyErrorMessage(e)}). You can still save it — Accounts will place it.",
          style: TextStyle(fontSize: 12.5, color: crm.textSecondary),
        ),
        color: crm.warning,
      ),
      data: (preview) {
        if (preview.works.isEmpty) {
          return box(
            Text(
              'You have no work on this day, so Accounts will place this meal.',
              style: TextStyle(fontSize: 12.5, color: crm.textSecondary),
            ),
            color: crm.warning,
          );
        }
        final pinned = pinnedBookingId == null
            ? null
            : preview.workById(pinnedBookingId);
        final auto = preview.workById(preview.suggestion.bookingId);
        final work = pinned ?? auto;
        final isChosen = pinned != null;
        // The limit is for the meals being entered, widened by any bill already filed that spans them.
        final poolMeals = (preview.team?.meals.isNotEmpty ?? false) ? orderMeals(preview.team!.meals) : meals;
        final poolKey = poolMeals.join('+');
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _placement(context, crm, preview, work, isChosen, box),
            // What the team's meal comes to — filled in, with quick ways to change it.
            _TeamAmountPicker(
              team: preview.team,
              meal: meals.join('+'),
              amount: amount,
              onAuto: onAutoAmount,
              onUse: onUseAmount,
            ),
            // The team's limit for this meal, checked against the amount as it is typed.
            if (preview.team != null && (amount ?? 0) > 0) ...[
              const SizedBox(height: 8),
              TeamLimitBanner(
                check: TeamMealCheck.compute(
                  preview.team!,
                  amount!,
                  meal: poolKey,
                  meals: poolMeals,
                ),
                meal: poolKey,
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _placement(
    BuildContext context,
    CrmTheme crm,
    MealPreview preview,
    DayWorkBrief? work,
    bool isChosen,
    Widget Function(Widget child, {Color? color}) box,
  ) {
    return box(
      Row(
        children: [
          Icon(Icons.link_rounded, size: 18, color: crm.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isChosen
                      ? 'Counted under (your choice)'
                      : 'Will be counted under',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                    color: crm.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  work == null
                      ? 'Another day\'s work'
                      : '${work.customerName.isEmpty ? 'Work' : work.customerName}  ·  ${workWhen(work)}',
                  key: const Key('mealPlacementWork'),
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: crm.textPrimary,
                  ),
                ),
                // How far the work is — Accounts judges the amount by it.
                if (work != null && work.travelDistanceKm > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      travelDistanceText(work.travelDistanceKm),
                      key: const Key('mealPlacementDistance'),
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: crm.textSecondary,
                      ),
                    ),
                  ),
                if (!isChosen && preview.suggestion.isLast)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'Covers ${_mealsInWords(meals)} — counted under the last work of the day.',
                      key: const Key('mealPlacementLast'),
                      style: TextStyle(
                        fontSize: 11.5,
                        color: crm.textSecondary,
                      ),
                    ),
                  )
                else if (!isChosen && preview.suggestion.reason.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      preview.suggestion.reason,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: crm.textSecondary,
                      ),
                    ),
                  ),
                // What may be spent on this meal per head, and what that makes for the team.
                if (preview.allowance != null) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      preview.allowance!.heads > 0
                          ? '${isCombined ? 'Allowance (${mealsLabel(meals)})' : 'Allowance'}: ${_rupees(preview.allowance!.amountPerHead)} per head × ${preview.allowance!.heads} ${preview.allowance!.heads == 1 ? 'head' : 'heads'} = ${_rupees(preview.allowance!.teamAllowance)}'
                          : '${isCombined ? 'Allowance (${mealsLabel(meals)})' : 'Allowance'}: ${_rupees(preview.allowance!.amountPerHead)} per head',
                      key: const Key('mealAllowanceHint'),
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: crm.textPrimary,
                      ),
                    ),
                  ),
                  if (work != null &&
                      work.serviceStart != null &&
                      work.serviceStart!.toLocal().hour < 8 &&
                      meals.contains('breakfast'))
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              '🌅 Early start before 8 AM — ₹250 allowance applied',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFFD97706),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
                if (!isChosen && preview.suggestion.isFar)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'This is more than 4 hours from your nearest work — check the time.',
                      key: const Key('mealPlacementFar'),
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: crm.warning,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (preview.works.length > 1)
                TextButton(
                  key: const Key('mealPlacementChange'),
                  onPressed: () => _choose(context, preview),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Text('Change'),
                ),
              if (isChosen)
                TextButton(
                  key: const Key('mealPlacementAuto'),
                  onPressed: () => onPin(null),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Text('Automatic'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The amount for the meal worked out from the team: N heads × the allowance per head. Tells the
/// form (once per change of work / meal / team) so it can fill the field, and offers the choices a
/// team actually has — the whole team's meal, just the artist's own share, or what is left of it.
class _TeamAmountPicker extends StatefulWidget {
  final TeamMealState? team;
  final String meal;
  final double? amount;
  final ValueChanged<double?>? onAuto;
  final ValueChanged<double>? onUse;
  const _TeamAmountPicker({
    required this.team,
    required this.meal,
    required this.amount,
    required this.onAuto,
    required this.onUse,
  });

  @override
  State<_TeamAmountPicker> createState() => _TeamAmountPickerState();
}

class _TeamAmountPickerState extends State<_TeamAmountPicker> {
  TeamAmount? get _t => TeamAmount.of(widget.team);

  /// Changes with the work, the meal and the sum, so the form hears about each new answer once.
  String get _key => '${widget.team?.workId}|${widget.meal}|${_t?.suggested}';

  @override
  void initState() {
    super.initState();
    _tell();
  }

  @override
  void didUpdateWidget(covariant _TeamAmountPicker old) {
    super.didUpdateWidget(old);
    final was =
        '${old.team?.workId}|${old.meal}|${TeamAmount.of(old.team)?.suggested}';
    if (was != _key) _tell();
  }

  void _tell() {
    final onAuto = widget.onAuto;
    if (onAuto == null) return;
    final suggested = _t?.suggested;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) onAuto(suggested);
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = _t;
    if (t == null || widget.onUse == null) return const SizedBox.shrink();
    final crm = context.crmColors;
    final typed = widget.amount == null ? null : (widget.amount! * 100).round();
    bool isTyped(double v) => typed != null && typed == (v * 100).round();

    Widget chip(String key, String label, double value) => ChoiceChip(
      key: Key(key),
      label: Text(label),
      selected: isTyped(value),
      onSelected: (_) => widget.onUse!(value),
      visualDensity: VisualDensity.compact,
    );

    final solo = t.heads == 1;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            solo
                ? 'You are the only one on this work'
                : 'Team of ${t.heads} — ${t.heads} × ${_rupees(t.perHead)} = ${_rupees(t.whole)}',
            key: const Key('teamAmountLine'),
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: crm.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              if (solo)
                chip(
                  'teamAmountWhole',
                  'Allowance ${_rupees(t.whole)}',
                  t.whole,
                )
              else ...[
                if (t.someoneLogged && t.left > 0)
                  chip(
                    'teamAmountLeft',
                    'What\'s left ${_rupees(t.left)}',
                    t.left,
                  ),
                chip(
                  'teamAmountWhole',
                  'Whole team ${_rupees(t.whole)}',
                  t.whole,
                ),
                chip(
                  'teamAmountMe',
                  'Just me ${_rupees(t.perHead)}',
                  t.perHead,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// "Team limit exceeded" — or how much of it is left — for the amount being entered:
/// lunch for 3 heads at ₹150 = ₹450; already logged ₹300 + this ₹200 = ₹500 → ₹50 over.
class TeamLimitBanner extends StatelessWidget {
  final TeamMealCheck check;
  final String meal;
  const TeamLimitBanner({super.key, required this.check, required this.meal});

  static String rupees(double v) => _rupees(v);

  /// "3 heads × ₹150 = ₹450"
  static String limitText(TeamMealCheck c) =>
      '${c.heads} ${c.heads == 1 ? 'head' : 'heads'} × ${_rupees(c.allowancePerHead ?? 0)} = ${_rupees(c.limit ?? 0)}';

  @override
  Widget build(BuildContext context) {
    if (!check.isOver && !check.isWithin) return const SizedBox.shrink();
    final crm = context.crmColors;
    final over = check.isOver;
    final color = over ? crm.destructive : crm.success;
    final name = mealLabel(meal).isEmpty ? 'This meal' : mealLabel(meal);
    final logged = check.alreadySpent > 0
        ? 'Already logged ${_rupees(check.alreadySpent)} + this ${_rupees(check.thisAmount)} = ${_rupees(check.total)}'
        : 'This ${_rupees(check.thisAmount)}';

    return Container(
      key: Key(over ? 'teamLimitOver' : 'teamLimitWithin'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.4),
          width: over ? 1.4 : 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            over ? Icons.warning_amber_rounded : Icons.check_circle_outline,
            size: 20,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  over
                      ? 'Team limit exceeded by ${_rupees(check.over)}'
                      : 'Within the team limit — ${_rupees(check.left)} left',
                  key: const Key('teamLimitTitle'),
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$name limit for the team: ${limitText(check)}.',
                  key: const Key('teamLimitLimit'),
                  style: TextStyle(fontSize: 12, color: crm.textPrimary),
                ),
                Text(
                  '$logged.',
                  key: const Key('teamLimitSum'),
                  style: TextStyle(fontSize: 12, color: crm.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
