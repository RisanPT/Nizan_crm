import 'package:dio/dio.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/fleet/data/fuel_price.dart';

/// The fuel prices (Accounts / the fleet manager / an admin change them; everyone signed in may read them).
class FuelPriceService {
  final Dio _dio;
  FuelPriceService(this._dio);

  Future<FuelPrices> list() async {
    try {
      final response = await _dio.get('/fuel-prices');
      return FuelPrices.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      throw AppException(e, action: 'load the fuel prices');
    }
  }

  Future<FuelPriceRow> create(FuelPriceRow row) async {
    try {
      final response = await _dio.post('/fuel-prices', data: row.toBody());
      return FuelPriceRow.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      throw AppException(e, action: 'save the fuel price');
    }
  }

  Future<FuelPriceRow> update(String id, FuelPriceRow row) async {
    try {
      final response = await _dio.put('/fuel-prices/$id', data: row.toBody());
      return FuelPriceRow.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      throw AppException(e, action: 'save the fuel price');
    }
  }

  Future<void> delete(String id) async {
    try {
      await _dio.delete('/fuel-prices/$id');
    } catch (e) {
      throw AppException(e, action: 'delete the fuel price');
    }
  }
}
