import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/marketing/data/asset_search.dart';
import 'package:nizan_crm/features/marketing/data/socials_models.dart';
import 'package:nizan_crm/features/marketing/data/team_models.dart' show TeamBrand;
import 'package:nizan_crm/features/marketing/presentation/kit/mkt_kit.dart';
import 'package:nizan_crm/features/marketing/presentation/media/asset_viewer.dart' show AutoplayToggle;
import 'package:nizan_crm/features/marketing/presentation/portfolio/gallery_filters.dart';
import 'package:nizan_crm/features/marketing/presentation/socials/asset_editor.dart';
import 'package:nizan_crm/features/marketing/presentation/socials/socials_assets_tab.dart' show AssetGrid, AssetRows, AssetLayoutToggle;
import 'package:nizan_crm/features/marketing/services/portfolio_service.dart';
import 'package:nizan_crm/features/marketing/services/socials_service.dart';
import 'package:nizan_crm/features/marketing/services/team_service.dart';

/// What the search box understands — shown on its help button.
const kGallerySearchHelp = 'Every word must be found (title, keyword, page, portfolio, owner, or the shoot\'s title, place and crew).\n'
    '"kerala bride" — these words together\n'
    '-party — leave out\n'
    '#bridal — only assets with the keyword\n'
    'videos, photos, reels… — that type';

/// The company's asset library — Creative Portfolio → Gallery and Socials → Content & Assets show the same library with the same
/// search — searched and filtered on the server so it stays quick however large it grows. Words to search (every word must match; "phrases", -left out, #keywords), filters with several values each (media, type,
/// stage, portfolio, page, owner — the numbers next to them are what picking them would show), keywords (all / any / left out, and
/// the assets with none yet), final / ready-to-post, the days added, and four orders (Best match while searching). Pages of
/// [kGalleryPageSize] with "Show more". Choose assets to add or remove keywords on all of them at once; tap a keyword on a card to
/// filter by it. On a phone the filters open in a sheet.
///
/// [showKpis] puts the library's six figures on top (the Gallery); [mediaChips] puts quick Images / Videos / Designs / Documents
/// chips over the results (Socials).
class AssetLibraryView extends ConsumerStatefulWidget {
  const AssetLibraryView({super.key, this.title = 'Assets', this.showKpis = true, this.mediaChips = false, this.uploadKey = 'gl_upload', this.uploadLabel = 'Upload', this.listKey = 'portfolio_gallery_list', this.emptyText = 'The gallery is empty. Upload an asset — a link to the file — or add one from a shoot.'});
  final String title, uploadKey, uploadLabel, listKey;

  /// What an empty library says.
  final String emptyText;
  final bool showKpis, mediaChips;

  @override
  ConsumerState<AssetLibraryView> createState() => _AssetLibraryViewState();
}

class _AssetLibraryViewState extends ConsumerState<AssetLibraryView> {
  AssetSearch _s = const AssetSearch();
  final _searchText = TextEditingController();
  Timer? _debounce;
  int _loaded = 1;
  bool _list = false;
  Set<String>? _picked; // null = not choosing
  AssetPage? _lastP1;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchText.dispose();
    super.dispose();
  }

  void _apply(AssetSearch s) => setState(() {
        _s = s;
        _loaded = 1;
      });

  void _typed(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted && v != _s.q) _apply(_s.copyWith(q: v));
    });
  }

  void _filterByKeyword(String k) {
    if (!_s.keywords.contains(k)) _apply(_s.toggleKeyword(k));
  }

  void _pick(Asset a) => setState(() {
        final p = {...?_picked};
        if (!p.remove(a.id)) p.add(a.id);
        _picked = p;
      });

  Future<void> _openFilters(AssetSearch search) => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (_) => _FilterSheet(initial: search, brand: search.brand, onChanged: (s) => _apply(s.copyWith(brand: 'all'))),
      );

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(teamFilterProvider);
    final brand = filter.brand;
    final search = _s.copyWith(brand: brand.wire);
    final first = ref.watch(galleryPageProvider((search, 1)));
    // a new search keeps the last answer on screen until its own arrives — the search box and filters never vanish under a spinner
    if (first.hasValue) _lastP1 = first.value;
    final p1 = first.value ?? _lastP1;
    if (p1 == null) {
      return RefreshIndicator(
        onRefresh: () async => refreshPortfolio(ref),
        child: ListView(children: [if (first.hasError) AppErrorView(error: first.error!, onRetry: () => refreshPortfolio(ref)) else ...const [SizedBox(height: 200), Center(child: CircularProgressIndicator())]]),
      );
    }
    final items = [...p1.items];
    var more = false;
    Object? moreError;
    for (var i = 2; i <= _loaded; i++) {
      final v = ref.watch(galleryPageProvider((search, i)));
      if (v.hasValue) items.addAll(v.value!.items);
      if (v.isLoading) more = true;
      if (v.hasError) moreError = v.error;
    }
    final status = (loading: first.isLoading, error: first.hasError && !first.isLoading ? first.error : null);
    return RefreshIndicator(
      onRefresh: () async => refreshPortfolio(ref),
      child: LayoutBuilder(builder: (context, box) {
        final wide = box.maxWidth >= 900;
        final panel = MktCard(title: 'Filters', icon: Icons.filter_alt_outlined, child: GalleryFilterPanel(search: _s, page: p1, onChanged: _apply, showTitle: false));
        final results = _results(context, p1, items, more, moreError, search, status, wide: wide);
        return ListView(
          key: Key(widget.listKey),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          children: [
            if (widget.showKpis) ...[_kpis(p1.counts), const SizedBox(height: 12)],
            if (wide) MktGrid(breakpoint: 900, rows: [[(3, panel), (9, results)]]) else results,
          ],
        );
      }),
    );
  }

  Widget _kpis(AssetCounts c) => MktKpiRow(minWidth: 170, children: [
        MktKpiCard(key: const Key('gl_kpi_total'), icon: Icons.layers_outlined, value: groupedCount(c.total), label: 'Total Assets', tint: Mkt.primary),
        MktKpiCard(key: const Key('gl_kpi_photos'), icon: Icons.image_outlined, value: groupedCount(c.photos), label: 'Photos', tint: Mkt.good),
        MktKpiCard(key: const Key('gl_kpi_videos'), icon: Icons.play_circle_outline_rounded, value: groupedCount(c.videos), label: 'Videos', tint: Mkt.warn),
        MktKpiCard(key: const Key('gl_kpi_finals'), icon: Icons.workspace_premium_outlined, value: groupedCount(c.finals), label: 'Final Outputs', tint: Mkt.primaryLight),
        MktKpiCard(key: const Key('gl_kpi_approved'), icon: Icons.verified_outlined, value: groupedCount(c.approved), label: 'Approved', tint: Mkt.blue),
        MktKpiCard(key: const Key('gl_kpi_post'), icon: Icons.check_circle_outline_rounded, value: c.postProducedPct == null ? '—' : '${c.postProducedPct}%', label: 'Post-production Completion', tint: Mkt.pink),
      ]);

  Widget _results(BuildContext context, AssetPage p1, List<Asset> items, bool more, Object? moreError, AssetSearch search, ({bool loading, Object? error}) status, {required bool wide}) {
    final brand = ref.read(teamFilterProvider).brand;
    final picking = _picked != null;
    final picked = _picked ?? const <String>{};
    final sortValue = !_s.hasWords && (_s.sort == 'newest' || _s.sort == 'relevance') ? 'auto' : _s.sort;
    final read = p1.searchRead;
    final searchBox = TextField(
      key: const Key('gl_search'),
      controller: _searchText,
      onChanged: _typed,
      onSubmitted: (v) {
        _debounce?.cancel();
        if (v != _s.q) _apply(_s.copyWith(q: v));
      },
      style: mktText(13),
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.search_rounded, size: 18),
        hintText: 'Search title, keyword, page, shoot, place, artist…',
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 10),
        suffixIcon: Row(mainAxisSize: MainAxisSize.min, children: [
          if (_searchText.text.isNotEmpty)
            IconButton(
              key: const Key('gl_search_clear'),
              tooltip: 'Clear the search',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.close_rounded, size: 17),
              onPressed: () {
                _searchText.clear();
                _debounce?.cancel();
                _apply(_s.copyWith(q: ''));
              },
            ),
          const Tooltip(key: Key('gl_search_help'), message: kGallerySearchHelp, child: Padding(padding: EdgeInsets.only(right: 8), child: Icon(Icons.help_outline_rounded, size: 17, color: Mkt.inkSoft))),
        ]),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: const BorderSide(color: Mkt.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: const BorderSide(color: Mkt.primary)),
      ),
    );
    return MktCard(
      title: widget.title,
      subtitle: p1.total == p1.counts.total ? '${groupedCount(p1.total)} in the library' : '${groupedCount(p1.total)} of ${groupedCount(p1.counts.total)} match',
      icon: Icons.photo_library_outlined,
      trailing: MktPrimaryButton(key: Key(widget.uploadKey), label: widget.uploadLabel, icon: Icons.upload_rounded, onPressed: () => showAssetEditor(context, ref, brand: brand == TeamBrand.kerala ? 'kerala' : 'main', manager: p1.canManage)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (widget.mediaChips) ...[_mediaChips(p1), const SizedBox(height: 10)],
        Wrap(spacing: 10, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          SizedBox(width: wide ? 340 : double.infinity, child: searchBox),
          if (!wide)
            OutlinedButton.icon(
              key: const Key('gl_filters_btn'),
              onPressed: () => _openFilters(search),
              icon: const Icon(Icons.filter_alt_outlined, size: 17),
              label: Text(_s.filterCount == 0 ? 'Filters' : 'Filters (${_s.filterCount})'),
            ),
          KeyedSubtree(
            key: const Key('gl_sort'),
            child: MktDropdownPill<String>(
              value: sortValue,
              icon: Icons.sort_rounded,
              options: [('auto', _s.hasWords ? 'Sort: Best match' : 'Sort: Newest'), if (_s.hasWords) ('newest', 'Sort: Newest'), ('oldest', 'Sort: Oldest'), ('title', 'Sort: Title A–Z')],
              onChanged: (v) => _apply(_s.copyWith(sort: v)),
            ),
          ),
          const AutoplayToggle(),
          AssetLayoutToggle(list: _list, onChanged: (v) => setState(() => _list = v)),
          TextButton.icon(
            key: const Key('gl_select'),
            onPressed: () => setState(() => _picked = picking ? null : <String>{}),
            icon: Icon(picking ? Icons.close_rounded : Icons.checklist_rounded, size: 17),
            label: Text(picking ? 'Done choosing' : 'Choose'),
          ),
        ]),
        if (read.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text('Searching for: $read', key: const Key('gl_search_read'), style: mktText(11.5, color: Mkt.inkSoft))),
        const SizedBox(height: 8),
        SizedBox(height: 3, child: status.loading ? const LinearProgressIndicator(key: Key('gl_loading'), minHeight: 2) : null),
        if (status.error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              const Icon(Icons.error_outline_rounded, size: 16, color: Mkt.bad),
              const SizedBox(width: 6),
              Expanded(child: Text('${friendlyErrorMessage(status.error)} What is shown is from the last search.', key: const Key('gl_error'), style: mktText(12, color: Mkt.bad))),
              TextButton(onPressed: () => refreshPortfolio(ref), child: const Text('Try again')),
            ]),
          ),
        const SizedBox(height: 7),
        ActiveFilterChips(search: _s, onChanged: _apply, names: p1.artistNames),
        if (picking) _pickBar(context, items, picked),
        if (items.isEmpty)
          MktEmpty(p1.counts.total == 0 ? (_s.from != null ? 'No asset was added in these days.' : widget.emptyText) : 'No asset matches. Try fewer words or filters.', icon: Icons.photo_library_outlined, height: 140)
        else if (_list)
          AssetRows(items: items, selected: picked, onSelect: picking ? _pick : null, onKeyword: _filterByKeyword, manager: p1.canManage)
        else
          // two cards a row on a phone: a library is browsed, not read one by one
          AssetGrid(items: items, minWidth: wide ? 170 : 140, selected: picked, onSelect: picking ? _pick : null, onKeyword: _filterByKeyword, manager: p1.canManage),
        if (items.isNotEmpty) ...[
          const SizedBox(height: 12),
          Center(
            child: Column(children: [
              Text('Showing ${groupedCount(items.length)} of ${groupedCount(p1.total)}', key: const Key('gl_shown'), style: mktText(11.5, color: Mkt.inkSoft)),
              if (moreError != null) Text(friendlyErrorMessage(moreError), style: mktText(11.5, color: Mkt.bad)),
              if (more)
                const Padding(padding: EdgeInsets.all(8), child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)))
              else if (items.length < p1.total && _loaded < p1.pages)
                TextButton(key: const Key('gl_more'), onPressed: () => setState(() => _loaded += 1), child: Text('Show ${groupedCount((p1.total - items.length).clamp(0, kGalleryPageSize))} more')),
            ]),
          ),
        ],
      ]),
    );
  }

  /// One tap for one kind of media (All / Images / Videos / Designs / Documents), with how many each would show.
  Widget _mediaChips(AssetPage p1) {
    final on = _s.facet('media');
    final m = p1.facet('media');
    Widget chip(String? media, String label, int count) => Padding(
          padding: const EdgeInsets.only(right: 6),
          child: MktFilterChip(
            key: Key('soc_asset_media_${media ?? 'all'}'),
            label: label,
            count: count,
            selected: media == null ? on.isEmpty : (on.length == 1 && on.contains(media)),
            onTap: () => _apply(_s.copyWith(facets: {..._s.facets, 'media': media == null || (on.length == 1 && on.contains(media)) ? <String>{} : {media}}..removeWhere((_, v) => v.isEmpty))),
          ),
        );
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        chip(null, 'All Assets', m.values.fold(0, (a, b) => a + b)),
        chip('image', 'Images', m['image'] ?? 0),
        chip('video', 'Videos', m['video'] ?? 0),
        chip('design', 'Designs', m['design'] ?? 0),
        chip('document', 'Documents', m['document'] ?? 0),
      ]),
    );
  }

  Widget _pickBar(BuildContext context, List<Asset> items, Set<String> picked) {
    final chosen = items.where((a) => picked.contains(a.id)).toList();
    Future<void> bulk(bool remove) async {
      if (chosen.isEmpty) return;
      final changed = await showBulkKeywordsDialog(context, ref, chosen, remove: remove);
      if (changed && mounted) setState(() => _picked = <String>{});
    }

    return Container(
      key: const Key('gl_pick_bar'),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: Mkt.primarySoft, borderRadius: BorderRadius.circular(10), border: Border.all(color: Mkt.primary.withValues(alpha: 0.3))),
      child: Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
        Text(chosen.isEmpty ? 'Tap assets to choose them' : '${chosen.length} chosen', key: const Key('gl_pick_count'), style: mktText(12.5, weight: FontWeight.w800, color: Mkt.primary)),
        TextButton(key: const Key('gl_pick_all'), onPressed: () => setState(() => _picked = {for (final a in items) a.id}), child: Text('Choose all ${items.length} shown')),
        if (chosen.isNotEmpty) ...[
          FilledButton.tonalIcon(key: const Key('gl_bulk_add'), onPressed: () => bulk(false), icon: const Icon(Icons.sell_outlined, size: 16), label: const Text('Add keywords')),
          OutlinedButton.icon(key: const Key('gl_bulk_remove'), onPressed: () => bulk(true), icon: const Icon(Icons.label_off_outlined, size: 16), label: const Text('Remove keywords')),
          TextButton(key: const Key('gl_pick_none'), onPressed: () => setState(() => _picked = <String>{}), child: const Text('Clear')),
        ],
      ]),
    );
  }
}

/// The filters in a sheet (phones): each change applies at once, and the numbers follow it.
class _FilterSheet extends ConsumerStatefulWidget {
  const _FilterSheet({required this.initial, required this.brand, required this.onChanged});
  final AssetSearch initial;
  final String brand;
  final ValueChanged<AssetSearch> onChanged;

  @override
  ConsumerState<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends ConsumerState<_FilterSheet> {
  late AssetSearch _s = widget.initial;
  AssetPage? _last;

  void _set(AssetSearch s) {
    setState(() => _s = s);
    widget.onChanged(s);
  }

  @override
  Widget build(BuildContext context) {
    final page = ref.watch(galleryPageProvider((_s.copyWith(brand: widget.brand), 1)));
    if (page.hasValue) _last = page.value;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      builder: (context, scroll) => Column(children: [
        Expanded(child: ListView(key: const Key('gl_filter_sheet'), controller: scroll, padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), children: [GalleryFilterPanel(search: _s, page: _last, onChanged: _set)])),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const Key('gl_filters_done'),
                style: FilledButton.styleFrom(backgroundColor: Mkt.maroon),
                onPressed: () => Navigator.pop(context),
                child: Text(_last == null ? 'Show results' : 'Show ${groupedCount(_last!.total)} result${_last!.total == 1 ? '' : 's'}'),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}
