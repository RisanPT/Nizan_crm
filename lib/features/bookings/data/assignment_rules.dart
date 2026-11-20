import 'package:nizan_crm/core/models/employee.dart';
import 'package:nizan_crm/features/bookings/data/booking.dart';

// WHO CAN BE PUT ON A WORK'S TEAM, and how that assignment is written — the rules behind the LEAD / DRIVER / ASST / ASSOC. chips of the
// booking's Artist Assignment panel, kept here (not in the screen) so they can be tested.
//
//  • LEAD      an active artist (artistRole artist).
//  • DRIVER    a driver.
//  • ASST      an artist or assistant.
//  • ASSOC.    an ASSOCIATE: an outside artist (Employee.isAssociate) who works the event with the team and is paid per work through Artist
//              Payouts. Associates are picked — or added on the spot — under their own chip and are NOT offered as lead or assistant, so a
//              work's team shows clearly who is an associate. On the team an associate is the lead's assistant (roleType 'assistant').
// Someone already on the team is never offered again.

const kAssignmentTypes = ['lead', 'driver', 'assistant', 'associate'];

/// The people the dropdown of [type] offers: right kind, not already on the team, each once.
List<Employee> selectableStaff(List<Employee> staff, String type, List<BookingAssignment> assigned) {
  final taken = {for (final a in assigned) a.employeeId};
  final seen = <String>{};
  return [
    for (final e in staff)
      if (_fits(e, type) && !taken.contains(e.id) && seen.add(e.id)) e,
  ];
}

bool _fits(Employee e, String type) {
  final role = e.artistRole.toLowerCase();
  if (type == 'associate') return e.isAssociate;
  if (e.isAssociate) return false;
  if (type == 'lead') return role == 'artist';
  if (type == 'driver') return role == 'driver';
  return role == 'assistant' || role == 'artist';
}

/// How [e] is written on the team for [type]; [roleText] is what the person typed in the role box (e.g. "Hair").
BookingAssignment assignmentFor(Employee e, String type, {String roleText = ''}) {
  final typed = roleText.trim();
  final spec = e.specialization.trim();
  return BookingAssignment(
    employeeId: e.id,
    artistName: e.name,
    role: type == 'lead'
        ? 'Lead Artist'
        : type == 'driver'
            ? 'Driver'
            : (typed.isEmpty ? (type == 'associate' ? 'Associate' : 'Assistant') : typed),
    specialization: e.specialization,
    works: e.works.isNotEmpty
        ? e.works
        : [
            if (spec.isNotEmpty)
              spec
            else if (type == 'driver')
              'Driver',
          ],
    phone: e.phone,
    type: e.type,
    roleType: type == 'associate' ? 'assistant' : type,
  );
}

/// The ids of the associates among [staff] — for the ASSOCIATE badge on the assigned team.
Set<String> associateIdsOf(Iterable<Employee> staff) => {for (final e in staff) if (e.isAssociate) e.id};

// ── The Calendar's staff filter ──────────────────────────────────────────────────────────────────────────────────────────────────────
// The "All Staff" dropdown on the Calendar Scheduler: All Staff · Not Assigned · All Associates · one artist · one associate.
// An associate is found the same way an artist is — by employee id, on the booking or on any of its packages — so the filter and the
// monthly works report agree with the work's team panel.

/// The filter value for "every work that has an associate on it".
const kAssociatesFilter = 'associates';

bool _anyOnBooking(Booking b, bool Function(BookingAssignment) test) =>
    b.assignedStaff.any(test) || b.bookingItems.any((item) => item.assignedStaff.any(test));

/// Does [b] show under the staff [filter]? [associateIds] is everyone flagged as an associate (see [associateIdsOf]) — used by
/// [kAssociatesFilter]. Any other value is an employee id.
bool bookingMatchesStaffFilter(Booking b, String filter, Set<String> associateIds) {
  if (filter == 'all') return true;
  if (filter == 'unassigned') return !_anyOnBooking(b, (a) => a.artistName.trim().isNotEmpty);
  if (filter == kAssociatesFilter) {
    return associateIds.isNotEmpty && _anyOnBooking(b, (a) => associateIds.contains(a.employeeId));
  }
  return _anyOnBooking(b, (a) => a.employeeId == filter);
}

/// The people the associate report is about: every associate for [kAssociatesFilter], just that person for an associate's id, and
/// nobody (null) for any other filter — which is a plain works report.
Set<String>? associateFocus(String filter, Set<String> associateIds) {
  if (filter == kAssociatesFilter) return associateIds;
  if (associateIds.contains(filter)) return {filter};
  return null;
}

/// What the associate report's file name carries after the month: `associates` for all of them, `associate_<name>` for one person, and
/// nothing for a plain works report.
String associateReportFileTag(String filter, Iterable<Employee> staff) {
  if (filter == kAssociatesFilter) return 'associates';
  for (final e in staff) {
    if (e.id == filter && e.isAssociate) {
      final slug = e.name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_').replaceAll(RegExp(r'^_+|_+$'), '');
      return slug.isEmpty ? 'associate' : 'associate_$slug';
    }
  }
  return '';
}

/// The distinct names of the associates on [entries] (each person once, in the order they appear) — what the ASSOC badge on a calendar chip
/// shows and lists in its tooltip. Empty when no associate is on any of them.
List<String> associateNamesOn(Iterable<BookingDisplayEntry> entries, Set<String> associateIds) {
  final seen = <String>{};
  final names = <String>[];
  for (final e in entries) {
    for (final a in e.assignedStaff) {
      final name = a.artistName.trim();
      if (name.isNotEmpty && associateIds.contains(a.employeeId) && seen.add(a.employeeId)) names.add(name);
    }
  }
  return names;
}
