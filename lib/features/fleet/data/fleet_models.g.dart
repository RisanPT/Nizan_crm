// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'fleet_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_FleetJob _$FleetJobFromJson(Map<String, dynamic> json) => _FleetJob(
  id: json['_id'] as String,
  bookingNumber: json['bookingNumber'] as String,
  driverId: json['driverId'] as String?,
  vehicleId: json['vehicleId'],
  preTripPhotos:
      (json['preTripPhotos'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const [],
  tripStatus: json['tripStatus'] as String? ?? 'unassigned',
  customerName: json['customerName'] as String,
  address: json['address'] as String?,
  mapUrl: json['mapUrl'] as String?,
  service: json['service'] as String,
  eventSlot: json['eventSlot'] as String?,
  serviceStart: DateTime.parse(json['serviceStart'] as String),
  serviceEnd: DateTime.parse(json['serviceEnd'] as String),
  travelDistanceKm: (json['travelDistanceKm'] as num?)?.toDouble() ?? 0,
  pocName: json['pocName'] as String?,
  pocPhone: json['pocPhone'] as String?,
  assignedStaff:
      (json['assignedStaff'] as List<dynamic>?)
          ?.map((e) => e as Map<String, dynamic>)
          .toList() ??
      const [],
);

Map<String, dynamic> _$FleetJobToJson(_FleetJob instance) => <String, dynamic>{
  '_id': instance.id,
  'bookingNumber': instance.bookingNumber,
  'driverId': instance.driverId,
  'vehicleId': instance.vehicleId,
  'preTripPhotos': instance.preTripPhotos,
  'tripStatus': instance.tripStatus,
  'customerName': instance.customerName,
  'address': instance.address,
  'mapUrl': instance.mapUrl,
  'service': instance.service,
  'eventSlot': instance.eventSlot,
  'serviceStart': instance.serviceStart.toIso8601String(),
  'serviceEnd': instance.serviceEnd.toIso8601String(),
  'travelDistanceKm': instance.travelDistanceKm,
  'pocName': instance.pocName,
  'pocPhone': instance.pocPhone,
  'assignedStaff': instance.assignedStaff,
};

_AccidentReport _$AccidentReportFromJson(
  Map<String, dynamic> json,
) => _AccidentReport(
  id: json['_id'] as String,
  driver: _driverName(json['driver']),
  vehicle: _vehicleName(json['vehicle']),
  job: _jobRef(json['job']),
  location: AccidentLocation.fromJson(json['location'] as Map<String, dynamic>),
  photos: (json['photos'] as List<dynamic>).map((e) => e as String).toList(),
  description: json['description'] as String,
  opposite: json['opposite'] == null
      ? null
      : AccidentOpposite.fromJson(json['opposite'] as Map<String, dynamic>),
  status: json['status'] as String,
  createdAt: json['createdAt'] == null
      ? null
      : DateTime.parse(json['createdAt'] as String),
);

Map<String, dynamic> _$AccidentReportToJson(_AccidentReport instance) =>
    <String, dynamic>{
      '_id': instance.id,
      'driver': instance.driver,
      'vehicle': instance.vehicle,
      'job': instance.job,
      'location': instance.location,
      'photos': instance.photos,
      'description': instance.description,
      'opposite': instance.opposite,
      'status': instance.status,
      'createdAt': instance.createdAt?.toIso8601String(),
    };

_AccidentOpposite _$AccidentOppositeFromJson(Map<String, dynamic> json) =>
    _AccidentOpposite(
      name: json['name'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      vehicleNumber: json['vehicleNumber'] as String? ?? '',
      notes: json['notes'] as String? ?? '',
    );

Map<String, dynamic> _$AccidentOppositeToJson(_AccidentOpposite instance) =>
    <String, dynamic>{
      'name': instance.name,
      'phone': instance.phone,
      'vehicleNumber': instance.vehicleNumber,
      'notes': instance.notes,
    };

_AccidentLocation _$AccidentLocationFromJson(Map<String, dynamic> json) =>
    _AccidentLocation(
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      address: json['address'] as String?,
    );

Map<String, dynamic> _$AccidentLocationToJson(_AccidentLocation instance) =>
    <String, dynamic>{
      'lat': instance.lat,
      'lng': instance.lng,
      'address': instance.address,
    };

_DriverReview _$DriverReviewFromJson(Map<String, dynamic> json) =>
    _DriverReview(
      id: json['_id'] as String,
      driver: json['driver'] as String,
      artist: json['artist'] as String,
      job: json['job'] as String,
      rating: (json['rating'] as num).toInt(),
      comment: json['comment'] as String?,
    );

Map<String, dynamic> _$DriverReviewToJson(_DriverReview instance) =>
    <String, dynamic>{
      '_id': instance.id,
      'driver': instance.driver,
      'artist': instance.artist,
      'job': instance.job,
      'rating': instance.rating,
      'comment': instance.comment,
    };

_ServiceReminder _$ServiceReminderFromJson(Map<String, dynamic> json) =>
    _ServiceReminder(
      id: json['_id'] as String,
      vehicle: json['vehicle'],
      serviceType: json['serviceType'] as String,
      dueDate: json['dueDate'] == null
          ? null
          : DateTime.parse(json['dueDate'] as String),
      dueKm: (json['dueKm'] as num?)?.toDouble(),
      status: json['status'] as String? ?? 'pending',
      notes: json['notes'] as String?,
    );

Map<String, dynamic> _$ServiceReminderToJson(_ServiceReminder instance) =>
    <String, dynamic>{
      '_id': instance.id,
      'vehicle': instance.vehicle,
      'serviceType': instance.serviceType,
      'dueDate': instance.dueDate?.toIso8601String(),
      'dueKm': instance.dueKm,
      'status': instance.status,
      'notes': instance.notes,
    };
