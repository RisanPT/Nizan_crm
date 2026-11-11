import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nizan_crm/features/fleet/data/gps_km.dart';
import 'package:nizan_crm/features/fleet/services/gps_km_service.dart';
import 'package:nizan_crm/providers/dio_provider.dart';

final gpsKmServiceProvider = Provider<GpsKmService>(
  (ref) => GpsKmService(ref.watch(dioProvider)),
);

/// Which days to check; a null side means "let the server choose" (the latest upload's days).
typedef GpsCheckQuery = ({DateTime? from, DateTime? to});

/// Driver km vs GPS km. Plain FutureProvider.family (not codegen) — no build_runner run needed.
final gpsCheckProvider =
    FutureProvider.autoDispose.family<GpsCheck, GpsCheckQuery>((ref, q) {
  return ref.watch(gpsKmServiceProvider).compare(from: q.from, to: q.to);
});
