import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/features/bookings/data/booking.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/allocation/data/allocation_models.dart';
import 'package:nizan_crm/features/bookings/controllers/booking_provider.dart';
import 'package:nizan_crm/features/fleet/data/fleet_availability.dart';
import 'package:nizan_crm/features/fleet/presentation/widgets/fleet_availability_widgets.dart' show showFleetConflictDialog;

/// "Assign anyway?" — the server refused an artist because she is already on another work then, on leave, or out of slots (backend
/// middleware/artistAssignmentGuard.js, or the allocation's confirm). True only when the person chose to go ahead.
Future<bool> showArtistConflictDialog(BuildContext context, AllocationRefusal r) async {
  final crm = context.crmColors;
  final answer = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      icon: Icon(Icons.event_busy_rounded, color: crm.warning),
      title: const Text('Assign anyway?'),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (final p in (r.problems.isEmpty ? [r.message] : r.problems))
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.error_outline_rounded, size: 16, color: crm.destructive),
                const SizedBox(width: 6),
                Expanded(child: Text(p, key: const Key('artist_conflict_problem'), style: TextStyle(fontSize: 13.5, color: crm.textPrimary))),
              ]),
            ),
          for (final w in r.warnings)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.info_outline_rounded, size: 15, color: crm.warning),
                const SizedBox(width: 6),
                Expanded(child: Text(w, style: TextStyle(fontSize: 12.5, color: crm.textSecondary))),
              ]),
            ),
          const SizedBox(height: 6),
          Text('Assigning anyway is recorded, and a slot past her day goes to the Artist Head to OK.', style: TextStyle(fontSize: 12, color: crm.textSecondary)),
        ]),
      ),
      actions: [
        TextButton(key: const Key('artist_conflict_cancel'), onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(key: const Key('artist_conflict_confirm'), style: FilledButton.styleFrom(backgroundColor: crm.warning), onPressed: () => Navigator.pop(context, true), child: const Text('Assign anyway')),
      ],
    ),
  );
  return answer == true;
}

/// Saves a booking; when the server refuses a driver / vehicle (FLEET_CONFLICT) or an artist (ARTIST_CONFLICT), asks "assign anyway?"
/// and — only on a yes — saves again with that confirmation (both, one after the other, when both apply). [allocationIntent] — what the
/// Manage Booking "Suggest team" chose, recorded with the save. Null when the person chose not to assign.
Future<Booking?> saveBookingConfirmingConflicts(BuildContext context, WidgetRef ref, Booking booking, {Map<String, dynamic>? allocationIntent}) async {
  var fleet = false;
  var artist = false;
  for (var attempt = 0; attempt < 3; attempt++) {
    try {
      return await ref.read(bookingProvider.notifier).updateBooking(booking, confirmFleetConflict: fleet, confirmArtistConflict: artist, extraBody: allocationIntent == null ? null : {'allocationIntent': allocationIntent});
    } catch (error) {
      final fc = FleetConflict.of(error);
      if (fc != null && !fleet) {
        if (!context.mounted || !await showFleetConflictDialog(context, fc)) return null;
        fleet = true;
        continue;
      }
      final ac = AllocationRefusal.of(error);
      if (ac != null && ac.isConflict && !artist) {
        if (!context.mounted || !await showArtistConflictDialog(context, ac)) return null;
        artist = true;
        continue;
      }
      rethrow;
    }
  }
  return null;
}
