import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nizan_crm/providers/dio_provider.dart';

/// Sends quotation / invoice PDFs to TeamN Chat (WhatsApp) through our backend
/// (/api/whatsapp). The TeamN Chat key stays on the server — this works the
/// same on web, Windows and mobile.
final whatsAppServiceProvider =
    Provider<WhatsAppService>((ref) => WhatsAppService(ref.watch(dioProvider)));

enum WhatsAppSendMode {
  /// "Send to WhatsApp team" — waits in the customer's chat for staff.
  handover,

  /// "Send to customer now" — delivered to the customer at once.
  send,
}

class WhatsAppSendResult {
  final bool ok;

  /// TeamN Chat's readable error ("template not approved", …) when !ok.
  final String error;

  const WhatsAppSendResult.success() : ok = true, error = '';
  const WhatsAppSendResult.failure(this.error) : ok = false;
}

class WhatsAppService {
  final Dio _dio;

  WhatsAppService(this._dio);

  /// Invoices: pass [bookingId] — the server reads the invoice number, name,
  /// phone and event date from the booking. Quotations: pass [reference],
  /// [customerName] and [phone].
  Future<WhatsAppSendResult> sendDocument({
    required WhatsAppSendMode mode,
    required String kind, // quotation | invoice
    Uint8List? pdf,
    String? html,
    required String filename,
    String? bookingId,
    String? reference,
    String? customerName,
    String? phone,
  }) async {
    final form = FormData.fromMap({
      'kind': kind,
      'bookingId': ?bookingId,
      'reference': ?reference,
      'customer_name': ?customerName,
      'phone': ?phone,
      // Print HTML → the server renders the identical PDF (headless Chrome).
      'html': ?html,
      if (pdf != null)
        'file': MultipartFile.fromBytes(
          pdf,
          filename: filename,
          contentType: DioMediaType('application', 'pdf'),
        ),
    });
    try {
      final response = await _dio.post(
        '/whatsapp/${mode == WhatsAppSendMode.send ? 'send' : 'handover'}',
        data: form,
        options: Options(
          // TeamN Chat asks for at least 60 s; the server itself waits 90 s.
          sendTimeout: const Duration(minutes: 2),
          receiveTimeout: const Duration(minutes: 2),
          // Every reply is { ok, error } — read it whatever the status code.
          validateStatus: (_) => true,
        ),
      );
      final data = response.data;
      if (data is Map && data['ok'] == true) {
        return const WhatsAppSendResult.success();
      }
      final error = data is Map
          ? (data['error'] ?? data['message'] ?? '').toString()
          : '';
      return WhatsAppSendResult.failure(error.isNotEmpty
          ? error
          : 'WhatsApp send failed (HTTP ${response.statusCode}).');
    } on DioException catch (e) {
      final timedOut = e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.receiveTimeout;
      return WhatsAppSendResult.failure(timedOut
          ? 'No answer in time. Check TeamN Chat before trying again — it may already have gone through.'
          : 'Could not reach the server. Check your connection and try again.');
    }
  }
}
