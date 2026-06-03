import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/auth/app_role.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/extensions/space_extension.dart';
import '../../core/models/booking.dart';
import '../../core/models/lead.dart';
import '../../core/providers/booking_provider.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/theme/crm_theme.dart';
import '../../services/lead_service.dart';
import '../../core/utils/dashboard_report_service.dart';
import '../../core/utils/responsive_builder.dart';
import '../../services/employee_service.dart';
import '../../services/package_service.dart';
import '../../services/collection_service.dart';
import '../../core/models/artist_collection.dart';
import '../../core/models/employee.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  late DateTime _selectedMonth;
  late List<DateTime> _dropdownMonths;

  int _activeTab = 0; // 0: Operations, 1: Sales
  String _salesRange = 'Last 30 days'; // 'Last 7 days', 'Last 30 days', 'Last 6 months', 'Custom'
  bool _compareEnabled = true;
  DateTimeRange? _customDateRange;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month, 1);
    
    // Generate the last 12 months for the dropdown selection
    _dropdownMonths = List.generate(12, (index) {
      return DateTime(now.year, now.month - index, 1);
    });
  }

  Map<String, DateTimeRange> _getDateRanges() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    DateTime currentStart;
    DateTime currentEnd = today;
    DateTime prevStart;
    DateTime prevEnd;

    if (_salesRange == 'Last 7 days') {
      currentStart = today.subtract(const Duration(days: 6));
      prevStart = currentStart.subtract(const Duration(days: 7));
      prevEnd = currentStart.subtract(const Duration(days: 1));
    } else if (_salesRange == 'Last 6 months') {
      currentStart = DateTime(today.year, today.month - 5, 1);
      prevStart = DateTime(currentStart.year, currentStart.month - 6, 1);
      prevEnd = currentStart.subtract(const Duration(days: 1));
    } else if (_salesRange == 'Custom' && _customDateRange != null) {
      currentStart = _customDateRange!.start;
      currentEnd = _customDateRange!.end;
      final diff = currentEnd.difference(currentStart).inDays + 1;
      prevStart = currentStart.subtract(Duration(days: diff));
      prevEnd = currentStart.subtract(const Duration(days: 1));
    } else {
      // Default: Last 30 days
      currentStart = today.subtract(const Duration(days: 29));
      prevStart = currentStart.subtract(const Duration(days: 30));
      prevEnd = currentStart.subtract(const Duration(days: 1));
    }

    return {
      'current': DateTimeRange(start: currentStart, end: currentEnd),
      'previous': DateTimeRange(start: prevStart, end: prevEnd),
    };
  }

  Map<String, dynamic> _calculateSalesMetrics(List<Booking> bookings, DateTimeRange currentRange, DateTimeRange prevRange) {
    final currentBookings = bookings.where((b) {
      final date = DateTime(b.bookingDate.year, b.bookingDate.month, b.bookingDate.day);
      return !date.isBefore(currentRange.start) && !date.isAfter(currentRange.end);
    }).toList();

    final prevBookings = bookings.where((b) {
      final date = DateTime(b.bookingDate.year, b.bookingDate.month, b.bookingDate.day);
      return !date.isBefore(prevRange.start) && !date.isAfter(prevRange.end);
    }).toList();

    final double currentSales = currentBookings.fold(0.0, (sum, b) => sum + b.totalPrice);
    final int currentOrders = currentBookings.length;
    final double currentAvgBasket = currentOrders > 0 ? currentSales / currentOrders : 0.0;

    final double prevSales = prevBookings.fold(0.0, (sum, b) => sum + b.totalPrice);
    final int prevOrders = prevBookings.length;
    final double prevAvgBasket = prevOrders > 0 ? prevSales / prevOrders : 0.0;

    double salesGrowth = 0.0;
    if (prevSales > 0) {
      salesGrowth = ((currentSales - prevSales) / prevSales) * 100;
    } else if (currentSales > 0) {
      salesGrowth = 100.0;
    }

    double ordersGrowth = 0.0;
    if (prevOrders > 0) {
      ordersGrowth = ((currentOrders - prevOrders) / prevOrders) * 100;
    } else if (currentOrders > 0) {
      ordersGrowth = 100.0;
    }

    double avgBasketGrowth = 0.0;
    if (prevAvgBasket > 0) {
      avgBasketGrowth = ((currentAvgBasket - prevAvgBasket) / prevAvgBasket) * 100;
    } else if (currentAvgBasket > 0) {
      avgBasketGrowth = 100.0;
    }

    return {
      'currentBookings': currentBookings,
      'prevBookings': prevBookings,
      'currentSales': currentSales,
      'prevSales': prevSales,
      'salesGrowth': salesGrowth,
      'currentOrders': currentOrders,
      'prevOrders': prevOrders,
      'ordersGrowth': ordersGrowth,
      'currentAvgBasket': currentAvgBasket,
      'prevAvgBasket': prevAvgBasket,
      'avgBasketGrowth': avgBasketGrowth,
    };
  }

  List<BarChartGroupData> _buildChartGroups(
    List<Booking> currentBookings,
    List<Booking> prevBookings,
    DateTimeRange currentRange,
    DateTimeRange prevRange,
    bool compareEnabled,
  ) {
    final List<BarChartGroupData> groups = [];
    
    if (_salesRange == 'Last 6 months') {
      for (int i = 0; i < 6; i++) {
        final currentMonthStart = DateTime(currentRange.start.year, currentRange.start.month + i, 1);
        final currentMonthEnd = DateTime(currentMonthStart.year, currentMonthStart.month + 1, 0);
        
        final prevMonthStart = DateTime(prevRange.start.year, prevRange.start.month + i, 1);
        final prevMonthEnd = DateTime(prevMonthStart.year, prevMonthStart.month + 1, 0);

        final double currentVal = currentBookings
            .where((b) => !b.bookingDate.isBefore(currentMonthStart) && !b.bookingDate.isAfter(currentMonthEnd))
            .fold(0.0, (sum, b) => sum + b.totalPrice);

        final double prevVal = prevBookings
            .where((b) => !b.bookingDate.isBefore(prevMonthStart) && !b.bookingDate.isAfter(prevMonthEnd))
            .fold(0.0, (sum, b) => sum + b.totalPrice);

        groups.add(
          BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: currentVal,
                color: const Color(0xFFE05E26), // Orange
                width: 14,
                borderRadius: const BorderRadius.all(Radius.circular(2)),
              ),
              if (compareEnabled)
                BarChartRodData(
                  toY: prevVal,
                  color: const Color(0xFFD2D5DA), // Grey
                  width: 14,
                  borderRadius: const BorderRadius.all(Radius.circular(2)),
                ),
            ],
          ),
        );
      }
    } else {
      final diffDays = currentRange.end.difference(currentRange.start).inDays + 1;
      for (int i = 0; i < diffDays; i++) {
        final currentDate = currentRange.start.add(Duration(days: i));
        final prevDate = prevRange.start.add(Duration(days: i));

        final double currentVal = currentBookings
            .where((b) => b.bookingDate.year == currentDate.year && b.bookingDate.month == currentDate.month && b.bookingDate.day == currentDate.day)
            .fold(0.0, (sum, b) => sum + b.totalPrice);

        final double prevVal = prevBookings
            .where((b) => b.bookingDate.year == prevDate.year && b.bookingDate.month == prevDate.month && b.bookingDate.day == prevDate.day)
            .fold(0.0, (sum, b) => sum + b.totalPrice);

        groups.add(
          BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: currentVal,
                color: const Color(0xFFE05E26), // Orange
                width: diffDays > 10 ? 4 : 10,
                borderRadius: const BorderRadius.all(Radius.circular(2)),
              ),
              if (compareEnabled)
                BarChartRodData(
                  toY: prevVal,
                  color: const Color(0xFFD2D5DA), // Grey
                  width: diffDays > 10 ? 4 : 10,
                  borderRadius: const BorderRadius.all(Radius.circular(2)),
                ),
            ],
          ),
        );
      }
    }
    return groups;
  }

  String _getXAxisLabel(int value, DateTimeRange currentRange) {
    if (_salesRange == 'Last 6 months') {
      final monthDate = DateTime(currentRange.start.year, currentRange.start.month + value, 1);
      return _monthName(monthDate.month).substring(0, 3);
    } else if (_salesRange == 'Last 7 days') {
      final date = currentRange.start.add(Duration(days: value));
      const weekdayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return weekdayNames[date.weekday - 1];
    } else {
      final date = currentRange.start.add(Duration(days: value));
      if (value % 5 == 0 || value == 29) {
        return '${date.day} ${_monthName(date.month).substring(0, 3)}';
      }
      return '';
    }
  }

  Future<void> _selectCustomRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _customDateRange ?? DateTimeRange(
        start: DateTime.now().subtract(const Duration(days: 30)),
        end: DateTime.now(),
      ),
    );
    if (picked != null) {
      setState(() {
        _salesRange = 'Custom';
        _customDateRange = picked;
      });
    }
  }

  String formatInrCurrency(double amount, {bool decimal = false}) {
    if (amount >= 100000) {
      final int value = amount.toInt();
      final formatted = value.toString().replaceAllMapped(RegExp(r'(\d+?)(?=(\d\d)+(\d)(?!\d))'), (m) => '${m[1]},');
      return '₹$formatted';
    }
    final format = decimal ? amount.toStringAsFixed(2) : amount.toStringAsFixed(0);
    final parts = format.split('.');
    final intPart = parts[0].replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
    final decimals = parts.length > 1 ? '.${parts[1]}' : '';
    return '₹$intPart$decimals';
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required double growth,
    required String prevValue,
    required bool compareEnabled,
    required double width,
  }) {
    final isPositive = growth >= 0;
    final growthText = '${isPositive ? "↑" : "↓"} ${growth.abs().toStringAsFixed(0)}%';
    final growthColor = isPositive ? const Color(0xFF10B981) : const Color(0xFFEF4444);

    return Container(
      width: width,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF4B5563),
                ),
              ),
              const Icon(Icons.info_outline, size: 14, color: Color(0xFF9CA3AF)),
            ],
          ),
          12.h,
          Row(
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: GoogleFonts.inter(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                ),
              ),
              if (compareEnabled) ...[
                8.w,
                Text(
                  growthText,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: growthColor,
                  ),
                ),
              ],
            ],
          ),
          8.h,
          if (compareEnabled)
            Text(
              '$prevValue in previous period',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF6B7280),
              ),
            )
          else
            const SizedBox(height: 14),
        ],
      ),
    );
  }

  Widget buildDateSelector() {
    final datePills = ['Last 7 days', 'Last 30 days', 'Last 6 months', 'Custom'];
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: datePills.map((range) {
            final isSelected = _salesRange == range;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: OutlinedButton(
                onPressed: () {
                  if (range == 'Custom') {
                    _selectCustomRange();
                  } else {
                    setState(() {
                      _salesRange = range;
                    });
                  }
                },
                style: OutlinedButton.styleFrom(
                  backgroundColor: isSelected ? const Color(0xFFFFF6F0) : Colors.white,
                  side: BorderSide(
                    color: isSelected ? const Color(0xFFE05E26) : const Color(0xFFD2D5DA),
                    width: 1.5,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                child: Row(
                  children: [
                    if (range == 'Custom') ...[
                      const Icon(Icons.calendar_today_outlined, size: 12, color: Color(0xFFE05E26)),
                      8.w,
                    ],
                    Text(
                      range,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        color: isSelected ? const Color(0xFFE05E26) : const Color(0xFF4B5563),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(
              value: _compareEnabled,
              onChanged: (val) {
                setState(() {
                  _compareEnabled = val;
                });
              },
              activeThumbColor: const Color(0xFF10B981),
            ),
            8.w,
            Text(
              'Compare with previous period',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1F2937),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget buildTabBar() {
    final tabStyles = GoogleFonts.inter(
      fontSize: 14,
      fontWeight: FontWeight.w600,
    );

    final List<String> tabs = ['Operations', 'Sales'];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: Colors.grey.withValues(alpha: 0.15),
            width: 1.0,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: tabs.asMap().entries.map((entry) {
          final idx = entry.key;
          final label = entry.value;
          final isSelected = _activeTab == idx;

          return GestureDetector(
            onTap: () {
              setState(() {
                _activeTab = idx;
              });
            },
            child: Container(
              margin: const EdgeInsets.only(right: 32),
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: isSelected ? const Color(0xFFE05E26) : Colors.transparent,
                    width: 2.0,
                  ),
                ),
              ),
              child: Text(
                label,
                style: tabStyles.copyWith(
                  color: isSelected ? const Color(0xFFE05E26) : const Color(0xFF7B8694),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget getTabContent(
    String userName,
    List<Booking> bookings,
    List<Lead> leads,
    List<ArtistCollection> collections,
    List<Lead> filteredLeads,
    int enquiriesCount,
    int bookingsCount,
    double conversionRate,
    double growthRate,
    bool isGrowthPositive,
    double totalRevenue,
    double revenueGrowth,
    bool isRevenueGrowthPositive,
    String Function(double) formatCurrency,
    VoidCallback exportReport,
    CrmTheme crmColors,
    bool isDesktop,
    bool isTablet,
    List<Employee> employees,
  ) {
    switch (_activeTab) {
      case 0:
        return _buildOperationsTab(context, userName, bookings, leads, collections, filteredLeads, enquiriesCount, bookingsCount, conversionRate, growthRate, isGrowthPositive, totalRevenue, revenueGrowth, isRevenueGrowthPositive, formatCurrency, exportReport, crmColors, isDesktop, isTablet);
      case 1:
        return _buildSalesTab(bookings, crmColors, isDesktop);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildSalesTab(List<Booking> bookings, CrmTheme crmColors, bool isDesktop) {
    final ranges = _getDateRanges();
    final currentRange = ranges['current']!;
    final prevRange = ranges['previous']!;

    final metrics = _calculateSalesMetrics(bookings, currentRange, prevRange);
    
    final double currentSales = metrics['currentSales'];
    final double prevSales = metrics['prevSales'];
    final double salesGrowth = metrics['salesGrowth'];

    final int currentOrders = metrics['currentOrders'];
    final int prevOrders = metrics['prevOrders'];
    final double ordersGrowth = metrics['ordersGrowth'];

    final double currentAvgBasket = metrics['currentAvgBasket'];
    final double prevAvgBasket = metrics['prevAvgBasket'];
    final double avgBasketGrowth = metrics['avgBasketGrowth'];

    final List<Booking> currentPeriodBookings = metrics['currentBookings'];
    final List<Booking> prevPeriodBookings = metrics['prevBookings'];

    final groups = _buildChartGroups(currentPeriodBookings, prevPeriodBookings, currentRange, prevRange, _compareEnabled);

    double maxY = 1000.0;
    for (final group in groups) {
      for (final rod in group.barRods) {
        if (rod.toY > maxY) {
          maxY = rod.toY;
        }
      }
    }
    maxY = (maxY * 1.15).roundToDouble();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sales Dashboard',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF0F172A),
            ),
          ),
          16.h,
          buildDateSelector(),
          24.h,
          LayoutBuilder(
            builder: (context, constraints) {
              final double spacing = 16.0;
              final int columns = isDesktop ? 3 : 1;
              final double itemWidth = (constraints.maxWidth - (spacing * (columns - 1))) / columns;

              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  _buildKpiCard(
                    title: 'Sales',
                    value: formatInrCurrency(currentSales),
                    growth: salesGrowth,
                    prevValue: formatInrCurrency(prevSales),
                    compareEnabled: _compareEnabled,
                    width: itemWidth,
                  ),
                  _buildKpiCard(
                    title: 'Orders',
                    value: currentOrders.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},'),
                    growth: ordersGrowth,
                    prevValue: prevOrders.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},'),
                    compareEnabled: _compareEnabled,
                    width: itemWidth,
                  ),
                  _buildKpiCard(
                    title: 'Avg. basket size',
                    value: formatInrCurrency(currentAvgBasket, decimal: true),
                    growth: avgBasketGrowth,
                    prevValue: formatInrCurrency(prevAvgBasket, decimal: true),
                    compareEnabled: _compareEnabled,
                    width: itemWidth,
                  ),
                ],
              );
            },
          ),
          32.h,
          Card(
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Sales by Day',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          8.w,
                          const Icon(Icons.info_outline, size: 14, color: Color(0xFF9CA3AF)),
                        ],
                      ),
                      Row(
                        children: [
                          OutlinedButton.icon(
                            onPressed: () {},
                            icon: const Icon(Icons.show_chart, size: 14, color: Color(0xFF374151)),
                            label: Text(
                              'End of day report',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF374151),
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              backgroundColor: Colors.white,
                              side: const BorderSide(color: Color(0xFFE5E7EB)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                          ),
                          8.w,
                          IconButton(
                            onPressed: () {},
                            icon: const Icon(Icons.download_outlined, size: 18, color: Color(0xFF374151)),
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side: const BorderSide(color: Color(0xFFE5E7EB)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  16.h,
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sales ($currentOrders)',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: const Color(0xFF4B5563),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      6.h,
                      Row(
                        children: [
                          Text(
                            formatInrCurrency(currentSales),
                            style: GoogleFonts.inter(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          if (_compareEnabled) ...[
                            8.w,
                            Text(
                              '${salesGrowth >= 0 ? "↑" : "↓"} ${salesGrowth.abs().toStringAsFixed(0)}%',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: salesGrowth >= 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (_compareEnabled) ...[
                        4.h,
                        Text(
                          '${formatInrCurrency(prevSales)} ($prevOrders) in previous period',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ],
                  ),
                  32.h,
                  if (groups.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 48),
                        child: Text(
                          'No sales data in this period',
                          style: GoogleFonts.inter(color: const Color(0xFF6B7280)),
                        ),
                      ),
                    )
                  else
                    SizedBox(
                      height: 280,
                      child: BarChart(
                        BarChartData(
                          alignment: BarChartAlignment.spaceAround,
                          maxY: maxY,
                          gridData: FlGridData(
                            show: true,
                            drawVerticalLine: false,
                            horizontalInterval: maxY > 10000 ? (maxY / 4).roundToDouble() : 2500,
                            getDrawingHorizontalLine: (value) => FlLine(
                              color: Colors.grey.withValues(alpha: 0.1),
                              strokeWidth: 1,
                            ),
                          ),
                          titlesData: FlTitlesData(
                            show: true,
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 30,
                                getTitlesWidget: (value, meta) {
                                  final label = _getXAxisLabel(value.toInt(), currentRange);
                                  return SideTitleWidget(
                                    meta: meta,
                                    space: 8,
                                    child: Text(
                                      label,
                                      style: GoogleFonts.inter(
                                        color: const Color(0xFF7B8694),
                                        fontSize: 9,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 45,
                                getTitlesWidget: (value, meta) {
                                  if (value == 0) return const SizedBox.shrink();
                                  return SideTitleWidget(
                                    meta: meta,
                                    child: Text(
                                      value >= 1000 ? '${(value / 1000).toStringAsFixed(0)}k' : value.toStringAsFixed(0),
                                      style: GoogleFonts.inter(
                                        color: const Color(0xFF7B8694),
                                        fontSize: 9,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          ),
                          borderData: FlBorderData(show: false),
                          barTouchData: BarTouchData(
                            touchTooltipData: BarTouchTooltipData(
                              getTooltipColor: (group) => const Color(0xFF0F172A),
                              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                return BarTooltipItem(
                                  formatInrCurrency(rod.toY),
                                  GoogleFonts.inter(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                );
                              },
                            ),
                          ),
                          barGroups: groups,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOperationsTab(
    BuildContext context,
    String userName,
    List<Booking> bookings,
    List<Lead> leads,
    List<ArtistCollection> collections,
    List<Lead> filteredLeads,
    int enquiriesCount,
    int bookingsCount,
    double conversionRate,
    double growthRate,
    bool isGrowthPositive,
    double totalRevenue,
    double revenueGrowth,
    bool isRevenueGrowthPositive,
    String Function(double) formatCurrency,
    VoidCallback exportReport,
    CrmTheme crmColors,
    bool isDesktop,
    bool isTablet,
  ) {
    return SingleChildScrollView(
      padding: 24.p,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DashboardHeader(
            userName: userName,
            selectedMonth: _selectedMonth,
            dropdownMonths: _dropdownMonths,
            onMonthChanged: (newMonth) {
              setState(() {
                _selectedMonth = newMonth;
              });
            },
            onDownloadReport: exportReport,
          ),
          32.h,
          LayoutBuilder(
            builder: (context, constraints) {
              int columns = isDesktop ? 5 : (isTablet ? 3 : 1);
              double spacing = 16.0;
              double itemWidth =
                  (constraints.maxWidth - (spacing * (columns - 1))) / columns;

              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  _MetricCard(
                    title: 'TOTAL ENQUIRIES',
                    value: enquiriesCount.toString().replaceAllMapped(
                        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                        (Match m) => '${m[1]},'),
                    trend: '${filteredLeads.isNotEmpty ? "+100" : "0"}%',
                    isPositive: true,
                    sparklineData: const [10, 12, 11, 15, 14, 18, 17, 22],
                    sparklineColor: const Color(0xFFCBA052),
                    icon: Icons.people_outline,
                    gradientColors: [
                      const Color(0xFFFFFAF3).withValues(alpha: 0.9),
                      const Color(0xFFFEEAD3).withValues(alpha: 0.7),
                    ],
                    width: itemWidth,
                  ),
                  _MetricCard(
                    title: 'TOTAL BOOKINGS',
                    value: bookingsCount.toString().replaceAllMapped(
                        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                        (Match m) => '${m[1]},'),
                    trend: '${bookingsCount > 0 ? "+100" : "0"}%',
                    isPositive: true,
                    sparklineData: const [8, 9, 7, 10, 12, 11, 14],
                    sparklineColor: const Color(0xFFD46A92),
                    icon: Icons.calendar_month_outlined,
                    gradientColors: [
                      const Color(0xFFFFF5F6).withValues(alpha: 0.9),
                      const Color(0xFFFED7DD).withValues(alpha: 0.7),
                    ],
                    width: itemWidth,
                  ),
                  _MetricCard(
                    title: 'CONVERSION RATE',
                    value: '${conversionRate.toStringAsFixed(1)}%',
                    trend: '${conversionRate > 0 ? "+100" : "0"}%',
                    isPositive: true,
                    sparklineData: const [28, 30, 29, 32, 31, 34],
                    sparklineColor: const Color(0xFF7A6BB9),
                    icon: Icons.adjust_outlined,
                    gradientColors: [
                      const Color(0xFFF9F7FF).withValues(alpha: 0.9),
                      const Color(0xFFE8E0FF).withValues(alpha: 0.7),
                    ],
                    width: itemWidth,
                  ),
                  _MetricCard(
                    title: 'REVENUE GENERATED',
                    value: formatCurrency(totalRevenue),
                    trend: '${isRevenueGrowthPositive ? "+" : ""}${revenueGrowth.toStringAsFixed(1)}%',
                    isPositive: isRevenueGrowthPositive,
                    sparklineData: const [5, 6, 7, 9, 8, 11, 12],
                    sparklineColor: const Color(0xFFCBA052),
                    icon: Icons.wallet_giftcard_outlined,
                    gradientColors: [
                      const Color(0xFFFFFBF0).withValues(alpha: 0.9),
                      const Color(0xFFFFF0CA).withValues(alpha: 0.7),
                    ],
                    width: itemWidth,
                  ),
                  _MetricCard(
                    title: 'MONTHLY GROWTH',
                    value: '${growthRate.toStringAsFixed(1)}%',
                    trend: '${isGrowthPositive ? "+" : ""}${growthRate.toStringAsFixed(1)}%',
                    isPositive: isGrowthPositive,
                    sparklineData: const [16, 15, 13, 14, 12, 13, 11],
                    sparklineColor: const Color(0xFF6C96C8),
                    icon: Icons.trending_up,
                    gradientColors: [
                      const Color(0xFFF0F5FF).withValues(alpha: 0.9),
                      const Color(0xFFD0E0FF).withValues(alpha: 0.7),
                    ],
                    width: itemWidth,
                  ),
                ],
              );
            },
          ),
          32.h,
          if (isDesktop)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: _LeadGrowthCard(leads: leads),
                ),
                24.w,
                Expanded(
                  flex: 1,
                  child: _LeadSourcesCard(
                    leads: filteredLeads,
                  ),
                ),
              ],
            )
          else
            Column(
              children: [
                _LeadGrowthCard(leads: leads),
                24.h,
                _LeadSourcesCard(
                  leads: filteredLeads,
                ),
              ],
            ),
          32.h,
          _EnquiriesByLocationCard(
            leads: filteredLeads,
          ),
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authSessionProvider);
    final role = session != null
        ? AppRole.fromString(session.role)
        : AppRole.artist;

    final isDesktop = ResponsiveBuilder.isDesktop(context);
    final isTablet = ResponsiveBuilder.isTablet(context);
    final crmColors = context.crmColors;

    final asyncBookings = ref.watch(bookingProvider);
    final asyncArtistBookings = role == AppRole.artist
        ? ref.watch(artistAssignedWorksProvider(1))
        : null;

    final asyncPackages = ref.watch(packagesProvider);
    final asyncEmployees = ref.watch(employeesProvider);
    final asyncLeads = ref.watch(leadsProvider);
    final asyncCollections = ref.watch(collectionsProvider);

    final allBookings = role == AppRole.artist
        ? (asyncArtistBookings?.value?.items ?? const <Booking>[])
        : (asyncBookings.value ?? const <Booking>[]);

    if (role == AppRole.artist) {
      if (asyncArtistBookings == null || asyncArtistBookings.isLoading) {
        return const Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        );
      }
      if (asyncArtistBookings.hasError) {
        return Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Text(
                'Error loading bookings: ${asyncArtistBookings.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          ),
        );
      }
      return _ArtistDashboardView(
        isDesktop: isDesktop,
        isTablet: isTablet,
        allBookings: allBookings,
        employeeId: session?.employeeId,
        employeeName: session?.name,
      );
    }

    final authSession = session;
    final userName = authSession?.name ?? 'Aanya';

    final bookings = allBookings;
    final leads = asyncLeads.value ?? const <Lead>[];
    final collections = asyncCollections.value ?? const <ArtistCollection>[];

    // Filter leads and bookings dynamically for the selected month (used in Operations tab)
    final filteredLeads = leads.where((l) =>
      l.createdAt.year == _selectedMonth.year && l.createdAt.month == _selectedMonth.month
    ).toList();

    final filteredBookings = bookings.where((b) =>
      b.bookingDate.year == _selectedMonth.year && b.bookingDate.month == _selectedMonth.month
    ).toList();

    final int enquiriesCount = filteredLeads.length;
    
    // Converted or booked leads represent bookings count
    final int bookingsCount = filteredLeads.where((l) => 
      l.bookedDate != null || 
      l.status.toLowerCase() == 'converted'
    ).length;
    
    final double conversionRate = enquiriesCount > 0 
        ? (bookingsCount / enquiriesCount) * 100 
        : 0.0;

    // Calculate monthly growth dynamically comparing selected month with previous month
    final prevMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1, 1);
    final leadsThisMonth = filteredLeads.length;
    final leadsLastMonth = leads.where((l) => 
      l.createdAt.year == prevMonth.year && 
      l.createdAt.month == prevMonth.month
    ).length;

    double growthRate = 0.0;
    if (leadsLastMonth > 0) {
      growthRate = ((leadsThisMonth - leadsLastMonth) / leadsLastMonth) * 100;
    } else if (leadsThisMonth > 0) {
      growthRate = 100.0; // infinite growth since last month was 0
    }
    final bool isGrowthPositive = growthRate >= 0;

    // Revenue generated from completed bookings in the database for the selected month
    double totalRevenue = filteredBookings
        .where((b) => b.status.toLowerCase() == 'completed')
        .fold<double>(0, (sum, b) => sum + b.totalPrice);
    
    if (totalRevenue == 0) {
      // Fallback to active bookings total price
      final activeBookingsTotal = filteredBookings
          .where((b) => b.status.toLowerCase() != 'cancelled')
          .fold<double>(0, (sum, b) => sum + b.totalPrice);
      totalRevenue = activeBookingsTotal;
    }

    // Calculate monthly revenue growth comparing selected month with previous month
    final prevMonthBookings = bookings.where((b) =>
      b.bookingDate.year == prevMonth.year && b.bookingDate.month == prevMonth.month
    ).toList();
    double prevRevenue = prevMonthBookings
        .where((b) => b.status.toLowerCase() == 'completed')
        .fold<double>(0, (sum, b) => sum + b.totalPrice);
    if (prevRevenue == 0) {
      prevRevenue = prevMonthBookings
          .where((b) => b.status.toLowerCase() != 'cancelled')
          .fold<double>(0, (sum, b) => sum + b.totalPrice);
    }
    double revenueGrowth = 0.0;
    if (prevRevenue > 0) {
      revenueGrowth = ((totalRevenue - prevRevenue) / prevRevenue) * 100;
    } else if (totalRevenue > 0) {
      revenueGrowth = 100.0;
    }
    final bool isRevenueGrowthPositive = revenueGrowth >= 0;

    String formatCurrency(double amount) {
      if (amount >= 100000) {
        final int value = amount.toInt();
        return '₹${value.toString().replaceAllMapped(RegExp(r'(\d+?)(?=(\d\d)+(\d)(?!\d))'), (m) => '${m[1]},')}';
      }
      return '₹${amount.toStringAsFixed(0)}';
    }

    Future<void> exportReport() async {
      final packages = asyncPackages.value;
      final employees = asyncEmployees.value;

      if (asyncBookings.value == null || packages == null || employees == null) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please wait until dashboard data finishes loading.'),
          ),
        );
        return;
      }

      await downloadDashboardReport(
        month: _selectedMonth,
        bookings: bookings,
        packages: packages,
        employees: employees,
        leads: leads,
        collections: collections,
        reportType: 'executive',
      );
    }

    return Scaffold(
      body: Container(
        color: crmColors.background,
        child: Column(
          children: [
            buildTabBar(),
            Expanded(
              child: getTabContent(
                userName,
                bookings,
                leads,
                collections,
                filteredLeads,
                enquiriesCount,
                bookingsCount,
                conversionRate,
                growthRate,
                isGrowthPositive,
                totalRevenue,
                revenueGrowth,
                isRevenueGrowthPositive,
                formatCurrency,
                exportReport,
                crmColors,
                isDesktop,
                isTablet,
                asyncEmployees.value ?? const <Employee>[],
              ),
            ),
          ],
        ),
      ),
    );
  }

}

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

// HEADER WIDGET
class _DashboardHeader extends StatelessWidget {
  final String userName;
  final DateTime selectedMonth;
  final List<DateTime> dropdownMonths;
  final ValueChanged<DateTime> onMonthChanged;
  final VoidCallback onDownloadReport;

  const _DashboardHeader({
    required this.userName,
    required this.selectedMonth,
    required this.dropdownMonths,
    required this.onMonthChanged,
    required this.onDownloadReport,
  });

  @override
  Widget build(BuildContext context) {
    final crmColors = context.crmColors;
    final isMobile = ResponsiveBuilder.isMobile(context);

    final dropdownWidget = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: crmColors.border.withValues(alpha: 0.08)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<DateTime>(
          value: selectedMonth,
          icon: const Icon(Icons.keyboard_arrow_down, size: 16, color: Color(0xFF7B8694)),
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF0B1B3B),
          ),
          items: dropdownMonths.map((date) {
            final label = '${_monthName(date.month)} ${date.year}';
            return DropdownMenuItem<DateTime>(
              value: date,
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_outlined, size: 14, color: Color(0xFFC59B27)),
                  8.w,
                  Text(label),
                ],
              ),
            );
          }).toList(),
          onChanged: (newVal) {
            if (newVal != null) {
              onMonthChanged(newVal);
            }
          },
        ),
      ),
    );

    final downloadButton = ElevatedButton.icon(
      onPressed: onDownloadReport,
      icon: const Icon(Icons.download, size: 16),
      label: const Text('Download Report'),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF0B1B3B),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        elevation: 0,
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Left side greetings
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'STAKEHOLDER ANALYTICS · LIVE',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: crmColors.textSecondary,
                      letterSpacing: 1.5,
                    ),
                  ),
                  6.h,
                  RichText(
                    text: TextSpan(
                      style: GoogleFonts.playfairDisplay(
                        fontSize: isMobile ? 22 : 32,
                        fontWeight: FontWeight.w400,
                        color: const Color(0xFF0B1B3B),
                      ),
                      children: [
                        TextSpan(text: 'Good morning, $userName — '),
                        TextSpan(
                          text: 'this month, quietly',
                          style: GoogleFonts.cormorantGaramond(
                            fontStyle: FontStyle.italic,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFFC59B27),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Right side dropdown on Desktop
            if (!isMobile)
              Row(
                children: [
                  downloadButton,
                  16.w,
                  dropdownWidget,
                ],
              ),
          ],
        ),

        // Right side stacked elements on Mobile
        if (isMobile) ...[
          16.h,
          Row(
            children: [
              Expanded(
                child: dropdownWidget,
              ),
              12.w,
              downloadButton,
            ],
          ),
        ],
      ],
    );
  }
}

// GLASSMORPHIC METRIC CARD
class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String trend;
  final bool isPositive;
  final List<double> sparklineData;
  final Color sparklineColor;
  final IconData icon;
  final List<Color> gradientColors;
  final double width;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.trend,
    required this.isPositive,
    required this.sparklineData,
    required this.sparklineColor,
    required this.icon,
    required this.gradientColors,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 145,
      padding: 16.p,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.6),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon and Trend Pill
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: 6.p,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: const Color(0xFF0B1B3B)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isPositive
                      ? const Color(0xFFE2F3EB)
                      : const Color(0xFFFDE8E9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isPositive ? Icons.trending_up : Icons.trending_down,
                      size: 11,
                      color: isPositive ? const Color(0xFF0B5B37) : const Color(0xFF7B1B2A),
                    ),
                    4.w,
                    Text(
                      trend,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isPositive ? const Color(0xFF0B5B37) : const Color(0xFF7B1B2A),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          16.h,
          // Title
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF7B8694),
              letterSpacing: 0.8,
            ),
          ),
          4.h,
          // Value and Sparkline Row
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.bottomLeft,
                    child: Text(
                      value,
                      style: GoogleFonts.inter(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0B1B3B),
                      ),
                    ),
                  ),
                ),
                8.w,
                SizedBox(
                  width: 60,
                  height: 30,
                  child: CustomPaint(
                    painter: _SparklinePainter(
                      data: sparklineData,
                      color: sparklineColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// SPARKLINE PAINTER
class _SparklinePainter extends CustomPainter {
  final List<double> data;
  final Color color;

  _SparklinePainter({required this.data, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final double stepX = size.width / (data.length - 1);
    final double minVal = data.reduce((a, b) => a < b ? a : b);
    final double maxVal = data.reduce((a, b) => a > b ? a : b);
    final double valRange = maxVal - minVal == 0 ? 1.0 : maxVal - minVal;

    double getX(int index) => index * stepX;
    double getY(double val) {
      final ratio = (val - minVal) / valRange;
      return size.height - (ratio * (size.height - 4)) - 2;
    }

    path.moveTo(getX(0), getY(data[0]));

    for (int i = 0; i < data.length - 1; i++) {
      final x1 = getX(i);
      final y1 = getY(data[i]);
      final x2 = getX(i + 1);
      final y2 = getY(data[i + 1]);

      final cx1 = x1 + (x2 - x1) / 2.0;
      final cy1 = y1;
      final cx2 = x1 + (x2 - x1) / 2.0;
      final cy2 = y2;

      path.cubicTo(cx1, cy1, cx2, cy2, x2, y2);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) =>
      oldDelegate.data != data || oldDelegate.color != color;
}

// LEAD GROWTH BAR CHART CARD
class _LeadGrowthCard extends StatefulWidget {
  final List<Lead> leads;
  const _LeadGrowthCard({required this.leads});

  @override
  State<_LeadGrowthCard> createState() => _LeadGrowthCardState();
}

class _LeadGrowthCardState extends State<_LeadGrowthCard> {
  String _activeTab = 'Monthly';

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final bool hasData = widget.leads.isNotEmpty;
    
    // Default YTD totals and monthly counts if no data
    String ytdValue = '0';
    String trendValue = '0.0%';
    bool isTrendPositive = true;
    double maxY = 10.0;
    
    List<double> barValues = List.filled(12, 0.0);

    if (hasData) {
      ytdValue = widget.leads.length.toString();
      
      // Calculate growth trend
      final startOfThisMonth = DateTime(now.year, now.month, 1);
      final startOfLastMonth = DateTime(now.year, now.month - 1, 1);
      
      final leadsThisMonth = widget.leads.where((l) => l.createdAt.isAfter(startOfThisMonth)).length;
      final leadsLastMonth = widget.leads.where((l) => 
        l.createdAt.isAfter(startOfLastMonth) && 
        l.createdAt.isBefore(startOfThisMonth)
      ).length;

      if (leadsLastMonth > 0) {
        final pct = ((leadsThisMonth - leadsLastMonth) / leadsLastMonth) * 100;
        trendValue = '${pct >= 0 ? "+" : ""}${pct.toStringAsFixed(1)}%';
        isTrendPositive = pct >= 0;
      } else {
        trendValue = leadsThisMonth > 0 ? '+100.0%' : '0.0%';
        isTrendPositive = true;
      }

      // Group leads by month for the current year
      final monthlyCounts = List<double>.filled(12, 0.0);
      for (final lead in widget.leads) {
        if (lead.createdAt.year == now.year) {
          monthlyCounts[lead.createdAt.month - 1] += 1.0;
        }
      }
      barValues = monthlyCounts;
      
      final peak = barValues.reduce((a, b) => a > b ? a : b);
      maxY = peak > 0 ? peak : 10.0;
    }

    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: 24.p,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Card Title Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Lead growth',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0B1B3B),
                      ),
                    ),
                    Text(
                      '— twelve months, climbing',
                      style: GoogleFonts.cormorantGaramond(
                        fontStyle: FontStyle.italic,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFFC25A7C),
                      ),
                    ),
                  ],
                ),
                // Toggle pill segment
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F6F8),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: ['Monthly', 'Weekly', 'Daily'].map((tab) {
                      final isSelected = tab == _activeTab;
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _activeTab = tab;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.white : Colors.transparent,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.04),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Text(
                            tab,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                              color: isSelected ? const Color(0xFF0B1B3B) : const Color(0xFF7B8694),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
            24.h,

            // Cumulative Total Area
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  ytdValue,
                  style: GoogleFonts.inter(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0B1B3B),
                  ),
                ),
                8.w,
                Text(
                  trendValue,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isTrendPositive ? const Color(0xFF0B5B37) : const Color(0xFF7B1B2A),
                  ),
                ),
                const Spacer(),
                Text(
                  'YTD',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF7B8694),
                  ),
                ),
              ],
            ),
            28.h,

            // Bar Chart Area
            SizedBox(
              height: 250,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxY,
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (group) => const Color(0xFF0B1B3B),
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        return BarTooltipItem(
                          '${rod.toY.toInt()} leads',
                          GoogleFonts.inter(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 24,
                        getTitlesWidget: (value, meta) {
                          const style = TextStyle(color: Color(0xFF7B8694), fontSize: 10, fontWeight: FontWeight.w500);
                          String text = '';
                          switch (value.toInt()) {
                            case 0: text = 'Jan'; break;
                            case 1: text = 'Feb'; break;
                            case 2: text = 'Mar'; break;
                            case 3: text = 'Apr'; break;
                            case 4: text = 'May'; break;
                            case 5: text = 'Jun'; break;
                            case 6: text = 'Jul'; break;
                            case 7: text = 'Aug'; break;
                            case 8: text = 'Sep'; break;
                            case 9: text = 'Oct'; break;
                            case 10: text = 'Nov'; break;
                            case 11: text = 'Dec'; break;
                          }
                          return SideTitleWidget(
                            meta: meta,
                            space: 6,
                            child: Text(text, style: style),
                          );
                        },
                      ),
                    ),
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  barGroups: List.generate(12, (index) => _makeBarGroup(index, barValues[index], maxY)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  BarChartGroupData _makeBarGroup(int x, double y, double maxY) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          color: const Color(0xFFCBA052), // gold
          width: 18,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
          backDrawRodData: BackgroundBarChartRodData(
            show: true,
            toY: maxY,
            color: const Color(0xFFF1EDE6),
          ),
        ),
      ],
    );
  }
}

// LEAD SOURCES DONUT CHART CARD
class _LeadSourcesCard extends StatelessWidget {
  final List<Lead> leads;

  const _LeadSourcesCard({
    required this.leads,
  });

  @override
  Widget build(BuildContext context) {
    final int totalCount = leads.length;
    final int instagramCount = leads.where((l) => l.source.toLowerCase().contains('instagram')).length;
    
    // Web form maps to Web/YouTube
    final int webFormCount = leads.where((l) => 
      l.source.toLowerCase().contains('youtube') || 
      l.source.toLowerCase().contains('web')
    ).length;
    
    final int whatsappCount = leads.where((l) => 
      l.source.toLowerCase().contains('whatsapp') || 
      l.source.toLowerCase().contains('chat')
    ).length;
    
    final int callsCount = leads.where((l) => 
      l.source.toLowerCase().contains('call') || 
      l.source.toLowerCase().contains('phone')
    ).length;

    final int otherCount = totalCount - (instagramCount + webFormCount + whatsappCount + callsCount);

    double instagramPct = 0.0;
    double webFormPct = 0.0;
    double whatsappPct = 0.0;
    double callsPct = 0.0;
    double otherPct = 0.0;

    if (totalCount > 0) {
      instagramPct = (instagramCount / totalCount) * 100;
      webFormPct = (webFormCount / totalCount) * 100;
      whatsappPct = (whatsappCount / totalCount) * 100;
      callsPct = (callsCount / totalCount) * 100;
      otherPct = (otherCount / totalCount) * 100;
    }

    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: 24.p,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Card Title Header
            Text(
              'Lead sources',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0B1B3B),
              ),
            ),
            Text(
              '— where they really come from',
              style: GoogleFonts.cormorantGaramond(
                fontStyle: FontStyle.italic,
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: const Color(0xFFC25A7C),
              ),
            ),
            28.h,

            // Donut Pie Chart inside a stack
            Center(
              child: SizedBox(
                width: 170,
                height: 170,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    PieChart(
                      PieChartData(
                        sectionsSpace: 3,
                        centerSpaceRadius: 55,
                        startDegreeOffset: -90,
                        sections: totalCount == 0
                            ? [
                                PieChartSectionData(
                                  color: const Color(0xFFF1EDE6), // light grey placeholder for empty chart
                                  value: 100,
                                  title: '',
                                  radius: 20,
                                ),
                              ]
                            : [
                                PieChartSectionData(
                                  color: const Color(0xFFD46A92), // instagram (pink)
                                  value: instagramPct > 0 ? instagramPct : 0.001,
                                  title: '',
                                  radius: 20,
                                ),
                                PieChartSectionData(
                                  color: const Color(0xFFCBA052), // web form (gold)
                                  value: webFormPct > 0 ? webFormPct : 0.001,
                                  title: '',
                                  radius: 20,
                                ),
                                PieChartSectionData(
                                  color: const Color(0xFF7A6BB9), // whatsapp (purple)
                                  value: whatsappPct > 0 ? whatsappPct : 0.001,
                                  title: '',
                                  radius: 20,
                                ),
                                PieChartSectionData(
                                  color: const Color(0xFF6C96C8), // calls (blue)
                                  value: callsPct > 0 ? callsPct : 0.001,
                                  title: '',
                                  radius: 20,
                                ),
                                if (otherCount > 0)
                                  PieChartSectionData(
                                    color: const Color(0xFF7B8694), // other (grey)
                                    value: otherPct,
                                    title: '',
                                    radius: 20,
                                  ),
                              ],
                      ),
                    ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          totalCount.toString().replaceAllMapped(
                            RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                            (Match m) => '${m[1]},'
                          ),
                          style: GoogleFonts.inter(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF0B1B3B),
                          ),
                        ),
                        Text(
                          'TOTAL LEADS',
                          style: GoogleFonts.inter(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF7B8694),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            32.h,

            // Legends List
            Column(
              children: [
                _LegendTile(
                  color: const Color(0xFFD46A92),
                  icon: Icons.camera_alt_outlined,
                  name: 'Instagram',
                  count: instagramCount.toString(),
                  percentage: '${instagramPct.toStringAsFixed(1)}%',
                ),
                const Divider(height: 16),
                _LegendTile(
                  color: const Color(0xFFCBA052),
                  icon: Icons.language_outlined,
                  name: 'Web form',
                  count: webFormCount.toString(),
                  percentage: '${webFormPct.toStringAsFixed(1)}%',
                ),
                const Divider(height: 16),
                _LegendTile(
                  color: const Color(0xFF7A6BB9),
                  icon: Icons.chat_bubble_outline_rounded,
                  name: 'WhatsApp',
                  count: whatsappCount.toString(),
                  percentage: '${whatsappPct.toStringAsFixed(1)}%',
                ),
                const Divider(height: 16),
                _LegendTile(
                  color: const Color(0xFF6C96C8),
                  icon: Icons.phone_outlined,
                  name: 'Calls',
                  count: callsCount.toString(),
                  percentage: '${callsPct.toStringAsFixed(1)}%',
                ),
                if (otherCount > 0) ...[
                  const Divider(height: 16),
                  _LegendTile(
                    color: const Color(0xFF7B8694),
                    icon: Icons.more_horiz_outlined,
                    name: 'Other',
                    count: otherCount.toString(),
                    percentage: '${otherPct.toStringAsFixed(1)}%',
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendTile extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String name;
  final String count;
  final String percentage;

  const _LegendTile({
    required this.color,
    required this.icon,
    required this.name,
    required this.count,
    required this.percentage,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Colored Icon
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 12, color: color),
        ),
        10.w,
        // Name
        Expanded(
          child: Text(
            name,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF0B1B3B),
            ),
          ),
        ),
        // Count
        Text(
          count,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF0B1B3B),
          ),
        ),
        16.w,
        // Percentage
        SizedBox(
          width: 45,
          child: Text(
            percentage,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF7B8694),
            ),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
}

// ENQUIRIES BY LOCATION MAP CARD
const Map<String, LatLng> _districtCoordinates = {
  'kasaragod': LatLng(12.5102, 74.9852),
  'kannur': LatLng(11.8745, 75.3704),
  'kozhikode': LatLng(11.2588, 75.7804),
  'calicut': LatLng(11.2588, 75.7804),
  'wayanad': LatLng(11.6854, 76.1320),
  'malappuram': LatLng(11.0722, 76.0740),
  'palakkad': LatLng(10.7867, 76.6548),
  'thrissur': LatLng(10.5276, 76.2144),
  'ernakulam': LatLng(9.9816, 76.2999),
  'kochi': LatLng(9.9816, 76.2999),
  'idukki': LatLng(9.8500, 76.9700),
  'kottayam': LatLng(9.5916, 76.5224),
  'alappuzha': LatLng(9.4981, 76.3388),
  'pathanamthitta': LatLng(9.2648, 76.7870),
  'kollam': LatLng(8.8932, 76.6141),
  'trivandrum': LatLng(8.5241, 76.9366),
  'tvm': LatLng(8.5241, 76.9366),
};

LatLng? _getCoordinates(String location) {
  final normalized = location.toLowerCase().trim();
  for (final entry in _districtCoordinates.entries) {
    if (normalized.contains(entry.key)) {
      return entry.value;
    }
  }
  return null;
}

class _EnquiriesByLocationCard extends StatelessWidget {
  final List<Lead> leads;

  const _EnquiriesByLocationCard({
    required this.leads,
  });

  @override
  Widget build(BuildContext context) {
    final crmColors = context.crmColors;
    final isDesktop = ResponsiveBuilder.isDesktop(context);

    // Group leads by coordinate
    final Map<LatLng, List<Lead>> groupedLeads = {};
    for (final lead in leads) {
      final latLng = _getCoordinates(lead.location);
      if (latLng != null) {
        groupedLeads.putIfAbsent(latLng, () => []).add(lead);
      }
    }

    final List<Marker> mapMarkers = [];
    groupedLeads.forEach((latLng, leadList) {
      final count = leadList.length;
      if (count > 0) {
        // Find the canonical name from coordinate keys
        String name = leadList.first.location;
        final norm = name.toLowerCase();
        for (final key in _districtCoordinates.keys) {
          if (norm.contains(key)) {
            name = key[0].toUpperCase() + key.substring(1);
            if (name == 'Tvm') name = 'Trivandrum';
            if (name == 'Kochi') name = 'Ernakulam';
            break;
          }
        }

        final isHighlighted = name.toLowerCase().contains('ernakulam') ||
            name.toLowerCase().contains('kozhikode');

        mapMarkers.add(
          Marker(
            point: latLng,
            width: 50,
            height: 50,
            child: _MapPulsingDot(
              label: name,
              count: count,
              isHighlighted: isHighlighted,
            ),
          ),
        );
      }
    });

    String normLoc(Lead l) => l.location.toLowerCase().trim();
    final int kozhikodeCount = leads.where((l) => normLoc(l).contains('kozhikode') || normLoc(l).contains('calicut')).length;
    final int malappuramCount = leads.where((l) => normLoc(l).contains('malappuram')).length;
    final int thrissurCount = leads.where((l) => normLoc(l).contains('thrissur')).length;
    final int ernakulamCount = leads.where((l) => normLoc(l).contains('ernakulam') || normLoc(l).contains('kochi')).length;
    final int trivandrumCount = leads.where((l) => normLoc(l).contains('trivandrum') || normLoc(l).contains('tvm')).length;

    Widget buildMapWidget() {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: FlutterMap(
          options: const MapOptions(
            initialCenter: LatLng(10.5, 76.2), // Center of Kerala
            initialZoom: 7.2,
            minZoom: 5.0,
            maxZoom: 18.0,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.nizan.crm',
            ),
            MarkerLayer(
              markers: mapMarkers,
            ),
          ],
        ),
      );
    }

    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: 24.p,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Card Title Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Enquiries by location',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0B1B3B),
                      ),
                    ),
                    Text(
                      '— interactive live map',
                      style: GoogleFonts.cormorantGaramond(
                        fontStyle: FontStyle.italic,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFFC25A7C),
                      ),
                    ),
                  ],
                ),
                // Live Indicator
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFFD46A92),
                        shape: BoxShape.circle,
                      ),
                    ),
                    8.w,
                    Text(
                      'Enquiry volume',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF7B8694),
                      ),
                    ),
                    16.w,
                    const Icon(Icons.flash_on, size: 12, color: Color(0xFFCBA052)),
                    4.w,
                    Text(
                      'Live',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFCBA052),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            12.h,
            Text(
              '※ Click any district pin to see details',
              style: GoogleFonts.inter(
                fontSize: 11,
                color: const Color(0xFF7B8694),
                fontWeight: FontWeight.w500,
              ),
            ),
            28.h,

            // Content Area split on Desktop
            if (isDesktop)
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    flex: 3,
                    child: Center(
                      child: Container(
                        width: 400,
                        height: 380,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9F7FF).withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: crmColors.border.withValues(alpha: 0.04)),
                        ),
                        child: buildMapWidget(),
                      ),
                    ),
                  ),
                  48.w,
                  // Top Performing Cities List
                  Expanded(
                    flex: 2,
                    child: _TopCitiesList(
                      kozhikode: kozhikodeCount,
                      ernakulam: ernakulamCount,
                      malappuram: malappuramCount,
                      thrissur: thrissurCount,
                      trivandrum: trivandrumCount,
                    ),
                  ),
                ],
              )
            else
              Column(
                children: [
                  Container(
                    width: double.infinity,
                    height: 320,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9F7FF).withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: crmColors.border.withValues(alpha: 0.04)),
                    ),
                    child: buildMapWidget(),
                  ),
                  32.h,
                  _TopCitiesList(
                    kozhikode: kozhikodeCount,
                    ernakulam: ernakulamCount,
                    malappuram: malappuramCount,
                    thrissur: thrissurCount,
                    trivandrum: trivandrumCount,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

// PULSING INTERACTIVE MAP DOT
class _MapPulsingDot extends StatefulWidget {
  final String label;
  final int count;
  final bool isHighlighted;

  const _MapPulsingDot({
    required this.label,
    required this.count,
    this.isHighlighted = false,
  });

  @override
  State<_MapPulsingDot> createState() => _MapPulsingDotState();
}

class _MapPulsingDotState extends State<_MapPulsingDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dotColor = widget.isHighlighted ? const Color(0xFFD46A92) : const Color(0xFFCBA052);
    return GestureDetector(
      onTap: () {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Icon(Icons.location_on, color: dotColor),
                const SizedBox(width: 8),
                Text(widget.label, style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
              ],
            ),
            content: Text(
              'Total enquiries from ${widget.label} is currently ${widget.count}.',
              style: GoogleFonts.inter(fontSize: 14),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Close', style: TextStyle(color: dotColor)),
              ),
            ],
          ),
        );
      },
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // Pulse Ring
          ScaleTransition(
            scale: Tween<double>(begin: 0.8, end: 2.2).animate(
              CurvedAnimation(parent: _controller, curve: Curves.easeOut),
            ),
            child: FadeTransition(
              opacity: Tween<double>(begin: 0.6, end: 0.0).animate(
                CurvedAnimation(parent: _controller, curve: Curves.easeOut),
              ),
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          // Center Solid Circle with Lead Count Badge
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: dotColor.withValues(alpha: 0.4),
                  blurRadius: 4,
                  spreadRadius: 2,
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              '${widget.count}',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// TOP PERFORMING CITIES LIST
class _TopCitiesList extends StatelessWidget {
  final int kozhikode;
  final int ernakulam;
  final int malappuram;
  final int thrissur;
  final int trivandrum;

  const _TopCitiesList({
    required this.kozhikode,
    required this.ernakulam,
    required this.malappuram,
    required this.thrissur,
    required this.trivandrum,
  });

  @override
  Widget build(BuildContext context) {
    final locations = [
      (name: 'Kozhikode', count: kozhikode, progress: 0.8),
      (name: 'Ernakulam', count: ernakulam, progress: 0.95),
      (name: 'Malappuram', count: malappuram, progress: 0.7),
      (name: 'Thrissur', count: thrissur, progress: 0.65),
      (name: 'Trivandrum', count: trivandrum, progress: 0.6),
    ]..sort((a, b) => b.count.compareTo(a.count));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'TOP PERFORMING CITIES',
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF7B8694),
            letterSpacing: 1.2,
          ),
        ),
        16.h,
        ...locations.map((loc) {
          final maxCount = locations.fold<int>(1, (max, l) => l.count > max ? l.count : max);
          final double ratio = loc.count / maxCount;
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      loc.name,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF0B1B3B),
                      ),
                    ),
                    Text(
                      '${loc.count} leads',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0B1B3B),
                      ),
                    ),
                  ],
                ),
                8.h,
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: ratio.clamp(0.05, 1.0),
                    minHeight: 6,
                    backgroundColor: const Color(0xFFF1EDE6),
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFCBA052)),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
class _ArtistDashboardView extends StatelessWidget {
  const _ArtistDashboardView({
    required this.isDesktop,
    required this.isTablet,
    required this.allBookings,
    this.employeeId,
    this.employeeName,
  });

  final bool isDesktop;
  final bool isTablet;
  final List<Booking> allBookings;
  final String? employeeId;
  final String? employeeName;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final theme = Theme.of(context);

    // Bookings are already filtered by employeeId from the backend provider
    final myBookings = allBookings;

    final now = DateTime.now();
    final todayBookings = myBookings
        .where(
          (b) =>
              b.serviceStart.year == now.year &&
              b.serviceStart.month == now.month &&
              b.serviceStart.day == now.day,
        )
        .toList();

    final upcomingBookings =
        myBookings.where((b) => b.serviceStart.isAfter(now)).toList()
          ..sort((a, b) => a.serviceStart.compareTo(b.serviceStart));

    final totalEarnings = myBookings
        .where((b) => b.status.toLowerCase() == 'completed')
        .fold<double>(0, (sum, b) => sum + b.totalPrice);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Section
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [crm.primary, crm.sidebar],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: crm.primary.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Hello, ${employeeName ?? "Artist"}',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          4.h,
                          Text(
                            todayBookings.isEmpty
                                ? 'No works today'
                                : 'You have ${todayBookings.length} tasks',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.notifications_none,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                24.h,
                const Divider(color: Colors.white24),
                16.h,
                Row(
                  children: [
                    _HeaderMiniStat(
                      label: 'Total Collected',
                      value: '₹${totalEarnings.toStringAsFixed(0)}',
                    ),
                    const VerticalDivider(
                      color: Colors.white24,
                      indent: 8,
                      endIndent: 8,
                    ),
                    _HeaderMiniStat(
                      label: 'Pending',
                      value: '${upcomingBookings.length} Works',
                    ),
                  ],
                ),
              ],
            ),
          ),
          24.h,
          Text(
            'Performance Overview',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          16.h,
          SizedBox(
            height: 160,
            child: ListView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              children: [
                _ModernStatCard(
                  title: 'Completed',
                  value:
                      '${myBookings.where((b) => b.status.toLowerCase() == "completed").length}',
                  icon: Icons.task_alt_rounded,
                  color: Colors.green,
                ),
                16.w,
                _ModernStatCard(
                  title: 'In Progress',
                  value:
                      '${myBookings.where((b) => b.status.toLowerCase() == "confirmed").length}',
                  icon: Icons.sync_rounded,
                  color: Colors.blue,
                ),
                16.w,
                _ModernStatCard(
                  title: 'Assigned',
                  value: '${myBookings.length}',
                  icon: Icons.assignment_rounded,
                  color: crm.primary,
                ),
              ],
            ),
          ),
          32.h,
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Today\'s Schedule',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              TextButton(
                onPressed: () => context.go('/works'),
                child: const Text('View All'),
              ),
            ],
          ),
          12.h,
          if (todayBookings.isEmpty)
            _buildEmptyState(context, 'Relax! No assignments for today.')
          else
            ...todayBookings.map(
              (b) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ArtistMiniCard(booking: b),
              ),
            ),
          32.h,
          // ── Upcoming (next 3) ─────────────────────────────
          if (upcomingBookings.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Upcoming',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                TextButton(
                  onPressed: () => context.go('/works'),
                  child: const Text('See All'),
                ),
              ],
            ),
            12.h,
            ...upcomingBookings
                .take(3)
                .map(
                  (b) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _ArtistMiniCard(booking: b, dimmed: true),
                  ),
                ),
            20.h,
          ],
          _ArtistQuickActions(),
          40.h,
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, String message) {
    return Container(
      padding: const EdgeInsets.all(32),
      width: double.infinity,
      decoration: BoxDecoration(
        color: context.crmColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.crmColors.border),
      ),
      child: Column(
        children: [
          Icon(
            Icons.event_busy_outlined,
            size: 48,
            color: context.crmColors.textSecondary.withValues(alpha: 0.5),
          ),
          16.h,
          Text(
            message,
            style: TextStyle(color: context.crmColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Artist Mini Card (used on dashboard Today/Upcoming sections)
// ─────────────────────────────────────────────────────────────────────────────
class _ArtistMiniCard extends StatelessWidget {
  final Booking booking;
  final bool dimmed;

  const _ArtistMiniCard({required this.booking, this.dimmed = false});

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
        return const Color(0xFF3B82F6);
      case 'completed':
        return const Color(0xFF22C55E);
      case 'pending':
        return const Color(0xFFF97316);
      case 'cancelled':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF8B5CF6);
    }
  }

  String _fmtTime(DateTime d) {
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final m = d.minute.toString().padLeft(2, '0');
    final ap = d.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $ap';
  }

  String _fmt(DateTime d) {
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
    return '${d.day} ${months[d.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final statusColor = _statusColor(booking.status);
    final opacity = dimmed ? 0.65 : 1.0;

    return Opacity(
      opacity: opacity,
      child: Container(
        decoration: BoxDecoration(
          color: crm.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: crm.border.withValues(alpha: 0.5)),
          boxShadow: dimmed
              ? null
              : [
                  BoxShadow(
                    color: statusColor.withValues(alpha: 0.1),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    statusColor.withValues(alpha: 0.2),
                    statusColor.withValues(alpha: 0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                border: Border.all(color: statusColor.withValues(alpha: 0.2)),
              ),
              alignment: Alignment.center,
              child: Text(
                booking.initials,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  color: statusColor,
                ),
              ),
            ),
            16.w,

            // Name + service
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    booking.customerName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  4.h,
                  Text(
                    booking.service,
                    style: TextStyle(
                      fontSize: 12,
                      color: crm.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            12.w,

            // Time + date
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _fmtTime(booking.serviceStart),
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    color: statusColor,
                  ),
                ),
                6.h,
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Text(
                    _fmt(booking.serviceStart),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ArtistQuickActions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Quick Actions',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            20.h,
            _QuickActionItem(
              icon: Icons.assignment_outlined,
              title: 'All My Works',
              onTap: () => context.go('/works'),
              color: crm.primary,
            ),
            _QuickActionItem(
              icon: Icons.account_balance_wallet_outlined,
              title: 'My Finance',
              onTap: () => context.go('/finance'),
              color: Colors.green,
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Color color;

  const _QuickActionItem({
    required this.icon,
    required this.title,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: onTap,
    );
  }
}

class _HeaderMiniStat extends StatelessWidget {
  final String label;
  final String value;

  const _HeaderMiniStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        4.h,
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _ModernStatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _ModernStatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return Container(
      width: 170,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.12),
            color.withValues(alpha: 0.02),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 22),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: TextStyle(
                  color: crm.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
