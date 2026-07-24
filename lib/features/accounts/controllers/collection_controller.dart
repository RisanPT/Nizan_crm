import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nizan_crm/features/accounts/data/artist_collection.dart';
import 'package:nizan_crm/providers/dio_provider.dart';
import 'package:nizan_crm/features/accounts/services/collection_service.dart';

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
