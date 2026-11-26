import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/marketing/data/portfolio_models.dart';
import 'package:nizan_crm/features/marketing/presentation/kit/mkt_kit.dart';
import 'package:nizan_crm/features/marketing/presentation/portfolio/portfolio_widgets.dart';
import 'package:nizan_crm/features/marketing/presentation/portfolio/shoot_editor.dart';
import 'package:nizan_crm/features/marketing/presentation/socials/socials_widgets.dart' show platformName, postStatusLabel;
import 'package:nizan_crm/features/marketing/services/portfolio_service.dart';

/// On a booking (Marketing): the work's content checklist — the document's "the content checklist per work feeds Shoots and Posting".
/// The shoots linked to this work, what each should produce, and what has been delivered (approved assets and posts that went out,
/// each once) and posted. "Plan a shoot" opens a new shoot plan with this work already linked, its day and client filled in.
class BookingContentCard extends ConsumerWidget {
  const BookingContentCard({super.key, required this.bookingId});
  final String bookingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crm = context.crmColors;
    final async = ref.watch(bookingContentProvider(bookingId));
    return Container(
      key: const Key('bookingContentCard'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: crm.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: crm.border)),
      child: async.when(
        loading: () => const SizedBox(height: 60, child: Center(child: CircularProgressIndicator())),
        error: (e, _) => Row(children: [
          Expanded(child: Text(friendlyErrorMessage(e), style: TextStyle(color: crm.textSecondary))),
          TextButton(onPressed: () => ref.invalidate(bookingContentProvider(bookingId)), child: const Text('Try again')),
        ]),
        data: (c) => _body(context, ref, crm, c),
      ),
    );
  }

  Widget _body(BuildContext context, WidgetRef ref, CrmTheme crm, BookingContent c) {
    Future<void> plan() async {
      await showShootEditor(context, ref, booking: c.booking ?? BookingBrief(id: bookingId));
      ref.invalidate(bookingContentProvider(bookingId));
    }

    final planButton = TextButton.icon(key: const Key('bookingContentPlan'), onPressed: plan, icon: const Icon(Icons.add_rounded, size: 18), label: Text(c.shoots.isEmpty ? 'Plan a shoot for this work' : 'Plan another shoot'));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
        Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.videocam_outlined, size: 18, color: Mkt.primary),
          const SizedBox(width: 8),
          Flexible(child: Text('Content', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: crm.textPrimary))),
        ]),
        if (c.booking?.contentRequired == true) const MktChip('Content creation required', key: Key('bookingContentRequired'), color: Mkt.primary),
      ]),
      const SizedBox(height: 4),
      Text('The shoots planned for this work, what each should produce, and what has been delivered and posted.', style: TextStyle(fontSize: 12, color: crm.textSecondary)),
      const SizedBox(height: 12),
      if (c.shoots.isEmpty) Text('No shoot is linked to this work yet.', key: const Key('bookingContentNone'), style: TextStyle(color: crm.textSecondary)),
      for (final x in c.shoots) _shoot(crm, x),
      Align(alignment: Alignment.centerLeft, child: planButton),
    ]);
  }

  Widget _shoot(CrmTheme crm, ({ShootSummary summary, List<ChecklistRow> checklist, List<ShootPost> posts}) x) {
    final s = x.summary;
    return Container(
      key: Key('bookingContentShoot_${s.id}'),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: crm.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Text(s.title, style: TextStyle(fontWeight: FontWeight.w800, color: crm.textPrimary)),
          Text(shootDay(s.shootDate), style: TextStyle(fontSize: 12, color: crm.textSecondary)),
          MktChip(shootStatusLabel(s.status), color: shootStatusColor(s.status)),
          if (s.delayed) const MktChip('Delayed', color: Mkt.bad),
        ]),
        const SizedBox(height: 8),
        if (x.checklist.isEmpty) Text('No outputs are planned for this shoot.', style: TextStyle(fontSize: 12, color: crm.textSecondary)),
        for (final r in x.checklist)
          Padding(
            key: Key('bookingContentRow_${s.id}_${r.key}'),
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(children: [
              Icon(r.done ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded, size: 18, color: r.done ? Mkt.good : crm.textSecondary),
              const SizedBox(width: 8),
              Expanded(flex: 3, child: Text(r.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: crm.textPrimary))),
              Flexible(flex: 3, child: Text(r.planned > 0 ? '${r.delivered} / ${r.planned} delivered' : '${r.delivered} delivered', maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.right, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: crm.textPrimary))),
              const SizedBox(width: 10),
              Flexible(flex: 2, child: Text('${r.posted} posted', maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.right, style: TextStyle(fontSize: 12, color: crm.textSecondary))),
            ]),
          ),
        if (x.posts.isNotEmpty) ...[
          const SizedBox(height: 6),
          for (final p in x.posts.take(5))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(children: [
                Icon(p.status == 'published' ? Icons.check_circle_outline_rounded : Icons.schedule_send_outlined, size: 15, color: p.status == 'published' ? Mkt.good : crm.textSecondary),
                const SizedBox(width: 6),
                Expanded(child: Text(p.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: crm.textPrimary))),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    [platformName(p.platform), p.status == 'published' ? 'Posted${p.publishedDate == null ? '' : ' ${DateFormat('d MMM').format(p.publishedDate!)}'}' : postStatusLabel(p.status)].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: TextStyle(fontSize: 11.5, color: crm.textSecondary),
                  ),
                ),
              ]),
            ),
        ],
      ]),
    );
  }
}
