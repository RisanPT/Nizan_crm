import 'dart:io';
import 'dart:ui';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:nizan_crm/features/bookings/data/booking.dart';
import 'booking_pdf.dart';
import 'booking_print_service.dart';

Future<void> printBookingDetails(
  Booking booking, {
  required BookingPrintVariant variant,
  List<Booking> relatedArtistBookings = const [],
  List<BookingDisplayEntry> relatedArtistEntries = const [],
  BookingDisplayEntry? selectedArtistEntry,
  String artistName = '',
}) async {
  // Build the PDF (shared with web / WhatsApp), save locally, native share.
  final bytes = await buildBookingPdfBytes(
    booking,
    variant: variant,
    relatedArtistBookings: relatedArtistBookings,
    relatedArtistEntries: relatedArtistEntries,
    selectedArtistEntry: selectedArtistEntry,
    artistName: artistName,
  );
  final tempDir = await getTemporaryDirectory();
  final fileName = bookingPdfFileName(booking, variant);
  final file = File('${tempDir.path}/$fileName');
  await file.writeAsBytes(bytes);

  await Share.shareXFiles(
    [XFile(file.path)],
    subject: 'Booking Report - ${booking.customerName}',
    text: 'Please find attached the Booking PDF for ${booking.customerName}.',
    sharePositionOrigin: const Rect.fromLTWH(0, 0, 300, 300),
  );
}

Future<void> printMultipleBookingDetails(
  List<Booking> selectedBookings, {
  required BookingPrintVariant variant,
}) async {
  if (selectedBookings.isEmpty) return;
  // For now, we reuse printBookingDetails by just printing the first one,
  // or you can implement the aggregated logic here similar to the single print.
  // Full implementation of data aggregation goes here as planned.
  await printBookingDetails(selectedBookings.first, variant: variant);
}

// Not HTML-based here — see booking_print_service.dart.
String? bookingPrintHtml(Booking booking, {required BookingPrintVariant variant}) => null;
