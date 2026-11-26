import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/marketing/data/coordination_models.dart';
import 'package:nizan_crm/features/marketing/presentation/coordinations/coord_widgets.dart';
import 'package:nizan_crm/features/marketing/presentation/coordinations/followup_editor.dart';
import 'package:nizan_crm/features/marketing/presentation/kit/mkt_kit.dart';
import 'package:nizan_crm/features/marketing/services/coordination_service.dart';
import 'package:nizan_crm/features/marketing/services/team_service.dart';

/// Coordinations → Follow-ups: what is still to be chased, by whom and by when — with the strip, a month calendar of due days (a view over
/// the same records) and the Overdue list. With its reminder on, the owner is told in the app when it falls due (once per due day).
class CoordFollowUpsTab extends ConsumerWidget {
  const CoordFollowUpsTab({super.key});

  void _set(WidgetRef ref, FollowUpQuery q) => ref.read(coordFollowUpQueryProvider.notifier).state = q;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(coordFollowUpsProvider);
    final q = ref.watch(coordFollowUpQueryProvider);
    final members = ref.watch(coordSetupProvider).maybeWhen(data: (s) => s.members, orElse: () => const <CoordMember>[]);
    return RefreshIndicator(
      onRefresh: () async => refreshCoordinations(ref),
      child: async.when(
        loading: coordLoading,
        error: (e, _) => coordError(e, ref),
        data: (d) {
          final k = d.kpis;
          void status(String s) => _set(ref, q.copyWith(status: s, page: 1));
          final ownerName = q.ownerId == null ? null : members.where((m) => m.id == q.ownerId).map((m) => m.name).firstOrNull;
          return ListView(
            key: const Key('coord_followups_list'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            children: [
              MktKpiRow(minWidth: 165, children: [
                coordKpi(keyName: 'co_fu_kpi_total', icon: Icons.checklist_rounded, value: '${k.total}', label: 'Total Follow-ups', tint: Mkt.primary, onTap: () => status('all')),
                coordKpi(keyName: 'co_fu_kpi_today', icon: Icons.today_rounded, value: '${k.dueToday}', label: 'Due Today', tint: Mkt.warn, onTap: () => status('due_today')),
                coordKpi(keyName: 'co_fu_kpi_upcoming', icon: Icons.upcoming_outlined, value: '${k.upcoming}', label: 'Upcoming', tint: Mkt.blue, onTap: () => status('upcoming')),
                coordKpi(keyName: 'co_fu_kpi_overdue', icon: Icons.error_outline_rounded, value: '${k.overdue}', label: 'Overdue', tint: Mkt.bad, onTap: () => status('overdue')),
                coordKpi(keyName: 'co_fu_kpi_completed', icon: Icons.check_circle_outline_rounded, value: '${k.completed}', label: 'Completed', tint: Mkt.good, onTap: () => status('completed')),
              ]),
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.end, crossAxisAlignment: WrapCrossAlignment.center, children: [
                KeyedSubtree(
                  key: const Key('co_fu_owner_pill'),
                  child: MktDropdownPill<String>(
                    value: q.ownerId ?? '',
                    icon: Icons.person_outline_rounded,
                    options: [('', 'All Owners'), for (final m in members) (m.id, m.name)],
                    onChanged: (v) => _set(ref, v.isEmpty ? q.copyWith(clearOwner: true, page: 1) : q.copyWith(ownerId: v, page: 1)),
                  ),
                ),
                if (ownerName != null) Text('Showing $ownerName’s follow-ups', style: mktText(11.5, color: Mkt.inkSoft)),
                ExportButton(type: 'followups', extra: {'ownerId': ?q.ownerId}),
                MktPrimaryButton(key: const Key('co_fu_new'), label: 'Add Follow-up', onPressed: () => showFollowUpEditor(context, ref)),
              ]),
              const SizedBox(height: 12),
              MktGrid(breakpoint: 980, rows: [
                [(7, _TableCard(data: d, query: q)), (3, Column(children: [const _CalendarCard(), const SizedBox(height: 12), _OverdueCard(data: d)]))],
              ]),
            ],
          );
        },
      ),
    );
  }
}

class _TableCard extends ConsumerWidget {
  const _TableCard({required this.data, required this.query});
  final FollowUpList data;
  final FollowUpQuery query;

  void _set(WidgetRef ref, FollowUpQuery q) => ref.read(coordFollowUpQueryProvider.notifier).state = q;

  @override
  Widget build(BuildContext context, WidgetRef ref) => MktCard(
        title: 'Follow-ups',
        icon: Icons.notifications_active_outlined,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [for (final f in const [('all', 'All'), ('due_today', 'Due Today'), ('upcoming', 'Upcoming'), ('overdue', 'Overdue'), ('completed', 'Completed')]) Padding(padding: const EdgeInsets.only(right: 6), child: MktFilterChip(key: Key('co_fu_status_${f.$1}'), label: f.$2, selected: query.status == f.$1, onTap: () => _set(ref, query.copyWith(status: f.$1, page: 1))))]),
          ),
          const SizedBox(height: 8),
          SizedBox(width: 260, child: CoordSearchField(fieldKey: const Key('co_fu_search'), initial: query.q, hint: 'Search follow-ups…', onChanged: (v) => _set(ref, ref.read(coordFollowUpQueryProvider).copyWith(q: v, page: 1)))),
          const SizedBox(height: 8),
          if (data.items.isEmpty)
            MktEmpty(data.kpis.total == 0 ? 'No follow-ups in this period. Use Add Follow-up.' : 'No follow-up matches.', icon: Icons.notifications_none_rounded, height: 130)
          else
            MktTable(
              minWidth: 800,
              columns: const [MktCol('', width: 36), MktCol('Follow-up Item', flex: 5), MktCol('Related To', flex: 3), MktCol('Owner', flex: 3), MktCol('Department', flex: 2), MktCol('Due Date', flex: 2), MktCol('Status', flex: 2), MktCol('Reminder', width: 64, align: Alignment.center)],
              rowKeys: [for (final f in data.items) Key('co_fu_row_${f.id}')],
              onRowTap: (i) => data.items[i].canEdit ? showFollowUpEditor(context, ref, followUp: data.items[i]) : null,
              rows: [for (final f in data.items) _cells(context, ref, f)],
            ),
          const SizedBox(height: 6),
          CoordPager(keyPrefix: 'co_fu', total: data.total, page: data.page, pageSize: data.pageSize, shown: data.items.length, onPage: (p) => _set(ref, query.copyWith(page: p))),
        ]),
      );

  List<Widget> _cells(BuildContext context, WidgetRef ref, FollowUpRow f) => [
        InkWell(
          key: Key('co_fu_done_${f.id}'),
          onTap: f.canEdit ? () => coordQuickWrite(context, ref, () => ref.read(marketingCoordinationServiceProvider).saveFollowUp({'status': f.done ? 'open' : 'done'}, id: f.id)) : null,
          child: Icon(f.done ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded, size: 19, color: f.done ? Mkt.good : Mkt.inkSoft),
        ),
        Text(f.item, maxLines: 2, overflow: TextOverflow.ellipsis, style: mktText(12, weight: FontWeight.w600)),
        Text(orDash(f.relatedTo), maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(11.5, color: Mkt.inkSoft)),
        PersonCell(f.owner),
        DeptChip(f.department),
        Text(f.state == 'due_today' ? 'Today' : coordDay(f.dueDate), maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(12, weight: f.state == 'overdue' || f.state == 'due_today' ? FontWeight.w800 : FontWeight.w500, color: f.state == 'overdue' || f.state == 'due_today' ? Mkt.bad : Mkt.ink)),
        MktChip(kFollowUpStateLabels[f.state] ?? f.state, color: followUpStateColor(f.state)),
        Icon(f.reminder ? Icons.notifications_active_rounded : Icons.notifications_none_rounded, size: 18, color: f.reminder ? (f.state == 'overdue' ? Mkt.bad : Mkt.primary) : Mkt.inkSoft.withValues(alpha: 0.5)),
      ];
}

/// The month of due days: a dot per kind (open, overdue, done); tapping a day narrows every list to that day.
class _CalendarCard extends ConsumerWidget {
  const _CalendarCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(coordCalendarMonthProvider);
    final async = ref.watch(coordCalendarProvider);
    final today = todayDay();
    void move(int by) => ref.read(coordCalendarMonthProvider.notifier).state = DateTime(month.year, month.month + by);
    final lead = DateTime(month.year, month.month, 1).weekday - 1;
    final days = DateUtils.getDaysInMonth(month.year, month.month);
    final cells = <int?>[for (var i = 0; i < lead; i++) null, for (var d = 1; d <= days; d++) d];
    while (cells.length % 7 != 0) {
      cells.add(null);
    }
    return MktCard(
      title: 'Follow-up Calendar',
      icon: Icons.calendar_month_outlined,
      child: Column(children: [
        Row(children: [
          Expanded(child: Text(DateFormat('MMMM yyyy').format(month), key: const Key('co_cal_title'), style: mktText(13, weight: FontWeight.w800))),
          IconButton(key: const Key('co_cal_prev'), visualDensity: VisualDensity.compact, onPressed: () => move(-1), icon: const Icon(Icons.chevron_left_rounded, size: 20)),
          IconButton(key: const Key('co_cal_next'), visualDensity: VisualDensity.compact, onPressed: () => move(1), icon: const Icon(Icons.chevron_right_rounded, size: 20)),
        ]),
        Row(children: [for (final w in const ['M', 'T', 'W', 'T', 'F', 'S', 'S']) Expanded(child: Center(child: Text(w, style: mktText(10.5, weight: FontWeight.w700, color: Mkt.inkSoft))))]),
        const SizedBox(height: 4),
        async.when(
          loading: () => const SizedBox(height: 120, child: Center(child: CircularProgressIndicator())),
          error: (e, _) => AppErrorView(error: e, onRetry: () => ref.invalidate(coordCalendarProvider)),
          data: (cal) => Column(key: const Key('co_cal_grid'), children: [
            for (var r = 0; r < cells.length ~/ 7; r++)
              Row(children: [
                for (var c = 0; c < 7; c++)
                  Expanded(
                    child: cells[r * 7 + c] == null
                        ? const SizedBox(height: 40)
                        : _DayCell(
                            day: DateTime(month.year, month.month, cells[r * 7 + c]!),
                            info: cal.on(TeamFilter.day(DateTime(month.year, month.month, cells[r * 7 + c]!))),
                            isToday: TeamFilter.day(DateTime(month.year, month.month, cells[r * 7 + c]!)) == today,
                            onTap: () {
                              final d = DateTime(month.year, month.month, cells[r * 7 + c]!);
                              ref.read(teamFilterProvider.notifier).state = ref.read(teamFilterProvider).copyWith(from: d, to: d);
                              ref.read(coordFollowUpQueryProvider.notifier).state = ref.read(coordFollowUpQueryProvider).copyWith(page: 1);
                            },
                          ),
                  ),
              ]),
          ]),
        ),
        const SizedBox(height: 6),
        Wrap(spacing: 10, children: [for (final l in const [('Open', Mkt.primary), ('Overdue', Mkt.bad), ('Done', Mkt.good)]) Row(mainAxisSize: MainAxisSize.min, children: [Container(width: 6, height: 6, decoration: BoxDecoration(color: l.$2, shape: BoxShape.circle)), const SizedBox(width: 4), Text(l.$1, style: mktText(10, color: Mkt.inkSoft))])]),
      ]),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({required this.day, required this.info, required this.isToday, required this.onTap});
  final DateTime day;
  final CalendarDay? info;
  final bool isToday;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final i = info;
    return InkWell(
      key: Key('co_cal_day_${TeamFilter.day(day)}'),
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: SizedBox(
        height: 40,
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(width: 22, height: 22, alignment: Alignment.center, decoration: BoxDecoration(color: isToday ? Mkt.primary : null, shape: BoxShape.circle), child: Text('${day.day}', style: mktText(11, weight: isToday ? FontWeight.w800 : FontWeight.w600, color: isToday ? Colors.white : Mkt.ink))),
          const SizedBox(height: 2),
          SizedBox(
            height: 6,
            child: i == null
                ? null
                : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    if (i.open - i.overdue > 0) _dot(Mkt.primary),
                    if (i.overdue > 0) _dot(Mkt.bad),
                    if (i.done > 0) _dot(Mkt.good),
                  ]),
          ),
        ]),
      ),
    );
  }

  Widget _dot(Color c) => Container(width: 5, height: 5, margin: const EdgeInsets.symmetric(horizontal: 1), decoration: BoxDecoration(color: c, shape: BoxShape.circle));
}

class _OverdueCard extends ConsumerWidget {
  const _OverdueCard({required this.data});
  final FollowUpList data;

  @override
  Widget build(BuildContext context, WidgetRef ref) => MktCard(
        title: 'Overdue (${data.overdueTotal})',
        icon: Icons.error_outline_rounded,
        iconColor: Mkt.bad,
        link: 'View All',
        linkKey: const Key('co_overdue_all_link'),
        onLink: () => ref.read(coordFollowUpQueryProvider.notifier).state = ref.read(coordFollowUpQueryProvider).copyWith(status: 'overdue', page: 1),
        child: data.overdue.isEmpty
            ? const MktEmpty('Nothing is overdue.', icon: Icons.task_alt_rounded, height: 90)
            : Column(key: const Key('co_overdue_list'), children: [
                for (final f in data.overdue)
                  Padding(
                    key: Key('co_overdue_${f.id}'),
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(children: [
                      const Icon(Icons.circle, size: 7, color: Mkt.bad),
                      const SizedBox(width: 8),
                      Expanded(child: Text(f.item, maxLines: 2, overflow: TextOverflow.ellipsis, style: mktText(12, weight: FontWeight.w600))),
                      const SizedBox(width: 6),
                      Text('${f.daysAgo} ${f.daysAgo == 1 ? 'day' : 'days'} ago', maxLines: 1, style: mktText(10.5, weight: FontWeight.w700, color: Mkt.bad)),
                    ]),
                  ),
              ]),
      );
}
