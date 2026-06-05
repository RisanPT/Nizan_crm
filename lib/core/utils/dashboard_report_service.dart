import '../models/artist_collection.dart';
import '../models/lead.dart';
import '../models/booking.dart';
import '../models/employee.dart';
import '../models/service_package.dart';
import '../models/district.dart';
import 'dashboard_report_service_stub.dart'
    if (dart.library.io) 'dashboard_report_service_mobile.dart'
    if (dart.library.html) 'dashboard_report_service_web.dart' as impl;

Future<void> downloadDashboardReport({
  required DateTime month,
  required List<Booking> bookings,
  required List<ServicePackage> packages,
  required List<Employee> employees,
  String reportType = 'executive',
  List<Lead> leads = const [],
  List<ArtistCollection> collections = const [],
  bool useEventDate = false,
  DateTime? startDate,
  DateTime? endDate,
  List<District> districts = const [],
  String? activeFilters,
}) {
  return impl.downloadDashboardReport(
    month: month,
    bookings: bookings,
    packages: packages,
    employees: employees,
    reportType: reportType,
    leads: leads,
    collections: collections,
    useEventDate: useEventDate,
    startDate: startDate,
    endDate: endDate,
    districts: districts,
    activeFilters: activeFilters,
  );
}

Future<void> downloadLeadsReport({
  required List<Lead> leads,
  String statusFilter = 'All',
  String sourceFilter = 'All',
  String searchQuery = '',
}) {
  return impl.downloadLeadsReport(
    leads: leads,
    statusFilter: statusFilter,
    sourceFilter: sourceFilter,
    searchQuery: searchQuery,
  );
}
