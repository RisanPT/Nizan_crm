import 'package:dio/dio.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/accounts/data/work_profit.dart';

/// Work profit for Accounts: what each work earned and cost (GET /api/work-profit).
class WorkProfitService {
  final Dio _dio;
  WorkProfitService(this._dio);

  Future<WorkProfitPage> getPage(WorkProfitQuery query) async {
    try {
      final response = await _dio.get(
        '/work-profit',
        queryParameters: query.toParams(),
      );
      return WorkProfitPage.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      throw AppException(e, action: 'load the work profit');
    }
  }

  /// Every work matching [query] (capped by the server), for a download.
  Future<WorkProfitPage> export(WorkProfitQuery query) async {
    try {
      final response = await _dio.get(
        '/work-profit',
        queryParameters: query.toParams(export: true),
      );
      return WorkProfitPage.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      throw AppException(e, action: 'export the work profit');
    }
  }
}
