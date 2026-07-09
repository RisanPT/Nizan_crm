// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'fleet_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$FleetJob {

@JsonKey(name: '_id') String get id; String get bookingNumber; String? get driverId; dynamic get vehicleId;// Could be String or a Map depending on populate
 List<String> get preTripPhotos; String get tripStatus; String get customerName; String? get address; String? get mapUrl; String get service; String? get eventSlot; DateTime get serviceStart; DateTime get serviceEnd; double get travelDistanceKm; String? get pocName; String? get pocPhone; List<Map<String, dynamic>> get assignedStaff;
/// Create a copy of FleetJob
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FleetJobCopyWith<FleetJob> get copyWith => _$FleetJobCopyWithImpl<FleetJob>(this as FleetJob, _$identity);

  /// Serializes this FleetJob to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FleetJob&&(identical(other.id, id) || other.id == id)&&(identical(other.bookingNumber, bookingNumber) || other.bookingNumber == bookingNumber)&&(identical(other.driverId, driverId) || other.driverId == driverId)&&const DeepCollectionEquality().equals(other.vehicleId, vehicleId)&&const DeepCollectionEquality().equals(other.preTripPhotos, preTripPhotos)&&(identical(other.tripStatus, tripStatus) || other.tripStatus == tripStatus)&&(identical(other.customerName, customerName) || other.customerName == customerName)&&(identical(other.address, address) || other.address == address)&&(identical(other.mapUrl, mapUrl) || other.mapUrl == mapUrl)&&(identical(other.service, service) || other.service == service)&&(identical(other.eventSlot, eventSlot) || other.eventSlot == eventSlot)&&(identical(other.serviceStart, serviceStart) || other.serviceStart == serviceStart)&&(identical(other.serviceEnd, serviceEnd) || other.serviceEnd == serviceEnd)&&(identical(other.travelDistanceKm, travelDistanceKm) || other.travelDistanceKm == travelDistanceKm)&&(identical(other.pocName, pocName) || other.pocName == pocName)&&(identical(other.pocPhone, pocPhone) || other.pocPhone == pocPhone)&&const DeepCollectionEquality().equals(other.assignedStaff, assignedStaff));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,bookingNumber,driverId,const DeepCollectionEquality().hash(vehicleId),const DeepCollectionEquality().hash(preTripPhotos),tripStatus,customerName,address,mapUrl,service,eventSlot,serviceStart,serviceEnd,travelDistanceKm,pocName,pocPhone,const DeepCollectionEquality().hash(assignedStaff));

@override
String toString() {
  return 'FleetJob(id: $id, bookingNumber: $bookingNumber, driverId: $driverId, vehicleId: $vehicleId, preTripPhotos: $preTripPhotos, tripStatus: $tripStatus, customerName: $customerName, address: $address, mapUrl: $mapUrl, service: $service, eventSlot: $eventSlot, serviceStart: $serviceStart, serviceEnd: $serviceEnd, travelDistanceKm: $travelDistanceKm, pocName: $pocName, pocPhone: $pocPhone, assignedStaff: $assignedStaff)';
}


}

/// @nodoc
abstract mixin class $FleetJobCopyWith<$Res>  {
  factory $FleetJobCopyWith(FleetJob value, $Res Function(FleetJob) _then) = _$FleetJobCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: '_id') String id, String bookingNumber, String? driverId, dynamic vehicleId, List<String> preTripPhotos, String tripStatus, String customerName, String? address, String? mapUrl, String service, String? eventSlot, DateTime serviceStart, DateTime serviceEnd, double travelDistanceKm, String? pocName, String? pocPhone, List<Map<String, dynamic>> assignedStaff
});




}
/// @nodoc
class _$FleetJobCopyWithImpl<$Res>
    implements $FleetJobCopyWith<$Res> {
  _$FleetJobCopyWithImpl(this._self, this._then);

  final FleetJob _self;
  final $Res Function(FleetJob) _then;

/// Create a copy of FleetJob
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? bookingNumber = null,Object? driverId = freezed,Object? vehicleId = freezed,Object? preTripPhotos = null,Object? tripStatus = null,Object? customerName = null,Object? address = freezed,Object? mapUrl = freezed,Object? service = null,Object? eventSlot = freezed,Object? serviceStart = null,Object? serviceEnd = null,Object? travelDistanceKm = null,Object? pocName = freezed,Object? pocPhone = freezed,Object? assignedStaff = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,bookingNumber: null == bookingNumber ? _self.bookingNumber : bookingNumber // ignore: cast_nullable_to_non_nullable
as String,driverId: freezed == driverId ? _self.driverId : driverId // ignore: cast_nullable_to_non_nullable
as String?,vehicleId: freezed == vehicleId ? _self.vehicleId : vehicleId // ignore: cast_nullable_to_non_nullable
as dynamic,preTripPhotos: null == preTripPhotos ? _self.preTripPhotos : preTripPhotos // ignore: cast_nullable_to_non_nullable
as List<String>,tripStatus: null == tripStatus ? _self.tripStatus : tripStatus // ignore: cast_nullable_to_non_nullable
as String,customerName: null == customerName ? _self.customerName : customerName // ignore: cast_nullable_to_non_nullable
as String,address: freezed == address ? _self.address : address // ignore: cast_nullable_to_non_nullable
as String?,mapUrl: freezed == mapUrl ? _self.mapUrl : mapUrl // ignore: cast_nullable_to_non_nullable
as String?,service: null == service ? _self.service : service // ignore: cast_nullable_to_non_nullable
as String,eventSlot: freezed == eventSlot ? _self.eventSlot : eventSlot // ignore: cast_nullable_to_non_nullable
as String?,serviceStart: null == serviceStart ? _self.serviceStart : serviceStart // ignore: cast_nullable_to_non_nullable
as DateTime,serviceEnd: null == serviceEnd ? _self.serviceEnd : serviceEnd // ignore: cast_nullable_to_non_nullable
as DateTime,travelDistanceKm: null == travelDistanceKm ? _self.travelDistanceKm : travelDistanceKm // ignore: cast_nullable_to_non_nullable
as double,pocName: freezed == pocName ? _self.pocName : pocName // ignore: cast_nullable_to_non_nullable
as String?,pocPhone: freezed == pocPhone ? _self.pocPhone : pocPhone // ignore: cast_nullable_to_non_nullable
as String?,assignedStaff: null == assignedStaff ? _self.assignedStaff : assignedStaff // ignore: cast_nullable_to_non_nullable
as List<Map<String, dynamic>>,
  ));
}

}


/// Adds pattern-matching-related methods to [FleetJob].
extension FleetJobPatterns on FleetJob {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _FleetJob value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _FleetJob() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _FleetJob value)  $default,){
final _that = this;
switch (_that) {
case _FleetJob():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _FleetJob value)?  $default,){
final _that = this;
switch (_that) {
case _FleetJob() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: '_id')  String id,  String bookingNumber,  String? driverId,  dynamic vehicleId,  List<String> preTripPhotos,  String tripStatus,  String customerName,  String? address,  String? mapUrl,  String service,  String? eventSlot,  DateTime serviceStart,  DateTime serviceEnd,  double travelDistanceKm,  String? pocName,  String? pocPhone,  List<Map<String, dynamic>> assignedStaff)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FleetJob() when $default != null:
return $default(_that.id,_that.bookingNumber,_that.driverId,_that.vehicleId,_that.preTripPhotos,_that.tripStatus,_that.customerName,_that.address,_that.mapUrl,_that.service,_that.eventSlot,_that.serviceStart,_that.serviceEnd,_that.travelDistanceKm,_that.pocName,_that.pocPhone,_that.assignedStaff);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: '_id')  String id,  String bookingNumber,  String? driverId,  dynamic vehicleId,  List<String> preTripPhotos,  String tripStatus,  String customerName,  String? address,  String? mapUrl,  String service,  String? eventSlot,  DateTime serviceStart,  DateTime serviceEnd,  double travelDistanceKm,  String? pocName,  String? pocPhone,  List<Map<String, dynamic>> assignedStaff)  $default,) {final _that = this;
switch (_that) {
case _FleetJob():
return $default(_that.id,_that.bookingNumber,_that.driverId,_that.vehicleId,_that.preTripPhotos,_that.tripStatus,_that.customerName,_that.address,_that.mapUrl,_that.service,_that.eventSlot,_that.serviceStart,_that.serviceEnd,_that.travelDistanceKm,_that.pocName,_that.pocPhone,_that.assignedStaff);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: '_id')  String id,  String bookingNumber,  String? driverId,  dynamic vehicleId,  List<String> preTripPhotos,  String tripStatus,  String customerName,  String? address,  String? mapUrl,  String service,  String? eventSlot,  DateTime serviceStart,  DateTime serviceEnd,  double travelDistanceKm,  String? pocName,  String? pocPhone,  List<Map<String, dynamic>> assignedStaff)?  $default,) {final _that = this;
switch (_that) {
case _FleetJob() when $default != null:
return $default(_that.id,_that.bookingNumber,_that.driverId,_that.vehicleId,_that.preTripPhotos,_that.tripStatus,_that.customerName,_that.address,_that.mapUrl,_that.service,_that.eventSlot,_that.serviceStart,_that.serviceEnd,_that.travelDistanceKm,_that.pocName,_that.pocPhone,_that.assignedStaff);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _FleetJob implements FleetJob {
  const _FleetJob({@JsonKey(name: '_id') required this.id, required this.bookingNumber, this.driverId, this.vehicleId, final  List<String> preTripPhotos = const [], this.tripStatus = 'unassigned', required this.customerName, this.address, this.mapUrl, required this.service, this.eventSlot, required this.serviceStart, required this.serviceEnd, this.travelDistanceKm = 0, this.pocName, this.pocPhone, final  List<Map<String, dynamic>> assignedStaff = const []}): _preTripPhotos = preTripPhotos,_assignedStaff = assignedStaff;
  factory _FleetJob.fromJson(Map<String, dynamic> json) => _$FleetJobFromJson(json);

@override@JsonKey(name: '_id') final  String id;
@override final  String bookingNumber;
@override final  String? driverId;
@override final  dynamic vehicleId;
// Could be String or a Map depending on populate
 final  List<String> _preTripPhotos;
// Could be String or a Map depending on populate
@override@JsonKey() List<String> get preTripPhotos {
  if (_preTripPhotos is EqualUnmodifiableListView) return _preTripPhotos;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_preTripPhotos);
}

@override@JsonKey() final  String tripStatus;
@override final  String customerName;
@override final  String? address;
@override final  String? mapUrl;
@override final  String service;
@override final  String? eventSlot;
@override final  DateTime serviceStart;
@override final  DateTime serviceEnd;
@override@JsonKey() final  double travelDistanceKm;
@override final  String? pocName;
@override final  String? pocPhone;
 final  List<Map<String, dynamic>> _assignedStaff;
@override@JsonKey() List<Map<String, dynamic>> get assignedStaff {
  if (_assignedStaff is EqualUnmodifiableListView) return _assignedStaff;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_assignedStaff);
}


/// Create a copy of FleetJob
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FleetJobCopyWith<_FleetJob> get copyWith => __$FleetJobCopyWithImpl<_FleetJob>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$FleetJobToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _FleetJob&&(identical(other.id, id) || other.id == id)&&(identical(other.bookingNumber, bookingNumber) || other.bookingNumber == bookingNumber)&&(identical(other.driverId, driverId) || other.driverId == driverId)&&const DeepCollectionEquality().equals(other.vehicleId, vehicleId)&&const DeepCollectionEquality().equals(other._preTripPhotos, _preTripPhotos)&&(identical(other.tripStatus, tripStatus) || other.tripStatus == tripStatus)&&(identical(other.customerName, customerName) || other.customerName == customerName)&&(identical(other.address, address) || other.address == address)&&(identical(other.mapUrl, mapUrl) || other.mapUrl == mapUrl)&&(identical(other.service, service) || other.service == service)&&(identical(other.eventSlot, eventSlot) || other.eventSlot == eventSlot)&&(identical(other.serviceStart, serviceStart) || other.serviceStart == serviceStart)&&(identical(other.serviceEnd, serviceEnd) || other.serviceEnd == serviceEnd)&&(identical(other.travelDistanceKm, travelDistanceKm) || other.travelDistanceKm == travelDistanceKm)&&(identical(other.pocName, pocName) || other.pocName == pocName)&&(identical(other.pocPhone, pocPhone) || other.pocPhone == pocPhone)&&const DeepCollectionEquality().equals(other._assignedStaff, _assignedStaff));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,bookingNumber,driverId,const DeepCollectionEquality().hash(vehicleId),const DeepCollectionEquality().hash(_preTripPhotos),tripStatus,customerName,address,mapUrl,service,eventSlot,serviceStart,serviceEnd,travelDistanceKm,pocName,pocPhone,const DeepCollectionEquality().hash(_assignedStaff));

@override
String toString() {
  return 'FleetJob(id: $id, bookingNumber: $bookingNumber, driverId: $driverId, vehicleId: $vehicleId, preTripPhotos: $preTripPhotos, tripStatus: $tripStatus, customerName: $customerName, address: $address, mapUrl: $mapUrl, service: $service, eventSlot: $eventSlot, serviceStart: $serviceStart, serviceEnd: $serviceEnd, travelDistanceKm: $travelDistanceKm, pocName: $pocName, pocPhone: $pocPhone, assignedStaff: $assignedStaff)';
}


}

/// @nodoc
abstract mixin class _$FleetJobCopyWith<$Res> implements $FleetJobCopyWith<$Res> {
  factory _$FleetJobCopyWith(_FleetJob value, $Res Function(_FleetJob) _then) = __$FleetJobCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: '_id') String id, String bookingNumber, String? driverId, dynamic vehicleId, List<String> preTripPhotos, String tripStatus, String customerName, String? address, String? mapUrl, String service, String? eventSlot, DateTime serviceStart, DateTime serviceEnd, double travelDistanceKm, String? pocName, String? pocPhone, List<Map<String, dynamic>> assignedStaff
});




}
/// @nodoc
class __$FleetJobCopyWithImpl<$Res>
    implements _$FleetJobCopyWith<$Res> {
  __$FleetJobCopyWithImpl(this._self, this._then);

  final _FleetJob _self;
  final $Res Function(_FleetJob) _then;

/// Create a copy of FleetJob
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? bookingNumber = null,Object? driverId = freezed,Object? vehicleId = freezed,Object? preTripPhotos = null,Object? tripStatus = null,Object? customerName = null,Object? address = freezed,Object? mapUrl = freezed,Object? service = null,Object? eventSlot = freezed,Object? serviceStart = null,Object? serviceEnd = null,Object? travelDistanceKm = null,Object? pocName = freezed,Object? pocPhone = freezed,Object? assignedStaff = null,}) {
  return _then(_FleetJob(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,bookingNumber: null == bookingNumber ? _self.bookingNumber : bookingNumber // ignore: cast_nullable_to_non_nullable
as String,driverId: freezed == driverId ? _self.driverId : driverId // ignore: cast_nullable_to_non_nullable
as String?,vehicleId: freezed == vehicleId ? _self.vehicleId : vehicleId // ignore: cast_nullable_to_non_nullable
as dynamic,preTripPhotos: null == preTripPhotos ? _self._preTripPhotos : preTripPhotos // ignore: cast_nullable_to_non_nullable
as List<String>,tripStatus: null == tripStatus ? _self.tripStatus : tripStatus // ignore: cast_nullable_to_non_nullable
as String,customerName: null == customerName ? _self.customerName : customerName // ignore: cast_nullable_to_non_nullable
as String,address: freezed == address ? _self.address : address // ignore: cast_nullable_to_non_nullable
as String?,mapUrl: freezed == mapUrl ? _self.mapUrl : mapUrl // ignore: cast_nullable_to_non_nullable
as String?,service: null == service ? _self.service : service // ignore: cast_nullable_to_non_nullable
as String,eventSlot: freezed == eventSlot ? _self.eventSlot : eventSlot // ignore: cast_nullable_to_non_nullable
as String?,serviceStart: null == serviceStart ? _self.serviceStart : serviceStart // ignore: cast_nullable_to_non_nullable
as DateTime,serviceEnd: null == serviceEnd ? _self.serviceEnd : serviceEnd // ignore: cast_nullable_to_non_nullable
as DateTime,travelDistanceKm: null == travelDistanceKm ? _self.travelDistanceKm : travelDistanceKm // ignore: cast_nullable_to_non_nullable
as double,pocName: freezed == pocName ? _self.pocName : pocName // ignore: cast_nullable_to_non_nullable
as String?,pocPhone: freezed == pocPhone ? _self.pocPhone : pocPhone // ignore: cast_nullable_to_non_nullable
as String?,assignedStaff: null == assignedStaff ? _self._assignedStaff : assignedStaff // ignore: cast_nullable_to_non_nullable
as List<Map<String, dynamic>>,
  ));
}


}


/// @nodoc
mixin _$AccidentReport {

@JsonKey(name: '_id') String get id;@JsonKey(fromJson: _driverName) String get driver;@JsonKey(fromJson: _vehicleName) String get vehicle;@JsonKey(fromJson: _jobRef) String? get job; AccidentLocation get location; List<String> get photos; String get description; AccidentOpposite? get opposite; String get status; DateTime? get createdAt;
/// Create a copy of AccidentReport
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AccidentReportCopyWith<AccidentReport> get copyWith => _$AccidentReportCopyWithImpl<AccidentReport>(this as AccidentReport, _$identity);

  /// Serializes this AccidentReport to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AccidentReport&&(identical(other.id, id) || other.id == id)&&(identical(other.driver, driver) || other.driver == driver)&&(identical(other.vehicle, vehicle) || other.vehicle == vehicle)&&(identical(other.job, job) || other.job == job)&&(identical(other.location, location) || other.location == location)&&const DeepCollectionEquality().equals(other.photos, photos)&&(identical(other.description, description) || other.description == description)&&(identical(other.opposite, opposite) || other.opposite == opposite)&&(identical(other.status, status) || other.status == status)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,driver,vehicle,job,location,const DeepCollectionEquality().hash(photos),description,opposite,status,createdAt);

@override
String toString() {
  return 'AccidentReport(id: $id, driver: $driver, vehicle: $vehicle, job: $job, location: $location, photos: $photos, description: $description, opposite: $opposite, status: $status, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class $AccidentReportCopyWith<$Res>  {
  factory $AccidentReportCopyWith(AccidentReport value, $Res Function(AccidentReport) _then) = _$AccidentReportCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: '_id') String id,@JsonKey(fromJson: _driverName) String driver,@JsonKey(fromJson: _vehicleName) String vehicle,@JsonKey(fromJson: _jobRef) String? job, AccidentLocation location, List<String> photos, String description, AccidentOpposite? opposite, String status, DateTime? createdAt
});


$AccidentLocationCopyWith<$Res> get location;$AccidentOppositeCopyWith<$Res>? get opposite;

}
/// @nodoc
class _$AccidentReportCopyWithImpl<$Res>
    implements $AccidentReportCopyWith<$Res> {
  _$AccidentReportCopyWithImpl(this._self, this._then);

  final AccidentReport _self;
  final $Res Function(AccidentReport) _then;

/// Create a copy of AccidentReport
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? driver = null,Object? vehicle = null,Object? job = freezed,Object? location = null,Object? photos = null,Object? description = null,Object? opposite = freezed,Object? status = null,Object? createdAt = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,driver: null == driver ? _self.driver : driver // ignore: cast_nullable_to_non_nullable
as String,vehicle: null == vehicle ? _self.vehicle : vehicle // ignore: cast_nullable_to_non_nullable
as String,job: freezed == job ? _self.job : job // ignore: cast_nullable_to_non_nullable
as String?,location: null == location ? _self.location : location // ignore: cast_nullable_to_non_nullable
as AccidentLocation,photos: null == photos ? _self.photos : photos // ignore: cast_nullable_to_non_nullable
as List<String>,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,opposite: freezed == opposite ? _self.opposite : opposite // ignore: cast_nullable_to_non_nullable
as AccidentOpposite?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}
/// Create a copy of AccidentReport
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AccidentLocationCopyWith<$Res> get location {
  
  return $AccidentLocationCopyWith<$Res>(_self.location, (value) {
    return _then(_self.copyWith(location: value));
  });
}/// Create a copy of AccidentReport
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AccidentOppositeCopyWith<$Res>? get opposite {
    if (_self.opposite == null) {
    return null;
  }

  return $AccidentOppositeCopyWith<$Res>(_self.opposite!, (value) {
    return _then(_self.copyWith(opposite: value));
  });
}
}


/// Adds pattern-matching-related methods to [AccidentReport].
extension AccidentReportPatterns on AccidentReport {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AccidentReport value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AccidentReport() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AccidentReport value)  $default,){
final _that = this;
switch (_that) {
case _AccidentReport():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AccidentReport value)?  $default,){
final _that = this;
switch (_that) {
case _AccidentReport() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: '_id')  String id, @JsonKey(fromJson: _driverName)  String driver, @JsonKey(fromJson: _vehicleName)  String vehicle, @JsonKey(fromJson: _jobRef)  String? job,  AccidentLocation location,  List<String> photos,  String description,  AccidentOpposite? opposite,  String status,  DateTime? createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AccidentReport() when $default != null:
return $default(_that.id,_that.driver,_that.vehicle,_that.job,_that.location,_that.photos,_that.description,_that.opposite,_that.status,_that.createdAt);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: '_id')  String id, @JsonKey(fromJson: _driverName)  String driver, @JsonKey(fromJson: _vehicleName)  String vehicle, @JsonKey(fromJson: _jobRef)  String? job,  AccidentLocation location,  List<String> photos,  String description,  AccidentOpposite? opposite,  String status,  DateTime? createdAt)  $default,) {final _that = this;
switch (_that) {
case _AccidentReport():
return $default(_that.id,_that.driver,_that.vehicle,_that.job,_that.location,_that.photos,_that.description,_that.opposite,_that.status,_that.createdAt);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: '_id')  String id, @JsonKey(fromJson: _driverName)  String driver, @JsonKey(fromJson: _vehicleName)  String vehicle, @JsonKey(fromJson: _jobRef)  String? job,  AccidentLocation location,  List<String> photos,  String description,  AccidentOpposite? opposite,  String status,  DateTime? createdAt)?  $default,) {final _that = this;
switch (_that) {
case _AccidentReport() when $default != null:
return $default(_that.id,_that.driver,_that.vehicle,_that.job,_that.location,_that.photos,_that.description,_that.opposite,_that.status,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AccidentReport implements AccidentReport {
  const _AccidentReport({@JsonKey(name: '_id') required this.id, @JsonKey(fromJson: _driverName) required this.driver, @JsonKey(fromJson: _vehicleName) required this.vehicle, @JsonKey(fromJson: _jobRef) this.job, required this.location, required final  List<String> photos, required this.description, this.opposite, required this.status, this.createdAt}): _photos = photos;
  factory _AccidentReport.fromJson(Map<String, dynamic> json) => _$AccidentReportFromJson(json);

@override@JsonKey(name: '_id') final  String id;
@override@JsonKey(fromJson: _driverName) final  String driver;
@override@JsonKey(fromJson: _vehicleName) final  String vehicle;
@override@JsonKey(fromJson: _jobRef) final  String? job;
@override final  AccidentLocation location;
 final  List<String> _photos;
@override List<String> get photos {
  if (_photos is EqualUnmodifiableListView) return _photos;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_photos);
}

@override final  String description;
@override final  AccidentOpposite? opposite;
@override final  String status;
@override final  DateTime? createdAt;

/// Create a copy of AccidentReport
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AccidentReportCopyWith<_AccidentReport> get copyWith => __$AccidentReportCopyWithImpl<_AccidentReport>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AccidentReportToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AccidentReport&&(identical(other.id, id) || other.id == id)&&(identical(other.driver, driver) || other.driver == driver)&&(identical(other.vehicle, vehicle) || other.vehicle == vehicle)&&(identical(other.job, job) || other.job == job)&&(identical(other.location, location) || other.location == location)&&const DeepCollectionEquality().equals(other._photos, _photos)&&(identical(other.description, description) || other.description == description)&&(identical(other.opposite, opposite) || other.opposite == opposite)&&(identical(other.status, status) || other.status == status)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,driver,vehicle,job,location,const DeepCollectionEquality().hash(_photos),description,opposite,status,createdAt);

@override
String toString() {
  return 'AccidentReport(id: $id, driver: $driver, vehicle: $vehicle, job: $job, location: $location, photos: $photos, description: $description, opposite: $opposite, status: $status, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$AccidentReportCopyWith<$Res> implements $AccidentReportCopyWith<$Res> {
  factory _$AccidentReportCopyWith(_AccidentReport value, $Res Function(_AccidentReport) _then) = __$AccidentReportCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: '_id') String id,@JsonKey(fromJson: _driverName) String driver,@JsonKey(fromJson: _vehicleName) String vehicle,@JsonKey(fromJson: _jobRef) String? job, AccidentLocation location, List<String> photos, String description, AccidentOpposite? opposite, String status, DateTime? createdAt
});


@override $AccidentLocationCopyWith<$Res> get location;@override $AccidentOppositeCopyWith<$Res>? get opposite;

}
/// @nodoc
class __$AccidentReportCopyWithImpl<$Res>
    implements _$AccidentReportCopyWith<$Res> {
  __$AccidentReportCopyWithImpl(this._self, this._then);

  final _AccidentReport _self;
  final $Res Function(_AccidentReport) _then;

/// Create a copy of AccidentReport
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? driver = null,Object? vehicle = null,Object? job = freezed,Object? location = null,Object? photos = null,Object? description = null,Object? opposite = freezed,Object? status = null,Object? createdAt = freezed,}) {
  return _then(_AccidentReport(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,driver: null == driver ? _self.driver : driver // ignore: cast_nullable_to_non_nullable
as String,vehicle: null == vehicle ? _self.vehicle : vehicle // ignore: cast_nullable_to_non_nullable
as String,job: freezed == job ? _self.job : job // ignore: cast_nullable_to_non_nullable
as String?,location: null == location ? _self.location : location // ignore: cast_nullable_to_non_nullable
as AccidentLocation,photos: null == photos ? _self._photos : photos // ignore: cast_nullable_to_non_nullable
as List<String>,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,opposite: freezed == opposite ? _self.opposite : opposite // ignore: cast_nullable_to_non_nullable
as AccidentOpposite?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

/// Create a copy of AccidentReport
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AccidentLocationCopyWith<$Res> get location {
  
  return $AccidentLocationCopyWith<$Res>(_self.location, (value) {
    return _then(_self.copyWith(location: value));
  });
}/// Create a copy of AccidentReport
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AccidentOppositeCopyWith<$Res>? get opposite {
    if (_self.opposite == null) {
    return null;
  }

  return $AccidentOppositeCopyWith<$Res>(_self.opposite!, (value) {
    return _then(_self.copyWith(opposite: value));
  });
}
}


/// @nodoc
mixin _$AccidentOpposite {

 String get name; String get phone; String get vehicleNumber; String get notes;
/// Create a copy of AccidentOpposite
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AccidentOppositeCopyWith<AccidentOpposite> get copyWith => _$AccidentOppositeCopyWithImpl<AccidentOpposite>(this as AccidentOpposite, _$identity);

  /// Serializes this AccidentOpposite to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AccidentOpposite&&(identical(other.name, name) || other.name == name)&&(identical(other.phone, phone) || other.phone == phone)&&(identical(other.vehicleNumber, vehicleNumber) || other.vehicleNumber == vehicleNumber)&&(identical(other.notes, notes) || other.notes == notes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,phone,vehicleNumber,notes);

@override
String toString() {
  return 'AccidentOpposite(name: $name, phone: $phone, vehicleNumber: $vehicleNumber, notes: $notes)';
}


}

/// @nodoc
abstract mixin class $AccidentOppositeCopyWith<$Res>  {
  factory $AccidentOppositeCopyWith(AccidentOpposite value, $Res Function(AccidentOpposite) _then) = _$AccidentOppositeCopyWithImpl;
@useResult
$Res call({
 String name, String phone, String vehicleNumber, String notes
});




}
/// @nodoc
class _$AccidentOppositeCopyWithImpl<$Res>
    implements $AccidentOppositeCopyWith<$Res> {
  _$AccidentOppositeCopyWithImpl(this._self, this._then);

  final AccidentOpposite _self;
  final $Res Function(AccidentOpposite) _then;

/// Create a copy of AccidentOpposite
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? phone = null,Object? vehicleNumber = null,Object? notes = null,}) {
  return _then(_self.copyWith(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,phone: null == phone ? _self.phone : phone // ignore: cast_nullable_to_non_nullable
as String,vehicleNumber: null == vehicleNumber ? _self.vehicleNumber : vehicleNumber // ignore: cast_nullable_to_non_nullable
as String,notes: null == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [AccidentOpposite].
extension AccidentOppositePatterns on AccidentOpposite {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AccidentOpposite value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AccidentOpposite() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AccidentOpposite value)  $default,){
final _that = this;
switch (_that) {
case _AccidentOpposite():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AccidentOpposite value)?  $default,){
final _that = this;
switch (_that) {
case _AccidentOpposite() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name,  String phone,  String vehicleNumber,  String notes)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AccidentOpposite() when $default != null:
return $default(_that.name,_that.phone,_that.vehicleNumber,_that.notes);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name,  String phone,  String vehicleNumber,  String notes)  $default,) {final _that = this;
switch (_that) {
case _AccidentOpposite():
return $default(_that.name,_that.phone,_that.vehicleNumber,_that.notes);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name,  String phone,  String vehicleNumber,  String notes)?  $default,) {final _that = this;
switch (_that) {
case _AccidentOpposite() when $default != null:
return $default(_that.name,_that.phone,_that.vehicleNumber,_that.notes);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AccidentOpposite implements AccidentOpposite {
  const _AccidentOpposite({this.name = '', this.phone = '', this.vehicleNumber = '', this.notes = ''});
  factory _AccidentOpposite.fromJson(Map<String, dynamic> json) => _$AccidentOppositeFromJson(json);

@override@JsonKey() final  String name;
@override@JsonKey() final  String phone;
@override@JsonKey() final  String vehicleNumber;
@override@JsonKey() final  String notes;

/// Create a copy of AccidentOpposite
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AccidentOppositeCopyWith<_AccidentOpposite> get copyWith => __$AccidentOppositeCopyWithImpl<_AccidentOpposite>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AccidentOppositeToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AccidentOpposite&&(identical(other.name, name) || other.name == name)&&(identical(other.phone, phone) || other.phone == phone)&&(identical(other.vehicleNumber, vehicleNumber) || other.vehicleNumber == vehicleNumber)&&(identical(other.notes, notes) || other.notes == notes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,phone,vehicleNumber,notes);

@override
String toString() {
  return 'AccidentOpposite(name: $name, phone: $phone, vehicleNumber: $vehicleNumber, notes: $notes)';
}


}

/// @nodoc
abstract mixin class _$AccidentOppositeCopyWith<$Res> implements $AccidentOppositeCopyWith<$Res> {
  factory _$AccidentOppositeCopyWith(_AccidentOpposite value, $Res Function(_AccidentOpposite) _then) = __$AccidentOppositeCopyWithImpl;
@override @useResult
$Res call({
 String name, String phone, String vehicleNumber, String notes
});




}
/// @nodoc
class __$AccidentOppositeCopyWithImpl<$Res>
    implements _$AccidentOppositeCopyWith<$Res> {
  __$AccidentOppositeCopyWithImpl(this._self, this._then);

  final _AccidentOpposite _self;
  final $Res Function(_AccidentOpposite) _then;

/// Create a copy of AccidentOpposite
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? phone = null,Object? vehicleNumber = null,Object? notes = null,}) {
  return _then(_AccidentOpposite(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,phone: null == phone ? _self.phone : phone // ignore: cast_nullable_to_non_nullable
as String,vehicleNumber: null == vehicleNumber ? _self.vehicleNumber : vehicleNumber // ignore: cast_nullable_to_non_nullable
as String,notes: null == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$AccidentLocation {

 double get lat; double get lng; String? get address;
/// Create a copy of AccidentLocation
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AccidentLocationCopyWith<AccidentLocation> get copyWith => _$AccidentLocationCopyWithImpl<AccidentLocation>(this as AccidentLocation, _$identity);

  /// Serializes this AccidentLocation to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AccidentLocation&&(identical(other.lat, lat) || other.lat == lat)&&(identical(other.lng, lng) || other.lng == lng)&&(identical(other.address, address) || other.address == address));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,lat,lng,address);

@override
String toString() {
  return 'AccidentLocation(lat: $lat, lng: $lng, address: $address)';
}


}

/// @nodoc
abstract mixin class $AccidentLocationCopyWith<$Res>  {
  factory $AccidentLocationCopyWith(AccidentLocation value, $Res Function(AccidentLocation) _then) = _$AccidentLocationCopyWithImpl;
@useResult
$Res call({
 double lat, double lng, String? address
});




}
/// @nodoc
class _$AccidentLocationCopyWithImpl<$Res>
    implements $AccidentLocationCopyWith<$Res> {
  _$AccidentLocationCopyWithImpl(this._self, this._then);

  final AccidentLocation _self;
  final $Res Function(AccidentLocation) _then;

/// Create a copy of AccidentLocation
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? lat = null,Object? lng = null,Object? address = freezed,}) {
  return _then(_self.copyWith(
lat: null == lat ? _self.lat : lat // ignore: cast_nullable_to_non_nullable
as double,lng: null == lng ? _self.lng : lng // ignore: cast_nullable_to_non_nullable
as double,address: freezed == address ? _self.address : address // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [AccidentLocation].
extension AccidentLocationPatterns on AccidentLocation {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AccidentLocation value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AccidentLocation() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AccidentLocation value)  $default,){
final _that = this;
switch (_that) {
case _AccidentLocation():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AccidentLocation value)?  $default,){
final _that = this;
switch (_that) {
case _AccidentLocation() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( double lat,  double lng,  String? address)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AccidentLocation() when $default != null:
return $default(_that.lat,_that.lng,_that.address);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( double lat,  double lng,  String? address)  $default,) {final _that = this;
switch (_that) {
case _AccidentLocation():
return $default(_that.lat,_that.lng,_that.address);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( double lat,  double lng,  String? address)?  $default,) {final _that = this;
switch (_that) {
case _AccidentLocation() when $default != null:
return $default(_that.lat,_that.lng,_that.address);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AccidentLocation implements AccidentLocation {
  const _AccidentLocation({required this.lat, required this.lng, this.address});
  factory _AccidentLocation.fromJson(Map<String, dynamic> json) => _$AccidentLocationFromJson(json);

@override final  double lat;
@override final  double lng;
@override final  String? address;

/// Create a copy of AccidentLocation
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AccidentLocationCopyWith<_AccidentLocation> get copyWith => __$AccidentLocationCopyWithImpl<_AccidentLocation>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AccidentLocationToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AccidentLocation&&(identical(other.lat, lat) || other.lat == lat)&&(identical(other.lng, lng) || other.lng == lng)&&(identical(other.address, address) || other.address == address));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,lat,lng,address);

@override
String toString() {
  return 'AccidentLocation(lat: $lat, lng: $lng, address: $address)';
}


}

/// @nodoc
abstract mixin class _$AccidentLocationCopyWith<$Res> implements $AccidentLocationCopyWith<$Res> {
  factory _$AccidentLocationCopyWith(_AccidentLocation value, $Res Function(_AccidentLocation) _then) = __$AccidentLocationCopyWithImpl;
@override @useResult
$Res call({
 double lat, double lng, String? address
});




}
/// @nodoc
class __$AccidentLocationCopyWithImpl<$Res>
    implements _$AccidentLocationCopyWith<$Res> {
  __$AccidentLocationCopyWithImpl(this._self, this._then);

  final _AccidentLocation _self;
  final $Res Function(_AccidentLocation) _then;

/// Create a copy of AccidentLocation
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? lat = null,Object? lng = null,Object? address = freezed,}) {
  return _then(_AccidentLocation(
lat: null == lat ? _self.lat : lat // ignore: cast_nullable_to_non_nullable
as double,lng: null == lng ? _self.lng : lng // ignore: cast_nullable_to_non_nullable
as double,address: freezed == address ? _self.address : address // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$DriverReview {

@JsonKey(name: '_id') String get id; String get driver; String get artist; String get job; int get rating; String? get comment;
/// Create a copy of DriverReview
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DriverReviewCopyWith<DriverReview> get copyWith => _$DriverReviewCopyWithImpl<DriverReview>(this as DriverReview, _$identity);

  /// Serializes this DriverReview to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DriverReview&&(identical(other.id, id) || other.id == id)&&(identical(other.driver, driver) || other.driver == driver)&&(identical(other.artist, artist) || other.artist == artist)&&(identical(other.job, job) || other.job == job)&&(identical(other.rating, rating) || other.rating == rating)&&(identical(other.comment, comment) || other.comment == comment));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,driver,artist,job,rating,comment);

@override
String toString() {
  return 'DriverReview(id: $id, driver: $driver, artist: $artist, job: $job, rating: $rating, comment: $comment)';
}


}

/// @nodoc
abstract mixin class $DriverReviewCopyWith<$Res>  {
  factory $DriverReviewCopyWith(DriverReview value, $Res Function(DriverReview) _then) = _$DriverReviewCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: '_id') String id, String driver, String artist, String job, int rating, String? comment
});




}
/// @nodoc
class _$DriverReviewCopyWithImpl<$Res>
    implements $DriverReviewCopyWith<$Res> {
  _$DriverReviewCopyWithImpl(this._self, this._then);

  final DriverReview _self;
  final $Res Function(DriverReview) _then;

/// Create a copy of DriverReview
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? driver = null,Object? artist = null,Object? job = null,Object? rating = null,Object? comment = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,driver: null == driver ? _self.driver : driver // ignore: cast_nullable_to_non_nullable
as String,artist: null == artist ? _self.artist : artist // ignore: cast_nullable_to_non_nullable
as String,job: null == job ? _self.job : job // ignore: cast_nullable_to_non_nullable
as String,rating: null == rating ? _self.rating : rating // ignore: cast_nullable_to_non_nullable
as int,comment: freezed == comment ? _self.comment : comment // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [DriverReview].
extension DriverReviewPatterns on DriverReview {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DriverReview value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DriverReview() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DriverReview value)  $default,){
final _that = this;
switch (_that) {
case _DriverReview():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DriverReview value)?  $default,){
final _that = this;
switch (_that) {
case _DriverReview() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: '_id')  String id,  String driver,  String artist,  String job,  int rating,  String? comment)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DriverReview() when $default != null:
return $default(_that.id,_that.driver,_that.artist,_that.job,_that.rating,_that.comment);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: '_id')  String id,  String driver,  String artist,  String job,  int rating,  String? comment)  $default,) {final _that = this;
switch (_that) {
case _DriverReview():
return $default(_that.id,_that.driver,_that.artist,_that.job,_that.rating,_that.comment);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: '_id')  String id,  String driver,  String artist,  String job,  int rating,  String? comment)?  $default,) {final _that = this;
switch (_that) {
case _DriverReview() when $default != null:
return $default(_that.id,_that.driver,_that.artist,_that.job,_that.rating,_that.comment);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _DriverReview implements DriverReview {
  const _DriverReview({@JsonKey(name: '_id') required this.id, required this.driver, required this.artist, required this.job, required this.rating, this.comment});
  factory _DriverReview.fromJson(Map<String, dynamic> json) => _$DriverReviewFromJson(json);

@override@JsonKey(name: '_id') final  String id;
@override final  String driver;
@override final  String artist;
@override final  String job;
@override final  int rating;
@override final  String? comment;

/// Create a copy of DriverReview
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DriverReviewCopyWith<_DriverReview> get copyWith => __$DriverReviewCopyWithImpl<_DriverReview>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DriverReviewToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DriverReview&&(identical(other.id, id) || other.id == id)&&(identical(other.driver, driver) || other.driver == driver)&&(identical(other.artist, artist) || other.artist == artist)&&(identical(other.job, job) || other.job == job)&&(identical(other.rating, rating) || other.rating == rating)&&(identical(other.comment, comment) || other.comment == comment));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,driver,artist,job,rating,comment);

@override
String toString() {
  return 'DriverReview(id: $id, driver: $driver, artist: $artist, job: $job, rating: $rating, comment: $comment)';
}


}

/// @nodoc
abstract mixin class _$DriverReviewCopyWith<$Res> implements $DriverReviewCopyWith<$Res> {
  factory _$DriverReviewCopyWith(_DriverReview value, $Res Function(_DriverReview) _then) = __$DriverReviewCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: '_id') String id, String driver, String artist, String job, int rating, String? comment
});




}
/// @nodoc
class __$DriverReviewCopyWithImpl<$Res>
    implements _$DriverReviewCopyWith<$Res> {
  __$DriverReviewCopyWithImpl(this._self, this._then);

  final _DriverReview _self;
  final $Res Function(_DriverReview) _then;

/// Create a copy of DriverReview
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? driver = null,Object? artist = null,Object? job = null,Object? rating = null,Object? comment = freezed,}) {
  return _then(_DriverReview(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,driver: null == driver ? _self.driver : driver // ignore: cast_nullable_to_non_nullable
as String,artist: null == artist ? _self.artist : artist // ignore: cast_nullable_to_non_nullable
as String,job: null == job ? _self.job : job // ignore: cast_nullable_to_non_nullable
as String,rating: null == rating ? _self.rating : rating // ignore: cast_nullable_to_non_nullable
as int,comment: freezed == comment ? _self.comment : comment // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$ServiceReminder {

@JsonKey(name: '_id') String get id; dynamic get vehicle; String get serviceType; DateTime? get dueDate; double? get dueKm; String get status; String? get notes;
/// Create a copy of ServiceReminder
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ServiceReminderCopyWith<ServiceReminder> get copyWith => _$ServiceReminderCopyWithImpl<ServiceReminder>(this as ServiceReminder, _$identity);

  /// Serializes this ServiceReminder to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ServiceReminder&&(identical(other.id, id) || other.id == id)&&const DeepCollectionEquality().equals(other.vehicle, vehicle)&&(identical(other.serviceType, serviceType) || other.serviceType == serviceType)&&(identical(other.dueDate, dueDate) || other.dueDate == dueDate)&&(identical(other.dueKm, dueKm) || other.dueKm == dueKm)&&(identical(other.status, status) || other.status == status)&&(identical(other.notes, notes) || other.notes == notes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,const DeepCollectionEquality().hash(vehicle),serviceType,dueDate,dueKm,status,notes);

@override
String toString() {
  return 'ServiceReminder(id: $id, vehicle: $vehicle, serviceType: $serviceType, dueDate: $dueDate, dueKm: $dueKm, status: $status, notes: $notes)';
}


}

/// @nodoc
abstract mixin class $ServiceReminderCopyWith<$Res>  {
  factory $ServiceReminderCopyWith(ServiceReminder value, $Res Function(ServiceReminder) _then) = _$ServiceReminderCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: '_id') String id, dynamic vehicle, String serviceType, DateTime? dueDate, double? dueKm, String status, String? notes
});




}
/// @nodoc
class _$ServiceReminderCopyWithImpl<$Res>
    implements $ServiceReminderCopyWith<$Res> {
  _$ServiceReminderCopyWithImpl(this._self, this._then);

  final ServiceReminder _self;
  final $Res Function(ServiceReminder) _then;

/// Create a copy of ServiceReminder
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? vehicle = freezed,Object? serviceType = null,Object? dueDate = freezed,Object? dueKm = freezed,Object? status = null,Object? notes = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,vehicle: freezed == vehicle ? _self.vehicle : vehicle // ignore: cast_nullable_to_non_nullable
as dynamic,serviceType: null == serviceType ? _self.serviceType : serviceType // ignore: cast_nullable_to_non_nullable
as String,dueDate: freezed == dueDate ? _self.dueDate : dueDate // ignore: cast_nullable_to_non_nullable
as DateTime?,dueKm: freezed == dueKm ? _self.dueKm : dueKm // ignore: cast_nullable_to_non_nullable
as double?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,notes: freezed == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [ServiceReminder].
extension ServiceReminderPatterns on ServiceReminder {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ServiceReminder value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ServiceReminder() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ServiceReminder value)  $default,){
final _that = this;
switch (_that) {
case _ServiceReminder():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ServiceReminder value)?  $default,){
final _that = this;
switch (_that) {
case _ServiceReminder() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: '_id')  String id,  dynamic vehicle,  String serviceType,  DateTime? dueDate,  double? dueKm,  String status,  String? notes)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ServiceReminder() when $default != null:
return $default(_that.id,_that.vehicle,_that.serviceType,_that.dueDate,_that.dueKm,_that.status,_that.notes);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: '_id')  String id,  dynamic vehicle,  String serviceType,  DateTime? dueDate,  double? dueKm,  String status,  String? notes)  $default,) {final _that = this;
switch (_that) {
case _ServiceReminder():
return $default(_that.id,_that.vehicle,_that.serviceType,_that.dueDate,_that.dueKm,_that.status,_that.notes);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: '_id')  String id,  dynamic vehicle,  String serviceType,  DateTime? dueDate,  double? dueKm,  String status,  String? notes)?  $default,) {final _that = this;
switch (_that) {
case _ServiceReminder() when $default != null:
return $default(_that.id,_that.vehicle,_that.serviceType,_that.dueDate,_that.dueKm,_that.status,_that.notes);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ServiceReminder implements ServiceReminder {
  const _ServiceReminder({@JsonKey(name: '_id') required this.id, required this.vehicle, required this.serviceType, this.dueDate, this.dueKm, this.status = 'pending', this.notes});
  factory _ServiceReminder.fromJson(Map<String, dynamic> json) => _$ServiceReminderFromJson(json);

@override@JsonKey(name: '_id') final  String id;
@override final  dynamic vehicle;
@override final  String serviceType;
@override final  DateTime? dueDate;
@override final  double? dueKm;
@override@JsonKey() final  String status;
@override final  String? notes;

/// Create a copy of ServiceReminder
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ServiceReminderCopyWith<_ServiceReminder> get copyWith => __$ServiceReminderCopyWithImpl<_ServiceReminder>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ServiceReminderToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ServiceReminder&&(identical(other.id, id) || other.id == id)&&const DeepCollectionEquality().equals(other.vehicle, vehicle)&&(identical(other.serviceType, serviceType) || other.serviceType == serviceType)&&(identical(other.dueDate, dueDate) || other.dueDate == dueDate)&&(identical(other.dueKm, dueKm) || other.dueKm == dueKm)&&(identical(other.status, status) || other.status == status)&&(identical(other.notes, notes) || other.notes == notes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,const DeepCollectionEquality().hash(vehicle),serviceType,dueDate,dueKm,status,notes);

@override
String toString() {
  return 'ServiceReminder(id: $id, vehicle: $vehicle, serviceType: $serviceType, dueDate: $dueDate, dueKm: $dueKm, status: $status, notes: $notes)';
}


}

/// @nodoc
abstract mixin class _$ServiceReminderCopyWith<$Res> implements $ServiceReminderCopyWith<$Res> {
  factory _$ServiceReminderCopyWith(_ServiceReminder value, $Res Function(_ServiceReminder) _then) = __$ServiceReminderCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: '_id') String id, dynamic vehicle, String serviceType, DateTime? dueDate, double? dueKm, String status, String? notes
});




}
/// @nodoc
class __$ServiceReminderCopyWithImpl<$Res>
    implements _$ServiceReminderCopyWith<$Res> {
  __$ServiceReminderCopyWithImpl(this._self, this._then);

  final _ServiceReminder _self;
  final $Res Function(_ServiceReminder) _then;

/// Create a copy of ServiceReminder
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? vehicle = freezed,Object? serviceType = null,Object? dueDate = freezed,Object? dueKm = freezed,Object? status = null,Object? notes = freezed,}) {
  return _then(_ServiceReminder(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,vehicle: freezed == vehicle ? _self.vehicle : vehicle // ignore: cast_nullable_to_non_nullable
as dynamic,serviceType: null == serviceType ? _self.serviceType : serviceType // ignore: cast_nullable_to_non_nullable
as String,dueDate: freezed == dueDate ? _self.dueDate : dueDate // ignore: cast_nullable_to_non_nullable
as DateTime?,dueKm: freezed == dueKm ? _self.dueKm : dueKm // ignore: cast_nullable_to_non_nullable
as double?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,notes: freezed == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
