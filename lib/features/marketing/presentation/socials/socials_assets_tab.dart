import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/marketing/data/socials_models.dart';
import 'package:nizan_crm/features/marketing/data/team_models.dart';
import 'package:nizan_crm/features/marketing/presentation/kit/mkt_kit.dart';
import 'package:nizan_crm/features/marketing/presentation/media/asset_viewer.dart';
import 'package:nizan_crm/features/marketing/presentation/media/card_preview.dart';
import 'package:nizan_crm/features/marketing/presentation/portfolio/asset_library_view.dart';
import 'package:nizan_crm/features/marketing/presentation/socials/asset_editor.dart';
import 'package:nizan_crm/features/marketing/presentation/socials/socials_widgets.dart' show AssetThumb;
import 'package:nizan_crm/features/marketing/services/portfolio_service.dart';
import 'package:nizan_crm/features/marketing/services/socials_service.dart';
import 'package:nizan_crm/features/marketing/presentation/portfolio/work_review_widgets.dart';

Color assetStageColor(String s) => switch (s) {
      'approved' => Mkt.good,
      'in_review' => Mkt.warn,
      'rejected' => Mkt.bad,
      'in_edit' || 'post_produced' => Mkt.blue,
      _ => Mkt.grey,
    };

/// The actions on one asset: open its file, change it, send it for review, approve, reject, delete.
class AssetMenu extends ConsumerWidget {
  const AssetMenu({super.key, required this.asset, this.manager = false});
  final Asset asset;

  /// A Marketing Manager: Approve and Reject are offered (the server refuses them from anyone else).
  final bool manager;

  Future<void> _stage(BuildContext context, WidgetRef ref, String stage) async {
    try {
      await ref.read(marketingSocialsServiceProvider).saveAsset({'stage': stage}, id: asset.id);
      refreshPortfolio(ref);
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
      refreshPortfolio(ref);
    } on TeamRefusal catch (r) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(r.message)));
    } catch (e) {
      if (context.mounted) showErrorSnackBar(context, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
        key: Key('asset_menu_${asset.id}'),
        tooltip: 'Actions',
        padding: EdgeInsets.zero,
        iconSize: 18,
        onSelected: (v) {
          switch (v) {
            case 'open':
              launchUrl(Uri.parse(asset.url), mode: LaunchMode.externalApplication);
            case 'edit':
              showAssetEditor(context, ref, asset: asset, manager: manager);
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
          // approving and rejecting are a Marketing Manager's call
          if (manager && asset.stage != 'approved') const PopupMenuItem(value: 'approve', child: Text('Approve')),
          if (manager && asset.stage != 'rejected') const PopupMenuItem(value: 'reject', child: Text('Reject')),
          const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Mkt.bad))),
        ],
      );
  }
}

/// An asset's keywords as small chips; tapping one asks for it ([onKeyword]). The first [max], then "+n".
class AssetKeywordChips extends StatelessWidget {
  const AssetKeywordChips({super.key, required this.asset, required this.onKeyword, this.max = 3});
  final Asset asset;
  final ValueChanged<String> onKeyword;
  final int max;

  @override
  Widget build(BuildContext context) => Wrap(spacing: 4, runSpacing: 4, children: [
        for (final k in asset.tags.take(max))
          InkWell(
            key: Key('asset_kw_${asset.id}_$k'),
            borderRadius: BorderRadius.circular(6),
            onTap: () => onKeyword(k),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: Mkt.primarySoft, borderRadius: BorderRadius.circular(6)),
              child: Text(k, maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(10.5, weight: FontWeight.w600, color: Mkt.primary)),
            ),
          ),
        if (asset.tags.length > max) Tooltip(message: asset.tags.skip(max).join(', '), child: Text('+${asset.tags.length - max}', style: mktText(10.5, color: Mkt.inkSoft, weight: FontWeight.w700))),
      ]);
}

/// Ticked or not, while assets are being chosen.
class _PickMark extends StatelessWidget {
  const _PickMark({super.key, required this.on});
  final bool on;
  @override
  Widget build(BuildContext context) => Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(shape: BoxShape.circle, color: on ? Mkt.primary : Colors.white.withValues(alpha: 0.92), border: Border.all(color: on ? Mkt.primary : Mkt.inkSoft, width: 1.5)),
        child: on ? const Icon(Icons.check_rounded, size: 16, color: Colors.white) : null,
      );
}

/// One asset as a card: picture, title, type and stage, and a menu to open its link, change it, move it on or delete it. With [onSelect]
/// the gallery is choosing assets: a tap ticks it ([selected]) instead of opening it. With [onKeyword] its keywords show and a tap on
/// one asks for that keyword.
class AssetCard extends ConsumerWidget {
  const AssetCard({super.key, required this.asset, this.onChanged, this.selected = false, this.onSelect, this.onKeyword, this.manager = false});
  final Asset asset;
  final bool manager;
  final VoidCallback? onChanged;
  final bool selected;
  final VoidCallback? onSelect;
  final ValueChanged<String>? onKeyword;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final picking = onSelect != null;
    return Container(
      key: Key('asset_${asset.id}'),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: selected ? Mkt.primarySoft : Mkt.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: selected ? Mkt.primary : Mkt.border, width: selected ? 2 : 1)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Stack(children: [
          // the picture opens the asset in the app (a Dropbox video plays right there); with Autoplay on it plays a muted preview here too
          InkWell(key: const Key('asset_thumb'), onTap: () => picking ? onSelect!() : showAssetViewer(context, asset), child: AssetCardPicture(asset: asset)),
          Positioned(left: 6, top: 6, child: MktChip(assetKindLabel(asset.kind), color: Mkt.primary)),
          if (picking) Positioned(left: 6, bottom: 6, child: IgnorePointer(child: _PickMark(key: Key('asset_pick_${asset.id}'), on: selected))),
          if (asset.isFinal) const Positioned(right: 6, top: 6, child: MktChip('Final', color: Mkt.warn, solid: true)),
          if (asset.media == 'video' && asset.durationSec > 0) Positioned(right: 6, bottom: 6, child: MktChip('${asset.durationSec ~/ 60}:${(asset.durationSec % 60).toString().padLeft(2, '0')}', color: Colors.black87, solid: true)),
        ]),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(child: Text(asset.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(12.5, weight: FontWeight.w700))),
          AssetMenu(asset: asset, manager: manager),
        ]),
        Text([if (asset.page.isNotEmpty) asset.page else asset.portfolio, asset.brand == 'kerala' ? 'Kerala' : 'Main'].where((x) => x.isNotEmpty).join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(10.5, color: Mkt.inkSoft)),
        // the work it came from — day, booking, client, artists — and the client's rating of it
        if (asset.work != null) WorkCardLines(work: asset.work!),
        if (onKeyword != null && asset.tags.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 5), child: AssetKeywordChips(asset: asset, onKeyword: onKeyword!)),
        const SizedBox(height: 4),
        MktChip(assetStageLabel(asset.stage), color: assetStageColor(asset.stage)),
      ]),
    );
  }
}

/// The assets as a list: a small picture, title, type · page · brand, owner, the day it was added, stage and the actions.
class AssetRows extends StatelessWidget {
  const AssetRows({super.key, required this.items, this.selected = const {}, this.onSelect, this.onKeyword, this.manager = false});
  final List<Asset> items;
  final bool manager;

  /// While choosing assets: which are ticked, and what a tap does ([AssetCard]).
  final Set<String> selected;
  final ValueChanged<Asset>? onSelect;
  final ValueChanged<String>? onKeyword;

  @override
  Widget build(BuildContext context) => Column(key: const Key('asset_rows'), children: [
        for (final a in items)
          Container(
            key: Key('asset_row_${a.id}'),
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(color: selected.contains(a.id) ? Mkt.primarySoft : null, border: const Border(bottom: BorderSide(color: Mkt.border))),
            child: Row(children: [
              if (onSelect != null) Checkbox(key: Key('asset_pick_${a.id}'), value: selected.contains(a.id), visualDensity: VisualDensity.compact, onChanged: (_) => onSelect!(a)),
              InkWell(onTap: () => onSelect != null ? onSelect!(a) : showAssetViewer(context, a), child: SizedBox(width: 56, child: AssetThumb(asset: a, height: 42))),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(a.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(12.5, weight: FontWeight.w700)),
                  Text([assetKindLabel(a.kind), if (a.page.isNotEmpty) a.page else a.portfolio, a.brand == 'kerala' ? 'Kerala' : 'Main', if (a.owner.isNotEmpty) a.owner, if (a.createdAt != null) DateFormat('d MMM yyyy').format(a.createdAt!)].where((x) => x.isNotEmpty).join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(10.5, color: Mkt.inkSoft)),
                  if (a.work != null) WorkCardLines(work: a.work!, compact: true),
                  if (onKeyword != null && a.tags.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 3), child: AssetKeywordChips(asset: a, onKeyword: onKeyword!, max: 5)),
                ]),
              ),
              if (a.isFinal) const Padding(padding: EdgeInsets.only(right: 4), child: MktChip('Final', color: Mkt.warn)),
              MktChip(assetStageLabel(a.stage), color: assetStageColor(a.stage)),
              AssetMenu(asset: a, manager: manager),
            ]),
          ),
      ]);
}

/// Grid or list — each viewer's choice on the screen.
class AssetLayoutToggle extends StatelessWidget {
  const AssetLayoutToggle({super.key, required this.list, required this.onChanged});
  final bool list;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        IconButton(key: const Key('asset_layout_grid'), tooltip: 'Grid', visualDensity: VisualDensity.compact, isSelected: !list, onPressed: () => onChanged(false), icon: Icon(Icons.grid_view_rounded, size: 18, color: list ? Mkt.inkSoft : Mkt.primary)),
        IconButton(key: const Key('asset_layout_list'), tooltip: 'List', visualDensity: VisualDensity.compact, isSelected: list, onPressed: () => onChanged(true), icon: Icon(Icons.view_list_rounded, size: 18, color: list ? Mkt.primary : Mkt.inkSoft)),
      ]);
}

/// A responsive grid of [AssetCard]s.
class AssetGrid extends StatelessWidget {
  const AssetGrid({super.key, required this.items, this.minWidth = 190, this.selected = const {}, this.onSelect, this.onKeyword, this.manager = false});
  final List<Asset> items;
  final bool manager;
  final double minWidth;

  /// While choosing assets: which are ticked, and what a tap does ([AssetCard]).
  final Set<String> selected;
  final ValueChanged<Asset>? onSelect;
  final ValueChanged<String>? onKeyword;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        const gap = 12.0;
        final cols = (box.maxWidth / minWidth).floor().clamp(1, 8);
        final w = (box.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(spacing: gap, runSpacing: gap, children: [
          for (final a in items) SizedBox(key: ValueKey(a.id), width: w, child: AssetCard(asset: a, selected: selected.contains(a.id), onSelect: onSelect == null ? null : () => onSelect!(a), onKeyword: onKeyword, manager: manager)),
        ]);
      });
}

/// Socials → Content & Assets: the same asset library and the same search as the Creative Portfolio gallery ([AssetLibraryView]), with
/// quick media chips on top and without the gallery's figures.
class SocialsAssetsTab extends StatelessWidget {
  const SocialsAssetsTab({super.key});

  @override
  Widget build(BuildContext context) => const AssetLibraryView(title: 'Content & Assets', showKpis: false, mediaChips: true, uploadKey: 'soc_asset_add', uploadLabel: 'Upload Asset', listKey: 'socials_assets_list', emptyText: 'No assets yet. Upload the first one — a link to the file in Drive or Dropbox.');
}
