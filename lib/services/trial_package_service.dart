import 'package:dio/dio.dart';
import '../core/models/trial_package.dart';

class TrialPackageService {
  final Dio _dio;
  
  TrialPackageService(this._dio);

  Future<List<TrialPackage>> getTrialPackages() async {
    try {
      final response = await _dio.get('/trial-packages');
      final data = response.data as List;
      return data.map((json) => TrialPackage.fromJson(json)).toList();
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<TrialPackage> createTrialPackage(TrialPackage pkg) async {
    try {
      final response = await _dio.post(
        '/trial-packages',
        data: pkg.toJson(),
      );
      return TrialPackage.fromJson(response.data);
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<TrialPackage> updateTrialPackage(TrialPackage pkg) async {
    try {
      final response = await _dio.put(
        '/trial-packages/${pkg.id}',
        data: pkg.toJson(),
      );
      return TrialPackage.fromJson(response.data);
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> deleteTrialPackage(String id) async {
    try {
      await _dio.delete('/trial-packages/$id');
    } catch (e) {
      throw _handleError(e);
    }
  }

  Exception _handleError(dynamic error) {
    if (error is DioException) {
      final message = error.response?.data?['message'] ?? error.message;
      return Exception(message);
    }
    return Exception(error.toString());
  }
}
