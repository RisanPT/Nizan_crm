import 'package:dio/dio.dart';
import 'package:nizan_crm/features/accounts/data/hra_record.dart';

class HraService {
  final Dio _dio;
  HraService(this._dio);

  Future<List<HraRecord>> getRecords({int? month, int? year, String? employeeId}) async {
    final res = await _dio.get('/hra', queryParameters: {
      'month': ?month,
      'year': ?year,
      if (employeeId != null && employeeId.isNotEmpty) 'employeeId': employeeId,
    });
    final list = res.data as List;
    return list.map((e) => HraRecord.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<HraStats> getStats() async {
    final res = await _dio.get('/hra/stats');
    return HraStats.fromJson(res.data as Map<String, dynamic>);
  }

  Future<HraRecord> create(Map<String, dynamic> payload) async {
    final res = await _dio.post('/hra', data: payload);
    return HraRecord.fromJson(res.data as Map<String, dynamic>);
  }

  Future<HraRecord> update(String id, Map<String, dynamic> payload) async {
    final res = await _dio.put('/hra/$id', data: payload);
    return HraRecord.fromJson(res.data as Map<String, dynamic>);
  }

  Future<void> delete(String id) async {
    await _dio.delete('/hra/$id');
  }
}
