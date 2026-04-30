import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/extensions/space_extension.dart';
import '../../core/theme/crm_theme.dart';


class LeaveRequestScreen extends ConsumerStatefulWidget {
  const LeaveRequestScreen({super.key});

  @override
  ConsumerState<LeaveRequestScreen> createState() => _LeaveRequestScreenState();
}

class _LeaveRequestScreenState extends ConsumerState<LeaveRequestScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final crm = context.crmColors;

    // Mock data for leave history
    final leaveHistory = [
      (date: '2024-05-10', type: 'Sick Leave', status: 'Approved', reason: 'Fever'),
      (date: '2024-04-15', type: 'Personal', status: 'Rejected', reason: 'Family event'),
      (date: '2024-06-20', type: 'Vacation', status: 'Pending', reason: 'Summer trip'),
    ];

    Future<void> showApplyLeaveDialog() async {
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          title: Text(
            'New Leave Request',
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Leave Type',
                    prefixIcon: Icon(Icons.category_outlined),
                  ),
                  items: ['Sick Leave', 'Personal', 'Vacation', 'Other']
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (v) {},
                ),
                16.h,
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Select Date',
                    prefixIcon: Icon(Icons.calendar_today_outlined),
                    suffixIcon: Icon(Icons.arrow_drop_down),
                  ),
                  readOnly: true,
                  onTap: () => showDatePicker(
                    context: ctx,
                    initialDate: DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 90)),
                  ),
                ),
                16.h,
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Reason for Leave',
                    alignLabelWithHint: true,
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('CANCEL', style: TextStyle(color: crm.textSecondary, fontWeight: FontWeight.bold)),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8, bottom: 8),
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('SUBMIT REQUEST'),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Time Off',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      'Request leaves and track history',
                      style: TextStyle(color: crm.textSecondary, fontSize: 13),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: showApplyLeaveDialog,
                icon: const Icon(Icons.add_rounded, size: 20),
                label: const Text('APPLY'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ],
          ),
          32.h,
          Text(
            'Request History',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          16.h,
          Expanded(
            child: ListView.separated(
              physics: const BouncingScrollPhysics(),
              itemCount: leaveHistory.length,
              separatorBuilder: (_, _) => 12.h,
              itemBuilder: (context, index) {
                final item = leaveHistory[index];
                final statusColor = item.status == 'Approved'
                    ? crm.success
                    : item.status == 'Rejected'
                        ? crm.destructive
                        : crm.warning;

                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: crm.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: crm.border.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.calendar_month_outlined, color: statusColor, size: 22),
                      ),
                      16.w,
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.type,
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                            ),
                            4.h,
                            Text(
                              '${item.date} • ${item.reason}',
                              style: TextStyle(color: crm.textSecondary, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          item.status.toUpperCase(),
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.w900,
                            fontSize: 10,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
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
