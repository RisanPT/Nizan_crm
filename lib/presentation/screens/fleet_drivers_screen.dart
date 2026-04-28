import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../core/extensions/space_extension.dart';
import '../../core/models/employee.dart';
import '../../core/models/service_region.dart';
import '../../core/theme/crm_theme.dart';
import '../../core/utils/responsive_builder.dart';
import '../../services/employee_service.dart';
import '../../services/region_service.dart';
import '../common_widgets/paginated_footer.dart';

class FleetDriversScreen extends HookConsumerWidget {
  const FleetDriversScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final crmColors = context.crmColors;
    final isMobile = ResponsiveBuilder.isMobile(context);
    final pageState = useState(1);
    const pageSize = 20;
    final asyncEmployees = ref.watch(employeesProvider);
    final asyncRegions = ref.watch(regionsProvider);

    Future<void> openDriverDialog([Employee? driver]) async {
      final nameCtrl = TextEditingController(text: driver?.name ?? '');
      final emailCtrl = TextEditingController(text: driver?.email ?? '');
      final roleCtrl = TextEditingController(
        text: driver?.specialization.isNotEmpty == true
            ? driver!.specialization
            : 'Fleet Driver',
      );
      final phoneCtrl = TextEditingController(text: driver?.phone ?? '');
      var type = driver?.type ?? 'in-house';
      var status = driver?.status ?? 'active';
      var regionId = driver?.regionId ?? '';

      await showDialog(
        context: context,
        builder: (dialogContext) {
          final regions = asyncRegions.value ?? const <ServiceRegion>[];
          final regionOptions = [
            const DropdownMenuItem(
              value: '',
              child: Text('Any / All'),
            ),
            ...regions.map(
              (region) => DropdownMenuItem(
                value: region.id,
                child: Text(region.name),
              ),
            ),
          ];
          final hasSelectedRegion = regionOptions.any(
            (item) => item.value == regionId,
          );
          return StatefulBuilder(
            builder: (context, setState) => AlertDialog(
              title: Text(driver == null ? 'Add Driver' : 'Edit Driver'),
              content: SizedBox(
                width: 420,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(labelText: 'Name'),
                      ),
                      16.h,
                      TextField(
                        controller: emailCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Email (Optional)',
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
                                  value: 'in-house',
                                  child: Text('In-House'),
                                ),
                                DropdownMenuItem(
                                  value: 'outsource',
                                  child: Text('Outsource'),
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
                              initialValue: hasSelectedRegion ? regionId : '',
                              items: regionOptions,
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() => regionId = value);
                                }
                              },
                              decoration: const InputDecoration(
                                labelText: 'Region',
                              ),
                            ),
                          ),
                        ],
                      ),
                      16.h,
                      TextField(
                        controller: roleCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Role / Notes',
                        ),
                      ),
                      16.h,
                      TextField(
                        controller: phoneCtrl,
                        decoration: const InputDecoration(labelText: 'Phone'),
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
                            value: 'inactive',
                            child: Text('Inactive'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) setState(() => status = value);
                        },
                        decoration: const InputDecoration(labelText: 'Status'),
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
                    await ref.read(employeeServiceProvider).saveEmployee(
                          id: driver?.id,
                          name: nameCtrl.text.trim(),
                          email: emailCtrl.text.trim(),
                          type: type,
                          artistRole: 'driver',
                          specialization: roleCtrl.text.trim(),
                          phone: phoneCtrl.text.trim(),
                          status: status,
                          regionId: regionId,
                          category: 'administrative',
                        );
                    ref.invalidate(employeesProvider);
                    ref.invalidate(paginatedEmployeesProvider);
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
                    'Fleet Drivers',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Manage driver records used across bookings and fleet vehicles.',
                    style: TextStyle(color: crmColors.textSecondary),
                  ),
                ],
              ),
            ),
            if (!isMobile)
              Row(
                children: [
                  OutlinedButton(
                    onPressed: () => context.go('/staff'),
                    child: const Text('Open Staff Management'),
                  ),
                  12.w,
                  ElevatedButton.icon(
                    onPressed: () => openDriverDialog(),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Driver'),
                  ),
                ],
              ),
          ],
        ),
        if (isMobile) ...[
          16.h,
          ElevatedButton.icon(
            onPressed: () => openDriverDialog(),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add Driver'),
          ),
        ],
        24.h,
        Expanded(
          child: asyncEmployees.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(
              child: Text(
                'Failed to load drivers: $error',
                style: TextStyle(color: crmColors.textSecondary),
              ),
            ),
            data: (employees) {
              final allDrivers = employees
                  .where((employee) => employee.artistRole == 'driver')
                  .toList();
              final totalPages = allDrivers.isEmpty
                  ? 1
                  : (allDrivers.length / pageSize).ceil();
              final currentPage = pageState.value.clamp(1, totalPages);
              if (currentPage != pageState.value) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  pageState.value = currentPage;
                });
              }
              final startIndex = (currentPage - 1) * pageSize;
              final endIndex = (startIndex + pageSize).clamp(
                0,
                allDrivers.length,
              );
              final drivers = allDrivers.sublist(startIndex, endIndex);

              if (drivers.isEmpty) {
                return Center(
                  child: Text(
                    'No drivers found.',
                    style: TextStyle(color: crmColors.textSecondary),
                  ),
                );
              }

              return Card(
                child: ListView.separated(
                  itemCount: drivers.length,
                  separatorBuilder: (context, index) =>
                      Divider(height: 1, color: crmColors.border),
                  itemBuilder: (context, index) {
                    final driver = drivers[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: crmColors.warning.withValues(
                          alpha: 0.12,
                        ),
                        child: Icon(
                          Icons.badge_outlined,
                          color: crmColors.warning,
                        ),
                      ),
                      title: Text(
                        driver.name,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        [
                          driver.phone,
                          driver.regionName,
                          driver.specialization,
                        ].where((item) => item.isNotEmpty).join(' • '),
                      ),
                      trailing: Wrap(
                        spacing: 8,
                        children: [
                          Text(
                            driver.status.toUpperCase(),
                            style: TextStyle(
                              color: driver.status == 'active'
                                  ? crmColors.success
                                  : crmColors.textSecondary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          TextButton(
                            onPressed: () => openDriverDialog(driver),
                            child: const Text('Edit'),
                          ),
                          TextButton(
                            onPressed: () async {
                              await ref
                                  .read(employeeServiceProvider)
                                  .deleteEmployee(driver.id);
                              ref.invalidate(employeesProvider);
                              ref.invalidate(paginatedEmployeesProvider);
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: crmColors.destructive,
                            ),
                            child: const Text('Delete'),
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
        asyncEmployees.maybeWhen(
          data: (employees) {
            final totalDrivers = employees
                .where((employee) => employee.artistRole == 'driver')
                .length;
            final totalPages = totalDrivers == 0
                ? 1
                : (totalDrivers / pageSize).ceil();
            final currentPage = pageState.value.clamp(1, totalPages);
            final currentItemCount = totalDrivers == 0
                ? 0
                : ((currentPage - 1) * pageSize + pageSize > totalDrivers
                      ? totalDrivers - ((currentPage - 1) * pageSize)
                      : pageSize);

            return PaginatedFooter(
              page: currentPage,
              limit: pageSize,
              totalPages: totalPages,
              totalItems: totalDrivers,
              currentItemCount: currentItemCount,
              onPrevious: pageState.value > 1
                  ? () => pageState.value -= 1
                  : null,
              onNext: pageState.value < totalPages
                  ? () => pageState.value += 1
                  : null,
            );
          },
          orElse: () => const SizedBox.shrink(),
        ),
      ],
    );
  }
}
