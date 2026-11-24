import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/marketing/data/portfolio_models.dart';
import 'package:nizan_crm/features/marketing/data/socials_models.dart';
import 'package:nizan_crm/features/marketing/data/team_models.dart' show TeamRefusal;
import 'package:nizan_crm/features/marketing/presentation/kit/mkt_kit.dart';
import 'package:nizan_crm/features/marketing/presentation/portfolio/portfolio_widgets.dart';
import 'package:nizan_crm/features/marketing/presentation/portfolio/shoot_editor.dart';
import 'package:nizan_crm/features/marketing/presentation/socials/asset_editor.dart';
import 'package:nizan_crm/features/marketing/services/portfolio_service.dart';
import 'package:nizan_crm/features/marketing/services/socials_service.dart';

/// Creative Portfolio → Shoot Planner: the shoot plans on the left, the open one on the right with its brief, milestones and progress.
/// The plan is typed once; the progress moves when members log pre-production, production and post-production work against the shoot.
class ShootPlannerTab extends ConsumerWidget {
  const ShootPlannerTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(plannerProvider);
    return RefreshIndicator(
      onRefresh: () async => refreshPortfolio(ref),
      child: async.when(
        loading: () => ListView(children: const [SizedBox(height: 200), Center(child: CircularProgressIndicator())]),
        error: (e, _) => ListView(children: [AppErrorView(error: e, onRetry: () => refreshPortfolio(ref))]),
        data: (d) {
          final c = d.counts;
          final selected = ref.watch(selectedShootProvider);
          final openId = d.items.any((s) => s.id == selected) ? selected : (d.items.isEmpty ? null : d.items.first.id);
          return ListView(
            key: const Key('portfolio_planner_list'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            children: [
              MktKpiRow(minWidth: 180, children: [
                MktKpiCard(key: const Key('pf_kpi_planned'), icon: Icons.track_changes_rounded, value: '${c.planned}', label: 'Planned Shoots', tint: Mkt.violet),
                MktKpiCard(key: const Key('pf_kpi_production'), icon: Icons.videocam_outlined, value: '${c.inProduction}', label: 'In Production', tint: Mkt.good),
                MktKpiCard(key: const Key('pf_kpi_post'), icon: Icons.edit_outlined, value: '${c.postProduction}', label: 'In Post-production', tint: Mkt.warn),
                MktKpiCard(key: const Key('pf_kpi_completed'), icon: Icons.check_circle_outline_rounded, value: '${c.completed}', label: 'Completed', tint: Mkt.blue),
                MktKpiCard(key: const Key('pf_kpi_week'), icon: Icons.event_outlined, value: '${c.thisWeek}', label: 'This Week', tint: Mkt.pink),
              ]),
              const SizedBox(height: 12),
              MktGrid(breakpoint: 980, rows: [
                [(4, _ListCard(data: d, openId: openId)), (8, openId == null ? const MktCard(title: 'Shoot', icon: Icons.videocam_outlined, child: MktEmpty('Plan a shoot to see its brief, milestones and progress here.', icon: Icons.videocam_outlined, height: 200)) : ShootDetailCard(key: ValueKey('detail_$openId'), id: openId))],
              ]),
            ],
          );
        },
      ),
    );
  }
}

class _ListCard extends ConsumerStatefulWidget {
  const _ListCard({required this.data, required this.openId});
  final PlannerData data;
  final String? openId;

  @override
  ConsumerState<_ListCard> createState() => _ListCardState();
}

class _ListCardState extends ConsumerState<_ListCard> {
  late final _search = TextEditingController(text: ref.read(plannerQueryProvider).q);

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _set(PlannerQuery q) => ref.read(plannerQueryProvider.notifier).state = q;

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final q = ref.watch(plannerQueryProvider);
    final from = d.total == 0 ? 0 : (d.page - 1) * d.pageSize + 1;
    final to = (d.page - 1) * d.pageSize + d.items.length;
    final pages = (d.total / d.pageSize).ceil().clamp(1, 999);
    return MktCard(
      title: 'Shoot Plans',
      icon: Icons.video_library_outlined,
      trailing: TextButton(key: const Key('pf_new_plan_inline'), onPressed: () => showShootEditor(context, ref), child: Text('+ New Plan', style: mktText(11.5, weight: FontWeight.w700, color: Mkt.violet))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        TextField(
          key: const Key('pf_search'),
          controller: _search,
          onChanged: (v) => _set(PlannerQuery(status: q.status, q: v)),
          style: mktText(13),
          decoration: InputDecoration(prefixIcon: const Icon(Icons.search_rounded, size: 18), hintText: 'Search shoot plan…', isDense: true, contentPadding: const EdgeInsets.symmetric(vertical: 10), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: const BorderSide(color: Mkt.border)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: const BorderSide(color: Mkt.violet))),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
          for (final f in const [('all', 'All'), ('planned', 'Planned'), ('in_production', 'In Production'), ('post_production', 'Post'), ('completed', 'Completed')]) Padding(padding: const EdgeInsets.only(right: 6), child: MktFilterChip(key: Key('pf_status_${f.$1}'), label: f.$2, selected: q.status == f.$1, onTap: () => _set(PlannerQuery(status: f.$1, q: q.q)))),
        ])),
        const SizedBox(height: 8),
        if (d.items.isEmpty) const MktEmpty('No shoot plan in this period. Use New Shoot Plan.', icon: Icons.videocam_outlined, height: 130),
        for (final s in d.items)
          InkWell(
            key: Key('pf_plan_${s.id}'),
            borderRadius: BorderRadius.circular(12),
            onTap: () => ref.read(selectedShootProvider.notifier).state = s.id,
            child: Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: s.id == widget.openId ? Mkt.violetSoft : Mkt.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: s.id == widget.openId ? Mkt.violet : Mkt.border)),
              child: Row(children: [
                ShootCover(url: s.coverUrl, size: 46),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(s.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(12.5, weight: FontWeight.w800)),
                    Text([if (s.category.isNotEmpty) s.category, s.shootType].where((x) => x.isNotEmpty).join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(10.5, color: Mkt.inkSoft)),
                    Row(children: [const Icon(Icons.event_outlined, size: 11, color: Mkt.inkSoft), const SizedBox(width: 4), Flexible(child: Text(shootDay(s.shootDate, pattern: 'd MMM yyyy'), maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(10.5, color: Mkt.inkSoft)))]),
                  ]),
                ),
                const SizedBox(width: 6),
                MktChip(shootStatusLabel(s.status), color: shootStatusColor(s.status)),
              ]),
            ),
          ),
        const SizedBox(height: 4),
        Row(children: [
          Flexible(child: Text(d.total == 0 ? 'No shoots' : 'Showing $from–$to of ${d.total}', key: const Key('pf_showing'), maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(11, color: Mkt.inkSoft))),
          const Spacer(),
          IconButton(key: const Key('pf_prev'), visualDensity: VisualDensity.compact, onPressed: d.page > 1 ? () => _set(PlannerQuery(status: q.status, q: q.q, page: d.page - 1)) : null, icon: const Icon(Icons.chevron_left_rounded, size: 20)),
          Text('${d.page} / $pages', style: mktText(11.5, weight: FontWeight.w700)),
          IconButton(key: const Key('pf_next'), visualDensity: VisualDensity.compact, onPressed: d.page < pages ? () => _set(PlannerQuery(status: q.status, q: q.q, page: d.page + 1)) : null, icon: const Icon(Icons.chevron_right_rounded, size: 20)),
        ]),
      ]),
    );
  }
}

enum _Part { brief, moodboard, plan, crew, approvals }

/// The open shoot: header with its status, five views (Brief, Moodboard, Content Plan, Crew & Logistics, Approvals), milestones and progress.
class ShootDetailCard extends ConsumerStatefulWidget {
  const ShootDetailCard({super.key, required this.id});
  final String id;

  @override
  ConsumerState<ShootDetailCard> createState() => _ShootDetailCardState();
}

class _ShootDetailCardState extends ConsumerState<ShootDetailCard> {
  _Part _part = _Part.brief;

  static const _labels = {_Part.brief: 'Brief', _Part.moodboard: 'Moodboard', _Part.plan: 'Content Plan', _Part.crew: 'Crew & Logistics', _Part.approvals: 'Approvals'};

  Future<void> _setStatus(ShootDetail d, String status) async {
    try {
      await ref.read(marketingPortfolioServiceProvider).saveShoot({'status': status}, id: d.summary.id);
      refreshPortfolio(ref);
    } on TeamRefusal catch (r) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(r.message)));
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    }
  }

  Future<void> _delete(ShootDetail d) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete this shoot plan?'),
        content: Text('"${d.summary.title}" is removed. A shoot that has assets or logged work cannot be deleted — cancel it instead.'),
        actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')), FilledButton(key: const Key('shoot_delete_confirm'), onPressed: () => Navigator.pop(c, true), child: const Text('Delete'))],
      ),
    );
    if (yes != true) return;
    try {
      await ref.read(marketingPortfolioServiceProvider).deleteShoot(d.summary.id);
      ref.read(selectedShootProvider.notifier).state = null;
      refreshPortfolio(ref);
    } on TeamRefusal catch (r) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(r.message)));
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(shootDetailProvider(widget.id));
    return async.when(
      loading: () => const MktCard(title: 'Shoot', icon: Icons.videocam_outlined, child: SizedBox(height: 240, child: Center(child: CircularProgressIndicator()))),
      error: (e, _) => MktCard(title: 'Shoot', icon: Icons.videocam_outlined, child: AppErrorView(error: e, onRetry: () => ref.invalidate(shootDetailProvider(widget.id)))),
      data: (d) {
        final s = d.summary;
        return MktCard(
          title: s.title,
          subtitle: [if (s.category.isNotEmpty) s.category, s.shootType].where((x) => x.isNotEmpty).join(' · '),
          icon: Icons.videocam_outlined,
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            KeyedSubtree(key: const Key('shoot_status_pill'), child: MktDropdownPill<String>(value: s.status, icon: Icons.circle, options: [for (final st in kShootStatuses) (st.$1, st.$2)], onChanged: (v) => _setStatus(d, v))),
            PopupMenuButton<String>(
              key: const Key('shoot_menu'),
              onSelected: (v) => v == 'edit' ? showShootEditor(context, ref, shoot: d) : _delete(d),
              itemBuilder: (_) => const [PopupMenuItem(value: 'edit', child: Text('Edit plan')), PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Mkt.bad)))],
            ),
          ]),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(spacing: 14, runSpacing: 4, children: [
              _fact(Icons.event_outlined, shootDay(s.shootDate)),
              if (s.time.isNotEmpty) _fact(Icons.schedule_rounded, s.time),
              if (s.location.isNotEmpty) _fact(Icons.place_outlined, s.location),
              _fact(Icons.groups_2_outlined, '${s.crewCount} crew'),
              if (s.rescheduleCount > 0) _fact(Icons.update_rounded, 'Rescheduled ${s.rescheduleCount}×'),
              if (s.delayed) const MktChip('Delayed', color: Mkt.bad),
            ]),
            const SizedBox(height: 10),
            SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [for (final p in _Part.values) Padding(padding: const EdgeInsets.only(right: 6), child: MktFilterChip(key: Key('pf_part_${p.name}'), label: _labels[p]!, selected: _part == p, onTap: () => setState(() => _part = p)))])),
            const SizedBox(height: 10),
            switch (_part) {
              _Part.brief => _Brief(d: d),
              _Part.moodboard => _Moodboard(d: d),
              _Part.plan => _Plan(d: d),
              _Part.crew => _Crew(d: d),
              _Part.approvals => _Approvals(d: d),
            },
            const SizedBox(height: 12),
            _Progress(d: d),
          ]),
        );
      },
    );
  }

  Widget _fact(IconData icon, String text) => Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 14, color: Mkt.inkSoft), const SizedBox(width: 5), Text(text, style: mktText(11.5, color: Mkt.inkSoft))]);
}

class _Brief extends StatelessWidget {
  const _Brief({required this.d});
  final ShootDetail d;

  @override
  Widget build(BuildContext context) {
    Widget row(String k, String v) => v.isEmpty ? const SizedBox.shrink() : Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [SizedBox(width: 96, child: Text(k, style: mktText(11.5, color: Mkt.inkSoft))), Expanded(child: Text(v, style: mktText(12.5, weight: FontWeight.w600)))]));
    final planned = [for (final o in kOutputKeys) if ((d.summary.planned[o.$1] ?? 0) > 0) '${d.summary.planned[o.$1]} ${o.$2.toLowerCase()}'];
    return Container(
      key: const Key('pf_brief'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Mkt.bg, borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Shoot Brief', style: mktText(12.5, weight: FontWeight.w800)),
        const SizedBox(height: 4),
        row('Objective', d.objective),
        row('Audience', d.audience),
        row('Content pillar', d.pillar),
        row('Shoot type', d.summary.shootType),
        row('Notes', d.notes),
        if (d.objective.isEmpty && d.audience.isEmpty && d.pillar.isEmpty && d.notes.isEmpty) Text('No brief written yet — Edit plan to add the objective and audience.', style: mktText(11.5, color: Mkt.inkSoft)),
        const SizedBox(height: 6),
        Text('Outputs (Planned)', style: mktText(11.5, color: Mkt.inkSoft)),
        const SizedBox(height: 4),
        planned.isEmpty ? Text('None planned', style: mktText(11.5, color: Mkt.inkSoft)) : Wrap(spacing: 6, runSpacing: 6, children: [for (final p in planned) MktChip(p, color: Mkt.violet)]),
      ]),
    );
  }
}

class _Moodboard extends StatelessWidget {
  const _Moodboard({required this.d});
  final ShootDetail d;

  @override
  Widget build(BuildContext context) {
    if (d.references.isEmpty) return const MktEmpty('No reference links yet — add them in Edit plan.', icon: Icons.photo_library_outlined, height: 110);
    return Column(key: const Key('pf_moodboard'), children: [
      for (final r in d.references)
        ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.link_rounded, color: Mkt.violet),
          title: Text(r.label.isEmpty ? r.url : r.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(12.5, weight: FontWeight.w700)),
          subtitle: r.label.isEmpty ? null : Text(r.url, maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(10.5, color: Mkt.inkSoft)),
          trailing: const Icon(Icons.open_in_new_rounded, size: 16),
          onTap: () => launchUrl(Uri.parse(r.url), mode: LaunchMode.externalApplication),
        ),
    ]);
  }
}

class _Plan extends ConsumerWidget {
  const _Plan({required this.d});
  final ShootDetail d;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = d.summary;
    final rows = [for (final o in kOutputKeys) if ((s.planned[o.$1] ?? 0) > 0 || (s.delivered[o.$1] ?? 0) > 0) (o.$2, s.planned[o.$1] ?? 0, s.delivered[o.$1] ?? 0)];
    return Column(key: const Key('pf_plan'), crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (rows.isEmpty) const MktEmpty('No outputs are planned. Add them in Edit plan.', icon: Icons.checklist_rounded, height: 90) else
        for (final r in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(children: [
              SizedBox(width: 110, child: Text(r.$1, style: mktText(12.5))),
              Expanded(child: MktProgress(pct: r.$2 == 0 ? 100 : (r.$3 * 100 / r.$2).round().clamp(0, 100), color: r.$3 >= r.$2 ? Mkt.good : Mkt.violet2, labelWidth: 0, showLabel: false)),
              const SizedBox(width: 10),
              Text('${r.$3} / ${r.$2}', style: mktText(12, weight: FontWeight.w800)),
            ]),
          ),
      const SizedBox(height: 6),
      Text('Delivered = an asset attached to this shoot that is Approved or marked Final.', style: mktText(11, color: Mkt.inkSoft)),
      const SizedBox(height: 8),
      Align(alignment: Alignment.centerLeft, child: OutlinedButton.icon(key: const Key('pf_add_asset'), onPressed: () => showAssetEditor(context, ref, shootId: s.id, brand: s.brand), icon: const Icon(Icons.add_rounded, size: 16), label: const Text('Add asset to this shoot'))),
      if (d.assets.isNotEmpty) ...[
        const SizedBox(height: 10),
        Text('Assets (${d.assets.length})', style: mktText(12.5, weight: FontWeight.w800)),
        for (final a in d.assets.take(8))
          ListTile(key: Key('pf_asset_${a.id}'), dense: true, contentPadding: EdgeInsets.zero, leading: Icon(a.media == 'video' ? Icons.play_circle_outline_rounded : Icons.image_outlined, color: Mkt.violet), title: Text(a.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(12.5, weight: FontWeight.w600)), subtitle: Text(assetKindLabel(a.kind), style: mktText(10.5, color: Mkt.inkSoft)), trailing: MktChip(assetStageLabel(a.stage), color: a.stage == 'approved' ? Mkt.good : Mkt.grey), onTap: () => launchUrl(Uri.parse(a.url), mode: LaunchMode.externalApplication)),
      ],
    ]);
  }
}

class _Crew extends StatelessWidget {
  const _Crew({required this.d});
  final ShootDetail d;

  @override
  Widget build(BuildContext context) {
    final s = d.summary;
    return Column(key: const Key('pf_crew'), crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(spacing: 14, children: [
        Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.place_outlined, size: 15, color: Mkt.inkSoft), const SizedBox(width: 5), Text(s.location.isEmpty ? 'No location' : s.location, style: mktText(12.5))]),
        Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.schedule_rounded, size: 15, color: Mkt.inkSoft), const SizedBox(width: 5), Text(s.time.isEmpty ? 'No time set' : s.time, style: mktText(12.5))]),
      ]),
      const SizedBox(height: 8),
      if (d.crew.isEmpty) const MktEmpty('No crew assigned yet.', icon: Icons.groups_2_outlined, height: 80) else
        for (final c in d.crew)
          Padding(padding: const EdgeInsets.symmetric(vertical: 5), child: Row(children: [MktAvatar(c.name, size: 28), const SizedBox(width: 10), Expanded(child: Text(c.name, style: mktText(12.5, weight: FontWeight.w700))), if (c.role.isNotEmpty) MktChip(c.role, color: Mkt.violet)])),
    ]);
  }
}

class _Approvals extends ConsumerWidget {
  const _Approvals({required this.d});
  final ShootDetail d;

  Future<void> _stage(BuildContext context, WidgetRef ref, ShootAsset a, String stage) async {
    try {
      await ref.read(marketingSocialsServiceProvider).saveAsset({'stage': stage}, id: a.id);
      refreshPortfolio(ref);
    } on TeamRefusal catch (r) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(r.message)));
    } catch (e) {
      if (context.mounted) showErrorSnackBar(context, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = d.assets.where((a) => a.stage != 'raw').toList();
    if (list.isEmpty) return const MktEmpty('Nothing is waiting for approval. Assets that leave raw footage appear here.', icon: Icons.verified_outlined, height: 100);
    return Column(key: const Key('pf_approvals'), children: [
      for (final a in list)
        Padding(
          key: Key('pf_approval_${a.id}'),
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(children: [
            Expanded(child: Text(a.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(12.5, weight: FontWeight.w700))),
            MktChip(assetStageLabel(a.stage), color: a.stage == 'approved' ? Mkt.good : (a.stage == 'rejected' ? Mkt.bad : Mkt.warn)),
            if (a.stage != 'approved') IconButton(key: Key('pf_approve_${a.id}'), tooltip: 'Approve', visualDensity: VisualDensity.compact, onPressed: () => _stage(context, ref, a, 'approved'), icon: const Icon(Icons.check_circle_outline_rounded, color: Mkt.good, size: 20)),
            if (a.stage != 'rejected') IconButton(key: Key('pf_reject_${a.id}'), tooltip: 'Reject', visualDensity: VisualDensity.compact, onPressed: () => _stage(context, ref, a, 'rejected'), icon: const Icon(Icons.cancel_outlined, color: Mkt.bad, size: 20)),
          ]),
        ),
    ]);
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.d});
  final ShootDetail d;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('pf_progress'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(border: Border.all(color: Mkt.border), borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Milestone & Progress', style: mktText(12.5, weight: FontWeight.w800)),
          const SizedBox(height: 10),
          MilestoneStepper(milestones: d.milestones, current: d.currentMilestone),
          if (d.activity.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('Moves when work is logged against this shoot:', style: mktText(10.5, color: Mkt.inkSoft)),
            for (final l in d.activity.take(3)) Text('• ${l.member.isEmpty ? '' : '${l.member}: '}${l.workedOn}${l.stage.isEmpty ? '' : ' (${kMilestoneLabels[l.stage] ?? l.stage})'}', maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(10.5, color: Mkt.inkSoft)),
          ],
        ])),
        const SizedBox(width: 14),
        ProgressRing(pct: d.summary.progress),
      ]),
    );
  }
}
