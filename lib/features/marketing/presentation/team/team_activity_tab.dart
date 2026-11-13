import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/marketing/data/team_models.dart';
import 'package:nizan_crm/features/marketing/presentation/kit/mkt_kit.dart';
import 'package:nizan_crm/features/marketing/presentation/team/log_activity_sheet.dart';
import 'package:nizan_crm/features/marketing/presentation/team/team_widgets.dart';
import 'package:nizan_crm/features/marketing/services/team_service.dart';

/// Team Dashboard → Team Activity: the live feed of everybody's logs, newest first, with Today's Summary counted from the same logs.
class TeamActivityTab extends ConsumerStatefulWidget {
  const TeamActivityTab({super.key});

  @override
  ConsumerState<TeamActivityTab> createState() => _TeamActivityTabState();
}

class _TeamActivityTabState extends ConsumerState<TeamActivityTab> {
  ActivityKind? _kind;

  @override
  Widget build(BuildContext context) {
    final feed = ref.watch(teamActivityProvider);
    return RefreshIndicator(
      onRefresh: () async => refreshTeam(ref),
      child: feed.when(
        loading: () => ListView(children: const [SizedBox(height: 200), Center(child: CircularProgressIndicator())]),
        error: (e, _) => ListView(children: [AppErrorView(error: e, onRetry: () => refreshTeam(ref))]),
        data: (d) {
          final items = _kind == null ? d.items : d.items.where((a) => a.kind == _kind).toList();
          final s = d.summary;
          final summary = MktCard(
            title: "Today's Summary",
            subtitle: s.day.isEmpty ? null : shortDay(s.day),
            icon: Icons.insights_outlined,
            child: Column(
              key: const Key('team_activity_summary'),
              children: [
                _line('Activities logged', '${s.logged}', Icons.edit_note_rounded, Mkt.violet),
                _line('Completed', '${s.completed}', Icons.check_circle_outline_rounded, Mkt.good),
                _line('In progress', '${s.inProgress}', Icons.timelapse_rounded, Mkt.blue),
                _line('Meetings', '${s.meetings}', Icons.groups_2_outlined, Mkt.violet2),
                _line('Time logged', hoursLabel(s.minutes), Icons.schedule_rounded, Mkt.warn),
              ],
            ),
          );
          final list = MktCard(
            title: 'Live Feed',
            subtitle: '${d.total} log${d.total == 1 ? '' : 's'} in this period',
            icon: Icons.bolt_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      MktFilterChip(key: const Key('team_kind_all'), label: 'All', selected: _kind == null, onTap: () => setState(() => _kind = null)),
                      for (final k in ActivityKind.values)
                        Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: MktFilterChip(key: Key('team_kind_${k.wire}'), label: k.label, selected: _kind == k, onTap: () => setState(() => _kind = _kind == k ? null : k)),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                if (items.isEmpty) const MktEmpty('Nothing has been logged here yet.', icon: Icons.history_toggle_off_rounded),
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0) const Divider(height: 1, color: Mkt.border),
                  _FeedRow(item: items[i]),
                ],
              ],
            ),
          );
          return LayoutBuilder(
            builder: (context, box) {
              final wide = box.maxWidth >= 900;
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                children: [
                  if (wide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 7, child: list),
                        const SizedBox(width: 12),
                        Expanded(flex: 3, child: summary),
                      ],
                    )
                  else ...[
                    summary,
                    const SizedBox(height: 12),
                    list,
                  ],
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _line(String label, String value, IconData icon, Color color) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(color: Mkt.tint(color), borderRadius: BorderRadius.circular(9)),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(label, style: mktText(13))),
        Text(value, style: mktText(15, weight: FontWeight.w800)),
      ],
    ),
  );
}

class _FeedRow extends StatelessWidget {
  const _FeedRow({required this.item});
  final TeamFeedItem item;

  @override
  Widget build(BuildContext context) {
    final a = item;
    return Padding(
      key: Key('team_activity_${a.id}'),
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 62,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(shortDay(a.day), style: mktText(11, weight: FontWeight.w700)),
                Text(timeOf(a.at), style: mktText(10.5, color: Mkt.inkSoft)),
              ],
            ),
          ),
          MktAvatar(a.member),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${a.member} · ${a.workedOn}', style: mktText(13, weight: FontWeight.w700)),
                const SizedBox(height: 2),
                Wrap(
                  spacing: 8,
                  runSpacing: 3,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (a.projectLabel.isNotEmpty) Text(a.projectLabel, style: mktText(11.5, color: Mkt.inkSoft)),
                    if (a.minutes > 0) Text(hoursLabel(a.minutes), style: mktText(11.5, color: Mkt.inkSoft)),
                    if (a.brand == TeamBrand.kerala) const MktChip('Kerala', color: Mkt.blue),
                    if (a.legacy) const MktChip('Earlier entry', color: Mkt.grey),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          MktChip(a.status.label, color: workStatusColor(a.status)),
        ],
      ),
    );
  }
}

/// "My day": the logs for one day with their totals, and the Log Activity button — what the old EOD Entry tab was, built on the log.
class MyDayPanel extends ConsumerStatefulWidget {
  const MyDayPanel({super.key});

  @override
  ConsumerState<MyDayPanel> createState() => _MyDayPanelState();
}

class _MyDayPanelState extends ConsumerState<MyDayPanel> {
  DateTime _day = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final key = (date: TeamFilter.day(_day), memberId: null as String?);
    final setup = ref.watch(logSetupProvider(key));
    return setup.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => AppErrorView(error: e, onRetry: () => ref.invalidate(logSetupProvider(key))),
      data: (s) => ListView(
        key: const Key('my_day_list'),
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              IconButton(key: const Key('my_day_prev'), onPressed: () => setState(() => _day = _day.subtract(const Duration(days: 1))), icon: const Icon(Icons.chevron_left_rounded)),
              Text(rangeLabel(_day, _day), style: mktText(16, weight: FontWeight.w800)),
              IconButton(
                key: const Key('my_day_next'),
                onPressed: TeamFilter.day(_day) == TeamFilter.day(DateTime.now()) ? null : () => setState(() => _day = _day.add(const Duration(days: 1))),
                icon: const Icon(Icons.chevron_right_rounded),
              ),
              const Spacer(),
              MktPrimaryButton(key: const Key('my_day_log'), label: 'Log Activity', onPressed: s.canEdit ? () => showLogActivity(context, date: _day) : null),
            ],
          ),
          if (s.notice.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(s.notice, style: mktText(12.5, color: Mkt.inkSoft)),
            ),
          const SizedBox(height: 10),
          MktCard(
            title: 'Logged Today',
            subtitle: '${s.logs.length} log${s.logs.length == 1 ? '' : 's'} · ${hoursLabel(s.dayMinutes)}',
            icon: Icons.edit_calendar_outlined,
            child: s.logs.isEmpty
                ? const MktEmpty('Nothing logged for this day yet. Tap Log Activity to add what you worked on.', icon: Icons.edit_note_rounded)
                : Column(
                    children: [
                      for (final l in s.logs)
                        ListTile(
                          key: Key('my_day_log_${l.id}'),
                          contentPadding: EdgeInsets.zero,
                          leading: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(color: Mkt.tint(workStatusColor(l.status)), borderRadius: BorderRadius.circular(10)),
                            child: Icon(kindIcon(l.kind), size: 18, color: workStatusColor(l.status)),
                          ),
                          title: Text(l.workedOn, style: mktText(13.5, weight: FontWeight.w700)),
                          subtitle: Text(
                            [timeOf(l.loggedAt), if (l.projectLabel.isNotEmpty) l.projectLabel, if (l.minutes > 0) hoursLabel(l.minutes), l.status.label].where((x) => x.isNotEmpty).join(' · '),
                            style: mktText(11.5, color: Mkt.inkSoft),
                          ),
                          trailing: l.legacy
                              ? const MktChip('Earlier entry', color: Mkt.grey)
                              : Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(key: Key('my_day_edit_${l.id}'), tooltip: 'Change', onPressed: s.canEdit ? () => showLogActivity(context, date: _day, editing: l) : null, icon: const Icon(Icons.edit_outlined, size: 18)),
                                    IconButton(key: Key('my_day_delete_${l.id}'), tooltip: 'Delete', onPressed: s.canEdit ? () => _delete(l) : null, icon: const Icon(Icons.delete_outline_rounded, size: 18)),
                                  ],
                                ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _delete(SavedLog l) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete this log?'),
        content: Text('"${l.workedOn}" will be removed, and the day\'s totals will drop by it.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(key: const Key('my_day_delete_confirm'), onPressed: () => Navigator.pop(c, true), child: const Text('Delete')),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    try {
      await ref.read(marketingTeamServiceProvider).deleteLog(l.id);
      refreshTeam(ref);
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    }
  }
}
