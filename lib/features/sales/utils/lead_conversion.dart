import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:nizan_crm/features/sales/data/lead.dart';

/// True when [lead] is in a stage that can still be converted into a booking.
/// Already-Converted, Lost, or pending-lost leads shouldn't offer conversion.
bool canConvertLead(Lead lead) =>
    lead.status != 'Converted' &&
    lead.status != 'Lost' &&
    lead.status != 'Pending Lost Approval';

/// The `/booking/add` route that converts [lead] into a booking. We forward the
/// customer details we already know (name, phone, email, address, pincode) plus
/// `leadId`, so the Add Booking screen opens pre-filled and the salesperson only
/// has to pick the package and the event date(s). On save, the backend links the
/// new booking to this lead and flips it to Converted (see linkLeadsToBooking).
String leadToBookingRoute(Lead lead) {
  final email = lead.email?.trim() ?? '';
  // A not-yet-converted lead usually has no `address` (that's filled from the
  // booking on conversion) — fall back to the town in `location`.
  final address =
      lead.address.trim().isNotEmpty ? lead.address.trim() : lead.location.trim();
  final params = <String, String>{
    'mode': 'single',
    'leadId': lead.id,
    'name': lead.name,
    'phone': lead.phone,
    if (email.isNotEmpty) 'email': email,
    if (address.isNotEmpty) 'address': address,
    if (lead.pincode.trim().isNotEmpty) 'pincode': lead.pincode.trim(),
  };
  return Uri(path: '/booking/add', queryParameters: params).toString();
}

/// Opens the pre-filled Add Booking screen for converting [lead].
void convertLeadToBooking(BuildContext context, Lead lead) {
  context.push(leadToBookingRoute(lead));
}
