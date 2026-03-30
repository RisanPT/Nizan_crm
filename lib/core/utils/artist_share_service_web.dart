import 'package:web/web.dart' as web;

import '../models/booking.dart';

Future<void> shareArtistOnWhatsApp({
  required String phoneNumber,
  required String artistName,
  required String bookingNumber,
  required List<BookingDisplayEntry> entries,
}) async {
  final normalizedPhone = _normalizePhone(phoneNumber);
  if (normalizedPhone.isEmpty) return;

  final lines = <String>[
    'Nizan Makeovers artist work sheet',
    if (artistName.trim().isNotEmpty) 'Artist: ${artistName.trim()}',
    'Booking Ref: #$bookingNumber',
    '',
    'Today\'s assigned works:',
    ...entries.asMap().entries.map((item) {
      final index = item.key + 1;
      final entry = item.value;
      final slot = entry.eventSlot.trim().isEmpty
          ? 'Open Slot'
          : entry.eventSlot.trim();
      return '$index. ${entry.service} | $slot | ${_formatTime(entry.serviceStart)} - ${_formatTime(entry.serviceEnd)} | ${entry.booking.customerName}';
    }),
    '',
    'Artist PDF has been opened from CRM for print/download.',
  ];

  final url =
      'https://wa.me/$normalizedPhone?text=${Uri.encodeComponent(lines.join('\n'))}';
  web.window.open(url, '_blank');
}

String _normalizePhone(String input) {
  final digitsOnly = input.replaceAll(RegExp(r'[^0-9]'), '');
  if (digitsOnly.isEmpty) return '';
  if (digitsOnly.length == 10) {
    return '91$digitsOnly';
  }
  return digitsOnly;
}

String _formatTime(DateTime value) {
  final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
  final minute = value.minute.toString().padLeft(2, '0');
  final meridiem = value.hour < 12 ? 'AM' : 'PM';
  return '$hour:$minute $meridiem';
}
