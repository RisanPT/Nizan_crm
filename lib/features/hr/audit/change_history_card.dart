import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:nizan_crm/core/error/app_error_view.dart';
import 'package:nizan_crm/core/providers/auth_provider.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/hr/audit/audit_log_service.dart';

/// "Change history" card for the staff details screen: who changed which
/// pay / bank / job field, when, from what to what. Renders nothing for users
/// without company-wide pay access (the API would 403 anyway).
class ChangeHistoryCard extends ConsumerWidget {
  final String employeeId;
  const ChangeHistoryCard({super.key, required this.employeeId});

  static const _fieldLabels = <String, String>{
    'baseSalary': 'Base salary',
    'allowances': 'Allowances',
    'deductions': 'Deductions',
    'attendanceDeduction': 'Attendance deduction',
    'incentives': 'Incentives',
    'roomRent': 'Room rent',
    'bonus': 'Bonus',
    'netAmount': 'Net amount',
    'hra': 'HRA',
    'hraDay': 'HRA day',
    'salaryType': 'Salary type',
    'overtimeRate': 'Overtime rate',
    'bankName': 'Bank name',
    'accountNumber': 'Account number',
    'ifscCode': 'IFSC',
    'upiId': 'UPI ID',
    'panNumber': 'PAN',
    'statutoryApplicability.uan': 'UAN',
    'statutoryApplicability.epf': 'EPF',
    'statutoryApplicability.esi': 'ESI',
    'currentGrade': 'Grade',
    'department': 'Department',
    'departmentId': 'Department (link)',
    'status': 'Status',
    'employmentStatus': 'Employment status',
    'role': 'Role',
    'designationId': 'Designation',
    'reportingManagerId': 'Reporting manager',
    'dateOfJoining': 'Date of joining',
    'paymentDate': 'Payment date',
    'paymentMethod': 'Payment method',
    'transactionRef': 'Transaction ref',
    'notes': 'Notes',
  };

  static const _actionLabels = <String, String>{
    'update': 'Updated',
    'increment': 'Salary increment',
    'apply': 'Compensation revision applied',
    'approve': 'Slip approved',
    'pay': 'Slip paid',
    'delete': 'Slip deleted',
    'lock': 'Payroll locked',
    'unlock': 'Payroll unlocked',
  };

  static String _fmt(Object? v) {
    if (v == null) return '—';
    if (v is bool) return v ? 'Yes' : 'No';
    if (v is num) return NumberFormat('#,##,##0.##', 'en_IN').format(v);
    final s = v.toString();
    if (RegExp(r'^\d{4}-\d{2}-\d{2}T').hasMatch(s)) {
      final d = DateTime.tryParse(s);
      if (d != null) return DateFormat('d MMM yyyy').format(d.toLocal());
    }
    // Raw ObjectId references are not meaningful to read.
    if (RegExp(r'^[0-9a-f]{24}$').hasMatch(s)) return '(changed)';
    return s.isEmpty ? '—' : s;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authSessionProvider);
    if (!canSeeChangeHistory(session)) return const SizedBox.shrink();
    final crm = context.crmColors;
    final theme = Theme.of(context);
    final async = ref.watch(employeeAuditLogProvider(employeeId));

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: crm.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.history, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('Change history',
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                ),
                IconButton(
                  tooltip: 'Refresh',
                  icon: const Icon(Icons.refresh),
                  onPressed: () => ref.invalidate(employeeAuditLogProvider(employeeId)),
                ),
              ],
            ),
            const Divider(height: 32),
            async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => AppErrorView(
                error: e,
                compact: true,
                onRetry: () => ref.invalidate(employeeAuditLogProvider(employeeId)),
              ),
              data: (logs) {
                if (logs.isEmpty) {
                  return Text('No changes recorded yet.',
                      style: TextStyle(color: crm.textSecondary));
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [for (final l in logs) _entry(context, l)],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _entry(BuildContext context, AuditLogEntry l) {
    final crm = context.crmColors;
    final when = l.at != null ? DateFormat('d MMM yyyy, h:mm a').format(l.at!.toLocal()) : '';
    final who = l.byName.isNotEmpty ? l.byName : 'System';
    final title = _actionLabels[l.action] ?? l.action;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$title · ${l.entity}', style: const TextStyle(fontWeight: FontWeight.w600)),
          Text('$when · by $who', style: TextStyle(fontSize: 12, color: crm.textSecondary)),
          if (l.note.isNotEmpty)
            Text(l.note, style: TextStyle(fontSize: 12, color: crm.textSecondary)),
          for (final c in l.changes)
            Padding(
              padding: const EdgeInsets.only(top: 3, left: 8),
              child: Text.rich(TextSpan(children: [
                TextSpan(
                    text: '${_fieldLabels[c.field] ?? c.field}: ',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                TextSpan(text: '${_fmt(c.from)}  →  ${_fmt(c.to)}', style: const TextStyle(fontSize: 13)),
              ])),
            ),
        ],
      ),
    );
  }
}
