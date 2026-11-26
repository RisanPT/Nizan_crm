import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/crm/data/crm_weekly_models.dart';
import 'package:nizan_crm/features/crm/presentation/widgets/crm_booking_care_card.dart';
import 'package:nizan_crm/features/crm/presentation/widgets/crm_widgets.dart';
import 'package:nizan_crm/features/crm/services/crm_weekly_service.dart';

/// A CRM to-do list from the works themselves: [kind] 'verify' — the coming 7 days' works to confirm with the client; 'photos' — the
/// last 14 days' works whose photos are still to collect. What is not done comes first, each with its button; a tap opens the booking.
class CrmCareToDo extends ConsumerWidget {
  const CrmCareToDo({super.key, required this.kind, this.canWrite = true});
  final String kind;
  final bool canWrite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crm = context.crmColors;
    final async = ref.watch(crmCareListProvider(kind));
    final verify = kind == 'verify';
    final title = verify ? 'To verify with the client — next 7 days' : 'Photos to collect — last 14 days';
    return Column(
      key: Key('crmToDo_$kind'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(child: Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: crm.textPrimary))),
          if (async.value case final l?) Text('${l.done} of ${l.works} done', style: TextStyle(fontWeight: FontWeight.w700, color: l.done == l.works ? crm.success : crm.textSecondary)),
        ]),
        const SizedBox(height: 8),
        async.when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text(friendlyErrorMessage(e), style: TextStyle(color: crm.textSecondary)),
          data: (l) {
            final open = l.items.where((i) => !i.done).toList();
            if (open.isEmpty) {
              return Text(l.works == 0 ? 'No works.' : (verify ? 'Every work is verified.' : 'Every work has its photos.'), style: TextStyle(color: crm.success));
            }
            return Column(children: [for (final i in open) _row(context, ref, crm, i, verify)]);
          },
        ),
      ],
    );
  }

  Widget _row(BuildContext context, WidgetRef ref, CrmTheme crm, CrmCareListItem i, bool verify) => CrmPanel(
    key: Key('crmToDo_${kind}_${i.bookingId}_${i.day}'),
    margin: const EdgeInsets.only(bottom: 8),
    radius: 12,
    child: ListTile(
      onTap: () => context.go('/booking/manage/${i.bookingId}'),
      leading: Icon(verify ? Icons.phone_in_talk_outlined : Icons.photo_camera_outlined, color: crm.primary),
      title: Row(children: [
        Flexible(child: Text(i.client, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700))),
        if (i.medical) ...[const SizedBox(width: 6), Tooltip(message: 'Has a medical note', child: Icon(Icons.medical_information_outlined, size: 16, color: crm.destructive))],
      ]),
      subtitle: Text([crmDayLabel(i.day), if (i.bookingNumber.isNotEmpty) i.bookingNumber, if (i.phone.isNotEmpty) i.phone].join(' · ')),
      trailing: canWrite
          ? OutlinedButton(
              key: Key('crmToDoDone_${kind}_${i.bookingId}_${i.day}'),
              onPressed: () async {
                try {
                  final svc = ref.read(crmWeeklyServiceProvider);
                  verify ? await svc.verify(i.bookingId, i.day) : await svc.photos(i.bookingId, i.day);
                  refreshCrmCare(ref);
                } catch (e) {
                  if (context.mounted) showErrorSnackBar(context, e);
                }
              },
              child: Text(verify ? 'Verified' : 'Collected'),
            )
          : null,
    ),
  );
}
