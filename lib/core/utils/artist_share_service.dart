import '../models/booking.dart';
import 'artist_share_service_stub.dart'
    if (dart.library.html) 'artist_share_service_web.dart' as impl;

Future<void> shareArtistOnWhatsApp({
  required String phoneNumber,
  required String artistName,
  required String bookingNumber,
  required List<BookingDisplayEntry> entries,
}) {
  return impl.shareArtistOnWhatsApp(
    phoneNumber: phoneNumber,
    artistName: artistName,
    bookingNumber: bookingNumber,
    entries: entries,
  );
}
