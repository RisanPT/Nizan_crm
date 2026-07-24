import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nizan_crm/core/theme/app_theme.dart';
import 'package:nizan_crm/features/marketing/data/marketing_models.dart';
import 'package:nizan_crm/features/marketing/presentation/screens/growth_scores_screen.dart';
import 'package:nizan_crm/features/marketing/services/marketing_service.dart';

/// A competitor triggering all seven signals — the case that overflowed the
/// fixed-height evidence sheet by 99px.
RankingBoard _boardWithMaxSignals() {
  const keys = [
    ('newCampaign', 'New Campaign', 5),
    ('viralContent', 'Viral Content', 5),
    ('qualityCreative', 'Quality Creative', 5),
    ('followerGrowth', 'Follower Growth', 3),
    ('engagementIncrease', 'Engagement Increase', 3),
    ('newService', 'New Service', 2),
    ('newPartnership', 'New Partnership', 2),
  ];
  return RankingBoard(
    weekOf: DateTime(2026, 7, 20),
    rankings: [
      CompetitorRanking(
        rank: 1,
        competitorId: 'c1',
        name: 'Glamour Studio Kochi',
        city: 'Kochi',
        category: 'Bridal',
        instagram: 'glam',
        score: 25,
        previousScore: 17,
        movement: 8,
        signals: [
          for (final k in keys)
            ScoreSignal(
              key: k.$1,
              label: k.$2,
              points: k.$3,
              evidence: 'Evidence for ${k.$2}',
              link: 'https://instagram.com/reel/${k.$1}',
            ),
        ],
      ),
    ],
    reels: const [],
    websites: const [],
    collaborations: const [],
  );
}

void main() {
  testWidgets('evidence sheet scrolls instead of overflowing with 7 signals',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        rankingsProvider(null).overrideWith((ref) async => _boardWithMaxSignals()),
        competitorsProvider.overrideWith((ref) async => <Competitor>[]),
      ],
      child: MaterialApp(
        theme: ThemeData(extensions: [AppTheme.crmThemeExtension]),
        home: const Scaffold(body: GrowthScoresScreen()),
      ),
    ));
    await tester.pumpAndSettle();

    // Open the evidence sheet by tapping the competitor row.
    await tester.tap(find.text('Glamour Studio Kochi'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Glamour Studio Kochi · score 25/25'), findsOneWidget);
    // A signal near the end is present (scrollable), even if off-screen.
    expect(find.text('New Partnership'), findsOneWidget);
  });
}
