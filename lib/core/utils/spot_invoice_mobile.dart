import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:nizan_crm/core/models/spot_invoice.dart';
import 'spot_invoice_pdf.dart';

Future<void> printSpotInvoice(SpotInvoiceData data) async {
  final bytes = await buildSpotQuotationPdfBytes(data);
  final tempDir = await getTemporaryDirectory();
  final file = File('${tempDir.path}/${spotQuotationFileName(data)}');
  await file.writeAsBytes(bytes);
  await Share.shareXFiles([XFile(file.path)],
      subject: 'Quotation ${data.invoiceNo}');
}
