import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nizan_crm/providers/dio_provider.dart';
import 'package:nizan_crm/features/finance/data/sales_report.dart';
import 'package:nizan_crm/features/finance/services/sales_report_service.dart';

final salesReportServiceProvider = Provider<SalesReportService>((ref) {
  return SalesReportService(ref.watch(dioProvider));
});

/// A sales report keyed by (kind, from, to, groupBy). Empty strings mean unset.
final salesReportProvider = FutureProvider.family<SalesReport,
    ({String kind, String from, String to, String groupBy})>((ref, k) async {
  return ref.watch(salesReportServiceProvider).get(
        k.kind,
        from: k.from.isEmpty ? null : k.from,
        to: k.to.isEmpty ? null : k.to,
        groupBy: k.groupBy.isEmpty ? null : k.groupBy,
      );
});
