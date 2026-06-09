import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../core/extensions/space_extension.dart';
import '../../core/theme/crm_theme.dart';
import '../../core/utils/responsive_builder.dart';
import '../../services/employee_service.dart';
import '../../core/providers/booking_provider.dart';
import '../../core/models/booking.dart';
import '../../core/models/employee.dart';
import 'dart:math';

class SlotManagementScreen extends HookConsumerWidget {
  const SlotManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crmColors = context.crmColors;
    final isMobile = ResponsiveBuilder.isMobile(context);
    final isTablet = ResponsiveBuilder.isTablet(context);
    
    // Providers
    final asyncEmployees = ref.watch(employeesProvider);
    final asyncBookings = ref.watch(bookingProvider);
    
    // State
    final selectedRegion = useState<String?>(null);
    final selectedDistrict = useState<String?>(null);
    final selectedTime = useState<TimeOfDay?>(null);
    final selectedTimeframe = useState<String>('Monthly');
    final selectedDate = useState<DateTime>(DateTime.now());

    // Extract bookings and artists
    final bookings = asyncBookings.value ?? [];
    final artists = asyncEmployees.value?.where((e) => e.artistRole == 'artist').toList() ?? [];

    // Filter artists based on selected region and district
    final filteredArtists = artists.where((artist) {
      if (selectedRegion.value != null && artist.regionName != selectedRegion.value) {
        return false;
      }
      if (selectedDistrict.value != null && artist.regionName != selectedDistrict.value) {
        return false;
      }
      return true;
    }).toList();

    // Timeframe boundaries
    DateTime getStartDate(String timeframe, DateTime baseDate) {
      if (timeframe == 'Daily') {
        return DateTime(baseDate.year, baseDate.month, baseDate.day);
      } else if (timeframe == 'Monthly') {
        return DateTime(baseDate.year, baseDate.month, 1);
      } else { // Financial Year (starting April 1st)
        final startYear = baseDate.month >= 4 ? baseDate.year : baseDate.year - 1;
        return DateTime(startYear, 4, 1);
      }
    }

    DateTime getEndDate(String timeframe, DateTime baseDate) {
      if (timeframe == 'Daily') {
        return DateTime(baseDate.year, baseDate.month, baseDate.day, 23, 59, 59);
      } else if (timeframe == 'Monthly') {
        final nextMonth = DateTime(baseDate.year, baseDate.month + 1, 1);
        return nextMonth.subtract(const Duration(seconds: 1));
      } else { // Financial Year (ending March 31st)
        final startYear = baseDate.month >= 4 ? baseDate.year : baseDate.year - 1;
        return DateTime(startYear + 1, 3, 31, 23, 59, 59);
      }
    }

    final startDate = getStartDate(selectedTimeframe.value, selectedDate.value);
    final endDate = getEndDate(selectedTimeframe.value, selectedDate.value);
    final totalDays = endDate.difference(startDate).inDays + 1;

    // Filter bookings based on Region, District and selected timeframe spread
    final rangeBookings = bookings.where((b) {
      final status = b.status.toLowerCase();
      if (status == 'cancelled' || status == 'rejected' || status == 'postponed') return false;

      final dates = b.selectedDates.isNotEmpty ? b.selectedDates : [b.bookingDate];
      final hasDateInSpread = dates.any((d) => 
        !d.isBefore(startDate) && !d.isAfter(endDate)
      );
      if (!hasDateInSpread) return false;

      if (selectedRegion.value != null && b.region != selectedRegion.value) {
        return false;
      }
      if (selectedDistrict.value != null && b.region != selectedDistrict.value) {
        return false;
      }

      return true;
    }).toList();

    // Calculate booked slots
    int bookedSlots = 0;
    int assignedSlotsCount = 0;
    int unassignedSlotsCount = 0;

    for (final Booking b in rangeBookings) {
      final dates = b.selectedDates.isNotEmpty ? b.selectedDates : [b.bookingDate];
      final activeDates = dates.where((d) => !d.isBefore(startDate) && !d.isAfter(endDate)).toList();
      
      for (final _ in activeDates) {
        if (b.assignedStaff.isEmpty) {
          bookedSlots += 1;
          unassignedSlotsCount += 1;
        } else {
          final matchingStaffCount = b.assignedStaff.where((staff) {
            return filteredArtists.any((a) => a.id == staff.employeeId);
          }).length;

          if (matchingStaffCount == 0) {
            bookedSlots += 1;
            unassignedSlotsCount += 1;
          } else {
            bookedSlots += matchingStaffCount;
            assignedSlotsCount += matchingStaffCount;
          }
        }
      }
    }

    final totalSlots = filteredArtists.length * 3 * totalDays;
    final remainingSlots = max(0, totalSlots - bookedSlots);
    final double utilizationRate = totalSlots > 0 
        ? (bookedSlots / totalSlots * 100).clamp(0.0, 100.0) 
        : (bookedSlots > 0 ? 100.0 : 0.0);

    // Weekday booking count calculation
    final Map<int, List<int>> weekdayBookingCounts = {
      DateTime.monday: [0, 0], // [booked, capacity]
      DateTime.tuesday: [0, 0],
      DateTime.wednesday: [0, 0],
      DateTime.thursday: [0, 0],
      DateTime.friday: [0, 0],
      DateTime.saturday: [0, 0],
      DateTime.sunday: [0, 0],
    };

    if (totalSlots > 0) {
      for (int i = 0; i < totalDays; i++) {
        final currentDay = startDate.add(Duration(days: i));
        final weekday = currentDay.weekday;
        
        final dayCapacity = filteredArtists.length * 3;
        weekdayBookingCounts[weekday]![1] += dayCapacity;

        int dayBookings = 0;
        for (final Booking b in rangeBookings) {
          final dates = b.selectedDates.isNotEmpty ? b.selectedDates : [b.bookingDate];
          final isOnThisDay = dates.any((d) => 
            d.year == currentDay.year && d.month == currentDay.month && d.day == currentDay.day
          );
          if (isOnThisDay) {
            if (b.assignedStaff.isEmpty) {
              dayBookings += 1;
            } else {
              final matchingCount = b.assignedStaff.where((staff) => 
                filteredArtists.any((a) => a.id == staff.employeeId)
              ).length;
              dayBookings += matchingCount == 0 ? 1 : matchingCount;
            }
          }
        }
        weekdayBookingCounts[weekday]![0] += dayBookings;
      }
    }

    // High demand dates
    final List<Map<String, dynamic>> highDemandDates = [];
    if (totalSlots > 0 && selectedTimeframe.value != 'Daily') {
      for (int i = 0; i < totalDays; i++) {
        final currentDay = startDate.add(Duration(days: i));
        final dayCapacity = filteredArtists.length * 3;
        if (dayCapacity == 0) continue;

        int dayBookings = 0;
        for (final Booking b in rangeBookings) {
          final dates = b.selectedDates.isNotEmpty ? b.selectedDates : [b.bookingDate];
          final isOnThisDay = dates.any((d) => 
            d.year == currentDay.year && d.month == currentDay.month && d.day == currentDay.day
          );
          if (isOnThisDay) {
            if (b.assignedStaff.isEmpty) {
              dayBookings += 1;
            } else {
              final matchingCount = b.assignedStaff.where((staff) => 
                filteredArtists.any((a) => a.id == staff.employeeId)
              ).length;
              dayBookings += matchingCount == 0 ? 1 : matchingCount;
            }
          }
        }
        
        final dayRate = (dayBookings / dayCapacity * 100);
        if (dayRate >= 80.0) {
          highDemandDates.add({
            'date': currentDay,
            'rate': dayRate,
            'booked': dayBookings,
            'capacity': dayCapacity,
          });
        }
      }
      highDemandDates.sort((a, b) => (b['rate'] as double).compareTo(a['rate'] as double));
    }

    // Region comparison stats
    final Map<String, List<int>> regionStats = {};
    for (final artist in artists) {
      if (artist.regionName.isNotEmpty) {
        regionStats.putIfAbsent(artist.regionName, () => [0, 0]);
        regionStats[artist.regionName]![0] += 1;
      }
    }
    for (final Booking b in bookings) {
      final status = b.status.toLowerCase();
      if (status == 'cancelled' || status == 'rejected' || status == 'postponed') continue;
      final dates = b.selectedDates.isNotEmpty ? b.selectedDates : [b.bookingDate];
      final hasDateInSpread = dates.any((d) => 
        !d.isBefore(startDate) && !d.isAfter(endDate)
      );
      if (!hasDateInSpread) continue;

      if (b.region.isNotEmpty) {
        regionStats.putIfAbsent(b.region, () => [0, 0]);
        final activeDates = dates.where((d) => !d.isBefore(startDate) && !d.isAfter(endDate)).toList();
        for (final _ in activeDates) {
          if (b.assignedStaff.isEmpty) {
            regionStats[b.region]![1] += 1;
          } else {
            final matchingCount = b.assignedStaff.where((staff) {
              final emp = asyncEmployees.value?.firstWhere((e) => e.id == staff.employeeId, orElse: () => const Employee(id: '', name: '', email: '', type: '', artistRole: '', specialization: '', phone: '', status: '', regionId: '', regionName: '', category: ''));
              return emp != null && emp.regionName == b.region;
            }).length;
            regionStats[b.region]![1] += matchingCount == 0 ? 1 : matchingCount;
          }
        }
      }
    }

    final uniqueRegions = artists
        .map((e) => e.regionName)
        .where((r) => r.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
      
    final mockDistricts = [
      'Alappuzha',
      'Ernakulam',
      'Idukki',
      'Kannur',
      'Kasaragod',
      'Kollam',
      'Kottayam',
      'Kozhikode',
      'Malappuram',
      'Palakkad',
      'Pathanamthitta',
      'Thiruvananthapuram',
      'Thrissur',
      'Wayanad'
    ];

    Future<void> selectTime(BuildContext context) async {
      final TimeOfDay? picked = await showTimePicker(
        context: context,
        initialTime: selectedTime.value ?? TimeOfDay.now(),
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: ColorScheme.dark(
                primary: crmColors.primary,
                onPrimary: Colors.white,
                surface: crmColors.surface,
                onSurface: crmColors.textPrimary,
              ),
            ),
            child: child!,
          );
        },
      );
      if (picked != null && picked != selectedTime.value) {
        selectedTime.value = picked;
      }
    }

    Future<void> selectDate(BuildContext context) async {
      final DateTime? picked = await showDatePicker(
        context: context,
        initialDate: selectedDate.value,
        firstDate: DateTime(2020),
        lastDate: DateTime(2100),
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: ColorScheme.dark(
                primary: crmColors.primary,
                onPrimary: Colors.white,
                surface: crmColors.surface,
                onSurface: crmColors.textPrimary,
              ),
            ),
            child: child!,
          );
        },
      );
      if (picked != null && picked != selectedDate.value) {
        selectedDate.value = picked;
      }
    }

    Color getUtilizationColor(double rate) {
      if (rate < 50) return crmColors.success;
      if (rate < 80) return Colors.orange;
      return crmColors.destructive;
    }

    String getWeekdayName(int weekday) {
      switch (weekday) {
        case DateTime.monday: return 'Mon';
        case DateTime.tuesday: return 'Tue';
        case DateTime.wednesday: return 'Wed';
        case DateTime.thursday: return 'Thu';
        case DateTime.friday: return 'Fri';
        case DateTime.saturday: return 'Sat';
        case DateTime.sunday: return 'Sun';
        default: return '';
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Slot Management Dashboard'),
        backgroundColor: crmColors.surface,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: 24.p,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // TOP BAR: Dropdowns & Time
            Wrap(
              spacing: 16,
              runSpacing: 16,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 200,
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: selectedRegion.value,
                    decoration: const InputDecoration(
                      labelText: 'Select Region',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('All Regions')),
                      ...uniqueRegions.map((r) => DropdownMenuItem(value: r, child: Text(r, overflow: TextOverflow.ellipsis))),
                    ],
                    onChanged: (val) => selectedRegion.value = val,
                  ),
                ),
                SizedBox(
                  width: 200,
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: selectedDistrict.value,
                    decoration: const InputDecoration(
                      labelText: 'Select District',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('All Districts')),
                      ...mockDistricts.map((d) => DropdownMenuItem(value: d, child: Text(d, overflow: TextOverflow.ellipsis))),
                    ],
                    onChanged: (val) => selectedDistrict.value = val,
                  ),
                ),
                SizedBox(
                  width: 200,
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: selectedTimeframe.value,
                    decoration: const InputDecoration(
                      labelText: 'Timeframe',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Daily', child: Text('Daily')),
                      DropdownMenuItem(value: 'Monthly', child: Text('Monthly')),
                      DropdownMenuItem(value: 'Financial Year', child: Text('Financial Year', overflow: TextOverflow.ellipsis)),
                    ],
                    onChanged: (val) {
                      if (val != null) selectedTimeframe.value = val;
                    },
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => selectDate(context),
                  icon: const Icon(Icons.calendar_today),
                  label: Text('Date: ${selectedDate.value.day}/${selectedDate.value.month}/${selectedDate.value.year}'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => selectTime(context),
                  icon: const Icon(Icons.access_time),
                  label: Text(selectedTime.value != null 
                    ? 'Time: ${selectedTime.value!.format(context)}' 
                    : 'Select Slot Time'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                ),
                if (selectedRegion.value != null || 
                    selectedDistrict.value != null || 
                    selectedTime.value != null || 
                    selectedTimeframe.value != 'Monthly' ||
                    selectedDate.value.day != DateTime.now().day ||
                    selectedDate.value.month != DateTime.now().month ||
                    selectedDate.value.year != DateTime.now().year)
                  TextButton.icon(
                    onPressed: () {
                      selectedRegion.value = null;
                      selectedDistrict.value = null;
                      selectedTime.value = null;
                      selectedTimeframe.value = 'Monthly';
                      selectedDate.value = DateTime.now();
                    },
                    icon: const Icon(Icons.clear),
                    label: const Text('Clear Filters'),
                  ),
              ],
            ),
            24.h,
            // DASHBOARD CARDS
            LayoutBuilder(
              builder: (context, constraints) {
                final cardWidth = isMobile 
                    ? constraints.maxWidth 
                    : (isTablet 
                        ? (constraints.maxWidth - 16) / 2 
                        : (constraints.maxWidth - 48) / 4);
                return Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    _StatCard(
                      title: 'Total Artists',
                      value: filteredArtists.length.toString(),
                      icon: Icons.people_outline,
                      trend: '${artists.length} total in system',
                      width: cardWidth,
                      color: crmColors.primary,
                    ),
                    _StatCard(
                      title: 'Total Slots',
                      value: totalSlots.toString(),
                      icon: Icons.event_seat_outlined,
                      trend: '3 slots/artist/day',
                      width: cardWidth,
                      color: crmColors.secondary,
                    ),
                    _StatCard(
                      title: 'Booked Slots',
                      value: bookedSlots.toString(),
                      icon: Icons.assignment_outlined,
                      trend: '$assignedSlotsCount assigned, $unassignedSlotsCount pending',
                      width: cardWidth,
                      color: Colors.orange,
                    ),
                    _StatCard(
                      title: 'Slot Utilization (SUA)',
                      value: '${utilizationRate.toStringAsFixed(1)}%',
                      icon: Icons.trending_up_outlined,
                      trend: '$remainingSlots slots remaining',
                      width: cardWidth,
                      color: getUtilizationColor(utilizationRate),
                    ),
                  ],
                );
              },
            ),
            32.h,
            // ANALYTICS BREAKDOWN ROW
            if (!isMobile)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: _buildSlotAllocationCard(context, assignedSlotsCount, unassignedSlotsCount, remainingSlots, totalSlots),
                  ),
                  16.w,
                  Expanded(
                    flex: 2,
                    child: _buildWeekdayLoadCard(context, weekdayBookingCounts, getWeekdayName),
                  ),
                ],
              )
            else ...[
              _buildSlotAllocationCard(context, assignedSlotsCount, unassignedSlotsCount, remainingSlots, totalSlots),
              16.h,
              _buildWeekdayLoadCard(context, weekdayBookingCounts, getWeekdayName),
            ],
            24.h,
            // HIGH DEMAND ALERTS & REGION HEATMAP ROW
            if (!isMobile)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _buildHighDemandAlerts(context, highDemandDates),
                  ),
                  16.w,
                  Expanded(
                    child: _buildRegionComparisonCard(context, regionStats),
                  ),
                ],
              )
            else ...[
              _buildHighDemandAlerts(context, highDemandDates),
              16.h,
              _buildRegionComparisonCard(context, regionStats),
            ],
            32.h,
            // ARTIST PREDICTION SECTION
            Text(
              'Artist Assignment Prediction',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            8.h,
            Text(
              'AI-driven matching based on location distance, slot utilization capacity, and workload equations.',
              style: TextStyle(color: crmColors.textSecondary),
            ),
            16.h,
            Card(
              color: crmColors.surface,
              margin: EdgeInsets.zero,
              child: asyncEmployees.when(
                loading: () => const SizedBox(
                  height: 200,
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (err, stack) => SizedBox(
                  height: 200,
                  child: Center(child: Text('Error: $err')),
                ),
                data: (_) {
                  if (filteredArtists.isEmpty) {
                    return const SizedBox(
                      height: 150,
                      child: Center(child: Text('No artists available for selected filters.')),
                    );
                  }

                  // Calculate Prediction Scores
                  final predictions = filteredArtists.map((artist) {
                    double score = 65.0; // Higher baseline
                    
                    if (selectedRegion.value != null && artist.regionName == selectedRegion.value) {
                      score += 25.0; // Region match
                    }

                    if (selectedTime.value != null) {
                      final hour = selectedTime.value!.hour;
                      if (hour >= 8 && hour <= 18) {
                        score += 10.0;
                      }
                    }

                    // Calculate workload of this artist on the selected day
                    int artistDayBookings = 0;
                    for (final Booking b in bookings) {
                      final status = b.status.toLowerCase();
                      if (status == 'cancelled' || status == 'rejected' || status == 'postponed') continue;
                      
                      final dates = b.selectedDates.isNotEmpty ? b.selectedDates : [b.bookingDate];
                      final isOnThisDay = dates.any((d) => 
                        d.year == selectedDate.value.year && 
                        d.month == selectedDate.value.month && 
                        d.day == selectedDate.value.day
                      );
                      if (isOnThisDay) {
                        final isAssigned = b.assignedStaff.any((staff) => staff.employeeId == artist.id);
                        if (isAssigned) {
                          artistDayBookings += 1;
                        }
                      }
                    }

                    // Workload constraint deduction: 30 points penalty per booking
                    score -= (artistDayBookings * 30.0);
                    score = score.clamp(0.0, 100.0);

                    return {
                      'artist': artist,
                      'score': score,
                      'bookingsCount': artistDayBookings,
                    };
                  }).toList();

                  // Sort by highest score
                  predictions.sort((a, b) => (b['score'] as double).compareTo(a['score'] as double));

                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: predictions.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = predictions[index];
                      final artist = item['artist'] as Employee;
                      final score = item['score'] as double;
                      final dayBookings = item['bookingsCount'] as int;
                      
                      final isHighMatch = score >= 75;
                      final isMediumMatch = score >= 40 && score < 75;
                      final isFullyBooked = dayBookings >= 3;

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        leading: CircleAvatar(
                          backgroundColor: crmColors.primary.withValues(alpha: 0.1),
                          child: Text(
                            artist.name.isNotEmpty ? artist.name.substring(0, 1).toUpperCase() : '?',
                            style: TextStyle(color: crmColors.primary),
                          ),
                        ),
                        title: Row(
                          children: [
                            Text(
                              artist.name,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            if (isFullyBooked) ...[
                              8.w,
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: crmColors.destructive.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Fully Booked',
                                  style: TextStyle(color: crmColors.destructive, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ]
                          ],
                        ),
                        subtitle: Text(
                          'Region: ${artist.regionName.isNotEmpty ? artist.regionName : "N/A"} • Specialization: ${artist.specialization.isNotEmpty ? artist.specialization : "General"}',
                          style: TextStyle(color: crmColors.textSecondary, fontSize: 13),
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${score.toStringAsFixed(1)}% Match',
                              style: TextStyle(
                                color: isFullyBooked 
                                    ? crmColors.destructive 
                                    : (isHighMatch 
                                        ? crmColors.success 
                                        : (isMediumMatch ? Colors.orange : crmColors.destructive)),
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              isFullyBooked 
                                  ? 'Max Capacity Reached' 
                                  : '$dayBookings/3 Slots Occupied Today',
                              style: TextStyle(color: crmColors.textSecondary, fontSize: 11),
                            )
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlotAllocationCard(BuildContext context, int assigned, int unassigned, int free, int total) {
    final crmColors = context.crmColors;
    
    final double assignedPct = total > 0 ? (assigned / total) : 0.0;
    final double unassignedPct = total > 0 ? (unassigned / total) : 0.0;
    final double freePct = total > 0 ? (free / total) : 1.0;

    return Card(
      color: crmColors.surface,
      elevation: 1,
      child: Padding(
        padding: 20.p,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Slot Allocation Breakdown',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            16.h,
            // Stacked bar chart
            Container(
              height: 24,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: crmColors.border.withValues(alpha: 0.3),
              ),
              clipBehavior: Clip.antiAlias,
              child: Row(
                children: [
                  if (assigned > 0)
                    Expanded(
                      flex: (assignedPct * 1000).toInt(),
                      child: Container(
                        color: crmColors.primary,
                        child: const Center(child: Text('', style: TextStyle(fontSize: 10, color: Colors.white))),
                      ),
                    ),
                  if (unassigned > 0)
                    Expanded(
                      flex: (unassignedPct * 1000).toInt(),
                      child: Container(
                        color: Colors.orange,
                        child: const Center(child: Text('', style: TextStyle(fontSize: 10, color: Colors.white))),
                      ),
                    ),
                  if (free > 0)
                    Expanded(
                      flex: (freePct * 1000).toInt(),
                      child: Container(
                        color: crmColors.border.withValues(alpha: 0.5),
                      ),
                    ),
                ],
              ),
            ),
            20.h,
            // Legend
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildLegendItem(context, 'Assigned slots', '$assigned', crmColors.primary),
                _buildLegendItem(context, 'Pending/Unassigned', '$unassigned', Colors.orange),
                _buildLegendItem(context, 'Free capacity', '$free', crmColors.textSecondary.withValues(alpha: 0.5)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(BuildContext context, String label, String value, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        8.w,
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: context.crmColors.textSecondary, fontSize: 11)),
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ],
        )
      ],
    );
  }

  Widget _buildWeekdayLoadCard(BuildContext context, Map<int, List<int>> weekdayCounts, String Function(int) getName) {
    final crmColors = context.crmColors;
    
    // Sort weekdays from Monday to Sunday
    final sortedDays = [
      DateTime.monday,
      DateTime.tuesday,
      DateTime.wednesday,
      DateTime.thursday,
      DateTime.friday,
      DateTime.saturday,
      DateTime.sunday,
    ];

    return Card(
      color: crmColors.surface,
      elevation: 1,
      child: Padding(
        padding: 20.p,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Weekly Peak Load Patterns',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            16.h,
            ...sortedDays.map((day) {
              final stats = weekdayCounts[day]!;
              final booked = stats[0];
              final capacity = stats[1];
              final double rate = capacity > 0 ? (booked / capacity) : 0.0;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6.0),
                child: Row(
                  children: [
                    SizedBox(
                      width: 40,
                      child: Text(getName(day), style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: rate,
                          minHeight: 8,
                          backgroundColor: crmColors.border.withValues(alpha: 0.3),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            rate > 0.8 ? crmColors.destructive : (rate > 0.5 ? Colors.orange : crmColors.primary),
                          ),
                        ),
                      ),
                    ),
                    12.w,
                    SizedBox(
                      width: 60,
                      child: Text(
                        '${(rate * 100).toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontWeight: FontWeight.bold, 
                          color: rate > 0.8 ? crmColors.destructive : crmColors.textPrimary,
                        ),
                        textAlign: TextAlign.end,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildHighDemandAlerts(BuildContext context, List<Map<String, dynamic>> alerts) {
    final crmColors = context.crmColors;
    return Card(
      color: crmColors.surface,
      elevation: 1,
      child: Padding(
        padding: 20.p,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: crmColors.destructive, size: 20),
                8.w,
                Text(
                  'High Demand Dates (>80%)',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            16.h,
            if (alerts.isEmpty)
              SizedBox(
                height: 120,
                child: Center(
                  child: Text(
                    'No critical capacity dates detected.',
                    style: TextStyle(color: crmColors.textSecondary, fontStyle: FontStyle.italic),
                  ),
                ),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 200),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: alerts.length,
                  itemBuilder: (context, index) {
                    final alert = alerts[index];
                    final date = alert['date'] as DateTime;
                    final rate = alert['rate'] as double;
                    final booked = alert['booked'] as int;
                    final capacity = alert['capacity'] as int;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: crmColors.destructive.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: crmColors.destructive.withValues(alpha: 0.15)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${date.day}/${date.month}/${date.year}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '${rate.toStringAsFixed(0)}% Booked ($booked/$capacity)',
                            style: TextStyle(color: crmColors.destructive, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRegionComparisonCard(BuildContext context, Map<String, List<int>> stats) {
    final crmColors = context.crmColors;
    final entries = stats.entries.toList();

    return Card(
      color: crmColors.surface,
      elevation: 1,
      child: Padding(
        padding: 20.p,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Regional Slot Comparison',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            16.h,
            if (entries.isEmpty)
              const SizedBox(
                height: 120,
                child: Center(child: Text('No regional stats found.')),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 200),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: entries.length,
                  itemBuilder: (context, index) {
                    final entry = entries[index];
                    final regionName = entry.key;
                    final artistsCount = entry.value[0];
                    final bookedCount = entry.value[1];
                    final int capacity = artistsCount * 3;
                    final double rate = capacity > 0 ? (bookedCount / capacity * 100) : 0.0;

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            regionName,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Row(
                            children: [
                              Text('$bookedCount/$capacity slots', style: TextStyle(color: crmColors.textSecondary)),
                              16.w,
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: rate > 80 ? crmColors.destructive.withValues(alpha: 0.1) : (rate > 50 ? Colors.orange.withValues(alpha: 0.1) : crmColors.success.withValues(alpha: 0.1)),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '${rate.toStringAsFixed(0)}%',
                                  style: TextStyle(
                                    color: rate > 80 ? crmColors.destructive : (rate > 50 ? Colors.orange : crmColors.success),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          )
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final String trend;
  final double width;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.trend,
    required this.width,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final crmColors = context.crmColors;
    return SizedBox(
      width: width,
      child: Card(
        color: crmColors.surface,
        elevation: 1,
        child: Padding(
          padding: 20.p,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        color: crmColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Container(
                    padding: 8.p,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, size: 20, color: color),
                  ),
                ],
              ),
              16.h,
              Text(
                value,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: crmColors.textPrimary,
                ),
              ),
              8.h,
              Text(
                trend,
                style: TextStyle(
                  color: crmColors.textSecondary,
                  fontSize: 12,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
