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
      var fuelType = vehicle?.fuelType ?? 'petrol';
      var status = vehicle?.status ?? 'active';
      var driverId = vehicle?.driver?.id ?? '';
      var ownershipType = vehicle?.ownershipType ?? 'in_house';

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
                          DropdownMenuItem(
                            value: 'active',
                            child: Text('Active'),
                          ),
                          DropdownMenuItem(
                            value: 'maintenance',
                            child: Text('Maintenance'),
                          ),
                          DropdownMenuItem(
                            value: 'inactive',
                            child: Text('Inactive'),
                          ),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
            if (!isMobile)
              ElevatedButton.icon(
                onPressed: () => openVehicleDialog(),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Vehicle'),
              ),
          ],
        ),
        if (isMobile) ...[
          16.h,
          ElevatedButton.icon(
            onPressed: () => openVehicleDialog(),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add Vehicle'),
          ),
        ],
        24.h,
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
                  child: Text(
                    'No vehicles found.',
                    style: TextStyle(color: crmColors.textSecondary),
                  ),
                );
              }

              return Card(
                child: ListView.separated(
                  itemCount: vehicles.length,
                  separatorBuilder: (context, index) =>
                      Divider(height: 1, color: crmColors.border),
                  itemBuilder: (context, index) {
                    final vehicle = vehicles[index];
                    return ListTile(
                      title: Text(
                        '${vehicle.name} • ${vehicle.registrationNumber}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        [
                          vehicle.brand,
                          vehicle.type.toUpperCase(),
                          vehicle.ownershipType == 'rented' ? 'RENTED' : 'IN-HOUSE',
                          vehicle.driver?.name.isNotEmpty == true
                              ? 'Driver: ${vehicle.driver!.name}'
                              : 'Unassigned',
                        ].where((item) => item.isNotEmpty).join(' • '),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: vehicle.status == 'active'
                                  ? crmColors.success.withValues(alpha: 0.12)
                                  : crmColors.textSecondary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              vehicle.status.toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: vehicle.status == 'active'
                                    ? crmColors.success
                                    : crmColors.textSecondary,
                              ),
                            ),
                          ),
                          8.w,
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert, size: 20),
                            onSelected: (val) async {
                              if (val == 'edit') {
                                openVehicleDialog(vehicle);
                              } else if (val == 'delete') {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Delete Vehicle'),
                                    content: Text('Are you sure you want to delete ${vehicle.name}?'),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(ctx, false),
                                        child: const Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () => Navigator.pop(ctx, true),
                                        style: TextButton.styleFrom(foregroundColor: crmColors.destructive),
                                        child: const Text('Delete'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  await ref.read(vehicleServiceProvider).deleteVehicle(vehicle.id);
                                  ref.invalidate(vehiclesProvider);
                                  ref.invalidate(paginatedVehiclesProvider);
                                }
                              }
                            },
                            itemBuilder: (ctx) => [
                              const PopupMenuItem(
                                value: 'edit',
                                child: Row(
                                  children: [
                                    Icon(Icons.edit, size: 16),
                                    SizedBox(width: 8),
                                    Text('Edit'),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(Icons.delete, size: 16, color: crmColors.destructive),
                                    const SizedBox(width: 8),
                                    Text('Delete', style: TextStyle(color: crmColors.destructive)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
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
}
