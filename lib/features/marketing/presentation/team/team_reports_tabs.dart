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

const _kHead = TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Mkt.inkSoft);

/// Team Dashboard → Logs & Timesheet: hours per person per day, and how the team's time splits across the activity groups.
class TeamTimesheetTab extends ConsumerWidget {
  const TeamTimesheetTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sheet = ref.watch(teamTimesheetProvider);
    return RefreshIndicator(
      onRefresh: () async => refreshTeam(ref),
      child: sheet.when(
        loading: () => ListView(children: const [SizedBox(height: 200), Center(child: CircularProgressIndicator())]),
        error: (e, _) => ListView(children: [AppErrorView(error: e, onRetry: () => refreshTeam(ref))]),
        data: (t) {
          final shownDays = t.days.length > 14 ? t.days.sublist(t.days.length - 14) : t.days;
          final table = MktCard(
            title: 'Daily logs',
            subtitle: 'Total ${t.totalLabel}',
            icon: Icons.schedule_rounded,
            trailing: TextButton.icon(
              key: const Key('team_timesheet_export'),
              onPressed: () => downloadCsv('marketing-timesheet.csv', [
                ['Member', 'Role', 'Logs', 'Days logged', 'Hours', ...t.days],
                for (final r in t.rows) [r.name, r.role, r.logs, r.daysLogged, (r.minutes / 60).toStringAsFixed(2), ...t.days.map((d) => ((r.byDay[d] ?? 0) / 60).toStringAsFixed(2))],
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
                        const DataColumn(label: Text('Total')),
                        for (final d in shownDays) DataColumn(label: Text(DateFormat('E d').format(DateTime.parse(d)), style: const TextStyle(fontSize: 11))),
                        const DataColumn(label: Text('Status')),
                      ],
                      rows: [
                        for (final r in t.rows)
                          DataRow(key: ValueKey('team_timesheet_${r.memberId}'), cells: [
                            DataCell(Row(children: [MemberAvatar(r.name, size: 24), const SizedBox(width: 8), Text(r.name)])),
                            DataCell(Text(r.label, style: const TextStyle(fontWeight: FontWeight.w700))),
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
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                if (wide) Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(flex: 8, child: table), const SizedBox(width: 12), Expanded(flex: 4, child: split)]) else ...[table, const SizedBox(height: 12), split],
              ],
            );
          });
        },
      ),
    );
  }
}

/// Team Dashboard → Performance: each person's task completion, on-time delivery and activity rate, and the weekly trend.
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
                MktKpiCard(key: const Key('team_perf_activity'), icon: Icons.bolt_rounded, label: 'Team activity rate', value: pctText(p.activityRate), tint: Mkt.violet2),
                MktKpiCard(key: const Key('team_perf_tasks'), icon: Icons.task_alt_rounded, label: 'Tasks completed', value: '${p.tasksCompleted}', tint: Mkt.good),
                MktKpiCard(key: const Key('team_perf_ontime'), icon: Icons.verified_outlined, label: 'On-time delivery', value: pctText(p.onTimeDelivery), tint: Mkt.blue),
              ]),
              const SizedBox(height: 12),
              MktCard(
                title: 'Team performance',
                subtitle: 'Best first',
                icon: Icons.leaderboard_outlined,
                child: p.rows.isEmpty
                    ? const MktEmpty('No team members.', icon: Icons.leaderboard_outlined)
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          key: const Key('team_performance_table'),
                          headingTextStyle: _kHead,
                      headingRowHeight: 38,
                          dataRowMinHeight: 42,
                          columns: const [DataColumn(label: Text('Member')), DataColumn(label: Text('Task completion')), DataColumn(label: Text('On-time delivery')), DataColumn(label: Text('Activity rate')), DataColumn(label: Text('Overall'))],
                          rows: [
                            for (final r in p.rows)
                              DataRow(key: ValueKey('team_perf_${r.memberId}'), cells: [
                                DataCell(Row(children: [MemberAvatar(r.name, size: 24), const SizedBox(width: 8), Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [Text(r.name, style: const TextStyle(fontWeight: FontWeight.w700)), if (r.role.isNotEmpty) Text(r.role, style: TextStyle(fontSize: 10.5, color: Mkt.inkSoft))])])),
                                DataCell(cell(r.completion)),
                                DataCell(cell(r.onTime)),
                                DataCell(cell(r.activityRate)),
                                DataCell(Text(pctText(r.overall), style: const TextStyle(fontWeight: FontWeight.w800))),
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
                            LineChartBarData(spots: [for (var i = 0; i < p.trend.length; i++) if (p.trend[i].completion != null) FlSpot(i.toDouble(), p.trend[i].completion!.toDouble())], isCurved: true, color: Mkt.violet, barWidth: 2.5),
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

/// Team Dashboard → Attendance: who is in, on a shoot, on leave or not in yet, for one day, and the month's rate.
class TeamAttendanceTab extends ConsumerStatefulWidget {
  const TeamAttendanceTab({super.key});

  @override
  ConsumerState<TeamAttendanceTab> createState() => _TeamAttendanceTabState();
}

class _TeamAttendanceTabState extends ConsumerState<TeamAttendanceTab> {
  DateTime _day = DateTime.now();

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
              Align(alignment: Alignment.centerLeft, child: MktPill(key: const Key('team_attendance_day'), label: DateFormat('EEE d MMM yyyy').format(_day), icon: Icons.calendar_today_outlined, onTap: _pick)),
              const SizedBox(height: 10),
              MktKpiRow(minWidth: 160, children: [
                MktKpiCard(key: const Key('team_att_present'), icon: Icons.person_outline, label: 'Present', value: '${s.present}', tint: Mkt.good),
                MktKpiCard(key: const Key('team_att_shoot'), icon: Icons.videocam_outlined, label: 'On shoot', value: '${s.onShoot}', tint: Mkt.warn),
                MktKpiCard(key: const Key('team_att_leave'), icon: Icons.beach_access_outlined, label: 'On leave', value: '${s.onLeave}', tint: Mkt.blue),
                MktKpiCard(key: const Key('team_att_absent'), icon: Icons.person_off_outlined, label: 'Not in', value: '${s.absent}', tint: Mkt.grey),
                MktKpiCard(key: const Key('team_att_rate'), icon: Icons.donut_large_rounded, label: 'Attendance rate (month)', value: pctText(a.rate), note: a.linked == 0 ? 'No login linked to a team member yet' : null, tint: Mkt.violet),
              ]),
              const SizedBox(height: 12),
              MktCard(
                title: 'Attendance & availability',
                icon: Icons.event_available_outlined,
                child: a.rows.isEmpty
                    ? const MktEmpty('No team members.', icon: Icons.event_available_outlined)
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          key: const Key('team_attendance_table'),
                          headingTextStyle: _kHead,
                      headingRowHeight: 38,
                          columns: const [DataColumn(label: Text('Member')), DataColumn(label: Text('Check-in')), DataColumn(label: Text('Check-out')), DataColumn(label: Text('Hours')), DataColumn(label: Text('Work mode')), DataColumn(label: Text('Status'))],
                          rows: [
                            for (final r in a.rows)
                              DataRow(key: ValueKey('team_att_row_${r.memberId}'), cells: [
                                DataCell(Row(children: [MemberAvatar(r.name, size: 24), const SizedBox(width: 8), Text(r.name)])),
                                DataCell(Text(r.checkIn == null ? '—' : timeOf(r.checkIn))),
                                DataCell(Text(r.checkOut == null ? '—' : timeOf(r.checkOut))),
                                DataCell(Text(r.hours == null ? '—' : '${r.hours}h')),
                                DataCell(Text(switch (r.workMode) { 'office' => 'Office', 'on_shoot' => 'On shoot', 'on_leave' => 'On leave', _ => '—' })),
                                DataCell(MktChip(r.state, color: switch (r.state) { 'Active' => kTeamGood, 'On Shoot' => kTeamWatch, 'On Leave' => kTeamBlue, _ => kTeamGrey })),
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

/// Team Dashboard → Reports: daily, weekly, performance, project and the full activity log for the chosen period and brand — shown
/// here and exported as a CSV. (Scheduled e-mailed reports are not built: the CRM has no scheduler yet.)
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
    ('daily', 'Daily report', 'What the team logged on a day', Icons.today_outlined),
    ('weekly', 'Weekly report', 'Hours, logs and tasks per person', Icons.date_range_outlined),
    ('performance', 'Performance report', 'Completion, on-time and activity rate', Icons.leaderboard_outlined),
    ('project', 'Project report', 'Work and hours per project or client', Icons.folder_open_outlined),
    ('activity', 'Activity log', 'Every log in the period (custom export)', Icons.table_rows_outlined),
  ];

  Future<void> _run(String type) async {
    setState(() {
      _type = type;
      _loading = true;
      _error = null;
    });
    try {
      final r = await ref.read(marketingTeamServiceProvider).report(type, ref.read(teamFilterProvider));
      if (mounted) {
        setState(() {
          _report = r;
          _loading = false;
        });
      }
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
                  decoration: BoxDecoration(color: _type == t.$1 ? Mkt.violetSoft : Mkt.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: _type == t.$1 ? Mkt.violet : Mkt.border)),
                  child: Row(children: [
                    Container(width: 36, height: 36, decoration: BoxDecoration(color: Mkt.tint(Mkt.violet), borderRadius: BorderRadius.circular(10)), child: Icon(t.$4, size: 19, color: Mkt.violet)),
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
      ],
    );
  }
}
