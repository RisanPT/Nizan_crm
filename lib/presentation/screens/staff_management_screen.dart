import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../core/extensions/space_extension.dart';
import '../../core/models/employee.dart';
import '../../core/models/service_region.dart';
import '../../core/theme/crm_theme.dart';
import '../../core/utils/responsive_builder.dart';
import '../../services/employee_service.dart';
import '../../services/region_service.dart';

class StaffManagementScreen extends HookConsumerWidget {
  const StaffManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final crmColors = context.crmColors;
    final isMobile = ResponsiveBuilder.isMobile(context);
    final asyncEmployees = ref.watch(employeesProvider);
    final asyncRegions = ref.watch(regionsProvider);

    Future<void> openStaffDialog([
      Employee? employee,
      String? presetRole,
    ]) async {
      final nameCtrl = TextEditingController(text: employee?.name ?? '');
      final emailCtrl = TextEditingController(text: employee?.email ?? '');
      final specializationCtrl = TextEditingController(
        text: employee?.specialization ?? '',
      );
      final phoneCtrl = TextEditingController(text: employee?.phone ?? '');
      var type = employee?.type ?? 'outsource';
      var artistRole = employee?.artistRole ?? presetRole ?? 'artist';
      var status = employee?.status ?? 'active';
      var regionId = employee?.regionId ?? '';

      await showDialog(
        context: context,
        builder: (dialogContext) {
          final regions = asyncRegions.value ?? const <ServiceRegion>[];
          final regionItems = <DropdownMenuItem<String>>[
            const DropdownMenuItem(value: '', child: Text('Any / All')),
            ...regions.map(
              (region) =>
                  DropdownMenuItem(value: region.id, child: Text(region.name)),
            ),
          ];

          return StatefulBuilder(
            builder: (context, setState) => AlertDialog(
              title: Text(
                employee == null
                    ? (presetRole == 'driver' ? 'Add Driver' : 'Add Staff')
                    : 'Edit Staff',
              ),
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
                                if (value != null) {
                                  setState(() => type = value);
                                }
                              },
                              decoration: const InputDecoration(
                                labelText: 'Type',
                              ),
                            ),
                          ),
                          16.w,
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: regionId,
                              items: regionItems,
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
                      DropdownButtonFormField<String>(
                        initialValue: artistRole,
                        items: const [
                          DropdownMenuItem(
                            value: 'artist',
                            child: Text('Artist'),
                          ),
                          DropdownMenuItem(
                            value: 'assistant',
                            child: Text('Assistant'),
                          ),
                          DropdownMenuItem(
                            value: 'driver',
                            child: Text('Driver'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => artistRole = value);
                          }
                        },
                        decoration: const InputDecoration(
                          labelText: 'Staff Role',
                        ),
                      ),
                      16.h,
                      TextField(
                        controller: specializationCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Specialization / Role',
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
                          if (value != null) {
                            setState(() => status = value);
                          }
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
                    await ref
                        .read(employeeServiceProvider)
                        .saveEmployee(
                          id: employee?.id,
                          name: nameCtrl.text.trim(),
                          email: emailCtrl.text.trim(),
                          type: type,
                          artistRole: artistRole,
                          specialization: specializationCtrl.text.trim(),
                          phone: phoneCtrl.text.trim(),
                          status: status,
                          regionId: regionId,
                        );
                    ref.invalidate(employeesProvider);
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
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Artists / Staff / Drivers',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Manage artists, assistants, drivers, type, region, and staff details.',
                    style: TextStyle(color: crmColors.textSecondary),
                  ),
                ],
              ),
            ),
            if (!isMobile)
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () => openStaffDialog(null, 'driver'),
                    icon: const Icon(Icons.local_taxi_outlined, size: 18),
                    label: const Text('Add Driver'),
                  ),
                  16.w,
                  ElevatedButton.icon(
                    onPressed: () => openStaffDialog(),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Staff'),
                  ),
                ],
              ),
          ],
        ),
        if (isMobile) ...[
          16.h,
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => openStaffDialog(null, 'driver'),
                  icon: const Icon(Icons.local_taxi_outlined, size: 18),
                  label: const Text('Add Driver'),
                ),
              ),
              16.w,
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => openStaffDialog(),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Staff'),
                ),
              ),
            ],
          ),
        ],
        24.h,
        Expanded(
          child: asyncEmployees.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(
              child: Text(
                'Failed to load staff: $error',
                style: TextStyle(color: crmColors.textSecondary),
              ),
            ),
            data: (employees) {
              if (employees.isEmpty) {
                return Center(
                  child: Text(
                    'No staff found.',
                    style: TextStyle(color: crmColors.textSecondary),
                  ),
                );
              }

              return Card(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minWidth:
                          MediaQuery.of(context).size.width -
                          (isMobile ? 32 : 300),
                    ),
                    child: SingleChildScrollView(
                      child: DataTable(
                        columnSpacing: 28,
                        headingTextStyle: TextStyle(
                          color: crmColors.textSecondary,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                        columns: const [
                          DataColumn(label: Text('NAME')),
                          DataColumn(label: Text('TYPE')),
                          DataColumn(label: Text('LEVEL')),
                          DataColumn(label: Text('ROLE')),
                          DataColumn(label: Text('PHONE')),
                          DataColumn(label: Text('STATUS')),
                          DataColumn(label: Text('ACTIONS')),
                        ],
                        rows: employees
                            .map(
                              (employee) => _buildStaffRow(
                                context,
                                ref,
                                employee,
                                onEdit: () => openStaffDialog(employee),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  DataRow _buildStaffRow(
    BuildContext context,
    WidgetRef ref,
    Employee employee, {
    required VoidCallback onEdit,
  }) {
    final crmColors = context.crmColors;
    final isArtist = employee.artistRole == 'artist';
    final isDriver = employee.artistRole == 'driver';
    final isActive = employee.status == 'active';
    final levelLabel = isArtist
        ? 'Artist'
        : isDriver
        ? 'Driver'
        : 'Assistant';
    final levelColor = isArtist
        ? crmColors.accent
        : isDriver
        ? Colors.indigo
        : crmColors.primary;
    final levelBackground = isArtist
        ? crmColors.accent.withValues(alpha: 0.12)
        : isDriver
        ? Colors.indigo.withValues(alpha: 0.10)
        : crmColors.primary.withValues(alpha: 0.10);

    return DataRow(
      cells: [
        DataCell(
          Text(
            employee.name,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        DataCell(
          Text(
            employee.type,
            style: TextStyle(
              color: employee.type == 'in-house'
                  ? crmColors.accent
                  : crmColors.textSecondary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: levelBackground,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              levelLabel,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: levelColor,
              ),
            ),
          ),
        ),
        DataCell(
          Text(employee.specialization.isEmpty ? '-' : employee.specialization),
        ),
        DataCell(Text(employee.phone.isEmpty ? '-' : employee.phone)),
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isActive
                  ? crmColors.success.withValues(alpha: 0.12)
                  : crmColors.destructive.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              isActive ? 'Active' : 'Inactive',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isActive ? crmColors.success : crmColors.destructive,
              ),
            ),
          ),
        ),
        DataCell(
          Row(
            children: [
              TextButton(onPressed: onEdit, child: const Text('Edit')),
              TextButton(
                onPressed: () async {
                  await ref
                      .read(employeeServiceProvider)
                      .deleteEmployee(employee.id);
                  ref.invalidate(employeesProvider);
                },
                style: TextButton.styleFrom(
                  foregroundColor: crmColors.destructive,
                ),
                child: const Text('Delete'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
