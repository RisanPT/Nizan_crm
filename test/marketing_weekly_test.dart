import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/theme/app_theme.dart';
import 'package:nizan_crm/features/marketing/data/team_models.dart';
import 'package:nizan_crm/features/marketing/data/weekly_models.dart';
import 'package:nizan_crm/features/marketing/presentation/kit/mkt_kit.dart';
import 'package:nizan_crm/features/marketing/presentation/weekly/weekly_report_screen.dart';
import 'package:nizan_crm/features/marketing/presentation/weekly/weekly_widgets.dart';
import 'package:nizan_crm/features/marketing/services/team_service.dart';
import 'package:nizan_crm/features/marketing/services/weekly_service.dart';

// The Marketing Weekly Report: one page — KPI cards, day-by-day performance, lead quality and sources, individual insights, campaigns and
// ads, recent activity, production, revenue and collection, key insights — and the Export.

Map<String, dynamic> _day(String day, int weekday, int leads, int bookings, num revenue, {Map<String, dynamic>? before}) => {
      'day': day, 'weekday': weekday, 'now': {'leads': leads, 'bookings': bookings, 'revenue': revenue}, 'before': before,
    };

Map<String, dynamic> _payload({bool spend = true, bool viewer = true, Map<String, dynamic>? over}) => {
      'range': {'from': '2026-11-09', 'to': '2026-11-15', 'brand': 'all'},
      'previous': {'from': '2026-11-02', 'to': '2026-11-08'},
      'today': '2026-11-13',
      'headline': {
        'leads': {'now': 109250, 'before': 97500, 'change': 12},
        'bookings': {'now': 102, 'before': 88, 'change': 15.9},
        'revenue': {'now': 3476000, 'before': 2950000, 'change': 17.8},
        'adSpend': spend ? {'now': 145000, 'before': 133000, 'change': 9} : null,
        'conversionRate': {'now': 33, 'before': 30, 'change': 3, 'unit': 'pp'},
      },
      'sparks': {'leads': [1, 2, 3, 4, 5, 6, 7], 'bookings': [0, 1, 0, 2, 1, 0, 1], 'revenue': [0, 100, 0, 200, 100, 0, 50], 'adSpend': spend ? [1, 1, 2, 2, 3, 3, 4] : null, 'conversionRate': [0, 10, 0, 20, 10, 0, 5]},
      'trend': [
        _day('2026-11-09', 1, 2, 0, 0, before: {'day': '2026-11-02', 'leads': 1, 'bookings': 0, 'revenue': 0}),
        _day('2026-11-10', 2, 5, 1, 8000, before: {'day': '2026-11-03', 'leads': 3, 'bookings': 1, 'revenue': 6000}),
        _day('2026-11-11', 3, 4, 0, 0, before: {'day': '2026-11-04', 'leads': 2, 'bookings': 0, 'revenue': 0}),
        _day('2026-11-12', 4, 6, 2, 20000, before: {'day': '2026-11-05', 'leads': 4, 'bookings': 0, 'revenue': 0}),
        _day('2026-11-13', 5, 3, 0, 0, before: {'day': '2026-11-06', 'leads': 2, 'bookings': 0, 'revenue': 0}),
        _day('2026-11-14', 6, 0, 0, 0, before: {'day': '2026-11-07', 'leads': 0, 'bookings': 0, 'revenue': 0}),
        _day('2026-11-15', 0, 0, 0, 0, before: {'day': '2026-11-08', 'leads': 0, 'bookings': 0, 'revenue': 0}),
      ],
      'quality': {'total': 109250, 'rows': [{'key': 'Hot', 'label': 'Hot', 'count': 26800, 'pct': 24.5}, {'key': 'Warm', 'label': 'Warm', 'count': 38100, 'pct': 34.9}, {'key': 'Cold', 'label': 'Cold', 'count': 44350, 'pct': 40.6}]},
      'sources': {'total': 109250, 'rows': [{'key': 'ig_main', 'label': 'Instagram (Main)', 'count': 49000, 'pct': 44.9}, {'key': 'whatsapp', 'label': 'WhatsApp', 'count': 35000, 'pct': 32}, {'key': 'youtube', 'label': 'YouTube', 'count': 25250, 'pct': 23.1}]},
      'members': {
        'viewer': viewer,
        'rows': [
          {'memberId': 'm1', 'name': 'Preethi', 'role': 'Brand Manager', 'metric': 'Reels posted', 'value': 27, 'unit': 'count', 'change': 35},
          {'memberId': 'm2', 'name': '=HYPERLINK("x")', 'role': 'Editor', 'metric': null, 'value': 3, 'unit': 'hours', 'change': null},
        ],
        'silent': 2,
      },
      'campaigns': {
        'rows': [
          {'id': 'c1', 'title': 'Bridal Campaign', 'brand': 'main', 'status': 'active', 'spend': 5000, 'leads': 340, 'bookings': 45, 'revenue': 1475000, 'cpl': 14.7, 'roas': 295},
          {'id': 'c2', 'title': 'Festive Offers', 'brand': 'kerala', 'status': 'active', 'spend': 2000, 'leads': 210, 'bookings': 30, 'revenue': 1120000, 'cpl': 9.5, 'roas': 560},
        ],
        'total': 8,
      },
      'ads': [{'id': 'ad1', 'name': 'Bridal reel ad', 'campaign': 'Bridal Campaign', 'format': 'video', 'impressions': 60000, 'clicks': 1200, 'spend': 5000, 'results': 60, 'ctr': 2, 'verdict': 'top'}],
      'recent': [
        {'at': '2026-11-12T10:00:00.000Z', 'kind': 'lead', 'text': 'New lead from Instagram (Main)'},
        {'at': '2026-11-12T09:00:00.000Z', 'kind': 'booking', 'text': 'Booking confirmed — ₹75,000'},
        {'at': '2026-11-11T09:00:00.000Z', 'kind': 'campaign', 'text': 'New campaign “Festive Offers”'},
      ],
      'production': {'planned': 30, 'done': 23, 'categories': [{'category': 'Influencer', 'planned': 10, 'done': 8}, {'category': 'Model', 'planned': 15, 'done': 12}, {'category': 'Event', 'planned': 5, 'done': 3}]},
      'revenueCollection': {'bookings': 102, 'orderValue': 3476000, 'advance': 358000, 'collectedLater': 120000, 'balanceDue': 3118000, 'averageOrder': 34078, 'advanceProgress': 10.3},
      'insights': ['Leads increased 12% compared with the period before.', 'Instagram (Main) contributed 45% of the leads.', 'Conversion rate improved to 33% (+3 pp).'],
      'status': {'adSpendRecorded': spend, 'adSpendNote': spend ? null : 'No ad spend has been recorded for this period — import a Meta Ads export in Campaigns.', 'leadsCapped': false},
      ...?over,
    };

class _FakeWeekly extends MarketingWeeklyService {
  _FakeWeekly([Map<String, dynamic>? payload]) : payload = payload ?? _payload(), super(Dio());
  Map<String, dynamic> payload;
  bool fails = false;
  final filters = <TeamFilter>[];

  @override
  Future<WeeklyReport> report(TeamFilter f) async {
    filters.add(f);
    if (fails) throw AppException(DioException(requestOptions: RequestOptions(path: '/marketing/weekly'), type: DioExceptionType.connectionError), action: 'load the weekly report'); // what the real service throws
    return WeeklyReport.fromJson(payload);
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

typedef _Saved = ({String name, List<List<Object?>> rows});

Future<({_FakeWeekly w, List<_Saved> saved})> _pump(WidgetTester tester, {_FakeWeekly? fake, Size size = const Size(1280, 3000), Future<void> Function(String, List<List<Object?>>)? saver}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final w = fake ?? _FakeWeekly();
  final saved = <_Saved>[];
  final overrides = <Override>[
    marketingWeeklyServiceProvider.overrideWithValue(w),
    marketingTeamServiceProvider.overrideWithValue(_NoTeam()),
    weeklyCsvSaverProvider.overrideWithValue(saver ?? (name, rows) async => saved.add((name: name, rows: rows))),
  ];
  await tester.pumpWidget(ProviderScope(overrides: overrides, child: MaterialApp(theme: AppTheme.lightTheme, home: const Scaffold(body: WeeklyReportScreen()))));
  await tester.pumpAndSettle();
  return (w: w, saved: saved);
}

Finder _k(String key) => find.byKey(Key(key));
String _kpiText(WidgetTester t, String key) => t.widgetList<Text>(find.descendant(of: _k(key), matching: find.byType(Text))).map((e) => e.data ?? '').join(' | ');

void main() {
  group('how the payload reads', () {
    test('every part parses', () {
      final r = WeeklyReport.fromJson(_payload());
      expect(r.from, '2026-11-09');
      expect(r.previousTo, '2026-11-08');
      expect(r.headline.leads.now, 109250);
      expect(r.headline.leads.change, 12);
      expect(r.headline.adSpend!.now, 145000);
      expect(r.headline.conversionKnown, isTrue);
      expect(r.sparks['leads']!.length, 7);
      expect(r.trend.length, 7);
      expect(r.trend[1].now.of('revenue'), 8000);
      expect(r.trend[1].before!.of('bookings'), 1);
      expect(r.trend[1].now.of('anything else'), 5); // leads is the default metric
      expect(r.quality.rows.first.pct, 24.5);
      expect(r.members.rows.last.isHours, isTrue);
      expect(r.members.rows.last.metric, isNull);
      expect(r.members.silent, 2);
      expect(r.campaigns.length, 2);
      expect(r.campaignTotal, 8);
      expect(r.ads.single.ctr, 2);
      expect(r.recent.first.kind, 'lead');
      expect(r.production.categories.length, 3);
      expect(r.revenue.advanceProgress, 10.3);
      expect(r.insights.length, 3);
    });

    test('an empty payload is an empty report, not a crash; no spend is null rather than 0; an unknown rate is not 0%', () {
      final r = WeeklyReport.fromJson(const {});
      expect(r.brand, 'all');
      expect(r.trend, isEmpty);
      expect(r.headline.adSpend, isNull);
      expect(r.headline.conversionKnown, isFalse);
      expect(r.members.rows, isEmpty);
      expect(r.production.planned, 0);
      expect(r.revenue.averageOrder, isNull);
      expect(r.sparks, isEmpty);
      final noSpend = WeeklyReport.fromJson(_payload(spend: false));
      expect(noSpend.headline.adSpend, isNull);
      expect(noSpend.sparks['adSpend'], isNull);
      expect(noSpend.status.adSpendNote, contains('No ad spend'));
      final noRate = WeeklyReport.fromJson({'headline': {'conversionRate': {'now': null, 'before': null, 'change': null}}});
      expect(noRate.headline.conversionKnown, isFalse);
    });

    test('a seven-day range reads "last week"; any other length "previous period"', () {
      expect(WeeklyReport.fromJson(_payload()).against, 'vs last week');
      final month = WeeklyReport.fromJson({'range': {'from': '2026-11-01', 'to': '2026-11-30'}});
      expect(month.isWeek, isFalse);
      expect(month.against, 'vs previous period');
      expect(WeeklyReport.fromJson(const {}).isWeek, isFalse);
    });

    test('the little texts: member result, change arrow, event time', () {
      expect(memberResult(const WeeklyMemberRow(metric: 'Reels posted', value: 27)), '27 Reels posted');
      expect(memberResult(const WeeklyMemberRow(unit: 'hours', value: 3.5)), '3.5 h logged');
      expect(changeArrow(35), '↑ 35%');
      expect(changeArrow(-8.5), '↓ 8.5%');
      expect(changeArrow(0), '→ 0%');
      expect(changeArrow(null), '');
      final now = DateTime(2026, 11, 13, 12);
      expect(eventTime(null, now: now), '');
      expect(eventTime(now.subtract(const Duration(seconds: 20)), now: now), 'just now');
      expect(eventTime(now.subtract(const Duration(minutes: 12)), now: now), '12 min ago');
      expect(eventTime(now.subtract(const Duration(hours: 3)), now: now), '3 h ago');
      expect(eventTime(now.subtract(const Duration(days: 2)), now: now), contains('11 Nov'));
    });

    test('the CSV carries the range, every card, and writes a formula-looking name as text', () {
      final rows = weeklyCsvRows(WeeklyReport.fromJson(_payload()));
      expect(rows.first, ['Marketing Weekly Report']);
      expect(rows[1], ['From', '2026-11-09', 'To', '2026-11-15', 'Brand', 'All brands']);
      final flat = rows.map((r) => r.join('|')).toList();
      expect(flat, contains('Total leads|109250|97500|12%'));
      expect(flat.any((l) => l.startsWith('Ad spend (₹)|145000')), isTrue);
      expect(flat.any((l) => l.startsWith('Conversion rate (%)|33|30|3 pp')), isTrue);
      expect(flat.where((l) => l.startsWith('2026-11-1')).length, greaterThanOrEqualTo(6)); // day by day
      expect(flat.any((l) => l.startsWith('Hot|26800|24.5')), isTrue);
      expect(flat.any((l) => l.startsWith("'=HYPERLINK")), isTrue);
      expect(flat.any((l) => l.contains('2 member(s) logged nothing')), isTrue);
      expect(flat.any((l) => l.startsWith('All shoots|30|23')), isTrue);
      expect(flat.any((l) => l.startsWith('Balance due|3118000')), isTrue);
      expect(flat.last, 'Conversion rate improved to 33% (+3 pp).');
      expect(weeklyCsvFileName(WeeklyReport.fromJson(_payload())), 'marketing-weekly-report-2026-11-09-to-2026-11-15.csv');
      expect(weeklyCsvFileName(WeeklyReport.fromJson({'range': {'from': '2026-11-01', 'to': '2026-11-02', 'brand': 'kerala'}})), 'marketing-weekly-report-2026-11-01-to-2026-11-02-kerala.csv');
    });

    test('with no ad spend the CSV says "Not recorded" instead of 0', () {
      final rows = weeklyCsvRows(WeeklyReport.fromJson(_payload(spend: false)));
      expect(rows.firstWhere((r) => r.isNotEmpty && r.first == 'Ad spend (₹)')[1], 'Not recorded');
    });
  });

  group('the page', () {
    testWidgets('the header, the filters and the Export button', (tester) async {
      await _pump(tester);
      expect(find.text('Marketing Weekly Report'), findsOneWidget);
      expect(find.text('Track your marketing performance and activities at a glance'), findsOneWidget);
      expect(_k('wk_export'), findsOneWidget);
      expect(find.text('Export'), findsOneWidget);
    });

    testWidgets('the five KPI cards carry the figure and its change on last week', (tester) async {
      await _pump(tester);
      expect(_kpiText(tester, 'wk_kpi_leads'), allOf(contains('1,09,250'), contains('Total Leads'), contains('↑ +12% vs last week')));
      expect(_kpiText(tester, 'wk_kpi_bookings'), allOf(contains('102'), contains('Bookings'), contains('↑ +15.9% vs last week')));
      expect(_kpiText(tester, 'wk_kpi_revenue'), allOf(contains('₹34.76L'), contains('Revenue'), contains('↑ +17.8%')));
      expect(_kpiText(tester, 'wk_kpi_adspend'), allOf(contains('₹1.45L'), contains('Ad Spend'), contains('↑ +9%')));
      expect(_kpiText(tester, 'wk_kpi_rate'), allOf(contains('33%'), contains('Conversion Rate'), contains('↑ +3 pp')));
    });

    testWidgets('a rising change is green; rising ad spend is neutral grey (more spend is neither good nor bad on its own)', (tester) async {
      await _pump(tester);
      expect(tester.widget<MktKpiCard>(_k('wk_kpi_leads')).good, isTrue);
      expect(tester.widget<MktKpiCard>(_k('wk_kpi_adspend')).good, isNull);
      final p = _payload();
      p['headline'] = {...(p['headline'] as Map), 'leads': <String, dynamic>{'now': 5, 'before': 10, 'change': -50}};
      await _pump(tester, fake: _FakeWeekly(p));
      expect(tester.widget<MktKpiCard>(_k('wk_kpi_leads')).good, isFalse);
      expect(_kpiText(tester, 'wk_kpi_leads'), contains('↓ −50% vs last week'));
    });

    testWidgets('no ad spend recorded: the card says "Not recorded", shows no number, and the page says how to fix it', (tester) async {
      await _pump(tester, fake: _FakeWeekly(_payload(spend: false)));
      final t = _kpiText(tester, 'wk_kpi_adspend');
      expect(t, allOf(contains('—'), contains('Not recorded')));
      expect(t, isNot(contains('₹')));
      expect(find.textContaining('No ad spend has been recorded'), findsOneWidget);
    });

    testWidgets('a range that is not a week reads "vs previous period"', (tester) async {
      await _pump(tester, fake: _FakeWeekly(_payload(over: {'range': {'from': '2026-11-01', 'to': '2026-11-30', 'brand': 'all'}})));
      expect(_kpiText(tester, 'wk_kpi_leads'), contains('vs previous period'));
      expect(find.text('This period'), findsOneWidget);
      expect(find.text('Previous period'), findsOneWidget);
    });

    testWidgets('an unknown conversion rate shows a dash, not 0%', (tester) async {
      final p = _payload();
      p['headline'] = {...(p['headline'] as Map), 'conversionRate': <String, dynamic>{'now': null, 'before': null, 'change': null}};
      await _pump(tester, fake: _FakeWeekly(p));
      final t = _kpiText(tester, 'wk_kpi_rate');
      expect(t, contains('—'));
      expect(t, isNot(contains('0%')));
    });

    testWidgets('the performance chart: This Week against Last Week, with Leads / Bookings / Revenue tabs', (tester) async {
      await _pump(tester);
      expect(find.text('Weekly Performance Overview'), findsOneWidget);
      expect(find.text('This week'), findsOneWidget);
      expect(find.text('Last week'), findsOneWidget);
      expect(_k('wk_chart_leads'), findsOneWidget);
      await tester.tap(_k('wk_chart_tab_bookings'));
      await tester.pumpAndSettle();
      expect(_k('wk_chart_bookings'), findsOneWidget);
      expect(_k('wk_chart_leads'), findsNothing);
      await tester.tap(_k('wk_chart_tab_revenue'));
      await tester.pumpAndSettle();
      expect(_k('wk_chart_revenue'), findsOneWidget);
    });

    testWidgets('a quiet range shows an empty chart message, not a flat line', (tester) async {
      await _pump(tester, fake: _FakeWeekly(_payload(over: {'trend': []})));
      expect(find.text('Nothing recorded in this range.'), findsOneWidget);
    });

    testWidgets('lead quality and sources: totals in the middle, a legend with counts and shares', (tester) async {
      await _pump(tester);
      expect(find.text('Lead Quality Distribution'), findsOneWidget);
      expect(find.text('Hot'), findsOneWidget);
      expect(find.textContaining('26,800'), findsOneWidget);
      expect(find.textContaining('24.5%'), findsOneWidget);
      expect(find.text('Lead Sources'), findsOneWidget);
      expect(find.text('Instagram (Main)'), findsWidgets);
      expect(find.text('44.9%'), findsOneWidget);
      expect(find.text('1,09,250'), findsNWidgets(3)); // the KPI card and the two donut centres
    });

    testWidgets('lead quality: whatever buckets the server sends are drawn — Nurture too, and one the app has never heard of', (tester) async {
      final four = {'total': 100, 'rows': [
        {'key': 'Hot', 'label': 'Hot', 'count': 20, 'pct': 20.0},
        {'key': 'Warm', 'label': 'Warm', 'count': 30, 'pct': 30.0},
        {'key': 'Nurture', 'label': 'Nurture', 'count': 15, 'pct': 15.0},
        {'key': 'Cold', 'label': 'Cold', 'count': 25, 'pct': 25.0},
        {'key': 'Not rated', 'label': 'Not rated', 'count': 10, 'pct': 10.0},
      ]};
      await _pump(tester, fake: _FakeWeekly(_payload(over: {'quality': four})));
      for (final b in ['Hot', 'Warm', 'Nurture', 'Cold', 'Not rated']) {
        expect(find.text(b), findsOneWidget, reason: b);
      }
      final donut = tester.widget<MktDonut>(find.ancestor(of: find.byKey(const Key('wk_quality_total')), matching: find.byType(MktDonut)));
      expect(donut.slices.length, 5);
      expect(donut.colors, [Mkt.bad, Mkt.warn, Mkt.teal, Mkt.blue, Mkt.grey]);
    });

    test('a quality bucket the app does not know still gets a colour of its own', () {
      expect(qualityColor('Nurture'), Mkt.teal);
      expect(qualityColor('hot'), Mkt.bad);
      expect(qualityColor('Lukewarm', 5), isNot(qualityColor('Lukewarm', 6)), reason: 'by its place, so two new buckets differ');
    });

    testWidgets('no leads: both donuts say so', (tester) async {
      await _pump(tester, fake: _FakeWeekly(_payload(over: {'quality': {'total': 0, 'rows': []}, 'sources': {'total': 0, 'rows': []}})));
      expect(find.text('No leads in this range.'), findsNWidgets(2));
    });

    testWidgets('individual insights: each member\'s key result and change; hours for a member with no counts; the silent count', (tester) async {
      await _pump(tester);
      expect(find.text('Individual Insights'), findsOneWidget);
      expect(find.text('Each member’s key result from their logs'), findsOneWidget);
      expect(_k('wk_member_m1'), findsOneWidget);
      expect(find.text('Preethi'), findsOneWidget);
      expect(find.text('Brand Manager'), findsOneWidget);
      expect(find.textContaining('27 Reels posted'), findsOneWidget);
      expect(find.textContaining('↑ 35%'), findsOneWidget);
      expect(find.textContaining('3 h logged'), findsOneWidget);
      expect(find.text('2 members logged nothing in this range.'), findsOneWidget);
    });

    testWidgets('a member who is not a manager sees their own result and no team notes', (tester) async {
      await _pump(tester, fake: _FakeWeekly(_payload(viewer: false)));
      expect(find.text('Your key result from your logs'), findsOneWidget);
      expect(find.textContaining('logged nothing'), findsNothing);
    });

    testWidgets('a member who logged nothing is told so, not that "nobody" did', (tester) async {
      await _pump(tester, fake: _FakeWeekly(_payload(over: {'members': {'viewer': false, 'rows': [], 'silent': 1}})));
      expect(find.text('You have not logged any work in this range.'), findsOneWidget);
      expect(find.textContaining('Nobody'), findsNothing);
    });

    testWidgets('campaigns: no "showing x of y" note when every campaign is already listed', (tester) async {
      final p = _payload();
      p['campaigns'] = {'rows': (p['campaigns'] as Map)['rows'], 'total': 2};
      await _pump(tester, fake: _FakeWeekly(p));
      expect(find.textContaining('Showing'), findsNothing);
    });

    testWidgets('nobody logged: the card says so', (tester) async {
      await _pump(tester, fake: _FakeWeekly(_payload(over: {'members': {'viewer': true, 'rows': [], 'silent': 4}})));
      expect(find.text('Nobody logged work in this range.'), findsOneWidget);
    });

    testWidgets('campaign performance: leads, bookings and revenue per campaign; a note when only some are shown; the Ads tab', (tester) async {
      await _pump(tester);
      expect(find.text('Campaign & Paid Performance'), findsOneWidget);
      expect(_k('wk_campaign_c1'), findsOneWidget);
      expect(find.text('Bridal Campaign'), findsOneWidget);
      expect(find.text('340'), findsOneWidget);
      expect(find.text('₹14.75L'), findsOneWidget);
      expect(find.textContaining('Showing 2 of 8 campaigns'), findsOneWidget);
      await tester.tap(_k('wk_camp_tab_ads'));
      await tester.pumpAndSettle();
      expect(_k('wk_ad_ad1'), findsOneWidget);
      expect(find.text('Bridal reel ad'), findsOneWidget);
      expect(find.text('2%'), findsOneWidget);
      expect(find.text('Bridal Campaign'), findsNothing);
    });

    testWidgets('no campaigns and no ads: honest empty messages', (tester) async {
      await _pump(tester, fake: _FakeWeekly(_payload(over: {'campaigns': {'rows': [], 'total': 0}, 'ads': []})));
      expect(find.text('No campaign had spend or leads in this range.'), findsOneWidget);
      await tester.tap(_k('wk_camp_tab_ads'));
      await tester.pumpAndSettle();
      expect(find.text('No ads recorded yet — add them in Campaigns.'), findsOneWidget);
    });

    testWidgets('recent activities: the newest first, one row each', (tester) async {
      await _pump(tester);
      expect(find.text('Recent Activities'), findsOneWidget);
      expect(_k('wk_recent_0'), findsOneWidget);
      expect(_k('wk_recent_2'), findsOneWidget);
      expect(find.text('New lead from Instagram (Main)'), findsOneWidget);
      expect(find.text('Booking confirmed — ₹75,000'), findsOneWidget);
    });

    testWidgets('production: a ring per category with done/planned, and the overall line', (tester) async {
      await _pump(tester);
      expect(find.text('Production Activities of the Week'), findsOneWidget);
      expect(find.text('23 of 30 planned shoots done'), findsOneWidget);
      expect(find.text('8/10'), findsOneWidget);
      expect(find.text('12/15'), findsOneWidget);
      expect(find.text('3/5'), findsOneWidget);
      expect(find.text('Influencer Shoots Done'), findsOneWidget);
      expect(_k('wk_ring_2'), findsOneWidget);
    });

    testWidgets('no shoots planned: the card says so', (tester) async {
      await _pump(tester, fake: _FakeWeekly(_payload(over: {'production': {'planned': 0, 'done': 0, 'categories': []}})));
      expect(find.text('No shoots were planned in this range.'), findsOneWidget);
      expect(_k('wk_ring_0'), findsNothing);
    });

    testWidgets('revenue and collection: the four tiles, the advance progress and the later collections', (tester) async {
      await _pump(tester);
      expect(find.text('Revenue & Collection'), findsOneWidget);
      expect(find.text('102 bookings counted'), findsOneWidget);
      String tile(String key) => _kpiText(tester, key);
      expect(tile('wk_rev_order'), allOf(contains('Total Order Value'), contains('₹34.76L')));
      expect(tile('wk_rev_advance'), allOf(contains('Advance Collected'), contains('₹3.58L')));
      expect(tile('wk_rev_balance'), allOf(contains('Balance Due'), contains('₹31.18L')));
      expect(tile('wk_rev_average'), allOf(contains('Avg Order Value'), contains('₹34,078')));
      expect(find.text('Advance Collection Progress'), findsOneWidget);
      expect(find.descendant(of: _k('wk_rev_progress'), matching: find.text('10%')), findsOneWidget);
      expect(find.textContaining('₹1.20L collected after the advance.'), findsOneWidget);
    });

    testWidgets('nothing collected after the advance: no "collected after" note, and an unknown average shows a dash', (tester) async {
      await _pump(tester, fake: _FakeWeekly(_payload(over: {'revenueCollection': {'bookings': 3, 'orderValue': 30000, 'advance': 9000, 'collectedLater': 0, 'balanceDue': 21000, 'averageOrder': null, 'advanceProgress': 30}})));
      expect(find.textContaining('collected after the advance'), findsNothing);
      expect(_kpiText(tester, 'wk_rev_average'), contains('—'));
      expect(find.text('3 bookings counted'), findsOneWidget);
      expect(find.descendant(of: _k('wk_rev_progress'), matching: find.text('30%')), findsOneWidget);
    });

    testWidgets('one booking reads "1 booking counted"', (tester) async {
      await _pump(tester, fake: _FakeWeekly(_payload(over: {'revenueCollection': {'bookings': 1, 'orderValue': 5000, 'advance': 1000, 'collectedLater': 0, 'balanceDue': 4000, 'averageOrder': 5000, 'advanceProgress': 20}})));
      expect(find.text('1 booking counted'), findsOneWidget);
    });

    testWidgets('one silent member reads in the singular', (tester) async {
      await _pump(tester, fake: _FakeWeekly(_payload(over: {'members': {'viewer': true, 'silent': 1, 'rows': [{'memberId': 'm1', 'name': 'Preethi', 'role': '', 'metric': 'Reels posted', 'value': 4, 'unit': 'count', 'change': null}]}})));
      expect(find.text('1 member logged nothing in this range.'), findsOneWidget);
      expect(find.text('—'), findsWidgets); // an empty role is a dash
      expect(find.descendant(of: _k('wk_member_m1'), matching: find.textContaining('↑')), findsNothing); // no change known → no arrow on that row
    });

    testWidgets('no bookings: the revenue card says so and shows no zero tiles', (tester) async {
      await _pump(tester, fake: _FakeWeekly(_payload(over: {'revenueCollection': {'bookings': 0, 'orderValue': 0, 'advance': 0, 'collectedLater': 0, 'balanceDue': 0, 'averageOrder': null, 'advanceProgress': null}})));
      expect(find.text('No bookings were counted in this range.'), findsOneWidget);
      expect(_k('wk_rev_order'), findsNothing);
    });

    testWidgets('key insights list, and an empty list explains itself', (tester) async {
      await _pump(tester);
      expect(find.text('Key Insights'), findsOneWidget);
      expect(find.text('Leads increased 12% compared with the period before.'), findsOneWidget);
      expect(_k('wk_insight_2'), findsOneWidget);
    });

    testWidgets('no insights: an explanation instead of a blank card', (tester) async {
      await _pump(tester, fake: _FakeWeekly(_payload(over: {'insights': []})));
      expect(find.text('Insights appear once there are leads to compare.'), findsOneWidget);
    });

    testWidgets('the leads cap warning shows when the server stopped at its cap', (tester) async {
      await _pump(tester, fake: _FakeWeekly(_payload(over: {'status': {'adSpendRecorded': true, 'leadsCapped': true}})));
      expect(find.textContaining('more leads in this range than the report can load'), findsOneWidget);
    });
  });

  group('filters, export, failing', () {
    testWidgets('the page asks for the shared range and brand, and asks again when the brand changes', (tester) async {
      final (:w, :saved) = await _pump(tester);
      expect(saved, isEmpty);
      expect(w.filters.length, 1);
      expect(w.filters.first.brand, TeamBrand.all);
      final c = ProviderScope.containerOf(tester.element(find.byType(WeeklyReportScreen)));
      c.read(teamFilterProvider.notifier).state = w.filters.first.copyWith(brand: TeamBrand.kerala);
      await tester.pumpAndSettle();
      expect(w.filters.last.brand, TeamBrand.kerala);
    });

    testWidgets('Export downloads the whole page as a CSV named for the range', (tester) async {
      final (:w, :saved) = await _pump(tester);
      await tester.tap(_k('wk_export'));
      await tester.pumpAndSettle();
      expect(saved.length, 1);
      expect(saved.single.name, 'marketing-weekly-report-2026-11-09-to-2026-11-15.csv');
      expect(saved.single.rows.first, ['Marketing Weekly Report']);
      expect(saved.single.rows.length, greaterThan(30));
      expect(w.filters.length, 1); // exporting does not re-read the page
    });

    testWidgets('a failing download says so in plain words (no raw error) and the button comes back', (tester) async {
      await _pump(tester, saver: (_, _) async => throw Exception('disk is on fire'));
      await tester.tap(_k('wk_export'));
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.textContaining('Exception'), findsNothing);
      expect(find.text('Export'), findsOneWidget);
    });

    testWidgets('Export waits until the report has loaded', (tester) async {
      final w = _FakeWeekly()..fails = true;
      await _pump(tester, fake: w);
      final button = tester.widget<FilledButton>(find.descendant(of: _k('wk_export'), matching: find.byType(FilledButton)));
      expect(button.onPressed, isNull);
    });

    testWidgets('a failing source says so with Try again, and trying again loads the page', (tester) async {
      final w = _FakeWeekly()..fails = true;
      await _pump(tester, fake: w);
      expect(find.text('Try again'), findsOneWidget);
      expect(find.textContaining('DioException'), findsNothing);
      expect(find.textContaining('connectionError'), findsNothing);
      w.fails = false;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('Individual Insights'), findsOneWidget);
    });

    testWidgets('an empty report still draws every card with its own message', (tester) async {
      await _pump(tester, fake: _FakeWeekly(const {}));
      expect(tester.takeException(), isNull);
      for (final t in ['Weekly Performance Overview', 'Lead Quality Distribution', 'Lead Sources', 'Individual Insights', 'Campaign & Paid Performance', 'Recent Activities', 'Revenue & Collection', 'Key Insights']) {
        expect(find.text(t), findsOneWidget, reason: t);
      }
    });
  });

  group('the service', () {
    test('asks /marketing/weekly with the range and brand, and reads the answer', () async {
      final seen = <RequestOptions>[];
      final dio = Dio(BaseOptions(baseUrl: 'http://x.test/api'))..httpClientAdapter = _Capture(seen, body: '{"range":{"from":"2026-11-09","to":"2026-11-15","brand":"kerala"},"headline":{"leads":{"now":4,"before":2,"change":100}}}');
      final r = await MarketingWeeklyService(dio).report(TeamFilter(from: DateTime(2026, 11, 9), to: DateTime(2026, 11, 15), brand: TeamBrand.kerala));
      expect(seen.single.method, 'GET');
      expect(seen.single.path, '/marketing/weekly');
      expect(seen.single.queryParameters, {'from': '2026-11-09', 'to': '2026-11-15', 'brand': 'kerala'});
      expect(r.headline.leads.now, 4);
      expect(r.brand, 'kerala');
    });

    test('a refusal becomes a plain-words error, not a DioException', () async {
      final dio = Dio(BaseOptions(baseUrl: 'http://x.test/api'))..httpClientAdapter = _Capture([], status: 403, body: '{"message":"Only the Marketing team can open this."}');
      await expectLater(MarketingWeeklyService(dio).report(TeamFilter.thisWeek()), throwsA(isNot(isA<DioException>())));
    });
  });

  group('phone', () {
    testWidgets('the whole page fits a 390-wide screen without overflow, with data, with nothing, and with no ad spend', (tester) async {
      await _pump(tester, size: const Size(390, 4200));
      expect(tester.takeException(), isNull);
      await tester.tap(_k('wk_camp_tab_ads'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(_k('wk_chart_tab_revenue'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('an empty report fits 390', (tester) async {
      await _pump(tester, fake: _FakeWeekly(const {}), size: const Size(390, 3000));
      expect(tester.takeException(), isNull);
    });

    testWidgets('no ad spend fits 390', (tester) async {
      await _pump(tester, fake: _FakeWeekly(_payload(spend: false, viewer: false)), size: const Size(390, 4200));
      expect(tester.takeException(), isNull);
    });
  });
}
