import 'package:url_launcher/url_launcher.dart';
import '../models/booking.dart';

class WhatsAppService {
  static Future<void> sendInvoiceMessage(Booking booking) async {
    final phone = _formatPhoneNumber(booking.phone);
    if (phone.isEmpty) return;

    final balance = booking.totalPrice - booking.advanceAmount - booking.discountAmount;
    
    final message = '''
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

    final whatsappUrl = Uri.parse(
      'https://wa.me/$phone?text=${Uri.encodeComponent(message)}',
    );

    if (await canLaunchUrl(whatsappUrl)) {
      await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
    } else {
      throw 'Could not launch WhatsApp for $phone';
    }
  }

  static String _formatPhoneNumber(String phone) {
    // Remove all non-digit characters
    String cleaned = phone.replaceAll(RegExp(r'\D'), '');
    
    // If it starts with 0, remove it
    if (cleaned.startsWith('0')) {
      cleaned = cleaned.substring(1);
    }
    
    // Add default country code for India (+91) if it looks like a 10-digit number
    if (cleaned.length == 10) {
      cleaned = '91$cleaned';
    }
    
    return cleaned;
  }
}
