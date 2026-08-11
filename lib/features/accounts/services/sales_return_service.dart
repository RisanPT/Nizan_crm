import 'package:dio/dio.dart';
import 'package:nizan_crm/features/accounts/data/sales_return.dart';

class SalesReturnService {
  final Dio _dio;
  SalesReturnService(this._dio);

  Future<List<SalesReturn>> getSalesReturns({String? search, String? status}) async {
    final res = await _dio.get('/sales-returns', queryParameters: {
      if (search != null && search.isNotEmpty) 'search': search,
      if (status != null && status.isNotEmpty && status != 'All') 'status': status,
    });
    final list = res.data as List;
    return list.map((e) => SalesReturn.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<SalesReturnStats> getStats() async {
    final res = await _dio.get('/sales-returns/stats');
    return SalesReturnStats.fromJson(res.data as Map<String, dynamic>);
  }

  Future<SalesReturn> create(Map<String, dynamic> payload) async {
    final res = await _dio.post('/sales-returns', data: payload);
    return SalesReturn.fromJson(res.data as Map<String, dynamic>);
  }

  Future<SalesReturn> update(String id, Map<String, dynamic> payload) async {
    final res = await _dio.put('/sales-returns/$id', data: payload);
    return SalesReturn.fromJson(res.data as Map<String, dynamic>);
  }

  Future<SalesReturn> updateStatus(String id, String status) async {
    final res = await _dio.patch('/sales-returns/$id/status', data: {'status': status});
    return SalesReturn.fromJson(res.data as Map<String, dynamic>);
  }

  Future<void> delete(String id) async {
    await _dio.delete('/sales-returns/$id');
  }
}
