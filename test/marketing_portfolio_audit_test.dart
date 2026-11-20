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
import 'package:nizan_crm/features/marketing/presentation/portfolio/booking_content_card.dart';
import 'package:nizan_crm/features/marketing/presentation/portfolio/portfolio_screen.dart';
import 'package:nizan_crm/features/marketing/presentation/portfolio/shoot_editor.dart';
import 'package:nizan_crm/features/marketing/presentation/portfolio/shoot_reports_tab.dart';
import 'package:nizan_crm/features/marketing/services/portfolio_service.dart';
import 'package:nizan_crm/features/marketing/services/socials_service.dart';
import 'package:nizan_crm/features/marketing/services/team_service.dart';
import 'package:nizan_crm/features/marketing/presentation/media/media_stream.dart';

// The Creative Portfolio fixes after the audit: the storyboard, the linked work (booking), makeup artists on the crew, outputs that
// count posts, the report's Outputs and Notes and an export of every row, attendance and artists in availability, the gallery's tags
// and list view, a member's own log entries, and the booking screen's Content card.

Map<String, dynamic> _shoot(String id, {String title = 'Bridal Transformation', String status = 'in_production', int? turnaround, bool delayed = false}) => {
      'id': id, 'title': title, 'brand': 'main', 'category': 'Bridal Makeup', 'shootType': 'Full Shoot', 'status': status, 'shootDate': '2026-11-10', 'startTime': '09:00', 'endTime': '17:00', 'location': 'Studio 1',
      'coverUrl': '', 'crewCount': 2, 'progress': 60, 'planned': {'reels': 2, 'stills': 1}, 'plannedTotal': 3, 'delivered': {'reels': 2}, 'deliveredPosts': {'reels': 1}, 'deliveredTotal': 2, 'turnaround': turnaround,
      'rescheduleCount': 0, 'delayed': delayed, 'bookingId': 'b1',
    };

Map<String, dynamic> _detail(String id) => {
      ..._shoot(id),
      'pillar': 'Bridal', 'brief': {'objective': 'Show the transformation', 'audience': 'Brides', 'notes': 'Bring the gold set.\nShoot by the window.'},
      'crew': [{'memberId': 'm1', 'employeeId': null, 'name': 'Ashique', 'role': 'Videographer'}, {'memberId': null, 'employeeId': 'e1', 'name': 'Anu', 'role': 'Makeup Artist'}],
      'references': [],
      'storyboard': [{'shotNo': '1', 'description': 'Bride walks in', 'shotType': 'Wide', 'durationSec': 8, 'referenceUrl': 'https://d.test/ref', 'notes': ''}, {'shotNo': '2A', 'description': 'Close-up of the eyes', 'shotType': 'Close-up', 'durationSec': 4, 'referenceUrl': '', 'notes': 'slow motion'}],
      'booking': {'id': 'b1', 'bookingNumber': '26111234', 'customerName': 'Anjali', 'service': 'Bridal Makeup', 'eventDate': '2026-11-20', 'eventDates': ['2026-11-20'], 'district': 'Kozhikode', 'contentRequired': true},
      'milestones': [], 'currentMilestone': 'production', 'assets': [],
      'posts': [{'id': 'p1', 'title': 'Reel B out', 'platform': 'instagram', 'contentType': 'reel', 'status': 'published', 'brand': 'main', 'scheduledDate': '2026-11-12T05:00:00.000Z', 'publishedDate': '2026-11-12T05:00:00.000Z', 'permalink': '', 'assetId': null}],
      'checklist': [{'key': 'reels', 'label': 'Reels', 'planned': 2, 'delivered': 2, 'posted': 1, 'done': true}, {'key': 'stills', 'label': 'Stills / Photos', 'planned': 1, 'delivered': 0, 'posted': 0, 'done': false}],
      'footageMb': 0, 'takeaways': [],
      'activity': [{'id': 'l1', 'member': 'Preethi', 'workedOn': 'Moodboard', 'stage': 'pre_production', 'status': 'completed', 'day': '2026-11-06'}],
      'activityScope': 'own',
    };

class _FakePortfolio extends MarketingPortfolioService {
  _FakePortfolio() : super(Dio());
  final saved = <({Map<String, dynamic> body, String? id})>[];
  final allReportsCalls = <ReportQuery>[];
  Map<String, dynamic> content = {
    'booking': {'id': 'b1', 'bookingNumber': '26111234', 'customerName': 'Anjali', 'service': 'Bridal Makeup', 'eventDate': '2026-11-20', 'contentRequired': true},
    'shoots': [{..._shoot('s1'), 'checklist': [{'key': 'reels', 'label': 'Reels', 'planned': 2, 'delivered': 2, 'posted': 1, 'done': true}, {'key': 'stills', 'label': 'Stills / Photos', 'planned': 1, 'delivered': 0, 'posted': 0, 'done': false}], 'posts': [{'id': 'p1', 'title': 'Reel B out', 'platform': 'instagram', 'contentType': 'reel', 'status': 'published', 'publishedDate': '2026-11-12T05:00:00.000Z'}]}],
  };

  @override
  Future<PlannerData> planner(TeamFilter f, PlannerQuery q) async => PlannerData.fromJson({'counts': {}, 'total': 1, 'items': [_shoot('s1')]});
  @override
  Future<ShootDetail> shoot(String id) async => ShootDetail.fromJson(_detail(id));
  @override
  Future<ProductionCalendar> calendar(TeamFilter f, {String? day}) async => ProductionCalendar.fromJson({
        'day': '2026-11-20', 'counts': {}, 'items': [], 'today': [], 'upcoming': [], 'load': {'total': 0, 'rows': []},
        'availability': [{'role': 'Makeup Artist', 'total': 4, 'booked': 1, 'onLeave': 1, 'absent': 0, 'onWork': 1, 'available': 1}, {'role': 'Videographer', 'total': 2, 'booked': 1, 'onLeave': 0, 'absent': 1, 'onWork': 0, 'available': 0}],
      });
  @override
  Future<ShootReports> reports(TeamFilter f, ReportQuery q) async => ShootReports.fromJson({'kpis': {}, 'monthly': [], 'distribution': {'total': 0, 'rows': []}, 'filters': {'all': 9}, 'total': 9, 'page': 1, 'pageSize': 8, 'rows': [_shoot('s1')]});
  @override
  Future<ShootReports> allReports(TeamFilter f, ReportQuery q) async {
    allReportsCalls.add(q);
    return ShootReports.fromJson({'rows': [for (var i = 0; i < 9; i++) _shoot('s$i')], 'total': 9});
  }

  @override
  Future<ShootSetup> setup() async => ShootSetup.fromJson({'members': [{'id': 'm1', 'name': 'Ashique', 'role': 'Videographer'}], 'artists': [{'id': 'e1', 'name': 'Anu', 'role': 'Makeup Artist'}, {'id': 'e2', 'name': 'Bina', 'role': 'Makeup Artist'}], 'shootTypes': ['Full Shoot']});
  @override
  Future<ShootSummary> saveShoot(Map<String, dynamic> body, {String? id}) async {
    saved.add((body: body, id: id));
    return ShootSummary.fromJson(_shoot(id ?? 'new'));
  }

  @override
  Future<List<BookingBrief>> bookingOptions({String q = '', String? around}) async => [BookingBrief.fromJson(const {'id': 'b7', 'bookingNumber': '26119999', 'customerName': 'Fathima', 'service': 'Engagement', 'eventDate': '2026-11-25'})];
  @override
  Future<BookingContent> bookingContent(String bookingId) async => BookingContent.fromJson(content);
}

class _FakeSocials extends MarketingSocialsService {
  _FakeSocials() : super(Dio());
  final queries = <AssetQuery>[];
  final searches = <AssetSearch>[];
  @override
  Future<AssetPage> searchAssets(AssetSearch s, {int pageNo = 1, int limit = kGalleryPageSize}) async {
    searches.add(s);
    return AssetPage.fromJson({..._library(), 'total': 1});
  }

  @override
  Future<AssetList> assets(AssetQuery q) async {
    queries.add(q);
    return AssetList.fromJson(_library());
  }

  Map<String, dynamic> _library() => ({
      'items': [{'id': 'g1', 'title': 'Mehendi still', 'brand': 'kerala', 'kind': 'still', 'media': 'image', 'stage': 'approved', 'url': 'https://d.test/g', 'portfolio': 'Kerala', 'page': 'Mehendi', 'tags': ['mehendi'], 'owner': 'Preethi', 'createdAt': '2026-11-10T05:00:00.000Z'}],
      'counts': {'total': 1},
      'facets': {'tags': {'mehendi': 1, 'bridal': 4}, 'owners': {'Preethi': 1}},
    });
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
    return ResponseBody.fromString('{"items":[]}', 200, headers: {Headers.contentTypeHeader: ['application/json']});
  }

  @override
  void close({bool force = false}) {}
}

Future<({_FakePortfolio p, _FakeSocials s})> _pump(WidgetTester tester, Widget Function(WidgetRef ref) body, {Size size = const Size(1280, 2000), Map<String, dynamic>? content}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final p = _FakePortfolio();
  if (content != null) p.content = content;
  final s = _FakeSocials();
  final overrides = <Override>[marketingPortfolioServiceProvider.overrideWithValue(p), marketingSocialsServiceProvider.overrideWithValue(s), marketingTeamServiceProvider.overrideWithValue(_NoTeam()), mediaStreamServiceProvider.overrideWithValue(NoMediaStream())];
  await tester.pumpWidget(ProviderScope(overrides: overrides, child: MaterialApp(theme: AppTheme.lightTheme, home: Scaffold(body: Consumer(builder: (context, ref, _) => body(ref))))));
  await tester.pumpAndSettle();
  return (p: p, s: s);
}

Finder _k(String key) => find.byKey(Key(key));

void main() {
  group('how the new parts of the payloads read', () {
    test('a shoot detail reads its storyboard, work, posts, checklist and whose log entries it shows', () {
      final d = ShootDetail.fromJson(_detail('s1'));
      expect(d.storyboard.map((f) => f.shotNo), ['1', '2A']);
      expect(d.storyboard.first.toJson(), {'shotNo': '1', 'description': 'Bride walks in', 'shotType': 'Wide', 'durationSec': 8, 'referenceUrl': 'https://d.test/ref', 'imageUrl': '', 'notes': ''});
      expect(d.booking!.label, '26111234 · Anjali');
      expect(d.booking!.contentRequired, isTrue);
      expect(d.posts.single.status, 'published');
      expect(d.checklist.first.done, isTrue);
      expect(d.activityScope, 'own');
      expect(d.summary.deliveredPosts['reels'], 1);
      expect(d.summary.bookingId, 'b1');
      expect(d.crew.last.employeeId, 'e1');
      expect(d.crew.last.toJson(), {'employeeId': 'e1', 'name': 'Anu', 'role': 'Makeup Artist'});
      expect(ShootDetail.fromJson(const {'id': 'x'}).booking, isNull);
    });

    test('availability reads absent and on-a-work; the setup reads the artists; a booking\'s content its shoots', () {
      final r = RoleAvailability.fromJson(const {'role': 'Makeup Artist', 'total': 4, 'absent': 1, 'onWork': 2});
      expect([r.absent, r.onWork], [1, 2]);
      expect(ShootSetup.fromJson(const {'artists': [{'id': 'e1', 'name': 'Anu', 'role': 'Makeup Artist'}]}).artists.single.name, 'Anu');
      final c = BookingContent.fromJson(_FakePortfolio().content);
      expect(c.booking!.customerName, 'Anjali');
      expect(c.shoots.single.checklist.length, 2);
      expect(c.shoots.single.posts.single.title, 'Reel B out');
    });
  });

  group('Shoot Planner', () {
    testWidgets('the Storyboard view lists the frames in order, and the open shoot names its work', (tester) async {
      await _pump(tester, (ref) => const PortfolioScreen());
      expect(find.descendant(of: _k('pf_booking'), matching: find.text('Work: 26111234 · Anjali (20 Nov)')), findsOneWidget);
      await tester.tap(_k('pf_part_storyboard'));
      await tester.pumpAndSettle();
      expect(_k('pf_frame_0'), findsOneWidget);
      expect(find.descendant(of: _k('pf_frame_1'), matching: find.text('Close-up of the eyes')), findsOneWidget);
      expect(find.descendant(of: _k('pf_frame_1'), matching: find.text('2A')), findsOneWidget);
      expect(find.text('2 frames · 0:12 in all'), findsOneWidget);
    });

    testWidgets('editing the storyboard: add a frame, move it to the top, save the frames in that order; a frame needs a description', (tester) async {
      final f = await _pump(tester, (ref) => const PortfolioScreen());
      await tester.tap(_k('pf_part_storyboard'));
      await tester.pumpAndSettle();
      await tester.tap(_k('pf_storyboard_edit'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(_k('sb_add'));
      await tester.tap(_k('sb_add'));
      await tester.pumpAndSettle();
      await tester.tap(_k('sb_save'));
      await tester.pumpAndSettle();
      expect(find.text('Frame 3 needs a description.'), findsOneWidget);
      expect(f.p.saved, isEmpty);
      await tester.enterText(_k('sb_desc_2'), 'Jewellery detail');
      await tester.enterText(_k('sb_dur_2'), '5');
      await tester.ensureVisible(_k('sb_up_2'));
      await tester.tap(_k('sb_up_2'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(_k('sb_up_1'));
      await tester.tap(_k('sb_up_1'));
      await tester.pumpAndSettle();
      await tester.tap(_k('sb_save'));
      await tester.pumpAndSettle();
      final sb = f.p.saved.single.body['storyboard'] as List;
      expect(f.p.saved.single.id, 's1');
      expect(sb.map((x) => x['description']), ['Jewellery detail', 'Bride walks in', 'Close-up of the eyes']);
      expect(sb.first['durationSec'], 5);
      expect(sb.last['shotNo'], '2A');
    });

    testWidgets('a member sees that the logged work shown is their own', (tester) async {
      await _pump(tester, (ref) => const PortfolioScreen());
      expect(find.textContaining('(your own entries)'), findsOneWidget);
    });

    testWidgets('the Content Plan lists the posts from the shoot', (tester) async {
      await _pump(tester, (ref) => const PortfolioScreen());
      await tester.tap(_k('pf_part_plan'));
      await tester.pumpAndSettle();
      expect(_k('pf_post_p1'), findsOneWidget);
      expect(find.descendant(of: _k('pf_post_p1'), matching: find.text('Posted')), findsOneWidget);
    });
  });

  group('the shoot form', () {
    testWidgets('a work is picked from the bookings and a makeup artist added to the crew; both are sent', (tester) async {
      final f = await _pump(tester, (ref) => const PortfolioScreen());
      await tester.tap(_k('pf_new_shoot'));
      await tester.pumpAndSettle();
      await tester.enterText(_k('shoot_title'), 'Fathima engagement');
      await tester.ensureVisible(_k('shoot_booking'));
      await tester.tap(_k('shoot_booking'));
      await tester.pumpAndSettle();
      await tester.tap(_k('pick_booking_b7'));
      await tester.pumpAndSettle();
      expect(find.text('26119999 · Fathima · 25 Nov'), findsOneWidget);
      await tester.ensureVisible(_k('shoot_artist_add'));
      await tester.tap(_k('shoot_artist_add'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bina · Makeup Artist').last);
      await tester.pumpAndSettle();
      expect(_k('shoot_artist_e2'), findsOneWidget);
      await tester.tap(_k('shoot_save'));
      await tester.pumpAndSettle();
      final b = f.p.saved.single.body;
      expect(b['bookingId'], 'b7');
      expect(b['crew'], [{'employeeId': 'e2', 'name': 'Bina', 'role': 'Makeup Artist'}]);
    });

    testWidgets('editing keeps the artist and the work; the work can be unlinked', (tester) async {
      final f = await _pump(tester, (ref) => const PortfolioScreen());
      await tester.tap(_k('shoot_menu'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit plan'));
      await tester.pumpAndSettle();
      expect(_k('shoot_artist_e1'), findsOneWidget);
      expect(tester.widget<TextField>(_k('shoot_other_crew')).controller!.text, '', reason: 'an artist is not a free-typed crew line');
      await tester.ensureVisible(_k('shoot_booking'));
      await tester.tap(find.descendant(of: _k('shoot_booking'), matching: find.byIcon(Icons.close_rounded)));
      await tester.pumpAndSettle();
      await tester.tap(_k('shoot_save'));
      await tester.pumpAndSettle();
      final b = f.p.saved.single.body;
      expect(b['bookingId'], isNull);
      expect((b['crew'] as List).map((c) => c['name']), ['Ashique', 'Anu']);
    });

    testWidgets('opened for a booking, the plan has the work linked and its day and client filled in', (tester) async {
      final f = await _pump(tester, (ref) => Builder(builder: (context) => TextButton(key: const Key('open'), onPressed: () => showShootEditor(context, ref, booking: BookingBrief.fromJson(const {'id': 'b1', 'bookingNumber': '26111234', 'customerName': 'Anjali', 'service': 'Bridal Makeup', 'eventDate': '2026-11-20'})), child: const Text('open'))));
      await tester.tap(_k('open'));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(_k('shoot_title')).controller!.text, 'Anjali – Bridal Makeup');
      expect(find.text('Fri 20 Nov 2026'), findsOneWidget);
      await tester.tap(_k('shoot_save'));
      await tester.pumpAndSettle();
      expect(f.p.saved.single.body['bookingId'], 'b1');
      expect(f.p.saved.single.body['shootDate'], '2026-11-20');
    });
  });

  group('Shoot Reports', () {
    testWidgets('the report\'s Outputs (planned, delivered, as posts, left) and Notes views', (tester) async {
      await _pump(tester, (ref) => const PortfolioScreen(initialTab: 'reports'));
      await tester.tap(_k('sr_part_outputs'));
      await tester.pumpAndSettle();
      expect(_k('sr_outputs'), findsOneWidget);
      final reels = find.descendant(of: _k('sr_output_reels'), matching: find.byType(Text));
      expect(tester.widgetList<Text>(reels).map((t) => t.data), ['Reels', '2', '2', '1', '0']);
      final stills = find.descendant(of: _k('sr_output_stills'), matching: find.byType(Text));
      expect(tester.widgetList<Text>(stills).map((t) => t.data), ['Stills', '1', '0', '0', '1']);
      await tester.tap(_k('sr_part_notes'));
      await tester.pumpAndSettle();
      expect(find.text('Bring the gold set.\nShoot by the window.'), findsOneWidget);
    });

    testWidgets('Export asks for EVERY matching row, not the page on screen', (tester) async {
      final f = await _pump(tester, (ref) => const PortfolioScreen(initialTab: 'reports'));
      await tester.tap(_k('sr_export'));
      await tester.pumpAndSettle();
      expect(f.p.allReportsCalls.length, 1);
    });

    test('the export rows: one per shoot, outputs by type, an unknown turnaround empty', () {
      final rows = shootReportsCsvRows([for (var i = 0; i < 9; i++) ShootSummary.fromJson(_shoot('s$i', turnaround: i == 0 ? 4 : null, delayed: i == 1))]);
      expect(rows.length, 10, reason: 'a header and all nine shoots');
      final header = rows.first.cast<String>();
      expect(header.contains('Reels planned') && header.contains('Reels delivered'), isTrue);
      final first = rows[1];
      expect(first[header.indexOf('Turnaround (days)')], 4);
      expect(rows[2][header.indexOf('Turnaround (days)')], '', reason: 'not known yet → empty, never 0');
      expect(rows[2][header.indexOf('Delayed')], 'Yes');
      expect(first[header.indexOf('Reels planned')], 2);
      expect(first[header.indexOf('Delivered as posts')], 1);
    });
  });

  group('Production Calendar and Gallery', () {
    testWidgets('availability says who is on a shoot, on a client work, on leave or absent', (tester) async {
      await _pump(tester, (ref) => const PortfolioScreen(initialTab: 'calendar'));
      expect(find.descendant(of: _k('pc_role_Makeup Artist'), matching: find.text('1 on a client work')), findsOneWidget);
      expect(find.descendant(of: _k('pc_role_Makeup Artist'), matching: find.text('1 on a shoot')), findsOneWidget);
      expect(find.descendant(of: _k('pc_role_Videographer'), matching: find.text('1 absent')), findsOneWidget);
      expect(find.descendant(of: _k('pc_role_Makeup Artist'), matching: find.text('1 / 4 Available')), findsOneWidget);
    });

    testWidgets('the gallery cuts by a tag and by owner, and shows a list as well as a grid', (tester) async {
      final f = await _pump(tester, (ref) => const PortfolioScreen(initialTab: 'gallery'));
      await tester.ensureVisible(_k('gl_tag_mehendi'));
      await tester.tap(_k('gl_tag_mehendi'));
      await tester.pumpAndSettle();
      expect(f.s.searches.last.keywords, ['mehendi']);
      await tester.ensureVisible(_k('gl_owner_Preethi'));
      await tester.tap(_k('gl_owner_Preethi'));
      await tester.pumpAndSettle();
      expect(f.s.searches.last.facet('owner'), {'Preethi'});
      expect(f.s.searches.last.keywords, ['mehendi']);
      await tester.ensureVisible(_k('asset_layout_list'));
      await tester.tap(_k('asset_layout_list'));
      await tester.pumpAndSettle();
      expect(_k('asset_row_g1'), findsOneWidget);
    });
  });

  group('the booking\'s Content card', () {
    testWidgets('shows the linked shoot, its planned outputs against delivered and posted, and the posts', (tester) async {
      await _pump(tester, (ref) => const SingleChildScrollView(child: BookingContentCard(bookingId: 'b1')));
      expect(_k('bookingContentRequired'), findsOneWidget);
      expect(_k('bookingContentShoot_s1'), findsOneWidget);
      expect(find.descendant(of: _k('bookingContentRow_s1_reels'), matching: find.text('2 / 2 delivered')), findsOneWidget);
      expect(find.descendant(of: _k('bookingContentRow_s1_reels'), matching: find.text('1 posted')), findsOneWidget);
      expect(find.descendant(of: _k('bookingContentRow_s1_stills'), matching: find.byIcon(Icons.check_box_outline_blank_rounded)), findsOneWidget);
      expect(find.text('Reel B out'), findsOneWidget);
      expect(find.text('Plan another shoot'), findsOneWidget);
    });

    testWidgets('with no shoot it says so, and planning one opens the plan with the work linked and filled in', (tester) async {
      final f = await _pump(tester, (ref) => const SingleChildScrollView(child: BookingContentCard(bookingId: 'b1')), content: {..._FakePortfolio().content, 'shoots': []});
      expect(_k('bookingContentNone'), findsOneWidget);
      expect(find.text('Plan a shoot for this work'), findsOneWidget);
      await tester.tap(_k('bookingContentPlan'));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(_k('shoot_title')).controller!.text, 'Anjali – Bridal Makeup');
      expect(find.text('26111234 · Anjali · 20 Nov'), findsOneWidget, reason: 'the work is already linked');
      await tester.tap(_k('shoot_save'));
      await tester.pumpAndSettle();
      expect(f.p.saved.single.body['bookingId'], 'b1');
      expect(f.p.saved.single.body['shootDate'], '2026-11-20');
    });

    testWidgets('fits a phone without overflow', (tester) async {
      await _pump(tester, (ref) => const SingleChildScrollView(child: BookingContentCard(bookingId: 'b1')), size: const Size(360, 900));
      expect(tester.takeException(), isNull);
    });
  });

  group('what the service asks the server for', () {
    test('booking and shoot options, a booking\'s content, and the whole report for the export', () async {
      final seen = <RequestOptions>[];
      final s = MarketingPortfolioService(Dio()..httpClientAdapter = _Capture(seen));
      final f = TeamFilter(from: DateTime(2026, 11, 1), to: DateTime(2026, 11, 30));
      await s.bookingOptions(q: ' anjali ', around: '2026-11-20');
      await s.shootOptions();
      await s.bookingContent('b1');
      await s.allReports(f, const ReportQuery(filter: 'delayed'));
      expect(seen.map((r) => r.path), ['/marketing/portfolio/booking-options', '/marketing/portfolio/shoot-options', '/marketing/portfolio/bookings/b1/content', '/marketing/portfolio/reports']);
      expect(seen[0].queryParameters, {'q': 'anjali', 'around': '2026-11-20'});
      expect(seen[1].queryParameters, isEmpty);
      expect(seen[3].queryParameters, containsPair('all', 1));
      expect(seen[3].queryParameters, containsPair('filter', 'delayed'));
    });
  });
}
