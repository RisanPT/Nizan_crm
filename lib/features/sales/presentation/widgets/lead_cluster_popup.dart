import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/sales/controllers/lead_controller.dart';

/// Demand-alert popup: lists every cluster of leads that share the SAME event
/// date AND the SAME place at/above the threshold, so the sales team can see the
/// pileup and act. Styled to match [showReminderPopup].
Future<void> showLeadClusterPopup(
  BuildContext context,
  WidgetRef ref,
  List<LeadCluster> clusters,
) {
  final crm = context.crmColors;
  final totalLeads = clusters.fold<int>(0, (s, c) => s + c.count);

  return showDialog(
    context: context,
    builder: (ctx) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520),
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
                  child: Icon(Icons.groups_2_rounded, color: crm.warning, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'High demand — same date & place',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: crm.textPrimary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        clusters.length == 1
                            ? '1 date + place with $totalLeads leads'
                            : '${clusters.length} date + place clusters · $totalLeads leads',
                        style: TextStyle(fontSize: 12.5, color: crm.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: clusters.length,
                separatorBuilder: (_, _) => const SizedBox(height: 14),
                itemBuilder: (context, i) => _clusterCard(ctx, crm, clusters[i]),
              ),
            ),
            const SizedBox(height: 20),
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
                child: const Text('Close',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Widget _clusterCard(BuildContext ctx, CrmTheme crm, LeadCluster c) {
  // Keep each cluster scannable — show the first slice, note the remainder.
  const maxShown = 10;
  final shown = c.leads.take(maxShown).toList();
  final remaining = c.count - shown.length;

  return Container(
    decoration: BoxDecoration(
      color: crm.warning.withValues(alpha: 0.05),
      border: Border.all(color: crm.warning.withValues(alpha: 0.25)),
      borderRadius: BorderRadius.circular(12),
    ),
    padding: const EdgeInsets.all(12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.event_rounded, size: 16, color: crm.warning),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '${_fmtDate(c.date)}  ·  ${c.place}',
                style: TextStyle(
                    fontWeight: FontWeight.w800, color: crm.textPrimary, fontSize: 13.5),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                color: crm.warning,
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text('${c.count} leads',
                  style: const TextStyle(
                      color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        for (final lead in shown) _leadRow(ctx, crm, lead),
        if (remaining > 0)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 2),
            child: Text('+ $remaining more with this date & place',
                style: TextStyle(
                    fontSize: 11.5,
                    fontStyle: FontStyle.italic,
                    color: crm.textSecondary)),
          ),
      ],
    ),
  );
}

Widget _leadRow(BuildContext ctx, CrmTheme crm, LeadClusterItem lead) {
  final color = _statusColor(crm, lead.status);
  return InkWell(
    borderRadius: BorderRadius.circular(8),
    onTap: () {
      Navigator.pop(ctx);
      ctx.go('/sales/leads/${lead.id}');
    },
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(lead.name.isEmpty ? 'Unnamed lead' : lead.name,
                    style: TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13, color: crm.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                if (lead.phone.isNotEmpty)
                  Text(lead.phone,
                      style: TextStyle(fontSize: 11.5, color: crm.textSecondary)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(lead.status,
                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: color)),
          ),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right, size: 16, color: crm.textSecondary),
        ],
      ),
    ),
  );
}

// Local copies (the leads-screen helpers are file-private). Kept in sync with
// _statusColor / _fmtDate in sales_leads_screen.dart.
Color _statusColor(CrmTheme crm, String status) {
  switch (status) {
    case 'New':
      return const Color(0xFF2563EB);
    case 'Contacted':
      return const Color(0xFF7C3AED);
    case 'Qualified':
      return const Color(0xFF0891B2);
    case 'Follow-up':
      return crm.warning;
    case 'Converted':
      return crm.success;
    case 'Lost':
      return crm.destructive;
    default:
      return crm.textSecondary;
  }
}

String _fmtDate(String ymd) {
  final d = DateTime.tryParse(ymd);
  if (d == null) return ymd;
  return DateFormat('EEE, d MMM yyyy').format(d);
}
