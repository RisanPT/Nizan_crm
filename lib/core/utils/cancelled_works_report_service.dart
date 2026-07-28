import 'package:nizan_crm/features/bookings/data/booking.dart';

import 'cancelled_works_report_stub.dart'
    if (dart.library.io) 'cancelled_works_report_mobile.dart'
    if (dart.library.html) 'cancelled_works_report_web.dart' as impl;

/// Generates a printable "Cancelled Works" report.
///
/// On web this opens the browser print dialog (Save as PDF); on mobile it
/// builds a PDF and hands it to the OS share sheet.
Future<void> printCancelledWorksReport(
  List<Booking> cancelled, {
  String periodLabel = 'All time',
}) {
  return impl.printCancelledWorksReport(cancelled, periodLabel: periodLabel);
}
