import '../models/booking.dart';
import 'booking_print_service_stub.dart'
    if (dart.library.io) 'booking_print_service_mobile.dart'
    if (dart.library.html) 'booking_print_service_web.dart'
    as impl;

enum BookingPrintVariant { clientInvoice, clientConfirmation, clientAdvanceReceipt, artist, trialInvoice }

Future<void> printBookingDetails(
  Booking booking, {
  required BookingPrintVariant variant,
  List<Booking> relatedArtistBookings = const [],
  List<BookingDisplayEntry> relatedArtistEntries = const [],
  BookingDisplayEntry? selectedArtistEntry,
  String artistName = '',
}) {
  return impl.printBookingDetails(
    booking,
    variant: variant,
    relatedArtistBookings: relatedArtistBookings,
    relatedArtistEntries: relatedArtistEntries,
    selectedArtistEntry: selectedArtistEntry,
    artistName: artistName,
  );
}
