import '../models/booking.dart';
import 'booking_print_service_stub.dart'
    if (dart.library.html) 'booking_print_service_web.dart'
    as impl;

enum BookingPrintVariant { client, artist }

Future<void> printBookingDetails(
  Booking booking, {
  required BookingPrintVariant variant,
  List<Booking> relatedArtistBookings = const [],
  String artistName = '',
}) {
  return impl.printBookingDetails(
    booking,
    variant: variant,
    relatedArtistBookings: relatedArtistBookings,
    artistName: artistName,
  );
}
