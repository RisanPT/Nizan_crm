import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../core/extensions/space_extension.dart';
import '../../core/models/employee.dart';
import '../../core/models/list_page_params.dart';
import '../../core/models/vehicle.dart';
import '../../core/theme/crm_theme.dart';
import '../../core/utils/responsive_builder.dart';
import '../../services/employee_service.dart';
import '../../services/vehicle_service.dart';
import '../common_widgets/paginated_footer.dart';

class FleetVehiclesScreen extends HookConsumerWidget {
  const FleetVehiclesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final crmColors = context.crmColors;
    final isMobile = ResponsiveBuilder.isMobile(context);
    final pageState = useState(1);
    const pageSize = 20;

    final asyncVehicles = ref.watch(
      paginatedVehiclesProvider(
        ListPageParams(page: pageState.value, limit: pageSize),
      ),
    );
    final asyncEmployees = ref.watch(employeesProvider);

    Future<void> openVehicleDialog([Vehicle? vehicle]) async {
      final nameCtrl = TextEditingController(text: vehicle?.name ?? '');
      final regCtrl = TextEditingController(
        text: vehicle?.registrationNumber ?? '',
      );
      final brandCtrl = TextEditingController(text: vehicle?.brand ?? '');
      final notesCtrl = TextEditingController(text: vehicle?.notes ?? '');
      var type = vehicle?.type ?? 'car';
      if (!['car', 'van', 'bike', 'other'].contains(type)) {
        type = 'car';
      }
      var fuelType = vehicle?.fuelType ?? 'petrol';
      if (!['petrol', 'diesel', 'electric', 'hybrid', 'cng', 'other'].contains(fuelType)) {
        fuelType = 'petrol';
      }
      var status = vehicle?.status ?? 'running';
      if (!['running', 'under_service', 'accident', 'complaint', 'other'].contains(status)) {
        status = 'running';
      }
      var driverId = vehicle?.driver?.id ?? '';
      var ownershipType = vehicle?.ownershipType ?? 'in_house';
      if (!['in_house', 'rented'].contains(ownershipType)) {
        ownershipType = 'in_house';
      }

      await showDialog(
        context: context,
        builder: (dialogContext) {
          final drivers = (asyncEmployees.value ?? const <Employee>[])
              .where((employee) => employee.artistRole == 'driver')
              .toList();
          final driverOptions = [
            const DropdownMenuItem(
              value: '',
              child: Text('Unassigned'),
            ),
            ...drivers.map(
              (driver) => DropdownMenuItem(
                value: driver.id,
                child: Text(driver.name),
              ),
            ),
          ];
          final hasSelectedDriver = driverOptions.any(
            (item) => item.value == driverId,
          );

          return StatefulBuilder(
            builder: (context, setState) => AlertDialog(
              title: Text(vehicle == null ? 'Add Vehicle' : 'Edit Vehicle'),
              content: SizedBox(
                width: isMobile ? double.maxFinite : 440,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Vehicle Name',
                        ),
                      ),
                      16.h,
                      TextField(
                        controller: regCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Registration Number',
                        ),
                      ),
                      16.h,
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: type,
                              items: const [
                                DropdownMenuItem(
                                  value: 'car',
                                  child: Text('Car'),
                                ),
                                DropdownMenuItem(
                                  value: 'van',
                                  child: Text('Van'),
                                ),
                                DropdownMenuItem(
                                  value: 'bike',
                                  child: Text('Bike'),
                                ),
                                DropdownMenuItem(
                                  value: 'other',
                                  child: Text('Other'),
                                ),
                              ],
                              onChanged: (value) {
                                if (value != null) setState(() => type = value);
                              },
                              decoration: const InputDecoration(
                                labelText: 'Type',
                              ),
                            ),
                          ),
                          16.w,
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: fuelType,
                              items: const [
                                DropdownMenuItem(
                                  value: 'petrol',
                                  child: Text('Petrol'),
                                ),
                                DropdownMenuItem(
                                  value: 'diesel',
                                  child: Text('Diesel'),
                                ),
                                DropdownMenuItem(
                                  value: 'electric',
                                  child: Text('Electric'),
                                ),
                                DropdownMenuItem(
                                  value: 'hybrid',
                                  child: Text('Hybrid'),
                                ),
                                DropdownMenuItem(
                                  value: 'cng',
                                  child: Text('CNG'),
                                ),
                                DropdownMenuItem(
                                  value: 'other',
                                  child: Text('Other'),
                                ),
                              ],
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() => fuelType = value);
                                }
                              },
                              decoration: const InputDecoration(
                                labelText: 'Fuel Type',
                              ),
                            ),
                          ),
                        ],
                      ),
                      16.h,
                      TextField(
                        controller: brandCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Brand / Model',
                        ),
                      ),
                      16.h,
                      DropdownButtonFormField<String>(
                        initialValue: hasSelectedDriver ? driverId : '',
                        items: driverOptions,
                        onChanged: (value) {
                          if (value != null) setState(() => driverId = value);
                        },
                        decoration: const InputDecoration(
                          labelText: 'Assigned Driver',
                        ),
                      ),
                      16.h,
                      DropdownButtonFormField<String>(
                        initialValue: ownershipType,
                        items: const [
                          DropdownMenuItem(
                            value: 'in_house',
                            child: Text('In-House'),
                          ),
                          DropdownMenuItem(
                            value: 'rented',
                            child: Text('Rented'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => ownershipType = value);
                          }
                        },
                        decoration: const InputDecoration(
                          labelText: 'Ownership Type',
                        ),
                      ),
                      16.h,
                      DropdownButtonFormField<String>(
                        initialValue: status,
                        items: const [
                          DropdownMenuItem(value: 'running', child: Text('Running')),
                          DropdownMenuItem(value: 'under_service', child: Text('Under Service')),
                          DropdownMenuItem(value: 'accident', child: Text('Accident')),
                          DropdownMenuItem(value: 'complaint', child: Text('Complaint')),
                          DropdownMenuItem(value: 'other', child: Text('Other')),
                        ],
                        onChanged: (value) {
                          if (value != null) setState(() => status = value);
                        },
                        decoration: const InputDecoration(
                          labelText: 'Status',
                        ),
                      ),
                      16.h,
                      TextField(
                        controller: notesCtrl,
                        maxLines: 3,
                        decoration: const InputDecoration(labelText: 'Notes'),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    await ref.read(vehicleServiceProvider).saveVehicle(
                          id: vehicle?.id,
                          name: nameCtrl.text.trim(),
                          registrationNumber: regCtrl.text.trim(),
                          type: type,
                          brand: brandCtrl.text.trim(),
                          fuelType: fuelType,
                          status: status,
                          notes: notesCtrl.text.trim(),
                          driverId: driverId,
                          ownershipType: ownershipType,
                        );
                    ref.invalidate(vehiclesProvider);
                    ref.invalidate(paginatedVehiclesProvider);
                    if (dialogContext.mounted) {
                      Navigator.of(dialogContext).pop();
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            ),
          );
        },
      );
    }

    Color statusColor(String status, CrmTheme colors) {
      switch (status) {
        case 'running':
          return colors.success;
        case 'under_service':
          return colors.warning;
        case 'accident':
          return colors.destructive;
        case 'complaint':
          return Colors.orange;
        default:
          return colors.textSecondary;
      }
    }

    IconData vehicleIcon(String type) {
      switch (type) {
        case 'van':
          return Icons.airport_shuttle_outlined;
        case 'bike':
          return Icons.two_wheeler_outlined;
        default:
          return Icons.directions_car_outlined;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Desktop header ──────────────────────────────────────────────
        if (!isMobile) ...[
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Fleet Vehicles',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Manage cars, bikes, vans, assigned drivers, and current status.',
                      style: TextStyle(color: crmColors.textSecondary),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => openVehicleDialog(),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Vehicle'),
              ),
            ],
          ),
          24.h,
        ],

        // ── Mobile header ───────────────────────────────────────────────
        if (isMobile)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                asyncVehicles.maybeWhen(
                  data: (r) {
                    final count = r.totalItems;
                    return Text(
                      '$count vehicle${count == 1 ? '' : 's'}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: crmColors.textSecondary,
                      ),
                    );
                  },
                  orElse: () => const SizedBox.shrink(),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: () => openVehicleDialog(),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add Vehicle',
                      style: TextStyle(fontSize: 13)),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 36),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
                  ),
                ),
              ],
            ),
          ),

        // ── List ────────────────────────────────────────────────────────
        Expanded(
          child: asyncVehicles.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(
              child: Text(
                'Failed to load vehicles: $error',
                style: TextStyle(color: crmColors.textSecondary),
              ),
            ),
            data: (response) {
              final vehicles = response.items;
              if (vehicles.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.directions_car_outlined,
                        size: 56,
                        color: crmColors.textSecondary.withValues(alpha: 0.4),
                      ),
                      16.h,
                      Text(
                        'No vehicles yet',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: crmColors.textSecondary,
                        ),
                      ),
                      6.h,
                      Text(
                        'Tap "Add Vehicle" to get started.',
                        style: TextStyle(
                          fontSize: 12,
                          color: crmColors.textSecondary.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                );
              }

              int crossAxisCount = 1;
              if (!isMobile) {
                final width = MediaQuery.of(context).size.width;
                if (width > 1200) {
                  crossAxisCount = 3;
                } else if (width > 800) {
                  crossAxisCount = 2;
                }
              }

              return GridView.builder(
                padding: EdgeInsets.zero,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  mainAxisExtent: 180,
                ),
                itemCount: vehicles.length,
                itemBuilder: (context, index) {
                  final v = vehicles[index];
                  final isRented = v.ownershipType == 'rented';
                  final accentColor = statusColor(v.status, crmColors);

                  return Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: crmColors.border),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Left accent line
                          Container(width: 6, color: accentColor),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Vehicle icon badge
                                      Container(
                                        width: 48,
                                        height: 48,
                                        decoration: BoxDecoration(
                                          color: accentColor.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Icon(
                                          vehicleIcon(v.type),
                                          color: accentColor,
                                          size: 26,
                                        ),
                                      ),
                                      12.w,
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              v.name,
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            4.h,
                                            Text(
                                              v.registrationNumber.isNotEmpty ? '${v.registrationNumber} • ${v.brand}' : v.brand,
                                              style: TextStyle(fontSize: 12, color: crmColors.textSecondary),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Menu
                                      PopupMenuButton<String>(
                                        icon: Icon(Icons.more_vert, size: 20, color: crmColors.textSecondary),
                                        onSelected: (val) async {
                                          if (val == 'edit') {
                                            openVehicleDialog(v);
                                          } else if (val == 'delete') {
                                            final confirm = await showDialog<bool>(
                                              context: context,
                                              builder: (ctx) => AlertDialog(
                                                title: const Text('Delete Vehicle'),
                                                content: Text('Delete ${v.name}?'),
                                                actions: [
                                                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                                  TextButton(
                                                    onPressed: () => Navigator.pop(ctx, true),
                                                    style: TextButton.styleFrom(foregroundColor: crmColors.destructive),
                                                    child: const Text('Delete'),
                                                  ),
                                                ],
                                              ),
                                            );
                                            if (confirm == true) {
                                              await ref.read(vehicleServiceProvider).deleteVehicle(v.id);
                                              ref.invalidate(vehiclesProvider);
                                              ref.invalidate(paginatedVehiclesProvider);
                                            }
                                          }
                                        },
                                        itemBuilder: (ctx) => [
                                          const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 16), SizedBox(width: 8), Text('Edit')])),
                                          PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, size: 16, color: crmColors.destructive), SizedBox(width: 8), Text('Delete', style: TextStyle(color: crmColors.destructive))])),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const Spacer(),
                                  if (v.driver?.name.isNotEmpty == true) ...[
                                    Row(
                                      children: [
                                        Icon(Icons.person_outline, size: 14, color: crmColors.textSecondary),
                                        6.w,
                                        Expanded(
                                          child: Text(
                                            'Driver: ${v.driver!.name}',
                                            style: TextStyle(fontSize: 12, color: crmColors.textSecondary, fontWeight: FontWeight.w500),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    8.h,
                                  ],
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Wrap(
                                        spacing: 8,
                                        children: [
                                          _tag(isRented ? 'RENTED' : 'IN-HOUSE', isRented ? crmColors.warning : crmColors.primary),
                                          _tag(v.fuelType.toUpperCase(), crmColors.textSecondary),
                                        ],
                                      ),
                                      // Status Dropdown Toggle
                                      Container(
                                        height: 32,
                                        padding: const EdgeInsets.symmetric(horizontal: 8),
                                        decoration: BoxDecoration(
                                          color: accentColor.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: DropdownButtonHideUnderline(
                                          child: DropdownButton<String>(
                                            value: ['running', 'under_service', 'accident', 'complaint', 'other'].contains(v.status) ? v.status : 'running',
                                            icon: Icon(Icons.arrow_drop_down, size: 18, color: accentColor),
                                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: accentColor),
                                            onChanged: (newStatus) async {
                                              if (newStatus != null && newStatus != v.status) {
                                                await ref.read(vehicleServiceProvider).saveVehicle(
                                                  id: v.id,
                                                  name: v.name,
                                                  registrationNumber: v.registrationNumber,
                                                  type: v.type,
                                                  status: newStatus,
                                                  brand: v.brand,
                                                  fuelType: v.fuelType,
                                                  notes: v.notes,
                                                  driverId: v.driver?.id,
                                                  ownershipType: v.ownershipType,
                                                );
                                                ref.invalidate(vehiclesProvider);
                                                ref.invalidate(paginatedVehiclesProvider);
                                              }
                                            },
                                            items: const [
                                              DropdownMenuItem(value: 'running', child: Text('Running')),
                                              DropdownMenuItem(value: 'under_service', child: Text('Under Service')),
                                              DropdownMenuItem(value: 'accident', child: Text('Accident')),
                                              DropdownMenuItem(value: 'complaint', child: Text('Complaint')),
                                              DropdownMenuItem(value: 'other', child: Text('Other')),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        20.h,
        asyncVehicles.maybeWhen(
          data: (response) => PaginatedFooter(
            page: response.page,
            limit: response.limit,
            totalPages: response.totalPages,
            totalItems: response.totalItems,
            currentItemCount: response.items.length,
            onPrevious: response.page > 1
                ? () => pageState.value -= 1
                : null,
            onNext: response.page < response.totalPages
                ? () => pageState.value += 1
                : null,
          ),
          orElse: () => const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _tag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}
