import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/marketing/data/content_item.dart';
import 'package:nizan_crm/features/marketing/presentation/kit/mkt_kit.dart';
import 'package:nizan_crm/features/marketing/services/content_service.dart';
import 'package:nizan_crm/features/marketing/presentation/screens/content_calendar_screen.dart'
    show platformColor, platformIcon, contentStatusColor;

class ContentDashboardScreen extends ConsumerWidget {
  const ContentDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(contentStatsProvider);

    return MktPage(
      child: Material(
        type: MaterialType.transparency,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: MktHeader(
              icon: Icons.insights_outlined,
              title: 'Content Dashboard',
              subtitle: 'Plan, schedule and track content across platforms',
              actions: [
                MktPill(label: 'Calendar', icon: Icons.event_note_outlined, trailing: false, onTap: () => context.go('/marketing/content/calendar')),
                MktPill(label: 'Refresh', icon: Icons.refresh, trailing: false, onTap: () => ref.invalidate(contentStatsProvider)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => AppErrorView(error: e, onRetry: () => ref.invalidate(contentStatsProvider)),
              data: (s) => RefreshIndicator(
                onRefresh: () async => ref.invalidate(contentStatsProvider),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                  children: [
                    _statGrid(s),
                    const SizedBox(height: 12),
                    MktGrid(
                      breakpoint: 900,
                      rows: [
                        [
                          (
                            1,
                            _breakdown('By platform', Icons.public, s.byPlatform, s.total,
                                labelOf: platformLabel, colorOf: platformColor, iconOf: platformIcon),
                          ),
                          (
                            1,
                            _breakdown('By status', Icons.donut_small_outlined,
                                {for (final st in contentStatuses) st: (s.byStatus[st] ?? 0)}, s.total,
                                labelOf: contentStatusLabel, colorOf: contentStatusColor, iconOf: null, hideZero: true),
                          ),
                        ],
                      ],
                    ),
                    if (s.total == 0) ...[
                      const SizedBox(height: 12),
                      _emptyHint(context),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _statGrid(ContentStats s) {
    return MktKpiRow(
      children: [
        MktKpiCard(icon: Icons.folder_copy_outlined, value: '${s.total}', label: 'Total planned', tint: Mkt.primary),
        MktKpiCard(icon: Icons.calendar_month_outlined, value: '${s.scheduledThisMonth}', label: 'Scheduled this month', tint: Mkt.blue),
        MktKpiCard(icon: Icons.check_circle_outline, value: '${s.publishedThisMonth}', label: 'Published this month', tint: Mkt.good),
        MktKpiCard(icon: Icons.hourglass_bottom_outlined, value: '${s.dueThisWeek}', label: 'Due this week', tint: Mkt.warn),
        MktKpiCard(icon: Icons.warning_amber_outlined, value: '${s.overdue}', label: 'Overdue', tint: Mkt.bad),
        MktKpiCard(icon: Icons.lightbulb_outline, value: '${s.byStatus['idea'] ?? 0}', label: 'Ideas backlog', tint: Mkt.teal),
      ],
    );
  }

  Widget _breakdown(
    String title,
    IconData titleIcon,
    Map<String, int> data,
    int total, {
    required String Function(String) labelOf,
    required Color Function(String) colorOf,
    IconData Function(String)? iconOf,
    bool hideZero = false,
  }) {
    final entries = data.entries.where((e) => !hideZero || e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final max = entries.map((e) => e.value).fold<int>(0, (m, v) => v > m ? v : m);
    return MktCard(
      title: title,
      icon: titleIcon,
      child: entries.isEmpty
          ? const MktEmpty('No data yet.', icon: Icons.bar_chart_rounded)
          : Column(children: [
              for (final e in entries)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(children: [
                    if (iconOf != null) ...[
                      Icon(iconOf(e.key), size: 15, color: colorOf(e.key)),
                      const SizedBox(width: 8),
                    ] else ...[
                      Container(width: 10, height: 10, decoration: BoxDecoration(color: colorOf(e.key), shape: BoxShape.circle)),
                      const SizedBox(width: 8),
                    ],
                    SizedBox(width: 96, child: Text(labelOf(e.key), maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(13))),
                    Expanded(
                      child: MktProgress(
                        pct: max == 0 ? 0 : (e.value / max * 100).round(),
                        color: colorOf(e.key),
                        height: 8,
                        showLabel: false,
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 28,
                      child: Text('${e.value}', textAlign: TextAlign.right, style: mktText(13, weight: FontWeight.w700)),
                    ),
                  ]),
                ),
            ]),
    );
  }

  Widget _emptyHint(BuildContext context) => MktCard(
        title: 'No content planned yet',
        icon: Icons.event_note_outlined,
        child: Column(children: [
          const MktEmpty('Open the Content Calendar and add your first post, reel, or story.', icon: Icons.event_note_outlined),
          const SizedBox(height: 4),
          MktPrimaryButton(
            onPressed: () => context.go('/marketing/content/calendar'),
            label: 'Go to Content Calendar',
          ),
        ]),
      );
}
