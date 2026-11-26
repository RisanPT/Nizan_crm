import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/finance/utils/csv_export.dart';
import 'package:nizan_crm/features/marketing/presentation/kit/mkt_kit.dart';
import 'package:nizan_crm/features/marketing/data/team_models.dart';
import 'package:nizan_crm/features/marketing/presentation/team/team_widgets.dart';
import 'package:nizan_crm/features/marketing/services/team_service.dart';
import 'package:nizan_crm/features/marketing/presentation/reports/marketing_reports_panel.dart';
import 'package:nizan_crm/features/marketing/services/marketing_reports_service.dart';

const _kHead = TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Mkt.inkSoft);

/// The four parts of Logs & Timesheet.
enum LogsPart { daily, timesheet, summary, report }

/// Team Dashboard → Logs & Timesheet: the Daily Logs (every entry, with all it says), the Timesheet (hours per person per day and how the
/// time splits across the categories), the Work Summary (per member: what they completed, what is pending, their next priority) and the
/// Activity Report (the counts per activity and group) — the same logs read four ways, each with its own export.
class TeamTimesheetTab extends ConsumerStatefulWidget {
  const TeamTimesheetTab({super.key});

  @override
  ConsumerState<TeamTimesheetTab> createState() => _TeamTimesheetTabState();
}

class _TeamTimesheetTabState extends ConsumerState<TeamTimesheetTab> {
  LogsPart _part = LogsPart.daily;

  @override
  Widget build(BuildContext context) {
    final picker = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        for (final p in const [(LogsPart.daily, 'Daily Logs'), (LogsPart.timesheet, 'Timesheet'), (LogsPart.summary, 'Work Summary'), (LogsPart.report, 'Activity Report')])
          Padding(padding: const EdgeInsets.only(right: 6), child: MktFilterChip(key: Key('team_logs_${p.$1.name}'), label: p.$2, selected: _part == p.$1, onTap: () => setState(() => _part = p.$1))),
      ]),
    );
    final Widget part = _part == LogsPart.daily ? _dailyLogs() : _sheetPart();
    return RefreshIndicator(
      onRefresh: () async => refreshTeam(ref),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [picker, const SizedBox(height: 10), part],
      ),
    );
  }

  Widget _dailyLogs() {
    final logs = ref.watch(teamLogsProvider);
    return logs.when(
      loading: () => const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator())),
      error: (e, _) => AppErrorView(error: e, onRetry: () => refreshTeam(ref)),
      data: (d) {
        final pages = (d.total / d.pageSize).ceil().clamp(1, 9999);
        return MktCard(
          title: 'Daily Logs',
          subtitle: '${d.total} log${d.total == 1 ? '' : 's'} · ${hoursLabel(d.totalMinutes)}',
          icon: Icons.edit_note_rounded,
          trailing: TextButton.icon(
            key: const Key('team_logs_export'),
            onPressed: () async {
              try {
                final all = d.total > d.items.length ? await ref.read(marketingTeamServiceProvider).logs(ref.read(teamFilterProvider), limit: 200) : d;
                await downloadCsv('marketing-daily-logs.csv', dailyLogsCsv(all.items));
              } catch (e) {
                if (mounted) showErrorSnackBar(context, e);
              }
            },
            icon: const Icon(Icons.download_rounded, size: 16),
            label: const Text('Export'),
          ),
          child: d.items.isEmpty
              ? const MktEmpty('Nothing was logged in this period.', icon: Icons.edit_note_rounded)
              : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  for (var i = 0; i < d.items.length; i++) ...[
                    if (i > 0) const Divider(height: 1, color: Mkt.border),
                    _DailyLogRow(e: d.items[i]),
                  ],
                  if (pages > 1)
                    Row(children: [
                      Text('Page ${d.page} of $pages', style: mktText(11.5, color: Mkt.inkSoft)),
                      const Spacer(),
                      IconButton(key: const Key('team_logs_prev'), onPressed: d.page > 1 ? () => ref.read(teamLogsPageProvider.notifier).state = d.page - 1 : null, icon: const Icon(Icons.chevron_left_rounded)),
                      IconButton(key: const Key('team_logs_next'), onPressed: d.page < pages ? () => ref.read(teamLogsPageProvider.notifier).state = d.page + 1 : null, icon: const Icon(Icons.chevron_right_rounded)),
                    ]),
                ]),
        );
      },
    );
  }

  Widget _sheetPart() {
    final sheet = ref.watch(teamTimesheetProvider);
    return sheet.when(
      loading: () => const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator())),
      error: (e, _) => AppErrorView(error: e, onRetry: () => refreshTeam(ref)),
      data: (t) => switch (_part) {
        LogsPart.summary => _WorkSummaryCard(t: t),
        LogsPart.report => _ActivityReportCard(t: t),
        _ => _timesheet(t),
      },
    );
  }

  Widget _timesheet(Timesheet t) {
    final shownDays = t.days.length > 14 ? t.days.sublist(t.days.length - 14) : t.days;
    final tbShown = t.timebox.live;
    final table = MktCard(
      title: 'Timesheet',
      subtitle: tbShown ? 'Logged ${t.totalLabel} · Timebox ${t.timeboxTotalLabel}' : 'Total ${t.totalLabel}',
      icon: Icons.schedule_rounded,
      trailing: TextButton.icon(
        key: const Key('team_timesheet_export'),
        onPressed: () => downloadCsv('marketing-timesheet.csv', [
          ['Member', 'Role', 'Logs', 'Days logged', 'Hours logged', 'Timebox hours', ...t.days],
          for (final r in t.rows)
            [r.name, r.role, r.logs, r.daysLogged, (r.minutes / 60).toStringAsFixed(2), r.timeboxMinutes == null ? '' : (r.timeboxMinutes! / 60).toStringAsFixed(2), ...t.days.map((d) => ((r.byDay[d] ?? 0) / 60).toStringAsFixed(2))],
        ]),
        icon: const Icon(Icons.download_rounded, size: 16),
        label: const Text('Export'),
      ),
      child: t.rows.isEmpty
          ? const MktEmpty('No team members.', icon: Icons.schedule_rounded)
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                key: const Key('team_timesheet_table'),
                headingTextStyle: _kHead,
                headingRowHeight: 38,
                dataRowMinHeight: 40,
                dataRowMaxHeight: 44,
                columns: [
                  const DataColumn(label: Text('Member')),
                  const DataColumn(label: Text('Logged')),
                  if (tbShown) const DataColumn(label: Tooltip(message: 'The hours Timebox counted from punch-in to punch-out (after lunch)', child: Text('Timebox'))),
                  for (final d in shownDays) DataColumn(label: Text(DateFormat('E d').format(DateTime.parse(d)), style: const TextStyle(fontSize: 11))),
                  const DataColumn(label: Text('Status')),
                ],
                rows: [
                  for (final r in t.rows)
                    DataRow(key: ValueKey('team_timesheet_${r.memberId}'), cells: [
                      DataCell(Row(children: [MemberAvatar(r.name, size: 24), const SizedBox(width: 8), Text(r.name)])),
                      DataCell(Text(r.label, style: const TextStyle(fontWeight: FontWeight.w700))),
                      if (tbShown) DataCell(Text(r.timeboxMinutes == null ? '—' : r.timeboxLabel, key: ValueKey('team_timesheet_tb_${r.memberId}'), style: TextStyle(fontWeight: FontWeight.w700, color: r.timeboxMinutes == null ? Mkt.inkSoft : Mkt.good))),
                      for (final d in shownDays) DataCell(Text(hoursLabel(r.byDay[d] ?? 0), style: TextStyle(color: (r.byDay[d] ?? 0) == 0 ? Mkt.inkSoft : Mkt.ink))),
                      DataCell(MktChip(r.status, color: r.status == 'Submitted' ? kTeamGood : kTeamGrey)),
                    ]),
                ],
              ),
            ),
    );
    final split = MktCard(
      title: 'Time distribution',
      icon: Icons.pie_chart_outline_rounded,
      child: t.split.isEmpty
          ? const MktEmpty('No time logged.', icon: Icons.pie_chart_outline_rounded)
          : MktDonut(
              centerKey: const Key('team_timesheet_total'),
              centerValue: t.totalLabel,
              centerLabel: 'Logged',
              slices: [for (final g in t.split) (label: g.group, value: g.minutes.toDouble(), trailing: '${g.pct}% · ${hoursLabel(g.minutes)}')],
            ),
    );
    return LayoutBuilder(builder: (context, box) {
      final wide = box.maxWidth >= 1000;
      final body = wide ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(flex: 8, child: table), const SizedBox(width: 12), Expanded(flex: 4, child: split)]) : Column(children: [table, const SizedBox(height: 12), split]);
      // without Timebox the timesheet has only the logged hours: say why there is no Timebox column
      return tbShown ? body : Column(children: [TimeboxBanner(info: t.timebox, what: 'Hours'), const SizedBox(height: 10), body]);
    });
  }
}

/// Every log of the period for a CSV (pure, so it can be checked).
List<List<Object?>> dailyLogsCsv(List<DailyLogEntry> items) => [
      ['Date', 'Time', 'Member', 'Worked on', 'Project / client', 'Category', 'Status', 'Minutes', 'Completed', 'Pending', 'Next priority', 'Counts'],
      for (final e in items)
        [e.item.day, timeOf(e.item.at), e.item.member, e.item.workedOn, e.item.projectLabel, e.item.group.isEmpty ? 'Others' : e.item.group, e.item.status.label, e.item.minutes, e.completed, e.pending, e.nextPriority, e.counts.map((c) => '${c.metric}: ${_num(c.value)}').join('; ')],
    ];

String _num(num v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();

class _DailyLogRow extends StatelessWidget {
  const _DailyLogRow({required this.e});
  final DailyLogEntry e;

  @override
  Widget build(BuildContext context) {
    final a = e.item;
    Widget line(String label, String text) => text.isEmpty
        ? const SizedBox.shrink()
        : Padding(padding: const EdgeInsets.only(top: 2), child: Text.rich(TextSpan(children: [TextSpan(text: '$label  ', style: mktText(11, weight: FontWeight.w700, color: Mkt.inkSoft)), TextSpan(text: text, style: mktText(12))])));
    return Padding(
      key: Key('team_log_${a.id}'),
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 62, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(shortDay(a.day), style: mktText(11, weight: FontWeight.w700)), Text(timeOf(a.at), style: mktText(10.5, color: Mkt.inkSoft))])),
        MktAvatar(a.member),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${a.member} · ${a.workedOn}', style: mktText(13, weight: FontWeight.w700)),
            Text([if (a.projectLabel.isNotEmpty) a.projectLabel, a.group.isEmpty ? 'Others' : a.group, if (a.minutes > 0) hoursLabel(a.minutes)].join(' · '), style: mktText(11.5, color: Mkt.inkSoft)),
            line('Completed', e.completed),
            line('Pending', e.pending),
            line('Next', e.nextPriority),
            if (e.counts.isNotEmpty) line('Counts', e.counts.map((c) => '${c.metric} ${_num(c.value)}').join(' · ')),
          ]),
        ),
        const SizedBox(width: 8),
        MktChip(a.status.label, color: workStatusColor(a.status)),
      ]),
    );
  }
}

class _WorkSummaryCard extends StatelessWidget {
  const _WorkSummaryCard({required this.t});
  final Timesheet t;

  @override
  Widget build(BuildContext context) => MktCard(
        title: 'Work Summary',
        subtitle: 'Per member, from their logs in this period',
        icon: Icons.assignment_turned_in_outlined,
        trailing: TextButton.icon(key: const Key('team_summary_export'), onPressed: () => downloadCsv('marketing-work-summary.csv', workSummaryCsv(t.workSummary)), icon: const Icon(Icons.download_rounded, size: 16), label: const Text('Export')),
        child: t.workSummary.isEmpty
            ? const MktEmpty('No team members.', icon: Icons.assignment_turned_in_outlined)
            : Column(children: [
                for (final w in t.workSummary)
                  Container(
                    key: Key('team_summary_${w.memberId}'),
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Mkt.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: Mkt.border)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        MktAvatar(w.name),
                        const SizedBox(width: 8),
                        Expanded(child: Text(w.name, style: mktText(13.5, weight: FontWeight.w800))),
                        Text(w.logs == 0 ? 'Nothing logged' : '${w.logs} log${w.logs == 1 ? '' : 's'} · ${hoursLabel(w.minutes)}${w.lastDay == null ? '' : ' · last ${shortDay(w.lastDay!)}'}', style: mktText(11.5, color: Mkt.inkSoft)),
                      ]),
                      const SizedBox(height: 8),
                      Text('COMPLETED (${w.completedCount})', style: mktText(10, weight: FontWeight.w800, color: Mkt.inkSoft, spacing: 0.6)),
                      if (w.completed.isEmpty) Text('—', style: mktText(12, color: Mkt.inkSoft)) else for (final c in w.completed) Text('• $c', style: mktText(12)),
                      const SizedBox(height: 6),
                      Text('PENDING', style: mktText(10, weight: FontWeight.w800, color: Mkt.inkSoft, spacing: 0.6)),
                      Text(w.pending.isEmpty ? '—' : w.pending, style: mktText(12, color: w.pending.isEmpty ? Mkt.inkSoft : Mkt.ink)),
                      const SizedBox(height: 6),
                      Text('NEXT PRIORITY', style: mktText(10, weight: FontWeight.w800, color: Mkt.inkSoft, spacing: 0.6)),
                      Text(w.nextPriority.isEmpty ? '—' : w.nextPriority, style: mktText(12, color: w.nextPriority.isEmpty ? Mkt.inkSoft : Mkt.ink)),
                    ]),
                  ),
              ]),
      );
}

List<List<Object?>> workSummaryCsv(List<WorkSummaryRow> rows) => [
      ['Member', 'Role', 'Logs', 'Hours', 'Completed logs', 'What was completed', 'Pending', 'Next priority', 'Last log'],
      for (final w in rows) [w.name, w.role, w.logs, (w.minutes / 60).toStringAsFixed(2), w.completedCount, w.completed.join(' | '), w.pending, w.nextPriority, w.lastDay ?? ''],
    ];

class _ActivityReportCard extends StatelessWidget {
  const _ActivityReportCard({required this.t});
  final Timesheet t;

  @override
  Widget build(BuildContext context) => MktCard(
        title: 'Activity Report',
        subtitle: 'The counts logged in this period, per activity and group',
        icon: Icons.bar_chart_rounded,
        trailing: TextButton.icon(key: const Key('team_report_activity_export'), onPressed: () => downloadCsv('marketing-activity-report.csv', activityReportCsv(t.activityReport)), icon: const Icon(Icons.download_rounded, size: 16), label: const Text('Export')),
        child: t.activityReport.isEmpty
            ? const MktEmpty('No counts were logged in this period.', icon: Icons.bar_chart_rounded)
            : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final g in t.activityGroups) MktChip('${g.group}: ${_num(g.total)}', color: Mkt.primaryLight),
                ]),
                const SizedBox(height: 10),
                MktTable(
                  key: const Key('team_activity_report_table'),
                  minWidth: 460,
                  columns: const [MktCol('Activity', flex: 5), MktCol('Group', flex: 3), MktCol('Total', width: 80, align: Alignment.centerRight), MktCol('Logs', width: 56, align: Alignment.centerRight), MktCol('People', width: 60, align: Alignment.centerRight)],
                  rows: [
                    for (final r in t.activityReport)
                      [
                        Text(r.metric, maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(12.5, weight: FontWeight.w700)),
                        Text(r.group, style: mktText(12, color: Mkt.inkSoft)),
                        Text(r.isMoney ? '₹${_num(r.total)}' : _num(r.total), style: mktText(12.5, weight: FontWeight.w800)),
                        Text('${r.logs}', style: mktText(12)),
                        Text('${r.members}', style: mktText(12)),
                      ],
                  ],
                ),
              ]),
      );
}

List<List<Object?>> activityReportCsv(List<ActivityReportRow> rows) => [
      ['Activity', 'Group', 'Total', 'Logs', 'People'],
      for (final r in rows) [r.metric, r.group, r.total, r.logs, r.members],
    ];

/// Team Dashboard → Performance: each person's task completion, on-time delivery, activity rate and lead → booking (the CRM leads given
/// to them, by the Lead Report's rules), with their own weekly trend; and the team's weekly trend.
class TeamPerformanceTab extends ConsumerWidget {
  const TeamPerformanceTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perf = ref.watch(teamPerformanceProvider);
    return RefreshIndicator(
      onRefresh: () async => refreshTeam(ref),
      child: perf.when(
        loading: () => ListView(children: const [SizedBox(height: 200), Center(child: CircularProgressIndicator())]),
        error: (e, _) => ListView(children: [AppErrorView(error: e, onRetry: () => refreshTeam(ref))]),
        data: (p) {
          Widget cell(int? v) => SizedBox(width: 120, child: v == null ? Text('—', style: TextStyle(color: Mkt.inkSoft)) : MktProgress(pct: v, color: v >= 80 ? Mkt.good : (v >= 50 ? Mkt.warn : Mkt.bad)));
          return ListView(
            key: const Key('team_performance_list'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              MktKpiRow(children: [
                MktKpiCard(key: const Key('team_perf_activity'), icon: Icons.bolt_rounded, label: 'Team activity rate', value: pctText(p.activityRate), tint: Mkt.primaryLight),
                MktKpiCard(key: const Key('team_perf_tasks'), icon: Icons.task_alt_rounded, label: 'Tasks completed', value: '${p.tasksCompleted}', tint: Mkt.good),
                MktKpiCard(key: const Key('team_perf_ontime'), icon: Icons.verified_outlined, label: 'On-time delivery', value: pctText(p.onTimeDelivery), tint: Mkt.blue),
                MktKpiCard(key: const Key('team_perf_l2b'), icon: Icons.trending_up_rounded, label: 'Lead → booking', value: rateText(p.leadToBooking), note: p.leads == null ? 'No member has a login with leads' : '${p.leads} lead${p.leads == 1 ? '' : 's'} given to the team', tint: Mkt.teal),
              ]),
              const SizedBox(height: 12),
              MktCard(
                title: 'Team performance',
                subtitle: 'Best first',
                icon: Icons.leaderboard_outlined,
                trailing: TextButton.icon(key: const Key('team_perf_export'), onPressed: () => downloadCsv('marketing-performance.csv', performanceCsv(p.rows)), icon: const Icon(Icons.download_rounded, size: 16), label: const Text('Export')),
                child: p.rows.isEmpty
                    ? const MktEmpty('No team members.', icon: Icons.leaderboard_outlined)
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          key: const Key('team_performance_table'),
                          headingTextStyle: _kHead,
                      headingRowHeight: 38,
                          dataRowMinHeight: 42,
                          columns: const [DataColumn(label: Text('Member')), DataColumn(label: Text('Task completion')), DataColumn(label: Text('On-time delivery')), DataColumn(label: Text('Activity rate')), DataColumn(label: Text('Lead → booking')), DataColumn(label: Text('Overall')), DataColumn(label: Text('Weekly trend'))],
                          rows: [
                            for (final r in p.rows)
                              DataRow(key: ValueKey('team_perf_${r.memberId}'), cells: [
                                DataCell(Row(children: [MemberAvatar(r.name, size: 24), const SizedBox(width: 8), Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [Text(r.name, style: const TextStyle(fontWeight: FontWeight.w700)), if (r.role.isNotEmpty) Text(r.role, style: TextStyle(fontSize: 10.5, color: Mkt.inkSoft))])])),
                                DataCell(cell(r.completion)),
                                DataCell(cell(r.onTime)),
                                DataCell(cell(r.activityRate)),
                                DataCell(Tooltip(
                                  message: r.leads == null ? 'No login linked, so no CRM leads' : '${r.booked ?? 0} booked of ${r.leads} lead${r.leads == 1 ? '' : 's'}',
                                  child: Text(r.leads == null ? '—' : '${rateText(r.leadToBooking)}  (${r.booked ?? 0}/${r.leads})', key: ValueKey('team_perf_l2b_${r.memberId}')),
                                )),
                                DataCell(Text(pctText(r.overall), style: const TextStyle(fontWeight: FontWeight.w800))),
                                DataCell(_MemberTrend(key: ValueKey('team_perf_trend_${r.memberId}'), weeks: r.trend)),
                              ]),
                          ],
                        ),
                      ),
              ),
              const SizedBox(height: 12),
              MktCard(
                title: 'Performance trend',
                subtitle: 'Of the tasks due each week: the share completed, and the share of those on time',
                icon: Icons.show_chart_rounded,
                child: p.trend.every((w) => w.completion == null && w.onTime == null)
                    ? const MktEmpty('No task fell due in this period.', icon: Icons.show_chart_rounded)
                    : SizedBox(
                        key: const Key('team_performance_trend'),
                        height: 150,
                        child: LineChart(LineChartData(
                          minY: 0,
                          maxY: 100,
                          gridData: FlGridData(drawVerticalLine: false, horizontalInterval: 25, getDrawingHorizontalLine: (_) => FlLine(color: Mkt.border, strokeWidth: 1)),
                          borderData: FlBorderData(show: false),
                          titlesData: FlTitlesData(
                            topTitles: const AxisTitles(),
                            rightTitles: const AxisTitles(),
                            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 34, interval: 25, getTitlesWidget: (v, _) => Text('${v.toInt()}%', style: TextStyle(fontSize: 10, color: Mkt.inkSoft)))),
                            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 22, interval: 1, getTitlesWidget: (v, _) => Text('Wk ${v.toInt() + 1}', style: TextStyle(fontSize: 10, color: Mkt.inkSoft)))),
                          ),
                          lineBarsData: [
                            LineChartBarData(spots: [for (var i = 0; i < p.trend.length; i++) if (p.trend[i].completion != null) FlSpot(i.toDouble(), p.trend[i].completion!.toDouble())], isCurved: true, color: Mkt.primary, barWidth: 2.5),
                            LineChartBarData(spots: [for (var i = 0; i < p.trend.length; i++) if (p.trend[i].onTime != null) FlSpot(i.toDouble(), p.trend[i].onTime!.toDouble())], isCurved: true, color: kTeamGood, barWidth: 2.5),
                          ],
                        )),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// "33.3%" for a rate with one decimal, "—" for none.
String rateText(double? v) => v == null ? '—' : '${v == v.roundToDouble() ? v.toInt() : v}%';

/// The performance table for a CSV (pure, so it can be checked). A figure nobody can know is blank, never 0.
List<List<Object?>> performanceCsv(List<PerformanceRow> rows) => [
      ['Member', 'Role', 'Tasks in scope', 'Task completion %', 'On-time %', 'Activity rate %', 'Leads', 'Booked', 'Lead → booking %', 'Overall %'],
      for (final r in rows) [r.name, r.role, r.tasks, r.completion ?? '', r.onTime ?? '', r.activityRate ?? '', r.leads ?? '', r.booked ?? '', r.leadToBooking ?? '', r.overall ?? ''],
    ];

/// A member's weekly activity rate as a small line (and "—" when no week could be measured).
class _MemberTrend extends StatelessWidget {
  const _MemberTrend({super.key, required this.weeks});
  final List<MemberWeek> weeks;

  @override
  Widget build(BuildContext context) {
    final values = [for (final w in weeks) if (w.activityPct != null) w.activityPct!.toDouble()];
    if (values.length < 2) return Text(values.isEmpty ? '—' : '${values.first.toInt()}%', style: const TextStyle(color: Mkt.inkSoft));
    return Tooltip(
      message: [for (final w in weeks) 'Wk ${w.week}: ${pctText(w.activityPct)} active${w.completion == null ? '' : ', ${w.completion}% of tasks due done'}'].join('\n'),
      child: SizedBox(width: 90, height: 28, child: MktSparkline(values: values, color: values.last >= values.first ? Mkt.good : Mkt.bad)),
    );
  }
}

/// Team Dashboard → Attendance: who is in the Office, On Shoot, Working From Home, On Leave or not in yet on a day, each person's rate for
/// the month, and the way to say how you are working today (a manager can set it for anyone).
class TeamAttendanceTab extends ConsumerStatefulWidget {
  const TeamAttendanceTab({super.key});

  @override
  ConsumerState<TeamAttendanceTab> createState() => _TeamAttendanceTabState();
}

class _TeamAttendanceTabState extends ConsumerState<TeamAttendanceTab> {
  DateTime _day = DateTime.now();

  Future<void> _setMode(WorkMode? mode, String day, String? memberId) async {
    try {
      await ref.read(marketingTeamServiceProvider).setWorkMode(mode, day: day, memberId: memberId);
      refreshTeam(ref);
    } on TeamRefusal catch (r) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(r.message)));
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    }
  }

  Future<void> _pick() async {
    final now = DateTime.now();
    final d = await showDatePicker(context: context, initialDate: _day, firstDate: DateTime(now.year - 1), lastDate: now);
    if (d != null) setState(() => _day = d);
  }

  @override
  Widget build(BuildContext context) {
    final key = TeamFilter.day(_day);
    final data = ref.watch(teamAttendanceProvider(key));
    return RefreshIndicator(
      onRefresh: () async => refreshTeam(ref),
      child: data.when(
        loading: () => ListView(children: const [SizedBox(height: 200), Center(child: CircularProgressIndicator())]),
        error: (e, _) => ListView(children: [AppErrorView(error: e, onRetry: () => refreshTeam(ref))]),
        data: (a) {
          final s = a.summary;
          return ListView(
            key: const Key('team_attendance_list'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                MktPill(key: const Key('team_attendance_day'), label: DateFormat('EEE d MMM yyyy').format(_day), icon: Icons.calendar_today_outlined, onTap: _pick),
                if (a.canSetOwn) _OwnModePicker(rows: a.rows, onSet: (m) => _setMode(m, key, null)),
              ]),
              const SizedBox(height: 10),
              TimeboxBanner(info: a.timebox, what: 'Attendance'),
              const SizedBox(height: 10),
              MktKpiRow(minWidth: 150, children: [
                MktKpiCard(key: const Key('team_att_present'), icon: Icons.person_outline, label: 'Present (office)', value: '${s.present}', tint: Mkt.good),
                MktKpiCard(key: const Key('team_att_shoot'), icon: Icons.videocam_outlined, label: 'On shoot', value: '${s.onShoot}', tint: Mkt.warn),
                MktKpiCard(key: const Key('team_att_wfh'), icon: Icons.home_work_outlined, label: 'Work from home', value: '${s.wfh}', tint: Mkt.teal),
                MktKpiCard(key: const Key('team_att_leave'), icon: Icons.beach_access_outlined, label: 'On leave', value: '${s.onLeave}', tint: Mkt.blue),
                MktKpiCard(key: const Key('team_att_absent'), icon: Icons.person_off_outlined, label: 'Not in', value: '${s.absent}', tint: Mkt.grey),
                MktKpiCard(key: const Key('team_att_rate'), icon: Icons.donut_large_rounded, label: 'Attendance rate (month)', value: pctText(a.rate), note: a.rate == null ? 'No login linked and no work mode set yet' : (a.timebox.live ? 'as Timebox counts it' : null), tint: Mkt.primary),
              ]),
              const SizedBox(height: 12),
              MktCard(
                title: 'Attendance & availability',
                icon: Icons.event_available_outlined,
                trailing: TextButton.icon(key: const Key('team_att_export'), onPressed: () => downloadCsv('marketing-attendance-$key.csv', attendanceCsv(a)), icon: const Icon(Icons.download_rounded, size: 16), label: const Text('Export')),
                child: a.rows.isEmpty
                    ? const MktEmpty('No team members.', icon: Icons.event_available_outlined)
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          key: const Key('team_attendance_table'),
                          headingTextStyle: _kHead,
                      headingRowHeight: 38,
                          columns: const [DataColumn(label: Text('Member')), DataColumn(label: Text('Check-in')), DataColumn(label: Text('Check-out')), DataColumn(label: Text('Hours')), DataColumn(label: Text('Work mode')), DataColumn(label: Text('Status')), DataColumn(label: Text('Timebox plan')), DataColumn(label: Text('Month'))],
                          rows: [
                            for (final r in a.rows)
                              DataRow(key: ValueKey('team_att_row_${r.memberId}'), cells: [
                                DataCell(Row(children: [
                                  MemberAvatar(r.name, size: 24),
                                  const SizedBox(width: 8),
                                  Text(r.name),
                                  const SizedBox(width: 6),
                                  if (r.fromTimebox)
                                    Tooltip(message: r.timeboxLink == 'name' ? 'From Timebox (matched by name — link their login to be sure)' : 'From Timebox', child: Icon(Icons.verified_outlined, key: ValueKey('team_att_tb_${r.memberId}'), size: 15, color: Mkt.good))
                                  else if (r.source == 'logs')
                                    const Tooltip(message: 'Only a work log — no attendance record', child: Icon(Icons.edit_note_rounded, size: 15, color: Mkt.inkSoft)),
                                ])),
                                DataCell(Text(r.checkIn == null ? '—' : timeOf(r.checkIn))),
                                DataCell(Text(r.checkOut == null ? (r.stillIn ? 'still in' : '—') : timeOf(r.checkOut), key: ValueKey('team_att_out_${r.memberId}'))),
                                DataCell(Text(r.hours == null ? '—' : '${r.hours}h', key: ValueKey('team_att_hours_${r.memberId}'))),
                                DataCell(a.canSetOthers || (r.self && a.canSetOwn)
                                    ? _ModeMenu(row: r, onSet: (m) => _setMode(m, key, r.self ? null : r.memberId))
                                    : Text(workModeLabel(r.workMode) + (r.modeSet ? ' ✓' : ''))),
                                DataCell(Tooltip(message: r.status, child: MktChip(r.state, key: ValueKey('team_att_state_${r.memberId}'), color: attendanceStateColor(r.state)))),
                                DataCell(Text(r.planTotal == null ? '—' : '${r.planDone}/${r.planTotal} done', key: ValueKey('team_att_plan_${r.memberId}'))),
                                DataCell(Tooltip(
                                  message: r.daysExpected == null
                                      ? 'No attendance linked and no work mode set'
                                      : '${r.daysAttended} of ${r.daysExpected} working days${r.monthSource == 'timebox' ? ' (Timebox)' : ''}',
                                  child: Text(pctText(r.monthRate), key: ValueKey('team_att_month_${r.memberId}')),
                                )),
                              ]),
                          ],
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

Color attendanceStateColor(String state) => switch (state) { 'Active' => kTeamGood, 'On Shoot' => kTeamWatch, 'Work From Home' => Mkt.teal, 'On Leave' => kTeamBlue, _ => kTeamGrey };

/// The day's board for a CSV (pure, so it can be checked).
List<List<Object?>> attendanceCsv(AttendanceData a) => [
      ['Member', 'Role', 'Check-in', 'Check-out', 'Hours', 'Work mode', 'State', 'Status', 'Source', 'Plan done', 'Plan items', 'Month rate %', 'Days attended', 'Days expected'],
      for (final r in a.rows)
        [r.name, r.role, r.checkIn == null ? '' : timeOf(r.checkIn), r.checkOut == null ? '' : timeOf(r.checkOut), r.hours ?? '', workModeLabel(r.workMode), r.state, r.status, attendanceSourceLabel(r.source), r.planDone ?? '', r.planTotal ?? '', r.monthRate ?? '', r.daysAttended ?? '', r.daysExpected ?? ''],
    ];

/// Where a row's attendance comes from, in words.
String attendanceSourceLabel(String source) => switch (source) { 'timebox' => 'Timebox', 'crm' => 'CRM record', 'logs' => 'Work log only', _ => '' };

/// Says where the team's attendance comes from: Timebox exactly (and who is not linked yet), or — when Timebox is not connected or did not
/// answer — the CRM's own records, with the reason. Never silent: a screen without Timebox must not pass for Timebox.
class TimeboxBanner extends StatelessWidget {
  const TimeboxBanner({super.key, required this.info, required this.what});
  final TimeboxInfo info;

  /// "Attendance" or "Hours" — what the screen takes from Timebox.
  final String what;

  @override
  Widget build(BuildContext context) {
    final (color, icon, text) = info.live
        ? (Mkt.good, Icons.verified_outlined, '$what from Timebox, exactly as Timebox records it.')
        : info.ok
            ? (Mkt.warn, Icons.link_off_rounded, 'No team member is linked to Timebox yet, so $what comes from the CRM\'s own records and the work logs.')
            : info.mode == 'off'
                ? (Mkt.grey, Icons.cloud_off_outlined, info.problem)
                : (Mkt.bad, Icons.error_outline_rounded, info.problem);
    return Container(
      key: const Key('team_timebox_banner'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
      decoration: BoxDecoration(color: Mkt.tint(color, 0.10), borderRadius: BorderRadius.circular(10), border: Border.all(color: Mkt.tint(color, 0.35))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 17, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(text, key: const Key('team_timebox_text'), style: mktText(12.5, weight: FontWeight.w700, height: 1.35))),
        ]),
        if (info.ok && info.unlinked.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 25, top: 4),
            child: Text(
              'Not linked to Timebox: ${info.unlinked.join(', ')}. Link each one\'s login (whose employee record Timebox knows) in EOD → Setup; until then their row comes from the CRM\'s records.',
              key: const Key('team_timebox_unlinked'),
              style: mktText(11.5, color: Mkt.inkSoft, height: 1.35),
            ),
          ),
      ]),
    );
  }
}

/// "How I'm working today": Office / On Shoot / Work From Home for the viewer's own row.
class _OwnModePicker extends StatelessWidget {
  const _OwnModePicker({required this.rows, required this.onSet});
  final List<AttendanceRow> rows;
  final ValueChanged<WorkMode?> onSet;

  @override
  Widget build(BuildContext context) {
    final mine = rows.where((r) => r.self).firstOrNull;
    final current = mine != null && mine.modeSet ? WorkMode.parse(mine.workMode) : null;
    return Wrap(spacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
      Text('I am working:', style: mktText(12, weight: FontWeight.w700, color: Mkt.inkSoft)),
      for (final m in WorkMode.values)
        MktFilterChip(key: Key('team_my_mode_${m.wire}'), label: m.label, selected: current == m, onTap: () => onSet(current == m ? null : m)),
    ]);
  }
}

/// A row's work mode, changeable: a member's own (inside the edit window) or, for a manager, anyone's.
class _ModeMenu extends StatelessWidget {
  const _ModeMenu({required this.row, required this.onSet});
  final AttendanceRow row;
  final ValueChanged<WorkMode?> onSet;

  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
        key: Key('team_att_mode_${row.memberId}'),
        tooltip: 'Set the work mode',
        position: PopupMenuPosition.under,
        onSelected: (v) => onSet(v == 'clear' ? null : WorkMode.parse(v)),
        itemBuilder: (_) => [
          for (final m in WorkMode.values) PopupMenuItem(value: m.wire, child: Text(m.label)),
          if (row.modeSet) const PopupMenuItem(value: 'clear', child: Text('Not set')),
        ],
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(workModeLabel(row.workMode) + (row.modeSet ? ' ✓' : ''), style: mktText(12.5)),
          const Icon(Icons.arrow_drop_down_rounded, size: 18, color: Mkt.inkSoft),
        ]),
      );
}

/// Team Dashboard → Reports: daily, weekly, monthly, performance, project and the full activity log for the chosen period and brand — shown
/// here and exported as a CSV. A report made here is kept in "Saved reports" (opening it makes it again for its period and brand); the
/// "Scheduled reports" make the weekly / monthly ones by themselves and tell the marketing managers (backend /api/marketing/reports).

/// The report a saved one makes: its own kind, else (a scheduled "Campaign Summary") the weekly report.
String teamReportTypeFor(String kind) => const ['daily', 'weekly', 'monthly', 'performance', 'project', 'activity'].contains(kind) ? kind : 'weekly';

/// The day the daily report is for: today — or, when the range ended before today, the range's last day (never its first, never a future day).
String reportDay(TeamFilter f, {DateTime? now}) {
  final today = TeamFilter.day(now ?? DateTime.now());
  return today.compareTo(f.toDay) > 0 ? f.toDay : today;
}

class TeamReportsTab extends ConsumerStatefulWidget {
  const TeamReportsTab({super.key});

  @override
  ConsumerState<TeamReportsTab> createState() => _TeamReportsTabState();
}

class _TeamReportsTabState extends ConsumerState<TeamReportsTab> {
  String? _type;
  TeamReport? _report;
  bool _loading = false;
  Object? _error;

  static const _types = [
    ('daily', 'Daily report', 'What the team logged today (or the last day of the range)', Icons.today_outlined),
    ('weekly', 'Weekly report', 'Hours, logs and tasks per person', Icons.date_range_outlined),
    ('monthly', 'Monthly report', 'The month the range ends in, per person', Icons.calendar_month_outlined),
    ('performance', 'Performance report', 'Completion, on-time and activity rate', Icons.leaderboard_outlined),
    ('project', 'Project report', 'Work and hours per project or client', Icons.folder_open_outlined),
    ('activity', 'Activity log', 'Every log in the period (custom export)', Icons.table_rows_outlined),
  ];

  /// Makes the [type] report for the shared dates and brand; one made here is kept in "Saved reports" ([keep]).
  Future<void> _run(String type, {bool keep = true}) async {
    setState(() {
      _type = type;
      _loading = true;
      _error = null;
    });
    try {
      final f = ref.read(teamFilterProvider);
      final day = type == 'daily' ? reportDay(f) : null;
      final r = await ref.read(marketingTeamServiceProvider).report(type, f, day: day);
      if (mounted) {
        setState(() {
          _report = r;
          _loading = false;
        });
      }
      if (keep && mounted) await keepGeneratedReport(ref, module: 'team', kind: type, name: r.title, from: day ?? f.fromDay, to: day ?? f.toDay, brand: f.brand.wire);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e;
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _report;
    return ListView(
      key: const Key('team_reports_list'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Wrap(spacing: 10, runSpacing: 10, children: [
          for (final t in _types)
            SizedBox(
              width: 220,
              child: InkWell(
                key: Key('team_report_${t.$1}'),
                borderRadius: BorderRadius.circular(14),
                onTap: () => _run(t.$1),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: _type == t.$1 ? Mkt.primarySoft : Mkt.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: _type == t.$1 ? Mkt.primary : Mkt.border)),
                  child: Row(children: [
                    Container(width: 36, height: 36, decoration: BoxDecoration(color: Mkt.tint(Mkt.primary), borderRadius: BorderRadius.circular(10)), child: Icon(t.$4, size: 19, color: Mkt.primary)),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(t.$2, style: mktText(13, weight: FontWeight.w800)), Text(t.$3, style: mktText(11, color: Mkt.inkSoft))])),
                  ]),
                ),
              ),
            ),
        ]),
        const SizedBox(height: 14),
        if (_loading) const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
        if (_error != null) AppErrorView(error: _error!, onRetry: _type == null ? null : () => _run(_type!)),
        if (r != null && !_loading)
          MktCard(
            title: r.title,
            subtitle: '${r.rows.length} row${r.rows.length == 1 ? '' : 's'}',
            icon: Icons.description_outlined,
            trailing: TextButton.icon(key: const Key('team_report_export'), onPressed: () => downloadCsv('marketing-${_type ?? 'report'}.csv', [r.columns, ...r.rows]), icon: const Icon(Icons.download_rounded, size: 16), label: const Text('Export CSV')),
            child: r.rows.isEmpty
                ? const MktEmpty('Nothing to report for this period and brand.', icon: Icons.description_outlined)
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      key: const Key('team_report_table'),
                      headingTextStyle: _kHead,
                      headingRowHeight: 36,
                      dataRowMinHeight: 34,
                      dataRowMaxHeight: 52,
                      columns: [for (final c in r.columns) DataColumn(label: Text(c, style: const TextStyle(fontSize: 12)))],
                      rows: [for (final row in r.rows.take(200)) DataRow(cells: [for (final v in row) DataCell(ConstrainedBox(constraints: const BoxConstraints(maxWidth: 260), child: Text('${v ?? ''}', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12))))])],
                    ),
                  ),
          ),
        const SizedBox(height: 14),
        MarketingReportsPanel(module: 'team', onOpen: _openSaved),
      ],
    );
  }

  /// A saved report: its period and brand on the shared filter, and made again (not kept a second time).
  void _openSaved(MarketingSavedReport saved) {
    showSavedReportPeriod(ref, saved);
    _run(teamReportTypeFor(saved.kind), keep: false);
  }
}
