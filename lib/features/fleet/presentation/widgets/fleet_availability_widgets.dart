import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/allocation/data/allocation_models.dart';
import 'package:nizan_crm/features/allocation/presentation/widgets/artist_conflict_dialog.dart'
    show showArtistConflictDialog;
import 'package:nizan_crm/features/bookings/controllers/booking_provider.dart';
import 'package:nizan_crm/features/bookings/data/booking.dart';
import 'package:nizan_crm/features/bookings/data/driver_day.dart';
import 'package:nizan_crm/features/fleet/data/fleet_availability.dart';

/// free | tight | busy | unavailable → the colour it is drawn in.
Color availabilityColor(CrmTheme crm, String status) => switch (status) {
  'free' => crm.success,
  'tight' => crm.warning,
  'busy' => crm.destructive,
  'unavailable' => crm.destructive,
  _ => crm.textSecondary,
};

String availabilityLabel(String status) => switch (status) {
  'free' => 'Free',
  'tight' => 'Tight',
  'busy' => 'Busy',
  'unavailable' => 'Unavailable',
  _ => status,
};

/// A small coloured "Free / Tight / Busy / Unavailable".
class AvailabilityPill extends StatelessWidget {
  final String status;
  const AvailabilityPill({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final color = availabilityColor(context.crmColors, status);
    return Container(
      key: Key('availability_$status'),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        availabilityLabel(status),
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

String _day(String iso) =>
    iso.isEmpty ? '' : DateFormat('d MMM').format(DateTime.parse(iso));

/// A line for each thing wrong with (or worth knowing about) the driver / vehicle picked.
class AvailabilityNote extends StatelessWidget {
  final ResourceAvailability? resource;
  const AvailabilityNote({super.key, required this.resource});

  @override
  Widget build(BuildContext context) {
    final r = resource;
    if (r == null || (r.conflicts.isEmpty && r.warnings.isEmpty)) {
      return const SizedBox.shrink();
    }
    final crm = context.crmColors;
    final color = availabilityColor(
      crm,
      r.status == 'free' ? 'tight' : r.status,
    );
    Widget line(AvailabilityProblem p, {required bool warning}) => Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            warning ? Icons.info_outline_rounded : Icons.warning_amber_rounded,
            size: 14,
            color: warning ? crm.textSecondary : color,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              [
                if (p.day.isNotEmpty && (p.isOverlap || p.isTight)) _day(p.day),
                p.text,
              ].where((x) => x.isNotEmpty).join(' · '),
              style: TextStyle(
                fontSize: 12,
                height: 1.3,
                color: warning ? crm.textSecondary : crm.textPrimary,
                fontWeight: warning ? FontWeight.w500 : FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
    return Container(
      key: Key('availabilityNote_${r.id}'),
      width: double.infinity,
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final p in r.conflicts) line(p, warning: false),
          for (final p in r.warnings) line(p, warning: true),
        ],
      ),
    );
  }
}

/// "Assign anyway?" — what the server found when a driver / vehicle was put on a work. True = assign anyway.
Future<bool> showFleetConflictDialog(
  BuildContext context,
  FleetConflict conflict,
) async {
  final answer = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      final crm = ctx.crmColors;
      return AlertDialog(
        key: const Key('fleetConflictDialog'),
        icon: Icon(
          Icons.warning_amber_rounded,
          color: crm.destructive,
          size: 32,
        ),
        title: const Text('Already committed'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final p in conflict.problems)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          p.resource == 'driver'
                              ? Icons.person_outline
                              : Icons.directions_car_outlined,
                          size: 18,
                          color: crm.destructive,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: '${p.name}\n',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                TextSpan(
                                  text: [
                                    if (p.day.isNotEmpty && p.isOverlap)
                                      _day(p.day),
                                    p.text,
                                  ].where((x) => x.isNotEmpty).join(' · '),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                for (final p in conflict.warnings)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      p.text,
                      style: TextStyle(fontSize: 12, color: crm.textSecondary),
                    ),
                  ),
                Text(
                  'Assigning them anyway puts both works at risk. Only do it if you know it can work (for example, both works are at the same venue).',
                  style: TextStyle(fontSize: 12.5, color: crm.textSecondary),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            key: const Key('fleetConflictCancel'),
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Choose another'),
          ),
          FilledButton(
            key: const Key('fleetConflictAssign'),
            style: FilledButton.styleFrom(backgroundColor: crm.destructive),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Assign anyway'),
          ),
        ],
      );
    },
  );
  return answer == true;
}

/// Saves a booking. If the server refuses a driver / vehicle because it is already committed (or
/// unavailable), asks "assign anyway?" and — only if the answer is yes — saves again with confirmation.
/// Returns the saved booking, or null when the person chose not to assign. Any other failure is thrown
/// as before, for the caller to show.
///
/// One driver per artist per day: if the artist's other works that day have another driver, the
/// server asks first (409 DRIVER_DAY_CONFLICT) — "move them too?"; after the save, the works that
/// got the driver too (or were left alone, and why) are shown.
///
/// An artist the server refuses for a booking (ARTIST_CONFLICT) is asked about the same way.
Future<Booking?> updateBookingConfirmingFleet(
  BuildContext context,
  WidgetRef ref,
  Booking booking, {
  Map<String, dynamic>? allocationIntent,
}) async {
  var confirmFleet = false;
  var confirmDriverDay = false;
  var confirmArtist = false;
  // At most one question of each kind, then a final save.
  for (var attempt = 0; attempt < 4; attempt++) {
    try {
      final saved = await ref
          .read(bookingProvider.notifier)
          .updateBooking(
            booking,
            confirmFleetConflict: confirmFleet,
            confirmDriverDay: confirmDriverDay,
            confirmArtistConflict: confirmArtist,
            extraBody: allocationIntent == null ? null : {'allocationIntent': allocationIntent},
          );
      final result = saved.driverDay;
      if (result != null && context.mounted) {
        await showDriverDayResultDialog(context, result);
      }
      return saved;
    } catch (error) {
      final fleet = FleetConflict.of(error);
      final day = DriverDayConflict.of(error);
      final artist = AllocationRefusal.of(error);
      if (fleet != null && !confirmFleet) {
        if (!context.mounted) return null;
        if (!await showFleetConflictDialog(context, fleet)) return null;
        confirmFleet = true;
      } else if (day != null && !confirmDriverDay) {
        if (!context.mounted) return null;
        if (!await showDriverDayConflictDialog(context, day)) return null;
        confirmDriverDay = true;
      } else if (artist != null && artist.isConflict && !confirmArtist) {
        if (!context.mounted) return null;
        if (!await showArtistConflictDialog(context, artist)) return null;
        confirmArtist = true;
      } else {
        rethrow;
      }
    }
  }
  return null;
}

String _workTime(DriverDayWork w) {
  final at = w.serviceStart;
  final day = w.day.isEmpty ? '' : _day(w.day);
  if (at == null) return day;
  return [day, DateFormat('h:mm a').format(at)].where((x) => x.isNotEmpty).join(', ');
}

Widget _workLine(BuildContext context, DriverDayWork w, String note, {IconData icon = Icons.event_note_outlined}) {
  final crm = context.crmColors;
  return Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: crm.textSecondary),
        const SizedBox(width: 8),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: w.label.isNotEmpty ? w.label : w.customerName,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                TextSpan(
                  text: [_workTime(w), note].where((x) => x.isNotEmpty).map((x) => '\n$x').join(),
                  style: TextStyle(fontSize: 12.5, color: crm.textSecondary),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

/// "Move them too?" — the artist's other works that day have another driver. True = move them.
Future<bool> showDriverDayConflictDialog(
  BuildContext context,
  DriverDayConflict conflict,
) async {
  final driver = conflict.driverName.isNotEmpty ? conflict.driverName : 'this driver';
  final answer = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      final crm = ctx.crmColors;
      return AlertDialog(
        key: const Key('driverDayConflictDialog'),
        icon: Icon(Icons.swap_horiz_rounded, color: crm.warning, size: 32),
        title: const Text('Same driver for the whole day'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "One driver covers all of the artist's works in a day. "
                  '${conflict.works.length == 1 ? 'This work has' : 'These works have'} another driver now:',
                ),
                const SizedBox(height: 12),
                for (final w in conflict.works)
                  _workLine(ctx, w, 'Driver now: ${w.driverName}', icon: Icons.person_outline),
                Text(
                  'Move ${conflict.works.length == 1 ? 'it' : 'them'} to $driver too?',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            key: const Key('driverDayConflictCancel'),
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('driverDayConflictMove'),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Move to $driver'),
          ),
        ],
      );
    },
  );
  return answer == true;
}

/// What the save did to the artist's other works that day.
Future<void> showDriverDayResultDialog(
  BuildContext context,
  DriverDayResult result,
) {
  final driver = result.driverName.isNotEmpty ? result.driverName : 'the driver';
  return showDialog<void>(
    context: context,
    builder: (ctx) {
      final crm = ctx.crmColors;
      return AlertDialog(
        key: const Key('driverDayResultDialog'),
        icon: Icon(Icons.directions_car_outlined, color: crm.success, size: 32),
        title: Text(result.removed ? 'Driver removed for the day' : 'Driver set for the whole day'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (result.assigned.isNotEmpty) ...[
                  Text(
                    result.removed
                        ? "Also removed from the artist's other works that day:"
                        : "Also assigned to $driver — the artist's other works that day:",
                  ),
                  const SizedBox(height: 10),
                  for (final w in result.assigned)
                    _workLine(
                      ctx,
                      w,
                      w.driverName.isNotEmpty && !result.removed ? 'Was: ${w.driverName}' : '',
                      icon: Icons.check_circle_outline,
                    ),
                ],
                if (result.skipped.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  const Text('Not changed:', style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  for (final w in result.skipped)
                    _workLine(ctx, w, w.reasonText, icon: Icons.info_outline_rounded),
                ],
                for (final warning in result.warnings)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      warning,
                      style: TextStyle(fontSize: 12.5, color: crm.destructive),
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          FilledButton(
            key: const Key('driverDayResultOk'),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      );
    },
  );
}
