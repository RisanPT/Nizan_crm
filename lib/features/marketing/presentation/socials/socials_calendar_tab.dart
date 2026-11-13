import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/marketing/data/socials_models.dart';
import 'package:nizan_crm/features/marketing/presentation/kit/mkt_kit.dart';
import 'package:nizan_crm/features/marketing/presentation/socials/post_editor.dart';
import 'package:nizan_crm/features/marketing/presentation/socials/socials_widgets.dart';
import 'package:nizan_crm/features/marketing/services/socials_service.dart';
import 'package:nizan_crm/features/marketing/services/team_service.dart';

enum CalView { month, week, list }

/// What the calendar asks the server for: a window of days (and a platform); the brand comes from the shared filter.
typedef CalKey = ({String from, String to, String platform});

final socialsWindowProvider = FutureProvider.autoDispose.family<SocialsCalendar, CalKey>((ref, k) {
  final f = ref.watch(teamFilterProvider);
  final window = TeamFilter(from: DateTime.parse(k.from), to: DateTime.parse(k.to), brand: f.brand);
  return ref.watch(marketingSocialsServiceProvider).calendar(window, platform: k.platform);
}, retry: (_, _) => null);

String _d(DateTime d) => TeamFilter.day(d);

/// Socials → Content Calendar: the month, the week or a list of what is planned and scheduled. The entries ARE the posts (nothing is
/// typed twice); click one to change it, click a day's + to plan a new one there.
class SocialsCalendarTab extends ConsumerStatefulWidget {
  const SocialsCalendarTab({super.key});

  @override
  ConsumerState<SocialsCalendarTab> createState() => _SocialsCalendarTabState();
}

class _SocialsCalendarTabState extends ConsumerState<SocialsCalendarTab> {
  CalView _view = CalView.month;
  DateTime _cursor = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
  String _platform = 'all';

  (DateTime, DateTime) get _window {
    switch (_view) {
      case CalView.month:
        final first = DateTime(_cursor.year, _cursor.month, 1);
        final lead = first.weekday - 1; // Monday first
        final start = first.subtract(Duration(days: lead));
        return (start, start.add(const Duration(days: 41)));
      case CalView.week:
        final monday = _cursor.subtract(Duration(days: _cursor.weekday - 1));
        return (monday, monday.add(const Duration(days: 6)));
      case CalView.list:
        final first = DateTime(_cursor.year, _cursor.month, 1);
        return (first, DateTime(_cursor.year, _cursor.month + 1, 0));
    }
  }

  void _move(int dir) => setState(() {
        _cursor = switch (_view) {
          CalView.week => _cursor.add(Duration(days: 7 * dir)),
          _ => DateTime(_cursor.year, _cursor.month + dir, 1),
        };
      });

  String get _title => switch (_view) {
        CalView.week => () {
            final (a, b) = _window;
            return '${DateFormat('d MMM').format(a)} – ${DateFormat('d MMM yyyy').format(b)}';
          }(),
        _ => DateFormat('MMMM yyyy').format(_cursor),
      };

  @override
  Widget build(BuildContext context) {
    final (from, to) = _window;
    final async = ref.watch(socialsWindowProvider((from: _d(from), to: _d(to), platform: _platform)));
    final controls = Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
      IconButton(key: const Key('soc_cal_prev'), onPressed: () => _move(-1), icon: const Icon(Icons.chevron_left_rounded)),
      Text(_title, key: const Key('soc_cal_title'), style: mktText(15, weight: FontWeight.w800)),
      IconButton(key: const Key('soc_cal_next'), onPressed: () => _move(1), icon: const Icon(Icons.chevron_right_rounded)),
      for (final v in CalView.values) MktFilterChip(key: Key('soc_cal_view_${v.name}'), label: v.name[0].toUpperCase() + v.name.substring(1), selected: _view == v, onTap: () => setState(() => _view = v)),
      KeyedSubtree(key: const Key('soc_cal_platform'), child: MktDropdownPill<String>(value: _platform, icon: Icons.public_rounded, options: [('all', 'All Platforms'), for (final p in kPlatforms) (p.$1, p.$2)], onChanged: (v) => setState(() => _platform = v))),
      MktPrimaryButton(key: const Key('soc_cal_add'), label: 'Add Content', onPressed: () => showPostEditor(context, ref, day: _cursor)),
    ]);
    return RefreshIndicator(
      onRefresh: () async => refreshSocials(ref),
      child: ListView(
        key: const Key('socials_calendar_list'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          MktCard(
            title: 'Content Calendar',
            subtitle: 'Plan, schedule and manage all social media content',
            icon: Icons.calendar_month_outlined,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              controls,
              const SizedBox(height: 10),
              async.when(
                loading: () => const SizedBox(height: 240, child: Center(child: CircularProgressIndicator())),
                error: (e, _) => AppErrorView(error: e, onRetry: () => refreshSocials(ref)),
                data: (cal) => switch (_view) {
                  CalView.month => _MonthGrid(month: _cursor, start: from, items: cal.items, onAdd: (d) => showPostEditor(context, ref, day: d)),
                  CalView.week => _WeekRow(start: from, items: cal.items, onAdd: (d) => showPostEditor(context, ref, day: d)),
                  CalView.list => _ListView(items: cal.items),
                },
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

String _dayKey(SocialPost p) => p.day == null ? '' : _d(p.day!);

class _Chip extends ConsumerWidget {
  const _Chip({required this.post, this.compact = true});
  final SocialPost post;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = stageColor(stageKeyOf(post.status));
    return InkWell(
      key: Key('soc_post_${post.id}'),
      borderRadius: BorderRadius.circular(6),
      onTap: () => showPostEditor(context, ref, post: post),
      child: Container(
        margin: const EdgeInsets.only(bottom: 3),
        padding: EdgeInsets.symmetric(horizontal: 5, vertical: compact ? 2 : 5),
        decoration: BoxDecoration(color: Mkt.tint(formatColor(post.contentType), 0.13), borderRadius: BorderRadius.circular(6), border: Border(left: BorderSide(color: c, width: 3))),
        child: Row(children: [
          Icon(formatIcon(post.contentType), size: 11, color: formatColor(post.contentType)),
          const SizedBox(width: 4),
          Expanded(child: Text(post.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(10, weight: FontWeight.w700))),
        ]),
      ),
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({required this.month, required this.start, required this.items, required this.onAdd});
  final DateTime month;
  final DateTime start;
  final List<SocialPost> items;
  final void Function(DateTime) onAdd;

  @override
  Widget build(BuildContext context) {
    final byDay = <String, List<SocialPost>>{};
    for (final p in items) {
      byDay.putIfAbsent(_dayKey(p), () => []).add(p);
    }
    final today = _d(DateTime.now());
    // five rows are enough unless the month spills into a sixth
    final lastOfMonth = DateTime(month.year, month.month + 1, 0);
    final rows = ((lastOfMonth.difference(start).inDays + 1) / 7).ceil();
    return Column(key: const Key('soc_month_grid'), children: [
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
                final list = byDay[key] ?? const <SocialPost>[];
                return Container(
                  key: Key('soc_day_$key'),
                  height: 96,
                  margin: const EdgeInsets.all(1.5),
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(color: inMonth ? Mkt.card : Mkt.bg, borderRadius: BorderRadius.circular(8), border: Border.all(color: key == today ? Mkt.violet : Mkt.border)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Text('${day.day}', style: mktText(10.5, weight: key == today ? FontWeight.w800 : FontWeight.w500, color: key == today ? Mkt.violet : (inMonth ? Mkt.ink : Mkt.inkSoft))),
                      const Spacer(),
                      if (inMonth) InkWell(onTap: () => onAdd(day), child: const Icon(Icons.add_rounded, size: 14, color: Mkt.inkSoft)),
                    ]),
                    const SizedBox(height: 2),
                    for (final p in list.take(2)) _Chip(post: p),
                    if (list.length > 2) Text('+${list.length - 2} more', style: mktText(9.5, color: Mkt.inkSoft)),
                  ]),
                );
              }),
            ),
        ]),
    ]);
  }
}

class _WeekRow extends StatelessWidget {
  const _WeekRow({required this.start, required this.items, required this.onAdd});
  final DateTime start;
  final List<SocialPost> items;
  final void Function(DateTime) onAdd;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      key: const Key('soc_week_row'),
      scrollDirection: Axis.horizontal,
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (var i = 0; i < 7; i++)
          Builder(builder: (context) {
            final day = start.add(Duration(days: i));
            final list = items.where((p) => _dayKey(p) == _d(day)).toList();
            return Container(
              key: Key('soc_week_${_d(day)}'),
              width: 150,
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Mkt.card, borderRadius: BorderRadius.circular(10), border: Border.all(color: Mkt.border)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [Text(DateFormat('EEE d').format(day), style: mktText(12, weight: FontWeight.w800)), const Spacer(), InkWell(onTap: () => onAdd(day), child: const Icon(Icons.add_rounded, size: 16, color: Mkt.inkSoft))]),
                const SizedBox(height: 6),
                if (list.isEmpty) Text('Nothing planned', style: mktText(11, color: Mkt.inkSoft)),
                for (final p in list) _Chip(post: p, compact: false),
              ]),
            );
          }),
      ]),
    );
  }
}

class _ListView extends ConsumerWidget {
  const _ListView({required this.items});
  final List<SocialPost> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (items.isEmpty) return const MktEmpty('Nothing is planned in this month.', icon: Icons.event_busy_outlined);
    return MktTable(
      key: const Key('soc_list_table'),
      minWidth: 560,
      rowHeight: 50,
      rowKeys: [for (final p in items) Key('soc_list_${p.id}')],
      onRowTap: (i) => showPostEditor(context, ref, post: items[i]),
      columns: const [MktCol('Date', width: 74), MktCol('Post', flex: 5), MktCol('Platform', flex: 2), MktCol('Format', flex: 2), MktCol('Brand', width: 64), MktCol('Stage', width: 110, align: Alignment.centerRight)],
      rows: [
        for (final p in items)
          [
            Text(p.day == null ? '' : DateFormat('d MMM').format(p.day!), style: mktText(12, weight: FontWeight.w700)),
            Row(children: [PostThumb(url: p.thumbUrl, contentType: p.contentType, width: 34, height: 34, radius: 8), const SizedBox(width: 8), Flexible(child: Text(p.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: mktText(12.5, weight: FontWeight.w700)))]),
            Row(children: [Icon(platformIcon(p.platform), size: 14, color: Mkt.violet), const SizedBox(width: 5), Text(platformName(p.platform), style: mktText(12))]),
            Text(postFormatLabel(p.contentType), style: mktText(12)),
            Text(p.brand == 'kerala' ? 'Kerala' : 'Main', style: mktText(12, color: p.brand == 'kerala' ? Mkt.blue : Mkt.inkSoft)),
            MktChip(postStatusLabel(p.status), color: stageColor(stageKeyOf(p.status))),
          ],
      ],
    );
  }
}
