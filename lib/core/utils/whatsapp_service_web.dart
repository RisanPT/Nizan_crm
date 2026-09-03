import 'package:web/web.dart' as web;

import 'package:nizan_crm/features/bookings/data/booking.dart';

Future<void> sendInvoiceMessage(Booking booking) async {
  final phone = _formatPhoneNumber(booking.phone);
  if (phone.isEmpty) return;

  final message = _buildInvoiceMessage(booking);
  final whatsappUrl =
      'https://wa.me/$phone?text=${Uri.encodeComponent(message)}';
  web.window.open(whatsappUrl, '_blank');
}

Future<void> sendReviewRequest(Booking booking, String reviewUrl) async {
  final phone = _formatPhoneNumber(booking.phone);
  if (phone.isEmpty) throw 'This booking has no valid phone number.';
  if (reviewUrl.isEmpty) throw 'No review link available.';

  final message = _buildReviewMessage(booking, reviewUrl);
  final whatsappUrl =
      'https://wa.me/$phone?text=${Uri.encodeComponent(message)}';
  web.window.open(whatsappUrl, '_blank');
}

String _buildReviewMessage(Booking booking, String reviewUrl) {
  return '''
Hi *${booking.customerName}*,

Thank you for choosing *Team N Makeovers*! 🌸

We would love to hear about your experience. Please take 2 minutes to share your review:
$reviewUrl

Your feedback means the world to us 💖
''';
}

String _buildInvoiceMessage(Booking booking) {
  final balance =
      booking.totalPrice - booking.advanceAmount - booking.discountAmount;

  final reviewCta = booking.reviewUrl.isNotEmpty
      ? '\n\n⭐ *We would love your feedback!* Please take a moment to review your experience:\n${booking.reviewUrl}\n'
      : '';

  return '''
Hi *${booking.customerName}*,

Greetings from *Team N ERP*! 🌸

We are pleased to inform you that your booking *#${booking.displayBookingNumber}* for *${booking.service}* has been successfully completed.

*Summary:*
- Total Amount: INR ${booking.totalPrice.toStringAsFixed(0)}
- Advance Paid: INR ${booking.advanceAmount.toStringAsFixed(0)}
- Discount: INR ${booking.discountAmount.toStringAsFixed(0)}
- *Remaining Balance: INR ${balance.toStringAsFixed(0)}*

Thank you for choosing us! We hope you loved our service. Have a wonderful day!$reviewCta
_Sent via Team N ERP_
''';
}

String _formatPhoneNumber(String phone) {
  var cleaned = phone.replaceAll(RegExp(r'\D'), '');
  if (cleaned.startsWith('0')) {
    cleaned = cleaned.substring(1);
  }
  if (cleaned.length == 10) {
    cleaned = '91$cleaned';
  }
  return cleaned;
}
