import '../models/booking.dart';
import '../models/employee.dart';
import '../models/service_package.dart';
import 'dashboard_report_service_stub.dart'
    if (dart.library.html) 'dashboard_report_service_web.dart' as impl;

Future<void> downloadDashboardReport({
  required DateTime month,
  required List<Booking> bookings,
  required List<ServicePackage> packages,
  required List<Employee> employees,
}) {
  return impl.downloadDashboardReport(
    month: month,
    bookings: bookings,
    packages: packages,
    employees: employees,
  );
}
