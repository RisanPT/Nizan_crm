import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/marketing/data/portfolio_models.dart';
import 'package:nizan_crm/features/marketing/presentation/kit/mkt_kit.dart';
import 'package:nizan_crm/features/marketing/presentation/portfolio/portfolio_widgets.dart';
import 'package:nizan_crm/features/marketing/presentation/portfolio/shoot_editor.dart';
import 'package:nizan_crm/features/marketing/services/portfolio_service.dart';
import 'package:nizan_crm/features/marketing/services/team_service.dart';

enum PcView { month, week, list }

String _d(DateTime d) => TeamFilter.day(d);

/// Creative Portfolio → Production Calendar. Its entries come from the shoot plans (never typed twice); the stage counts and the donut
/// move with the work members log against each shoot; crew availability reads the plan's crew and approved leave.
class ProductionCalendarTab extends ConsumerStatefulWidget {
  const ProductionCalendarTab({super.key});

  @override
  ConsumerState<ProductionCalendarTab> createState() => _ProductionCalendarTabState();
}

class _ProductionCalendarTabState extends ConsumerState<ProductionCalendarTab> {
  PcView _view = PcView.month;
  DateTime _cursor = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

  (DateTime, DateTime) get _window {
    final first = DateTime(_cursor.year, _cursor.month, 1);
    switch (_view) {
      case PcView.week:
        final monday = _cursor.subtract(Duration(days: _cursor.weekday - 1));
        return (monday, monday.add(const Duration(days: 6)));
      default:
        // the grid shows whole weeks around the month, so the window covers them
        final start = first.subtract(Duration(days: first.weekday - 1));
        final last = DateTime(_cursor.year, _cursor.month + 1, 0);
        return (start, last.add(Duration(days: 7 - last.weekday)));
    }
  }

  void _move(int dir) => setState(() => _cursor = _view == PcView.week ? _cursor.add(Duration(days: 7 * dir)) : DateTime(_cursor.year, _cursor.month + dir, 1));

  String get _title => _view == PcView.week ? '${DateFormat('d MMM').format(_window.$1)} – ${DateFormat('d MMM yyyy').format(_window.$2)}' : DateFormat('MMMM yyyy').format(_cursor);

  @override
  Widget build(BuildContext context) {
    final (from, to) = _window;
    final async = ref.watch(productionCalendarProvider((from: _d(from), to: _d(to), day: null)));
    return RefreshIndicator(
      onRefresh: () async => refreshPortfolio(ref),
      child: async.when(
        loading: () => ListView(children: const [SizedBox(height: 200), Center(child: CircularProgressIndicator())]),
        error: (e, _) => ListView(children: [AppErrorView(error: e, onRetry: () => refreshPortfolio(ref))]),
        data: (c) {
          final k = c.counts;
          return ListView(
            key: const Key('portfolio_calendar_list'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            children: [
              MktKpiRow(minWidth: 180, children: [
                MktKpiCard(key: const Key('pc_kpi_scheduled'), icon: Icons.event_outlined, value: '${k.total}', label: 'Scheduled Shoots', tint: Mkt.violet),
                MktKpiCard(key: const Key('pc_kpi_production'), icon: Icons.videocam_outlined, value: '${k.inProduction}', label: 'In Production', tint: Mkt.good),
                MktKpiCard(key: const Key('pc_kpi_post'), icon: Icons.edit_outlined, value: '${k.postProduction}', label: 'In Post-production', tint: Mkt.warn),
                MktKpiCard(key: const Key('pc_kpi_completed'), icon: Icons.check_circle_outline_rounded, value: '${k.completed}', label: 'Completed', tint: Mkt.blue),
                MktKpiCard(key: const Key('pc_kpi_rescheduled'), icon: Icons.update_rounded, value: '${k.rescheduled}', label: 'Rescheduled', tint: Mkt.pink),
              ]),
              const SizedBox(height: 12),
              MktGrid(breakpoint: 980, rows: [
                [
                  (8, MktCard(
                    title: 'Production Calendar',
                    icon: Icons.calendar_month_outlined,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                        IconButton(key: const Key('pc_prev'), onPressed: () => _move(-1), icon: const Icon(Icons.chevron_left_rounded)),
                        Text(_title, key: const Key('pc_title'), style: mktText(15, weight: FontWeight.w800)),
                        IconButton(key: const Key('pc_next'), onPressed: () => _move(1), icon: const Icon(Icons.chevron_right_rounded)),
                        for (final v in PcView.values) MktFilterChip(key: Key('pc_view_${v.name}'), label: v.name[0].toUpperCase() + v.name.substring(1), selected: _view == v, onTap: () => setState(() => _view = v)),
                      ]),
                      const SizedBox(height: 10),
                      switch (_view) {
                        PcView.month => _Month(month: _cursor, start: from, items: c.items),
                        PcView.week => _Week(start: from, items: c.items),
                        PcView.list => _List(items: c.items.where((s) => s.shootDate.startsWith(DateFormat('yyyy-MM').format(_cursor))).toList()),
                      },
                    ]),
                  )),
                  (4, Column(children: [_Today(c: c), const SizedBox(height: 12), _Upcoming(c: c)])),
                ],
                [(5, _Load(c: c)), (7, _Availability(c: c))],
              ]),
            ],
          );
        },
      ),
    );
  }
}

class _Chip extends ConsumerWidget {
  const _Chip({required this.s});
  final ShootSummary s;

  @override
  Widget build(BuildContext context, WidgetRef ref) => InkWell(
        key: Key('pc_shoot_${s.id}'),
        borderRadius: BorderRadius.circular(6),
        onTap: () async {
          final d = await ref.read(shootDetailProvider(s.id).future);
          if (context.mounted) showShootEditor(context, ref, shoot: d);
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 3),
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(color: Mkt.tint(shootStatusColor(s.status), 0.14), borderRadius: BorderRadius.circular(6), border: Border(left: BorderSide(color: shootStatusColor(s.status), width: 3))),
          child: Text(s.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(10, weight: FontWeight.w700)),
        ),
      );
}

class _Month extends StatelessWidget {
  const _Month({required this.month, required this.start, required this.items});
  final DateTime month, start;
  final List<ShootSummary> items;

  @override
  Widget build(BuildContext context) {
    final last = DateTime(month.year, month.month + 1, 0);
    final rows = ((last.add(Duration(days: 7 - last.weekday)).difference(start).inDays + 1) / 7).ceil();
    final today = _d(DateTime.now());
    return Column(key: const Key('pc_month_grid'), children: [
      Row(children: [for (final d in ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']) Expanded(child: Center(child: Text(d, style: mktText(11, weight: FontWeight.w700, color: Mkt.inkSoft))))]),
      const SizedBox(height: 4),
      for (var r = 0; r < rows; r++)
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (var c = 0; c < 7; c++)
            Expanded(
              child: Builder(builder: (context) {
                final day = start.add(Duration(days: r * 7 + c));
                final key = _d(day);
                final inMonth = day.month == month.month;
                final list = items.where((s) => s.shootDate == key).toList();
                return Container(
                  key: Key('pc_day_$key'),
                  height: 84,
                  margin: const EdgeInsets.all(1.5),
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(color: inMonth ? Mkt.card : Mkt.bg, borderRadius: BorderRadius.circular(8), border: Border.all(color: key == today ? Mkt.violet : Mkt.border)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${day.day}', style: mktText(10.5, weight: key == today ? FontWeight.w800 : FontWeight.w500, color: key == today ? Mkt.violet : (inMonth ? Mkt.ink : Mkt.inkSoft))),
                    const SizedBox(height: 2),
                    for (final s in list.take(2)) _Chip(s: s),
                    if (list.length > 2) Text('+${list.length - 2} more', style: mktText(9.5, color: Mkt.inkSoft)),
                  ]),
                );
              }),
            ),
        ]),
    ]);
  }
}

class _Week extends StatelessWidget {
  const _Week({required this.start, required this.items});
  final DateTime start;
  final List<ShootSummary> items;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        key: const Key('pc_week_row'),
        scrollDirection: Axis.horizontal,
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (var i = 0; i < 7; i++)
            Builder(builder: (context) {
              final day = start.add(Duration(days: i));
              final list = items.where((s) => s.shootDate == _d(day)).toList();
              return Container(
                key: Key('pc_week_${_d(day)}'),
                width: 140,
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Mkt.card, borderRadius: BorderRadius.circular(10), border: Border.all(color: Mkt.border)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(DateFormat('EEE d').format(day), style: mktText(12, weight: FontWeight.w800)), const SizedBox(height: 6), if (list.isEmpty) Text('No shoot', style: mktText(11, color: Mkt.inkSoft)), for (final s in list) _Chip(s: s)]),
              );
            }),
        ]),
      );
}

class _List extends StatelessWidget {
  const _List({required this.items});
  final List<ShootSummary> items;

  @override
  Widget build(BuildContext context) => items.isEmpty
      ? const MktEmpty('No shoot in this month.', icon: Icons.event_busy_outlined)
      : MktTable(
          key: const Key('pc_list_table'),
          minWidth: 520,
          rowHeight: 48,
          rowKeys: [for (final s in items) Key('pc_list_${s.id}')],
          columns: const [MktCol('Date', width: 74), MktCol('Shoot', flex: 5), MktCol('Brand', width: 64), MktCol('Location', flex: 3), MktCol('Stage', width: 118, align: Alignment.centerRight)],
          rows: [for (final s in items) [Text(shootDay(s.shootDate, pattern: 'd MMM'), style: mktText(12, weight: FontWeight.w700)), Text(s.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: mktText(12.5, weight: FontWeight.w700)), Text(s.brand == 'kerala' ? 'Kerala' : 'Main', style: mktText(12)), Text(s.location, maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(11.5, color: Mkt.inkSoft)), MktChip(shootStatusLabel(s.status), color: shootStatusColor(s.status))]],
        );
}

class _Today extends StatelessWidget {
  const _Today({required this.c});
  final ProductionCalendar c;

  @override
  Widget build(BuildContext context) => MktCard(
        title: "Today's Productions",
        subtitle: DateFormat('EEE, d MMM yyyy').format(DateTime.now()),
        icon: Icons.videocam_outlined,
        child: c.today.isEmpty
            ? const MktEmpty('No shoot is planned for today.', icon: Icons.videocam_off_outlined, height: 90)
            : Column(children: [
                for (final t in c.today)
                  Container(
                    key: Key('pc_today_${t.summary.id}'),
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(border: Border.all(color: Mkt.border), borderRadius: BorderRadius.circular(12)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        ShootCover(url: t.summary.coverUrl, size: 42),
                        const SizedBox(width: 10),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(t.summary.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(12.5, weight: FontWeight.w800)), Text([t.summary.time, t.summary.location].where((x) => x.isNotEmpty).join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(10.5, color: Mkt.inkSoft))])),
                        MktChip(shootStatusLabel(t.summary.status), color: shootStatusColor(t.summary.status)),
                      ]),
                      const SizedBox(height: 10),
                      Text('Shoot Progress', style: mktText(11, weight: FontWeight.w700, color: Mkt.inkSoft)),
                      const SizedBox(height: 6),
                      MilestoneStepper(milestones: t.milestones, showDates: false),
                    ]),
                  ),
              ]),
      );
}

class _Upcoming extends StatelessWidget {
  const _Upcoming({required this.c});
  final ProductionCalendar c;

  @override
  Widget build(BuildContext context) => MktCard(
        title: 'Upcoming Shoots',
        icon: Icons.upcoming_outlined,
        child: c.upcoming.isEmpty
            ? const MktEmpty('Nothing is planned after today.', icon: Icons.event_available_outlined, height: 80)
            : Column(children: [
                for (final s in c.upcoming)
                  Padding(
                    key: Key('pc_upcoming_${s.id}'),
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(children: [
                      ShootCover(url: s.coverUrl, size: 36, radius: 8),
                      const SizedBox(width: 10),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(s.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(12, weight: FontWeight.w700)), Text(shootDay(s.shootDate, pattern: 'd MMM yyyy'), style: mktText(10.5, color: Mkt.inkSoft))])),
                      MktChip(shootStatusLabel(s.status), color: shootStatusColor(s.status)),
                    ]),
                  ),
              ]),
      );
}

class _Load extends StatelessWidget {
  const _Load({required this.c});
  final ProductionCalendar c;

  @override
  Widget build(BuildContext context) => MktCard(
        title: 'Production Load',
        icon: Icons.donut_large_rounded,
        child: c.loadTotal == 0
            ? const MktEmpty('No shoot in this period.', icon: Icons.donut_large_rounded, height: 110)
            : MktDonut(centerKey: const Key('pc_load_total'), centerValue: '${c.loadTotal}', centerLabel: 'Total Shoots', colors: [for (final r in c.load) shootStatusColor(r.key == 'pre_production' ? 'pre_production' : r.key)], slices: [for (final r in c.load) (label: r.label, value: r.count.toDouble(), trailing: '${r.pct}% (${r.count})')]),
      );
}

class _Availability extends StatelessWidget {
  const _Availability({required this.c});
  final ProductionCalendar c;

  @override
  Widget build(BuildContext context) => MktCard(
        title: 'Crew & Resource Availability',
        subtitle: c.day.isEmpty ? null : shootDay(c.day, pattern: 'EEE d MMM'),
        icon: Icons.groups_2_outlined,
        child: c.availability.isEmpty
            ? const MktEmpty('No team members are set up.', icon: Icons.groups_2_outlined, height: 90)
            : Column(children: [
                for (final r in c.availability)
                  Padding(
                    key: Key('pc_role_${r.role}'),
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(children: [
                      SizedBox(width: 130, child: Text(r.role, maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(12.5, weight: FontWeight.w700))),
                      Expanded(child: MktProgress(pct: r.total == 0 ? 0 : (r.available * 100 / r.total).round(), color: r.available == 0 ? Mkt.bad : Mkt.good, showLabel: false)),
                      const SizedBox(width: 10),
                      Text('${r.available} / ${r.total} Available', style: mktText(11.5, weight: FontWeight.w700)),
                      if (r.onLeave > 0) Padding(padding: const EdgeInsets.only(left: 6), child: MktChip('${r.onLeave} on leave', color: Mkt.blue)),
                    ]),
                  ),
              ]),
      );
}
