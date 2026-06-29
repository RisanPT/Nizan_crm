import 'package:freezed_annotation/freezed_annotation.dart';

part 'fleet_models.freezed.dart';
part 'fleet_models.g.dart';

@freezed
abstract class FleetJob with _$FleetJob {
  const factory FleetJob({
    @JsonKey(name: '_id') required String id,
    required String bookingNumber,
    String? driverId,
    dynamic vehicleId, // Could be String or a Map depending on populate
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

@freezed
abstract class AccidentReport with _$AccidentReport {
  const factory AccidentReport({
    @JsonKey(name: '_id') required String id,
    required String driver,
    required String vehicle,
    String? job,
    required AccidentLocation location,
    required List<String> photos,
    required String description,
    required String status,
  }) = _AccidentReport;

  factory AccidentReport.fromJson(Map<String, dynamic> json) => _$AccidentReportFromJson(json);
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
