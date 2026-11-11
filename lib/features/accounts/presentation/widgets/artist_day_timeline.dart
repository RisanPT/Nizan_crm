import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/core/utils/responsive_builder.dart';
import 'package:nizan_crm/features/accounts/controllers/expense_controller.dart';
import 'package:nizan_crm/features/accounts/data/artist_expense.dart' show kMeals, mealsLabel, periodLabel, travelDistanceText;
import 'package:nizan_crm/features/accounts/data/work_cost.dart';
import 'package:nizan_crm/features/accounts/presentation/widgets/list_common.dart' show rupeesWhole;

/// The IST calendar day of an instant, as the server reads it ('YYYY-MM-DD').
String istDay(DateTime t) => DateFormat('yyyy-MM-dd').format(t.toUtc().add(const Duration(hours: 5, minutes: 30)));

String _clock(DateTime? t) => t == null ? '' : DateFormat('h:mm a').format(t.toLocal());

const _categoryLabels = {'food': 'Food', 'travel': 'Travel', 'stay': 'Stay', 'materials': 'Materials', 'fuel': 'Fuel', 'other': 'Other'};

/// What a cost line is called: the meal and its time for food, else the category.
String costLineLabel(CostLine l) {
  if (l.isFood && l.effectiveMeals.isNotEmpty) return '${mealsLabel(l.effectiveMeals)} · ${_clock(l.at)}';
  return _categoryLabels[l.category] ?? l.category;
}

IconData costLineIcon(CostLine l) {
  // one meal: its icon; several meals on one bill: the plain cutlery
  if (l.isFood && l.effectiveMeals.length == 1) return kMeals.where((m) => m.$1 == l.effectiveMeals.first).map((m) => m.$3).firstOrNull ?? Icons.restaurant_outlined;
  if (l.isFood) return Icons.restaurant_outlined;
  return switch (l.category) {
    'travel' => Icons.directions_car_outlined,
    'stay' => Icons.hotel_outlined,
    'materials' => Icons.brush_outlined,
    'fuel' => Icons.local_gas_station_outlined,
    _ => Icons.receipt_long_outlined,
  };
}

/// One artist's day as a timeline: their works in time order and, under each, the costs that
/// belong to it — food by the time of the meal — then whatever could not be placed.
Future<void> showArtistDayTimeline(BuildContext context, {required String employeeId, required String day, String? artistName}) {
  final body = ArtistDayTimeline(employeeId: employeeId, day: day, artistName: artistName);
  if (ResponsiveBuilder.isMobile(context)) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, controller) => ArtistDayTimeline(employeeId: employeeId, day: day, artistName: artistName, scrollController: controller),
      ),
    );
  }
  return showDialog<void>(
    context: context,
    builder: (_) => Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 620, maxHeight: 760), child: body),
    ),
  );
}

class ArtistDayTimeline extends ConsumerWidget {
  final String employeeId;
  final String day;
  final String? artistName;
  final ScrollController? scrollController;

  const ArtistDayTimeline({super.key, required this.employeeId, required this.day, this.artistName, this.scrollController});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crm = context.crmColors;
    final async = ref.watch(artistDayProvider((employeeId: employeeId, day: day)));
    final dayText = DateFormat('EEE d MMM yyyy').format(DateTime.parse(day));

    return async.when(
      loading: () => const SizedBox(height: 220, child: Center(child: CircularProgressIndicator())),
      error: (e, _) => SizedBox(
        height: 260,
        child: AppErrorView(error: e, onRetry: () => ref.invalidate(artistDayProvider)),
      ),
      data: (d) {
        final name = d.employeeName.isNotEmpty ? d.employeeName : (artistName ?? 'Artist');
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                        Text(dayText, style: TextStyle(fontSize: 12.5, color: crm.textSecondary)),
                      ],
                    ),
                  ),
                  IconButton(onPressed: () => Navigator.of(context).maybePop(), icon: const Icon(Icons.close)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Wrap(spacing: 8, runSpacing: 6, children: [
                _pill(crm, 'Food', rupeesWhole(d.totals.food), crm.primary),
                _pill(crm, 'Other', rupeesWhole(d.totals.other), crm.accent),
                _pill(crm, 'Day total', rupeesWhole(d.totals.all), crm.success),
                if (d.totals.unplaced > 0) _pill(crm, 'Not placed', rupeesWhole(d.totals.unplaced), crm.warning, key: const Key('dayUnplacedPill')),
              ]),
            ),
            Flexible(
              child: d.works.isEmpty && d.unplaced.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(32),
                      child: Center(child: Text('No works or expenses on this day.', style: TextStyle(color: crm.textSecondary))),
                    )
                  : ListView(
                      controller: scrollController,
                      shrinkWrap: true,
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                      children: [
                        if (d.works.isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text('This artist had no work on this day.', key: const Key('dayNoWorks'), style: TextStyle(color: crm.textSecondary)),
                          ),
                        for (final w in d.works) _workBlock(context, crm, w),
                        if (d.unplaced.isNotEmpty) _unplacedBlock(crm, d.unplaced),
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _pill(CrmTheme crm, String label, String value, Color color, {Key? key}) => Container(
        key: key,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
        child: Text.rich(TextSpan(children: [
          TextSpan(text: '$label  ', style: TextStyle(fontSize: 11, color: crm.textSecondary, fontWeight: FontWeight.w600)),
          TextSpan(text: value, style: TextStyle(fontSize: 12.5, color: crm.textPrimary, fontWeight: FontWeight.w800)),
        ])),
      );

  Widget _workBlock(BuildContext context, CrmTheme crm, DayWork w) {
    final when = [_clock(w.serviceStart), _clock(w.serviceEnd)].where((x) => x.isNotEmpty).join(' – ');
    return Container(
      key: Key('dayWork_${w.bookingId}'),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: crm.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: crm.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            decoration: BoxDecoration(
              color: crm.primary.withValues(alpha: 0.06),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(w.customerName.isEmpty ? 'Work' : w.customerName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5)),
                      const SizedBox(height: 2),
                      Text(
                        [
                          if (w.outsideDay) 'From another day',
                          if (w.period.isNotEmpty) periodLabel(w.period),
                          if (when.isNotEmpty) when,
                          if (w.bookingNumber.isNotEmpty) w.bookingNumber,
                          if (w.service.isNotEmpty) w.service,
                        ].join('  ·  '),
                        style: TextStyle(fontSize: 11.5, color: crm.textSecondary),
                      ),
                      if (w.place.isNotEmpty)
                        Text(w.place, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: crm.textSecondary.withValues(alpha: 0.8))),
                      // how far the work is — to judge the day's spend by
                      if (w.travelDistanceKm > 0)
                        Text(travelDistanceText(w.travelDistanceKm), key: Key('dayWorkDistance_${w.bookingId}'), style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: crm.textSecondary)),
                    ],
                  ),
                ),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(rupeesWhole(w.total), key: Key('dayWorkTotal_${w.bookingId}'), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                  if (w.food > 0) Text('food ${rupeesWhole(w.food)}', style: TextStyle(fontSize: 10.5, color: crm.textSecondary)),
                ]),
              ],
            ),
          ),
          if (w.expenses.isEmpty)
            Padding(padding: const EdgeInsets.all(14), child: Text('Nothing spent under this work.', style: TextStyle(fontSize: 12, color: crm.textSecondary)))
          else
            for (final l in w.expenses) _line(crm, l),
        ],
      ),
    );
  }

  Widget _unplacedBlock(CrmTheme crm, List<CostLine> lines) => Container(
        key: const Key('dayUnplaced'),
        decoration: BoxDecoration(color: crm.warning.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(14), border: Border.all(color: crm.warning.withValues(alpha: 0.3))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
              child: Text('NOT PLACED UNDER A WORK', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 0.6, color: crm.warning)),
            ),
            for (final l in lines) _line(crm, l, showReason: true),
            const SizedBox(height: 4),
          ],
        ),
      );

  Widget _line(CrmTheme crm, CostLine l, {bool showReason = false}) {
    final struck = !l.counted;
    final statusColor = l.status == 'verified' ? crm.success : (l.status == 'rejected' ? crm.destructive : crm.warning);
    final note = showReason ? l.reason : (l.isFood && l.mode == 'pinned' ? 'Chosen by the artist' : (l.isFood ? l.reason : ''));
    return Padding(
      key: Key('costLine_${l.expenseId}'),
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(costLineIcon(l), size: 18, color: crm.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(costLineLabel(l), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, decoration: struck ? TextDecoration.lineThrough : null)),
                if (note.isNotEmpty) Text(note, style: TextStyle(fontSize: 11.5, color: crm.textSecondary)),
                if (l.isFar) Text('Check the time — far from any work', key: Key('costLineFar_${l.expenseId}'), style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: crm.warning)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(rupeesWhole(l.amount), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, decoration: struck ? TextDecoration.lineThrough : null)),
            Text(l.status == 'verified' ? 'Approved' : (l.status == 'rejected' ? 'Rejected' : 'Pending'), style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: statusColor)),
          ]),
        ],
      ),
    );
  }
}
