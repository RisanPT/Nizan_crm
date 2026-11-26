import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/finance/utils/csv_export.dart';
import 'package:nizan_crm/features/marketing/data/team_models.dart';
import 'package:nizan_crm/features/marketing/presentation/kit/mkt_kit.dart';
import 'package:nizan_crm/features/marketing/presentation/team/log_activity_sheet.dart';
import 'package:nizan_crm/features/marketing/presentation/team/team_widgets.dart';
import 'package:nizan_crm/features/marketing/services/team_service.dart';

/// The Team Activity tab's views: the live feed, or the period read By Member / By Project / By Category.
enum ActivityView { feed, member, project, category }

/// Team Dashboard → Team Activity: the live feed of everybody's logs, newest first, with Today's Summary — and the same logs By Member,
/// By Project and By Category. Every cut is made on the server (kind, and the row a view was tapped for), so nothing is missed past the
/// first page; tapping a row of a view shows that row's logs in the feed.
class TeamActivityTab extends ConsumerStatefulWidget {
  const TeamActivityTab({super.key});

  @override
  ConsumerState<TeamActivityTab> createState() => _TeamActivityTabState();
}

class _TeamActivityTabState extends ConsumerState<TeamActivityTab> {
  ActivityView _view = ActivityView.feed;

  void _setQuery(ActivityQuery q) => ref.read(teamActivityQueryProvider.notifier).state = q;

  /// A row of a view was tapped: the feed shows its logs.
  void _narrow(ActivityView view, ActivityViewRow r) {
    final kind = ref.read(teamActivityQueryProvider).kind;
    _setQuery(switch (view) {
      ActivityView.member => ActivityQuery(kind: kind, memberId: r.key, label: r.label),
      ActivityView.project => ActivityQuery(kind: kind, project: r.key, label: r.label),
      _ => ActivityQuery(kind: kind, group: r.key, label: r.label),
    });
    setState(() => _view = ActivityView.feed);
  }

  @override
  Widget build(BuildContext context) {
    final feed = ref.watch(teamActivityProvider);
    final q = ref.watch(teamActivityQueryProvider);
    return RefreshIndicator(
      onRefresh: () async => refreshTeam(ref),
      child: feed.when(
        loading: () => ListView(children: const [SizedBox(height: 200), Center(child: CircularProgressIndicator())]),
        error: (e, _) => ListView(children: [AppErrorView(error: e, onRetry: () => refreshTeam(ref))]),
        data: (d) {
          final items = d.items;
          final s = d.summary;
          final summary = MktCard(
            title: "Today's Summary",
            subtitle: s.day.isEmpty ? null : shortDay(s.day),
            icon: Icons.insights_outlined,
            child: Column(
              key: const Key('team_activity_summary'),
              children: [
                _line('Activities logged', '${s.logged}', Icons.edit_note_rounded, Mkt.primary),
                _line('Completed', '${s.completed}', Icons.check_circle_outline_rounded, Mkt.good),
                _line('In progress', '${s.inProgress}', Icons.timelapse_rounded, Mkt.blue),
                _line('Meetings', '${s.meetings}', Icons.groups_2_outlined, Mkt.primaryLight),
                _line('Time logged', hoursLabel(s.minutes), Icons.schedule_rounded, Mkt.warn),
              ],
            ),
          );
          final views = SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              for (final v in const [(ActivityView.feed, 'Live Feed'), (ActivityView.member, 'By Member'), (ActivityView.project, 'By Project'), (ActivityView.category, 'By Category')])
                Padding(padding: const EdgeInsets.only(right: 6), child: MktFilterChip(key: Key('team_view_${v.$1.name}'), label: v.$2, selected: _view == v.$1, onTap: () => setState(() => _view = v.$1))),
            ]),
          );
          final Widget body = switch (_view) {
            ActivityView.feed => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        MktFilterChip(key: const Key('team_kind_all'), label: 'All', selected: q.kind == null, onTap: () => _setQuery(q.withKind(null))),
                        for (final k in ActivityKind.values)
                          Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: MktFilterChip(key: Key('team_kind_${k.wire}'), label: k.label, selected: q.kind == k, onTap: () => _setQuery(q.withKind(q.kind == k ? null : k))),
                          ),
                      ],
                    ),
                  ),
                  if (q.narrowed)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: InputChip(key: const Key('team_activity_narrowed'), label: Text('Showing: ${q.label}'), deleteIcon: const Icon(Icons.close_rounded, key: Key('team_activity_narrowed_clear'), size: 16), onDeleted: () => _setQuery(q.cleared)),
                    ),
                  const SizedBox(height: 10),
                  if (items.isEmpty) const MktEmpty('Nothing has been logged here yet.', icon: Icons.history_toggle_off_rounded),
                  for (var i = 0; i < items.length; i++) ...[
                    if (i > 0) const Divider(height: 1, color: Mkt.border),
                    _FeedRow(item: items[i]),
                  ],
                  if (d.total > items.length) Padding(padding: const EdgeInsets.only(top: 8), child: Text('Showing the newest ${items.length} of ${d.total} — export for all of them.', style: mktText(11, color: Mkt.inkSoft))),
                ],
              ),
            ActivityView.member => _ViewTable(keyPrefix: 'team_by_member', first: 'Member', rows: d.byMember, onTap: (r) => _narrow(ActivityView.member, r)),
            ActivityView.project => _ViewTable(keyPrefix: 'team_by_project', first: 'Project / client', rows: d.byProject, onTap: (r) => _narrow(ActivityView.project, r)),
            ActivityView.category => _ViewTable(keyPrefix: 'team_by_category', first: 'Category', rows: d.byCategory, onTap: (r) => _narrow(ActivityView.category, r)),
          };
          final list = MktCard(
            title: switch (_view) { ActivityView.feed => 'Live Feed', ActivityView.member => 'By Member', ActivityView.project => 'By Project', ActivityView.category => 'By Category' },
            subtitle: _view == ActivityView.feed ? '${d.total} log${d.total == 1 ? '' : 's'}${q.narrowed || q.kind != null ? ' match' : ' in this period'}' : 'The whole period · tap a row to see its logs',
            icon: Icons.bolt_outlined,
            trailing: TextButton.icon(key: const Key('team_activity_export'), onPressed: () => _export(d), icon: const Icon(Icons.download_rounded, size: 16), label: const Text('Export')),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [views, const SizedBox(height: 10), body]),
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

  /// The view on screen as a CSV: the feed's logs (all of them, up to 500), or the rows of the view.
  Future<void> _export(TeamActivityFeed d) async {
    try {
      if (_view == ActivityView.feed) {
        final all = d.total > d.items.length ? await ref.read(marketingTeamServiceProvider).activity(ref.read(teamFilterProvider), q: ref.read(teamActivityQueryProvider), limit: 500) : d;
        await downloadCsv('marketing-team-activity.csv', activityFeedCsv(all.items));
      } else {
        final rows = switch (_view) { ActivityView.member => d.byMember, ActivityView.project => d.byProject, _ => d.byCategory };
        await downloadCsv('marketing-team-activity-${_view.name}.csv', activityViewCsv(_view == ActivityView.member ? 'Member' : _view == ActivityView.project ? 'Project / client' : 'Category', rows));
      }
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    }
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

/// The feed's rows for a CSV (pure, so it can be checked).
List<List<Object?>> activityFeedCsv(List<TeamFeedItem> items) => [
      ['Date', 'Time', 'Member', 'Worked on', 'Project / client', 'Kind', 'Category', 'Brand', 'Status', 'Minutes'],
      for (final a in items) [a.day, timeOf(a.at), a.member, a.workedOn, a.projectLabel, a.kind.label, a.group.isEmpty ? 'Others' : a.group, a.brand.label, a.status.label, a.minutes],
    ];

/// A view's rows for a CSV.
List<List<Object?>> activityViewCsv(String first, List<ActivityViewRow> rows) => [
      [first, 'Logs', 'Hours', 'Completed'],
      for (final r in rows) [r.label, r.logs, (r.minutes / 60).toStringAsFixed(2), r.completed],
    ];

/// One of the By Member / By Project / By Category tables: logs, time and completed per row, the most logs first.
class _ViewTable extends StatelessWidget {
  const _ViewTable({required this.keyPrefix, required this.first, required this.rows, required this.onTap});
  final String keyPrefix, first;
  final List<ActivityViewRow> rows;
  final ValueChanged<ActivityViewRow> onTap;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const MktEmpty('Nothing has been logged in this period.', icon: Icons.history_toggle_off_rounded);
    final most = rows.fold<int>(0, (m, r) => r.logs > m ? r.logs : m);
    return MktTable(
      key: Key(keyPrefix),
      minWidth: 420,
      rowKeys: [for (final r in rows) Key('${keyPrefix}_${r.key}')],
      onRowTap: (i) => onTap(rows[i]),
      columns: [MktCol(first, flex: 5), const MktCol('Logs', flex: 3), const MktCol('Time', width: 70), const MktCol('Done', width: 50, align: Alignment.centerRight)],
      rows: [
        for (final r in rows)
          [
            Text(r.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(12.5, weight: FontWeight.w700)),
            Padding(padding: const EdgeInsets.only(right: 10), child: Row(children: [Expanded(child: MktProgress(pct: most == 0 ? 0 : (r.logs * 100 / most).round(), color: Mkt.primaryLight, showLabel: false)), const SizedBox(width: 6), Text('${r.logs}', style: mktText(12, weight: FontWeight.w700))])),
            Text(hoursLabel(r.minutes), style: mktText(12)),
            Text('${r.completed}', style: mktText(12, weight: FontWeight.w700)),
          ],
      ],
    );
  }
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
