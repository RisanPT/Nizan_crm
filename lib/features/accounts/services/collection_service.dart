import 'package:dio/dio.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/accounts/data/artist_collection.dart';

class CollectionService {
  final Dio _dio;

  CollectionService(this._dio);

  Future<List<ArtistCollection>> getCollections({
    String? status,
    String? bookingId,
    String? employeeId,
    String? paymentMode,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final Map<String, dynamic> query = {};
      if (status != null) query['status'] = status;
      if (bookingId != null) query['bookingId'] = bookingId;
      if (employeeId != null) query['employeeId'] = employeeId;
      if (paymentMode != null) query['paymentMode'] = paymentMode;
      if (startDate != null) query['startDate'] = startDate.toIso8601String();
      if (endDate != null) query['endDate'] = endDate.toIso8601String();

      final response = await _dio.get(
        '/collections',
        queryParameters: query.isNotEmpty ? query : null,
      );
      final data = response.data as List;
      return data
          .map((item) => ArtistCollection.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw AppException(e, action: 'load collections');
    }
  }

  /// Unified payments-received (booking advances + logged collections) over a
  /// date range, for reconciliation/export.
  Future<PaymentsReceivedResult> getPaymentsReceived({
    DateTime? from,
    DateTime? to,
    String? status,
  }) async {
    try {
      final q = <String, dynamic>{};
      if (from != null) q['from'] = from.toIso8601String();
      if (to != null) q['to'] = to.toIso8601String();
      if (status != null && status.isNotEmpty) q['status'] = status;
      final res = await _dio.get('/collections/payments-received',
          queryParameters: q.isEmpty ? null : q);
      final d = res.data as Map<String, dynamic>;
      return PaymentsReceivedResult(
        rows: ((d['rows'] as List?) ?? const [])
            .map((e) => PaymentReceivedRow.fromJson(e as Map<String, dynamic>))
            .toList(),
        total: (d['total'] as num?)?.toDouble() ?? 0,
        collectionsTotal: (d['collectionsTotal'] as num?)?.toDouble() ?? 0,
        advancesTotal: (d['advancesTotal'] as num?)?.toDouble() ?? 0,
      );
    } catch (e) {
      throw AppException(e, action: 'load payments received');
    }
  }

  Future<ArtistCollection> createCollection({
    String? bookingId,
    String? trialId,
    required String employeeId,
    required double amount,
    required DateTime date,
    required String paymentMode,
    String notes = '',
    String? attachmentUrl,
  }) async {
    try {
      final payload = {
        'bookingId': ?bookingId,
        'trialId': ?trialId,
        'employeeId': employeeId,
        'amount': amount,
        'date': date.toIso8601String(),
        'paymentMode': paymentMode,
        'notes': notes,
        'attachmentUrl': attachmentUrl,
      };
      final response = await _dio.post('/collections', data: payload);
      return ArtistCollection.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      throw AppException(e, action: 'create collection');
    }
  }

  /// Edits an existing collection. The backend rejects this for an artist once
  /// Accounts has verified or rejected the entry.
  Future<ArtistCollection> updateCollection({
    required String id,
    double? amount,
    DateTime? date,
    String? paymentMode,
    String? notes,
    String? attachmentUrl,
  }) async {
    try {
      final response = await _dio.put('/collections/$id', data: {
        'amount': ?amount,
        'date': ?date?.toIso8601String(),
        'paymentMode': ?paymentMode,
        'notes': ?notes,
        'attachmentUrl': ?attachmentUrl,
      });
      return ArtistCollection.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      throw AppException(e, action: 'update collection');
    }
  }

  Future<ArtistCollection> verifyCollection({
    required String id,
    required String status, // 'verified' | 'rejected'
    required String verifiedBy,
  }) async {
    try {
      final response = await _dio.put(
        '/collections/$id/verify',
        data: {'status': status, 'verifiedBy': verifiedBy},
      );
      return ArtistCollection.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      throw AppException(e, action: 'verify collection');
    }
  }

  Future<void> deleteCollection(String id) async {
    try {
      await _dio.delete('/collections/$id');
    } catch (e) {
      throw AppException(e, action: 'delete collection');
    }
  }
}

class PaymentReceivedRow {
  final DateTime date;
  final String customer;
  final String ref;
  final double amount;
  final String mode;
  final String type; // advance | collection
  final String status;

  const PaymentReceivedRow({
    required this.date,
    required this.customer,
    required this.ref,
    required this.amount,
    required this.mode,
    required this.type,
    required this.status,
  });

  factory PaymentReceivedRow.fromJson(Map<String, dynamic> j) => PaymentReceivedRow(
        date: DateTime.tryParse((j['date'] ?? '').toString()) ?? DateTime.now(),
        customer: (j['customer'] ?? '').toString(),
        ref: (j['ref'] ?? '').toString(),
        amount: (j['amount'] as num?)?.toDouble() ?? 0,
        mode: (j['mode'] ?? '').toString(),
        type: (j['type'] ?? '').toString(),
        status: (j['status'] ?? '').toString(),
      );
}

class PaymentsReceivedResult {
  final List<PaymentReceivedRow> rows;
  final double total;
  final double collectionsTotal;
  final double advancesTotal;
  const PaymentsReceivedResult({
    required this.rows,
    required this.total,
    required this.collectionsTotal,
    required this.advancesTotal,
  });
}
