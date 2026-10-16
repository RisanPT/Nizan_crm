import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nizan_crm/providers/dio_provider.dart';

/// Road distance from the headquarters (HiLITE Business Park, Calicut),
/// worked out on the server (GET /api/geo/distance).
final geoDistanceServiceProvider =
    Provider<GeoDistanceService>((ref) => GeoDistanceService(ref.watch(dioProvider)));

class HqDistance {
  final double km;
  final int durationMin;
  final String from;
  final String to;
  final String method; // pincode | address

  const HqDistance({
    required this.km,
    required this.durationMin,
    required this.from,
    required this.to,
    required this.method,
  });

  String get driveTime {
    final h = durationMin ~/ 60, m = durationMin % 60;
    return h == 0 ? '$m min' : '${h}h ${m}m';
  }
}

class GeoDistanceService {
  final Dio _dio;
  GeoDistanceService(this._dio);

  /// Throws a [String] with a readable reason when it can't be worked out.
  Future<HqDistance> fromHq({String pincode = '', String address = ''}) =>
      _get({
        if (pincode.trim().isNotEmpty) 'pincode': pincode.trim(),
        if (address.trim().isNotEmpty) 'address': address.trim(),
      });

  /// From a pasted Google Maps link or typed "lat, lng" (the exact venue pin).
  Future<HqDistance> fromMapLink(String link) => _get({'link': link.trim()});

  Future<HqDistance> _get(Map<String, String> query) async {
    final Response res;
    try {
      res = await _dio.get(
        '/geo/distance',
        queryParameters: query,
        options: Options(validateStatus: (_) => true),
      );
    } on DioException {
      throw 'Could not reach the server to calculate the distance.';
    }
    final d = res.data;
    if (d is Map && d['ok'] == true) {
      return HqDistance(
        km: (d['km'] as num).toDouble(),
        durationMin: (d['durationMin'] as num?)?.toInt() ?? 0,
        from: d['from'] as String? ?? 'HQ',
        to: d['to'] as String? ?? '',
        method: d['method'] as String? ?? '',
      );
    }
    throw (d is Map ? (d['error'] ?? d['message']) : null)?.toString() ??
        'Could not calculate the distance (HTTP ${res.statusCode}).';
  }
}
