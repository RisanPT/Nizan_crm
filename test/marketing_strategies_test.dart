import 'dart:async';

import 'package:dio/dio.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/theme/app_theme.dart';
import 'package:nizan_crm/features/marketing/data/strategy_models.dart';
import 'package:nizan_crm/features/marketing/data/team_models.dart';
import 'package:nizan_crm/features/marketing/presentation/kit/mkt_kit.dart';
import 'package:nizan_crm/features/marketing/presentation/strategies/strategies_screen.dart';
import 'package:nizan_crm/features/marketing/presentation/strategies/strategy_editors.dart' show reviewLinkOptions;
import 'package:nizan_crm/features/marketing/presentation/strategies/strategy_exports.dart';
import 'package:nizan_crm/features/marketing/presentation/strategies/strategy_research_tab.dart' show enquiryTrendValue, enquiryTrendNote;
import 'package:nizan_crm/features/marketing/presentation/strategies/strategy_widgets.dart';
import 'package:nizan_crm/features/marketing/services/strategy_service.dart';
import 'package:nizan_crm/features/marketing/services/team_service.dart';

// Strategies & Developments: Overview, Strategic Plans, Development Projects, Roadmap, Initiatives, Research & Insights, Reviews.
// Dates in the fixtures are fixed and mid-day, so nothing here depends on today.

Map<String, dynamic> _owner(String name, {String id = 'm1', String source = 'set'}) => {'id': id, 'name': name, 'source': source};

Map<String, dynamic> _work(
  String id, {
  String kind = 'initiative',
  String title = 'Launch Bridal Campaign v2',
  String status = 'on_track',
  int progress = 75,
  String source = 'tasks',
  bool noOwner = false,
  String ownerName = 'Abhiram',
  String ownerId = 'm9',
  String ownerSource = 'set',
  String? due = '2026-11-15',
  String dueSource = 'set',
  String focus = 'Revenue & Lead Growth',
  String category = 'Technology',
  String impact = 'high',
  String stored = 'active',
  int tasks = 4,
  int done = 3,
  int minutes = 0,
  int? typedProgress,
  String description = '',
  String? plan,
}) =>
    {
      'kind': kind, 'id': id, 'title': title, 'brand': 'main', 'focusArea': kind == 'project' ? '' : focus, 'category': kind == 'project' ? category : '', 'impact': kind == 'project' ? '' : impact,
      'description': description, 'notes': '', 'plan': plan == null ? null : {'id': 'p1', 'title': plan}, 'storedStatus': stored, 'status': status,
      'owner': noOwner ? null : _owner(ownerName, id: ownerId, source: ownerSource), 'progress': progress, 'progressSource': source, 'typedProgress': typedProgress,
      'taskCount': source == 'tasks' ? tasks : 0, 'doneCount': source == 'tasks' ? done : 0, 'start': '2026-11-01', 'typedStart': '2026-11-01', 'due': due, 'dueSource': due == null ? 'none' : dueSource, 'closedDay': null, 'minutes': minutes,
    };

Map<String, dynamic> _quarter(int q, String theme, List<Map<String, dynamic>> items, {int done = 0}) => {
      'quarter': q, 'label': 'Q$q', 'months': ['Jan – Mar', 'Apr – Jun', 'Jul – Sep', 'Oct – Dec'][q - 1], 'theme': theme, 'total': items.length, 'done': done, 'pct': items.isEmpty ? null : (done * 100 / items.length).round(), 'items': items,
    };

Map<String, dynamic> _line(String id, String title, int quarter, {bool done = false, String by = '', String link = ''}) => {
      'id': id, 'year': 2026, 'quarter': quarter, 'theme': '', 'title': title, 'brand': 'main', 'done': done, 'doneBy': by, 'doneAt': done ? '2026-11-10T12:00:00.000Z' : null, 'planId': null, 'initiativeId': null, 'link': link,
    };

Map<String, dynamic> _finding(String id, String title, String kind, {String author = 'Preethi', String authorId = 'm1', String link = '', String summary = 'A short summary'}) =>
    {'id': id, 'title': title, 'kind': kind, 'summary': summary, 'link': link, 'brand': 'main', 'date': '2026-11-10', 'tags': ['bridal'], 'author': author, 'authorId': authorId};

Map<String, dynamic> _review(String id, String period, {String type = 'quarterly', String date = '2026-10-05'}) => {
      'id': id, 'type': type, 'periodLabel': period, 'reviewDate': date, 'brand': 'main', 'summary': 'How the quarter went', 'createdBy': 'Meera',
      'outcomes': [
        {'text': 'Lead target achieved (102%)', 'state': 'achieved'},
        {'text': 'Brand engagement up 48%', 'state': 'achieved'},
        {'text': 'Kerala expansion in progress (60%)', 'state': 'partial'},
        {'text': 'New service launch delayed', 'state': 'missed'},
      ],
      'scores': {'total': 4, 'achieved': 2, 'partial': 1, 'missed': 1, 'achievedPct': 50, 'partialPct': 25, 'missedPct': 25, 'overall': 50},
      'actionItems': [
        {'id': 'a1', 'text': 'Complete bridal vertical go-to-market', 'owner': {'id': 'm1', 'name': 'Preethi'}, 'priority': 'high', 'targetDate': '2026-11-20', 'status': 'in_progress', 'overdue': false},
        {'id': 'a2', 'text': 'Finalise Kerala expansion locations', 'owner': {'id': 'm2', 'name': 'Ashique'}, 'priority': 'high', 'targetDate': '2026-10-01', 'status': 'open', 'overdue': true},
        {'id': 'a3', 'text': 'Review Q4 budget and strategy', 'owner': null, 'priority': 'medium', 'targetDate': null, 'status': 'done', 'overdue': false},
      ],
    };

Map<String, dynamic> _setup({bool manage = true, String? me = 'm1'}) => {
      'canManage': manage,
      'me': me == null ? null : {'id': me, 'name': 'Preethi'},
      'members': [{'id': 'm1', 'name': 'Preethi'}, {'id': 'm2', 'name': 'Ashique'}],
      'plans': [{'id': 'p1', 'title': 'Revenue plan', 'year': 2026}],
      'initiatives': [{'id': 'i1', 'title': 'Launch Bridal Campaign v2'}],
      'focusAreas': ['Revenue & Lead Growth', 'Operations'],
      'categories': ['Technology', 'Operations'],
    };

Map<String, dynamic> _overview() => {
      'year': 2026,
      'kpis': {'activeStrategies': 12, 'developmentProjects': 8, 'totalInitiatives': 24, 'onTrack': 18, 'atRisk': 4, 'newThisWeek': 2},
      'focusAreas': {'total': 12, 'rows': [{'focusArea': 'Brand & Market Positioning', 'count': 3}, {'focusArea': 'Revenue & Lead Growth', 'count': 3}, {'focusArea': 'Content & Creative Scale', 'count': 2}]},
      'roadmap': {
        'year': 2026,
        'quarters': [
          _quarter(1, 'Foundation', [_line('r1', 'Brand consolidation', 1, done: true), _line('r2', 'Content engine setup', 1, done: true), _line('r3', 'Process & tools', 1)], done: 2),
          _quarter(2, 'Growth', [_line('r4', 'Campaign scale-up', 2)]),
          _quarter(3, 'Expansion', []),
          _quarter(4, 'Optimization', [for (var i = 0; i < 6; i++) _line('o$i', 'Q4 line $i', 4)]),
        ],
      },
      'initiatives': [
        _work('i1'),
        _work('i2', title: 'CRM & Lead Automation', status: 'in_progress', progress: 0, source: 'none', noOwner: true, due: null),
        _work('i3', title: 'Content Production Scale', status: 'at_risk', progress: 40, ownerName: 'Ashique', source: 'owner', due: '2026-12-05'),
      ],
      'projects': [_work('d1', kind: 'project', title: 'Website v2', progress: 85, description: 'Brand site & portfolio upgrade'), _work('d2', kind: 'project', title: 'Content Asset Library', status: 'in_progress', progress: 60, category: 'Operations')],
      'performance': [
        {'focusArea': 'Brand & Market Positioning', 'progress': 92, 'initiatives': 3, 'measured': 2},
        {'focusArea': 'Revenue & Lead Growth', 'progress': 76, 'initiatives': 2, 'measured': 2},
        {'focusArea': 'Team Capability', 'progress': null, 'initiatives': 1, 'measured': 0},
      ],
      'recentUpdates': [
        {'kind': 'review', 'at': '2026-11-12T12:00:00.000Z', 'text': 'Q3 2026 review added', 'subtitle': 'Quarterly review', 'by': 'Meera'},
        {'kind': 'task_done', 'at': '2026-11-11T12:00:00.000Z', 'text': 'Hero reel completed', 'subtitle': 'Launch Bridal Campaign v2', 'by': 'Asha'},
      ],
      'research': [_finding('f1', 'Instagram Growth Trends – Nov 2026', 'market_insight'), _finding('f2', 'Studio Expansion Feasibility', 'report', link: 'https://d.test/studio')],
      'keyOutcomes': {'review': {'id': 'rv1', 'type': 'quarterly', 'periodLabel': 'Q3 2026', 'reviewDate': '2026-10-05'}, 'outcomes': _review('rv1', 'Q3 2026')['outcomes'], 'scores': _review('rv1', 'Q3 2026')['scores']},
    };

Map<String, dynamic> _plans() => {
      'counts': {'total': 7, 'active': 3, 'inProgress': 2, 'onHold': 1, 'completed': 4},
      'focusAreas': {'total': 3, 'rows': [{'focusArea': 'Brand Growth', 'count': 2}, {'focusArea': 'Revenue Growth', 'count': 1}]},
      'progress': {'total': 7, 'slices': [{'key': 'active', 'label': 'Active', 'count': 1, 'pct': 14}, {'key': 'in_progress', 'label': 'In Progress', 'count': 2, 'pct': 29}, {'key': 'on_hold', 'label': 'On Hold', 'count': 1, 'pct': 14}, {'key': 'completed', 'label': 'Completed', 'count': 3, 'pct': 43}]},
      'goals': [{'text': 'Increase qualified leads by 40%', 'plan': 'Brand plan', 'focusArea': 'Brand Growth'}, {'text': 'Launch 2 new service verticals', 'plan': 'Revenue plan', 'focusArea': 'Revenue Growth'}],
      'items': [
        {'id': 'p1', 'title': 'Brand plan', 'focusArea': 'Brand Growth', 'year': 2026, 'brand': 'main', 'status': 'active', 'statusLabel': 'Active', 'goals': ['Increase qualified leads by 40%', 'Improve engagement'], 'description': 'D', 'owner': {'id': 'm2', 'name': 'Ashique'}, 'initiativeCount': 3, 'projectCount': 1},
        {'id': 'p2', 'title': 'Revenue plan', 'focusArea': 'Revenue Growth', 'year': 2026, 'brand': 'main', 'status': 'in_progress', 'statusLabel': 'In Progress', 'goals': [], 'description': '', 'owner': null, 'initiativeCount': 0, 'projectCount': 0},
        {'id': 'p3', 'title': 'Team build', 'focusArea': 'Team', 'year': 2026, 'brand': 'main', 'status': 'on_hold', 'statusLabel': 'On Hold', 'goals': [], 'description': '', 'owner': null, 'initiativeCount': 0, 'projectCount': 0},
      ],
    };

Map<String, dynamic> _workList({String kind = 'initiative', List<Map<String, dynamic>>? items, int total = 24}) => {
      'counts': {'total': total, 'open': 17, 'completed': 4, 'onHold': 3, 'onTrack': 12, 'atRisk': 3, 'inProgress': 2},
      'focusAreas': ['Operations', 'Revenue & Lead Growth'],
      'total': total, 'page': 1, 'pageSize': 10,
      'items': items ?? [
        _work('i1', kind: kind, title: kind == 'project' ? 'Website v2' : 'Meta Lead Quality Improvement'),
        _work('i2', kind: kind, title: kind == 'project' ? 'CRM & Lead Automation' : 'Content Automation Workflow', status: 'at_risk', progress: 30, ownerName: 'Ashique'),
        _work('i3', kind: kind, title: kind == 'project' ? 'Kerala Plan' : 'Marketing Knowledge Hub', status: 'on_hold', source: 'none', progress: 0, noOwner: true, due: null),
      ],
    };

Map<String, dynamic> _roadmap() => {
      'year': 2026,
      'counts': {'items': 4, 'done': 1, 'pct': 25},
      'quarters': [_quarter(1, 'Foundation', [_line('r1', 'Brand consolidation', 1, done: true, by: 'Ravi', link: 'CRM & Lead Automation'), _line('r2', 'Process & tools', 1)], done: 1), _quarter(2, 'Growth', [_line('r4', 'Campaign scale-up', 2)]), _quarter(3, 'Expansion', []), _quarter(4, 'Optimization', [_line('r5', 'Performance review', 4)])],
      'timeline': {
        'year': 2026,
        'bars': [
          {'kind': 'initiative', 'id': 'i1', 'title': 'Brand Growth Campaign', 'owner': 'Abhiram', 'progress': 70, 'progressSource': 'tasks', 'status': 'on_track', 'start': '2026-01-15', 'end': '2026-04-30', 'from': 0.04, 'to': 0.33, 'startsBefore': false, 'endsAfter': false},
          {'kind': 'project', 'id': 'd1', 'title': 'Website v2', 'owner': '', 'progress': 0, 'progressSource': 'none', 'status': 'in_progress', 'start': '2026-04-01', 'end': '2026-09-30', 'from': 0.25, 'to': 0.75, 'startsBefore': false, 'endsAfter': false},
        ],
        'undated': [{'kind': 'initiative', 'id': 'i9', 'title': 'Hyderabad Studio Setup', 'owner': '', 'progress': 0, 'progressSource': 'none', 'status': 'in_progress', 'start': '2026-11-01', 'end': null, 'from': 0, 'to': 1}],
      },
    };

Map<String, dynamic> _research({int total = 7, int page = 1}) => {
      'counts': {'total': 28, 'report': 14, 'marketInsight': 6, 'competitor': 4, 'opportunity': 8},
      'keyInsights': [_finding('k1', 'Bridal search interest up by 32% in Kerala', 'market_insight', summary: 'Seasonal peak'), _finding('k2', 'Reels drive 74% of social reach', 'market_insight', author: 'Ashique', authorId: 'm2')],
      'opportunities': [_finding('o1', 'Expand bridal trials campaign', 'opportunity'), _finding('o2', 'Increase NRI-focused ads', 'opportunity')],
      'total': total, 'page': page, 'pageSize': 3,
      'items': [_finding('f1', 'Instagram Growth Trends', 'market_insight', link: 'https://d.test/ig'), _finding('f2', 'Competitor pricing sweep', 'competitor', author: 'Ashique', authorId: 'm2'), _finding('f3', 'Bridal Market Insights', 'report')],
    };

Map<String, dynamic> _reviews(String type) => {
      'type': type,
      'counts': {'strategy': 1, 'project': 0, 'campaign': 1, 'quarterly': 2},
      'items': type == 'quarterly' ? [_review('rv1', 'Q3 2026'), _review('rv2', 'Q2 2026', date: '2026-07-05')] : (type == 'strategy' ? [_review('rv3', 'Brand strategy', type: 'strategy')] : <Map<String, dynamic>>[]),
    };

Map<String, dynamic> _detail(String kind, String id) => {
      ..._work(id, kind: kind, title: kind == 'project' ? 'Website v2' : 'Launch Bridal Campaign v2', minutes: 135, plan: 'Revenue plan', description: 'Bridal campaign for the season', focus: 'Revenue & Lead Growth'),
      'tasks': [
        {'id': 't1', 'title': 'Shoot hero reel', 'assignee': 'Preethi', 'status': 'in_progress', 'progress': 50, 'dueDate': '2026-11-20', 'completedAt': null},
        {'id': 't2', 'title': 'Brief the creatives', 'assignee': 'Ashique', 'status': 'completed', 'progress': 100, 'dueDate': '2026-11-05', 'completedAt': '2026-11-04T12:00:00.000Z'},
      ],
      'logs': [{'id': 'l1', 'member': 'Preethi', 'workedOn': 'Campaign planning', 'minutes': 90, 'day': '2026-11-09', 'status': 'completed'}],
    };

class _FakeStrategies extends MarketingStrategyService {
  _FakeStrategies() : super(Dio());
  Map<String, dynamic> setupJson = _setup();
  Map<String, dynamic> overviewJson = _overview();
  Map<String, dynamic> plansJson = _plans();
  Map<String, dynamic> roadmapJson = _roadmap();
  Map<String, dynamic>? initiativesJson, projectsJson, researchJson, reviewsJson;
  bool overviewFails = false;
  bool plansFail = false;
  bool initiativesFail = false;
  TeamRefusal? refuse;
  Completer<void>? hold;
  final detailOverrides = <String, Map<String, dynamic>>{};

  final overviewFilters = <TeamFilter>[];
  final initiativeCalls = <({TeamFilter f, WorkQuery q, int? limit})>[];
  final projectCalls = <({TeamFilter f, WorkQuery q, int? limit})>[];
  final roadmapCalls = <({TeamFilter f, int? year})>[];
  final researchCalls = <({ResearchQuery q, int? limit})>[];
  final reviewCalls = <String>[];
  final detailCalls = <String>[];
  final plansSaved = <({Map<String, dynamic> body, String? id})>[];
  final plansDeleted = <String>[];
  final initiativesSaved = <({Map<String, dynamic> body, String? id})>[];
  final initiativesDeleted = <String>[];
  final projectsSaved = <({Map<String, dynamic> body, String? id})>[];
  final projectsDeleted = <String>[];
  final linesSaved = <({Map<String, dynamic> body, String? id})>[];
  final linesDeleted = <String>[];
  final ticks = <({String id, bool done})>[];
  final findingsSaved = <({Map<String, dynamic> body, String? id})>[];
  final findingsDeleted = <String>[];
  final reviewsSaved = <({Map<String, dynamic> body, String? id})>[];
  final reviewsDeleted = <String>[];
  final actions = <({String review, String action, String status})>[];

  Future<void> _gate() async {
    if (hold != null) await hold!.future;
    if (refuse != null) throw refuse!;
  }

  bool setupFails = false;
  Completer<void>? setupGate;
  int setupCalls = 0;

  @override
  Future<StrategySetup> setup() async {
    setupCalls += 1;
    if (setupGate != null) await setupGate!.future;
    if (setupFails) throw Exception('boom');
    return StrategySetup.fromJson(setupJson);
  }

  @override
  Future<StrategyOverview> overview(TeamFilter f) async {
    overviewFilters.add(f);
    if (overviewFails) throw Exception('boom');
    return StrategyOverview.fromJson(overviewJson);
  }

  @override
  Future<PlansData> plans(TeamFilter f) async {
    if (plansFail) throw Exception('boom');
    return PlansData.fromJson(plansJson);
  }

  @override
  Future<WorkList> initiatives(TeamFilter f, WorkQuery q, {int? limit}) async {
    initiativeCalls.add((f: f, q: q, limit: limit));
    if (initiativesFail) throw Exception('boom');
    return WorkList.fromJson({...(initiativesJson ?? _workList()), 'page': q.page});
  }

  @override
  Future<WorkList> projects(TeamFilter f, WorkQuery q, {int? limit}) async {
    projectCalls.add((f: f, q: q, limit: limit));
    return WorkList.fromJson({...(projectsJson ?? _workList(kind: 'project', total: 12)), 'page': q.page});
  }

  @override
  Future<WorkDetail> initiative(String id) async {
    detailCalls.add('initiative:$id');
    return WorkDetail.fromJson({..._detail('initiative', id), ...?detailOverrides[id]});
  }

  @override
  Future<WorkDetail> project(String id) async {
    detailCalls.add('project:$id');
    return WorkDetail.fromJson({..._detail('project', id), ...?detailOverrides[id]});
  }

  @override
  Future<RoadmapData> roadmap(TeamFilter f, {int? year}) async {
    roadmapCalls.add((f: f, year: year));
    return RoadmapData.fromJson({...roadmapJson, 'year': year ?? roadmapJson['year']});
  }

  @override
  Future<ResearchData> research(TeamFilter f, ResearchQuery q, {int? limit}) async {
    researchCalls.add((q: q, limit: limit));
    return ResearchData.fromJson({...(researchJson ?? _research()), 'page': q.page});
  }

  @override
  Future<ReviewsData> reviews(TeamFilter f, ReviewQuery q) async {
    reviewCalls.add(q.type);
    return ReviewsData.fromJson(reviewsJson ?? _reviews(q.type));
  }

  @override
  Future<PlanItem> savePlan(Map<String, dynamic> body, {String? id}) async {
    await _gate();
    plansSaved.add((body: body, id: id));
    return PlanItem.fromJson({'id': id ?? 'new', ...body});
  }

  @override
  Future<void> deletePlan(String id) async {
    await _gate();
    plansDeleted.add(id);
  }

  @override
  Future<WorkItem> saveInitiative(Map<String, dynamic> body, {String? id}) async {
    await _gate();
    initiativesSaved.add((body: body, id: id));
    return WorkItem.fromJson(_work(id ?? 'new'));
  }

  @override
  Future<void> deleteInitiative(String id) async {
    await _gate();
    initiativesDeleted.add(id);
  }

  @override
  Future<WorkItem> saveProject(Map<String, dynamic> body, {String? id}) async {
    await _gate();
    projectsSaved.add((body: body, id: id));
    return WorkItem.fromJson(_work(id ?? 'new', kind: 'project'));
  }

  @override
  Future<void> deleteProject(String id) async {
    await _gate();
    projectsDeleted.add(id);
  }

  @override
  Future<RoadmapLine> saveRoadmapLine(Map<String, dynamic> body, {String? id}) async {
    await _gate();
    linesSaved.add((body: body, id: id));
    return RoadmapLine.fromJson({'id': id ?? 'new', ...body});
  }

  @override
  Future<void> deleteRoadmapLine(String id) async {
    await _gate();
    linesDeleted.add(id);
  }

  @override
  Future<RoadmapLine> tickRoadmapLine(String id, {required bool done}) async {
    await _gate();
    ticks.add((id: id, done: done));
    return RoadmapLine.fromJson(_line(id, 'x', 1, done: done));
  }

  @override
  Future<Finding> saveFinding(Map<String, dynamic> body, {String? id}) async {
    await _gate();
    findingsSaved.add((body: body, id: id));
    return Finding.fromJson({'id': id ?? 'new', ...body});
  }

  @override
  Future<void> deleteFinding(String id) async {
    await _gate();
    findingsDeleted.add(id);
  }

  @override
  Future<StrategyReview> saveReview(Map<String, dynamic> body, {String? id}) async {
    await _gate();
    reviewsSaved.add((body: body, id: id));
    return StrategyReview.fromJson(_review(id ?? 'new', 'x'));
  }

  @override
  Future<void> deleteReview(String id) async {
    await _gate();
    reviewsDeleted.add(id);
  }

  @override
  Future<StrategyReview> setActionStatus(String reviewId, String actionId, String status) async {
    await _gate();
    actions.add((review: reviewId, action: actionId, status: status));
    return StrategyReview.fromJson(_review(reviewId, 'x'));
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

Future<_FakeStrategies> _pump(WidgetTester tester, {String tab = 'overview', _FakeStrategies? fake, Size size = const Size(1280, 2400)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final f = fake ?? _FakeStrategies();
  final overrides = <Override>[marketingStrategyServiceProvider.overrideWithValue(f), marketingTeamServiceProvider.overrideWithValue(_NoTeam())];
  await tester.pumpWidget(ProviderScope(overrides: overrides, child: MaterialApp(theme: AppTheme.lightTheme, home: Scaffold(body: StrategiesScreen(initialTab: tab)))));
  await tester.pumpAndSettle();
  return f;
}

Finder _k(String key) => find.byKey(Key(key));
String _text(WidgetTester t, Finder f) => t.widget<Text>(f).data!;
Finder _in(String key, String text) => find.descendant(of: _k(key), matching: find.text(text));
/// Scrolls the tab's list (by its key) until the finder is on screen.
Future<void> _scrollTo(WidgetTester t, Finder target, String listKey) async {
  await t.scrollUntilVisible(target, 200, scrollable: find.descendant(of: _k(listKey), matching: find.byType(Scrollable)).first);
  await t.pumpAndSettle();
}

Future<void> _pick(WidgetTester t, String dropdownKey, String label) async {
  await t.ensureVisible(_k(dropdownKey));
  await t.tap(_k(dropdownKey));
  await t.pumpAndSettle();
  await t.tap(find.text(label).last);
  await t.pumpAndSettle();
}

void main() {
  group('how the payloads read', () {
    test('a piece of work reads where its progress came from; a missing part is empty, never a crash', () {
      final w = WorkItem.fromJson(_work('i1', progress: 75, tasks: 4, done: 3));
      expect(w.progress, 75);
      expect(w.hasProgress, isTrue);
      expect(w.progressNote, '3 of 4 tasks done');
      expect(w.owner!.name, 'Abhiram');
      expect(w.isOpen, isTrue);
      expect(WorkItem.fromJson(_work('i2', source: 'owner', progress: 40)).progressNote, 'set by owner');
      final none = WorkItem.fromJson(_work('i3', source: 'none', progress: 0, noOwner: true, due: null));
      expect(none.hasProgress, isFalse);
      expect(none.progressNote, 'no tasks tied yet');
      expect(none.owner, isNull);
      expect(none.due, isNull);
      expect(WorkItem.fromJson(_work('i4', tasks: 1, done: 1)).progressNote, '1 of 1 task done');
      final empty = WorkItem.fromJson(const {'id': 'x', 'title': 'x'});
      expect(empty.kind, 'initiative');
      expect(empty.status, 'in_progress');
      expect(empty.progressSource, 'none');
      expect(empty.brand, 'main');
      expect(empty.isOpen, isTrue);
      expect(WorkItem.fromJson(_work('p', kind: 'project')).isProject, isTrue);
    });

    test('status words are the document\'s; the hand-set statuses are the manager\'s', () {
      expect([for (final s in ['on_track', 'in_progress', 'at_risk', 'on_hold', 'completed']) workStatusLabel(s)], ['On Track', 'In Progress', 'At Risk', 'On Hold', 'Completed']);
      expect(workStatusLabel('weird'), 'weird');
      expect({for (final s in ['on_track', 'in_progress', 'at_risk', 'on_hold', 'completed']) workStatusColor(s)}.length, 5);
      expect(kInitiativeStoredStatuses.map((s) => s.$1), ['planned', 'active', 'on_hold', 'completed', 'cancelled']);
      expect(kProjectStoredStatuses.map((s) => s.$1), ['planned', 'in_progress', 'on_hold', 'completed', 'cancelled']);
      expect(findingKindLabel('market_insight'), 'Market insight');
      expect(reviewTypeLabel('campaign'), 'Campaign Review');
      expect(actionStatusLabel('in_progress'), 'In Progress');
      expect(planStatusLabel('on_hold'), 'On Hold');
    });

    test('the overview, plans, roadmap, research and reviews read their payloads', () {
      final o = StrategyOverview.fromJson(_overview());
      expect(o.kpis.activeStrategies, 12);
      expect(o.focusTotal, 12);
      expect(o.focus.length, 3);
      expect(o.quarters.length, 4);
      expect(o.quarters[0].theme, 'Foundation');
      expect(o.quarters[0].pct, 67);
      expect(o.initiatives.length, 3);
      expect(o.performance[2].progress, isNull);
      expect(o.updates.first.kind, 'review');
      expect(o.keyOutcomes!.periodLabel, 'Q3 2026');
      expect(o.keyOutcomes!.scores.overall, 50);
      final p = PlansData.fromJson(_plans());
      expect([p.counts.active, p.counts.inProgress, p.counts.onHold, p.counts.completed], [3, 2, 1, 4]);
      expect(p.slices.map((s) => s.count), [1, 2, 1, 3]);
      expect(p.items[0].ownerName, 'Ashique');
      expect(p.items[1].ownerId, isNull);
      final r = RoadmapData.fromJson(_roadmap());
      expect(r.bars.length, 2);
      expect(r.bars[1].progressSource, 'none');
      expect(r.undated.single.end, isNull);
      expect([r.items, r.done, r.pct], [4, 1, 25]);
      final rs = ResearchData.fromJson(_research());
      expect(rs.counts.marketInsight, 6);
      expect(rs.items.length, 3);
      final rv = ReviewsData.fromJson(_reviews('quarterly'));
      expect(rv.items.first.actionItems[1].overdue, isTrue);
      expect(rv.items.first.actionItems[2].ownerId, isNull);
      expect(rv.counts['quarterly'], 2);
      final s = StrategySetup.fromJson(_setup(me: null));
      expect(s.meId, isNull);
      expect(s.members.length, 2);
    });

    test('every payload reads as empty from {}', () {
      expect(StrategyOverview.fromJson(const {}).keyOutcomes, isNull);
      expect(StrategyOverview.fromJson(const {}).kpis.totalInitiatives, 0);
      expect(PlansData.fromJson(const {}).items, isEmpty);
      expect(WorkList.fromJson(const {}).page, 1);
      expect(WorkList.fromJson(const {}).pageSize, 10);
      expect(RoadmapData.fromJson(const {}).quarters, isEmpty);
      expect(ResearchData.fromJson(const {}).page, 1);
      expect(ReviewsData.fromJson(const {}).type, 'all');
      expect(ReviewScores.fromJson(const {}).overall, isNull);
      expect(StrategySetup.fromJson(const {}).canManage, isFalse);
      expect(WorkDetail.fromJson(const {'id': 'x'}).tasks, isEmpty);
    });
  });

  group('the screen', () {
    testWidgets('a header with the date range, the brand and New Initiative, and the seven tabs in the document\'s order', (tester) async {
      await _pump(tester);
      expect(tester.widget<Text>(find.byKey(const Key('mkt_title'))).textSpan!.toPlainText(), 'Strategies & Developments');
      expect(_k('team_filter_range'), findsOneWidget);
      expect(_k('team_brand_pill'), findsOneWidget);
      expect(_k('st_new_initiative'), findsOneWidget);
      expect(find.descendant(of: _k('st_new_initiative'), matching: find.text('New Initiative')), findsOneWidget);
      for (final t in kStrategyTabs) {
        expect(_k('st_tab_${t.$1}'), findsOneWidget, reason: t.$1);
      }
      expect([for (final t in kStrategyTabs) t.$1], ['overview', 'plans', 'projects', 'roadmap', 'initiatives', 'research', 'reviews']);
      expect([for (final t in kStrategyTabs) t.$2], ['Overview', 'Strategic Plans', 'Development Projects', 'Roadmap', 'Initiatives', 'Research & Insights', 'Reviews']);
      expect(_k('strategies_overview_list'), findsOneWidget);
    });

    testWidgets('the ?tab= opens that tab; an unknown one opens the Overview', (tester) async {
      for (final (tab, list) in [('plans', 'strategies_plans_list'), ('projects', 'strategies_project_list'), ('roadmap', 'strategies_roadmap_list'), ('initiatives', 'strategies_initiative_list'), ('research', 'strategies_research_list'), ('reviews', 'strategies_reviews_list'), ('nonsense', 'strategies_overview_list')]) {
        await _pump(tester, tab: tab);
        expect(_k(list), findsOneWidget, reason: tab);
        await tester.pumpWidget(const SizedBox());
      }
    });

    testWidgets('tapping a tab pill opens it', (tester) async {
      await _pump(tester);
      for (final (tab, list) in [('plans', 'strategies_plans_list'), ('projects', 'strategies_project_list'), ('roadmap', 'strategies_roadmap_list'), ('initiatives', 'strategies_initiative_list'), ('research', 'strategies_research_list'), ('reviews', 'strategies_reviews_list'), ('overview', 'strategies_overview_list')]) {
        await tester.tap(_k('st_tab_$tab'));
        await tester.pumpAndSettle();
        expect(_k(list), findsOneWidget, reason: tab);
      }
    });

    testWidgets('the shared date range and brand re-read the screen', (tester) async {
      final f = await _pump(tester);
      final first = f.overviewFilters.last;
      expect(first.fromDay, TeamFilter.thisWeek().fromDay);
      expect(first.brand, TeamBrand.all);
      await tester.tap(_k('team_filter_quick'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Last month'));
      await tester.pumpAndSettle();
      final now = DateTime.now();
      expect(f.overviewFilters.last.fromDay, TeamFilter.day(DateTime(now.year, now.month - 1, 1)));
      expect(f.overviewFilters.last.toDay, TeamFilter.day(DateTime(now.year, now.month, 0)));
      await tester.tap(_k('team_brand_pill'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kerala').last);
      await tester.pumpAndSettle();
      expect(f.overviewFilters.last.brand, TeamBrand.kerala);
    });
  });

  group('Overview', () {
    testWidgets('the six KPIs', (tester) async {
      await _pump(tester);
      for (final (key, value, label) in [('st_kpi_active', '12', 'Active Strategies'), ('st_kpi_projects', '8', 'Development Projects'), ('st_kpi_initiatives', '24', 'Total Initiatives'), ('st_kpi_on_track', '18', 'On Track'), ('st_kpi_at_risk', '4', 'At Risk'), ('st_kpi_new', '2', 'New This Week')]) {
        expect(_in(key, value), findsOneWidget, reason: key);
        expect(_in(key, label), findsOneWidget, reason: key);
      }
    });

    testWidgets('Strategic Focus Areas: the donut total and the list', (tester) async {
      await _pump(tester);
      expect(_text(tester, _k('st_focus_total')), '12');
      expect(find.text('Strategic Focus Areas (2026)'), findsOneWidget);
      expect(find.text('Brand & Market Positioning'), findsWidgets);
      expect(find.text('Content & Creative Scale'), findsOneWidget);
    });

    testWidgets('the Quarterly Strategic Roadmap shows the four columns with their themes, items and a "+n more" when there are many', (tester) async {
      await _pump(tester);
      expect(find.text('Q1 (Jan – Mar)'), findsOneWidget);
      expect(find.text('Q4 (Oct – Dec)'), findsOneWidget);
      expect(_in('st_ov_q1', 'Foundation'), findsOneWidget);
      expect(_in('st_ov_q1', 'Brand consolidation'), findsOneWidget);
      expect(_in('st_ov_q2', 'Campaign scale-up'), findsOneWidget);
      expect(_in('st_ov_q3', 'Nothing planned'), findsOneWidget);
      expect(_in('st_ov_q4', '+2 more'), findsOneWidget);
      expect(find.descendant(of: _k('st_ov_q1'), matching: find.byIcon(Icons.check_circle_rounded)), findsNWidgets(2), reason: 'two ticked lines');
    });

    testWidgets('Key Strategic Initiatives: owner, progress (or "Not set"), due date and status; a missing owner is a dash', (tester) async {
      await _pump(tester);
      expect(_in('st_ov_init_i1', 'Launch Bridal Campaign v2'), findsOneWidget);
      expect(_in('st_ov_init_i1', 'Abhiram'), findsOneWidget);
      expect(_in('st_ov_init_i1', '75%'), findsOneWidget);
      expect(_in('st_ov_init_i1', '3 of 4 tasks done'), findsOneWidget);
      expect(_in('st_ov_init_i1', '15 Nov'), findsOneWidget);
      expect(_in('st_ov_init_i1', 'On Track'), findsOneWidget);
      expect(_in('st_ov_init_i2', 'Not set'), findsOneWidget, reason: 'never a made-up 0%');
      expect(_in('st_ov_init_i2', 'no tasks tied yet'), findsOneWidget);
      expect(_in('st_ov_init_i2', '—'), findsWidgets);
      expect(_in('st_ov_init_i2', 'In Progress'), findsOneWidget);
      expect(_in('st_ov_init_i3', 'At Risk'), findsOneWidget);
      expect(_in('st_ov_init_i3', 'set by owner'), findsOneWidget);
    });

    testWidgets('Development Projects: a card with its description and progress bar', (tester) async {
      await _pump(tester);
      expect(_in('st_ov_proj_d1', 'Website v2'), findsOneWidget);
      expect(_in('st_ov_proj_d1', 'Brand site & portfolio upgrade'), findsOneWidget);
      expect(_in('st_ov_proj_d1', '85%'), findsOneWidget);
      expect(_in('st_ov_proj_d2', 'Operations'), findsOneWidget, reason: 'no description: the category');
      expect(_in('st_ov_proj_d2', '60%'), findsOneWidget);
    });

    testWidgets('Strategy Performance is a bar per focus area; one with no measured progress has no bar', (tester) async {
      await _pump(tester);
      final chart = tester.widget<BarChart>(find.descendant(of: _k('st_perf_chart'), matching: find.byType(BarChart)));
      expect(chart.data.barGroups.map((g) => g.barRods.first.toY), [92, 76, 0]);
      expect(chart.data.barGroups[2].barRods.first.color, Colors.transparent);
      expect(chart.data.maxY, 100);
    });

    testWidgets('Recent Updates, Research cards and Key Outcomes are the real records', (tester) async {
      await _pump(tester);
      expect(_k('st_update_0'), findsOneWidget);
      expect(find.text('Q3 2026 review added'), findsOneWidget);
      expect(find.text('Quarterly review · Meera'), findsOneWidget);
      expect(find.text('Hero reel completed'), findsOneWidget);
      expect(find.text('Launch Bridal Campaign v2 · Asha'), findsOneWidget);
      expect(_k('st_ov_find_f1'), findsOneWidget);
      expect(find.text('Instagram Growth Trends – Nov 2026'), findsOneWidget);
      expect(find.text('Market insight · 10 Nov'), findsOneWidget);
      expect(find.text('Quarterly Review · Q3 2026'), findsOneWidget);
      expect(find.text('Lead target achieved (102%)'), findsOneWidget);
      expect(_k('st_outcome_0'), findsOneWidget);
      expect(tester.widget<Icon>(_k('st_outcome_0')).icon, Icons.check_circle_rounded);
      expect(tester.widget<Icon>(_k('st_outcome_2')).icon, Icons.timelapse_rounded);
      expect(tester.widget<Icon>(_k('st_outcome_3')).icon, Icons.cancel_rounded);
    });

    testWidgets('the View All links open the other tabs', (tester) async {
      await _pump(tester);
      for (final (link, list) in [('st_link_plans', 'strategies_plans_list'), ('st_link_roadmap', 'strategies_roadmap_list'), ('st_link_initiatives', 'strategies_initiative_list'), ('st_link_projects', 'strategies_project_list'), ('st_link_research', 'strategies_research_list'), ('st_link_reviews', 'strategies_reviews_list')]) {
        await tester.tap(_k('st_tab_overview'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(_k(link));
        await tester.tap(_k(link));
        await tester.pumpAndSettle();
        expect(_k(list), findsOneWidget, reason: link);
      }
    });

    testWidgets('a quiet period shows honest empty states and zeros', (tester) async {
      final f = _FakeStrategies()
        ..overviewJson = {
          'year': 2026,
          'kpis': {'activeStrategies': 0, 'developmentProjects': 0, 'totalInitiatives': 0, 'onTrack': 0, 'atRisk': 0, 'newThisWeek': 0},
          'focusAreas': {'total': 0, 'rows': []},
          'roadmap': {'year': 2026, 'quarters': []},
          'initiatives': [], 'projects': [], 'performance': [], 'recentUpdates': [], 'research': [], 'keyOutcomes': null,
        };
      await _pump(tester, fake: f);
      expect(_in('st_kpi_active', '0'), findsOneWidget);
      expect(find.textContaining('No active strategic plan'), findsOneWidget);
      expect(find.text('Nothing is planned on the roadmap for this year yet.'), findsOneWidget);
      expect(find.textContaining('No initiative in this period'), findsOneWidget);
      expect(find.text('No development project in this period.'), findsOneWidget);
      expect(find.textContaining('Progress shows once initiatives have tasks'), findsOneWidget);
      expect(find.text('Nothing has changed in this period.'), findsOneWidget);
      expect(find.textContaining('No findings in this period'), findsOneWidget);
      expect(find.textContaining('No review yet'), findsOneWidget);
      expect(find.byType(BarChart), findsNothing);
    });

    testWidgets('a failing read shows "Try again", and trying again reads it', (tester) async {
      final f = _FakeStrategies()..overviewFails = true;
      await _pump(tester, fake: f);
      expect(find.text('Try again'), findsOneWidget);
      expect(_k('st_kpi_active'), findsNothing);
      f.overviewFails = false;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(_in('st_kpi_active', '12'), findsOneWidget);
    });

    testWidgets('a row of the initiatives table opens the initiative', (tester) async {
      final f = await _pump(tester);
      await tester.ensureVisible(_k('st_ov_init_i1'));
      await tester.tap(_k('st_ov_init_i1'));
      await tester.pumpAndSettle();
      expect(f.detailCalls, ['initiative:i1']);
      expect(_text(tester, _k('wd_title')), 'Launch Bridal Campaign v2');
    });
  });

  group('Initiatives and Development Projects', () {
    testWidgets('Initiatives: KPIs, the table\'s columns and rows', (tester) async {
      final f = await _pump(tester, tab: 'initiatives');
      for (final (key, value, label) in [('in_kpi_total', '24', 'Total Initiatives'), ('in_kpi_open', '17', 'Active'), ('in_kpi_completed', '4', 'Completed'), ('in_kpi_hold', '3', 'Paused')]) {
        expect(_in(key, value), findsOneWidget, reason: key);
        expect(_in(key, label), findsOneWidget, reason: key);
      }
      for (final c in ['Initiative', 'Focus Area', 'Impact', 'Owner', 'Progress', 'Status', 'Due Date']) {
        expect(find.text(c), findsWidgets, reason: c);
      }
      expect(_in('in_row_i1', 'Meta Lead Quality Improvement'), findsOneWidget);
      expect(_in('in_row_i1', 'Revenue & Lead Growth'), findsOneWidget);
      expect(_in('in_row_i1', 'High'), findsOneWidget);
      expect(_in('in_row_i1', 'Abhiram'), findsOneWidget);
      expect(_in('in_row_i1', '75%'), findsOneWidget);
      expect(_in('in_row_i1', '15 Nov 2026'), findsOneWidget);
      expect(_in('in_row_i2', 'At Risk'), findsOneWidget);
      expect(_in('in_row_i3', 'Not set'), findsOneWidget);
      expect(_in('in_row_i3', 'On Hold'), findsOneWidget);
      expect(_text(tester, _k('in_showing')), 'Showing 1–3 of 24');
      expect(f.initiativeCalls.last.q.status, 'all');
    });

    testWidgets('the status chips, focus area, search and paging cut the list (what the server was asked)', (tester) async {
      final f = await _pump(tester, tab: 'initiatives');
      await tester.tap(_k('in_status_at_risk'));
      await tester.pumpAndSettle();
      expect(f.initiativeCalls.last.q.status, 'at_risk');
      await tester.tap(_k('in_status_open'));
      await tester.pumpAndSettle();
      expect(f.initiativeCalls.last.q.status, 'open');
      await tester.tap(_k('in_status_on_hold'));
      await tester.pumpAndSettle();
      expect(f.initiativeCalls.last.q.status, 'on_hold');
      await tester.tap(_k('in_status_all'));
      await tester.pumpAndSettle();
      await tester.tap(_k('in_focus_filter'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Operations').last);
      await tester.pumpAndSettle();
      expect(f.initiativeCalls.last.q.focusArea, 'Operations');
      await tester.enterText(_k('in_search'), 'crm');
      await tester.pumpAndSettle();
      expect(f.initiativeCalls.last.q.q, 'crm');
      expect(f.initiativeCalls.last.q.focusArea, 'Operations', reason: 'filters add up');
      expect(f.initiativeCalls.last.q.page, 1);
      await tester.tap(_k('in_next'));
      await tester.pumpAndSettle();
      expect(f.initiativeCalls.last.q.page, 2);
      expect(f.initiativeCalls.last.q.q, 'crm');
      await tester.tap(_k('in_prev'));
      await tester.pumpAndSettle();
      expect(f.initiativeCalls.last.q.page, 1);
      await tester.tap(_k('in_next'));
      await tester.pumpAndSettle();
      expect(f.initiativeCalls.last.q.page, 2);
      await tester.tap(_k('in_status_completed'));
      await tester.pumpAndSettle();
      expect(f.initiativeCalls.last.q.page, 1, reason: 'a new cut starts on page 1');
      expect(f.initiativeCalls.last.q.status, 'completed');
    });

    testWidgets('only a manager sees the Cancelled chip', (tester) async {
      await _pump(tester, tab: 'initiatives');
      expect(_k('in_status_cancelled'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await _pump(tester, tab: 'initiatives', fake: _FakeStrategies()..setupJson = _setup(manage: false));
      expect(_k('in_status_cancelled'), findsNothing);
    });

    testWidgets('Export asks for up to 100 rows with the same cut', (tester) async {
      final f = await _pump(tester, tab: 'initiatives');
      await tester.tap(_k('in_status_at_risk'));
      await tester.pumpAndSettle();
      await tester.tap(_k('in_export'));
      await tester.pumpAndSettle();
      expect(f.initiativeCalls.last.limit, 100);
      expect(f.initiativeCalls.last.q.status, 'at_risk');
      expect(f.initiativeCalls.last.q.page, 1);
    });

    testWidgets('empty and failing states', (tester) async {
      await _pump(tester, tab: 'initiatives', fake: _FakeStrategies()..initiativesJson = _workList(items: [], total: 0));
      expect(find.textContaining('No initiative in this period'), findsOneWidget);
      expect(_text(tester, _k('in_showing')), 'Nothing to show');
      await tester.pumpWidget(const SizedBox());
      final f = _FakeStrategies()..initiativesFail = true;
      await _pump(tester, tab: 'initiatives', fake: f);
      expect(find.text('Try again'), findsOneWidget);
      f.initiativesFail = false;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(_in('in_kpi_total', '24'), findsOneWidget);
    });

    testWidgets('Development Projects: its own KPI words, columns (a Category, no Impact) and the manager-only New Project', (tester) async {
      await _pump(tester, tab: 'projects');
      for (final (key, value, label) in [('dp_kpi_total', '12', 'Total Projects'), ('dp_kpi_open', '17', 'In Progress'), ('dp_kpi_completed', '4', 'Completed'), ('dp_kpi_hold', '3', 'On Hold')]) {
        expect(_in(key, value), findsOneWidget, reason: key);
        expect(_in(key, label), findsOneWidget, reason: key);
      }
      expect(find.text('Category'), findsOneWidget);
      expect(find.text('Impact'), findsNothing);
      expect(_in('dp_row_i1', 'Website v2'), findsOneWidget);
      expect(_in('dp_row_i1', 'Technology'), findsOneWidget);
      expect(_k('st_new_project'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await _pump(tester, tab: 'projects', fake: _FakeStrategies()..setupJson = _setup(manage: false));
      expect(_k('st_new_project'), findsNothing, reason: 'a member does not add projects');
    });

    testWidgets('project filters go to the project query, not the initiatives\'', (tester) async {
      final f = await _pump(tester, tab: 'projects');
      await tester.tap(_k('dp_status_on_hold'));
      await tester.pumpAndSettle();
      expect(f.projectCalls.last.q.status, 'on_hold');
      await tester.enterText(_k('dp_search'), 'web');
      await tester.pumpAndSettle();
      expect(f.projectCalls.last.q.q, 'web');
      expect(f.initiativeCalls, isEmpty);
    });
  });

  group('one initiative or project', () {
    testWidgets('the detail shows where each figure came from, the tasks tied to it, the hours and the logged work', (tester) async {
      final f = await _pump(tester, tab: 'initiatives');
      await tester.tap(_k('in_row_i1'));
      await tester.pumpAndSettle();
      expect(f.detailCalls, ['initiative:i1']);
      expect(_text(tester, _k('wd_title')), 'Launch Bridal Campaign v2');
      expect(_in('wd_status', 'On Track'), findsOneWidget);
      expect(_in('wd_owner', 'Abhiram'), findsOneWidget);
      expect(_in('wd_progress', '75%'), findsOneWidget);
      expect(_in('wd_progress', '3 of 4 tasks done'), findsOneWidget);
      expect(_in('wd_due', '15 Nov 2026'), findsOneWidget);
      expect(_in('wd_hours', '2h 15m'), findsOneWidget);
      expect(find.text('Tasks tied to it (2)'), findsOneWidget);
      expect(_k('wd_task_t1'), findsOneWidget);
      expect(_in('wd_task_t1', 'Shoot hero reel'), findsOneWidget);
      expect(_in('wd_task_t1', '50%'), findsOneWidget);
      expect(_in('wd_task_t2', '100%'), findsOneWidget);
      expect(find.text('Preethi · Campaign planning'), findsOneWidget);
      expect(find.textContaining('Plan: Revenue plan'), findsOneWidget);
      expect(find.text('Bridal campaign for the season'), findsOneWidget);
    });

    testWidgets('a project\'s detail shows its hours and logged work too (logs are tied to a development project now)', (tester) async {
      final f = await _pump(tester, tab: 'projects');
      await tester.tap(_k('dp_row_i1'));
      await tester.pumpAndSettle();
      expect(f.detailCalls, ['project:i1']);
      expect(_k('wd_hours'), findsOneWidget);
      expect(find.text('Logged work'), findsOneWidget);
      expect(find.text('Strategy work logged'), findsOneWidget);
    });

    testWidgets('Edit is for the manager or the owner they chose; Delete is the manager\'s', (tester) async {
      // a member who is not the owner (the work is Abhiram\'s = m9; the member is m1)
      await _pump(tester, tab: 'initiatives', fake: _FakeStrategies()..setupJson = _setup(manage: false));
      await tester.tap(_k('in_row_i1'));
      await tester.pumpAndSettle();
      expect(_k('wd_edit'), findsNothing);
      expect(_k('wd_delete'), findsNothing);
      expect(_k('wd_close'), findsOneWidget);
      await tester.tap(_k('wd_close'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      // the owner
      final owner = _FakeStrategies()..setupJson = _setup(manage: false, me: 'm9');
      await _pump(tester, tab: 'initiatives', fake: owner);
      await tester.tap(_k('in_row_i1'));
      await tester.pumpAndSettle();
      expect(_k('wd_edit'), findsOneWidget);
      expect(_k('wd_delete'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      // the manager
      await _pump(tester, tab: 'initiatives');
      await tester.tap(_k('in_row_i1'));
      await tester.pumpAndSettle();
      expect(_k('wd_edit'), findsOneWidget);
      expect(_k('wd_delete'), findsOneWidget);
    });

    testWidgets('Edit opens the form with what is stored, from the screen', (tester) async {
      await _pump(tester, tab: 'initiatives');
      await tester.tap(_k('in_row_i1'));
      await tester.pumpAndSettle();
      await tester.tap(_k('wd_edit'));
      await tester.pumpAndSettle();
      expect(_k('wd_title'), findsNothing, reason: 'the detail closed');
      expect(find.text('Edit initiative'), findsOneWidget);
      expect(tester.widget<TextField>(_k('work_title')).controller!.text, 'Launch Bridal Campaign v2');
      expect(tester.widget<TextField>(_k('work_area')).controller!.text, 'Revenue & Lead Growth');
    });

    testWidgets('Delete asks first, then deletes; a refusal (it has tasks) is shown in the server\'s words and nothing is lost', (tester) async {
      final f = await _pump(tester, tab: 'initiatives');
      await tester.tap(_k('in_row_i1'));
      await tester.pumpAndSettle();
      await tester.tap(_k('wd_delete'));
      await tester.pumpAndSettle();
      expect(find.text('Delete this initiative?'), findsOneWidget);
      await tester.tap(_k('st_delete_cancel'));
      await tester.pumpAndSettle();
      expect(f.initiativesDeleted, isEmpty);
      await tester.tap(_k('wd_delete'));
      await tester.pumpAndSettle();
      f.refuse = const TeamRefusal('This initiative has 3 tasks tied to it. Cancel it instead, so the record stays.', status: 409);
      await tester.tap(_k('st_delete_confirm'));
      await tester.pumpAndSettle();
      expect(find.text('This initiative has 3 tasks tied to it. Cancel it instead, so the record stays.'), findsOneWidget);
      expect(f.initiativesDeleted, isEmpty);
      f.refuse = null;
      await tester.tap(_k('wd_delete'));
      await tester.pumpAndSettle();
      await tester.tap(_k('st_delete_confirm'));
      await tester.pumpAndSettle();
      expect(f.initiativesDeleted, ['i1']);
      expect(_k('wd_title'), findsNothing, reason: 'the detail closed');
    });

    testWidgets('a project is deleted through the project call', (tester) async {
      final f = await _pump(tester, tab: 'projects');
      await tester.tap(_k('dp_row_i1'));
      await tester.pumpAndSettle();
      await tester.tap(_k('wd_delete'));
      await tester.pumpAndSettle();
      await tester.tap(_k('st_delete_confirm'));
      await tester.pumpAndSettle();
      expect(f.projectsDeleted, ['i1']);
      expect(f.initiativesDeleted, isEmpty);
    });
  });

  group('the initiative form', () {
    testWidgets('a member makes an initiative: the title is required; owner and status are not theirs to set; the payload is what was typed', (tester) async {
      final f = await _pump(tester, fake: _FakeStrategies()..setupJson = _setup(manage: false));
      await tester.tap(_k('st_new_initiative'));
      await tester.pumpAndSettle();
      expect(find.text('New initiative'), findsOneWidget);
      expect(_k('work_status'), findsNothing, reason: 'status is the manager\'s');
      expect(tester.widget<DropdownButtonFormField<String?>>(_k('work_owner')).onChanged, isNull, reason: 'an initiative a member makes is theirs');
      await tester.tap(_k('work_save'));
      await tester.pumpAndSettle();
      expect(_text(tester, _k('work_error')), 'Give the initiative a title.');
      expect(f.initiativesSaved, isEmpty);
      await tester.enterText(_k('work_title'), 'Hyderabad Studio Setup');
      await tester.enterText(_k('work_area'), 'Operations');
      await tester.enterText(_k('work_progress'), '30');
      await tester.enterText(_k('work_notes'), 'Shortlist sites');
      await _pick(tester, 'work_impact', 'Low');
      await tester.tap(_k('work_save'));
      await tester.pumpAndSettle();
      expect(f.initiativesSaved.length, 1);
      final b = f.initiativesSaved.single.body;
      expect(f.initiativesSaved.single.id, isNull);
      expect(b['title'], 'Hyderabad Studio Setup');
      expect(b['focusArea'], 'Operations');
      expect(b['impact'], 'low');
      expect(b['progress'], 30);
      expect(b['notes'], 'Shortlist sites');
      expect(b['brand'], 'main');
      expect(b['dueDate'], isNull);
      expect(b['startDate'], isNull);
      expect(b['planId'], isNull);
      expect(b.containsKey('status'), isFalse);
      expect(b.containsKey('ownerId'), isFalse);
      expect(find.text('New initiative'), findsNothing, reason: 'the form closed');
    });

    testWidgets('a manager also sets the status and the owner; the owner defaults to themselves when they are on the team', (tester) async {
      final f = await _pump(tester);
      await tester.tap(_k('st_new_initiative'));
      await tester.pumpAndSettle();
      await tester.enterText(_k('work_title'), 'CRM & Lead Automation');
      await _pick(tester, 'work_status', 'On hold');
      await tester.tap(_k('work_save'));
      await tester.pumpAndSettle();
      var b = f.initiativesSaved.single.body;
      expect(b['status'], 'on_hold');
      expect(b['ownerId'], 'm1', reason: 'the manager is Preethi (m1) in this setup');
      f.initiativesSaved.clear();
      await tester.tap(_k('st_new_initiative'));
      await tester.pumpAndSettle();
      await tester.enterText(_k('work_title'), 'Given away');
      await _pick(tester, 'work_owner', 'Ashique');
      await tester.tap(_k('work_save'));
      await tester.pumpAndSettle();
      b = f.initiativesSaved.single.body;
      expect(b['ownerId'], 'm2');
      expect(b['status'], 'active');
    });

    testWidgets('the due date picker sets dueDate; the × clears it', (tester) async {
      final f = await _pump(tester);
      await tester.tap(_k('st_new_initiative'));
      await tester.pumpAndSettle();
      await tester.enterText(_k('work_title'), 'Dated one');
      await tester.tap(find.descendant(of: _k('work_due'), matching: find.byType(MktPill)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(_k('work_save'));
      await tester.pumpAndSettle();
      expect(f.initiativesSaved.single.body['dueDate'], TeamFilter.day(DateTime.now()));
      f.initiativesSaved.clear();
      await tester.tap(_k('st_new_initiative'));
      await tester.pumpAndSettle();
      await tester.enterText(_k('work_title'), 'Dated one');
      await tester.tap(find.descendant(of: _k('work_due'), matching: find.byType(MktPill)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: _k('work_due'), matching: find.byIcon(Icons.close_rounded)));
      await tester.pumpAndSettle();
      await tester.tap(_k('work_save'));
      await tester.pumpAndSettle();
      expect(f.initiativesSaved.single.body['dueDate'], isNull);
    });

    testWidgets('a bad progress is refused in the form before anything is sent; the server\'s refusal is shown in the form and the form stays open', (tester) async {
      final f = await _pump(tester);
      await tester.tap(_k('st_new_initiative'));
      await tester.pumpAndSettle();
      await tester.enterText(_k('work_title'), 'Needs care');
      await tester.enterText(_k('work_progress'), '140');
      await tester.tap(_k('work_save'));
      await tester.pumpAndSettle();
      expect(_text(tester, _k('work_error')), 'Progress is a whole number from 0 to 100.');
      await tester.enterText(_k('work_progress'), 'abc');
      await tester.tap(_k('work_save'));
      await tester.pumpAndSettle();
      expect(_text(tester, _k('work_error')), 'Progress is a whole number from 0 to 100.');
      expect(f.initiativesSaved, isEmpty);
      await tester.enterText(_k('work_progress'), '');
      f.refuse = const TeamRefusal('The due date is before the start date.', field: 'dueDate');
      await tester.tap(_k('work_save'));
      await tester.pumpAndSettle();
      expect(_text(tester, _k('work_error')), 'The due date is before the start date.');
      expect(_k('work_title'), findsOneWidget, reason: 'the form stays open');
      expect(tester.widget<FilledButton>(_k('work_save')).onPressed, isNotNull, reason: 'Save works again');
    });

    testWidgets('Save is disabled while saving', (tester) async {
      final f = _FakeStrategies()..hold = Completer<void>();
      await _pump(tester, fake: f);
      await tester.tap(_k('st_new_initiative'));
      await tester.pumpAndSettle();
      await tester.enterText(_k('work_title'), 'Slow one');
      await tester.tap(_k('work_save'));
      await tester.pump();
      expect(tester.widget<FilledButton>(_k('work_save')).onPressed, isNull);
      expect(tester.widget<OutlinedButton>(_k('work_cancel')).onPressed, isNull);
      f.hold!.complete();
      await tester.pumpAndSettle();
      expect(f.initiativesSaved.length, 1);
      expect(find.text('New initiative'), findsNothing);
    });

    testWidgets('editing prefills what was typed; tasks tied to it say that they decide the progress; saving sends the id', (tester) async {
      final one = _work('i1', title: 'Launch Bridal Campaign v2', typedProgress: 30, ownerSource: 'set', ownerId: 'm2', ownerName: 'Ashique', plan: 'Revenue plan');
      final f = _FakeStrategies()
        ..initiativesJson = _workList(items: [one])
        ..detailOverrides['i1'] = one;
      await _pump(tester, tab: 'initiatives', fake: f);
      await tester.tap(_k('in_row_i1'));
      await tester.pumpAndSettle();
      await tester.tap(_k('wd_edit'));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(_k('work_progress')).controller!.text, '30');
      expect(find.textContaining('Tasks are tied to this initiative'), findsOneWidget);
      expect(_in('work_owner', 'Ashique'), findsOneWidget);
      expect(_in('work_plan', 'Revenue plan (2026)'), findsOneWidget);
      await tester.tap(_k('work_save'));
      await tester.pumpAndSettle();
      expect(f.initiativesSaved.single.id, 'i1');
      final b = f.initiativesSaved.single.body;
      expect(b['title'], 'Launch Bridal Campaign v2');
      expect(b['progress'], 30);
      expect(b['ownerId'], 'm2');
      expect(b['planId'], 'p1');
      expect(b['startDate'], '2026-11-01');
      expect(b['dueDate'], '2026-11-15');
    });

    testWidgets('an owner worked out from the tasks is not saved as a chosen one; a due date from the tasks is not typed in', (tester) async {
      final one = _work('i1', ownerSource: 'tasks', dueSource: 'tasks', due: '2026-12-25');
      final f = _FakeStrategies()
        ..initiativesJson = _workList(items: [one])
        ..detailOverrides['i1'] = one;
      await _pump(tester, tab: 'initiatives', fake: f);
      await tester.tap(_k('in_row_i1'));
      await tester.pumpAndSettle();
      await tester.tap(_k('wd_edit'));
      await tester.pumpAndSettle();
      await tester.tap(_k('work_save'));
      await tester.pumpAndSettle();
      final b = f.initiativesSaved.single.body;
      expect(b['ownerId'], isNull, reason: 'it stays "use the tasks"');
      expect(b['dueDate'], isNull, reason: 'it stays "latest task due date"');
    });
  });

  group('the development project form', () {
    testWidgets('a manager adds a project: name, category, the due date is endDate; no Impact', (tester) async {
      final f = await _pump(tester, tab: 'projects');
      await tester.tap(_k('st_new_project'));
      await tester.pumpAndSettle();
      expect(find.text('New development project'), findsOneWidget);
      expect(_k('work_impact'), findsNothing);
      await tester.tap(_k('work_save'));
      await tester.pumpAndSettle();
      expect(_text(tester, _k('work_error')), 'Give the project a name.');
      await tester.enterText(_k('work_title'), 'Website v2');
      await tester.enterText(_k('work_area'), 'Technology');
      await _pick(tester, 'work_status', 'On hold');
      await tester.tap(_k('work_save'));
      await tester.pumpAndSettle();
      final b = f.projectsSaved.single.body;
      expect(f.initiativesSaved, isEmpty);
      expect(b['name'], 'Website v2');
      expect(b['category'], 'Technology');
      expect(b['status'], 'on_hold');
      expect(b.containsKey('endDate'), isTrue);
      expect(b.containsKey('dueDate'), isFalse);
      expect(b.containsKey('title'), isFalse);
      expect(b.containsKey('impact'), isFalse);
    });

    testWidgets('a category chip fills the field', (tester) async {
      await _pump(tester, tab: 'projects');
      await tester.tap(_k('st_new_project'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ActionChip, 'Operations'));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(_k('work_area')).controller!.text, 'Operations');
    });
  });

  group('Strategic Plans', () {
    testWidgets('the KPIs, focus areas, plan progress donut, goals and the plan table', (tester) async {
      await _pump(tester, tab: 'plans');
      for (final (key, value, label) in [('pl_kpi_active', '3', 'Active Plans'), ('pl_kpi_progress', '2', 'In Progress'), ('pl_kpi_hold', '1', 'On Hold'), ('pl_kpi_completed', '4', 'Completed')]) {
        expect(_in(key, value), findsOneWidget, reason: key);
        expect(_in(key, label), findsOneWidget, reason: key);
      }
      expect(_in('pl_focus_Brand Growth', '2'), findsOneWidget);
      expect(_in('pl_focus_Revenue Growth', '1'), findsOneWidget);
      expect(_text(tester, _k('pl_total')), '7');
      expect(find.text('2 · 29%'), findsOneWidget);
      expect(find.text('3 · 43%'), findsOneWidget);
      expect(find.text('Increase qualified leads by 40%'), findsOneWidget);
      expect(_in('pl_row_p1', 'Brand plan'), findsOneWidget);
      expect(_in('pl_row_p1', 'Brand Growth'), findsOneWidget);
      expect(_in('pl_row_p1', 'Ashique'), findsOneWidget);
      expect(_in('pl_row_p1', '3 init. · 1 proj.'), findsOneWidget);
      expect(_in('pl_row_p1', 'Active'), findsOneWidget);
      expect(_in('pl_row_p3', 'On Hold'), findsOneWidget);
    });

    testWidgets('a manager has New, Edit and Delete; a member only reads', (tester) async {
      await _pump(tester, tab: 'plans');
      expect(_k('pl_new'), findsOneWidget);
      expect(_k('pl_edit_p1'), findsOneWidget);
      expect(_k('pl_delete_p1'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await _pump(tester, tab: 'plans', fake: _FakeStrategies()..setupJson = _setup(manage: false));
      expect(_k('pl_new'), findsNothing);
      expect(_k('pl_edit_p1'), findsNothing);
      expect(_k('pl_delete_p1'), findsNothing);
      expect(_in('pl_row_p1', 'Brand plan'), findsOneWidget);
    });

    testWidgets('the plan form needs a title and a focus area; the payload carries the year, status, owner and the goals one per line', (tester) async {
      final f = await _pump(tester, tab: 'plans');
      await tester.tap(_k('pl_new'));
      await tester.pumpAndSettle();
      await tester.tap(_k('plan_save'));
      await tester.pumpAndSettle();
      expect(_text(tester, _k('plan_error')), 'Give the plan a title.');
      await tester.enterText(_k('plan_title'), 'Brand & Market Positioning');
      await tester.tap(_k('plan_save'));
      await tester.pumpAndSettle();
      expect(_text(tester, _k('plan_error')), 'Choose the focus area of the plan.');
      expect(f.plansSaved, isEmpty);
      await tester.enterText(_k('plan_focus'), 'Brand Growth');
      await tester.enterText(_k('plan_goals'), 'Increase qualified leads by 40%\n\n  Improve engagement  \n');
      await _pick(tester, 'plan_status', 'In Progress');
      await _pick(tester, 'plan_owner', 'Ashique');
      await tester.tap(_k('plan_save'));
      await tester.pumpAndSettle();
      final b = f.plansSaved.single.body;
      expect(f.plansSaved.single.id, isNull);
      expect(b['title'], 'Brand & Market Positioning');
      expect(b['focusArea'], 'Brand Growth');
      expect(b['year'], DateTime.now().year);
      expect(b['status'], 'in_progress');
      expect(b['ownerId'], 'm2');
      expect(b['goals'], ['Increase qualified leads by 40%', 'Improve engagement']);
      expect(b['brand'], 'main');
    });

    testWidgets('editing a plan prefills it and sends its id; a refusal stays in the form', (tester) async {
      final f = await _pump(tester, tab: 'plans');
      await tester.tap(_k('pl_edit_p1'));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(_k('plan_title')).controller!.text, 'Brand plan');
      expect(tester.widget<TextField>(_k('plan_goals')).controller!.text, 'Increase qualified leads by 40%\nImprove engagement');
      f.refuse = const TeamRefusal('Only a Marketing Manager can change a strategic plan.', status: 403);
      await tester.tap(_k('plan_save'));
      await tester.pumpAndSettle();
      expect(_text(tester, _k('plan_error')), 'Only a Marketing Manager can change a strategic plan.');
      f.refuse = null;
      await tester.tap(_k('plan_save'));
      await tester.pumpAndSettle();
      expect(f.plansSaved.single.id, 'p1');
    });

    testWidgets('Delete asks first', (tester) async {
      final f = await _pump(tester, tab: 'plans');
      await tester.tap(_k('pl_delete_p3'));
      await tester.pumpAndSettle();
      expect(find.text('Delete this plan?'), findsOneWidget);
      await tester.tap(_k('st_delete_cancel'));
      await tester.pumpAndSettle();
      expect(f.plansDeleted, isEmpty);
      await tester.tap(_k('pl_delete_p3'));
      await tester.pumpAndSettle();
      await tester.tap(_k('st_delete_confirm'));
      await tester.pumpAndSettle();
      expect(f.plansDeleted, ['p3']);
    });

    testWidgets('empty and failing states', (tester) async {
      await _pump(tester, tab: 'plans', fake: _FakeStrategies()..plansJson = {'counts': {}, 'focusAreas': {'rows': []}, 'progress': {'total': 0, 'slices': []}, 'goals': [], 'items': []});
      expect(find.textContaining('No live plan yet'), findsOneWidget);
      expect(find.text('No plan in this period.'), findsOneWidget);
      expect(find.textContaining('Goals show here'), findsOneWidget);
      expect(find.textContaining('No strategic plan in this period'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      final f = _FakeStrategies()..plansFail = true;
      await _pump(tester, tab: 'plans', fake: f);
      expect(find.text('Try again'), findsOneWidget);
      f.plansFail = false;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(_in('pl_kpi_active', '3'), findsOneWidget);
    });
  });

  group('Roadmap', () {
    testWidgets('the Timeline: a bar per initiative and project with its progress on it, the dashes for no progress, the year\'s months, and the ones with no end date apart', (tester) async {
      final f = await _pump(tester, tab: 'roadmap');
      expect(f.roadmapCalls.last.year, isNull, reason: 'the server takes the year of the range');
      expect(_text(tester, _k('st_rm_year')), '2026');
      expect(find.text('1 of 4 milestones done (25%)'), findsOneWidget);
      expect(_k('st_tl_bar_i1'), findsOneWidget);
      expect(_text(tester, _k('st_tl_pct_i1')), '70%');
      expect(_text(tester, _k('st_tl_pct_d1')), '—', reason: 'no progress is not 0%');
      expect(find.text('Brand Growth Campaign'), findsOneWidget);
      expect(find.text('Website v2'), findsOneWidget);
      for (final m in ['Jan', 'Jun', 'Dec']) {
        expect(find.text(m), findsOneWidget, reason: m);
      }
      expect(find.text('No end date yet — not drawn'), findsOneWidget);
      expect(_k('st_tl_undated_i9'), findsOneWidget);
      expect(_k('st_tl_bar_i9'), findsNothing);
      final bar = tester.getRect(_k('st_tl_bar_i1'));
      final other = tester.getRect(_k('st_tl_bar_d1'));
      expect(bar.left, lessThan(other.left), reason: 'starts earlier in the year');
      expect(bar.width, greaterThan(0));
    });

    testWidgets('a bar opens its record', (tester) async {
      final f = await _pump(tester, tab: 'roadmap');
      await tester.tap(_k('st_tl_bar_d1'));
      await tester.pumpAndSettle();
      expect(f.detailCalls, ['project:d1']);
      await tester.tap(_k('wd_close'));
      await tester.pumpAndSettle();
      await tester.tap(_k('st_tl_label_i1'));
      await tester.pumpAndSettle();
      expect(f.detailCalls.last, 'initiative:i1');
    });

    testWidgets('Quarterly: the four quarters with their counts; members tick lines off (what was sent) and take the tick back', (tester) async {
      final f = await _pump(tester, tab: 'roadmap');
      await tester.tap(_k('st_rm_view_quarterly'));
      await tester.pumpAndSettle();
      expect(_k('st_rm_q1'), findsOneWidget);
      expect(_text(tester, _k('st_rm_count_q1')), '1 of 2 done');
      expect(_text(tester, _k('st_rm_count_q3')), 'Nothing planned');
      expect(_in('st_rm_q1', 'Q1 · Foundation'), findsOneWidget);
      expect(_in('st_rm_q1', 'Jan – Mar'), findsOneWidget);
      expect(_in('st_rm_q1', 'Done by Ravi · 10 Nov'), findsNothing, reason: 'the link comes first in the caption');
      expect(find.textContaining('CRM & Lead Automation · Done by Ravi'), findsOneWidget);
      expect(tester.widget<Checkbox>(_k('st_rm_tick_r1')).value, isTrue);
      expect(tester.widget<Checkbox>(_k('st_rm_tick_r2')).value, isFalse);
      await tester.tap(_k('st_rm_tick_r2'));
      await tester.pumpAndSettle();
      expect(f.ticks, [(id: 'r2', done: true)]);
      await tester.tap(_k('st_rm_tick_r1'));
      await tester.pumpAndSettle();
      expect(f.ticks.last, (id: 'r1', done: false));
    });

    testWidgets('someone not on the team cannot tick (and is not offered the box); a refusal is shown', (tester) async {
      await _pump(tester, tab: 'roadmap', fake: _FakeStrategies()..setupJson = _setup(manage: false, me: null));
      await tester.tap(_k('st_rm_view_quarterly'));
      await tester.pumpAndSettle();
      expect(tester.widget<Checkbox>(_k('st_rm_tick_r2')).onChanged, isNull);
      await tester.pumpWidget(const SizedBox());
      final f = _FakeStrategies();
      await _pump(tester, tab: 'roadmap', fake: f);
      await tester.tap(_k('st_rm_view_quarterly'));
      await tester.pumpAndSettle();
      f.refuse = const TeamRefusal('You are not on the Marketing team.', status: 403);
      await tester.tap(_k('st_rm_tick_r2'));
      await tester.pumpAndSettle();
      expect(find.text('You are not on the Marketing team.'), findsOneWidget);
      expect(f.ticks, isEmpty);
    });

    testWidgets('the year stepper asks for the year before and after', (tester) async {
      final f = await _pump(tester, tab: 'roadmap');
      await tester.tap(_k('st_rm_next'));
      await tester.pumpAndSettle();
      expect(f.roadmapCalls.last.year, 2027);
      await tester.tap(_k('st_rm_prev'));
      await tester.pumpAndSettle();
      expect(f.roadmapCalls.last.year, 2026);
      await tester.tap(_k('st_rm_prev'));
      await tester.pumpAndSettle();
      expect(f.roadmapCalls.last.year, 2025);
    });

    testWidgets('a manager adds a line to a quarter (its theme is suggested), edits and deletes; a member has none of these', (tester) async {
      final f = await _pump(tester, tab: 'roadmap');
      await tester.tap(_k('st_rm_view_quarterly'));
      await tester.pumpAndSettle();
      await tester.tap(_k('st_rm_add_q1'));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(_k('rm_theme')).controller!.text, 'Foundation');
      await tester.tap(_k('rm_save'));
      await tester.pumpAndSettle();
      expect(_text(tester, _k('rm_error')), 'Give the roadmap line a title.');
      await tester.enterText(_k('rm_title'), 'Brand audit');
      await _pick(tester, 'rm_initiative', 'Launch Bridal Campaign v2');
      await tester.tap(_k('rm_save'));
      await tester.pumpAndSettle();
      var b = f.linesSaved.single.body;
      expect(f.linesSaved.single.id, isNull);
      expect([b['title'], b['year'], b['quarter'], b['theme'], b['initiativeId'], b['planId']], ['Brand audit', 2026, 1, 'Foundation', 'i1', null]);
      // edit
      f.linesSaved.clear();
      await tester.tap(_k('st_rm_menu_r2'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(_k('rm_title')).controller!.text, 'Process & tools');
      await _pick(tester, 'rm_quarter', 'Q2');
      await tester.tap(_k('rm_save'));
      await tester.pumpAndSettle();
      b = f.linesSaved.single.body;
      expect([f.linesSaved.single.id, b['quarter']], ['r2', 2]);
      // delete
      await tester.tap(_k('st_rm_menu_r2'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(_k('st_delete_confirm'));
      await tester.pumpAndSettle();
      expect(f.linesDeleted, ['r2']);
      // a member
      await tester.pumpWidget(const SizedBox());
      await _pump(tester, tab: 'roadmap', fake: _FakeStrategies()..setupJson = _setup(manage: false));
      await tester.tap(_k('st_rm_view_quarterly'));
      await tester.pumpAndSettle();
      expect(_k('st_rm_add'), findsNothing);
      expect(_k('st_rm_add_q1'), findsNothing);
      expect(_k('st_rm_menu_r2'), findsNothing);
    });

    testWidgets('empty states: nothing on the timeline, nothing planned', (tester) async {
      await _pump(tester, tab: 'roadmap', fake: _FakeStrategies()..roadmapJson = {'year': 2026, 'counts': {'items': 0, 'done': 0, 'pct': null}, 'quarters': [], 'timeline': {'year': 2026, 'bars': [], 'undated': []}});
      expect(find.text('No initiative or development project runs in this year yet.'), findsOneWidget);
      expect(find.text('No milestones planned yet'), findsOneWidget);
      await tester.tap(_k('st_rm_view_quarterly'));
      await tester.pumpAndSettle();
      expect(find.text('Nothing planned'), findsNWidgets(4));
    });
  });

  group('Research & Insights', () {
    testWidgets('the four KPIs, Key Insights and Opportunity Areas, and the findings with who entered them', (tester) async {
      final f = await _pump(tester, tab: 'research');
      for (final (key, value, label) in [('rs_kpi_report', '14', 'Research Reports'), ('rs_kpi_insight', '6', 'Market Insights'), ('rs_kpi_competitor', '4', 'Competitor Analysis'), ('rs_kpi_opportunity', '8', 'Opportunities')]) {
        expect(_in(key, value), findsOneWidget, reason: key);
        expect(_in(key, label), findsOneWidget, reason: key);
      }
      expect(_in('rs_key_insights', 'Bridal search interest up by 32% in Kerala'), findsOneWidget);
      expect(_in('rs_key_insights', 'Reels drive 74% of social reach'), findsOneWidget);
      expect(_in('rs_opportunities', 'Expand bridal trials campaign'), findsOneWidget);
      expect(_in('rs_row_f1', 'Instagram Growth Trends'), findsOneWidget);
      expect(_in('rs_row_f1', 'Market insight'), findsOneWidget);
      expect(_in('rs_row_f1', '10 Nov 2026 · Preethi'), findsOneWidget);
      expect(_in('rs_row_f1', '#bridal'), findsOneWidget);
      expect(_k('rs_open_f1'), findsOneWidget, reason: 'it has a link');
      expect(_k('rs_open_f2'), findsNothing, reason: 'no link');
      expect(_text(tester, _k('rs_showing')), 'Showing 1–3 of 7');
      expect(find.text('Market Trend Index'), findsNothing, reason: 'nothing entered measures a trend');
      expect(f.researchCalls.last.q.kind, 'all');
    });

    testWidgets('the kind chips, search and paging cut the list', (tester) async {
      final f = await _pump(tester, tab: 'research');
      await tester.tap(_k('rs_kind_competitor'));
      await tester.pumpAndSettle();
      expect(f.researchCalls.last.q.kind, 'competitor');
      await tester.enterText(_k('rs_search'), 'pricing');
      await tester.pumpAndSettle();
      expect(f.researchCalls.last.q.q, 'pricing');
      expect(f.researchCalls.last.q.kind, 'competitor');
      await tester.tap(_k('rs_next'));
      await tester.pumpAndSettle();
      expect(f.researchCalls.last.q.page, 2);
      await tester.tap(_k('rs_kind_opportunity'));
      await tester.pumpAndSettle();
      expect(f.researchCalls.last.q.page, 1);
      await tester.tap(_k('rs_export'));
      await tester.pumpAndSettle();
      expect(f.researchCalls.last.limit, 100);
    });

    testWidgets('a member adds a finding: the title is needed; the payload has the kind, link and tags; a refused link stays in the form', (tester) async {
      final f = await _pump(tester, tab: 'research');
      await tester.tap(_k('rs_new'));
      await tester.pumpAndSettle();
      await tester.tap(_k('fd_save'));
      await tester.pumpAndSettle();
      expect(_text(tester, _k('fd_error')), 'Give the finding a title.');
      await tester.enterText(_k('fd_title'), 'Bridal search trends');
      await _pick(tester, 'fd_kind', 'Opportunity');
      await tester.enterText(_k('fd_summary'), 'Peaks before the season');
      await tester.enterText(_k('fd_link'), 'javascript:alert(1)');
      await tester.enterText(_k('fd_tags'), 'bridal, Kerala ,');
      f.refuse = const TeamRefusal('The link must start with https://.', field: 'link');
      await tester.tap(_k('fd_save'));
      await tester.pumpAndSettle();
      expect(_text(tester, _k('fd_error')), 'The link must start with https://.');
      expect(f.findingsSaved, isEmpty);
      f.refuse = null;
      await tester.enterText(_k('fd_link'), 'https://drive.google.com/x');
      await tester.tap(_k('fd_save'));
      await tester.pumpAndSettle();
      final b = f.findingsSaved.single.body;
      expect(f.findingsSaved.single.id, isNull);
      expect([b['title'], b['kind'], b['summary'], b['link'], b['brand']], ['Bridal search trends', 'opportunity', 'Peaks before the season', 'https://drive.google.com/x', 'main']);
      expect(b['tags'], ['bridal', 'Kerala']);
      expect(b['date'], TeamFilter.day(DateTime.now()));
    });

    testWidgets('a member edits and deletes only their own findings; a manager any; someone off the team cannot add', (tester) async {
      // member m1 (Preethi): f1 and f3 are hers (authorId m1), f2 is Ashique's (m2)
      final f = await _pump(tester, tab: 'research', fake: _FakeStrategies()..setupJson = _setup(manage: false));
      expect(_k('rs_edit_f1'), findsOneWidget);
      expect(_k('rs_delete_f1'), findsOneWidget);
      expect(_k('rs_edit_f2'), findsNothing);
      expect(_k('rs_delete_f2'), findsNothing);
      await tester.tap(_k('rs_edit_f1'));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(_k('fd_title')).controller!.text, 'Instagram Growth Trends');
      expect(tester.widget<TextField>(_k('fd_link')).controller!.text, 'https://d.test/ig');
      await tester.tap(_k('fd_save'));
      await tester.pumpAndSettle();
      expect(f.findingsSaved.single.id, 'f1');
      await tester.tap(_k('rs_delete_f1'));
      await tester.pumpAndSettle();
      await tester.tap(_k('st_delete_confirm'));
      await tester.pumpAndSettle();
      expect(f.findingsDeleted, ['f1']);
      await tester.pumpWidget(const SizedBox());
      await _pump(tester, tab: 'research');
      expect(_k('rs_edit_f2'), findsOneWidget, reason: 'a manager');
      await tester.pumpWidget(const SizedBox());
      await _pump(tester, tab: 'research', fake: _FakeStrategies()..setupJson = _setup(manage: false, me: null));
      expect(_k('rs_new'), findsNothing);
    });

    testWidgets('empty states', (tester) async {
      await _pump(tester, tab: 'research', fake: _FakeStrategies()..researchJson = {'counts': {}, 'keyInsights': [], 'opportunities': [], 'items': [], 'total': 0, 'page': 1, 'pageSize': 10});
      expect(find.text('No market insight entered in this period.'), findsOneWidget);
      expect(find.text('No opportunity entered in this period.'), findsOneWidget);
      expect(find.textContaining('No findings in this period'), findsOneWidget);
      expect(_in('rs_kpi_report', '0'), findsOneWidget);
    });
  });

  group('Reviews', () {
    testWidgets('the type tabs with counts; the Review Summary donut counted from the outcomes; Key Outcomes; the action items', (tester) async {
      final f = await _pump(tester, tab: 'reviews');
      expect(f.reviewCalls.last, 'strategy', reason: 'the document opens on the Strategy Review');
      expect(_in('rv_tab_strategy', 'Strategy Review'), findsOneWidget);
      expect(_in('rv_tab_strategy', '1'), findsOneWidget);
      expect(_in('rv_tab_project', '0'), findsOneWidget);
      expect(_in('rv_tab_quarterly', '2'), findsOneWidget);
      await tester.tap(_k('rv_tab_quarterly'));
      await tester.pumpAndSettle();
      expect(f.reviewCalls.last, 'quarterly');
      expect(find.text('Review Summary – Q3 2026'), findsOneWidget);
      expect(_text(tester, _k('rv_overall')), '50%');
      expect(find.text('Achieved'), findsOneWidget);
      expect(find.text('Partially Achieved'), findsOneWidget);
      expect(find.text('Not Achieved'), findsOneWidget);
      expect(find.text('50% · 2'), findsOneWidget);
      expect(find.text('25% · 1'), findsNWidgets(2));
      expect(find.text('Lead target achieved (102%)'), findsOneWidget);
      expect(tester.widget<Icon>(_k('rv_outcome_0')).icon, Icons.check_circle_rounded);
      expect(tester.widget<Icon>(_k('rv_outcome_2')).icon, Icons.timelapse_rounded);
      expect(tester.widget<Icon>(_k('rv_outcome_3')).icon, Icons.cancel_rounded);
      expect(_in('rv_action_a1', 'Complete bridal vertical go-to-market'), findsOneWidget);
      expect(_in('rv_action_a1', 'Preethi'), findsOneWidget);
      expect(_in('rv_action_a1', 'High'), findsOneWidget);
      expect(_in('rv_action_a1', '20 Nov 2026'), findsOneWidget);
      expect(_in('rv_action_a1', 'In Progress'), findsOneWidget);
      expect(_in('rv_action_a2', 'Open'), findsOneWidget);
      expect(_in('rv_action_a3', 'Done'), findsOneWidget);
      expect(_in('rv_action_a3', '—'), findsNWidgets(2), reason: 'no owner, no target date');
    });

    testWidgets('a type with no review in the range says so; a type with two reviews offers a picker for the other one', (tester) async {
      await _pump(tester, tab: 'reviews');
      await tester.tap(_k('rv_tab_project'));
      await tester.pumpAndSettle();
      expect(find.textContaining('No project review in this period'), findsOneWidget);
      expect(_k('rv_overall'), findsNothing);
      await tester.tap(_k('rv_tab_quarterly'));
      await tester.pumpAndSettle();
      expect(find.text('Review Summary – Q3 2026'), findsOneWidget, reason: 'the latest first');
      await tester.tap(_k('rv_picker'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Q2 2026 ·').last);
      await tester.pumpAndSettle();
      expect(find.text('Review Summary – Q2 2026'), findsOneWidget);
    });

    testWidgets('the owner of an action item ticks it (done); a manager any; someone else cannot', (tester) async {
      // member m1 (Preethi): a1 is hers, a2 is Ashique's, a3 has no owner
      final f = await _pump(tester, tab: 'reviews', fake: _FakeStrategies()..setupJson = _setup(manage: false));
      await tester.tap(_k('rv_tab_quarterly'));
      await tester.pumpAndSettle();
      expect(tester.widget<Checkbox>(_k('rv_action_tick_a1')).onChanged, isNotNull);
      expect(tester.widget<Checkbox>(_k('rv_action_tick_a2')).onChanged, isNull);
      expect(tester.widget<Checkbox>(_k('rv_action_tick_a3')).onChanged, isNull);
      expect(tester.widget<Checkbox>(_k('rv_action_tick_a3')).value, isTrue);
      await tester.tap(_k('rv_action_tick_a1'));
      await tester.pumpAndSettle();
      expect(f.actions, [(review: 'rv1', action: 'a1', status: 'done')]);
      await tester.pumpWidget(const SizedBox());
      final m = await _pump(tester, tab: 'reviews');
      await tester.tap(_k('rv_tab_quarterly'));
      await tester.pumpAndSettle();
      await tester.tap(_k('rv_action_tick_a3'));
      await tester.pumpAndSettle();
      expect(m.actions.last, (review: 'rv1', action: 'a3', status: 'open'), reason: 'ticking a done item reopens it');
      m.refuse = const TeamRefusal('You can only change the action items given to you.', status: 403);
      await tester.tap(_k('rv_action_tick_a2'));
      await tester.pumpAndSettle();
      expect(find.text('You can only change the action items given to you.'), findsOneWidget);
    });

    testWidgets('only a manager sees New Review, Edit and Delete', (tester) async {
      await _pump(tester, tab: 'reviews', fake: _FakeStrategies()..setupJson = _setup(manage: false));
      expect(_k('rv_new'), findsNothing);
      expect(_k('rv_edit'), findsNothing);
      expect(_k('rv_delete'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await _pump(tester, tab: 'reviews');
      expect(_k('rv_new'), findsOneWidget);
      expect(_k('rv_edit'), findsOneWidget);
      expect(_k('rv_delete'), findsOneWidget);
    });

    testWidgets('a new review: a period and at least one outcome are needed; the payload has the outcomes and the action items', (tester) async {
      final f = await _pump(tester, tab: 'reviews');
      await tester.tap(_k('rv_tab_quarterly'));
      await tester.pumpAndSettle();
      await tester.tap(_k('rv_new'));
      await tester.pumpAndSettle();
      expect(tester.widget<DropdownButtonFormField<String>>(_k('rv_type')).initialValue, 'quarterly', reason: 'the open tab\'s type');
      await tester.tap(_k('rv_save'));
      await tester.pumpAndSettle();
      expect(_text(tester, _k('rv_error')), 'Name the period or subject of the review (for example Q3 2026).');
      await tester.enterText(_k('rv_period'), 'Q4 2026');
      await tester.tap(_k('rv_save'));
      await tester.pumpAndSettle();
      expect(_text(tester, _k('rv_error')), 'Add at least one outcome — the score is counted from them.');
      expect(f.reviewsSaved, isEmpty);
      await tester.enterText(_k('rv_outcome_text_0'), 'Lead target achieved');
      await tester.tap(_k('rv_add_outcome'));
      await tester.pumpAndSettle();
      await tester.enterText(_k('rv_outcome_text_1'), 'Launch delayed');
      await _pick(tester, 'rv_outcome_state_1', 'Not achieved');
      await tester.tap(_k('rv_add_action'));
      await tester.pumpAndSettle();
      await tester.enterText(_k('rv_action_text_0'), 'Finalise locations');
      await _pick(tester, 'rv_action_owner_0', 'Ashique');
      await _pick(tester, 'rv_action_priority_0', 'High');
      await tester.tap(_k('rv_add_action'));
      await tester.pumpAndSettle();
      await tester.tap(_k('rv_save'));
      await tester.pumpAndSettle();
      final b = f.reviewsSaved.single.body;
      expect(f.reviewsSaved.single.id, isNull);
      expect(b['type'], 'quarterly');
      expect(b['periodLabel'], 'Q4 2026');
      expect(b['outcomes'], [{'text': 'Lead target achieved', 'state': 'achieved'}, {'text': 'Launch delayed', 'state': 'missed'}]);
      expect((b['actionItems'] as List).length, 1, reason: 'the empty second action row is dropped');
      final a = (b['actionItems'] as List).single as Map;
      expect([a['id'], a['text'], a['ownerId'], a['priority'], a['status'], a['targetDate']], [null, 'Finalise locations', 'm2', 'high', 'open', null]);
      expect(b['reviewDate'], TeamFilter.day(DateTime.now()));
    });

    testWidgets('editing a review prefills it and keeps each action item\'s id (so a tick survives); a refusal stays in the form', (tester) async {
      final f = await _pump(tester, tab: 'reviews');
      await tester.tap(_k('rv_tab_quarterly'));
      await tester.pumpAndSettle();
      await tester.tap(_k('rv_edit'));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(_k('rv_period')).controller!.text, 'Q3 2026');
      expect(tester.widget<TextField>(_k('rv_outcome_text_3')).controller!.text, 'New service launch delayed');
      expect(tester.widget<TextField>(_k('rv_action_text_1')).controller!.text, 'Finalise Kerala expansion locations');
      f.refuse = const TeamRefusal('Only a Marketing Manager can change a review.', status: 403);
      await tester.tap(_k('rv_save'));
      await tester.pumpAndSettle();
      expect(_text(tester, _k('rv_error')), 'Only a Marketing Manager can change a review.');
      f.refuse = null;
      await tester.tap(_k('rv_outcome_del_3'));
      await tester.pumpAndSettle();
      await tester.tap(_k('rv_action_del_0'));
      await tester.pumpAndSettle();
      await tester.tap(_k('rv_save'));
      await tester.pumpAndSettle();
      expect(f.reviewsSaved.single.id, 'rv1');
      final b = f.reviewsSaved.single.body;
      expect((b['outcomes'] as List).length, 3);
      expect([for (final a in b['actionItems'] as List) (a as Map)['id']], ['a2', 'a3']);
      expect((b['actionItems'] as List).first['targetDate'], '2026-10-01');
    });

    testWidgets('Delete asks first', (tester) async {
      final f = await _pump(tester, tab: 'reviews');
      await tester.tap(_k('rv_tab_quarterly'));
      await tester.pumpAndSettle();
      await tester.tap(_k('rv_delete'));
      await tester.pumpAndSettle();
      await tester.tap(_k('st_delete_cancel'));
      await tester.pumpAndSettle();
      expect(f.reviewsDeleted, isEmpty);
      await tester.tap(_k('rv_delete'));
      await tester.pumpAndSettle();
      await tester.tap(_k('st_delete_confirm'));
      await tester.pumpAndSettle();
      expect(f.reviewsDeleted, ['rv1']);
    });
  });

  group('what the service asks the server for', () {
    Future<List<RequestOptions>> capture(Future<void> Function(MarketingStrategyService s) run, {int status = 200, String body = '{}'}) async {
      final seen = <RequestOptions>[];
      await run(MarketingStrategyService(Dio()..httpClientAdapter = _Capture(seen, status: status, body: body)));
      return seen;
    }

    final f = TeamFilter(from: DateTime(2026, 11, 1), to: DateTime(2026, 11, 30), brand: TeamBrand.kerala);

    test('every read carries the shared range and brand; each adds its own cut', () async {
      final reqs = await capture((s) async {
        await s.overview(f);
        await s.plans(f);
        await s.initiatives(f, const WorkQuery(status: 'at_risk', focusArea: 'Operations', q: ' crm ', page: 3));
        await s.projects(f, const WorkQuery(status: 'on_hold'), limit: 100);
        await s.roadmap(f, year: 2027);
        await s.research(f, const ResearchQuery(kind: 'opportunity', q: ' bridal ', page: 2));
        await s.reviews(f, const ReviewQuery(type: 'quarterly'));
      });
      expect(reqs.map((r) => r.path), [
        '/marketing/strategies/overview', '/marketing/strategies/plans', '/marketing/strategies/initiatives', '/marketing/strategies/projects', '/marketing/strategies/roadmap', '/marketing/strategies/research', '/marketing/strategies/reviews',
      ]);
      for (final r in reqs) {
        expect(r.method, 'GET', reason: r.path);
        expect(r.queryParameters, containsPair('from', '2026-11-01'), reason: r.path);
        expect(r.queryParameters, containsPair('to', '2026-11-30'), reason: r.path);
        expect(r.queryParameters, containsPair('brand', 'kerala'), reason: r.path);
      }
      expect(reqs[2].queryParameters, containsPair('status', 'at_risk'));
      expect(reqs[2].queryParameters, containsPair('focusArea', 'Operations'));
      expect(reqs[2].queryParameters, containsPair('q', 'crm'));
      expect(reqs[2].queryParameters, containsPair('page', 3));
      expect(reqs[2].queryParameters.containsKey('limit'), isFalse);
      expect(reqs[3].queryParameters, containsPair('limit', 100));
      expect(reqs[4].queryParameters, containsPair('year', 2027));
      expect(reqs[5].queryParameters, containsPair('kind', 'opportunity'));
      expect(reqs[5].queryParameters, containsPair('q', 'bridal'));
      expect(reqs[5].queryParameters, containsPair('page', 2));
      expect(reqs[6].queryParameters, containsPair('type', 'quarterly'));
    });

    test('"all", an empty search and no year are not sent', () async {
      final reqs = await capture((s) async {
        await s.initiatives(f, const WorkQuery());
        await s.research(f, const ResearchQuery());
        await s.roadmap(f);
        await s.reviews(f, const ReviewQuery(type: 'all'));
        await s.initiative('i1');
        await s.project('d1');
        await s.setup();
      });
      expect(reqs[0].queryParameters.keys.toSet(), {'from', 'to', 'brand', 'page'});
      expect(reqs[1].queryParameters.keys.toSet(), {'from', 'to', 'brand', 'page'});
      expect(reqs[2].queryParameters.containsKey('year'), isFalse);
      expect(reqs[3].queryParameters.containsKey('type'), isFalse);
      expect(reqs.skip(4).map((r) => r.path), ['/marketing/strategies/initiatives/i1', '/marketing/strategies/projects/d1', '/marketing/strategies/setup']);
    });

    test('saving posts or puts by whether there is an id; deleting and the small writes use their own verbs', () async {
      final reqs = await capture((s) async {
        await s.savePlan({'title': 'x'});
        await s.savePlan({'title': 'y'}, id: 'p1');
        await s.deletePlan('p1');
        await s.saveInitiative({'title': 'x'});
        await s.saveInitiative({'title': 'y'}, id: 'i1');
        await s.deleteInitiative('i1');
        await s.saveProject({'name': 'x'});
        await s.saveProject({'name': 'y'}, id: 'd1');
        await s.deleteProject('d1');
        await s.saveRoadmapLine({'title': 'x'});
        await s.saveRoadmapLine({'title': 'y'}, id: 'r1');
        await s.deleteRoadmapLine('r1');
        await s.tickRoadmapLine('r1', done: true);
        await s.saveFinding({'title': 'x'});
        await s.saveFinding({'title': 'y'}, id: 'f1');
        await s.deleteFinding('f1');
        await s.saveReview({'type': 'quarterly'});
        await s.saveReview({'type': 'quarterly'}, id: 'rv1');
        await s.deleteReview('rv1');
        await s.setActionStatus('rv1', 'a1', 'done');
      });
      expect([for (final r in reqs) '${r.method} ${r.path}'], [
        'POST /marketing/strategies/plans', 'PUT /marketing/strategies/plans/p1', 'DELETE /marketing/strategies/plans/p1',
        'POST /marketing/strategies/initiatives', 'PUT /marketing/strategies/initiatives/i1', 'DELETE /marketing/strategies/initiatives/i1',
        'POST /marketing/strategies/projects', 'PUT /marketing/strategies/projects/d1', 'DELETE /marketing/strategies/projects/d1',
        'POST /marketing/strategies/roadmap', 'PUT /marketing/strategies/roadmap/r1', 'DELETE /marketing/strategies/roadmap/r1', 'POST /marketing/strategies/roadmap/r1/tick',
        'POST /marketing/strategies/research', 'PUT /marketing/strategies/research/f1', 'DELETE /marketing/strategies/research/f1',
        'POST /marketing/strategies/reviews', 'PUT /marketing/strategies/reviews/rv1', 'DELETE /marketing/strategies/reviews/rv1', 'PATCH /marketing/strategies/reviews/rv1/actions/a1',
      ]);
      expect(reqs[0].data, {'title': 'x'});
      expect(reqs[12].data, {'done': true});
      expect(reqs[19].data, {'status': 'done'});
    });

    test('a server refusal comes back as its own words, with its field; other failures are plain app errors', () async {
      final dio = Dio()..httpClientAdapter = _Capture([], status: 409, body: '{"message":"This initiative has 3 tasks tied to it. Cancel it instead, so the record stays.","field":"x"}');
      await expectLater(MarketingStrategyService(dio).deleteInitiative('i1'), throwsA(isA<TeamRefusal>().having((e) => e.message, 'message', 'This initiative has 3 tasks tied to it. Cancel it instead, so the record stays.').having((e) => e.status, 'status', 409).having((e) => e.field, 'field', 'x')));
      for (final status in [400, 403, 404]) {
        await expectLater(MarketingStrategyService(Dio()..httpClientAdapter = _Capture([], status: status, body: '{"message":"No."}')).saveReview({'type': 'x'}), throwsA(isA<TeamRefusal>().having((e) => e.status, 'status', status)));
      }
      await expectLater(MarketingStrategyService(Dio()..httpClientAdapter = _Capture([], status: 500, body: '{"message":"boom"}')).saveReview({'type': 'x'}), throwsA(isA<AppException>()));
      await expectLater(MarketingStrategyService(Dio()..httpClientAdapter = _Capture([], status: 500)).overview(f), throwsA(isA<AppException>()));
    });
  });

  group('a new date range or brand starts again', () {
    testWidgets('the initiatives table goes back to page 1', (tester) async {
      final f = await _pump(tester, tab: 'initiatives');
      await tester.tap(_k('in_next'));
      await tester.pumpAndSettle();
      expect(f.initiativeCalls.last.q.page, 2);
      await tester.tap(_k('team_brand_pill'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kerala').last);
      await tester.pumpAndSettle();
      expect(f.initiativeCalls.last.f.brand, TeamBrand.kerala);
      expect(f.initiativeCalls.last.q.page, 1);
    });

    testWidgets('the research list goes back to page 1', (tester) async {
      final f = await _pump(tester, tab: 'research');
      await tester.tap(_k('rs_next'));
      await tester.pumpAndSettle();
      expect(f.researchCalls.last.q.page, 2);
      await tester.tap(_k('team_brand_pill'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Main').last);
      await tester.pumpAndSettle();
      expect(f.researchCalls.last.q.page, 1);
    });

    testWidgets('the roadmap goes back to the year of the range after a detour with the year stepper', (tester) async {
      final f = await _pump(tester, tab: 'roadmap');
      await tester.tap(_k('st_rm_next'));
      await tester.pumpAndSettle();
      expect(f.roadmapCalls.last.year, 2027);
      await tester.tap(_k('team_brand_pill'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kerala').last);
      await tester.pumpAndSettle();
      expect(f.roadmapCalls.last.year, isNull);
      expect(f.roadmapCalls.last.f.brand, TeamBrand.kerala);
    });
  });

  group('the setup (who may manage, the team list)', () {
    testWidgets('it is read once up front, so the forms already know it', (tester) async {
      final f = await _pump(tester);
      expect(f.setupCalls, 1);
      await tester.tap(_k('st_new_initiative'));
      await tester.pumpAndSettle();
      expect(f.setupCalls, 1, reason: 'the form did not ask again');
      expect(_k('work_status'), findsOneWidget);
    });

    testWidgets('a form opened before the setup arrives waits for it (and then offers the team), instead of showing a wrong owner', (tester) async {
      final f = _FakeStrategies()..setupGate = Completer<void>();
      await _pump(tester, fake: f);
      await tester.tap(_k('st_new_initiative'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(_k('work_title'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      f.setupGate!.complete();
      await tester.pumpAndSettle();
      expect(_k('work_title'), findsOneWidget);
      await _pick(tester, 'work_owner', 'Ashique');
      await tester.enterText(_k('work_title'), 'Late setup');
      await tester.tap(_k('work_save'));
      await tester.pumpAndSettle();
      expect(f.initiativesSaved.single.body['ownerId'], 'm2');
    });

    testWidgets('a setup that cannot be read still lets a member open the form; the server decides', (tester) async {
      final f = _FakeStrategies()..setupFails = true;
      await _pump(tester, fake: f);
      await tester.tap(_k('st_new_initiative'));
      await tester.pumpAndSettle();
      expect(_k('work_title'), findsOneWidget);
      expect(_k('work_status'), findsNothing, reason: 'with nothing known, only member fields');
    });
  });

  group('the CSV every report exports', () {
    test('initiatives and projects: no progress is blank (never 0), hours only for initiatives', () {
      final items = [WorkItem.fromJson(_work('i1', minutes: 135)), WorkItem.fromJson(_work('i2', source: 'none', progress: 0, noOwner: true, due: null, status: 'in_progress'))];
      final rows = workCsv(items, project: false);
      expect(rows[0], ['Initiative', 'Focus area', 'Impact', 'Brand', 'Owner', 'Progress %', 'Progress from', 'Status', 'Start', 'Due', 'Hours logged']);
      expect(rows[1], ['Launch Bridal Campaign v2', 'Revenue & Lead Growth', 'High', 'main', 'Abhiram', 75, '3 of 4 tasks done', 'On Track', '2026-11-01', '2026-11-15', '2.3']);
      expect(rows[2][5], '', reason: 'not set is blank');
      expect(rows[2][4], '');
      expect(rows[2][9], '');
      final p = workCsv([WorkItem.fromJson(_work('d1', kind: 'project', category: 'Technology'))], project: true);
      expect(p[0], ['Project', 'Category', 'Brand', 'Owner', 'Progress %', 'Progress from', 'Status', 'Start', 'Due']);
      expect(p[1][1], 'Technology');
      expect(p[1].length, 9);
    });

    test('plans, findings and action items', () {
      final plans = plansCsv(PlansData.fromJson(_plans()).items);
      expect(plans[0], ['Plan', 'Focus area', 'Year', 'Brand', 'Status', 'Owner', 'Initiatives', 'Projects', 'Goals']);
      expect(plans[1], ['Brand plan', 'Brand Growth', 2026, 'main', 'Active', 'Ashique', 3, 1, 'Increase qualified leads by 40% | Improve engagement']);
      final f = findingsCsv(ResearchData.fromJson(_research()).items);
      expect(f[1], ['Instagram Growth Trends', 'Market insight', '2026-11-10', 'main', 'Preethi', 'https://d.test/ig', 'bridal', 'A short summary']);
      final a = actionItemsCsv(StrategyReview.fromJson(_review('rv1', 'Q3 2026')));
      expect(a[0], ['Review', 'Action item', 'Owner', 'Priority', 'Target date', 'Status']);
      expect(a[1], ['Q3 2026 (Quarterly Review)', 'Complete bridal vertical go-to-market', 'Preethi', 'High', '2026-11-20', 'In Progress']);
      expect(a[3], ['Q3 2026 (Quarterly Review)', 'Review Q4 budget and strategy', '', 'Medium', '', 'Done']);
    });

    test('the roadmap: milestones then the timeline bars, with the ones with no end day too', () {
      final rows = roadmapCsv(RoadmapData.fromJson(_roadmap()));
      expect(rows[0].length, 12);
      expect(rows[1], ['Milestone', 'Q1', 'Foundation', 'Brand consolidation', 'Yes', 'Ravi', rows[1][6], '', '', '', '', '']);
      expect(rows[1][6], matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));
      expect(rows[2].sublist(0, 6), ['Milestone', 'Q1', 'Foundation', 'Process & tools', 'No', '']);
      expect(rows.where((r) => r[0] == 'Milestone').length, 4);
      final bars = rows.where((r) => r[0] == 'Initiative' || r[0] == 'Project').toList();
      expect(bars.map((r) => r[3]), ['Brand Growth Campaign', 'Website v2', 'Hyderabad Studio Setup']);
      expect(bars[0].sublist(7), ['2026-01-15', '2026-04-30', 70, 'On Track', 'Abhiram']);
      expect(bars[1][9], '', reason: 'no progress is blank');
      expect(bars[2][8], '', reason: 'no end day');
    });

    testWidgets('every report has an Export button', (tester) async {
      await _pump(tester, tab: 'plans');
      expect(_k('pl_export'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await _pump(tester, tab: 'roadmap');
      expect(_k('st_rm_export'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await _pump(tester, tab: 'reviews');
      expect(_k('rv_export'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await _pump(tester, tab: 'research');
      expect(_k('rs_export'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await _pump(tester, tab: 'projects');
      expect(_k('dp_export'), findsOneWidget);
    });
  });

  group('the pieces', () {
    test('days, hours and short focus names', () {
      expect(strategyDay('2026-11-15'), '15 Nov 2026');
      expect(strategyDay('2026-11-15', pattern: 'd MMM'), '15 Nov');
      expect(strategyDay(null), '—');
      expect(strategyDay(''), '—');
      expect(strategyDay('nonsense'), 'nonsense');
      expect(hoursText(0), '0m');
      expect(hoursText(45), '45m');
      expect(hoursText(60), '1h');
      expect(hoursText(135), '2h 15m');
      expect(shortFocus('Brand & Market Positioning'), 'Brand');
      expect(shortFocus('Operations & Automation'), 'Operatio…');
      expect(shortFocus('  Team  Capability '), 'Team');
    });

    test('colours: every status and priority has its own', () {
      expect({for (final s in ['on_track', 'in_progress', 'at_risk', 'on_hold', 'completed']) workStatusColor(s)}.length, 5);
      expect({for (final s in ['active', 'in_progress', 'on_hold', 'completed']) planStatusColor(s)}.length, 4);
      expect({for (final s in ['high', 'medium', 'low']) priorityColor(s)}.length, 3);
      expect({for (final s in ['achieved', 'partial', 'missed']) outcomeColor(s)}.length, 3);
      expect({for (final s in ['achieved', 'partial', 'missed']) outcomeIcon(s)}.length, 3);
    });

    test('who may change a piece of work: a manager, or the owner who was chosen (not one worked out from tasks)', () {
      final w = WorkItem.fromJson(_work('i1', ownerId: 'm5'));
      expect(canChangeWork(StrategySetup.fromJson(_setup(manage: true, me: null)), w), isTrue);
      expect(canChangeWork(StrategySetup.fromJson(_setup(manage: false, me: 'm5')), w), isTrue);
      expect(canChangeWork(StrategySetup.fromJson(_setup(manage: false, me: 'm6')), w), isFalse);
      expect(canChangeWork(StrategySetup.fromJson(_setup(manage: false, me: null)), w), isFalse);
      expect(canChangeWork(StrategySetup.fromJson(_setup(manage: false, me: 'm5')), WorkItem.fromJson(_work('i1', ownerId: 'm5', ownerSource: 'tasks'))), isFalse);
      expect(canChangeWork(StrategySetup.fromJson(_setup(manage: false, me: 'm5')), WorkItem.fromJson(_work('i1', noOwner: true))), isFalse);
    });
  });

  group('a phone', () {
    testWidgets('every tab fits a 390-wide screen without overflow, with long names too', (tester) async {
      final long = 'A very long strategic initiative name that goes on and on';
      final f = _FakeStrategies()
        ..overviewJson = ({
          ..._overview(),
          'initiatives': [_work('i1', title: long, ownerName: 'Abhiram Krishnamoorthy Nair', focus: 'Brand & Market Positioning and Everything Else')],
          'projects': [_work('d1', kind: 'project', title: long, description: long)],
          'research': [_finding('f1', long, 'report')],
        })
        ..initiativesJson = _workList(items: [_work('i1', title: long, ownerName: 'Abhiram Krishnamoorthy Nair', focus: 'Brand & Market Positioning and Everything Else')])
        ..projectsJson = _workList(kind: 'project', items: [_work('d1', kind: 'project', title: long, category: 'Technology and Development')]);
      await _pump(tester, fake: f, size: const Size(390, 2400));
      expect(tester.takeException(), isNull, reason: 'overview');
      Future<void> open(String t) async {
        await tester.ensureVisible(_k('st_tab_$t'));
        await tester.tap(_k('st_tab_$t'));
        await tester.pumpAndSettle();
      }

      for (final t in ['plans', 'projects', 'roadmap', 'initiatives', 'research', 'reviews']) {
        await open(t);
        expect(tester.takeException(), isNull, reason: t);
      }
      await open('roadmap');
      await tester.tap(_k('st_rm_view_quarterly'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'quarterly');
      await open('reviews');
      await tester.tap(_k('rv_tab_quarterly'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'a review with its table');
    });

    testWidgets('the forms open as bottom sheets on a phone and fit', (tester) async {
      await _pump(tester, size: const Size(390, 900));
      await tester.tap(_k('st_new_initiative'));
      await tester.pumpAndSettle();
      expect(_k('work_title'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(_k('work_cancel'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(_k('st_tab_reviews'));
      await tester.tap(_k('st_tab_reviews'));
      await tester.pumpAndSettle();
      await tester.tap(_k('rv_new'));
      await tester.pumpAndSettle();
      await tester.tap(_k('rv_add_action'));
      await tester.pumpAndSettle();
      expect(_k('rv_action_text_0'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(_k('rv_cancel'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(_k('st_tab_plans'));
      await tester.tap(_k('st_tab_plans'));
      await tester.pumpAndSettle();
      await _scrollTo(tester, _k('pl_new'), 'strategies_plans_list');
      await tester.tap(_k('pl_new'));
      await tester.pumpAndSettle();
      expect(_k('plan_title'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the detail sheet fits a phone', (tester) async {
      await _pump(tester, tab: 'initiatives', size: const Size(390, 900));
      final cell = find.descendant(of: _k('in_row_i1'), matching: find.text('Meta Lead Quality Improvement'));
      await _scrollTo(tester, cell, 'strategies_initiative_list');
      await tester.tap(cell);
      await tester.pumpAndSettle();
      expect(_k('wd_title'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  // ── the audit's fixes (S1–S4) ───────────────────────────────────────────────
  group('audit fixes: how the new payloads read', () {
    test('strategy work logged per record and on the Overview (every type listed, so a step nobody logged is 0)', () {
      final w = StrategyWork.fromJson({'total': 3, 'logs': 1, 'counts': [{'metric': 'First drafts prepared', 'total': 2}, {'metric': 'Strategy meetings held', 'total': 1}], 'types': ['First drafts prepared', 'Strategy meetings held', 'Executions done'], 'tracked': true});
      expect([w.of('First drafts prepared'), w.of('Executions done'), w.tracked], [2, 0, true]);
      expect(WorkItem.fromJson({..._work('i1'), 'strategyWork': {'total': 3}}).strategyWork.total, 3);
      expect(WorkItem.fromJson(_work('i1')).strategyWork.tracked, isFalse);
      expect(StrategyOverview.fromJson(const {}).strategyWork.counts, isEmpty);
    });

    test('the enquiry trend: honestly labelled, "—" with nothing to compare (never 0%), and what it is made of', () {
      final t = EnquiryTrend.fromJson({'label': 'Enquiry trend vs last quarter', 'quarter': 'Q4 2026', 'previousQuarter': 'Q3 2026', 'elapsedDays': 49, 'now': {'leads': 84}, 'before': {'leads': 75, 'to': '2026-08-18'}, 'change': 12});
      expect(enquiryTrendValue(t), '+12%');
      expect(enquiryTrendNote(t), '84 so far in Q4 2026 vs 75 in the same 49 days of Q3 2026');
      expect(enquiryTrendValue(EnquiryTrend.fromJson({'change': -8})), '−8%');
      expect(enquiryTrendValue(EnquiryTrend.fromJson({'quarter': 'Q4 2026', 'change': null})), '—');
      expect(ResearchData.fromJson(const {}).enquiryTrend.label, 'Enquiry trend vs last quarter');
    });

    test('a review\'s link reads as it stands now; the picker offers plans, projects and initiatives, and keeps a link no longer listed', () {
      final r = StrategyReview.fromJson({..._review('rv9', 'Website v3'), 'linked': {'kind': 'project', 'id': 'p1', 'title': 'Website v3', 'status': 'on_track', 'statusLabel': 'On Track', 'progress': 70, 'progressSource': 'tasks'}});
      expect([r.linked!.kindLabel, r.linked!.progress, r.linked!.hasProgress], ['Development project', 70, true]);
      expect(StrategyReview.fromJson(_review('rv1', 'Q3')).linked, isNull);
      final setup = StrategySetup.fromJson({..._setup(), 'projects': [{'id': 'p1', 'title': 'Website v3'}]});
      final options = reviewLinkOptions(setup, null);
      expect(options.first.$1, isNull);
      expect(options.any((o) => o.$1 == 'project:p1'), isTrue);
      expect(reviewLinkOptions(setup, const ReviewLink(kind: 'initiative', id: 'gone', title: 'Old push')).last, ('initiative:gone', 'Initiative · Old push'));
    });

    test('the Overview exports its KPIs, focus areas, work and the strategy work logged; an unknown progress is blank', () {
      final o = StrategyOverview.fromJson({..._overview(), 'strategyWork': {'tracked': true, 'types': ['First drafts prepared'], 'counts': [{'metric': 'First drafts prepared', 'total': 4}]}});
      final csv = overviewCsv(o);
      expect(csv.first, ['Section', 'Item', 'Value', 'Detail']);
      expect(csv.firstWhere((r) => r[1] == 'Active strategies')[2], o.kpis.activeStrategies);
      expect(csv.firstWhere((r) => r[0] == 'Strategy work logged'), ['Strategy work logged', 'First drafts prepared', 4, '']);
      final none = overviewCsv(StrategyOverview.fromJson({'initiatives': [{..._work('i1'), 'progressSource': 'none'}]}));
      expect(none.firstWhere((r) => r[0] == 'Initiative')[2], '');
    });
  });

  group('audit fixes: the screens', () {
    testWidgets('Research: the enquiry trend vs last quarter is the first card', (tester) async {
      final f = _FakeStrategies()..researchJson = {..._research(), 'enquiryTrend': {'label': 'Enquiry trend vs last quarter', 'quarter': 'Q4 2026', 'previousQuarter': 'Q3 2026', 'elapsedDays': 49, 'now': {'leads': 84}, 'before': {'leads': 75}, 'change': 12}};
      await _pump(tester, tab: 'research', fake: f);
      expect(find.descendant(of: _k('rs_kpi_trend'), matching: find.text('+12%')), findsOneWidget);
      expect(find.descendant(of: _k('rs_kpi_trend'), matching: find.text('Enquiry trend vs last quarter')), findsOneWidget);
    });

    testWidgets('Research: no earlier enquiries → "—", not 0%', (tester) async {
      final f = _FakeStrategies()..researchJson = {..._research(), 'enquiryTrend': {'quarter': 'Q4 2026', 'previousQuarter': 'Q3 2026', 'elapsedDays': 10, 'now': {'leads': 4}, 'before': {'leads': 0}, 'change': null}};
      await _pump(tester, tab: 'research', fake: f);
      expect(find.descendant(of: _k('rs_kpi_trend'), matching: find.text('—')), findsOneWidget);
    });

    testWidgets('Reviews: a linked review shows what it reviews, its status and its progress now', (tester) async {
      final f = _FakeStrategies()..reviewsJson = {'type': 'strategy', 'counts': {'strategy': 1}, 'items': [{..._review('rv9', 'Website v3', type: 'strategy'), 'linked': {'kind': 'project', 'id': 'p1', 'title': 'Website v3', 'status': 'on_track', 'statusLabel': 'On Track', 'progress': 70, 'progressSource': 'tasks'}}]};
      await _pump(tester, tab: 'reviews', fake: f);
      expect(_k('rv_linked'), findsOneWidget);
      expect(find.descendant(of: _k('rv_linked'), matching: find.text('On Track')), findsOneWidget);
      expect(_k('rv_linked_progress'), findsOneWidget);
    });

    testWidgets('a new review can name what it reviews; the payload carries the link', (tester) async {
      final f = _FakeStrategies()..setupJson = {..._setup(), 'projects': [{'id': 'p1', 'title': 'Website v3'}]};
      await _pump(tester, tab: 'reviews', fake: f);
      await tester.tap(_k('rv_new'));
      await tester.pumpAndSettle();
      await tester.enterText(_k('rv_period'), 'Website v3 mid-point');
      await tester.enterText(_k('rv_outcome_text_0'), 'Design signed off');
      await _pick(tester, 'rv_link', 'Project · Website v3');
      await tester.tap(_k('rv_save'));
      await tester.pumpAndSettle();
      final b = f.reviewsSaved.single.body;
      expect([b['linkKind'], b['linkId']], ['project', 'p1']);
    });

    testWidgets('a review with no link sends none (and an edit can take one away)', (tester) async {
      final f = await _pump(tester, tab: 'reviews');
      await tester.tap(_k('rv_new'));
      await tester.pumpAndSettle();
      await tester.enterText(_k('rv_period'), 'Q4 2026');
      await tester.enterText(_k('rv_outcome_text_0'), 'Lead target achieved');
      await tester.tap(_k('rv_save'));
      await tester.pumpAndSettle();
      final b = f.reviewsSaved.single.body;
      expect([b['linkKind'], b['linkId']], [null, null]);
    });

    testWidgets('a work item\'s detail lists the strategy steps logged on it', (tester) async {
      final f = _FakeStrategies()..detailOverrides['i1'] = {'strategyWork': {'total': 3, 'logs': 1, 'counts': [{'metric': 'First drafts prepared', 'total': 2}, {'metric': 'Strategy meetings held', 'total': 1}]}};
      await _pump(tester, tab: 'initiatives', fake: f);
      await tester.tap(_k('in_row_i1'));
      await tester.pumpAndSettle();
      expect(find.text('First drafts prepared  2'), findsOneWidget);
      expect(find.text('Strategy meetings held  1'), findsOneWidget);
    });

    testWidgets('Overview: Export CSV, and the strategy work logged in the range (every step listed)', (tester) async {
      final f = _FakeStrategies()..overviewJson = {..._overview(), 'strategyWork': {'tracked': true, 'logs': 2, 'types': ['First drafts prepared', 'Executions done'], 'counts': [{'metric': 'First drafts prepared', 'total': 4}]}};
      await _pump(tester, fake: f);
      expect(_k('st_overview_export'), findsOneWidget);
      expect(_k('st_strategy_work'), findsOneWidget);
      expect(find.text('First drafts prepared  4'), findsOneWidget);
      expect(find.text('Executions done  0'), findsOneWidget);
    });
  });
}

