import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/marketing/data/socials_models.dart';
import 'package:nizan_crm/features/marketing/presentation/kit/mkt_kit.dart';
import 'package:nizan_crm/features/marketing/presentation/socials/post_editor.dart';
import 'package:nizan_crm/features/marketing/presentation/socials/socials_targets_dialog.dart';
import 'package:nizan_crm/features/marketing/presentation/socials/socials_widgets.dart';
import 'package:nizan_crm/features/marketing/presentation/team/team_widgets.dart' show workStatusColor, shortDay;
import 'package:nizan_crm/features/marketing/data/team_models.dart' show WorkStatus;
import 'package:nizan_crm/features/marketing/services/socials_service.dart';

/// Socials → Overview, laid out as the document draws it: the format counts, the publishing pipeline and workflow, the platform split,
/// the activity tracker (targets against what members logged), this week's calendar, the team's logged work, engagement, recent
/// posts, organic Instagram leads and the week's focus. Every number is read from the posts, the logs and the CRM's leads.
class SocialsOverviewTab extends ConsumerWidget {
  const SocialsOverviewTab({super.key, this.onGo});

  /// Jump to another tab ("View All" links).
  final void Function(String tab)? onGo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(socialsOverviewProvider);
    return RefreshIndicator(
      onRefresh: () async => refreshSocials(ref),
      child: data.when(
        loading: () => ListView(children: const [SizedBox(height: 200), Center(child: CircularProgressIndicator())]),
        error: (e, _) => ListView(children: [AppErrorView(error: e, onRetry: () => refreshSocials(ref))]),
        data: (o) {
          final k = o.kpis;
          Widget kpi(String key, IconData icon, String label, int value, String changeKey, Color tint) {
            final d = deltaOf(k.change[changeKey]);
            return MktKpiCard(key: Key(key), icon: icon, value: '$value', label: label, note: d?.text, good: d?.good, tint: tint);
          }

          return ListView(
            key: const Key('socials_overview_list'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            children: [
              MktKpiRow(children: [
                kpi('soc_kpi_total', Icons.layers_outlined, 'Total Posts', k.total, 'total', Mkt.violet),
                kpi('soc_kpi_reels', Icons.play_circle_outline_rounded, 'Reels', k.reels, 'reels', Mkt.pink),
                kpi('soc_kpi_trial', Icons.science_outlined, 'Trial Reels', k.trialReels, 'trialReels', Mkt.warn),
                kpi('soc_kpi_stories', Icons.auto_stories_outlined, 'Stories', k.stories, 'stories', Mkt.violet2),
                kpi('soc_kpi_feed', Icons.view_carousel_outlined, 'Feed / Carousel', k.feed, 'feed', Mkt.warn),
                kpi('soc_kpi_collab', Icons.people_alt_outlined, 'Collab Posts', k.collab, 'collab', Mkt.blue),
              ]),
              const SizedBox(height: 12),
              MktGrid(rows: [
                [(4, _PipelineCard(o: o)), (5, _WorkflowCard(o: o)), (3, _PlatformsCard(o: o))],
                [
                  (4, _TrackerCard(o: o)),
                  (
                    8,
                    Column(children: [
                      _CalendarStrip(o: o, onSeeAll: () => onGo?.call('calendar')),
                      const SizedBox(height: 12),
                      MktGrid(breakpoint: 760, rows: [
                        [(6, _TeamCard(o: o)), (5, _EngagementCard(o: o))],
                      ]),
                    ]),
                  ),
                ],
                [(4, _RecentCard(o: o, onSeeAll: () => onGo?.call('performance'))), (4, _LeadsCard(o: o)), (4, _FocusCard(o: o))],
              ]),
            ],
          );
        },
      ),
    );
  }
}

class _PipelineCard extends StatelessWidget {
  const _PipelineCard({required this.o});
  final SocialsOverview o;

  @override
  Widget build(BuildContext context) {
    // the document lists them Published first
    final order = ['published', 'scheduled', 'producing', 'in_review', 'planned'];
    final stages = [for (final key in order) o.pipeline.stages.firstWhere((s) => s.key == key, orElse: () => StageCount(key: key, label: key))];
    return MktCard(
      title: 'Publishing Pipeline',
      icon: Icons.layers_outlined,
      child: o.pipeline.total == 0
          ? const MktEmpty('Nothing planned in this period.', icon: Icons.layers_outlined)
          : MktDonut(
              centerKey: const Key('soc_pipeline_total'),
              centerValue: '${o.pipeline.total}',
              centerLabel: 'Contents',
              colors: [for (final s in stages) stageColor(s.key)],
              slices: [for (final s in stages) (label: s.label, value: s.count.toDouble(), trailing: '${s.count}  ${s.pct}%')],
            ),
    );
  }
}

class _WorkflowCard extends StatelessWidget {
  const _WorkflowCard({required this.o});
  final SocialsOverview o;

  @override
  Widget build(BuildContext context) {
    const steps = [('planned', 'Planned', Icons.lightbulb_outline_rounded), ('producing', 'Producing', Icons.movie_creation_outlined), ('in_review', 'In Review', Icons.edit_outlined), ('scheduled', 'Scheduled', Icons.event_outlined), ('published', 'Published', Icons.check_circle_outline_rounded)];
    return MktCard(
      title: 'Content Workflow',
      icon: Icons.account_tree_outlined,
      child: LayoutBuilder(builder: (context, box) {
        final tile = (box.maxWidth - 4 * 18) / 5;
        return Row(children: [
          for (var i = 0; i < steps.length; i++) ...[
            if (i > 0) const SizedBox(width: 18, child: Icon(Icons.arrow_forward_rounded, size: 14, color: Mkt.inkSoft)),
            SizedBox(
              width: tile.clamp(48, 120).toDouble(),
              child: Container(
                key: Key('soc_flow_${steps[i].$1}'),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(color: Mkt.tint(stageColor(steps[i].$1), 0.10), borderRadius: BorderRadius.circular(12)),
                child: Column(children: [
                  Icon(steps[i].$3, size: 18, color: stageColor(steps[i].$1)),
                  const SizedBox(height: 4),
                  Text('${o.pipeline.countOf(steps[i].$1)}', style: mktText(18, weight: FontWeight.w800, color: stageColor(steps[i].$1))),
                  FittedBox(fit: BoxFit.scaleDown, child: Text(steps[i].$2, style: mktText(10, weight: FontWeight.w700, color: Mkt.inkSoft))),
                ]),
              ),
            ),
          ],
        ]);
      }),
    );
  }
}

class _PlatformsCard extends StatelessWidget {
  const _PlatformsCard({required this.o});
  final SocialsOverview o;

  @override
  Widget build(BuildContext context) {
    return MktCard(
      title: 'Platform Distribution',
      icon: Icons.hub_outlined,
      child: o.platforms.isEmpty
          ? const MktEmpty('No posts went out in this period.', icon: Icons.hub_outlined)
          : Column(children: [
              for (final p in o.platforms)
                Padding(
                  key: Key('soc_platform_${p.platform}_${p.brand}'),
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(children: [
                    Icon(platformIcon(p.platform), size: 16, color: Mkt.violet),
                    const SizedBox(width: 8),
                    Expanded(child: Text(p.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(12))),
                    Text('${p.count}', style: mktText(12.5, weight: FontWeight.w800)),
                    const SizedBox(width: 8),
                    if (p.spark.length > 1 && p.spark.any((v) => v > 0)) SizedBox(width: 38, height: 18, child: MktSparkline(values: [for (final v in p.spark) v.toDouble()], color: Mkt.good)),
                    const SizedBox(width: 6),
                    SizedBox(width: 46, child: _ChangeChip(p.change)),
                  ]),
                ),
            ]),
    );
  }
}

class _ChangeChip extends StatelessWidget {
  const _ChangeChip(this.change);
  final int? change;

  @override
  Widget build(BuildContext context) {
    if (change == null) return const SizedBox.shrink();
    if (change == 0) return MktChip('0%', color: Mkt.grey);
    return MktChip('${change! > 0 ? '+' : '−'}${change!.abs()}%', color: change! > 0 ? Mkt.good : Mkt.bad);
  }
}

class _TrackerCard extends ConsumerWidget {
  const _TrackerCard({required this.o});
  final SocialsOverview o;

  String _n(double v) => v == v.roundToDouble() ? '${v.toInt()}' : v.toStringAsFixed(1);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MktCard(
      title: 'Content Activity Tracker',
      icon: Icons.grid_view_rounded,
      trailing: TextButton(key: const Key('soc_set_targets'), onPressed: () => showSocialsTargets(context, ref), child: Text('Set targets', style: mktText(11.5, weight: FontWeight.w700, color: Mkt.violet))),
      child: !o.hasMetrics
          ? const MktEmpty('No activities are set up under Socials yet. Add them in Team → EOD → Setup, and they appear here.', icon: Icons.grid_view_rounded, height: 120)
          : MktTable(
              minWidth: 330,
              rowHeight: 40,
              columns: const [MktCol('Activity', flex: 5), MktCol('Target', width: 52, align: Alignment.center), MktCol('Done', width: 52, align: Alignment.center), MktCol('Progress', flex: 4)],
              rowKeys: [for (final r in o.tracker) Key('soc_tracker_${r.metricId}')],
              rows: [
                for (final r in o.tracker)
                  [
                    Text(r.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: mktText(12)),
                    Text(r.target == null ? '—' : _n(r.target!), style: mktText(12, color: Mkt.inkSoft)),
                    Text(_n(r.completed), style: mktText(12, weight: FontWeight.w700)),
                    r.progress == null
                        ? Text('No target', style: mktText(11, color: Mkt.inkSoft))
                        : Padding(padding: const EdgeInsets.only(right: 4), child: MktProgress(pct: r.progress!.clamp(0, 999), color: r.progress! >= 100 ? Mkt.good : (r.progress! >= 60 ? Mkt.violet2 : Mkt.warn), labelWidth: 42)),
                  ],
              ],
            ),
    );
  }
}

class _CalendarStrip extends StatelessWidget {
  const _CalendarStrip({required this.o, this.onSeeAll});
  final SocialsOverview o;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    return MktCard(
      title: 'Content Calendar',
      subtitle: o.calendar.isEmpty ? null : 'Week of ${shortDay(o.calendar.first.day)}',
      icon: Icons.calendar_month_outlined,
      link: onSeeAll == null ? null : 'View Calendar',
      linkKey: const Key('soc_calendar_link'),
      onLink: onSeeAll,
      child: LayoutBuilder(builder: (context, box) {
        // seven days across the card; below a readable width the strip scrolls sideways instead of squeezing
        const gap = 6.0;
        final w = ((box.maxWidth - gap * 6) / 7).clamp(92.0, 160.0);
        final strip = Row(crossAxisAlignment: CrossAxisAlignment.start, spacing: gap, children: [
          for (final d in o.calendar)
            SizedBox(
              key: Key('soc_cal_${d.day}'),
              width: w,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(DateFormat('EEE').format(DateTime.parse(d.day)), style: mktText(11.5, weight: FontWeight.w800)),
                Text(DateFormat('d MMM').format(DateTime.parse(d.day)), style: mktText(10.5, color: Mkt.inkSoft)),
                const SizedBox(height: 6),
                if (d.items.isEmpty)
                  Container(height: 70, decoration: BoxDecoration(border: Border.all(color: Mkt.border), borderRadius: BorderRadius.circular(10)), alignment: Alignment.center, child: Text('—', style: mktText(12, color: Mkt.inkSoft)))
                else
                  for (final p in d.items.take(2))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Stack(children: [
                        PostThumb(url: p.thumbUrl, contentType: p.contentType, width: w, height: 70),
                        Positioned(left: 6, bottom: 5, right: 6, child: Text(p.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(9.5, weight: FontWeight.w700, color: p.thumbUrl.isEmpty ? Mkt.ink : Colors.white))),
                        Positioned(right: 5, top: 5, child: Icon(platformIcon(p.platform), size: 12, color: p.thumbUrl.isEmpty ? Mkt.inkSoft : Colors.white)),
                      ]),
                    ),
                if (d.items.length > 2) Text('+${d.items.length - 2} more', style: mktText(10.5, color: Mkt.inkSoft)),
              ]),
            ),
        ]);
        return box.maxWidth >= 92 * 7 + gap * 6 ? strip : SingleChildScrollView(scrollDirection: Axis.horizontal, child: strip);
      }),
    );
  }
}

class _TeamCard extends StatelessWidget {
  const _TeamCard({required this.o});
  final SocialsOverview o;

  @override
  Widget build(BuildContext context) {
    return MktCard(
      title: 'Team Activities (Socials)',
      subtitle: o.teamDay.isEmpty ? null : shortDay(o.teamDay),
      icon: Icons.groups_2_outlined,
      child: o.teamActivities.isEmpty
          ? const MktEmpty('Nothing logged for Socials today.', icon: Icons.edit_note_rounded)
          : MktTable(
              minWidth: 300,
              rowHeight: 44,
              rowKeys: [for (final t in o.teamActivities) Key('soc_team_${t.memberId}')],
              columns: const [MktCol('Team Member', flex: 3), MktCol('Today\'s Activities', flex: 5), MktCol('Status', width: 84, align: Alignment.centerRight)],
              rows: [
                for (final t in o.teamActivities)
                  [
                    Row(children: [MktAvatar(t.name, size: 22), const SizedBox(width: 6), Flexible(child: Text(t.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(12, weight: FontWeight.w700)))]),
                    Text(t.activities.join(', '), maxLines: 2, overflow: TextOverflow.ellipsis, style: mktText(11.5, color: Mkt.inkSoft)),
                    MktChip(t.status == 'completed' ? 'Completed' : 'In Progress', color: workStatusColor(t.status == 'completed' ? WorkStatus.completed : WorkStatus.inProgress)),
                  ],
              ],
            ),
    );
  }
}

class _EngagementCard extends StatelessWidget {
  const _EngagementCard({required this.o});
  final SocialsOverview o;

  @override
  Widget build(BuildContext context) {
    final e = o.engagement;
    Widget stat(String key, IconData icon, Color c, int v, String label, int? change) {
      final d = deltaOf(change, tail: '');
      return Container(
        key: Key(key),
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(children: [
          Icon(icon, size: 18, color: c),
          const SizedBox(height: 4),
          Text(compactCount(v), style: mktText(15, weight: FontWeight.w800)),
          Text(label, style: mktText(10.5, color: Mkt.inkSoft)),
          if (d != null) Text(change == 0 ? '—' : '${change! > 0 ? '↑' : '↓'} ${change.abs()}%', style: mktText(10, weight: FontWeight.w700, color: d.good == null ? Mkt.inkSoft : (d.good! ? Mkt.good : Mkt.bad))),
        ]),
      );
    }

    return MktCard(
      title: 'Engagement Overview',
      icon: Icons.favorite_border_rounded,
      child: e.engagements == 0 && e.reach == 0
          ? const MktEmpty('No numbers have been typed on this period\'s posts yet.', icon: Icons.favorite_border_rounded)
          : Row(children: [
              Expanded(child: stat('soc_eng_likes', Icons.favorite_rounded, Mkt.pink, e.likes, 'Likes', e.change['likes'])),
              Expanded(child: stat('soc_eng_comments', Icons.chat_bubble_outline_rounded, Mkt.violet2, e.comments, 'Comments', e.change['comments'])),
              Expanded(child: stat('soc_eng_reposts', Icons.repeat_rounded, Mkt.good, e.reposts, 'Reposts', e.change['reposts'])),
              Expanded(child: stat('soc_eng_shares', Icons.send_outlined, Mkt.violet, e.shares, 'Shares', e.change['shares'])),
              Expanded(child: stat('soc_eng_saves', Icons.bookmark_border_rounded, Mkt.warn, e.saves, 'Saves', e.change['saves'])),
            ]),
    );
  }
}

class _RecentCard extends StatelessWidget {
  const _RecentCard({required this.o, this.onSeeAll});
  final SocialsOverview o;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    return MktCard(
      title: 'Recent Posts',
      icon: Icons.photo_library_outlined,
      link: onSeeAll == null ? null : 'View All',
      linkKey: const Key('soc_recent_link'),
      onLink: onSeeAll,
      child: o.recentPosts.isEmpty
          ? const MktEmpty('No posts have gone out in this period.', icon: Icons.photo_library_outlined)
          : Row(children: [
              for (final p in o.recentPosts)
                Expanded(
                  child: Padding(
                    key: Key('soc_recent_${p.id}'),
                    padding: const EdgeInsets.only(right: 8),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      AspectRatio(aspectRatio: 0.9, child: LayoutBuilder(builder: (context, box) => PostThumb(url: p.thumbUrl, contentType: p.contentType, width: box.maxWidth, height: box.maxHeight))),
                      const SizedBox(height: 4),
                      Text(p.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(11, weight: FontWeight.w700)),
                      Text(p.views > 0 ? '${compactCount(p.views)} views' : postFormatLabel(p.contentType), style: mktText(10.5, color: Mkt.inkSoft)),
                    ]),
                  ),
                ),
            ]),
    );
  }
}

class _LeadsCard extends StatelessWidget {
  const _LeadsCard({required this.o});
  final SocialsOverview o;

  @override
  Widget build(BuildContext context) {
    final l = o.leads;
    final d = deltaOf(l.change);
    return MktCard(
      title: 'Leads & Inquiries (Organic)',
      icon: Icons.person_search_outlined,
      child: Row(children: [
        Expanded(
          flex: 4,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${l.total}', key: const Key('soc_leads_total'), style: mktText(30, weight: FontWeight.w800, spacing: -0.5)),
            Text('Total Leads', style: mktText(11.5, color: Mkt.inkSoft)),
            if (d != null) Text(d.text, style: mktText(10.5, weight: FontWeight.w700, color: d.good == null ? Mkt.inkSoft : (d.good! ? Mkt.good : Mkt.bad))),
          ]),
        ),
        Expanded(
          flex: 5,
          child: Column(children: [
            for (final r in [('Instagram (Main)', l.main, 'soc_leads_main'), ('Instagram (Kerala)', l.kerala, 'soc_leads_kerala')])
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(children: [
                  const Icon(Icons.camera_alt_outlined, size: 15, color: Mkt.pink),
                  const SizedBox(width: 6),
                  Expanded(child: Text(r.$1, maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(11.5))),
                  Text('${r.$2}', key: Key(r.$3), style: mktText(12.5, weight: FontWeight.w800)),
                ]),
              ),
          ]),
        ),
      ]),
    );
  }
}

class _FocusCard extends StatelessWidget {
  const _FocusCard({required this.o});
  final SocialsOverview o;

  @override
  Widget build(BuildContext context) {
    return MktCard(
      title: "This Week's Focus",
      icon: Icons.track_changes_rounded,
      child: o.focus.isEmpty
          ? const MktEmpty('No Socials task is due this week.', icon: Icons.track_changes_rounded)
          : Column(children: [
              for (final f in o.focus)
                Padding(
                  key: Key('soc_focus_${f.id}'),
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(children: [
                    Icon(f.done ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded, size: 18, color: f.done ? Mkt.good : Mkt.inkSoft),
                    const SizedBox(width: 8),
                    Expanded(child: Text(f.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: mktText(12, color: f.done ? Mkt.inkSoft : Mkt.ink))),
                    const SizedBox(width: 8),
                    SizedBox(width: 90, child: MktProgress(pct: f.done ? 100 : f.progress, color: Mkt.violet2, labelWidth: 34)),
                  ]),
                ),
            ]),
    );
  }
}

/// The header button's action on every Socials tab: a new post.
Future<void> createContent(BuildContext context, WidgetRef ref) => showPostEditor(context, ref);
