import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/marketing/data/team_models.dart';
import 'package:nizan_crm/features/marketing/presentation/kit/mkt_kit.dart';
import 'package:nizan_crm/features/marketing/presentation/team/team_widgets.dart';
import 'package:nizan_crm/features/marketing/services/team_service.dart';

/// Team Dashboard → Overview, laid out as the marketing team's document draws it: six headline cards, then the team table beside
/// today's activity and the workload donut; the category bars beside the weekly trend and the attendance tiles; and the deadlines,
/// recent updates and key insights. Every number is counted from the team's logs and tasks (backend utils/marketingTeamStats.js):
/// log a piece of work once and it shows here, in the member table, today's feed, the donut, the trend and the attendance strip.
class TeamOverviewTab extends ConsumerWidget {
  const TeamOverviewTab({super.key, this.onSeeAll});

  /// Jump to another tab ("View All" links): 'activity', 'tasks', 'attendance'.
  final void Function(String tab)? onSeeAll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overview = ref.watch(teamOverviewProvider);
    return RefreshIndicator(
      onRefresh: () async => refreshTeam(ref),
      child: overview.when(
        loading: () => ListView(children: const [SizedBox(height: 200), Center(child: CircularProgressIndicator())]),
        error: (e, _) => ListView(children: [AppErrorView(error: e, onRetry: () => refreshTeam(ref))]),
        data: (o) {
          final k = o.kpis;
          String delta(int? v, String tail) => v == null ? '' : '${v >= 0 ? '↑ +' : '↓ −'}${v.abs()}% $tail';
          final tiles = <Widget>[
            MktKpiCard(
              key: const Key('team_kpi_members'),
              icon: Icons.groups_2_outlined,
              value: '${k.members}',
              label: 'Team Members',
              note: k.membersJoined > 0 ? '↑ +${k.membersJoined} this month' : null,
              good: k.membersJoined > 0 ? true : null,
              tint: Mkt.violet,
            ),
            MktKpiCard(
              key: const Key('team_kpi_completed'),
              icon: Icons.task_alt_rounded,
              value: '${k.tasksCompleted}',
              label: 'Tasks Completed',
              note: delta(k.tasksCompletedChange, 'vs before'),
              good: k.tasksCompletedChange == null ? null : k.tasksCompletedChange! >= 0,
              tint: Mkt.good,
            ),
            MktKpiCard(key: const Key('team_kpi_progress'), icon: Icons.layers_outlined, value: '${k.inProgress}', label: 'In Progress', tint: Mkt.blue),
            MktKpiCard(
              key: const Key('team_kpi_blocked'),
              icon: Icons.hourglass_bottom_rounded,
              value: '${k.pendingBlocked}',
              label: 'Pending / Blocked',
              note: k.pendingBlocked == 0 ? null : 'Needs attention',
              good: k.pendingBlocked == 0 ? null : false,
              tint: Mkt.warn,
            ),
            MktKpiCard(key: const Key('team_kpi_activity'), icon: Icons.bolt_rounded, value: pctText(k.activityRate), label: 'Team Activity Rate', tint: Mkt.violet2),
            MktKpiCard(key: const Key('team_kpi_ontime'), icon: Icons.verified_outlined, value: pctText(k.onTimeDelivery), label: 'On-time Delivery', tint: Mkt.teal),
          ];

          return ListView(
            key: const Key('team_overview_list'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            children: [
              MktKpiRow(children: tiles),
              const SizedBox(height: 12),
              MktGrid(
                rows: [
                  [
                    (5, _MembersCard(o: o, onSeeAll: () => onSeeAll?.call('performance'))),
                    (4, _FeedCard(o: o, onSeeAll: () => onSeeAll?.call('activity'))),
                    (3, _WorkloadCard(o: o)),
                  ],
                  [
                    (4, _CategoryCard(o: o)),
                    (5, _TrendCard(o: o)),
                    (3, _AttendanceCard(o: o, onSeeAll: () => onSeeAll?.call('attendance'))),
                  ],
                  [
                    (4, _DeadlinesCard(o: o, onSeeAll: () => onSeeAll?.call('tasks'))),
                    (4, _RecentCard(o: o, onSeeAll: () => onSeeAll?.call('activity'))),
                    (4, _InsightsCard(o: o)),
                  ],
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

Color _stateColor(String s) => switch (s) {
  'Active' => Mkt.good,
  'On Shoot' => Mkt.warn,
  'On Leave' => Mkt.blue,
  _ => Mkt.grey,
};

/// A stable colour for a role / category word, so the same role is always the same pill.
Color _wordColor(String w) => Mkt.series(w.codeUnits.fold<int>(0, (s, u) => s + u));

/// Which icon stands for a category in the progress card.
IconData categoryIcon(String name) {
  final n = name.toLowerCase();
  if (n.contains('video') || n.contains('shoot') || n.contains('reel') || n.contains('edit')) return Icons.videocam_outlined;
  if (n.contains('design') || n.contains('graphic') || n.contains('creative')) return Icons.palette_outlined;
  if (n.contains('campaign') || n.contains('ad')) return Icons.campaign_outlined;
  if (n.contains('social') || n.contains('post')) return Icons.share_outlined;
  if (n.contains('content') || n.contains('copy') || n.contains('blog')) return Icons.edit_note_rounded;
  if (n.contains('strateg') || n.contains('plan')) return Icons.flag_outlined;
  if (n.contains('meeting') || n.contains('coord')) return Icons.groups_2_outlined;
  if (n.contains('lead') || n.contains('sales')) return Icons.person_search_outlined;
  return Icons.folder_outlined;
}

/// The Overview shows the first few people; "View All" opens the Performance tab with everyone.
const _kMemberRows = 7;

class _MembersCard extends StatelessWidget {
  const _MembersCard({required this.o, this.onSeeAll});
  final TeamOverview o;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    return MktCard(
      title: 'Team Members',
      icon: Icons.groups_2_outlined,
      link: onSeeAll == null ? null : 'View All',
      onLink: onSeeAll,
      child: o.members.isEmpty
          ? const MktEmpty('No team members yet. Add them in EOD → Setup.', icon: Icons.groups_2_outlined)
          : MktTable(
              minWidth: 440,
              rowKeys: [for (final m in o.members.take(_kMemberRows)) Key('team_member_${m.memberId}')],
              columns: const [
                MktCol('Team Member', flex: 5),
                MktCol('Role', flex: 5),
                MktCol('Tasks', width: 48, align: Alignment.center),
                MktCol('Progress', flex: 3),
                MktCol('Activity', width: 84, align: Alignment.centerRight),
              ],
              rows: [
                for (final m in o.members.take(_kMemberRows))
                  [
                    Row(
                      children: [
                        MktAvatar(m.name),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(m.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(12.5, weight: FontWeight.w700)),
                        ),
                      ],
                    ),
                    m.role.isEmpty ? const SizedBox.shrink() : MktChip(m.role, color: _wordColor(m.role)),
                    Text('${m.tasks}', style: mktText(12.5, weight: FontWeight.w700)),
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: MktProgress(pct: m.progress, color: Mkt.good),
                    ),
                    MktChip(m.state, color: _stateColor(m.state)),
                  ],
              ],
            ),
    );
  }
}

class _FeedCard extends StatelessWidget {
  const _FeedCard({required this.o, this.onSeeAll});
  final TeamOverview o;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    final isToday = o.todayDay == TeamFilter.day(DateTime.now());
    return MktCard(
      title: o.todayDay.isEmpty
          ? 'Team Activity'
          : isToday
          ? "Today's Team Activity"
          : '${shortDay(o.todayDay)} Team Activity',
      icon: Icons.bolt_outlined,
      link: onSeeAll == null ? null : 'View All',
      linkKey: const Key('team_feed_view_all'),
      onLink: onSeeAll,
      child: o.todayFeed.isEmpty
          ? const MktEmpty('Nothing has been logged for the day yet.', icon: Icons.history_toggle_off_rounded)
          : MktTimeline(
              items: [
                for (final a in o.todayFeed.take(6))
                  MktTimelineItem(
                    key: Key('team_feed_${a.id}'),
                    time: timeOf(a.at),
                    title: '${a.member} · ${a.workedOn}',
                    subtitle: a.projectLabel,
                    color: workStatusColor(a.status),
                  ),
              ],
            ),
    );
  }
}

class _WorkloadCard extends StatelessWidget {
  const _WorkloadCard({required this.o});
  final TeamOverview o;

  @override
  Widget build(BuildContext context) {
    return MktCard(
      title: 'Department Workload',
      icon: Icons.donut_large_rounded,
      child: o.workload.isEmpty
          ? const MktEmpty('No work in this period.', icon: Icons.donut_large_rounded)
          : MktDonut(
              centerKey: const Key('team_workload_total'),
              centerValue: '${o.totalItems}',
              centerLabel: 'Total Tasks',
              slices: [for (final w in o.workload) (label: w.group, value: w.count.toDouble(), trailing: '${w.pct}% (${w.count})')],
            ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.o});
  final TeamOverview o;

  @override
  Widget build(BuildContext context) {
    return MktCard(
      title: 'Task Progress by Category',
      icon: Icons.stacked_bar_chart_rounded,
      child: o.progressByCategory.isEmpty
          ? const MktEmpty('No work in this period.', icon: Icons.stacked_bar_chart_rounded)
          : Column(
              children: [
                for (var i = 0; i < o.progressByCategory.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Icon(categoryIcon(o.progressByCategory[i].group), size: 17, color: Mkt.series(i)),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 100,
                          child: Text(o.progressByCategory[i].group, maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(12)),
                        ),
                        Expanded(
                          child: MktProgress(pct: o.progressByCategory[i].pct, color: Mkt.series(i)),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

class _TrendCard extends StatelessWidget {
  const _TrendCard({required this.o});
  final TeamOverview o;

  String _label(String day, int count) {
    final d = DateTime.tryParse(day);
    if (d == null) return '';
    return count <= 8 ? DateFormat('E').format(d) : DateFormat('d').format(d);
  }

  @override
  Widget build(BuildContext context) {
    final t = o.trend;
    final range = rangeLabel(DateTime.tryParse(o.from) ?? DateTime.now(), DateTime.tryParse(o.to) ?? DateTime.now());
    final maxCompleted = t.fold<int>(0, (m, p) => p.completed > m ? p.completed : m);
    final maxY = (maxCompleted < 4 ? 4 : maxCompleted + 1).toDouble();
    const left = 28.0, right = 38.0, bottom = 22.0;
    Widget legendDot(Color c, String label, {bool line = false}) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        line ? Container(width: 14, height: 3, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(2))) : Container(width: 9, height: 9, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 6),
        Text(label, style: mktText(11, color: Mkt.inkSoft)),
      ],
    );
    return MktCard(
      title: 'Weekly Activity Trend',
      subtitle: range,
      icon: Icons.show_chart_rounded,
      child: t.isEmpty
          ? const MktEmpty('Nothing in this period.', icon: Icons.show_chart_rounded)
          : Column(
              children: [
                // the bars (tasks done each day) and the line (share of the team that logged) share one plot area
                SizedBox(
                  height: 190,
                  child: Stack(
                    children: [
                      BarChart(
                        key: const Key('team_trend_bars'),
                        BarChartData(
                          maxY: maxY,
                          alignment: BarChartAlignment.spaceAround,
                          gridData: FlGridData(
                            drawVerticalLine: false,
                            horizontalInterval: maxCompleted < 4 ? 1 : null,
                            getDrawingHorizontalLine: (_) => const FlLine(color: Mkt.border, strokeWidth: 1),
                          ),
                          borderData: FlBorderData(show: false),
                          barTouchData: BarTouchData(enabled: false),
                          titlesData: FlTitlesData(
                            topTitles: const AxisTitles(),
                            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: right, getTitlesWidget: _none)),
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: left,
                                getTitlesWidget: (v, _) => v == v.roundToDouble() ? Text('${v.toInt()}', style: mktText(10, color: Mkt.inkSoft)) : const SizedBox.shrink(),
                              ),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: bottom,
                                getTitlesWidget: (v, _) => Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(_label(t[v.toInt()].day, t.length), style: mktText(10, color: Mkt.inkSoft)),
                                ),
                              ),
                            ),
                          ),
                          barGroups: [
                            for (var i = 0; i < t.length; i++)
                              BarChartGroupData(
                                x: i,
                                barRods: [BarChartRodData(toY: t[i].completed.toDouble(), color: Mkt.violet2, width: t.length > 14 ? 5 : 16, borderRadius: const BorderRadius.vertical(top: Radius.circular(5)))],
                              ),
                          ],
                        ),
                      ),
                      IgnorePointer(
                        child: LineChart(
                          key: const Key('team_trend_line'),
                          LineChartData(
                            minX: -0.5,
                            maxX: t.length - 0.5,
                            minY: 0,
                            maxY: 100,
                            gridData: const FlGridData(show: false),
                            borderData: FlBorderData(show: false),
                            lineTouchData: const LineTouchData(enabled: false),
                            titlesData: FlTitlesData(
                              topTitles: const AxisTitles(),
                              leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: left, getTitlesWidget: _none)),
                              bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: bottom, getTitlesWidget: _none)),
                              rightTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: right,
                                  interval: 25,
                                  getTitlesWidget: (v, _) => Padding(
                                    padding: const EdgeInsets.only(left: 6),
                                    child: Text('${v.toInt()}%', style: mktText(9.5, color: Mkt.inkSoft)),
                                  ),
                                ),
                              ),
                            ),
                            lineBarsData: [
                              LineChartBarData(
                                spots: [
                                  for (var i = 0; i < t.length; i++)
                                    if (t[i].activityPct != null) FlSpot(i.toDouble(), t[i].activityPct!.toDouble()),
                                ],
                                isCurved: true,
                                color: Mkt.blue,
                                barWidth: 2.5,
                                dotData: const FlDotData(show: true),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(spacing: 16, children: [legendDot(Mkt.violet2, 'Tasks Completed'), legendDot(Mkt.blue, 'Activity Rate', line: true)]),
              ],
            ),
    );
  }
}

Widget _none(double v, TitleMeta m) => const SizedBox.shrink();

class _AttendanceCard extends StatelessWidget {
  const _AttendanceCard({required this.o, this.onSeeAll});
  final TeamOverview o;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    final a = o.attendance;
    Widget tile(String label, int n, Color c, IconData icon) => Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      decoration: BoxDecoration(color: Mkt.tint(c, 0.10), borderRadius: BorderRadius.circular(12)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: c),
          const SizedBox(height: 6),
          Text('$n', style: mktText(20, weight: FontWeight.w800, color: c)),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(label, style: mktText(10.5, weight: FontWeight.w700, color: c)),
          ),
        ],
      ),
    );
    return MktCard(
      title: 'Team Attendance & Availability',
      subtitle: a.day.isEmpty ? null : shortDay(a.day),
      icon: Icons.event_available_outlined,
      link: onSeeAll == null ? null : 'View All',
      onLink: onSeeAll,
      child: Column(
        key: const Key('team_attendance_strip'),
        children: [
          Row(
            children: [
              Expanded(child: tile('Present', a.present, Mkt.good, Icons.person_outline)),
              const SizedBox(width: 8),
              Expanded(child: tile('On Shoot', a.onShoot, Mkt.warn, Icons.videocam_outlined)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: tile('On Leave', a.onLeave, Mkt.blue, Icons.beach_access_outlined)),
              const SizedBox(width: 8),
              Expanded(child: tile('Not in', a.absent, Mkt.grey, Icons.person_off_outlined)),
            ],
          ),
        ],
      ),
    );
  }
}

class _DeadlinesCard extends StatelessWidget {
  const _DeadlinesCard({required this.o, this.onSeeAll});
  final TeamOverview o;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    return MktCard(
      title: 'Upcoming Deadlines',
      icon: Icons.event_outlined,
      link: onSeeAll == null ? null : 'View All',
      onLink: onSeeAll,
      child: o.deadlines.isEmpty
          ? const MktEmpty('No open task has a deadline coming up.', icon: Icons.event_available_outlined)
          : Column(
              children: [
                for (final d in o.deadlines)
                  Padding(
                    key: Key('team_deadline_${d.id}'),
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(color: Mkt.tint(priorityColor(d.priority), 0.12), borderRadius: BorderRadius.circular(9)),
                          child: Icon(Icons.event_outlined, size: 16, color: priorityColor(d.priority)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(d.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(12.5, weight: FontWeight.w700)),
                              Text([if (d.project.isNotEmpty) d.project, if (d.assignee.isNotEmpty) d.assignee].join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(11, color: Mkt.inkSoft)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(shortDay(d.dueDate), style: mktText(11.5, weight: FontWeight.w700)),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

class _RecentCard extends StatelessWidget {
  const _RecentCard({required this.o, this.onSeeAll});
  final TeamOverview o;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    return MktCard(
      title: 'Recent Updates',
      icon: Icons.history_rounded,
      link: onSeeAll == null ? null : 'View All',
      onLink: onSeeAll,
      child: o.recentUpdates.isEmpty
          ? const MktEmpty('No updates yet.', icon: Icons.history_rounded)
          : Column(
              children: [
                for (final a in o.recentUpdates)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        MktAvatar(a.member, size: 28),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: a.member,
                                  style: mktText(12.5, weight: FontWeight.w700),
                                ),
                                TextSpan(text: '  ${a.workedOn}', style: mktText(12.5)),
                              ],
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(shortDay(a.day), style: mktText(11, color: Mkt.inkSoft)),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

class _InsightsCard extends StatelessWidget {
  const _InsightsCard({required this.o});
  final TeamOverview o;

  @override
  Widget build(BuildContext context) {
    return MktCard(
      title: 'Key Insights',
      icon: Icons.lightbulb_outline_rounded,
      child: Column(
        key: const Key('team_insights'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final line in o.insights)
            Container(
              margin: const EdgeInsets.symmetric(vertical: 3),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(color: Mkt.tint(Mkt.good, 0.07), borderRadius: BorderRadius.circular(10)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 1),
                    child: Icon(Icons.check_circle_rounded, size: 15, color: Mkt.good),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(line, style: mktText(12.5))),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
