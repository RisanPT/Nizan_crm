import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:nizan_crm/core/extensions/space_extension.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/core/utils/responsive_builder.dart';
import 'package:nizan_crm/features/accounts/controllers/subscription_controller.dart';
import 'package:nizan_crm/features/accounts/data/subscription.dart';
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

class AdministrativeSubscriptionsScreen extends ConsumerStatefulWidget {
  const AdministrativeSubscriptionsScreen({super.key});

  @override
  ConsumerState<AdministrativeSubscriptionsScreen> createState() =>
      _AdministrativeSubscriptionsScreenState();
}

class _AdministrativeSubscriptionsScreenState
    extends ConsumerState<AdministrativeSubscriptionsScreen> {
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
      case 'active':
        return crm.success;
      case 'paused':
        return crm.warning;
      case 'expired':
      case 'cancelled':
        return crm.destructive;
      default:
        return crm.textSecondary;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showAddEditSubscriptionDialog({Subscription? subscription}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _AddEditSubscriptionDialog(
        subscription: subscription,
        onSaved: () {
          ref.invalidate(subscriptionsProvider);
          ref.invalidate(subscriptionStatsProvider);
        },
      ),
    );
  }

  Future<void> _deleteSubscription(Subscription sub) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Subscription'),
        content: Text('Are you sure you want to remove "${sub.name}"?'),
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
        final service = ref.read(subscriptionServiceProvider);
        await service.deleteSubscription(sub.id);
        ref.invalidate(subscriptionsProvider);
        ref.invalidate(subscriptionStatsProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Subscription deleted successfully')),
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
    final filter = ref.watch(subscriptionFilterProvider);
    final asyncSubs = ref.watch(subscriptionsProvider);
    final asyncStats = ref.watch(subscriptionStatsProvider);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(subscriptionsProvider);
          ref.invalidate(subscriptionStatsProvider);
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
                        'Software & Subscriptions',
                        style: TextStyle(
                          fontSize: isMobile ? 22 : 28,
                          fontWeight: FontWeight.w800,
                          color: crm.textPrimary,
                          letterSpacing: -0.5,
                        ),
                      ),
                      4.h,
                      Text(
                        'Track active software licenses, recurring tools, SaaS billing, and renewal timelines across all business units.',
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
                    onPressed: () => _showAddEditSubscriptionDialog(),
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
                      'Add Subscription',
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
                  onPressed: () => _showAddEditSubscriptionDialog(),
                  style: FilledButton.styleFrom(
                    backgroundColor: crm.primary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Subscription'),
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
                    stats.activeCount.toString(),
                    'Active Tools',
                    Icons.apps_outlined,
                    crm.primary,
                  ),
                  InvStat(
                    _money(stats.monthlyRunRate),
                    'Monthly Run-Rate',
                    Icons.trending_up_outlined,
                    crm.accent,
                  ),
                  InvStat(
                    _money(stats.annualizedCost),
                    'Annualized Spend',
                    Icons.account_balance_outlined,
                    crm.success,
                  ),
                  InvStat(
                    stats.upcomingRenewalsCount.toString(),
                    'Renewals in 30 Days',
                    Icons.notification_important_outlined,
                    stats.upcomingRenewalsCount > 0 ? crm.warning : crm.textSecondary,
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
                        ref.read(subscriptionFilterProvider.notifier).state =
                            filter.copyWith(department: dept);
                      },
                    ),
                  );
                }).toList(),
              ),
            ),

            14.h,

            // ── Secondary Filters (Status, Search) ──
            Wrap(
              spacing: 12,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // Status chips
                Wrap(
                  spacing: 6,
                  children: ['all', 'active', 'paused', 'cancelled', 'expired'].map((s) {
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
                        ref.read(subscriptionFilterProvider.notifier).state =
                            filter.copyWith(status: s);
                      },
                    );
                  }).toList(),
                ),

                // Search field
                SizedBox(
                  width: isMobile ? double.infinity : 240,
                  height: 38,
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) {
                      ref.read(subscriptionFilterProvider.notifier).state =
                          filter.copyWith(search: v);
                    },
                    decoration: InputDecoration(
                      hintText: 'Search tool or license...',
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

            // ── Subscriptions List ──
            asyncSubs.when(
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
                    'Failed to load subscriptions: $e',
                    style: TextStyle(color: crm.textSecondary),
                  ),
                ),
              ),
              data: (subs) {
                if (subs.isEmpty) {
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
                          Icons.cloud_sync_outlined,
                          size: 48,
                          color: crm.textSecondary.withValues(alpha: 0.5),
                        ),
                        12.h,
                        Text(
                          'No software subscriptions found',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: crm.textPrimary,
                          ),
                        ),
                        4.h,
                        Text(
                          'Click "Add Subscription" above to register software tools and licenses.',
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
                  itemCount: subs.length,
                  separatorBuilder: (_, _) => 10.h,
                  itemBuilder: (ctx, idx) {
                    final sub = subs[idx];
                    final deptColor = _deptColor(sub.department);
                    final statusColor = _statusColor(crm, sub.status);

                    return Container(
                      decoration: BoxDecoration(
                        color: crm.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: sub.isRenewingSoon
                              ? crm.warning.withValues(alpha: 0.6)
                              : crm.border,
                          width: sub.isRenewingSoon ? 1.5 : 1,
                        ),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Tool Avatar Icon
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: deptColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.cloud_outlined,
                                  color: deptColor,
                                  size: 24,
                                ),
                              ),
                              12.w,
                              // Name & Info
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            sub.name,
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700,
                                              color: crm.textPrimary,
                                            ),
                                          ),
                                        ),
                                        8.w,
                                        // Department Badge
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
                                            sub.department,
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
                                        if (sub.plan.isNotEmpty) ...[
                                          Text(
                                            sub.plan,
                                            style: TextStyle(
                                              fontSize: 12.5,
                                              color: crm.textSecondary,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          Text('•', style: TextStyle(color: crm.textSecondary)),
                                        ],
                                        Text(
                                          sub.billingCycleLabel,
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            color: crm.textSecondary,
                                          ),
                                        ),
                                        Text('•', style: TextStyle(color: crm.textSecondary)),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.event,
                                              size: 13,
                                              color: sub.isRenewingSoon
                                                  ? crm.warning
                                                  : crm.textSecondary,
                                            ),
                                            4.w,
                                            Text(
                                              'Renewal: ${_date(sub.renewalDate)}',
                                              style: TextStyle(
                                                fontSize: 12.5,
                                                fontWeight: sub.isRenewingSoon
                                                    ? FontWeight.w700
                                                    : FontWeight.normal,
                                                color: sub.isRenewingSoon
                                                    ? crm.warning
                                                    : crm.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (sub.ownerName.isNotEmpty || sub.ownerEmployee != null) ...[
                                          Text('•', style: TextStyle(color: crm.textSecondary)),
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.person_outline, size: 14, color: crm.textSecondary),
                                              4.w,
                                              Text(
                                                sub.ownerEmployee?.name ?? sub.ownerName,
                                                style: TextStyle(
                                                  fontSize: 12.5,
                                                  color: crm.textSecondary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              // Cost & Status
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    _money(sub.cost),
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: crm.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    '/${sub.billingCycle.toLowerCase().replaceAll('ly', '')}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: crm.textSecondary,
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
                                      sub.status.toUpperCase(),
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

                          if (sub.isRenewingSoon || sub.isOverdue) ...[
                            8.h,
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: (sub.isOverdue ? crm.destructive : crm.warning)
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.alarm,
                                    size: 16,
                                    color: sub.isOverdue ? crm.destructive : crm.warning,
                                  ),
                                  8.w,
                                  Text(
                                    sub.isOverdue
                                        ? 'Renewal is overdue by ${sub.daysUntilRenewal.abs()} days!'
                                        : 'Renews in ${sub.daysUntilRenewal} days (${_date(sub.renewalDate)})',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: sub.isOverdue ? crm.destructive : crm.warning,
                                    ),
                                  ),
                                  const Spacer(),
                                  if (sub.autoRenew)
                                    Text(
                                      'Auto-renew ON',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: crm.textSecondary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],

                          if (sub.notes.isNotEmpty) ...[
                            8.h,
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Theme.of(context).scaffoldBackgroundColor,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                sub.notes,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: crm.textSecondary,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          ],

                          // Actions
                          8.h,
                          const Divider(height: 1),
                          8.h,
                          Row(
                            children: [
                              if (sub.websiteUrl.isNotEmpty)
                                TextButton.icon(
                                  onPressed: () {},
                                  icon: const Icon(Icons.open_in_new, size: 15),
                                  label: Text(
                                    sub.websiteUrl,
                                    style: const TextStyle(fontSize: 12),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                )
                              else
                                Text(
                                  'Payment: ${sub.paymentMethod}',
                                  style: TextStyle(fontSize: 12, color: crm.textSecondary),
                                ),
                              const Spacer(),
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 18),
                                tooltip: 'Edit Subscription',
                                onPressed: () =>
                                    _showAddEditSubscriptionDialog(subscription: sub),
                              ),
                              IconButton(
                                icon: Icon(Icons.delete_outline, size: 18, color: crm.destructive),
                                tooltip: 'Delete',
                                onPressed: () => _deleteSubscription(sub),
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

class _AddEditSubscriptionDialog extends ConsumerStatefulWidget {
  final Subscription? subscription;
  final VoidCallback onSaved;

  const _AddEditSubscriptionDialog({this.subscription, required this.onSaved});

  @override
  ConsumerState<_AddEditSubscriptionDialog> createState() =>
      _AddEditSubscriptionDialogState();
}

class _AddEditSubscriptionDialogState
    extends ConsumerState<_AddEditSubscriptionDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _planCtrl;
  late TextEditingController _costCtrl;
  late TextEditingController _websiteCtrl;
  late TextEditingController _notesCtrl;
  late TextEditingController _paymentMethodCtrl;
  late TextEditingController _ownerNameCtrl;

  late String _selectedDept;
  late String _selectedBillingCycle;
  late String _selectedStatus;
  late DateTime _selectedRenewalDate;
  bool _autoRenew = true;
  String? _selectedEmployeeId;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final s = widget.subscription;
    _nameCtrl = TextEditingController(text: s?.name ?? '');
    _planCtrl = TextEditingController(text: s?.plan ?? '');
    _costCtrl = TextEditingController(
      text: s != null ? s.cost.toStringAsFixed(0) : '',
    );
    _websiteCtrl = TextEditingController(text: s?.websiteUrl ?? '');
    _notesCtrl = TextEditingController(text: s?.notes ?? '');
    _paymentMethodCtrl = TextEditingController(text: s?.paymentMethod ?? 'credit_card');
    _ownerNameCtrl = TextEditingController(text: s?.ownerName ?? '');

    _selectedDept = s?.department ?? 'IT';
    _selectedBillingCycle = s?.billingCycle ?? 'monthly';
    _selectedStatus = s?.status ?? 'active';
    _selectedRenewalDate = s?.renewalDate ?? DateTime.now().add(const Duration(days: 30));
    _autoRenew = s?.autoRenew ?? true;
    _selectedEmployeeId = s?.ownerEmployee?.id;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _planCtrl.dispose();
    _costCtrl.dispose();
    _websiteCtrl.dispose();
    _notesCtrl.dispose();
    _paymentMethodCtrl.dispose();
    _ownerNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final service = ref.read(subscriptionServiceProvider);
      final payload = {
        'name': _nameCtrl.text.trim(),
        'department': _selectedDept,
        'plan': _planCtrl.text.trim(),
        'cost': double.tryParse(_costCtrl.text.trim()) ?? 0,
        'billingCycle': _selectedBillingCycle,
        'renewalDate': _selectedRenewalDate.toIso8601String(),
        'paymentMethod': _paymentMethodCtrl.text.trim(),
        if (_selectedEmployeeId != null && _selectedEmployeeId!.isNotEmpty)
          'ownerEmployeeId': _selectedEmployeeId,
        'ownerName': _ownerNameCtrl.text.trim(),
        'status': _selectedStatus,
        'autoRenew': _autoRenew,
        'websiteUrl': _websiteCtrl.text.trim(),
        'notes': _notesCtrl.text.trim(),
      };

      if (widget.subscription == null) {
        await service.createSubscription(payload);
      } else {
        await service.updateSubscription(widget.subscription!.id, payload);
      }

      widget.onSaved();
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.subscription == null
                  ? 'Subscription added successfully'
                  : 'Subscription updated successfully',
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
                      widget.subscription == null
                          ? 'Add Software / Subscription'
                          : 'Edit Subscription',
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

                // Name & Department
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Tool / Service Name *',
                          hintText: 'e.g. Google Workspace, Adobe CC',
                        ),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Enter tool name' : null,
                      ),
                    ),
                    12.w,
                    Expanded(
                      flex: 1,
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
                  ],
                ),
                12.h,

                // Plan & Cost
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _planCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Plan / Tier',
                          hintText: 'e.g. Standard 10 Seats, Pro Tier',
                        ),
                      ),
                    ),
                    12.w,
                    Expanded(
                      child: TextFormField(
                        controller: _costCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Cost (₹) *',
                          prefixText: '₹ ',
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Enter cost';
                          if (double.tryParse(v.trim()) == null) return 'Invalid number';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                12.h,

                // Billing Cycle & Next Renewal Date
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedBillingCycle,
                        decoration: const InputDecoration(labelText: 'Billing Cycle'),
                        items: const [
                          DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                          DropdownMenuItem(value: 'quarterly', child: Text('Quarterly')),
                          DropdownMenuItem(value: 'yearly', child: Text('Yearly')),
                          DropdownMenuItem(value: 'one-time', child: Text('One-Time License')),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedBillingCycle = val);
                        },
                      ),
                    ),
                    12.w,
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _selectedRenewalDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2035),
                          );
                          if (picked != null) {
                            setState(() => _selectedRenewalDate = picked);
                          }
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Next Renewal Date *',
                            suffixIcon: Icon(Icons.calendar_today, size: 18),
                          ),
                          child: Text(DateFormat('d MMM yyyy').format(_selectedRenewalDate)),
                        ),
                      ),
                    ),
                  ],
                ),
                12.h,

                // Owner Staff Member
                employeesAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (_, _) => TextFormField(
                    controller: _ownerNameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Responsible Owner Name',
                    ),
                  ),
                  data: (staffList) {
                    return DropdownButtonFormField<String?>(
                      initialValue: _selectedEmployeeId,
                      decoration: const InputDecoration(
                        labelText: 'Tool Owner / Admin Staff',
                      ),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('None / Organization-wide')),
                        ...staffList.map((emp) => DropdownMenuItem(
                              value: emp.id,
                              child: Text('${emp.name} (${emp.department ?? emp.role ?? 'Staff'})'),
                            )),
                      ],
                      onChanged: (val) => setState(() => _selectedEmployeeId = val),
                    );
                  },
                ),
                12.h,

                // Status & Auto-Renew
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedStatus,
                        decoration: const InputDecoration(labelText: 'Status'),
                        items: const [
                          DropdownMenuItem(value: 'active', child: Text('Active')),
                          DropdownMenuItem(value: 'paused', child: Text('Paused')),
                          DropdownMenuItem(value: 'cancelled', child: Text('Cancelled')),
                          DropdownMenuItem(value: 'expired', child: Text('Expired')),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedStatus = val);
                        },
                      ),
                    ),
                    12.w,
                    Expanded(
                      child: SwitchListTile(
                        title: const Text('Auto-Renew', style: TextStyle(fontSize: 13)),
                        contentPadding: EdgeInsets.zero,
                        value: _autoRenew,
                        onChanged: (val) => setState(() => _autoRenew = val),
                      ),
                    ),
                  ],
                ),
                12.h,

                // Website URL
                TextFormField(
                  controller: _websiteCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Website / Login URL',
                    hintText: 'https://...',
                    prefixIcon: Icon(Icons.language, size: 18),
                  ),
                ),
                12.h,

                // Notes
                TextFormField(
                  controller: _notesCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Notes / Account Details',
                    hintText: 'Account ID, license key notes, vendor contact...',
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
                          : Text(widget.subscription == null ? 'Add Subscription' : 'Save Changes'),
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
