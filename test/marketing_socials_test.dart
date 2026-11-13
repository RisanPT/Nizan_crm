import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:nizan_crm/core/theme/app_theme.dart';
import 'package:nizan_crm/features/marketing/data/socials_models.dart';
import 'package:nizan_crm/features/marketing/data/team_models.dart';
import 'package:nizan_crm/features/marketing/presentation/kit/mkt_kit.dart';
import 'package:nizan_crm/features/marketing/presentation/socials/socials_screen.dart';
import 'package:nizan_crm/features/marketing/presentation/socials/socials_widgets.dart';
import 'package:nizan_crm/features/marketing/services/socials_service.dart';
import 'package:nizan_crm/features/marketing/services/team_service.dart';

// The Socials module: Overview, Content Calendar, Content & Assets, Publishing & Accounts, Performance, Reports & Insights.

Map<String, dynamic> _post(String id, {String title = 'Bridal Look Reveal', String status = 'published', String type = 'reel', String platform = 'instagram', String brand = 'main', String day = '2026-11-10', int views = 0, Map<String, dynamic>? metrics}) => {
      'id': id, 'title': title, 'platform': platform, 'contentType': type, 'status': status, 'brand': brand,
      'scheduledDate': '${day}T05:30:00.000Z', 'publishedDate': status == 'published' ? '${day}T05:30:00.000Z' : null,
      'thumbUrl': '', 'permalink': '', 'assignedToName': '', 'caption': 'cap', 'campaign': '', 'metrics': metrics ?? {'reach': 1000}, 'views': views,
    };

Map<String, dynamic> _overview({bool metrics = true}) => {
      'from': '2026-11-09', 'to': '2026-11-15', 'brand': 'all',
      'kpis': {'total': 53, 'reels': 27, 'trialReels': 6, 'stories': 14, 'feed': 5, 'collab': 1, 'other': 0, 'change': {'total': 12, 'reels': 17, 'trialReels': 0, 'stories': null, 'feed': -8, 'collab': 5}},
      'pipeline': {'total': 64, 'stages': [
        {'key': 'planned', 'label': 'Planned', 'count': 6, 'pct': 9}, {'key': 'producing', 'label': 'In Production', 'count': 4, 'pct': 6},
        {'key': 'in_review', 'label': 'In Review', 'count': 2, 'pct': 3}, {'key': 'scheduled', 'label': 'Scheduled', 'count': 12, 'pct': 19}, {'key': 'published', 'label': 'Published', 'count': 40, 'pct': 63},
      ]},
      'platforms': [
        {'platform': 'instagram', 'brand': 'main', 'label': 'Instagram (Main)', 'count': 32, 'spark': [1, 2, 3, 2, 4, 3, 5], 'change': 14},
        {'platform': 'instagram', 'brand': 'kerala', 'label': 'Instagram (Kerala)', 'count': 2, 'spark': [0, 0, 1, 0, 0, 1, 0], 'change': null},
        {'platform': 'youtube', 'brand': 'main', 'label': 'YouTube', 'count': 3, 'spark': [0, 0, 0, 0, 0, 0, 0], 'change': 0},
      ],
      'tracker': {'hasMetrics': metrics, 'rows': metrics ? [
        {'metricId': 'mt1', 'name': 'Reels posted', 'target': 26, 'completed': 27, 'progress': 104},
        {'metricId': 'mt2', 'name': 'Stories posted', 'target': null, 'completed': 14, 'progress': null},
      ] : []},
      'calendar': [for (var i = 0; i < 7; i++) {'day': '2026-11-${(9 + i).toString().padLeft(2, '0')}', 'items': i == 1 ? [_post('p1')] : []}],
      'weekFrom': '2026-11-09',
      'teamActivities': [{'memberId': 'm1', 'name': 'Preethi', 'activities': ['2 posts, 1 reel', 'caption and hashtag'], 'status': 'completed'}, {'memberId': 'm2', 'name': 'Abhiram', 'activities': ['Video edit'], 'status': 'in_progress'}],
      'teamDay': '2026-11-12',
      'engagement': {'reach': 468320, 'impressions': 1092450, 'views': 128460, 'likes': 27200, 'comments': 166, 'reposts': 100, 'shares': 3700, 'saves': 4500, 'linkClicks': 3420, 'engagements': 35666, 'engagementRate': 7.6, 'change': {'likes': 18, 'comments': 9, 'reposts': 0, 'shares': 16, 'saves': 22}, 'engagementsChange': 18},
      'recentPosts': [_post('p1', views: 312000), _post('p2', title: 'Hair styling', views: 148000)],
      'leads': {'total': 83, 'main': 69, 'kerala': 14, 'change': 12},
      'focus': [{'id': 'f1', 'title': 'Publish 12 planned contents', 'progress': 100, 'done': true}, {'id': 'f2', 'title': 'Plan next week', 'progress': 0, 'done': false}],
      'insights': [],
    };

Map<String, dynamic> _assets() => {
      'items': [
        {'id': 'a1', 'title': 'SkyBride_Exterior.mp4', 'brand': 'main', 'kind': 'reel', 'media': 'video', 'stage': 'approved', 'url': 'https://d.test/a', 'thumbUrl': '', 'portfolio': 'Main (Company)', 'page': 'Bridal Makeup', 'tags': ['bridal'], 'durationSec': 42, 'sizeMb': 0, 'shootId': null, 'isFinal': true, 'ownerName': ''},
        {'id': 'a2', 'title': 'Studio_Ambience.jpg', 'brand': 'main', 'kind': 'still', 'media': 'image', 'stage': 'in_review', 'url': 'https://d.test/b', 'thumbUrl': '', 'portfolio': 'Main (Company)', 'page': '', 'tags': [], 'durationSec': 0, 'sizeMb': 0, 'shootId': null, 'isFinal': false, 'ownerName': ''},
      ],
      'counts': {'total': 2, 'photos': 1, 'videos': 1, 'finals': 1, 'approved': 1, 'approvedPct': 50},
      'facets': {'portfolios': {'Main (Company)': 2}, 'pages': {'Bridal Makeup': 1}, 'stages': {'approved': 1, 'in_review': 1}, 'media': {'video': 1, 'image': 1}, 'kinds': {'reel': 1, 'still': 1}},
    };

class _FakeSocials extends MarketingSocialsService {
  _FakeSocials() : super(Dio());
  Map<String, dynamic> overviewJson = _overview();
  Map<String, dynamic> assetsJson = _assets();
  final filters = <TeamFilter>[];
  final calendars = <({String from, String to, String platform, String brand})>[];
  final assetQueries = <AssetQuery>[];
  final performancePlatforms = <String>[];
  final savedPosts = <({Map<String, dynamic> body, String? id})>[];
  final savedAssets = <({Map<String, dynamic> body, String? id})>[];
  final savedAccounts = <({Map<String, dynamic> body, String? id})>[];
  final savedTargets = <({String brand, String week, Map<String, double> values})>[];
  TeamRefusal? refuse;
  bool overviewFails = false;

  @override
  Future<SocialsOverview> overview(TeamFilter f) async {
    filters.add(f);
    if (overviewFails) throw Exception('boom');
    return SocialsOverview.fromJson(overviewJson);
  }

  @override
  Future<SocialsCalendar> calendar(TeamFilter f, {String platform = 'all'}) async {
    calendars.add((from: f.fromDay, to: f.toDay, platform: platform, brand: f.brand.wire));
    return SocialsCalendar.fromJson({'items': [_post('c1', title: 'Calendar reel', day: '2026-11-10'), _post('c2', title: 'Scheduled carousel', type: 'carousel', status: 'scheduled', day: '2026-11-12')], 'pipeline': overviewJson['pipeline']});
  }

  @override
  Future<AssetList> assets(AssetQuery q) async {
    assetQueries.add(q);
    final items = (assetsJson['items'] as List).cast<Map<String, dynamic>>().where((a) => q.q.isEmpty || (a['title'] as String).toLowerCase().contains(q.q.toLowerCase())).toList();
    return AssetList.fromJson({...assetsJson, 'items': items});
  }

  @override
  Future<PublishingData> publishing(TeamFilter f) async => PublishingData.fromJson({
        'accounts': [{'id': 'ac1', 'platform': 'instagram', 'brand': 'main', 'handle': '@teamn.bridal', 'status': 'manual', 'followers': 128400, 'note': ''}],
        'queue': [_post('q1', title: 'Amenity Tour', status: 'scheduled', day: '2026-11-14'), _post('q2', title: 'Family Living', status: 'in-review', day: '2026-11-15')],
        'recent': [_post('r1', title: 'Published one')],
      });

  @override
  Future<SocialsPerformance> performance(TeamFilter f, {String platform = 'all'}) async {
    performancePlatforms.add(platform);
    return SocialsPerformance.fromJson({
      'totals': {'reach': 468320, 'impressions': 1092450, 'engagements': 35666, 'engagementRate': 7.6, 'videoViews': 128460, 'linkClicks': 3420, 'change': {'reach': 16, 'impressions': 21, 'engagements': 18, 'videoViews': -4, 'linkClicks': null}},
      'trend': [for (var i = 0; i < 7; i++) {'day': '2026-11-${(9 + i).toString().padLeft(2, '0')}', 'reach': 1000 * (i + 1), 'impressions': 1500 * (i + 1)}],
      'platforms': [{'platform': 'instagram', 'label': 'Instagram', 'posts': 34, 'reach': 298450, 'impressions': 674210, 'engagements': 28100, 'er': 2.7}, {'platform': 'youtube', 'label': 'YouTube', 'posts': 3, 'reach': 32560, 'impressions': 104200, 'engagements': 420, 'er': null}],
      'top': [{'id': 't1', 'title': 'Family at SkyCity', 'platform': 'instagram', 'brand': 'main', 'contentType': 'reel', 'thumbUrl': '', 'permalink': '', 'views': 84200, 'engagements': 5000}],
      'contentStatus': overviewJson['pipeline'],
    });
  }

  @override
  Future<SocialsReports> reports(TeamFilter f) async => SocialsReports.fromJson({
        'from': '2026-11-09', 'to': '2026-11-15', 'brand': 'all',
        'summary': {'overallGrowth': 22, 'reach': {'value': 468320, 'change': 16}, 'impressions': {'value': 1092450, 'change': 21}, 'engagements': {'value': 12846, 'change': -3}, 'followers': {'value': 150000, 'change': null}},
        'growthTrend': [for (var i = 0; i < 6; i++) {'month': '2026-${(6 + i).toString().padLeft(2, '0')}', 'reach': 100000 * (i + 1), 'impressions': 200000, 'engagements': 5000, 'posts': 10 + i}],
        'insights': ['Reels earned 2.4× the engagement of static posts (6 reels, 4 static).'],
        'platforms': [{'platform': 'instagram', 'label': 'Instagram', 'posts': 34, 'reach': 298450, 'impressions': 674210, 'engagements': 28100, 'er': 2.7}],
        'top': [],
        'kpis': (overviewJson['kpis']),
      });

  @override
  Future<TargetsData> targets(TeamFilter f) async => TargetsData.fromJson({'week': '2026-11-09', 'metrics': [{'id': 'mt1', 'name': 'Reels posted', 'target': 26}, {'id': 'mt2', 'name': 'Stories posted', 'target': null}]});

  @override
  Future<void> saveTargets({required String brand, required String week, required Map<String, double> values}) async {
    if (refuse != null) throw refuse!;
    savedTargets.add((brand: brand, week: week, values: values));
  }

  @override
  Future<Asset> saveAsset(Map<String, dynamic> body, {String? id}) async {
    if (refuse != null) throw refuse!;
    savedAssets.add((body: body, id: id));
    return Asset.fromJson({'id': id ?? 'new', 'title': body['title'] ?? 'x', ...body});
  }

  @override
  Future<SocialAccount> saveAccount(Map<String, dynamic> body, {String? id}) async {
    if (refuse != null) throw refuse!;
    savedAccounts.add((body: body, id: id));
    return SocialAccount.fromJson({'id': 'n', ...body});
  }

  @override
  Future<void> savePost(Map<String, dynamic> body, {String? id}) async {
    if (refuse != null) throw refuse!;
    savedPosts.add((body: body, id: id));
  }
}

/// A Dio adapter that records what was asked and answers with an empty JSON object (or a chosen status and body).
class _Capture implements HttpClientAdapter {
  _Capture(this.seen, {this.status = 200, this.body = '{}'});
  final List<RequestOptions> seen;
  final int status;
  final String body;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<List<int>>? requestStream, Future<void>? cancelFuture) async {
    seen.add(options);
    return ResponseBody.fromString(body, status, headers: {Headers.contentTypeHeader: ['application/json']});
  }

  @override
  void close({bool force = false}) {}
}

/// The header's filter bar looks for the team (a manager's member list); in these tests there is none.
class _NoTeam extends MarketingTeamService {
  _NoTeam() : super(Dio());
  @override
  Future<LogSetup> logSetup({required String date, String? memberId}) async => throw Exception('no team in this test');
}

Future<_FakeSocials> _pump(WidgetTester tester, Widget screen, {_FakeSocials? fake, Size size = const Size(1280, 1500)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final f = fake ?? _FakeSocials();
  final overrides = <Override>[marketingSocialsServiceProvider.overrideWithValue(f), marketingTeamServiceProvider.overrideWithValue(_NoTeam())];
  await tester.pumpWidget(ProviderScope(overrides: overrides, child: MaterialApp(theme: AppTheme.lightTheme, home: Scaffold(body: screen))));
  await tester.pumpAndSettle();
  return f;
}

Finder _k(String key) => find.byKey(Key(key));
String _text(WidgetTester t, Finder f) => t.widget<Text>(f).data!;

Future<void> _openTab(WidgetTester tester, String id) async {
  await tester.tap(_k('soc_tab_$id'));
  await tester.pumpAndSettle();
}

void main() {
  group('how the payloads read', () {
    test('counts: compact (K, M) for tiles, exact with separators for the headline numbers', () {
      expect(compactCount(0), '0');
      expect(compactCount(999), '999');
      expect(compactCount(4500), '4.5K');
      expect(compactCount(27200), '27.2K');
      expect(compactCount(468320), '468.3K');
      expect(compactCount(999990), '1.00M', reason: 'never "1000.0K"');
      expect(compactCount(1092450), '1.09M');
      expect(compactCount(12500000), '12.5M');
      expect(groupedCount(468320), '468,320');
      expect(groupedCount(999), '999');
      expect(groupedCount(1092450), '1,092,450');
    });

    test('an overview reads every part, and a missing part is empty rather than a crash', () {
      final o = SocialsOverview.fromJson(_overview());
      expect(o.kpis.total, 53);
      expect(o.kpis.change['stories'], isNull);
      expect(o.pipeline.countOf('scheduled'), 12);
      expect(o.platforms.first.label, 'Instagram (Main)');
      expect(o.tracker.first.progress, 104);
      expect(o.leads.kerala, 14);
      final empty = SocialsOverview.fromJson(const {});
      expect(empty.kpis.total, 0);
      expect(empty.platforms, isEmpty);
      expect(empty.hasMetrics, isFalse);
    });

    test('a post status maps to its pipeline stage, and each stage has its own colour', () {
      expect({for (final st in ['idea', 'planned', 'in-progress', 'in-review', 'scheduled', 'published', 'cancelled']) st: stageKeyOf(st)}, {
        'idea': 'planned', 'planned': 'planned', 'in-progress': 'producing', 'in-review': 'in_review', 'scheduled': 'scheduled', 'published': 'published', 'cancelled': 'cancelled',
      });
      expect({for (final k in ['planned', 'producing', 'in_review', 'scheduled', 'published']) stageColor(k)}.length, 5, reason: 'five stages, five colours');
      expect(postStatusLabel('in-review'), 'In Review');
      expect(postFormatLabel('trial_reel'), 'Trial Reel');
    });

    test('an asset query is compared by its parts and sends only what is set', () {
      const a = AssetQuery(q: ' bridal ', stage: 'approved');
      expect(a.query, {'q': 'bridal', 'stage': 'approved'});
      expect(a == const AssetQuery(q: ' bridal ', stage: 'approved'), isTrue);
      expect(a.copyWith(stage: null).stage, isNull, reason: 'null clears a filter');
      expect(a.copyWith(brand: 'kerala').query['brand'], 'kerala');
      expect(const AssetQuery().query, isEmpty);
      expect(a == const AssetQuery(q: 'bridal', stage: 'in_review'), isFalse);
      expect(const AssetQuery(q: 'a') == const AssetQuery(q: 'b'), isFalse);
      expect(const AssetQuery(brand: 'kerala') == const AssetQuery(), isFalse);
      expect(const AssetQuery(q: 'a').hashCode == const AssetQuery(q: 'a').hashCode, isTrue);
    });
  });

  group('the Socials screen', () {
    testWidgets('has the six tabs the document draws, the breadcrumb title and the Create Content button', (tester) async {
      await _pump(tester, const SocialsScreen());
      for (final t in kSocialsTabs) {
        expect(_k('soc_tab_${t.$1}'), findsOneWidget, reason: t.$1);
      }
      expect(kSocialsTabs.map((t) => t.$1).toList(), ['overview', 'calendar', 'assets', 'publishing', 'performance', 'reports']);
      expect(find.textContaining('Socials  ›  '), findsOneWidget);
      expect(_k('soc_create_content'), findsOneWidget);
      await _openTab(tester, 'publishing');
      expect(find.text('Publishing & Accounts'), findsWidgets);
    });

    testWidgets('a tab can be opened from a link (?tab=…)', (tester) async {
      await _pump(tester, const SocialsScreen(initialTab: 'performance'));
      expect(_k('socials_performance_list'), findsOneWidget);
    });
  });

  group('Overview', () {
    testWidgets('the KPI strip shows the counts with their change on the period before', (tester) async {
      await _pump(tester, const SocialsScreen());
      expect(find.descendant(of: _k('soc_kpi_total'), matching: find.text('53')), findsOneWidget);
      expect(find.descendant(of: _k('soc_kpi_total'), matching: find.text('↑ +12% vs last week')), findsOneWidget);
      expect(find.descendant(of: _k('soc_kpi_reels'), matching: find.text('27')), findsOneWidget);
      expect(find.descendant(of: _k('soc_kpi_feed'), matching: find.text('↓ −8% vs last week')), findsOneWidget);
      expect(find.descendant(of: _k('soc_kpi_trial'), matching: find.text('No change')), findsOneWidget);
      expect(find.descendant(of: _k('soc_kpi_stories'), matching: find.textContaining('vs last week')), findsNothing, reason: 'no base to compare with → no change shown');
    });

    testWidgets('the pipeline, the workflow and the platform split hold the same counts', (tester) async {
      await _pump(tester, const SocialsScreen());
      expect(_text(tester, _k('soc_pipeline_total')), '64');
      expect(find.descendant(of: _k('soc_flow_scheduled'), matching: find.text('12')), findsOneWidget);
      expect(find.descendant(of: _k('soc_flow_published'), matching: find.text('40')), findsOneWidget);
      expect(find.descendant(of: _k('soc_flow_planned'), matching: find.text('6')), findsOneWidget);
      expect(find.descendant(of: _k('soc_platform_instagram_main'), matching: find.text('Instagram (Main)')), findsOneWidget);
      expect(find.descendant(of: _k('soc_platform_instagram_main'), matching: find.text('+14%')), findsOneWidget);
      expect(find.descendant(of: _k('soc_platform_instagram_kerala'), matching: find.text('Instagram (Kerala)')), findsOneWidget);
      expect(find.descendant(of: _k('soc_platform_youtube_main'), matching: find.text('0%')), findsOneWidget);
    });

    testWidgets('the activity tracker shows target, done and progress — and says "No target" when none is set', (tester) async {
      await _pump(tester, const SocialsScreen());
      final reels = _k('soc_tracker_mt1');
      expect(find.descendant(of: reels, matching: find.text('26')), findsOneWidget);
      expect(find.descendant(of: reels, matching: find.text('27')), findsOneWidget);
      expect(find.descendant(of: reels, matching: find.text('104%')), findsOneWidget);
      expect(find.descendant(of: _k('soc_tracker_mt2'), matching: find.text('No target')), findsOneWidget);
    });

    testWidgets('with no Socials activities set up the tracker says where to add them', (tester) async {
      await _pump(tester, const SocialsScreen(), fake: _FakeSocials()..overviewJson = _overview(metrics: false));
      expect(find.textContaining('No activities are set up under Socials yet'), findsWidgets);
    });

    testWidgets('team activities, engagement, recent posts, organic leads and the week\'s focus', (tester) async {
      await _pump(tester, const SocialsScreen());
      expect(find.descendant(of: _k('soc_team_m1'), matching: find.text('Completed')), findsOneWidget);
      expect(find.descendant(of: _k('soc_team_m2'), matching: find.text('In Progress')), findsOneWidget);
      expect(find.descendant(of: _k('soc_eng_likes'), matching: find.text('27.2K')), findsOneWidget);
      expect(find.descendant(of: _k('soc_eng_saves'), matching: find.text('4.5K')), findsOneWidget);
      expect(find.descendant(of: _k('soc_recent_p1'), matching: find.text('312.0K views')), findsOneWidget);
      expect(_text(tester, _k('soc_leads_total')), '83');
      expect(_text(tester, _k('soc_leads_main')), '69');
      expect(_text(tester, _k('soc_leads_kerala')), '14');
      expect(find.descendant(of: _k('soc_focus_f1'), matching: find.byIcon(Icons.check_box_rounded)), findsOneWidget);
      expect(find.descendant(of: _k('soc_focus_f2'), matching: find.byIcon(Icons.check_box_outline_blank_rounded)), findsOneWidget);
    });

    testWidgets('a failing source says so with Try again; the brand filter asks again for that brand', (tester) async {
      final down = _FakeSocials()..overviewFails = true;
      await _pump(tester, const SocialsScreen(), fake: down);
      expect(find.text('Try again'), findsOneWidget);
      final ok = await _pump(tester, const SocialsScreen());
      expect(ok.filters.last.brand, TeamBrand.all);
      await tester.tap(_k('team_brand_pill'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kerala').last);
      await tester.pumpAndSettle();
      expect(ok.filters.last.brand, TeamBrand.kerala);
    });

    testWidgets('the "View Calendar" link jumps to the calendar tab', (tester) async {
      await _pump(tester, const SocialsScreen());
      await tester.tap(_k('soc_calendar_link'));
      await tester.pumpAndSettle();
      expect(_k('socials_calendar_list'), findsOneWidget);
    });
  });

  group('Content Calendar', () {
    testWidgets('the month grid holds the posts; the list view is a table of the same posts', (tester) async {
      final f = await _pump(tester, const SocialsScreen(initialTab: 'calendar'));
      expect(f.calendars, isNotEmpty);
      expect(_k('soc_month_grid'), findsOneWidget);
      expect(_k('soc_post_c1'), findsWidgets);
      await tester.tap(_k('soc_cal_view_list'));
      await tester.pumpAndSettle();
      expect(_k('soc_list_table'), findsOneWidget);
      expect(find.text('Calendar reel'), findsWidgets);
      expect(find.text('Scheduled carousel'), findsWidgets);
    });

    testWidgets('next month asks the server for that month; the platform filter is sent', (tester) async {
      final f = await _pump(tester, const SocialsScreen(initialTab: 'calendar'));
      final before = f.calendars.length;
      final title = _text(tester, _k('soc_cal_title'));
      final now = DateTime.now();
      expect(title, DateFormat('MMMM yyyy').format(DateTime(now.year, now.month)));
      await tester.tap(_k('soc_cal_next'));
      await tester.pumpAndSettle();
      expect(_text(tester, _k('soc_cal_title')), DateFormat('MMMM yyyy').format(DateTime(now.year, now.month + 1)));
      expect(f.calendars.last.from.compareTo(f.calendars[before - 1].from), greaterThan(0), reason: 'the next window starts later');
      await tester.tap(_k('soc_cal_prev'));
      await tester.pumpAndSettle();
      expect(_text(tester, _k('soc_cal_title')), title);
      expect(f.calendars.length, greaterThan(before));
      await tester.tap(_k('soc_cal_platform'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('YouTube').last);
      await tester.pumpAndSettle();
      expect(f.calendars.last.platform, 'youtube');
    });

    testWidgets('a post opens its editor filled in; saving sends the change with the post\'s id', (tester) async {
      final f = await _pump(tester, const SocialsScreen(initialTab: 'calendar'));
      await tester.tap(_k('soc_post_c1').first);
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(_k('post_title')).controller!.text, 'Calendar reel');
      await tester.enterText(_k('post_title'), 'Calendar reel v2');
      await tester.tap(_k('post_save'));
      await tester.pumpAndSettle();
      expect(f.savedPosts.single.id, 'c1');
      expect(f.savedPosts.single.body['title'], 'Calendar reel v2');
      expect(f.savedPosts.single.body['status'], 'published');
      expect(f.savedPosts.single.body['brand'], 'main');
    });
  });

  group('the post editor', () {
    testWidgets('a title is needed; a filled post is sent with its stage, brand and the numbers typed on it', (tester) async {
      final f = await _pump(tester, const SocialsScreen());
      await tester.tap(_k('soc_create_content'));
      await tester.pumpAndSettle();
      await tester.tap(_k('post_save'));
      await tester.pumpAndSettle();
      expect(find.text('Give the post a title.'), findsOneWidget);
      expect(f.savedPosts, isEmpty);
      await tester.enterText(_k('post_title'), 'Festive reel');
      await tester.enterText(_k('post_metric_reach'), '1200');
      await tester.enterText(_k('post_metric_likes'), '80');
      await tester.tap(_k('post_save'));
      await tester.pumpAndSettle();
      final b = f.savedPosts.single.body;
      expect(f.savedPosts.single.id, isNull);
      expect(b['title'], 'Festive reel');
      expect(b['status'], 'planned');
      expect(b['platform'], 'instagram');
      expect(b['metrics'], {'reach': 1200, 'likes': 80});
      expect(b.containsKey('publishedDate'), isFalse, reason: 'not published yet');
    });

    testWidgets('the brand chosen in the editor is the brand sent', (tester) async {
      final f = await _pump(tester, const SocialsScreen());
      await tester.tap(_k('soc_create_content'));
      await tester.pumpAndSettle();
      await tester.enterText(_k('post_title'), 'Kerala bridal reel');
      await tester.tap(_k('post_brand'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kerala').last);
      await tester.pumpAndSettle();
      await tester.tap(_k('post_status'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Published').last);
      await tester.pumpAndSettle();
      await tester.tap(_k('post_save'));
      await tester.pumpAndSettle();
      expect(f.savedPosts.single.body['brand'], 'kerala');
      expect(f.savedPosts.single.body['status'], 'published');
      expect(f.savedPosts.single.body.containsKey('publishedDate'), isTrue, reason: 'a published post carries the day it went out');
    });

    testWidgets('what the server refuses is shown in the form', (tester) async {
      final f = _FakeSocials()..refuse = const TeamRefusal('Only marketing can add content');
      await _pump(tester, const SocialsScreen(), fake: f);
      await tester.tap(_k('soc_create_content'));
      await tester.pumpAndSettle();
      await tester.enterText(_k('post_title'), 'x');
      await tester.tap(_k('post_save'));
      await tester.pumpAndSettle();
      expect(find.text('Only marketing can add content'), findsOneWidget);
      expect(_k('post_title'), findsOneWidget, reason: 'the form stays open');
    });
  });

  group('Content & Assets', () {
    testWidgets('counts on the chips, the cards with their stage, and search narrows the library', (tester) async {
      final f = await _pump(tester, const SocialsScreen(initialTab: 'assets'));
      expect(find.descendant(of: _k('soc_asset_media_all'), matching: find.text('2')), findsOneWidget);
      expect(find.descendant(of: _k('soc_asset_media_video'), matching: find.text('1')), findsOneWidget);
      expect(find.descendant(of: _k('asset_a1'), matching: find.text('Approved / Final')), findsOneWidget);
      expect(find.descendant(of: _k('asset_a2'), matching: find.text('In Review')), findsOneWidget);
      await tester.enterText(_k('soc_asset_search'), 'studio');
      await tester.pumpAndSettle();
      expect(f.assetQueries.last.q, 'studio');
      expect(_k('asset_a2'), findsOneWidget);
      expect(_k('asset_a1'), findsNothing);
    });

    testWidgets('a media chip filters; tapping it again clears it', (tester) async {
      final f = await _pump(tester, const SocialsScreen(initialTab: 'assets'));
      await tester.tap(_k('soc_asset_media_video'));
      await tester.pumpAndSettle();
      expect(f.assetQueries.last.media, 'video');
      await tester.tap(_k('soc_asset_media_video'));
      await tester.pumpAndSettle();
      expect(f.assetQueries.last.media, isNull);
    });

    testWidgets('an asset is added with a title and a link; a refusal from the server is shown', (tester) async {
      final f = _FakeSocials()..refuse = const TeamRefusal('Paste the link to the file (a Drive or cloud link starting with https://).');
      await _pump(tester, const SocialsScreen(initialTab: 'assets'), fake: f);
      await tester.tap(_k('soc_asset_add'));
      await tester.pumpAndSettle();
      await tester.enterText(_k('asset_title'), 'Hero still');
      await tester.tap(_k('asset_save'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Paste the link to the file'), findsOneWidget);
      f.refuse = null;
      await tester.enterText(_k('asset_url'), 'https://drive.google.com/x');
      await tester.tap(_k('asset_save'));
      await tester.pumpAndSettle();
      final b = f.savedAssets.single.body;
      expect(b['title'], 'Hero still');
      expect(b['url'], 'https://drive.google.com/x');
      expect(b['stage'], 'raw');
      expect(f.savedAssets.single.id, isNull);
    });

    testWidgets('the menu moves an asset on: approve sends the stage with the asset\'s id', (tester) async {
      final f = await _pump(tester, const SocialsScreen(initialTab: 'assets'));
      await tester.tap(_k('asset_menu_a2'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Approve').last);
      await tester.pumpAndSettle();
      expect(f.savedAssets.single.id, 'a2');
      expect(f.savedAssets.single.body, {'stage': 'approved'});
    });

    testWidgets('an empty library says how to start', (tester) async {
      final f = _FakeSocials()..assetsJson = {'items': [], 'counts': {'total': 0}, 'facets': {}};
      await _pump(tester, const SocialsScreen(initialTab: 'assets'), fake: f);
      expect(find.textContaining('No assets yet'), findsOneWidget);
    });
  });

  group('Publishing & Accounts', () {
    testWidgets('accounts show followers and an honest "Manual" status; the queue lists what waits to go out', (tester) async {
      await _pump(tester, const SocialsScreen(initialTab: 'publishing'));
      expect(find.descendant(of: _k('soc_account_ac1'), matching: find.text('Instagram (Main)')), findsOneWidget);
      expect(find.descendant(of: _k('soc_account_ac1'), matching: find.text('128.4K')), findsOneWidget);
      expect(find.descendant(of: _k('soc_account_ac1'), matching: find.text('Manual')), findsOneWidget);
      expect(find.text('Publishing Queue (2)'), findsOneWidget);
      expect(find.descendant(of: _k('soc_queue_q1'), matching: find.text('Scheduled')), findsOneWidget);
      expect(find.descendant(of: _k('soc_queue_q2'), matching: find.text('In Review')), findsOneWidget);
      expect(_k('soc_published_r1'), findsOneWidget);
    });

    testWidgets('an account is added; one the server refuses (already listed) is explained', (tester) async {
      final f = _FakeSocials();
      await _pump(tester, const SocialsScreen(initialTab: 'publishing'), fake: f);
      await tester.tap(_k('soc_account_add'));
      await tester.pumpAndSettle();
      await tester.enterText(_k('acct_handle'), '@teamn.kerala');
      await tester.enterText(_k('acct_followers'), '21600');
      await tester.tap(_k('acct_save'));
      await tester.pumpAndSettle();
      expect(f.savedAccounts.single.body, {'platform': 'instagram', 'brand': 'main', 'handle': '@teamn.kerala', 'followers': 21600});
      f.refuse = const TeamRefusal('That account is already listed.', status: 409);
      await tester.tap(_k('soc_account_add'));
      await tester.pumpAndSettle();
      await tester.tap(_k('acct_save'));
      await tester.pumpAndSettle();
      expect(find.text('That account is already listed.'), findsOneWidget);
    });

    testWidgets('Schedule Post opens the editor on the Scheduled stage', (tester) async {
      await _pump(tester, const SocialsScreen(initialTab: 'publishing'));
      await tester.tap(_k('soc_schedule_post'));
      await tester.pumpAndSettle();
      expect(find.text('Scheduled'), findsWidgets);
      expect(_k('post_status'), findsOneWidget);
    });
  });

  group('Performance', () {
    testWidgets('the six figures, the platform table and the best posts', (tester) async {
      await _pump(tester, const SocialsScreen(initialTab: 'performance'));
      expect(find.descendant(of: _k('soc_perf_reach'), matching: find.text('468,320')), findsOneWidget);
      expect(find.descendant(of: _k('soc_perf_reach'), matching: find.text('↑ +16% vs last week')), findsOneWidget);
      expect(find.descendant(of: _k('soc_perf_impr'), matching: find.text('1,092,450')), findsOneWidget);
      expect(find.descendant(of: _k('soc_perf_er'), matching: find.text('7.6%')), findsOneWidget);
      expect(find.descendant(of: _k('soc_perf_views'), matching: find.text('↓ −4% vs last week')), findsOneWidget);
      expect(find.descendant(of: _k('soc_perf_clicks'), matching: find.textContaining('vs last week')), findsNothing);
      expect(find.descendant(of: _k('soc_perf_row_instagram'), matching: find.text('2.7%')), findsOneWidget);
      expect(find.descendant(of: _k('soc_perf_row_youtube'), matching: find.text('—')), findsOneWidget, reason: 'no reach-based rate when nothing was typed');
      expect(find.descendant(of: _k('soc_top_t1'), matching: find.text('Family at SkyCity')), findsOneWidget);
      expect(_text(tester, _k('soc_perf_status_total')), '64');
    });

    testWidgets('the platform filter asks again for that platform', (tester) async {
      final f = await _pump(tester, const SocialsScreen(initialTab: 'performance'));
      await tester.tap(_k('soc_perf_platform'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('YouTube').last);
      await tester.pumpAndSettle();
      expect(f.performancePlatforms.last, 'youtube');
    });
  });

  group('Reports & Insights', () {
    testWidgets('the summary: overall growth, each figure with its change, the six-month chart and the insights', (tester) async {
      await _pump(tester, const SocialsScreen(initialTab: 'reports'));
      expect(_text(tester, _k('soc_report_growth_pct')), '+22%');
      expect(find.descendant(of: _k('soc_report_reach'), matching: find.text('↑ 16%')), findsOneWidget);
      expect(find.descendant(of: _k('soc_report_eng'), matching: find.text('↓ 3%')), findsOneWidget);
      expect(find.descendant(of: _k('soc_report_followers'), matching: find.text('—')), findsOneWidget);
      expect(_k('soc_growth_chart'), findsOneWidget);
      expect(find.textContaining('Reels earned 2.4×'), findsOneWidget);
    });

    testWidgets('growth that cannot be worked out says what it needs; the other views open', (tester) async {
      final f = _FakeSocials();
      await _pump(tester, const SocialsScreen(initialTab: 'reports'), fake: f);
      await tester.tap(_k('soc_report_growth'));
      await tester.tap(_k('soc_report_content'));
      await tester.pumpAndSettle();
      expect(find.text('Posts by Format'), findsOneWidget);
      expect(find.text('Platform Analysis'), findsOneWidget);
      await tester.tap(_k('soc_report_growth'));
      await tester.pumpAndSettle();
      expect(_k('soc_growth_table'), findsOneWidget);
    });
  });

  group('targets', () {
    testWidgets('Set targets opens the week\'s metrics and saves the numbers typed, for the week and brand', (tester) async {
      final f = await _pump(tester, const SocialsScreen());
      await tester.tap(_k('soc_set_targets'));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(_k('soc_target_mt1')).controller!.text, '26', reason: 'the current target is filled in');
      await tester.enterText(_k('soc_target_mt1'), '30');
      await tester.enterText(_k('soc_target_mt2'), '12');
      await tester.tap(_k('soc_targets_save'));
      await tester.pumpAndSettle();
      expect(f.savedTargets.single.week, '2026-11-09');
      expect(f.savedTargets.single.brand, 'all');
      expect(f.savedTargets.single.values, {'mt1': 30.0, 'mt2': 12.0});
    });

    testWidgets('a negative target is refused before it is sent; a refusal from the server is shown', (tester) async {
      final f = _FakeSocials();
      await _pump(tester, const SocialsScreen(), fake: f);
      await tester.tap(_k('soc_set_targets'));
      await tester.pumpAndSettle();
      await tester.enterText(_k('soc_target_mt1'), '-4');
      await tester.tap(_k('soc_targets_save'));
      await tester.pumpAndSettle();
      expect(find.text('A target must be a number, zero or more.'), findsOneWidget);
      expect(f.savedTargets, isEmpty);
      f.refuse = const TeamRefusal('Only a Marketing Manager can set targets.', status: 403);
      await tester.enterText(_k('soc_target_mt1'), '5');
      await tester.tap(_k('soc_targets_save'));
      await tester.pumpAndSettle();
      expect(find.text('Only a Marketing Manager can set targets.'), findsOneWidget);
    });
  });

  group('a phone', () {
    testWidgets('the overview fits a 390-wide screen without overflow and the tab row scrolls', (tester) async {
      await _pump(tester, const SocialsScreen(), size: const Size(390, 1800));
      expect(tester.takeException(), isNull);
      expect(_k('soc_kpi_total'), findsOneWidget);
      expect(_k('soc_flow_published'), findsOneWidget);
      await _openTab(tester, 'reports');
      expect(tester.takeException(), isNull);
    });
  });

  group('what the service asks the server for', () {
    Future<List<RequestOptions>> capture(Future<void> Function(MarketingSocialsService s) run) async {
      final seen = <RequestOptions>[];
      final dio = Dio()..httpClientAdapter = _Capture(seen);
      await run(MarketingSocialsService(dio));
      return seen;
    }

    final f = TeamFilter(from: DateTime(2026, 11, 9), to: DateTime(2026, 11, 15), brand: TeamBrand.kerala);

    test('every Socials read carries the shared range and brand', () async {
      final reqs = await capture((s) async {
        await s.overview(f);
        await s.performance(f);
        await s.reports(f);
        await s.calendar(f);
        await s.targets(f);
      });
      expect(reqs.map((r) => r.path), ['/marketing/socials/overview', '/marketing/socials/performance', '/marketing/socials/reports', '/marketing/socials/calendar', '/marketing/socials/targets']);
      for (final r in reqs) {
        expect(r.queryParameters, containsPair('from', '2026-11-09'), reason: r.path);
        expect(r.queryParameters, containsPair('to', '2026-11-15'), reason: r.path);
        expect(r.queryParameters, containsPair('brand', 'kerala'), reason: r.path);
      }
    });

    test('a platform is sent when one is chosen and left out for all', () async {
      final reqs = await capture((s) async {
        await s.performance(f, platform: 'youtube');
        await s.performance(f);
        await s.calendar(f, platform: 'youtube');
        await s.calendar(f);
      });
      expect(reqs[0].queryParameters['platform'], 'youtube');
      expect(reqs[1].queryParameters.containsKey('platform'), isFalse);
      expect(reqs[2].queryParameters['platform'], 'youtube');
      expect(reqs[3].queryParameters.containsKey('platform'), isFalse);
    });

    test('publishing filters by brand only when one is chosen; assets send their filters', () async {
      final reqs = await capture((s) async {
        await s.publishing(f);
        await s.publishing(TeamFilter(from: f.from, to: f.to));
        await s.assets(const AssetQuery(q: 'bridal', stage: 'approved', brand: 'kerala'));
      });
      expect(reqs[0].queryParameters, {'brand': 'kerala'});
      expect(reqs[1].queryParameters, isEmpty);
      expect(reqs[2].queryParameters, {'q': 'bridal', 'stage': 'approved', 'brand': 'kerala'});
    });

    test('targets are saved for a week and brand as a list of metric and number', () async {
      final reqs = await capture((s) => s.saveTargets(brand: 'all', week: '2026-11-09', values: {'m1': 26}));
      expect(reqs.single.method, 'PUT');
      expect(reqs.single.data, {'brand': 'all', 'period': '2026-11-09', 'values': [{'metricId': 'm1', 'target': 26.0}]});
    });

    test('a server refusal comes back as its own words', () async {
      final dio = Dio()..httpClientAdapter = _Capture([], status: 403, body: '{"message":"Only a Marketing Manager can set targets."}');
      await expectLater(MarketingSocialsService(dio).saveTargets(brand: 'all', week: '2026-11-09', values: {'m1': 1}), throwsA(isA<TeamRefusal>().having((e) => e.message, 'message', 'Only a Marketing Manager can set targets.')));
    });
  });

  group('the kit', () {
    testWidgets('a donut with the legend beside it when wide and under it when narrow — labels never cut', (tester) async {
      Future<void> pumpAt(double w) async {
        await tester.pumpWidget(MaterialApp(theme: AppTheme.lightTheme, home: Scaffold(body: Center(child: SizedBox(width: w, child: const MktDonut(centerValue: '64', centerLabel: 'Contents', slices: [(label: 'Published', value: 40, trailing: '40  63%'), (label: 'Scheduled', value: 12, trailing: '12  19%')]))))));
        await tester.pump();
      }

      await pumpAt(420);
      final wideLabel = tester.getTopLeft(find.text('Published'));
      final wideDonut = tester.getTopLeft(find.text('64'));
      expect(wideLabel.dx, greaterThan(wideDonut.dx), reason: 'beside');
      await pumpAt(240);
      expect(tester.getTopLeft(find.text('Published')).dy, greaterThan(tester.getTopLeft(find.text('64')).dy), reason: 'under');
      expect(tester.takeException(), isNull);
    });
  });
}
