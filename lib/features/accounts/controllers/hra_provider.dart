import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nizan_crm/providers/dio_provider.dart';
import 'package:nizan_crm/features/accounts/data/hra_record.dart';
import 'package:nizan_crm/features/accounts/services/hra_service.dart';

final hraServiceProvider = Provider<HraService>((ref) => HraService(ref.watch(dioProvider)));

final hraRecordsProvider = FutureProvider<List<HraRecord>>((ref) async {
  return ref.watch(hraServiceProvider).getRecords();
});

final hraStatsProvider = FutureProvider<HraStats>((ref) async {
  return ref.watch(hraServiceProvider).getStats();
});
