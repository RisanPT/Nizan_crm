import 'package:freezed_annotation/freezed_annotation.dart';

part 'fleet_models.freezed.dart';
part 'fleet_models.g.dart';

@freezed
abstract class FleetJob with _$FleetJob {
  const factory FleetJob({
    @JsonKey(name: '_id') required String id,
    required String bookingNumber,
    String? driverId,
    dynamic vehicleId,
    @Default([]) List<String> preTripPhotos,
    @Default('unassigned') String tripStatus,
    required String customerName,
    String? address,
    String? mapUrl,
    required String service,
    String? eventSlot,
    required DateTime serviceStart,
    required DateTime serviceEnd,
    @Default(0) double travelDistanceKm,
    String? pocName,
    String? pocPhone,
    @Default([]) List<Map<String, dynamic>> assignedStaff,
  }) = _FleetJob;

  factory FleetJob.fromJson(Map<String, dynamic> json) => _$FleetJobFromJson(json);
}

// Reference fields arrive either as an id string (unpopulated) or a populated
// object; extract a display string either way so parsing never crashes.
String _driverName(dynamic v) {
  if (v == null) return '';
  if (v is String) return v;
  if (v is Map) return (v['name'] ?? v['_id'] ?? '').toString();
  return v.toString();
}

String _vehicleName(dynamic v) {
  if (v == null) return '';
  if (v is String) return v;
  if (v is Map) {
    final reg = (v['registrationNumber'] ?? '').toString();
    final type = (v['type'] ?? '').toString();
    if (reg.isNotEmpty && type.isNotEmpty) return '$type · $reg';
    if (reg.isNotEmpty) return reg;
    if (type.isNotEmpty) return type;
    return (v['_id'] ?? '').toString();
  }
  return v.toString();
}

String? _jobRef(dynamic v) {
  if (v == null) return null;
  if (v is String) return v;
  if (v is Map) return (v['bookingNumber'] ?? v['_id'] ?? '').toString();
  return v.toString();
}

@freezed
abstract class AccidentReport with _$AccidentReport {
  const factory AccidentReport({
    @JsonKey(name: '_id') required String id,
    @JsonKey(fromJson: _driverName) required String driver,
    @JsonKey(fromJson: _vehicleName) required String vehicle,
    @JsonKey(fromJson: _jobRef) String? job,
    required AccidentLocation location,
    required List<String> photos,
    required String description,
    AccidentOpposite? opposite,
    required String status,
    DateTime? createdAt,
  }) = _AccidentReport;

  factory AccidentReport.fromJson(Map<String, dynamic> json) => _$AccidentReportFromJson(json);
}

@freezed
abstract class AccidentOpposite with _$AccidentOpposite {
  const factory AccidentOpposite({
    @Default('') String name,
    @Default('') String phone,
    @Default('') String vehicleNumber,
    @Default('') String notes,
  }) = _AccidentOpposite;

  factory AccidentOpposite.fromJson(Map<String, dynamic> json) =>
      _$AccidentOppositeFromJson(json);
}

extension AccidentOppositeX on AccidentOpposite {
  bool get hasData =>
      name.trim().isNotEmpty ||
      phone.trim().isNotEmpty ||
      vehicleNumber.trim().isNotEmpty ||
      notes.trim().isNotEmpty;
}

@freezed
abstract class AccidentLocation with _$AccidentLocation {
  const factory AccidentLocation({
    required double lat,
    required double lng,
    String? address,
  }) = _AccidentLocation;

  factory AccidentLocation.fromJson(Map<String, dynamic> json) => _$AccidentLocationFromJson(json);
}

@freezed
abstract class DriverReview with _$DriverReview {
  const factory DriverReview({
    @JsonKey(name: '_id') required String id,
    required String driver,
    required String artist,
    required String job,
    required int rating,
    String? comment,
  }) = _DriverReview;

  factory DriverReview.fromJson(Map<String, dynamic> json) => _$DriverReviewFromJson(json);
}

@freezed
abstract class ServiceReminder with _$ServiceReminder {
  const factory ServiceReminder({
    @JsonKey(name: '_id') required String id,
    required dynamic vehicle,
    required String serviceType,
    DateTime? dueDate,
    double? dueKm,
    @Default('pending') String status,
    String? notes,
  }) = _ServiceReminder;

  factory ServiceReminder.fromJson(Map<String, dynamic> json) => _$ServiceReminderFromJson(json);
}
