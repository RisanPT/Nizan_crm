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
import 'staff_details_screen.dart';

class StaffManagementScreen extends HookConsumerWidget {
  const StaffManagementScreen({super.key});

  static const List<String> adminDepartments = [
    'CRM',
    'Finance',
    'Accounts',
    'IT',
    'Sales',
    'Marketing',
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
        return Colors.blue;
      case 'SALES':
        return Colors.orange;
      case 'MARKETING':
        return Colors.purple;
      case 'HR':
        return Colors.pink;
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

    final asyncEmployees = ref.watch(
      paginatedEmployeesProvider(
        ListPageParams(
          page: pageState.value,
          limit: pageSize,
          category: queryCategory,
          department: queryDepartment,
          artistRole: queryArtistRole,
          search: mainSearchQuery.value,
          zoneId: activeTab.value == 'operations' ? mainSelectedZoneId.value : null,
          stateId: activeTab.value == 'operations' ? mainSelectedStateId.value : null,
          regionId: activeTab.value == 'operations' ? mainSelectedRegionId.value : null,
          districtId: activeTab.value == 'operations' ? mainSelectedDistrictId.value : null,
          pincodeId: activeTab.value == 'operations' ? mainSelectedPincodeId.value : null,
        ),
      ),
    );

    Future<void> openStaffDialog([
      Employee? employee,
      String? defaultCategory,
    ]) async {
      final isEditing = employee != null;

      // Determine initial category
      var initialCat = defaultCategory ??
          (activeTab.value == 'administrative'
              ? 'administrative'
              : (activeTab.value == 'operations' ? 'operations' : 'administrative'));

      if (employee != null) {
        final isOps = employee.artistRole == 'driver' ||
            employee.artistRole == 'artist' ||
            employee.artistRole == 'assistant' ||
            employee.category == 'operations' ||
            employee.category == 'creative';
        if (isOps) {
          initialCat = 'operations';
        } else {
          initialCat = 'administrative';
        }
      }

      final nameCtrl = TextEditingController(text: employee?.name ?? '');
      final emailCtrl = TextEditingController(text: employee?.email ?? '');
      final roleOrDesignationCtrl = TextEditingController(
        text: employee?.role?.isNotEmpty == true
            ? employee!.role!
            : (employee?.specialization ?? ''),
      );
      final phoneCtrl = TextEditingController(text: employee?.phone ?? '');
      final worksCtrl = TextEditingController(
        text: employee?.works.join(', ') ?? '',
      );
      final baseSalaryCtrl = TextEditingController(
        text: employee != null && employee.baseSalary > 0
            ? employee.baseSalary.toStringAsFixed(0)
            : '',
      );
      final allowancesCtrl = TextEditingController(
        text: employee != null && employee.allowances > 0
            ? employee.allowances.toStringAsFixed(0)
            : '',
      );
      final deductionsCtrl = TextEditingController(
        text: employee != null && employee.deductions > 0
            ? employee.deductions.toStringAsFixed(0)
            : '',
      );
      final bankNameCtrl = TextEditingController(text: employee?.bankName ?? '');
      final accountNumberCtrl =
          TextEditingController(text: employee?.accountNumber ?? '');
      final ifscCodeCtrl = TextEditingController(text: employee?.ifscCode ?? '');
      final upiIdCtrl = TextEditingController(text: employee?.upiId ?? '');
      final panNumberCtrl = TextEditingController(text: employee?.panNumber ?? '');

      var category = initialCat;
      var type = employee?.type ?? 'in-house';
      var artistRole = employee?.artistRole ?? 'artist';
      var salaryType = employee?.salaryType ??
          (initialCat == 'administrative' ? 'fixed_monthly' : 'per_booking');
      var status = employee?.status ?? 'active';
      var department = employee?.department ??
          (initialCat == 'administrative' ? 'HR' : 'Operations');
      var regionId = employee?.regionId ?? '';
      var zoneId = employee?.zoneId ?? '';
      var stateId = employee?.stateId ?? '';
      var districtId = employee?.districtId ?? '';
      var pincodeId = employee?.pincodeId ?? '';

      await showDialog(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setModalState) {
              final isAdministrative = category == 'administrative';

              return AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                title: Text(
                  isEditing
                      ? 'Edit Staff Member'
                      : (isAdministrative
                          ? 'Add Administrative Staff'
                          : 'Add Operations Staff'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                content: SizedBox(
                  width: 480,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Category switcher (Administrative vs Operations)
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: crmColors.surface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: crmColors.border),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: () {
                                    setModalState(() {
                                      category = 'administrative';
                                      if (department == 'Operations') {
                                        department = 'HR';
                                      }
                                    });
                                  },
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 8),
                                    decoration: BoxDecoration(
                                      color: isAdministrative
                                          ? crmColors.primary
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.business_center_outlined,
                                          size: 16,
                                          color: isAdministrative
                                              ? Colors.white
                                              : crmColors.textSecondary,
                                        ),
                                        6.w,
                                        Text(
                                          'Administrative',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: isAdministrative
                                                ? Colors.white
                                                : crmColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: InkWell(
                                  onTap: () {
                                    setModalState(() {
                                      category = 'operations';
                                      department = 'Operations';
                                    });
                                  },
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 8),
                                    decoration: BoxDecoration(
                                      color: !isAdministrative
                                          ? crmColors.accent
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.brush_outlined,
                                          size: 16,
                                          color: !isAdministrative
                                              ? Colors.white
                                              : crmColors.textSecondary,
                                        ),
                                        6.w,
                                        Text(
                                          'Operations (Artist/Fleet)',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: !isAdministrative
                                                ? Colors.white
                                                : crmColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        16.h,

                        // Name
                        TextField(
                          controller: nameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Full Name *',
                            prefixIcon: Icon(Icons.person_outline, size: 18),
                          ),
                        ),
                        14.h,

                        // Email
                        TextField(
                          controller: emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Email Address',
                            prefixIcon: Icon(Icons.email_outlined, size: 18),
                          ),
                        ),
                        14.h,

                        // Phone
                        TextField(
                          controller: phoneCtrl,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'Phone Number',
                            prefixIcon: Icon(Icons.phone_outlined, size: 18),
                          ),
                        ),
                        14.h,

                        if (isAdministrative) ...[
                          // Department selection
                          DropdownButtonFormField<String>(
                            isExpanded: true,
                            initialValue: adminDepartments.contains(department)
                                ? department
                                : 'HR',
                            items: adminDepartments
                                .map((d) => DropdownMenuItem(
                                      value: d,
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 10,
                                            height: 10,
                                            decoration: BoxDecoration(
                                              color: getDepartmentColor(
                                                  d, context),
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          8.w,
                                          Text(d),
                                        ],
                                      ),
                                    ))
                                .toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setModalState(() => department = val);
                              }
                            },
                            decoration: const InputDecoration(
                              labelText: 'Department *',
                              prefixIcon:
                                  Icon(Icons.apartment_outlined, size: 18),
                            ),
                          ),
                          14.h,

                          // Designation / Role
                          TextField(
                            controller: roleOrDesignationCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Designation / Job Title *',
                              hintText: 'e.g. HR Executive, Accountant, Sales Lead',
                              prefixIcon: Icon(
                                  Icons.badge_outlined,
                                  size: 18),
                            ),
                          ),
                          14.h,
                        ] else ...[
                          // Operations Role (Artist, Assistant, Driver)
                          DropdownButtonFormField<String>(
                            isExpanded: true,
                            initialValue: ['artist', 'assistant', 'driver']
                                    .contains(artistRole)
                                ? artistRole
                                : 'artist',
                            items: const [
                              DropdownMenuItem(
                                value: 'artist',
                                child: Text('Artist / Stylist'),
                              ),
                              DropdownMenuItem(
                                value: 'assistant',
                                child: Text('Assistant'),
                              ),
                              DropdownMenuItem(
                                value: 'driver',
                                child: Text('Fleet Driver / Logistics'),
                              ),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setModalState(() => artistRole = val);
                              }
                            },
                            decoration: const InputDecoration(
                              labelText: 'Operations Role *',
                              prefixIcon:
                                  Icon(Icons.palette_outlined, size: 18),
                            ),
                          ),
                          14.h,

                          // Specialization / Skills
                          TextField(
                            controller: roleOrDesignationCtrl,
                            decoration: InputDecoration(
                              labelText: artistRole == 'driver'
                                  ? 'License / Vehicle Type'
                                  : 'Primary Specialization',
                              hintText: artistRole == 'driver'
                                  ? 'e.g. Heavy Vehicle, Light Commercial'
                                  : 'e.g. Bridal Makeup, Airbrush, Hair Styling',
                              prefixIcon: const Icon(
                                  Icons.star_border_outlined,
                                  size: 18),
                            ),
                          ),
                          14.h,

                          if (artistRole != 'driver') ...[
                            TextField(
                              controller: worksCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Works / Services (comma-separated)',
                                hintText: 'e.g. Bridal, Reception, Saree Draping',
                                prefixIcon: Icon(Icons.work_outline, size: 18),
                              ),
                            ),
                            14.h,
                          ],

                          // Location Allocation
                          const Text(
                            'Geographic Assignment',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          8.h,
                          DropdownButtonFormField<String>(
                            isExpanded: true,
                            initialValue: zoneId.isEmpty ? null : zoneId,
                            items: [
                              const DropdownMenuItem(
                                  value: null, child: Text('Select Zone')),
                              ...zones.map((z) => DropdownMenuItem(
                                  value: z.id, child: Text(z.name))),
                            ],
                            onChanged: (value) {
                              setModalState(() {
                                zoneId = value ?? '';
                                stateId = '';
                                regionId = '';
                                districtId = '';
                                pincodeId = '';
                              });
                            },
                            decoration:
                                const InputDecoration(labelText: 'Zone'),
                          ),
                          10.h,
                          DropdownButtonFormField<String>(
                            isExpanded: true,
                            initialValue: stateId.isEmpty ? null : stateId,
                            items: [
                              const DropdownMenuItem(
                                  value: null, child: Text('Select State')),
                              ...states
                                  .where((s) => s.zoneId == zoneId)
                                  .map((s) => DropdownMenuItem(
                                      value: s.id, child: Text(s.name))),
                            ],
                            onChanged: zoneId.isEmpty
                                ? null
                                : (value) {
                                    setModalState(() {
                                      stateId = value ?? '';
                                      regionId = '';
                                      districtId = '';
                                      pincodeId = '';
                                    });
                                  },
                            decoration:
                                const InputDecoration(labelText: 'State'),
                          ),
                          10.h,
                          DropdownButtonFormField<String>(
                            isExpanded: true,
                            initialValue: regionId.isEmpty ? null : regionId,
                            items: [
                              const DropdownMenuItem(
                                  value: null, child: Text('Select Region')),
                              ...regions
                                  .where((r) => r.stateId == stateId)
                                  .map((r) => DropdownMenuItem(
                                      value: r.id, child: Text(r.name))),
                            ],
                            onChanged: stateId.isEmpty
                                ? null
                                : (value) {
                                    setModalState(() {
                                      regionId = value ?? '';
                                      districtId = '';
                                      pincodeId = '';
                                    });
                                  },
                            decoration:
                                const InputDecoration(labelText: 'Region'),
                          ),
                          10.h,
                          DropdownButtonFormField<String>(
                            isExpanded: true,
                            initialValue:
                                districtId.isEmpty ? null : districtId,
                            items: [
                              const DropdownMenuItem(
                                  value: null, child: Text('Select District')),
                              ...districts
                                  .where((d) => d.regionId == regionId)
                                  .map((d) => DropdownMenuItem(
                                      value: d.id, child: Text(d.name))),
                            ],
                            onChanged: regionId.isEmpty
                                ? null
                                : (value) {
                                    setModalState(() {
                                      districtId = value ?? '';
                                      pincodeId = '';
                                    });
                                  },
                            decoration:
                                const InputDecoration(labelText: 'District'),
                          ),
                          10.h,
                          DropdownButtonFormField<String>(
                            isExpanded: true,
                            initialValue: pincodeId.isEmpty ? null : pincodeId,
                            items: [
                              const DropdownMenuItem(
                                  value: null, child: Text('Select Pincode')),
                              ...pincodes
                                  .where((p) => p.districtId == districtId)
                                  .map((p) => DropdownMenuItem(
                                      value: p.id, child: Text(p.code))),
                            ],
                            onChanged: districtId.isEmpty
                                ? null
                                : (value) {
                                    setModalState(() {
                                      pincodeId = value ?? '';
                                    });
                                  },
                            decoration:
                                const InputDecoration(labelText: 'Pincode'),
                          ),
                          14.h,
                        ],

                        // Employment Type & Status Row
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                isExpanded: true,
                                initialValue: type,
                                items: const [
                                  DropdownMenuItem(
                                    value: 'in-house',
                                    child: Text('In-House / Full-time'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'outsource',
                                    child: Text('Contract / Outsource'),
                                  ),
                                ],
                                onChanged: (value) {
                                  if (value != null) {
                                    setModalState(() => type = value);
                                  }
                                },
                                decoration: const InputDecoration(
                                    labelText: 'Employment Type'),
                              ),
                            ),
                            12.w,
                            Expanded(
                              child: DropdownButtonFormField<String>(
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
                                    setModalState(() => status = value);
                                  }
                                },
                                decoration: const InputDecoration(
                                    labelText: 'Status'),
                              ),
                            ),
                          ],
                        ),
                        16.h,

                        // ── SALARY & COMPENSATION SECTION ──
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: crmColors.surface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: crmColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.currency_rupee,
                                      size: 16, color: crmColors.primary),
                                  6.w,
                                  const Text(
                                    'Salary & Compensation',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                              12.h,
                              DropdownButtonFormField<String>(
                                isExpanded: true,
                                initialValue: salaryType,
                                items: const [
                                  DropdownMenuItem(
                                    value: 'fixed_monthly',
                                    child: Text('Fixed Monthly Salary'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'per_booking',
                                    child: Text('Per Booking / Commission'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'daily',
                                    child: Text('Daily Wage / Day Rate'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'hybrid',
                                    child: Text('Hybrid (Fixed + Commission)'),
                                  ),
                                ],
                                onChanged: (val) {
                                  if (val != null) {
                                    setModalState(() => salaryType = val);
                                  }
                                },
                                decoration: const InputDecoration(
                                  labelText: 'Salary Scheme',
                                  isDense: true,
                                ),
                              ),
                              10.h,
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: baseSalaryCtrl,
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(
                                        labelText: 'Base Salary (₹)',
                                        hintText: 'e.g. 25000',
                                        isDense: true,
                                      ),
                                    ),
                                  ),
                                  8.w,
                                  Expanded(
                                    child: TextField(
                                      controller: allowancesCtrl,
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(
                                        labelText: 'Allowances (₹)',
                                        hintText: 'e.g. 3000',
                                        isDense: true,
                                      ),
                                    ),
                                  ),
                                  8.w,
                                  Expanded(
                                    child: TextField(
                                      controller: deductionsCtrl,
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(
                                        labelText: 'Deductions (₹)',
                                        hintText: 'e.g. 1000',
                                        isDense: true,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        14.h,

                        // ── BANKING & PAYMENT DETAILS ──
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: crmColors.surface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: crmColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.account_balance_outlined,
                                      size: 16, color: crmColors.accent),
                                  6.w,
                                  const Text(
                                    'Bank & Payment Info (for Accounts)',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                              12.h,
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: bankNameCtrl,
                                      decoration: const InputDecoration(
                                        labelText: 'Bank Name',
                                        hintText: 'e.g. HDFC / SBI',
                                        isDense: true,
                                      ),
                                    ),
                                  ),
                                  8.w,
                                  Expanded(
                                    child: TextField(
                                      controller: accountNumberCtrl,
                                      decoration: const InputDecoration(
                                        labelText: 'Account No.',
                                        isDense: true,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              10.h,
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: ifscCodeCtrl,
                                      decoration: const InputDecoration(
                                        labelText: 'IFSC Code',
                                        isDense: true,
                                      ),
                                    ),
                                  ),
                                  8.w,
                                  Expanded(
                                    child: TextField(
                                      controller: upiIdCtrl,
                                      decoration: const InputDecoration(
                                        labelText: 'UPI ID / PhonePe',
                                        isDense: true,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
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
                      if (nameCtrl.text.trim().isEmpty) {
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          const SnackBar(
                              content: Text('Please enter staff name')),
                        );
                        return;
                      }

                      final effectiveWorks = worksCtrl.text
                          .split(',')
                          .map((w) => w.trim())
                          .where((w) => w.isNotEmpty)
                          .toList();

                      final effectiveRole = roleOrDesignationCtrl.text.trim().isNotEmpty
                          ? roleOrDesignationCtrl.text.trim()
                          : (isAdministrative ? 'Staff' : (artistRole == 'driver' ? 'Driver' : 'Artist'));

                      await ref
                          .read(employeeServiceProvider)
                          .saveEmployee(
                            id: employee?.id,
                            name: nameCtrl.text.trim(),
                            email: emailCtrl.text.trim(),
                            type: type,
                            artistRole: isAdministrative ? 'staff' : artistRole,
                            specialization: effectiveRole,
                            phone: phoneCtrl.text.trim(),
                            status: status,
                            regionId: isAdministrative ? '' : regionId,
                            category: category,
                            department: department,
                            role: effectiveRole,
                            works: isAdministrative ? null : effectiveWorks,
                            zoneId: isAdministrative ? '' : zoneId,
                            stateId: isAdministrative ? '' : stateId,
                            districtId: isAdministrative ? '' : districtId,
                            pincodeId: isAdministrative ? '' : pincodeId,
                            salaryType: salaryType,
                            baseSalary: double.tryParse(baseSalaryCtrl.text.trim()) ?? 0,
                            allowances: double.tryParse(allowancesCtrl.text.trim()) ?? 0,
                            deductions: double.tryParse(deductionsCtrl.text.trim()) ?? 0,
                            bankName: bankNameCtrl.text.trim(),
                            accountNumber: accountNumberCtrl.text.trim(),
                            ifscCode: ifscCodeCtrl.text.trim(),
                            upiId: upiIdCtrl.text.trim(),
                            panNumber: panNumberCtrl.text.trim(),
                          );

                      ref.invalidate(employeesProvider);
                      ref.invalidate(paginatedEmployeesProvider);

                      if (dialogContext.mounted) {
                        Navigator.of(dialogContext).pop();
                      }
                    },
                    child: Text(isEditing ? 'Save Changes' : 'Create Staff'),
                  ),
                ],
              );
            },
          );
        },
      );
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
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: crmColors.border),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
        ),
        16.h,

        // Staff Grid / List Content
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
    final theme = Theme.of(context);
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
                        Text(
                          employee.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        4.h,
                        Row(
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
                            if (employee.type == 'in-house') ...[
                              6.w,
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
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                StaffDetailsScreen(employee: employee),
                          ),
                        );
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
    );
  }
}
