import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'package:nizan_crm/core/error/error_message.dart';
import 'package:nizan_crm/features/reviews/data/review.dart';
import 'package:nizan_crm/providers/dio_provider.dart';

class ReviewService {
  final Dio _dio;
  ReviewService(this._dio);

  Future<List<Review>> getReviews({
    String? status,
    bool complaint = false,
    bool followUp = false,
    String? search,
  }) async {
    try {
      final qp = <String, dynamic>{};
      if (status != null && status.isNotEmpty && status != 'all') {
        qp['status'] = status;
      }
      if (complaint) qp['complaint'] = 'true';
      if (followUp) qp['followUp'] = 'true';
      if (search != null && search.trim().isNotEmpty) qp['search'] = search.trim();
      final res = await _dio.get('/reviews', queryParameters: qp.isEmpty ? null : qp);
      return (res.data as List)
          .map((e) => Review.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw Exception(friendlyErrorMessage(e, fallback: 'Failed to load reviews'));
    }
  }

  /// Ensure a review exists for the booking and return its public form URL.
  Future<String> getReviewLink(String bookingId) async {
    try {
      final res = await _dio.post('/reviews/for-booking/$bookingId');
      return (res.data['reviewUrl'] ?? '').toString();
    } on DioException catch (e) {
      throw Exception(friendlyErrorMessage(e, fallback: 'Failed to get the review link'));
    }
  }

  Future<ArtistReviewPerformance> getArtistPerformance(String employeeId) async {
    try {
      final res = await _dio.get('/reviews/artist/$employeeId');
      return ArtistReviewPerformance.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(
          friendlyErrorMessage(e, fallback: 'Failed to load artist reviews'));
    }
  }

  Future<ReviewAnalytics> getAnalytics() async {
    try {
      final res = await _dio.get('/reviews/analytics');
      return ReviewAnalytics.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(friendlyErrorMessage(e, fallback: 'Failed to load insights'));
    }
  }

  Future<Review> getById(String id) async {
    try {
      final res = await _dio.get('/reviews/$id');
      return Review.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(friendlyErrorMessage(e, fallback: 'Failed to load review'));
    }
  }

  Future<Review> updateInternal(
    String id, {
    bool? complaint,
    bool? compliment,
    bool? followUpRequired,
    bool? reviewPosted,
    bool? referralOpportunity,
    String? managerComments,
  }) async {
    try {
      final res = await _dio.put('/reviews/$id', data: {
        'complaint': ?complaint,
        'compliment': ?compliment,
        'followUpRequired': ?followUpRequired,
        'reviewPosted': ?reviewPosted,
        'referralOpportunity': ?referralOpportunity,
        'managerComments': ?managerComments,
      });
      return Review.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(friendlyErrorMessage(e, fallback: 'Failed to update review'));
    }
  }
}

final reviewServiceProvider =
    Provider<ReviewService>((ref) => ReviewService(ref.watch(dioProvider)));

class ReviewFilter {
  final String status; // all | submitted | pending
  final bool complaint;
  final String search;
  const ReviewFilter({this.status = 'submitted', this.complaint = false, this.search = ''});

  ReviewFilter copyWith({String? status, bool? complaint, String? search}) => ReviewFilter(
        status: status ?? this.status,
        complaint: complaint ?? this.complaint,
        search: search ?? this.search,
      );

  @override
  bool operator ==(Object other) =>
      other is ReviewFilter &&
      other.status == status &&
      other.complaint == complaint &&
      other.search == search;
  @override
  int get hashCode => Object.hash(status, complaint, search);
}

final reviewFilterProvider =
    StateProvider<ReviewFilter>((ref) => const ReviewFilter());

final reviewsProvider = FutureProvider<List<Review>>((ref) async {
  final f = ref.watch(reviewFilterProvider);
  return ref.watch(reviewServiceProvider).getReviews(
        status: f.status,
        complaint: f.complaint,
        search: f.search,
      );
});

final reviewAnalyticsProvider = FutureProvider<ReviewAnalytics>((ref) async {
  return ref.watch(reviewServiceProvider).getAnalytics();
});

/// A single artist's client-review performance (avg rating, breakdown,
/// testimonials), keyed by their Employee id.
final artistReviewPerformanceProvider =
    FutureProvider.family<ArtistReviewPerformance, String>((ref, empId) async {
  return ref.watch(reviewServiceProvider).getArtistPerformance(empId);
});

class ArtistReviewTestimonial {
  final String text, bride;
  final double rating;
  final bool consent;
  const ArtistReviewTestimonial(
      {this.text = '', this.bride = '', this.rating = 0, this.consent = false});
  factory ArtistReviewTestimonial.fromJson(Map<String, dynamic> j) =>
      ArtistReviewTestimonial(
        text: (j['text'] ?? '').toString(),
        bride: (j['bride'] ?? '').toString(),
        rating: (j['rating'] as num?)?.toDouble() ?? 0,
        consent: j['consent'] == true,
      );
}

class ArtistReviewPerformance {
  final int reviewCount;
  final double avgClientRating;
  final double avgBrideScore;
  final Map<String, double> breakdown;
  final List<ArtistReviewTestimonial> testimonials;
  const ArtistReviewPerformance({
    this.reviewCount = 0,
    this.avgClientRating = 0,
    this.avgBrideScore = 0,
    this.breakdown = const {},
    this.testimonials = const [],
  });

  factory ArtistReviewPerformance.fromJson(Map<String, dynamic> j) {
    final b = (j['breakdown'] as Map?) ?? const {};
    return ArtistReviewPerformance(
      reviewCount: (j['reviewCount'] as num?)?.toInt() ?? 0,
      avgClientRating: (j['avgClientRating'] as num?)?.toDouble() ?? 0,
      avgBrideScore: (j['avgBrideScore'] as num?)?.toDouble() ?? 0,
      breakdown:
          b.map((k, v) => MapEntry(k.toString(), (v as num?)?.toDouble() ?? 0)),
      testimonials: ((j['testimonials'] as List?) ?? const [])
          .map((e) => ArtistReviewTestimonial.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class ArtistStat {
  final String artistName;
  final int count;
  final double avgBrideScore, avgTeamScore;
  const ArtistStat({
    required this.artistName,
    this.count = 0,
    this.avgBrideScore = 0,
    this.avgTeamScore = 0,
  });

  factory ArtistStat.fromJson(Map<String, dynamic> j) => ArtistStat(
        artistName: (j['artistName'] ?? '').toString(),
        count: (j['count'] as num?)?.toInt() ?? 0,
        avgBrideScore: (j['avgBrideScore'] as num?)?.toDouble() ?? 0,
        avgTeamScore: (j['avgTeamScore'] as num?)?.toDouble() ?? 0,
      );
}

class ReviewAnalytics {
  final int totalSubmitted, pending;
  final double avgBrideScore, avgTeamScore;
  final int nps, promoters, passives, detractors, npsResponses;
  final int complaints, followUps, testimonialsAvailable;
  final List<ArtistStat> perArtist;

  const ReviewAnalytics({
    this.totalSubmitted = 0,
    this.pending = 0,
    this.avgBrideScore = 0,
    this.avgTeamScore = 0,
    this.nps = 0,
    this.promoters = 0,
    this.passives = 0,
    this.detractors = 0,
    this.npsResponses = 0,
    this.complaints = 0,
    this.followUps = 0,
    this.testimonialsAvailable = 0,
    this.perArtist = const [],
  });

  factory ReviewAnalytics.fromJson(Map<String, dynamic> j) {
    int i(dynamic v) => (v as num?)?.toInt() ?? 0;
    double d(dynamic v) => (v as num?)?.toDouble() ?? 0;
    return ReviewAnalytics(
      totalSubmitted: i(j['totalSubmitted']),
      pending: i(j['pending']),
      avgBrideScore: d(j['avgBrideScore']),
      avgTeamScore: d(j['avgTeamScore']),
      nps: i(j['nps']),
      promoters: i(j['promoters']),
      passives: i(j['passives']),
      detractors: i(j['detractors']),
      npsResponses: i(j['npsResponses']),
      complaints: i(j['complaints']),
      followUps: i(j['followUps']),
      testimonialsAvailable: i(j['testimonialsAvailable']),
      perArtist: ((j['perArtist'] as List?) ?? const [])
          .map((e) => ArtistStat.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
