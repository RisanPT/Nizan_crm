import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/providers/dio_provider.dart';

import '../data/consultation.dart';
import '../data/consultation_summary.dart';

/// An image picked on the device, ready to upload.
class PickedImage {
  const PickedImage({required this.name, required this.bytes, required this.mime});

  final String name;
  final Uint8List bytes;
  final String mime;

  /// The real type from the file's first bytes (JPEG, PNG or WebP — the only
  /// ones the server accepts), or null for anything else.
  static String? sniffMime(Uint8List b) {
    if (b.length < 12) return null;
    if (b[0] == 0xFF && b[1] == 0xD8 && b[2] == 0xFF) return 'image/jpeg';
    if (b[0] == 0x89 && b[1] == 0x50 && b[2] == 0x4E && b[3] == 0x47) return 'image/png';
    if (String.fromCharCodes(b.sublist(0, 4)) == 'RIFF' &&
        String.fromCharCodes(b.sublist(8, 12)) == 'WEBP') {
      return 'image/webp';
    }
    return null;
  }
}

final consultationServiceProvider = Provider<ConsultationService>((ref) {
  return ConsultationService(ref.watch(dioProvider));
});

/// The stylist already has a consultation in that slot (HTTP 409
/// SCHEDULE_CONFLICT). Carries the clashing bookings so the UI can list them
/// and, for a stylist lead, offer to book over them.
class ScheduleConflictException implements Exception {
  ScheduleConflictException(this.message, this.conflicts);

  final String message;
  final List<ConsultationConflict> conflicts;

  @override
  String toString() => message;
}

class ConsultationService {
  ConsultationService(this._dio);

  final Dio _dio;

  Object _wrap(Object e, String action) {
    if (e is DioException && e.response?.statusCode == 409) {
      final data = e.response?.data;
      if (data is Map && data['code'] == 'SCHEDULE_CONFLICT') {
        return ScheduleConflictException(
          data['message'] as String? ?? 'That time is already booked',
          ((data['conflicts'] as List?) ?? const [])
              .whereType<Map<String, dynamic>>()
              .map(ConsultationConflict.fromJson)
              .toList(),
        );
      }
    }
    return AppException(e, action: action);
  }

  static String _iso(DateTime d) => d.toUtc().toIso8601String();

  static String day(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  // GET /api/consultations?from=&to=&status=&stylistId=&leadId=
  Future<List<Consultation>> list({
    String? from,
    String? to,
    String? status,
    String? stylistId,
    String? leadId,
  }) async {
    try {
      final res = await _dio.get('/consultations', queryParameters: {
        if (from != null && from.isNotEmpty) 'from': from,
        if (to != null && to.isNotEmpty) 'to': to,
        if (status != null && status.isNotEmpty) 'status': status,
        if (stylistId != null && stylistId.isNotEmpty) 'stylistId': stylistId,
        if (leadId != null && leadId.isNotEmpty) 'leadId': leadId,
      });
      return (res.data as List)
          .whereType<Map<String, dynamic>>()
          .map(Consultation.fromJson)
          .toList();
    } catch (e) {
      throw _wrap(e, 'load consultations');
    }
  }

  // GET /api/consultations/summary?from=&to=&stylistId=
  Future<ConsultationSummary> summary({String? from, String? to, String? stylistId}) async {
    try {
      final res = await _dio.get('/consultations/summary', queryParameters: {
        if (from != null && from.isNotEmpty) 'from': from,
        if (to != null && to.isNotEmpty) 'to': to,
        if (stylistId != null && stylistId.isNotEmpty) 'stylistId': stylistId,
      });
      return ConsultationSummary.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw _wrap(e, 'load the dashboard');
    }
  }

  // GET /api/consultations/:id
  Future<Consultation> getById(String id) async {
    try {
      final res = await _dio.get('/consultations/$id');
      return Consultation.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw _wrap(e, 'load the consultation');
    }
  }

  // GET /api/consultations/lead/:leadId
  Future<LeadConsultations> forLead(String leadId) async {
    try {
      final res = await _dio.get('/consultations/lead/$leadId');
      return LeadConsultations.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw _wrap(e, 'load the client\'s consultations');
    }
  }

  // GET /api/consultations/stylists
  Future<List<ConsultationStylist>> stylists() async {
    try {
      final res = await _dio.get('/consultations/stylists');
      return (res.data as List)
          .whereType<Map<String, dynamic>>()
          .map(ConsultationStylist.fromJson)
          .toList();
    } catch (e) {
      throw _wrap(e, 'load stylists');
    }
  }

  // GET /api/consultations/leads/search?q=
  Future<List<ConsultationLead>> searchLeads(String q) async {
    try {
      final res =
          await _dio.get('/consultations/leads/search', queryParameters: {'q': q});
      return (res.data as List).map(ConsultationLead.fromJson).toList();
    } catch (e) {
      throw _wrap(e, 'search clients');
    }
  }

  // POST /api/consultations — for a client file ([clientId]), or for a Team N
  // enquiry ([leadId]; the server finds or makes its client file).
  Future<Consultation> create({
    String? clientId,
    String? leadId,
    required DateTime scheduledAt,
    required int durationMins,
    String? stylistId,
    String mode = 'Video',
    String meetingLink = '',
    String location = '',
    bool force = false,
  }) async {
    try {
      final res = await _dio.post('/consultations', data: {
        if (clientId != null && clientId.isNotEmpty) 'clientId': clientId else 'leadId': leadId,
        'scheduledAt': _iso(scheduledAt),
        'durationMins': durationMins,
        'stylistId': ?stylistId,
        'mode': mode,
        'meetingLink': meetingLink,
        'location': location,
        if (force) 'force': true,
      });
      return Consultation.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw _wrap(e, 'schedule the consultation');
    }
  }

  // PUT /api/consultations/:id — meeting details and notes only.
  Future<Consultation> update(String id, Map<String, dynamic> fields) async {
    try {
      final res = await _dio.put('/consultations/$id', data: fields);
      return Consultation.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw _wrap(e, 'save the consultation');
    }
  }

  // PATCH /api/consultations/:id/reschedule
  Future<Consultation> reschedule(
    String id, {
    required DateTime scheduledAt,
    required int durationMins,
    String? stylistId,
    String reason = '',
    bool force = false,
  }) async {
    try {
      final res = await _dio.patch('/consultations/$id/reschedule', data: {
        'scheduledAt': _iso(scheduledAt),
        'durationMins': durationMins,
        'stylistId': ?stylistId,
        'reason': reason,
        if (force) 'force': true,
      });
      return Consultation.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw _wrap(e, 'reschedule the consultation');
    }
  }

  Future<Consultation> cancel(String id, {String reason = ''}) =>
      _transition(id, 'cancel', {'reason': reason}, 'cancel the consultation');

  Future<Consultation> markNoShow(String id) =>
      _transition(id, 'no-show', {}, 'update the consultation');

  /// Marks the call completed and saves the after-call [details] (keys from
  /// [kAfterCallFields]) in the same request.
  Future<Consultation> complete(String id, {Map<String, String> details = const {}}) =>
      _transition(id, 'complete', details, 'complete the consultation');

  // POST /api/consultations/:id/images — multipart field `images`.
  Future<Consultation> addImages(String id, List<PickedImage> images) async {
    try {
      final form = FormData();
      for (final img in images) {
        form.files.add(MapEntry(
          'images',
          MultipartFile.fromBytes(img.bytes,
              filename: img.name, contentType: DioMediaType.parse(img.mime)),
        ));
      }
      final res = await _dio.post('/consultations/$id/images', data: form);
      return Consultation.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw _wrap(e, 'upload the images');
    }
  }

  // PATCH /api/consultations/:id/images/:imageId
  Future<Consultation> updateImageCaption(String id, String imageId, String caption) async {
    try {
      final res = await _dio.patch('/consultations/$id/images/$imageId', data: {'caption': caption});
      return Consultation.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw _wrap(e, 'save the caption');
    }
  }

  // DELETE /api/consultations/:id/images/:imageId
  Future<Consultation> deleteImage(String id, String imageId) async {
    try {
      final res = await _dio.delete('/consultations/$id/images/$imageId');
      return Consultation.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw _wrap(e, 'remove the image');
    }
  }

  Future<Consultation> markInviteSent(String id) =>
      _transition(id, 'invite-sent', {'channel': 'WhatsApp'}, 'record the invite');

  Future<Consultation> _transition(
      String id, String path, Map<String, dynamic> body, String action) async {
    try {
      final res = await _dio.patch('/consultations/$id/$path', data: body);
      return Consultation.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw _wrap(e, action);
    }
  }
}
