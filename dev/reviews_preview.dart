// DEV ONLY — a stand-alone preview of the Client Reviews screen with made-up
// sample data: no backend, no login, nothing is saved or sent. Build + serve:
//   flutter build web -t dev/reviews_preview.dart -o build/reviews_preview
//   node dev/serve_static.mjs build/reviews_preview 5191
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/core/theme/app_theme.dart';
import 'package:nizan_crm/features/reviews/data/review.dart';
import 'package:nizan_crm/features/reviews/presentation/screens/reviews_screen.dart';
import 'package:nizan_crm/features/reviews/services/review_service.dart';

DateTime _ago(int d) => DateTime.now().subtract(Duration(days: d));

final _submitted = [
  for (final (i, n, a, s, nps, q, c) in [
    (0, 'Sample Bride A', 'Artist One', 4.8, 10, 'The makeup lasted all day and the team was so calm.', false),
    (1, 'Sample Bride B', 'Artist Two', 4.2, 8, 'Lovely look, hair took a little longer than planned.', false),
    (2, 'Sample Bride C', 'Artist One', 2.4, 4, 'Team arrived late and the saree draping was rushed.', true),
    (3, 'Sample Bride D', 'Artist Three', 5.0, 9, '', false),
  ])
    Review(
      id: 's$i',
      brideName: n,
      artistName: a,
      artistNames: [a],
      bookingNumber: 'BK-10${20 + i}',
      status: 'submitted',
      submittedAt: _ago(i * 3 + 1),
      createdAt: _ago(i * 3 + 4),
      brideScore: s,
      nps: nps,
      testimonial: q,
      marketingConsent: q.isNotEmpty && !c,
      complaint: c,
      followUpRequired: c,
      reviewPosted: i == 0,
    ),
];

final _pending = [
  Review(
    id: 'p1', brideName: 'Sample Client E', artistName: 'Artist Two', artistNames: const ['Artist Two'],
    bookingNumber: 'BK-1031', status: 'pending', createdAt: _ago(6), weddingDate: _ago(6),
    manualSentAt: _ago(5), lastManualSentAt: _ago(5), manualSendCount: 1,
    customerPhone: '+910000000001', reviewUrl: 'http://localhost/sample-link-1',
  ),
  Review(
    id: 'p2', brideName: 'Sample Client F', artistName: 'Artist One', artistNames: const ['Artist One'],
    bookingNumber: 'BK-1032', status: 'pending', createdAt: _ago(3), weddingDate: _ago(3),
    autoSendStatus: 'sent', autoSentAt: _ago(2), openedAt: _ago(2), lastOpenedAt: _ago(1), openCount: 2,
    customerPhone: '+910000000002', reviewUrl: 'http://localhost/sample-link-2',
  ),
  Review(
    id: 'p3', brideName: 'Sample Client G', artistName: 'Artist Three', artistNames: const ['Artist Three'],
    bookingNumber: 'BK-1033', status: 'pending', createdAt: _ago(9), weddingDate: _ago(9),
    manualSentAt: _ago(8), lastManualSentAt: _ago(2), manualSendCount: 3,
    openedAt: _ago(8), lastOpenedAt: _ago(2), openCount: 3, answeredCount: 6, totalQuestions: 12,
    customerPhone: '+910000000003', reviewUrl: 'http://localhost/sample-link-3',
  ),
];

class _SampleReviewService extends ReviewService {
  _SampleReviewService() : super(Dio());

  @override
  Future<List<Review>> getReviews({
    String? status,
    bool sentOnly = false,
    bool complaint = false,
    bool followUp = false,
    String? search,
    String? artist,
    DateTime? from,
    DateTime? to,
  }) async {
    var list = status == 'pending' ? _pending : _submitted;
    if (complaint) list = list.where((r) => r.complaint).toList();
    final q = (search ?? '').toLowerCase();
    if (q.isNotEmpty) list = list.where((r) => r.brideName.toLowerCase().contains(q)).toList();
    return list;
  }

  @override
  Future<ReviewAnalytics> getAnalytics({DateTime? from, DateTime? to}) async => const ReviewAnalytics(
        totalSubmitted: 4,
        pending: 3,
        notSubmitted: 3,
        notOpened: 1,
        responseRate: 57,
        avgBrideScore: 4.1,
        avgTeamScore: 4.3,
        nps: 25,
        promoters: 2,
        passives: 1,
        detractors: 1,
        npsResponses: 4,
        complaints: 1,
        followUps: 1,
        testimonialsAvailable: 2,
        categoryAverages: {
          'overall': 4.3, 'makeup': 4.6, 'hair': 3.9, 'saree': 3.4, 'punctuality': 3.8,
          'professionalism': 4.5, 'communication': 4.4, 'politeness': 4.8, 'handlingRequests': 4.2,
        },
        perArtist: [
          ArtistStat(artistName: 'Artist Three', count: 1, avgBrideScore: 5, avgTeamScore: 5),
          ArtistStat(artistName: 'Artist Two', count: 1, avgBrideScore: 4.2, avgTeamScore: 4.4),
          ArtistStat(artistName: 'Artist One', count: 2, avgBrideScore: 3.6, avgTeamScore: 3.9),
        ],
      );
}

void main() {
  runApp(ProviderScope(
    overrides: [reviewServiceProvider.overrideWithValue(_SampleReviewService())],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const ReviewsScreen(),
    ),
  ));
}
