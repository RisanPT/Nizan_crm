import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/models/artist_collection.dart';
import '../providers/dio_provider.dart';

final collectionServiceProvider = Provider<CollectionService>((ref) {
  return CollectionService(ref.watch(dioProvider));
});

/// All collections (accounts-team view, filterable).
final collectionsProvider = FutureProvider<List<ArtistCollection>>((ref) async {
  return ref.watch(collectionServiceProvider).getCollections();
});

/// Collections scoped to a single artist (artist view).
final artistCollectionsProvider =
    FutureProvider.family<List<ArtistCollection>, String>((ref, employeeId) async {
  return ref
      .watch(collectionServiceProvider)
      .getCollections(employeeId: employeeId);
});

class CollectionService {
  final Dio _dio;

  CollectionService(this._dio);

  Future<List<ArtistCollection>> getCollections({
    String? status,
    String? bookingId,
    String? employeeId,
  }) async {
    try {
      final Map<String, dynamic> query = {};
      if (status != null) query['status'] = status;
      if (bookingId != null) query['bookingId'] = bookingId;
      if (employeeId != null) query['employeeId'] = employeeId;

      final response = await _dio.get(
        '/collections',
        queryParameters: query.isNotEmpty ? query : null,
      );
      final data = response.data as List;
      return data
          .map((item) => ArtistCollection.fromJson(item as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw Exception('Failed to load collections: ${e.message}');
    }
  }

  Future<ArtistCollection> createCollection({
    required String bookingId,
    required String employeeId,
    required double amount,
    required DateTime date,
    required String paymentMode,
    String notes = '',
  }) async {
    try {
      final payload = {
        'bookingId': bookingId,
        'employeeId': employeeId,
        'amount': amount,
        'date': date.toIso8601String(),
        'paymentMode': paymentMode,
        'notes': notes,
      };
      final response = await _dio.post('/collections', data: payload);
      return ArtistCollection.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      final data = e.response?.data;
      throw Exception(
        (data is Map && data['message'] != null)
            ? data['message'].toString()
            : 'Failed to create collection: ${e.message}',
      );
    }
  }

  Future<ArtistCollection> verifyCollection({
    required String id,
    required String status, // 'verified' | 'rejected'
    required String verifiedBy,
  }) async {
    try {
      final response = await _dio.put(
        '/collections/$id/verify',
        data: {'status': status, 'verifiedBy': verifiedBy},
      );
      return ArtistCollection.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception('Failed to verify collection: ${e.message}');
    }
  }

  Future<void> deleteCollection(String id) async {
    try {
      await _dio.delete('/collections/$id');
    } on DioException catch (e) {
      throw Exception('Failed to delete collection: ${e.message}');
    }
  }
}
