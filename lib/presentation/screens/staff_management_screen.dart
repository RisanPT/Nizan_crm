import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../core/extensions/space_extension.dart';
import '../../core/models/employee.dart';
import '../../core/models/list_page_params.dart';
import '../../core/models/zone.dart';
import '../../core/models/geographic_state.dart';
import '../../core/models/service_region.dart';
import '../../core/models/district.dart';
import '../../core/models/pincode.dart';
import '../../core/theme/crm_theme.dart';
import '../../core/utils/responsive_builder.dart';
import '../common_widgets/paginated_footer.dart';
import '../../services/employee_service.dart';
import '../../services/region_service.dart';
import '../../services/zone_service.dart';
import '../../services/state_service.dart';
import '../../services/district_service.dart';
import '../../services/pincode_service.dart';
import 'package:go_router/go_router.dart';
import 'package:nizan_crm/features/hr/shared/hr_ui.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/state/data_refresh.dart';
import 'package:nizan_crm/features/hr/presentation/widgets/timebox_link_dialog.dart';
import 'package:nizan_crm/features/hr/service/timebox_service.dart';
import 'package:nizan_crm/features/hr/onboarding/presentation/widgets/complete_onboarding_dialog.dart';

class StaffManagementScreen extends HookConsumerWidget {
  const StaffManagementScreen({super.key});

  static const List<String> adminDepartments = [
    'CRM',
    'Finance',
    'Accounts',
    'IT',
    'Management',
    'Manager',
    'Sales',
    'Marketing',
    'Operations',
    'HR',
    'General',
  ];

  static Color getDepartmentColor(String? dept, BuildContext context) {
    final crm = context.crmColors;
    switch (dept?.toUpperCase()) {
      case 'CRM':
        return Colors.indigo;
      case 'FINANCE':
        return Colors.teal;
      case 'ACCOUNTS':
        return crm.success;
      case 'IT':
      case 'TECHNOLOGY & SYSTEMS (IT)':
        return Colors.blue;
      case 'SALES':
        return Colors.orange;
      case 'MARKETING':
        return Colors.purple;
      case 'HR':
        return Colors.pink;
      case 'MANAGEMENT':
        return Colors.deepPurple;
      case 'MANAGER':
        return Colors.brown;
      case 'OPERATIONS':
        return crm.accent;
      default:
        return crm.primary;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final crmColors = context.crmColors;
    final isMobile = ResponsiveBuilder.isMobile(context);
    final pageState = useState(1);
    const pageSize = 20;

    // Tab state: 'all', 'administrative', 'operations'
    final activeTab = useState('all');

    final mainSearchQuery = useState('');
    final selectedDepartment = useState('All');
    final selectedOperationsRole = useState('All');
    final selectedTimeboxStatus = useState('All'); // 'All', 'linked', 'unlinked'
    final isSyncingTimebox = useState(false);

    // Geographic filter states for operations
    final mainSelectedZoneId = useState('');
    final mainSelectedStateId = useState('');
    final mainSelectedRegionId = useState('');
    final mainSelectedDistrictId = useState('');
    final mainSelectedPincodeId = useState('');

    final asyncZones = ref.watch(zonesProvider);
    final asyncStates = ref.watch(statesProvider);
    final asyncRegions = ref.watch(regionsProvider);
    final asyncDistricts = ref.watch(districtsProvider);
    final asyncPincodes = ref.watch(pincodesProvider);

    final zones = asyncZones.value ?? const <ZoneModel>[];
    final states = asyncStates.value ?? const <GeographicState>[];
    final regions = asyncRegions.value ?? const <ServiceRegion>[];
    final districts = asyncDistricts.value ?? const <District>[];
    final pincodes = asyncPincodes.value ?? const <Pincode>[];

    final mainAvailableStates =
        states.where((s) => s.zoneId == mainSelectedZoneId.value).toList();
    final mainAvailableRegions =
        regions.where((r) => r.stateId == mainSelectedStateId.value).toList();
    final mainAvailableDistricts = districts
        .where((d) => d.regionId == mainSelectedRegionId.value)
        .toList();
    final mainAvailablePincodes = pincodes
        .where((p) => p.districtId == mainSelectedDistrictId.value)
        .toList();

    final queryCategory =
        activeTab.value == 'all' ? 'all' : activeTab.value;
    final queryDepartment =
        selectedDepartment.value != 'All' ? selectedDepartment.value : null;
    final queryArtistRole = activeTab.value == 'operations' &&
            selectedOperationsRole.value != 'All'
        ? selectedOperationsRole.value
        : null;
    final queryTimeboxStatus =
        selectedTimeboxStatus.value != 'All' ? selectedTimeboxStatus.value : null;

    final asyncEmployees = ref.watch(
      paginatedEmployeesProvider(
        ListPageParams(
          page: pageState.value,
          limit: pageSize,
          category: queryCategory,
          department: queryDepartment,
          artistRole: queryArtistRole,
          timeboxStatus: queryTimeboxStatus,
          search: mainSearchQuery.value,
          zoneId: activeTab.value == 'operations' ? mainSelectedZoneId.value : null,
          stateId: activeTab.value == 'operations' ? mainSelectedStateId.value : null,
          regionId: activeTab.value == 'operations' ? mainSelectedRegionId.value : null,
          districtId: activeTab.value == 'operations' ? mainSelectedDistrictId.value : null,
          pincodeId: activeTab.value == 'operations' ? mainSelectedPincodeId.value : null,
        ),
      ),
    );

    Future<void> syncTimeboxAction() async {
      isSyncingTimebox.value = true;
      try {
        final res = await ref.read(timeboxServiceProvider).syncEmployees();
        ref.invalidate(paginatedEmployeesProvider);
        ref.invalidate(employeesProvider);
        ref.refreshData.employees();
        ref.refreshData.hr();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.teal.shade800,
              content: Text(res.message.isNotEmpty
                  ? res.message
                  : 'Timebox attendance sync completed successfully!'),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.red.shade800,
              content: Text(friendlyErrorMessage(e)),
            ),
          );
        }
      } finally {
        isSyncingTimebox.value = false;
      }
    }

    Future<void> openStaffDialog([
      Employee? employee,
      String? defaultCategory,
    ]) async {
      final saved = await showCompleteOnboardingDialog(
        context,
        employee: employee,
        startOnboardingChecklist: false,
      );
      if (saved != null) {
        ref.invalidate(paginatedEmployeesProvider);
        ref.invalidate(employeesProvider);
        ref.refreshData.employees();
        ref.refreshData.hr();
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header Row
        if (!isMobile) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Staff & Human Resources',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    4.h,
                    Text(
                      'Manage administrative departments, creative artists, and fleet personnel.',
                      style: TextStyle(color: crmColors.textSecondary),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.teal,
                      side: const BorderSide(color: Colors.teal),
                    ),
                    onPressed: isSyncingTimebox.value ? null : syncTimeboxAction,
                    icon: isSyncingTimebox.value
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.teal),
                          )
                        : const Icon(Icons.sync, size: 16),
                    label: Text(isSyncingTimebox.value ? 'Syncing...' : 'Sync Timebox'),
                  ),
                  12.w,
                  OutlinedButton.icon(
                    onPressed: () => openStaffDialog(null, 'administrative'),
                    icon: const Icon(Icons.business_center_outlined, size: 16),
                    label: const Text('Add Administrative'),
                  ),
                  12.w,
                  ElevatedButton.icon(
                    onPressed: () => openStaffDialog(null, 'operations'),
                    icon: const Icon(Icons.palette_outlined, size: 16),
                    label: const Text('Add Operations'),
                  ),
                ],
              ),
            ],
          ),
          16.h,
        ],
        if (isMobile) ...[
          12.h,
          Row(
            children: [
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.teal,
                  side: const BorderSide(color: Colors.teal),
                ),
                onPressed: isSyncingTimebox.value ? null : syncTimeboxAction,
                icon: isSyncingTimebox.value
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.teal),
                      )
                    : const Icon(Icons.sync, size: 16),
                label: Text(isSyncingTimebox.value ? 'Syncing...' : 'Sync Timebox'),
              ),
              8.w,
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => openStaffDialog(null, 'administrative'),
                  icon: const Icon(Icons.business_center_outlined, size: 16),
                  label: const Text('Add Admin'),
                ),
              ),
              8.w,
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => openStaffDialog(null, 'operations'),
                  icon: const Icon(Icons.palette_outlined, size: 16),
                  label: const Text('Add Ops'),
                ),
              ),
            ],
          ),
          12.h,
        ],

        // Primary Category Switcher (Tabs)
        Container(
          decoration: BoxDecoration(
            color: crmColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: crmColors.border),
          ),
          padding: const EdgeInsets.all(4),
          child: Row(
            children: [
              _buildCategoryTab(
                context,
                title: 'All Staff',
                icon: Icons.people_alt_outlined,
                isSelected: activeTab.value == 'all',
                onTap: () {
                  activeTab.value = 'all';
                  selectedDepartment.value = 'All';
                  selectedOperationsRole.value = 'All';
                  pageState.value = 1;
                },
              ),
              _buildCategoryTab(
                context,
                title: 'Administrative Staff',
                icon: Icons.business_center_outlined,
                isSelected: activeTab.value == 'administrative',
                onTap: () {
                  activeTab.value = 'administrative';
                  selectedDepartment.value = 'All';
                  pageState.value = 1;
                },
              ),
              _buildCategoryTab(
                context,
                title: 'Operations Staff (Artists & Fleet)',
                icon: Icons.palette_outlined,
                isSelected: activeTab.value == 'operations',
                onTap: () {
                  activeTab.value = 'operations';
                  selectedOperationsRole.value = 'All';
                  pageState.value = 1;
                },
              ),
            ],
          ),
        ),
        16.h,

        // Context-Aware Filter & Search Box
        Container(
          decoration: hrCardDecoration(crmColors),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
                // Top Search Bar
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.search, size: 18),
                          hintText: activeTab.value == 'administrative'
                              ? 'Search administrative staff by name, email, department, designation...'
                              : (activeTab.value == 'operations'
                                  ? 'Search artists & drivers by name, phone, specialization...'
                                  : 'Search all employees...'),
                          isDense: true,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        onChanged: (val) {
                          mainSearchQuery.value = val;
                          pageState.value = 1;
                        },
                      ),
                    ),
                    if (mainSearchQuery.value.isNotEmpty ||
                        selectedDepartment.value != 'All' ||
                        selectedOperationsRole.value != 'All' ||
                        selectedTimeboxStatus.value != 'All' ||
                        mainSelectedZoneId.value.isNotEmpty ||
                        mainSelectedStateId.value.isNotEmpty ||
                        mainSelectedRegionId.value.isNotEmpty ||
                        mainSelectedDistrictId.value.isNotEmpty ||
                        mainSelectedPincodeId.value.isNotEmpty) ...[
                      12.w,
                      TextButton.icon(
                        onPressed: () {
                          mainSearchQuery.value = '';
                          selectedDepartment.value = 'All';
                          selectedOperationsRole.value = 'All';
                          selectedTimeboxStatus.value = 'All';
                          mainSelectedZoneId.value = '';
                          mainSelectedStateId.value = '';
                          mainSelectedRegionId.value = '';
                          mainSelectedDistrictId.value = '';
                          mainSelectedPincodeId.value = '';
                          pageState.value = 1;
                        },
                        icon: const Icon(Icons.clear, size: 16),
                        label: const Text('Clear Filters'),
                      ),
                    ],
                  ],
                ),

                // Timebox Biometric Link Status Chips
                12.h,
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      Text(
                        'Timebox Biometrics: ',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: crmColors.textSecondary,
                        ),
                      ),
                      8.w,
                      FilterChip(
                        label: const Text('All Staff'),
                        selected: selectedTimeboxStatus.value == 'All',
                        onSelected: (_) {
                          selectedTimeboxStatus.value = 'All';
                          pageState.value = 1;
                        },
                      ),
                      8.w,
                      FilterChip(
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.fingerprint, size: 14, color: Colors.teal),
                            SizedBox(width: 4),
                            Text('Biometric Linked'),
                          ],
                        ),
                        selected: selectedTimeboxStatus.value == 'linked',
                        onSelected: (_) {
                          selectedTimeboxStatus.value = 'linked';
                          pageState.value = 1;
                        },
                      ),
                      8.w,
                      FilterChip(
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.link_off, size: 14, color: Colors.blueGrey),
                            SizedBox(width: 4),
                            Text('Not Linked'),
                          ],
                        ),
                        selected: selectedTimeboxStatus.value == 'unlinked',
                        onSelected: (_) {
                          selectedTimeboxStatus.value = 'unlinked';
                          pageState.value = 1;
                        },
                      ),
                    ],
                  ),
                ),

                // Department filter chips for Administrative or All tabs
                if (activeTab.value == 'administrative' ||
                    activeTab.value == 'all') ...[
                  12.h,
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        Text(
                          'Department: ',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: crmColors.textSecondary,
                          ),
                        ),
                        8.w,
                        FilterChip(
                          label: const Text('All Departments'),
                          selected: selectedDepartment.value == 'All',
                          onSelected: (_) {
                            selectedDepartment.value = 'All';
                            pageState.value = 1;
                          },
                        ),
                        8.w,
                        ...adminDepartments.map((dept) {
                          final isSel = selectedDepartment.value == dept;
                          final color = getDepartmentColor(dept, context);
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: FilterChip(
                              label: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: color,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  6.w,
                                  Text(dept),
                                ],
                              ),
                              selected: isSel,
                              selectedColor: color.withValues(alpha: 0.18),
                              onSelected: (_) {
                                selectedDepartment.value = dept;
                                pageState.value = 1;
                              },
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ],

                // Operations role chips & Geographic Filters for Operations tab
                if (activeTab.value == 'operations') ...[
                  12.h,
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        Text(
                          'Role: ',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: crmColors.textSecondary,
                          ),
                        ),
                        8.w,
                        FilterChip(
                          label: const Text('All Roles'),
                          selected: selectedOperationsRole.value == 'All',
                          onSelected: (_) {
                            selectedOperationsRole.value = 'All';
                            pageState.value = 1;
                          },
                        ),
                        8.w,
                        FilterChip(
                          avatar: const Icon(Icons.brush, size: 14),
                          label: const Text('Artists'),
                          selected: selectedOperationsRole.value == 'artist',
                          onSelected: (_) {
                            selectedOperationsRole.value = 'artist';
                            pageState.value = 1;
                          },
                        ),
                        8.w,
                        FilterChip(
                          avatar: const Icon(Icons.assistant, size: 14),
                          label: const Text('Assistants'),
                          selected: selectedOperationsRole.value == 'assistant',
                          onSelected: (_) {
                            selectedOperationsRole.value = 'assistant';
                            pageState.value = 1;
                          },
                        ),
                        8.w,
                        FilterChip(
                          avatar: const Icon(Icons.directions_car, size: 14),
                          label: const Text('Fleet Drivers'),
                          selected: selectedOperationsRole.value == 'driver',
                          onSelected: (_) {
                            selectedOperationsRole.value = 'driver';
                            pageState.value = 1;
                          },
                        ),
                      ],
                    ),
                  ),
                  12.h,
                  // Geographic Cascading Dropdowns
                  if (isMobile)
                    Column(
                      children: [
                        DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue: mainSelectedZoneId.value.isEmpty
                              ? null
                              : mainSelectedZoneId.value,
                          decoration: const InputDecoration(
                              labelText: 'Zone', isDense: true),
                          items: zones
                              .map((z) => DropdownMenuItem(
                                  value: z.id, child: Text(z.name)))
                              .toList(),
                          onChanged: (val) {
                            mainSelectedZoneId.value = val ?? '';
                            mainSelectedStateId.value = '';
                            mainSelectedRegionId.value = '';
                            mainSelectedDistrictId.value = '';
                            mainSelectedPincodeId.value = '';
                            pageState.value = 1;
                          },
                        ),
                        10.h,
                        DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue: mainSelectedStateId.value.isEmpty
                              ? null
                              : mainSelectedStateId.value,
                          decoration: const InputDecoration(
                              labelText: 'State', isDense: true),
                          items: mainAvailableStates
                              .map((s) => DropdownMenuItem(
                                  value: s.id, child: Text(s.name)))
                              .toList(),
                          onChanged: mainSelectedZoneId.value.isEmpty
                              ? null
                              : (val) {
                                  mainSelectedStateId.value = val ?? '';
                                  mainSelectedRegionId.value = '';
                                  mainSelectedDistrictId.value = '';
                                  mainSelectedPincodeId.value = '';
                                  pageState.value = 1;
                                },
                        ),
                        10.h,
                        DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue: mainSelectedRegionId.value.isEmpty
                              ? null
                              : mainSelectedRegionId.value,
                          decoration: const InputDecoration(
                              labelText: 'Region', isDense: true),
                          items: mainAvailableRegions
                              .map((r) => DropdownMenuItem(
                                  value: r.id, child: Text(r.name)))
                              .toList(),
                          onChanged: mainSelectedStateId.value.isEmpty
                              ? null
                              : (val) {
                                  mainSelectedRegionId.value = val ?? '';
                                  mainSelectedDistrictId.value = '';
                                  mainSelectedPincodeId.value = '';
                                  pageState.value = 1;
                                },
                        ),
                        10.h,
                        DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue: mainSelectedDistrictId.value.isEmpty
                              ? null
                              : mainSelectedDistrictId.value,
                          decoration: const InputDecoration(
                              labelText: 'District', isDense: true),
                          items: mainAvailableDistricts
                              .map((d) => DropdownMenuItem(
                                  value: d.id, child: Text(d.name)))
                              .toList(),
                          onChanged: mainSelectedRegionId.value.isEmpty
                              ? null
                              : (val) {
                                  mainSelectedDistrictId.value = val ?? '';
                                  mainSelectedPincodeId.value = '';
                                  pageState.value = 1;
                                },
                        ),
                      ],
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            isExpanded: true,
                            initialValue: mainSelectedZoneId.value.isEmpty
                                ? null
                                : mainSelectedZoneId.value,
                            decoration: const InputDecoration(
                                labelText: 'Zone', isDense: true),
                            items: zones
                                .map((z) => DropdownMenuItem(
                                    value: z.id, child: Text(z.name)))
                                .toList(),
                            onChanged: (val) {
                              mainSelectedZoneId.value = val ?? '';
                              mainSelectedStateId.value = '';
                              mainSelectedRegionId.value = '';
                              mainSelectedDistrictId.value = '';
                              mainSelectedPincodeId.value = '';
                              pageState.value = 1;
                            },
                          ),
                        ),
                        10.w,
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            isExpanded: true,
                            initialValue: mainSelectedStateId.value.isEmpty
                                ? null
                                : mainSelectedStateId.value,
                            decoration: const InputDecoration(
                                labelText: 'State', isDense: true),
                            items: mainAvailableStates
                                .map((s) => DropdownMenuItem(
                                    value: s.id, child: Text(s.name)))
                                .toList(),
                            onChanged: mainSelectedZoneId.value.isEmpty
                                ? null
                                : (val) {
                                    mainSelectedStateId.value = val ?? '';
                                    mainSelectedRegionId.value = '';
                                    mainSelectedDistrictId.value = '';
                                    mainSelectedPincodeId.value = '';
                                    pageState.value = 1;
                                  },
                          ),
                        ),
                        10.w,
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            isExpanded: true,
                            initialValue: mainSelectedRegionId.value.isEmpty
                                ? null
                                : mainSelectedRegionId.value,
                            decoration: const InputDecoration(
                                labelText: 'Region', isDense: true),
                            items: mainAvailableRegions
                                .map((r) => DropdownMenuItem(
                                    value: r.id, child: Text(r.name)))
                                .toList(),
                            onChanged: mainSelectedStateId.value.isEmpty
                                ? null
                                : (val) {
                                    mainSelectedRegionId.value = val ?? '';
                                    mainSelectedDistrictId.value = '';
                                    mainSelectedPincodeId.value = '';
                                    pageState.value = 1;
                                  },
                          ),
                        ),
                        10.w,
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            isExpanded: true,
                            initialValue: mainSelectedDistrictId.value.isEmpty
                                ? null
                                : mainSelectedDistrictId.value,
                            decoration: const InputDecoration(
                                labelText: 'District', isDense: true),
                            items: mainAvailableDistricts
                                .map((d) => DropdownMenuItem(
                                    value: d.id, child: Text(d.name)))
                                .toList(),
                            onChanged: mainSelectedRegionId.value.isEmpty
                                ? null
                                : (val) {
                                    mainSelectedDistrictId.value = val ?? '';
                                    mainSelectedPincodeId.value = '';
                                    pageState.value = 1;
                                  },
                          ),
                        ),
                        10.w,
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            isExpanded: true,
                            initialValue: mainSelectedPincodeId.value.isEmpty
                                ? null
                                : mainSelectedPincodeId.value,
                            decoration: const InputDecoration(
                                labelText: 'Pincode', isDense: true),
                            items: mainAvailablePincodes
                                .map((p) => DropdownMenuItem(
                                    value: p.id, child: Text(p.code)))
                                .toList(),
                            onChanged: mainSelectedDistrictId.value.isEmpty
                                ? null
                                : (val) {
                                    mainSelectedPincodeId.value = val ?? '';
                                    pageState.value = 1;
                                  },
                          ),
                        ),
                      ],
                    ),
                ],
              ],
            ),
        ),
        16.h,

        // Staff Grid / List Content
        Expanded(
          child: asyncEmployees.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => AppErrorView(
              error: error,
              onRetry: () => ref.invalidate(paginatedEmployeesProvider),
            ),
            data: (response) {
              final employees = response.items;
              if (employees.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people_outline,
                          size: 64, color: theme.dividerColor),
                      16.h,
                      Text(
                        activeTab.value == 'administrative'
                            ? 'No administrative staff found.'
                            : (activeTab.value == 'operations'
                                ? 'No operations staff found.'
                                : 'No staff found.'),
                        style: TextStyle(
                            color: crmColors.textSecondary, fontSize: 16),
                      ),
                      12.h,
                      ElevatedButton.icon(
                        onPressed: () => openStaffDialog(),
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Add Staff Member'),
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
                  mainAxisExtent: 180,
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
        16.h,
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

  Widget _buildCategoryTab(
    BuildContext context, {
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final crm = context.crmColors;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? crm.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? Colors.white : crm.textSecondary,
              ),
              8.w,
              Flexible(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? Colors.white : crm.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStaffCard(
    BuildContext context,
    WidgetRef ref,
    Employee employee, {
    required VoidCallback onEdit,
  }) {
    final crmColors = context.crmColors;

    final isArtist = employee.artistRole == 'artist';
    final isDriver = employee.artistRole == 'driver';
    final isAssistant = employee.artistRole == 'assistant';
    final isOps = isDriver || isArtist || isAssistant || employee.category == 'operations' || employee.category == 'creative';
    final isAdmin = !isOps && (employee.category == 'administrative' ||
        employee.category == 'admin' ||
        employee.category == 'it' ||
        employee.category == 'marketing' ||
        employee.category == 'sales' ||
        employee.category == 'crm' ||
        employee.category == 'accounts' ||
        employee.category == 'hr');
    final isActive = employee.status == 'active';

    final deptColor = getDepartmentColor(employee.department, context);

    return Container(
      decoration: hrCardDecoration(crmColors),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            context.push('/staff/${employee.id}', extra: employee);
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: isAdmin
                        ? deptColor.withValues(alpha: 0.15)
                        : (isArtist
                            ? crmColors.accent.withValues(alpha: 0.15)
                            : crmColors.primary.withValues(alpha: 0.15)),
                    backgroundImage: employee.profileImage.isNotEmpty
                        ? NetworkImage(employee.profileImage)
                        : null,
                    child: employee.profileImage.isEmpty
                        ? Text(
                            employee.name.isNotEmpty
                                ? employee.name.substring(0, 1).toUpperCase()
                                : '?',
                            style: TextStyle(
                              color: isAdmin
                                  ? deptColor
                                  : (isArtist
                                      ? crmColors.accent
                                      : crmColors.primary),
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          )
                        : null,
                  ),
                  10.w,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                employee.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 15),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF601A29).withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: const Color(0xFF601A29).withValues(alpha: 0.2),
                                  width: 0.8,
                                ),
                              ),
                              child: Text(
                                employee.displayCode,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF601A29),
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                        4.h,
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: [
                            if (isAdmin) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: deptColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  employee.department ?? 'Administrative',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: deptColor,
                                  ),
                                ),
                              ),
                            ] else ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isArtist
                                      ? crmColors.accent.withValues(alpha: 0.12)
                                      : (isDriver
                                          ? Colors.orange.withValues(alpha: 0.12)
                                          : crmColors.primary
                                              .withValues(alpha: 0.10)),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  isArtist
                                      ? 'Artist'
                                      : (isDriver ? 'Fleet Driver' : 'Assistant'),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: isArtist
                                        ? crmColors.accent
                                        : (isDriver
                                            ? Colors.orange
                                            : crmColors.primary),
                                  ),
                                ),
                              ),
                            ],
                            // Employment Status Badge
                            () {
                              final statusColor = employee.isConfirmed
                                  ? const Color(0xFF1E7E34)
                                  : (employee.isProbation
                                      ? Colors.amber.shade800
                                      : (employee.isNoticePeriod
                                          ? Colors.deepOrange
                                          : Colors.grey));
                              final statusLabel = employee.isConfirmed
                                  ? 'Confirmed'
                                  : (employee.isProbation
                                      ? 'Probation'
                                      : (employee.isNoticePeriod
                                          ? 'Notice'
                                          : 'Exited'));
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 5, vertical: 2),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                      color: statusColor.withValues(alpha: 0.25),
                                      width: 0.6),
                                ),
                                child: Text(
                                  statusLabel,
                                  style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: statusColor),
                                ),
                              );
                            }(),
                            // Performance Grade Pill
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFC9A66B)
                                    .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                    color: const Color(0xFFC9A66B), width: 0.6),
                              ),
                              child: Text(
                                'Grade ${employee.currentGrade}',
                                style: const TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF601A29)),
                              ),
                            ),
                            if (employee.type == 'in-house') ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 5, vertical: 2),
                                decoration: BoxDecoration(
                                  color: crmColors.accent.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'In-House',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: crmColors.accent,
                                  ),
                                ),
                              ),
                            ],
                            // Timebox Biometric Status Badge
                            if (employee.isTimeboxLinked) ...[
                              InkWell(
                                onTap: () => showTimeboxLinkDialog(context, ref, employee),
                                borderRadius: BorderRadius.circular(4),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 5, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.teal.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                        color: Colors.teal.withValues(alpha: 0.35),
                                        width: 0.6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.fingerprint,
                                          size: 10, color: Colors.teal),
                                      const SizedBox(width: 3),
                                      Text(
                                        'Timebox #${employee.timeboxEmployeeId}',
                                        style: const TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.teal,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ] else ...[
                              InkWell(
                                onTap: () => showTimeboxLinkDialog(context, ref, employee),
                                borderRadius: BorderRadius.circular(4),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 5, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                        color: Colors.grey.withValues(alpha: 0.25),
                                        width: 0.6),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.link_off,
                                          size: 10, color: Colors.grey),
                                      SizedBox(width: 3),
                                      Text(
                                        'No Timebox',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
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
                    icon: const Icon(Icons.more_vert, size: 18),
                    onSelected: (value) async {
                      if (value == 'edit') {
                        onEdit();
                      } else if (value == 'view') {
                        context.push('/staff/${employee.id}', extra: employee);
                      } else if (value == 'timebox') {
                        showTimeboxLinkDialog(context, ref, employee);
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
                          try {
                            await ref
                                .read(employeeServiceProvider)
                                .deleteEmployee(employee.id);
                            ref.refreshData.employees();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Staff member deleted')),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              showErrorSnackBar(context, e);
                            }
                          }
                        }
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'view',
                        child: Row(
                          children: [
                            Icon(Icons.visibility_outlined, size: 16),
                            SizedBox(width: 8),
                            Text('View Profile'),
                          ],
                        ),
                      ),
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
                      const PopupMenuItem(
                        value: 'timebox',
                        child: Row(
                          children: [
                            Icon(Icons.fingerprint, size: 16, color: Colors.teal),
                            SizedBox(width: 8),
                            Text('Timebox Biometrics'),
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

              // Role / Specialization / Designation
              if (employee.role?.isNotEmpty == true ||
                  employee.specialization.isNotEmpty) ...[
                Row(
                  children: [
                    Icon(
                      isAdmin ? Icons.badge_outlined : Icons.work_outline,
                      size: 13,
                      color: crmColors.textSecondary,
                    ),
                    6.w,
                    Expanded(
                      child: Text(
                        employee.role?.isNotEmpty == true
                            ? employee.role!
                            : employee.specialization,
                        style: TextStyle(
                          color: crmColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                4.h,
              ],

              // Geographic info (for operations) or Email (for admin)
              if (!isAdmin) ...[
                () {
                  final geoPath = [
                    if (employee.zoneName.isNotEmpty) employee.zoneName,
                    if (employee.stateName.isNotEmpty) employee.stateName,
                    if (employee.regionName.isNotEmpty) employee.regionName,
                    if (employee.districtName.isNotEmpty) employee.districtName,
                    if (employee.pincodeCode.isNotEmpty) employee.pincodeCode,
                  ].join(' › ');
                  if (geoPath.isNotEmpty) {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.location_on_outlined,
                                size: 13, color: crmColors.textSecondary),
                            6.w,
                            Expanded(
                              child: Text(
                                geoPath,
                                style: TextStyle(
                                    color: crmColors.textSecondary,
                                    fontSize: 12),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        4.h,
                      ],
                    );
                  }
                  return const SizedBox.shrink();
                }(),
              ] else if (employee.email.isNotEmpty) ...[
                Row(
                  children: [
                    Icon(Icons.email_outlined,
                        size: 13, color: crmColors.textSecondary),
                    6.w,
                    Expanded(
                      child: Text(
                        employee.email,
                        style: TextStyle(
                            color: crmColors.textSecondary, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                4.h,
              ],

              // Phone & Status Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (employee.phone.isNotEmpty)
                    Row(
                      children: [
                        Icon(Icons.phone_outlined,
                            size: 13, color: crmColors.textSecondary),
                        4.w,
                        Text(
                          employee.phone,
                          style: TextStyle(
                              color: crmColors.textSecondary, fontSize: 12),
                        ),
                      ],
                    )
                  else
                    const SizedBox.shrink(),
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: isActive
                              ? crmColors.success
                              : crmColors.destructive,
                          shape: BoxShape.circle,
                        ),
                      ),
                      4.w,
                      Text(
                        isActive ? 'Active' : 'Inactive',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: isActive
                              ? crmColors.success
                              : crmColors.destructive,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
}
