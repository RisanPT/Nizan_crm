import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:nizan_crm/features/accounts/data/artist_collection.dart';
import 'package:nizan_crm/features/accounts/controllers/collection_controller.dart';
import 'package:nizan_crm/features/bookings/controllers/booking_provider.dart' show bookingsRefreshTriggerProvider;

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
  // Not registered in data_refresh.collections(); watching the bookings
  // trigger (bumped by refreshData.collections()/bookings()) keeps it fresh.
  ref.watch(bookingsRefreshTriggerProvider);
  final filters = ref.watch(collectionFiltersProvider);
  return ref.watch(collectionServiceProvider).getCollections(
    employeeId: filters.employeeId,
    paymentMode: filters.paymentMode,
    startDate: filters.startDate,
    endDate: filters.endDate,
    status: filters.status,
  );
});
