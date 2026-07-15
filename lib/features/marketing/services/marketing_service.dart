import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/dio_provider.dart';
import '../data/marketing_models.dart';

final marketingServiceProvider = Provider<MarketingService>((ref) {
  return MarketingService(ref.watch(dioProvider));
});

final competitorsProvider = FutureProvider<List<Competitor>>((ref) async {
  return ref.watch(marketingServiceProvider).getCompetitors();
});

/// Weekly ranking board; pass a weekOf (ISO date) or null for the latest week.
final rankingsProvider =
    FutureProvider.family<RankingBoard, String?>((ref, weekOf) async {
  return ref.watch(marketingServiceProvider).getRankings(weekOf: weekOf);
});

class MarketingService {
  MarketingService(this._dio);
  final Dio _dio;

  Future<List<Competitor>> getCompetitors() async {
    try {
      final res = await _dio.get('/marketing/competitors');
      return (res.data as List)
          .map((e) => Competitor.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw Exception(_msg(e, 'Failed to load competitors'));
    }
  }

  Future<Competitor> createCompetitor(Competitor c) async {
    try {
      final res = await _dio.post('/marketing/competitors', data: c.toJson());
      return Competitor.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(_msg(e, 'Failed to add competitor'));
    }
  }

  Future<Competitor> updateCompetitor(String id, Competitor c) async {
    try {
      final res =
          await _dio.put('/marketing/competitors/$id', data: c.toJson());
      return Competitor.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(_msg(e, 'Failed to update competitor'));
    }
  }

  Future<void> deleteCompetitor(String id) async {
    try {
      await _dio.delete('/marketing/competitors/$id');
    } on DioException catch (e) {
      throw Exception(_msg(e, 'Failed to delete competitor'));
    }
  }

  /// Add/update a competitor's weekly snapshot. [data] holds numeric metrics +
  /// boolean flags; the backend computes the score.
  Future<CompetitorSnapshot> upsertSnapshot(
      String competitorId, Map<String, dynamic> data) async {
    try {
      final res = await _dio.post(
          '/marketing/competitors/$competitorId/snapshot',
          data: data);
      return CompetitorSnapshot.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(_msg(e, 'Failed to save weekly data'));
    }
  }

  /// Bulk import parsed CSV rows. Returns {created, updated, snapshots, errors}.
  Future<Map<String, dynamic>> importRows(
    List<Map<String, dynamic>> rows, {
    DateTime? weekOf,
  }) async {
    try {
      final res = await _dio.post('/marketing/competitors/import', data: {
        'rows': rows,
        'weekOf': ?weekOf?.toIso8601String(),
      });
      return Map<String, dynamic>.from(res.data as Map);
    } on DioException catch (e) {
      throw Exception(_msg(e, 'Import failed'));
    }
  }

  Future<RankingBoard> getRankings({String? weekOf}) async {
    try {
      final res = await _dio.get('/marketing/rankings',
          queryParameters: {'weekOf': ?weekOf});
      return RankingBoard.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(_msg(e, 'Failed to load rankings'));
    }
  }

  String _msg(DioException e, String fallback) {
    final data = e.response?.data;
    if (data is Map && data['message'] is String) return data['message'];
    return e.message ?? fallback;
  }
}
