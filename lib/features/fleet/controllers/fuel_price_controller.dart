import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nizan_crm/features/fleet/data/fuel_price.dart';
import 'package:nizan_crm/features/fleet/services/fuel_price_service.dart';
import 'package:nizan_crm/providers/dio_provider.dart';

final fuelPriceServiceProvider = Provider<FuelPriceService>(
  (ref) => FuelPriceService(ref.watch(dioProvider)),
);

/// Every fuel price. A form that only wants today's rate treats a failure as "no price": the fill-in
/// and the hint simply stay away, nothing is blocked.
final fuelPricesProvider = FutureProvider.autoDispose<FuelPrices>((ref) {
  return ref.watch(fuelPriceServiceProvider).list();
});
