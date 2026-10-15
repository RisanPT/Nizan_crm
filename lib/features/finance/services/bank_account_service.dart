import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/finance/data/bank_account.dart';
import 'package:nizan_crm/providers/dio_provider.dart';

class BankAccountsResult {
  final List<BankAccount> accounts;

  /// Live total across active accounts (bank + cash).
  final double totalBalance;
  final double bankTotal;
  final double cashTotal;
  const BankAccountsResult({
    required this.accounts,
    required this.totalBalance,
    this.bankTotal = 0,
    this.cashTotal = 0,
  });
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
        bankTotal: (data['bankTotal'] as num?)?.toDouble() ?? 0,
        cashTotal: (data['cashTotal'] as num?)?.toDouble() ?? 0,
      );
    } catch (e) {
      throw AppException(e, action: 'load bank accounts');
    }
  }

  /// [ledgerId] links an existing Cash/Bank ledger; null creates a new one.
  Future<void> create({
    required String name,
    String kind = 'bank',
    String? ledgerId,
    String bankName = '',
    String accountNumber = '',
    required double balance,
    required DateTime asOf,
    String note = '',
  }) async {
    try {
      await _dio.post('/bank-accounts', data: {
        'name': name,
        'kind': kind,
        'ledgerId': ?ledgerId,
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

  /// Link to an existing ledger ([ledgerId]), create a new one ([create]), or
  /// unlink (neither).
  Future<void> linkLedger(String id, {String? ledgerId, bool create = false}) async {
    try {
      await _dio.put('/bank-accounts/$id/ledger', data: {
        if (create) 'create': true,
        'ledgerId': ?ledgerId,
      });
    } catch (e) {
      throw AppException(e, action: 'link the ledger');
    }
  }

  Future<List<LedgerOption>> getLedgerOptions() async {
    try {
      final res = await _dio.get('/bank-accounts/ledger-options');
      return ((res.data as List?) ?? const [])
          .map((e) => LedgerOption.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
    } catch (e) {
      throw AppException(e, action: 'load ledger accounts');
    }
  }

  Future<BankTxnResult> getTransactions(String id) async {
    try {
      final res = await _dio.get('/bank-accounts/$id/transactions');
      return BankTxnResult.fromJson((res.data as Map).cast<String, dynamic>());
    } catch (e) {
      throw AppException(e, action: 'load transactions');
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

/// Cash / Bank ledgers available for linking.
final bankLedgerOptionsProvider = FutureProvider.autoDispose<List<LedgerOption>>((ref) async {
  return ref.watch(bankAccountServiceProvider).getLedgerOptions();
});

/// Ledger movements on one account since its last manual balance.
final bankTransactionsProvider = FutureProvider.autoDispose.family<BankTxnResult, String>((ref, id) async {
  return ref.watch(bankAccountServiceProvider).getTransactions(id);
});
