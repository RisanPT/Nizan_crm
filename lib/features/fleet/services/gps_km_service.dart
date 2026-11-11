import 'package:dio/dio.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/fleet/data/gps_km.dart';
import 'package:nizan_crm/features/fleet/data/gps_report_parser.dart';

/// The GPS tracker's km report: saving it, and checking driver km against it.
class GpsKmService {
  final Dio _dio;
  GpsKmService(this._dio);

  static String _day(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Driver km vs GPS km for [from]…[to]. Both null = the latest upload's days.
  Future<GpsCheck> compare({DateTime? from, DateTime? to}) async {
    try {
      final response = await _dio.get(
        '/fleet/gps-km/compare',
        queryParameters: {
          if (from != null) 'from': _day(from),
          if (to != null) 'to': _day(to),
        },
      );
      return GpsCheck.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      throw AppException(e, action: 'load the GPS km check');
    }
  }

  /// Save a report that has been read from a file. Safe to repeat: a day that is
  /// already saved is updated, not added again.
  Future<GpsUploadResult> upload({
    required String fileName,
    required List<GpsReportRow> rows,
  }) async {
    try {
      final response = await _dio.post(
        '/fleet/gps-km/upload',
        data: {'fileName': fileName, 'rows': [for (final r in rows) r.toJson()]},
      );
      return GpsUploadResult.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      throw AppException(e, action: 'upload the GPS report');
    }
  }
}
