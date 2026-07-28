import 'package:nizan_crm/models/customer.dart';

import 'client_report_service_stub.dart'
    if (dart.library.io) 'client_report_service_mobile.dart'
    if (dart.library.html) 'client_report_service_web.dart' as impl;

/// Generates a printable "all client details" report.
///
/// On web this opens the browser print dialog (Save as PDF); on mobile it
/// builds a PDF and hands it to the OS share sheet.
Future<void> printClientsReport(List<Customer> clients) {
  return impl.printClientsReport(clients);
}
