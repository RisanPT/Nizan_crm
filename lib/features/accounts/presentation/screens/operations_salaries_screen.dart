import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:nizan_crm/core/extensions/space_extension.dart';
import 'package:nizan_crm/core/models/salary.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/core/utils/responsive_builder.dart';
import 'package:nizan_crm/features/accounts/controllers/salary_controller.dart';
import 'package:nizan_crm/features/accounts/services/salary_service.dart';

const _monthNames = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

String _formatCurrency(double amount) {
  return NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0)
      .format(amount);
}

class OperationsSalariesScreen extends ConsumerStatefulWidget {
  const OperationsSalariesScreen({super.key});

  @override
  ConsumerState<OperationsSalariesScreen> createState() =>
      _OperationsSalariesScreenState();
}

class _OperationsSalariesScreenState
    extends ConsumerState<OperationsSalariesScreen> {
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _showRecordPaymentDialog(Salary salary) {
    String paymentMethod = 'upi';
    final refCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    DateTime paymentDate = DateTime.now();

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  const Icon(Icons.payment, color: Colors.green),
                  8.w,
                  const Text('Disburse Operations Payout',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              content: SizedBox(
                width: 440,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: context.crmColors.accent.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              salary.employeeName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            2.h,
                            Text(
                              'Operations · ${salary.role} (${salary.salaryType.replaceAll('_', ' ')})',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(ctx).hintColor),
                            ),
                            6.h,
                            Text(
                              'Payout Amount: ${_formatCurrency(salary.netAmount)}',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: context.crmColors.accent),
                            ),
                          ],
                        ),
                      ),
                      14.h,

                      if (salary.bankName.isNotEmpty || salary.upiId.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.grey.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Payment Destination:',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11)),
                              4.h,
                              if (salary.upiId.isNotEmpty)
                                Text('UPI ID: ${salary.upiId}',
                                    style: const TextStyle(fontSize: 11)),
                              if (salary.bankName.isNotEmpty)
                                Text(
                                    '${salary.bankName} · Acc: ${salary.accountNumber} · IFSC: ${salary.ifscCode}',
                                    style: const TextStyle(fontSize: 11)),
                            ],
                          ),
                        ),
                        14.h,
                      ],

                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: paymentMethod,
                        items: const [
                          DropdownMenuItem(
                            value: 'upi',
                            child: Text('UPI / GPay / PhonePe / Paytm'),
                          ),
                          DropdownMenuItem(
                            value: 'bank_transfer',
                            child: Text('Bank Transfer (NEFT / IMPS)'),
                          ),
                          DropdownMenuItem(
                            value: 'cash',
                            child: Text('Cash Payout'),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setModalState(() => paymentMethod = val);
                          }
                        },
                        decoration: const InputDecoration(
                          labelText: 'Payout Method *',
                          isDense: true,
                        ),
                      ),
                      12.h,
                      TextField(
                        controller: refCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Transaction Ref / UPI UTR No.',
                          hintText: 'e.g. UPI-20260408-982109',
                          isDense: true,
                        ),
                      ),
                      12.h,
                      TextField(
                        controller: notesCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Payout Notes / Trip / Booking ID',
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
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  onPressed: () async {
                    try {
                      await ref.read(salaryServiceProvider).paySalary(
                            salary.id,
                            paymentMethod: paymentMethod,
                            transactionRef: refCtrl.text.trim(),
                            paymentDate: paymentDate,
                            notes: notesCtrl.text.trim(),
                          );
                      ref.invalidate(opsSalariesProvider);
                      ref.invalidate(salariesProvider);
                      if (ctx.mounted) Navigator.of(ctx).pop();
                    } catch (e) {
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(content: Text(e.toString())),
                        );
                      }
                    }
                  },
                  child: const Text('Confirm Payout',
                      style: TextStyle(color: Colors.white)),
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
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.brush, color: context.crmColors.accent),
              8.w,
              const Text('Operations Staff Payout Slip',
                  style: TextStyle(fontWeight: FontWeight.bold)),
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
                      color: context.crmColors.accent.withValues(alpha: 0.08),
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
                          'Operations · ${salary.role} (${salary.salaryType.replaceAll('_', ' ')})',
                          style: TextStyle(
                              fontSize: 12, color: Theme.of(ctx).hintColor),
                        ),
                        4.h,
                        Text(
                          'Period: ${_monthNames[salary.month - 1]} ${salary.year}',
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  16.h,
                  _buildSlipRow('Base / Retainer', _formatCurrency(salary.baseSalary)),
                  _buildSlipRow('Trip / Booking Commission', '+ ${_formatCurrency(salary.allowances)}',
                      color: Colors.green),
                  _buildSlipRow('Performance Bonus', '+ ${_formatCurrency(salary.bonus)}',
                      color: Colors.green),
                  _buildSlipRow('Advances / Deductions', '- ${_formatCurrency(salary.deductions)}',
                      color: Colors.red),
                  const Divider(height: 24),
                  _buildSlipRow(
                    'Total Payable',
                    _formatCurrency(salary.netAmount),
                    isBold: true,
                    fontSize: 16,
                  ),
                  16.h,
                  if (salary.bankName.isNotEmpty || salary.upiId.isNotEmpty) ...[
                    const Text('Payment Details',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    6.h,
                    if (salary.upiId.isNotEmpty)
                      Text('UPI ID: ${salary.upiId}',
                          style: const TextStyle(fontSize: 12)),
                    if (salary.bankName.isNotEmpty)
                      Text('Bank: ${salary.bankName} · Acc: ${salary.accountNumber} · IFSC: ${salary.ifscCode}',
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
    final filter = ref.watch(opsSalariesFilterProvider);
    final salariesAsync = ref.watch(opsSalariesProvider);

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
                        'Operations Staff Payouts (Accounts)',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      4.h,
                      Text(
                        'Disburse monthly wages and booking payouts for Creative Artists, Stylists, Assistants, and Fleet Drivers.',
                        style: TextStyle(color: crm.textSecondary, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            16.h,

            // ── PERIOD SELECTOR & STATS ──
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
                child: Text('Error loading payouts: $err'),
              ),
              data: (result) {
                final stats = result.stats;
                return Column(
                  children: [
                    // Filter bar for Period
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
                              size: 18, color: crm.accent),
                          8.w,
                          const Text('Period:',
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
                                ref.read(opsSalariesFilterProvider.notifier).state =
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
                                ref.read(opsSalariesFilterProvider.notifier).state =
                                    filter.copyWith(year: val);
                              }
                            },
                          ),
                          const Spacer(),
                          Text(
                            '${result.salaries.length} Operations Personnel',
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
                            title: 'Total Operations Payout',
                            amount: _formatCurrency(stats.totalOperations),
                            subtitle: '${stats.count} operational personnel',
                            icon: Icons.brush_outlined,
                            color: crm.accent,
                          ),
                        ),
                        10.w,
                        Expanded(
                          child: _buildMetricCard(
                            crm,
                            title: 'Total Disbursed',
                            amount: _formatCurrency(stats.totalPaid),
                            subtitle: 'Paid by accounts',
                            icon: Icons.check_circle_outline,
                            color: Colors.green,
                          ),
                        ),
                        10.w,
                        Expanded(
                          child: _buildMetricCard(
                            crm,
                            title: 'Pending Payout',
                            amount: _formatCurrency(stats.totalPending),
                            subtitle: 'Awaiting disbursement',
                            icon: Icons.pending_actions_outlined,
                            color: Colors.orange,
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
            16.h,

            // ── SEARCH & STATUS FILTER ──
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (val) {
                      ref.read(opsSalariesFilterProvider.notifier).state =
                          filter.copyWith(search: val);
                    },
                    decoration: InputDecoration(
                      hintText: 'Search artist or driver by name or role...',
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
                        child: Text('Pending Payout (Approved by HR)')),
                    DropdownMenuItem(value: 'paid', child: Text('Paid')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      ref.read(opsSalariesFilterProvider.notifier).state =
                          filter.copyWith(status: val);
                    }
                  },
                ),
              ],
            ),
            12.h,

            // ── SALARIES LIST ──
            Expanded(
              child: salariesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) =>
                    Center(child: Text('Failed to load operations payouts: $err')),
                data: (result) {
                  final list = result.salaries;
                  if (list.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.payments_outlined,
                              size: 48,
                              color: crm.textSecondary.withValues(alpha: 0.5)),
                          12.h,
                          Text(
                            'No operational payout slips found for this selection.',
                            style: TextStyle(
                                color: crm.textSecondary, fontSize: 14),
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
                      return _buildSalaryCard(crm, s);
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

  Widget _buildSalaryCard(CrmTheme crm, Salary s) {
    final statusColor = s.isPaid ? Colors.green : Colors.orange;
    final statusText = s.isPaid ? 'Paid' : 'Pending Payout';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: crm.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: crm.accent.withValues(alpha: 0.15),
            child: Icon(
              Icons.brush,
              size: 20,
              color: crm.accent,
            ),
          ),
          14.w,

          // Name, Role & Salary Scheme
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
                        color: crm.accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        s.role,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: crm.accent,
                        ),
                      ),
                    ),
                  ],
                ),
                3.h,
                Text(
                  'Scheme: ${s.salaryType.replaceAll('_', ' ')} · Base: ${_formatCurrency(s.baseSalary)}',
                  style: TextStyle(fontSize: 11.5, color: crm.textSecondary),
                ),
              ],
            ),
          ),

          // Payment info (UPI / Bank)
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (s.upiId.isNotEmpty)
                  Text(
                    'UPI: ${s.upiId}',
                    style: const TextStyle(
                        fontSize: 11.5, fontWeight: FontWeight.w500),
                  )
                else if (s.bankName.isNotEmpty)
                  Text(
                    '${s.bankName} - ${s.accountNumber}',
                    style: const TextStyle(
                        fontSize: 11.5, fontWeight: FontWeight.w500),
                  )
                else
                  Text(
                    'No payment details registered',
                    style: TextStyle(fontSize: 11, color: crm.textSecondary),
                  ),
                if (s.ifscCode.isNotEmpty)
                  Text(
                    'IFSC: ${s.ifscCode}',
                    style: TextStyle(fontSize: 10.5, color: crm.textSecondary),
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
                tooltip: 'View Slip',
                icon: const Icon(Icons.receipt_long_outlined, size: 18),
                onPressed: () => _showViewPayslipDialog(s),
              ),
              if (!s.isPaid)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 8),
                  ),
                  onPressed: () => _showRecordPaymentDialog(s),
                  icon: const Icon(Icons.payment, size: 14),
                  label: const Text('Disburse', style: TextStyle(fontSize: 12)),
                )
              else
                Text(
                  'Disbursed ✓',
                  style: TextStyle(
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.bold,
                      fontSize: 12),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
