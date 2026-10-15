/// Km driven over a date range, from GET /fleet/manager/km-report.
class KmReport {
  final double totalKm;
  final int trips;

  /// Completed trips in the range without both odometer readings.
  final int untrackedTrips;
  final double avgKmPerTrip;
  final List<KmByDriver> drivers; // most km first
  final List<KmByVehicle> vehicles; // most km first
  final List<KmTrip> tripList; // newest first

  const KmReport({
    required this.totalKm,
    required this.trips,
    required this.untrackedTrips,
    required this.avgKmPerTrip,
    required this.drivers,
    required this.vehicles,
    required this.tripList,
  });

  factory KmReport.fromJson(Map<String, dynamic> json) {
    final t = json['totals'] as Map<String, dynamic>? ?? const {};
    List<T> list<T>(String key, T Function(Map<String, dynamic>) f) =>
        ((json[key] as List?) ?? const [])
            .map((e) => f(e as Map<String, dynamic>))
            .toList();
    return KmReport(
      totalKm: _d(t['km']),
      trips: (t['trips'] as num?)?.toInt() ?? 0,
      untrackedTrips: (t['untrackedTrips'] as num?)?.toInt() ?? 0,
      avgKmPerTrip: _d(t['avgKmPerTrip']),
      drivers: list('drivers', KmByDriver.fromJson),
      vehicles: list('vehicles', KmByVehicle.fromJson),
      tripList: list('trips', KmTrip.fromJson),
    );
  }
}

class KmByDriver {
  final String driverId;
  final String name;
  final int trips;
  final double km;
  const KmByDriver(this.driverId, this.name, this.trips, this.km);

  factory KmByDriver.fromJson(Map<String, dynamic> j) => KmByDriver(
        j['driverId'] as String? ?? '',
        j['name'] as String? ?? '',
        (j['trips'] as num?)?.toInt() ?? 0,
        _d(j['km']),
      );
}

class KmByVehicle {
  final String vehicleId;
  final String name;
  final String registrationNumber;
  final int trips;
  final double km;

  /// Fuel bought for this vehicle in the same range, and ₹ per km from it.
  final double fuelSpend;
  final double? costPerKm;
  const KmByVehicle(this.vehicleId, this.name, this.registrationNumber,
      this.trips, this.km, this.fuelSpend, this.costPerKm);

  factory KmByVehicle.fromJson(Map<String, dynamic> j) => KmByVehicle(
        j['vehicleId'] as String? ?? '',
        j['name'] as String? ?? '',
        j['registrationNumber'] as String? ?? '',
        (j['trips'] as num?)?.toInt() ?? 0,
        _d(j['km']),
        _d(j['fuelSpend']),
        (j['costPerKm'] as num?)?.toDouble(),
      );
}

class KmTrip {
  final String bookingNumber;
  final String customerName;
  final String driverName;
  final String vehicleName;
  final String registrationNumber;
  final double startKm;
  final double endKm;
  final double km;
  final DateTime? completedAt;
  const KmTrip({
    required this.bookingNumber,
    required this.customerName,
    required this.driverName,
    required this.vehicleName,
    required this.registrationNumber,
    required this.startKm,
    required this.endKm,
    required this.km,
    this.completedAt,
  });

  factory KmTrip.fromJson(Map<String, dynamic> j) => KmTrip(
        bookingNumber: j['bookingNumber'] as String? ?? '',
        customerName: j['customerName'] as String? ?? '',
        driverName: j['driverName'] as String? ?? '',
        vehicleName: j['vehicleName'] as String? ?? '',
        registrationNumber: j['registrationNumber'] as String? ?? '',
        startKm: _d(j['startKm']),
        endKm: _d(j['endKm']),
        km: _d(j['km']),
        completedAt: j['completedAt'] is String
            ? DateTime.tryParse(j['completedAt'] as String)?.toLocal()
            : null,
      );
}

double _d(dynamic v) => (v as num?)?.toDouble() ?? 0;
