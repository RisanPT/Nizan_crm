import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/features/marketing/data/team_models.dart';
import 'package:nizan_crm/features/marketing/presentation/kit/mkt_kit.dart';
import 'package:nizan_crm/features/marketing/services/team_service.dart';

/// The filters in a page header, in the order the marketing team's document draws them: the date range pill ("2 – 8 Nov 2026 ▾"), the
/// team pill ("Marketing Team ▾" — for a manager, to look at one member) and the brand pill ("All Brands ▾"). The document's rule is that
/// every screen filters by date range and brand, so this is one shared state: the choice follows you from tab to tab.
List<Widget> teamFilterActions(BuildContext context, WidgetRef ref, {bool showRange = true, bool showMember = true}) {
  final f = ref.watch(teamFilterProvider);
  final today = TeamFilter.day(DateTime.now());
  // a manager gets a member picker (the form's setup lists the team only for managers)
  final members = ref.watch(logSetupProvider((date: today, memberId: null))).maybeWhen(data: (s) => s.members, orElse: () => const <({String id, String name})>[]);

  void set(TeamFilter next) => ref.read(teamFilterProvider.notifier).state = next;
  final now = DateTime.now();
  final thisWeek = TeamFilter.thisWeek(now: now);
  final lastWeekStart = thisWeek.from.subtract(const Duration(days: 7));

  Future<void> pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 1),
      initialDateRange: DateTimeRange(start: f.from, end: f.to),
    );
    if (picked != null) set(f.copyWith(from: picked.start, to: picked.end));
  }

  void quick(DateTime from, DateTime to) => set(f.copyWith(from: from, to: to));

  final memberName = f.memberId == null ? null : members.where((m) => m.id == f.memberId).map((m) => m.name).firstOrNull;

  return [
    if (showRange)
      PopupMenuButton<String>(
        key: const Key('team_filter_quick'),
        tooltip: 'Date range',
        position: PopupMenuPosition.under,
        onSelected: (v) {
          switch (v) {
            case 'today':
              quick(DateTime(now.year, now.month, now.day), DateTime(now.year, now.month, now.day));
            case 'week':
              quick(thisWeek.from, thisWeek.to);
            case 'lastWeek':
              quick(lastWeekStart, lastWeekStart.add(const Duration(days: 6)));
            case 'month':
              quick(DateTime(now.year, now.month, 1), DateTime(now.year, now.month + 1, 0));
            case 'lastMonth':
              quick(DateTime(now.year, now.month - 1, 1), DateTime(now.year, now.month, 0));
            case 'custom':
              pickRange();
          }
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'today', child: Text('Today')),
          PopupMenuItem(value: 'week', child: Text('This week')),
          PopupMenuItem(value: 'lastWeek', child: Text('Last week')),
          PopupMenuItem(value: 'month', child: Text('This month')),
          PopupMenuItem(value: 'lastMonth', child: Text('Last month')),
          PopupMenuDivider(),
          PopupMenuItem(value: 'custom', child: Text('Custom range…')),
        ],
        child: IgnorePointer(child: MktDateRangePill(key: const Key('team_filter_range'), from: f.from, to: f.to, onTap: () {})),
      ),
    if (showMember && members.length > 1)
      PopupMenuButton<String?>(
        key: const Key('team_member_filter'),
        tooltip: 'Team member',
        position: PopupMenuPosition.under,
        onSelected: (id) => set(id == null ? f.copyWith(clearMember: true) : f.copyWith(memberId: id)),
        itemBuilder: (_) => [
          PopupMenuItem<String?>(value: null, child: Text('Marketing Team', style: mktText(13, weight: f.memberId == null ? FontWeight.w800 : FontWeight.w500))),
          for (final m in members) PopupMenuItem<String?>(value: m.id, child: Text(m.name, style: mktText(13, weight: f.memberId == m.id ? FontWeight.w800 : FontWeight.w500))),
        ],
        child: IgnorePointer(child: MktPill(label: memberName ?? 'Marketing Team', icon: Icons.groups_2_outlined)),
      ),
    KeyedSubtree(
      key: const Key('team_brand_pill'),
      child: MktDropdownPill<TeamBrand>(
        value: f.brand,
        icon: Icons.storefront_outlined,
        options: [for (final b in TeamBrand.values) (b, b == TeamBrand.all ? 'All Brands' : b.label)],
        onChanged: (b) => set(f.copyWith(brand: b)),
      ),
    ),
  ];
}
