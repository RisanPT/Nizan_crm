// The Creative Portfolio gallery's search, filters and keywords (backend controllers/marketingSocialsController.js → listAssets and the
// /assets/keywords routes; the rules in backend utils/assetSearch.js and utils/assetKeywords.js).

import 'package:flutter/foundation.dart';

import 'package:nizan_crm/features/marketing/data/socials_models.dart';

int _i(dynamic v) => (v as num?)?.toInt() ?? 0;
String _s(dynamic v) => v?.toString() ?? '';
Map<String, dynamic> _m(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
List<Map<String, dynamic>> _l(dynamic v) => ((v as List?) ?? const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
List<String> _strs(dynamic v) => ((v as List?) ?? const []).map(_s).where((x) => x.isNotEmpty).toList();

// ── keywords: the server's rules, so the form shows what will be saved ────────

/// The most keywords one asset carries, and the longest a keyword may be (the server refuses more — never cuts short).
const kMaxKeywords = 50;
const kMaxKeywordLen = 40;

final _edge = RegExp(r'''^[\s"'`.,;:!?()\[\]{}<>|\\/*~^=+\-]+|[\s"'`.,;:!?()\[\]{}<>|\\/*~^=+\-]+$''');

/// One spelling for a keyword: no leading #, single spaces, no stray punctuation at either end, lower case ("#Bridal." → "bridal").
String normalizeKeyword(String raw) => raw.replaceFirst(RegExp(r'^[\s#]+'), '').replaceAll(RegExp(r'\s+'), ' ').replaceAll(_edge, '').toLowerCase();

/// The pieces typed or pasted: a comma, semicolon, new line, tab or # starts the next keyword ("bridal, reel #kerala bride").
List<String> splitKeywords(String input) => [for (final piece in input.split(RegExp(r'[,;\n\r\t]+'))) ...piece.split('#')];

/// [current] with what was typed added: normalized, never twice. Returns the new list and, when something could not be added, why.
({List<String> keywords, String? notice}) addKeywords(List<String> current, Iterable<String> typed, {int max = kMaxKeywords}) {
  final out = [...current];
  String? notice;
  for (final piece in typed) {
    final k = normalizeKeyword(piece);
    if (k.isEmpty) continue;
    if (k.length > kMaxKeywordLen) {
      notice = 'Keep each keyword to $kMaxKeywordLen characters — split "${k.length > 24 ? '${k.substring(0, 24)}…' : k}" with a comma.';
      continue;
    }
    if (out.contains(k)) {
      notice = '"$k" is already added.';
      continue;
    }
    if (out.length >= max) {
      notice = 'An asset can carry up to $max keywords.';
      break;
    }
    out.add(k);
  }
  return (keywords: out, notice: notice);
}

class KeywordCount {
  const KeywordCount(this.keyword, this.count);
  final String keyword;
  final int count;
  factory KeywordCount.fromJson(Map<String, dynamic> j) => KeywordCount(_s(j['keyword']), _i(j['count']));
}

/// The library's keywords with how many assets carry each; [canManage] = this login may rename, merge and remove them.
class KeywordList {
  const KeywordList({this.items = const [], this.total = 0, this.canManage = false});
  final List<KeywordCount> items;
  final int total;
  final bool canManage;
  factory KeywordList.fromJson(Map<String, dynamic> j) => KeywordList(items: _l(j['items']).map(KeywordCount.fromJson).toList(), total: _i(j['total']), canManage: j['canManage'] == true);
}

class KeywordRename {
  const KeywordRename({required this.from, required this.to, this.updated = 0, this.merged = false});
  final String from, to;
  final int updated;
  final bool merged;
  factory KeywordRename.fromJson(Map<String, dynamic> j) => KeywordRename(from: _s(j['from']), to: _s(j['to']), updated: _i(j['updated']), merged: j['merged'] == true);
}

/// What a bulk keyword change did: changed, already so, left as they were (and why), not found.
class BulkKeywordResult {
  const BulkKeywordResult({this.updated = 0, this.unchanged = 0, this.skipped = const [], this.missing = 0});
  final int updated, unchanged, missing;
  final List<({String title, String reason})> skipped;
  factory BulkKeywordResult.fromJson(Map<String, dynamic> j) => BulkKeywordResult(
        updated: _i(j['updated']),
        unchanged: _i(j['unchanged']),
        missing: _i(j['missing']),
        skipped: [for (final s in _l(j['skipped'])) (title: _s(s['title']), reason: _s(s['reason']))],
      );

  /// In words, for the message after it is done.
  String summary(String verb) {
    final parts = <String>[
      updated == 0 ? 'No asset needed $verb' : '${verb[0].toUpperCase()}${verb.substring(1)} on $updated asset${updated == 1 ? '' : 's'}',
      if (unchanged > 0 && updated > 0) '$unchanged already so',
      if (skipped.isNotEmpty) '${skipped.length} left as ${skipped.length == 1 ? 'it was' : 'they were'}: ${skipped.map((s) => '${s.title} (${s.reason})').join('; ')}',
      if (missing > 0) '$missing no longer in the library',
    ];
    return '${parts.join(' · ')}.';
  }
}

// ── the search ───────────────────────────────────────────────────────────────

/// How many assets a page of the gallery brings.
const kGalleryPageSize = 60;

/// The filters with several values each, by the name the server knows them by.
/// 'artist' (an artist on the work behind the item: employee id or "n:name") and 'review' (the client's review of it) — see
/// work_review.dart.
const kAssetFacets = ['media', 'kind', 'stage', 'portfolio', 'page', 'owner', 'artist', 'review'];

/// One gallery search. Every list is "any of these"; the lists, keywords, toggles and dates add up. [keywords] are all wanted unless
/// [kwAny]; [notKeywords] are left out. [sort] 'auto' = Best match while words are searched, else the newest first.
@immutable
class AssetSearch {
  const AssetSearch({this.q = '', this.facets = const {}, this.keywords = const [], this.notKeywords = const [], this.kwAny = false, this.finalOnly = false, this.usable = false, this.untagged = false, this.from, this.to, this.sort = 'auto', this.brand = 'all'});
  final String q;
  final Map<String, Set<String>> facets;
  final List<String> keywords, notKeywords;
  final bool kwAny, finalOnly, usable, untagged;
  final String? from, to;
  final String sort, brand;

  Set<String> facet(String name) => facets[name] ?? const {};
  bool get hasWords => q.trim().isNotEmpty;
  String get effectiveSort => sort == 'auto' ? (hasWords ? 'relevance' : 'newest') : (sort == 'relevance' && !hasWords ? 'newest' : sort);

  /// The filters on (the words searched, the sort and the brand are not filters) — for the "Filters (3)" button.
  int get filterCount => facets.values.fold(0, (n, s) => n + s.length) + keywords.length + notKeywords.length + (finalOnly ? 1 : 0) + (usable ? 1 : 0) + (untagged ? 1 : 0) + (from != null ? 1 : 0);

  AssetSearch copyWith({String? q, Map<String, Set<String>>? facets, List<String>? keywords, List<String>? notKeywords, bool? kwAny, bool? finalOnly, bool? usable, bool? untagged, Object? from = _keep, Object? to = _keep, String? sort, String? brand}) => AssetSearch(
        q: q ?? this.q,
        facets: facets ?? this.facets,
        keywords: keywords ?? this.keywords,
        notKeywords: notKeywords ?? this.notKeywords,
        kwAny: kwAny ?? this.kwAny,
        finalOnly: finalOnly ?? this.finalOnly,
        usable: usable ?? this.usable,
        untagged: untagged ?? this.untagged,
        from: identical(from, _keep) ? this.from : from as String?,
        to: identical(to, _keep) ? this.to : to as String?,
        sort: sort ?? this.sort,
        brand: brand ?? this.brand,
      );

  /// [value] in or out of the [name] filter.
  AssetSearch toggle(String name, String value) {
    final s = {...facet(name)};
    if (!s.remove(value)) s.add(value);
    return copyWith(facets: {...facets, name: s}..removeWhere((_, v) => v.isEmpty));
  }

  /// A keyword wanted (or, with [exclude], left out); asked again = taken off. A keyword is never both.
  AssetSearch toggleKeyword(String k, {bool exclude = false}) {
    final inList = exclude ? notKeywords : keywords;
    if (inList.contains(k)) return exclude ? copyWith(notKeywords: [...notKeywords]..remove(k)) : copyWith(keywords: [...keywords]..remove(k));
    return exclude ? copyWith(notKeywords: [...notKeywords, k], keywords: [...keywords]..remove(k)) : copyWith(keywords: [...keywords, k], notKeywords: [...notKeywords]..remove(k));
  }

  /// Every filter off; the words searched and the sort stay.
  AssetSearch cleared() => AssetSearch(q: q, sort: sort, brand: brand);

  Map<String, dynamic> query({int pageNo = 1, int limit = kGalleryPageSize}) => {
        if (hasWords) 'q': q.trim(),
        for (final f in kAssetFacets)
          if (facet(f).isNotEmpty) f: facet(f).toList(),
        if (keywords.isNotEmpty) 'kw': keywords,
        if (kwAny && keywords.isNotEmpty) 'kwMode': 'any',
        if (notKeywords.isNotEmpty) 'notKw': notKeywords,
        if (finalOnly) 'final': 1,
        if (usable) 'usable': 1,
        if (untagged) 'untagged': 1,
        if (from != null && to != null) ...{'from': from, 'to': to},
        if (brand != 'all') 'brand': brand,
        'sort': effectiveSort,
        'pageNo': pageNo,
        'limit': limit,
      };

  @override
  bool operator ==(Object other) =>
      other is AssetSearch &&
      other.q == q &&
      mapEquals(other.facets.map((k, v) => MapEntry(k, (v.toList()..sort()).join('\u0000'))), facets.map((k, v) => MapEntry(k, (v.toList()..sort()).join('\u0000')))) &&
      listEquals(other.keywords, keywords) &&
      listEquals(other.notKeywords, notKeywords) &&
      other.kwAny == kwAny &&
      other.finalOnly == finalOnly &&
      other.usable == usable &&
      other.untagged == untagged &&
      other.from == from &&
      other.to == to &&
      other.sort == sort &&
      other.brand == brand;

  @override
  int get hashCode => Object.hash(q, Object.hashAllUnordered(facets.entries.map((e) => Object.hash(e.key, Object.hashAllUnordered(e.value)))), Object.hashAll(keywords), Object.hashAll(notKeywords), kwAny, finalOnly, usable, untagged, from, to, sort, brand);
}

const Object _keep = Object();

/// One page of the gallery: the assets, how many match in all, the library's figures (brand and dates), each filter's values with the
/// number they would show (counted with every filter but their own), the keywords, how many have none, and what the search box was
/// read as.
class AssetPage {
  const AssetPage({this.items = const [], this.total = 0, this.pageNo = 1, this.pages = 1, this.sort = 'newest', this.counts = const AssetCounts(), this.facets = const {}, this.keywords = const [], this.untagged = 0, this.terms = const [], this.exclude = const [], this.hashKeywords = const [], this.hashNotKeywords = const [], this.canManage = false, this.artistNames = const {}});
  final List<Asset> items;

  /// This login may approve, reject and mark final outputs (a Marketing Manager).
  final bool canManage;
  final int total, pageNo, pages, untagged;
  final String sort;
  final AssetCounts counts;
  final Map<String, Map<String, int>> facets;
  final List<KeywordCount> keywords;
  final List<String> terms, exclude, hashKeywords, hashNotKeywords;

  /// The artists in the Artist filter: key → name.
  final Map<String, String> artistNames;

  Map<String, int> facet(String name) => facets[name] ?? const {};

  factory AssetPage.fromJson(Map<String, dynamic> j) {
    final f = _m(j['facets']);
    Map<String, int> counts(String k) => _m(f[k]).map((a, b) => MapEntry(a, _i(b)));
    final kw = _l(f['keywords']).map(KeywordCount.fromJson).toList();
    final search = _m(j['search']);
    final artists = _l(f['artists']);
    return AssetPage(
      items: _l(j['items']).map(Asset.fromJson).toList(),
      total: _i(j['total']),
      pageNo: _i(j['pageNo']) == 0 ? 1 : _i(j['pageNo']),
      pages: _i(j['pages']) == 0 ? 1 : _i(j['pages']),
      sort: _s(j['sort']).isEmpty ? 'newest' : _s(j['sort']),
      counts: AssetCounts.fromJson(_m(j['counts'])),
      facets: {
        'media': counts('media'),
        'kind': counts('kinds'),
        'stage': counts('stages'),
        'portfolio': counts('portfolios'),
        'page': counts('pages'),
        'owner': counts('owners'),
        // the artists on the works (most items first) and the kinds of client review (an older server sends neither)
        'artist': {for (final a in artists) _s(a['key']): _i(a['count'])},
        'review': {for (final e in _m(f['reviews']).entries) e.key: _i(e.value)},
      },
      // a server without the keyword list sends the map only
      keywords: kw.isNotEmpty ? kw : counts('tags').entries.map((e) => KeywordCount(e.key, e.value)).toList(),
      untagged: _i(f['untagged']),
      terms: _strs(search['terms']),
      exclude: _strs(search['exclude']),
      hashKeywords: _strs(search['keywords']),
      hashNotKeywords: _strs(search['notKeywords']),
      canManage: j['canManage'] == true,
      artistNames: {for (final a in artists) _s(a['key']): _s(a['name'])},
    );
  }

  /// What the search box was read as, in words ("bridal · "kerala bride" · not party · keyword hero"); '' when nothing was.
  String get searchRead => [...terms, for (final x in exclude) 'not $x', for (final k in hashKeywords) 'keyword $k', for (final k in hashNotKeywords) 'not keyword $k'].join(' · ');
}
