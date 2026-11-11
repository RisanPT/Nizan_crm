import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';

import '../../data/consultation.dart';
import 'consultation_ui.dart';

/// One consultation as a tappable row — used by the calendar agenda, the list
/// screen and the lead card.
class ConsultationTile extends StatelessWidget {
  const ConsultationTile({
    super.key,
    required this.consultation,
    this.showDate = false,
    this.showClient = true,
  });

  final Consultation consultation;

  /// Show the date as well as the time (list screens and the lead card).
  final bool showDate;

  /// Hide the client name where it is already obvious (the lead card).
  final bool showClient;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final c = consultation;
    final color = consultationStatusColor(c.status);
    final muted = c.status == 'Cancelled';

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => context.push('/consultations/${c.id}'),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: crm.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border(left: BorderSide(color: color, width: 4)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 92,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (showDate)
                    Text(fmtShortDay(c.scheduledAt),
                        style: TextStyle(
                            fontWeight: FontWeight.w700, color: crm.textPrimary, fontSize: 13)),
                  Text(fmtTime(c.scheduledAt),
                      style: TextStyle(
                          fontWeight: showDate ? FontWeight.w500 : FontWeight.w700,
                          color: crm.textPrimary,
                          fontSize: 13)),
                  Text('${c.durationMins} min',
                      style: TextStyle(color: crm.textSecondary, fontSize: 11)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (showClient)
                    Text(
                      c.clientName.isEmpty ? 'Client' : c.clientName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: muted ? crm.textSecondary : crm.textPrimary,
                        decoration: muted ? TextDecoration.lineThrough : null,
                      ),
                    ),
                  Row(
                    children: [
                      Icon(c.isVideo ? Icons.videocam_outlined : Icons.place_outlined,
                          size: 14, color: crm.textSecondary),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          [
                            c.isVideo ? 'Video' : 'In-person',
                            if (c.stylistName.isNotEmpty) c.stylistName,
                          ].join('  ·  '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: crm.textSecondary, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ConsultationStatusChip(c.status),
          ],
        ),
      ),
    );
  }
}
