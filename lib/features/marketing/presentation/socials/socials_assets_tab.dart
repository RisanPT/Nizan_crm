import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/marketing/data/socials_models.dart';
import 'package:nizan_crm/features/marketing/data/team_models.dart';
import 'package:nizan_crm/features/marketing/presentation/kit/mkt_kit.dart';
import 'package:nizan_crm/features/marketing/presentation/socials/asset_editor.dart';
import 'package:nizan_crm/features/marketing/presentation/socials/socials_widgets.dart';
import 'package:nizan_crm/features/marketing/services/socials_service.dart';
import 'package:nizan_crm/features/marketing/services/team_service.dart';

Color assetStageColor(String s) => switch (s) {
      'approved' => Mkt.good,
      'in_review' => Mkt.warn,
      'rejected' => Mkt.bad,
      'in_edit' || 'post_produced' => Mkt.blue,
      _ => Mkt.grey,
    };

/// One asset as a card: picture, title, type and stage, and a menu to open its link, change it, move it on or delete it.
class AssetCard extends ConsumerWidget {
  const AssetCard({super.key, required this.asset, this.onChanged});
  final Asset asset;
  final VoidCallback? onChanged;

  Future<void> _stage(BuildContext context, WidgetRef ref, String stage) async {
    try {
      await ref.read(marketingSocialsServiceProvider).saveAsset({'stage': stage}, id: asset.id);
      refreshSocials(ref);
    } on TeamRefusal catch (r) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(r.message)));
    } catch (e) {
      if (context.mounted) showErrorSnackBar(context, e);
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete this asset?'),
        content: Text('"${asset.title}" is removed from the library. The file itself stays where it is stored.'),
        actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')), FilledButton(key: const Key('asset_delete_confirm'), onPressed: () => Navigator.pop(c, true), child: const Text('Delete'))],
      ),
    );
    if (yes != true) return;
    try {
      await ref.read(marketingSocialsServiceProvider).deleteAsset(asset.id);
      refreshSocials(ref);
    } on TeamRefusal catch (r) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(r.message)));
    } catch (e) {
      if (context.mounted) showErrorSnackBar(context, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      key: Key('asset_${asset.id}'),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: Mkt.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: Mkt.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Stack(children: [
          InkWell(onTap: () => launchUrl(Uri.parse(asset.url), mode: LaunchMode.externalApplication), child: AssetThumb(asset: asset)),
          Positioned(left: 6, top: 6, child: MktChip(assetKindLabel(asset.kind), color: Mkt.violet)),
          if (asset.isFinal) const Positioned(right: 6, top: 6, child: MktChip('Final', color: Mkt.warn, solid: true)),
          if (asset.media == 'video' && asset.durationSec > 0) Positioned(right: 6, bottom: 6, child: MktChip('${asset.durationSec ~/ 60}:${(asset.durationSec % 60).toString().padLeft(2, '0')}', color: Colors.black87, solid: true)),
        ]),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(child: Text(asset.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(12.5, weight: FontWeight.w700))),
          PopupMenuButton<String>(
            key: Key('asset_menu_${asset.id}'),
            tooltip: 'Actions',
            padding: EdgeInsets.zero,
            iconSize: 18,
            onSelected: (v) {
              switch (v) {
                case 'open':
                  launchUrl(Uri.parse(asset.url), mode: LaunchMode.externalApplication);
                case 'edit':
                  showAssetEditor(context, ref, asset: asset);
                case 'review':
                  _stage(context, ref, 'in_review');
                case 'approve':
                  _stage(context, ref, 'approved');
                case 'reject':
                  _stage(context, ref, 'rejected');
                case 'delete':
                  _delete(context, ref);
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'open', child: Text('Open file')),
              const PopupMenuItem(value: 'edit', child: Text('Edit')),
              if (asset.stage != 'in_review') const PopupMenuItem(value: 'review', child: Text('Send for review')),
              if (asset.stage != 'approved') const PopupMenuItem(value: 'approve', child: Text('Approve')),
              if (asset.stage != 'rejected') const PopupMenuItem(value: 'reject', child: Text('Reject')),
              const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Mkt.bad))),
            ],
          ),
        ]),
        Text([if (asset.page.isNotEmpty) asset.page else asset.portfolio, asset.brand == 'kerala' ? 'Kerala' : 'Main'].where((x) => x.isNotEmpty).join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(10.5, color: Mkt.inkSoft)),
        const SizedBox(height: 4),
        MktChip(assetStageLabel(asset.stage), color: assetStageColor(asset.stage)),
      ]),
    );
  }
}

/// A responsive grid of [AssetCard]s.
class AssetGrid extends StatelessWidget {
  const AssetGrid({super.key, required this.items, this.minWidth = 190});
  final List<Asset> items;
  final double minWidth;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        const gap = 12.0;
        final cols = (box.maxWidth / minWidth).floor().clamp(1, 8);
        final w = (box.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(spacing: gap, runSpacing: gap, children: [for (final a in items) SizedBox(width: w, child: AssetCard(asset: a))]);
      });
}

/// Socials → Content & Assets: the asset library with its approval status. (The same library the Creative Portfolio gallery shows.)
class SocialsAssetsTab extends ConsumerStatefulWidget {
  const SocialsAssetsTab({super.key});

  @override
  ConsumerState<SocialsAssetsTab> createState() => _SocialsAssetsTabState();
}

class _SocialsAssetsTabState extends ConsumerState<SocialsAssetsTab> {
  String _q = '';
  String? _media; // null = all
  String? _stage;
  String? _kind;

  @override
  Widget build(BuildContext context) {
    final brand = ref.watch(teamFilterProvider).brand;
    final query = AssetQuery(q: _q, media: _media, stage: _stage, kind: _kind, brand: brand.wire);
    final async = ref.watch(socialsAssetsProvider(query));
    return RefreshIndicator(
      onRefresh: () async => refreshSocials(ref),
      child: ListView(
        key: const Key('socials_assets_list'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          MktCard(
            title: 'Content & Assets',
            subtitle: 'Manage content ideas, production and the asset library',
            icon: Icons.photo_library_outlined,
            trailing: MktPrimaryButton(key: const Key('soc_asset_add'), label: 'Upload Asset', icon: Icons.upload_rounded, onPressed: () => showAssetEditor(context, ref, brand: brand == TeamBrand.kerala ? 'kerala' : 'main')),
            child: async.when(
              loading: () => const SizedBox(height: 200, child: Center(child: CircularProgressIndicator())),
              error: (e, _) => AppErrorView(error: e, onRetry: () => refreshSocials(ref)),
              data: (l) {
                final c = l.counts;
                return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(children: [
                      MktFilterChip(key: const Key('soc_asset_media_all'), label: 'All Assets', count: c.total, selected: _media == null, onTap: () => setState(() => _media = null)),
                      const SizedBox(width: 6),
                      MktFilterChip(key: const Key('soc_asset_media_image'), label: 'Images', count: c.photos, selected: _media == 'image', onTap: () => setState(() => _media = _media == 'image' ? null : 'image')),
                      const SizedBox(width: 6),
                      MktFilterChip(key: const Key('soc_asset_media_video'), label: 'Videos', count: c.videos, selected: _media == 'video', onTap: () => setState(() => _media = _media == 'video' ? null : 'video')),
                      const SizedBox(width: 6),
                      MktFilterChip(key: const Key('soc_asset_media_design'), label: 'Designs', count: l.media['design'] ?? 0, selected: _media == 'design', onTap: () => setState(() => _media = _media == 'design' ? null : 'design')),
                      const SizedBox(width: 6),
                      MktFilterChip(key: const Key('soc_asset_media_document'), label: 'Documents', count: l.media['document'] ?? 0, selected: _media == 'document', onTap: () => setState(() => _media = _media == 'document' ? null : 'document')),
                    ]),
                  ),
                  const SizedBox(height: 10),
                  Wrap(spacing: 10, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                    SizedBox(
                      width: 260,
                      child: TextField(
                        key: const Key('soc_asset_search'),
                        onChanged: (v) => setState(() => _q = v),
                        style: mktText(13),
                        decoration: InputDecoration(prefixIcon: const Icon(Icons.search_rounded, size: 18), hintText: 'Search assets, titles or tags…', isDense: true, contentPadding: const EdgeInsets.symmetric(vertical: 10), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: const BorderSide(color: Mkt.border)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: const BorderSide(color: Mkt.violet))),
                      ),
                    ),
                    KeyedSubtree(key: const Key('soc_asset_kind'), child: MktDropdownPill<String>(value: _kind ?? 'all', icon: Icons.category_outlined, options: [('all', 'Any type'), for (final k in kAssetKinds) (k.$1, k.$2)], onChanged: (v) => setState(() => _kind = v == 'all' ? null : v))),
                    KeyedSubtree(key: const Key('soc_asset_stage'), child: MktDropdownPill<String>(value: _stage ?? 'all', icon: Icons.flag_outlined, options: [('all', 'Any status'), for (final s in kAssetStages) (s.$1, '${s.$2}${(l.stages[s.$1] ?? 0) > 0 ? ' (${l.stages[s.$1]})' : ''}')], onChanged: (v) => setState(() => _stage = v == 'all' ? null : v))),
                  ]),
                  const SizedBox(height: 12),
                  if (l.items.isEmpty)
                    MktEmpty(c.total == 0 ? 'No assets yet. Upload the first one — a link to the file in Drive.' : 'No asset matches these filters.', icon: Icons.photo_library_outlined, height: 140)
                  else
                    AssetGrid(items: l.items),
                ]);
              },
            ),
          ),
        ],
      ),
    );
  }
}
