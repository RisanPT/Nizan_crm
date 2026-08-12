import 'package:dio/dio.dart';
import 'package:nizan_crm/features/finance/data/asset.dart';
import 'package:nizan_crm/features/finance/data/depreciation.dart';

class AssetService {
  final Dio _dio;
  AssetService(this._dio);

  String _msg(DioException e, String fallback) {
    final data = e.response?.data;
    if (data is Map && data['message'] != null) return data['message'].toString();
    return '$fallback: ${e.message}';
  }

  /// [type] = 'digital' | 'physical' | 'all'.
  Future<List<Asset>> getAssets({String type = 'all', String? search}) async {
    try {
      final res = await _dio.get('/assets', queryParameters: {
        if (type != 'all') 'type': type,
        if (search != null && search.isNotEmpty) 'search': search,
      });
      return (res.data as List)
          .map((e) => Asset.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw Exception(_msg(e, 'Failed to load assets'));
    }
  }

  Future<AssetStats> getStats() async {
    try {
      final res = await _dio.get('/assets/stats');
      return AssetStats.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(_msg(e, 'Failed to load asset stats'));
    }
  }

  Future<Asset> save(Map<String, dynamic> body, {String? id}) async {
    try {
      final res = id == null
          ? await _dio.post('/assets', data: body)
          : await _dio.put('/assets/$id', data: body);
      return Asset.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(_msg(e, 'Failed to save asset'));
    }
  }

  Future<void> delete(String id) async {
    try {
      await _dio.delete('/assets/$id');
    } on DioException catch (e) {
      throw Exception(_msg(e, 'Failed to delete asset'));
    }
  }

  // ── Depreciation ──
  Future<DepreciationSchedule> getDepreciationSchedule({DateTime? asOf}) async {
    try {
      final res = await _dio.get('/assets/depreciation/schedule',
          queryParameters: {if (asOf != null) 'asOf': asOf.toIso8601String()});
      return DepreciationSchedule.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(_msg(e, 'Failed to load depreciation schedule'));
    }
  }

  Future<DepreciationRunResult> runDepreciation({DateTime? asOf}) async {
    try {
      final res = await _dio.post('/assets/depreciation/run',
          data: {if (asOf != null) 'asOf': asOf.toIso8601String()});
      return DepreciationRunResult.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(_msg(e, 'Failed to run depreciation'));
    }
  }

  Future<List<DepreciationRunSummary>> getDepreciationRuns() async {
    try {
      final res = await _dio.get('/assets/depreciation/runs');
      return (res.data as List)
          .map((e) => DepreciationRunSummary.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw Exception(_msg(e, 'Failed to load depreciation runs'));
    }
  }
}
