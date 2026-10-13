import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/providers/dio_provider.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/hr_reimbursement/data/claim_models.dart';

class ReimbursementService {
  final Dio _dio;
  ReimbursementService(this._dio);

  List<ExpenseClaim> _list(dynamic data) {
    final raw = data is List ? data : const [];
    return raw.map((e) => ExpenseClaim.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<ExpenseClaim>> getMine() async {
    try {
      final res = await _dio.get('/reimbursements/mine');
      return _list(res.data);
    } catch (e) {
      throw AppException(e, action: 'load my claims');
    }
  }

  Future<List<ExpenseClaim>> getRequests({String? status}) async {
    try {
      final res = await _dio.get('/reimbursements/requests', queryParameters: {'status': ?status});
      return _list(res.data);
    } catch (e) {
      throw AppException(e, action: 'load claims');
    }
  }

  Future<void> submit({
    required String title,
    required double amount,
    required String category,
    DateTime? date,
    String description = '',
    String receiptUrl = '',
  }) async {
    try {
      await _dio.post('/reimbursements', data: {
        'title': title,
        'amount': amount,
        'category': category,
        if (date != null) 'date': date.toIso8601String(),
        'description': description,
        'receiptUrl': receiptUrl,
      });
    } catch (e) {
      throw AppException(e, action: 'submit claim');
    }
  }

  Future<void> cancel(String id) async {
    try {
      await _dio.post('/reimbursements/$id/cancel');
    } catch (e) {
      throw AppException(e, action: 'cancel claim');
    }
  }

  Future<void> pay(String id, {String paymentMethod = 'bank'}) async {
    try {
      await _dio.post('/reimbursements/$id/pay', data: {'paymentMethod': paymentMethod});
    } catch (e) {
      throw AppException(e, action: 'mark claim paid');
    }
  }
}

final reimbursementServiceProvider =
    Provider<ReimbursementService>((ref) => ReimbursementService(ref.watch(dioProvider)));

final myClaimsProvider = FutureProvider<List<ExpenseClaim>>((ref) => ref.watch(reimbursementServiceProvider).getMine());

final claimRequestsProvider =
    FutureProvider<List<ExpenseClaim>>((ref) => ref.watch(reimbursementServiceProvider).getRequests());
