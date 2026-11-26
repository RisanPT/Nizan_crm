import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:nizan_crm/core/auth/access_control.dart';
import 'package:nizan_crm/core/providers/auth_provider.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/allocation/data/allocation_models.dart';
import 'package:nizan_crm/features/allocation/presentation/widgets/allocation_sheet.dart';
import 'package:nizan_crm/features/allocation/services/allocation_service.dart';

// AUTOMATIC ALLOCATION, as people see it: right after a booking is saved / a request accepted, which team the system gave it to (or
// why it waits for CRM) — the salespeople included; and the same, read-only, on Manage Booking.

String _dayText(String day) {
  final d = DateTime.tryParse(day);
  return d == null ? day : DateFormat('EEE d MMM').format(d);
}

/// "Bridal Makeup · Sat 12 Dec, 10:30 AM · Kozhikode"
String unitWhenText(AllocationUnitStatus u) {
  final d = u.days.isEmpty ? null : u.days.first;
  return [
    if (u.label.isNotEmpty) u.label,
    if (d != null) '${_dayText(d.day)}${d.start.isEmpty ? '' : ', ${fmtHHMM(d.start)}'}${u.days.length > 1 ? ' (+${u.days.length - 1} day${u.days.length > 2 ? 's' : ''})' : ''}',
    if (d != null && d.place.isNotEmpty) d.place,
  ].join(' · ');
}

/// One package's line: who has it (and how), or why it waits.
class AllocationUnitLine extends StatelessWidget {
  const AllocationUnitLine({super.key, required this.unit, this.showWhen = true});
  final AllocationUnitStatus unit;
  final bool showWhen;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final u = unit;
    final (icon, color, head) = u.assigned
        ? (Icons.check_circle_rounded, crm.success, u.teamName.isEmpty ? (u.lead.isEmpty ? 'Artist assigned' : u.lead) : u.teamName)
        : u.status == 'waiting_approval'
            ? (Icons.more_time_rounded, crm.warning, '${u.teamName.isEmpty ? 'An extra slot' : u.teamName} — waiting for the Artist Head')
            : (Icons.hourglass_top_rounded, crm.warning, 'Waiting for CRM to assign the artist');
    final sub = <String>[
      if (u.assigned && u.people.isNotEmpty) u.people,
      if (u.assigned && u.howText.isNotEmpty) u.howText,
    ].join(' · ');
    final reason = u.assigned ? u.reason : u.reason.replaceFirst(RegExp(r'^Waiting for CRM — '), '');
    return Padding(
      key: Key('alloc_unit_${u.unitKey}'),
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.only(top: 1), child: Icon(icon, size: 20, color: color)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (showWhen && unitWhenText(u).isNotEmpty) Text(unitWhenText(u), style: TextStyle(fontSize: 12, color: crm.textSecondary)),
            Text(head, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: crm.textPrimary)),
            if (sub.isNotEmpty) Text(sub, style: TextStyle(fontSize: 13, color: crm.textPrimary)),
            if (reason.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 2), child: Text(reason, key: Key('alloc_reason_${u.unitKey}'), style: TextStyle(fontSize: 12.5, color: crm.textSecondary))),
          ]),
        ),
      ]),
    );
  }
}

/// After a booking is saved (or a request accepted) with automatic allocation on: shows who got it, or that it waits for CRM and why.
/// Someone who may allocate can open the allocation from here ("Allocate now" / "Change team"). → false when automatic allocation
/// doesn't apply to this booking (off, or a booking from before go-live) — the caller then does what it did before.
Future<bool> showBookingAllocationResult(BuildContext context, WidgetRef ref, {required String bookingId}) async {
  final access = Access.of(ref.read(authSessionProvider));
  if (bookingId.isEmpty || !access.canSeeBookingAllocation) return false;
  BookingAllocationStatus status;
  try {
    status = await ref.read(allocationServiceProvider).bookingStatus(bookingId);
  } catch (_) {
    return false; // can't be read: nothing extra to show
  }
  // automatic allocation's result — or a 4th work on a full date that waits for the Artist Head's OK
  final fourth = status.units.any((u) => u.status == 'waiting_approval');
  if ((!status.auto && !fourth) || !status.eligible || status.units.isEmpty || !context.mounted) return false;
  final canAllocate = access.canAllocateArtists;
  final action = await showDialog<String>(
    context: context,
    builder: (ctx) => BookingAllocationResultDialog(status: status, canAllocate: canAllocate),
  );
  if (action == 'allocate' && context.mounted) {
    await showAllocationSheet(context, bookingId: bookingId, source: 'board', primaryLabel: status.anyWaiting ? 'Allocate' : 'Change team');
  }
  ref.invalidate(bookingAllocationStatusProvider(bookingId));
  return true;
}

class BookingAllocationResultDialog extends StatelessWidget {
  const BookingAllocationResultDialog({super.key, required this.status, required this.canAllocate});
  final BookingAllocationStatus status;
  final bool canAllocate;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final title = status.allAssigned
        ? 'Artist assigned'
        : status.units.any((u) => u.status == 'waiting_approval')
            ? "Waiting for the Artist Head's OK"
        : status.units.every((u) => !u.assigned)
            ? 'Sent to CRM for the artist'
            : 'Artist allocation';
    return AlertDialog(
      key: const Key('alloc_result'),
      title: Text(title),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (status.bookingNumber.isNotEmpty) Text('#${status.bookingNumber}', style: TextStyle(fontSize: 12.5, color: crm.textSecondary, fontWeight: FontWeight.w600)),
            for (final u in status.units) AllocationUnitLine(unit: u),
            if (status.anyWaiting && !canAllocate)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('You will get a notification when CRM assigns the artist.', key: const Key('alloc_result_wait_note'), style: TextStyle(fontSize: 12.5, color: crm.textSecondary)),
              ),
          ]),
        ),
      ),
      actions: [
        if (canAllocate)
          TextButton(
            key: const Key('alloc_result_allocate'),
            onPressed: () => Navigator.pop(context, 'allocate'),
            child: Text(status.anyWaiting ? 'Allocate now' : 'Change team'),
          ),
        FilledButton(key: const Key('alloc_result_ok'), style: FilledButton.styleFrom(backgroundColor: crm.primary), onPressed: () => Navigator.pop(context), child: const Text('OK')),
      ],
    );
  }
}

/// Manage Booking: the booking's artist allocation, read-only (the salespeople see it too). Hidden when the allocation does not apply.
class BookingAllocationCard extends ConsumerWidget {
  const BookingAllocationCard({super.key, required this.bookingId});
  final String bookingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final access = Access.of(ref.watch(authSessionProvider));
    if (bookingId.isEmpty || !access.canSeeBookingAllocation) return const SizedBox.shrink();
    final st = ref.watch(bookingAllocationStatusProvider(bookingId)).value;
    if (st == null || !st.eligible || st.units.isEmpty) return const SizedBox.shrink();
    final crm = context.crmColors;
    return Container(
      key: const Key('booking_alloc_card'),
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: crm.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: crm.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('Artist allocation', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: crm.textPrimary))),
          if (access.canAllocateArtists && st.anyWaiting)
            FilledButton(
              key: const Key('booking_alloc_allocate'),
              style: FilledButton.styleFrom(backgroundColor: crm.primary, visualDensity: VisualDensity.compact),
              onPressed: () async {
                await showAllocationSheet(context, bookingId: bookingId, source: 'manage', primaryLabel: 'Allocate');
                ref.invalidate(bookingAllocationStatusProvider(bookingId));
              },
              child: const Text('Allocate'),
            ),
        ]),
        for (final u in st.units) AllocationUnitLine(unit: u, showWhen: st.units.length > 1),
      ]),
    );
  }
}
