import 'dart:async';
import 'package:flutter_riverpod/legacy.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:nizan_crm/core/auth/app_role.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../services/booking_service.dart';
import '../models/booking.dart';
import 'auth_provider.dart';

part 'booking_provider.g.dart';

class PaginatedBookingsParams {
  final int page;
  final int limit;
  final String search;
  final bool duplicatesOnly;
  final String? financialYear;
  final String? employeeId;
  final String? zoneId;
  final String? stateId;
  final String? regionId;
  final String? districtId;
  final String? pincodeId;

  const PaginatedBookingsParams({
    required this.page,
    required this.limit,
    this.search = '',
    this.duplicatesOnly = false,
    this.financialYear,
    this.employeeId,
    this.zoneId,
    this.stateId,
    this.regionId,
    this.districtId,
    this.pincodeId,
  });

  @override
  bool operator ==(Object other) {
    return other is PaginatedBookingsParams &&
        other.page == page &&
        other.limit == limit &&
        other.search == search &&
        other.duplicatesOnly == duplicatesOnly &&
        other.financialYear == financialYear &&
        other.employeeId == employeeId &&
        other.zoneId == zoneId &&
        other.stateId == stateId &&
        other.regionId == regionId &&
        other.districtId == districtId &&
        other.pincodeId == pincodeId;
  }

  @override
  int get hashCode => Object.hash(
    page,
    limit,
    search,
    duplicatesOnly,
    financialYear,
    employeeId,
    zoneId,
    stateId,
    regionId,
    districtId,
    pincodeId,
  );
}

final bookingsRefreshTriggerProvider = StateProvider<int>((ref) => 0);

final paginatedBookingsProvider =
    FutureProvider.family<PaginatedBookingsResponse, PaginatedBookingsParams>((
      ref,
      params,
    ) async {
      ref.watch(bookingsRefreshTriggerProvider);
      final authSession = ref.watch(authControllerProvider).session;
      final role = AppRole.fromString(authSession?.role);

      var zoneId = params.zoneId;
      var stateId = params.stateId;
      var regionId = params.regionId;
      var districtId = params.districtId;
      var pincodeId = params.pincodeId;

      if (!role.isFullAccess) {
        if (authSession != null) {
          if (authSession.zoneId.isNotEmpty) zoneId = authSession.zoneId;
          if (authSession.stateId.isNotEmpty) stateId = authSession.stateId;
          if (authSession.regionId.isNotEmpty) regionId = authSession.regionId;
          if (authSession.districtId.isNotEmpty) districtId = authSession.districtId;
          if (authSession.pincodeId.isNotEmpty) pincodeId = authSession.pincodeId;
        }
      }

      return ref.watch(bookingServiceProvider).getPaginatedBookings(
            page: params.page,
            limit: params.limit,
            search: params.search,
            duplicatesOnly: params.duplicatesOnly,
            financialYear: params.financialYear,
            employeeId: params.employeeId,
            zoneId: zoneId,
            stateId: stateId,
            regionId: regionId,
            districtId: districtId,
            pincodeId: pincodeId,
          );
    });

final artistAssignedWorksProvider =
    FutureProvider.family<PaginatedBookingsResponse, int>((ref, page) async {
      final auth = ref.watch(authControllerProvider);
      final employeeId = auth.session?.employeeId ?? '';

      if (employeeId.isEmpty) {
        return const PaginatedBookingsResponse(
          items: [],
          page: 1,
          limit: 20,
          totalItems: 0,
          totalPages: 1,
          summary: BookingPageSummary(
            totalSales: 0,
            totalAdvance: 0,
            completedCount: 0,
            cancelledCount: 0,
          ),
        );
      }

      return ref.watch(
        paginatedBookingsProvider(
          PaginatedBookingsParams(
            page: page,
            limit: 20,
            employeeId: employeeId,
          ),
        ).future,
      );
    });

@Riverpod(keepAlive: true)
class BookingNotifier extends _$BookingNotifier {
  @override
  FutureOr<List<Booking>> build() async {
    return _fetchBookings();
  }

  Future<List<Booking>> _fetchBookings() async {
    final service = ref.watch(bookingServiceProvider);
    final bookings = await service.getBookings();
    return _syncAutoCompletedBookings(service, bookings);
  }

  Future<List<Booking>> _syncAutoCompletedBookings(
    BookingService service,
    List<Booking> bookings,
  ) async {
    final today = DateTime.now();
    final startOfToday = DateTime(today.year, today.month, today.day);

    final staleConfirmedBookings = bookings
        .where(
          (booking) =>
              booking.status.toLowerCase() == 'confirmed' &&
              DateTime(
                booking.serviceEnd.year,
                booking.serviceEnd.month,
                booking.serviceEnd.day,
              ).isBefore(startOfToday),
        )
        .toList();

    if (staleConfirmedBookings.isEmpty) {
      return bookings;
    }

    final updatedById = <String, Booking>{};

    for (final booking in staleConfirmedBookings) {
      try {
        final updated = await service.updateBooking(
          booking.copyWith(status: 'completed'),
        );
        updatedById[updated.id] = updated;
      } catch (_) {
        updatedById[booking.id] = booking.copyWith(status: 'completed');
      }
    }

    return [for (final booking in bookings) updatedById[booking.id] ?? booking];
  }

  Future<Booking> addBooking(Booking booking) async {
    final service = ref.read(bookingServiceProvider);

    try {
      final createdBooking = await service.createBooking(booking);
      if (ref.mounted) {
        ref.read(bookingsRefreshTriggerProvider.notifier).state++;
        ref.invalidateSelf();
      }
      return createdBooking;
    } catch (err, stack) {
      if (ref.mounted) {
        state = AsyncError(err, stack);
      }
      rethrow;
    }
  }

  Future<Booking> updateBooking(Booking booking) async {
    final service = ref.read(bookingServiceProvider);
    final previousState = state;
    final currentBookings = state.value ?? [];

    state = AsyncData([
      for (final existing in currentBookings)
        if (existing.id == booking.id) booking else existing,
    ]);

    try {
      final updatedBooking = await service.updateBooking(booking);
      if (ref.mounted) {
        state = AsyncData([
          for (final existing in state.value ?? [])
            if (existing.id == updatedBooking.id) updatedBooking else existing,
        ]);
        ref.read(bookingsRefreshTriggerProvider.notifier).state++;
        ref.invalidateSelf();
      }
      return updatedBooking;
    } catch (err, stack) {
      if (ref.mounted) {
        state = previousState;
        state = AsyncError(err, stack);
      }
      rethrow;
    }
  }

  Future<void> removeBooking(String id) async {
    final service = ref.read(bookingServiceProvider);

    // Optimistic update
    final previousState = state;
    state = AsyncData((state.value ?? []).where((b) => b.id != id).toList());

    try {
      await service.deleteBooking(id);
      if (ref.mounted) {
        ref.read(bookingsRefreshTriggerProvider.notifier).state++;
      }
    } catch (err, stack) {
      if (ref.mounted) {
        state = previousState; // Rollback
        state = AsyncError(err, stack);
      }
    }
  }

  List<Booking> bookingsForDate(DateTime date) {
    return (state.value ?? []).where((b) => b.isOnDate(date)).toList();
  }
}
