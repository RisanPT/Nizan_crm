import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nizan_crm/core/auth/workspace.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';

import '../../controllers/consultation_provider.dart';
import 'consultation_tile.dart';
import 'consultation_ui.dart';

/// A client's consultations on the lead page: the SRS client status, the recent
/// consultations, and a button to book another. Hidden entirely for users
/// without any consultations permission.
class LeadConsultationsCard extends ConsumerWidget {
  const LeadConsultationsCard({super.key, required this.leadId});

  final String leadId;

  static const _maxShown = 4;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final access = ref.watch(effectiveAccessProvider);
    if (!access.canSeeConsultations) return const SizedBox.shrink();

    final crm = context.crmColors;
    final async = ref.watch(leadConsultationsProvider(leadId));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: crm.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.video_camera_front_outlined, size: 20, color: crm.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Consultations',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: crm.textPrimary)),
              ),
              if (async.value != null)
                ConsultationStatusChip(
                  async.value!.derivedStatus,
                  color: clientStatusColor(async.value!.derivedStatus),
                ),
            ],
          ),
          const SizedBox(height: 12),
          async.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            error: (e, _) => AppErrorView(
              error: e,
              compact: true,
              onRetry: () => ref.invalidate(leadConsultationsProvider(leadId)),
            ),
            data: (data) {
              final shown = data.consultations.take(_maxShown).toList();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (shown.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text('No consultations booked for this client yet.',
                          style: TextStyle(color: crm.textSecondary)),
                    )
                  else
                    for (final c in shown)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: ConsultationTile(consultation: c, showDate: true, showClient: false),
                      ),
                  if (data.consultations.length > _maxShown)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text('+ ${data.consultations.length - _maxShown} earlier',
                          style: TextStyle(color: crm.textSecondary, fontSize: 12)),
                    ),
                  OutlinedButton.icon(
                    onPressed: () => context.push('/consultations/new?leadId=$leadId'),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Schedule consultation'),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
