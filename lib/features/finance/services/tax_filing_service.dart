import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/finance/data/tax_filing.dart';
import 'package:nizan_crm/features/finance/services/month_end_service.dart' show Period;
import 'package:nizan_crm/providers/dio_provider.dart';

class TaxFilingService {
  final Dio _dio;
  TaxFilingService(this._dio);

  Future<TaxFilingBoard> getBoard(int month, int year) async {
    try {
      final res = await _dio.get('/tax-filings',
          queryParameters: {'month': month, 'year': year});
      return TaxFilingBoard.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw AppException(e, action: 'load tax filings');
    }
  }

  /// Record a filing as filed (or reset to pending).
  Future<void> save({
    required String type,
    required int periodMonth,
    required int periodYear,
    String status = 'filed',
    DateTime? filedDate,
    String arn = '',
    double amount = 0,
    String notes = '',
  }) async {
    try {
      await _dio.put('/tax-filings', data: {
        'type': type,
        'periodMonth': periodMonth,
        'periodYear': periodYear,
        'status': status,
        'filedDate': filedDate?.toIso8601String(),
        'arn': arn,
        'amount': amount,
        'notes': notes,
      });
    } catch (e) {
      throw AppException(e, action: 'save the filing');
    }
  }
}

final taxFilingServiceProvider =
    Provider<TaxFilingService>((ref) => TaxFilingService(ref.watch(dioProvider)));

final taxFilingBoardProvider =
    FutureProvider.family<TaxFilingBoard, Period>((ref, p) async {
  return ref.watch(taxFilingServiceProvider).getBoard(p.month, p.year);
});
