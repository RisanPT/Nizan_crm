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
    return service.getBookings();
  }

  Future<Booking> addBooking(Booking booking) async {
    final service = ref.read(bookingServiceProvider);

    // Optimistic update
    final previousState = state;
    state = AsyncData([...(state.value ?? []), booking]);

    try {
      final createdBooking = await service.createBooking(booking);
      state = AsyncData([
        for (final existing in state.value ?? [])
          if (existing.id == booking.id) createdBooking else existing,
      ]);
      ref.invalidateSelf();
      return createdBooking;
    } catch (err, stack) {
      state = previousState; // Rollback
      state = AsyncError(err, stack);
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
