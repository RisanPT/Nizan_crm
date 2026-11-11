// A driver's day (GET /fleet/driver/day-sheet and /fleet/manager/day-sheet):
// the works, the planned route and km, how the odometer compares, and the day's
// expenses put under the works.
//
//   ONE work in the day   → HQ → work → HQ, the way back = the way out (total ×2)
//   SEVERAL works         → HQ → 1st → 2nd … → last → HQ, in start-time order

double? _num(Object? v) => (v as num?)?.toDouble();
double _num0(Object? v) => (v as num?)?.toDouble() ?? 0;

Map<String, dynamic> _map(Object? v) => (v as Map?)?.cast<String, dynamic>() ?? const {};

List<T> _list<T>(Object? raw, T Function(Map<String, dynamic>) f) =>
    (raw as List? ?? const []).map((e) => f((e as Map).cast<String, dynamic>())).toList();

class DayLeg {
  /// out | between | return | estimate
  final String kind;
  final String from;
  final String to;

  /// null = the road distance couldn't be measured.
  final double? km;
  final int durationMin;

  /// The way back of a single work: taken as the same as the way out.
  final bool mirrored;
  final String note;

  const DayLeg({
    required this.kind,
    required this.from,
    required this.to,
    required this.km,
    required this.durationMin,
    required this.mirrored,
    required this.note,
  });

  factory DayLeg.fromJson(Map<String, dynamic> j) => DayLeg(
        kind: j['kind'] as String? ?? 'between',
        from: j['from'] as String? ?? '',
        to: j['to'] as String? ?? '',
        km: _num(j['km']),
        durationMin: (j['durationMin'] as num?)?.round() ?? 0,
        mirrored: j['mirrored'] == true,
        note: j['note'] as String? ?? '',
      );
}

class DayPlan {
  /// none | round_trip | multi_stop
  final String rule;
  final List<DayLeg> legs;
  final double plannedKm;
  final int plannedMin;

  /// Some location was only a pincode area, or a leg couldn't be measured.
  final bool approximate;
  final List<String> warnings;

  /// Set when the whole route couldn't be built (e.g. distance service not set up).
  final String planError;

  const DayPlan({
    required this.rule,
    required this.legs,
    required this.plannedKm,
    required this.plannedMin,
    required this.approximate,
    required this.warnings,
    required this.planError,
  });

  factory DayPlan.fromJson(Map<String, dynamic> j) => DayPlan(
        rule: j['rule'] as String? ?? 'none',
        legs: _list(j['legs'], DayLeg.fromJson),
        plannedKm: _num0(j['plannedKm']),
        plannedMin: (j['plannedMin'] as num?)?.round() ?? 0,
        approximate: j['approximate'] == true,
        warnings: (j['warnings'] as List? ?? const []).map((e) => '$e').toList(),
        planError: j['planError'] as String? ?? '',
      );
}

class DayVariance {
  final double km;
  final int percent;
  const DayVariance(this.km, this.percent);
}

class DayDistance {
  final double plannedKm;

  /// The way home to HQ — never on the odometer, as no trip is open for it.
  final double returnKm;

  /// plannedKm − returnKm: the part the trips' odometer readings cover.
  final double plannedTrackedKm;
  final double trackedKm;
  final DayVariance? variance;

  /// Odometer trips + the way home; only once every work of the day is finished.
  final double? estimatedDayKm;

  const DayDistance({
    required this.plannedKm,
    required this.returnKm,
    required this.plannedTrackedKm,
    required this.trackedKm,
    required this.variance,
    required this.estimatedDayKm,
  });

  factory DayDistance.fromJson(Map<String, dynamic> j) {
    final v = j['variance'];
    return DayDistance(
      plannedKm: _num0(j['plannedKm']),
      returnKm: _num0(j['returnKm']),
      plannedTrackedKm: _num0(j['plannedTrackedKm']),
      trackedKm: _num0(j['trackedKm']),
      variance: v is Map ? DayVariance(_num0(v['km']), (v['percent'] as num?)?.round() ?? 0) : null,
      estimatedDayKm: _num(j['estimatedDayKm']),
    );
  }
}

class DayFuelEstimate {
  final String unit; // km/l …
  final double ratedMileage;
  final double units; // litres / kg / kWh expected
  const DayFuelEstimate(this.unit, this.ratedMileage, this.units);
}

class WorkCosts {
  final double total;
  final double direct;
  final double shared;
  final Map<String, double> byCategory;
  const WorkCosts(this.total, this.direct, this.shared, this.byCategory);

  factory WorkCosts.fromJson(Map<String, dynamic> j) => WorkCosts(
        _num0(j['total']),
        _num0(j['direct']),
        _num0(j['shared']),
        _map(j['byCategory']).map((k, v) => MapEntry(k, _num0(v))),
      );
}

class DayVehicle {
  final String id;
  final String name;
  final String registrationNumber;
  final String category;
  final int seats;
  const DayVehicle(this.id, this.name, this.registrationNumber, this.category, this.seats);

  String get label => registrationNumber.isNotEmpty ? registrationNumber : name;
}

class DayTeam {
  /// Artists + assistants going to the work (not the driver).
  final int count;
  final String suggestedLabel;
  final bool needsMultiple;

  /// true = the vehicle takes them; false = it doesn't; null = capacity not recorded / no vehicle.
  final bool? fits;
  const DayTeam(this.count, this.suggestedLabel, this.needsMultiple, this.fits);
}

class DayWork {
  final String id;
  final String bookingNumber;
  final String label;
  final String customerName;
  final String service;
  final String eventSlot;
  final DateTime? start;
  final DateTime? end;
  final String tripStatus;
  final double? startKm;
  final double? endKm;
  final double? trackedKm;

  /// This work's share of the day's planned km (the way home counts for the last work).
  final double plannedKm;
  final bool located;
  final bool approximate;
  final DayVehicle? vehicle;
  final DayTeam team;
  final WorkCosts costs;

  const DayWork({
    required this.id,
    required this.bookingNumber,
    required this.label,
    required this.customerName,
    required this.service,
    required this.eventSlot,
    required this.start,
    required this.end,
    required this.tripStatus,
    required this.startKm,
    required this.endKm,
    required this.trackedKm,
    required this.plannedKm,
    required this.located,
    required this.approximate,
    required this.vehicle,
    required this.team,
    required this.costs,
  });

  factory DayWork.fromJson(Map<String, dynamic> j) {
    final v = j['vehicle'];
    final t = _map(j['team']);
    final s = _map(t['suggested']);
    return DayWork(
      id: j['id']?.toString() ?? '',
      bookingNumber: j['bookingNumber'] as String? ?? '',
      label: j['label'] as String? ?? '',
      customerName: j['customerName'] as String? ?? '',
      service: j['service'] as String? ?? '',
      eventSlot: j['eventSlot'] as String? ?? '',
      start: DateTime.tryParse(j['serviceStart']?.toString() ?? '')?.toLocal(),
      end: DateTime.tryParse(j['serviceEnd']?.toString() ?? '')?.toLocal(),
      tripStatus: j['tripStatus'] as String? ?? 'unassigned',
      startKm: _num(j['startKm']),
      endKm: _num(j['endKm']),
      trackedKm: _num(j['trackedKm']),
      plannedKm: _num0(j['plannedKm']),
      located: j['located'] == true,
      approximate: j['approximate'] == true,
      vehicle: v is Map
          ? DayVehicle(
              v['id']?.toString() ?? '',
              v['name'] as String? ?? '',
              v['registrationNumber'] as String? ?? '',
              v['category'] as String? ?? '',
              (v['seats'] as num?)?.toInt() ?? 0,
            )
          : null,
      team: DayTeam(
        (t['count'] as num?)?.toInt() ?? 0,
        s['label'] as String? ?? '',
        s['needsMultiple'] == true,
        t['fits'] as bool?,
      ),
      costs: WorkCosts.fromJson(_map(j['costs'])),
    );
  }
}

class DayAllocation {
  final String bookingId;
  final double amount;
  const DayAllocation(this.bookingId, this.amount);
}

class DayExpense {
  final String id;
  final String category;
  final double amount;

  /// pending | approved | rejected
  final String status;
  final DateTime? date;
  final String station;
  final String notes;
  final double liters;
  final double odometerKm;
  final String vehicleName;
  final String? bookingId;

  /// direct | shared | unallocated | rejected
  final String mode;
  final String reason;
  final List<DayAllocation> allocations;

  const DayExpense({
    required this.id,
    required this.category,
    required this.amount,
    required this.status,
    required this.date,
    required this.station,
    required this.notes,
    required this.liters,
    required this.odometerKm,
    required this.vehicleName,
    required this.bookingId,
    required this.mode,
    required this.reason,
    required this.allocations,
  });

  factory DayExpense.fromJson(Map<String, dynamic> j) => DayExpense(
        id: j['id']?.toString() ?? '',
        category: j['category'] as String? ?? 'other',
        amount: _num0(j['amount']),
        status: j['status'] as String? ?? 'pending',
        date: DateTime.tryParse(j['date']?.toString() ?? '')?.toLocal(),
        station: j['station'] as String? ?? '',
        notes: j['notes'] as String? ?? '',
        liters: _num0(j['liters']),
        odometerKm: _num0(j['odometerKm']),
        vehicleName: j['vehicleName'] as String? ?? '',
        bookingId: j['bookingId']?.toString(),
        mode: j['mode'] as String? ?? 'unallocated',
        reason: j['reason'] as String? ?? '',
        allocations: _list(
          j['allocations'],
          (a) => DayAllocation(a['bookingId']?.toString() ?? '', _num0(a['amount'])),
        ),
      );
}

class DayTotals {
  final double amount;
  final Map<String, double> byCategory;
  final double shared;
  final double unallocated;
  const DayTotals(this.amount, this.byCategory, this.shared, this.unallocated);
}

class DaySheet {
  final String dayKey;
  final String driverName;
  final String hq;
  final List<DayWork> works;
  final DayPlan plan;
  final DayDistance distance;
  final DayFuelEstimate? fuelEstimate;
  final List<DayExpense> expenses;
  final DayTotals totals;

  const DaySheet({
    required this.dayKey,
    required this.driverName,
    required this.hq,
    required this.works,
    required this.plan,
    required this.distance,
    required this.fuelEstimate,
    required this.expenses,
    required this.totals,
  });

  DayWork? workById(String id) {
    for (final w in works) {
      if (w.id == id) return w;
    }
    return null;
  }

  factory DaySheet.fromJson(Map<String, dynamic> j) {
    final fe = j['fuelEstimate'];
    final t = _map(j['totals']);
    return DaySheet(
      dayKey: j['dayKey'] as String? ?? '',
      driverName: _map(j['driver'])['name'] as String? ?? '',
      hq: j['hq'] as String? ?? '',
      works: _list(j['works'], DayWork.fromJson),
      plan: DayPlan.fromJson(_map(j['plan'])),
      distance: DayDistance.fromJson(_map(j['distance'])),
      fuelEstimate: fe is Map
          ? DayFuelEstimate(
              fe['unit'] as String? ?? 'km/l',
              _num0(fe['ratedMileage']),
              _num0(fe['units']),
            )
          : null,
      expenses: _list(j['expenses'], DayExpense.fromJson),
      totals: DayTotals(
        _num0(t['amount']),
        _map(t['byCategory']).map((k, v) => MapEntry(k, _num0(v))),
        _num0(t['shared']),
        _num0(t['unallocated']),
      ),
    );
  }
}
