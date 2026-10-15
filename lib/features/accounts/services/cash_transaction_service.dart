import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/accounts/data/cash_transaction.dart';
import 'package:nizan_crm/providers/dio_provider.dart';

class CashTransactionService {
  final Dio _dio;
  CashTransactionService(this._dio);

  Future<CashTxnPage> list(CashTxnFilter f) async {
    try {
      final res = await _dio.get('/cash-transactions', queryParameters: {
        if (f.from.isNotEmpty) 'from': f.from,
        if (f.to.isNotEmpty) 'to': f.to,
        if (f.type != 'all') 'type': f.type,
        if (f.search.trim().isNotEmpty) 'search': f.search.trim(),
      });
      final data = (res.data as Map).cast<String, dynamic>();
      return CashTxnPage(
        rows: ((data['rows'] as List?) ?? const [])
            .map((e) => CashTransaction.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
        totals: CashTxnTotals.fromJson((data['totals'] as Map?)?.cast<String, dynamic>()),
      );
    } catch (e) {
      throw AppException(e, action: 'load transactions');
    }
  }

  /// Ledgers the form can book against (all but Cash / Bank).
  Future<List<TxnAccountRef>> accounts() async {
    try {
      final res = await _dio.get('/cash-transactions/accounts');
      return ((res.data as List?) ?? const [])
          .map((e) => TxnAccountRef.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
    } catch (e) {
      throw AppException(e, action: 'load accounts');
    }
  }

  Future<void> save(Map<String, dynamic> body, {String? id}) async {
    try {
      if (id == null) {
        await _dio.post('/cash-transactions', data: body);
      } else {
        await _dio.put('/cash-transactions/$id', data: body);
      }
    } catch (e) {
      throw AppException(e, action: 'save the transaction');
    }
  }

  Future<void> delete(String id) async {
    try {
      await _dio.delete('/cash-transactions/$id');
    } catch (e) {
      throw AppException(e, action: 'delete the transaction');
    }
  }
}

final cashTransactionServiceProvider =
    Provider<CashTransactionService>((ref) => CashTransactionService(ref.watch(dioProvider)));

final cashTransactionsProvider = FutureProvider.autoDispose.family<CashTxnPage, CashTxnFilter>((ref, f) async {
  return ref.watch(cashTransactionServiceProvider).list(f);
});

final cashTxnAccountsProvider = FutureProvider.autoDispose<List<TxnAccountRef>>((ref) async {
  return ref.watch(cashTransactionServiceProvider).accounts();
});
