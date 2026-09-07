import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'package:nizan_crm/features/accounts/data/artist_payout.dart';
import 'package:nizan_crm/providers/dio_provider.dart';

class ArtistPayoutService {
  final Dio _dio;
  ArtistPayoutService(this._dio);

  Future<List<ArtistPayout>> getPayouts({
    String? status,
    String? employeeId,
    String? bookingId,
    int? month,
    int? year,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final q = <String, dynamic>{};
      if (status != null && status.isNotEmpty && status != 'all') {
        q['status'] = status;
      }
      if (employeeId != null && employeeId.isNotEmpty) q['employeeId'] = employeeId;
      if (bookingId != null && bookingId.isNotEmpty) q['bookingId'] = bookingId;
      if (month != null && year != null) {
        q['month'] = month;
        q['year'] = year;
      } else {
        if (startDate != null) q['startDate'] = startDate.toIso8601String();
        if (endDate != null) q['endDate'] = endDate.toIso8601String();
      }
      final res = await _dio.get('/artist-payouts',
          queryParameters: q.isEmpty ? null : q);
      return (res.data as List)
          .map((e) => ArtistPayout.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw Exception(_msg(e, 'Failed to load payouts'));
    }
  }

  Future<ArtistPayout> createPayout({
    required String employeeId,
    String? bookingId,
    required double amount,
    required DateTime date,
    String paymentMode = 'bank_transfer',
    String notes = '',
  }) async {
    try {
      final res = await _dio.post('/artist-payouts', data: {
        'employeeId': employeeId,
        'bookingId': ?bookingId,
        'amount': amount,
        'date': date.toIso8601String(),
        'paymentMode': paymentMode,
        'notes': notes,
      });
      return ArtistPayout.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(_msg(e, 'Failed to create payout'));
    }
  }

  Future<ArtistPayout> updatePayout({
    required String id,
    double? amount,
    DateTime? date,
    String? paymentMode,
    String? notes,
    String? bookingId,
  }) async {
    try {
      final res = await _dio.put('/artist-payouts/$id', data: {
        'amount': ?amount,
        'date': ?date?.toIso8601String(),
        'paymentMode': ?paymentMode,
        'notes': ?notes,
        'bookingId': ?bookingId,
      });
      return ArtistPayout.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(_msg(e, 'Failed to update payout'));
    }
  }

  Future<ArtistPayout> approvePayout(String id) async {
    try {
      final res = await _dio.put('/artist-payouts/$id/approve');
      return ArtistPayout.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(_msg(e, 'Failed to approve payout'));
    }
  }

  Future<ArtistPayout> payPayout(String id, {String? paymentMode}) async {
    try {
      final res = await _dio.put('/artist-payouts/$id/pay',
          data: {'paymentMode': ?paymentMode});
      return ArtistPayout.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(_msg(e, 'Failed to pay payout'));
    }
  }

  Future<void> deletePayout(String id) async {
    try {
      await _dio.delete('/artist-payouts/$id');
    } on DioException catch (e) {
      throw Exception(_msg(e, 'Failed to delete payout'));
    }
  }

  String _msg(DioException e, String fallback) {
    final data = e.response?.data;
    if (data is Map && data['message'] != null) return data['message'].toString();
    return e.message ?? fallback;
  }
}

final artistPayoutServiceProvider =
    Provider<ArtistPayoutService>((ref) => ArtistPayoutService(ref.watch(dioProvider)));

class PayoutFilter {
  final String status; // all | pending | approved | paid
  final int? month;
  final int? year;
  const PayoutFilter({this.status = 'all', this.month, this.year});

  PayoutFilter copyWith({String? status, int? month, int? year, bool clearMonth = false}) =>
      PayoutFilter(
        status: status ?? this.status,
        month: clearMonth ? null : (month ?? this.month),
        year: clearMonth ? null : (year ?? this.year),
      );

  @override
  bool operator ==(Object other) =>
      other is PayoutFilter &&
      other.status == status &&
      other.month == month &&
      other.year == year;
  @override
  int get hashCode => Object.hash(status, month, year);
}

final payoutFilterProvider =
    StateProvider<PayoutFilter>((ref) => const PayoutFilter());

final artistPayoutsProvider = FutureProvider<List<ArtistPayout>>((ref) async {
  final f = ref.watch(payoutFilterProvider);
  return ref.watch(artistPayoutServiceProvider).getPayouts(
        status: f.status,
        month: f.month,
        year: f.year,
      );
});

/// All payouts for one artist — used by the Artist profile to show total paid.
final artistPayoutsForEmployeeProvider =
    FutureProvider.family<List<ArtistPayout>, String>((ref, employeeId) async {
  return ref.watch(artistPayoutServiceProvider).getPayouts(employeeId: employeeId);
});
