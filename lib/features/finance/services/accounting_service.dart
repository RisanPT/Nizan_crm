import 'package:dio/dio.dart';
import 'package:nizan_crm/features/finance/data/chart_account.dart';
import 'package:nizan_crm/features/finance/data/journal_entry.dart';
import 'package:nizan_crm/features/finance/data/report_models.dart';
import 'package:nizan_crm/features/finance/data/aging_report.dart';
import 'package:nizan_crm/features/finance/data/gst_models.dart';
import 'package:nizan_crm/features/finance/data/account_ledger.dart';
import 'package:nizan_crm/features/finance/data/accounting_settings.dart';
import 'package:nizan_crm/features/finance/data/bank_recon.dart';

class AccountingService {
  final Dio _dio;
  AccountingService(this._dio);

  String _msg(DioException e, String fallback) {
    final data = e.response?.data;
    if (data is Map && data['message'] != null) return data['message'].toString();
    return '$fallback: ${e.message}';
  }

  // ── Chart of Accounts ──
  Future<List<ChartAccount>> getAccounts({String nature = 'all'}) async {
    try {
      final res = await _dio.get('/accounting/accounts',
          queryParameters: {if (nature != 'all') 'nature': nature});
      return (res.data as List)
          .map((e) => ChartAccount.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw Exception(_msg(e, 'Failed to load accounts'));
    }
  }

  Future<int> seedAccounts() async {
    try {
      final res = await _dio.post('/accounting/accounts/seed');
      return (res.data as Map)['inserted'] as int? ?? 0;
    } on DioException catch (e) {
      throw Exception(_msg(e, 'Failed to seed accounts'));
    }
  }

  Future<ChartAccount> saveAccount(Map<String, dynamic> body, {String? id}) async {
    try {
      final res = id == null
          ? await _dio.post('/accounting/accounts', data: body)
          : await _dio.put('/accounting/accounts/$id', data: body);
      return ChartAccount.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(_msg(e, 'Failed to save account'));
    }
  }

  Future<void> deleteAccount(String id) async {
    try {
      await _dio.delete('/accounting/accounts/$id');
    } on DioException catch (e) {
      throw Exception(_msg(e, 'Failed to delete account'));
    }
  }

  // ── Journal ──
  Future<List<JournalEntry>> getJournal({
    String type = 'all',
    String status = 'all',
    String? from,
    String? to,
  }) async {
    try {
      final res = await _dio.get('/accounting/journal', queryParameters: {
        if (type != 'all') 'type': type,
        if (status != 'all') 'status': status,
        'from': ?from,
        'to': ?to,
      });
      return (res.data as List)
          .map((e) => JournalEntry.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw Exception(_msg(e, 'Failed to load journal'));
    }
  }

  Future<JournalEntry> createJournal(Map<String, dynamic> body) async {
    try {
      final res = await _dio.post('/accounting/journal', data: body);
      return JournalEntry.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(_msg(e, 'Failed to post entry'));
    }
  }

  Future<void> voidJournal(String id) async {
    try {
      await _dio.delete('/accounting/journal/$id');
    } on DioException catch (e) {
      throw Exception(_msg(e, 'Failed to void entry'));
    }
  }

  /// Post existing operations (bookings, collections, expenses, payroll,
  /// returns) into the ledger. Idempotent — safe to re-run. Returns how many
  /// vouchers were posted.
  Future<int> backfill() async {
    try {
      final res = await _dio.post(
        '/accounting/backfill',
        // Bulk posting over many source docs can take a while — give it room.
        options: Options(
          sendTimeout: const Duration(minutes: 3),
          receiveTimeout: const Duration(minutes: 3),
        ),
      );
      return (res.data as Map)['totalPosted'] as int? ?? 0;
    } on DioException catch (e) {
      throw Exception(_msg(e, 'Failed to sync ledger'));
    }
  }

  // ── Reports ──
  Future<TrialBalance> getTrialBalance({String? from, String? to}) async {
    try {
      final res = await _dio.get('/accounting/trial-balance', queryParameters: {
        'from': ?from,
        'to': ?to,
      });
      return TrialBalance.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(_msg(e, 'Failed to load trial balance'));
    }
  }

  Future<PnlReport> getProfitAndLoss({String? from, String? to}) async {
    try {
      final res = await _dio.get('/accounting/profit-loss', queryParameters: {
        'from': ?from,
        'to': ?to,
      });
      return PnlReport.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(_msg(e, 'Failed to load P&L'));
    }
  }

  Future<BalanceSheetReport> getBalanceSheet({String? to}) async {
    try {
      final res = await _dio.get('/accounting/balance-sheet',
          queryParameters: {'to': ?to});
      return BalanceSheetReport.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(_msg(e, 'Failed to load balance sheet'));
    }
  }

  /// [kind] = 'receivables' | 'payables'. [asOf] (ISO date) ages balances as on
  /// that day — obligations still ahead of it count as "not yet due".
  Future<AgingReport> getAging(String kind, {String? asOf}) async {
    try {
      final res = await _dio.get(
        '/accounting/$kind',
        queryParameters: {if (asOf != null && asOf.isNotEmpty) 'asOf': asOf},
      );
      return AgingReport.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(_msg(e, 'Failed to load $kind'));
    }
  }

  /// Statement of account for one party. [kind] = 'receivables' | 'payables'.
  Future<PartyStatement> getPartyStatement(String kind, String name, {String phone = ''}) async {
    try {
      final res = await _dio.get('/accounting/party-statement', queryParameters: {
        'kind': kind,
        'name': name,
        if (phone.isNotEmpty) 'phone': phone,
      });
      return PartyStatement.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(_msg(e, 'Failed to load statement'));
    }
  }

  // ── GST ──
  Future<GstSettings> getGstSettings() async {
    try {
      final res = await _dio.get('/accounting/gst/settings');
      return GstSettings.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(_msg(e, 'Failed to load GST settings'));
    }
  }

  Future<GstSettings> updateGstSettings(GstSettings s) async {
    try {
      final res = await _dio.put('/accounting/gst/settings', data: s.toJson());
      return GstSettings.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(_msg(e, 'Failed to save GST settings'));
    }
  }

  Future<GstSummary> getGstSummary({String? from, String? to}) async {
    try {
      final res = await _dio.get('/accounting/gst/summary', queryParameters: {
        'from': ?from,
        'to': ?to,
      });
      return GstSummary.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(_msg(e, 'Failed to load GST summary'));
    }
  }

  Future<AccountingSettings> getAccountingSettings() async {
    try {
      final res = await _dio.get('/accounting/settings');
      return AccountingSettings.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(_msg(e, 'Failed to load settings'));
    }
  }

  /// Close the books through [lockDate], or pass null to reopen.
  Future<AccountingSettings> setLockDate(DateTime? lockDate) async {
    try {
      final res = await _dio.put('/accounting/settings',
          data: {'lockDate': lockDate?.toIso8601String()});
      return AccountingSettings.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(_msg(e, 'Failed to update period lock'));
    }
  }

  Future<AccountLedger> getLedger(String accountId, {String? from, String? to}) async {
    try {
      final res = await _dio.get('/accounting/ledger/$accountId', queryParameters: {
        'from': ?from,
        'to': ?to,
      });
      return AccountLedger.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(_msg(e, 'Failed to load ledger'));
    }
  }

  Future<Gstr1Report> getGstr1({String? from, String? to}) async {
    try {
      final res = await _dio.get('/accounting/gst/gstr1', queryParameters: {
        'from': ?from,
        'to': ?to,
      });
      return Gstr1Report.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(_msg(e, 'Failed to load GSTR-1'));
    }
  }

  // ── Bank reconciliation ──
  Future<List<BankAccountRef>> getBankAccounts() async {
    try {
      final res = await _dio.get('/accounting/bank/accounts');
      return (res.data as List)
          .map((e) => BankAccountRef.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw Exception(_msg(e, 'Failed to load bank accounts'));
    }
  }

  Future<ImportResult> importStatement(
    String bankAccountId,
    String batchLabel,
    List<Map<String, dynamic>> lines,
  ) async {
    try {
      final res = await _dio.post(
        '/accounting/bank/import',
        data: {'bankAccountId': bankAccountId, 'batchLabel': batchLabel, 'lines': lines},
        options: Options(
          sendTimeout: const Duration(minutes: 2),
          receiveTimeout: const Duration(minutes: 2),
        ),
      );
      return ImportResult.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(_msg(e, 'Failed to import statement'));
    }
  }

  Future<Reconciliation> getReconciliation(String bankAccountId) async {
    try {
      final res = await _dio.get('/accounting/bank/reconciliation',
          queryParameters: {'bankAccountId': bankAccountId});
      return Reconciliation.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(_msg(e, 'Failed to load reconciliation'));
    }
  }

  Future<int> autoMatch(String bankAccountId, {int dateWindowDays = 4}) async {
    try {
      final res = await _dio.post('/accounting/bank/auto-match',
          data: {'bankAccountId': bankAccountId, 'dateWindowDays': dateWindowDays});
      return (res.data as Map)['matched'] as int? ?? 0;
    } on DioException catch (e) {
      throw Exception(_msg(e, 'Failed to auto-match'));
    }
  }

  Future<void> matchManual(String statementLineId, String entryId) async {
    try {
      await _dio.post('/accounting/bank/match',
          data: {'statementLineId': statementLineId, 'entryId': entryId});
    } on DioException catch (e) {
      throw Exception(_msg(e, 'Failed to match'));
    }
  }

  Future<void> unmatch(String statementLineId) async {
    try {
      await _dio.post('/accounting/bank/unmatch',
          data: {'statementLineId': statementLineId});
    } on DioException catch (e) {
      throw Exception(_msg(e, 'Failed to unmatch'));
    }
  }

  Future<int> clearStatement(String bankAccountId) async {
    try {
      final res = await _dio.delete('/accounting/bank/statement',
          queryParameters: {'bankAccountId': bankAccountId});
      return (res.data as Map)['deleted'] as int? ?? 0;
    } on DioException catch (e) {
      throw Exception(_msg(e, 'Failed to clear statement'));
    }
  }
}
