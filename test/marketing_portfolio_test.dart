import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:nizan_crm/core/theme/app_theme.dart';
import 'package:nizan_crm/features/marketing/data/portfolio_models.dart';
import 'package:nizan_crm/features/marketing/data/socials_models.dart';
import 'package:nizan_crm/features/marketing/data/team_models.dart';
import 'package:nizan_crm/features/marketing/presentation/portfolio/portfolio_screen.dart';
import 'package:nizan_crm/features/marketing/presentation/portfolio/portfolio_widgets.dart';
import 'package:nizan_crm/features/marketing/services/portfolio_service.dart';
import 'package:nizan_crm/features/marketing/services/socials_service.dart';
import 'package:nizan_crm/features/marketing/services/team_service.dart';

// The Creative Portfolio: Shoot Planner, Production Calendar, Shoot Reports, Gallery — and the shoot picker in the Log Activity form.

List<Map<String, dynamic>> _milestones({int done = 2}) => [
      for (final (i, k) in ['brief', 'pre_production', 'production', 'post_production', 'distribution'].indexed) {'key': k, 'label': kMilestoneLabels[k], 'date': '2026-11-${10 + i}', 'doneAt': i < done ? '2026-11-0${5 + i}T05:00:00.000Z' : null},
    ];

Map<String, dynamic> _shoot(String id, {String title = 'Bridal Transformation – Nov', String status = 'pre_production', String brand = 'main', int progress = 40, Map<String, int>? planned, Map<String, int>? delivered, int? turnaround, bool delayed = false, int crew = 3, String date = '2026-11-10'}) => {
      'id': id, 'title': title, 'brand': brand, 'category': 'Bridal Makeup', 'shootType': 'Full Shoot', 'status': status, 'shootDate': date, 'startTime': '09:00', 'endTime': '17:00', 'location': 'Studio 1, Kozhikode', 'coverUrl': '',
      'crewCount': crew, 'progress': progress, 'planned': planned ?? {'reels': 3, 'stills': 10, 'films': 1}, 'plannedTotal': (planned ?? {'reels': 3, 'stills': 10, 'films': 1}).values.fold(0, (a, b) => a + b),
      'delivered': delivered ?? {'reels': 1}, 'deliveredTotal': (delivered ?? {'reels': 1}).values.fold(0, (a, b) => a + b), 'turnaround': turnaround, 'rescheduleCount': 0, 'delayed': delayed,
    };

Map<String, dynamic> _detail(String id, {String status = 'pre_production'}) => {
      ..._shoot(id, status: status),
      'pillar': 'Bridal · Transformation · Trust',
      'brief': {'objective': 'Showcase the complete bridal transformation', 'audience': 'Brides (Kerala, 22–35)', 'notes': 'Bring the gold set'},
      'crew': [{'memberId': 'm1', 'name': 'Ashique', 'role': 'Videographer'}, {'memberId': null, 'name': 'Makeup artist', 'role': 'Makeup'}],
      'references': [{'label': 'Moodboard', 'url': 'https://d.test/mood'}],
      'milestones': _milestones(),
      'currentMilestone': 'production',
      'assets': [
        {'id': 'a1', 'title': 'Reel 1', 'kind': 'reel', 'media': 'video', 'stage': 'approved', 'url': 'https://d.test/r1', 'thumbUrl': '', 'isFinal': false, 'durationSec': 30, 'sizeMb': 1024, 'createdAt': '2026-11-12T05:00:00.000Z'},
        {'id': 'a2', 'title': 'Still 1', 'kind': 'still', 'media': 'image', 'stage': 'in_review', 'url': 'https://d.test/s1', 'thumbUrl': '', 'isFinal': false, 'durationSec': 0, 'sizeMb': 0, 'createdAt': '2026-11-12T05:00:00.000Z'},
      ],
      'footageMb': 1024,
      'takeaways': ['1 of 14 planned outputs delivered so far.'],
      'activity': [{'id': 'l1', 'member': 'Preethi', 'workedOn': 'Moodboard approved', 'stage': 'pre_production', 'status': 'completed', 'day': '2026-11-06'}],
    };

Map<String, dynamic> _planner() => {
      'counts': {'total': 12, 'planned': 4, 'inProduction': 2, 'postProduction': 1, 'completed': 5, 'rescheduled': 1, 'thisWeek': 3, 'today': 1},
      'total': 12, 'page': 1, 'pageSize': 5,
      'items': [_shoot('s1'), _shoot('s2', title: 'Party Makeup Series', status: 'planned', progress: 20), _shoot('s3', title: 'Kerala Mehendi', status: 'in_production', brand: 'kerala', progress: 60)],
    };

Map<String, dynamic> _calendar() => {
      'day': '2026-11-10',
      'counts': {'total': 18, 'planned': 6, 'inProduction': 5, 'postProduction': 4, 'completed': 3, 'rescheduled': 2, 'thisWeek': 3, 'today': 1},
      // the 10th of whatever month the test runs in, so the month grid and the list view always have them
      'items': [_shoot('s1', date: DateFormat('yyyy-MM-10').format(DateTime.now())), _shoot('s2', title: 'Party Makeup Series', status: 'planned', date: DateFormat('yyyy-MM-11').format(DateTime.now()))],
      'today': [{..._shoot('s1', status: 'in_production'), 'milestones': _milestones()}],
      'upcoming': [_shoot('s4', title: 'Client Testimonial', status: 'planned')],
      'load': {'total': 18, 'rows': [{'key': 'pre_production', 'label': 'Pre-production', 'count': 4, 'pct': 22}, {'key': 'in_production', 'label': 'Production', 'count': 5, 'pct': 28}, {'key': 'post_production', 'label': 'Post-production', 'count': 4, 'pct': 22}, {'key': 'completed', 'label': 'Completed', 'count': 5, 'pct': 28}]},
      'availability': [{'role': 'Videographer', 'total': 5, 'booked': 1, 'onLeave': 0, 'available': 4}, {'role': 'Video Editor', 'total': 4, 'booked': 2, 'onLeave': 1, 'available': 1}],
    };

Map<String, dynamic> _reports() => {
      'kpis': {'shoots': 18, 'completed': 14, 'outputs': 56, 'footageGb': 92.8, 'turnaround': 3.4, 'change': {'shoots': 12, 'completed': 27, 'outputs': 40, 'footageGb': 18, 'turnaround': -26}},
      'monthly': [for (final (i, m) in ['2026-07', '2026-08', '2026-09', '2026-10', '2026-11'].indexed) {'month': m, 'shoots': 3, 'planned': 10 + i, 'delivered': 8 + i, 'turnaround': 5.0 - i * 0.5}],
      'distribution': {'total': 56, 'rows': [{'key': 'reels', 'label': 'Reels', 'count': 20, 'pct': 36}, {'key': 'stills', 'label': 'Stills / Photos', 'count': 14, 'pct': 25}]},
      'filters': {'all': 18, 'completed': 14, 'in_production': 3, 'delayed': 1},
      'total': 18, 'page': 1, 'pageSize': 8,
      'rows': [_shoot('s1', status: 'completed', turnaround: 3, delivered: {'reels': 3, 'stills': 10, 'films': 1}), _shoot('s2', title: 'Party Makeup Series', status: 'in_production', delayed: true, delivered: {'reels': 1})],
    };

class _FakePortfolio extends MarketingPortfolioService {
  _FakePortfolio() : super(Dio());
  final planners = <({TeamFilter f, PlannerQuery q})>[];
  final reportQueries = <ReportQuery>[];
  final calendars = <({String from, String to, String brand})>[];
  final saved = <({Map<String, dynamic> body, String? id})>[];
  final deleted = <String>[];
  TeamRefusal? refuse;
  bool plannerFails = false;
  Map<String, dynamic> plannerJson = _planner();

  @override
  Future<PlannerData> planner(TeamFilter f, PlannerQuery q) async {
    planners.add((f: f, q: q));
    if (plannerFails) throw Exception('boom');
    return PlannerData.fromJson(plannerJson);
  }

  @override
  Future<ShootDetail> shoot(String id) async => ShootDetail.fromJson(_detail(id));

  @override
  Future<ProductionCalendar> calendar(TeamFilter f, {String? day}) async {
    calendars.add((from: f.fromDay, to: f.toDay, brand: f.brand.wire));
    return ProductionCalendar.fromJson(_calendar());
  }

  @override
  Future<ShootReports> reports(TeamFilter f, ReportQuery q) async {
    reportQueries.add(q);
    return ShootReports.fromJson(_reports());
  }

  @override
  Future<ShootSetup> setup() async => ShootSetup.fromJson({'members': [{'id': 'm1', 'name': 'Ashique', 'role': 'Videographer'}, {'id': 'm2', 'name': 'Preethi', 'role': 'Video Editor'}], 'categories': ['Bridal Makeup'], 'pillars': [], 'shootTypes': ['Full Shoot', 'Quick']});

  @override
  Future<ShootSummary> saveShoot(Map<String, dynamic> body, {String? id}) async {
    if (refuse != null) throw refuse!;
    saved.add((body: body, id: id));
    return ShootSummary.fromJson(_shoot(id ?? 'new'));
  }

  @override
  Future<void> deleteShoot(String id) async {
    if (refuse != null) throw refuse!;
    deleted.add(id);
  }
}

class _FakeSocials extends MarketingSocialsService {
  _FakeSocials() : super(Dio());
  final assetQueries = <AssetQuery>[];
  final savedAssets = <({Map<String, dynamic> body, String? id})>[];

  @override
  Future<AssetList> assets(AssetQuery q) async {
    assetQueries.add(q);
    return AssetList.fromJson({
      'items': [
        {'id': 'g1', 'title': 'SkyBride_Exterior.mp4', 'brand': 'main', 'kind': 'reel', 'media': 'video', 'stage': 'approved', 'url': 'https://d.test/a', 'thumbUrl': '', 'portfolio': 'Main (Company)', 'page': 'Bridal Makeup', 'tags': [], 'durationSec': 42, 'sizeMb': 0, 'isFinal': true},
      ],
      'counts': {'total': 1248, 'photos': 432, 'videos': 186, 'finals': 58, 'approved': 52, 'approvedPct': 4, 'postProducedPct': 96},
      'facets': {'portfolios': {'Main (Company)': 520, 'Kerala': 180}, 'pages': {'Bridal Makeup': 248, 'Party Makeup': 86}, 'stages': {'approved': 432, 'raw': 120}, 'media': {'video': 186, 'image': 432}, 'kinds': {}},
    });
  }

  @override
  Future<Asset> saveAsset(Map<String, dynamic> body, {String? id}) async {
    savedAssets.add((body: body, id: id));
    return Asset.fromJson({'id': id ?? 'n', ...body});
  }
}

class _NoTeam extends MarketingTeamService {
  _NoTeam() : super(Dio());
  @override
  Future<LogSetup> logSetup({required String date, String? memberId}) async => throw Exception('no team in this test');
}

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

Future<({_FakePortfolio p, _FakeSocials s})> _pump(WidgetTester tester, {String tab = 'planner', _FakePortfolio? fake, Size size = const Size(1280, 1800)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final p = fake ?? _FakePortfolio();
  final s = _FakeSocials();
  final overrides = <Override>[marketingPortfolioServiceProvider.overrideWithValue(p), marketingSocialsServiceProvider.overrideWithValue(s), marketingTeamServiceProvider.overrideWithValue(_NoTeam())];
  await tester.pumpWidget(ProviderScope(overrides: overrides, child: MaterialApp(theme: AppTheme.lightTheme, home: Scaffold(body: PortfolioScreen(initialTab: tab)))));
  await tester.pumpAndSettle();
  return (p: p, s: s);
}

Finder _k(String key) => find.byKey(Key(key));
String _text(WidgetTester t, Finder f) => t.widget<Text>(f).data!;

void main() {
  group('how the payloads read', () {
    test('a shoot summary reads its plan, delivery and progress; a missing part is empty rather than a crash', () {
      final s = ShootSummary.fromJson(_shoot('s1', delivered: {'reels': 2, 'stills': 1}, turnaround: 4));
      expect(s.plannedTotal, 14);
      expect(s.deliveredTotal, 3);
      expect(s.turnaround, 4);
      expect(s.time, '09:00 – 17:00');
      expect(shootStatusLabel('in_production'), 'In Production');
      expect(shootStatusLabel('weird'), 'weird');
      final empty = ShootSummary.fromJson(const {'id': 'x', 'title': 'x'});
      expect(empty.brand, 'main');
      expect(empty.time, '');
      expect(empty.turnaround, isNull);
      expect(PlannerData.fromJson(const {}).page, 1);
    });

    test('a detail reads the milestones, crew, references, assets and activity', () {
      final d = ShootDetail.fromJson(_detail('s1'));
      expect(d.milestones.where((m) => m.done).length, 2);
      expect(d.milestones.first.label, 'Brief');
      expect(d.crew.first.memberId, 'm1');
      expect(d.crew.last.memberId, isNull);
      expect(d.crew.first.toJson(), {'memberId': 'm1', 'name': 'Ashique', 'role': 'Videographer'});
      expect(d.references.single.url, 'https://d.test/mood');
      expect(d.assets.length, 2);
      expect(d.footageMb, 1024);
      expect(d.activity.single.stage, 'pre_production');
    });

    test('query objects are compared by their parts', () {
      expect(const PlannerQuery(status: 'completed') == const PlannerQuery(status: 'completed'), isTrue);
      expect(const PlannerQuery(status: 'completed') == const PlannerQuery(), isFalse);
      expect(const PlannerQuery(page: 2) == const PlannerQuery(), isFalse);
      expect(const ReportQuery(q: 'a') == const ReportQuery(q: 'b'), isFalse);
      expect(const ReportQuery(filter: 'delayed').hashCode == const ReportQuery(filter: 'delayed').hashCode, isTrue);
    });
  });

  group('the Creative Portfolio screen', () {
    testWidgets('has the four tabs the document draws and the New Shoot Plan button', (tester) async {
      await _pump(tester);
      for (final t in kPortfolioTabs) {
        expect(_k('pf_tab_${t.$1}'), findsOneWidget, reason: t.$1);
      }
      expect(kPortfolioTabs.map((t) => t.$1).toList(), ['planner', 'calendar', 'reports', 'gallery']);
      expect(_k('pf_new_shoot'), findsOneWidget);
      expect(find.text('Creative Portfolio'), findsWidgets);
    });

    testWidgets('a tab can be opened from a link (?tab=…)', (tester) async {
      await _pump(tester, tab: 'gallery');
      expect(_k('portfolio_gallery_list'), findsOneWidget);
    });
  });

  group('Shoot Planner', () {
    testWidgets('the KPI strip, the plans and the first plan open with its facts', (tester) async {
      await _pump(tester);
      expect(find.descendant(of: _k('pf_kpi_planned'), matching: find.text('4')), findsOneWidget);
      expect(find.descendant(of: _k('pf_kpi_production'), matching: find.text('2')), findsOneWidget);
      expect(find.descendant(of: _k('pf_kpi_post'), matching: find.text('1')), findsOneWidget);
      expect(find.descendant(of: _k('pf_kpi_completed'), matching: find.text('5')), findsOneWidget);
      expect(find.descendant(of: _k('pf_kpi_week'), matching: find.text('3')), findsOneWidget);
      expect(_k('pf_plan_s1'), findsOneWidget);
      expect(find.descendant(of: _k('pf_plan_s3'), matching: find.text('In Production')), findsOneWidget);
      expect(find.text('Studio 1, Kozhikode'), findsOneWidget, reason: 'the first plan is open');
      expect(find.text('Showing 1–3 of 12'), findsOneWidget);
    });

    testWidgets('the brief, planned outputs, milestones and the progress ring', (tester) async {
      await _pump(tester);
      expect(find.text('Showcase the complete bridal transformation'), findsOneWidget);
      expect(find.text('Bridal · Transformation · Trust'), findsOneWidget);
      expect(find.text('3 reels'), findsOneWidget);
      expect(find.text('10 stills'), findsOneWidget);
      expect(_text(tester, _k('shoot_progress_pct')), '40%');
      for (final k in ['brief', 'pre_production', 'production', 'post_production', 'distribution']) {
        expect(_k('milestone_$k'), findsOneWidget, reason: k);
      }
      expect(find.textContaining('Moodboard approved'), findsOneWidget, reason: 'the work logged against the shoot is shown');
    });

    testWidgets('picking another plan opens it', (tester) async {
      await _pump(tester);
      await tester.tap(_k('pf_plan_s3'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('detail_s3')), findsOneWidget);
    });

    testWidgets('the status chips, search and paging ask the server for exactly that', (tester) async {
      final f = await _pump(tester);
      await tester.ensureVisible(_k('pf_status_completed'));
      await tester.tap(_k('pf_status_completed'));
      await tester.pumpAndSettle();
      expect(f.p.planners.last.q.status, 'completed');
      await tester.enterText(_k('pf_search'), 'party');
      await tester.pumpAndSettle();
      expect(f.p.planners.last.q.q, 'party');
      expect(f.p.planners.last.q.status, 'completed', reason: 'the status stays when you search');
    });

    testWidgets('paging: next goes to page 2 when there are more', (tester) async {
      final f = await _pump(tester);
      expect(tester.widget<IconButton>(_k('pf_prev')).onPressed, isNull, reason: 'nothing before the first page');
      expect(tester.widget<IconButton>(_k('pf_next')).onPressed, isNotNull);
      await tester.tap(_k('pf_next'));
      await tester.pumpAndSettle();
      expect(f.p.planners.last.q.page, 2);
    });

    testWidgets('the parts: moodboard links, content plan (planned against delivered), crew, approvals', (tester) async {
      final f = await _pump(tester);
      await tester.tap(_k('pf_part_moodboard'));
      await tester.pumpAndSettle();
      expect(find.text('Moodboard'), findsWidgets);
      await tester.tap(_k('pf_part_plan'));
      await tester.pumpAndSettle();
      expect(find.descendant(of: _k('pf_plan'), matching: find.text('1 / 3')), findsOneWidget, reason: 'reels: 1 delivered of 3 planned');
      expect(find.descendant(of: _k('pf_plan'), matching: find.text('0 / 10')), findsOneWidget);
      expect(find.text('Reel 1'), findsOneWidget);
      await tester.tap(_k('pf_part_crew'));
      await tester.pumpAndSettle();
      expect(find.text('Ashique'), findsOneWidget);
      expect(find.text('Makeup'), findsOneWidget);
      await tester.tap(_k('pf_part_approvals'));
      await tester.pumpAndSettle();
      expect(_k('pf_approve_a1'), findsNothing, reason: 'an approved asset has nothing to approve');
      await tester.tap(_k('pf_approve_a2'));
      await tester.pumpAndSettle();
      expect(f.s.savedAssets.single.id, 'a2');
      expect(f.s.savedAssets.single.body, {'stage': 'approved'});
    });

    testWidgets('changing the status from the pill saves it; a refusal is shown', (tester) async {
      final f = await _pump(tester);
      await tester.tap(_k('shoot_status_pill'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Completed').last);
      await tester.pumpAndSettle();
      expect(f.p.saved.single.id, 's1');
      expect(f.p.saved.single.body, {'status': 'completed'});
      f.p.refuse = const TeamRefusal('Only a Marketing Manager can do that.', status: 403);
      await tester.tap(_k('shoot_status_pill'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelled').last);
      await tester.pumpAndSettle();
      expect(find.text('Only a Marketing Manager can do that.'), findsOneWidget);
    });

    testWidgets('delete asks first and deletes only on confirm; a refusal (it has assets) is explained', (tester) async {
      final f = await _pump(tester);
      await tester.tap(_k('shoot_menu'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(f.p.deleted, isEmpty);
      f.p.refuse = const TeamRefusal('This shoot has 2 assets. Cancel it instead, so the record stays.', status: 409);
      await tester.tap(_k('shoot_menu'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete').last);
      await tester.pumpAndSettle();
      await tester.tap(_k('shoot_delete_confirm'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Cancel it instead'), findsOneWidget);
    });

    testWidgets('no plans says how to start; a failing source says so with Try again', (tester) async {
      await _pump(tester, fake: _FakePortfolio()..plannerJson = {'counts': {}, 'total': 0, 'items': []});
      expect(find.textContaining('No shoot plan in this period'), findsOneWidget);
      expect(find.textContaining('Plan a shoot to see its brief'), findsOneWidget);
      await _pump(tester, fake: _FakePortfolio()..plannerFails = true);
      expect(find.text('Try again'), findsOneWidget);
    });
  });

  group('the shoot form', () {
    testWidgets('a title is needed; a filled plan is sent with its crew, times and planned outputs', (tester) async {
      final f = await _pump(tester);
      await tester.tap(_k('pf_new_shoot'));
      await tester.pumpAndSettle();
      await tester.tap(_k('shoot_save'));
      await tester.pumpAndSettle();
      expect(find.text('Give the shoot a title.'), findsOneWidget);
      expect(f.p.saved, isEmpty);
      await tester.enterText(_k('shoot_title'), 'Festive Look');
      await tester.enterText(_k('shoot_category'), 'Party Makeup');
      await tester.enterText(_k('shoot_planned_reels'), '2');
      await tester.enterText(_k('shoot_planned_stills'), '8');
      await tester.enterText(_k('shoot_other_crew'), 'Makeup artist – Makeup, Model');
      await tester.ensureVisible(_k('shoot_crew_m1'));
      await tester.tap(_k('shoot_crew_m1'));
      await tester.pumpAndSettle();
      await tester.tap(_k('shoot_save'));
      await tester.pumpAndSettle();
      final b = f.p.saved.single.body;
      expect(f.p.saved.single.id, isNull);
      expect(b['title'], 'Festive Look');
      expect(b['category'], 'Party Makeup');
      expect(b['brand'], 'main');
      expect(b['shootType'], 'Full Shoot');
      expect(b['planned'], containsPair('reels', 2));
      expect(b['planned'], containsPair('stills', 8));
      expect(b['planned'], containsPair('films', 0));
      expect(b['crew'], [
        {'memberId': 'm1', 'name': 'Ashique', 'role': 'Videographer'},
        {'name': 'Makeup artist', 'role': 'Makeup'},
        {'name': 'Model', 'role': ''},
      ]);
      expect(b['startTime'], '');
      expect(b.containsKey('status'), isFalse, reason: 'a new plan starts Planned');
    });

    testWidgets('the brand chosen is the brand sent; a refusal from the server is shown in the form', (tester) async {
      final f = _FakePortfolio()..refuse = const TeamRefusal('The shoot has to end after it starts.');
      await _pump(tester, fake: f);
      await tester.tap(_k('pf_new_shoot'));
      await tester.pumpAndSettle();
      await tester.enterText(_k('shoot_title'), 'Kerala reel day');
      await tester.tap(_k('shoot_brand'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kerala').last);
      await tester.pumpAndSettle();
      await tester.tap(_k('shoot_save'));
      await tester.pumpAndSettle();
      expect(find.text('The shoot has to end after it starts.'), findsOneWidget);
      f.refuse = null;
      await tester.tap(_k('shoot_save'));
      await tester.pumpAndSettle();
      expect(f.saved.single.body['brand'], 'kerala');
    });

    testWidgets('editing opens the plan filled in and sends the change with its id and status', (tester) async {
      final f = await _pump(tester);
      await tester.tap(_k('shoot_menu'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit plan'));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(_k('shoot_title')).controller!.text, 'Bridal Transformation – Nov');
      expect(tester.widget<TextField>(_k('shoot_planned_reels')).controller!.text, '3');
      expect(tester.widget<TextField>(_k('shoot_other_crew')).controller!.text, 'Makeup artist – Makeup');
      await tester.enterText(_k('shoot_title'), 'Bridal Transformation v2');
      await tester.tap(_k('shoot_save'));
      await tester.pumpAndSettle();
      expect(f.p.saved.single.id, 's1');
      expect(f.p.saved.single.body['title'], 'Bridal Transformation v2');
      expect(f.p.saved.single.body['status'], 'pre_production');
    });
  });

  group('Production Calendar', () {
    testWidgets('the KPI strip, the month grid with the shoots, today\'s production with its progress, upcoming shoots', (tester) async {
      final f = await _pump(tester, tab: 'calendar');
      expect(f.p.calendars, isNotEmpty);
      expect(find.descendant(of: _k('pc_kpi_scheduled'), matching: find.text('18')), findsOneWidget);
      expect(find.descendant(of: _k('pc_kpi_production'), matching: find.text('5')), findsOneWidget);
      expect(find.descendant(of: _k('pc_kpi_rescheduled'), matching: find.text('2')), findsOneWidget);
      expect(_k('pc_month_grid'), findsOneWidget);
      expect(_k('pc_shoot_s1'), findsWidgets);
      expect(_k('pc_today_s1'), findsOneWidget);
      expect(find.text('Shoot Progress'), findsOneWidget);
      expect(find.descendant(of: _k('pc_upcoming_s4'), matching: find.text('Client Testimonial')), findsOneWidget);
    });

    testWidgets('the production load donut and the crew availability per role', (tester) async {
      await _pump(tester, tab: 'calendar');
      expect(_text(tester, _k('pc_load_total')), '18');
      expect(find.descendant(of: _k('pc_role_Videographer'), matching: find.text('4 / 5 Available')), findsOneWidget);
      expect(find.descendant(of: _k('pc_role_Video Editor'), matching: find.text('1 / 4 Available')), findsOneWidget);
      expect(find.descendant(of: _k('pc_role_Video Editor'), matching: find.text('1 on leave')), findsOneWidget);
    });

    testWidgets('next month asks for that month; the list view is a table of the month\'s shoots', (tester) async {
      final f = await _pump(tester, tab: 'calendar');
      final before = f.p.calendars.length;
      final now = DateTime.now();
      expect(_text(tester, _k('pc_title')), DateFormat('MMMM yyyy').format(DateTime(now.year, now.month)));
      await tester.tap(_k('pc_next'));
      await tester.pumpAndSettle();
      expect(_text(tester, _k('pc_title')), DateFormat('MMMM yyyy').format(DateTime(now.year, now.month + 1)));
      expect(f.p.calendars.length, greaterThan(before));
      expect(f.p.calendars.last.from.compareTo(f.p.calendars[before - 1].from), greaterThan(0));
      await tester.tap(_k('pc_prev'));
      await tester.pumpAndSettle();
      expect(_text(tester, _k('pc_title')), DateFormat('MMMM yyyy').format(DateTime(now.year, now.month)));
      await tester.tap(_k('pc_view_list'));
      await tester.pumpAndSettle();
      expect(_k('pc_list_table'), findsOneWidget);
      expect(_k('pc_list_s1'), findsOneWidget);
      expect(find.descendant(of: _k('pc_list_s2'), matching: find.text('Planned')), findsOneWidget);
      await tester.tap(_k('pc_view_week'));
      await tester.pumpAndSettle();
      expect(_k('pc_week_row'), findsOneWidget);
    });
  });

  group('Shoot Reports', () {
    testWidgets('the KPI strip with its changes (a shorter turnaround is good news)', (tester) async {
      await _pump(tester, tab: 'reports');
      expect(find.descendant(of: _k('sr_kpi_shoots'), matching: find.text('18')), findsOneWidget);
      expect(find.descendant(of: _k('sr_kpi_shoots'), matching: find.text('↑ +12% vs last period')), findsOneWidget);
      expect(find.descendant(of: _k('sr_kpi_footage'), matching: find.text('92.8 GB')), findsOneWidget);
      expect(find.descendant(of: _k('sr_kpi_turnaround'), matching: find.text('3.4 Days')), findsOneWidget);
      expect(find.descendant(of: _k('sr_kpi_turnaround'), matching: find.text('↓ −26% vs last period')), findsOneWidget);
      final note = tester.widget<Text>(find.descendant(of: _k('sr_kpi_turnaround'), matching: find.text('↓ −26% vs last period')));
      expect(note.style!.color, const Color(0xFF22A06B), reason: 'a fall in turnaround is green');
      final up = tester.widget<Text>(find.descendant(of: _k('sr_kpi_shoots'), matching: find.text('↑ +12% vs last period')));
      expect(up.style!.color, const Color(0xFF22A06B));
    });

    testWidgets('the charts hold their data; the rows show delivered against planned', (tester) async {
      await _pump(tester, tab: 'reports');
      expect(_k('sr_completion_chart'), findsOneWidget);
      expect(_k('sr_efficiency_chart'), findsOneWidget);
      expect(_text(tester, _k('sr_dist_total')), '56');
      expect(find.descendant(of: _k('sr_row_s1'), matching: find.text('14 of 14')), findsOneWidget);
      expect(find.descendant(of: _k('sr_row_s1'), matching: find.text('3 Days')), findsOneWidget);
      expect(find.descendant(of: _k('sr_row_s2'), matching: find.text('1 of 14')), findsOneWidget);
      expect(find.descendant(of: _k('sr_row_s2'), matching: find.text('—')), findsOneWidget, reason: 'no turnaround yet');
      expect(find.descendant(of: _k('sr_row_s2'), matching: find.byIcon(Icons.warning_amber_rounded)), findsOneWidget, reason: 'a delayed shoot is flagged');
    });

    testWidgets('the filter chips carry their counts and ask the server for that cut; search is sent', (tester) async {
      final f = await _pump(tester, tab: 'reports');
      expect(find.descendant(of: _k('sr_filter_completed'), matching: find.text('14')), findsOneWidget);
      expect(find.descendant(of: _k('sr_filter_delayed'), matching: find.text('1')), findsOneWidget);
      await tester.tap(_k('sr_filter_delayed'));
      await tester.pumpAndSettle();
      expect(f.p.reportQueries.last.filter, 'delayed');
      await tester.enterText(_k('sr_search'), 'party');
      await tester.pumpAndSettle();
      expect(f.p.reportQueries.last.q, 'party');
      expect(f.p.reportQueries.last.filter, 'delayed');
    });

    testWidgets('a row opens that shoot\'s report: overview, assets, checklist, team and the takeaways', (tester) async {
      await _pump(tester, tab: 'reports');
      expect(find.text('Showing 1–2 of 18'), findsOneWidget);
      expect(_text(tester, _k('sr_planned')), '3 reels, 10 stills, 1 films');
      expect(_text(tester, _k('sr_delivered')), '1 reels');
      expect(find.textContaining('Not yet — shows when every planned output is delivered'), findsOneWidget);
      expect(_text(tester, _k('sr_footage')), '1.0 GB');
      expect(find.text('1 of 14 planned outputs delivered so far.'), findsOneWidget);
      await tester.tap(_k('sr_part_assets'));
      await tester.pumpAndSettle();
      expect(find.text('Reel 1'), findsOneWidget);
      await tester.tap(_k('sr_part_checklist'));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.check_box_rounded), findsNWidgets(2), reason: 'Brief and Pre-production are done');
      expect(find.textContaining('Planned '), findsWidgets);
      await tester.tap(_k('sr_part_team'));
      await tester.pumpAndSettle();
      expect(find.text('Ashique'), findsOneWidget);
      await tester.tap(_k('sr_row_s2'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('report_s2')), findsOneWidget);
    });
  });

  group('Gallery', () {
    testWidgets('the six figures and the asset cards', (tester) async {
      await _pump(tester, tab: 'gallery');
      expect(find.descendant(of: _k('gl_kpi_total'), matching: find.text('1,248')), findsOneWidget);
      expect(find.descendant(of: _k('gl_kpi_photos'), matching: find.text('432')), findsOneWidget);
      expect(find.descendant(of: _k('gl_kpi_videos'), matching: find.text('186')), findsOneWidget);
      expect(find.descendant(of: _k('gl_kpi_finals'), matching: find.text('58')), findsOneWidget);
      expect(find.descendant(of: _k('gl_kpi_post'), matching: find.text('96%')), findsOneWidget);
      expect(_k('asset_g1'), findsOneWidget);
    });

    testWidgets('portfolio, page, stage and media filters carry their counts and narrow the query; tapping again clears', (tester) async {
      final f = await _pump(tester, tab: 'gallery');
      expect(find.descendant(of: _k('gl_portfolio_Kerala'), matching: find.text('180')), findsOneWidget);
      await tester.tap(_k('gl_portfolio_Kerala'));
      await tester.pumpAndSettle();
      expect(f.s.assetQueries.last.portfolio, 'Kerala');
      await tester.tap(_k('gl_page_Bridal Makeup'));
      await tester.pumpAndSettle();
      expect(f.s.assetQueries.last.page, 'Bridal Makeup');
      expect(f.s.assetQueries.last.portfolio, 'Kerala', reason: 'filters add up');
      await tester.tap(_k('gl_stage_approved'));
      await tester.pumpAndSettle();
      expect(f.s.assetQueries.last.stage, 'approved');
      await tester.tap(_k('gl_media_video'));
      await tester.pumpAndSettle();
      expect(f.s.assetQueries.last.media, 'video');
      await tester.tap(_k('gl_media_video'));
      await tester.pumpAndSettle();
      expect(f.s.assetQueries.last.media, isNull);
      await tester.enterText(_k('gl_search'), 'bridal');
      await tester.pumpAndSettle();
      expect(f.s.assetQueries.last.q, 'bridal');
    });

    testWidgets('Upload opens the asset form', (tester) async {
      await _pump(tester, tab: 'gallery');
      await tester.tap(_k('gl_upload'));
      await tester.pumpAndSettle();
      expect(_k('asset_title'), findsOneWidget);
      expect(_k('asset_url'), findsOneWidget);
    });
  });

  group('what the service asks the server for', () {
    Future<List<RequestOptions>> capture(Future<void> Function(MarketingPortfolioService s) run) async {
      final seen = <RequestOptions>[];
      await run(MarketingPortfolioService(Dio()..httpClientAdapter = _Capture(seen)));
      return seen;
    }

    final f = TeamFilter(from: DateTime(2026, 11, 1), to: DateTime(2026, 11, 30), brand: TeamBrand.kerala);

    test('every read carries the shared range and brand; the planner adds its cut', () async {
      final reqs = await capture((s) async {
        await s.planner(f, const PlannerQuery(status: 'completed', q: ' party ', page: 2));
        await s.calendar(f);
        await s.reports(f, const ReportQuery(filter: 'delayed', q: 'x'));
      });
      expect(reqs.map((r) => r.path), ['/marketing/portfolio/shoots', '/marketing/portfolio/calendar', '/marketing/portfolio/reports']);
      for (final r in reqs) {
        expect(r.queryParameters, containsPair('from', '2026-11-01'), reason: r.path);
        expect(r.queryParameters, containsPair('to', '2026-11-30'), reason: r.path);
        expect(r.queryParameters, containsPair('brand', 'kerala'), reason: r.path);
      }
      expect(reqs[0].queryParameters, containsPair('status', 'completed'));
      expect(reqs[0].queryParameters, containsPair('q', 'party'));
      expect(reqs[0].queryParameters, containsPair('page', 2));
      expect(reqs[2].queryParameters, containsPair('filter', 'delayed'));
    });

    test('"all" is not sent as a filter; saving posts or puts by whether there is an id', () async {
      final reqs = await capture((s) async {
        await s.planner(f, const PlannerQuery());
        await s.reports(f, const ReportQuery());
        await s.saveShoot({'title': 'x'});
        await s.saveShoot({'title': 'y'}, id: 's1');
        await s.deleteShoot('s1');
      });
      expect(reqs[0].queryParameters.containsKey('status'), isFalse);
      expect(reqs[0].queryParameters.containsKey('q'), isFalse);
      expect(reqs[1].queryParameters.containsKey('filter'), isFalse);
      expect([reqs[2].method, reqs[2].path], ['POST', '/marketing/portfolio/shoots']);
      expect([reqs[3].method, reqs[3].path], ['PUT', '/marketing/portfolio/shoots/s1']);
      expect([reqs[4].method, reqs[4].path], ['DELETE', '/marketing/portfolio/shoots/s1']);
    });

    test('a server refusal comes back as its own words', () async {
      final dio = Dio()..httpClientAdapter = _Capture([], status: 409, body: '{"message":"Cancel it instead, so the record stays."}');
      await expectLater(MarketingPortfolioService(dio).deleteShoot('s1'), throwsA(isA<TeamRefusal>().having((e) => e.message, 'message', 'Cancel it instead, so the record stays.')));
    });
  });

  group('the pieces', () {
    testWidgets('the milestone stepper ticks the done ones and marks where the shoot is', (tester) async {
      final ms = [for (final m in _milestones(done: 2)) Milestone.fromJson(m)];
      await tester.pumpWidget(MaterialApp(theme: AppTheme.lightTheme, home: Scaffold(body: Padding(padding: const EdgeInsets.all(16), child: MilestoneStepper(milestones: ms, current: 'production')))));
      expect(find.byIcon(Icons.check_rounded), findsNWidgets(2));
      expect(find.text('Production'), findsOneWidget);
      expect(find.text('Nov 12'), findsOneWidget);
    });

    test('statuses have their own colours', () {
      expect({for (final s in ['planned', 'pre_production', 'in_production', 'post_production', 'completed', 'cancelled']) shootStatusColor(s)}.length, 6);
      expect(shootDay('2026-11-10'), '10 Nov 2026');
      expect(shootDay('nonsense'), 'nonsense');
      expect(hhmm(const TimeOfDay(hour: 9, minute: 5)), '09:05');
    });
  });

  group('a phone', () {
    testWidgets('every tab fits a 390-wide screen without overflow', (tester) async {
      await _pump(tester, size: const Size(390, 2000));
      expect(tester.takeException(), isNull);
      for (final t in ['calendar', 'reports', 'gallery']) {
        await tester.tap(_k('pf_tab_$t'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: t);
      }
    });
  });
}
