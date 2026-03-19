class BookingAssignment {
  final String employeeId;
  final String artistName;
  final String role;
  final String phone;
  final String type;
  final String roleType;

  const BookingAssignment({
    required this.employeeId,
    required this.artistName,
    required this.role,
    this.phone = '',
    required this.type,
    required this.roleType,
  });

  factory BookingAssignment.fromJson(Map<String, dynamic> json) {
    return BookingAssignment(
      employeeId: json['employeeId'] as String? ?? '',
      artistName: json['artistName'] as String? ?? '',
      role: json['role'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      type: json['type'] as String? ?? '',
      roleType: json['roleType'] as String? ?? 'assistant',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'employeeId': employeeId,
      'artistName': artistName,
      'role': role,
      'phone': phone,
      'type': type,
      'roleType': roleType,
    };
  }

  BookingAssignment copyWith({
    String? employeeId,
    String? artistName,
    String? role,
    String? phone,
    String? type,
    String? roleType,
  }) {
    return BookingAssignment(
      employeeId: employeeId ?? this.employeeId,
      artistName: artistName ?? this.artistName,
      role: role ?? this.role,
      phone: phone ?? this.phone,
      type: type ?? this.type,
      roleType: roleType ?? this.roleType,
    );
  }
}

class BookingAddon {
  final String addonServiceId;
  final String service;
  final double amount;
  final int persons;

  const BookingAddon({
    this.addonServiceId = '',
    required this.service,
    required this.amount,
    required this.persons,
  });

  factory BookingAddon.fromJson(Map<String, dynamic> json) {
    return BookingAddon(
      addonServiceId: json['addonServiceId'] as String? ?? '',
      service: json['service'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      persons: (json['persons'] as num?)?.toInt() ?? 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'addonServiceId': addonServiceId,
      'service': service,
      'amount': amount,
      'persons': persons,
    };
  }

  BookingAddon copyWith({
    String? addonServiceId,
    String? service,
    double? amount,
    int? persons,
  }) {
    return BookingAddon(
      addonServiceId: addonServiceId ?? this.addonServiceId,
      service: service ?? this.service,
      amount: amount ?? this.amount,
      persons: persons ?? this.persons,
    );
  }
}

/// A model class representing a single booking in the system.
class Booking {
  final String id;
  final String packageId;
  final String regionId;
  final String driverId;
  final String customerName;
  final String phone;
  final String email;
  final String service;
  final String region;
  final String driverName;
  final String status;
  final String mapUrl;
  final String travelMode;
  final String travelTime;
  final double travelDistanceKm;
  final String requiredRoomDetail;
  final String secondaryContact;
  final String outfitDetails;
  final String captureStaffDetails;
  final String staffInstructions;
  final String internalRemarks;
  final bool contentCreationRequired;
  final DateTime bookingDate; // The "record" / calendar date
  final DateTime serviceStart; // Start of service period
  final DateTime serviceEnd; // End of service period
  final double totalPrice;
  final double advanceAmount;
  final double discountAmount;
  final String discountType;
  final double discountValue;
  final List<BookingAssignment> assignedStaff;
  final List<BookingAddon> addons;

  const Booking({
    required this.id,
    this.packageId = '',
    this.regionId = '',
    this.driverId = '',
    required this.customerName,
    required this.phone,
    this.email = '',
    required this.service,
    this.region = '',
    this.driverName = '',
    this.status = 'pending',
    this.mapUrl = '',
    this.travelMode = '',
    this.travelTime = '',
    this.travelDistanceKm = 0,
    this.requiredRoomDetail = '',
    this.secondaryContact = '',
    this.outfitDetails = '',
    this.captureStaffDetails = '',
    this.staffInstructions = '',
    this.internalRemarks = '',
    this.contentCreationRequired = false,
    required this.bookingDate,
    required this.serviceStart,
    required this.serviceEnd,
    required this.totalPrice,
    required this.advanceAmount,
    this.discountAmount = 0,
    this.discountType = 'inr',
    this.discountValue = 0,
    this.assignedStaff = const [],
    this.addons = const [],
  });

  /// Returns true if this booking falls on the given calendar date.
  bool isOnDate(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    final start = DateTime(
      serviceStart.year,
      serviceStart.month,
      serviceStart.day,
    );
    final end = DateTime(serviceEnd.year, serviceEnd.month, serviceEnd.day);
    return !d.isBefore(start) && !d.isAfter(end);
  }

  String get initials =>
      customerName.isNotEmpty ? customerName[0].toUpperCase() : '?';

  factory Booking.fromJson(Map<String, dynamic> json) {
    return Booking(
      id: json['_id'] as String? ?? json['id'] as String? ?? '',
      packageId: json['packageId'] as String? ?? '',
      regionId: json['regionId'] as String? ?? '',
      driverId: json['driverId'] as String? ?? '',
      customerName: json['customerName'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      email: json['email'] as String? ?? '',
      service: json['service'] as String? ?? '',
      region: json['region'] as String? ?? '',
      driverName: json['driverName'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      mapUrl: json['mapUrl'] as String? ?? '',
      travelMode: json['travelMode'] as String? ?? '',
      travelTime: json['travelTime'] as String? ?? '',
      travelDistanceKm: (json['travelDistanceKm'] as num?)?.toDouble() ?? 0,
      requiredRoomDetail: json['requiredRoomDetail'] as String? ?? '',
      secondaryContact: json['secondaryContact'] as String? ?? '',
      outfitDetails: json['outfitDetails'] as String? ?? '',
      captureStaffDetails: json['captureStaffDetails'] as String? ?? '',
      staffInstructions: json['staffInstructions'] as String? ?? '',
      internalRemarks: json['internalRemarks'] as String? ?? '',
      contentCreationRequired:
          json['contentCreationRequired'] as bool? ?? false,
      bookingDate: json['bookingDate'] != null
          ? DateTime.parse(json['bookingDate'] as String).toLocal()
          : DateTime.now(),
      serviceStart: json['serviceStart'] != null
          ? DateTime.parse(json['serviceStart'] as String).toLocal()
          : DateTime.now(),
      serviceEnd: json['serviceEnd'] != null
          ? DateTime.parse(json['serviceEnd'] as String).toLocal()
          : DateTime.now(),
      totalPrice: (json['totalPrice'] as num?)?.toDouble() ?? 0.0,
      advanceAmount: (json['advanceAmount'] as num?)?.toDouble() ?? 0.0,
      discountAmount: (json['discountAmount'] as num?)?.toDouble() ?? 0.0,
      discountType: json['discountType'] as String? ?? 'inr',
      discountValue: (json['discountValue'] as num?)?.toDouble() ?? 0.0,
      assignedStaff: ((json['assignedStaff'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(BookingAssignment.fromJson)
          .toList(),
      addons: ((json['addons'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(BookingAddon.fromJson)
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'customerName': customerName,
      'packageId': packageId,
      'regionId': regionId,
      'driverId': driverId,
      'phone': phone,
      'email': email,
      'service': service,
      'region': region,
      'driverName': driverName,
      'status': status,
      'mapUrl': mapUrl,
      'travelMode': travelMode,
      'travelTime': travelTime,
      'travelDistanceKm': travelDistanceKm,
      'requiredRoomDetail': requiredRoomDetail,
      'secondaryContact': secondaryContact,
      'outfitDetails': outfitDetails,
      'captureStaffDetails': captureStaffDetails,
      'staffInstructions': staffInstructions,
      'internalRemarks': internalRemarks,
      'contentCreationRequired': contentCreationRequired,
      'bookingDate': bookingDate.toIso8601String(),
      'serviceStart': serviceStart.toIso8601String(),
      'serviceEnd': serviceEnd.toIso8601String(),
      'totalPrice': totalPrice,
      'advanceAmount': advanceAmount,
      'discountAmount': discountAmount,
      'discountType': discountType,
      'discountValue': discountValue,
      'assignedStaff': assignedStaff.map((item) => item.toJson()).toList(),
      'addons': addons.map((item) => item.toJson()).toList(),
    };
  }

  Booking copyWith({
    String? id,
    String? packageId,
    String? regionId,
    String? driverId,
    String? customerName,
    String? phone,
    String? email,
    String? service,
    String? region,
    String? driverName,
    String? status,
    String? mapUrl,
    String? travelMode,
    String? travelTime,
    double? travelDistanceKm,
    String? requiredRoomDetail,
    String? secondaryContact,
    String? outfitDetails,
    String? captureStaffDetails,
    String? staffInstructions,
    String? internalRemarks,
    bool? contentCreationRequired,
    DateTime? bookingDate,
    DateTime? serviceStart,
    DateTime? serviceEnd,
    double? totalPrice,
    double? advanceAmount,
    double? discountAmount,
    String? discountType,
    double? discountValue,
    List<BookingAssignment>? assignedStaff,
    List<BookingAddon>? addons,
  }) {
    return Booking(
      id: id ?? this.id,
      packageId: packageId ?? this.packageId,
      regionId: regionId ?? this.regionId,
      driverId: driverId ?? this.driverId,
      customerName: customerName ?? this.customerName,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      service: service ?? this.service,
      region: region ?? this.region,
      driverName: driverName ?? this.driverName,
      status: status ?? this.status,
      mapUrl: mapUrl ?? this.mapUrl,
      travelMode: travelMode ?? this.travelMode,
      travelTime: travelTime ?? this.travelTime,
      travelDistanceKm: travelDistanceKm ?? this.travelDistanceKm,
      requiredRoomDetail: requiredRoomDetail ?? this.requiredRoomDetail,
      secondaryContact: secondaryContact ?? this.secondaryContact,
      outfitDetails: outfitDetails ?? this.outfitDetails,
      captureStaffDetails: captureStaffDetails ?? this.captureStaffDetails,
      staffInstructions: staffInstructions ?? this.staffInstructions,
      internalRemarks: internalRemarks ?? this.internalRemarks,
      contentCreationRequired:
          contentCreationRequired ?? this.contentCreationRequired,
      bookingDate: bookingDate ?? this.bookingDate,
      serviceStart: serviceStart ?? this.serviceStart,
      serviceEnd: serviceEnd ?? this.serviceEnd,
      totalPrice: totalPrice ?? this.totalPrice,
      advanceAmount: advanceAmount ?? this.advanceAmount,
      discountAmount: discountAmount ?? this.discountAmount,
      discountType: discountType ?? this.discountType,
      discountValue: discountValue ?? this.discountValue,
      assignedStaff: assignedStaff ?? this.assignedStaff,
      addons: addons ?? this.addons,
    );
  }
}
