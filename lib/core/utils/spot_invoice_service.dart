import 'package:nizan_crm/core/models/spot_invoice.dart';

import 'spot_invoice_stub.dart'
    if (dart.library.io) 'spot_invoice_mobile.dart'
    if (dart.library.html) 'spot_invoice_web.dart' as impl;

/// Generates a printable spot quotation (no GST). Web → browser print dialog;
/// mobile → PDF share sheet (share to WhatsApp, email, etc.).
Future<void> printSpotInvoice(SpotInvoiceData data) =>
    impl.printSpotInvoice(data);
