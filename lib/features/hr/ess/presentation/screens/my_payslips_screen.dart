import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/models/salary.dart';
import 'package:nizan_crm/core/providers/auth_provider.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/accounts/services/salary_service.dart';
import 'package:nizan_crm/features/accounts/utils/payslip_pdf.dart';

/// ESS: the signed-in employee's own payslips (approved / paid only).
/// Tap a slip to download (web) or share (mobile) its PDF.
class MyPayslipsScreen extends ConsumerStatefulWidget {
  const MyPayslipsScreen({super.key});

  @override
  ConsumerState<MyPayslipsScreen> createState() => _MyPayslipsScreenState();
}

class _MyPayslipsScreenState extends ConsumerState<MyPayslipsScreen> {
  String? _busyId;

  String _money(double v) =>
      NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0).format(v);

  Future<void> _download(Salary s) async {
    setState(() => _busyId = s.id);
    try {
      await downloadPayslipPdf(s);
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final session = ref.watch(authSessionProvider);
    final linked = (session?.employeeId ?? '').isNotEmpty;
    final async = ref.watch(mySalariesProvider);

    return Scaffold(
      backgroundColor: crm.background,
      appBar: AppBar(
        title: const Text('My Payslips'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(mySalariesProvider),
          ),
        ],
      ),
      body: !linked
          ? _empty(crm, 'Your login is not linked to an employee record. Please contact HR.')
          : async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => AppErrorView(error: e, onRetry: () => ref.invalidate(mySalariesProvider)),
              data: (slips) {
                if (slips.isEmpty) return _empty(crm, 'No payslips yet. They appear here once HR approves your salary.');
                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(mySalariesProvider),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: slips.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, i) => _tile(crm, slips[i]),
                  ),
                );
              },
            ),
    );
  }

  Widget _empty(dynamic crm, String msg) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.receipt_long_outlined, size: 48, color: crm.textSecondary),
            const SizedBox(height: 12),
            Text(msg, textAlign: TextAlign.center, style: TextStyle(color: crm.textSecondary)),
          ]),
        ),
      );

  Widget _tile(dynamic crm, Salary s) {
    final paid = s.isPaid;
    final busy = _busyId == s.id;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: crm.border),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: const Icon(Icons.receipt_long),
        title: Text(payslipMonthLabel(s), style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('Net pay ${_money(s.netAmount)}'),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: (paid ? Colors.green : Colors.orange).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(paid ? 'Paid' : 'Approved',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: paid ? Colors.green.shade700 : Colors.orange.shade800)),
          ),
          const SizedBox(width: 8),
          busy
              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
              : IconButton(
                  tooltip: 'Download payslip',
                  icon: const Icon(Icons.download_rounded),
                  onPressed: () => _download(s),
                ),
        ]),
        onTap: busy ? null : () => _download(s),
      ),
    );
  }
}
