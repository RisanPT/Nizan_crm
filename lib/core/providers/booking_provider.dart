import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../models/booking.dart';

// ---------------------------------------------------------------------------
// Notifier — starts empty; bookings are added by the user at runtime
// ---------------------------------------------------------------------------
class BookingNotifier extends Notifier<List<Booking>> {
  @override
  List<Booking> build() => [];

  void addBooking(Booking booking) {
    state = [...state, booking];
  }

  void removeBooking(String id) {
    state = state.where((b) => b.id != id).toList();
  }

  List<Booking> bookingsForDate(DateTime date) {
    return state.where((b) => b.isOnDate(date)).toList();
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------
final bookingProvider = NotifierProvider<BookingNotifier, List<Booking>>(
  BookingNotifier.new,
);
