import 'dart:typed_data';
import 'dart:js_interop';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:web/web.dart' as web;

import '../models/booking.dart';
import '../models/employee.dart';
import '../models/service_package.dart';

Future<void> downloadDashboardReport({
  required DateTime month,
  required List<Booking> bookings,
  required List<ServicePackage> packages,
  required List<Employee> employees,
}) async {
  final pdf = pw.Document();
  final report = _buildReport(month, bookings, packages, employees);

  pdf.addPage(
    pw.MultiPage(
      pageTheme: pw.PageTheme(
        margin: const pw.EdgeInsets.all(28),
        theme: pw.ThemeData.withFont(
          base: pw.Font.helvetica(),
          bold: pw.Font.helveticaBold(),
        ),
      ),
      build: (context) => [
        pw.Text(
          'Nizan CRM Dashboard Report',
          style: pw.TextStyle(
            fontSize: 24,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.blueGrey900,
          ),
        ),
        pw.SizedBox(height: 6),
        pw.Text(
          'Reporting Month: ${_monthLabel(month)}',
          style: const pw.TextStyle(
            fontSize: 12,
            color: PdfColors.blueGrey700,
          ),
        ),
        pw.SizedBox(height: 18),
        pw.Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _metricCard('Total Works', '${report.totalWorks}'),
            _metricCard('Completed Works', '${report.completedWorks}'),
            _metricCard('Cancelled Works', '${report.cancelledWorks}'),
            _metricCard(
              'Forecast Amount',
              'INR ${report.forecastAmount.toStringAsFixed(0)}',
            ),
          ],
        ),
        pw.SizedBox(height: 22),
        _sectionTitle('Daily Revenue Overview'),
        _dailyRevenueTable(report.dailyRevenue),
        pw.SizedBox(height: 22),
        _sectionTitle('Top Services'),
        _serviceTable(report.topServices),
        pw.SizedBox(height: 22),
        _sectionTitle('Top Staff'),
        _staffTable(report.topStaff),
        pw.SizedBox(height: 22),
        _sectionTitle('Pending Booking Requests'),
        _bookingTable(report.pendingBookings),
        pw.SizedBox(height: 22),
        _sectionTitle('Upcoming Bookings'),
        _bookingTable(report.upcomingBookings),
      ],
    ),
  );

  final bytes = await pdf.save();
  _downloadPdf(
    bytes,
    fileName:
        'dashboard-report-${month.year}-${month.month.toString().padLeft(2, '0')}.pdf',
  );
}

void _downloadPdf(Uint8List bytes, {required String fileName}) {
  final blob = web.Blob(
    [bytes.toJS].toJS,
    web.BlobPropertyBag(type: 'application/pdf'),
  );
  final objectUrl = web.URL.createObjectURL(blob);
  final anchor = web.document.createElement('a') as web.HTMLAnchorElement
    ..href = objectUrl
    ..download = fileName
    ..style.display = 'none';

  web.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  web.URL.revokeObjectURL(objectUrl);
}

pw.Widget _metricCard(String label, String value) {
  return pw.Container(
    width: 120,
    padding: const pw.EdgeInsets.all(12),
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: PdfColors.blueGrey100),
      borderRadius: pw.BorderRadius.circular(10),
      color: PdfColors.grey50,
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label,
          style: const pw.TextStyle(fontSize: 10, color: PdfColors.blueGrey600),
        ),
        pw.SizedBox(height: 8),
        pw.Text(
          value,
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
        ),
      ],
    ),
  );
}

pw.Widget _sectionTitle(String title) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 10),
    child: pw.Text(
      title,
      style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
    ),
  );
}

pw.Widget _dailyRevenueTable(List<_DailyRevenueMetric> rows) {
  return pw.TableHelper.fromTextArray(
    headers: const ['Day', 'Bookings', 'Revenue'],
    data: rows
        .map(
          (row) => [
            row.dayLabel,
            '${row.bookingsCount}',
            'INR ${row.revenue.toStringAsFixed(0)}',
          ],
        )
        .toList(),
    border: pw.TableBorder.all(color: PdfColors.blueGrey100),
    headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
    headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
    cellAlignment: pw.Alignment.centerLeft,
    cellPadding: const pw.EdgeInsets.all(8),
  );
}

pw.Widget _serviceTable(List<_ServiceMetric> rows) {
  return pw.TableHelper.fromTextArray(
    headers: const ['Service', 'Bookings', 'Price'],
    data: rows
        .map(
          (row) => [
            row.name,
            '${row.bookingsCount}',
            'INR ${row.amount.toStringAsFixed(0)}',
          ],
        )
        .toList(),
    border: pw.TableBorder.all(color: PdfColors.blueGrey100),
    headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
    headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
    cellPadding: const pw.EdgeInsets.all(8),
  );
}

pw.Widget _staffTable(List<_StaffMetric> rows) {
  return pw.TableHelper.fromTextArray(
    headers: const ['Staff', 'Role', 'Appointments'],
    data: rows
        .map(
          (row) => [
            row.name,
            row.role,
            '${row.appointmentsCount}',
          ],
        )
        .toList(),
    border: pw.TableBorder.all(color: PdfColors.blueGrey100),
    headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
    headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
    cellPadding: const pw.EdgeInsets.all(8),
  );
}

pw.Widget _bookingTable(List<Booking> rows) {
  return pw.TableHelper.fromTextArray(
    headers: const ['Client', 'Service', 'Date', 'Status', 'Amount'],
    data: rows
        .map(
          (booking) => [
            booking.customerName,
            booking.service,
            _dateLabel(booking.serviceStart),
            booking.status,
            'INR ${booking.totalPrice.toStringAsFixed(0)}',
          ],
        )
        .toList(),
    border: pw.TableBorder.all(color: PdfColors.blueGrey100),
    headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
    headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
    cellPadding: const pw.EdgeInsets.all(8),
  );
}

_DashboardReport _buildReport(
  DateTime month,
  List<Booking> bookings,
  List<ServicePackage> packages,
  List<Employee> employees,
) {
  final monthBookings = bookings.where((booking) {
    return booking.serviceStart.year == month.year &&
        booking.serviceStart.month == month.month;
  }).toList();

  final activeBookings = monthBookings
      .where((booking) => booking.status.toLowerCase() != 'cancelled')
      .toList();
  final completedWorks = monthBookings
      .where((booking) => booking.status.toLowerCase() == 'completed')
      .length;
  final cancelledWorks = monthBookings
      .where((booking) => booking.status.toLowerCase() == 'cancelled')
      .length;
  final forecastAmount = activeBookings
      .where((booking) => booking.status.toLowerCase() != 'completed')
      .fold<double>(
        0,
        (sum, booking) =>
            sum +
            (booking.totalPrice - booking.advanceAmount - booking.discountAmount)
                .clamp(0, double.infinity),
      );

  final packageById = {for (final package in packages) package.id: package};
  final employeeById = {for (final employee in employees) employee.id: employee};

  final serviceGroups = <String, List<Booking>>{};
  for (final booking in activeBookings) {
    final key = booking.packageId.isNotEmpty
        ? booking.packageId
        : booking.service.trim().toLowerCase();
    serviceGroups.putIfAbsent(key, () => []).add(booking);
  }

  final topServices = serviceGroups.entries.map((entry) {
    final sample = entry.value.first;
    final matchedPackage = packageById[sample.packageId];
    return _ServiceMetric(
      name: matchedPackage?.name ?? sample.service,
      bookingsCount: entry.value.length,
      amount: matchedPackage?.price ?? sample.totalPrice,
    );
  }).toList()
    ..sort((a, b) => b.bookingsCount.compareTo(a.bookingsCount));

  final staffStats = <String, _StaffMetric>{};
  for (final booking in activeBookings) {
    for (final assignment in booking.assignedStaff) {
      if (assignment.employeeId.isEmpty) continue;
      final employee = employeeById[assignment.employeeId];
      final previous = staffStats[assignment.employeeId];
      final role = employee?.specialization.trim().isNotEmpty == true
          ? employee!.specialization.trim()
          : assignment.works.isNotEmpty
              ? assignment.works.join(', ')
              : assignment.role;
      staffStats[assignment.employeeId] = _StaffMetric(
        name: employee?.name ?? assignment.artistName,
        role: role.isEmpty ? 'Assigned Staff' : role,
        appointmentsCount: (previous?.appointmentsCount ?? 0) + 1,
      );
    }
  }
  final topStaff = staffStats.values.toList()
    ..sort((a, b) => b.appointmentsCount.compareTo(a.appointmentsCount));

  final dailyMap = <int, _DailyRevenueMetric>{};
  for (final booking in activeBookings) {
    final day = booking.serviceStart.day;
    final previous = dailyMap[day];
    dailyMap[day] = _DailyRevenueMetric(
      dayLabel: '$day ${_monthShort(month.month)}',
      bookingsCount: (previous?.bookingsCount ?? 0) + 1,
      revenue: (previous?.revenue ?? 0) + booking.totalPrice,
    );
  }
  final dailyRevenue = dailyMap.entries.map((entry) => entry.value).toList()
    ..sort((a, b) => _extractDay(a.dayLabel).compareTo(_extractDay(b.dayLabel)));

  final pendingBookings = monthBookings
      .where((booking) => booking.status.toLowerCase() == 'pending')
      .toList()
    ..sort((a, b) => a.serviceStart.compareTo(b.serviceStart));

  final upcomingBookings = bookings
      .where((booking) => !booking.serviceStart.isBefore(DateTime.now()))
      .toList()
    ..sort((a, b) => a.serviceStart.compareTo(b.serviceStart));

  return _DashboardReport(
    totalWorks: activeBookings.length,
    completedWorks: completedWorks,
    cancelledWorks: cancelledWorks,
    forecastAmount: forecastAmount,
    topServices: topServices.take(5).toList(),
    topStaff: topStaff.take(5).toList(),
    dailyRevenue: dailyRevenue,
    pendingBookings: pendingBookings.take(10).toList(),
    upcomingBookings: upcomingBookings.take(10).toList(),
  );
}

String _monthLabel(DateTime date) => '${_monthName(date.month)} ${date.year}';

String _monthName(int month) {
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return months[month - 1];
}

String _monthShort(int month) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return months[month - 1];
}

String _dateLabel(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')} ${_monthShort(date.month)} ${date.year}';

int _extractDay(String dayLabel) =>
    int.tryParse(dayLabel.split(' ').first) ?? 0;

class _DashboardReport {
  final int totalWorks;
  final int completedWorks;
  final int cancelledWorks;
  final double forecastAmount;
  final List<_ServiceMetric> topServices;
  final List<_StaffMetric> topStaff;
  final List<_DailyRevenueMetric> dailyRevenue;
  final List<Booking> pendingBookings;
  final List<Booking> upcomingBookings;

  const _DashboardReport({
    required this.totalWorks,
    required this.completedWorks,
    required this.cancelledWorks,
    required this.forecastAmount,
    required this.topServices,
    required this.topStaff,
    required this.dailyRevenue,
    required this.pendingBookings,
    required this.upcomingBookings,
  });
}

class _ServiceMetric {
  final String name;
  final int bookingsCount;
  final double amount;

  const _ServiceMetric({
    required this.name,
    required this.bookingsCount,
    required this.amount,
  });
}

class _StaffMetric {
  final String name;
  final String role;
  final int appointmentsCount;

  const _StaffMetric({
    required this.name,
    required this.role,
    required this.appointmentsCount,
  });
}

class _DailyRevenueMetric {
  final String dayLabel;
  final int bookingsCount;
  final double revenue;

  const _DailyRevenueMetric({
    required this.dayLabel,
    required this.bookingsCount,
    required this.revenue,
  });
}
