import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/finance/data/bank_account.dart';
import 'package:nizan_crm/providers/dio_provider.dart';

class BankAccountsResult {
  final List<BankAccount> accounts;
  final double totalBalance;
  const BankAccountsResult({required this.accounts, required this.totalBalance});
}

class BankAccountService {
  final Dio _dio;
  BankAccountService(this._dio);

  Future<BankAccountsResult> getAccounts() async {
    try {
      final res = await _dio.get('/bank-accounts');
      final data = (res.data as Map).cast<String, dynamic>();
      return BankAccountsResult(
        accounts: ((data['accounts'] as List?) ?? const [])
            .map((e) => BankAccount.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
        totalBalance: (data['totalBalance'] as num?)?.toDouble() ?? 0,
      );
    } catch (e) {
      throw AppException(e, action: 'load bank accounts');
    }
  }

  Future<void> create({
    required String name,
    String bankName = '',
    String accountNumber = '',
    required double balance,
    required DateTime asOf,
    String note = '',
  }) async {
    try {
      await _dio.post('/bank-accounts', data: {
        'name': name,
        'bankName': bankName,
        'accountNumber': accountNumber,
        'balance': balance,
        'asOf': asOf.toIso8601String(),
        'note': note,
      });
    } catch (e) {
      throw AppException(e, action: 'add the account');
    }
  }

  Future<void> updateDetails(String id, {String? name, String? bankName, String? accountNumber, String? note, bool? active}) async {
    try {
      await _dio.put('/bank-accounts/$id', data: {
        'name': ?name,
        'bankName': ?bankName,
        'accountNumber': ?accountNumber,
        'note': ?note,
        'active': ?active,
      });
    } catch (e) {
      throw AppException(e, action: 'update the account');
    }
  }

  /// Record a new manual balance (appends to history).
  Future<void> recordBalance(String id, {required double balance, required DateTime asOf, String note = ''}) async {
    try {
      await _dio.post('/bank-accounts/$id/balance', data: {
        'balance': balance,
        'asOf': asOf.toIso8601String(),
        'note': note,
      });
    } catch (e) {
      throw AppException(e, action: 'update the balance');
    }
  }

  Future<void> delete(String id) async {
    try {
      await _dio.delete('/bank-accounts/$id');
    } catch (e) {
      throw AppException(e, action: 'delete the account');
    }
  }
}

final bankAccountServiceProvider =
    Provider<BankAccountService>((ref) => BankAccountService(ref.watch(dioProvider)));

final bankAccountsProvider = FutureProvider<BankAccountsResult>((ref) async {
  return ref.watch(bankAccountServiceProvider).getAccounts();
});
