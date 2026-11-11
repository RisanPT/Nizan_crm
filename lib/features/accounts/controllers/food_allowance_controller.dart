import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nizan_crm/features/accounts/data/food_allowance.dart';
import 'package:nizan_crm/features/accounts/services/food_allowance_service.dart';
import 'package:nizan_crm/providers/dio_provider.dart';

final foodAllowanceServiceProvider = Provider<FoodAllowanceService>((ref) => FoodAllowanceService(ref.watch(dioProvider)));

/// Every allowance rule, meals in the order of the day, the latest rule first.
final foodAllowanceRulesProvider = FutureProvider.autoDispose<List<FoodAllowanceRule>>((ref) {
  return ref.watch(foodAllowanceServiceProvider).list();
});
