import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/marketing/data/socials_models.dart';
import 'package:nizan_crm/features/marketing/data/team_models.dart' show TeamBrand;
import 'package:nizan_crm/features/marketing/presentation/kit/mkt_kit.dart';
import 'package:nizan_crm/features/marketing/presentation/socials/asset_editor.dart';
import 'package:nizan_crm/features/marketing/presentation/socials/socials_assets_tab.dart' show AssetGrid;
import 'package:nizan_crm/features/marketing/services/socials_service.dart';
import 'package:nizan_crm/features/marketing/services/team_service.dart';

/// Creative Portfolio → Gallery: the shared asset library with the document's filters — portfolio, page, production stage, media type.
/// An asset uploaded under a shoot inherits the shoot's brand, portfolio and page; approved assets are what Socials posts from.
class PortfolioGalleryTab extends ConsumerStatefulWidget {
  const PortfolioGalleryTab({super.key});

  @override
  ConsumerState<PortfolioGalleryTab> createState() => _PortfolioGalleryTabState();
}

class _PortfolioGalleryTabState extends ConsumerState<PortfolioGalleryTab> {
  String _q = '';
  String? _portfolio, _page, _stage, _media;
  String _sort = 'newest';

  @override
  Widget build(BuildContext context) {
    final brand = ref.watch(teamFilterProvider).brand;
    final query = AssetQuery(q: _q, portfolio: _portfolio, page: _page, stage: _stage, media: _media, brand: brand.wire, sort: _sort);
    final async = ref.watch(socialsAssetsProvider(query));
    return RefreshIndicator(
      onRefresh: () async => refreshSocials(ref),
      child: async.when(
        loading: () => ListView(children: const [SizedBox(height: 200), Center(child: CircularProgressIndicator())]),
        error: (e, _) => ListView(children: [AppErrorView(error: e, onRetry: () => refreshSocials(ref))]),
        data: (l) {
          final c = l.counts;
          Widget facet(String title, Map<String, int> values, String? selected, ValueChanged<String?> pick, String keyPrefix, {Map<String, String>? labels}) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: mktText(12.5, weight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  if (values.isEmpty) Text('—', style: mktText(11.5, color: Mkt.inkSoft)),
                  for (final e in values.entries)
                    InkWell(
                      key: Key('${keyPrefix}_${e.key}'),
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => pick(selected == e.key ? null : e.key),
                      child: Padding(padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2), child: Row(children: [Icon(selected == e.key ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded, size: 17, color: selected == e.key ? Mkt.violet : Mkt.inkSoft), const SizedBox(width: 8), Expanded(child: Text(labels?[e.key] ?? e.key, maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(12, weight: selected == e.key ? FontWeight.w800 : FontWeight.w500))), Text('${e.value}', style: mktText(11, color: Mkt.inkSoft))])),
                    ),
                ]),
              );
          final filters = MktCard(
            title: 'Gallery',
            icon: Icons.filter_alt_outlined,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              facet('Portfolios', l.portfolios, _portfolio, (v) => setState(() => _portfolio = v), 'gl_portfolio'),
              facet('Pages', l.pages, _page, (v) => setState(() => _page = v), 'gl_page'),
              facet('Production Stage', l.stages, _stage, (v) => setState(() => _stage = v), 'gl_stage', labels: {for (final s in kAssetStages) s.$1: s.$2}),
              facet('Media Type', l.media, _media, (v) => setState(() => _media = v), 'gl_media', labels: const {'video': 'Videos', 'image': 'Photos', 'design': 'Designs', 'document': 'Documents'}),
            ]),
          );
          final grid = MktCard(
            title: 'Assets',
            subtitle: '${l.items.length} shown',
            icon: Icons.photo_library_outlined,
            trailing: MktPrimaryButton(key: const Key('gl_upload'), label: 'Upload', icon: Icons.upload_rounded, onPressed: () => showAssetEditor(context, ref, brand: brand == TeamBrand.kerala ? 'kerala' : 'main')),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(spacing: 10, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                SizedBox(width: 280, child: TextField(key: const Key('gl_search'), onChanged: (v) => setState(() => _q = v), style: mktText(13), decoration: InputDecoration(prefixIcon: const Icon(Icons.search_rounded, size: 18), hintText: 'Search assets, shoot, page or keyword…', isDense: true, contentPadding: const EdgeInsets.symmetric(vertical: 10), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: const BorderSide(color: Mkt.border)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: const BorderSide(color: Mkt.violet))))),
                KeyedSubtree(key: const Key('gl_sort'), child: MktDropdownPill<String>(value: _sort, icon: Icons.sort_rounded, options: const [('newest', 'Sort: Newest'), ('oldest', 'Sort: Oldest')], onChanged: (v) => setState(() => _sort = v))),
              ]),
              const SizedBox(height: 12),
              if (l.items.isEmpty) MktEmpty(c.total == 0 ? 'The gallery is empty. Upload an asset — a link to the file — or add one from a shoot.' : 'No asset matches these filters.', icon: Icons.photo_library_outlined, height: 140) else AssetGrid(items: l.items, minWidth: 170),
            ]),
          );
          return ListView(
            key: const Key('portfolio_gallery_list'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            children: [
              MktKpiRow(minWidth: 170, children: [
                MktKpiCard(key: const Key('gl_kpi_total'), icon: Icons.layers_outlined, value: groupedCount(c.total), label: 'Total Assets', tint: Mkt.violet),
                MktKpiCard(key: const Key('gl_kpi_photos'), icon: Icons.image_outlined, value: groupedCount(c.photos), label: 'Photos', tint: Mkt.good),
                MktKpiCard(key: const Key('gl_kpi_videos'), icon: Icons.play_circle_outline_rounded, value: groupedCount(c.videos), label: 'Videos', tint: Mkt.warn),
                MktKpiCard(key: const Key('gl_kpi_finals'), icon: Icons.workspace_premium_outlined, value: groupedCount(c.finals), label: 'Final Outputs', tint: Mkt.violet2),
                MktKpiCard(key: const Key('gl_kpi_approved'), icon: Icons.verified_outlined, value: groupedCount(c.approved), label: 'Approved', tint: Mkt.blue),
                MktKpiCard(key: const Key('gl_kpi_post'), icon: Icons.check_circle_outline_rounded, value: c.postProducedPct == null ? '—' : '${c.postProducedPct}%', label: 'Post-production Completion', tint: Mkt.pink),
              ]),
              const SizedBox(height: 12),
              MktGrid(breakpoint: 900, rows: [[(3, filters), (9, grid)]]),
            ],
          );
        },
      ),
    );
  }
}
