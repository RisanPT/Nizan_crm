import 'package:nizan_crm/features/bookings/data/booking.dart';
import 'whatsapp_service_native.dart'
    if (dart.library.html) 'whatsapp_service_web.dart'
    as impl;

class WhatsAppService {
  static Future<void> sendInvoiceMessage(Booking booking) {
    return impl.sendInvoiceMessage(booking);
  }

  /// Opens WhatsApp to the client with a short review-request message that
  /// contains the public review-form [reviewUrl].
  static Future<void> sendReviewRequest(Booking booking, String reviewUrl) {
    return impl.sendReviewRequest(booking, reviewUrl);
  }

  /// Opens WhatsApp to [phone] with a pre-filled [message]. Generic outreach —
  /// used by marketing client re-engagement.
  static Future<void> openChat(String phone, String message) {
    return impl.openChat(phone, message);
  }
}
