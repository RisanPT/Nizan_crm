import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/marketing/data/coordination_models.dart';
import 'package:nizan_crm/features/marketing/presentation/coordinations/coord_widgets.dart';
import 'package:nizan_crm/features/marketing/presentation/coordinations/meeting_editor.dart';
import 'package:nizan_crm/features/marketing/presentation/kit/mkt_kit.dart';
import 'package:nizan_crm/features/marketing/services/coordination_service.dart';

/// Coordinations → Meetings: schedule a meeting (time, place or link, agenda, attendees), see the upcoming ones with a detail panel, close
/// one with its discussion notes and action items, and turn an action item into a follow-up.
class CoordMeetingsTab extends ConsumerWidget {
  const CoordMeetingsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(coordMeetingsProvider);
    final q = ref.watch(coordMeetingQueryProvider);
    final selected = ref.watch(coordSelectedMeetingProvider);
    return RefreshIndicator(
      onRefresh: () async => refreshCoordinations(ref),
      child: async.when(
        loading: coordLoading,
        error: (e, _) => coordError(e, ref),
        data: (d) {
          final k = d.kpis;
          final openId = d.items.any((m) => m.id == selected) ? selected : (d.items.isEmpty ? null : (d.items.firstWhere((m) => m.state == 'live' || m.state == 'upcoming', orElse: () => d.items.first)).id);
          return ListView(
            key: const Key('coord_meetings_list'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            children: [
              MktKpiRow(minWidth: 165, children: [
                coordKpi(keyName: 'co_mt_kpi_total', icon: Icons.event_note_outlined, value: '${k.total}', label: 'Total Meetings', tint: Mkt.primary),
                coordKpi(keyName: 'co_mt_kpi_week', icon: Icons.groups_2_outlined, value: '${k.thisWeek}', label: 'This Week', tint: Mkt.blue),
                coordKpi(keyName: 'co_mt_kpi_completed', icon: Icons.check_circle_outline_rounded, value: '${k.completed}', label: 'Completed', tint: Mkt.good),
                coordKpi(keyName: 'co_mt_kpi_upcoming', icon: Icons.schedule_rounded, value: '${k.upcoming}', label: 'Upcoming', tint: Mkt.warn, note: k.toClose > 0 ? '${k.toClose} ended without notes' : null),
              ]),
              const SizedBox(height: 12),
              MktGrid(breakpoint: 980, rows: [
                [(4, _ListCard(data: d, query: q, openId: openId)), (6, openId == null ? const MktCard(title: 'Meeting', icon: Icons.event_outlined, child: MktEmpty('Schedule a meeting to see its agenda, attendees and action items here.', icon: Icons.event_outlined, height: 200)) : _Detail(key: ValueKey('mt_$openId'), id: openId))],
              ]),
            ],
          );
        },
      ),
    );
  }
}

class _ListCard extends ConsumerWidget {
  const _ListCard({required this.data, required this.query, required this.openId});
  final MeetingList data;
  final MeetingQuery query;
  final String? openId;

  void _set(WidgetRef ref, MeetingQuery q) => ref.read(coordMeetingQueryProvider.notifier).state = q;

  @override
  Widget build(BuildContext context, WidgetRef ref) => MktCard(
        title: 'Upcoming Meetings',
        icon: Icons.event_outlined,
        trailing: const ExportButton(type: 'meetings'),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          MktPrimaryButton(key: const Key('co_mt_new'), label: 'Schedule Meeting', onPressed: () => showMeetingEditor(context, ref)),
          const SizedBox(height: 8),
          SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [for (final f in const [('all', 'All'), ('upcoming', 'Upcoming'), ('to_close', 'Needs notes'), ('completed', 'Completed')]) Padding(padding: const EdgeInsets.only(right: 6), child: MktFilterChip(key: Key('co_mt_filter_${f.$1}'), label: f.$2, selected: query.status == f.$1, onTap: () => _set(ref, MeetingQuery(status: f.$1, q: query.q))))])),
          const SizedBox(height: 8),
          CoordSearchField(fieldKey: const Key('co_mt_search'), initial: query.q, hint: 'Search meetings…', onChanged: (v) => _set(ref, MeetingQuery(status: ref.read(coordMeetingQueryProvider).status, q: v))),
          const SizedBox(height: 8),
          if (data.items.isEmpty) MktEmpty(query.status == 'all' && query.q.isEmpty ? 'No meetings in this period. Use Schedule Meeting.' : 'No meeting matches.', icon: Icons.event_outlined, height: 120),
          for (final m in data.items)
            InkWell(
              key: Key('co_mt_${m.id}'),
              borderRadius: BorderRadius.circular(12),
              onTap: () => ref.read(coordSelectedMeetingProvider.notifier).state = m.id,
              child: Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: m.id == openId ? Mkt.primarySoft : Mkt.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: m.id == openId ? Mkt.primary : Mkt.border)),
                child: Row(children: [
                  Container(width: 34, height: 34, decoration: BoxDecoration(color: Mkt.tint(meetingStateColor(m.state)), borderRadius: BorderRadius.circular(10)), child: Icon(m.state == 'completed' ? Icons.check_rounded : Icons.groups_2_outlined, size: 18, color: meetingStateColor(m.state))),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(m.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(12.5, weight: FontWeight.w800)),
                      Text(meetingWhen(m.day, m.timeRange), maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(10.5, color: Mkt.inkSoft)),
                    ]),
                  ),
                  const SizedBox(width: 6),
                  Flexible(child: MktChip(kMeetingStateLabels[m.state] ?? m.state, color: meetingStateColor(m.state))),
                ]),
              ),
            ),
        ]),
      );
}

class _Detail extends ConsumerWidget {
  const _Detail({super.key, required this.id});
  final String id;

  Future<void> _toggleDone(BuildContext context, WidgetRef ref, MeetingRow m, ActionItemRow item) => coordQuickWrite(
        context,
        ref,
        () => ref.read(marketingCoordinationServiceProvider).saveMeeting({
              'actionItems': [for (final i in m.actionItems) {'id': i.id, 'text': i.text, if (i.ownerId != null) 'ownerId': i.ownerId else 'ownerName': i.owner, 'due': i.due, 'done': i.id == item.id ? !i.done : i.done}],
            }, id: m.id),
      );

  Future<void> _setStatus(BuildContext context, WidgetRef ref, MeetingRow m, String status) => coordQuickWrite(context, ref, () => ref.read(marketingCoordinationServiceProvider).saveMeeting({'status': status}, id: m.id));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(coordMeetingProvider(id));
    return async.when(
      loading: () => const MktCard(title: 'Meeting', icon: Icons.event_outlined, child: SizedBox(height: 240, child: Center(child: CircularProgressIndicator()))),
      error: (e, _) => MktCard(title: 'Meeting', icon: Icons.event_outlined, child: AppErrorView(error: e, onRetry: () => ref.invalidate(coordMeetingProvider(id)))),
      data: (m) => MktCard(
        title: m.title,
        subtitle: meetingWhen(m.day, m.timeRange),
        icon: Icons.event_outlined,
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          Flexible(child: MktChip(kMeetingStateLabels[m.state] ?? m.state, color: meetingStateColor(m.state))),
          if (m.canEdit || m.canDelete)
            PopupMenuButton<String>(
              key: const Key('co_mt_menu'),
              onSelected: (v) async {
                if (v == 'edit') {
                  await showMeetingEditor(context, ref, meeting: m);
                } else if (v == 'cancel') {
                  await _setStatus(context, ref, m, 'cancelled');
                } else if (v == 'reopen') {
                  await _setStatus(context, ref, m, 'upcoming');
                } else if (v == 'delete') {
                  final yes = await confirmCoord(context, title: 'Delete this meeting?', body: '"${m.title}" is removed. Its follow-ups stay. Cancel it instead if you want the record to stay.', confirmLabel: 'Delete', confirmKey: const Key('co_mt_delete_confirm'));
                  if (yes && context.mounted) {
                    if (await coordQuickWrite(context, ref, () => ref.read(marketingCoordinationServiceProvider).deleteMeeting(m.id))) ref.read(coordSelectedMeetingProvider.notifier).state = null;
                  }
                }
              },
              itemBuilder: (_) => [
                if (m.canEdit) const PopupMenuItem(value: 'edit', child: Text('Edit')),
                if (m.canEdit && m.status != 'cancelled') const PopupMenuItem(value: 'cancel', child: Text('Cancel meeting')),
                if (m.canEdit && m.status != 'upcoming') const PopupMenuItem(value: 'reopen', child: Text('Reopen')),
                if (m.canDelete) const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Mkt.bad))),
              ],
            ),
        ]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Wrap(spacing: 14, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
            _fact(Icons.event_outlined, coordDay(m.day, pattern: 'EEE d MMM yyyy')),
            _fact(Icons.schedule_rounded, m.timeRange),
            if (m.location.isNotEmpty) _fact(Icons.place_outlined, m.location),
            if (m.link.isNotEmpty) OutlinedButton.icon(key: const Key('co_mt_join'), onPressed: () => launchUrl(Uri.parse(m.link), mode: LaunchMode.externalApplication), icon: const Icon(Icons.videocam_outlined, size: 16), label: const Text('Join')),
          ]),
          if (m.departments.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Wrap(spacing: 6, runSpacing: 4, children: [for (final d in m.departments) DeptChip(d)])),
          const SizedBox(height: 12),
          Text('Agenda', style: mktText(12.5, weight: FontWeight.w800)),
          const SizedBox(height: 4),
          if (m.agenda.isEmpty) Text('No agenda written.', style: mktText(11.5, color: Mkt.inkSoft)) else Column(key: const Key('co_mt_agenda_list'), crossAxisAlignment: CrossAxisAlignment.start, children: [for (final a in m.agenda) Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Text('•  $a', style: mktText(12)))]),
          const SizedBox(height: 12),
          Text('Attendees (${m.attendees.length})', key: const Key('co_mt_attendees_title'), style: mktText(12.5, weight: FontWeight.w800)),
          const SizedBox(height: 4),
          if (m.attendees.isEmpty) Text('Nobody has been added.', style: mktText(11.5, color: Mkt.inkSoft)) else Wrap(key: const Key('co_mt_attendees'), spacing: 10, runSpacing: 6, children: [for (final a in m.attendees.take(8)) Row(mainAxisSize: MainAxisSize.min, children: [MktAvatar(a.name, size: 22), const SizedBox(width: 5), Text(a.name, style: mktText(11.5))]), if (m.attendees.length > 8) MktChip('+${m.attendees.length - 8}', color: Mkt.primary)]),
          if (m.notes.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Discussion notes', style: mktText(12.5, weight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(m.notes, key: const Key('co_mt_notes_view'), style: mktText(12)),
          ],
          const SizedBox(height: 12),
          Text('Action items (${m.actionItems.length})', style: mktText(12.5, weight: FontWeight.w800)),
          const SizedBox(height: 4),
          if (m.actionItems.isEmpty) Text('None recorded. Close the meeting to add them.', style: mktText(11.5, color: Mkt.inkSoft)),
          for (final i in m.actionItems) _actionRow(context, ref, m, i),
          if (m.canEdit && (m.state == 'live' || m.state == 'to_close')) ...[
            const SizedBox(height: 12),
            FilledButton.icon(key: const Key('co_mt_complete'), style: FilledButton.styleFrom(backgroundColor: Mkt.primary), onPressed: () => showMeetingEditor(context, ref, meeting: m, complete: true), icon: const Icon(Icons.check_rounded, size: 18), label: const Text('Mark completed')),
          ],
        ]),
      ),
    );
  }

  Widget _fact(IconData icon, String text) => Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 14, color: Mkt.inkSoft), const SizedBox(width: 5), Flexible(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(11.5, color: Mkt.inkSoft)))]);

  Widget _actionRow(BuildContext context, WidgetRef ref, MeetingRow m, ActionItemRow i) {
    final tracked = i.followUpId != null;
    return Padding(
      key: Key('co_mt_action_${i.id}'),
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        InkWell(
          key: Key('co_mt_action_done_${i.id}'),
          onTap: m.canEdit && !tracked ? () => _toggleDone(context, ref, m, i) : null,
          child: Padding(padding: const EdgeInsets.only(top: 1, right: 8), child: Icon(i.done ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded, size: 18, color: i.done ? Mkt.good : Mkt.inkSoft)),
        ),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(i.text, style: mktText(12, weight: FontWeight.w600, color: i.done ? Mkt.inkSoft : Mkt.ink)),
            Text([if (i.owner.isNotEmpty) i.owner, if (i.due != null) 'due ${coordDay(i.due, pattern: 'd MMM')}'].join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(10.5, color: Mkt.inkSoft)),
          ]),
        ),
        const SizedBox(width: 6),
        if (tracked)
          const MktChip('In Follow-ups', color: Mkt.primaryLight)
        else if (!i.done && i.due != null && m.canEdit)
          TextButton(
            key: Key('co_mt_followup_${i.id}'),
            style: TextButton.styleFrom(visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(horizontal: 8)),
            onPressed: () => coordQuickWrite(context, ref, () => ref.read(marketingCoordinationServiceProvider).actionItemToFollowUp(m.id, i.id ?? '')),
            child: Text('Make follow-up', style: mktText(11, weight: FontWeight.w700, color: Mkt.primary)),
          ),
      ]),
    );
  }
}
