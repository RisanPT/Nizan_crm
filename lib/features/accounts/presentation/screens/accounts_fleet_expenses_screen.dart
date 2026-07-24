import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:nizan_crm/core/extensions/space_extension.dart';
import 'package:nizan_crm/features/fleet/data/fuel_expense.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/core/utils/responsive_builder.dart';
import 'package:nizan_crm/features/fleet/controllers/fuel_expense_controller.dart';
import 'package:nizan_crm/presentation/screens/inventory/inventory_widgets.dart';

/// Accounts → Operations → Fleet Expenses. Driver-submitted fleet expenses
/// (with the uploaded bill) surfaced in Accounts, reviewable/approvable here.
class AccountsFleetExpensesScreen extends ConsumerStatefulWidget {
  const AccountsFleetExpensesScreen({super.key});

  @override
  ConsumerState<AccountsFleetExpensesScreen> createState() =>
      _AccountsFleetExpensesScreenState();
}

class _AccountsFleetExpensesScreenState
    extends ConsumerState<AccountsFleetExpensesScreen> {
  String _status = 'all'; // all | pending | approved | rejected

  static String _money(double v) =>
      NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0)
          .format(v);
  static String _date(DateTime d) => DateFormat('d MMM yyyy').format(d);

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

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final isMobile = ResponsiveBuilder.isMobile(context);
    final async = ref.watch(fuelExpensesProvider);

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Failed to load fleet expenses:\n$e',
              textAlign: TextAlign.center,
              style: TextStyle(color: crm.textSecondary)),
        ),
      ),
      data: (all) {
        final items = [...all]..sort((a, b) => b.date.compareTo(a.date));
        final now = DateTime.now();
        double total = 0, approved = 0, pending = 0, thisMonth = 0;
        for (final e in items) {
          total += e.totalAmount;
          if (e.status == 'approved') approved += e.totalAmount;
          if (e.status == 'pending') pending += e.totalAmount;
          if (e.date.year == now.year && e.date.month == now.month) {
            thisMonth += e.totalAmount;
          }
        }
        final filtered = _status == 'all'
            ? items
            : items.where((e) => e.status == _status).toList();

        return ListView(
          padding: EdgeInsets.fromLTRB(
              isMobile ? 16 : 24, 16, isMobile ? 16 : 24, 24),
          children: [
            Text('Fleet Expenses',
                style: TextStyle(
                    fontSize: isMobile ? 22 : 28,
                    fontWeight: FontWeight.w800,
                    color: crm.textPrimary)),
            4.h,
            Text('Driver-submitted fleet expenses with bills — review & approve.',
                style: TextStyle(fontSize: 13, color: crm.textSecondary)),
            16.h,
            InvStatGrid(
              isMobile: isMobile,
              stats: [
                InvStat(_money(total), 'Total', Icons.summarize_outlined,
                    crm.primary),
                InvStat(_money(pending), 'Pending review',
                    Icons.hourglass_bottom_outlined, crm.warning),
                InvStat(_money(approved), 'Approved',
                    Icons.check_circle_outline, crm.success),
                InvStat(_money(thisMonth), 'This month',
                    Icons.calendar_month_outlined, crm.accent),
              ],
            ),
            18.h,
            Wrap(
              spacing: 8,
              children: [
                for (final s in const ['all', 'pending', 'approved', 'rejected'])
                  ChoiceChip(
                    selected: _status == s,
                    label: Text(s[0].toUpperCase() + s.substring(1)),
                    onSelected: (_) => setState(() => _status = s),
                  ),
              ],
            ),
            14.h,
            if (filtered.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 48),
                child: Center(
                  child: Text('No fleet expenses.',
                      style: TextStyle(color: crm.textSecondary)),
                ),
              )
            else
              ...filtered.map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _expenseCard(crm, e),
                  )),
          ],
        );
      },
    );
  }

  Widget _expenseCard(CrmTheme crm, FuelExpense e) {
    final c = _statusColor(crm, e.status);
    return Container(
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: crm.border),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                    e.driver?.name.isNotEmpty == true
                        ? e.driver!.name
                        : 'Driver',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: crm.textPrimary)),
              ),
              Text(_money(e.totalAmount),
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: crm.textPrimary)),
              8.w,
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: c.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(e.status,
                    style: TextStyle(
                        color: c, fontSize: 11, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          4.h,
          Text(
            [
              e.category,
              if (e.vehicle?.name.isNotEmpty == true) e.vehicle!.name,
              _date(e.date),
              if (e.notes.isNotEmpty) e.notes,
            ].join('  ·  '),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12.5, color: crm.textSecondary),
          ),
          10.h,
          Row(
            children: [
              if (e.billImage.isNotEmpty)
                OutlinedButton.icon(
                  onPressed: () => _viewBill(crm, e.billImage),
                  icon: const Icon(Icons.receipt_long, size: 16),
                  label: const Text('View bill'),
                  style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact),
                )
              else
                Text('No bill attached',
                    style: TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: crm.textSecondary)),
              const Spacer(),
              if (e.status != 'approved')
                TextButton(
                  onPressed: () => _setStatus(e, 'approved'),
                  child: Text('Approve',
                      style: TextStyle(color: crm.success)),
                ),
              if (e.status != 'rejected')
                TextButton(
                  onPressed: () => _setStatus(e, 'rejected'),
                  child: Text('Reject',
                      style: TextStyle(color: crm.destructive)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _setStatus(FuelExpense e, String status) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(fuelExpenseServiceProvider).setStatus(e.id, status);
      ref.invalidate(fuelExpensesProvider);
      messenger.showSnackBar(SnackBar(content: Text('Marked $status')));
    } catch (err) {
      messenger.showSnackBar(SnackBar(content: Text('$err')));
    }
  }

  void _viewBill(CrmTheme crm, String url) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
              child: Row(
                children: [
                  Icon(Icons.receipt_long, color: crm.primary),
                  8.w,
                  const Expanded(
                      child: Text('Expense Bill',
                          style: TextStyle(fontWeight: FontWeight.bold))),
                  IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx)),
                ],
              ),
            ),
            Flexible(
              child: InteractiveViewer(
                child: Image.network(url,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => Padding(
                          padding: const EdgeInsets.all(40),
                          child: Text('Could not load bill image',
                              style: TextStyle(color: crm.textSecondary)),
                        )),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
