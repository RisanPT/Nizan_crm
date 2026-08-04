import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:nizan_crm/core/extensions/space_extension.dart';
import 'package:nizan_crm/core/models/employee.dart';
import 'package:nizan_crm/core/models/salary.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/core/utils/responsive_builder.dart';
import 'package:nizan_crm/features/accounts/controllers/salary_controller.dart';
import 'package:nizan_crm/features/accounts/services/salary_service.dart';
import 'package:nizan_crm/features/hr/data/timebox_models.dart';
import 'package:nizan_crm/features/hr/service/timebox_service.dart';
import 'package:nizan_crm/services/employee_service.dart';

const _monthNames = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

String _formatCurrency(double amount) {
  return NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0)
      .format(amount);
}

class HRSalariesScreen extends ConsumerStatefulWidget {
  const HRSalariesScreen({super.key});

  @override
  ConsumerState<HRSalariesScreen> createState() => _HRSalariesScreenState();
}

class _HRSalariesScreenState extends ConsumerState<HRSalariesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchCtrl = TextEditingController();
  bool _isGenerating = false;
  bool _isTimeboxGenerating = false;
  /// Lookup: crmEmployeeId → PayrollRow for the current month.
  /// Populated when the administrative tab is visible.
  Map<String, PayrollRow> _payrollRowByCrmId = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      final filter = ref.read(salaryFilterProvider);
      String cat = 'all';
      if (_tabController.index == 0) cat = 'administrative';
      if (_tabController.index == 1) cat = 'operations';
      ref.read(salaryFilterProvider.notifier).state = filter.copyWith(category: cat);
    });

    // Default to administrative tab
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(salaryFilterProvider.notifier).state =
          ref.read(salaryFilterProvider).copyWith(category: 'administrative');
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _generatePayroll(int month, int year) async {
    setState(() => _isGenerating = true);
    try {
      final res = await ref.read(salaryServiceProvider).generateMonthlySalaries(
            month: month,
            year: year,
          );
      ref.invalidate(salariesProvider);
      ref.invalidate(adminSalariesProvider);
      ref.invalidate(opsSalariesProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message']?.toString() ?? 'Payroll generated successfully!'),
            backgroundColor: Colors.green.shade700,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  /// Generate payroll via Timebox attendance (attendance-pro-rated, admin only).
  Future<void> _generateTimeboxPayroll(int month, int year) async {
    // Confirm with user
    final crm = context.crmColors;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Timebox Attendance Payroll'),
        content: Text(
          'This will create/update administrative salary slips for '
          '${_monthNames[month - 1]} $year, pro-rated by Timebox attendance.\n\n'
          '• Employees matched in Timebox get attendance-prorated amounts\n'
          '• Unmatched employees are skipped\n'
          '• Slips already marked "paid" are never changed.\n\n'
          'Tip: Go to HR → Timebox → Payroll and click ↺ Sync first\n'
          'to ensure all staff are matched by ID.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Generate'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _isTimeboxGenerating = true);
    try {
      final tbMonth = TimeboxMonth(year, month);
      final msg = await ref.read(timeboxServiceProvider).generatePayroll(
            from: tbMonth.from,
            to: tbMonth.to,
          );
      ref.invalidate(salariesProvider);
      ref.invalidate(adminSalariesProvider);
      ref.invalidate(opsSalariesProvider);
      ref.invalidate(payrollPreviewProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: crm.success,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isTimeboxGenerating = false);
    }
  }

  void _showEditSalaryDialog(Salary salary) {
    final baseCtrl =
        TextEditingController(text: salary.baseSalary.toStringAsFixed(0));
    final allowCtrl =
        TextEditingController(text: salary.allowances.toStringAsFixed(0));
    final bonusCtrl =
        TextEditingController(text: salary.bonus.toStringAsFixed(0));
    final dedCtrl =
        TextEditingController(text: salary.deductions.toStringAsFixed(0));
    final notesCtrl = TextEditingController(text: salary.notes);

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.edit_note, size: 22),
              8.w,
              Expanded(
                child: Text(
                  'Adjust Salary - ${salary.employeeName}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Period: ${_monthNames[salary.month - 1]} ${salary.year} · Department: ${salary.department}',
                    style: TextStyle(
                        fontSize: 12, color: Theme.of(ctx).hintColor),
                  ),
                  16.h,
                  TextField(
                    controller: baseCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Base Salary (₹)',
                      isDense: true,
                    ),
                  ),
                  12.h,
                  TextField(
                    controller: allowCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Monthly Allowances (₹)',
                      isDense: true,
                    ),
                  ),
                  12.h,
                  TextField(
                    controller: bonusCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Bonus / Incentive (₹)',
                      isDense: true,
                    ),
                  ),
                  12.h,
                  TextField(
                    controller: dedCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Deductions / Advances (₹)',
                      isDense: true,
                    ),
                  ),
                  12.h,
                  TextField(
                    controller: notesCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Remarks / Notes',
                      isDense: true,
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  await ref.read(salaryServiceProvider).updateSalary(
                    salary.id,
                    {
                      'baseSalary': double.tryParse(baseCtrl.text.trim()) ?? 0,
                      'allowances': double.tryParse(allowCtrl.text.trim()) ?? 0,
                      'bonus': double.tryParse(bonusCtrl.text.trim()) ?? 0,
                      'deductions': double.tryParse(dedCtrl.text.trim()) ?? 0,
                      'notes': notesCtrl.text.trim(),
                    },
                  );
                  ref.invalidate(salariesProvider);
                  ref.invalidate(adminSalariesProvider);
                  ref.invalidate(opsSalariesProvider);
                  if (ctx.mounted) Navigator.of(ctx).pop();
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text(e.toString())),
                    );
                  }
                }
              },
              child: const Text('Update'),
            ),
          ],
        );
      },
    );
  }

  void _showAddCustomSlipDialog() {
    final employees = ref.read(employeesProvider).value ?? const <Employee>[];
    String? selectedEmpId = employees.isNotEmpty ? employees.first.id : null;
    final filter = ref.read(salaryFilterProvider);

    final baseCtrl = TextEditingController(text: '0');
    final allowCtrl = TextEditingController(text: '0');
    final bonusCtrl = TextEditingController(text: '0');
    final dedCtrl = TextEditingController(text: '0');
    final notesCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('Add Custom Salary Slip',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: 440,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: selectedEmpId,
                        items: employees
                            .map((e) => DropdownMenuItem(
                                  value: e.id,
                                  child: Text('${e.name} (${e.department ?? e.artistRole})'),
                                ))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setModalState(() {
                              selectedEmpId = val;
                              final found =
                                  employees.firstWhere((e) => e.id == val);
                              baseCtrl.text =
                                  found.baseSalary.toStringAsFixed(0);
                              allowCtrl.text =
                                  found.allowances.toStringAsFixed(0);
                              dedCtrl.text =
                                  found.deductions.toStringAsFixed(0);
                            });
                          }
                        },
                        decoration:
                            const InputDecoration(labelText: 'Select Employee *'),
                      ),
                      12.h,
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: baseCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Base Salary (₹)',
                                isDense: true,
                              ),
                            ),
                          ),
                          8.w,
                          Expanded(
                            child: TextField(
                              controller: allowCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Allowances (₹)',
                                isDense: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                      12.h,
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: bonusCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Bonus (₹)',
                                isDense: true,
                              ),
                            ),
                          ),
                          8.w,
                          Expanded(
                            child: TextField(
                              controller: dedCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Deductions (₹)',
                                isDense: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                      12.h,
                      TextField(
                        controller: notesCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Notes',
                          isDense: true,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (selectedEmpId == null) return;
                    try {
                      await ref.read(salaryServiceProvider).createSalary({
                        'employeeId': selectedEmpId,
                        'month': filter.month,
                        'year': filter.year,
                        'baseSalary':
                            double.tryParse(baseCtrl.text.trim()) ?? 0,
                        'allowances':
                            double.tryParse(allowCtrl.text.trim()) ?? 0,
                        'bonus': double.tryParse(bonusCtrl.text.trim()) ?? 0,
                        'deductions':
                            double.tryParse(dedCtrl.text.trim()) ?? 0,
                        'notes': notesCtrl.text.trim(),
                      });
                      ref.invalidate(salariesProvider);
                      ref.invalidate(adminSalariesProvider);
                      ref.invalidate(opsSalariesProvider);
                      if (ctx.mounted) Navigator.of(ctx).pop();
                    } catch (e) {
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(content: Text(e.toString())),
                        );
                      }
                    }
                  },
                  child: const Text('Create Slip'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showViewPayslipDialog(Salary salary) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.receipt_long, color: Colors.blueAccent),
              8.w,
              const Text('Salary Payslip', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          salary.employeeName,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        2.h,
                        Text(
                          '${salary.department} · ${salary.role}',
                          style: TextStyle(
                              fontSize: 12, color: Theme.of(ctx).hintColor),
                        ),
                        4.h,
                        Text(
                          'Pay Period: ${_monthNames[salary.month - 1]} ${salary.year}',
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  16.h,
                  _buildSlipRow('Base Salary', _formatCurrency(salary.baseSalary)),
                  _buildSlipRow('Allowances', '+ ${_formatCurrency(salary.allowances)}',
                      color: Colors.green),
                  _buildSlipRow('Bonus / Incentive', '+ ${_formatCurrency(salary.bonus)}',
                      color: Colors.green),
                  _buildSlipRow('Deductions / Advances', '- ${_formatCurrency(salary.deductions)}',
                      color: Colors.red),
                  const Divider(height: 24),
                  _buildSlipRow(
                    'Net Payable Amount',
                    _formatCurrency(salary.netAmount),
                    isBold: true,
                    fontSize: 16,
                  ),
                  16.h,
                  if (salary.bankName.isNotEmpty || salary.upiId.isNotEmpty) ...[
                    const Text('Payment Destination',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    6.h,
                    if (salary.bankName.isNotEmpty)
                      Text('Bank: ${salary.bankName} · Acc: ${salary.accountNumber} · IFSC: ${salary.ifscCode}',
                          style: const TextStyle(fontSize: 12)),
                    if (salary.upiId.isNotEmpty)
                      Text('UPI ID: ${salary.upiId}',
                          style: const TextStyle(fontSize: 12)),
                    12.h,
                  ],
                  if (salary.isPaid) ...[
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.green, size: 16),
                          6.w,
                          Expanded(
                            child: Text(
                              'Paid on ${salary.paymentDate != null ? DateFormat('d MMM yyyy').format(salary.paymentDate!) : ''} via ${salary.paymentMethod.toUpperCase()} (${salary.transactionRef})',
                              style: const TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSlipRow(String label, String value,
      {bool isBold = false, Color? color, double fontSize = 13}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(value,
              style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
                  color: color)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final theme = Theme.of(context);
    final isMobile = ResponsiveBuilder.isMobile(context);
    final filter = ref.watch(salaryFilterProvider);
    final salariesAsync = ref.watch(salariesProvider);
    // Watch Timebox payroll preview to get attendance data for admin salary cards.
    final payrollPreviewAsync = ref.watch(payrollPreviewProvider);
    payrollPreviewAsync.whenData((preview) {
      final map = <String, PayrollRow>{};
      for (final row in preview.rows) {
        if (row.crmEmployeeId != null) {
          map[row.crmEmployeeId!] = row;
        }
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _payrollRowByCrmId = map);
      });
    });

    return Scaffold(
      backgroundColor: crm.background,
      body: Padding(
        padding: EdgeInsets.all(isMobile ? 12 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── TOP HEADER ──
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'HR Salary & Payroll Management',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      4.h,
                      Text(
                        'Manage monthly staff compensation for Administrative departments and Operations.',
                        style: TextStyle(color: crm.textSecondary, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                12.w,
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: crm.surface,
                        foregroundColor: crm.textPrimary,
                        side: BorderSide(color: crm.border),
                      ),
                      onPressed: _showAddCustomSlipDialog,
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Add Custom Slip'),
                    ),
                    // ── Timebox Attendance Payroll ──
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: (_isTimeboxGenerating)
                          ? null
                          : () => _generateTimeboxPayroll(filter.month, filter.year),
                      icon: _isTimeboxGenerating
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.timelapse, size: 16),
                      label: Text(
                          _isTimeboxGenerating
                              ? 'Generating…'
                              : 'Attendance Payroll'),
                    ),
                    // ── Classic Full Payroll ──
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: crm.primary,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _isGenerating
                          ? null
                          : () => _generatePayroll(filter.month, filter.year),
                      icon: _isGenerating
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.auto_awesome, size: 16),
                      label: Text(
                          _isGenerating ? 'Generating...' : 'Full Payroll'),
                    ),
                  ],
                ),
              ],
            ),
            16.h,

            // ── PERIOD SELECTOR & SUMMARY STATS ──
            salariesAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (err, _) => Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('Error loading payroll stats: $err'),
              ),
              data: (result) {
                final stats = result.stats;
                return Column(
                  children: [
                    // Month & Year Filter Bar
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: crm.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: crm.border),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_month,
                              size: 18, color: crm.primary),
                          8.w,
                          const Text('Payroll Period:',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 13)),
                          12.w,
                          DropdownButton<int>(
                            value: filter.month,
                            underline: const SizedBox(),
                            items: List.generate(12, (i) => i + 1)
                                .map((m) => DropdownMenuItem(
                                      value: m,
                                      child: Text(_monthNames[m - 1]),
                                    ))
                                .toList(),
                            onChanged: (val) {
                              if (val != null) {
                                ref.read(salaryFilterProvider.notifier).state =
                                    filter.copyWith(month: val);
                              }
                            },
                          ),
                          8.w,
                          DropdownButton<int>(
                            value: filter.year,
                            underline: const SizedBox(),
                            items: [2024, 2025, 2026, 2027]
                                .map((y) => DropdownMenuItem(
                                      value: y,
                                      child: Text('$y'),
                                    ))
                                .toList(),
                            onChanged: (val) {
                              if (val != null) {
                                ref.read(salaryFilterProvider.notifier).state =
                                    filter.copyWith(year: val);
                              }
                            },
                          ),
                          const Spacer(),
                          Text(
                            '${stats.count} Employees in Period',
                            style: TextStyle(
                                fontSize: 12, color: crm.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    12.h,

                    // Stats Cards Row
                    Row(
                      children: [
                        Expanded(
                          child: _buildMetricCard(
                            crm,
                            title: 'Total Monthly Payroll',
                            amount: _formatCurrency(stats.totalNet),
                            subtitle: '${stats.count} slips processed',
                            icon: Icons.payments_outlined,
                            color: crm.primary,
                          ),
                        ),
                        10.w,
                        Expanded(
                          child: _buildMetricCard(
                            crm,
                            title: 'Administrative Staff',
                            amount: _formatCurrency(stats.totalAdministrative),
                            subtitle: 'Sales, IT, HR, Accounts',
                            icon: Icons.business_center_outlined,
                            color: const Color(0xFF6366F1),
                          ),
                        ),
                        10.w,
                        Expanded(
                          child: _buildMetricCard(
                            crm,
                            title: 'Operations Staff',
                            amount: _formatCurrency(stats.totalOperations),
                            subtitle: 'Artists, Fleet, Logistics',
                            icon: Icons.brush_outlined,
                            color: crm.accent,
                          ),
                        ),
                        10.w,
                        Expanded(
                          child: _buildMetricCard(
                            crm,
                            title: 'Disbursed by Accounts',
                            amount: _formatCurrency(stats.totalPaid),
                            subtitle:
                                'Pending: ${_formatCurrency(stats.totalPending)}',
                            icon: Icons.check_circle_outline,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
            16.h,

            // ── TABS: ADMINISTRATIVE vs OPERATIONS vs ALL ──
            Container(
              decoration: BoxDecoration(
                color: crm.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: crm.border),
              ),
              child: TabBar(
                controller: _tabController,
                indicatorColor: crm.primary,
                labelColor: crm.primary,
                unselectedLabelColor: crm.textSecondary,
                tabs: const [
                  Tab(
                    icon: Icon(Icons.business_center_outlined, size: 16),
                    text: 'Administrative Staff',
                  ),
                  Tab(
                    icon: Icon(Icons.brush_outlined, size: 16),
                    text: 'Operations Staff',
                  ),
                  Tab(
                    icon: Icon(Icons.groups_outlined, size: 16),
                    text: 'All Staff',
                  ),
                ],
              ),
            ),
            12.h,

            // ── TIMEBOX ATTENDANCE SUMMARY (admin tab only) ──
            if (_tabController.index == 0)
              payrollPreviewAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (e, st) => const SizedBox.shrink(),
                data: (preview) {
                  if (preview.rows.isEmpty) return const SizedBox.shrink();
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                      border:
                          Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.25)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.timelapse, size: 16, color: Color(0xFF6366F1)),
                        8.w,
                        Expanded(
                          child: Text(
                            'Timebox: ${preview.matched} matched · '
                            '${preview.unmatched} unmatched · '
                            'Net payable: ${NumberFormat.currency(locale: "en_IN", symbol: "₹", decimalDigits: 0).format(preview.totalNetPayable)}',
                            style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF6366F1),
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                        8.w,
                        TextButton(
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF6366F1),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          ),
                          onPressed: () => ref.invalidate(payrollPreviewProvider),
                          child: const Text('Refresh', style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                  );
                },
              ),

            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (val) {
                      ref.read(salaryFilterProvider.notifier).state =
                          ref.read(salaryFilterProvider).copyWith(search: val);
                    },
                    decoration: InputDecoration(
                      hintText: 'Search by employee name, role, department...',
                      prefixIcon: const Icon(Icons.search, size: 18),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                10.w,
                DropdownButton<String>(
                  value: filter.status,
                  underline: const SizedBox(),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All Statuses')),
                    DropdownMenuItem(
                        value: 'approved_by_hr',
                        child: Text('Approved by HR')),
                    DropdownMenuItem(value: 'paid', child: Text('Paid')),
                    DropdownMenuItem(value: 'draft', child: Text('Draft')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      ref.read(salaryFilterProvider.notifier).state =
                          filter.copyWith(status: val);
                    }
                  },
                ),
              ],
            ),
            12.h,

            // ── SALARY RECORDS LIST ──
            Expanded(
              child: salariesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(child: Text('Failed to load salaries: $err')),
                data: (result) {
                  final list = result.salaries;
                  if (list.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.badge_outlined,
                              size: 48, color: crm.textSecondary.withValues(alpha: 0.5)),
                          12.h,
                          Text(
                            'No salary records found for this period.',
                            style: TextStyle(color: crm.textSecondary, fontSize: 14),
                          ),
                          8.h,
                          Wrap(
                            spacing: 8,
                            alignment: WrapAlignment.center,
                            children: [
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF6366F1),
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: () =>
                                    _generateTimeboxPayroll(filter.month, filter.year),
                                icon: const Icon(Icons.timelapse, size: 16),
                                label: const Text('Attendance Payroll (Timebox)'),
                              ),
                              ElevatedButton.icon(
                                onPressed: () =>
                                    _generatePayroll(filter.month, filter.year),
                                icon: const Icon(Icons.auto_awesome, size: 16),
                                label: const Text('Full Payroll (Classic)'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    itemCount: list.length,
                    separatorBuilder: (context, index) => 8.h,
                    itemBuilder: (ctx, idx) {
                      final s = list[idx];
                      final payrollRow = _payrollRowByCrmId[s.employeeId];
                      return _buildSalaryCard(crm, s, payrollRow: payrollRow);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(
    CrmTheme crm, {
    required String title,
    required String amount,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: crm.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          12.w,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title,
                    style: TextStyle(
                        fontSize: 11,
                        color: crm.textSecondary,
                        fontWeight: FontWeight.w500)),
                2.h,
                Text(amount,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                2.h,
                Text(subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 10,
                        color: crm.textSecondary.withValues(alpha: 0.8))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSalaryCard(CrmTheme crm, Salary s, {PayrollRow? payrollRow}) {
    final statusColor = s.isPaid
        ? Colors.green
        : (s.status == 'approved_by_hr' ? Colors.blue : Colors.orange);
    final statusText = s.isPaid
        ? 'Paid'
        : (s.status == 'approved_by_hr' ? 'Approved by HR' : 'Draft');

    // Attendance context from Timebox (admin cards only)
    Color? attColor;
    String? attLabel;
    if (payrollRow != null) {
      final pct = payrollRow.attendancePercent;
      attColor = pct >= 90
          ? crm.success
          : pct >= 75
              ? crm.warning
              : crm.destructive;
      attLabel = '$pct% · ${payrollRow.daysPresent}/${payrollRow.expectedDays}d';
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: crm.border),
      ),
      child: Row(
        children: [
          // Employee Icon / Avatar
          CircleAvatar(
            radius: 20,
            backgroundColor: s.isAdmin
                ? const Color(0xFF6366F1).withValues(alpha: 0.15)
                : crm.accent.withValues(alpha: 0.15),
            child: Icon(
              s.isAdmin ? Icons.business_center : Icons.brush,
              size: 20,
              color: s.isAdmin ? const Color(0xFF6366F1) : crm.accent,
            ),
          ),
          14.w,

          // Name, Category & Department
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      s.employeeName,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    8.w,
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: (s.isAdmin ? const Color(0xFF6366F1) : crm.accent)
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        s.department,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color:
                              s.isAdmin ? const Color(0xFF6366F1) : crm.accent,
                        ),
                      ),
                    ),
                    // Attendance badge from Timebox
                    if (attColor != null && attLabel != null) ...[
                      8.w,
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: attColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: attColor.withValues(alpha: 0.3)),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.timelapse, size: 10, color: attColor),
                          3.w,
                          Text(attLabel,
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: attColor)),
                        ]),
                      ),
                    ],
                  ],
                ),
                3.h,
                Text(
                  '${s.role} · Scheme: ${s.salaryType.replaceAll('_', ' ')}',
                  style: TextStyle(fontSize: 11.5, color: crm.textSecondary),
                ),
              ],
            ),
          ),

          // Breakdown (Base + Allowances + Bonus - Deductions)
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Base: ${_formatCurrency(s.baseSalary)} + Allow: ${_formatCurrency(s.allowances)}',
                  style: TextStyle(fontSize: 11, color: crm.textSecondary),
                ),
                Text(
                  'Bonus: +${_formatCurrency(s.bonus)} · Ded: -${_formatCurrency(s.deductions)}',
                  style: TextStyle(fontSize: 11, color: crm.textSecondary),
                ),
              ],
            ),
          ),


          // Net Payable
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formatCurrency(s.netAmount),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15),
                ),
                2.h,
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          16.w,

          // Actions
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'View Payslip',
                icon: const Icon(Icons.visibility_outlined, size: 18),
                onPressed: () => _showViewPayslipDialog(s),
              ),
              IconButton(
                tooltip: 'Adjust / Edit',
                icon: const Icon(Icons.edit_outlined, size: 18),
                onPressed: () => _showEditSalaryDialog(s),
              ),
              if (s.status == 'draft')
                IconButton(
                  tooltip: 'HR Approve',
                  icon: const Icon(Icons.check_circle_outline,
                      size: 18, color: Colors.blue),
                  onPressed: () async {
                    await ref
                        .read(salaryServiceProvider)
                        .approveSalary(s.id);
                    ref.invalidate(salariesProvider);
                  },
                ),
              if (!s.isPaid)
                IconButton(
                  tooltip: 'Delete Slip',
                  icon: const Icon(Icons.delete_outline,
                      size: 18, color: Colors.red),
                  onPressed: () async {
                    await ref
                        .read(salaryServiceProvider)
                        .deleteSalary(s.id);
                    ref.invalidate(salariesProvider);
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}
