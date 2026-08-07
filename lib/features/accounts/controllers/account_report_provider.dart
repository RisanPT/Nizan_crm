import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nizan_crm/features/accounts/data/account_report.dart';
import 'package:nizan_crm/providers/dio_provider.dart';
import 'package:nizan_crm/features/accounts/services/account_report_service.dart';

final accountReportServiceProvider = Provider<AccountReportService>((ref) {
  return AccountReportService(ref.watch(dioProvider));
});

final accountReportsProvider = FutureProvider<List<AccountReport>>((ref) async {
  return ref.watch(accountReportServiceProvider).getReports();
});
