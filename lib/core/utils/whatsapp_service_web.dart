import 'package:web/web.dart' as web;

import '../models/booking.dart';

Future<void> sendInvoiceMessage(Booking booking) async {
  final phone = _formatPhoneNumber(booking.phone);
  if (phone.isEmpty) return;

  final message = _buildInvoiceMessage(booking);
  final whatsappUrl =
      'https://wa.me/$phone?text=${Uri.encodeComponent(message)}';
  web.window.open(whatsappUrl, '_blank');
}

String _buildInvoiceMessage(Booking booking) {
  final balance =
      booking.totalPrice - booking.advanceAmount - booking.discountAmount;

  return '''
Hi *${booking.customerName}*,

Greetings from *Team N Makeovers*! 🌸

We are pleased to inform you that your booking *#${booking.displayBookingNumber}* for *${booking.service}* has been successfully completed.

*Summary:*
- Total Amount: INR ${booking.totalPrice.toStringAsFixed(0)}
- Advance Paid: INR ${booking.advanceAmount.toStringAsFixed(0)}
- Discount: INR ${booking.discountAmount.toStringAsFixed(0)}
- *Remaining Balance: INR ${balance.toStringAsFixed(0)}*

Thank you for choosing us! We hope you loved our service. Have a wonderful day!

_Sent via Nizan ERP_
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
