import '../models/booking.dart';
import 'booking_print_service.dart';

Future<void> printBookingDetails(
  Booking booking, {
  required BookingPrintVariant variant,
  List<Booking> relatedArtistBookings = const [],
  List<BookingDisplayEntry> relatedArtistEntries = const [],
  BookingDisplayEntry? selectedArtistEntry,
  String artistName = '',
}) async {}
