import 'package:flutter/material.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/bookings/data/booking.dart';
import 'package:nizan_crm/features/fleet/data/vehicle.dart';
import 'package:nizan_crm/features/fleet/data/vehicle_categories.dart';

/// People going to the work besides the driver (artists + assistants), counting
/// each person once.
int teamSizeOf(List<BookingAssignment> staff) => {
      for (final s in staff)
        if (s.roleType != 'driver' && s.employeeId.isNotEmpty) s.employeeId,
    }.length;

/// "XL · 6 seats" for a vehicle in a picker ('' when neither is recorded).
String vehicleCapacityLabel(Vehicle v) {
  final parts = [
    if (v.category.isNotEmpty) vehicleCategoryShortLabel(v.category),
    if (v.seats > 0) '${v.seats} seats',
  ];
  return parts.isEmpty ? '' : ' · ${parts.join(' · ')}';
}

/// Under the vehicle picker: does the team fit, and what category suits it?
///   sedan / taxi → up to 4,  XL → up to 6,  MPV → up to 7,  Tempo Traveller → up to 12.
class VehicleCapacityHint extends StatelessWidget {
  final int people;
  final Vehicle? vehicle;
  const VehicleCapacityHint({super.key, required this.people, required this.vehicle});

  @override
  Widget build(BuildContext context) {
    if (people <= 0) return const SizedBox.shrink();
    final c = context.crmColors;
    final suggestion = suggestVehicleCategory(people);
    final suits = suggestion.needsMultiple
        ? 'This team is too big for one vehicle — it needs more than one.'
        : 'Suits a ${suggestion.category.label} (${suggestion.category.seats} seats).';

    late final IconData icon;
    late final Color color;
    late final String text;
    final v = vehicle;
    final fits = v == null ? null : seatsFit(v.seats, people);
    if (v == null) {
      icon = Icons.groups_outlined;
      color = c.textSecondary;
      text = 'Team of $people. $suits';
    } else if (fits == true) {
      icon = Icons.check_circle_outline;
      color = c.success;
      text = 'Team of $people fits — ${v.name} has ${v.seats} seats.';
    } else if (fits == false) {
      icon = Icons.warning_amber_rounded;
      color = c.destructive;
      text = 'Team of $people won\'t fit — ${v.name} has ${v.seats} seats. $suits';
    } else {
      icon = Icons.info_outline;
      color = c.warning;
      text = 'Team of $people. ${v.name}\'s seat count isn\'t recorded — set it in Fleet Vehicles. $suits';
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Expanded(child: Text(text, style: TextStyle(fontSize: 12, color: color, height: 1.35))),
        ],
      ),
    );
  }
}
