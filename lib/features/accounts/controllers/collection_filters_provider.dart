import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:nizan_crm/features/accounts/data/artist_collection.dart';
import 'package:nizan_crm/features/accounts/controllers/collection_controller.dart';

class CollectionFilters {
  final String? employeeId;
  final String? paymentMode;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? status;

  CollectionFilters({
    this.employeeId,
    this.paymentMode,
    this.startDate,
    this.endDate,
    this.status,
  });

  CollectionFilters copyWith({
    String? employeeId,
    String? paymentMode,
    DateTime? startDate,
    DateTime? endDate,
    String? status,
  }) {
    return CollectionFilters(
      employeeId: employeeId ?? this.employeeId,
      paymentMode: paymentMode ?? this.paymentMode,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      status: status ?? this.status,
    );
  }

  CollectionFilters reset() {
    return CollectionFilters();
  }
}

final collectionFiltersProvider = StateProvider<CollectionFilters>((ref) {
  return CollectionFilters();
});

final filteredCollectionsProvider = FutureProvider<List<ArtistCollection>>((ref) async {
  final filters = ref.watch(collectionFiltersProvider);
  return ref.watch(collectionServiceProvider).getCollections(
    employeeId: filters.employeeId,
    paymentMode: filters.paymentMode,
    startDate: filters.startDate,
    endDate: filters.endDate,
    status: filters.status,
  );
});
