// GPS tracker km vs the km drivers entered — from GET /fleet/gps-km/compare
// and POST /fleet/gps-km/upload.

/// A vehicle number reduced to what identifies it ("KL-57-Y-6100" = "KL 57 Y
/// 6100"; zero padding in an ordinary plate ignored). Mirrors `regKey` in the
/// backend's utils/gpsKm.js, so the app can say which plates in a file are
/// known before anything is uploaded.
String gpsRegKey(String value) {
  final plain = value.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
  final m = RegExp(r'^([A-Z]{2})(\d{1,2})([A-Z]{1,3})(\d{1,4})$').firstMatch(plain);
  return m == null ? plain : '${m[1]}${int.parse(m[2]!)}${m[3]}${m[4]!.padLeft(4, '0')}';
}

/// How a vehicle-day came out.
enum GpsDayStatus {
  ok('Matches', 'Driver km and GPS agree'),
  driverLow('Driver km low', 'GPS shows more than the driver entered'),
  driverHigh('Driver km high', 'The driver entered more than GPS shows'),
  noTrip('No trip logged', 'The vehicle moved but no driver km was entered'),
  noGps('No GPS data', 'Nothing to check against');

  final String label;
  final String meaning;
  const GpsDayStatus(this.label, this.meaning);

  static GpsDayStatus parse(String? s) => switch (s) {
        'ok' => ok,
        'driver_low' => driverLow,
        'driver_high' => driverHigh,
        'no_trip' => noTrip,
        _ => noGps,
      };

  /// Worth a manager's attention.
  bool get needsReview => this != ok;

  /// An actual comparison (counts towards accuracy).
  bool get compared => this == ok || this == driverLow || this == driverHigh;
}

double? _d(dynamic v) => (v as num?)?.toDouble();
double _d0(dynamic v) => (v as num?)?.toDouble() ?? 0;
int _i(dynamic v) => (v as num?)?.toInt() ?? 0;
DateTime? _day(dynamic v) => v is String && v.length >= 10 ? DateTime.tryParse(v.substring(0, 10)) : null;

class GpsTrip {
  final String bookingNumber;
  final String customerName;
  final String driverName;
  final double startKm;
  final double endKm;
  final double km;
  const GpsTrip({
    required this.bookingNumber,
    required this.customerName,
    required this.driverName,
    required this.startKm,
    required this.endKm,
    required this.km,
  });

  factory GpsTrip.fromJson(Map<String, dynamic> j) => GpsTrip(
        bookingNumber: j['bookingNumber'] as String? ?? '',
        customerName: j['customerName'] as String? ?? '',
        driverName: j['driverName'] as String? ?? '',
        startKm: _d0(j['startKm']),
        endKm: _d0(j['endKm']),
        km: _d0(j['km']),
      );
}

/// One vehicle on one day.
class GpsDay {
  final DateTime date;
  final String vehicleId;
  final String registrationNumber;
  final String vehicleName;
  final double? gpsKm;
  final double? driverKm;

  /// The drive back to the office, which no odometer entry records but GPS does.
  final double returnLegKm;

  /// 'route' (the day's stored route), 'booking' (the work's own distance) or 'none'.
  final String returnLegSource;
  final double? expectedKm;
  final double? diffKm;
  final double? diffPct;
  final double? toleranceKm;
  final GpsDayStatus status;

  /// For [GpsDayStatus.noGps]: 'missing' (no row in the report) or 'zero' (the tracker showed no movement).
  final String reason;
  final List<String> driverNames;
  final List<GpsTrip> trips;
  final double? runningHours;
  final double? stopHours;
  final double? idleHours;
  final String startAddress;
  final String endAddress;

  const GpsDay({
    required this.date,
    required this.vehicleId,
    required this.registrationNumber,
    required this.vehicleName,
    required this.status,
    this.gpsKm,
    this.driverKm,
    this.returnLegKm = 0,
    this.returnLegSource = 'none',
    this.expectedKm,
    this.diffKm,
    this.diffPct,
    this.toleranceKm,
    this.reason = '',
    this.driverNames = const [],
    this.trips = const [],
    this.runningHours,
    this.stopHours,
    this.idleHours,
    this.startAddress = '',
    this.endAddress = '',
  });

  String get vehicleLabel => [vehicleName, registrationNumber].where((s) => s.isNotEmpty).join(' · ');

  factory GpsDay.fromJson(Map<String, dynamic> j) => GpsDay(
        date: _day(j['date']) ?? DateTime.fromMillisecondsSinceEpoch(0),
        vehicleId: j['vehicleId'] as String? ?? '',
        registrationNumber: j['registrationNumber'] as String? ?? '',
        vehicleName: j['vehicleName'] as String? ?? '',
        status: GpsDayStatus.parse(j['status'] as String?),
        gpsKm: _d(j['gpsKm']),
        driverKm: _d(j['driverKm']),
        returnLegKm: _d0(j['returnLegKm']),
        returnLegSource: j['returnLegSource'] as String? ?? 'none',
        expectedKm: _d(j['expectedKm']),
        diffKm: _d(j['diffKm']),
        diffPct: _d(j['diffPct']),
        toleranceKm: _d(j['toleranceKm']),
        reason: j['reason'] as String? ?? '',
        driverNames: [for (final n in (j['driverNames'] as List? ?? const [])) n as String],
        trips: [for (final t in (j['trips'] as List? ?? const [])) GpsTrip.fromJson(t as Map<String, dynamic>)],
        runningHours: _d(j['runningHours']),
        stopHours: _d(j['stopHours']),
        idleHours: _d(j['idleHours']),
        startAddress: j['startAddress'] as String? ?? '',
        endAddress: j['endAddress'] as String? ?? '',
      );
}

/// A vehicle's or a driver's standing over the range.
class GpsStanding {
  final String id;
  final String name;
  final String registrationNumber; // vehicles only
  final double gpsKm; // vehicles only
  final int comparedDays;
  final int okDays;
  final int lowDays;
  final int highDays;
  final int noTripDays;
  final int noGpsDays;
  final double unloggedKm;
  final double netDiffKm;

  /// 0–100, null when no day could be compared.
  final double? accuracyPct;

  const GpsStanding({
    required this.id,
    required this.name,
    this.registrationNumber = '',
    this.gpsKm = 0,
    this.comparedDays = 0,
    this.okDays = 0,
    this.lowDays = 0,
    this.highDays = 0,
    this.noTripDays = 0,
    this.noGpsDays = 0,
    this.unloggedKm = 0,
    this.netDiffKm = 0,
    this.accuracyPct,
  });

  factory GpsStanding.vehicle(Map<String, dynamic> j) => GpsStanding(
        id: j['vehicleId'] as String? ?? '',
        name: j['name'] as String? ?? '',
        registrationNumber: j['registrationNumber'] as String? ?? '',
        gpsKm: _d0(j['gpsKm']),
        comparedDays: _i(j['comparedDays']),
        okDays: _i(j['okDays']),
        lowDays: _i(j['lowDays']),
        highDays: _i(j['highDays']),
        noTripDays: _i(j['noTripDays']),
        noGpsDays: _i(j['noGpsDays']),
        unloggedKm: _d0(j['unloggedKm']),
        netDiffKm: _d0(j['netDiffKm']),
        accuracyPct: _d(j['accuracyPct']),
      );

  factory GpsStanding.driver(Map<String, dynamic> j) => GpsStanding(
        id: j['driverId'] as String? ?? '',
        name: j['name'] as String? ?? '',
        comparedDays: _i(j['comparedDays']),
        okDays: _i(j['okDays']),
        lowDays: _i(j['lowDays']),
        highDays: _i(j['highDays']),
        netDiffKm: _d0(j['netDiffKm']),
        accuracyPct: _d(j['accuracyPct']),
      );

  /// "Innova · KL 57 Y 6100".
  String get label => [name, registrationNumber].where((s) => s.isNotEmpty).join(' · ');
}

class GpsTotals {
  final double gpsKm;
  final double comparedGpsKm;
  final double comparedDriverKm;
  final int comparedDays;
  final int okDays;
  final int lowDays;
  final int highDays;
  final int noTripDays;
  final int noGpsDays;
  final int reviewDays;
  final double unloggedKm;
  final double netDiffKm;
  final double? accuracyPct;
  const GpsTotals({
    this.gpsKm = 0,
    this.comparedGpsKm = 0,
    this.comparedDriverKm = 0,
    this.comparedDays = 0,
    this.okDays = 0,
    this.lowDays = 0,
    this.highDays = 0,
    this.noTripDays = 0,
    this.noGpsDays = 0,
    this.reviewDays = 0,
    this.unloggedKm = 0,
    this.netDiffKm = 0,
    this.accuracyPct,
  });

  factory GpsTotals.fromJson(Map<String, dynamic> j) => GpsTotals(
        gpsKm: _d0(j['gpsKm']),
        comparedGpsKm: _d0(j['comparedGpsKm']),
        comparedDriverKm: _d0(j['comparedDriverKm']),
        comparedDays: _i(j['comparedDays']),
        okDays: _i(j['okDays']),
        lowDays: _i(j['lowDays']),
        highDays: _i(j['highDays']),
        noTripDays: _i(j['noTripDays']),
        noGpsDays: _i(j['noGpsDays']),
        reviewDays: _i(j['reviewDays']),
        unloggedKm: _d0(j['unloggedKm']),
        netDiffKm: _d0(j['netDiffKm']),
        accuracyPct: _d(j['accuracyPct']),
      );
}

/// A vehicle with trips in the range but nothing in the GPS report.
class GpsUncovered {
  final String registrationNumber;
  final String name;
  final int trips;
  final double driverKm;
  const GpsUncovered(this.registrationNumber, this.name, this.trips, this.driverKm);

  factory GpsUncovered.fromJson(Map<String, dynamic> j) => GpsUncovered(
        j['registrationNumber'] as String? ?? '',
        j['name'] as String? ?? '',
        _i(j['trips']),
        _d0(j['driverKm']),
      );
}

/// A plate in the GPS report that is not a CRM vehicle.
class GpsUnmatched {
  final String registrationNumber;
  final int days;
  final double gpsKm;
  const GpsUnmatched(this.registrationNumber, this.days, this.gpsKm);

  factory GpsUnmatched.fromJson(Map<String, dynamic> j) => GpsUnmatched(
        j['registrationNumber'] as String? ?? '',
        _i(j['days']),
        _d0(j['gpsKm']),
      );
}

class GpsUploadInfo {
  final String fileName;
  final String uploadedByName;
  final DateTime? from;
  final DateTime? to;
  final int rows;
  final DateTime? uploadedAt;
  const GpsUploadInfo({
    required this.fileName,
    required this.uploadedByName,
    required this.rows,
    this.from,
    this.to,
    this.uploadedAt,
  });

  factory GpsUploadInfo.fromJson(Map<String, dynamic> j) => GpsUploadInfo(
        fileName: j['fileName'] as String? ?? '',
        uploadedByName: j['uploadedByName'] as String? ?? '',
        rows: _i(j['rows']),
        from: _day(j['from']),
        to: _day(j['to']),
        uploadedAt: j['uploadedAt'] is String ? DateTime.tryParse(j['uploadedAt'] as String)?.toLocal() : null,
      );
}

class GpsCheck {
  final DateTime from;
  final DateTime to;

  /// True when the server chose the dates (the latest upload's days).
  final bool defaulted;
  final double tolerancePercent;
  final double toleranceMinKm;
  final GpsTotals totals;
  final List<GpsStanding> vehicles; // least accurate first
  final List<GpsStanding> drivers; // least accurate first
  final List<GpsDay> days; // newest first
  final List<GpsUncovered> vehiclesWithoutGps;
  final List<GpsUnmatched> unmatchedGps;
  final List<GpsUploadInfo> uploads; // newest first

  const GpsCheck({
    required this.from,
    required this.to,
    required this.defaulted,
    required this.tolerancePercent,
    required this.toleranceMinKm,
    required this.totals,
    required this.vehicles,
    required this.drivers,
    required this.days,
    required this.vehiclesWithoutGps,
    required this.unmatchedGps,
    required this.uploads,
  });

  bool get hasUploads => uploads.isNotEmpty;

  factory GpsCheck.fromJson(Map<String, dynamic> j) {
    List<T> list<T>(String key, T Function(Map<String, dynamic>) f) =>
        [for (final e in (j[key] as List? ?? const [])) f(e as Map<String, dynamic>)];
    final tol = j['tolerance'] as Map<String, dynamic>? ?? const {};
    return GpsCheck(
      from: _day(j['from']) ?? DateTime.now(),
      to: _day(j['to']) ?? DateTime.now(),
      defaulted: j['defaulted'] == true,
      tolerancePercent: _d(tol['percent']) ?? 10,
      toleranceMinKm: _d(tol['minKm']) ?? 5,
      totals: GpsTotals.fromJson(j['totals'] as Map<String, dynamic>? ?? const {}),
      vehicles: list('vehicles', GpsStanding.vehicle),
      drivers: list('drivers', GpsStanding.driver),
      days: list('days', GpsDay.fromJson),
      vehiclesWithoutGps: list('vehiclesWithoutGps', GpsUncovered.fromJson),
      unmatchedGps: list('unmatchedGps', GpsUnmatched.fromJson),
      uploads: list('uploads', GpsUploadInfo.fromJson),
    );
  }
}

/// What saving a report did.
class GpsUploadResult {
  final DateTime? from;
  final DateTime? to;
  final int rows;
  final int created;
  final int updated;
  final int unchanged;
  final int skipped;
  const GpsUploadResult({
    required this.rows,
    required this.created,
    required this.updated,
    required this.unchanged,
    required this.skipped,
    this.from,
    this.to,
  });

  factory GpsUploadResult.fromJson(Map<String, dynamic> j) => GpsUploadResult(
        from: _day(j['from']),
        to: _day(j['to']),
        rows: _i(j['rows']),
        created: _i(j['created']),
        updated: _i(j['updated']),
        unchanged: _i(j['unchanged']),
        skipped: _i(j['skipped']),
      );
}
