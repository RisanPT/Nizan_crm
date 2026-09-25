import 'package:dio/dio.dart';
import '../core/models/trial_package.dart';
import 'package:nizan_crm/core/error/errors.dart';

class TrialPackageService {
  final Dio _dio;
  
  TrialPackageService(this._dio);

  Future<List<TrialPackage>> getTrialPackages() async {
    try {
      final response = await _dio.get('/trial-packages');
      final data = response.data as List;
      return data.map((json) => TrialPackage.fromJson(json)).toList();
    } catch (e) {
      throw AppException(e, action: 'load trial packages');
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
      throw AppException(e, action: 'create the trial package');
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
      throw AppException(e, action: 'update the trial package');
    }
  }

  Future<void> deleteTrialPackage(String id) async {
    try {
      await _dio.delete('/trial-packages/$id');
    } catch (e) {
      throw AppException(e, action: 'delete the trial package');
    }
  }
}
