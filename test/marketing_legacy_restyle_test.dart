// The legacy Marketing screens (Overview, Competitors, Weekly Score, Insights, Analytics, Re-engagement, Sales
// Calendar, Content Dashboard, Content Calendar) after their restyle to the Marketing design system: each one
// is pumped with fake data (long names, big numbers) at phone (390px) and laptop (1280px) widths and must lay
// out without a RenderFlex overflow, show the new header and keep its main controls. (The EOD screen is covered
// by marketing_eod_layout_test.dart, the signal-evidence sheet by growth_scores_sheet_test.dart.)
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:nizan_crm/core/models/auth_session.dart';
import 'package:nizan_crm/core/models/service_region.dart';
import 'package:nizan_crm/core/providers/auth_provider.dart';
import 'package:nizan_crm/core/theme/app_theme.dart';
import 'package:nizan_crm/features/marketing/data/campaign.dart';
import 'package:nizan_crm/features/marketing/data/content_item.dart';
import 'package:nizan_crm/features/marketing/data/marketing_models.dart';
import 'package:nizan_crm/features/marketing/presentation/screens/competitors_screen.dart';
import 'package:nizan_crm/features/marketing/presentation/screens/content_calendar_screen.dart';
import 'package:nizan_crm/features/marketing/presentation/screens/content_dashboard_screen.dart';
import 'package:nizan_crm/features/marketing/presentation/screens/growth_scores_screen.dart';
import 'package:nizan_crm/features/marketing/presentation/screens/marketing_analytics_screen.dart';
import 'package:nizan_crm/features/marketing/presentation/screens/marketing_calendar_screen.dart';
import 'package:nizan_crm/features/marketing/presentation/screens/marketing_dashboard_screen.dart';
import 'package:nizan_crm/features/marketing/presentation/screens/marketing_insights_screen.dart';
import 'package:nizan_crm/features/marketing/presentation/screens/marketing_reengagement_screen.dart';
import 'package:nizan_crm/features/marketing/services/campaign_service.dart';
import 'package:nizan_crm/features/marketing/services/content_service.dart';
import 'package:nizan_crm/features/marketing/services/marketing_insights_service.dart';
import 'package:nizan_crm/features/marketing/services/marketing_service.dart';
import 'package:nizan_crm/features/sales/controllers/lead_controller.dart';
import 'package:nizan_crm/features/sales/data/lead.dart';
import 'package:nizan_crm/features/slots/data/slot_models.dart';
import 'package:nizan_crm/features/slots/services/slot_service.dart';
import 'package:nizan_crm/services/region_service.dart';

const _desktop = Size(1280, 1400);
const _phone = Size(390, 1400);

const _longName = 'Glamour Studio Kochi — Bridal & Party Makeup Academy Pvt Ltd';

// ── fixtures ────────────────────────────────────────────────────────────────

CompetitorSnapshot _snap(int score) => CompetitorSnapshot(
      weekOf: DateTime.now().subtract(Duration(days: (DateTime.now().weekday + 6) % 7)),
      followers: 1234567,
      weeklyGrowthPct: 12.5,
      engagementRate: 4.2,
      adCampaigns: 12,
      score: score,
    );

List<Competitor> _competitors() => [
      Competitor(id: 'c1', name: _longName, city: 'Kochi', region: 'Ernakulam', category: 'Bridal', instagram: 'a', youtube: 'b', latestSnapshot: _snap(22)),
      const Competitor(id: 'c2', name: 'Glow Studio', city: 'Calicut'),
    ];

RankingBoard _board() => RankingBoard(
      weekOf: DateTime(2026, 11, 9),
      rankings: [
        CompetitorRanking(
          rank: 1,
          competitorId: 'c1',
          name: _longName,
          city: 'Kochi',
          category: 'Bridal',
          score: 22,
          previousScore: 15,
          movement: 7,
          signals: const [ScoreSignal(key: 'viralContent', label: 'Viral Content', points: 5, evidence: 'x', link: '')],
        ),
        const CompetitorRanking(rank: 2, competitorId: 'c2', name: 'Glow Studio', score: 3, movement: -2),
        const CompetitorRanking(rank: 3, competitorId: 'c3', name: 'New Entrant', score: 12),
      ],
      reels: const [LeaderboardEntry(rank: 1, competitorId: 'c1', name: _longName, city: 'Kochi', metric: 12.5, score: 22)],
    );

MarketingInsights _insights() => const MarketingInsights(
      nps: NpsSummary(
        nps: 54,
        promoters: 70,
        passives: 20,
        detractors: 10,
        responses: 1234,
        trend: [NpsPoint(month: '2026-08', nps: 40), NpsPoint(month: '2026-09', nps: 48), NpsPoint(month: '2026-10', nps: 54)],
      ),
      avgBrideScore: 4.6,
      csatSubmitted: 321,
      artistUtilPct: 72,
      artistBusy: 18,
      artistTotal: 25,
      slot: SlotUtil(totalCapacity: 1200, totalBooked: 640, pct: 53),
      byRegion: [SegmentRow(name: 'Ernakulam & Kochi Metropolitan Region', bookings: 120, revenue: 1234567), SegmentRow(name: 'Kozhikode', bookings: 80, revenue: 900000)],
      byDistrict: [SegmentRow(name: 'Thrissur', bookings: 44, revenue: 100000)],
      byMonth: [SegmentRow(name: '2026-09', bookings: 40, revenue: 100000), SegmentRow(name: '2026-10', bookings: 90, revenue: 500000), SegmentRow(name: '2026-11', bookings: 60, revenue: 250000)],
      byCulture: [SegmentRow(name: 'Hindu', bookings: 90, revenue: 800000), SegmentRow(name: 'Christian', bookings: 60, revenue: 500000), SegmentRow(name: 'Not specified', bookings: 5)],
      totalBookings: 155,
      coverage: Coverage(
        eventTotal: 200,
        eventWithDate: 180,
        eventMissing: 20,
        cultureExplicit: 100,
        cultureInferred: 50,
        cultureUnknown: 50,
        locWithRegion: 190,
        locWithDistrict: 150,
        locWithPincode: 90,
        worklist: [CoverageItem(id: 'b1', customerName: 'Fathima Liya Muhammed Kutty Abdul Rahman', missing: ['eventDate', 'culture', 'location'])],
      ),
    );

CalendarComparison _calendar() {
  final y = DateTime.now().year;
  String key(int yy, int m, int d) => '$yy-${m.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}';
  final m = DateTime.now().month;
  return CalendarComparison(
    year: y,
    prevYear: y - 1,
    current: {key(y, m, 5): const DayStat(bookings: 18, revenue: 1234567), key(y, m, 9): const DayStat(bookings: 3, revenue: 50000)},
    previous: {key(y - 1, m, 5): const DayStat(bookings: 7, revenue: 400000)},
    curTotalBookings: 1234,
    prevTotalBookings: 900,
    curTotalRevenue: 12345678,
    prevTotalRevenue: 9000000,
    byMonth: [for (var i = 1; i <= 12; i++) MonthYoY(month: i, curBookings: i * 10, prevBookings: i * 8, curRevenue: i * 100000.0, prevRevenue: i * 80000.0)],
  );
}

MonthAvailability _month(int year, int month) => MonthAvailability(
      year: year,
      month: month,
      defaultMorning: 5,
      defaultEvening: 5,
      totalCapacity: 300,
      totalAvailable: 120,
      totalBooked: 180,
      days: [
        for (var d = 1; d <= 28; d++)
          DaySlot(
            date: DateTime(year, month, d),
            isOverride: false,
            blocked: false,
            morning: SlotHalf(capacity: 5, booked: d % 6, available: 5 - d % 6),
            evening: SlotHalf(capacity: 5, booked: d % 5, available: 5 - d % 5),
            total: SlotHalf(capacity: 10, booked: d % 6 + d % 5, available: 10 - d % 6 - d % 5),
          ),
      ],
    );

List<ContentItem> _content() {
  final now = DateTime.now();
  return [
    ContentItem(id: 'i1', title: 'Bridal transformation reel for the monsoon season campaign', scheduledDate: DateTime(now.year, now.month, 5), platform: 'instagram', status: 'scheduled'),
    ContentItem(id: 'i2', title: 'Story', scheduledDate: DateTime(now.year, now.month, 5), platform: 'youtube', status: 'published'),
    ContentItem(id: 'i3', title: 'Carousel', scheduledDate: DateTime(now.year, now.month, 5), platform: 'facebook'),
    ContentItem(id: 'i4', title: 'Blog', scheduledDate: DateTime(now.year, now.month, 5), platform: 'website'),
    ContentItem(id: 'i5', title: 'Reel', scheduledDate: DateTime(now.year, now.month, 12), platform: 'whatsapp', status: 'planned'),
  ];
}

// ── harness ─────────────────────────────────────────────────────────────────

Future<void> _pump(WidgetTester tester, Size size, Widget screen, List<Override> overrides, {bool settle = true}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authSessionProvider.overrideWith(
          (ref) => const AuthSession(token: 't', userId: 'u0', name: 'Admin', email: 'admin@example.com', role: 'admin'),
        ),
        ...overrides,
      ],
      child: MaterialApp(theme: AppTheme.lightTheme, home: Scaffold(body: screen)),
    ),
  );
  await _settle(tester, settle);
}

/// pumpAndSettle — except on a screen with a live map (it never goes idle), where a few frames will do.
Future<void> _settle(WidgetTester tester, bool settle) async {
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
  }
}

/// Drags the page to its end so lazily built rows below the fold are laid out too.
Future<void> _scrollThrough(WidgetTester tester, {bool settle = true}) async {
  final hits = find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down).hitTestable();
  if (hits.evaluate().isEmpty) return;
  for (var i = 0; i < 6; i++) {
    await tester.drag(hits.first, const Offset(0, -600), warnIfMissed: false);
    await _settle(tester, settle);
    expect(tester.takeException(), isNull, reason: 'scrolled');
  }
}

String _headerTitle(WidgetTester tester) {
  final t = tester.widget<Text>(find.byKey(const Key('mkt_title')));
  return t.textSpan?.toPlainText() ?? t.data ?? '';
}

void main() {
  for (final (label, size) in [('laptop 1280', _desktop), ('phone 390', _phone)]) {
    group(label, () {
      testWidgets('Overview: KPIs, explore cards and the competitor watch', (tester) async {
        Future<T> never<T>() => Completer<T>().future; // a KPI still loading shows "—"
        await _pump(tester, size, const MarketingDashboardScreen(), [
          leadsProvider.overrideWith((ref) async => <Lead>[]),
          bookingCalendarProvider.overrideWith((ref) async => _calendar()),
          campaignsProvider.overrideWith((ref) async => const CampaignBoard(blendedRoiPct: 240, totalAdSpend: 1234567)),
          marketingInsightsProvider.overrideWith((ref) async => _insights()),
          contentStatsProvider.overrideWith((ref) async => const ContentStats(total: 9, dueThisWeek: 4, overdue: 3)),
          reEngagementProvider.overrideWith((ref) => never<ReEngagementResult>()),
          competitorsProvider.overrideWith((ref) async => _competitors()),
          rankingsProvider(null).overrideWith((ref) async => _board()),
        ]);
        expect(tester.takeException(), isNull);
        expect(_headerTitle(tester), 'Overview');
        expect(find.text('Explore marketing'), findsOneWidget);
        expect(find.text('Competitor watch'), findsOneWidget);
        expect(find.text('3 overdue'), findsOneWidget); // the content KPI's note
        expect(find.text('3 content overdue'), findsOneWidget); // and the attention chip
        await _scrollThrough(tester);
      });

      testWidgets('Competitors: list, search and the header actions', (tester) async {
        await _pump(tester, size, const CompetitorsScreen(), [
          competitorsProvider.overrideWith((ref) async => _competitors()),
          regionsProvider.overrideWith((ref) async => const [ServiceRegion(id: 'r1', name: 'Ernakulam', status: 'active', stateId: 's', stateName: 'Kerala')]),
        ]);
        expect(tester.takeException(), isNull);
        expect(_headerTitle(tester), 'Competitors');
        expect(find.text(_longName), findsOneWidget);
        expect(find.text('Add competitor'), findsOneWidget);
        expect(find.text('Import CSV'), findsOneWidget);
        await _scrollThrough(tester);
        // the search filters the list, an empty result shows the empty state
        await tester.enterText(find.byType(TextField), 'zzz');
        await tester.pumpAndSettle();
        expect(find.text(_longName), findsNothing);
        expect(find.text('No competitors yet — add one or import a CSV'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('Weekly Score: the four pill tabs switch the board', (tester) async {
        await _pump(tester, size, const GrowthScoresScreen(), [
          rankingsProvider(null).overrideWith((ref) async => _board()),
          competitorsProvider.overrideWith((ref) async => _competitors()),
        ]);
        expect(tester.takeException(), isNull);
        expect(_headerTitle(tester), 'Weekly Score');
        expect(find.text('Overall ranking'), findsOneWidget);
        expect(find.text('Weights'), findsOneWidget);
        await tester.ensureVisible(find.text('Top Reels'));
        await tester.tap(find.text('Top Reels'));
        await tester.pumpAndSettle();
        expect(find.text('Top reels'), findsOneWidget);
        expect(find.text('Overall ranking'), findsNothing);
        await tester.ensureVisible(find.text('Top Websites'));
        await tester.tap(find.text('Top Websites')); // no websites in the fixture → the empty card
        await tester.pumpAndSettle();
        expect(find.text('Nothing to rank yet'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('Insights: KPIs, gauges and segments', (tester) async {
        await _pump(tester, size, const MarketingInsightsScreen(), [
          marketingInsightsProvider.overrideWith((ref) async => _insights()),
        ]);
        expect(tester.takeException(), isNull);
        expect(_headerTitle(tester), 'Marketing Insights');
        expect(find.text('Net Promoter Score'), findsOneWidget);
        expect(find.text('Client Re-engagement'), findsOneWidget);
        await _scrollThrough(tester);
      });

      testWidgets('Analytics: timeline toggle, culture donut and the data-quality panel', (tester) async {
        await _pump(tester, size, const MarketingAnalyticsScreen(), [
          marketingInsightsProvider.overrideWith((ref) async => _insights()),
        ], settle: false);
        expect(tester.takeException(), isNull);
        expect(_headerTitle(tester), 'Marketing Analytics');
        await tester.ensureVisible(find.text('Revenue'));
        await tester.tap(find.text('Revenue'));
        await _settle(tester, false);
        expect(tester.takeException(), isNull);
        await _scrollThrough(tester, settle: false);
        expect(find.textContaining('Needs attention'), findsOneWidget);
      });

      testWidgets('Re-engagement: window chips and the client list', (tester) async {
        await _pump(tester, size, const MarketingReEngagementScreen(), [
          reEngagementProvider.overrideWith(
            (ref) async => const ReEngagementResult(count: 2, clients: [
              ReEngagementClient(customerName: 'Fathima Liya Muhammed Kutty Abdul Rahman', phone: '+91 98765 43210', monthsSince: 14, bookings: 3),
              ReEngagementClient(phone: '+91 98765 00000', monthsSince: 8),
            ]),
          ),
        ]);
        expect(tester.takeException(), isNull);
        expect(_headerTitle(tester), 'Client Re-engagement');
        expect(find.text('2 clients due'), findsOneWidget);
        expect(find.text('WhatsApp'), findsNWidgets(2));
        await tester.tap(find.text('12mo'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });

      testWidgets('Sales Calendar: year-over-year cards and the month grid', (tester) async {
        final now = DateTime.now();
        await _pump(tester, size, const MarketingCalendarScreen(), [
          bookingCalendarProvider.overrideWith((ref) async => _calendar()),
          monthAvailabilityProvider.overrideWith((ref, key) async => _month(key.year, key.month)),
        ]);
        expect(tester.takeException(), isNull);
        expect(_headerTitle(tester), 'Sales Calendar');
        expect(find.text('${now.year} bookings'), findsOneWidget);
        expect(find.text('Calendar'), findsOneWidget);
        await _scrollThrough(tester);
      });

      testWidgets('Content Dashboard: KPIs and breakdowns', (tester) async {
        await _pump(tester, size, const ContentDashboardScreen(), [
          contentStatsProvider.overrideWith(
            (ref) async => const ContentStats(
              total: 40,
              byStatus: {'idea': 10, 'planned': 12, 'published': 18},
              byPlatform: {'instagram': 25, 'youtube': 10, 'facebook': 5},
              scheduledThisMonth: 7,
              publishedThisMonth: 12345,
              dueThisWeek: 3,
              overdue: 2,
            ),
          ),
        ]);
        expect(tester.takeException(), isNull);
        expect(_headerTitle(tester), 'Content Dashboard');
        expect(find.text('By platform'), findsOneWidget);
        expect(find.text('By status'), findsOneWidget);
        await _scrollThrough(tester);
      });

      testWidgets('Content Calendar: month grid, header controls and the day sheet', (tester) async {
        await _pump(tester, size, const ContentCalendarScreen(), [
          contentByMonthProvider.overrideWith((ref, key) async => _content()),
        ]);
        expect(tester.takeException(), isNull);
        expect(_headerTitle(tester), 'Content Calendar');
        expect(find.text('Add Content'), findsOneWidget);
        expect(find.text('Today'), findsOneWidget);
        // step a month forward and back
        await tester.tap(find.byTooltip('Next month'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Previous month'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        // tapping the 5th opens the day sheet listing its content
        await tester.tap(find.text('5').first);
        await tester.pumpAndSettle();
        expect(find.textContaining('4 items'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    });
  }
}
