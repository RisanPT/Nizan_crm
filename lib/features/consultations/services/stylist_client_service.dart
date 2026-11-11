import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/providers/dio_provider.dart';

import '../data/stylist_client.dart';

final stylistClientServiceProvider = Provider<StylistClientService>((ref) {
  return StylistClientService(ref.watch(dioProvider));
});

/// That enquiry/booking already has a client file (HTTP 409 CLIENT_EXISTS).
class ClientExistsException implements Exception {
  ClientExistsException(this.message, this.clientId);

  final String message;
  final String clientId;

  @override
  String toString() => message;
}

/// What the My Clients list asks for. A record, so equal queries share one
/// cached provider instance.
typedef ClientQuery = ({String q, String company, String status, String sort});

/// The stylist client files API (/api/stylist-clients).
class StylistClientService {
  StylistClientService(this._dio);

  final Dio _dio;

  Object _wrap(Object e, String action) {
    if (e is DioException && e.response?.statusCode == 409) {
      final data = e.response?.data;
      if (data is Map && data['code'] == 'CLIENT_EXISTS') {
        return ClientExistsException(
          data['message'] as String? ?? 'This client already has a client file',
          (data['clientId'] ?? '').toString(),
        );
      }
    }
    return AppException(e, action: action);
  }

  // GET /api/stylist-clients?q=&company=&status=&sort=
  Future<List<StylistClient>> list(ClientQuery query) async {
    try {
      final res = await _dio.get('/stylist-clients', queryParameters: {
        if (query.q.trim().isNotEmpty) 'q': query.q.trim(),
        if (query.company.isNotEmpty) 'company': query.company,
        'status': query.status.isEmpty ? 'Active' : query.status,
        'sort': query.sort,
      });
      return (res.data as List)
          .whereType<Map<String, dynamic>>()
          .map(StylistClient.fromJson)
          .toList();
    } catch (e) {
      throw _wrap(e, 'load clients');
    }
  }

  // GET /api/stylist-clients/:id — with calls and images.
  Future<StylistClient> getById(String id) async {
    try {
      final res = await _dio.get('/stylist-clients/$id');
      return StylistClient.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw _wrap(e, 'load the client');
    }
  }

  // GET /api/stylist-clients/team-n-search?q=
  Future<List<TeamNCandidate>> searchTeamN(String q) async {
    try {
      final res = await _dio.get('/stylist-clients/team-n-search', queryParameters: {'q': q});
      return (res.data as List)
          .whereType<Map<String, dynamic>>()
          .map(TeamNCandidate.fromJson)
          .toList();
    } catch (e) {
      throw _wrap(e, 'search Team N clients');
    }
  }

  // POST /api/stylist-clients — Team N: filled in from the enquiry/booking.
  Future<StylistClient> createTeamN({
    required TeamNCandidate from,
    int requiredCalls = kDefaultRequiredCalls,
    String notes = '',
    String? stylistId,
  }) async {
    try {
      final res = await _dio.post('/stylist-clients', data: {
        'company': 'Team N',
        if (from.leadId.isNotEmpty) 'leadId': from.leadId,
        if (from.bookingId.isNotEmpty) 'bookingId': from.bookingId,
        'requiredCalls': requiredCalls,
        if (notes.trim().isNotEmpty) 'notes': notes.trim(),
        'stylistId': ?stylistId,
      });
      return StylistClient.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw _wrap(e, 'add the client');
    }
  }

  // POST /api/stylist-clients — Nizan: typed-in details.
  Future<StylistClient> createNizan(Map<String, dynamic> details, {String? stylistId}) async {
    try {
      final res = await _dio.post('/stylist-clients', data: {
        ...details,
        'company': 'Nizan',
        'stylistId': ?stylistId,
      });
      return StylistClient.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw _wrap(e, 'add the client');
    }
  }

  // PUT /api/stylist-clients/:id
  Future<StylistClient> update(String id, Map<String, dynamic> fields) async {
    try {
      final res = await _dio.put('/stylist-clients/$id', data: fields);
      return StylistClient.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw _wrap(e, 'save the client');
    }
  }

  // GET /api/stylist-clients/:id/report — the client report PDF.
  Future<Uint8List> downloadReport(String id) async {
    try {
      final res = await _dio.get<List<int>>(
        '/stylist-clients/$id/report',
        options: Options(responseType: ResponseType.bytes, receiveTimeout: const Duration(minutes: 2)),
      );
      return Uint8List.fromList(res.data ?? const []);
    } catch (e) {
      throw _wrap(e, 'make the report');
    }
  }

  // POST /api/stylist-clients/:id/refresh
  Future<StylistClient> refresh(String id) async {
    try {
      final res = await _dio.post('/stylist-clients/$id/refresh');
      return StylistClient.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw _wrap(e, 'refresh from the booking');
    }
  }
}
