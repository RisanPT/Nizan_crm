import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'package:nizan_crm/features/reviews/data/review.dart';
import 'package:nizan_crm/providers/dio_provider.dart';
import 'package:nizan_crm/core/error/errors.dart';

class ReviewService {
  final Dio _dio;
  ReviewService(this._dio);

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
    try {
      final qp = <String, dynamic>{};
      if (status != null && status.isNotEmpty && status != 'all') {
        qp['status'] = status;
      }
      if (sentOnly) qp['sent'] = 'true';
      if (complaint) qp['complaint'] = 'true';
      if (followUp) qp['followUp'] = 'true';
      if (search != null && search.trim().isNotEmpty) qp['search'] = search.trim();
      if (artist != null && artist.trim().isNotEmpty) qp['artist'] = artist.trim();
      if (from != null) qp['from'] = _day(from);
      if (to != null) qp['to'] = _day(to);
      final res = await _dio.get('/reviews', queryParameters: qp.isEmpty ? null : qp);
      return (res.data as List)
          .map((e) => Review.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw AppException(e, action: 'load reviews');
    }
  }

  /// Ensure a review exists for the booking and return its public form URL.
  /// [markSent] = staff are sending the link by hand now, so the automatic
  /// next-day WhatsApp send skips this client.
  Future<String> getReviewLink(String bookingId, {bool markSent = false}) async {
    try {
      final res = await _dio.post('/reviews/for-booking/$bookingId',
          data: markSent ? {'markSent': true} : null);
      return (res.data['reviewUrl'] ?? '').toString();
    } catch (e) {
      throw AppException(e, action: 'get the review link');
    }
  }

  Future<ArtistReviewPerformance> getArtistPerformance(String employeeId) async {
    try {
      final res = await _dio.get('/reviews/artist/$employeeId');
      return ArtistReviewPerformance.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw AppException(e, action: 'load artist reviews');
    }
  }

  static String _day(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<ReviewAnalytics> getAnalytics({DateTime? from, DateTime? to}) async {
    try {
      final qp = <String, dynamic>{
        if (from != null) 'from': _day(from),
        if (to != null) 'to': _day(to),
      };
      final res = await _dio.get('/reviews/analytics', queryParameters: qp.isEmpty ? null : qp);
      return ReviewAnalytics.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw AppException(e, action: 'load insights');
    }
  }

  Future<Review> getById(String id) async {
    try {
      final res = await _dio.get('/reviews/$id');
      return Review.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw AppException(e, action: 'load review');
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
    } catch (e) {
      throw AppException(e, action: 'update review');
    }
  }
}

final reviewServiceProvider =
    Provider<ReviewService>((ref) => ReviewService(ref.watch(dioProvider)));

/// Filters for one Reviews tab. [from]/[to] are inclusive days: the submitted
/// date on the Submitted tab, the wedding date on Not submitted.
class ReviewFilter {
  final String search;
  final String artist; // '' = all artists
  final DateTime? from, to;
  final bool followUpOnly; // Submitted tab: complaints / needs follow-up
  final String engagement; // Not submitted tab: '' | notOpened | opened | started

  const ReviewFilter({
    this.search = '',
    this.artist = '',
    this.from,
    this.to,
    this.followUpOnly = false,
    this.engagement = '',
  });

  ReviewFilter copyWith({
    String? search,
    String? artist,
    DateTime? from,
    DateTime? to,
    bool clearDates = false,
    bool? followUpOnly,
    String? engagement,
  }) =>
      ReviewFilter(
        search: search ?? this.search,
        artist: artist ?? this.artist,
        from: clearDates ? null : (from ?? this.from),
        to: clearDates ? null : (to ?? this.to),
        followUpOnly: followUpOnly ?? this.followUpOnly,
        engagement: engagement ?? this.engagement,
      );

  @override
  bool operator ==(Object other) =>
      other is ReviewFilter &&
      other.search == search &&
      other.artist == artist &&
      other.from == from &&
      other.to == to &&
      other.followUpOnly == followUpOnly &&
      other.engagement == engagement;
  @override
  int get hashCode => Object.hash(search, artist, from, to, followUpOnly, engagement);
}

final reviewFilterProvider =
    StateProvider<ReviewFilter>((ref) => const ReviewFilter());
final notSubmittedFilterProvider =
    StateProvider<ReviewFilter>((ref) => const ReviewFilter());

/// Submitted reviews (Submitted tab).
final reviewsProvider = FutureProvider<List<Review>>((ref) async {
  final f = ref.watch(reviewFilterProvider);
  return ref.watch(reviewServiceProvider).getReviews(
        status: 'submitted',
        complaint: f.followUpOnly,
        search: f.search,
        from: f.from,
        to: f.to,
      );
});

/// Keep only reviews where [artist] was on the team ('' = everyone). Done on
/// the device so the artist dropdown can list everyone in the loaded period.
List<Review> filterByArtist(List<Review> list, String artist) {
  if (artist.isEmpty) return list;
  final a = artist.toLowerCase();
  return list
      .where((r) =>
          r.artistName.toLowerCase() == a ||
          r.artistNames.any((n) => n.toLowerCase() == a))
      .toList();
}

/// Every artist name on the given reviews, sorted.
List<String> artistsIn(List<Review> list) {
  final set = <String>{};
  for (final r in list) {
    if (r.artistName.trim().isNotEmpty) set.add(r.artistName.trim());
    set.addAll(r.artistNames.map((n) => n.trim()).where((n) => n.isNotEmpty));
  }
  return set.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
}

/// Clients who were sent the review link but haven't submitted (Not
/// submitted tab). Artist + engagement filters are applied on the device.
final notSubmittedReviewsProvider = FutureProvider<List<Review>>((ref) async {
  final f = ref.watch(notSubmittedFilterProvider);
  return ref.watch(reviewServiceProvider).getReviews(
        status: 'pending',
        sentOnly: true,
        search: f.search,
        from: f.from,
        to: f.to,
      );
});

/// All-time analytics (also used by the artist screens).
final reviewAnalyticsProvider = FutureProvider<ReviewAnalytics>((ref) async {
  return ref.watch(reviewServiceProvider).getAnalytics();
});

/// Reviews-screen summary period: null = all time, else the last N days.
final reviewPeriodDaysProvider = StateProvider<int?>((ref) => null);

/// Analytics for the Reviews screen's chosen period.
final reviewInsightsProvider = FutureProvider<ReviewAnalytics>((ref) async {
  final days = ref.watch(reviewPeriodDaysProvider);
  if (days == null) return ref.watch(reviewAnalyticsProvider.future);
  final now = DateTime.now();
  return ref.watch(reviewServiceProvider).getAnalytics(
        from: DateTime(now.year, now.month, now.day).subtract(Duration(days: days - 1)),
        to: now,
      );
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
  final int notSubmitted, notOpened, responseRate;
  final Map<String, double> categoryAverages;
  final double avgBrideScore, avgTeamScore;
  final int nps, promoters, passives, detractors, npsResponses;
  final int complaints, followUps, testimonialsAvailable;
  final List<ArtistStat> perArtist;

  const ReviewAnalytics({
    this.totalSubmitted = 0,
    this.pending = 0,
    this.notSubmitted = 0,
    this.notOpened = 0,
    this.responseRate = 0,
    this.categoryAverages = const {},
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
      notSubmitted: i(j['notSubmitted']),
      notOpened: i(j['notOpened']),
      responseRate: i(j['responseRate']),
      categoryAverages: ((j['categoryAverages'] as Map?) ?? const {})
          .map((k, v) => MapEntry(k.toString(), d(v))),
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
