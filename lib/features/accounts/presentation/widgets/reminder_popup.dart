import 'package:flutter/material.dart';
import 'package:nizan_crm/core/extensions/space_extension.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';

/// A single urgent item shown in the [showReminderPopup] dialog.
class ReminderItem {
  final IconData icon;
  final String title;
  final String subtitle;

  /// true → overdue (rendered red), false → due soon (rendered amber).
  final bool overdue;

  const ReminderItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.overdue,
  });
}

/// Fleet-style urgent-reminders popup: an on-open dialog that lists the items
/// needing attention (overdue / due soon) with an "Acknowledge" button. Mirrors
/// the Fleet service-reminders popup so reminders live on the screen itself
/// instead of the notification stream.
Future<void> showReminderPopup(
  BuildContext context, {
  required String title,
  required List<ReminderItem> items,
}) {
  final crm = context.crmColors;
  final overdueCount = items.where((i) => i.overdue).length;

  return showDialog(
    context: context,
    builder: (ctx) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480),
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: crm.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: crm.warning.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.notification_important_rounded,
                      color: crm.warning, size: 24),
                ),
                16.w,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: crm.textPrimary),
                      ),
                      2.h,
                      Text(
                        overdueCount > 0
                            ? '$overdueCount overdue · ${items.length - overdueCount} due soon'
                            : '${items.length} due soon',
                        style: TextStyle(
                            fontSize: 12.5, color: crm.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            20.h,
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: items.length,
                separatorBuilder: (_, _) => 12.h,
                itemBuilder: (context, index) {
                  final r = items[index];
                  final color = r.overdue ? crm.destructive : crm.warning;
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.06),
                      border: Border.all(color: color.withValues(alpha: 0.25)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(r.icon, color: color, size: 26),
                        14.w,
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                r.title,
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: crm.textPrimary),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              4.h,
                              Row(
                                children: [
                                  Icon(
                                      r.overdue
                                          ? Icons.warning_rounded
                                          : Icons.schedule_rounded,
                                      color: color,
                                      size: 14),
                                  4.w,
                                  Expanded(
                                    child: Text(
                                      r.subtitle,
                                      style: TextStyle(
                                          color: color,
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
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
                },
              ),
            ),
            22.h,
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  backgroundColor: crm.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Acknowledge',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
