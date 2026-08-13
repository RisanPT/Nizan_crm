import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nizan_crm/providers/dio_provider.dart';
import 'package:nizan_crm/features/finance/data/chart_account.dart';
import 'package:nizan_crm/features/finance/data/journal_entry.dart';
import 'package:nizan_crm/features/finance/data/report_models.dart';
import 'package:nizan_crm/features/finance/data/aging_report.dart';
import 'package:nizan_crm/features/finance/data/gst_models.dart';
import 'package:nizan_crm/features/finance/data/account_ledger.dart';
import 'package:nizan_crm/features/finance/data/accounting_settings.dart';
import 'package:nizan_crm/features/finance/data/bank_recon.dart';
import 'package:nizan_crm/features/finance/services/accounting_service.dart';

final accountingServiceProvider = Provider<AccountingService>((ref) {
  return AccountingService(ref.watch(dioProvider));
});

/// Chart of accounts, optionally filtered by nature ('all' | asset | ...).
final chartAccountsProvider =
    FutureProvider.family<List<ChartAccount>, String>((ref, nature) async {
  return ref.watch(accountingServiceProvider).getAccounts(nature: nature);
});

/// Journal vouchers filtered by type/status and an optional date window
/// (from/to ISO strings; '' = open-ended). Status 'all' includes void.
final journalEntriesProvider = FutureProvider.family<List<JournalEntry>,
    ({String type, String status, String from, String to})>((ref, f) async {
  return ref.watch(accountingServiceProvider).getJournal(
        type: f.type,
        status: f.status,
        from: f.from.isEmpty ? null : f.from,
        to: f.to.isEmpty ? null : f.to,
      );
});

/// Trial balance as-of a date (ISO string; '' = all-time closing).
final trialBalanceProvider =
    FutureProvider.family<TrialBalance, String>((ref, asOfIso) async {
  return ref
      .watch(accountingServiceProvider)
      .getTrialBalance(to: asOfIso.isEmpty ? null : asOfIso);
});

/// P&L for a period. Key is (from, to) ISO strings; '' means open-ended.
final profitLossProvider =
    FutureProvider.family<PnlReport, ({String from, String to})>((ref, range) async {
  return ref.watch(accountingServiceProvider).getProfitAndLoss(
        from: range.from.isEmpty ? null : range.from,
        to: range.to.isEmpty ? null : range.to,
      );
});

/// Balance sheet as-of a date (ISO string; '' = today/all).
final balanceSheetProvider =
    FutureProvider.family<BalanceSheetReport, String>((ref, asOfIso) async {
  return ref
      .watch(accountingServiceProvider)
      .getBalanceSheet(to: asOfIso.isEmpty ? null : asOfIso);
});

/// Aging by kind ('receivables' | 'payables'), as on a given date (ISO, '' = today).
final agingProvider = FutureProvider.family<AgingReport,
    ({String kind, String asOf})>((ref, p) async {
  return ref
      .watch(accountingServiceProvider)
      .getAging(p.kind, asOf: p.asOf.isEmpty ? null : p.asOf);
});

/// Statement of account for one party (key: kind + name + phone).
final partyStatementProvider = FutureProvider.family<PartyStatement,
    ({String kind, String name, String phone})>((ref, p) async {
  return ref.watch(accountingServiceProvider).getPartyStatement(p.kind, p.name, phone: p.phone);
});

final gstSettingsProvider = FutureProvider<GstSettings>((ref) async {
  return ref.watch(accountingServiceProvider).getGstSettings();
});

/// GST summary for a period. Key is (from, to) ISO strings; '' means all-time.
final gstSummaryProvider =
    FutureProvider.family<GstSummary, ({String from, String to})>((ref, range) async {
  return ref.watch(accountingServiceProvider).getGstSummary(
        from: range.from.isEmpty ? null : range.from,
        to: range.to.isEmpty ? null : range.to,
      );
});

/// GSTR-1 register for a period. Key is (from, to) ISO strings; '' = all-time.
final gstr1Provider =
    FutureProvider.family<Gstr1Report, ({String from, String to})>((ref, range) async {
  return ref.watch(accountingServiceProvider).getGstr1(
        from: range.from.isEmpty ? null : range.from,
        to: range.to.isEmpty ? null : range.to,
      );
});

final accountingSettingsProvider = FutureProvider<AccountingSettings>((ref) async {
  return ref.watch(accountingServiceProvider).getAccountingSettings();
});

/// Ledger statement for one account, optionally bounded by a date window
/// (from/to ISO strings; '' = open-ended).
final ledgerProvider = FutureProvider.family<AccountLedger,
    ({String accountId, String from, String to})>((ref, k) async {
  return ref.watch(accountingServiceProvider).getLedger(
        k.accountId,
        from: k.from.isEmpty ? null : k.from,
        to: k.to.isEmpty ? null : k.to,
      );
});

/// Bank/cash accounts eligible for reconciliation.
final bankAccountsProvider = FutureProvider<List<BankAccountRef>>((ref) async {
  return ref.watch(accountingServiceProvider).getBankAccounts();
});

/// Reconciliation view for one bank/cash account id.
final reconciliationProvider =
    FutureProvider.family<Reconciliation, String>((ref, accountId) async {
  return ref.watch(accountingServiceProvider).getReconciliation(accountId);
});
