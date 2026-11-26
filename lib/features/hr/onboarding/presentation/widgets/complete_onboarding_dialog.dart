import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:nizan_crm/core/models/employee.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/state/data_refresh.dart';
import 'package:nizan_crm/services/employee_service.dart';
import 'package:nizan_crm/features/hr/onboarding/service/onboarding_service.dart';
import 'package:nizan_crm/features/hr/service/timebox_service.dart';
import 'package:nizan_crm/features/hr/data/timebox_models.dart';
import 'package:nizan_crm/features/hr/designations/data/designation_models.dart';
import 'package:nizan_crm/features/hr/designations/service/designation_service.dart';
import 'package:nizan_crm/features/org/services/department_service.dart';

/// Shows the complete employee onboarding & profile editor modal dialog.
/// Captures identity, hierarchy, dates, compensation, statutory (EPF/ESI/UAN),
/// banking, and immediate Timebox biometric/portal linkage.
Future<Employee?> showCompleteOnboardingDialog(
  BuildContext context, {
  Employee? employee,
  bool startOnboardingChecklist = true,
  /// New hires only: 'administrative' leaves Department unselected (HR must
  /// pick one); anything else keeps the Operations default.
  String? defaultCategory,
}) {
  return showDialog<Employee>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _CompleteOnboardingDialog(
      employee: employee,
      startOnboardingChecklist: startOnboardingChecklist,
      defaultCategory: defaultCategory,
    ),
  );
}

class _CompleteOnboardingDialog extends ConsumerStatefulWidget {
  final Employee? employee;
  final bool startOnboardingChecklist;
  final String? defaultCategory;

  const _CompleteOnboardingDialog({
    this.employee,
    this.startOnboardingChecklist = true,
    this.defaultCategory,
  });

  @override
  ConsumerState<_CompleteOnboardingDialog> createState() =>
      _CompleteOnboardingDialogState();
}

class _CompleteOnboardingDialogState
    extends ConsumerState<_CompleteOnboardingDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isSaving = false;
  late bool _initiateChecklist;

  // ── Tab 1: Personal & Contact ───────────────────────────────────────────────
  late TextEditingController _nameCtrl;
  late TextEditingController _codeCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _phoneCtrl;
  DateTime? _dateOfBirth;
  late TextEditingController _emergencyNameCtrl;
  late TextEditingController _emergencyRelCtrl;
  late TextEditingController _emergencyPhoneCtrl;

  // ── Tab 2: Job & Hierarchy ──────────────────────────────────────────────────
  String _department = 'Operations';
  late TextEditingController _roleCtrl;
  String? _reportingManagerId;
  String _currentGrade = 'B';
  String _type = 'in-house';
  String _employmentStatus = 'probation';
  String _status = 'active';
  DateTime? _dateOfJoining;
  DateTime? _probationEndDate;

  // ── Tab 3: Salary & Compensation ───────────────────────────────────────────
  String _salaryType = 'fixed_monthly';
  late TextEditingController _baseSalaryCtrl;
  late TextEditingController _allowancesCtrl;
  late TextEditingController _deductionsCtrl;
  late TextEditingController _hraCtrl;
  int _hraDay = 0;
  late TextEditingController _overtimeRateCtrl;

  // ── Tab 4: Banking & Statutory ─────────────────────────────────────────────
  late TextEditingController _bankNameCtrl;
  late TextEditingController _accountNumberCtrl;
  late TextEditingController _ifscCodeCtrl;
  late TextEditingController _upiIdCtrl;
  late TextEditingController _panNumberCtrl;
  bool _epfApplicable = false;
  late TextEditingController _uanCtrl;
  bool _esiApplicable = false;
  late TextEditingController _esiNumberCtrl;

  // ── Tab 5: Timebox Linkage ──────────────────────────────────────────────────
  int? _timeboxEmployeeId;
  String _timeboxName = '';
  final TextEditingController _tbSearchCtrl = TextEditingController();
  List<TimeboxEmployee> _timeboxEmployees = [];
  bool _loadingTimebox = true;

  /// Designations-master id the title was picked from (null = free text kept from before).
  String? _designationId;

  /// Only used while the Departments master is loading or unreachable.
  static const List<String> _fallbackDepartments = [
    'Operations',
    'HR',
    'Sales',
    'IT',
    'Finance',
    'Marketing',
    'Management',
  ];

  /// Department options: the active Departments master, plus the employee's
  /// current department if it is not in it, so opening the form never changes it.
  List<String> _departmentOptions(List<String> master) {
    final list = master.isEmpty ? [..._fallbackDepartments] : [...master];
    if (_department.isNotEmpty && !list.contains(_department)) list.insert(0, _department);
    return list;
  }

  /// Employee.category accepts only these values (backend enum).
  static const Set<String> _validCategories = {
    'operations', 'administrative', 'creative', 'it', 'marketing', 'sales', 'admin',
  };

  /// Category to save. An edit that keeps the department keeps the stored
  /// category; otherwise it is derived from the department, and any department
  /// without its own category (HR, Finance, CRM…) is 'administrative'.
  String _categoryToSave() {
    final e = widget.employee;
    if (e != null && e.department == _department && _validCategories.contains(e.category)) {
      return e.category;
    }
    switch (_department.trim().toLowerCase()) {
      case 'operations':
      case 'artist':
      case 'fleet':
        return 'operations';
      case 'it':
        return 'it';
      case 'marketing':
        return 'marketing';
      case 'sales':
        return 'sales';
      default:
        return 'administrative';
    }
  }

  /// artistRole to save. Edits keep the stored value (it drives artist/driver
  /// assignment elsewhere); new hires get one from the department.
  String _artistRoleToSave() {
    final e = widget.employee;
    if (e != null && e.artistRole.isNotEmpty) return e.artistRole;
    switch (_department.trim().toLowerCase()) {
      case 'operations':
      case 'artist':
        return 'artist';
      case 'fleet':
        return 'driver';
      default:
        return 'staff';
    }
  }

  /// Every Employee.type the backend stores (enum), so a stored value always
  /// has a matching dropdown item and is saved back unchanged.
  static const Map<String, String> _typeLabels = {
    'in-house': 'Permanent (In-House)',
    'full-time': 'Full-Time',
    'outsource': 'Outsource / Vendor',
    'contract': 'Fixed Term Contract',
  };

  /// The calendar day a stored date stands for. New saves are UTC midnight of
  /// the day; older ones were the browser's local midnight, read back locally.
  static DateTime? _calendarDay(DateTime? d) {
    if (d == null) return null;
    final u = d.toUtc();
    if (u.hour == 0 && u.minute == 0 && u.second == 0 && u.millisecond == 0) {
      return DateTime(u.year, u.month, u.day);
    }
    final l = d.toLocal();
    return DateTime(l.year, l.month, l.day);
  }

  static DateTime _today() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  /// Date picker whose initial day always sits inside [first, last].
  Future<DateTime?> _pickDay(DateTime? initial, DateTime first, DateTime last) {
    var init = initial ?? _today();
    if (init.isBefore(first)) init = first;
    final end = init.isAfter(last) ? init : last;
    return showDatePicker(context: context, initialDate: init, firstDate: first, lastDate: end);
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);

    final e = widget.employee;
    _initiateChecklist = widget.startOnboardingChecklist && e == null;

    // Tab 1
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _codeCtrl = TextEditingController(text: e?.employeeCode ?? '');
    _emailCtrl = TextEditingController(text: e?.email ?? '');
    _phoneCtrl = TextEditingController(text: e?.phone ?? '');
    _dateOfBirth = _calendarDay(e?.dateOfBirth);
    _emergencyNameCtrl = TextEditingController(text: e?.emergencyContactName ?? '');
    _emergencyRelCtrl =
        TextEditingController(text: e?.emergencyContactRelation ?? '');
    _emergencyPhoneCtrl =
        TextEditingController(text: e?.emergencyContactPhone ?? '');

    // Tab 2
    // Keep the stored department exactly as it is (it used to be reset to
    // Operations when it was not in a hard-coded list).
    if (e?.department != null && e!.department!.trim().isNotEmpty) {
      _department = e.department!.trim();
    } else if (e == null && widget.defaultCategory == 'administrative') {
      _department = ''; // an administrative hire: HR picks the department
    }
    _designationId = e?.designationId;
    _roleCtrl = TextEditingController(
      text: e?.role?.isNotEmpty == true
          ? e!.role!
          : (e?.specialization ?? ''),
    );
    _reportingManagerId = e?.reportingManagerId;
    _currentGrade = e?.currentGrade ?? 'B';
    // Keep the stored contract type exactly (it used to be rewritten on open).
    _type = e?.type ?? 'in-house';
    if (!_typeLabels.containsKey(_type)) _type = 'in-house';
    _employmentStatus = e?.employmentStatus ?? 'probation';
    if (!const {'probation', 'confirmed', 'notice_period', 'exited'}.contains(_employmentStatus)) {
      _employmentStatus = 'probation';
    }
    _status = e?.status == 'inactive' ? 'inactive' : 'active';
    // New hires default to joining today with a 90-day probation; an edit keeps
    // what is stored (an empty probation end stays empty until HR sets it).
    _dateOfJoining = e == null ? _today() : _calendarDay(e.dateOfJoining);
    _probationEndDate = e == null
        ? _today().add(const Duration(days: 90))
        : _calendarDay(e.probationEndDate);

    // Tab 3
    _salaryType = e?.salaryType ?? 'fixed_monthly';
    _baseSalaryCtrl = TextEditingController(
      text: (e != null && e.baseSalary > 0)
          ? e.baseSalary.toStringAsFixed(0)
          : '',
    );
    _allowancesCtrl = TextEditingController(
      text: (e != null && e.allowances > 0)
          ? e.allowances.toStringAsFixed(0)
          : '',
    );
    _deductionsCtrl = TextEditingController(
      text: (e != null && e.deductions > 0)
          ? e.deductions.toStringAsFixed(0)
          : '',
    );
    _hraCtrl = TextEditingController(
      text: (e != null && e.hra > 0) ? e.hra.toStringAsFixed(0) : '',
    );
    _hraDay = e?.hraDay ?? 0;
    _overtimeRateCtrl = TextEditingController(
      text: (e != null && e.overtimeRate > 0)
          ? e.overtimeRate.toStringAsFixed(0)
          : '',
    );

    // Tab 4
    _bankNameCtrl = TextEditingController(text: e?.bankName ?? '');
    _accountNumberCtrl = TextEditingController(text: e?.accountNumber ?? '');
    _ifscCodeCtrl = TextEditingController(text: e?.ifscCode ?? '');
    _upiIdCtrl = TextEditingController(text: e?.upiId ?? '');
    _panNumberCtrl = TextEditingController(text: e?.panNumber ?? '');
    _epfApplicable = e?.epfApplicable ?? false;
    _uanCtrl = TextEditingController(text: e?.uan ?? '');
    _esiApplicable = e?.esiApplicable ?? false;
    _esiNumberCtrl = TextEditingController(text: e?.esiNumber ?? '');

    // Tab 5
    _timeboxEmployeeId = e?.timeboxEmployeeId;
    _timeboxName = e?.timeboxName ?? '';

    _loadTimeboxStaff();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameCtrl.dispose();
    _codeCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _emergencyNameCtrl.dispose();
    _emergencyRelCtrl.dispose();
    _emergencyPhoneCtrl.dispose();
    _roleCtrl.dispose();
    _baseSalaryCtrl.dispose();
    _allowancesCtrl.dispose();
    _deductionsCtrl.dispose();
    _hraCtrl.dispose();
    _overtimeRateCtrl.dispose();
    _bankNameCtrl.dispose();
    _accountNumberCtrl.dispose();
    _ifscCodeCtrl.dispose();
    _upiIdCtrl.dispose();
    _panNumberCtrl.dispose();
    _uanCtrl.dispose();
    _esiNumberCtrl.dispose();
    _tbSearchCtrl.dispose();
    super.dispose();
  }

  /// Timebox ids already linked to OTHER employees → that employee's name.
  Map<int, String> _takenTimeboxIds(List<Employee> staff) => {
        for (final s in staff)
          if (s.timeboxEmployeeId != null && s.id != widget.employee?.id) s.timeboxEmployeeId!: s.name,
      };

  Future<void> _loadTimeboxStaff() async {
    try {
      final list = await ref.read(timeboxServiceProvider).getEmployees();
      Map<int, String> taken = const {};
      try {
        taken = _takenTimeboxIds(await ref.read(employeesProvider.future));
      } catch (_) {}
      if (mounted) {
        setState(() {
          _timeboxEmployees = list;
          _loadingTimebox = false;

          // New hires only: suggest a Timebox profile matching the email or
          // name, skipping profiles already linked to someone else. Edits
          // never change the link unless HR picks one.
          if (widget.employee == null && _timeboxEmployeeId == null && _nameCtrl.text.isNotEmpty) {
            final matches = list.where(
              (tb) =>
                  !taken.containsKey(tb.id) &&
                  ((tb.email.isNotEmpty &&
                          tb.email.toLowerCase() == _emailCtrl.text.trim().toLowerCase()) ||
                      tb.fullName.toLowerCase() == _nameCtrl.text.trim().toLowerCase()),
            );
            if (matches.isNotEmpty) {
              _timeboxEmployeeId = matches.first.id;
              _timeboxName = matches.first.fullName;
            }
          }
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingTimebox = false);
    }
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      _tabController.animateTo(0);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter employee full name')),
      );
      return;
    }

    // Email is optional (the server does not need it; Timebox-imported staff
    // often have none, and requiring it blocked editing them).
    final email = _emailCtrl.text.trim();

    if (_department.trim().isEmpty) {
      _tabController.animateTo(1);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a department')),
      );
      return;
    }

    // Departments-master id for the chosen name, so the org chart, member
    // counts and dept-head scoping follow a department change.
    String? departmentId;
    final depts = ref.read(departmentsProvider).maybeWhen(data: (l) => l, orElse: () => const []);
    for (final d in depts) {
      if (d.name.trim().toLowerCase() == _department.trim().toLowerCase()) {
        departmentId = d.id;
        break;
      }
    }

    final title = _roleCtrl.text.trim().isNotEmpty ? _roleCtrl.text.trim() : 'Staff';
    final existing = widget.employee;
    // An artist's specialization drives booking assignment: an edit keeps it
    // and only fills it from the title when it is empty.
    final specialization = (existing == null || existing.specialization.trim().isEmpty)
        ? title
        : existing.specialization;

    setState(() => _isSaving = true);
    try {
      final isNew = widget.employee == null;
      final savedEmployee = await ref.read(employeeServiceProvider).saveEmployee(
            id: widget.employee?.id,
            name: name,
            email: email,
            phone: _phoneCtrl.text.trim(),
            employeeCode: _codeCtrl.text.trim().isNotEmpty
                ? _codeCtrl.text.trim().toUpperCase()
                : null,
            dateOfBirth: _dateOfBirth,
            dateOfJoining: _dateOfJoining,
            probationEndDate: _probationEndDate,
            type: _type,
            artistRole: _artistRoleToSave(),
            specialization: specialization,
            role: title,
            department: _department,
            departmentId: departmentId,
            reportingManagerId: _reportingManagerId,
            currentGrade: _currentGrade,
            employmentStatus: _employmentStatus,
            status: _status,
            regionId: widget.employee?.regionId ?? '',
            category: _categoryToSave(),
            designationId: _designationId,
            salaryType: _salaryType,
            baseSalary: double.tryParse(_baseSalaryCtrl.text.trim()) ?? 0,
            allowances: double.tryParse(_allowancesCtrl.text.trim()) ?? 0,
            deductions: double.tryParse(_deductionsCtrl.text.trim()) ?? 0,
            hra: double.tryParse(_hraCtrl.text.trim()) ?? 0,
            hraDay: _hraDay,
            overtimeRate: double.tryParse(_overtimeRateCtrl.text.trim()) ?? 0,
            bankName: _bankNameCtrl.text.trim(),
            accountNumber: _accountNumberCtrl.text.trim(),
            ifscCode: _ifscCodeCtrl.text.trim(),
            upiId: _upiIdCtrl.text.trim(),
            panNumber: _panNumberCtrl.text.trim(),
            emergencyContactName: _emergencyNameCtrl.text.trim(),
            emergencyContactRelation: _emergencyRelCtrl.text.trim(),
            emergencyContactPhone: _emergencyPhoneCtrl.text.trim(),
            epfApplicable: _epfApplicable,
            esiApplicable: _esiApplicable,
            uan: _uanCtrl.text.trim(),
            esiNumber: _esiNumberCtrl.text.trim(),
            timeboxEmployeeId: _timeboxEmployeeId,
            timeboxName: _timeboxName,
            // "None" manager / no designation / Unlink Timebox must clear on save.
            sendClearableLinks: true,
          );

      // If user opted to seed onboarding tasks/documents
      if (isNew && _initiateChecklist) {
        try {
          await ref.read(onboardingServiceProvider).create(
                employeeId: savedEmployee.id,
                role: savedEmployee.role,
                department: savedEmployee.department,
                joiningDate: _dateOfJoining,
              );
        } catch (_) {}
      }

      ref.invalidate(paginatedEmployeesProvider);
      ref.invalidate(employeesProvider);
      ref.invalidate(onboardingsProvider);
      ref.refreshData.employees();
      ref.refreshData.hr();

      if (mounted) {
        Navigator.of(context).pop(savedEmployee);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF059669),
            content: Row(
              children: [
                const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isNew
                        ? 'Successfully onboarded ${savedEmployee.name}${_timeboxEmployeeId != null ? ' & linked with Timebox #$_timeboxEmployeeId' : ''}!'
                        : 'Updated employee record for ${savedEmployee.name}.',
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        showErrorSnackBar(context, e, fallback: 'Failed to save employee profile');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final isNew = widget.employee == null;
    final allStaffAsync = ref.watch(employeesProvider);

    return Dialog(
      backgroundColor: crm.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 860, maxHeight: 820),
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
              decoration: BoxDecoration(
                color: crm.primary.withValues(alpha: 0.05),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                border: Border(bottom: BorderSide(color: crm.border)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: crm.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isNew ? Icons.person_add_alt_1 : Icons.badge_outlined,
                      color: crm.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isNew ? 'Complete Employee Onboarding' : 'Edit Employee Master Record',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: crm.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isNew
                              ? 'Enter all identity, compensation, statutory, and Timebox link fields'
                              : 'Updating record for ${widget.employee?.name} (${widget.employee?.displayCode})',
                          style: TextStyle(fontSize: 12.5, color: crm.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                    tooltip: 'Close',
                  ),
                ],
              ),
            ),

            // ── Tab Bar Navigation ───────────────────────────────────────────
            Container(
              decoration: BoxDecoration(
                color: crm.background,
                border: Border(bottom: BorderSide(color: crm.border)),
              ),
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelColor: crm.primary,
                unselectedLabelColor: crm.textSecondary,
                indicatorColor: crm.primary,
                indicatorWeight: 3,
                labelStyle: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
                unselectedLabelStyle: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
                tabs: const [
                  Tab(icon: Icon(Icons.person_outline, size: 18), text: '1. Personal & Contact'),
                  Tab(icon: Icon(Icons.corporate_fare_outlined, size: 18), text: '2. Job & Hierarchy'),
                  Tab(icon: Icon(Icons.payments_outlined, size: 18), text: '3. Compensation'),
                  Tab(icon: Icon(Icons.account_balance_outlined, size: 18), text: '4. Bank & Statutory'),
                  Tab(icon: Icon(Icons.access_time_outlined, size: 18), text: '5. Timebox Link'),
                ],
              ),
            ),

            // ── Tab Content ──────────────────────────────────────────────────
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildTabPersonal(crm),
                  _buildTabJob(crm, allStaffAsync),
                  _buildTabCompensation(crm),
                  _buildTabStatutory(crm),
                  _buildTabTimebox(crm),
                ],
              ),
            ),

            // ── Footer Actions ───────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              decoration: BoxDecoration(
                color: crm.background,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                border: Border(top: BorderSide(color: crm.border)),
              ),
              child: Row(
                children: [
                  if (isNew)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Checkbox(
                          value: _initiateChecklist,
                          activeColor: crm.primary,
                          onChanged: (v) => setState(() => _initiateChecklist = v ?? true),
                        ),
                        Text(
                          'Seed 7-step onboarding checklist in HR module',
                          style: TextStyle(fontSize: 12, color: crm.textPrimary),
                        ),
                      ],
                    ),
                  const Spacer(),
                  TextButton(
                    onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: _isSaving ? null : _submit,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.check, size: 18),
                    label: Text(
                      _isSaving
                          ? 'Saving...'
                          : (isNew ? 'Complete Onboarding' : 'Save Changes'),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: crm.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Tab 1: Personal Details ─────────────────────────────────────────────────
  Widget _buildTabPersonal(CrmTheme crm) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Full Legal Name *',
                    hintText: 'e.g. Rahul Sharma',
                    prefixIcon: Icon(Icons.person_outline, size: 18),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                flex: 1,
                child: TextField(
                  controller: _codeCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Employee Code',
                    hintText: 'Auto-generated if empty',
                    prefixIcon: Icon(Icons.badge_outlined, size: 18),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Official Email',
                    hintText: 'name@company.com',
                    prefixIcon: Icon(Icons.email_outlined, size: 18),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: TextField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    hintText: '+91 98765 43210',
                    prefixIcon: Icon(Icons.phone_outlined, size: 18),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Date of Birth
          InkWell(
            onTap: () async {
              final picked = await _pickDay(_dateOfBirth ?? DateTime(1995, 1, 1), DateTime(1950), _today());
              if (picked != null) setState(() => _dateOfBirth = picked);
            },
            borderRadius: BorderRadius.circular(8),
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Date of Birth',
                prefixIcon: Icon(Icons.cake_outlined, size: 18),
              ),
              child: Text(
                _dateOfBirth != null
                    ? '${_dateOfBirth!.day}/${_dateOfBirth!.month}/${_dateOfBirth!.year}'
                    : 'Select date of birth',
                style: TextStyle(
                  color: _dateOfBirth != null ? crm.textPrimary : crm.textSecondary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Emergency Contact Box
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: crm.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: crm.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.emergency_outlined, size: 18, color: crm.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Emergency Contact Details',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: crm.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _emergencyNameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Contact Person Name',
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 1,
                      child: TextField(
                        controller: _emergencyRelCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Relationship (e.g. Spouse, Father)',
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _emergencyPhoneCtrl,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Emergency Phone',
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
    );
  }

  // ── Tab 2 fields: Department (Departments master) and Designation (Designations master)
  Widget _buildDepartmentField() {
    final master = ref.watch(departmentsProvider).maybeWhen(
          data: (list) => [for (final d in list) if (d.active && d.name.trim().isNotEmpty) d.name.trim()],
          orElse: () => const <String>[],
        );
    final options = _departmentOptions(master);
    return DropdownButtonFormField<String>(
      key: ValueKey('dept_${options.length}'),
      initialValue: options.contains(_department) ? _department : null,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Department *',
        prefixIcon: Icon(Icons.corporate_fare_outlined, size: 18),
      ),
      items: options.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
      onChanged: (v) => setState(() => _department = v ?? _department),
    );
  }

  static const String _addDesignationValue = '__add_new__';

  Widget _buildDesignationField(CrmTheme crm) {
    final async = ref.watch(designationsProvider);
    final list = async.maybeWhen(
      data: (l) => [for (final d in l) if (d.active && d.name.trim().isNotEmpty) d]
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase())),
      orElse: () => const <Designation>[],
    );
    final ids = {for (final d in list) d.id};
    final value = (_designationId != null && ids.contains(_designationId)) ? _designationId : null;
    final oldTitle = _roleCtrl.text.trim();
    // A title typed before the dropdown existed: shown so HR knows to pick a proper one.
    final helper = value == null && oldTitle.isNotEmpty
        ? 'Current title "$oldTitle" is not from the list. Pick one to replace it.'
        : null;

    return DropdownButtonFormField<String>(
      key: ValueKey('desig_${list.length}_$value'),
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'Designation / Job Role',
        hintText: async.isLoading ? 'Loading designations…' : 'Select a designation',
        helperText: helper,
        helperMaxLines: 2,
        prefixIcon: const Icon(Icons.work_outline, size: 18),
      ),
      items: [
        for (final d in list)
          DropdownMenuItem(
            value: d.id,
            child: Text(
              d.departmentName.isNotEmpty ? '${d.name}  ·  ${d.departmentName}' : d.name,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        DropdownMenuItem(
          value: _addDesignationValue,
          child: Text('+ Add new designation', style: TextStyle(color: crm.primary, fontWeight: FontWeight.w600)),
        ),
      ],
      onChanged: (v) async {
        if (v == null) return;
        if (v == _addDesignationValue) {
          final created = await _addDesignation();
          if (!mounted) return;
          setState(() {
            if (created != null) {
              _designationId = created.id;
              _roleCtrl.text = created.name;
            }
          });
          return;
        }
        final picked = list.firstWhere((d) => d.id == v);
        setState(() {
          _designationId = picked.id;
          _roleCtrl.text = picked.name;
        });
      },
    );
  }

  /// Creates a designation in the Designations master (under the selected
  /// department when it is in the master) and returns it.
  Future<Designation?> _addDesignation() async {
    final nameCtrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add designation'),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: 'Designation name',
            helperText: 'Saved to HRMS → Designations under $_department',
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, nameCtrl.text.trim()), child: const Text('Add')),
        ],
      ),
    );
    nameCtrl.dispose();
    if (name == null || name.isEmpty) return null;

    final existing = ref.read(designationsProvider).maybeWhen(data: (l) => l, orElse: () => const <Designation>[]);
    for (final d in existing) {
      if (d.name.trim().toLowerCase() == name.toLowerCase()) return d; // reuse, never duplicate
    }
    final depts = ref.read(departmentsProvider).maybeWhen(data: (l) => l, orElse: () => const []);
    String? deptId;
    for (final d in depts) {
      if (d.name.trim().toLowerCase() == _department.trim().toLowerCase()) deptId = d.id;
    }
    try {
      final created = await ref.read(designationServiceProvider).create(name: name, departmentId: deptId);
      ref.invalidate(designationsProvider);
      return created;
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, e, fallback: 'Could not add the designation');
      }
      return null;
    }
  }

  // ── Tab 2: Job & Hierarchy ──────────────────────────────────────────────────
  Widget _buildTabJob(CrmTheme crm, AsyncValue<List<Employee>> allStaffAsync) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _buildDepartmentField()),
              const SizedBox(width: 14),
              Expanded(child: _buildDesignationField(crm)),
            ],
          ),
          const SizedBox(height: 16),
          // Reporting Manager Dropdown
          allStaffAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (_, _) => const SizedBox.shrink(),
            data: (staff) {
              // Active, not-exited staff only — plus the current manager, so an
              // existing (now inactive) manager still shows and is not dropped.
              final activeStaff = staff
                  .where((s) =>
                      s.id != widget.employee?.id &&
                      ((s.status == 'active' && s.employmentStatus != 'exited') ||
                          s.id == _reportingManagerId))
                  .toList();
              return DropdownButtonFormField<String?>(
                initialValue: activeStaff.any((s) => s.id == _reportingManagerId)
                    ? _reportingManagerId
                    : null,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Reports To (Team Lead / Department Head)',
                  hintText: 'Select reporting manager in hierarchy',
                  prefixIcon: Icon(Icons.supervisor_account_outlined, size: 18),
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('None (Direct Department Head)')),
                  ...activeStaff.map((s) => DropdownMenuItem(
                        value: s.id,
                        child: Text('${s.name} (${s.role ?? s.department ?? 'Staff'})'),
                      )),
                ],
                onChanged: (v) => setState(() => _reportingManagerId = v),
              );
            },
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _currentGrade,
                  decoration: const InputDecoration(
                    labelText: 'Grade Level',
                    prefixIcon: Icon(Icons.grade_outlined, size: 18),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'A', child: Text('Grade A (Leadership / Senior)')),
                    DropdownMenuItem(value: 'B', child: Text('Grade B (Mid-Level)')),
                    DropdownMenuItem(value: 'C', child: Text('Grade C (Junior / Associate)')),
                    DropdownMenuItem(value: 'D', child: Text('Grade D (Intern / Trainee)')),
                  ],
                  onChanged: (v) => setState(() => _currentGrade = v ?? 'B'),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _type,
                  decoration: const InputDecoration(
                    labelText: 'Employment Contract',
                    prefixIcon: Icon(Icons.assignment_ind_outlined, size: 18),
                  ),
                  items: [
                    for (final t in _typeLabels.entries)
                      DropdownMenuItem(value: t.key, child: Text(t.value)),
                  ],
                  onChanged: (v) => setState(() => _type = v ?? 'in-house'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _employmentStatus,
                  decoration: const InputDecoration(
                    labelText: 'Probation / Confirmation Status',
                    prefixIcon: Icon(Icons.verified_user_outlined, size: 18),
                  ),
                  items: [
                    const DropdownMenuItem(value: 'probation', child: Text('Under Probation')),
                    const DropdownMenuItem(value: 'confirmed', child: Text('Confirmed Staff')),
                    const DropdownMenuItem(value: 'notice_period', child: Text('Serving Notice')),
                    // Set by Offboarding; shown so exited staff open correctly,
                    // never picked here.
                    DropdownMenuItem(
                      value: 'exited',
                      enabled: widget.employee?.employmentStatus == 'exited',
                      child: const Text('Exited (via Offboarding)'),
                    ),
                  ],
                  onChanged: (v) => setState(() => _employmentStatus = v ?? 'probation'),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _status,
                  decoration: const InputDecoration(
                    labelText: 'Account Status',
                    prefixIcon: Icon(Icons.toggle_on_outlined, size: 18),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'active', child: Text('Active')),
                    DropdownMenuItem(value: 'inactive', child: Text('Inactive')),
                  ],
                  onChanged: (v) => setState(() => _status = v ?? 'active'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Joining Date & Probation End Date
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final picked = await _pickDay(
                      _dateOfJoining,
                      DateTime(1990),
                      _today().add(const Duration(days: 365)),
                    );
                    if (picked != null) {
                      setState(() {
                        // Suggest a 90-day probation for new hires (or when none
                        // is set); never overwrite a date HR already has.
                        if (widget.employee == null || _probationEndDate == null) {
                          _probationEndDate = picked.add(const Duration(days: 90));
                        }
                        _dateOfJoining = picked;
                      });
                    }
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Date of Joining *',
                      prefixIcon: Icon(Icons.calendar_today_outlined, size: 18),
                    ),
                    child: Text(
                      _dateOfJoining != null
                          ? '${_dateOfJoining!.day}/${_dateOfJoining!.month}/${_dateOfJoining!.year}'
                          : 'Select joining date',
                      style: TextStyle(
                        color: _dateOfJoining != null ? crm.textPrimary : crm.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final picked = await _pickDay(
                      _probationEndDate ?? _dateOfJoining?.add(const Duration(days: 90)),
                      DateTime(1990),
                      _today().add(const Duration(days: 730)),
                    );
                    if (picked != null) setState(() => _probationEndDate = picked);
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Probation End Date',
                      prefixIcon: Icon(Icons.event_available_outlined, size: 18),
                    ),
                    child: Text(
                      _probationEndDate != null
                          ? '${_probationEndDate!.day}/${_probationEndDate!.month}/${_probationEndDate!.year}'
                          : 'Select probation end date',
                      style: TextStyle(
                        color: _probationEndDate != null ? crm.textPrimary : crm.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Tab 3: Salary & Compensation ───────────────────────────────────────────
  Widget _buildTabCompensation(CrmTheme crm) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _salaryType,
            decoration: const InputDecoration(
              labelText: 'Payroll Model',
              prefixIcon: Icon(Icons.payments_outlined, size: 18),
            ),
            items: const [
              DropdownMenuItem(value: 'fixed_monthly', child: Text('Fixed Monthly Salary')),
              DropdownMenuItem(value: 'daily', child: Text('Daily Wage')),
              DropdownMenuItem(value: 'per_booking', child: Text('Per Booking / Project')),
              DropdownMenuItem(value: 'commission', child: Text('Commission Only')),
              DropdownMenuItem(value: 'hybrid', child: Text('Hybrid (Fixed + Incentive)')),
            ],
            onChanged: (v) => setState(() => _salaryType = v ?? 'fixed_monthly'),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _baseSalaryCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Base Salary (₹/month) *',
                    prefixText: '₹ ',
                    prefixIcon: Icon(Icons.currency_rupee, size: 18),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: TextField(
                  controller: _allowancesCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Monthly Allowances (₹)',
                    prefixText: '₹ ',
                    prefixIcon: Icon(Icons.add_circle_outline, size: 18),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _deductionsCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Standard Deductions (₹)',
                    prefixText: '₹ ',
                    prefixIcon: Icon(Icons.remove_circle_outline, size: 18),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: TextField(
                  controller: _overtimeRateCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Overtime Hourly Rate (₹/hr)',
                    prefixText: '₹ ',
                    prefixIcon: Icon(Icons.more_time, size: 18),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // HRA Section
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _hraCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'House Rent Allowance / HRA (₹/month)',
                    prefixText: '₹ ',
                    prefixIcon: Icon(Icons.home_work_outlined, size: 18),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                flex: 1,
                child: DropdownButtonFormField<int>(
                  initialValue: _hraDay,
                  decoration: const InputDecoration(
                    labelText: 'HRA Due Day',
                    prefixIcon: Icon(Icons.calendar_month_outlined, size: 18),
                  ),
                  items: [
                    const DropdownMenuItem(value: 0, child: Text('Not Set')),
                    ...List.generate(31, (i) => i + 1).map((d) => DropdownMenuItem(
                          value: d,
                          child: Text('Day $d'),
                        )),
                  ],
                  onChanged: (v) => setState(() => _hraDay = v ?? 0),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Tab 4: Banking & Statutory ─────────────────────────────────────────────
  Widget _buildTabStatutory(CrmTheme crm) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bank Account Details (For Salary Disbursements)',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: crm.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _bankNameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Bank Name',
                    hintText: 'e.g. HDFC Bank, SBI',
                    prefixIcon: Icon(Icons.account_balance, size: 18),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: TextField(
                  controller: _accountNumberCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Account Number',
                    prefixIcon: Icon(Icons.numbers, size: 18),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _ifscCodeCtrl,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'IFSC Code',
                    hintText: 'HDFC0001234',
                    prefixIcon: Icon(Icons.pin, size: 18),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: TextField(
                  controller: _upiIdCtrl,
                  decoration: const InputDecoration(
                    labelText: 'UPI ID / PhonePe',
                    hintText: 'mobile@upi',
                    prefixIcon: Icon(Icons.qr_code, size: 18),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'Tax & Statutory Compliance (EPF / ESI)',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: crm.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _panNumberCtrl,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: 'PAN Card Number',
              hintText: 'ABCDE1234F',
              prefixIcon: Icon(Icons.badge, size: 18),
            ),
          ),
          const SizedBox(height: 16),
          // EPF Section
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: crm.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: crm.border),
            ),
            child: Column(
              children: [
                Material(
                  color: Colors.transparent,
                  child: SwitchListTile(
                    title: const Text('EPF Applicable (Provident Fund)', style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text('Enables PF deduction & contribution in monthly payroll', style: TextStyle(fontSize: 12)),
                    value: _epfApplicable,
                    activeThumbColor: crm.primary,
                    onChanged: (v) => setState(() => _epfApplicable = v),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                if (_epfApplicable) ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: _uanCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Universal Account Number (UAN) *',
                      hintText: '12-digit UAN',
                      isDense: true,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          // ESI Section
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: crm.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: crm.border),
            ),
            child: Column(
              children: [
                Material(
                  color: Colors.transparent,
                  child: SwitchListTile(
                    title: const Text('ESIC Applicable (Employee State Insurance)', style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text('Required for gross salary up to ₹21,000/month', style: TextStyle(fontSize: 12)),
                    value: _esiApplicable,
                    activeThumbColor: crm.primary,
                    onChanged: (v) => setState(() => _esiApplicable = v),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                if (_esiApplicable) ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: _esiNumberCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'ESI IP Insurance Number *',
                      hintText: '17-digit insurance number',
                      isDense: true,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Tab 5: Timebox Linking ──────────────────────────────────────────────────
  Widget _buildTabTimebox(CrmTheme crm) {
    // One Timebox profile per employee: profiles linked to someone else are
    // shown as taken and cannot be picked (the server refuses them too).
    final taken = _takenTimeboxIds(ref.watch(employeesProvider).value ?? const <Employee>[]);
    final query = _tbSearchCtrl.text.trim().toLowerCase();
    final filtered = _timeboxEmployees.where((tb) {
      if (query.isEmpty) return true;
      return tb.fullName.toLowerCase().contains(query) ||
          tb.email.toLowerCase().contains(query) ||
          tb.id.toString().contains(query);
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Informational Banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0D9488).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF0D9488).withValues(alpha: 0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.punch_clock_outlined, color: Color(0xFF0D9488), size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Timebox Employee Portal Linkage',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: const Color(0xFF0D9488),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Binding the employee to Timebox links their attendance punch-ins, daily worklists, and task assignments directly with CRM payroll and performance tracking.',
                        style: TextStyle(fontSize: 12.5, color: crm.textPrimary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Current Link Status Card
          if (_timeboxEmployeeId != null)
            Container(
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF059669).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF059669)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Color(0xFF059669), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Linked to Timebox Profile: $_timeboxName (ID #$_timeboxEmployeeId)',
                      style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF059669)),
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() {
                      _timeboxEmployeeId = null;
                      _timeboxName = '';
                    }),
                    child: const Text('Unlink', style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            ),

          // Search Field
          TextField(
            controller: _tbSearchCtrl,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Search Timebox Accounts',
              hintText: 'Search by employee name or email...',
              prefixIcon: const Icon(Icons.search, size: 18),
              suffixIcon: _tbSearchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 16),
                      onPressed: () => setState(() => _tbSearchCtrl.clear()),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 14),

          if (_loadingTimebox)
            const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
          else if (filtered.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              alignment: Alignment.center,
              child: Text(
                'No Timebox accounts match your search. Make sure the user exists on nztimebox.nizantech.com.',
                style: TextStyle(fontSize: 13, color: crm.textSecondary),
                textAlign: TextAlign.center,
              ),
            )
          else
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: crm.border),
              ),
              constraints: const BoxConstraints(maxHeight: 280),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: filtered.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (ctx, i) {
                  final tb = filtered[i];
                  final isSelected = _timeboxEmployeeId == tb.id;
                  final takenBy = taken[tb.id];

                  return Material(
                    color: Colors.transparent,
                    child: ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        radius: 16,
                        backgroundColor: isSelected ? crm.primary : crm.background,
                        child: Text(
                          '#${tb.id}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.white : crm.textPrimary,
                          ),
                        ),
                      ),
                      title: Text(
                        tb.fullName,
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                          color: isSelected ? crm.primary : crm.textPrimary,
                        ),
                      ),
                      subtitle: Text(
                        '${tb.email} · ${tb.department.isNotEmpty ? tb.department : 'General'}',
                        style: TextStyle(fontSize: 11.5, color: crm.textSecondary),
                      ),
                      trailing: isSelected
                          ? const Icon(Icons.check_circle, color: Color(0xFF059669), size: 20)
                          : takenBy != null
                          ? Text(
                              'Linked to $takenBy',
                              style: TextStyle(fontSize: 11.5, color: crm.textSecondary),
                            )
                          : OutlinedButton(
                              onPressed: () => setState(() {
                                _timeboxEmployeeId = tb.id;
                                _timeboxName = tb.fullName;
                              }),
                              style: OutlinedButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              ),
                              child: const Text('Select'),
                            ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
