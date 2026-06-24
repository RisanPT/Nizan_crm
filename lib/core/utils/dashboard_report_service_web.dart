import 'dart:typed_data';
import 'dart:js_interop';

import 'package:flutter/services.dart' show rootBundle;

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:web/web.dart' as web;

import '../models/artist_collection.dart';
import '../models/lead.dart';
import '../models/booking.dart';
import '../models/employee.dart';
import '../models/service_package.dart';
import '../models/district.dart';
import '../models/crm_user.dart';

// Cache for report logo bytes to avoid redundant asset loading
Uint8List? _cachedLogoBytes;

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
  if (_cachedLogoBytes == null) {
    final logoData = await rootBundle.load('assets/images/teamn_logo.png');
    _cachedLogoBytes = logoData.buffer.asUint8List();
  }
  final logoImage = pw.MemoryImage(_cachedLogoBytes!);

  final pdf = pw.Document();
  final report = _buildReport(
    month,
    bookings,
    packages,
    employees,
    useEventDate: useEventDate,
    startDate: startDate,
    endDate: endDate,
    reportType: reportType,
  );

  pdf.addPage(
    pw.MultiPage(
      pageTheme: pw.PageTheme(
        margin: const pw.EdgeInsets.all(28),
        theme: pw.ThemeData.withFont(
          base: pw.Font.helvetica(),
          bold: pw.Font.helveticaBold(),
        ),
      ),
      build: (context) {
        final title = switch (reportType) {
          'sales' => 'Team N CRM Sales Report',
          'marketing' => 'Team N CRM Marketing Report',
          'crm' => 'Team N CRM Client Relations Report',
          'finance' => 'Team N CRM Finance Report',
          'ceo_daily' => 'DAILY SALES REPORT | Team N Makeovers',
          'forecast' => 'Team N CRM Sales Forecast Report',
          _ => reportType.startsWith('month_end_cashflow') ? 'Month End Cash Flow Report' : 'Team N CRM Executive Overview',
        };

        return [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Image(logoImage, width: 40, height: 40),
              pw.SizedBox(width: 12),
              pw.Text(
                title,
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blueGrey900,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            reportType == 'ceo_daily'
                ? 'Report Date: ${_dateLabel(DateTime.now())}'
                : (startDate != null && endDate != null)
                    ? 'Reporting Period: ${_dateLabel(startDate)} - ${_dateLabel(endDate)}'
                    : 'Reporting Period: ${_monthLabel(month)}',
            style: const pw.TextStyle(
              fontSize: 12,
              color: PdfColors.blueGrey700,
            ),
          ),
          if (activeFilters != null && activeFilters.isNotEmpty) ...[
            pw.SizedBox(height: 4),
            pw.Text(
              'Active Filters: $activeFilters',
              style: pw.TextStyle(
                fontSize: 10,
                color: PdfColors.blueGrey600,
                fontStyle: pw.FontStyle.italic,
              ),
            ),
          ],
          pw.SizedBox(height: 18),

          if (reportType == 'executive' || reportType == 'sales') ...[
            pw.Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _metricCard('Total Sales', 'INR ${report.totalSales.toStringAsFixed(0)}'),
                _metricCard('Advance Collected', 'INR ${report.totalAdvance.toStringAsFixed(0)}'),
                _metricCard('Total Discounts', 'INR ${report.totalDiscount.toStringAsFixed(0)}'),
                _metricCard(
                  'Forecast Amount',
                  'INR ${report.forecastAmount.toStringAsFixed(0)}',
                ),
                _metricCard('Total Works', '${report.totalWorks}'),
                _metricCard('Completed Works', '${report.completedWorks}'),
                _metricCard('Cancelled Works', '${report.cancelledWorks}'),
              ],
            ),
            pw.SizedBox(height: 22),
            _sectionTitle('Daily Revenue Overview'),
            _dailyRevenueTable(report.dailyRevenue),
          ],

          if (reportType == 'forecast') ...[
            pw.Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _metricCard('Active Works', '${report.totalWorks}'),
                _metricCard('Forecast Amount', 'INR ${report.forecastAmount.toStringAsFixed(0)}'),
              ],
            ),
            pw.SizedBox(height: 22),
            _sectionTitle('Pending Collections (Forecast)'),
            _bookingTable(report.pendingBookings, districts),
            pw.SizedBox(height: 22),
            _sectionTitle('Upcoming Bookings'),
            _bookingTable(report.upcomingBookings, districts),
          ],

          if (reportType == 'executive' || reportType == 'marketing') ...[
            pw.SizedBox(height: 22),
            _sectionTitle('Top Services Performance'),
            _serviceTable(report.topServices),
          ],

          if (reportType == 'executive' || reportType == 'crm') ...[
            pw.SizedBox(height: 22),
            _sectionTitle('Top Staff Performance'),
            _staffTable(report.topStaff),
          ],

          if (reportType == 'executive' ||
              reportType == 'sales' ||
              reportType == 'crm') ...[
            pw.SizedBox(height: 22),
            _sectionTitle('Monthly Bookings Ledger'),
            _bookingTable(report.monthBookingsList, districts),
          ],

          if (reportType == 'finance') ...[
            pw.SizedBox(height: 22),
            _sectionTitle('Financial Summary'),
            _dailyRevenueTable(report.dailyRevenue),
            pw.SizedBox(height: 22),
            _sectionTitle('Expense Overview'),
            pw.Text(
              'Detailed expense breakdown is available in the Accounts module.',
            ),
          ],

          if (reportType == 'ceo_daily') ...[
            pw.SizedBox(height: 22),
            _sectionTitle('Daily Performance Metrics'),
            _metricCard('Total Leads', '${leads.length}'),
            pw.SizedBox(height: 22),
            _sectionTitle('Recent Collections'),
            _bookingTable(report.todaysBookings, districts),
            pw.SizedBox(height: 22),
            _sectionTitle('Detailed Sales Records'),
            _bookingTable(report.todaysBookings, districts),
          ],

          if (reportType.startsWith('month_end_cashflow')) ...[
            pw.Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                if (reportType == 'month_end_cashflow_All' || reportType == 'month_end_cashflow_Advance')
                  _metricCard('Advances Collected', 'INR ${report.cashFlowAdvances.toStringAsFixed(0)}'),
                if (reportType == 'month_end_cashflow_All' || reportType == 'month_end_cashflow_Collection')
                  _metricCard('Balances Collected', 'INR ${report.cashFlowCurrentEvents.toStringAsFixed(0)}'),
                _metricCard('Total Inflow (Filtered)', 'INR ${report.cashFlowTotal.toStringAsFixed(0)}'),
              ],
            ),
            pw.SizedBox(height: 22),
            _sectionTitle('Cash Flow Ledger'),
            _cashFlowTable(report.cashFlowTransactions, districts),
          ],
        ];
      },
    ),
  );

  final bytes = await pdf.save();
  _downloadPdf(
    bytes,
    fileName:
        '$reportType-report-${month.year}-${month.month.toString().padLeft(2, '0')}.pdf',
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
  final List<List<dynamic>> dataList = rows
      .map<List<dynamic>>(
        (row) => <dynamic>[
          row.dayLabel,
          '${row.bookingsCount}',
          'INR ${row.revenue.toStringAsFixed(0)}',
        ],
      )
      .toList();

  if (rows.isNotEmpty) {
    final totalBookings = rows.fold<int>(0, (sum, row) => sum + row.bookingsCount);
    final totalRevenue = rows.fold<double>(0.0, (sum, row) => sum + row.revenue);
    dataList.add(<dynamic>[
      pw.Text('Total', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
      pw.Text('$totalBookings', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
      pw.Text('INR ${totalRevenue.toStringAsFixed(0)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
    ]);
  }

  return pw.TableHelper.fromTextArray(
    headers: const ['Day', 'Bookings', 'Revenue'],
    data: dataList,
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
        .map((row) => [row.name, row.role, '${row.appointmentsCount}'])
        .toList(),
    border: pw.TableBorder.all(color: PdfColors.blueGrey100),
    headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
    headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
    cellPadding: const pw.EdgeInsets.all(8),
  );
}

pw.Widget _cashFlowTable(List<_CashFlowTransaction> rows, List<District> districts) {
  final List<List<dynamic>> dataList = rows.map((tx) {
    String displayDistrict = tx.booking.district.trim();
    if (displayDistrict.isEmpty && tx.booking.districtId.isNotEmpty && districts.isNotEmpty) {
      try {
        final matched = districts.firstWhere((d) => d.id == tx.booking.districtId);
        if (matched.name.isNotEmpty) {
          displayDistrict = matched.name.trim();
        }
      } catch (_) {}
    }
    if (displayDistrict.isEmpty) {
      displayDistrict = tx.booking.region.trim();
    }
    return <dynamic>[
      _dateLabel(tx.date),
      tx.clientName,
      tx.booking.phone,
      tx.booking.service,
      displayDistrict,
      tx.type,
      'INR ${tx.amount.toStringAsFixed(0)}',
    ];
  }).toList();

  if (rows.isNotEmpty) {
    final totalAmount = rows.fold<double>(0.0, (sum, tx) => sum + tx.amount);
    dataList.add(<dynamic>[
      pw.Text('Total', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
      '',
      '',
      '',
      '',
      '',
      pw.Text('INR ${totalAmount.toStringAsFixed(0)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
    ]);
  }

  return pw.TableHelper.fromTextArray(
    headers: const [
      'Date',
      'Client',
      'Phone',
      'Service',
      'District',
      'Transaction Type',
      'Amount',
    ],
    data: dataList,
    border: pw.TableBorder.all(color: PdfColors.blueGrey100),
    headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
    cellStyle: const pw.TextStyle(fontSize: 8),
    headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
    cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 6),
  );
}

pw.Widget _bookingTable(List<Booking> rows, List<District> districts) {
  final List<List<dynamic>> dataList = rows
      .map<List<dynamic>>(
        (booking) {
          String displayDistrict = booking.district.trim();
          if (displayDistrict.isEmpty && booking.districtId.isNotEmpty && districts.isNotEmpty) {
            try {
              final matched = districts.firstWhere(
                (d) => d.id == booking.districtId,
              );
              if (matched.name.isNotEmpty) {
                displayDistrict = matched.name.trim();
              }
            } catch (_) {}
          }
          if (displayDistrict.isEmpty) {
            displayDistrict = booking.region.trim();
          }

          return <dynamic>[
            booking.customerName,
            booking.phone,
            booking.service,
            displayDistrict,
            _dateLabel(booking.createdAt ?? booking.bookingDate),
            _dateLabel(booking.serviceStart),
            booking.status.toUpperCase(),
            'INR ${booking.advanceAmount.toStringAsFixed(0)}',
            'INR ${booking.discountAmount.toStringAsFixed(0)}',
            'INR ${booking.totalPrice.toStringAsFixed(0)}',
            'INR ${((booking.totalPrice - booking.advanceAmount - booking.discountAmount).clamp(0, double.infinity)).toStringAsFixed(0)}',
          ];
        },
      )
      .toList();

  if (rows.isNotEmpty) {
    final totalAdvance = rows.fold<double>(0.0, (sum, row) => sum + row.advanceAmount);
    final totalDiscount = rows.fold<double>(0.0, (sum, row) => sum + row.discountAmount);
    final totalPrice = rows.fold<double>(0.0, (sum, row) => sum + row.totalPrice);
    final totalBalance = rows.fold<double>(0.0, (sum, row) => sum + (row.totalPrice - row.advanceAmount - row.discountAmount).clamp(0, double.infinity));
    dataList.add(<dynamic>[
      pw.Text('Total', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
      '',
      '',
      '',
      '',
      '',
      '',
      pw.Text('INR ${totalAdvance.toStringAsFixed(0)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
      pw.Text('INR ${totalDiscount.toStringAsFixed(0)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
      pw.Text('INR ${totalPrice.toStringAsFixed(0)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
      pw.Text('INR ${totalBalance.toStringAsFixed(0)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
    ]);
  }

  return pw.TableHelper.fromTextArray(
    headers: const [
      'Client',
      'Phone',
      'Service',
      'District',
      'Booked',
      'Event',
      'Status',
      'Advance',
      'Discount',
      'Total',
      'Balance',
    ],
    data: dataList,
    border: pw.TableBorder.all(color: PdfColors.blueGrey100),
    headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7),
    cellStyle: const pw.TextStyle(fontSize: 7),
    headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
    cellPadding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 6),
  );
}

_DashboardReport _buildReport(
  DateTime month,
  List<Booking> bookings,
  List<ServicePackage> packages,
  List<Employee> employees, {
  bool useEventDate = false,
  DateTime? startDate,
  DateTime? endDate,
  String reportType = '',
}) {
  final monthBookings = bookings.where((booking) {
    final date = useEventDate
        ? booking.serviceStart
        : (booking.createdAt ?? booking.bookingDate);
    if (startDate != null && endDate != null) {
      return !date.isBefore(startDate) && !date.isAfter(endDate);
    }
    return date.year == month.year && date.month == month.month;
  }).toList();

  final activeBookings = monthBookings
      .where((booking) => booking.status.toLowerCase() != 'cancelled' && booking.status.toLowerCase() != 'rejected')
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
            (booking.totalPrice -
                    booking.advanceAmount -
                    booking.discountAmount)
                .clamp(0, double.infinity),
      );
  final totalSales = activeBookings.fold<double>(0, (sum, b) => sum + b.totalPrice);
  final totalDiscount = activeBookings.fold<double>(0, (sum, b) => sum + b.discountAmount);
  final totalAdvance = activeBookings.fold<double>(0, (sum, b) => sum + b.advanceAmount);

  final packageById = {for (final package in packages) package.id: package};
  final employeeById = {
    for (final employee in employees) employee.id: employee,
  };

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
  }).toList()..sort((a, b) => b.bookingsCount.compareTo(a.bookingsCount));

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

  final dailyMap = <String, _DailyRevenueMetric>{};
  final isMultiMonth = startDate != null && endDate != null;
  for (final booking in activeBookings) {
    final date = useEventDate
        ? booking.serviceStart
        : (booking.createdAt ?? booking.bookingDate);
    final key = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final previous = dailyMap[key];
    dailyMap[key] = _DailyRevenueMetric(
      dayLabel: isMultiMonth
          ? '${date.day} ${_monthShort(date.month)} ${date.year}'
          : '${date.day} ${_monthShort(date.month)}',
      bookingsCount: (previous?.bookingsCount ?? 0) + 1,
      revenue: (previous?.revenue ?? 0) + booking.totalPrice,
      date: DateTime(date.year, date.month, date.day),
    );
  }
  final dailyRevenue = dailyMap.entries.map((entry) => entry.value).toList()
    ..sort((a, b) => a.date.compareTo(b.date));

  final pendingBookings =
      monthBookings
          .where((booking) => booking.status.toLowerCase() == 'pending')
          .toList()
        ..sort(
          (a, b) =>
              (useEventDate ? a.serviceStart : (a.createdAt ?? a.bookingDate))
                  .compareTo(
                    useEventDate
                        ? b.serviceStart
                        : (b.createdAt ?? b.bookingDate),
                  ),
        );

  final upcomingBookings =
      bookings.where((booking) {
        final date = useEventDate
            ? booking.serviceStart
            : (booking.createdAt ?? booking.bookingDate);
        return !date.isBefore(DateTime.now());
      }).toList()..sort(
        (a, b) =>
            (useEventDate ? a.serviceStart : (a.createdAt ?? a.bookingDate))
                .compareTo(
                  useEventDate
                      ? b.serviceStart
                      : (b.createdAt ?? b.bookingDate),
                ),
      );

  final todaysBookings =
      bookings.where((booking) {
        final date = useEventDate
            ? booking.serviceStart
            : (booking.createdAt ?? booking.bookingDate);
        final now = DateTime.now();
        return date.year == now.year &&
            date.month == now.month &&
            date.day == now.day;
      }).toList()..sort(
        (a, b) =>
            (useEventDate ? a.serviceStart : (a.createdAt ?? a.bookingDate))
                .compareTo(
                  useEventDate
                      ? b.serviceStart
                      : (b.createdAt ?? b.bookingDate),
                ),
      );

  final completedBookingsList =
      monthBookings
          .where((booking) => booking.status.toLowerCase() == 'completed')
          .toList()
        ..sort(
          (a, b) =>
              (useEventDate ? a.serviceStart : (a.createdAt ?? a.bookingDate))
                  .compareTo(
                    useEventDate
                        ? b.serviceStart
                        : (b.createdAt ?? b.bookingDate),
                  ),
        );

  final monthBookingsList = List<Booking>.from(monthBookings)
    ..sort(
      (a, b) => (useEventDate ? a.serviceStart : (a.createdAt ?? a.bookingDate))
          .compareTo(
            useEventDate ? b.serviceStart : (b.createdAt ?? b.bookingDate),
          ),
    );

  double cashFlowAdvances = 0;
  double cashFlowCurrentEvents = 0;
  List<_CashFlowTransaction> cashFlowTransactions = [];

  if (reportType.startsWith('month_end_cashflow')) {
    bool includeAdvance = reportType == 'month_end_cashflow_All' || reportType == 'month_end_cashflow_Advance';
    bool includeCollection = reportType == 'month_end_cashflow_All' || reportType == 'month_end_cashflow_Collection';

    for (final booking in bookings) {
      if (booking.status.toLowerCase() == 'cancelled' || booking.status.toLowerCase() == 'rejected') continue;
      
      final bDate = booking.createdAt ?? booking.bookingDate;
      final eDate = booking.serviceStart;
      
      bool bookedThisMonth = bDate.year == month.year && bDate.month == month.month;
      bool eventThisMonth = eDate.year == month.year && eDate.month == month.month;

      if (bookedThisMonth && booking.advanceAmount > 0 && includeAdvance) {
        cashFlowAdvances += booking.advanceAmount;
        cashFlowTransactions.add(_CashFlowTransaction(
          date: bDate,
          clientName: booking.customerName,
          type: 'Advance Amount',
          amount: booking.advanceAmount,
          booking: booking,
        ));
      }
      
      if (eventThisMonth && booking.status.toLowerCase() == 'completed' && includeCollection) {
        double balance = (booking.totalPrice - booking.advanceAmount - booking.discountAmount).clamp(0, double.infinity);
        if (balance > 0) {
          cashFlowCurrentEvents += balance;
          cashFlowTransactions.add(_CashFlowTransaction(
            date: eDate,
            clientName: booking.customerName,
            type: 'Collection Amount (Balance)',
            amount: balance,
            booking: booking,
          ));
        }
      } else if (eventThisMonth && booking.status.toLowerCase() != 'completed' && includeCollection) {
        double balance = (booking.totalPrice - booking.advanceAmount - booking.discountAmount).clamp(0, double.infinity);
        if (balance > 0) {
          cashFlowCurrentEvents += balance;
          cashFlowTransactions.add(_CashFlowTransaction(
            date: eDate,
            clientName: booking.customerName,
            type: 'Collection Amount (Balance)',
            amount: balance,
            booking: booking,
          ));
        }
      }
    }
    cashFlowTransactions.sort((a, b) => a.date.compareTo(b.date));
  }

  return _DashboardReport(
    totalWorks: activeBookings.length,
    completedWorks: completedWorks,
    cancelledWorks: cancelledWorks,
    forecastAmount: forecastAmount,
    totalSales: totalSales,
    totalDiscount: totalDiscount,
    totalAdvance: totalAdvance,
    topServices: topServices.take(5).toList(),
    topStaff: topStaff.take(5).toList(),
    dailyRevenue: dailyRevenue,
    pendingBookings: pendingBookings.take(10).toList(),
    upcomingBookings: upcomingBookings.take(10).toList(),
    todaysBookings: todaysBookings,
    completedBookingsList: completedBookingsList,
    monthBookingsList: monthBookingsList,
    cashFlowTotal: cashFlowAdvances + cashFlowCurrentEvents,
    cashFlowAdvances: cashFlowAdvances,
    cashFlowCurrentEvents: cashFlowCurrentEvents,
    cashFlowTransactions: cashFlowTransactions,
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


class _DashboardReport {
  final int totalWorks;
  final int completedWorks;
  final int cancelledWorks;
  final double forecastAmount;
  final double totalSales;
  final double totalDiscount;
  final double totalAdvance;
  final List<_ServiceMetric> topServices;
  final List<_StaffMetric> topStaff;
  final List<_DailyRevenueMetric> dailyRevenue;
  final List<Booking> pendingBookings;
  final List<Booking> upcomingBookings;
  final List<Booking> todaysBookings;
  final List<Booking> completedBookingsList;
  final List<Booking> monthBookingsList;

  final double cashFlowTotal;
  final double cashFlowAdvances;
  final double cashFlowCurrentEvents;
  final List<_CashFlowTransaction> cashFlowTransactions;

  const _DashboardReport({
    required this.totalWorks,
    required this.completedWorks,
    required this.cancelledWorks,
    required this.forecastAmount,
    required this.totalSales,
    required this.totalDiscount,
    required this.totalAdvance,
    required this.topServices,
    required this.topStaff,
    required this.dailyRevenue,
    required this.pendingBookings,
    required this.upcomingBookings,
    required this.todaysBookings,
    required this.completedBookingsList,
    required this.monthBookingsList,
    this.cashFlowTotal = 0,
    this.cashFlowAdvances = 0,
    this.cashFlowCurrentEvents = 0,
    this.cashFlowTransactions = const [],
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
  final DateTime date;

  const _DailyRevenueMetric({
    required this.dayLabel,
    required this.bookingsCount,
    required this.revenue,
    required this.date,
  });
}

class _CashFlowTransaction {
  final DateTime date;
  final String clientName;
  final String type;
  final double amount;
  final Booking booking;

  const _CashFlowTransaction({
    required this.date,
    required this.clientName,
    required this.type,
    required this.amount,
    required this.booking,
  });
}

Future<void> downloadLeadsReport({
  required List<Lead> leads,
  String statusFilter = 'All',
  String sourceFilter = 'All',
  String searchQuery = '',
  List<CrmUser> users = const [],
}) async {
  if (_cachedLogoBytes == null) {
    final logoData = await rootBundle.load('assets/images/teamn_logo.png');
    _cachedLogoBytes = logoData.buffer.asUint8List();
  }
  final logoImage = pw.MemoryImage(_cachedLogoBytes!);

  final pdf = pw.Document();

  // Metrics
  final totalLeads = leads.length;
  final convertedLeads = leads.where((l) => l.status.toLowerCase() == 'converted').length;
  final conversionRate = totalLeads > 0 ? (convertedLeads / totalLeads * 100) : 0.0;
  
  final lostLeads = leads.where((l) => l.status.toLowerCase() == 'lost').length;
  final newLeads = leads.where((l) => l.status.toLowerCase() == 'new').length;
  final contactedLeads = leads.where((l) => l.status.toLowerCase() == 'contacted').length;
  final qualifiedLeads = leads.where((l) => l.status.toLowerCase() == 'qualified').length;
  final followUpLeads = leads.where((l) => l.status.toLowerCase() == 'follow-up').length;

  pdf.addPage(
    pw.MultiPage(
      pageTheme: pw.PageTheme(
        margin: const pw.EdgeInsets.all(28),
        theme: pw.ThemeData.withFont(
          base: pw.Font.helvetica(),
          bold: pw.Font.helveticaBold(),
        ),
      ),
      build: (context) {
        return [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Image(logoImage, width: 40, height: 40),
              pw.SizedBox(width: 12),
              pw.Text(
                'Team N CRM Leads Report',
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blueGrey900,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            'Report Date: ${_dateLabel(DateTime.now())}',
            style: const pw.TextStyle(
              fontSize: 12,
              color: PdfColors.blueGrey700,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Filters applied - Status: $statusFilter | Source: $sourceFilter${searchQuery.isNotEmpty ? " | Search: '$searchQuery'" : ""}',
            style: const pw.TextStyle(
              fontSize: 10,
              color: PdfColors.blueGrey600,
            ),
          ),
          pw.SizedBox(height: 18),

          // Summary Cards
          pw.Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _metricCard('Total Leads', '$totalLeads'),
              _metricCard('Converted Leads', '$convertedLeads'),
              _metricCard('Conversion Rate', '${conversionRate.toStringAsFixed(1)}%'),
              _metricCard('New / Contacted', '$newLeads / $contactedLeads'),
              _metricCard('Qualified / Follow-up', '$qualifiedLeads / $followUpLeads'),
              _metricCard('Lost Leads', '$lostLeads'),
            ],
          ),
          pw.SizedBox(height: 22),

          _sectionTitle('Staff-wise Leads Performance'),
          _staffWiseSummaryTable(leads, users),
          pw.SizedBox(height: 22),

          _sectionTitle('Month-wise Leads Summary'),
          _monthWiseSummaryTable(leads),
          pw.SizedBox(height: 22),

          _sectionTitle('Leads List'),
          _leadsTable(leads, users),
        ];
      },
    ),
  );

  final bytes = await pdf.save();
  _downloadPdf(
    bytes,
    fileName: 'leads-report-${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}.pdf',
  );
}

pw.Widget _leadsTable(List<Lead> rows, List<CrmUser> users) {
  if (rows.isEmpty) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(12),
      child: pw.Text(
        'No leads found matching current filters.',
        style: pw.TextStyle(fontStyle: pw.FontStyle.italic),
      ),
    );
  }

  final List<List<dynamic>> dataList = rows
      .map<List<dynamic>>(
        (lead) {
          String assignedName = 'Unassigned';
          if (lead.assignedTo != null && lead.assignedTo!.isNotEmpty) {
            final matched = users.firstWhere(
              (u) => u.id == lead.assignedTo,
              orElse: () => CrmUser(id: lead.assignedTo!, name: 'Staff', email: '', role: 'sales', active: true),
            );
            assignedName = matched.name;
          }
          return <dynamic>[
            _dateLabel(lead.createdAt),
            lead.name,
            lead.phone,
            lead.source,
            assignedName,
            lead.location,
            lead.leadType,
            lead.status.toUpperCase(),
            lead.remarks,
          ];
        },
      )
      .toList();

  return pw.TableHelper.fromTextArray(
    headers: const [
      'Date Created',
      'Name',
      'Phone',
      'Source',
      'Assigned To',
      'Location',
      'Type',
      'Status',
      'Remarks',
    ],
    data: dataList,
    border: pw.TableBorder.all(color: PdfColors.blueGrey100),
    headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
    headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
    cellPadding: const pw.EdgeInsets.all(4),
    cellAlignment: pw.Alignment.centerLeft,
    cellStyle: const pw.TextStyle(fontSize: 7),
  );
}

pw.Widget _staffWiseSummaryTable(List<Lead> leads, List<CrmUser> users) {
  final Map<String, List<Lead>> grouped = {};
  for (final lead in leads) {
    final key = lead.assignedTo ?? '';
    grouped.putIfAbsent(key, () => []).add(lead);
  }

  final List<List<dynamic>> tableData = [];
  grouped.forEach((userId, userLeads) {
    String staffName = 'Unassigned';
    if (userId.isNotEmpty) {
      final matched = users.firstWhere(
        (u) => u.id == userId,
        orElse: () => CrmUser(id: userId, name: 'User ($userId)', email: '', role: 'sales', active: true),
      );
      staffName = matched.name;
    }

    final total = userLeads.length;
    final converted = userLeads.where((l) => l.status.toLowerCase() == 'converted').length;
    final lost = userLeads.where((l) => l.status.toLowerCase() == 'lost').length;
    final active = total - converted - lost;
    final convRate = total > 0 ? (converted / total * 100) : 0.0;

    tableData.add([
      staffName,
      '$total',
      '$active',
      '$converted',
      '$lost',
      '${convRate.toStringAsFixed(1)}%',
    ]);
  });

  tableData.sort((a, b) => int.parse(b[1]).compareTo(int.parse(a[1])));

  return pw.TableHelper.fromTextArray(
    headers: const [
      'Staff Name',
      'Total Leads',
      'Active Leads',
      'Converted',
      'Lost',
      'Conv. Rate',
    ],
    data: tableData,
    border: pw.TableBorder.all(color: PdfColors.blueGrey100),
    headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
    headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
    cellPadding: const pw.EdgeInsets.all(6),
    cellAlignment: pw.Alignment.centerLeft,
    cellStyle: const pw.TextStyle(fontSize: 8),
  );
}

pw.Widget _monthWiseSummaryTable(List<Lead> leads) {
  final Map<String, List<Lead>> grouped = {};
  final List<String> monthNames = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  for (final lead in leads) {
    final date = lead.leadDate;
    final key = '${date.year}-${date.month.toString().padLeft(2, '0')}';
    grouped.putIfAbsent(key, () => []).add(lead);
  }

  final sortedKeys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

  final List<List<dynamic>> tableData = [];
  for (final key in sortedKeys) {
    final userLeads = grouped[key]!;
    final parts = key.split('-');
    final year = parts[0];
    final monthIndex = int.parse(parts[1]) - 1;
    final monthLabel = '${monthNames[monthIndex]} $year';

    final total = userLeads.length;
    final converted = userLeads.where((l) => l.status.toLowerCase() == 'converted').length;
    final lost = userLeads.where((l) => l.status.toLowerCase() == 'lost').length;
    final active = total - converted - lost;
    final convRate = total > 0 ? (converted / total * 100) : 0.0;

    tableData.add([
      monthLabel,
      '$total',
      '$active',
      '$converted',
      '$lost',
      '${convRate.toStringAsFixed(1)}%',
    ]);
  }

  return pw.TableHelper.fromTextArray(
    headers: const [
      'Month',
      'Total Leads',
      'Active Leads',
      'Converted',
      'Lost',
      'Conv. Rate',
    ],
    data: tableData,
    border: pw.TableBorder.all(color: PdfColors.blueGrey100),
    headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
    headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
    cellPadding: const pw.EdgeInsets.all(6),
    cellAlignment: pw.Alignment.centerLeft,
    cellStyle: const pw.TextStyle(fontSize: 8),
  );
}
