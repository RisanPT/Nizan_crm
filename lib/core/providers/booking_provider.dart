import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../services/booking_service.dart';
import '../models/booking.dart';

part 'booking_provider.g.dart';

@riverpod
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
                  )
                  .isBefore(startOfToday),
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

    return [
      for (final booking in bookings)
        updatedById[booking.id] ?? booking,
    ];
  }

  Future<Booking> addBooking(Booking booking) async {
    final service = ref.read(bookingServiceProvider);

    try {
      final createdBooking = await service.createBooking(booking);
      if (ref.mounted) {
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
      state = AsyncData([
        for (final existing in state.value ?? [])
          if (existing.id == updatedBooking.id) updatedBooking else existing,
      ]);
      ref.invalidateSelf();
      return updatedBooking;
    } catch (err, stack) {
      state = previousState;
      state = AsyncError(err, stack);
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
    } catch (err, stack) {
      state = previousState; // Rollback
      state = AsyncError(err, stack);
    }
  }

  List<Booking> bookingsForDate(DateTime date) {
    return (state.value ?? []).where((b) => b.isOnDate(date)).toList();
  }
}
