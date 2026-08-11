import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nizan_crm/providers/dio_provider.dart';
import 'package:nizan_crm/features/accounts/data/sales_return.dart';
import 'package:nizan_crm/features/accounts/services/sales_return_service.dart';

final salesReturnServiceProvider = Provider<SalesReturnService>((ref) {
  return SalesReturnService(ref.watch(dioProvider));
});

final salesReturnsProvider = FutureProvider<List<SalesReturn>>((ref) async {
  return ref.watch(salesReturnServiceProvider).getSalesReturns();
});

final salesReturnStatsProvider = FutureProvider<SalesReturnStats>((ref) async {
  return ref.watch(salesReturnServiceProvider).getStats();
});
