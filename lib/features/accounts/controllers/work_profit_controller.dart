import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nizan_crm/features/accounts/data/work_profit.dart';
import 'package:nizan_crm/features/accounts/services/work_profit_service.dart';
import 'package:nizan_crm/providers/dio_provider.dart';

final workProfitServiceProvider = Provider<WorkProfitService>(
  (ref) => WorkProfitService(ref.watch(dioProvider)),
);

/// One page of work profit; one cached request per distinct query.
final workProfitPageProvider = FutureProvider.autoDispose
    .family<WorkProfitPage, WorkProfitQuery>((ref, query) {
      return ref.watch(workProfitServiceProvider).getPage(query);
    });
