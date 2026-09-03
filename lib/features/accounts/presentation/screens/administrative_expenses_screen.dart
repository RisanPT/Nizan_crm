import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:nizan_crm/core/auth/access_control.dart';
import 'package:nizan_crm/core/auth/app_role.dart';
import 'package:nizan_crm/core/extensions/space_extension.dart';
import 'package:nizan_crm/core/providers/auth_provider.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/core/utils/responsive_builder.dart';
import 'package:nizan_crm/features/accounts/controllers/admin_expense_controller.dart';
import 'package:nizan_crm/features/accounts/data/admin_expense.dart';
import 'package:nizan_crm/core/providers/my_department_provider.dart';
import 'package:nizan_crm/features/accounts/data/expense_category.dart';
import 'package:nizan_crm/features/accounts/presentation/widgets/manage_expense_categories_dialog.dart';
import 'package:nizan_crm/features/accounts/services/expense_category_service.dart';
import 'package:nizan_crm/features/inventory/presentation/widgets/inventory_widgets.dart';
import 'package:nizan_crm/services/employee_service.dart';
import 'package:nizan_crm/core/models/employee.dart';
import 'package:nizan_crm/core/error/errors.dart';

const _departments = [
  'All',
  'CRM',
  'Finance',
  'Accounts',
  'IT',
  'Sales',
  'Marketing',
  'HR',
  'Artist',
  'Fleet',
  'Operations',
  'General',
];

const _categories = [
  'All',
  'office_supplies',
  'rent_utilities',
  'travel_transport',
  'food_beverage',
  'staff_mess',
  'hardware_equipment',
  'marketing_ads',
  'professional_services',
  'maintenance',
  'training',
  'staff_welfare',
  'other',
];

class AdministrativeExpensesScreen extends ConsumerStatefulWidget {
  const AdministrativeExpensesScreen({super.key});

  @override
  ConsumerState<AdministrativeExpensesScreen> createState() =>
      _AdministrativeExpensesScreenState();
}

class _AdministrativeExpensesScreenState
    extends ConsumerState<AdministrativeExpensesScreen> {
  final _searchController = TextEditingController();

  static String _money(double v) =>
      NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0)
          .format(v);
  static String _date(DateTime d) => DateFormat('d MMM yyyy').format(d);

  Color _deptColor(String dept) {
    switch (dept) {
      case 'CRM':
        return const Color(0xFF0284C7);
      case 'Finance':
        return const Color(0xFF16A34A);
      case 'Accounts':
        return const Color(0xFF0D9488);
      case 'IT':
        return const Color(0xFF7C3AED);
      case 'Sales':
        return const Color(0xFFEA580C);
      case 'Marketing':
        return const Color(0xFFDB2777);
      case 'HR':
        return const Color(0xFFCA8A04);
      case 'Operations':
        return const Color(0xFF475569);
      default:
        return const Color(0xFF64748B);
    }
  }

  Color _statusColor(CrmTheme crm, String s) {
    switch (s) {
      case 'approved':
        return crm.success;
      case 'rejected':
        return crm.destructive;
      default:
        return crm.warning;
    }
  }

  IconData _categoryIcon(String category) {
    switch (category) {
      case 'office_supplies':
        return Icons.inventory_2_outlined;
      case 'rent_utilities':
        return Icons.apartment_outlined;
      case 'travel_transport':
        return Icons.directions_car_outlined;
      case 'food_beverage':
      case 'staff_mess':
        return Icons.restaurant_outlined;
      case 'hardware_equipment':
        return Icons.devices_outlined;
      case 'marketing_ads':
        return Icons.campaign_outlined;
      case 'professional_services':
        return Icons.business_center_outlined;
      case 'maintenance':
        return Icons.build_outlined;
      case 'training':
        return Icons.school_outlined;
      case 'staff_welfare':
        return Icons.celebration_outlined;
      default:
        return Icons.receipt_long_outlined;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showAddEditExpenseDialog({AdminExpense? expense}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _AddEditAdminExpenseDialog(
        expense: expense,
        onSaved: () {
          ref.invalidate(adminExpensesProvider);
          ref.invalidate(adminExpenseStatsProvider);
        },
      ),
    );
  }

  void _showReceiptDialog(AdminExpense expense) {
    if (expense.receiptImage.isEmpty) return;
    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Stack(
            alignment: Alignment.topRight,
            children: [
              Container(
                constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
                decoration: BoxDecoration(
                  color: Theme.of(ctx).colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      expense.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Flexible(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          expense.receiptImage,
                          fit: BoxFit.contain,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(32.0),
                                child: CircularProgressIndicator(),
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) =>
                              const Padding(
                            padding: EdgeInsets.all(32.0),
                            child: Text('Unable to load receipt image'),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(ctx).pop(),
                icon: const CircleAvatar(
                  backgroundColor: Colors.black54,
                  child: Icon(Icons.close, color: Colors.white),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _verifyExpense(AdminExpense expense, String status) async {
    try {
      final service = ref.read(adminExpenseServiceProvider);
      await service.verifyAdminExpense(expense.id, status);
      ref.invalidate(adminExpensesProvider);
      ref.invalidate(adminExpenseStatsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Expense marked as $status'),
            backgroundColor: status == 'approved' ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyErrorMessage(e)), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteExpense(AdminExpense expense) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Expense'),
        content: Text('Are you sure you want to delete "${expense.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final service = ref.read(adminExpenseServiceProvider);
        await service.deleteAdminExpense(expense.id);
        ref.invalidate(adminExpensesProvider);
        ref.invalidate(adminExpenseStatsProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Expense deleted successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(friendlyErrorMessage(e)), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final isMobile = ResponsiveBuilder.isMobile(context);
    final filter = ref.watch(adminExpenseFilterProvider);
    final asyncExpenses = ref.watch(adminExpensesProvider);
    final asyncStats = ref.watch(adminExpenseStatsProvider);
    final session = ref.watch(authSessionProvider);
    final access = Access.of(session);
    // Approvers are Accounts/Admin ONLY — this matches the backend, which
    // rejects an approve/reject from anyone else. A department head's role may
    // resolve `payables` through the permission fallback, so we must NOT treat
    // that as "approver" here, or heads would wrongly get the full audit view.
    final isApprover =
        access.role == AppRole.admin || access.role == AppRole.accounts;
    final canVerify = isApprover;
    // Everyone else who can reach this screen (department heads, managers) gets
    // the scoped, submit-only view: their own department only, no approve
    // controls, no cross-department tabs. The backend already restricts their
    // data to their own department.
    final isDeptHeadView = !isApprover && access.isDepartmentHead;
    final myDept = ref.watch(myDepartmentNameProvider);

    void openManageCategories() {
      showDialog(
        context: context,
        builder: (_) => ManageExpenseCategoriesDialog(
          department: isDeptHeadView
              ? myDept
              : (filter.department != 'All' ? filter.department : ''),
          canPickDepartment: !isDeptHeadView,
        ),
      );
    }

    // Category options for the filter — the managed categories of the single
    // department in context, else the default seed set. The active filter value
    // is always kept selectable so the dropdown never trips on a stale value.
    final filterCatDept = isDeptHeadView
        ? myDept
        : (filter.department != 'All' ? filter.department : '');
    final filterCatBase = filterCatDept.isEmpty
        ? _categories.where((c) => c != 'All').toList()
        : (ref.watch(expenseCategoriesProvider(filterCatDept)).value ??
                const <ExpenseCategory>[])
            .map((c) => c.name)
            .toList();
    final filterCatOptions = <String>[
      'All',
      ...{
        ...filterCatBase,
        if (filter.category != 'All' && filter.category.isNotEmpty)
          filter.category,
      },
    ];

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(adminExpensesProvider);
          ref.invalidate(adminExpenseStatsProvider);
        },
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            isMobile ? 16 : 24,
            16,
            isMobile ? 16 : 24,
            32,
          ),
          children: [
            // ── Header ──
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isDeptHeadView
                            ? 'Department Expenses'
                            : 'Administrative Expenses',
                        style: TextStyle(
                          fontSize: isMobile ? 22 : 28,
                          fontWeight: FontWeight.w800,
                          color: crm.textPrimary,
                          letterSpacing: -0.5,
                        ),
                      ),
                      4.h,
                      Text(
                        isDeptHeadView
                            ? 'Submit your department\'s expenses for Accounts to approve. A pending expense is not paid until Accounts approves it.'
                            : 'Manage & audit operating expenses, overheads, and departmental spend across CRM, Finance, Accounts, IT, Sales, Marketing, HR, and Operations.',
                        style: TextStyle(
                          fontSize: 13,
                          color: crm.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isMobile) ...[
                  const SizedBox(width: 16),
                  OutlinedButton.icon(
                    onPressed: openManageCategories,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: crm.primary,
                      side: BorderSide(color: crm.primary.withValues(alpha: 0.5)),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.category_outlined, size: 18),
                    label: const Text(
                      'Categories',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    onPressed: () => _showAddEditExpenseDialog(),
                    style: FilledButton.styleFrom(
                      backgroundColor: crm.primary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.add, size: 20),
                    label: const Text(
                      'Record Expense',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ],
            ),
            if (isMobile) ...[
              12.h,
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _showAddEditExpenseDialog(),
                      style: FilledButton.styleFrom(
                        backgroundColor: crm.primary,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Record Expense'),
                    ),
                  ),
                  10.w,
                  OutlinedButton.icon(
                    onPressed: openManageCategories,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: crm.primary,
                      side: BorderSide(color: crm.primary.withValues(alpha: 0.5)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.category_outlined, size: 18),
                    label: const Text('Categories'),
                  ),
                ],
              ),
            ],

            16.h,

            // ── KPI Summary Cards ──
            asyncStats.when(
              loading: () => const SizedBox(
                height: 80,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, _) => const SizedBox.shrink(),
              data: (stats) => InvStatGrid(
                isMobile: isMobile,
                stats: [
                  InvStat(
                    _money(stats.totalAmount),
                    'Total Spend',
                    Icons.account_balance_wallet_outlined,
                    crm.primary,
                  ),
                  InvStat(
                    _money(stats.thisMonthAmount),
                    'This Month',
                    Icons.calendar_month_outlined,
                    crm.accent,
                  ),
                  InvStat(
                    '${_money(stats.pendingAmount)} (${stats.pendingCount})',
                    'Pending Audit',
                    Icons.hourglass_bottom_outlined,
                    crm.warning,
                  ),
                  InvStat(
                    _money(stats.approvedAmount),
                    'Approved',
                    Icons.check_circle_outline,
                    crm.success,
                  ),
                ],
              ),
            ),

            20.h,

            // ── Department Filter Tabs ── (hidden for a department head — they
            // only ever see their own department's expenses).
            if (!isDeptHeadView) ...[
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _departments.map((dept) {
                    final isSelected = filter.department == dept;
                    final color = dept == 'All' ? crm.primary : _deptColor(dept);
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        selected: isSelected,
                        label: Text(
                          dept,
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected ? Colors.white : crm.textPrimary,
                            fontSize: 13,
                          ),
                        ),
                        selectedColor: color,
                        backgroundColor: crm.surface,
                        side: BorderSide(
                          color: isSelected ? color : crm.border,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        onSelected: (val) {
                          ref.read(adminExpenseFilterProvider.notifier).state =
                              filter.copyWith(department: dept);
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
              14.h,
            ],

            // ── Secondary Filters (Status, Search, Date) ──
            Wrap(
              spacing: 12,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // Status chips
                Wrap(
                  spacing: 6,
                  children: ['all', 'pending', 'approved', 'rejected'].map((s) {
                    final isSel = filter.status == s;
                    final label = s == 'all'
                        ? 'All Status'
                        : s[0].toUpperCase() + s.substring(1);
                    return ChoiceChip(
                      label: Text(
                        label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                          color: isSel ? Colors.white : crm.textSecondary,
                        ),
                      ),
                      selected: isSel,
                      selectedColor: _statusColor(crm, s),
                      backgroundColor: crm.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      side: BorderSide(color: isSel ? Colors.transparent : crm.border),
                      onSelected: (_) {
                        ref.read(adminExpenseFilterProvider.notifier).state =
                            filter.copyWith(status: s);
                      },
                    );
                  }).toList(),
                ),

                // Category filter
                DropdownButtonHideUnderline(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: crm.surface,
                      border: Border.all(color: crm.border),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButton<String>(
                      value: filter.category,
                      dropdownColor: crm.surface,
                      isDense: true,
                      icon: Icon(Icons.arrow_drop_down, color: crm.textSecondary),
                      style: TextStyle(fontSize: 13, color: crm.textPrimary),
                      items: filterCatOptions.map((c) {
                        final label =
                            c == 'All' ? 'All Categories' : prettyCategory(c);
                        return DropdownMenuItem(
                          value: c,
                          child: Text(label),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          ref.read(adminExpenseFilterProvider.notifier).state =
                              filter.copyWith(category: val);
                        }
                      },
                    ),
                  ),
                ),

                // Search field
                SizedBox(
                  width: isMobile ? double.infinity : 220,
                  height: 38,
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) {
                      ref.read(adminExpenseFilterProvider.notifier).state =
                          filter.copyWith(search: v);
                    },
                    decoration: InputDecoration(
                      hintText: 'Search expense...',
                      hintStyle: TextStyle(fontSize: 13, color: crm.textSecondary),
                      prefixIcon: Icon(Icons.search, size: 18, color: crm.textSecondary),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                      filled: true,
                      fillColor: crm.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: crm.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: crm.border),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            16.h,

            // ── Expenses List ──
            asyncExpenses.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    'Failed to load expenses: $e',
                    style: TextStyle(color: crm.textSecondary),
                  ),
                ),
              ),
              data: (expenses) {
                if (expenses.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
                    decoration: BoxDecoration(
                      color: crm.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: crm.border),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.receipt_long_outlined,
                          size: 48,
                          color: crm.textSecondary.withValues(alpha: 0.5),
                        ),
                        12.h,
                        Text(
                          'No administrative expenses found',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: crm.textPrimary,
                          ),
                        ),
                        4.h,
                        Text(
                          'Click "Record Expense" above to add office or departmental expenses.',
                          style: TextStyle(fontSize: 13, color: crm.textSecondary),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: expenses.length,
                  separatorBuilder: (_, _) => 10.h,
                  itemBuilder: (ctx, idx) {
                    final exp = expenses[idx];
                    final deptColor = _deptColor(exp.department);
                    final statusColor = _statusColor(crm, exp.status);

                    return Container(
                      decoration: BoxDecoration(
                        color: crm.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: crm.border),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Category Icon Avatar
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: deptColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  _categoryIcon(exp.category),
                                  color: deptColor,
                                  size: 22,
                                ),
                              ),
                              12.w,
                              // Title & Details
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            exp.title,
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700,
                                              color: crm.textPrimary,
                                            ),
                                          ),
                                        ),
                                        8.w,
                                        // Department Pill
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: deptColor.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(
                                              color: deptColor.withValues(alpha: 0.4),
                                            ),
                                          ),
                                          child: Text(
                                            exp.department,
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: deptColor,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    4.h,
                                    Wrap(
                                      spacing: 12,
                                      runSpacing: 4,
                                      children: [
                                        if (exp.source == 'hra')
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: crm.primary.withValues(alpha: 0.12),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text('HRA',
                                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: crm.primary)),
                                          ),
                                        Text(
                                          exp.headLabel,
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            color: crm.textSecondary,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        Text('•', style: TextStyle(color: crm.textSecondary)),
                                        Text(
                                          _date(exp.date),
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            color: crm.textSecondary,
                                          ),
                                        ),
                                        if (exp.paidByName.isNotEmpty || exp.paidBy != null) ...[
                                          Text('•', style: TextStyle(color: crm.textSecondary)),
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.person_outline, size: 14, color: crm.textSecondary),
                                              4.w,
                                              Text(
                                                exp.paidBy?.name ?? exp.paidByName,
                                                style: TextStyle(
                                                  fontSize: 12.5,
                                                  color: crm.textSecondary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                        if (exp.paymentMethod.isNotEmpty) ...[
                                          Text('•', style: TextStyle(color: crm.textSecondary)),
                                          Text(
                                            exp.paymentMethodLabel,
                                            style: TextStyle(
                                              fontSize: 12.5,
                                              color: crm.textSecondary,
                                            ),
                                          ),
                                        ],
                                        if (exp.vendor.isNotEmpty) ...[
                                          Text('•', style: TextStyle(color: crm.textSecondary)),
                                          Row(mainAxisSize: MainAxisSize.min, children: [
                                            Icon(Icons.storefront_outlined, size: 14, color: crm.textSecondary),
                                            4.w,
                                            Text(exp.vendor, style: TextStyle(fontSize: 12.5, color: crm.textSecondary)),
                                          ]),
                                        ],
                                        if (exp.costTag.isNotEmpty) ...[
                                          Text('•', style: TextStyle(color: crm.textSecondary)),
                                          Row(mainAxisSize: MainAxisSize.min, children: [
                                            Icon(Icons.sell_outlined, size: 14, color: crm.accent),
                                            4.w,
                                            Text(exp.costTag, style: TextStyle(fontSize: 12.5, color: crm.accent, fontWeight: FontWeight.w600)),
                                          ]),
                                        ],
                                        if (exp.isRecurring) ...[
                                          Text('•', style: TextStyle(color: crm.textSecondary)),
                                          Row(mainAxisSize: MainAxisSize.min, children: [
                                            Icon(Icons.repeat_rounded, size: 14, color: crm.primary),
                                            4.w,
                                            Text('Recurring', style: TextStyle(fontSize: 12.5, color: crm.primary, fontWeight: FontWeight.w600)),
                                          ]),
                                        ],
                                        if (exp.gstType == 'rcm') ...[
                                          Text('•', style: TextStyle(color: crm.textSecondary)),
                                          Text('GST · RCM', style: TextStyle(fontSize: 12.5, color: crm.warning, fontWeight: FontWeight.w600)),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              // Amount & Status
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    _money(exp.amount),
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: crm.textPrimary,
                                    ),
                                  ),
                                  4.h,
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: statusColor.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      exp.status.toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w800,
                                        color: statusColor,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),

                          if (exp.notes.isNotEmpty) ...[
                            8.h,
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Theme.of(context).scaffoldBackgroundColor,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                exp.notes,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: crm.textSecondary,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          ],

                          // Action bar (Receipt, Verify, Edit, Delete)
                          8.h,
                          const Divider(height: 1),
                          8.h,
                          Row(
                            children: [
                              if (exp.receiptImage.isNotEmpty)
                                TextButton.icon(
                                  onPressed: () => _showReceiptDialog(exp),
                                  icon: const Icon(Icons.receipt, size: 16),
                                  label: const Text('View Bill / Receipt', style: TextStyle(fontSize: 12)),
                                )
                              else
                                Text(
                                  'No bill attached',
                                  style: TextStyle(fontSize: 12, color: crm.textSecondary),
                                ),
                              const Spacer(),
                              // Quick Approve / Reject for accounts / full access
                              if (canVerify && exp.isPending) ...[
                                OutlinedButton.icon(
                                  onPressed: () => _verifyExpense(exp, 'rejected'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: crm.destructive,
                                    side: BorderSide(color: crm.destructive.withValues(alpha: 0.4)),
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  icon: const Icon(Icons.close, size: 14),
                                  label: const Text('Reject', style: TextStyle(fontSize: 11)),
                                ),
                                8.w,
                                FilledButton.icon(
                                  onPressed: () => _verifyExpense(exp, 'approved'),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: crm.success,
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  icon: const Icon(Icons.check, size: 14),
                                  label: const Text('Approve', style: TextStyle(fontSize: 11)),
                                ),
                                8.w,
                              ],
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 18),
                                tooltip: 'Edit',
                                onPressed: () => _showAddEditExpenseDialog(expense: exp),
                              ),
                              IconButton(
                                icon: Icon(Icons.delete_outline, size: 18, color: crm.destructive),
                                tooltip: 'Delete',
                                onPressed: () => _deleteExpense(exp),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _AddEditAdminExpenseDialog extends ConsumerStatefulWidget {
  final AdminExpense? expense;
  final VoidCallback onSaved;

  const _AddEditAdminExpenseDialog({this.expense, required this.onSaved});

  @override
  ConsumerState<_AddEditAdminExpenseDialog> createState() =>
      _AddEditAdminExpenseDialogState();
}

class _AddEditAdminExpenseDialogState
    extends ConsumerState<_AddEditAdminExpenseDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleCtrl;
  late TextEditingController _amountCtrl;
  late TextEditingController _notesCtrl;
  late TextEditingController _invoiceCtrl;
  late TextEditingController _receiptCtrl;
  late TextEditingController _paidByNameCtrl;
  late TextEditingController _vendorCtrl;
  late TextEditingController _costTagCtrl;
  late TextEditingController _gstCtrl;

  late String _selectedDept;
  late String _selectedCategory;
  late String _selectedPaymentMethod;
  late DateTime _selectedDate;
  String? _selectedEmployeeId;
  String? _selectedHead;
  bool _isRecurring = false;
  String _gstType = 'none';
  bool _isSubmitting = false;
  // A department head (non-approver) may only file for their OWN department, so
  // the department field is locked to it. Accounts/Admin can pick any.
  bool _lockDept = false;

  @override
  void initState() {
    super.initState();
    final e = widget.expense;

    _titleCtrl = TextEditingController(text: e?.title ?? '');
    _amountCtrl = TextEditingController(
      text: e != null ? e.amount.toStringAsFixed(0) : '',
    );
    _notesCtrl = TextEditingController(text: e?.notes ?? '');
    _invoiceCtrl = TextEditingController(text: e?.invoiceNumber ?? '');
    _receiptCtrl = TextEditingController(text: e?.receiptImage ?? '');
    _paidByNameCtrl = TextEditingController(text: e?.paidByName ?? '');
    _vendorCtrl = TextEditingController(text: e?.vendor ?? '');
    _costTagCtrl = TextEditingController(text: e?.costTag ?? '');
    _gstCtrl = TextEditingController(
      text: (e != null && e.gstAmount > 0) ? e.gstAmount.toStringAsFixed(0) : '',
    );

    _selectedDept = e?.department ?? 'General';
    _selectedCategory = e?.category ?? 'office_supplies';
    _selectedPaymentMethod = e?.paymentMethod ?? 'bank_transfer';
    _selectedDate = e?.date ?? DateTime.now();
    _selectedEmployeeId = e?.paidBy?.id;
    _selectedHead = (e?.expenseHead.isNotEmpty ?? false) ? e!.expenseHead : null;
    _isRecurring = e?.isRecurring ?? false;
    _gstType = e?.gstType ?? 'none';
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _amountCtrl.dispose();
    _notesCtrl.dispose();
    _invoiceCtrl.dispose();
    _receiptCtrl.dispose();
    _paidByNameCtrl.dispose();
    _vendorCtrl.dispose();
    _costTagCtrl.dispose();
    _gstCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final service = ref.read(adminExpenseServiceProvider);
      final payload = {
        'title': _titleCtrl.text.trim(),
        'department': _selectedDept,
        'category': _selectedCategory,
        'expenseHead': _selectedHead ?? '',
        'vendor': _vendorCtrl.text.trim(),
        'costTag': _costTagCtrl.text.trim(),
        'isRecurring': _isRecurring,
        'gstType': _gstType,
        'gstAmount': double.tryParse(_gstCtrl.text.trim()) ?? 0,
        'amount': double.tryParse(_amountCtrl.text.trim()) ?? 0,
        'date': _selectedDate.toIso8601String(),
        'paymentMethod': _selectedPaymentMethod,
        if (_selectedEmployeeId != null && _selectedEmployeeId!.isNotEmpty)
          'paidBy': _selectedEmployeeId,
        'paidByName': _paidByNameCtrl.text.trim(),
        'receiptImage': _receiptCtrl.text.trim(),
        'invoiceNumber': _invoiceCtrl.text.trim(),
        'notes': _notesCtrl.text.trim(),
      };

      if (widget.expense == null) {
        await service.createAdminExpense(payload);
      } else {
        await service.updateAdminExpense(widget.expense!.id, payload);
      }

      widget.onSaved();
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.expense == null
                  ? 'Expense recorded successfully'
                  : 'Expense updated successfully',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyErrorMessage(e)), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final employeesAsync = ref.watch(employeesProvider);

    // Resolve whether the department must be locked to the signed-in user's own
    // department. Approvers (Accounts/Admin) can file for any department; a
    // department head is forced to their own by the backend. We take the
    // department NAME from the session, and — since an older session may not
    // carry `departmentName` yet — fall back to resolving it from the
    // department id against the loaded departments list.
    final session = ref.watch(authSessionProvider);
    final role = session?.role ?? '';
    final approver = role == 'admin' || role == 'accounts';
    // Resolved from session → departments → Employee record (see provider).
    final headDept = ref.watch(myDepartmentNameProvider);
    _lockDept = !approver && headDept.isNotEmpty;
    // When locked, the selection is always the head's own department (this also
    // corrects it once the department name finishes resolving).
    if (_lockDept && _selectedDept != headDept) {
      _selectedDept = headDept;
    }

    // Categories are managed per department — load the ones for the department
    // this expense is being filed under.
    final categoryValues = _selectedDept.isEmpty
        ? const <String>[]
        : (ref.watch(expenseCategoriesProvider(_selectedDept)).value ??
                const <ExpenseCategory>[])
            .map((c) => c.name)
            .toList();

    return Dialog(
      backgroundColor: crm.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 540,
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.expense == null
                          ? (_lockDept
                              ? 'Submit Department Expense'
                              : 'Record Administrative Expense')
                          : 'Edit Expense',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: crm.textPrimary,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                16.h,

                // Title
                TextFormField(
                  controller: _titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Expense Title *',
                    hintText: 'e.g. Office Stationery, Client Meeting Lunch, Server Hosting',
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Please enter a title' : null,
                ),
                12.h,

                // A department head whose department couldn't be resolved from
                // any source — warn them, since the backend will also reject the
                // submission until an admin assigns their department.
                if (!approver && !_lockDept) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: crm.warning.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: crm.warning.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: crm.warning, size: 18),
                        8.w,
                        Expanded(
                          child: Text(
                            'Your department isn\'t set on your account, so it can\'t be filled in automatically. Ask an admin to set your department.',
                            style: TextStyle(
                                fontSize: 12, color: crm.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  ),
                  12.h,
                ],

                // Department & Category
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        // Key on the value+lock so the field rebuilds with the
                        // correct selection once the head's department resolves.
                        key: ValueKey('dept-$_selectedDept-$_lockDept'),
                        initialValue: _selectedDept,
                        decoration: InputDecoration(
                          labelText: 'Department *',
                          helperText:
                              _lockDept ? 'Your department' : null,
                        ),
                        // Always include the currently selected department so a
                        // head's own department (or a custom one) is a valid item.
                        items: <String>{
                          ..._departments.where((d) => d != 'All'),
                          if (_selectedDept.isNotEmpty) _selectedDept,
                        }.map((dept) {
                          return DropdownMenuItem(value: dept, child: Text(dept));
                        }).toList(),
                        // Locked for department heads — they can only file for
                        // their own department.
                        onChanged: _lockDept
                            ? null
                            : (val) {
                                if (val != null) {
                                  setState(() => _selectedDept = val);
                                }
                              },
                      ),
                    ),
                    12.w,
                    Expanded(
                      child: Builder(
                        builder: (context) {
                          // Always keep the current selection selectable, even
                          // if it isn't in the loaded list (legacy value).
                          final options = <String>{
                            ...categoryValues,
                            if (_selectedCategory.isNotEmpty) _selectedCategory,
                          }.toList();
                          return DropdownButtonFormField<String>(
                            key: ValueKey(
                                'cat-$_selectedDept-${options.length}'),
                            initialValue: options.contains(_selectedCategory)
                                ? _selectedCategory
                                : null,
                            isExpanded: true,
                            decoration:
                                const InputDecoration(labelText: 'Category *'),
                            items: options
                                .map((v) => DropdownMenuItem(
                                      value: v,
                                      child: Text(prettyCategory(v)),
                                    ))
                                .toList(),
                            validator: (v) => (v == null || v.isEmpty)
                                ? 'Select a category'
                                : null,
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _selectedCategory = val);
                              }
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
                12.h,

                // Expense Head — controlled ledger (doc: "no free-text heads").
                DropdownButtonFormField<String>(
                  initialValue: _selectedHead,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Expense Head *'),
                  items: kExpenseHeads
                      .map((h) => DropdownMenuItem(
                            value: h.code,
                            child: Text(h.display, overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Select an expense head' : null,
                  onChanged: (val) => setState(() {
                    _selectedHead = val;
                    final h = expenseHeadByCode(val);
                    if (h != null && !h.recurring) _isRecurring = false;
                    if (h != null && h.foreign && _gstType == 'none') _gstType = 'rcm';
                  }),
                ),
                12.h,

                // Bride / event cost tag — mandatory for job-linked heads.
                if (expenseHeadByCode(_selectedHead)?.jobLinked ?? false) ...[
                  TextFormField(
                    controller: _costTagCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Bride / Event (Cost Tag) *',
                      hintText: 'e.g. Meghna Wedding — enables per-event costing',
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty)
                            ? 'Cost tag is required for job-linked heads'
                            : null,
                  ),
                  12.h,
                ],

                // Vendor / Payee — who the money was paid to (mandatory).
                TextFormField(
                  controller: _vendorCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Vendor / Payee *',
                    hintText: 'Shop / agency / person paid',
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Vendor / payee is required'
                      : null,
                ),
                12.h,

                // Recurring (for eligible heads) + tax / GST treatment.
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (expenseHeadByCode(_selectedHead)?.recurring ?? false)
                      Expanded(
                        child: CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          dense: true,
                          title: const Text('Recurring monthly', style: TextStyle(fontSize: 13)),
                          value: _isRecurring,
                          onChanged: (v) => setState(() => _isRecurring = v ?? false),
                        ),
                      ),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _gstType,
                        decoration: const InputDecoration(labelText: 'Tax / GST'),
                        items: const [
                          DropdownMenuItem(value: 'none', child: Text('No GST')),
                          DropdownMenuItem(value: 'gst', child: Text('GST')),
                          DropdownMenuItem(value: 'rcm', child: Text('GST · RCM (import)')),
                        ],
                        onChanged: (v) => setState(() => _gstType = v ?? 'none'),
                      ),
                    ),
                    if (_gstType != 'none') ...[
                      12.w,
                      Expanded(
                        child: TextFormField(
                          controller: _gstCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'GST Amt (₹)'),
                        ),
                      ),
                    ],
                  ],
                ),
                12.h,

                // Amount & Date
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _amountCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Amount (₹) *',
                          prefixText: '₹ ',
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Enter amount';
                          if (double.tryParse(v.trim()) == null) return 'Invalid number';
                          return null;
                        },
                      ),
                    ),
                    12.w,
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _selectedDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030),
                          );
                          if (picked != null) {
                            setState(() => _selectedDate = picked);
                          }
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Date *',
                            suffixIcon: Icon(Icons.calendar_today, size: 18),
                          ),
                          child: Text(DateFormat('d MMM yyyy').format(_selectedDate)),
                        ),
                      ),
                    ),
                  ],
                ),
                12.h,

                // Paid By — Staff Member (dropdown) *or* Vendor name (text) — mandatory
                employeesAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (_, _) => TextFormField(
                    controller: _paidByNameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Vendor / Payee Name *',
                      hintText: 'Enter vendor or staff name',
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty)
                            ? 'Vendor / payee name is required'
                            : null,
                  ),
                  data: (staffList) {
                    return DropdownButtonFormField<String?>(
                      initialValue: _selectedEmployeeId,
                      decoration: const InputDecoration(
                        labelText: 'Responsible Staff Member *',
                      ),
                      validator: (_) {
                        // Pass if a staff member is chosen OR a vendor name is typed
                        if ((_selectedEmployeeId != null && _selectedEmployeeId!.isNotEmpty) ||
                            _paidByNameCtrl.text.trim().isNotEmpty) {
                          return null;
                        }
                        return 'Select a staff member or enter a vendor name below';
                      },
                      items: [
                        const DropdownMenuItem(value: null, child: Text('None / Company Direct')),
                        ...staffList
                            .where((emp) => emp.isActive || emp.id == _selectedEmployeeId)
                            .map((emp) => DropdownMenuItem(
                              value: emp.id,
                              child: Text('${emp.name} (${emp.department ?? emp.role ?? 'Staff'})'),
                            )),
                      ],
                      onChanged: (val) => setState(() => _selectedEmployeeId = val),
                    );
                  },
                ),
                8.h,
                // Vendor / Payee free-text — required when no staff member is selected
                TextFormField(
                  controller: _paidByNameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Vendor / Payee Name',
                    hintText: 'If not a staff member, enter vendor name here',
                    prefixIcon: Icon(Icons.store_outlined, size: 18),
                  ),
                ),
                12.h,

                // Payment Method & Invoice Number
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedPaymentMethod,
                        decoration: const InputDecoration(labelText: 'Payment Method'),
                        items: const [
                          DropdownMenuItem(value: 'bank_transfer', child: Text('Bank Transfer')),
                          DropdownMenuItem(value: 'upi', child: Text('UPI / GPay')),
                          DropdownMenuItem(value: 'credit_card', child: Text('Corporate Card')),
                          DropdownMenuItem(value: 'debit_card', child: Text('Debit Card')),
                          DropdownMenuItem(value: 'cash', child: Text('Cash')),
                          DropdownMenuItem(value: 'petty_cash', child: Text('Petty Cash')),
                          DropdownMenuItem(value: 'other', child: Text('Other')),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedPaymentMethod = val);
                        },
                      ),
                    ),
                    12.w,
                    Expanded(
                      child: TextFormField(
                        controller: _invoiceCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Invoice / Bill # *',
                          hintText: 'Required',
                        ),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty)
                                ? 'Invoice / bill number is required'
                                : null,
                      ),
                    ),
                  ],
                ),
                12.h,

                // Receipt Image URL
                TextFormField(
                  controller: _receiptCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Receipt / Bill URL *',
                    hintText: 'https://...',
                    prefixIcon: Icon(Icons.link, size: 18),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty)
                          ? 'Bill attachment is required — upload and paste the URL'
                          : null,
                ),
                12.h,

                // Notes
                TextFormField(
                  controller: _notesCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Notes / Remarks',
                    hintText: 'Additional context regarding this expenditure...',
                  ),
                ),

                20.h,

                // Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    12.w,
                    FilledButton(
                      onPressed: _isSubmitting ? null : _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: crm.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(widget.expense == null ? 'Save Expense' : 'Update Expense'),
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
