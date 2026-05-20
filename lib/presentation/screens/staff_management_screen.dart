import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../core/extensions/space_extension.dart';
import '../../core/models/employee.dart';
import '../../core/models/list_page_params.dart';
import '../../core/theme/crm_theme.dart';
import '../../core/utils/responsive_builder.dart';
import '../common_widgets/paginated_footer.dart';
import '../../services/employee_service.dart';
import '../../services/region_service.dart';
import '../../services/zone_service.dart';
import '../../services/state_service.dart';
import '../../services/district_service.dart';
import '../../services/pincode_service.dart';
import 'staff_details_screen.dart';

class StaffManagementScreen extends HookConsumerWidget {
  const StaffManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final crmColors = context.crmColors;
    final isMobile = ResponsiveBuilder.isMobile(context);
    final pageState = useState(1);
    const pageSize = 20;

    // Hardcode category to 'creative' as we removed administrative staff
    final asyncEmployees = ref.watch(
      paginatedEmployeesProvider(
        ListPageParams(
          page: pageState.value,
          limit: pageSize,
          category: 'creative',
        ),
      ),
    );
    final asyncZones = ref.watch(zonesProvider);
    final asyncStates = ref.watch(statesProvider);
    final asyncRegions = ref.watch(regionsProvider);
    final asyncDistricts = ref.watch(districtsProvider);
    final asyncPincodes = ref.watch(pincodesProvider);

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
      var zoneId = employee?.zoneId ?? '';
      var stateId = employee?.stateId ?? '';
      var districtId = employee?.districtId ?? '';
      var pincodeId = employee?.pincodeId ?? '';
      var category = 'creative'; // hardcoded

      await showDialog(
        context: context,
        builder: (dialogContext) {


          return StatefulBuilder(
            builder: (context, setState) => AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: Text(
                employee == null
                    ? (presetRole == 'driver' ? 'Add Driver' : 'Add Staff')
                    : 'Edit Staff',
                style: const TextStyle(fontWeight: FontWeight.bold),
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
                      DropdownButtonFormField<String>(
                        isExpanded: true,
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
                      16.h,
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Location Details',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
                      8.h,
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        value: zoneId.isEmpty ? null : zoneId,
                        items: [
                          const DropdownMenuItem(value: null, child: Text('Select Zone')),
                          ...asyncZones.value?.map((z) => DropdownMenuItem(value: z.id, child: Text(z.name))) ?? [],
                        ],
                        onChanged: (value) {
                          setState(() {
                            zoneId = value ?? '';
                            stateId = '';
                            regionId = '';
                            districtId = '';
                            pincodeId = '';
                          });
                        },
                        decoration: const InputDecoration(labelText: 'Zone'),
                      ),
                      12.h,
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        value: stateId.isEmpty ? null : stateId,
                        items: [
                          const DropdownMenuItem(value: null, child: Text('Select State')),
                          ...asyncStates.value
                                  ?.where((s) => s.zoneId == zoneId)
                                  .map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))) ??
                              [],
                        ],
                        onChanged: zoneId.isEmpty
                            ? null
                            : (value) {
                                setState(() {
                                  stateId = value ?? '';
                                  regionId = '';
                                  districtId = '';
                                  pincodeId = '';
                                });
                              },
                        decoration: const InputDecoration(labelText: 'State'),
                      ),
                      12.h,
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        value: regionId.isEmpty ? null : regionId,
                        items: [
                          const DropdownMenuItem(value: null, child: Text('Select Region')),
                          ...asyncRegions.value
                                  ?.where((r) => r.stateId == stateId)
                                  .map((r) => DropdownMenuItem(value: r.id, child: Text(r.name))) ??
                              [],
                        ],
                        onChanged: stateId.isEmpty
                            ? null
                            : (value) {
                                setState(() {
                                  regionId = value ?? '';
                                  districtId = '';
                                  pincodeId = '';
                                });
                              },
                        decoration: const InputDecoration(labelText: 'Region'),
                      ),
                      12.h,
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        value: districtId.isEmpty ? null : districtId,
                        items: [
                          const DropdownMenuItem(value: null, child: Text('Select District')),
                          ...asyncDistricts.value
                                  ?.where((d) => d.regionId == regionId)
                                  .map((d) => DropdownMenuItem(value: d.id, child: Text(d.name))) ??
                              [],
                        ],
                        onChanged: regionId.isEmpty
                            ? null
                            : (value) {
                                setState(() {
                                  districtId = value ?? '';
                                  pincodeId = '';
                                });
                              },
                        decoration: const InputDecoration(labelText: 'District'),
                      ),
                      12.h,
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        value: pincodeId.isEmpty ? null : pincodeId,
                        items: [
                          const DropdownMenuItem(value: null, child: Text('Select Pincode')),
                          ...asyncPincodes.value
                                  ?.where((p) => p.districtId == districtId)
                                  .map((p) => DropdownMenuItem(value: p.id, child: Text(p.code))) ??
                              [],
                        ],
                        onChanged: districtId.isEmpty
                            ? null
                            : (value) {
                                setState(() {
                                  pincodeId = value ?? '';
                                });
                              },
                        decoration: const InputDecoration(labelText: 'Pincode'),
                      ),
                      16.h,
                      DropdownButtonFormField<String>(
                        isExpanded: true,
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
                        isExpanded: true,
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
                          category: category,
                          zoneId: zoneId,
                          stateId: stateId,
                          districtId: districtId,
                          pincodeId: pincodeId,
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
                    'Artists & Staff',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Manage artists, assistants, and their service regions.',
                    style: TextStyle(color: crmColors.textSecondary),
                  ),
                ],
              ),
            ),
            if (!isMobile)
              Row(
                children: [
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
            data: (response) {
              final employees = response.items;
              if (employees.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people,
                          size: 64, color: theme.dividerColor),
                      16.h,
                      Text(
                        'No staff found.',
                        style: TextStyle(
                            color: crmColors.textSecondary, fontSize: 16),
                      ),
                    ],
                  ),
                );
              }

              return GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: isMobile ? 1 : 3,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  mainAxisExtent: 160,
                ),
                itemCount: employees.length,
                itemBuilder: (context, index) {
                  return _buildStaffCard(
                    context,
                    ref,
                    employees[index],
                    onEdit: () => openStaffDialog(employees[index]),
                  );
                },
              );
            },
          ),
        ),
        20.h,
        asyncEmployees.maybeWhen(
          data: (response) => PaginatedFooter(
            page: response.page,
            limit: response.limit,
            totalPages: response.totalPages,
            totalItems: response.totalItems,
            currentItemCount: response.items.length,
            onPrevious: response.page > 1 ? () => pageState.value -= 1 : null,
            onNext: response.page < response.totalPages
                ? () => pageState.value += 1
                : null,
          ),
          orElse: () => const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildStaffCard(
    BuildContext context,
    WidgetRef ref,
    Employee employee, {
    required VoidCallback onEdit,
  }) {
    final theme = Theme.of(context);
    final crmColors = context.crmColors;
    final isArtist = employee.artistRole == 'artist';
    final isActive = employee.status == 'active';
    final levelLabel = isArtist ? 'Artist' : 'Assistant';
    final levelColor = isArtist ? crmColors.accent : crmColors.primary;
    final levelBackground = isArtist
        ? crmColors.accent.withValues(alpha: 0.12)
        : crmColors.primary.withValues(alpha: 0.10);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.1)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => StaffDetailsScreen(employee: employee),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                  backgroundImage: employee.profileImage.isNotEmpty
                      ? NetworkImage(employee.profileImage)
                      : null,
                  child: employee.profileImage.isEmpty
                      ? Text(
                          employee.name.isNotEmpty
                              ? employee.name.substring(0, 1).toUpperCase()
                              : '?',
                          style: TextStyle(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        )
                      : null,
                ),
                12.w,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        employee.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      4.h,
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: levelBackground,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              levelLabel,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: levelColor,
                              ),
                            ),
                          ),
                          if (employee.type == 'in-house') ...[
                            8.w,
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: crmColors.accent.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'In-House',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: crmColors.accent,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 20),
                  onSelected: (value) async {
                    if (value == 'edit') {
                      onEdit();
                    } else if (value == 'delete') {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Delete Staff'),
                          content: Text(
                              'Are you sure you want to delete ${employee.name}?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(true),
                              style: TextButton.styleFrom(
                                  foregroundColor: crmColors.destructive),
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        await ref
                            .read(employeeServiceProvider)
                            .deleteEmployee(employee.id);
                        ref.invalidate(employeesProvider);
                        ref.invalidate(paginatedEmployeesProvider);
                      }
                    }
                  },
                  itemBuilder: (context) => [
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
                          Icon(Icons.delete,
                              size: 16, color: crmColors.destructive),
                          const SizedBox(width: 8),
                          Text('Delete',
                              style: TextStyle(color: crmColors.destructive)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const Spacer(),
            if (employee.specialization.isNotEmpty) ...[
              Row(
                children: [
                  Icon(Icons.work_outline,
                      size: 14, color: crmColors.textSecondary),
                  6.w,
                  Expanded(
                    child: Text(
                      employee.specialization,
                      style: TextStyle(
                          color: crmColors.textSecondary, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              6.h,
            ],
            if (employee.regionName.isNotEmpty || employee.districtName.isNotEmpty) ...[
              Row(
                children: [
                  Icon(Icons.location_on_outlined,
                      size: 14, color: crmColors.textSecondary),
                  6.w,
                  Expanded(
                    child: Text(
                      [
                        if (employee.regionName.isNotEmpty) employee.regionName,
                        if (employee.districtName.isNotEmpty) employee.districtName,
                        if (employee.pincodeCode.isNotEmpty) employee.pincodeCode,
                      ].join(', '),
                      style: TextStyle(
                          color: crmColors.textSecondary, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              6.h,
            ],
            if (employee.phone.isNotEmpty) ...[
              Row(
                children: [
                  Icon(Icons.phone_outlined,
                      size: 14, color: crmColors.textSecondary),
                  6.w,
                  Text(
                    employee.phone,
                    style:
                        TextStyle(color: crmColors.textSecondary, fontSize: 13),
                  ),
                ],
              ),
              6.h,
            ],
            Row(
              children: [
                Icon(Icons.check_circle_outline,
                    size: 14, color: crmColors.textSecondary),
                6.w,
                Text(
                  isActive ? 'Active' : 'Inactive',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: isActive ? crmColors.success : crmColors.destructive,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      ),
    );
  }
}
