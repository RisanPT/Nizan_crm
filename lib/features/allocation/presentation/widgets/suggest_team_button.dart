import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/core/auth/access_control.dart';
import 'package:nizan_crm/core/models/employee.dart';
import 'package:nizan_crm/core/providers/auth_provider.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/allocation/presentation/widgets/allocation_sheet.dart';
import 'package:nizan_crm/features/allocation/services/allocation_service.dart';
import 'package:nizan_crm/features/bookings/data/assignment_rules.dart';
import 'package:nizan_crm/features/bookings/data/booking.dart';

/// Manage Booking's "Suggest team": shown only for a NEW booking (made or confirmed after the allocation went live), with suggestions on,
/// to someone who may allocate. The chosen team fills the assignment form; the save sends what was chosen (allocationIntent).
class SuggestTeamButton extends ConsumerWidget {
  const SuggestTeamButton({super.key, required this.bookingId, required this.unitKey, required this.onPicked});
  final String bookingId, unitKey;
  final void Function(AllocationPick pick) onPicked;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (bookingId.isEmpty || !Access.of(ref.watch(authSessionProvider)).canAllocateArtists) return const SizedBox.shrink();
    final settings = ref.watch(allocationSettingsProvider).value;
    if (settings == null || !settings.suggest || !settings.canAllocate) return const SizedBox.shrink();
    final a = ref.watch(bookingAllocationProvider(bookingId)).value;
    if (a == null || !a.eligible || a.units.every((u) => u.unitKey != unitKey)) return const SizedBox.shrink();
    final crm = context.crmColors;
    final top = a.units.firstWhere((u) => u.unitKey == unitKey).recommended;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: OutlinedButton.icon(
        key: const Key('suggest_team'),
        style: OutlinedButton.styleFrom(foregroundColor: crm.primary, side: BorderSide(color: crm.primary.withValues(alpha: 0.5))),
        onPressed: () async {
          final pick = await pickTeamFor(context, bookingId: bookingId, unitKey: unitKey);
          if (pick != null) onPicked(pick);
        },
        icon: const Icon(Icons.auto_awesome_outlined, size: 18),
        label: Text(top == null ? 'Suggest team' : 'Suggest team · ${top.teamName}'),
      ),
    );
  }
}

/// The form's team with [pick] put on: the lead and her assistants replace the old lead and assistants; drivers and associates stay.
List<BookingAssignment> withPickedTeam(List<BookingAssignment> current, AllocationPick pick, List<Employee> staff) {
  final byId = {for (final e in staff) e.id: e};
  final keep = current.where((a) => a.roleType == 'driver' || (byId[a.employeeId]?.isAssociate ?? false)).toList();
  final keepIds = keep.map((a) => a.employeeId).toSet();
  BookingAssignment entry(String id, String name, String type) {
    final e = byId[id];
    if (e != null) return assignmentFor(e, type);
    return BookingAssignment(employeeId: id, artistName: name, role: type == 'lead' ? 'Lead Artist' : 'Assistant', type: '', roleType: type);
  }

  return [
    if (!keepIds.contains(pick.lead.id)) entry(pick.lead.id, pick.lead.name, 'lead'),
    for (final x in pick.assistants)
      if (!keepIds.contains(x.id) && x.id != pick.lead.id) entry(x.id, x.name, 'assistant'),
    ...keep,
  ];
}
