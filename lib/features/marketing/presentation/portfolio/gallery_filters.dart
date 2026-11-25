import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/marketing/data/asset_search.dart';
import 'package:nizan_crm/features/marketing/data/socials_models.dart';
import 'package:nizan_crm/features/marketing/data/team_models.dart' show TeamRefusal;
import 'package:nizan_crm/features/marketing/services/team_service.dart' show teamFilterProvider;
import 'package:nizan_crm/features/marketing/presentation/kit/mkt_kit.dart';
import 'package:nizan_crm/features/marketing/presentation/portfolio/keyword_input.dart';
import 'package:nizan_crm/features/marketing/services/socials_service.dart';

// The Creative Portfolio gallery's advanced filters (each list is "any of these", the lists add up, the numbers are what picking it
// would show), the keyword filter (all / any / left out, plus "no keyword yet"), the active-filter chips, and the keyword tools:
// add or remove keywords on many assets at once, and — for a Marketing Manager — rename, merge and remove keywords library-wide.

const kMediaLabels = {'video': 'Videos', 'image': 'Photos', 'design': 'Designs', 'document': 'Documents'};
final kKindLabels = {for (final k in kAssetKinds) k.$1: k.$2};
final kStageLabels = {for (final s in kAssetStages) s.$1: s.$2};

/// What each filter is called on the screen, and the key prefix its rows carry.
const kFacetTitles = {'media': 'Media type', 'kind': 'Asset type', 'stage': 'Production stage', 'portfolio': 'Portfolio', 'page': 'Page', 'owner': 'Owner', 'review': 'Client review of the work', 'artist': 'Artist on the work'};
const _facetKey = {'media': 'gl_media', 'kind': 'gl_kind', 'stage': 'gl_stage', 'portfolio': 'gl_portfolio', 'page': 'gl_page', 'owner': 'gl_owner', 'review': 'gl_review', 'artist': 'gl_artist'};

/// The two filters on the work behind an item (its client's review, its artists) — shown first: they find the work that needs a look.
const kWorkFacets = ['review', 'artist'];

/// A filter value in words. [names] = the artists' names by key (the Artist filter's values are ids).
String facetValueLabel(String facet, String v, [Map<String, String> names = const {}]) => switch (facet) {
      'media' => kMediaLabels[v] ?? v,
      'kind' => kKindLabels[v] ?? v,
      'stage' => kStageLabels[v] ?? v,
      'review' => reviewFilterLabel(v),
      'artist' => (names[v] ?? '').isNotEmpty ? names[v]! : (v.startsWith('n:') ? v.substring(2) : 'An artist'),
      _ => v,
    };

String _day(DateTime d) => DateFormat('yyyy-MM-dd').format(d);
DateTime _parse(String s) => DateTime.parse(s);

/// The added-on dates in words ("Added 1 Nov – 30 Nov 2026").
String addedLabel(AssetSearch s) {
  if (s.from == null || s.to == null) return 'Added: any time';
  final a = _parse(s.from!);
  final b = _parse(s.to!);
  return 'Added ${DateFormat(a.year == b.year ? 'd MMM' : 'd MMM yyyy').format(a)} – ${DateFormat('d MMM yyyy').format(b)}';
}

/// The filters, for the side column (wide screens) or the Filters sheet (phones). [page] gives the numbers next to each value.
class GalleryFilterPanel extends ConsumerWidget {
  const GalleryFilterPanel({super.key, required this.search, required this.page, required this.onChanged, this.showTitle = true});
  final AssetSearch search;
  final AssetPage? page;
  final ValueChanged<AssetSearch> onChanged;

  /// "Filters" over the panel — off when the card around it already says so.
  final bool showTitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = page ?? const AssetPage();
    Map<String, int> values(String f) => {
          // a kind of review no item has is left out (unless it is picked)
          for (final e in p.facet(f).entries)
            if (f != 'review' || e.value > 0 || search.facet(f).contains(e.key)) e.key: e.value,
          for (final v in search.facet(f)) if (!p.facet(f).containsKey(v)) v: 0,
        };
    // stages and media in their natural order; the rest by how many
    List<String>? order(String f) => switch (f) {
          'stage' => [for (final s in kAssetStages) s.$1],
          'media' => kMediaLabels.keys.toList(),
          'kind' => [for (final k in kAssetKinds) k.$1],
          'review' => [for (final r in kReviewFilters) r.$1],
          _ => null,
        };
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (showTitle || search.filterCount > 0)
        Row(children: [
          Expanded(child: showTitle ? Text('Filters', style: mktText(14, weight: FontWeight.w800)) : const SizedBox.shrink()),
          if (search.filterCount > 0) TextButton(key: const Key('gl_clear'), onPressed: () => onChanged(search.cleared()), child: Text('Clear all (${search.filterCount})')),
        ]),
      const SizedBox(height: 4),
      KeywordFilter(search: search, page: p, onChanged: onChanged),
      const Divider(height: 22),
      _Toggle(keyName: 'gl_final', label: 'Final outputs only', value: search.finalOnly, onChanged: (v) => onChanged(search.copyWith(finalOnly: v))),
      _Toggle(keyName: 'gl_usable', label: 'Ready to post (approved or final)', value: search.usable, onChanged: (v) => onChanged(search.copyWith(usable: v))),
      const SizedBox(height: 6),
      _AddedPicker(search: search, onChanged: onChanged),
      const Divider(height: 22),
      for (final f in [...kWorkFacets, ...kAssetFacets.where((x) => !kWorkFacets.contains(x))])
        _FacetSection(name: f, values: values(f), order: order(f), selected: search.facet(f), names: p.artistNames, onToggle: (v) => onChanged(search.toggle(f, v))),
    ]);
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({required this.keyName, required this.label, required this.value, required this.onChanged, this.count});
  final String keyName, label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final int? count;
  @override
  Widget build(BuildContext context) => InkWell(
        key: Key(keyName),
        borderRadius: BorderRadius.circular(8),
        onTap: () => onChanged(!value),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
          child: Row(children: [
            Icon(value ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded, size: 17, color: value ? Mkt.primary : Mkt.inkSoft),
            const SizedBox(width: 8),
            Expanded(child: Text(label, style: mktText(12, weight: value ? FontWeight.w800 : FontWeight.w500))),
            if (count != null) Text('$count', style: mktText(11, color: Mkt.inkSoft)),
          ]),
        ),
      );
}

/// When the assets were added: any time, the shared Marketing period, or dates picked here.
class _AddedPicker extends ConsumerWidget {
  const _AddedPicker({required this.search, required this.onChanged});
  final AssetSearch search;
  final ValueChanged<AssetSearch> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = ref.watch(teamFilterProvider);
    final fmt = DateFormat('d MMM');
    final custom = search.from != null && !(search.from == f.fromDay && search.to == f.toDay);
    final value = search.from == null ? 'any' : (custom ? 'custom' : 'period');
    String range(String a, String b) {
      final x = _parse(a);
      final y = _parse(b);
      return '${DateFormat(x.year == y.year ? 'd MMM' : 'd MMM yy').format(x)} – ${DateFormat('d MMM yy').format(y)}';
    }

    // a narrow side column: the label says "Added", the pill only the dates — and it shrinks rather than overflows
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Added', style: mktText(12.5, weight: FontWeight.w800)),
      const SizedBox(height: 4),
      FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: KeyedSubtree(
          key: const Key('gl_added'),
          child: MktDropdownPill<String>(
            value: value,
            icon: Icons.event_outlined,
            options: [('any', 'Any time'), ('period', '${fmt.format(f.from)} – ${fmt.format(f.to)}'), ('custom', custom ? range(search.from!, search.to!) : 'Pick dates…')],
            onChanged: (v) async {
              if (v == 'any') return onChanged(search.copyWith(from: null, to: null));
              if (v == 'period') return onChanged(search.copyWith(from: f.fromDay, to: f.toDay));
              final now = DateTime.now();
              final r = await showDateRangePicker(
                context: context,
                firstDate: DateTime(2018),
                lastDate: DateTime(now.year + 1, 12, 31),
                initialDateRange: search.from == null ? DateTimeRange(start: now.subtract(const Duration(days: 30)), end: now) : DateTimeRange(start: _parse(search.from!), end: _parse(search.to!)),
                helpText: 'Assets added between',
              );
              if (r != null) onChanged(search.copyWith(from: _day(r.start), to: _day(r.end)));
            },
          ),
        ),
      ),
    ]);
  }
}

/// One filter's values as ticks, with the number each would show; the first six, then "Show all".
class _FacetSection extends StatefulWidget {
  const _FacetSection({required this.name, required this.values, required this.selected, required this.onToggle, this.order, this.names = const {}});
  final String name;
  final Map<String, String> names;
  final Map<String, int> values;
  final Set<String> selected;
  final ValueChanged<String> onToggle;
  final List<String>? order;

  @override
  State<_FacetSection> createState() => _FacetSectionState();
}

class _FacetSectionState extends State<_FacetSection> {
  bool _all = false;

  @override
  Widget build(BuildContext context) {
    final keys = widget.values.keys.toList();
    if (widget.order != null) keys.sort((a, b) => _rank(a).compareTo(_rank(b)));
    // what is picked stays in view, whatever its number
    final shown = _all ? keys : [...keys.take(6), ...keys.skip(6).where(widget.selected.contains)];
    final prefix = _facetKey[widget.name]!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(kFacetTitles[widget.name]!, style: mktText(12.5, weight: FontWeight.w800)),
        const SizedBox(height: 4),
        if (keys.isEmpty) Text('—', style: mktText(11.5, color: Mkt.inkSoft)),
        for (final v in shown)
          _Toggle(keyName: '${prefix}_$v', label: facetValueLabel(widget.name, v, widget.names), value: widget.selected.contains(v), count: widget.values[v], onChanged: (_) => widget.onToggle(v)),
        if (keys.length > 6) TextButton(key: Key('${prefix}_more'), style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact), onPressed: () => setState(() => _all = !_all), child: Text(_all ? 'Show fewer' : 'Show all ${keys.length}')),
      ]),
    );
  }

  int _rank(String v) {
    final i = widget.order!.indexOf(v);
    return i < 0 ? 999 : i;
  }
}

/// The keyword filter: find any keyword in the library, tick the most used, leave some out (⊘), all or any of them, and the assets that
/// have no keyword yet. "Manage keywords" opens the keyword tools.
class KeywordFilter extends ConsumerStatefulWidget {
  const KeywordFilter({super.key, required this.search, required this.page, required this.onChanged});
  final AssetSearch search;
  final AssetPage page;
  final ValueChanged<AssetSearch> onChanged;

  @override
  ConsumerState<KeywordFilter> createState() => _KeywordFilterState();
}

class _KeywordFilterState extends ConsumerState<KeywordFilter> {
  final _find = TextEditingController();
  Timer? _debounce;
  String _typed = '';
  bool _all = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _find.dispose();
    super.dispose();
  }

  void _want(String k, {bool exclude = false}) {
    _find.clear();
    setState(() => _typed = '');
    widget.onChanged(widget.search.toggleKeyword(k, exclude: exclude));
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.search;
    final top = widget.page.keywords;
    final picked = {...s.keywords, ...s.notKeywords};
    final shown = _all ? top : top.take(8).toList();
    final suggest = _typed.isEmpty ? null : ref.watch(keywordSuggestProvider(_typed));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Text('Keywords', style: mktText(12.5, weight: FontWeight.w800))),
        TextButton.icon(key: const Key('gl_kw_manage'), style: TextButton.styleFrom(visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(horizontal: 6)), onPressed: () => showKeywordManager(context, ref, onPick: (k) => widget.onChanged(widget.search.toggleKeyword(k))), icon: const Icon(Icons.tune_rounded, size: 15), label: const Text('Manage')),
      ]),
      const SizedBox(height: 4),
      TextField(
        key: const Key('gl_kw_find'),
        controller: _find,
        style: mktText(12.5),
        onChanged: (v) {
          _debounce?.cancel();
          _debounce = Timer(const Duration(milliseconds: 250), () {
            if (mounted) setState(() => _typed = normalizeKeyword(v));
          });
        },
        onSubmitted: (v) {
          final k = normalizeKeyword(v);
          if (k.isNotEmpty) _want(k);
        },
        decoration: InputDecoration(isDense: true, prefixIcon: const Icon(Icons.sell_outlined, size: 16), hintText: 'Find a keyword…', contentPadding: const EdgeInsets.symmetric(vertical: 9), border: OutlineInputBorder(borderRadius: BorderRadius.circular(9))),
      ),
      if (suggest != null)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: suggest.when(
            loading: () => const LinearProgressIndicator(minHeight: 2),
            error: (e, _) => Text(friendlyErrorMessage(e), style: mktText(11, color: Mkt.bad)),
            data: (l) {
              final list = l.items.where((k) => !picked.contains(k.keyword)).toList();
              if (list.isEmpty) return Text('No keyword in the library is like "$_typed".', key: const Key('gl_kw_none'), style: mktText(11, color: Mkt.inkSoft));
              return Wrap(spacing: 6, runSpacing: 6, children: [
                for (final k in list) ActionChip(key: Key('gl_kw_suggest_${k.keyword}'), visualDensity: VisualDensity.compact, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap, label: Text('${k.keyword}  ${k.count}', style: mktText(11.5, weight: FontWeight.w600)), onPressed: () => _want(k.keyword)),
              ]);
            },
          ),
        ),
      if (picked.isNotEmpty) ...[
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final k in s.keywords) InputChip(key: Key('gl_kw_on_$k'), visualDensity: VisualDensity.compact, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap, backgroundColor: Mkt.primarySoft, label: Text(k, style: mktText(11.5, weight: FontWeight.w700, color: Mkt.primary)), onDeleted: () => _want(k)),
          for (final k in s.notKeywords) InputChip(key: Key('gl_kw_off_$k'), visualDensity: VisualDensity.compact, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap, backgroundColor: Mkt.bad.withValues(alpha: 0.08), avatar: const Icon(Icons.block_rounded, size: 14, color: Mkt.bad), label: Text('not $k', style: mktText(11.5, weight: FontWeight.w700, color: Mkt.bad)), onDeleted: () => _want(k, exclude: true)),
        ]),
      ],
      if (s.keywords.length > 1)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Wrap(spacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
            Text('Show assets with', style: mktText(11.5, color: Mkt.inkSoft)),
            MktFilterChip(key: const Key('gl_kwmode_all'), label: 'all of them', selected: !s.kwAny, onTap: () => widget.onChanged(s.copyWith(kwAny: false))),
            MktFilterChip(key: const Key('gl_kwmode_any'), label: 'any of them', selected: s.kwAny, onTap: () => widget.onChanged(s.copyWith(kwAny: true))),
          ]),
        ),
      const SizedBox(height: 8),
      if (top.isEmpty) Text('No keywords on these assets yet.', style: mktText(11.5, color: Mkt.inkSoft)),
      for (final k in shown)
        Row(children: [
          Expanded(child: _Toggle(keyName: 'gl_tag_${k.keyword}', label: k.keyword, value: s.keywords.contains(k.keyword), count: k.count, onChanged: (_) => _want(k.keyword))),
          IconButton(
            key: Key('gl_tagx_${k.keyword}'),
            tooltip: s.notKeywords.contains(k.keyword) ? 'Stop leaving out "${k.keyword}"' : 'Leave out "${k.keyword}"',
            visualDensity: VisualDensity.compact,
            iconSize: 16,
            constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
            padding: EdgeInsets.zero,
            onPressed: () => _want(k.keyword, exclude: true),
            icon: Icon(Icons.block_rounded, color: s.notKeywords.contains(k.keyword) ? Mkt.bad : Mkt.inkSoft.withValues(alpha: 0.6)),
          ),
        ]),
      if (top.length > 8) TextButton(key: const Key('gl_tag_more'), style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact), onPressed: () => setState(() => _all = !_all), child: Text(_all ? 'Show fewer' : 'Show all ${top.length}')),
      _Toggle(keyName: 'gl_untagged', label: 'No keywords yet', value: s.untagged, count: widget.page.untagged, onChanged: (v) => widget.onChanged(s.copyWith(untagged: v))),
    ]);
  }
}

/// The filters in force as chips, each with its ×, and "Clear all".
class ActiveFilterChips extends StatelessWidget {
  const ActiveFilterChips({super.key, required this.search, required this.onChanged, this.names = const {}});
  final AssetSearch search;

  /// The artists' names by key (the Artist filter's values are ids).
  final Map<String, String> names;
  final ValueChanged<AssetSearch> onChanged;

  @override
  Widget build(BuildContext context) {
    final s = search;
    if (s.filterCount == 0) return const SizedBox.shrink();
    Widget chip(String key, String label, VoidCallback off, {Color color = Mkt.primary}) => InputChip(
          key: Key(key),
          visualDensity: VisualDensity.compact,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          backgroundColor: color.withValues(alpha: 0.08),
          side: BorderSide(color: color.withValues(alpha: 0.35)),
          label: Text(label, style: mktText(11.5, weight: FontWeight.w700, color: color)),
          deleteIconColor: color,
          onDeleted: off,
        );
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
        for (final k in s.keywords) chip('gl_active_kw_$k', '#$k', () => onChanged(s.toggleKeyword(k))),
        if (s.keywords.length > 1) chip('gl_active_kwmode', s.kwAny ? 'any of these keywords' : 'all of these keywords', () => onChanged(s.copyWith(kwAny: !s.kwAny)), color: Mkt.inkSoft),
        for (final k in s.notKeywords) chip('gl_active_notkw_$k', 'not #$k', () => onChanged(s.toggleKeyword(k, exclude: true)), color: Mkt.bad),
        for (final f in kAssetFacets)
          for (final v in s.facet(f)) chip('gl_active_${f}_$v', facetValueLabel(f, v, names), () => onChanged(s.toggle(f, v))),
        if (s.untagged) chip('gl_active_untagged', 'No keywords yet', () => onChanged(s.copyWith(untagged: false))),
        if (s.finalOnly) chip('gl_active_final', 'Final outputs', () => onChanged(s.copyWith(finalOnly: false))),
        if (s.usable) chip('gl_active_usable', 'Ready to post', () => onChanged(s.copyWith(usable: false))),
        if (s.from != null) chip('gl_active_added', addedLabel(s), () => onChanged(s.copyWith(from: null, to: null))),
        TextButton(key: const Key('gl_clear_all'), onPressed: () => onChanged(s.cleared()), child: const Text('Clear all')),
      ]),
    );
  }
}

// ── keyword tools ────────────────────────────────────────────────────────────

void _say(BuildContext context, String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text), duration: const Duration(seconds: 6)));

/// Add keywords to the chosen assets ([remove] false), or take some off them ([remove] true — the keywords they carry are offered).
/// Returns true when something was changed.
Future<bool> showBulkKeywordsDialog(BuildContext context, WidgetRef ref, List<Asset> assets, {required bool remove}) async {
  final changed = await showDialog<bool>(context: context, builder: (_) => _BulkKeywordsDialog(assets: assets, remove: remove));
  return changed == true;
}

class _BulkKeywordsDialog extends ConsumerStatefulWidget {
  const _BulkKeywordsDialog({required this.assets, required this.remove});
  final List<Asset> assets;
  final bool remove;

  @override
  ConsumerState<_BulkKeywordsDialog> createState() => _BulkKeywordsDialogState();
}

class _BulkKeywordsDialogState extends ConsumerState<_BulkKeywordsDialog> {
  List<String> _add = [];
  final _text = TextEditingController();
  final Set<String> _drop = {};
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  /// The keywords the chosen assets carry, the most shared first.
  List<MapEntry<String, int>> get _carried {
    final m = <String, int>{};
    for (final a in widget.assets) {
      for (final t in a.tags) {
        m[t] = (m[t] ?? 0) + 1;
      }
    }
    return m.entries.toList()..sort((a, b) => b.value.compareTo(a.value) == 0 ? a.key.compareTo(b.key) : b.value.compareTo(a.value));
  }

  Future<void> _apply() async {
    final add = widget.remove ? <String>[] : addKeywords(_add, splitKeywords(_text.text)).keywords;
    final drop = widget.remove ? _drop.toList() : <String>[];
    if (add.isEmpty && drop.isEmpty) return setState(() => _error = widget.remove ? 'Tick the keywords to take off.' : 'Type the keywords to add.');
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final r = await ref.read(marketingSocialsServiceProvider).bulkKeywords([for (final a in widget.assets) a.id], add: add, remove: drop);
      refreshSocials(ref);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context, true);
      messenger.showSnackBar(SnackBar(content: Text(r.summary(widget.remove ? 'removed' : 'added')), duration: const Duration(seconds: 6)));
    } on TeamRefusal catch (e) {
      if (mounted) setState(() => (_error = e.message, _saving = false));
    } catch (e) {
      if (mounted) setState(() => (_error = friendlyErrorMessage(e), _saving = false));
    }
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.assets.length;
    final carried = _carried;
    return AlertDialog(
      title: Text(widget.remove ? 'Remove keywords from $n asset${n == 1 ? '' : 's'}' : 'Add keywords to $n asset${n == 1 ? '' : 's'}'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (widget.remove) ...[
              if (carried.isEmpty) Text('These assets carry no keywords.', style: mktText(12.5, color: Mkt.inkSoft)),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final e in carried)
                  FilterChip(key: Key('bulk_drop_${e.key}'), selected: _drop.contains(e.key), label: Text('${e.key}  ${e.value}/$n'), onSelected: (v) => setState(() => v ? _drop.add(e.key) : _drop.remove(e.key))),
              ]),
            ] else ...[
              KeywordInput(keywords: _add, controller: _text, fieldKey: const Key('bulk_kw_input'), commitOnBlur: false, onChanged: (v) => setState(() => _add = v), note: 'Added to every chosen asset that does not have it yet. An asset already carrying $kMaxKeywords keywords is left as it was.'),
            ],
            if (_error != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(_error!, key: const Key('bulk_error'), style: mktText(12.5, weight: FontWeight.w600, color: Mkt.bad))),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(key: const Key('bulk_apply'), style: FilledButton.styleFrom(backgroundColor: Mkt.maroon), onPressed: _saving ? null : _apply, child: Text(widget.remove ? 'Remove' : 'Add')),
      ],
    );
  }
}

/// The new name for a keyword (the dialog owns its text field, so nothing is used after it closes).
class _RenameDialog extends StatefulWidget {
  const _RenameDialog({required this.keyword});
  final KeywordCount keyword;
  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final _ctl = TextEditingController(text: widget.keyword.keyword);

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final k = widget.keyword;
    return AlertDialog(
      title: Text('Rename "${k.keyword}"'),
      content: SizedBox(
        width: 380,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          TextField(key: const Key('kwm_rename_field'), controller: _ctl, autofocus: true, decoration: const InputDecoration(labelText: 'New keyword', border: OutlineInputBorder(), isDense: true), onSubmitted: (v) => Navigator.pop(context, v)),
          const SizedBox(height: 8),
          Text('Changes it on all ${k.count} asset${k.count == 1 ? '' : 's'}. Typing a keyword that already exists merges the two.', style: mktText(11.5, color: Mkt.inkSoft)),
        ]),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), FilledButton(key: const Key('kwm_rename_ok'), onPressed: () => Navigator.pop(context, _ctl.text), child: const Text('Rename'))],
    );
  }
}

/// Every keyword in the library with how many assets carry it. Tap one to filter by it ([onPick]). A Marketing Manager can rename one
/// (into an existing one = a merge, said before it is done) and remove one from every asset.
Future<void> showKeywordManager(BuildContext context, WidgetRef ref, {ValueChanged<String>? onPick}) => showDialog<void>(context: context, builder: (_) => _KeywordManager(onPick: onPick));

class _KeywordManager extends ConsumerStatefulWidget {
  const _KeywordManager({this.onPick});
  final ValueChanged<String>? onPick;

  @override
  ConsumerState<_KeywordManager> createState() => _KeywordManagerState();
}

class _KeywordManagerState extends ConsumerState<_KeywordManager> {
  String _q = '';
  bool _busy = false;

  Future<void> _rename(KeywordCount k, List<KeywordCount> all) async {
    final to = await showDialog<String>(context: context, builder: (_) => _RenameDialog(keyword: k));
    if (to == null || !mounted) return;
    final target = normalizeKeyword(to);
    if (target.isEmpty || target == k.keyword) return;
    final existing = all.where((x) => x.keyword == target).firstOrNull;
    if (existing != null) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Merge the keywords?'),
          content: Text('"${k.keyword}" (${k.count}) becomes "$target" (${existing.count}). An asset that has both keeps "$target" once. This cannot be undone in one step.'),
          actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')), FilledButton(key: const Key('kwm_merge_ok'), onPressed: () => Navigator.pop(c, true), child: const Text('Merge'))],
        ),
      );
      if (ok != true || !mounted) return;
    }
    await _run(() async {
      final r = await ref.read(marketingSocialsServiceProvider).renameKeyword(k.keyword, to);
      return r.merged ? '"${r.from}" merged into "${r.to}" on ${r.updated} asset${r.updated == 1 ? '' : 's'}.' : '"${r.from}" is now "${r.to}" on ${r.updated} asset${r.updated == 1 ? '' : 's'}.';
    });
  }

  Future<void> _remove(KeywordCount k) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Remove "${k.keyword}"?'),
        content: Text('It is taken off all ${k.count} asset${k.count == 1 ? '' : 's'} that carry it. The assets themselves stay.'),
        actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')), FilledButton(key: const Key('kwm_remove_ok'), style: FilledButton.styleFrom(backgroundColor: Mkt.bad), onPressed: () => Navigator.pop(c, true), child: const Text('Remove'))],
      ),
    );
    if (ok != true || !mounted) return;
    await _run(() async {
      final n = await ref.read(marketingSocialsServiceProvider).removeKeyword(k.keyword);
      return '"${k.keyword}" removed from $n asset${n == 1 ? '' : 's'}.';
    });
  }

  Future<void> _run(Future<String> Function() job) async {
    setState(() => _busy = true);
    try {
      final msg = await job();
      refreshSocials(ref);
      if (mounted) _say(context, msg);
    } on TeamRefusal catch (e) {
      if (mounted) _say(context, e.message);
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(keywordLibraryProvider);
    return AlertDialog(
      title: const Text('Keywords'),
      content: SizedBox(
        width: 520,
        height: 480,
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => AppErrorView(error: e, onRetry: () => ref.invalidate(keywordLibraryProvider)),
          data: (l) {
            final q = normalizeKeyword(_q);
            final list = q.isEmpty ? l.items : l.items.where((k) => k.keyword.contains(q)).toList();
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${l.total} keyword${l.total == 1 ? '' : 's'} in the library.${l.canManage ? ' Rename one to fix a spelling, or into another to merge them.' : ' A Marketing Manager can rename, merge and remove them.'}', style: mktText(12, color: Mkt.inkSoft)),
              const SizedBox(height: 8),
              TextField(key: const Key('kwm_search'), onChanged: (v) => setState(() => _q = v), decoration: InputDecoration(isDense: true, prefixIcon: const Icon(Icons.search_rounded, size: 18), hintText: 'Find a keyword…', border: OutlineInputBorder(borderRadius: BorderRadius.circular(9)))),
              if (_busy) const LinearProgressIndicator(minHeight: 2),
              const SizedBox(height: 6),
              Expanded(
                child: list.isEmpty
                    ? Center(child: Text(l.items.isEmpty ? 'No asset has a keyword yet.' : 'No keyword like "$q".', style: mktText(12.5, color: Mkt.inkSoft)))
                    : ListView.separated(
                        itemCount: list.length,
                        separatorBuilder: (_, _) => const Divider(height: 1, color: Mkt.border),
                        itemBuilder: (_, i) {
                          final k = list[i];
                          return ListTile(
                            key: Key('kwm_row_${k.keyword}'),
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                            title: Text(k.keyword, style: mktText(13, weight: FontWeight.w700)),
                            subtitle: Text('${k.count} asset${k.count == 1 ? '' : 's'}', style: mktText(11, color: Mkt.inkSoft)),
                            onTap: widget.onPick == null
                                ? null
                                : () {
                                    widget.onPick!(k.keyword);
                                    Navigator.pop(context);
                                  },
                            trailing: !l.canManage
                                ? null
                                : Row(mainAxisSize: MainAxisSize.min, children: [
                                    IconButton(key: Key('kwm_rename_${k.keyword}'), tooltip: 'Rename or merge', icon: const Icon(Icons.edit_outlined, size: 18), onPressed: _busy ? null : () => _rename(k, l.items)),
                                    IconButton(key: Key('kwm_remove_${k.keyword}'), tooltip: 'Remove from every asset', icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Mkt.bad), onPressed: _busy ? null : () => _remove(k)),
                                  ]),
                          );
                        },
                      ),
              ),
            ]);
          },
        ),
      ),
      actions: [TextButton(key: const Key('kwm_close'), onPressed: () => Navigator.pop(context), child: const Text('Close'))],
    );
  }
}
