import '../models/booking.dart';
import '../models/employee.dart';
import '../models/service_package.dart';

Future<void> downloadDashboardReport({
  required DateTime month,
  required List<Booking> bookings,
  required List<ServicePackage> packages,
  required List<Employee> employees,
}) {
  throw UnsupportedError('Dashboard PDF export is only available on web.');
}
