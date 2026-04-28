import '../models/booking.dart';
import 'whatsapp_service_native.dart'
    if (dart.library.html) 'whatsapp_service_web.dart'
    as impl;

class WhatsAppService {
  static Future<void> sendInvoiceMessage(Booking booking) {
    return impl.sendInvoiceMessage(booking);
  }
}
