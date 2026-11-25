import 'package:dio/dio.dart';
import 'package:nizan_crm/core/error/app_exception.dart';

// ONE DRIVER PER ARTIST PER DAY — what the server did (or wants confirmed) when a driver is
// assigned to one of an artist's works: her other works that day get the same driver and
// vehicle. The rule lives on the server (nizan_crm_backend/utils/driverDay.js).

/// One of the artist's other works that day.
class DriverDayWork {
  final String bookingId;
  final String bookingNumber;
  final String customerName;
  final DateTime? serviceStart;

  /// 'YYYY-MM-DD' (IST) — the day it shares with the edited work.
  final String day;

  /// "#BK-12 · Anu"
  final String label;

  /// The driver it has now (conflict) / had before (assigned).
  final String driverName;

  /// Why it was left alone: multi_day | trip_started | other_driver. Empty when it was assigned.
  final String reason;

  const DriverDayWork({
    required this.bookingId,
    required this.bookingNumber,
    required this.customerName,
    required this.serviceStart,
    required this.day,
    required this.label,
    this.driverName = '',
    this.reason = '',
  });

  factory DriverDayWork.fromJson(Map<String, dynamic> j) => DriverDayWork(
    bookingId: '${j['bookingId'] ?? ''}',
    bookingNumber: '${j['bookingNumber'] ?? ''}',
    customerName: '${j['customerName'] ?? ''}',
    serviceStart: DateTime.tryParse('${j['serviceStart'] ?? ''}')?.toLocal(),
    day: '${j['day'] ?? ''}',
    label: '${j['label'] ?? ''}',
    driverName: '${j['currentDriverName'] ?? j['previousDriverName'] ?? ''}',
    reason: '${j['reason'] ?? ''}',
  );

  String get reasonText => switch (reason) {
    'multi_day' => 'runs over several days — assign its driver by hand',
    'trip_started' => 'its trip has already started',
    'other_driver' => 'already has another driver — change it by hand if needed',
    _ => reason,
  };

  static List<DriverDayWork> listOf(Object? v) => [
    for (final w in (v as List? ?? const []))
      if (w is Map) DriverDayWork.fromJson(w.cast<String, dynamic>()),
  ];
}

/// What the server did after a save: `driverDay` in the booking response (null = nothing to do).
class DriverDayResult {
  final String driverName;

  /// The driver was taken off (so it was taken off her other works too).
  final bool removed;
  final List<DriverDayWork> assigned;
  final List<DriverDayWork> skipped;
  final List<String> warnings;

  const DriverDayResult({
    required this.driverName,
    required this.removed,
    required this.assigned,
    required this.skipped,
    required this.warnings,
  });

  bool get isEmpty => assigned.isEmpty && skipped.isEmpty && warnings.isEmpty;

  static DriverDayResult? fromJson(Object? json) {
    if (json is! Map) return null;
    final r = DriverDayResult(
      driverName: '${json['driverName'] ?? ''}',
      removed: json['removed'] == true,
      assigned: DriverDayWork.listOf(json['assigned']),
      skipped: DriverDayWork.listOf(json['skipped']),
      warnings: [for (final w in (json['warnings'] as List? ?? const [])) '$w'],
    );
    return r.isEmpty ? null : r;
  }
}

/// The server's 409 DRIVER_DAY_CONFLICT: some of her works that day have another driver.
class DriverDayConflict {
  final String message;
  final String driverName;
  final List<DriverDayWork> works;

  const DriverDayConflict({
    required this.message,
    required this.driverName,
    required this.works,
  });

  /// The conflict inside [error], or null when it is some other failure.
  static DriverDayConflict? of(Object? error) {
    final cause = error is AppException ? error.cause : error;
    if (cause is! DioException || cause.response?.statusCode != 409) {
      return null;
    }
    final data = cause.response?.data;
    if (data is! Map || data['code'] != 'DRIVER_DAY_CONFLICT') return null;
    return DriverDayConflict(
      message: '${data['message'] ?? ''}',
      driverName: '${data['driverName'] ?? ''}',
      works: DriverDayWork.listOf(data['works']),
    );
  }
}
