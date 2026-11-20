import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/marketing/data/lead_report_models.dart';
import 'package:nizan_crm/features/marketing/presentation/kit/mkt_kit.dart';
import 'package:nizan_crm/features/marketing/presentation/leadreport/lead_report_widgets.dart';
import 'package:nizan_crm/features/marketing/services/lead_report_service.dart';

/// Opens one lead read-only: a dialog on a wide screen, a bottom sheet on a phone. Nothing here edits the CRM's lead.
Future<void> showLeadDetail(BuildContext context, String id) {
  if (MediaQuery.sizeOf(context).width >= 700) {
    return showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Mkt.bg,
        insetPadding: const EdgeInsets.all(24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 640, maxHeight: 720), child: LeadDetailBody(id: id)),
      ),
    );
  }
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Mkt.bg,
    showDragHandle: true,
    constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.9),
    builder: (_) => LeadDetailBody(id: id),
  );
}

class LeadDetailBody extends ConsumerWidget {
  const LeadDetailBody({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(leadDetailProvider(id));
    return async.when(
      loading: () => const SizedBox(height: 240, child: Center(child: CircularProgressIndicator())),
      error: (e, _) => Padding(padding: const EdgeInsets.all(16), child: AppErrorView(error: e, onRetry: () => ref.invalidate(leadDetailProvider(id)))),
      data: (d) => _Detail(d: d),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({required this.d});
  final LeadDetail d;

  @override
  Widget build(BuildContext context) {
    final created = d.createdAt == null ? '—' : DateFormat('d MMM yyyy').format(d.createdAt!);
    Widget fact(String label, String value) => SizedBox(
          width: 170,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: mktText(10.5, weight: FontWeight.w700, color: Mkt.inkSoft)),
            Text(value.isEmpty ? '—' : value, maxLines: 2, overflow: TextOverflow.ellipsis, style: mktText(12.5, weight: FontWeight.w600)),
          ]),
        );
    final b = d.booking;
    return SingleChildScrollView(
      key: const Key('lr_detail'),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          MktAvatar(d.name, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(d.name, key: const Key('lr_detail_name'), maxLines: 2, overflow: TextOverflow.ellipsis, style: mktText(17, weight: FontWeight.w800)),
              Text(d.shortId, style: mktText(11.5, color: Mkt.inkSoft)),
            ]),
          ),
          IconButton(tooltip: 'Close', onPressed: () => Navigator.of(context).maybePop(), icon: const Icon(Icons.close_rounded)),
        ]),
        const SizedBox(height: 10),
        Wrap(spacing: 6, runSpacing: 6, children: [
          MktChip(d.status, color: leadStageColor(d.stage)),
          MktChip(d.priority, color: leadQualityColor(d.priority)),
          if (d.qualified) const MktChip('Qualified', color: Mkt.primary),
          MktChip(d.brand == 'kerala' ? 'Kerala' : 'Main', color: Mkt.grey),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Icon(d.canContact ? Icons.phone_outlined : Icons.lock_outline_rounded, size: 16, color: Mkt.inkSoft),
          const SizedBox(width: 8),
          Flexible(child: Text(d.contact.isEmpty ? '—' : d.contact, key: const Key('lr_detail_contact'), style: mktText(13.5, weight: FontWeight.w700))),
          if (d.canContact && d.phone.isNotEmpty) ...[const SizedBox(width: 6), ContactButtons(phone: d.phone, idKey: 'detail')],
        ]),
        if (!d.canContact) const LrNote('Contact details and notes are shown only to a Marketing Manager.', icon: Icons.lock_outline_rounded),
        const SizedBox(height: 14),
        Wrap(spacing: 12, runSpacing: 12, children: [
          fact('SOURCE', d.sourceLabel),
          fact('CAMPAIGN', d.campaign),
          fact('ASSIGNED TO', d.assignedTo),
          fact('CREATED', created),
          fact('EVENT', d.eventType),
          fact('PLACE', [d.district, d.region].where((x) => x.isNotEmpty).join(', ')),
        ]),
        const SizedBox(height: 14),
        if (d.firstContact != null && d.firstContact!.text.isNotEmpty) ...[
          Container(
            key: const Key('lr_detail_first_contact'),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(color: (d.firstContact!.state == 'waiting' || d.firstContact!.within == false ? Mkt.warn : Mkt.good).withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              Icon(d.firstContact!.state == 'waiting' ? Icons.hourglass_top_rounded : Icons.timer_outlined, size: 17, color: d.firstContact!.state == 'waiting' || d.firstContact!.within == false ? Mkt.warn : Mkt.good),
              const SizedBox(width: 8),
              Expanded(child: Text(d.firstContact!.text, style: mktText(12.5, weight: FontWeight.w600))),
            ]),
          ),
          const SizedBox(height: 12),
        ],
        MktCard(
          title: 'Follow-ups',
          icon: Icons.notifications_active_outlined,
          subtitle: 'Counted by the CRM: ${d.followUpCount} scheduled · ${d.followUpCompletedCount} actioned',
          child: d.followUpDate == null || d.followUpState == null
              ? Text('No follow-up is scheduled on this lead.', style: mktText(12, color: Mkt.inkSoft))
              : Row(children: [
                  Flexible(child: Text('Next: ${DateFormat('d MMM yyyy, h:mm a').format(d.followUpDate!)}', key: const Key('lr_detail_next_followup'), style: mktText(12.5, weight: FontWeight.w600))),
                  const SizedBox(width: 8),
                  MktChip(followUpLabel(d.followUpState!), color: followUpColor(d.followUpState!)),
                ]),
        ),
        if (b != null) ...[
          const SizedBox(height: 10),
          MktCard(
            title: 'Booking',
            icon: Icons.event_available_outlined,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${b.number.isEmpty ? 'Booking' : b.number} · ${b.status.isEmpty ? 'no status' : b.status}', style: mktText(12.5, weight: FontWeight.w600)),
              Text(b.counted && b.value != null ? 'Value ${rupees(b.value!, compact: false)} (after discount, excluding GST)' : 'Not counted: the booking is cancelled or still pending (so it is not a booking), or it was entered by a user left out of sales totals.', key: const Key('lr_detail_booking_value'), style: mktText(11.5, color: Mkt.inkSoft)),
            ]),
          ),
        ],
        if (d.reason.isNotEmpty || d.remarks.isNotEmpty) ...[
          const SizedBox(height: 10),
          MktCard(
            title: 'Notes',
            icon: Icons.sticky_note_2_outlined,
            child: SelectableText([if (d.reason.isNotEmpty) 'Reason: ${d.reason}', if (d.remarks.isNotEmpty) d.remarks].join('\n'), style: mktText(12, height: 1.35)),
          ),
        ],
        const SizedBox(height: 10),
        MktCard(
          title: 'Follow-up history',
          icon: Icons.history_rounded,
          child: d.activities.isEmpty
              ? const MktEmpty('Nothing has been logged on this lead.', icon: Icons.history_rounded, height: 80)
              : Column(key: const Key('lr_detail_history'), children: [
                  for (final a in d.activities)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        SizedBox(width: 78, child: Text(a.scheduledDate == null ? '—' : DateFormat('d MMM yy').format(a.scheduledDate!), style: mktText(11, color: Mkt.inkSoft))),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                              Text(a.typeLabel, style: mktText(12, weight: FontWeight.w700)),
                              MktChip(a.status, color: a.status == 'Completed' ? Mkt.good : (a.status == 'Cancelled' ? Mkt.grey : Mkt.warn)),
                              if (a.type == 'call' && a.callResponse.isNotEmpty && a.callResponse != 'N/A') MktChip(a.callResponse, color: Mkt.blue),
                            ]),
                            if (a.remark.isNotEmpty) Text(a.remark, maxLines: 3, overflow: TextOverflow.ellipsis, style: mktText(11.5, color: Mkt.inkSoft)),
                            if (a.by.isNotEmpty) Text('by ${a.by}', style: mktText(10.5, color: Mkt.inkSoft)),
                          ]),
                        ),
                      ]),
                    ),
                ]),
        ),
      ]),
    );
  }
}
