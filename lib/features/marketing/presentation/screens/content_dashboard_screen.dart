import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/marketing/data/content_item.dart';
import 'package:nizan_crm/features/marketing/services/content_service.dart';
import 'package:nizan_crm/features/marketing/presentation/screens/content_calendar_screen.dart'
    show platformColor, platformIcon, contentStatusColor;

class ContentDashboardScreen extends ConsumerWidget {
  const ContentDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crm = context.crmColors;
    final async = ref.watch(contentStatsProvider);

    return Scaffold(
      backgroundColor: crm.background,
      body: Column(children: [
        Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
          decoration: BoxDecoration(color: crm.surface, border: Border(bottom: BorderSide(color: crm.border))),
          child: Row(children: [
            Icon(Icons.insights_outlined, color: crm.primary),
            const SizedBox(width: 10),
            Text('Content Dashboard', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: crm.primary)),
            const Spacer(),
            TextButton.icon(
              onPressed: () => context.go('/marketing/content/calendar'),
              icon: const Icon(Icons.event_note_outlined, size: 18),
              label: const Text('Calendar'),
            ),
            IconButton(onPressed: () => ref.invalidate(contentStatsProvider), icon: const Icon(Icons.refresh)),
          ]),
        ),
        Expanded(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text(friendlyErrorMessage(e), style: TextStyle(color: crm.textSecondary))),
            data: (s) => RefreshIndicator(
              onRefresh: () async => ref.invalidate(contentStatsProvider),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  _statGrid(crm, s),
                  const SizedBox(height: 20),
                  _sectionTitle(crm, 'By platform'),
                  const SizedBox(height: 10),
                  _breakdown(crm, s.byPlatform, s.total,
                      labelOf: platformLabel, colorOf: platformColor, iconOf: platformIcon),
                  const SizedBox(height: 20),
                  _sectionTitle(crm, 'By status'),
                  const SizedBox(height: 10),
                  _breakdown(crm, {for (final st in contentStatuses) st: (s.byStatus[st] ?? 0)}, s.total,
                      labelOf: contentStatusLabel, colorOf: contentStatusColor, iconOf: null,
                      hideZero: true),
                  const SizedBox(height: 24),
                  if (s.total == 0) _emptyHint(context, crm),
                ],
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _statGrid(CrmTheme crm, ContentStats s) {
    final cards = [
      _Stat('Total planned', s.total, Icons.folder_copy_outlined, crm.primary),
      _Stat('Scheduled this month', s.scheduledThisMonth, Icons.calendar_month_outlined, Colors.blue.shade600),
      _Stat('Published this month', s.publishedThisMonth, Icons.check_circle_outline, const Color(0xFF2E8B57)),
      _Stat('Due this week', s.dueThisWeek, Icons.hourglass_bottom_outlined, Colors.orange.shade700),
      _Stat('Overdue', s.overdue, Icons.warning_amber_outlined, Colors.red.shade600),
      _Stat('Ideas backlog', s.byStatus['idea'] ?? 0, Icons.lightbulb_outline, Colors.amber.shade700),
    ];
    return LayoutBuilder(builder: (ctx, c) {
      final cols = c.maxWidth > 900 ? 3 : (c.maxWidth > 560 ? 3 : 2);
      return GridView.count(
        crossAxisCount: cols,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.5,
        children: [for (final st in cards) _statCard(crm, st)],
      );
    });
  }

  Widget _statCard(CrmTheme crm, _Stat st) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: crm.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: crm.border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(st.icon, size: 20, color: st.color),
          const Spacer(),
          Text('${st.value}', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: st.color)),
          Text(st.label, style: TextStyle(fontSize: 12, color: crm.textSecondary), maxLines: 2, overflow: TextOverflow.ellipsis),
        ]),
      );

  Widget _sectionTitle(CrmTheme crm, String t) =>
      Text(t, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: crm.primary));

  Widget _breakdown(
    CrmTheme crm,
    Map<String, int> data,
    int total, {
    required String Function(String) labelOf,
    required Color Function(String) colorOf,
    IconData Function(String)? iconOf,
    bool hideZero = false,
  }) {
    final entries = data.entries.where((e) => !hideZero || e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (entries.isEmpty) {
      return Text('No data yet.', style: TextStyle(color: crm.textSecondary, fontSize: 13));
    }
    final max = entries.map((e) => e.value).fold<int>(0, (m, v) => v > m ? v : m);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: crm.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: crm.border)),
      child: Column(children: [
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
              SizedBox(width: 96, child: Text(labelOf(e.key), style: TextStyle(fontSize: 13, color: crm.textPrimary))),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: LinearProgressIndicator(
                    value: max == 0 ? 0 : e.value / max,
                    minHeight: 8,
                    backgroundColor: crm.border,
                    valueColor: AlwaysStoppedAnimation(colorOf(e.key)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 28,
                child: Text('${e.value}', textAlign: TextAlign.right,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: crm.textPrimary)),
              ),
            ]),
          ),
      ]),
    );
  }

  Widget _emptyHint(BuildContext context, CrmTheme crm) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: crm.primary.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: crm.primary.withValues(alpha: 0.2)),
        ),
        child: Column(children: [
          Icon(Icons.event_note_outlined, color: crm.primary, size: 32),
          const SizedBox(height: 10),
          Text('No content planned yet', style: TextStyle(fontWeight: FontWeight.w700, color: crm.textPrimary)),
          const SizedBox(height: 4),
          Text('Open the Content Calendar and add your first post, reel, or story.',
              textAlign: TextAlign.center, style: TextStyle(color: crm.textSecondary, fontSize: 13)),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => context.go('/marketing/content/calendar'),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Go to Content Calendar'),
          ),
        ]),
      );
}

class _Stat {
  final String label;
  final int value;
  final IconData icon;
  final Color color;
  const _Stat(this.label, this.value, this.icon, this.color);
}
