import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import 'package:nizan_crm/core/error/app_exception.dart';

/// Something a driver or vehicle runs into for a work: it is already on another work at the same time
/// (`overlap`), has too little time to get there from the one before (`tight`), cannot be used
/// (`unavailable`: vehicle under service, driver on leave), or only deserves a mention (`warning`).
class AvailabilityProblem {
  final String resource; // driver | vehicle ('' inside a resource's own list)
  final String id;
  final String name;
  final String kind; // overlap | tight | unavailable | warning
  final String reason;
  final String day;
  final DateTime? start;
  final DateTime? end;
  final String withBookingNumber;
  final String withCustomer;
  final int? gapMinutes;
  final int? neededMinutes;
  final bool estimated;

  const AvailabilityProblem({
    this.resource = '',
    this.id = '',
    this.name = '',
    required this.kind,
    this.reason = '',
    this.day = '',
    this.start,
    this.end,
    this.withBookingNumber = '',
    this.withCustomer = '',
    this.gapMinutes,
    this.neededMinutes,
    this.estimated = false,
  });

  bool get isOverlap => kind == 'overlap';
  bool get isTight => kind == 'tight';
  bool get isUnavailable => kind == 'unavailable';
  bool get isWarning => kind == 'warning';

  /// Stops an assignment unless a person confirms.
  bool get isBlocking => isOverlap || isUnavailable;

  factory AvailabilityProblem.fromJson(Map<String, dynamic> j) {
    final w = j['with'];
    final withMap = w is Map
        ? w.cast<String, dynamic>()
        : const <String, dynamic>{};
    return AvailabilityProblem(
      resource: '${j['resource'] ?? ''}',
      id: '${j['id'] ?? ''}',
      name: '${j['name'] ?? ''}',
      kind: '${j['kind'] ?? ''}',
      reason: '${j['reason'] ?? ''}',
      day: '${j['day'] ?? ''}',
      start: DateTime.tryParse('${j['start'] ?? ''}')?.toLocal(),
      end: DateTime.tryParse('${j['end'] ?? ''}')?.toLocal(),
      withBookingNumber: '${withMap['bookingNumber'] ?? ''}',
      withCustomer: '${withMap['customerName'] ?? ''}',
      gapMinutes: (j['gapMinutes'] as num?)?.toInt(),
      neededMinutes: (j['neededMinutes'] as num?)?.toInt(),
      estimated: j['estimated'] == true,
    );
  }

  /// "1 h 30 min", "45 min".
  static String duration(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '$m min';
    return m == 0 ? '$h h' : '$h h $m min';
  }

  static String _clock(DateTime? t) =>
      t == null ? '' : DateFormat('h:mm a').format(t);

  /// The other work: "BK-12 · Beena" (whatever is known).
  String get otherWork =>
      [withBookingNumber, withCustomer].where((x) => x.isNotEmpty).join(' · ');

  /// One plain line a person can read.
  String get text {
    switch (kind) {
      case 'overlap':
        final what = otherWork.isEmpty ? 'another work' : otherWork;
        return start == null || end == null
            ? 'Already on $what'
            : 'Already on $what, ${_clock(start)}–${_clock(end)}';
      case 'tight':
        final gap = gapMinutes ?? 0;
        final need = neededMinutes ?? 0;
        return 'Only ${duration(gap < 0 ? 0 : gap)} from ${otherWork.isEmpty ? 'the other work' : otherWork} — '
            '${estimated ? 'about ' : ''}${duration(need)} needed to get there';
      default:
        return reason;
    }
  }
}

/// One driver or vehicle, for the booking being assigned.
class ResourceAvailability {
  final String id;
  final String name;
  final String registrationNumber;

  /// free | tight | busy | unavailable
  final String status;
  final List<AvailabilityProblem> conflicts;
  final List<AvailabilityProblem> warnings;

  const ResourceAvailability({
    required this.id,
    required this.name,
    this.registrationNumber = '',
    this.status = 'free',
    this.conflicts = const [],
    this.warnings = const [],
  });

  bool get isFree => status == 'free';
  bool get isBlocked => status == 'busy' || status == 'unavailable';

  /// The worst thing about it, in a line ('' when free).
  String get summary => conflicts.isEmpty
      ? (warnings.isEmpty ? '' : warnings.first.text)
      : conflicts.first.text;

  factory ResourceAvailability.fromJson(Map<String, dynamic> j) {
    List<AvailabilityProblem> list(Object? v) => [
      for (final p in (v as List? ?? const []))
        AvailabilityProblem.fromJson((p as Map).cast<String, dynamic>()),
    ];
    return ResourceAvailability(
      id: '${j['id'] ?? ''}',
      name: '${j['name'] ?? ''}',
      registrationNumber: '${j['registrationNumber'] ?? ''}',
      status: '${j['status'] ?? 'free'}',
      conflicts: list(j['conflicts']),
      warnings: list(j['warnings']),
    );
  }
}

/// How every driver and vehicle stands for one booking's days.
class BookingAvailability {
  final String bookingId;
  final List<String> days;
  final List<ResourceAvailability> drivers;
  final List<ResourceAvailability> vehicles;

  const BookingAvailability({
    required this.bookingId,
    this.days = const [],
    this.drivers = const [],
    this.vehicles = const [],
  });

  ResourceAvailability? driver(String? id) =>
      drivers.where((d) => d.id == id).firstOrNull;
  ResourceAvailability? vehicle(String? id) =>
      vehicles.where((v) => v.id == id).firstOrNull;

  factory BookingAvailability.fromJson(Map<String, dynamic> j) {
    List<ResourceAvailability> list(Object? v) => [
      for (final r in (v as List? ?? const []))
        ResourceAvailability.fromJson((r as Map).cast<String, dynamic>()),
    ];
    return BookingAvailability(
      bookingId: '${j['bookingId'] ?? ''}',
      days: [for (final d in (j['days'] as List? ?? const [])) '$d'],
      drivers: list(j['drivers']),
      vehicles: list(j['vehicles']),
    );
  }
}

// ── the day board ──

class BoardWork {
  final String bookingId;
  final String bookingNumber;
  final String customerName;
  final DateTime? start;
  final DateTime? end;
  const BoardWork({
    required this.bookingId,
    required this.bookingNumber,
    required this.customerName,
    this.start,
    this.end,
  });

  factory BoardWork.fromJson(Map<String, dynamic> j) => BoardWork(
    bookingId: '${j['bookingId'] ?? ''}',
    bookingNumber: '${j['bookingNumber'] ?? ''}',
    customerName: '${j['customerName'] ?? ''}',
    start: DateTime.tryParse('${j['start'] ?? ''}')?.toLocal(),
    end: DateTime.tryParse('${j['end'] ?? ''}')?.toLocal(),
  );
}

/// A driver or vehicle on the board: its works that day and anything wrong with it.
class BoardResource {
  final String id;
  final String name;
  final String registrationNumber;
  final String category;
  final int seats;
  final String status; // free | tight | busy | unavailable
  final List<BoardWork> works;

  /// Two of its own works that clash: ('overlap' | 'tight', [BK-1, BK-2]).
  final List<(String, List<String>)> clashes;
  final List<AvailabilityProblem> conflicts;
  final List<AvailabilityProblem> warnings;

  const BoardResource({
    required this.id,
    required this.name,
    this.registrationNumber = '',
    this.category = '',
    this.seats = 0,
    this.status = 'free',
    this.works = const [],
    this.clashes = const [],
    this.conflicts = const [],
    this.warnings = const [],
  });

  bool get isFreeAllDay => works.isEmpty && conflicts.isEmpty;

  factory BoardResource.fromJson(Map<String, dynamic> j) {
    List<AvailabilityProblem> list(Object? v) => [
      for (final p in (v as List? ?? const []))
        AvailabilityProblem.fromJson((p as Map).cast<String, dynamic>()),
    ];
    return BoardResource(
      id: '${j['id'] ?? ''}',
      name: '${j['name'] ?? ''}',
      registrationNumber: '${j['registrationNumber'] ?? ''}',
      category: '${j['category'] ?? ''}',
      seats: (j['seats'] as num?)?.toInt() ?? 0,
      status: '${j['status'] ?? 'free'}',
      works: [
        for (final w in (j['works'] as List? ?? const []))
          BoardWork.fromJson((w as Map).cast<String, dynamic>()),
      ],
      clashes: [
        for (final c in (j['clashes'] as List? ?? const []))
          (
            '${(c as Map)['kind']}',
            [for (final b in (c['between'] as List? ?? const [])) '$b'],
          ),
      ],
      conflicts: list(j['conflicts']),
      warnings: list(j['warnings']),
    );
  }
}

/// A work on the board that still needs a driver and/or a vehicle.
class NeedingWork {
  final BoardWork work;
  final bool needsDriver;
  final bool needsVehicle;
  const NeedingWork({
    required this.work,
    required this.needsDriver,
    required this.needsVehicle,
  });

  factory NeedingWork.fromJson(Map<String, dynamic> j) => NeedingWork(
    work: BoardWork.fromJson(j),
    needsDriver: j['needsDriver'] == true,
    needsVehicle: j['needsVehicle'] == true,
  );
}

class FleetBoard {
  final String day;
  final List<BoardResource> vehicles;
  final List<BoardResource> drivers;
  final List<NeedingWork> needing;
  const FleetBoard({
    required this.day,
    this.vehicles = const [],
    this.drivers = const [],
    this.needing = const [],
  });

  factory FleetBoard.fromJson(Map<String, dynamic> j) => FleetBoard(
    day: '${j['day'] ?? ''}',
    vehicles: [
      for (final v in (j['vehicles'] as List? ?? const []))
        BoardResource.fromJson((v as Map).cast<String, dynamic>()),
    ],
    drivers: [
      for (final d in (j['drivers'] as List? ?? const []))
        BoardResource.fromJson((d as Map).cast<String, dynamic>()),
    ],
    needing: [
      for (final n in (j['needing'] as List? ?? const []))
        NeedingWork.fromJson((n as Map).cast<String, dynamic>()),
    ],
  );
}

/// The server refused an assignment (409 FLEET_CONFLICT) because the driver / vehicle is already on
/// another work then, or unavailable. Asking "assign anyway?" and repeating the request with
/// confirmation goes through.
class FleetConflict {
  final String message;
  final List<AvailabilityProblem> problems;
  final List<AvailabilityProblem> warnings;
  const FleetConflict({
    required this.message,
    required this.problems,
    this.warnings = const [],
  });

  /// The conflict inside [error], or null when it is some other failure.
  static FleetConflict? of(Object? error) {
    final cause = error is AppException ? error.cause : error;
    if (cause is! DioException || cause.response?.statusCode != 409) {
      return null;
    }
    final data = cause.response?.data;
    if (data is! Map || data['code'] != 'FLEET_CONFLICT') return null;
    List<AvailabilityProblem> list(Object? v) => [
      for (final p in (v as List? ?? const []))
        AvailabilityProblem.fromJson((p as Map).cast<String, dynamic>()),
    ];
    return FleetConflict(
      message: '${data['message'] ?? ''}',
      problems: list(data['problems']),
      warnings: list(data['warnings']),
    );
  }
}
