import 'package:dio/dio.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/accounts/data/food_allowance.dart';

/// The food allowance per head (Accounts / admin change it; everyone signed in may read it).
class FoodAllowanceService {
  final Dio _dio;
  FoodAllowanceService(this._dio);

  Future<List<FoodAllowanceRule>> list() async {
    try {
      final response = await _dio.get('/food-allowances');
      return [for (final r in (response.data as List)) FoodAllowanceRule.fromJson((r as Map).cast<String, dynamic>())];
    } catch (e) {
      throw AppException(e, action: 'load the food allowance');
    }
  }

  Future<FoodAllowanceRule> create(FoodAllowanceRule rule) async {
    try {
      final response = await _dio.post('/food-allowances', data: rule.toBody());
      return FoodAllowanceRule.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      throw AppException(e, action: 'save the food allowance');
    }
  }

  Future<FoodAllowanceRule> update(String id, FoodAllowanceRule rule) async {
    try {
      final response = await _dio.put('/food-allowances/$id', data: rule.toBody());
      return FoodAllowanceRule.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      throw AppException(e, action: 'save the food allowance');
    }
  }

  /// Switches a rule on or off without touching anything else.
  Future<FoodAllowanceRule> setActive(String id, bool active) async {
    try {
      final response = await _dio.put('/food-allowances/$id', data: {'active': active});
      return FoodAllowanceRule.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      throw AppException(e, action: 'save the food allowance');
    }
  }

  Future<void> delete(String id) async {
    try {
      await _dio.delete('/food-allowances/$id');
    } catch (e) {
      throw AppException(e, action: 'delete the food allowance');
    }
  }
}
