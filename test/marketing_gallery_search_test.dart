import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nizan_crm/core/theme/app_theme.dart';
import 'package:nizan_crm/features/marketing/data/asset_search.dart';
import 'package:nizan_crm/features/marketing/data/socials_models.dart';
import 'package:nizan_crm/features/marketing/data/team_models.dart';
import 'package:nizan_crm/features/marketing/presentation/media/media_stream.dart';
import 'package:nizan_crm/features/marketing/presentation/portfolio/keyword_input.dart';
import 'package:nizan_crm/features/marketing/presentation/portfolio/portfolio_gallery_tab.dart';
import 'package:nizan_crm/features/marketing/presentation/socials/asset_editor.dart';
import 'package:nizan_crm/features/marketing/services/socials_service.dart';
import 'package:nizan_crm/features/marketing/services/team_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

// The Creative Portfolio gallery's advanced search: keywords typed every which way end up one spelling each (the server's rules), the
// filters take several values, keywords can be all / any / left out, the search box's words go to the server (and what it read is
// shown), pages load on "Show more", assets can be chosen to add or remove keywords together, and a Marketing Manager can rename,
// merge and remove keywords. Phones get the filters in a sheet.

Finder _k(String key) => find.byKey(Key(key));

Map<String, dynamic> _asset(String id, String title, {List<String> tags = const [], String media = 'image', String kind = 'still'}) =>
    {'id': id, 'title': title, 'brand': 'main', 'kind': kind, 'media': media, 'stage': 'approved', 'url': 'https://d.test/$id.jpg', 'thumbUrl': '', 'portfolio': 'Main (Company)', 'page': 'Bridal Makeup', 'tags': tags, 'owner': 'Preethi', 'createdAt': '2026-11-10T05:00:00.000Z'};

const _library = [KeywordCount('bridal', 4), KeywordCount('bride', 2), KeywordCount('reel', 2), KeywordCount('kerala bride', 1)];

class _Fake extends MarketingSocialsService {
  _Fake({this.canManage = false}) : super(Dio());
  final bool canManage;
  final searches = <(AssetSearch, int)>[];
  final bulk = <({List<String> ids, List<String> add, List<String> remove})>[];
  final renamed = <(String, String)>[];
  final removed = <String>[];
  final saved = <Map<String, dynamic>>[];

  @override
  Future<AssetPage> searchAssets(AssetSearch s, {int pageNo = 1, int limit = kGalleryPageSize}) async {
    searches.add((s, pageNo));
    final items = pageNo == 1
        ? [_asset('a1', 'Bridal reel — Anjali', tags: ['bridal', 'reel', 'kerala bride', 'hero'], media: 'video', kind: 'reel'), _asset('a2', 'Studio clip', tags: ['bridal', 'studio']), _asset('a3', 'Logo sheet')]
        : [_asset('a4', 'Second page still', tags: ['bridal']), _asset('a5', 'Last one')];
    return AssetPage.fromJson({
      'items': items,
      'total': 5,
      'pageNo': pageNo,
      'pages': 2,
      'sort': s.effectiveSort,
      'counts': {'total': 9, 'photos': 6, 'videos': 3, 'finals': 1, 'approved': 5, 'postProducedPct': 80},
      'facets': {
        'media': {'video': 3, 'image': 6},
        'portfolios': {'Main (Company)': 7, 'Kerala': 2},
        'pages': {'Bridal Makeup': 5},
        'stages': {'approved': 5, 'raw': 4},
        'kinds': {'reel': 3, 'still': 6},
        'owners': {'Preethi': 6, 'Anu': 3},
        'keywords': [for (final k in _library) {'keyword': k.keyword, 'count': k.count}],
        'untagged': 1,
      },
      if (s.hasWords) 'search': {'terms': ['"kerala bride"'], 'exclude': ['party']},
    });
  }

  @override
  Future<KeywordList> keywords({String q = '', int limit = 12}) async {
    final t = normalizeKeyword(q);
    return KeywordList(items: _library.where((k) => t.isEmpty || k.keyword.contains(t)).take(limit).toList(), total: _library.length, canManage: canManage);
  }

  @override
  Future<KeywordRename> renameKeyword(String from, String to) async {
    renamed.add((from, to));
    return KeywordRename(from: from, to: normalizeKeyword(to), updated: 2, merged: true);
  }

  @override
  Future<int> removeKeyword(String keyword) async {
    removed.add(keyword);
    return 1;
  }

  @override
  Future<BulkKeywordResult> bulkKeywords(List<String> ids, {List<String> add = const [], List<String> remove = const []}) async {
    bulk.add((ids: ids, add: add, remove: remove));
    return BulkKeywordResult(updated: ids.length - 1, unchanged: 0, skipped: const [(title: 'Full of keywords', reason: 'It would carry 52 keywords; the most is 50.')]);
  }

  @override
  Future<Asset> saveAsset(Map<String, dynamic> body, {String? id}) async {
    saved.add(body);
    return Asset.fromJson({'id': id ?? 'new', ...body});
  }
}

class _NoTeam extends MarketingTeamService {
  _NoTeam() : super(Dio());
  @override
  Future<LogSetup> logSetup({required String date, String? memberId}) async => throw Exception('no team in this test');
}

class _Capture implements HttpClientAdapter {
  _Capture(this.seen);
  final List<RequestOptions> seen;
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<List<int>>? requestStream, Future<void>? cancelFuture) async {
    seen.add(options);
    return ResponseBody.fromString('{}', 200, headers: {Headers.contentTypeHeader: ['application/json']});
  }

  @override
  void close({bool force = false}) {}
}

Future<_Fake> _pump(WidgetTester t, Widget child, {_Fake? fake, Size size = const Size(1400, 2600)}) async {
  SharedPreferences.setMockInitialValues({});
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final f = fake ?? _Fake();
  await t.pumpWidget(ProviderScope(
    overrides: [marketingSocialsServiceProvider.overrideWithValue(f), marketingTeamServiceProvider.overrideWithValue(_NoTeam()), mediaStreamServiceProvider.overrideWithValue(NoMediaStream())],
    child: MaterialApp(theme: AppTheme.lightTheme, home: Scaffold(body: child)),
  ));
  await t.pumpAndSettle();
  return f;
}

Future<void> _tap(WidgetTester t, String key) async {
  await t.ensureVisible(_k(key));
  await t.tap(_k(key));
  await t.pumpAndSettle();
}

/// A keyword field on its own, with what it holds kept outside (as the asset form keeps it).
class _Host extends StatefulWidget {
  const _Host({this.start = const []});
  final List<String> start;
  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late List<String> kw = [...widget.start];
  final text = TextEditingController();
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.all(16), child: KeywordInput(keywords: kw, controller: text, onChanged: (v) => setState(() => kw = v)));
}

List<String> _chips(WidgetTester t) => t.widgetList<InputChip>(find.byType(InputChip)).map((c) => (c.label as Text).data!).toList();

void main() {
  group('keywords — the server\'s rules, on the phone and the web alike', () {
    test('one spelling: case, #, spaces and stray punctuation make no new keyword', () {
      for (final v in ['Bridal', ' bridal ', '#Bridal', '##BRIDAL.', '"bridal"', '(bridal)']) {
        expect(normalizeKeyword(v), 'bridal', reason: v);
      }
      expect(normalizeKeyword('Kerala   Bride'), 'kerala bride');
      expect(normalizeKeyword('Pre-Wedding'), 'pre-wedding');
      expect(splitKeywords('bridal, reel; kerala\nbride #hero').map((s) => s.trim()).where((s) => s.isNotEmpty), ['bridal', 'reel', 'kerala', 'bride', 'hero']);
    });

    test('adding: never twice, never too long, never more than the most — and it says which', () {
      final dup = addKeywords(['bridal'], ['Reel', '#BRIDAL']);
      expect(dup.keywords, ['bridal', 'reel']);
      expect(dup.notice, '"bridal" is already added.');
      final long = addKeywords([], ['x' * 41]);
      expect(long.keywords, isEmpty);
      expect(long.notice, contains('40 characters'));
      final full = addKeywords([for (var i = 0; i < 49; i++) 'k$i'], ['a', 'b']);
      expect(full.keywords.length, 50);
      expect(full.notice, 'An asset can carry up to 50 keywords.');
    });

    testWidgets('typing: a comma adds; Enter adds; a pasted list becomes chips; × takes one off', (t) async {
      await _pump(t, const _Host());
      await t.enterText(_k('asset_tags'), 'Bridal, #Reel, kerala  bride');
      await t.pump();
      expect(_chips(t), ['bridal', 'reel']);
      expect(t.widget<TextField>(_k('asset_tags')).controller!.text, 'kerala  bride', reason: 'still being typed');
      await t.testTextInput.receiveAction(TextInputAction.done);
      await t.pumpAndSettle();
      expect(_chips(t), ['bridal', 'reel', 'kerala bride']);
      expect(find.text('3 / 50'), findsOneWidget);
      await t.enterText(_k('asset_tags'), 'BRIDAL,');
      await t.pump();
      expect(t.widget<Text>(_k('kw_notice')).data, '"bridal" is already added.');
      await t.tap(find.descendant(of: _k('kw_chip_reel'), matching: find.byIcon(Icons.close_rounded)));
      await t.pumpAndSettle();
      expect(_chips(t), ['bridal', 'kerala bride']);
    });

    testWidgets('Backspace in the empty field takes the last keyword off', (t) async {
      await _pump(t, const _Host(start: ['bridal', 'reel']));
      await t.tap(_k('asset_tags'));
      await t.pump();
      await t.sendKeyEvent(LogicalKeyboardKey.backspace);
      await t.pump();
      expect(_chips(t), ['bridal']);
    });

    testWidgets('suggestions from the library while typing, with how many carry each; a tap adds it', (t) async {
      await _pump(t, const _Host());
      await t.tap(_k('asset_tags'));
      await t.pumpAndSettle();
      expect(find.text('Often used:'), findsOneWidget);
      await t.enterText(_k('asset_tags'), 'bri');
      await t.pump(const Duration(milliseconds: 300));
      await t.pumpAndSettle();
      expect(find.text('bridal  4'), findsOneWidget);
      expect(find.text('kerala bride  1'), findsOneWidget);
      expect(find.textContaining('press Enter to add "bri"'), findsOneWidget, reason: 'a new keyword is allowed, and said');
      await t.tap(_k('kw_suggest_bridal'));
      await t.pumpAndSettle();
      expect(_chips(t), ['bridal']);
      expect(_k('kw_suggest_bridal'), findsNothing, reason: 'what is added is not suggested again');
    });

    testWidgets('full at 50: the field says so and takes no more', (t) async {
      await _pump(t, _Host(start: [for (var i = 0; i < 50; i++) 'k$i']));
      expect(find.text('50 / 50'), findsOneWidget);
      expect(t.widget<TextField>(_k('asset_tags')).enabled, isFalse);
    });

    testWidgets('the asset form saves the chips and what is still typed, once each', (t) async {
      final f = await _pump(t, Consumer(builder: (c, ref, _) => TextButton(key: const Key('open'), onPressed: () => showAssetEditor(c, ref), child: const Text('open'))));
      await _tap(t, 'open');
      await t.enterText(_k('asset_title'), 'Haldi still');
      await t.enterText(_k('asset_url'), 'https://d.test/h.jpg');
      await t.enterText(_k('asset_tags'), 'Haldi, #Kerala, haldi');
      await t.pump();
      await _tap(t, 'asset_save');
      expect(f.saved.single['tags'], ['haldi', 'kerala']);
    });
    testWidgets('on an Android phone a tap on Save does not leave the field — what is still typed is saved too', (t) async {
      final f = await _pump(t, Consumer(builder: (c, ref, _) => TextButton(key: const Key('open'), onPressed: () => showAssetEditor(c, ref), child: const Text('open'))));
      await _tap(t, 'open');
      await t.enterText(_k('asset_title'), 'Haldi still');
      await t.enterText(_k('asset_url'), 'https://d.test/h.jpg');
      await t.enterText(_k('asset_tags'), 'Haldi, Kerala Bride');
      await t.pump();
      expect(_chips(t), ['haldi']);
      await _tap(t, 'asset_save');
      expect(f.saved.single['tags'], ['haldi', 'kerala bride']);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));
  });

  group('the search the gallery sends', () {
    test('several values per filter, keywords all/any/left out, toggles, dates, sort, page', () {
      final s = const AssetSearch(q: ' bridal ', brand: 'kerala').toggle('media', 'video').toggle('media', 'image').toggleKeyword('bridal').toggleKeyword('reel').toggleKeyword('bts', exclude: true).copyWith(kwAny: true, finalOnly: true, untagged: true, from: '2026-11-01', to: '2026-11-30');
      expect(s.query(pageNo: 2), {
        'q': 'bridal',
        'media': ['video', 'image'],
        'kw': ['bridal', 'reel'],
        'kwMode': 'any',
        'notKw': ['bts'],
        'final': 1,
        'untagged': 1,
        'from': '2026-11-01',
        'to': '2026-11-30',
        'brand': 'kerala',
        'sort': 'relevance',
        'pageNo': 2,
        'limit': kGalleryPageSize,
      });
      expect(s.filterCount, 8, reason: 'two media, two keywords, one left out, final, untagged, dates');
      expect(const AssetSearch().query()['sort'], 'newest', reason: 'nothing typed: the newest first');
      expect(const AssetSearch(sort: 'relevance').effectiveSort, 'newest');
      expect(s.toggleKeyword('bts').keywords, ['bridal', 'reel', 'bts'], reason: 'wanting a left-out keyword stops leaving it out');
      expect(s.toggleKeyword('bts').notKeywords, isEmpty);
      expect(s.toggle('media', 'video').facet('media'), {'image'});
      expect(s.cleared(), const AssetSearch(q: ' bridal ', brand: 'kerala'));
    });

    test('equal searches are one provider key (the order a filter was ticked in does not matter)', () {
      final a = const AssetSearch().toggle('media', 'video').toggle('media', 'image');
      final b = const AssetSearch().toggle('media', 'image').toggle('media', 'video');
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a == a.toggleKeyword('x'), isFalse);
    });

    test('a list goes to the server as the same name repeated; the keyword tools post what they say', () async {
      final seen = <RequestOptions>[];
      final s = MarketingSocialsService(Dio()..httpClientAdapter = _Capture(seen));
      await s.searchAssets(const AssetSearch().toggle('media', 'video').toggle('media', 'image').toggleKeyword('kerala bride'));
      final q = seen.single.uri.query;
      expect(q, contains('media=video&media=image'));
      expect(q, contains('kw=kerala+bride'));
      await s.bulkKeywords(['a1', 'a2'], add: ['wedding'], remove: ['bts']);
      expect(seen.last.path, '/marketing/socials/assets/bulk-keywords');
      expect(seen.last.data, {'ids': ['a1', 'a2'], 'add': ['wedding'], 'remove': ['bts']});
      await s.renameKeyword('bride', 'bridal');
      expect(seen.last.path, '/marketing/socials/assets/keywords/rename');
      expect(seen.last.data, {'from': 'bride', 'to': 'bridal'});
    });

    test('a page reads the keyword list (or the older map), the facets, and what the search box was read as', () {
      final p = AssetPage.fromJson({
        'total': 3,
        'facets': {'tags': {'bridal': 2}, 'media': {'video': 1}, 'untagged': 4},
        'search': {'terms': ['bridal', '"kerala bride"'], 'exclude': ['party'], 'keywords': ['hero'], 'notKeywords': []},
      });
      expect(p.keywords.single.keyword, 'bridal');
      expect(p.facet('media'), {'video': 1});
      expect(p.untagged, 4);
      expect(p.searchRead, 'bridal · "kerala bride" · not party · keyword hero');
      expect(const BulkKeywordResult(updated: 2, unchanged: 1, skipped: [(title: 'X', reason: 'too many')]).summary('added'), 'Added on 2 assets · 1 already so · 1 left as it was: X (too many).');
    });
  });

  group('the gallery', () {
    testWidgets('filters take several values each, and add up; the numbers show; active filters are chips; Clear all', (t) async {
      final f = await _pump(t, const PortfolioGalleryTab());
      expect(find.descendant(of: _k('gl_media_video'), matching: find.text('3')), findsOneWidget);
      await _tap(t, 'gl_media_video');
      await _tap(t, 'gl_media_image');
      await _tap(t, 'gl_portfolio_Kerala');
      await _tap(t, 'gl_owner_Anu');
      final s = f.searches.last.$1;
      expect(s.facet('media'), {'video', 'image'});
      expect(s.facet('portfolio'), {'Kerala'});
      expect(s.facet('owner'), {'Anu'});
      expect(_k('gl_active_media_video'), findsOneWidget);
      expect(find.text('Clear all (4)'), findsOneWidget);
      await _tap(t, 'gl_clear_all');
      expect(f.searches.last.$1.filterCount, 0);
    });

    testWidgets('keywords: tick, leave out, all/any, find any keyword, no keywords yet', (t) async {
      final f = await _pump(t, const PortfolioGalleryTab());
      await _tap(t, 'gl_tag_bridal');
      await _tap(t, 'gl_tag_reel');
      expect(f.searches.last.$1.keywords, ['bridal', 'reel']);
      expect(f.searches.last.$1.kwAny, isFalse, reason: 'all of them, to begin with');
      await _tap(t, 'gl_kwmode_any');
      expect(f.searches.last.$1.kwAny, isTrue);
      await _tap(t, 'gl_tagx_bride');
      expect(f.searches.last.$1.notKeywords, ['bride']);
      expect(_k('gl_kw_off_bride'), findsOneWidget);
      await t.enterText(_k('gl_kw_find'), 'kerala');
      await t.pump(const Duration(milliseconds: 300));
      await t.pumpAndSettle();
      await _tap(t, 'gl_kw_suggest_kerala bride');
      expect(f.searches.last.$1.keywords, ['bridal', 'reel', 'kerala bride']);
      await _tap(t, 'gl_untagged');
      expect(f.searches.last.$1.untagged, isTrue);
      expect(find.descendant(of: _k('gl_untagged'), matching: find.text('1')), findsOneWidget);
    });

    testWidgets('the search box: sent after a pause, read back in words, and sorted by Best match', (t) async {
      final f = await _pump(t, const PortfolioGalleryTab());
      await t.enterText(_k('gl_search'), '"kerala bride" -party');
      await t.pump(const Duration(milliseconds: 100));
      expect(f.searches.last.$1.q, '', reason: 'not on every key');
      await t.pump(const Duration(milliseconds: 400));
      await t.pumpAndSettle();
      expect(f.searches.last.$1.q, '"kerala bride" -party');
      expect(f.searches.last.$1.effectiveSort, 'relevance');
      expect(find.text('Searching for: "kerala bride" · not party'), findsOneWidget);
      expect(find.text('Sort: Best match'), findsOneWidget);
      expect(find.text('Clear the search'), findsNothing);
      await _tap(t, 'gl_search_clear');
      expect(f.searches.last.$1.q, '');
      expect(find.text('Sort: Newest'), findsOneWidget);
    });

    testWidgets('a keyword on a card filters by it', (t) async {
      final f = await _pump(t, const PortfolioGalleryTab());
      expect(_k('asset_kw_a1_hero'), findsNothing, reason: 'a card shows its first three keywords, then "+1"');
      expect(find.descendant(of: _k('asset_a1'), matching: find.text('+1')), findsOneWidget);
      await _tap(t, 'asset_kw_a1_reel');
      expect(f.searches.last.$1.keywords, ['reel']);
      expect(_k('gl_active_kw_reel'), findsOneWidget);
    });

    testWidgets('pages: "Show more" brings the next page under the first', (t) async {
      final f = await _pump(t, const PortfolioGalleryTab());
      expect(find.text('Showing 3 of 5'), findsOneWidget);
      expect(find.text('5 of 9 match'), findsOneWidget);
      await _tap(t, 'gl_more');
      expect(f.searches.last.$2, 2);
      expect(_k('asset_a4'), findsOneWidget);
      expect(_k('asset_a1'), findsOneWidget);
      expect(find.text('Showing 5 of 5'), findsOneWidget);
      expect(_k('gl_more'), findsNothing);
    });

    testWidgets('choose assets, then add keywords to all of them; the result is said, including what was left as it was', (t) async {
      final f = await _pump(t, const PortfolioGalleryTab());
      await _tap(t, 'gl_select');
      await t.tap(find.descendant(of: _k('asset_a1'), matching: _k('asset_thumb')));
      await t.tap(find.descendant(of: _k('asset_a3'), matching: _k('asset_thumb')));
      await t.pumpAndSettle();
      expect(find.text('2 chosen'), findsOneWidget);
      expect(_k('viewer_close'), findsNothing, reason: 'choosing does not open the asset');
      await _tap(t, 'gl_bulk_add');
      await t.enterText(_k('bulk_kw_input'), 'Wedding, #Haldi');
      await t.pump();
      await _tap(t, 'bulk_apply');
      expect(f.bulk.single.ids, ['a1', 'a3']);
      expect(f.bulk.single.add, ['wedding', 'haldi']);
      expect(find.textContaining('Added on 1 asset'), findsOneWidget);
      expect(find.textContaining('Full of keywords (It would carry 52 keywords; the most is 50.)'), findsOneWidget);
    });

    testWidgets('remove keywords from the chosen: the keywords they carry are offered, with how many of them carry each', (t) async {
      final f = await _pump(t, const PortfolioGalleryTab());
      await _tap(t, 'gl_select');
      await _tap(t, 'gl_pick_all');
      await _tap(t, 'gl_bulk_remove');
      expect(find.text('bridal  2/3'), findsOneWidget);
      await _tap(t, 'bulk_apply');
      expect(find.text('Tick the keywords to take off.'), findsOneWidget);
      await _tap(t, 'bulk_drop_bridal');
      await _tap(t, 'bulk_apply');
      expect(f.bulk.single.remove, ['bridal']);
      expect(f.bulk.single.ids, ['a1', 'a2', 'a3']);
    });

    testWidgets('Manage keywords: a member sees the list and can filter by one, but not rename or remove', (t) async {
      final f = await _pump(t, const PortfolioGalleryTab());
      await _tap(t, 'gl_kw_manage');
      expect(_k('kwm_row_bride'), findsOneWidget);
      expect(_k('kwm_rename_bride'), findsNothing);
      expect(find.textContaining('A Marketing Manager can rename'), findsOneWidget);
      await _tap(t, 'kwm_row_bride');
      expect(f.searches.last.$1.keywords, ['bride']);
    });

    testWidgets('Manage keywords: a manager renames "bride" into "bridal" — said to be a merge first — and removes one', (t) async {
      final f = await _pump(t, const PortfolioGalleryTab(), fake: _Fake(canManage: true));
      await _tap(t, 'gl_kw_manage');
      await _tap(t, 'kwm_rename_bride');
      await t.enterText(_k('kwm_rename_field'), 'Bridal');
      await _tap(t, 'kwm_rename_ok');
      expect(find.text('Merge the keywords?'), findsOneWidget);
      expect(f.renamed, isEmpty, reason: 'not before it is confirmed');
      await _tap(t, 'kwm_merge_ok');
      expect(f.renamed.single, ('bride', 'Bridal'));
      expect(find.text('"bride" merged into "bridal" on 2 assets.'), findsOneWidget);
      await _tap(t, 'kwm_remove_reel');
      await _tap(t, 'kwm_remove_ok');
      expect(f.removed, ['reel']);
    });

    testWidgets('a phone: the filters open in a sheet, apply at once, and the button counts them; nothing overflows', (t) async {
      final f = await _pump(t, const PortfolioGalleryTab(), size: const Size(390, 2400));
      expect(t.takeException(), isNull);
      expect(_k('gl_media_video'), findsNothing, reason: 'no side column on a phone');
      await _tap(t, 'gl_filters_btn');
      await _tap(t, 'gl_media_video');
      expect(f.searches.last.$1.facet('media'), {'video'});
      await _tap(t, 'gl_filters_done');
      expect(find.text('Filters (1)'), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  });
}
