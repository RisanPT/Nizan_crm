import 'package:nizan_crm/features/accounts/data/artist_collection.dart';
import '../models/lead.dart';
import '../models/booking.dart';
import '../models/employee.dart';
import '../models/service_package.dart';
import '../models/district.dart';
import '../models/crm_user.dart';

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
}) async {
  throw UnsupportedError('Dashboard PDF export is only available on web.');
}

Future<void> downloadLeadsReport({
  required List<Lead> leads,
  String statusFilter = 'All',
  String sourceFilter = 'All',
  String searchQuery = '',
  List<CrmUser> users = const [],
}) async {
  throw UnsupportedError('Leads PDF export is only available on web.');
}
