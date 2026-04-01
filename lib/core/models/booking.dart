class BookingAssignment {
  final String employeeId;
  final String artistName;
  final String role;
  final String specialization;
  final List<String> works;
  final String phone;
  final String type;
  final String roleType;

  const BookingAssignment({
    required this.employeeId,
    required this.artistName,
    required this.role,
    this.specialization = '',
    this.works = const [],
    this.phone = '',
    required this.type,
    required this.roleType,
  });

  factory BookingAssignment.fromJson(Map<String, dynamic> json) {
    final normalizedWorks = ((json['works'] as List?) ?? const [])
        .map((item) => item?.toString().trim() ?? '')
        .where((item) => item.isNotEmpty)
        .toList();
    final specialization = json['specialization'] as String? ?? '';
    final role = json['role'] as String? ?? '';
    return BookingAssignment(
      employeeId: json['employeeId'] as String? ?? '',
      artistName: json['artistName'] as String? ?? '',
      role: role,
      specialization: specialization,
      works: normalizedWorks.isNotEmpty
          ? normalizedWorks
          : [
              if (specialization.trim().isNotEmpty)
                specialization.trim()
              else if (role.trim().isNotEmpty)
                role.trim(),
            ],
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
      'specialization': specialization,
      'works': works,
      'phone': phone,
      'type': type,
      'roleType': roleType,
    };
  }

  BookingAssignment copyWith({
    String? employeeId,
    String? artistName,
    String? role,
    String? specialization,
    List<String>? works,
    String? phone,
    String? type,
    String? roleType,
  }) {
    return BookingAssignment(
      employeeId: employeeId ?? this.employeeId,
      artistName: artistName ?? this.artistName,
      role: role ?? this.role,
      specialization: specialization ?? this.specialization,
      works: works ?? this.works,
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

class BookingItem {
  final String packageId;
  final String service;
  final String eventSlot;
  final List<DateTime> selectedDates;
  final double totalPrice;
  final double advanceAmount;
  final List<BookingAssignment> assignedStaff;

  const BookingItem({
    this.packageId = '',
    required this.service,
    this.eventSlot = '',
    this.selectedDates = const [],
    this.totalPrice = 0,
    this.advanceAmount = 0,
    this.assignedStaff = const [],
  });

  factory BookingItem.fromJson(Map<String, dynamic> json) {
    return BookingItem(
      packageId: json['packageId'] as String? ?? '',
      service: json['service'] as String? ?? '',
      eventSlot: json['eventSlot'] as String? ?? '',
      selectedDates: ((json['selectedDates'] as List?) ?? const [])
          .map(_parseDateOnlyValue)
          .toList(),
      totalPrice: (json['totalPrice'] as num?)?.toDouble() ?? 0.0,
      advanceAmount: (json['advanceAmount'] as num?)?.toDouble() ?? 0.0,
      assignedStaff: ((json['assignedStaff'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(BookingAssignment.fromJson)
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'packageId': packageId,
      'service': service,
      'eventSlot': eventSlot,
      'selectedDates': selectedDates.map(_formatDateOnly).toList(),
      'totalPrice': totalPrice,
      'advanceAmount': advanceAmount,
      'assignedStaff': assignedStaff.map((item) => item.toJson()).toList(),
    };
  }

  BookingItem copyWith({
    String? packageId,
    String? service,
    String? eventSlot,
    List<DateTime>? selectedDates,
    double? totalPrice,
    double? advanceAmount,
    List<BookingAssignment>? assignedStaff,
  }) {
    return BookingItem(
      packageId: packageId ?? this.packageId,
      service: service ?? this.service,
      eventSlot: eventSlot ?? this.eventSlot,
      selectedDates: selectedDates ?? this.selectedDates,
      totalPrice: totalPrice ?? this.totalPrice,
      advanceAmount: advanceAmount ?? this.advanceAmount,
      assignedStaff: assignedStaff ?? this.assignedStaff,
    );
  }
}

class BookingDisplayEntry {
  final String id;
  final Booking booking;
  final String service;
  final String eventSlot;
  final List<DateTime> selectedDates;
  final double totalPrice;
  final double advanceAmount;
  final DateTime serviceStart;
  final DateTime serviceEnd;
  final List<BookingAssignment> assignedStaff;

  const BookingDisplayEntry({
    required this.id,
    required this.booking,
    required this.service,
    required this.eventSlot,
    required this.selectedDates,
    required this.totalPrice,
    required this.advanceAmount,
    required this.serviceStart,
    required this.serviceEnd,
    required this.assignedStaff,
  });

  bool isOnDate(DateTime date) {
    final normalizedDay = DateTime(date.year, date.month, date.day);
    if (selectedDates.isNotEmpty) {
      return selectedDates.any(
        (selectedDate) =>
            selectedDate.year == normalizedDay.year &&
            selectedDate.month == normalizedDay.month &&
            selectedDate.day == normalizedDay.day,
      );
    }

    return serviceStart.year == normalizedDay.year &&
        serviceStart.month == normalizedDay.month &&
        serviceStart.day == normalizedDay.day;
  }

  String get summaryLabel {
    final normalizedSlot = eventSlot.trim();
    if (normalizedSlot.isNotEmpty) {
      return '$service • $normalizedSlot';
    }
    return service;
  }
}

class BookingPageSummary {
  final double totalSales;
  final double totalAdvance;
  final int completedCount;
  final int cancelledCount;

  const BookingPageSummary({
    this.totalSales = 0,
    this.totalAdvance = 0,
    this.completedCount = 0,
    this.cancelledCount = 0,
  });

  factory BookingPageSummary.fromJson(Map<String, dynamic> json) {
    return BookingPageSummary(
      totalSales: (json['totalSales'] as num?)?.toDouble() ?? 0,
      totalAdvance: (json['totalAdvance'] as num?)?.toDouble() ?? 0,
      completedCount: (json['completedCount'] as num?)?.toInt() ?? 0,
      cancelledCount: (json['cancelledCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class PaginatedBookingsResponse {
  final List<Booking> items;
  final int page;
  final int limit;
  final int totalItems;
  final int totalPages;
  final BookingPageSummary summary;

  const PaginatedBookingsResponse({
    required this.items,
    required this.page,
    required this.limit,
    required this.totalItems,
    required this.totalPages,
    required this.summary,
  });

  factory PaginatedBookingsResponse.fromJson(Map<String, dynamic> json) {
    return PaginatedBookingsResponse(
      items: ((json['items'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(Booking.fromJson)
          .toList(),
      page: (json['page'] as num?)?.toInt() ?? 1,
      limit: (json['limit'] as num?)?.toInt() ?? 20,
      totalItems: (json['totalItems'] as num?)?.toInt() ?? 0,
      totalPages: (json['totalPages'] as num?)?.toInt() ?? 1,
      summary: BookingPageSummary.fromJson(
        (json['summary'] as Map<String, dynamic>?) ?? const {},
      ),
    );
  }
}

/// A model class representing a single booking in the system.
class Booking {
  final String id;
  final String bookingNumber;
  final String packageId;
  final String regionId;
  final String driverId;
  final String customerName;
  final String phone;
  final String email;
  final bool legacyBooking;
  final String service;
  final String region;
  final String driverName;
  final String status;
  final String mapUrl;
  final String travelMode;
  final String travelTime;
  final double travelDistanceKm;
  final String eventSlot;
  final String requiredRoomDetail;
  final String secondaryContact;
  final String outfitDetails;
  final String captureStaffDetails;
  final String temporaryStaffDetails;
  final String staffInstructions;
  final String internalRemarks;
  final bool contentCreationRequired;
  final DateTime bookingDate; // The "record" / calendar date
  final List<DateTime> selectedDates;
  final DateTime serviceStart; // Start of service period
  final DateTime serviceEnd; // End of service period
  final double totalPrice;
  final double advanceAmount;
  final double discountAmount;
  final String discountType;
  final double discountValue;
  final List<BookingAssignment> assignedStaff;
  final List<BookingAddon> addons;
  final List<BookingItem> bookingItems;

  const Booking({
    required this.id,
    this.bookingNumber = '',
    this.packageId = '',
    this.regionId = '',
    this.driverId = '',
    required this.customerName,
    required this.phone,
    this.email = '',
    this.legacyBooking = false,
    required this.service,
    this.region = '',
    this.driverName = '',
    this.status = 'pending',
    this.mapUrl = '',
    this.travelMode = '',
    this.travelTime = '',
    this.travelDistanceKm = 0,
    this.eventSlot = '',
    this.requiredRoomDetail = '',
    this.secondaryContact = '',
    this.outfitDetails = '',
    this.captureStaffDetails = '',
    this.temporaryStaffDetails = '',
    this.staffInstructions = '',
    this.internalRemarks = '',
    this.contentCreationRequired = false,
    required this.bookingDate,
    this.selectedDates = const [],
    required this.serviceStart,
    required this.serviceEnd,
    required this.totalPrice,
    required this.advanceAmount,
    this.discountAmount = 0,
    this.discountType = 'inr',
    this.discountValue = 0,
    this.assignedStaff = const [],
    this.addons = const [],
    this.bookingItems = const [],
  });

  /// Returns true if this booking falls on the given calendar date.
  bool isOnDate(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    if (selectedDates.isNotEmpty) {
      return selectedDates.any(
        (selectedDate) =>
            selectedDate.year == d.year &&
            selectedDate.month == d.month &&
            selectedDate.day == d.day,
      );
    }
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

  String get displayBookingNumber {
    final explicitNumber = bookingNumber.trim();
    if (explicitNumber.isNotEmpty) return explicitNumber;
    return _numericBookingId(id);
  }

  List<BookingDisplayEntry> get displayEntries {
    final fallbackDates = selectedDates.isNotEmpty
        ? selectedDates
        : <DateTime>[bookingDate];

    if (bookingItems.isEmpty) {
      return [
        BookingDisplayEntry(
          id: '$id::0',
          booking: this,
          service: service,
          eventSlot: eventSlot,
          selectedDates: fallbackDates,
          totalPrice: totalPrice,
          advanceAmount: advanceAmount,
          serviceStart: serviceStart,
          serviceEnd: serviceEnd,
          assignedStaff: assignedStaff,
        ),
      ];
    }

    return bookingItems.asMap().entries.map((entry) {
      final index = entry.key;
      final item = entry.value;
      final itemDates = item.selectedDates.isNotEmpty
          ? item.selectedDates
          : fallbackDates;
      final anchorDate = itemDates.isNotEmpty ? itemDates.first : bookingDate;
      final itemStart = DateTime(
        anchorDate.year,
        anchorDate.month,
        anchorDate.day,
        serviceStart.hour,
        serviceStart.minute,
      );
      final itemEndDate = itemDates.isNotEmpty ? itemDates.last : anchorDate;
      final itemEnd = DateTime(
        itemEndDate.year,
        itemEndDate.month,
        itemEndDate.day,
        serviceEnd.hour,
        serviceEnd.minute,
      );

      return BookingDisplayEntry(
        id: '$id::$index',
        booking: this,
        service: item.service,
        eventSlot: item.eventSlot,
        selectedDates: itemDates,
        totalPrice: item.totalPrice,
        advanceAmount: item.advanceAmount,
        serviceStart: itemStart,
        serviceEnd: itemEnd,
        assignedStaff: item.assignedStaff,
      );
    }).toList();
  }

  factory Booking.fromJson(Map<String, dynamic> json) {
    final parsedSelectedDates = ((json['selectedDates'] as List?) ?? const [])
        .map(_parseDateOnlyValue)
        .toList();
    final parsedBookingDate = json['bookingDate'] != null
        ? _parseDateOnlyValue(json['bookingDate'])
        : DateTime.now();

    return Booking(
      id: json['_id'] as String? ?? json['id'] as String? ?? '',
      bookingNumber: json['bookingNumber'] as String? ?? '',
      packageId: json['packageId'] as String? ?? '',
      regionId: json['regionId'] as String? ?? '',
      driverId: json['driverId'] as String? ?? '',
      customerName: json['customerName'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      email: json['email'] as String? ?? '',
      legacyBooking: json['legacyBooking'] as bool? ?? false,
      service: json['service'] as String? ?? '',
      region: json['region'] as String? ?? '',
      driverName: json['driverName'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      mapUrl: json['mapUrl'] as String? ?? '',
      travelMode: json['travelMode'] as String? ?? '',
      travelTime: json['travelTime'] as String? ?? '',
      travelDistanceKm: (json['travelDistanceKm'] as num?)?.toDouble() ?? 0,
      eventSlot: json['eventSlot'] as String? ?? '',
      requiredRoomDetail: json['requiredRoomDetail'] as String? ?? '',
      secondaryContact: json['secondaryContact'] as String? ?? '',
      outfitDetails: json['outfitDetails'] as String? ?? '',
      captureStaffDetails: json['captureStaffDetails'] as String? ?? '',
      temporaryStaffDetails: json['temporaryStaffDetails'] as String? ?? '',
      staffInstructions: json['staffInstructions'] as String? ?? '',
      internalRemarks: json['internalRemarks'] as String? ?? '',
      contentCreationRequired:
          json['contentCreationRequired'] as bool? ?? false,
      bookingDate: parsedSelectedDates.isNotEmpty
          ? parsedSelectedDates.first
          : parsedBookingDate,
      selectedDates: parsedSelectedDates,
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
      bookingItems: ((json['bookingItems'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(BookingItem.fromJson)
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'bookingNumber': bookingNumber,
      'customerName': customerName,
      'packageId': packageId,
      'regionId': regionId,
      'driverId': driverId,
      'phone': phone,
      'email': email,
      'legacyBooking': legacyBooking,
      'service': service,
      'region': region,
      'driverName': driverName,
      'status': status,
      'mapUrl': mapUrl,
      'travelMode': travelMode,
      'travelTime': travelTime,
      'travelDistanceKm': travelDistanceKm,
      'eventSlot': eventSlot,
      'requiredRoomDetail': requiredRoomDetail,
      'secondaryContact': secondaryContact,
      'outfitDetails': outfitDetails,
      'captureStaffDetails': captureStaffDetails,
      'temporaryStaffDetails': temporaryStaffDetails,
      'staffInstructions': staffInstructions,
      'internalRemarks': internalRemarks,
      'contentCreationRequired': contentCreationRequired,
      'bookingDate': _formatDateOnly(bookingDate),
      'selectedDates': selectedDates
          .map(_formatDateOnly)
          .toList(),
      'serviceStart': serviceStart.toIso8601String(),
      'serviceEnd': serviceEnd.toIso8601String(),
      'totalPrice': totalPrice,
      'advanceAmount': advanceAmount,
      'discountAmount': discountAmount,
      'discountType': discountType,
      'discountValue': discountValue,
      'assignedStaff': assignedStaff.map((item) => item.toJson()).toList(),
      'addons': addons.map((item) => item.toJson()).toList(),
      'bookingItems': bookingItems.map((item) => item.toJson()).toList(),
    };
  }

  Booking copyWith({
    String? id,
    String? bookingNumber,
    String? packageId,
    String? regionId,
    String? driverId,
    String? customerName,
    String? phone,
    String? email,
    bool? legacyBooking,
    String? service,
    String? region,
    String? driverName,
    String? status,
    String? mapUrl,
    String? travelMode,
    String? travelTime,
    double? travelDistanceKm,
    String? eventSlot,
    String? requiredRoomDetail,
    String? secondaryContact,
    String? outfitDetails,
    String? captureStaffDetails,
    String? temporaryStaffDetails,
    String? staffInstructions,
    String? internalRemarks,
    bool? contentCreationRequired,
    DateTime? bookingDate,
    List<DateTime>? selectedDates,
    DateTime? serviceStart,
    DateTime? serviceEnd,
    double? totalPrice,
    double? advanceAmount,
    double? discountAmount,
    String? discountType,
    double? discountValue,
    List<BookingAssignment>? assignedStaff,
    List<BookingAddon>? addons,
    List<BookingItem>? bookingItems,
  }) {
    return Booking(
      id: id ?? this.id,
      bookingNumber: bookingNumber ?? this.bookingNumber,
      packageId: packageId ?? this.packageId,
      regionId: regionId ?? this.regionId,
      driverId: driverId ?? this.driverId,
      customerName: customerName ?? this.customerName,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      legacyBooking: legacyBooking ?? this.legacyBooking,
      service: service ?? this.service,
      region: region ?? this.region,
      driverName: driverName ?? this.driverName,
      status: status ?? this.status,
      mapUrl: mapUrl ?? this.mapUrl,
      travelMode: travelMode ?? this.travelMode,
      travelTime: travelTime ?? this.travelTime,
      travelDistanceKm: travelDistanceKm ?? this.travelDistanceKm,
      eventSlot: eventSlot ?? this.eventSlot,
      requiredRoomDetail: requiredRoomDetail ?? this.requiredRoomDetail,
      secondaryContact: secondaryContact ?? this.secondaryContact,
      outfitDetails: outfitDetails ?? this.outfitDetails,
      captureStaffDetails: captureStaffDetails ?? this.captureStaffDetails,
      temporaryStaffDetails:
          temporaryStaffDetails ?? this.temporaryStaffDetails,
      staffInstructions: staffInstructions ?? this.staffInstructions,
      internalRemarks: internalRemarks ?? this.internalRemarks,
      contentCreationRequired:
          contentCreationRequired ?? this.contentCreationRequired,
      bookingDate: bookingDate ?? this.bookingDate,
      selectedDates: selectedDates ?? this.selectedDates,
      serviceStart: serviceStart ?? this.serviceStart,
      serviceEnd: serviceEnd ?? this.serviceEnd,
      totalPrice: totalPrice ?? this.totalPrice,
      advanceAmount: advanceAmount ?? this.advanceAmount,
      discountAmount: discountAmount ?? this.discountAmount,
      discountType: discountType ?? this.discountType,
      discountValue: discountValue ?? this.discountValue,
      assignedStaff: assignedStaff ?? this.assignedStaff,
      addons: addons ?? this.addons,
      bookingItems: bookingItems ?? this.bookingItems,
    );
  }
}

String _numericBookingId(String value) {
  final normalizedValue = value.trim();
  if (normalizedValue.isEmpty) return '0000000000';
  if (RegExp(r'^\d+$').hasMatch(normalizedValue)) return normalizedValue;

  if (RegExp(r'^[a-fA-F0-9]+$').hasMatch(normalizedValue)) {
    try {
      final numericValue = BigInt.parse(normalizedValue, radix: 16).toString();
      return numericValue.length > 10
          ? numericValue.substring(numericValue.length - 10)
          : numericValue;
    } catch (_) {
      // Fall through to the generic digit-only cleanup.
    }
  }

  final digitsOnly = normalizedValue.replaceAll(RegExp(r'\D'), '');
  return digitsOnly.isNotEmpty ? digitsOnly : '0000000000';
}

DateTime _parseDateOnlyValue(dynamic raw) {
  final value = raw?.toString() ?? '';
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(value);
  if (match != null) {
    return DateTime(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
    );
  }

  final parsed = DateTime.tryParse(value)?.toLocal();
  if (parsed != null) {
    return DateTime(parsed.year, parsed.month, parsed.day);
  }

  return DateTime.now();
}

String _formatDateOnly(DateTime date) {
  final year = date.year.toString().padLeft(4, '0');
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}
