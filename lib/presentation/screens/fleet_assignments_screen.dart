import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/extensions/space_extension.dart';
import '../../core/models/booking.dart';
import '../../core/models/employee.dart';
import '../../core/models/vehicle.dart';
import '../../core/providers/booking_provider.dart';
import '../../core/theme/crm_theme.dart';
import '../../core/utils/responsive_builder.dart';
import '../../services/employee_service.dart';
import '../../services/vehicle_service.dart';

class FleetAssignmentsScreen extends ConsumerStatefulWidget {
  const FleetAssignmentsScreen({super.key});

  @override
  ConsumerState<FleetAssignmentsScreen> createState() =>
      _FleetAssignmentsScreenState();
}

class _FleetAssignmentsScreenState
    extends ConsumerState<FleetAssignmentsScreen> {
  String _searchQuery = '';
  bool _showUnassignedOnly = false;
  String? _activeBookingId;

  // Form Controllers
  final _distCtrl = TextEditingController();
  final _timeCtrl = TextEditingController();
  String? _selectedDriverId;
  String? _selectedVehicleId;
  bool _saving = false;

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
        travelDistanceKm: double.tryParse(_distCtrl.text.trim()) ?? 0,
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
        final filteredBookings = bookings.where((b) {
          final matchesSearch = b.customerName
                  .toLowerCase()
                  .contains(_searchQuery.toLowerCase()) ||
              b.bookingNumber.contains(_searchQuery) ||
              b.service.toLowerCase().contains(_searchQuery.toLowerCase());
          final hasArtists = b.assignedStaff.isNotEmpty;
          final isConfirmedOrCompleted =
              b.status.toLowerCase() == 'confirmed' ||
                  b.status.toLowerCase() == 'completed';
          final matchesUnassigned =
              !_showUnassignedOnly || (b.driverId.isEmpty && b.vehicleId.isEmpty);

          return matchesSearch && hasArtists && isConfirmedOrCompleted && matchesUnassigned;
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

        // Available Drivers list
        final drivers = (asyncEmployees.value ?? const <Employee>[])
            .where((emp) => emp.artistRole.toLowerCase() == 'driver')
            .toList();

        // Available Vehicles list
        final vehicles = (asyncVehicles.value ?? const <Vehicle>[])
            .where((veh) => veh.status.toLowerCase() == 'active')
            .toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Screen Header
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

            // Search and filters
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        decoration: const InputDecoration(
                          hintText: 'Search by client name, reference, service...',
                          prefixIcon: Icon(Icons.search, size: 20),
                          contentPadding: EdgeInsets.symmetric(vertical: 10),
                        ),
                        onChanged: (val) => setState(() => _searchQuery = val),
                      ),
                    ),
                    16.w,
                    Row(
                      children: [
                        Checkbox(
                          value: _showUnassignedOnly,
                          onChanged: (val) {
                            setState(() {
                              _showUnassignedOnly = val ?? false;
                              _activeBookingId = null;
                            });
                          },
                        ),
                        const Text(
                          'Unassigned Only',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
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

                    return Card(
                      child: ListTile(
                        title: Text(
                          '${booking.customerName} • #${booking.bookingNumber}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          '${booking.service}\n'
                          'Date: ${_formatDate(booking.serviceStart)}\n'
                          'Transport: ${isAssigned ? "${booking.driverName} • ${booking.travelMode}" : "Unassigned"}',
                        ),
                        trailing: Icon(
                          Icons.arrow_forward_ios,
                          size: 16,
                          color: isAssigned ? crmColors.success : crmColors.warning,
                        ),
                        onTap: () {
                          _loadBookingDetails(booking);
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Assign Transport'),
                              content: SingleChildScrollView(
                                child: _buildAssignmentForm(
                                    ctx, booking, drivers, vehicles),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: const Text('Cancel'),
                                ),
                                ElevatedButton(
                                  onPressed: _saving
                                      ? null
                                      : () async {
                                          await _saveAssignment(booking);
                                          if (ctx.mounted) Navigator.pop(ctx);
                                        },
                                  child: const Text('Save'),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              )
            else
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left list panel
                    Expanded(
                      flex: 4,
                      child: Card(
                        child: ListView.separated(
                          itemCount: filteredBookings.length,
                          separatorBuilder: (context, index) =>
                              Divider(height: 1, color: crmColors.border),
                          itemBuilder: (context, index) {
                            final booking = filteredBookings[index];
                            final isActive = booking.id == activeBooking?.id;
                            final isAssigned = booking.driverId.isNotEmpty &&
                                booking.vehicleId.isNotEmpty;

                            return InkWell(
                              onTap: () {
                                setState(() {
                                  _activeBookingId = booking.id;
                                  _loadBookingDetails(booking);
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: isActive
                                      ? crmColors.secondary.withValues(alpha: 0.15)
                                      : Colors.transparent,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            booking.customerName,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                          4.h,
                                          Text(
                                            '#${booking.bookingNumber} • ${booking.service}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: crmColors.textSecondary,
                                            ),
                                          ),
                                          6.h,
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.location_on_outlined,
                                                size: 12,
                                                color: crmColors.textSecondary,
                                              ),
                                              4.w,
                                              Text(
                                                '${booking.region} • ${booking.district}',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: crmColors.textSecondary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          _formatDate(booking.serviceStart),
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        8.h,
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isAssigned
                                                ? crmColors.success
                                                    .withValues(alpha: 0.12)
                                                : crmColors.warning
                                                    .withValues(alpha: 0.12),
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            isAssigned ? 'Assigned' : 'Pending',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: isAssigned
                                                  ? crmColors.success
                                                  : crmColors.warning,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
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
                                                    ? () {} // Can link to URL
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
          initialValue: _selectedDriverId,
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
            ...drivers.map((d) {
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
          initialValue: _selectedVehicleId,
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
            ...vehicles.map((v) {
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

  String _formatDate(DateTime date) {
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
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}
