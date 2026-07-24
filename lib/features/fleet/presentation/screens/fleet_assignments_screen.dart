import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:nizan_crm/core/extensions/space_extension.dart';
import 'package:nizan_crm/core/models/booking.dart';
import 'package:nizan_crm/core/models/employee.dart';
import 'package:nizan_crm/features/fleet/data/vehicle.dart';
import 'package:nizan_crm/core/providers/booking_provider.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/core/utils/responsive_builder.dart';
import 'package:nizan_crm/services/employee_service.dart';
import 'package:nizan_crm/features/fleet/controllers/vehicle_controller.dart';
import 'package:nizan_crm/features/fleet/presentation/screens/fleet_mobile_ui.dart';

enum AssignmentFilter { all, unassigned, assigned }

class FleetAssignmentsScreen extends ConsumerStatefulWidget {
  const FleetAssignmentsScreen({super.key});

  @override
  ConsumerState<FleetAssignmentsScreen> createState() =>
      _FleetAssignmentsScreenState();
}

class _FleetAssignmentsScreenState
    extends ConsumerState<FleetAssignmentsScreen> {
  String _searchQuery = '';
  AssignmentFilter _assignmentFilter = AssignmentFilter.all;
  String? _activeBookingId;
  DateTime _selectedMonth = DateTime.now();
  bool _filterByMonth = true;

  // Form Controllers
  final _distCtrl = TextEditingController();
  final _timeCtrl = TextEditingController();
  String? _selectedDriverId;
  String? _selectedVehicleId;
  bool _saving = false;

  Future<void> _openMapUrl(String url, BuildContext context) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open Google Maps link.')),
      );
    }
  }

  Future<void> _makePhoneCall(String phoneNumber, BuildContext context) async {
    final cleanPhone = phoneNumber.replaceAll(RegExp(r'\s+'), '');
    final uri = Uri.tryParse('tel:$cleanPhone');
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not launch phone call for $phoneNumber.')),
      );
    }
  }

  @override
  void dispose() {
    _distCtrl.dispose();
    _timeCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveAssignment(Booking booking) async {
    setState(() => _saving = true);
    try {
      final selectedDriverId = _selectedDriverId;
      final selectedVehicleId = _selectedVehicleId;

      final drivers = ref.read(employeesProvider).value ?? const <Employee>[];
      final vehicles = ref.read(vehiclesProvider).value ?? const <Vehicle>[];

      final driver = drivers.cast<Employee?>().firstWhere(
            (d) => d?.id == selectedDriverId,
            orElse: () => null,
          );
      final vehicle = vehicles.cast<Vehicle?>().firstWhere(
            (v) => v?.id == selectedVehicleId,
            orElse: () => null,
          );

      // Construct travel mode string based on vehicle name/reg
      String travelMode = booking.travelMode;
      if (vehicle != null) {
        travelMode = vehicle.registrationNumber.isNotEmpty
            ? '${vehicle.name} (${vehicle.registrationNumber})'
            : vehicle.name;
      } else if (selectedVehicleId == '') {
        travelMode = '';
      }

      final updatedBooking = booking.copyWith(
        driverId: selectedDriverId ?? '',
        driverName: driver?.name ?? '',
        vehicleId: selectedVehicleId ?? '',
        travelMode: travelMode,
        travelDistanceKm: _distCtrl.text.trim().isEmpty
            ? 0.0
            : (double.tryParse(_distCtrl.text.trim().replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0),
        travelTime: _timeCtrl.text.trim(),
      );

      await ref.read(bookingProvider.notifier).updateBooking(updatedBooking);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transport assignment updated successfully.'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save assignment: $error'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _loadBookingDetails(Booking booking) {
    _distCtrl.text = booking.travelDistanceKm > 0
        ? booking.travelDistanceKm.toStringAsFixed(1)
        : '';
    _timeCtrl.text = booking.travelTime;
    _selectedDriverId = booking.driverId.isNotEmpty ? booking.driverId : null;
    _selectedVehicleId = booking.vehicleId.isNotEmpty ? booking.vehicleId : null;
  }

  @override
  Widget build(BuildContext context) {
    final crmColors = context.crmColors;
    final isMobile = ResponsiveBuilder.isMobile(context);
    final asyncBookings = ref.watch(bookingProvider);
    final asyncEmployees = ref.watch(employeesProvider);
    final asyncVehicles = ref.watch(vehiclesProvider);

    return asyncBookings.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error loading assignments: $err')),
      data: (bookings) {
        // Only show confirmed/completed bookings that have artists assigned
        final baseFilteredBookings = bookings.where((b) {
          final matchesSearch = b.customerName
                  .toLowerCase()
                  .contains(_searchQuery.toLowerCase()) ||
              b.bookingNumber.contains(_searchQuery) ||
              b.service.toLowerCase().contains(_searchQuery.toLowerCase());
          final hasArtists = b.assignedStaff.isNotEmpty;
          final isConfirmedOrCompleted =
              b.status.toLowerCase() == 'confirmed' ||
                  b.status.toLowerCase() == 'completed';
          final matchesMonth = !_filterByMonth ||
              (b.serviceStart.year == _selectedMonth.year &&
                  b.serviceStart.month == _selectedMonth.month);

          return matchesSearch &&
              hasArtists &&
              isConfirmedOrCompleted &&
              matchesMonth;
        }).toList();

        final unassignedCount = baseFilteredBookings.where((b) => b.driverId.isEmpty && b.vehicleId.isEmpty).length;
        final assignedCount = baseFilteredBookings.where((b) => b.driverId.isNotEmpty || b.vehicleId.isNotEmpty).length;
        final allCount = baseFilteredBookings.length;

        final filteredBookings = baseFilteredBookings.where((b) {
          if (_assignmentFilter == AssignmentFilter.unassigned) {
            return b.driverId.isEmpty && b.vehicleId.isEmpty;
          } else if (_assignmentFilter == AssignmentFilter.assigned) {
            return b.driverId.isNotEmpty || b.vehicleId.isNotEmpty;
          }
          return true;
        }).toList()
          ..sort((a, b) => b.serviceStart.compareTo(a.serviceStart));

        final activeBooking = filteredBookings.cast<Booking?>().firstWhere(
              (b) => b?.id == _activeBookingId,
              orElse: () => filteredBookings.isNotEmpty ? filteredBookings.first : null,
            );

        if (filteredBookings.isNotEmpty && _activeBookingId == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && activeBooking != null) {
              setState(() {
                _activeBookingId = activeBooking.id;
                _loadBookingDetails(activeBooking);
              });
            }
          });
        }

        final allEmployees = asyncEmployees.value ?? const <Employee>[];
        final drivers = allEmployees
            .where((emp) => emp.artistRole.toLowerCase() == 'driver')
            .toList();
        if (_selectedDriverId != null && _selectedDriverId!.isNotEmpty) {
          final isPresent = drivers.any((d) => d.id == _selectedDriverId);
          if (!isPresent) {
            try {
              final assignedDriver = allEmployees.firstWhere((e) => e.id == _selectedDriverId);
              drivers.add(assignedDriver);
            } catch (_) {}
          }
        }

        final allVehicles = asyncVehicles.value ?? const <Vehicle>[];
        final vehicles = allVehicles
            .where((veh) => veh.status.toLowerCase() == 'running')
            .toList();
        if (_selectedVehicleId != null && _selectedVehicleId!.isNotEmpty) {
          final isPresent = vehicles.any((v) => v.id == _selectedVehicleId);
          if (!isPresent) {
            try {
              final assignedVehicle = allVehicles.firstWhere((v) => v.id == _selectedVehicleId);
              vehicles.add(assignedVehicle);
            } catch (_) {}
          }
        }

        final content = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Screen Header
            if (!isMobile) ...[
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Fleet Assignments',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        8.h,
                        Text(
                          'Assign vehicles, in-house or rented status, and drivers to artist jobs.',
                          style: TextStyle(color: crmColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              20.h,
            ],

            // Responsive Search & Filters
            if (isMobile) ...[
              // ── Title ─────────────────────────────────────────────────────
              const FleetMobileHeader(title: 'Assignments'),
              14.h,

              // ── Search + filter menu + month toggle ──────────────────────
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 46,
                      decoration: BoxDecoration(
                        color: crmColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: crmColors.border),
                      ),
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Search bookings...',
                          hintStyle: TextStyle(
                              fontSize: 13.5, color: crmColors.textSecondary),
                          prefixIcon: Icon(Icons.search,
                              size: 19, color: crmColors.textSecondary),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 13),
                          isDense: true,
                        ),
                        style: const TextStyle(fontSize: 13.5),
                        onChanged: (val) => setState(() => _searchQuery = val),
                      ),
                    ),
                  ),
                  8.w,
                  // Filter menu (All / Unassigned / Assigned)
                  _buildFilterMenuButton(
                      crmColors, allCount, unassignedCount, assignedCount),
                  8.w,
                  GestureDetector(
                    onTap: () => setState(() {
                      _filterByMonth = !_filterByMonth;
                      _activeBookingId = null;
                    }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      height: 46,
                      width: 46,
                      decoration: BoxDecoration(
                        color: _filterByMonth
                            ? crmColors.primary.withValues(alpha: 0.10)
                            : crmColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _filterByMonth
                              ? crmColors.primary.withValues(alpha: 0.35)
                              : crmColors.border,
                        ),
                      ),
                      child: Icon(
                        Icons.calendar_month_outlined,
                        size: 20,
                        color: _filterByMonth
                            ? crmColors.primary
                            : crmColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),

              // ── Active filter chip (shows current filter · tap ✕ to clear) ─
              if (_assignmentFilter != AssignmentFilter.all) ...[
                10.h,
                Row(children: [_buildActiveFilterChip(crmColors)]),
              ],

              // ── Slim month navigator (shown when month filter is on) ──────
              if (_filterByMonth) ...[
                10.h,
                Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: crmColors.primary.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: crmColors.primary.withValues(alpha: 0.15)),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 40,
                        child: IconButton(
                          icon: Icon(Icons.chevron_left, size: 18, color: crmColors.primary),
                          onPressed: () => setState(() {
                            _selectedMonth = DateTime(
                              _selectedMonth.year,
                              _selectedMonth.month - 1,
                              1,
                            );
                            _activeBookingId = null;
                          }),
                          padding: EdgeInsets.zero,
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () async {
                            final DateTime? picked = await showDatePicker(
                              context: context,
                              initialDate: _selectedMonth,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2030),
                              initialDatePickerMode: DatePickerMode.year,
                              helpText: 'Select Month & Year',
                            );
                            if (picked != null) {
                              setState(() {
                                _selectedMonth = DateTime(picked.year, picked.month, 1);
                                _activeBookingId = null;
                              });
                            }
                          },
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.calendar_month, size: 14, color: crmColors.primary),
                              6.w,
                              Text(
                                _formatMonthYear(_selectedMonth),
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.bold,
                                  color: crmColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 40,
                        child: IconButton(
                          icon: Icon(Icons.chevron_right, size: 18, color: crmColors.primary),
                          onPressed: () => setState(() {
                            _selectedMonth = DateTime(
                              _selectedMonth.year,
                              _selectedMonth.month + 1,
                              1,
                            );
                            _activeBookingId = null;
                          }),
                          padding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ] else ...[
              // Desktop Search, Filter, and Month Navigation
              Row(
                children: [
                  // Search
                  Expanded(
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: crmColors.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: crmColors.border),
                      ),
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Search by client, reference...',
                          hintStyle: TextStyle(fontSize: 14, color: crmColors.textSecondary),
                          prefixIcon: Icon(Icons.search, size: 20, color: crmColors.textSecondary),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 14),
                          isDense: true,
                        ),
                        onChanged: (val) => setState(() => _searchQuery = val),
                      ),
                    ),
                  ),
                  16.w,
                  
                  // Segmented Filter
                  Container(
                    height: 48,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: crmColors.border.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildSegmentTab('All $allCount', AssignmentFilter.all, crmColors),
                        _buildSegmentTab('Unassigned $unassignedCount', AssignmentFilter.unassigned, crmColors),
                        _buildSegmentTab('Assigned $assignedCount', AssignmentFilter.assigned, crmColors),
                      ],
                    ),
                  ),
                  16.w,

                  // Month Navigation
                  Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: crmColors.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: crmColors.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.chevron_left, size: 20, color: crmColors.textSecondary),
                          tooltip: 'Previous Month',
                          onPressed: () => setState(() {
                            _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1, 1);
                            _activeBookingId = null;
                            _filterByMonth = true;
                          }),
                        ),
                        TextButton.icon(
                          onPressed: () async {
                            final DateTime? picked = await showDatePicker(
                              context: context,
                              initialDate: _selectedMonth,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2030),
                              helpText: 'Select Month & Year',
                            );
                            if (picked != null) {
                              setState(() {
                                _selectedMonth = DateTime(picked.year, picked.month, 1);
                                _activeBookingId = null;
                                _filterByMonth = true;
                              });
                            }
                          },
                          icon: Icon(Icons.calendar_month, color: crmColors.textPrimary, size: 18),
                          label: Text(
                            _formatMonthYear(_selectedMonth),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: crmColors.textPrimary,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.chevron_right, size: 20, color: crmColors.textSecondary),
                          tooltip: 'Next Month',
                          onPressed: () => setState(() {
                            _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1);
                            _activeBookingId = null;
                            _filterByMonth = true;
                          }),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
            16.h,

            // Body Area
            if (filteredBookings.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.local_shipping_outlined,
                        size: 64,
                        color: crmColors.textSecondary,
                      ),
                      16.h,
                      Text(
                        'No bookings found requiring transport.',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      8.h,
                      Text(
                        'Confirmed bookings with assigned artists will appear here.',
                        style: TextStyle(color: crmColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              )
            else if (isMobile)
              Expanded(
                child: ListView.separated(
                  itemCount: filteredBookings.length,
                  separatorBuilder: (context, index) => 12.h,
                  itemBuilder: (context, index) {
                    final booking = filteredBookings[index];
                    final isAssigned =
                        booking.driverId.isNotEmpty && booking.vehicleId.isNotEmpty;

                    return _buildBookingCard(
                      context: context,
                      booking: booking,
                      isActive: false,
                      isAssigned: isAssigned,
                      crmColors: crmColors,
                      onTap: () {
                        _loadBookingDetails(booking);
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          useSafeArea: true,
                          builder: (ctx) {
                            return DraggableScrollableSheet(
                              initialChildSize: 0.78,
                              maxChildSize: 0.95,
                              minChildSize: 0.50,
                              expand: false,
                              builder: (sheetCtx, scrollController) {
                                return Container(
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).scaffoldBackgroundColor,
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(24),
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      // Drag handle
                                      Center(
                                        child: Container(
                                          margin: const EdgeInsets.only(top: 12, bottom: 4),
                                          width: 36,
                                          height: 4,
                                          decoration: BoxDecoration(
                                            color: crmColors.border,
                                            borderRadius: BorderRadius.circular(2),
                                          ),
                                        ),
                                      ),
                                      // Sheet header
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(20, 8, 8, 8),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'Assign Transport',
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .titleMedium
                                                        ?.copyWith(
                                                            fontWeight: FontWeight.bold),
                                                  ),
                                                  Text(
                                                    booking.customerName,
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      color: crmColors.primary,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ],
                                              ),
                                            ),
                                            IconButton(
                                              onPressed: () => Navigator.pop(ctx),
                                              icon: const Icon(Icons.close),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Divider(height: 1, color: crmColors.border),
                                      // Scrollable form
                                      Expanded(
                                        child: SingleChildScrollView(
                                          controller: scrollController,
                                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                                          child: _buildAssignmentForm(
                                              context, booking, drivers, vehicles),
                                        ),
                                      ),
                                      // Save button
                                      Padding(
                                        padding: EdgeInsets.fromLTRB(
                                          20,
                                          8,
                                          20,
                                          MediaQuery.of(ctx).viewInsets.bottom + 20,
                                        ),
                                        child: SizedBox(
                                          width: double.infinity,
                                          height: 48,
                                          child: ElevatedButton(
                                            onPressed: _saving
                                                ? null
                                                : () async {
                                                    await _saveAssignment(booking);
                                                    if (ctx.mounted) Navigator.pop(ctx);
                                                  },
                                            child: _saving
                                                ? const SizedBox(
                                                    width: 20,
                                                    height: 20,
                                                    child: CircularProgressIndicator(
                                                      strokeWidth: 2.5,
                                                      color: Colors.white,
                                                    ),
                                                  )
                                                : const Text('Save Transport Allocation'),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              )
            else
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left list panel - Responsive Grid of Cards
                    Expanded(
                      flex: 4,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final crossAxisCount = constraints.maxWidth > 520 ? 2 : 1;
                          
                          return GridView.builder(
                            itemCount: filteredBookings.length,
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: crossAxisCount,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: crossAxisCount == 2 ? 1.25 : 2.5,
                            ),
                            itemBuilder: (context, index) {
                              final booking = filteredBookings[index];
                              final isActive = booking.id == activeBooking?.id;
                              final isAssigned = booking.driverId.isNotEmpty &&
                                  booking.vehicleId.isNotEmpty;
                              
                              return _buildBookingCard(
                                context: context,
                                booking: booking,
                                isActive: isActive,
                                isAssigned: isAssigned,
                                crmColors: crmColors,
                                onTap: () {
                                  setState(() {
                                    _activeBookingId = booking.id;
                                    _loadBookingDetails(booking);
                                  });
                                },
                              );
                            },
                          );
                        },
                      ),
                    ),
                    16.w,

                    // Right detail panel
                    Expanded(
                      flex: 5,
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: activeBooking == null
                              ? Center(
                                  child: Text(
                                    'Select a booking to manage transport.',
                                    style: TextStyle(
                                        color: crmColors.textSecondary),
                                  ),
                                )
                              : StatefulBuilder(
                                  builder: (context, setInnerState) {
                                    return SingleChildScrollView(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          // Title & Number
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  'Booking #${activeBooking.bookingNumber}',
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .titleMedium
                                                      ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                ),
                                              ),
                                              IconButton(
                                                icon: const Icon(
                                                    Icons.map_outlined),
                                                tooltip: 'Open Location Link',
                                                onPressed: activeBooking
                                                        .mapUrl.isNotEmpty
                                                    ? () => _openMapUrl(activeBooking.mapUrl, context)
                                                    : null,
                                              ),
                                            ],
                                          ),
                                          Text(
                                            activeBooking.customerName,
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleLarge
                                                ?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                  color: crmColors.primary,
                                                ),
                                          ),
                                          12.h,
                                          const Divider(),
                                          12.h,

                                          // Artist assign details
                                          Text(
                                            'ASSIGNED ARTISTS & STAFF',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: crmColors.textSecondary,
                                              letterSpacing: 1.1,
                                            ),
                                          ),
                                          8.h,
                                          Wrap(
                                            spacing: 8,
                                            runSpacing: 8,
                                            children: activeBooking
                                                .assignedStaff
                                                .map((staff) {
                                              return Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 10,
                                                  vertical: 6,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: crmColors.accent
                                                      .withValues(alpha: 0.08),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  border: Border.all(
                                                    color: crmColors.accent
                                                        .withValues(alpha: 0.2),
                                                  ),
                                                ),
                                                child: Text(
                                                  '${staff.artistName} (${staff.role})',
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              );
                                            }).toList(),
                                          ),
                                          20.h,

                                          // Assignment inputs
                                          _buildAssignmentForm(
                                            context,
                                            activeBooking,
                                            drivers,
                                            vehicles,
                                          ),
                                          24.h,

                                          // Action button
                                          SizedBox(
                                            width: double.infinity,
                                            height: 48,
                                            child: ElevatedButton(
                                              onPressed: _saving
                                                  ? null
                                                  : () => _saveAssignment(
                                                      activeBooking),
                                              child: _saving
                                                  ? const SizedBox(
                                                      width: 20,
                                                      height: 20,
                                                      child:
                                                          CircularProgressIndicator(
                                                        strokeWidth: 2.5,
                                                        color: Colors.white,
                                                      ),
                                                    )
                                                  : const Text(
                                                      'Save Transport Allocation'),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );

        // Mobile gets its own horizontal insets (the shell adds none on phones);
        // desktop already receives padding from MainLayout.
        return isMobile
            ? Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: content,
              )
            : content;
      },
    );
  }

  Widget _buildAssignmentForm(
    BuildContext context,
    Booking booking,
    List<Employee> drivers,
    List<Vehicle> vehicles,
  ) {
    final crmColors = context.crmColors;

    // Sanitize lists to prevent DropdownButton crashes
    final uniqueDrivers = <String, Employee>{};
    for (var d in drivers) {
      uniqueDrivers[d.id] = d;
    }
    final safeDrivers = uniqueDrivers.values.toList();
    final safeDriverId = (_selectedDriverId != null && uniqueDrivers.containsKey(_selectedDriverId)) ? _selectedDriverId : null;

    final uniqueVehicles = <String, Vehicle>{};
    for (var v in vehicles) {
      uniqueVehicles[v.id] = v;
    }
    final safeVehicles = uniqueVehicles.values.toList();
    final safeVehicleId = (_selectedVehicleId != null && uniqueVehicles.containsKey(_selectedVehicleId)) ? _selectedVehicleId : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (booking.address.trim().isNotEmpty || booking.district.trim().isNotEmpty) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: crmColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: crmColors.border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.location_on_outlined,
                  color: crmColors.primary,
                  size: 20,
                ),
                12.w,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Event Address',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: crmColors.textSecondary,
                        ),
                      ),
                      4.h,
                      Text(
                        booking.address.trim().isNotEmpty
                            ? booking.address.trim()
                            : booking.district,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                if (booking.mapUrl.trim().isNotEmpty) ...[
                  8.w,
                  IconButton(
                    icon: const Icon(Icons.map_outlined),
                    color: Colors.green,
                    tooltip: 'Google Maps Direction',
                    onPressed: () => _openMapUrl(booking.mapUrl, context),
                  ),
                ],
              ],
            ),
          ),
          12.h,
        ],
        if (booking.pocName.trim().isNotEmpty) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: crmColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: crmColors.border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  Icons.person_pin_circle_outlined,
                  color: crmColors.primary,
                  size: 20,
                ),
                12.w,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Point of Contact (POC)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: crmColors.textSecondary,
                        ),
                      ),
                      4.h,
                      Text(
                        booking.pocName.trim(),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (booking.pocPhone.trim().isNotEmpty) ...[
                        2.h,
                        Text(
                          booking.pocPhone.trim(),
                          style: TextStyle(
                            fontSize: 12,
                            color: crmColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (booking.pocPhone.trim().isNotEmpty) ...[
                  8.w,
                  IconButton(
                    icon: const Icon(Icons.call_outlined),
                    color: crmColors.primary,
                    tooltip: 'Call POC',
                    onPressed: () => _makePhoneCall(booking.pocPhone, context),
                  ),
                ],
              ],
            ),
          ),
          16.h,
        ],
        Text(
          'TRANSPORT DETAILS & ALLOCATION',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: crmColors.textSecondary,
            letterSpacing: 1.1,
          ),
        ),
        12.h,

        // Driver selection dropdown
        DropdownButtonFormField<String>(
          initialValue: safeDriverId,
          decoration: const InputDecoration(
            labelText: 'Driver',
            prefixIcon: Icon(Icons.person_outline),
          ),
          hint: const Text('Select driver...'),
          items: [
            const DropdownMenuItem(
              value: '',
              child: Text('Unassigned'),
            ),
            ...safeDrivers.map((d) {
              return DropdownMenuItem(
                value: d.id,
                child: Text(d.name),
              );
            }),
          ],
          onChanged: (val) {
            setState(() {
              _selectedDriverId = (val == '') ? null : val;
            });
          },
        ),
        16.h,

        // Vehicle selection dropdown
        DropdownButtonFormField<String>(
          initialValue: safeVehicleId,
          decoration: const InputDecoration(
            labelText: 'Vehicle',
            prefixIcon: Icon(Icons.directions_car_outlined),
          ),
          hint: const Text('Select vehicle...'),
          items: [
            const DropdownMenuItem(
              value: '',
              child: Text('Unassigned'),
            ),
            ...safeVehicles.map((v) {
              final isRented = v.ownershipType == 'rented';
              return DropdownMenuItem(
                value: v.id,
                child: Text(
                  '${v.name} • ${v.registrationNumber} [${isRented ? "RENT" : "OWN"}]',
                ),
              );
            }),
          ],
          onChanged: (val) {
            setState(() {
              _selectedVehicleId = (val == '') ? null : val;
            });
          },
        ),
        16.h,

        // Distance & travel time fields
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _distCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Distance (KM)',
                  prefixIcon: Icon(Icons.map_outlined),
                ),
              ),
            ),
            16.w,
            Expanded(
              child: TextField(
                controller: _timeCtrl,
                decoration: const InputDecoration(
                  labelText: 'Est. Travel Time',
                  prefixIcon: Icon(Icons.access_time),
                  hintText: 'e.g. 2 hrs 30 mins',
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
  String _formatDateShort(DateTime date) {
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
    return months[date.month - 1];
  }

  String _formatMonthYear(DateTime date) {
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
    return '${months[date.month - 1]} ${date.year}';
  }

  Widget _buildBookingCard({
    required BuildContext context,
    required Booking booking,
    required bool isActive,
    required bool isAssigned,
    required CrmTheme crmColors,
    required VoidCallback onTap,
  }) {
    final accentColor = isAssigned ? crmColors.success : crmColors.warning;

    return Card(
      elevation: isActive ? 4 : 0,
      shadowColor: isActive ? crmColors.primary.withValues(alpha: 0.20) : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isActive ? crmColors.primary : crmColors.border,
          width: isActive ? 1.5 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Left accent strip ────────────────────────────────────
              Container(width: 4, color: accentColor),

              // ── Card content ─────────────────────────────────────────
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [

                      // ── Top row: date badge + info + status ──────────
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Date badge (day large, month below)
                          Container(
                            width: 46,
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? crmColors.primary
                                  : crmColors.primary.withValues(alpha: 0.09),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  booking.serviceStart.day.toString(),
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: isActive
                                        ? Colors.white
                                        : crmColors.primary,
                                    height: 1.0,
                                  ),
                                ),
                                3.h,
                                Text(
                                  _formatDateShort(booking.serviceStart),
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.3,
                                    color: isActive
                                        ? Colors.white.withValues(alpha: 0.80)
                                        : crmColors.primary
                                            .withValues(alpha: 0.65),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          12.w,

                          // Customer name + booking ref + service
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  booking.customerName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                4.h,
                                Text(
                                  '#${booking.bookingNumber}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: crmColors.textSecondary,
                                  ),
                                ),
                                if (booking.service.isNotEmpty) ...[
                                  2.h,
                                  Text(
                                    booking.service,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: crmColors.textSecondary
                                          .withValues(alpha: 0.75),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          6.w,

                          // Status badge — pill with border
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 9, vertical: 4),
                            decoration: BoxDecoration(
                              color: accentColor.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: accentColor.withValues(alpha: 0.30),
                              ),
                            ),
                            child: Text(
                              isAssigned ? 'Assigned' : 'Pending',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: accentColor,
                              ),
                            ),
                          ),
                        ],
                      ),

                      10.h,

                      // ── Location row ─────────────────────────────────
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            size: 13,
                            color: crmColors.textSecondary,
                          ),
                          4.w,
                          Expanded(
                            child: Text(
                              booking.district.isNotEmpty
                                  ? booking.district
                                  : 'Location not specified',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: crmColors.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),

                      8.h,

                      // ── Transport footer banner ───────────────────────
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.07),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: accentColor.withValues(alpha: 0.18),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isAssigned
                                  ? Icons.local_shipping_outlined
                                  : Icons.warning_amber_rounded,
                              size: 13,
                              color: accentColor,
                            ),
                            6.w,
                            Expanded(
                              child: Text(
                                isAssigned
                                    ? '${booking.driverName} • ${booking.travelMode}'
                                    : 'Tap to assign transport',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: accentColor,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (!isAssigned) ...[
                              4.w,
                              Icon(Icons.chevron_right,
                                  size: 14, color: accentColor),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _filterColor(AssignmentFilter filter, CrmTheme crmColors) {
    switch (filter) {
      case AssignmentFilter.unassigned:
        return crmColors.warning;
      case AssignmentFilter.assigned:
        return crmColors.success;
      case AssignmentFilter.all:
        return crmColors.primary;
    }
  }

  String _filterLabel(AssignmentFilter filter) {
    switch (filter) {
      case AssignmentFilter.unassigned:
        return 'Unassigned';
      case AssignmentFilter.assigned:
        return 'Assigned';
      case AssignmentFilter.all:
        return 'All';
    }
  }

  /// Mobile filter menu — a funnel icon that opens a popup with
  /// All / Unassigned / Assigned (with live counts). Tints when a filter is on.
  Widget _buildFilterMenuButton(
    CrmTheme crmColors,
    int allCount,
    int unassignedCount,
    int assignedCount,
  ) {
    final active = _assignmentFilter != AssignmentFilter.all;
    final color = _filterColor(_assignmentFilter, crmColors);
    return PopupMenuButton<AssignmentFilter>(
      tooltip: 'Filter bookings',
      position: PopupMenuPosition.under,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      onSelected: (f) => setState(() {
        _assignmentFilter = f;
        _activeBookingId = null;
      }),
      itemBuilder: (ctx) => [
        _filterMenuItem(AssignmentFilter.all, allCount, crmColors),
        _filterMenuItem(AssignmentFilter.unassigned, unassignedCount, crmColors),
        _filterMenuItem(AssignmentFilter.assigned, assignedCount, crmColors),
      ],
      child: Container(
        height: 46,
        width: 46,
        decoration: BoxDecoration(
          color: active ? color.withValues(alpha: 0.10) : crmColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active ? color.withValues(alpha: 0.35) : crmColors.border,
          ),
        ),
        child: Icon(
          Icons.filter_list_rounded,
          size: 20,
          color: active ? color : crmColors.textSecondary,
        ),
      ),
    );
  }

  PopupMenuItem<AssignmentFilter> _filterMenuItem(
    AssignmentFilter filter,
    int count,
    CrmTheme crmColors,
  ) {
    final selected = _assignmentFilter == filter;
    final color = _filterColor(filter, crmColors);
    return PopupMenuItem<AssignmentFilter>(
      value: filter,
      child: Row(
        children: [
          Icon(
            selected ? Icons.check_circle : Icons.circle_outlined,
            size: 18,
            color: selected ? color : crmColors.textSecondary,
          ),
          10.w,
          Text(
            _filterLabel(filter),
            style: TextStyle(
              fontSize: 14,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: crmColors.textPrimary,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Shows the currently applied filter with a ✕ to reset back to All.
  Widget _buildActiveFilterChip(CrmTheme crmColors) {
    final color = _filterColor(_assignmentFilter, crmColors);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.filter_list_rounded, size: 13, color: color),
          5.w,
          Text(
            '${_filterLabel(_assignmentFilter)} only',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          6.w,
          GestureDetector(
            onTap: () => setState(() {
              _assignmentFilter = AssignmentFilter.all;
              _activeBookingId = null;
            }),
            child: Icon(Icons.close, size: 13, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentTab(String text, AssignmentFilter filter, CrmTheme crmColors) {
    final isSelected = _assignmentFilter == filter;
    return GestureDetector(
      onTap: () {
        setState(() {
          _assignmentFilter = filter;
          _activeBookingId = null;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? crmColors.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  )
                ]
              : null,
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? crmColors.textPrimary : crmColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
