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
import 'package:nizan_crm/features/inventory/presentation/widgets/inventory_widgets.dart';
import 'package:nizan_crm/services/employee_service.dart';

const _departments = [
  'All',
  'CRM',
  'Finance',
  'Accounts',
  'IT',
  'Sales',
  'Marketing',
  'HR',
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
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
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
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
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
    final canVerify = access.role == AppRole.admin ||
        access.role == AppRole.accounts ||
        access.canSeeSub('payables.admin_expenses');

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
                        'Administrative Expenses',
                        style: TextStyle(
                          fontSize: isMobile ? 22 : 28,
                          fontWeight: FontWeight.w800,
                          color: crm.textPrimary,
                          letterSpacing: -0.5,
                        ),
                      ),
                      4.h,
                      Text(
                        'Manage & audit operating expenses, overheads, and departmental spend across CRM, Finance, Accounts, IT, Sales, Marketing, HR, and Operations.',
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
              SizedBox(
                width: double.infinity,
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

            // ── Department Filter Tabs ──
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
                      items: _categories.map((c) {
                        String label = c == 'All'
                            ? 'All Categories'
                            : c.split('_').map((w) => w[0].toUpperCase() + w.substring(1)).join(' ');
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
                                        Text(
                                          exp.categoryLabel,
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

  late String _selectedDept;
  late String _selectedCategory;
  late String _selectedPaymentMethod;
  late DateTime _selectedDate;
  String? _selectedEmployeeId;
  bool _isSubmitting = false;

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

    _selectedDept = e?.department ?? 'General';
    _selectedCategory = e?.category ?? 'office_supplies';
    _selectedPaymentMethod = e?.paymentMethod ?? 'bank_transfer';
    _selectedDate = e?.date ?? DateTime.now();
    _selectedEmployeeId = e?.paidBy?.id;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _amountCtrl.dispose();
    _notesCtrl.dispose();
    _invoiceCtrl.dispose();
    _receiptCtrl.dispose();
    _paidByNameCtrl.dispose();
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
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
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
                          ? 'Record Administrative Expense'
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

                // Department & Category
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedDept,
                        decoration: const InputDecoration(labelText: 'Department *'),
                        items: _departments.where((d) => d != 'All').map((dept) {
                          return DropdownMenuItem(value: dept, child: Text(dept));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedDept = val);
                        },
                      ),
                    ),
                    12.w,
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedCategory,
                        decoration: const InputDecoration(labelText: 'Category *'),
                        items: _categories.where((c) => c != 'All').map((cat) {
                          final label = cat
                              .split('_')
                              .map((w) => w[0].toUpperCase() + w.substring(1))
                              .join(' ');
                          return DropdownMenuItem(value: cat, child: Text(label));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedCategory = val);
                        },
                      ),
                    ),
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
                        ...staffList.map((emp) => DropdownMenuItem(
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
