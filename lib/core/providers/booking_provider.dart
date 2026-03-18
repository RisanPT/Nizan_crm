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

  Future<void> addBooking(Booking booking) async {
    final service = ref.read(bookingServiceProvider);
    
    // Optimistic update
    final previousState = state;
    state = AsyncData([...(state.value ?? []), booking]);

    try {
      await service.createBooking(booking);
      // Wait to re-fetch to ensure sync with backend, or just keep optimistic state
      ref.invalidateSelf();
    } catch (err, stack) {
      state = previousState; // Rollback
      state = AsyncError(err, stack);
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

