// A vehicle's fuel efficiency, worked out on the server from its fuel entries
// (GET /vehicles/:id/efficiency, and the fleet-wide GET /vehicles/efficiency).

double? _num(Object? v) => (v as num?)?.toDouble();
int? _int(Object? v) => (v as num?)?.round();

/// One stretch between two fill-ups.
class EfficiencyInterval {
  final DateTime? date;
  final double fromKm;
  final double toKm;
  final double km;
  final double liters;
  final double efficiency;

  /// A reading that doesn't look real (mistyped odometer, missed fill-up) —
  /// shown, but kept out of the average.
  final bool suspect;

  const EfficiencyInterval({
    required this.date,
    required this.fromKm,
    required this.toKm,
    required this.km,
    required this.liters,
    required this.efficiency,
    required this.suspect,
  });

  factory EfficiencyInterval.fromJson(Map<String, dynamic> json) => EfficiencyInterval(
        date: DateTime.tryParse(json['date']?.toString() ?? '')?.toLocal(),
        fromKm: _num(json['fromKm']) ?? 0,
        toKm: _num(json['toKm']) ?? 0,
        km: _num(json['km']) ?? 0,
        liters: _num(json['liters']) ?? 0,
        efficiency: _num(json['efficiency']) ?? 0,
        suspect: json['suspect'] == true,
      );
}

class EfficiencyMonth {
  final String month; // 'YYYY-MM'
  final double liters;
  final double spend;
  final double km;
  final double? efficiency;

  const EfficiencyMonth({
    required this.month,
    required this.liters,
    required this.spend,
    required this.km,
    required this.efficiency,
  });

  factory EfficiencyMonth.fromJson(Map<String, dynamic> json) => EfficiencyMonth(
        month: json['month'] as String? ?? '',
        liters: _num(json['liters']) ?? 0,
        spend: _num(json['spend']) ?? 0,
        km: _num(json['km']) ?? 0,
        efficiency: _num(json['efficiency']),
      );
}

class VehicleEfficiency {
  final String vehicleId;
  final String name;
  final String registrationNumber;
  final String category;
  final int seats;
  final String fuelType;

  /// 'km/l' | 'km/kg' | 'km/kWh'
  final String unit;
  final double? rated;
  final double? actual;
  final int? vsRatedPercent;

  /// good | watch | poor | unknown
  final String status;

  /// fill_ups | trips | none — how `actual` was measured.
  final String method;

  /// high | medium | low | none
  final String confidence;
  final int fillUpsUsed;
  final int intervalsUsed;
  final int suspectIntervals;
  final double kmTracked;
  final double litresUsed;
  final double? costPerKm;
  final double? avgPricePerUnit;
  final double fuelSpend;
  final int fillCount;
  final DateTime? lastFillDate;
  final double? tankCapacity;
  final int? ratedRangeKm;
  final int? actualRangeKm;
  final List<EfficiencyInterval> intervals;
  final List<EfficiencyMonth> monthly;

  const VehicleEfficiency({
    required this.vehicleId,
    required this.name,
    required this.registrationNumber,
    required this.category,
    required this.seats,
    required this.fuelType,
    required this.unit,
    required this.rated,
    required this.actual,
    required this.vsRatedPercent,
    required this.status,
    required this.method,
    required this.confidence,
    required this.fillUpsUsed,
    required this.intervalsUsed,
    required this.suspectIntervals,
    required this.kmTracked,
    required this.litresUsed,
    required this.costPerKm,
    required this.avgPricePerUnit,
    required this.fuelSpend,
    required this.fillCount,
    required this.lastFillDate,
    required this.tankCapacity,
    required this.ratedRangeKm,
    required this.actualRangeKm,
    required this.intervals,
    required this.monthly,
  });

  bool get hasFigure => actual != null;

  factory VehicleEfficiency.fromJson(Map<String, dynamic> json) {
    List<T> list<T>(Object? raw, T Function(Map<String, dynamic>) f) =>
        (raw as List? ?? const []).map((e) => f(e as Map<String, dynamic>)).toList();

    return VehicleEfficiency(
      vehicleId: json['vehicleId']?.toString() ?? '',
      name: json['name'] as String? ?? '',
      registrationNumber: json['registrationNumber'] as String? ?? '',
      category: json['category'] as String? ?? '',
      seats: _int(json['seats']) ?? 0,
      fuelType: json['fuelType'] as String? ?? 'petrol',
      unit: json['unit'] as String? ?? 'km/l',
      rated: _num(json['rated']),
      actual: _num(json['actual']),
      vsRatedPercent: _int(json['vsRatedPercent']),
      status: json['status'] as String? ?? 'unknown',
      method: json['method'] as String? ?? 'none',
      confidence: json['confidence'] as String? ?? 'none',
      fillUpsUsed: _int(json['fillUpsUsed']) ?? 0,
      intervalsUsed: _int(json['intervalsUsed']) ?? 0,
      suspectIntervals: _int(json['suspectIntervals']) ?? 0,
      kmTracked: _num(json['kmTracked']) ?? 0,
      litresUsed: _num(json['litresUsed']) ?? 0,
      costPerKm: _num(json['costPerKm']),
      avgPricePerUnit: _num(json['avgPricePerUnit']),
      fuelSpend: _num(json['fuelSpend']) ?? 0,
      fillCount: _int(json['fillCount']) ?? 0,
      lastFillDate: DateTime.tryParse(json['lastFillDate']?.toString() ?? '')?.toLocal(),
      tankCapacity: _num(json['tankCapacity']),
      ratedRangeKm: _int(json['ratedRangeKm']),
      actualRangeKm: _int(json['actualRangeKm']),
      intervals: list(json['intervals'], EfficiencyInterval.fromJson),
      monthly: list(json['monthly'], EfficiencyMonth.fromJson),
    );
  }
}

/// Every vehicle's headline figures, worst performers first.
class FleetEfficiency {
  final int days;
  final int vehicles;
  final int measured;
  final int poor;
  final int watch;
  final int good;
  final int missingRatedMileage;
  final List<VehicleEfficiency> items;

  const FleetEfficiency({
    required this.days,
    required this.vehicles,
    required this.measured,
    required this.poor,
    required this.watch,
    required this.good,
    required this.missingRatedMileage,
    required this.items,
  });

  factory FleetEfficiency.fromJson(Map<String, dynamic> json) {
    final s = (json['summary'] as Map<String, dynamic>?) ?? const {};
    return FleetEfficiency(
      days: _int(json['days']) ?? 365,
      vehicles: _int(s['vehicles']) ?? 0,
      measured: _int(s['measured']) ?? 0,
      poor: _int(s['poor']) ?? 0,
      watch: _int(s['watch']) ?? 0,
      good: _int(s['good']) ?? 0,
      missingRatedMileage: _int(s['missingRatedMileage']) ?? 0,
      items: (json['items'] as List? ?? const [])
          .map((e) => VehicleEfficiency.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  VehicleEfficiency? forVehicle(String vehicleId) {
    for (final i in items) {
      if (i.vehicleId == vehicleId) return i;
    }
    return null;
  }
}
