import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:nizan_crm/core/theme/app_theme.dart';
import 'package:nizan_crm/features/marketing/data/portfolio_models.dart';
import 'package:nizan_crm/features/marketing/data/asset_search.dart';
import 'package:nizan_crm/features/marketing/data/socials_models.dart';
import 'package:nizan_crm/features/marketing/data/team_models.dart';
import 'package:nizan_crm/features/marketing/presentation/socials/asset_editor.dart';
import 'package:nizan_crm/features/marketing/presentation/socials/post_editor.dart';
import 'package:nizan_crm/features/marketing/presentation/socials/socials_assets_tab.dart';
import 'package:nizan_crm/features/marketing/presentation/socials/socials_overview_tab.dart';
import 'package:nizan_crm/features/marketing/presentation/socials/socials_performance_tab.dart';
import 'package:nizan_crm/features/marketing/presentation/socials/socials_publishing_tab.dart';
import 'package:nizan_crm/features/marketing/presentation/socials/socials_reports_tab.dart';
import 'package:nizan_crm/features/marketing/services/portfolio_service.dart';
import 'package:nizan_crm/features/marketing/services/socials_service.dart';
import 'package:nizan_crm/features/marketing/services/team_service.dart';
import 'package:nizan_crm/features/marketing/presentation/media/media_stream.dart';

// The Socials fixes after the audit: posts are made from approved assets (and belong to their shoot), the asset library filters by
// owner and by the days assets were added and shows as a grid or a list, an asset picks its shoot (which decides its brand), the
// Performance export, the Reports' next actions and per-platform growth, Publishing in the shared dates, and a member's own activities.

Map<String, dynamic> _asset(String id, {String title = 'Final reel', String stage = 'approved', bool isFinal = false, String? shootId, String owner = 'Preethi', String brand = 'main'}) => {
      'id': id, 'title': title, 'brand': brand, 'kind': 'reel', 'media': 'video', 'stage': stage, 'url': 'https://d.test/$id', 'thumbUrl': 'https://d.test/$id.jpg', 'portfolio': 'Main (Company)', 'page': 'Bridal Makeup',
      'tags': ['bridal'], 'durationSec': 30, 'sizeMb': 0, 'shootId': shootId, 'isFinal': isFinal, 'ownerName': owner, 'owner': owner, 'createdAt': '2026-11-10T05:00:00.000Z',
    };

Map<String, dynamic> _post(String id, {String? assetId, String? shootId, String status = 'scheduled'}) => {
      'id': id, 'title': 'Bridal reveal', 'platform': 'pinterest', 'contentType': 'reel', 'status': status, 'brand': 'main', 'scheduledDate': '2026-11-12T05:30:00.000Z', 'publishedDate': null,
      'thumbUrl': '', 'permalink': '', 'assignedToName': '', 'caption': '', 'campaign': '', 'metrics': {}, 'views': 0, 'assetId': assetId, 'shootId': shootId,
    };

class _FakeSocials extends MarketingSocialsService {
  _FakeSocials() : super(Dio());
  final queries = <AssetQuery>[];
  final savedPosts = <({Map<String, dynamic> body, String? id})>[];
  final savedAssets = <({Map<String, dynamic> body, String? id})>[];
  final publishingFilters = <TeamFilter>[];
  Map<String, dynamic> overviewJson = {'teamScope': 'own', 'teamDay': '2026-11-12', 'teamActivities': [{'memberId': 'm1', 'name': 'Preethi', 'activities': ['Story edit'], 'status': 'completed'}]};

  final searches = <AssetSearch>[];

  Map<String, dynamic> _library(bool usable) {
    final items = usable ? [_asset('a1', shootId: 's1')] : [_asset('a1', shootId: 's1'), _asset('a2', title: 'Raw clip', stage: 'raw', owner: 'staff')];
    return {
      'items': items,
      'total': items.length,
      'counts': {'total': items.length, 'photos': 0, 'videos': items.length, 'finals': 0, 'approved': 1},
      'facets': {'portfolios': {}, 'pages': {}, 'stages': {'approved': 1, 'raw': 1}, 'media': {'video': 2}, 'kinds': {}, 'tags': {'bridal': 2}, 'owners': {'Preethi': 1, 'staff': 1}},
    };
  }

  @override
  Future<AssetPage> searchAssets(AssetSearch s, {int pageNo = 1, int limit = kGalleryPageSize}) async {
    searches.add(s);
    return AssetPage.fromJson(_library(s.usable));
  }

  @override
  Future<AssetList> assets(AssetQuery q) async {
    queries.add(q);
    return AssetList.fromJson(_library(q.usable));
  }

  @override
  Future<Asset> asset(String id) async => Asset.fromJson(_asset(id, title: 'Linked asset $id'));

  @override
  Future<void> savePost(Map<String, dynamic> body, {String? id}) async => savedPosts.add((body: body, id: id));

  @override
  Future<Asset> saveAsset(Map<String, dynamic> body, {String? id}) async {
    savedAssets.add((body: body, id: id));
    return Asset.fromJson({'id': id ?? 'n', 'title': 'x'});
  }

  @override
  Future<SocialsOverview> overview(TeamFilter f) async => SocialsOverview.fromJson(overviewJson);

  @override
  Future<PublishingData> publishing(TeamFilter f) async {
    publishingFilters.add(f);
    return PublishingData.fromJson({'accounts': [], 'queue': [], 'recent': []});
  }

  @override
  Future<SocialsPerformance> performance(TeamFilter f, {String platform = 'all'}) async => SocialsPerformance.fromJson({
        'totals': {'reach': 1800, 'impressions': 2400, 'engagements': 125, 'engagementRate': 6.9, 'videoViews': 2200, 'linkClicks': 0, 'change': {'reach': 350, 'impressions': null}},
        'trend': [{'day': '2026-11-10', 'reach': 1800, 'impressions': 2400}],
        'platforms': [{'platform': 'instagram', 'label': 'Instagram', 'posts': 3, 'reach': 1800, 'impressions': 2400, 'engagements': 125, 'er': 6.9, 'change': {'posts': 200, 'reach': 350, 'engagements': -10}}],
        'top': [],
        'contentStatus': {'total': 0, 'stages': []},
      });

  @override
  Future<SocialsReports> reports(TeamFilter f) async => SocialsReports.fromJson({
        'from': '2026-11-09', 'to': '2026-11-15',
        'summary': {'overallGrowth': 10, 'reach': {'value': 1800, 'change': 350}, 'impressions': {'value': 0}, 'engagements': {'value': 0}, 'followers': {'value': 0}},
        'growthTrend': [],
        'insights': [],
        'nextActions': ['Publish or reschedule the 2 posts past their scheduled day.', 'Reels are earning 3× the engagement of static posts — plan more reels.'],
        'platforms': [{'platform': 'youtube', 'label': 'YouTube', 'posts': 1, 'reach': 500, 'impressions': 0, 'engagements': 0, 'er': null, 'change': {'posts': 0, 'reach': -50, 'engagements': null}}],
        'top': [],
        'kpis': {},
      });
}

class _FakePortfolio extends MarketingPortfolioService {
  _FakePortfolio() : super(Dio());
  @override
  Future<List<ShootOption>> shootOptions({String q = ''}) async => [
        ShootOption.fromJson(const {'id': 's1', 'title': 'Bridal Transformation', 'brand': 'main', 'shootDate': '2026-11-10', 'status': 'completed'}),
        ShootOption.fromJson(const {'id': 's2', 'title': 'Kerala Mehendi', 'brand': 'kerala', 'shootDate': '2026-11-11', 'status': 'planned'}),
      ];
  @override
  Future<ShootDetail> shoot(String id) async => ShootDetail.fromJson({'id': id, 'title': 'Shoot $id', 'shootDate': '2026-11-10', 'status': 'planned'});
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

/// A screen with a button that runs [open] (an editor), inside the fakes.
Future<({_FakeSocials s, _FakePortfolio p})> _pump(WidgetTester tester, Widget Function(WidgetRef ref) body, {Size size = const Size(1280, 1500)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final s = _FakeSocials();
  final p = _FakePortfolio();
  final overrides = <Override>[marketingSocialsServiceProvider.overrideWithValue(s), marketingPortfolioServiceProvider.overrideWithValue(p), marketingTeamServiceProvider.overrideWithValue(_NoTeam()), mediaStreamServiceProvider.overrideWithValue(NoMediaStream())];
  await tester.pumpWidget(ProviderScope(overrides: overrides, child: MaterialApp(theme: AppTheme.lightTheme, home: Scaffold(body: Consumer(builder: (context, ref, _) => body(ref))))));
  await tester.pumpAndSettle();
  return (s: s, p: p);
}

Widget _opener(WidgetRef ref, Future<void> Function(BuildContext context) open) => Builder(builder: (context) => Center(child: TextButton(key: const Key('open'), onPressed: () => open(context), child: const Text('open'))));

Finder _k(String key) => find.byKey(Key(key));

void main() {
  group('how the new parts of the payloads read', () {
    test('a post carries its asset and shoot; an asset its owner and whether it can be posted', () {
      final p = SocialPost.fromJson(_post('p1', assetId: 'a1', shootId: 's1'));
      expect([p.assetId, p.shootId, p.platform], ['a1', 's1', 'pinterest']);
      expect(SocialPost.fromJson(_post('p2')).assetId, isNull);
      final a = Asset.fromJson(_asset('a1'));
      expect(a.owner, 'Preethi');
      expect(a.usable, isTrue);
      expect(Asset.fromJson(_asset('a2', stage: 'in_review')).usable, isFalse);
      expect(Asset.fromJson(_asset('a3', stage: 'in_edit', isFinal: true)).usable, isTrue, reason: 'a final output can be posted');
      expect(a.createdAt, isNotNull);
    });

    test('facets: tags and owners; a platform row its growth; reports the next actions; the overview whose work it shows', () {
      final l = AssetList.fromJson({'facets': {'tags': {'bridal': 3}, 'owners': {'Preethi': 2}}});
      expect(l.tags, {'bridal': 3});
      expect(l.owners, {'Preethi': 2});
      final row = PlatformPerf.fromJson({'platform': 'instagram', 'label': 'Instagram', 'change': {'reach': 12, 'posts': null}});
      expect(row.change['reach'], 12);
      expect(row.change['posts'], isNull, reason: 'nothing before → no figure, never 0');
      expect(SocialsReports.fromJson({'nextActions': ['Do this']}).nextActions, ['Do this']);
      expect(SocialsOverview.fromJson({'teamScope': 'own'}).teamScope, 'own');
      expect(SocialsOverview.fromJson(const {}).teamScope, 'team');
    });

    test('the asset query sends the owner, the tag, the dates (both or neither) and "usable"', () {
      expect(const AssetQuery(owner: 'Preethi', tag: 'bridal', usable: true, from: '2026-11-01', to: '2026-11-30').query, {'tag': 'bridal', 'owner': 'Preethi', 'from': '2026-11-01', 'to': '2026-11-30', 'usable': 1});
      expect(const AssetQuery(from: '2026-11-01').query.containsKey('from'), isFalse, reason: 'one date alone is not sent');
      expect(const AssetQuery(owner: 'a') == const AssetQuery(owner: 'a'), isTrue);
      expect(const AssetQuery(from: '2026-11-01', to: '2026-11-02') == const AssetQuery(), isFalse);
      expect(const AssetQuery().copyWith(owner: 'x', tag: 'y').query, {'tag': 'y', 'owner': 'x'});
    });
  });

  group('the post form: made from an approved asset, belongs to its shoot', () {
    testWidgets('the asset picker lists only approved or final assets; picking one sends it and locks the shoot to the asset\'s', (tester) async {
      final f = await _pump(tester, (ref) => _opener(ref, (c) => showPostEditor(c, ref)));
      await tester.tap(_k('open'));
      await tester.pumpAndSettle();
      await tester.enterText(_k('post_title'), 'From the shoot');
      await tester.ensureVisible(_k('post_asset'));
      await tester.tap(_k('post_asset'));
      await tester.pumpAndSettle();
      expect(f.s.queries.last.usable, isTrue, reason: 'the picker asks the server for usable assets only');
      expect(_k('pick_asset_a2'), findsNothing, reason: 'a raw clip is never offered');
      await tester.tap(_k('pick_asset_a1'));
      await tester.pumpAndSettle();
      expect(find.text('Final reel'), findsOneWidget);
      expect(find.text('The asset\'s shoot.'), findsOneWidget, reason: 'the shoot follows the asset');
      expect(find.text('Shoot s1 · 10 Nov'), findsOneWidget, reason: 'the asset\'s shoot is named');
      expect(tester.widget<TextField>(_k('post_thumb')).controller!.text, 'https://d.test/a1.jpg', reason: 'an empty thumbnail takes the asset\'s');
      await tester.ensureVisible(_k('post_save'));
      await tester.tap(_k('post_save'));
      await tester.pumpAndSettle();
      final b = f.s.savedPosts.single.body;
      expect(b['assetId'], 'a1');
      expect(b.containsKey('shootId'), isFalse, reason: 'with an asset the server decides the shoot');
    });

    testWidgets('without an asset a post can name the shoot it is for; clearing sends nothing linked', (tester) async {
      final f = await _pump(tester, (ref) => _opener(ref, (c) => showPostEditor(c, ref)));
      await tester.tap(_k('open'));
      await tester.pumpAndSettle();
      await tester.enterText(_k('post_title'), 'Planned for a shoot');
      await tester.ensureVisible(_k('post_shoot'));
      await tester.tap(_k('post_shoot'));
      await tester.pumpAndSettle();
      await tester.tap(_k('pick_shoot_s2'));
      await tester.pumpAndSettle();
      expect(find.text('Kerala Mehendi · 11 Nov'), findsOneWidget);
      await tester.ensureVisible(_k('post_save'));
      await tester.tap(_k('post_save'));
      await tester.pumpAndSettle();
      expect(f.s.savedPosts.single.body['assetId'], isNull);
      expect(f.s.savedPosts.single.body['shootId'], 's2');
    });

    testWidgets('editing a post shows the asset it is made from (read from the server)', (tester) async {
      await _pump(tester, (ref) => _opener(ref, (c) => showPostEditor(c, ref, post: SocialPost.fromJson(_post('p1', assetId: 'a9', shootId: 's1')))));
      await tester.tap(_k('open'));
      await tester.pumpAndSettle();
      expect(find.text('Linked asset a9'), findsOneWidget);
      expect(find.text('Shoot s1 · 10 Nov'), findsOneWidget);
    });

    testWidgets('a post whose figures come from Instagram says so (and which ones a sync replaces); a typed one does not', (tester) async {
      final synced = SocialPost.fromJson({..._post('p1'), 'metricsSource': 'instagram', 'metricsSyncedAt': '2026-11-18T08:40:00.000Z'});
      expect(synced.fromInstagram, isTrue);
      await _pump(tester, (ref) => _opener(ref, (c) => showPostEditor(c, ref, post: synced)));
      await tester.tap(_k('open'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('post_metrics_from_instagram')), findsOneWidget);
      expect(find.textContaining('Impressions, reposts and link clicks stay as typed'), findsOneWidget);
    });

    testWidgets('a post with typed figures has no Instagram note', (tester) async {
      await _pump(tester, (ref) => _opener(ref, (c) => showPostEditor(c, ref, post: SocialPost.fromJson(_post('p1')))));
      await tester.tap(_k('open'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('post_metrics_from_instagram')), findsNothing);
    });
  });

  group('the asset form: the shoot decides its brand and portfolio', () {
    testWidgets('picking a Kerala shoot sets and locks the brand and portfolio; the shoot and owner are sent', (tester) async {
      final f = await _pump(tester, (ref) => _opener(ref, (c) => showAssetEditor(c, ref, brand: 'main')));
      await tester.tap(_k('open'));
      await tester.pumpAndSettle();
      await tester.enterText(_k('asset_title'), 'Mehendi still');
      await tester.enterText(_k('asset_url'), 'https://d.test/m.jpg');
      await tester.tap(_k('asset_shoot'));
      await tester.pumpAndSettle();
      await tester.tap(_k('pick_shoot_s2'));
      await tester.pumpAndSettle();
      expect(find.text('Brand (from the shoot)'), findsOneWidget);
      expect(tester.widget<TextField>(_k('asset_portfolio')).enabled, isFalse);
      expect(tester.widget<TextField>(_k('asset_portfolio')).controller!.text, 'Kerala');
      await tester.ensureVisible(_k('asset_owner'));
      await tester.enterText(_k('asset_owner'), 'Ashique');
      await tester.tap(_k('asset_save'));
      await tester.pumpAndSettle();
      final b = f.s.savedAssets.single.body;
      expect([b['shootId'], b['brand'], b['portfolio'], b['ownerName']], ['s2', 'kerala', 'Kerala', 'Ashique']);
    });

    testWidgets('an asset added from a shoot names that shoot; clearing it frees the brand', (tester) async {
      final f = await _pump(tester, (ref) => _opener(ref, (c) => showAssetEditor(c, ref, shootId: 's1', brand: 'main')));
      await tester.tap(_k('open'));
      await tester.pumpAndSettle();
      expect(find.text('Shoot s1 · 10 Nov'), findsOneWidget);
      await tester.tap(find.descendant(of: _k('asset_shoot'), matching: find.byIcon(Icons.close_rounded)));
      await tester.pumpAndSettle();
      expect(find.text('Brand'), findsOneWidget);
      await tester.enterText(_k('asset_title'), 'Loose still');
      await tester.enterText(_k('asset_url'), 'https://d.test/l.jpg');
      await tester.tap(_k('asset_save'));
      await tester.pumpAndSettle();
      expect(f.s.savedAssets.single.body['shootId'], isNull);
    });
  });

  group('Content & Assets: owner, dates, grid or list', () {
    testWidgets('the owner filter and "added in these days" are asked of the server; the list view shows rows', (tester) async {
      final f = await _pump(tester, (ref) => const SocialsAssetsTab());
      await tester.ensureVisible(_k('gl_owner_staff'));
      await tester.tap(_k('gl_owner_staff'));
      await tester.pumpAndSettle();
      expect(f.s.searches.last.facet('owner'), {'staff'});
      expect(f.s.searches.last.from, isNull, reason: 'any time by default — the library is a library');
      await tester.ensureVisible(_k('gl_added'));
      await tester.tap(_k('gl_added'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining(RegExp(r'^\d+ \w+ – ')).last);
      await tester.pumpAndSettle();
      final week = TeamFilter.thisWeek();
      expect([f.s.searches.last.from, f.s.searches.last.to], [week.fromDay, week.toDay]);
      expect(f.s.searches.last.facet('owner'), {'staff'}, reason: 'filters add up');
      expect(_k('asset_rows'), findsNothing);
      await tester.tap(_k('asset_layout_list'));
      await tester.pumpAndSettle();
      expect(_k('asset_rows'), findsOneWidget);
      expect(_k('asset_row_a1'), findsOneWidget);
      expect(find.descendant(of: _k('asset_row_a1'), matching: find.textContaining('Preethi')), findsOneWidget, reason: 'the row names the owner');
    });
  });

  group('Performance and Reports', () {
    testWidgets('Performance has an Export CSV button and a growth column per platform', (tester) async {
      await _pump(tester, (ref) => const SocialsPerformanceTab());
      expect(_k('soc_perf_export'), findsOneWidget);
      expect(tester.widget<Text>(_k('soc_perf_growth_instagram')).data, '+350%');
    });

    test('the Performance CSV holds the totals with their change, the platforms with growth, the days — unknown figures empty', () {
      final p = SocialsPerformance.fromJson({
        'totals': {'reach': 1800, 'impressions': 2400, 'engagements': 125, 'engagementRate': null, 'videoViews': 0, 'linkClicks': 0, 'change': {'reach': 350}},
        'trend': [{'day': '2026-11-10', 'reach': 1800, 'impressions': 2400}],
        'platforms': [{'platform': 'pinterest', 'label': 'Pinterest', 'posts': 1, 'reach': 50, 'impressions': 0, 'engagements': 0, 'er': null, 'change': {'posts': null, 'reach': 25}}],
        'top': [{'id': 't1', 'title': 'Best', 'platform': 'pinterest', 'contentType': 'reel', 'views': 9, 'engagements': 1, 'permalink': 'https://x.test'}],
      });
      final rows = performanceCsvRows(p, from: '2026-11-09', to: '2026-11-15', platform: 'pinterest');
      expect(rows.first, ['Socials performance', '2026-11-09', '2026-11-15', 'Pinterest']);
      expect(rows.firstWhere((r) => r.isNotEmpty && r.first == 'Reach'), ['Reach', 1800, '350']);
      expect(rows.firstWhere((r) => r.isNotEmpty && r.first == 'Impressions'), ['Impressions', 2400, ''], reason: 'no change known → empty, not 0');
      expect(rows.firstWhere((r) => r.isNotEmpty && r.first == 'Engagement rate (%)')[1], '');
      expect(rows.firstWhere((r) => r.isNotEmpty && r.first == 'Pinterest'), ['Pinterest', 1, 50, 0, 0, '', '', '25', '']);
      expect(rows.firstWhere((r) => r.isNotEmpty && r.first == 'Best'), ['Best', 'Pinterest', 'Reel', 9, 1, 'https://x.test']);
      expect(rows.last, ['2026-11-10', 1800, 2400]);
      expect(growthText(null), '—');
      expect(growthText(-8), '−8%');
    });

    testWidgets('Reports shows the next actions, numbered, and each platform\'s reach growth', (tester) async {
      await _pump(tester, (ref) => const SocialsReportsTab());
      expect(_k('soc_report_next'), findsOneWidget);
      expect(find.text('Publish or reschedule the 2 posts past their scheduled day.'), findsOneWidget);
      expect(find.descendant(of: _k('soc_report_next'), matching: find.text('2')), findsOneWidget);
      await tester.tap(_k('soc_report_content'));
      await tester.pumpAndSettle();
      expect(find.descendant(of: _k('soc_report_platform_youtube'), matching: find.text('−50%')), findsOneWidget);
    });

    test('the Reports CSV ends with the next actions and carries each platform\'s growth', () {
      final r = SocialsReports.fromJson({'from': '2026-11-09', 'to': '2026-11-15', 'nextActions': ['Plan the next posts.'], 'platforms': [{'platform': 'youtube', 'label': 'YouTube', 'posts': 1, 'reach': 5, 'change': {'reach': -50}}]});
      final rows = reportsCsvRows(r);
      expect(rows.last, ['Plan the next posts.']);
      expect(rows[rows.length - 2], ['Next actions']);
      expect(rows.firstWhere((x) => x.isNotEmpty && x.first == 'YouTube'), ['YouTube', 1, 5, 0, 0, '', '', '-50', '']);
    });
  });

  group('Publishing and the overview', () {
    testWidgets('Publishing reads the shared dates and says so on both lists', (tester) async {
      final f = await _pump(tester, (ref) => const SocialsPublishingTab());
      expect(f.s.publishingFilters.single, TeamFilter.thisWeek());
      expect(find.textContaining('Scheduled '), findsOneWidget);
      expect(find.text('Nothing was published in these days.'), findsOneWidget);
    });

    testWidgets('a member\'s overview shows only their own activities, and says so', (tester) async {
      await _pump(tester, (ref) => SocialsOverviewTab(onGo: (_) {}), size: const Size(1280, 3000));
      expect(find.text('Your Activities (Socials)'), findsOneWidget);
      expect(find.textContaining('only your own work is shown'), findsOneWidget);
      expect(_k('soc_team_m1'), findsOneWidget);
    });
  });

  group('what the service asks the server for', () {
    test('one asset by its id; publishing with the dates', () async {
      final seen = <RequestOptions>[];
      final s = MarketingSocialsService(Dio()..httpClientAdapter = _Capture(seen));
      await s.asset('a1').catchError((_) => const Asset(id: '', title: ''));
      await s.publishing(TeamFilter(from: DateTime(2026, 11, 2), to: DateTime(2026, 11, 8)));
      expect(seen.map((r) => r.path), ['/marketing/socials/assets/a1', '/marketing/socials/publishing']);
      expect(seen[1].queryParameters, {'from': '2026-11-02', 'to': '2026-11-08'});
    });
  });
}
